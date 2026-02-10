{
  description = "wl-ime-type";
  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    { zig2nix, treefmt-nix, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        env = zig2nix.outputs.zig-env.${system} { zig = zig2nix.outputs.packages.${system}.zig-latest; };
        pkgs = env.pkgs;
        project = "wl-ime-type";
      in
      {
        packages.default = env.package rec {
          pname = project;
          src = ./.;

          nativeBuildInputs = with pkgs; [
            scdoc
            pkg-config
            wayland-scanner
          ];

          buildInputs = with pkgs; [
            wayland
            wayland-protocols
          ];

          zigWrapperLibs = buildInputs;

          zigBuildZonLock = ./build.zig.zon2json-lock;

          zigBuildFlags = [ "-Doptimize=ReleaseFast" ];

          postBuild = ''
            scdoc < wl-ime-type.1.scd > wl-ime-type.1
          '';

          postInstall = ''
            install -Dm644 wl-ime-type.1 -t $out/share/man/man1
          '';

          meta = with pkgs.lib; {
            mainProgram = project;
            description = "IME typing tool for Wayland in zig";
            homepage = "https://github.com/psynyde/${project}";
            license = licenses.bsd2;
            maintainers = with maintainers; [ psynyde ];
            platforms = platforms.linux;
          };
        };

        devShells.default = env.mkShell {
          name = project;
          LSP_SERVER = "zls";
          packages = with pkgs; [
            zls

            scdoc
            pkg-config
            wayland-scanner

            wayland
            wayland-protocols
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
    ));
}
