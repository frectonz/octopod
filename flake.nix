{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "x86_64-linux" ];

      forAllSystems = function:
        nixpkgs.lib.genAttrs systems (system:
          function (import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          }));
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.fzf
            pkgs.just
            pkgs.hurl
            pkgs.elm2nix
            pkgs.watchexec
            pkgs.rust-analyzer
            pkgs.elmPackages.elm
            pkgs.elmPackages.elm-format
            pkgs.rust-bin.stable.latest.default
            pkgs.elmPackages.elm-language-server

            (pkgs.writeShellApplication {
              name = "run";
              text = "watchexec -r just run";
            })
          ];
        };
      });

      packages = forAllSystems (pkgs:
        let
          ui = pkgs.callPackage ./ui/default.nix { };

          rustPlatform = pkgs.makeRustPlatform {
            cargo = pkgs.rust-bin.stable.latest.default;
            rustc = pkgs.rust-bin.stable.latest.default;
          };
        in {
          default = rustPlatform.buildRustPackage {
            pname = "octopod";
            version = "0.1.0";
            src = ./.;

            preBuild = ''
              cp ${ui}/Main.js ui/Main.js
            '';

            cargoLock.lockFile = ./Cargo.lock;
          };
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-classic);
    };
}
