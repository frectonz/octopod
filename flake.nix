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
            pkgs.cargo-dist
            pkgs.rust-analyzer
            pkgs.elmPackages.elm
            pkgs.elmPackages.elm-format
            pkgs.rust-bin.stable.latest.default
            pkgs.elmPackages.elm-language-server
            pkgs.nodePackages.vscode-langservers-extracted

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

          pname = "octopod";
          version = "0.1.2";
        in rec {
          default = rustPlatform.buildRustPackage {
            inherit pname version;
            src = ./.;

            preBuild = ''
              cp ${ui}/Main.js ui/Main.js
            '';

            cargoLock.lockFile = ./Cargo.lock;
          };

          image = pkgs.dockerTools.buildLayeredImage {
            name = pname;
            tag = "latest";
            created = "now";
            config.Cmd = [ "${default}/bin/octopod" ];
          };

          deploy = pkgs.writeShellScriptBin "deploy" ''
            ${pkgs.skopeo}/bin/skopeo --insecure-policy copy docker-archive:${image} docker://docker.io/frectonz/octopod:${version} --dest-creds="frectonz:$ACCESS_TOKEN"
            ${pkgs.skopeo}/bin/skopeo --insecure-policy copy docker://docker.io/frectonz/octopod:${version} docker://docker.io/frectonz/octopod:latest --dest-creds="frectonz:$ACCESS_TOKEN"
          '';
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-classic);
    };
}
