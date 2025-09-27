{
  self,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let

  cfg = config.virtualisation.libvirtd.scopedHooks;
  "libvirt-hooks-dispatcher" = self.packages.${pkgs.system}.libvirt-hooks-dispatcher;

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

  hookPhasesModule =
    with types;
    submodule {
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

  hooksModule =
    with types;
    submodule {
      options = builtins.listToAttrs (
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
      hookExeFileName = builtins.baseNameOf hookExe;
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
      # Filter out all nulls and nnormalize type to list
      normalize = xs: builtins.filter (x: x != null) (lib.lists.toList xs);

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

  # Create symlinks for all phases, all hookTypes and all defied VMs
  mkVmsHooks =
    { vmsConfig }:
    builtins.concatLists (
      attrsets.mapAttrsToList (vmName: hooksConfig: mkVmHooks { inherit vmName hooksConfig; }) vmsConfig
    );

  qemuVmsHooks = mkVmsHooks { vmsConfig = cfg.qemu.perGuest; };

  isLibvirtEnabled = config.virtualisation.libvirtd.enable;

in
{
  options.virtualisation.libvirtd.scopedHooks = {
    qemu = {
      enable = lib.mkEnableOption "Qemu scoped hooks";
      perGuest = lib.mkOption {
        type = types.attrsOf hooksModule;
        default = { };
        description = "Per guest qemu hooks";
      };
    };
  };

  config = lib.mkIf (cfg.qemu.enable && isLibvirtEnabled) {
    systemd.tmpfiles.rules = qemuVmsHooks ++ removeHooksRootRule;
    virtualisation.libvirtd.hooks.qemu.hooks-dispatcher = lib.getExe libvirt-hooks-dispatcher;
  };
}
