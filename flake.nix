{
  description = "Solana";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    docker-tools.url = "github:ZentriaMC/docker-tools";

    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    docker-tools.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, docker-tools, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;

          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "cudatoolkit"
          ];
        };

        # https://rust-lang.github.io/rustup-components-history/
        mkRustPlatform = flavor: version:
          let
            toolchain = pkgs.rust-bin.${flavor}."${version}".minimal.override {
              extensions = [
                "rustfmt" # build-time dependency, yes
              ];
            };
          in
          pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };
      in
      rec {
        packages.solana = pkgs.callPackage ./solana.nix {
          rustPlatform = mkRustPlatform "stable" "1.59.0";

          inherit (pkgs.darwin.apple_sdk.frameworks) AppKit CoreFoundation IOKit Security;
          MacOSX-SDK = pkgs.darwin.apple_sdk.MacOSX-SDK or null;
          System = null; # broken, see https://github.com/NixOS/nixpkgs/issues/163215
          #System = pkgs.darwin.apple_sdk.frameworks.System or null;
        };

        packages.solana-validator-only = packages.solana.override {
          validatorOnly = true;
        };
      });
}
