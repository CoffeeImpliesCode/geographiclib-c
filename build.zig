// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `LICENSE.txt` holds upstream's own MIT/X11 text,
// unmodified. Nothing in this file is upstream's, and nothing here changes an
// upstream byte.

//! Zig 0.16 build for the GeographicLib C geodesic library.
//!
//! The library is upstream's own C, byte for byte: `src/geodesic.c` and its
//! public header `src/geodesic.h`, which is the whole of upstream's
//! `add_library` list (`src/CMakeLists.txt:1`, `add_library (${LIBNAME}
//! geodesic.c geodesic.h)`). Nothing is downloaded, no CMake, Make or
//! configure script is executed, and every mode compiles everything from this
//! repository rather than linking an installed copy.
//!
//! Upstream reference: tag `v2.2`, `CMakeLists.txt:5-13`
//! (`PROJECT_VERSION_MAJOR 2`, `MINOR 2`, `PATCH 0`, `SUFFIX ""`) and
//! `src/geodesic.h:29,34,39` (`GEODESIC_VERSION_MAJOR 2`, `..._MINOR 2`,
//! `..._PATCH 0`). `build()` refuses to configure when `build.zig.zon .version`
//! and those components disagree, so the manifest, the pkg-config `Version:`
//! field and the upstream header cannot describe three different releases. The
//! pinned commit SHA belongs in `FORK-NOTES.md` and `UPSTREAM.md`, which the
//! fork's provenance owner writes; this script does not restate a SHA it cannot
//! read.
//!
//! Entry points
//! -----------
//!   zig build            install the delivered native library, the public
//!                        header `geodesic.h`, upstream's `LICENSE.txt`, the
//!                        licence and provenance records, upstream's doc inputs,
//!                        `lib/pkgconfig/libgeodc.pc`, and compile the example
//!   zig build test       run the facade tests for the selected target
//!                        (`-Dtarget`; the host when it is absent)
//!   zig build smoke      run the example program
//!   zig build consumer   run the module consumer inside this build graph
//!   zig build upstream-test
//!                        build and run upstream's own `geodtest` and
//!                        `geodsigntest` C programs
//!   zig build check      compile the C core, the facade, the API exercise,
//!                        the tests, the example and both upstream test
//!                        programs for the six-target matrix, running nothing
//!
//!   cross-test           the same `test` step, for the published 53-platform
//!                        Zig 0.16.0 Tier 1/2 table rather than the host alone.
//!                        `cross-test` discovers `cross-test.profile.sh` from
//!                        the package root, runs `zig build test -Dtarget=TARGET`
//!                        for each of them, and executes the binary where a
//!                        runner exists and records explicit `build_only`
//!                        coverage where one does not. `test` is what the
//!                        harness reaches for, and it builds the same graph and
//!                        the same test binary for whatever `-Dtarget` says:
//!                        nothing in `build()` narrows the graph to the host,
//!                        and the `check` matrix below is compile-only and is
//!                        not a substitute for it.
//!
//! Options
//! -------
//!   -Dtarget=<triple>    build for one target; `zig build check` then checks
//!                        that target only instead of the whole matrix.
//!   -Doptimize=<mode>    the caller's mode, passed to every graph below. No
//!                        target-specific or mode-specific branch exists in
//!                        this file: the facade, the C core and the upstream
//!                        programs are compiled the same way in Debug and
//!                        ReleaseSafe, so a bound that one mode checks and the
//!                        other does not cannot be written into them.
//!   -Dlinkage=static|dynamic
//!                        which native artifact this build delivers and
//!                        installs. The default is `static`, which is what
//!                        this build has always produced, so a caller that
//!                        passes nothing still gets `libgeodc.a`. Note that
//!                        this is a fork deviation from upstream's own default,
//!                        not upstream's default: `CMakeLists.txt:20` is
//!                        `option (BUILD_SHARED_LIBS "Build as a shared
//!                        library" ON)`.
//!   -Druntime=true|false
//!                        how the facade reaches the native entry points, not
//!                        which artifact this build delivers. The default is
//!                        `false`, the linked route this package has always
//!                        had. `true` resolves them through one
//!                        process-lifetime table that an explicit
//!                        `load(source)` fills, and links nothing native into
//!                        the module. The two options are orthogonal: under
//!                        `-Druntime=true` the library is still compiled and
//!                        still installed, so a caller may name this build's own
//!                        provider or another one.
//!
//! There is no system-library mode in this wave, by contract: the source pin
//! and the bounded contracts must stay identical in every mode, and a real
//! installed libgeodc with a matching header is not something this repository
//! can promise to any of the six matrix targets. So the rule is recorded as
//! NOT APPLICABLE rather than claimed as a satisfied gate, and nothing here
//! links `-lgeodc` as a system library. There is likewise no
//! `b.systemIntegrationOption` call: an unused option is a knob nobody has
//! checked, and a mode that cannot be entered is better named in this comment
//! than half-built behind a flag.
//!
//! Static and shared delivery
//! --------------------------
//! Nothing about the compiled C changes between the two deliveries. The same
//! one source, the same pinned C99 level, the same `-ffp-contract=off`, the same
//! header, the same translation, the same facade and the same tests. Three
//! things do change, and each is a delivery fact rather than a source fact:
//!
//!   * **Position independence.** `addCLibrary` states `.pic = true` on the
//!     library's own module when the delivered linkage is `dynamic`. A shared
//!     object needs it, and a static archive does not, so the option says which
//!     of the two this is instead of leaving it to the artifact kind.
//!   * **An export surface on ELF and macOS.** `-fvisibility=hidden` narrows
//!     the exported set to the declarations that `src/geodesic.h` decorates,
//!     which are exactly the 21 public entry points (`src/geodesic.h:145` to
//!     `:803`). `src/geodesic.h:68` already widens them:
//!     `__attribute__ ((visibility("default")))` under any `__GNUC__`
//!     compiler, clang included, and `src/geodesic.c:26` includes that header,
//!     so the definitions carry the same decoration as the declarations. No
//!     version script and no hand-written export list is involved: the header
//!     already says which symbols are public, and a second list beside it could
//!     only drift from it. The flag reaches the shared delivery only. It is
//!     inert for a static archive, which has no dynamic symbol table.
//!   * **An export surface on Windows.** `-fvisibility` does nothing for a
//!     COFF image, and `src/geodesic.h:64-72` reaches `__declspec(dllexport)`
//!     only under `_MSC_VER` together with `PROJ_MSVC_DLL_EXPORT`
//!     (`src/geodesic.h:65`), which is PROJ's own build switch: PROJ compiles
//!     this file into `proj.dll`, where that macro is how a C library with
//!     hundreds of exported names contributes a few without colliding with
//!     PROJ's. It is not this fork's switch and defining it would be claiming a
//!     PROJ integration as this library's ABI. So for a Windows shared build
//!     `addCLibrary` defines `GEOD_DLL` itself, as
//!     `__declspec(dllexport)`, on the compile line that produces the
//!     definitions. That is the header's own first branch
//!     (`src/geodesic.h:64`, `#if !defined(GEOD_DLL)`) doing what it was
//!     written to allow, with no PROJ macro and no `proj_symbol_rename.h`.
//!     `PROJ_RENAME_SYMBOLS` (`src/geodesic.h:74-76`) stays undefined, as
//!     upstream leaves it, so the exported names are upstream's own `geod_*`
//!     names and not a renamed variant.
//!
//! The *declaration* side is left alone on purpose, in both deliveries. The
//! header has no PROJ-free `__declspec(dllimport)` spelling, so defining
//! `GEOD_DLL` for a consumer would decorate its declarations `dllexport`
//! instead, which is the wrong direction; an undecorated declaration links
//! against a Windows import library correctly. On ELF and macOS the header's
//! own default is already `visibility("default")`, which is what a consumer of
//! a shared object wants. So `translate.addIncludePath` is the only thing the
//! translation is told, in both deliveries.
//!
//! There is no soname, because upstream declares none. `src/CMakeLists.txt:1`
//! sets no `VERSION` or `SOVERSION` property and no `install()` rule anywhere
//! in the tree (`HOWTO-RELEASE.txt` records `install` under "not supported:
//! install (distribution is via PROJ)"), so upstream's own shared build is
//! `libgeodc.so` with no versioned file name. This build matches it rather than
//! inventing an ABI number, which means the string a `.system` runtime load has
//! to name is `libgeodc.so`, and that is what this build installs.
//!
//! One target boundary belongs here rather than only in the code. WASI has no
//! dynamic linker (`std.Target.DynamicLinker.kind` is `.none` for it,
//! `lib/std/Target.zig:2345`), so it cannot carry a shared object at all, and
//! `zig build check` walks a WASI target. `-Dlinkage=dynamic` is therefore
//! **refused** for such a target and never answered with an archive: the
//! option names the artifact, so a build that cannot produce that artifact
//! says so instead of delivering a different one under the same name.
//!
//! Where the refusal lands depends on what was asked for. For the graph `zig
//! build` publishes it is a configure-time stop - `addGraph` refuses before a
//! single step is created for the target - naming the target, the platform
//! fact it resolved and the spelling that does work there. For a `zig build
//! check` cell it is a printed exclusion: the target's triple and the same
//! reason, with no cell built for it. Nothing is substituted either way, and a
//! printed exclusion is not a pass.
//!
//! The default is unaffected. `-Dlinkage=static` carries every target in the
//! matrix, WASI included, so the six-target `check` is complete for the
//! delivery this package has always produced.
//!
//! libm
//! ---
//! `mathLibrary` below is the one list of targets that need `-lm`, and it
//! serves four callers: the library's own module, the module a dependent
//! imports, the upstream C programs, and the `Libs.private:` line of the
//! installed pkg-config file. `src/geodesic.c` calls 34 `sin`, 31 `cos`, 29
//! `sqrt`, 22 `fabs`, 18 `atan2`, 10 `hypot`, 2 `remquo` and 1 `atan`, so libm
//! is a real dependency of the compiled core, not an assumption.
//!
//! Installed closure
//! -----------------
//! Upstream installs nothing, so every path below is this fork's design and
//! `zig build` owns all of it; packaging copies from this graph rather than
//! reproducing it.
//!
//!   * the delivered native library, through `b.installArtifact`:
//!     `lib/libgeodc.a`, `lib/libgeodc.so`, `lib/libgeodc.dylib`, or
//!     `bin/geodc.dll` with `lib/geodc.lib` beside it on Windows, by target
//!     and `-Dlinkage`. The header directory is `include/` in every case:
//!     `Step.InstallArtifact` defaults `h_dir` to `.header` for any library
//!     (`lib/std/Build/Step/InstallArtifact.zig:88-92`).
//!   * `include/geodesic.h`, through `installHeader`, which is upstream's
//!     whole public header set (`src/CMakeLists.txt:1`, and the
//!     `$<INSTALL_INTERFACE:include>` of its `target_include_directories`). It
//!     also puts that header on the include path of anything linking the
//!     installed artifact, so a C consumer needs nothing from this tree.
//!   * `LICENSE.txt` at the prefix root: upstream's own MIT/X11 text,
//!     unmodified. A private repository removes no licence obligation, so the
//!     text that covers the compiled archive ships next to it.
//!   * `share/licenses/geographiclib/` with this fork's own records:
//!     `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md` and `UPSTREAM.sha256`.
//!   * `share/doc/geographiclib/` with upstream's documentation inputs
//!     (`doc/geodesic-c.dox.in`, `doc/doxyfile.in`, `doc/HEADER.html`,
//!     `doc/FOOTER.html`) and this fork's preserved upstream README
//!     (`README.upstream.md`). `doc/.htaccess` is upstream's Apache
//!     configuration and is not installed because upstream's own packaging
//!     excludes it (`CMakeLists.txt:133`), and `doc/CMakeLists.txt` is
//!     upstream's build wiring for a Doxygen run this package never performs.
//!   * `lib/pkgconfig/libgeodc.pc`, generated here and relocatable: `prefix`
//!     is `${pcfiledir}/../..` rather than a configured absolute prefix, so
//!     the installed file is correct wherever `--prefix` pointed, including a
//!     Nix store path only known at build time.
//!
//! Upstream's three example programs (`tools/direct.c`, `tools/inverse.c`,
//! `tools/planimeter.c`, `CMakeLists.txt:72`) are not compiled and not
//! installed; `core_sources` below records that decision and why.
//!
//! Published routes
//! ----------------
//! This package publishes these routes, and one reachability it deliberately
//! does not publish:
//!
//!   * `dep.module("geographiclib")`: the Zig facade, `zig/root.zig`.  This is
//!     the one registered module.  It carries `link_libc`, libm where the
//!     target needs it, `src/` on its include path, the translated header as
//!     `c`, and the delivered library behind all of them, so a dependent that
//!     adds this module needs nothing further to call the facade or to reach
//!     `geodesic.h`.
//!   * `c` on that same module: the translated header itself, for a caller
//!     that needs a declaration the facade does not name.  It is deliberately
//!     *not* registered as a module of its own: `addModule("c")` would make
//!     `dep.module("c")` resolve and hand a dependent the same declarations
//!     without the library that satisfies them, which is a reachability a
//!     dependent cannot tell from support.
//!   * `dep.artifact("geodc")`: the compiled native library, named as upstream
//!     names it (`CMakeLists.txt:66`, `set (LIBNAME geodc)`), for a dependent
//!     that links the archive into its own C or Zig build.  It is not needed
//!     to use the facade and no consumer here asks for it.
//!   * the installed `include/geodesic.h`, the native library and
//!     `lib/pkgconfig/libgeodc.pc` under `zig-out/`, for a C consumer that
//!     includes the header and links the library.
//!
//! `README.zig.md` states the same routes for a reader deciding what to
//! import, and `zig/root.zig` states the Zig one on the module itself.

