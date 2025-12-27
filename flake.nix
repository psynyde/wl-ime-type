{
  description = "wl-ime-type";
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
        project = "wl-ime-type";
        zigDeps = pkgs.callPackage ./zig-deps.nix { };
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = project;
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              zig.hook
              scdoc
              pkg-config
              wayland-scanner
            ];

            buildInputs = with pkgs; [
              wayland
              wayland-protocols
            ];

            postPatch = ''
              ln -s ${zigDeps} $ZIG_GLOBAL_CACHE_DIR/p
            '';

            zigBuildFlags = [ "-Doptimize=ReleaseFast" ];

            postBuild = ''
              scdoc < wl-ime-type.1.scd > wl-ime-type.1
            '';

            postInstall = ''
              install -Dm644 wl-ime-type.1 -t $out/share/man/man1
            '';

            meta = with pkgs.lib; {
              description = "IME typing tool for Wayland in zig";
              homepage = "https://github.com/psynyde/${project}";
              license = licenses.bsd2;
              maintainers = with maintainers; [ psynyde ];
              platforms = platforms.linux;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          name = project;
          LSP_SERVER = "zls";
          packages = with pkgs; [
            zig
            zls
            scdoc
            zon2nix

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
