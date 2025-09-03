{
  description = "Nix flake for wl-ime-type";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "wl-ime-type";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              pkg-config
              scdoc
            ];

            buildInputs = with pkgs; [
              wayland
              wayland-scanner
            ];

            makeFlags = [ "PREFIX=${placeholder "out"}" ];
          };
        }
      );
    };
}