const std = @import("std");

/// The runtime-loading build half, owned by the API role.
///
/// `createModule` builds the generated dispatch that replaces
/// `translate.createModule()` under `-Druntime=true`; it makes the loader-core
/// module itself and re-exports `LoadSource`/`LoadError` from it.
/// `createCoreModule` builds that same core module for the *linked* branch,
/// where there is no dispatch to carry the types and the facade's `rt` import
/// is where they come from.
///
/// The two branches must not both call `createCoreModule`: `LoadSource` and
/// `LoadError` are this SDK's public types, so they have to be the *same* types
/// in one build. A second core instance would be a second, nominally distinct
/// `LoadSource`, and `geographiclib.load(source)` would hand the facade's type
/// to a function expecting the dispatch's. `addGraph` documents the branch and
/// is the only function that calls either of these.
const runtime_graph = @import("runtime/graph.zig");

/// `build.zig.zon` itself. `@import` of the manifest is how a build script reads
/// `.version` without a second copy of it; `spglib/build.zig:4` and
/// `blake3/build.zig:254` read it the same way.
const manifest = @import("build.zig.zon");

/// `build.zig.zon .version`, parsed. The parse is the loud part: a manifest
/// whose `.version` is not a semantic version fails to configure here rather
/// than being silently compared as something else.
const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// Upstream's own version, read out of `CMakeLists.txt:5-13` and
/// `src/geodesic.h:29,34,39`. It is the version of the C library, not a
/// version of this wrapper, so `build.zig.zon .version` carries the same three
/// components. The pkg-config `Version:` field spells it the way upstream's
/// own `PROJECT_VERSION` does, with two of them.
const upstream_version: std.SemanticVersion = .{ .major = 2, .minor = 2, .patch = 0 };

