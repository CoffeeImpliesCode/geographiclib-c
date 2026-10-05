# SPDX-License-Identifier: MIT
#
# The one source-only derivation for this SDK. `flake.nix` and `devenv.nix`
# both `callPackage` it, and the static and shared deliveries are two calls with
# a different `linkage` - never a second convention that returns several
# packages.
#
# This derivation adds no installed path of its own. The build graph owns the
# source list, the C flags, the header configuration and the whole installed
# closure: the native library, `include/geodesic.h`, upstream's `LICENSE.txt` at
# the prefix root, this fork's licence and provenance records under
# `share/licenses/geographiclib/`, upstream's documentation inputs plus this
# fork's preserved upstream README under `share/doc/geographiclib/`, and the
# relocatable `lib/pkgconfig/libgeodc.pc`.
#
# Those two `share/` directories are named after the published **module**
# (`geographiclib`), which is what `build.zig` installs; they are not named
# after this derivation's `pname`, its package identity or the library name,
# so a hand-read `zig build --prefix <p> install` tree and `$out` are the same
# tree. Nothing below re-copies any of them: the derivation adds no installed
# path of its own.
#
# Source-only means the inputs are this repository's own files: no build-time
# download, no `../` import of a sibling, no host path and no configured prefix.
# The build tools - one compiler - come from nixpkgs, as they must.
{ lib, stdenv, zig, linkage ? "static", optimize ? "ReleaseSafe" }:

assert lib.assertMsg
  (builtins.elem linkage [ "static" "dynamic" ])
  ''
    package.nix: `linkage` must be "static" or "dynamic", not "${linkage}".
  '';

assert lib.assertMsg
  (builtins.elem optimize [ "Debug" "ReleaseSafe" "ReleaseFast" "ReleaseSmall" ])
  ''
    package.nix: `optimize` must be one of the four Zig optimize mode
    spellings, not "${optimize}".
  '';

stdenv.mkDerivation {
  pname = "geographiclib-c";

  # Upstream's own version: `CMakeLists.txt:5-7` and `src/geodesic.h:29,34,39`
  # both read 2.2.0, which upstream spells "2.2". It is upstream's number, not
  # a fork release number.
  version = "2.2.0";

  # This repository minus build state and repository metadata. A deny-list, so a
  # file the build needs cannot be forgotten here.
  src = lib.cleanSourceWith {
    name = "geographiclib-c-source";
    src = ./.;
    filter =
      path: type:
      let
        base = baseNameOf (toString path);
        excluded = [
          ".git"
          ".direnv"
          ".devenv"
          ".devenv.flake.nix"
          ".zig-cache"
          "zig-cache"
          "zig-out"
          "zig-pkg"
          "result"
        ];
      in
      !(builtins.elem base excluded || lib.hasPrefix "result-" base);
  };

  strictDeps = true;
  nativeBuildInputs = [ zig ];

  # Exactly one `zig build install` runs. `dontInstall` is deliberately not set:
  # it would disable the hook's real install phase. The hook's own build,
  # configure and check phases are switched off so nothing builds twice and no
  # flag set other than the one below reaches the build graph.
  dontConfigure = true;
  dontBuild = true;
  dontUseZigCheck = true;
  doCheck = false;

  # The sandbox has no writable HOME, so both Zig caches go under the TMPDIR Nix
  # provides, outside the unpacked source tree.
  preInstall = ''
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
  '';

  # `-j` comes from the hook (NIX_BUILD_CORES) and `--prefix $out` from leaving
  # `dontAddPrefix` unset. `dontSetZigDefaultFlags` suppresses the hook's own
  # `-Dcpu=baseline --release=safe` so that exactly one optimize selection
  # reaches the build graph.
  dontSetZigDefaultFlags = true;
  zigInstallFlags = [
    "-Dcpu=baseline"
    "-Doptimize=${optimize}"
    "-Dlinkage=${linkage}"
  ];

  passthru = {
    inherit linkage;
    # The Zig module a dependent imports; not upstream's library name.
    zigModuleName = "geographiclib";
    # Upstream's `LIBNAME` (`CMakeLists.txt:66`), which is what a C consumer's
    # `-lgeodc` resolves.
    nativeLibraryName = "geodc";
    publicHeader = "include/geodesic.h";
    pkgConfigFile = "lib/pkgconfig/libgeodc.pc";
  };

  meta = {
    description = ''
      GeographicLib-C: the geodesic routines of GeographicLib, compiled from
      this repository's own unmodified upstream C.
    '';
    longDescription = ''
      Solves the direct and inverse geodesic problems on an ellipsoid of
      revolution - a biaxial ellipsoid, oblate for Earth-like bodies, prolate for
      others, a sphere at f = 0. There is no triaxial solver and no
      Transverse Mercator, rhumb line, UTM/UPS/MGRS, geocentric conversion, geoid
      or magnetic model; those exist only in the C++ GeographicLib. Algorithms by
      C. F. F. Karney, "Algorithms for geodesics", J. Geodesy 87(1), 43-55 (2013),
      with addenda at https://geographiclib.sourceforge.io/geod-addenda.html.
    '';
    # Upstream is MIT/X11; the owner's grant for this fork's own files is the
    # same term. `meta.license` cannot express the per-file inventory.
    license = lib.licenses.mit;
    licenseFiles = [
      "LICENSE.txt"
      "NOTICE.md"
      "FORK-LICENSE.md"
    ];
    # No `mainProgram`: this output is a library, a header, metadata and
    # documents. No `platforms` either - an observed compile matrix is recorded
    # as receipts in README.md, and a list here would read as a support claim
    # this derivation has not run a gate for.
  };
}