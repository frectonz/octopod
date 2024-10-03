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
            pkgs.hurl
            pkgs.just
            pkgs.bacon
            pkgs.httpie
            pkgs.rust-analyzer
            pkgs.elmPackages.elm
            pkgs.elmPackages.elm-land
            pkgs.elmPackages.elm-format
            pkgs.rust-bin.stable.latest.default
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-classic);
    };
}
