{
  description = "Libvirt hooks dispatcher";

  # Flake inputs
  inputs = {
    # Feature-rich, flexible logger utility for bash.
    bash-logger = {
      url = "github:Jatsekku/bash-logger";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Packages collection & NixOS.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs@{ self, ... }:
    let
      # List of all supported systems
      supportedSystems = inputs.nixpkgs.lib.systems.flakeExposed;

      # Function for providing system-specific attributes
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            # Nixpkgs configured per system
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Apply overlays defined by flake itself
              overlays = [ self.overlays.default ];
            };
            inherit system;
          }
        );
    in
    {
      # Provide packages
      packages = forEachSupportedSystem (
        { pkgs, system }:
        let
          # Dependencies
          bash-logger = inputs.bash-logger.packages.${system}.default;

          # Build package set
          libvirt-hooks-pkg = pkgs.callPackage ./nix/package.nix {
            inherit bash-logger;
          };
        in
        {
          # Expose package
          libvirt-hooks = libvirt-hooks-pkg;
        }
      );

      # Inject packages via overlays
      overlays.default = final: prev: {
        inherit (self.packages.${final.system})
          libvirt-hooks
          ;
      };

      # Provide NixOs modules
      nixosModules = rec {
        libvirt-hooks = { pkgs, lib, ... }: {
          imports = [ ./nix/module.nix ];

          # Inject the default package
          virtualisation.libvirtd.scopedHooks.qemu.package =
            lib.mkDefault
              self.packages.${pkgs.stdenv.hostPlatform.system}.libvirt-hooks;
        };

        # Alias default to the exact same module
        default = libvirt-hooks;
      };

      # Generate devShell for each system
      devShells = forEachSupportedSystem ({ pkgs, ... }: import ./nix/devshell.nix { inherit pkgs; });

      # Set formatter for Nix
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
