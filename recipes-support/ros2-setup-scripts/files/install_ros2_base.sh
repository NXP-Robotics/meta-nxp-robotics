#!/usr/bin/env bash
#
# install_ros2_base
# One-shot ROS2 Jazzy base installer.
#
# Mirrors the official ROS2 Jazzy deb install, step-by-step:
#   https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html
# The ONLY board-specific difference is the fixed ros-jazzy-ros-base version
# (see ROS_FIXED_VERSION below).
#
# USAGE:
#   install_ros2_base [-i] [-l] [-h]
#
#   (no flags)  Non-interactive: run all steps unattended, installs fixed version (ros-jazzy-ros-base=${ROS_FIXED_VERSION})
#   -i          Interactive: prompt [Y/n] before each step
#   -l          Latest: install latest upstream ros-jazzy-ros-base (ignores fixed version)
#   -h          Show this help and exit
#
#   Flags can be combined, e.g.: install_ros2_base -i -l
#
set -euo pipefail
trap 'printf "\nERROR: Installation aborted at line %s. Fix the issue above and re-run the script.\nTip: use -i for step-by-step control (prompt before each step).\n" "$LINENO"' ERR

# --- NavQ95-specific: fixed ros-jazzy-ros-base version ---------------------
# Override by exporting ROS_FIXED_VERSION before running this script.
# Read the version currently INSTALLED on a board:
#   dpkg-query -W -f='${Version}\n' ros-jazzy-ros-base
# Read the versions AVAILABLE in the repo (per architecture):
#   apt-cache madison ros-jazzy-ros-base
# NOTE: the package version is architecture-specific; pin the arm64 build for NavQ95.
ROS_FIXED_VERSION="${ROS_FIXED_VERSION:-0.11.0-1noble.20260614.091815}"

# --- Flags -------------------------------------------------------------------
FLAG_INTERACTIVE="no"
FLAG_LATEST="no"

for arg in "$@"; do
    case "$arg" in
        -i) FLAG_INTERACTIVE="yes" ;;
        -l) FLAG_LATEST="yes" ;;
        -h)
            printf 'Usage: install_ros2_base [-i] [-l] [-h]\n\n'
            printf '  (no flags)  Non-interactive: run all steps unattended, installs fixed version (ros-jazzy-ros-base=%s)\n' "${ROS_FIXED_VERSION}"
            printf '  -i          Interactive: prompt [Y/n] before each step\n'
            printf '  -l          Latest: install latest upstream ros-jazzy-ros-base (ignores fixed version)\n'
            printf '  -h          Show this help and exit\n\n'
            printf 'Flags can be combined, e.g.: install_ros2_base -i -l\n'
            exit 0
            ;;
        *) printf 'Unknown flag: %s\nRun install_ros2_base -h for usage.\n' "$arg"; exit 1 ;;
    esac
done

# -l: fixed version is ignored
if [ "$FLAG_LATEST" = "yes" ]; then
    printf -- 'WARNING: -l (latest) specified, latest upstream will be installed (ignoring pinned ROS_FIXED_VERSION=%s).\n' "${ROS_FIXED_VERSION}"
fi

TOTAL=7

# run_step <index> <description> <function>
# non-interactive: announce + run. interactive: prompt [Y/n] (Enter=Y), n=skip.
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
    if [ "$FLAG_LATEST" = "yes" ]; then
        # LATEST install -- no version pin, no hold.
        sudo apt install -y ros-jazzy-ros-base
    else
        # FIXED install -- the NavQ95-specific diff.
        sudo apt install -y "ros-jazzy-ros-base=${ROS_FIXED_VERSION}"
        sudo apt-mark hold ros-jazzy-ros-base    # prevent auto-upgrade off the baseline
    fi
}

step_6_dev_tools() {
    sudo apt install -y ros-dev-tools
}

step_7_report() {
    # source may reference unbound ament vars -- temporarily disable set -u
    set +u
    source /opt/ros/jazzy/setup.bash
    set -u
    printf 'ROS_DISTRO = %s\n' "${ROS_DISTRO:-<unset>}"
    ros2 doctor --report 2>/dev/null | grep -i "middleware name" || true
    printf 'ros-jazzy-ros-base installed version: %s\n' \
        "$(dpkg-query -W -f='${Version}' ros-jazzy-ros-base 2>/dev/null || echo '<not found>')"
}

# --- Main --------------------------------------------------------------------
printf 'ROS2 Jazzy base installer -- mode: '
if [ "$FLAG_INTERACTIVE" = "yes" ]; then
    printf 'interactive'
else
    printf 'non-interactive'
fi
printf ', version: '
if [ "$FLAG_LATEST" = "yes" ]; then
    printf 'latest upstream\n'
    step5_desc="Install ros-jazzy-ros-base (latest upstream)"
else
    printf 'fixed (%s)\n' "${ROS_FIXED_VERSION}"
    step5_desc="Install ros-jazzy-ros-base (fixed ${ROS_FIXED_VERSION})"
fi

run_step 1 "Set locale (UTF-8)"                          step_1_locale
run_step 2 "Enable universe repository"                  step_2_universe
run_step 3 "Add ROS2 apt source (ros2-apt-source deb)"   step_3_apt_source
run_step 4 "apt update && upgrade"                       step_4_update
run_step 5 "$step5_desc"                                 step_5_rosbase
run_step 6 "Install ros-dev-tools"                       step_6_dev_tools
run_step 7 "Report installation"                         step_7_report

printf '\nSUCCESS. All steps completed.\n'
printf 'NOTE: ROS2 is not yet active in this shell. Run: source /opt/ros/jazzy/setup.bash\n'