/// The name a dependent writes in its dependency map, and the name of the one
/// registered module. It is not upstream's library name: upstream calls the
/// library `geodc` (`CMakeLists.txt:66`) and the directory `GeographicLib-C`
/// (`CMakeLists.txt:2`).
const module_name = "geographiclib";

/// The compiled artifact's name, upstream's own `LIBNAME` (`CMakeLists.txt:66`).
/// The installed archive is `libgeodc.a` because of it, which is the name a C
/// consumer's `-lgeodc` needs, and it is the name the installed shared object
/// carries too.
const lib_name = "geodc";

/// The installed pkg-config file's base name. `pkg-config --libs libgeodc` is
/// how a C consumer of the install asks for the library by name rather than
/// spelling `-L` and `-l` itself, which is the whole point of installing one.
const pkg_config_name = "libgeodc";

/// The Zig facade: an allocation-free wrapper over the translated `geod_*`
/// calls. It re-exports the translated module as `c`.
const facade_source = "zig/root.zig";

/// The explicit exercise of every public facade method. `zig build check`
/// compiles it for every matrix target, which is what forces each facade body
/// to be analysed rather than merely declared.
const exercise_source = "zig/api_exercise.zig";

/// The one header this package translates. It is a fork-authored wrapper whose
/// whole job is to name the header; see the file for why it is a wrapper and
/// not a copy.
const translate_header = "zig/translate.h";

/// Test root. Every public facade method is called from here as well as from
/// `zig/api_exercise.zig`, which is what makes `zig build test` a run of the
/// facade rather than of an unreferenced archive.
const test_source = "tests.zig";

/// The deterministic example program that `zig build smoke` runs.
const example_source = "smoke.zig";

/// Language level for every C translation unit, pinned.
///
/// Upstream requires C99 with extensions off: `CMakeLists.txt:28-31`
/// (`# We require C99`, `set (CMAKE_C_STANDARD 99)`,
/// `set (CMAKE_C_STANDARD_REQUIRED ON)`, `set (CMAKE_C_EXTENSIONS OFF)`),
/// which is what `-std=c99` spells. It is pinned rather than inherited so a
/// change of clang's default cannot silently move it.
///
/// Native initialization uses `M_PI` if the target's math header defines it.
/// Otherwise it computes `atan2(0.0, -1.0)` (`src/geodesic.c:69-72`).
/// The explicit C99 level keeps the required dialect stable.
///
/// Warnings are not promoted to errors here, although upstream's default is
/// `-Werror` (`CMakeLists.txt:58-64`). That flag would make this build fail on
/// a compiler's new diagnostic rather than on a defect in the code, and the
/// driver runs the gates that decide whether the library is correct.
///
/// Disable contraction explicitly, as the fork's numerical contract requires.
/// Upstream leaves this choice to the compiler except for its Intel FP model
/// (`CMakeLists.txt:43-56`). This flag is a build-only deviation.
/// No fast-math or reassociation option is enabled.
const c_flags = [_][]const u8{ "-std=c99", "-ffp-contract=off" };

