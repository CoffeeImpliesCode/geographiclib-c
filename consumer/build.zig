// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `../LICENSE.txt` holds upstream's own MIT/X11 text.

//! A package that consumes `geographiclib` from outside.
//!
//! This exists to prove one thing: that a dependent needs only
//! `dep.module("geographiclib")` and gets a working, correctly linked library.
//! If the facade module stopped carrying the C library, stopped carrying libm,
//! or stopped putting `src/` on its include path, or if the translated header
//! stopped matching the compiled `src/geodesic.c`, this would stop building or
//! stop producing the distances below, and nothing inside the library would
//! notice.
//!
//! Run it with `zig build run`. It exits non-zero if any result disagrees with
//! the independent expectation it states, so it is a check and not a demo.
//!
//! It deliberately does not ask for `dep.artifact("geodc")`. A dependent that
//! had to link the archive as well as import the module would prove nothing
//! about the module being self-contained.
//!
//! `-Dlinkage` and `-Druntime`
//! --------------------------
//! Both are forwarded to the dependency under the names the library declares
//! them, so the same question can be asked of every delivery and of both
//! dispatch routes:
//!
//!     zig build run                            the default: static, linked
//!     zig build run -Dlinkage=dynamic          the shared object, linked
//!     zig build run -Druntime=true             nothing linked; the program
//!                                              names a provider with an
//!                                              explicit load, and its own
//!                                              initialization says which
//!
//! They are forwarded unconditionally rather than only when passed, so this
//! file and the library cannot disagree about their defaults: this build
//! states `static` and `false`, which is exactly what `build.zig` defaults to.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The library's own defaults, restated. `build.zig` refuses to configure
    // when the manifest version and the compiled upstream version disagree, so
    // a value here cannot drift into describing a different release.
    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Forwarded to the library: which native artifact it delivers. The " ++
            "default is the library's own default, a static archive.",
    ) orelse .static;
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Forwarded to the library: resolve the native entry points at run time " ++
            "instead of linking them. The default is the library's own default, " ++
            "the linked route.",
    ) orelse false;

    const dep = b.dependency("geographiclib_c", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

    // No `link_libc` here on purpose. The C requirement belongs to the library
    // module, which carries it; a dependent states its own, and this program
    // needs nothing beyond what the library already brings. Adding it here
    // would hide a library that forgot to declare it.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("geographiclib", dep.module("geographiclib"));

    const exe = b.addExecutable(.{
        .name = "geographiclib-c-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}