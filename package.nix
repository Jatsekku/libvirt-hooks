{
  pkgs,
  bash-logger,
}:

let
  hooks-dispatcher-scriptContent = builtins.readFile ./src/hooks-dispatcher.sh;
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
in
pkgs.writeShellApplication {
  name = "libvirt-hooks-dispatcher";
  text = ''
    #!/usr/bin/env bash
    export BASH_LOGGER_SH=${bash-logger-scriptPath}

    ${hooks-dispatcher-scriptContent}
  '';
  runtimeInputs = [
    pkgs.bash
  ];
}