/// The one flag a shared delivery adds, on ELF and macOS.
///
/// See "Static and shared delivery" above for why it exists and why it is
/// upstream's own mechanism rather than a list written beside it. It is inert
/// on a COFF target, which is why `cUnitFlags` does not pass it there.
const c_flags_shared = [_][]const u8{"-fvisibility=hidden"};

/// `c_flags` and `c_flags_shared` concatenated for the shared build.
///
/// `++` is array concatenation and both operands are comptime constants, so
/// this is a compile-time value rather than a buffer built at configure time.
/// It exists so the language level is written once: a shared build that
/// quietly compiled `src/geodesic.c` at a different C standard would be a much
/// harder defect to see than a duplicated literal.
const c_flags_dynamic = c_flags ++ c_flags_shared;

/// The flags one C translation unit of this library is compiled with.
///
/// Every source in `core_sources` goes through this one function, so the shared
/// flag cannot reach one unit and miss another.
fn cUnitFlags(
    target: std.Build.ResolvedTarget,
    linkage: std.builtin.LinkMode,
) []const []const u8 {
    const shared = linkage == .dynamic and !exportsThroughDeclspec(target);
    return if (shared) &c_flags_dynamic else &c_flags;
}

/// The core library, upstream's own `add_library` list
/// (`src/CMakeLists.txt:1`). `geodesic.h` is not a source: it is installed as
/// a header below and reached through `src/` on the include path.
///
/// Files in this repository this build deliberately does not compile:
///
///   * `tools/direct.c`, `tools/inverse.c`, `tools/planimeter.c`: upstream's
///     three example programs (`CMakeLists.txt:72`,
///     `set (TOOLS direct inverse planimeter)`). They are programs, not library
///     sources, and `smoke.zig` is this package's own example. They are
///     upstream's material and stay in the tree byte for byte.
///   * `tools/CMakeLists.txt`, `tests/CMakeLists.txt`, `src/CMakeLists.txt`,
///     `CMakeLists.txt`, `proj-example/`, `doc/`, `distrib-C/`: upstream's own
///     build system, documentation and a distribution placeholder. Nothing
///     here reads, writes or executes any of it, and no source in this build
///     is conditioned on it having run.
const core_sources = [_][]const u8{
    "src/geodesic.c",
};

/// Upstream's public header, the one header `src/CMakeLists.txt` names and the
/// one `zig/translate.h` includes.
const public_header = "src/geodesic.h";

/// The directory that holds both, and the include path every C compilation
/// below is given.
const source_dir = "src";

/// This fork's own licence and provenance records, installed under
/// `share/licenses/geographiclib/`.
///
/// `LICENSE.txt` is not in this list because it is upstream's and already has
/// its own established place at the prefix root; the four below are the records
/// that describe what this fork did to it. `UPSTREAM.sha256` travels with them
/// because the digests are what make the installed claim checkable.
const licence_records = [_][]const u8{
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
    "UPSTREAM.sha256",
};

/// The documentation this install carries, under `share/doc/geographiclib/`.
///
/// The first four files are upstream's Doxygen inputs and the page furniture
/// for the site they generate, unmodified; `README.upstream.md` is this fork's
/// preserved copy of upstream's own front page. `doc/.htaccess` and
/// `doc/CMakeLists.txt` are deliberately absent; the header comment says why.
const doc_records = [_][]const u8{
    "README.upstream.md",
    "doc/geodesic-c.dox.in",
    "doc/doxyfile.in",
    "doc/HEADER.html",
    "doc/FOOTER.html",
};

/// Upstream's own two C test programs (`tests/CMakeLists.txt:1`,
/// `set (TESTS geodtest geodsigntest)`).
///
/// Both are `int main(void)` programs with their expectations compiled in -
/// `tests/geodtest.c:1167-1216` runs 60 named cases and returns the number of
/// failures, and `tests/geodsigntest.c:87-374` checks signed zero and +/-180,
/// printing the number of failures and returning 1 if there was one - so
/// `upstream-test` needs no data files and no stdin, which is why this step is
/// self-contained and what the contract calls native upstream validation.
///
/// Both are linked the same way in both deliveries: they are programs for the
/// delivered native library and do not touch the facade, so `-Druntime` changes
/// nothing about them. Under a shared delivery `geodtest` binds the shared
/// object, which is the upstream way to run it against that delivery.
const UpstreamTest = struct {
    /// The program's name, which is also its step name and its artifact name.
    name: []const u8,
    /// The upstream source, unmodified.
    source: []const u8,
    /// Whether this program links `libgeodc` or compiles the library's
    /// sources into itself instead.
    ///
    /// It is not a preference. `tests/geodsigntest.c:16` is
    /// `#include "geodesic.c"`, so it reaches the file-static `AngRound`,
    /// `AngNormalize`, `AngDiff`, `sincosdx`, `atan2dx` and `sumx` that no
    /// exported function exposes; `tests/CMakeLists.txt:14-15` says so and
    /// links it against `${MATH_LIBS}` alone. Linking the archive as well
    /// would give that program a second definition of every symbol in it.
    /// `geodtest` is the other way round: it uses only the public API and
    /// `tests/CMakeLists.txt:8-9` links it against `${LIBNAME}`.
    links_library: bool,
};

const upstream_tests = [_]UpstreamTest{
    .{ .name = "geodtest", .source = "tests/geodtest.c", .links_library = true },
    .{ .name = "geodsigntest", .source = "tests/geodsigntest.c", .links_library = false },
};

