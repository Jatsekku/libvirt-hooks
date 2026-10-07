# NixOS Libvirt hooks module

A flexible, declarative NixOS module designed to configure and manage QEMU scoped hooks for libvirt.

## Features

- **Per-Guest Configuration**: Define hook scripts independently for each virtual machine guest.

---

## Options reference

### NixOS module options <br>`virtualisation.libvirtd.scopedHooks.qemu`

| Option     | Type                 | Default | Description                          |
| :--------- | :------------------- | :------ | :----------------------------------- |
| `enable`   | bool                 | `false` | Whether to enable Qemu scoped hooks. |
| `package`  | package              |         | libvirt-hooks package to use.        |
| `perGuest` | attrs of hooksModule | `{}`    | Per guest qemu hooks.                |

### Hooks (hooksModule) options <br>`virtualisation.libvirtd.scopedHooks.qemu.perGuest.<vmName>.<hookType>.<phase>`

| Option  | Type                                | Default | Description                                       |
| :------ | :---------------------------------- | :------ | :------------------------------------------------ |
| `begin` | nullOr (oneOf [ str (listOf str) ]) | `null`  | Path(s) to script(s) executed at the begin phase. |
| `end`   | nullOr (oneOf [ str (listOf str) ]) | `null`  | Path(s) to script(s) executed at the end phase.   |

---

## Usage examples

1. Add the module to your flake.nix inputs:

```nix
libvirt-hooks = {
  url = "github:Jatsekku/libvirt-hooks";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

2. Import the NixOS module:
```nix
imports = [ inputs.libvirt-hooks.nixosModules.default ]; 
```

3. Enable module and add some hooks:
> [!IMPORTANT]
> To use libvirt hooks make sure that you have libvirt daemon enabled.
>```nix
>  virtualisation.libvirtd.enable = true;
>```

```nix
{
  virtualisation.libvirtd.scopedHooks.qemu = {
    enable = true;

    perGuest = {
      # Target your VM by its libvirt name
      "my-windows-vm" = {
        prepare = { };
        release = { }; 
      };
    };
  };
}
```

---

