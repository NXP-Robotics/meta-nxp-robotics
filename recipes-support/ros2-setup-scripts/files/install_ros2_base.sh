#!/usr/bin/env bash
#
# install_ros2_base
# One-shot ROS2 Jazzy base installer (always latest upstream).
#
# Mirrors the official ROS2 Jazzy deb install, step-by-step:
#   https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html
#
# USAGE:
#   install_ros2_base [-i] [-h]
#
#   (no flags)  Non-interactive: run all steps unattended, installs latest ros-jazzy-ros-base
#   -i          Interactive: prompt [Y/n] before each step
#   -h          Show this help and exit
#
set -eEuo pipefail
trap 'printf "\nERROR: Installation aborted at line %s. Fix the issue above and re-run the script.\nTip: use -i for step-by-step control (prompt before each step).\n" "$LINENO"' ERR

# --- Flags -------------------------------------------------------------------
FLAG_INTERACTIVE="no"

for arg in "$@"; do
    case "$arg" in
        -i) FLAG_INTERACTIVE="yes" ;;
        -h)
            printf 'Usage: install_ros2_base [-i] [-h]\n\n'
            printf '  (no flags)  Non-interactive: run all steps, install latest ros-jazzy\n'
            printf '  -i          Interactive: prompt [Y/n] before each step\n'
            printf '  -h          Show this help and exit\n'
            exit 0
            ;;
        *) printf 'Unknown flag: %s\nRun install_ros2_base -h for usage.\n' "$arg"; exit 1 ;;
    esac
done

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

# Check whether ros-jazzy-ros-base is already installed and decide what to do in step 5.
# Sets SKIP_ROSBASE=yes if the user declines the upgrade or if it is already at latest.
SKIP_ROSBASE="no"
check_ros_installed() {
    local installed latest_ver ans

    installed="$(dpkg-query -W -f='${Version}' ros-jazzy-ros-base 2>/dev/null || true)"
    [ -z "$installed" ] && return 0  # not installed, proceed with full install

    # Fetch latest candidate from apt (requires apt lists; best-effort).
    sudo apt-get update -qq 2>/dev/null || true
    latest_ver="$(apt-cache policy ros-jazzy-ros-base 2>/dev/null \
        | awk '/Candidate:/{print $2}')"

    if [ "$installed" = "$latest_ver" ]; then
        printf '\nros-jazzy-ros-base is already installed and up to date.\n'
        printf 'Installed version: %s. Skipping install step.\n' "$installed"
        SKIP_ROSBASE="yes"
        return 0
    fi

    printf '\nWARNING: ros-jazzy-ros-base is already installed.\n'
    printf '  Installed version : %s\n' "$installed"
    printf '  Latest version    : %s\n' "${latest_ver:-<unknown>}"
    printf '  This is NOT the latest version.\n\n'
    printf 'Upgrade to the latest version? [Y/n] (auto-upgrading in 10 seconds) '

    ans=""
    if read -r -t 10 ans 2>/dev/null; then
        ans="${ans:-y}"
    else
        printf '\n(Timeout reached, proceeding with upgrade.)\n'
        ans="y"
    fi

    case "$ans" in
        n|N)
            printf 'Upgrade skipped. Keeping installed version %s.\n' "$installed"
            SKIP_ROSBASE="yes"
            ;;
        *)
            printf 'Upgrading ros-jazzy-ros-base to latest...\n'
            ;;
    esac
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
    if [ "$SKIP_ROSBASE" = "yes" ]; then
        printf 'ros-jazzy-ros-base install/upgrade skipped.\n'
        return 0
    fi
    sudo apt-mark unhold ros-jazzy-ros-base || true  # release any hold from a previous run
    sudo apt install -y ros-jazzy-ros-base
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
printf ', version: latest upstream\n'

check_ros_installed

run_step 1 "Set locale (UTF-8)"                          step_1_locale
run_step 2 "Enable universe repository"                  step_2_universe
run_step 3 "Add ROS2 apt source (ros2-apt-source deb)"   step_3_apt_source
run_step 4 "apt update && upgrade"                       step_4_update
run_step 5 "Install ros-jazzy-ros-base (latest upstream)" step_5_rosbase
run_step 6 "Install ros-dev-tools"                       step_6_dev_tools
run_step 7 "Report installation"                         step_7_report

printf '\nSUCCESS. All steps completed.\n'
printf 'NOTE: ROS2 is not yet active in this shell. Run: source /opt/ros/jazzy/setup.bash\n'
