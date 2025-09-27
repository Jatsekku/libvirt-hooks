{
  description = "Libvirt hooks dispatcher";

  inputs = {
    bash-logger = {
      url = "github:Jatsekku/bash-logger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      bash-logger,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          bash-logger-pkg = bash-logger.packages.${system}.default;
          libvirt-hooks-pkg = pkgs.callPackage ./package.nix { bash-logger = bash-logger-pkg; };
        in
        {
          libvirt-hooks-dispatcher = libvirt-hooks-pkg;
        }
      );

      nixosModules = {
        libvirt-hooks =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import ./module.nix {
            inherit
              config
              lib
              pkgs
              self
              ;
          };
        default = self.nixosModules.libvirt-hooks;
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