/// The cross-compilation matrix `check` walks when no target is named. The
/// order is the one this workspace uses everywhere; nothing is skipped, and
/// nothing here is pre-judged: if a target cannot be satisfied on the machine
/// running the gate, that is for the gate to report.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// One target's library and facade.
const Graph = struct {
    /// The compiled native library, in whichever linkage this target can carry.
    c_lib: *std.Build.Step.Compile,
    /// The facade module, with `c` bound to the translated header for the
    /// library this graph compiled.
    module: *std.Build.Module,
    /// The translated header, shared by the facade and by the API exercise so
    /// both describe exactly one C ABI in a graph. Under `-Druntime` this is
    /// the generated dispatch instead, which is what keeps the exercise honest
    /// about the route it is exercising.
    c_module: *std.Build.Module,
    /// The one loader-core module instance this graph built, or null when
    /// `-Druntime` is on and the generated dispatch owns the instance instead.
    ///
    /// It is a field rather than a second `createCoreModule` call in
    /// `addExercise` because there must be exactly one: `createModule` builds
    /// the core internally and re-exports `LoadSource`/`LoadError` from it, so
    /// a second instance would be a second, nominally distinct `LoadSource` and
    /// a `load(source)` written against one would be handed to the other. The
    /// exercise gets this same instance, never a new one.
    core_module: ?*std.Build.Module,
};

/// The name a compiled artifact carries in this build graph.
///
/// The published graph installs `libgeodc.a` or `libgeodc.so`, the name a C
/// consumer's `-lgeodc` needs. A check graph installs nothing, so its
/// artifacts carry the target triple instead: six targets share one build
/// graph, and six steps all called "geodc" make `--summary all` impossible to
/// read.
fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// The target's maths library, when it is a library of its own.
///
/// This is the one list of targets that need `-lm`. `src/geodesic.c` includes
/// `<math.h>` (`src/geodesic.c:27`) and builds its whole series evaluation on
/// `DBL_EPSILON` and `DBL_MIN` (`src/geodesic.c:28`, `<float.h>`), and it
/// calls 34 `sin`, 31 `cos`, 29 `sqrt`, 22 `fabs`, 18 `atan2`, 10 `hypot`, 2
/// `remquo` and 1 `atan`, so this is a real dependency of the compiled core
/// and not an assumption.
///
/// It is separate on glibc and the BSDs and part of libc on macOS, Windows and
/// wasi, which is why the list is a list.
fn mathLibrary(target: std.Build.ResolvedTarget) ?[]const u8 {
    return switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => "m",
        else => null,
    };
}

/// Links the target's maths library where the target needs it.
///
/// The link goes on the module a dependent imports, not only on the archive:
/// a `linkSystemLibrary` on a static library stays inside that library's own
/// link line and never reaches the executable that links the archive, which
/// would leave every dependent to discover the undefined `sqrt` on its own.
/// This is the rule `inchi/build.zig:414-430` records for the same reason.
fn linkMath(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (mathLibrary(target)) |lib| module.linkSystemLibrary(lib, .{});
}

/// Whether this target's exported symbols come from `__declspec` rather than
/// from an ELF or Mach-O visibility attribute.
///
/// A COFF image has no dynamic symbol table for `-fvisibility` to narrow and
/// no default-visibility concept to widen, so on those targets the export
/// surface has to be written into the declarations with `__declspec`.
fn exportsThroughDeclspec(target: std.Build.ResolvedTarget) bool {
    return switch (target.result.os.tag) {
        .windows, .uefi => true,
        else => false,
    };
}

/// Whether this target can carry the linkage that was requested.
///
/// It gates a refusal and nothing else. There is deliberately no second return
/// value that would let a caller substitute another linkage: the resolver that
/// used to stand here silently turned a requested shared object into a static
/// archive on a target with no dynamic linker, and a caller who passed
/// `-Dlinkage=dynamic` got back a package whose own `libgeodc.pc`, installed
/// file name and loadable artifact were not the ones that option names. The
/// option names the artifact, and this build either produces that artifact or
/// says it cannot.
///
/// Windows loads PE/COFF DLLs without an interpreter path. Other shared
/// targets need a dynamic linker. Static archives need neither.
fn targetCanCarry(
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) bool {
    return requested == .static or target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// The exact reason a linkage cannot be honoured for `target`.
///
/// One message, so the refusal a caller reads for one target is the refusal
/// they would read for any other, and so `requireSupportedLinkage` and
/// `addTargetCheck` cannot describe the same boundary two different ways. It
/// names the platform fact it resolved from `std.Target.DynamicLinker.kind`, the
/// spelling that does work there, and the fact that this build does not answer
/// with something else.
fn unsupportedLinkageReason(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    return b.fmt(
        "geographiclib: -Dlinkage=dynamic is unsupported for {s}: dynamic linker kind is {s}. " ++
            "No static archive is substituted. Use -Dlinkage=static for this target.",
        .{ @tagName(target.result.os.tag), @tagName(std.Target.DynamicLinker.kind(target.result.os.tag)) },
    );
}

/// Refuses a linkage this target cannot carry, naming the reason.
///
/// This is a configure-time refusal and it happens before any step is created
/// for the target, so nothing is half-built and nothing is reported as a
/// result. `addGraph` calls it for the target it is about to build, which is
/// the caller's own `-Dtarget` for the published graph; `addTargetCheck` has
/// already filtered out the cells this function would refuse, and says so by
/// name.
///
/// `-Dlinkage=static` - the default - remains a full configuration for every
/// target in the matrix, WASI included. This is about the shared variant of a
/// target that cannot host one, not about the target being unsupported.
fn requireSupportedLinkage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) void {
    if (!targetCanCarry(target, requested)) {
        @panic(unsupportedLinkageReason(b, target));
    }
}

