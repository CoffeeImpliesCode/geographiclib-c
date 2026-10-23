// SPDX-License-Identifier: MIT

const std = @import("std");

/// Runtime graph builder; loader types must share one module instance.
const runtime_graph = @import("runtime/graph.zig");

const manifest = @import("build.zig.zon");

const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// Upstream version from CMakeLists.txt:5-13 and src/geodesic.h:29,34,39.
const upstream_version: std.SemanticVersion = .{ .major = 2, .minor = 2, .patch = 0 };

const module_name = "geographiclib";

/// Upstream artifact name (CMakeLists.txt:66).
const lib_name = "geodc";

const pkg_config_name = "libgeodc";

const facade_source = "zig/root.zig";

/// Calls public facade methods so the compiler analyzes their bodies.
const exercise_source = "zig/api_exercise.zig";

const translate_header = "zig/translate.h";

const test_source = "tests.zig";

const example_source = "smoke.zig";

/// Upstream requires C99 (CMakeLists.txt:28-31).
/// Disable FP contraction for the numerical contract (CMakeLists.txt:43-56).
const c_flags = [_][]const u8{ "-std=c99", "-ffp-contract=off" };

/// Shared ELF/Mach-O builds hide symbols not marked public by `geodesic.h`.
const c_flags_shared = [_][]const u8{"-fvisibility=hidden"};

const c_flags_dynamic = c_flags ++ c_flags_shared;

fn cUnitFlags(
    target: std.Build.ResolvedTarget,
    linkage: std.lang.LinkMode,
) []const []const u8 {
    const shared = linkage == .dynamic and !exportsThroughDeclspec(target);
    return if (shared) &c_flags_dynamic else &c_flags;
}

/// Core source list from upstream's library target (src/CMakeLists.txt:1).
const core_sources = [_][]const u8{
    "src/geodesic.c",
};

/// Upstream public header (src/CMakeLists.txt:1).
const public_header = "src/geodesic.h";

const source_dir = "src";

const licence_records = [_][]const u8{
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
    "UPSTREAM.sha256",
};

const doc_records = [_][]const u8{
    "README.upstream.md",
    "doc/geodesic-c.dox.in",
    "doc/doxyfile.in",
    "doc/HEADER.html",
    "doc/FOOTER.html",
};

/// Upstream test programs and link requirements (tests/CMakeLists.txt:1).
const UpstreamTest = struct {
    name: []const u8,
    source: []const u8,
    /// False when the source includes geodesic.c, or linking duplicates symbols (tests/geodsigntest.c:16).
    links_library: bool,
};

const upstream_tests = [_]UpstreamTest{
    .{ .name = "geodtest", .source = "tests/geodtest.c", .links_library = true },
    .{ .name = "geodsigntest", .source = "tests/geodsigntest.c", .links_library = false },
};

const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

const Graph = struct {
    c_lib: *std.Build.Step.Compile,
    module: *std.Build.Module,
    /// Translated header or runtime dispatch.
    c_module: *std.Build.Module,
    /// Reuse the loader module so its public types keep one identity.
    core_module: ?*std.Build.Module,
};

/// Target triples keep private matrix artifact names unique.
fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// Link libm where libc does not provide geodesic.c's math calls.
fn mathLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => "m",
        else => null,
    };
}

/// Add libm to the consumer module; static archives do not propagate system libraries.
fn linkMath(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (mathLibrary(target)) |lib| module.linkSystemLibrary(lib, .{});
}

/// COFF exports need declspec; ELF/Mach-O use symbol visibility.
fn exportsThroughDeclspec(target: std.Build.ResolvedTarget) bool {
    return switch (target.result.os.tag) {
        .windows, .uefi => true,
        else => false,
    };
}

/// Windows loads DLLs without an interpreter path; other shared targets need a dynamic linker.
fn targetCanCarry(
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) bool {
    return requested == .static or target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

fn unsupportedLinkageReason(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    return b.fmt(
        "geographiclib: -Dlinkage=dynamic is unsupported for {s}: dynamic linker kind is {s}. " ++
            "No static archive is substituted. Use -Dlinkage=static for this target.",
        .{ @tagName(target.result.os.tag), @tagName(std.Target.DynamicLinker.kind(target.result.os.tag)) },
    );
}

/// Reject unsupported shared linkage before creating target build steps.
fn requireSupportedLinkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) void {
    if (!targetCanCarry(target, requested)) {
        @panic(unsupportedLinkageReason(b, target));
    }
}

fn addCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    name: []const u8,
) *std.Build.Step.Compile {
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // Upstream defines no shared-library version (src/CMakeLists.txt:1).
        .version = null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // libc supplies math headers and constants used in src/geodesic.c:27-28.
            .link_libc = true,
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;
    c_mod.addIncludePath(b.path(source_dir));

    // GEOD_DLL selects the header's dllexport branch; PROJ's macro is for PROJ integration (src/geodesic.h:64-72).
    if (linkage == .dynamic and exportsThroughDeclspec(target)) {
        c_mod.addCMacro("GEOD_DLL", "__declspec(dllexport)");
    }

    for (core_sources) |source| {
        c_mod.addCSourceFile(.{
            .file = b.path(source),
            .flags = cUnitFlags(target, linkage),
        });
    }

    linkMath(c_mod, target);

    // Installing this header adds it to linking consumers' include paths.
    c_lib.installHeader(b.path(public_header), "geodesic.h");

    return c_lib;
}

