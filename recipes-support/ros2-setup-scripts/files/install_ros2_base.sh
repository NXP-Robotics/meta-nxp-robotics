#!/usr/bin/env bash
#
# install_ros2_base.sh
# One-shot ROS2 Jazzy base installer (Ubuntu 24.04 / arm64).
#
# Mirrors the official ROS2 Jazzy deb install, step-by-step:
#   https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html
# The ONLY board-specific difference is the pinned ros-jazzy-ros-base version
# (see ROS_BASE_VERSION below).
#
# USAGE:
#   ./install_ros2_base.sh        # default: run ALL steps, no prompts (unattended / ssh)
#   ./install_ros2_base.sh -i     # interactive: prompt [Y/n] before each step
#
# PREREQUISITE: the board must have working internet access (apt can reach
# packages.ros.org). This script does NOT configure networking or a proxy.
#
set -euo pipefail
trap 'printf "\nERROR: Installation aborted at line %s. Fix the issue above and re-run the script.\nTip: use -i for step-by-step control (prompt before each step).\n" "$LINENO"' ERR

# --- NavQ95-specific: pinned ros-jazzy-ros-base version ---------------------
# Override by exporting ROS_BASE_VERSION before running this script.
# Read the version currently INSTALLED on a board:
#   dpkg-query -W -f='${Version}\n' ros-jazzy-ros-base
# Read the versions AVAILABLE in the repo (per architecture):
#   apt-cache madison ros-jazzy-ros-base
# NOTE: the package version is architecture-specific; pin the arm64 build for NavQ95.
ROS_BASE_VERSION="${ROS_BASE_VERSION:-0.11.0-1noble.20260614.091815}"

# --- Mode --------------------------------------------------------------------
INTERACTIVE="no"        # default: run everything, no prompts
[ "${1:-}" = "-i" ] && INTERACTIVE="yes"

TOTAL=7

# run_step <index> <description> <function>
# non-interactive: announce + run. interactive: prompt [Y/n] (Enter=Y), n=skip.
run_step() {
    local idx="$1" desc="$2" fn="$3" ans="y"
    if [ "$INTERACTIVE" = "yes" ]; then
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
step_1_locale() {
    sudo apt update && sudo apt install -y locales
    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    export LANG=en_US.UTF-8
}

step_2_universe() {
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y universe
}

step_3_apt_source() {
    sudo apt install -y curl
    ROS_APT_SOURCE_VERSION="$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
      | grep -F 'tag_name' | awk -F\" '{print $4}')"
    curl -L -o /tmp/ros2-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo "$VERSION_CODENAME")_all.deb"
    sudo dpkg -i /tmp/ros2-apt-source.deb
}

step_4_update() {
    sudo apt update
    sudo apt upgrade -y
}

step_5_rosbase() {
    # PINNED install -- the NavQ95-specific diff.
    sudo apt install -y "ros-jazzy-ros-base=${ROS_BASE_VERSION}"
    sudo apt-mark hold ros-jazzy-ros-base    # prevent auto-upgrade off the baseline
}

step_6_dev_tools() {
    sudo apt install -y ros-dev-tools
}

step_7_verify() {
    # source may reference unbound ament vars -- temporarily disable set -u
    set +u
    source /opt/ros/jazzy/setup.bash
    set -u
    echo "ROS_DISTRO = ${ROS_DISTRO:-<unset>}"
    ros2 doctor --report 2>/dev/null | grep -i "middleware name" || true
}

# --- Main --------------------------------------------------------------------
if [ "$INTERACTIVE" = "yes" ]; then
    printf 'ROS2 Jazzy base installer -- interactive mode (prompting before each step)\n'
else
    printf 'ROS2 Jazzy base installer -- non-interactive mode (running all steps)\n'
fi
run_step 1 "Set locale (UTF-8)"                          step_1_locale
run_step 2 "Enable universe repository"                  step_2_universe
run_step 3 "Add ROS2 apt source (ros2-apt-source deb)"   step_3_apt_source
run_step 4 "apt update && upgrade"                       step_4_update
run_step 5 "Install ros-jazzy-ros-base (pinned ${ROS_BASE_VERSION})" step_5_rosbase
run_step 6 "Install ros-dev-tools"                       step_6_dev_tools
run_step 7 "Verify installation"                         step_7_verify

printf '\nSUCCESS. All steps completed. ros-jazzy-ros-base=%s installed and held.\nNOTE: ROS2 is not yet active in this shell. Run: source /opt/ros/jazzy/setup.bash\n' "${ROS_BASE_VERSION}"