/// Compiles the core library for one target, in the requested delivery.
///
/// One source, at the pinned C level, with `src/` on the include path for its
/// own `#include "geodesic.h"` (`src/geodesic.c:26`), and the export surface the
/// requested linkage needs. `src/geodesic.h:64-72` is the only configuration
/// that header has, so nothing else is defined here: `src/geodesic.c:38` picks
/// the series order itself (`GEOGRAPHICLIB_GEODESIC_ORDER 6`), and there is no
/// generated header, so there is nothing to generate per target and no way for a
/// host's configuration to reach a cross target's compile line.
fn addCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    name: []const u8,
) *std.Build.Step.Compile {
    // `linkage` is what the caller asked for, verbatim. There is no resolver
    // in front of it: `addGraph` has already refused a linkage this target
    // cannot carry, so by the time a step is created the requested artifact is
    // one this platform can produce.
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // Upstream sets no `VERSION` and no `SOVERSION` property
        // (`src/CMakeLists.txt:1`, and no `set_target_properties` anywhere in
        // the tree), so there is no soname to record and no versioned file name
        // to install. A number invented here would be an ABI claim nobody
        // upstream made.
        .version = null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // libc, because `src/geodesic.c:27-28` includes <math.h> and
            // <float.h> and the whole algorithm is built on DBL_EPSILON and
            // DBL_MIN.
            .link_libc = true,
            // Stated rather than implied. A shared library is position
            // independent whether or not this says so; a static archive is
            // neither this nor anything else, and the flag is what says which
            // of the two this build is delivering.
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;
    c_mod.addIncludePath(b.path(source_dir));

    // The Windows half of the export surface, and only the Windows half. See
    // "Static and shared delivery" above: `__declspec(dllexport)` is reached by
    // upstream's own header only under `_MSC_VER` together with
    // `PROJ_MSVC_DLL_EXPORT`, which is PROJ's switch for embedding this file
    // in `proj.dll`. Defining `GEOD_DLL` here takes the header's first branch
    // (`src/geodesic.h:64`, `#if !defined(GEOD_DLL)`) with no PROJ macro
    // defined and no `proj_symbol_rename.h` included, so the exported names
    // are upstream's own `geod_*` names.
    //
    // It is on this compile line and not on the translation's, because a
    // consumer of a shared object wants the opposite direction and this header
    // has no spelling for it: see the header comment.
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

    // Installing the header also puts it on the include path of anything that
    // links this artifact, so a C consumer needs nothing from this tree to
    // call it. `geodesic.h` is the only public header upstream has
    // (`src/CMakeLists.txt:1`, and its `include/` install interface).
    c_lib.installHeader(b.path(public_header), "geodesic.h");

    return c_lib;
}