/// Build a facade graph; matrix targets use private modules.
/// Only the public graph registers `module_name`.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
    public: bool,
) Graph {
    requireSupportedLinkage(b, target, linkage);

    const c_lib = addCLibrary(b, target, optimize, linkage, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Translate this tree's header, not a host-installed copy (WISDOM.md W14).
    translate.addIncludePath(b.path(source_dir));

    const module = if (public)
        b.addModule(module_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Reuse the translation step so runtime C types keep one identity.
    // The dispatch owns the only loader core; the linked graph imports it.
    const c_module = if (runtime_loaded) blk: {
        // Runtime symbols must come through the loader, not static links.
        break :blk runtime_graph.createModule(b, translate, target, optimize);
    } else blk: {
        // Do not register `c` separately; that would expose declarations without the library.
        break :blk translate.createModule();
    };
    module.addImport("c", c_module);

    const core_module: ?*std.Build.Module = if (runtime_loaded)
        null
    else
        runtime_graph.createCoreModule(b, target, optimize);

    if (core_module) |rt| {
        module.addImport("rt", rt);
        module.linkLibrary(c_lib);
        linkMath(module, target);
    }

    module.addIncludePath(b.path(source_dir));

    return .{
        .c_lib = c_lib,
        .module = module,
        .c_module = c_module,
        .core_module = core_module,
    };
}

fn facadeProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    facade: *std.Build.Module,
    source: []const u8,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport(module_name, facade);
    return mod;
}

fn addExercise(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    graph: Graph,
    runtime_loaded: bool,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .root_source_file = b.path(exercise_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("c", graph.c_module);
    // Resolve the facade's `rt` import against this module's import table.
    if (graph.core_module) |rt| mod.addImport("rt", rt);
    if (!runtime_loaded) {
        mod.linkLibrary(graph.c_lib);
        linkMath(mod, target);
    }
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Compile upstream tests; geodsigntest includes geodesic.c (tests/geodsigntest.c:16).
fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    graph: Graph,
    spec: UpstreamTest,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path(source_dir));
    mod.addCSourceFile(.{
        .file = b.path(spec.source),
        .flags = &c_flags,
    });
    linkMath(mod, target);
    if (spec.links_library) {
        mod.linkLibrary(graph.c_lib);
    }
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Generate relocatable pkg-config metadata; upstream ships no pkg-config file.
/// Keep upstream's version spelling and place static-only libm in `Libs.private`.
/// `GEOD_DLL` is export-only, so omit it from Windows `Cflags` (src/geodesic.h:64-72).
fn addPkgConfig(b: *std.Build, target: std.Build.ResolvedTarget) void {
    const libs_private = if (mathLibrary(target)) |lib|
        b.fmt("Libs.private: -l{s}\n", .{lib})
    else
        "";

    const pc = b.addWriteFiles().add(b.fmt("{s}.pc", .{pkg_config_name}), b.fmt(
        \\# Generated by build.zig. Upstream ships no pkg-config file:
        \\# src/CMakeLists.txt:1 names one library and there is no install()
        \\# rule in the tree (HOWTO-RELEASE.txt, "not supported: install"),
        \\# so every field below comes from the build that produced the
        \\# library rather than from an upstream template. addPkgConfig names
        \\# which three of these fields are this graph's own decision and why.
        \\prefix=${{pcfiledir}}/../..
        \\exec_prefix=${{prefix}}
        \\libdir=${{prefix}}/lib
        \\includedir=${{prefix}}/include
        \\
        \\Name: {s}
        \\Description: GeographicLib-C, the geodesic routines in C
        \\URL: https://geographiclib.sourceforge.io/C/doc
        \\Version: {d}.{d}
        \\
        \\Requires:
        \\Libs: -L"${{libdir}}" -l{s}
        \\{s}Cflags: -I"${{includedir}}"
        \\
    , .{
        pkg_config_name,
        upstream_version.major,
        upstream_version.minor,
        lib_name,
        libs_private,
    }));
    const install = b.addInstallFileWithDir(
        pc,
        .lib,
        b.fmt("pkgconfig/{s}.pc", .{pkg_config_name}),
    );
    b.getInstallStep().dependOn(&install.step);
}

/// Install licence/provenance records and upstream documentation.
fn installRecords(b: *std.Build) void {
    for (licence_records) |record| {
        const install = b.addInstallFileWithDir(
            b.path(record),
            .prefix,
            b.fmt("share/licenses/{s}/{s}", .{ module_name, record }),
        );
        b.getInstallStep().dependOn(&install.step);
    }
    for (doc_records) |record| {
        const install = b.addInstallFileWithDir(
            b.path(record),
            .prefix,
            b.fmt("share/doc/{s}/{s}", .{ module_name, std.fs.path.basename(record) }),
        );
        b.getInstallStep().dependOn(&install.step);
    }
}

fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // Target triples keep per-target artifact names unique.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // Exclude unsupported linkage rather than substituting a static archive.
    if (!targetCanCarry(cross_target, linkage)) {
        std.debug.print(
            "geographiclib: check: {s} is NOT covered by this run. {s}\n",
            .{ triple, unsupportedLinkageReason(b, cross_target) },
        );
        return;
    }

    const graph = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false);

    step.dependOn(&addExercise(
        b,
        cross_target,
        optimize,
        graph,
        runtime_loaded,
        b.fmt("geographiclib-exercise-{s}", .{triple}),
    ).step);

    step.dependOn(&b.addTest(.{
        .name = b.fmt("geographiclib-tests-{s}", .{triple}),
        .root_module = facadeProgram(b, cross_target, optimize, graph.module, test_source),
    }).step);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("geographiclib-smoke-{s}", .{triple}),
        .root_module = facadeProgram(b, cross_target, optimize, graph.module, example_source),
    }).step);

    for (upstream_tests) |spec| {
        step.dependOn(&addUpstreamTest(
            b,
            cross_target,
            optimize,
            graph,
            spec,
            b.fmt("{s}-{s}", .{ spec.name, triple }),
        ).step);
    }
}

