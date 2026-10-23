# SPDX-License-Identifier: MIT
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

  # Upstream version: CMakeLists.txt:5-7; src/geodesic.h:29,34,39.
  version = "2.2.0";

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

  dontConfigure = true;
  dontBuild = true;
  dontUseZigCheck = true;
  doCheck = false;

  # The Nix sandbox has no writable HOME; keep Zig caches under TMPDIR.
  preInstall = ''
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
  '';

  # Disable implicit Zig hook flags; pass CPU, optimize and linkage explicitly.
  dontSetZigDefaultFlags = true;
  zigInstallFlags = [
    "-Dcpu=baseline"
    "-Doptimize=${optimize}"
    "-Dlinkage=${linkage}"
  ];

  passthru = {
    inherit linkage;
    zigModuleName = "geographiclib";
    # Upstream library name (CMakeLists.txt:66).
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
    # File-specific licence coverage is listed in NOTICE.md.
    license = lib.licenses.mit;
    licenseFiles = [
      "LICENSE.txt"
      "NOTICE.md"
      "FORK-LICENSE.md"
    ];
  };
}