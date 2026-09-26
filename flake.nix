{
  description = "HSH - a desktop shell built for YOU.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hsh-wallpapers = {
      url = "github:mora1ss/shell-wallpapers";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, hsh-wallpapers, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      overlays.default = final: _prev: {
        hsh = final.callPackage ./nix/package.nix {
          rev = self.rev or self.dirtyRev or "dirty";
        };
      };

      packages = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.callPackage ./nix/package.nix {
            rev = self.rev or self.dirtyRev or "dirty";
          };
          hsh = self.packages.${system}.default;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/hsh";
        };
        hshd = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/hshd";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [ nixpkgs-fmt nil ];
          };
        });

      homeManagerModules.default = import ./nix/hm-module.nix {
        inherit self;
        wallpapers = hsh-wallpapers;
      };
      homeManagerModules.hsh = self.homeManagerModules.default;

      nixosModules.default = import ./nix/nixos-module.nix;
      nixosModules.hsh = self.nixosModules.default;

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
