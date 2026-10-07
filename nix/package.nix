{ pkgs, bash-logger }:
let
  # Path to external lib (bash-logger)
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
  bash-logger-logFilePath = "/var/log/libvirt/libvirt-hooks.log";

  hooks-scriptPath = ../src/hooks.sh;

  runtimeInputs = [
    pkgs.bash
  ];

  hooks-scriptContent = builtins.readFile hooks-scriptPath;
in
pkgs.writeShellApplication {
  inherit runtimeInputs;
  name = "libvirt-hooks-dispatcher";
  text = ''
    #!/usr/bin/env bash
    export BASH_LOGGER_SH=${bash-logger-scriptPath}
    export LOG_FILE_PATH=${bash-logger-logFilePath}

    ${hooks-scriptContent}
  '';
}
