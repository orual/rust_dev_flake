{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, naersk, nixpkgs, rust-overlay, devshell, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        nativeSystem = "x86_64-linux";
        nativeTarget = "x86_64-unknown-linux-gnu";
        crossTarget = "aarch64-unknown-linux-gnu"; # "armv7-unknown-linux-gnueabihf";
        overlays = [ (import rust-overlay) ];
        pkgs = (import nixpkgs) {
          inherit system overlays;
        };

        pkgsCrossTarget = (import nixpkgs) {
          inherit overlays;
          system = "${system}";
          crossSystem = {
            config = "${crossTarget}";
          };
        };


        extensions = [
          "rust-src" # for rust-analyzer
          "rust-analyzer"
        ];

        targets = [
          nativeTarget
          crossTarget
        ];

        # native compilation
        toolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = extensions;
          targets = targets;
        };

        # Using a separate pkgs instance so that we get the cross-compile on the typical host
        crossToolchain = pkgsCrossTarget.rust-bin.stable.latest.default.override {
          extensions = extensions;
          targets = targets;
        };

        # A naersk version for the native and cross-compilation toolchains
        naersk' = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };

        naerskCross' = naersk.lib.${nativeSystem}.override {
          cargo = crossToolchain;
          rustc = crossToolchain;
        };


        # Same deal for the package builds
        naerskBuildPackage = target: args:
          naersk'.buildPackage (
            args
            // { CARGO_BUILD_TARGET = target; }
            // cargoConfig
          );

        naerskCrossBuild = target: args:
          naerskCross'.buildPackage (
            args
            // { CARGO_BUILD_TARGET = target; }
            // cargoConfig
          );


        cargoConfig = { };

      in
      rec {
        # For `nix build` & `nix run`:
        defaultPackage = naerskBuildPackage {
          src = ./.;
        };

        defaultCrossPackage = naerskCrossBuild {
          src = ./.;
        };

        # Run `nix build .#test` to run tests
        test = naerskBuildPackage {
          src = ./.;
          mode = "test";
          #cargoTestOptions = [ ''cargo_test_options="$cargo_test_options --lib"'' ];
        };

        # Run `nix build .#check` to check code
        check = naerskBuildPackage {
          src = ./.;
          mode = "check";
        };

        packages.devshell = self.outputs.devShells.${system}.default;

        devShells.default =
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ devshell.overlays.default ];
            };
          in
          pkgs.devshell.mkShell ({ config, ... }: {
            name = "template";
            env = [
            ];

            packages = [
              defaultPackage
              toolchain
              pkgs.cargo-udeps
            ];

            commands = [
              {
                name = "greet";
                command = ''
                  printf -- 'Hello, %s!\n' "''${1:-world}"
                '';
              }
            ];
          } // cargoConfig);
      }
    );
}
