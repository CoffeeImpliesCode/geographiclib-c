# Changelog

Changes in this fork relative to GeographicLib-C v2.2.

- Port to Zig 0.17.0.
- Nix's `optimize` argument uses Zig 0.17's lowercase modes: `debug`, `safe`, `fast`, and `small`.
- Add `package.nix` and flake outputs for static and shared libraries; include packaging and runtime files in the fetched package.
- Add `-Dlinkage=static|dynamic` and optional `-Druntime=true`; static linked builds remain the default.
- Correct runtime-loading build paths for Zig 0.16.
- Separate basic `direct`/`inverse` calls from extended `genDirect`/`genInverse` APIs, matching their distinct upstream calculations.
- Make `Geodesic.init` initialize caller-owned storage in place.
- Interpret `geod_mask` output bits separately from coefficient bits; `genPosition` returns `error.DistanceNotAccepted` when distance input is unavailable.
- Keep `api_exercise` as a build/test program, not a public module export.
- Add `prepare()` to initialize upstream's process-global state before concurrent `geod_init` calls.
- Compile upstream C as C99 with floating-point contraction disabled.
- Add a Zig 0.16 package with module `geographiclib` and artifact `geodc`.
