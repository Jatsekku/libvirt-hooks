#!/bin/bash
set +o errexit

readonly HOOKS_ROOT_PATH="/var/lib/libvirt/hooks/qemu"
readonly BASH_LOGGER_SH="/etc/bash-logger.sh"
# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "hooks-dispatcher" "$LOG_LEVEL_DBG"
logger_set_log_file "/var/log/libvirt/hooks-dispatcher.log"
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"

__is_arg_empty() {
   [[ -z "$1" ]] 
}

__is_directory() {
    local -r path="$1"
    [[ -d "$path" ]]
}

__is_file_executable() {
    local -r executable_path="$1"
    [[ -x "$executable_path" ]]
}

__does_file_exist() {
    local -r executable_path="$1"
    [[ -e "$executable_path" ]]
}

__execute_script() {
    local -r script_path="$1"

    # script_path file has to exis
    if ! __does_file_exist "$script_path"; then
        log_err "File [${script_path}] not found"
        return 1
    fi

    # script_path file has to be executable
    if ! __is_file_executable "$script_path"; then
        log_err "File [${script_path}] is not executable"
        return 1
    fi

    log_dbg "Executing script [${script_path}] ..."
    "$script_path"

    #TODO: Check status and gather output to log
}

__execute_scripts() {
    local -r scripts_dir_path="$1"

    while IFS= read -r script_path; do
        ! __is_arg_empty "$script_path" || continue
        __execute_script "$script_path"
    done < <(find -L "$scripts_dir_path" -maxdepth 1 -type f -executable -print)
}

dispatch_hook() {
    local -r guest_name="$1"
    local -r hook_name="$2"
    local -r phase_name="$3"

    log_inf "Recived hook [${guest_name}::${hook_name}::${phase_name}]"
    local -r hook_dir_path="${HOOKS_ROOT_PATH}/${guest_name}/${hook_name}/${phase_name}"

    # hook_dir_path has to exist
    if ! __is_directory "$hook_dir_path"; then
        log_wrn "Hook directory [${hook_dir_path}] not found. Ignoring..."
        return 0
    fi

    __execute_scripts "$hook_dir_path"
}

dispatch_hook "$1" "$2" "$3"