/// Builds one target's library and facade.
///
/// `public` chooses between the package module set, which is what a dependent
/// reaches through `dep.module("geographiclib")`, and a private module. A
/// cross-target check needs the private form: modules are registered by name
/// against the whole build, so registering `geographiclib` once per matrix
/// target would leave only the last of them reachable and silently stop
/// checking the rest. The translated header is imported rather than registered
/// in both forms; the published routes are named above.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    public: bool,
) Graph {
    // The one place a requested linkage is checked against what this target can
    // carry, and it is checked before a single step exists for the target. A
    // caller who asked for a shared object on a platform that has no dynamic
    // linker stops here, with the reason, rather than receiving an archive
    // under the option's own name.
    requireSupportedLinkage(b, target, linkage);

    const c_lib = addCLibrary(b, target, optimize, linkage, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // `zig/translate.h` includes `<geodesic.h>`, and this is the only header
    // search path the translation has. Without it the translation would
    // silently bind to whatever `geodesic.h` happens to be installed on the
    // build machine and describe that library's declarations rather than the
    // ones this graph compiles (`WISDOM.md` W14).
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

    // Where the runtime-loading seam is
    // ---------------------------------
    // `runtime/graph.zig`, which the API role owns, exposes
    //
    //     pub fn createModule(
    //         b: *std.Build,
    //         translate: *std.Build.Step.TranslateC,
    //         target: std.Build.ResolvedTarget,
    //         optimize: std.builtin.OptimizeMode,
    //     ) *std.Build.Module
    //
    // and `-Druntime=true` substitutes that one call for
    // `translate.createModule()`. It takes the `TranslateC` step this function
    // has already built, so the generated dispatch keeps the exact translated
    // type and constant namespace rather than compiling a second copy of the
    // native extern structs and casting between two nominally distinct Zig
    // modules.
    //
    // `-Dlinkage` is orthogonal and keeps meaning what it means: it selects
    // which artifact this build *delivers* and installs, never which one the
    // module dispatches through. The library above was built and will be
    // installed in both branches.
    //
    // The `rt` import is for the linked branch only, and the reason is the
    // nominal type rather than the code. `runtime_graph.createModule` creates the one
    // core-module instance the generated dispatch uses and re-exports
    // `LoadSource`/`LoadError` from it; a second instance created here for the
    // facade would be a *different* `LoadSource`, and
    // `geographiclib.load(source)` would be handing the facade's type to a
    // function expecting the dispatch's. One instance per build, no more. In a
    // linked build there is no dispatch, so the facade's own `rt` import is
    // where those two public types come from, and `zig/root.zig` picks between
    // the two with a comptime branch, so the module a configuration does not
    // need is never resolved and never compiled.
    const c_module = if (runtime_loaded) blk: {
        // A loaded provider must arrive through the platform loader, so the
        // link line names nothing. Linking the archive or `-lm` as well would
        // make the linker resolve the same symbols itself and the runtime
        // route would quietly be a linked one.
        break :blk runtime_graph.createModule(b, translate, target, optimize);
    } else blk: {
        // The translated header is imported, never registered. `addModule("c")`
        // would make `dep.module("c")` resolve and hand a dependent the same
        // declarations without the library that satisfies them; `c` on the
        // facade is the supported way in and carries the facade's own linkage.
        break :blk translate.createModule();
    };
    module.addImport("c", c_module);

    // One loader-core instance, created here and handed to every module that
    // needs it in this configuration: the facade below, and the API exercise
    // through `Graph.core_module`. `addGraph` is the only place that calls
    // `createCoreModule`, for the reason above - two instances would be two
    // nominally distinct `LoadSource` types.
    const core_module: ?*std.Build.Module = if (runtime_loaded)
        null
    else
        runtime_graph.createCoreModule(b, target, optimize);

    if (core_module) |rt| {
        module.addImport("rt", rt);
        module.linkLibrary(c_lib);
        // The same libm requirement as the archive's own module, on the module
        // a dependent actually imports.
        linkMath(module, target);
    }

    // `src/` is on the facade's include path in both branches, and this is not
    // a link decision: a dependent that compiles its own C against this package
    // must find the same `geodesic.h` the core was compiled with, whether or
    // not this configuration links anything native.
    module.addIncludePath(b.path(source_dir));

    return .{
        .c_lib = c_lib,
        .module = module,
        .c_module = c_module,
        .core_module = core_module,
    };
}

/// A Zig program or test root that imports the published facade module.
///
/// `link_libc` is stated on every one of them even though the facade carries
/// it: a dependent states its own, and this build should fail here if the
/// facade ever stopped bringing libc along.
fn facadeProgram(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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

/// The explicit API exercise, compiled as its own program.
///
/// It is the root of an executable rather than a test file for one reason: a
/// Zig function body is analysed only when something calls it, and a `pub fn`
/// nobody references is not analysed however prominent it is. As the root of an
/// executable its `main` is the entry point, so every call `main` makes is
/// compiled - which is what makes this a check of the facade rather than of an
/// archive nobody used.
///
/// It imports `c` from the same translation the facade imports, and does not
/// import the facade module: the facade already contains this file, so a
/// module import from here would close a loop between the two. Under
/// `-Druntime` that `c` is the generated dispatch, so the exercise compiles the
/// route the facade actually calls, and it links nothing: the provider a run
/// would need is named by the API role's own loader tests.
fn addExercise(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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
    // The same core-module instance the facade's own `rt` import names, and for
    // the same reason the facade needs it: this module's root includes
    // `zig/root.zig`, and an import inside that file resolves against *this*
    // module's table, not the facade's. Without this the linked branch's
    // `rt.LoadSource` - the taken branch of the facade's comptime `if` - is a
    // missing import. Under `-Druntime` the dispatch carries the public types
    // itself and `rt` is never resolved, so there is nothing to bind and
    // `core_module` is null.
    if (graph.core_module) |rt| mod.addImport("rt", rt);
    if (!runtime_loaded) {
        mod.linkLibrary(graph.c_lib);
        linkMath(mod, target);
    }
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Builds one upstream C test program, unmodified, for one target.
///
/// Both programs get `src/` on the include path: `geodtest.c` includes
/// `"geodesic.h"` (`tests/geodtest.c:12`) and `geodsigntest.c` includes
/// `"geodesic.c"` (`tests/geodsigntest.c:16`), which in turn includes the
/// header. That is the include directory `tests/CMakeLists.txt:17` gives the
/// second program and the one this build gives both.
fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    spec: UpstreamTest,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // libc, because both programs include <stdio.h>, <math.h> and
        // <float.h> and print through stdio.
        .link_libc = true,
    });
    mod.addIncludePath(b.path(source_dir));
    mod.addCSourceFile(.{
        .file = b.path(spec.source),
        // `c_flags` and not `cUnitFlags`: these two are executables, and
        // `-fvisibility=hidden` narrows a dynamic symbol table, which an
        // executable does not have. `geodtest` links the delivered library -
        // the shared object under a shared delivery - and `geodsigntest`
        // compiles `src/geodesic.c` into itself (`tests/geodsigntest.c:16`);
        // neither is affected by which of the two the library is delivered as.
        .flags = &c_flags,
    });
    linkMath(mod, target);
    if (spec.links_library) {
        mod.linkLibrary(graph.c_lib);
    }
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Writes `lib/pkgconfig/libgeodc.pc` and installs it.
///
/// Upstream ships no pkg-config file: `src/CMakeLists.txt:1` names one library
/// and there is no `install()` rule anywhere in the tree
/// (`HOWTO-RELEASE.txt`, "not supported: install"), so there is no upstream
/// field for this file to copy. It is written from the facts the build already
/// holds rather than invented, and three of its fields are decided here:
///
///   * `prefix` is `${pcfiledir}/../..`. This graph does not know where
///     `--prefix` will point when it writes the file, so it cannot write an
///     absolute prefix. pkg-config resolves `${pcfiledir}` against the `.pc`
///     file it found, which makes the installed file correct wherever the
///     prefix landed, including a Nix store path known only at build time.
///   * `Version:` is upstream's own two-component spelling,
///     `CMakeLists.txt:8` `PROJECT_VERSION "2.2"`. `build()` has already
///     checked the three components against `build.zig.zon .version`, so the
///     manifest, this field and `src/geodesic.h:29,34,39` cannot name three
///     different releases.
///   * `Libs.private:` carries `-lm` only where `mathLibrary` says the target
///     needs it, which is the one honest form of that line: libm is a
///     dependency of the static archive and of nothing else.
///
/// `Libs:` is the same in both deliveries, because the library *name* does not
/// change with linkage: a C consumer asks for `-lgeodc` and the linker resolves
/// it to `libgeodc.a` or, through `libgeodc.so`, to the shared object.
///
/// `Cflags:` carries no `-DGEOD_DLL`, and that absence is deliberate rather
/// than an omission. Upstream has no pkg-config file to copy a `Cflags` line
/// from, and `src/geodesic.h:64-72` reaches `__declspec(dllimport)` nowhere:
/// its only `__declspec` branch is `dllexport`, and only under PROJ's
/// `PROJ_MSVC_DLL_EXPORT`. Passing that switch to a consumer of this library
/// would describe PROJ's embedding rather than this one. What a Windows
/// consumer needs is the import library, which the linker finds through `-lgeodc`.
fn addPkgConfig(b: *std.Build, target: std.Build.ResolvedTarget) void {
    // `Libs.private:` is a whole line or no line at all: pkg-config reads
    // `--static` output as `Libs` plus `Libs.private`, and a `-lm` appended to
    // `Libs` would instead be handed to every consumer whether or not it links
    // this library statically. libm is a dependency of the static archive and
    // of nothing else, because the shared object records it as its own
    // `DT_NEEDED`.
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

/// Installs this fork's licence and provenance records, and upstream's
/// documentation inputs.
///
/// `share/licenses/geographiclib` and `share/doc/geographiclib` are the two
/// directories `package.nix`'s `$out` carries, because that derivation runs
/// this graph with `--prefix $out` and copies nothing of its own: there is no
/// second writer for either path, and no overwrite to reconcile.
///
/// Both directory names are `module_name`, which is a decision rather than a
/// convenience: they are named after the **published module**,
/// `geographiclib`, and not after this repository's directory
/// (`geographiclib-c`), the manifest's `.name` (`.geographiclib_c`), the
/// artifact (`geodc`) or the derivation's `pname` (`geographiclib-c`). One
/// spelling for the installed tree is what makes a hand-written
/// `zig build --prefix <p> install` and a Nix `$out` the same directory tree,
/// and it is the spelling `NOTICE.md` and `README.md` state for both layers.
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

/// Compiles the full graph, the exercise, the tests, the example and both
/// upstream programs for one matrix target, and attaches all of them to
/// `step`.
///
/// Nothing is run here, so every result this produces is compile evidence and
/// not a claim that a cross-built binary executed. That is why the upstream
/// programs appear here as compiles rather than as runs: `upstream-test` runs
/// them natively, and a successful foreign compile is `build_only`.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // The triple names the cross artifacts. Six targets in one build graph
    // otherwise produce six steps called "geodc", which makes `--summary all`
    // useless for telling them apart.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // A cell whose target cannot carry the requested linkage is left out of
    // this run, by name and with the reason, rather than checked against a
    // different artifact than the one that was asked for. Under the default
    // static linkage `targetCanCarry` is true for every target and all six are
    // checked, so the six-target matrix is complete for the default graph and
    // nothing is lost by the rule. Under `-Dlinkage=dynamic` a target with no
    // dynamic linker is not covered, and the line below says so: a printed
    // exclusion is not a pass, and this build will not produce a static archive
    // to stand in for the shared object the run asked for.
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
    // One version, or the build refuses to configure. The parse above already
    // refuses a manifest that is not a semantic version; this refuses one that
    // is a different release from upstream's header.
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version does not match upstream's version read from " ++
            "CMakeLists.txt:5-13 and src/geodesic.h:29,34,39");
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The one delivery option. The default is what this build has always
    // produced, so an existing caller that passes nothing is unaffected.
    const linkage = b.option(
        std.builtin.LinkMode,
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

    // The dispatch option, orthogonal to the delivery above. The default is the
    // linked route this package has always had.
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

    // The installed closure, in one place. The library and its public header
    // (through `installHeader` in `addCLibrary`), upstream's own MIT/X11 text
    // at the prefix root, this fork's licence and provenance records, upstream's
    // documentation inputs, and the relocatable pkg-config file for the
    // delivery this build actually produced.
    b.installArtifact(graph.c_lib);
    b.installFile("LICENSE.txt", "LICENSE.txt");
    installRecords(b);
    addPkgConfig(b, target);

    // `zig build` also compiles the example. The example is the cheapest thing
    // that proves the facade, the translated header and the C library agree on
    // types, symbols and link-time dependencies - in particular that libm
    // reached the dependent's link line. It is compiled, not installed: it is
    // a proof, not a deliverable.
    const example = b.addExecutable(.{
        .name = "geographiclib-smoke",
        .root_module = facadeProgram(b, target, optimize, graph.module, example_source),
    });
    b.getInstallStep().dependOn(&example.step);

    // A run artifact already depends on building the executable, which
    // depends on compiling the C and linking the facade. `zig build smoke`
    // deliberately does not depend on the install step: installing is
    // `zig build`'s job and conflating the two would make a smoke run depend
    // on the install layout.
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    if (b.args) |args| run_example.addArgs(args);
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    const consumer = b.addExecutable(.{
        .name = "geographiclib-consumer",
        .root_module = facadeProgram(b, target, optimize, graph.module, "consumer/src/main.zig"),
    });
    const run_consumer = b.addRunArtifact(consumer);
    run_consumer.has_side_effects = true;
    // Forwarded like the example's, and for the same reason: under `-Druntime`
    // this program has no library on its link line and is given the provider it
    // must load by an explicit argument, which only reaches it through `b.args`.
    // `zig build consumer -- --provider <path>` is therefore a real command and
    // not a silent no-op.
    if (b.args) |args| run_consumer.addArgs(args);
    b.step("consumer", "Run the module consumer").dependOn(&run_consumer.step);

    // The test root is `tests.zig`, which names the test blocks; a root that
    // only re-exported them would discover no tests and still exit zero.
    // `addRunArtifact` is used rather than a plain compile so that this is a
    // real runnable test step for whatever `-Dtarget` names: a foreign target
    // is left to whichever executor the cross-test harness detects, and this
    // build does not decide that.
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

    // Upstream's own C test programs, built and run. `geodtest` returns the
    // number of failures from `main` (`tests/geodtest.c:1215`) and
    // `geodsigntest` returns 1 after printing the count
    // (`tests/geodsigntest.c:370-372`), so a non-zero exit is upstream's own
    // report and needs no wrapper here to interpret it.
    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own geodtest and geodsigntest C programs",
    );
    for (upstream_tests) |spec| {
        const program = addUpstreamTest(b, target, optimize, graph, spec, spec.name);
        const run = b.addRunArtifact(program);
        if (b.args) |args| run.addArgs(args);
        upstream_step.dependOn(&run.step);
    }

    // The cross target gate. Compiling the exercise, the tests, the example and
    // both upstream programs for each target is what makes this a check of the
    // facade rather than of an unreferenced archive, and `addTargetCheck`
    // says why. Nothing runs here.
    //
    // The independent exercise calls every supported body; `test` executes it.
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

    // Configure-time lines, not gate results: what this build graph compiled,
    // in which delivery, and where its include path points. They are printed
    // whether or not any step runs, and they say nothing about whether the
    // results were executed.
    std.debug.print(
        "geographiclib: {s}, delivered as a {s} library from [{s}], C99, header {s}\n",
        .{
            lib_name,
            @tagName(linkage),
            std.mem.join(b.allocator, ", ", &core_sources) catch @panic("OOM"),
            public_header,
        },
    );
    // No substitution notice, because there is no substitution: a requested
    // `dynamic` this target cannot carry was refused by `addGraph` above,
    // before this line was reached.
    if (runtime_loaded) {
        std.debug.print(
            "geographiclib: runtime-loaded dispatch (-Druntime=true); nothing " ++
                "native is linked into the module, and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
}