{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
with types;
let
  cfg = config.virtualisation.libvirtd.scopedHooks.qemu;

  # Don't use qemu/d as it's also managed by libvirtd
  hooksRoot = "/var/lib/libvirt/hooks/qemu";
  removeHooksRootRule = [ "Q ${hooksRoot}" ];

  hooksNames = [
    "prepare"
    "start"
    "started"
    "stopped"
    "release"
  ];

  hookPhasesModule = submodule {
    options = {
      begin = mkOption {
        type = nullOr (oneOf [
          str
          (listOf str)
        ]);
        default = null;
        description = "Path(s) to script(s) executed at the begin phase.";
      };

      end = mkOption {
        type = nullOr (oneOf [
          str
          (listOf str)
        ]);
        default = null;
        description = "Path(s) to script(s) executed at the end phase.";
      };
    };
  };

  hooksModule = submodule {
    options = listToAttrs (
      map (hookName: {
        name = hookName;
        value = mkOption {
          type = hookPhasesModule;
          default = { };
          description = "Hook type";
        };
      }) hooksNames
    );
  };

  # Create single symlink to script
  mkVmHookSymlink =
    {
      vmName,
      hookType,
      hookPhase,
      hookExe,
    }:
    let
      hookExeFileName = baseNameOf hookExe;
      targetPath = "${hooksRoot}/${vmName}/${hookType}/${hookPhase}/${hookExeFileName}";
      sourcePath = hookExe;
    in
    "L+ ${targetPath} - - - - ${sourcePath}";

  # Create symlinks for all phases (begin/end)
  mkVmHooksPhases =
    {
      vmName,
      hookType,
      hookBeginExes,
      hookEndExes,
    }:
    let
      # Filter out all nulls and normalize type to list
      normalize = xs: filter (x: x != null) (lists.toList xs);

      normalizedHookBeginExes = normalize hookBeginExes;
      normalizedHookEndExes = normalize hookEndExes;
    in
    (map (
      hookExe:
      mkVmHookSymlink {
        inherit vmName hookType;
        hookPhase = "begin";
        inherit hookExe;
      }
    ) normalizedHookBeginExes)
    ++ (map (
      hookExe:
      mkVmHookSymlink {
        inherit vmName hookType;
        hookPhase = "end";
        inherit hookExe;
      }
    ) normalizedHookEndExes);

  # Create symlinks for all phases (begin/end)
  # and all hookTypes (prepare, start, started, stopped, released)
  mkVmHooks =
    { vmName, hooksConfig }:
    builtins.concatLists (
      attrsets.mapAttrsToList (
        hookType: hookConfig:
        mkVmHooksPhases {
          inherit vmName hookType;
          hookBeginExes = hookConfig.begin or [ ];
          hookEndExes = hookConfig.end or [ ];
        }
      ) hooksConfig
    );

  # Create symlinks for all phases, all hookTypes and all defined VMs
  mkVmsHooks =
    { vmsConfig }:
    builtins.concatLists (
      attrsets.mapAttrsToList (vmName: hooksConfig: mkVmHooks { inherit vmName hooksConfig; }) vmsConfig
    );

  qemuVmsHooks = mkVmsHooks { vmsConfig = cfg.perGuest; };

  isLibvirtEnabled = config.virtualisation.libvirtd.enable;
in
{
  options.virtualisation.libvirtd.scopedHooks.qemu = {
    enable = mkEnableOption "Qemu scoped hooks";

    package = mkOption {
      type = package;
      description = "libvirt-hooks package to use.";
    };

    perGuest = lib.mkOption {
      type = attrsOf hooksModule;
      default = { };
      description = "Per guest qemu hooks";
    };
  };

  config = mkMerge [
    {
      # Fix for nixpkgs bug
      # https://github.com/NixOS/nixpkgs/issues/377609
      systemd.services.libvirtd-config.serviceConfig.RemainAfterExit = mkDefault true;
    }
    (mkIf (cfg.enable && isLibvirtEnabled) {
      systemd.tmpfiles.rules = qemuVmsHooks ++ removeHooksRootRule;

      # /var/lib/libvirt/hooks/qemu.d/
      virtualisation.libvirtd.hooks.qemu.hooks-dispatcher = getExe cfg.package;
    })
  ];
}
