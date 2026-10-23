# geographiclib-c

Builds upstream GeographicLib-C v2.2 as a Zig 0.16 package. It provides the native C library and a typed Zig facade for direct and inverse geodesics on an ellipsoid of revolution.

## Source deviations from upstream

- `src/geodesic.c`, `src/geodesic.h`, upstream tests, tools, documentation and licence files are unchanged.
- `.gitignore` retains upstream's rules and adds this package's Zig cache entries.
- `README.upstream.md` preserves upstream's README. This file is the fork's package README.
- `testdata/geodtest-cases.txt` transcribes upstream's 20-case corpus; `testdata/LICENSE.md` records its provenance and licence.

## Build deviations

- The Zig build graph replaces upstream's CMake build. It compiles `src/geodesic.c` and translates the public C header.
- C translation units use `-std=c99 -ffp-contract=off`. Upstream requires C99 but does not set a floating-point contraction option.
- Warnings are not errors; upstream enables `-Werror` by default.
- Upstream defaults to a shared library. This package defaults to a static archive; `-Dlinkage=dynamic` selects a shared library.
- `geodsigntest` includes `geodesic.c`, so it is compiled from the test source without linking the library.
- The install step includes `LICENSE.txt` and `lib/pkgconfig/libgeodc.pc`; upstream has no install target.

## Support matrix

This table describes math-library linkage, not platform support. The package makes no platform-support claim. Runtime execution also depends on an available target executor.

| Target OS | Math library |
|---|---|
| Linux, FreeBSD, NetBSD, OpenBSD, DragonFly, Illumos | Separate `libm` |
| macOS, Windows, `wasm32-wasi` | Math functions are in libc |

## Consumption

### Zig

Add the package to `build.zig.zon`:

```zig
.dependencies = .{
    .geographiclib_c = .{ .path = "../geographiclib-c" },
},
```

Import its module from `build.zig`:

```zig
const dep = b.dependency("geographiclib_c", .{ .target = target, .optimize = optimize });
exe_mod.addImport("geographiclib", dep.module("geographiclib"));
```

The package key is `geographiclib_c`; the module is `geographiclib`; the native artifact is `geodc`. Import the module only; it carries the native library and required system links.

Build options: `-Dtarget=<triple>`, `-Doptimize=<mode>`, `-Dlinkage=static|dynamic` (default `static`), and `-Druntime=<bool>` (default `false`).

### C

`zig build install` installs `include/geodesic.h`, `lib/libgeodc.a` and `LICENSE.txt`. Use `-Dlinkage=dynamic` for the shared library. Link `-lm` on the targets in the table above.

### Nix

`nix build .#static` builds the default archive; `nix build .#shared` builds the shared library.
