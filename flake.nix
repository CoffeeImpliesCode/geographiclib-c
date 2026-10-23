# SPDX-License-Identifier: MIT
{
  description = "GeographicLib-C built from this repository, as a Zig 0.16 package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-windows"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      geodc =
        pkgs: linkage:
        pkgs.callPackage ./package.nix {
          zig = pkgs.zig_0_16;
          inherit linkage;
        };
    in
    {
      packages = forAllSystems (
        pkgs:
        rec {
          static = geodc pkgs "static";
          shared = geodc pkgs "dynamic";
          default = static;
        }
      );
    };
}