pub fn build(b: *std.Build) void {
    // Require the manifest version to match upstream sources (CMakeLists.txt:5-13; src/geodesic.h:29,34,39).
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version does not match upstream's version read from " ++
            "CMakeLists.txt:5-13 and src/geodesic.h:29,34,39");
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and what " ++
            "this build has always produced) or as a real shared object. The " ++
            "compiled C, the header, the translation, the facade, the tests and " ++
            "the example are identical either way: the option selects the " ++
            "delivery, never the dispatch. A target whose OS has no dynamic " ++
            "linker cannot carry a shared object, and -Dlinkage=dynamic is " ++
            "refused for it at configure time rather than delivered as an " ++
            "archive; the static default works on every target, including wasi.",
    ) orelse .static;

    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated header and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, and " ++
            "nothing native is linked into the module. The native artifact is " ++
            "still compiled and still installed, so a caller may name this " ++
            "build's own provider or another one. Orthogonal to -Dlinkage: that " ++
            "option says which artifact is delivered, this one says how the " ++
            "module reaches it.",
    ) orelse false;

    const graph = addGraph(b, target, optimize, linkage, runtime_loaded, true);

    b.installArtifact(graph.c_lib);
    b.installFile("LICENSE.txt", "LICENSE.txt");
    installRecords(b);
    addPkgConfig(b, target);

    const example = b.addExecutable(.{
        .name = "geographiclib-smoke",
        .root_module = facadeProgram(b, target, optimize, graph.module, example_source),
    });
    b.getInstallStep().dependOn(&example.step);

    // Run the example without depending on the install layout.
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    run_example.addPassthruArgs();
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    const consumer = b.addExecutable(.{
        .name = "geographiclib-consumer",
        .root_module = facadeProgram(b, target, optimize, graph.module, "consumer/src/main.zig"),
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    // Forward arguments so runtime consumers can name the provider path.
    run_consumer.addPassthruArgs();
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    const unit_tests = b.addTest(.{
        .name = "geographiclib-tests",
        .root_module = facadeProgram(b, target, optimize, graph.module, test_source),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    const test_step = b.step("test", "Run the facade tests and every API operation");
    test_step.dependOn(&run_tests.step);

    const exercise = addExercise(
        b,
        target,
        optimize,
        graph,
        runtime_loaded,
        "geographiclib-exercise",
    );
    b.getInstallStep().dependOn(&exercise.step);
    const run_exercise = b.addRunArtifact(exercise);
    run_exercise.has_side_effects = true;
    test_step.dependOn(&run_exercise.step);
    b.step("exercise", "Run every supported facade operation").dependOn(&run_exercise.step);

    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own geodtest and geodsigntest C programs",
    );
    for (upstream_tests) |spec| {
        const program = addUpstreamTest(b, target, optimize, graph, spec, spec.name);
        const run = b.addRunArtifact(program);
        run.addPassthruArgs();
        upstream_step.dependOn(&run.step);
    }

    const check_step = b.step(
        "check",
        "Compile the C core, the facade, the API exercise, the tests, the " ++
            "example and both upstream test programs for the six-target matrix " ++
            "without running any of them",
    );
    if (!target.query.isNative()) {
        addTargetCheck(b, check_step, target.query, optimize, linkage, runtime_loaded);
    } else {
        for (check_targets) |query| {
            addTargetCheck(b, check_step, query, optimize, linkage, runtime_loaded);
        }
    }

    std.debug.print(
        "geographiclib: {s}, delivered as a {s} library from [{s}], C99, header {s}\n",
        .{
            lib_name,
            @tagName(linkage),
            std.mem.join(b.allocator, ", ", &core_sources) catch @panic("OOM"),
            public_header,
        },
    );
    if (runtime_loaded) {
        std.debug.print(
            "geographiclib: runtime-loaded dispatch (-Druntime=true); nothing " ++
                "native is linked into the module, and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
}
