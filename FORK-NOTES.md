# Fork notes

## Source changes

- `.gitignore`: retains upstream rules and adds Zig cache and output paths.
- `README.md`: provides the fork's package guide; `README.upstream.md` preserves upstream's README.
- `zig/translate.h`: exposes `src/geodesic.h` to Zig's C translator.
- `zig/root.zig`: adds a typed Zig facade over translated C declarations and preserves distinct direct/general and inverse/general calls.
- `runtime/graph.zig`: adds runtime-loaded dispatch through one process-lifetime function table.
- `zig/api_exercise.zig`: adds a standalone program that exercises facade methods and error paths.
- `tests.zig`: adds Zig tests over the upstream geodesic cases and typed facade.
- `smoke.zig`: adds a small executable example for the facade.
- `testdata/geodtest-cases.txt`: transcribes the 20 upstream `geodtest.c` cases for the Zig tests.
- The upstream C implementation, public header, test programs, tools, documentation, and licence files remain unchanged.

## Build graph changes

- `build.zig` replaces upstream's CMake graph; it builds `src/geodesic.c` and translates the public header through `zig/translate.h`.
- C compilation uses C99 and `-ffp-contract=off`; warnings are not errors.
- The default artifact is static, unlike upstream's shared default. Dynamic linkage is an explicit option.
- Runtime-loaded dispatch is independent of artifact linkage; the native artifact is still built and installed.
- `geodsigntest` compiles its own `geodesic.c` because the test includes that source file.
- `check` compiles the library, facade, exercise, smoke program, Zig tests, and both upstream test programs for its target matrix. It does not run them.
- The graph adds `test`, `smoke`, `exercise`, `consumer`, and `upstream-test` steps.
- Installation includes the native artifact, public header, licence and provenance records, upstream documentation, and generated relocatable `libgeodc.pc`. Upstream has no install target or pkg-config file.
- There is no system-library mode. Linking system PROJ would use PROJ's copy of the C source, not this package's source.

## Runtime and platform boundaries

- The typed facade calls `prepare()` before constructors reach upstream's unsynchronised first-call initialization. Raw C consumers cannot call this Zig function; they must make the first `geod_init` call before starting worker threads or serialize that call.
- The facade preserves upstream input behavior: longitude is not range-checked, and latitude outside `[-90, 90]` produces `NaN`.
- `libm` is linked on Linux, FreeBSD, NetBSD, OpenBSD, DragonFly, and Illumos. macOS, Windows, and `wasm32-wasi` provide these functions through libc.
- Static linkage is available on the declared targets. Dynamic linkage requires a dynamic linker, except Windows uses its PE/COFF loader; WASI has no dynamic linker.
- Windows shared builds use `GEOD_DLL` exports. Other shared builds hide symbols not marked public in `geodesic.h`.
- The six `check` targets are compile targets, not a platform-support list. The package makes no broader platform-support claim; 32-bit x86 runtime behavior under QEMU depends on emulated x87 `FPREM1` status handling.
