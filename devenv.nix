# SPDX-License-Identifier: MIT
{
  pkgs,
  ...
}:

let
  zig = pkgs.zig_0_17;

  geodc =
    linkage:
    pkgs.callPackage ./package.nix {
      inherit zig;
      inherit linkage;
    };

  static = geodc "static";

  # Convert the checkout path to a string; path interpolation would copy it to the store.
  sdkRoot = builtins.toString ./.;

  # Tasks run from this checkout and keep Zig caches and output outside it.
  # Caller cache exports win; defaults use XDG_CACHE_HOME or TMPDIR.
  taskPreamble = ''
    sdkRoot=${pkgs.lib.escapeShellArg sdkRoot}
    cd "$sdkRoot" || exit 1
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="$XDG_CACHE_HOME/zig-local-cache"
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
      else
        echo "geographiclib-c: XDG_CACHE_HOME and TMPDIR are both unset, so no" >&2
        echo "Zig cache and no install prefix are chosen here. Export" >&2
        echo "ZIG_LOCAL_CACHE_DIR at an approved mount." >&2
        exit 1
      fi
      export ZIG_LOCAL_CACHE_DIR
    fi
    if [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="$XDG_CACHE_HOME/zig"
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig"
      else
        echo "geographiclib-c: export ZIG_GLOBAL_CACHE_DIR at an approved mount," >&2
        echo "or set XDG_CACHE_HOME or TMPDIR." >&2
        exit 1
      fi
      export ZIG_GLOBAL_CACHE_DIR
    fi
    geodcPrefix="''${GEODC_PREFIX:-$ZIG_LOCAL_CACHE_DIR/geographiclib-c/zig-out}"
  '';
in
{
  packages = [
    zig
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
  ];

  assertions = [
    {
      assertion = zig.version == "0.17.0";
      message = ''
        src/ and zig/ are written against Zig 0.17.0; nixpkgs supplies
        ${zig.version}.
      '';
    }
  ];

  outputs = {
    inherit static;
    shared = geodc "dynamic";
    default = static;
  };

  tasks = {
    "sdk:build" = {
      description = "Install the delivery closure into a prefix outside this repository";
      exec = ''
        ${taskPreamble}
        zig build -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --prefix "$geodcPrefix" --summary all "$@"
      '';
    };

    "sdk:test" = {
      description = "Run the facade tests and every API operation";
      exec = ''
        ${taskPreamble}
        zig build test -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:smoke" = {
      description = "Run the deterministic example program";
      exec = ''
        ${taskPreamble}
        zig build smoke -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:exercise" = {
      description = "Run every supported facade operation";
      exec = ''
        ${taskPreamble}
        zig build exercise -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:upstream-test" = {
      description = "Build and run upstream's own geodtest and geodsigntest C programs";
      exec = ''
        ${taskPreamble}
        zig build upstream-test -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:check" = {
      description = "Compile the six-target matrix without running any of it";
      exec = ''
        ${taskPreamble}
        zig build check -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:consumer" = {
      description = "Build and run consumer/src/main.zig inside this build graph";
      exec = ''
        ${taskPreamble}
        zig build consumer -j8 --cache-dir "$ZIG_LOCAL_CACHE_DIR" --summary all "$@"
      '';
    };

    "sdk:integrity" = {
      description = "Check the recorded digests in UPSTREAM.sha256 against this tree";
      exec = ''
        ${taskPreamble}
        sha256sum -c UPSTREAM.sha256
      '';
    };
  };
}