#!/usr/bin/env bash
#
# install_ros2_env.sh
# One-shot ROS2 Jazzy environment configurator for NavQ95.
#
# Installs the Zenoh RMW middleware and generates a persistent ROS2
# environment config file (ros2rc) with NavQ95-specific exports.
#
# USAGE:
#   install_ros2_env [-i] [-l] [-h]
#
#   (no flags)  Non-interactive: run all steps unattended,
#               installs fixed version(s): ros-jazzy-rmw-zenoh-cpp=${ZENOH_FIXED_VERSION}
#   -i          Interactive: prompt [Y/n] before each step
#   -l          Latest: install latest upstream packages (ignores fixed version)
#   -h          Show this help and exit
#
#   Flags can be combined, e.g.: install_ros2_env -i -l
#
set -eEuo pipefail
trap 'printf "\nERROR: Installation aborted at line %s. Fix the issue above and\n\
re-run the script.\nTip: use -i for step-by-step control (prompt before each step).\n" \
"$LINENO"' ERR

# --- NavQ95-specific: fixed ros-jazzy-rmw-zenoh-cpp version ------------------
# Override by exporting ZENOH_FIXED_VERSION before running this script.
ZENOH_FIXED_VERSION="${ZENOH_FIXED_VERSION:-0.2.9-1noble.20260612.051449}"

# --- Output path for the generated ros2rc file -------------------------------
# Override by exporting ROS2RC_PATH before running this script.
ROS2RC_PATH="${ROS2RC_PATH:-${HOME}/.ros2rc}"

# --- Flags -------------------------------------------------------------------
FLAG_INTERACTIVE="no"
FLAG_LATEST="no"

for arg in "$@"; do
    case "$arg" in
        -i) FLAG_INTERACTIVE="yes" ;;
        -l) FLAG_LATEST="yes" ;;
        -h)
            printf 'Usage: install_ros2_env [-i] [-l] [-h]\n\n'
            printf '  (no flags)  Non-interactive: run all steps unattended,\n'
            printf '              installs fixed version(s): ros-jazzy-rmw-zenoh-cpp=%s\n' \
                "${ZENOH_FIXED_VERSION}"
            printf '  -i          Interactive: prompt [Y/n] before each step\n'
            printf '  -l          Latest: install latest upstream packages\n'
            printf '              (ignores fixed version)\n'
            printf '  -h          Show this help and exit\n\n'
            printf 'Flags can be combined, e.g.: install_ros2_env -i -l\n'
            exit 0
            ;;
        *) printf 'Unknown flag: %s\nRun install_ros2_env -h for usage.\n' "$arg"; exit 1 ;;
    esac
done

# -l: fixed version is ignored
if [ "$FLAG_LATEST" = "yes" ]; then
    printf -- 'WARNING: -l (latest) specified, latest upstream packages will be installed\n'
    printf -- '         (ignoring fixed ZENOH_FIXED_VERSION=%s).\n' "${ZENOH_FIXED_VERSION}"
fi

TOTAL=3

run_step() {
    local idx="$1" desc="$2" fn="$3" ans="y"
    if [ "$FLAG_INTERACTIVE" = "yes" ]; then
        printf '\nStep %s/%s: %s  [Y/n] ' "$idx" "$TOTAL" "$desc"
        read -r ans || ans="y"
        ans="${ans:-y}"
        case "$ans" in
            n|N) printf 'Step %s/%s: SKIPPED\n' "$idx" "$TOTAL"; return 0 ;;
        esac
    else
        printf '\n=== Step %s/%s: %s ===\n' "$idx" "$TOTAL" "$desc"
    fi
    "$fn"
}

# --- Steps -------------------------------------------------------------------
step_1_zenoh() {
    sudo apt update
    sudo apt-mark unhold ros-jazzy-rmw-zenoh-cpp || true  # release any hold from a previous run
    if [ "$FLAG_LATEST" = "yes" ]; then
        sudo apt install -y ros-jazzy-rmw-zenoh-cpp
    else
        sudo apt install -y "ros-jazzy-rmw-zenoh-cpp=${ZENOH_FIXED_VERSION}"
        sudo apt-mark hold ros-jazzy-rmw-zenoh-cpp
    fi
}

step_2_ros2rc() {
    printf 'Generating %s ...\n' "${ROS2RC_PATH}"
    tee "${ROS2RC_PATH}" > /dev/null <<'EOF'
# ros2rc -- NavQ95 ROS2 environment configuration
# Source this file to activate the ROS2 Jazzy environment with Zenoh RMW:
#   source ~/.ros2rc

# Activate ROS2 Jazzy
source /opt/ros/jazzy/setup.bash

# Use Zenoh as the RMW implementation
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
EOF
    chmod 644 "${ROS2RC_PATH}"
    printf 'ros2rc written to %s\n' "${ROS2RC_PATH}"
}

step_3_report() {
    if [ ! -f /opt/ros/jazzy/setup.bash ]; then
        printf 'ERROR: /opt/ros/jazzy/setup.bash not found. Run install_ros2_base first.\n'
        return 1
    fi
    set +u
    source /opt/ros/jazzy/setup.bash
    export RMW_IMPLEMENTATION=rmw_zenoh_cpp
    set -u
    printf 'ROS_DISTRO            = %s\n' "${ROS_DISTRO:-<unset>}"
    printf 'RMW_IMPLEMENTATION    = %s\n' "${RMW_IMPLEMENTATION:-<unset>}"
    printf 'ros-jazzy-rmw-zenoh-cpp installed version: %s\n' \
        "$(dpkg-query -W -f='${Version}' ros-jazzy-rmw-zenoh-cpp 2>/dev/null || echo '<not found>')"
    printf 'ros2rc path           = %s\n' "${ROS2RC_PATH}"
}

# --- Main --------------------------------------------------------------------
printf 'ROS2 Jazzy env configurator -- mode: '
if [ "$FLAG_INTERACTIVE" = "yes" ]; then
    printf 'interactive'
else
    printf 'non-interactive'
fi
printf ', version: '
if [ "$FLAG_LATEST" = "yes" ]; then
    printf 'latest upstream packages\n'
    step1_desc="Install ros-jazzy-rmw-zenoh-cpp (latest upstream)"
else
    printf 'fixed ros-jazzy-rmw-zenoh-cpp (%s)\n' "${ZENOH_FIXED_VERSION}"
    step1_desc="Install ros-jazzy-rmw-zenoh-cpp (fixed ${ZENOH_FIXED_VERSION})"
fi

run_step 1 "${step1_desc}"                               step_1_zenoh
run_step 2 "Generate ros2rc environment config"          step_2_ros2rc
run_step 3 "Report installation"                         step_3_report

printf '\nSUCCESS. All steps completed.\n'
printf 'To activate the ROS2 Zenoh environment, run:\n'
printf '  source %s\n' "${ROS2RC_PATH}"
printf '\nTo activate automatically on every login, add it to your shell startup script:\n'
printf '  echo "source %s" >> ~/.bashrc\n' "${ROS2RC_PATH}"
