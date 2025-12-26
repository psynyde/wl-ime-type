{
  description = "wl-ime-type-zig";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        project = "wl-ime-type-zig";
      in
      {
        devShells.default = pkgs.mkShell {
          name = project;
          LSP_SERVER = "zls";
          packages = with pkgs; [
            zig
            zls

            pkg-config

            wayland
            wayland-protocols
            wayland-scanner
          ];
          shellHook = ''
            echo -e '(¬_¬") Entered ${project} :D'
          '';
        };
        formatter = treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            zig.enable = true;
          };
        };
      }
    );
}
