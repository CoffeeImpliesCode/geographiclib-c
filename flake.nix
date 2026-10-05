# SPDX-License-Identifier: MIT
#
# nix build .#static   static libgeodc plus header, pkg-config and licence records
# nix build .#shared   the same, shared
# nix build            .#static
#
# `default` is static because that is this SDK's existing native policy. Upstream's
# own `CMakeLists.txt:20` defaults to shared (`BUILD_SHARED_LIBS ON`), and that
# difference is recorded as a build-only deviation in README.md.
#
# No devShell: the canonical development environment is `devenv shell`. No
# formatter attribute. `flake.lock` is committed beside this file and named in
# `build.zig.zon`'s `.paths`, so a fetched copy carries the flake layer whole;
# it resolves the input below to the same revision, with
# `narHash sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=` and lock format
# version 7. `devenv.lock` does not exist in this tree and `.paths` does not name
# it - `devenv.yaml` pins the shell's input by revision in source instead - so
# neither lock is the only record of its pin.
{
  description = "GeographicLib-C built from this repository, as a Zig 0.16 package";

  # The revision the workspace's devenv locks resolve `nixpkgs-src` to, read out
  # of ../simd/devenv.lock. The narHash beside it there belongs to a
  # `flake: false` input and is not a hash this file can claim, so the hash
  # recorded for this flake is its own `flake.lock`'s, which Nix wrote by
  # resolving the `url` below. The revision is pinned in source as well, so the
  # pin does not live in the lock alone.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";

  outputs =
    { self, nixpkgs }:
    let
      # Systems the attributes are exposed for. Exposure is not a support claim;
      # the observed compile matrix is in README.md, with receipts.
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