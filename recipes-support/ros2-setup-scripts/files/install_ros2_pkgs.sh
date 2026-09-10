#!/usr/bin/env bash
#
# install_ros2_pkgs.sh
# One-shot ROS2 Jazzy packages installer for NavQ95.
#
# Installs a set of additional ROS2 packages on top of a ROS2 base +
# environment setup (see install_ros2_base and install_ros2_env).
#
# USAGE:
#   install_ros2_pkgs [-i] [-l] [--all-px4-msgs] [-h]
#
#   (no flags)  Non-interactive: install all packages unattended at their
#               fixed versions.
#   -i          Interactive: prompt [Y/n] before each package
#   -l          Latest: install latest upstream packages (ignores fixed versions)
#   --all-px4-msgs  Build every px4_msgs message instead of the T1 subset
#   -h          Show this help and exit
#
#   Flags can be combined, e.g.: install_ros2_pkgs -i -l
#
set -eEuo pipefail
trap 'printf "\nERROR: Installation aborted at line %s. Fix the issue above and\n\
re-run the script.\nTip: use -i for step-by-step control (prompt before each step).\n" \
"$LINENO"' ERR

# ============================================================================
# Package lookup table (single source of truth).
#
# To add a package:
#   1. Add a ROS2PKG_<ID>_* block below (NAME, VERSION, INSTALL, REPORT, USAGE).
#   2. Append <ID> to ROS2PKG_IDS.
#   3. For a standard apt package, set INSTALL="pkg_install_apt". For a
#      non-standard install (e.g. git clone + colcon), add a bespoke
#      pkg_install_<id> function and point INSTALL at it.
#
#   NAME    - package / clone identifier
#   VERSION - fixed version (override by exporting ROS2PKG_<ID>_VERSION)
#   INSTALL - install function for this package (pkg_install_apt or a bespoke one)
#   REPORT  - command that prints the installed version
#   USAGE   - post-install tip (\n for multiple lines)
# ============================================================================
# demo-nodes-cpp: ROS2 demo nodes (talker/listener) — functional smoke test
ROS2PKG_DEMO_NODES_CPP_NAME="ros-jazzy-demo-nodes-cpp"
ROS2PKG_DEMO_NODES_CPP_VERSION="${ROS2PKG_DEMO_NODES_CPP_VERSION:-0.33.11-1noble.20260612.180159}"
ROS2PKG_DEMO_NODES_CPP_INSTALL="pkg_install_apt"
ROS2PKG_DEMO_NODES_CPP_REPORT="dpkg-query -W -f='\${Version}' ros-jazzy-demo-nodes-cpp"
ROS2PKG_DEMO_NODES_CPP_REPORT+=" 2>/dev/null || echo '<not found>'"
ROS2PKG_DEMO_NODES_CPP_USAGE="Try the demo talker/listener in two terminals"
ROS2PKG_DEMO_NODES_CPP_USAGE+=" (after sourcing your ROS2 env):"
ROS2PKG_DEMO_NODES_CPP_USAGE+="\n  ros2 run demo_nodes_cpp talker"
ROS2PKG_DEMO_NODES_CPP_USAGE+="\n  ros2 run demo_nodes_cpp listener"

# rosbag2: record and play back ROS2 topics
ROS2PKG_ROSBAG2_NAME="ros-jazzy-rosbag2"
ROS2PKG_ROSBAG2_VERSION="${ROS2PKG_ROSBAG2_VERSION:-0.26.11-1noble.20260612.202546}"
ROS2PKG_ROSBAG2_INSTALL="pkg_install_apt"
ROS2PKG_ROSBAG2_REPORT="dpkg-query -W -f='\${Version}' ros-jazzy-rosbag2"
ROS2PKG_ROSBAG2_REPORT+=" 2>/dev/null || echo '<not found>'"
ROS2PKG_ROSBAG2_USAGE="Record and play back topics (after sourcing your ROS2 env):"
ROS2PKG_ROSBAG2_USAGE+="\n  ros2 bag record -a -o <bag>"
ROS2PKG_ROSBAG2_USAGE+="\n  ros2 bag play <bag>"

# px4_msgs: PX4 uORB message definitions
ROS2PKG_PX4_MSGS_NAME="px4_msgs"
ROS2PKG_PX4_MSGS_VERSION="${ROS2PKG_PX4_MSGS_VERSION:-release/1.17}"
ROS2PKG_PX4_MSGS_INSTALL="pkg_install_px4_msgs"
ROS2PKG_PX4_MSGS_REPORT="git -C \"\$HOME/ros2_ws/src/px4_msgs\" rev-parse --abbrev-ref HEAD"
ROS2PKG_PX4_MSGS_REPORT+=" 2>/dev/null || echo '<not found>'"
ROS2PKG_PX4_MSGS_USAGE="Source the workspace overlay before use:"
ROS2PKG_PX4_MSGS_USAGE+="\n  source ~/ros2_ws/install/setup.bash"

# Ordered list of package ids to process (one <ID> per ROS2PKG_<ID>_* block above).
ROS2PKG_IDS=(
    "DEMO_NODES_CPP"
    "ROSBAG2"
    "PX4_MSGS"
)

# --- Lookup-table accessors --------------------------------------------------
# Read a field from the package lookup table.
# pkg_field <ID> <FIELD>  ->  prints ROS2PKG_<ID>_<FIELD>
pkg_field() {
    local var="ROS2PKG_$1_$2"
    printf '%s' "${!var}"
}

# Resolve a package NAME to its <ID> (prints the id, or nothing if unknown).
# pkg_id_by_name <package-name>
pkg_id_by_name() {
    local want="$1" id
    for id in "${ROS2PKG_IDS[@]}"; do
        if [ "$(pkg_field "$id" NAME)" = "$want" ]; then
            printf '%s' "$id"
            return 0
        fi
    done
    return 1
}

# --- Flags & package selection ----------------------------------------------
FLAG_INTERACTIVE="no"
FLAG_LATEST="no"
FLAG_ALL_PX4_MSGS="no"
SELECTED_NAMES=()   # package names requested on the CLI (empty = all)

for arg in "$@"; do
    case "$arg" in
        -i) FLAG_INTERACTIVE="yes" ;;
        -l) FLAG_LATEST="yes" ;;
        --all-px4-msgs) FLAG_ALL_PX4_MSGS="yes" ;;
        -h)
            printf 'Usage: install_ros2_pkgs [-i] [-l] [--all-px4-msgs] [-h] [package ...]\n\n'
            printf '  (no args)   Non-interactive: install all packages unattended\n'
            printf '              at their fixed versions.\n'
            printf '  package ... Install only the named package(s); default is all.\n'
            printf '  -i          Interactive: prompt [Y/n] before each package\n'
            printf '  -l          Latest: install latest upstream packages\n'
            printf '              (ignores fixed versions)\n'
            printf '  --all-px4-msgs  Build every px4_msgs message definition instead\n'
            printf '              of only those needed for the T1 usecase\n'
            printf '  -h          Show this help and exit\n\n'
            printf 'Packages to install (fixed version):\n'
            for id in "${ROS2PKG_IDS[@]}"; do
                printf '  %-30s(%s)\n' "$(pkg_field "$id" NAME)" "$(pkg_field "$id" VERSION)"
            done
            printf '\nExamples:\n'
            printf '  install_ros2_pkgs                        # install all packages\n'
            printf '  install_ros2_pkgs ros-jazzy-rosbag2      # install only the named package\n'
            printf '  install_ros2_pkgs -i                     # prompt before each package\n'
            printf '  install_ros2_pkgs -i -l px4_msgs         # flags and packages combine\n'
            printf '  install_ros2_pkgs --all-px4-msgs         # build all px4_msgs messages\n'
            exit 0
            ;;
        -*) printf 'Unknown flag: %s\nRun install_ros2_pkgs -h for usage.\n' "$arg"; exit 1 ;;
        *)  SELECTED_NAMES+=("$arg") ;;
    esac
done

# Resolve the requested package names to ids; default to all when none given.
SELECTED_IDS=()   # package ids to install this run (resolved from SELECTED_NAMES, or all)
if [ "${#SELECTED_NAMES[@]}" -eq 0 ]; then
    SELECTED_IDS=("${ROS2PKG_IDS[@]}")
else
    for name in "${SELECTED_NAMES[@]}"; do
        id="$(pkg_id_by_name "$name")" || {
            printf 'Unknown package: %s\n' "$name"
            printf 'Known packages:\n'
            for kid in "${ROS2PKG_IDS[@]}"; do printf '  %s\n' "$(pkg_field "$kid" NAME)"; done
            exit 1
        }
        SELECTED_IDS+=("$id")
    done
fi

# Prerequisite: ROS2 base must be installed (see install_ros2_base)
# Override ROS_SETUP_BASH before running to point at a different ROS2 install.
ROS_SETUP_BASH="${ROS_SETUP_BASH:-/opt/ros/jazzy/setup.bash}"
if [ ! -f "$ROS_SETUP_BASH" ]; then
    printf 'ERROR: ROS2 Jazzy not found (%s missing).\n' "$ROS_SETUP_BASH"
    printf 'Run install_ros2_base first.\n'
    exit 1
fi

# -l: fixed versions are ignored
if [ "$FLAG_LATEST" = "yes" ]; then
    printf -- 'WARNING: -l (latest) specified, latest upstream packages will be installed\n'
    printf -- '         (ignoring the fixed ROS2PKG_*_VERSION versions).\n'
fi

INSTALLED_IDS=()   # packages installed this run (populated on success; used by report/usage)

# ============================================================================
# Generic helpers (do not change when adding a package)
# ============================================================================

# pkg_run_install <ID> <DESC> <FN>
# Runs the install function (passing <ID> to it); on success records <ID> in
# INSTALLED_IDS. A skipped package (interactive 'n') returns before the install
# and is not recorded; a failed install aborts the script via the ERR trap.
pkg_run_install() {
    local id="$1" desc="$2" fn="$3" ans="y"
    if [ "$FLAG_INTERACTIVE" = "yes" ]; then
        printf '\n%s  [Y/n] ' "$desc"
        read -r ans || ans="y"
        ans="${ans:-y}"
        case "$ans" in
            n|N) printf '%s: SKIPPED\n' "$desc"; return 0 ;;
        esac
    else
        printf '\n=== %s ===\n' "$desc"
    fi
    "$fn" "$id"
    INSTALLED_IDS+=("$id")
}

# Report installed versions for the packages installed this run.
pkg_report() {
    local id name report
    printf '\n=== Report installation ===\n'
    for id in "${INSTALLED_IDS[@]}"; do
        name="$(pkg_field "$id" NAME)"
        report="$(pkg_field "$id" REPORT)"
        printf '%s installed version: %s\n' "$name" "$(eval "$report")"
    done
}

# Print post-install usage tips for the packages installed this run.
pkg_usage() {
    local id name
    for id in "${INSTALLED_IDS[@]}"; do
        name="$(pkg_field "$id" NAME)"
        printf '\n=== Usage: %s ===\n' "$name"
        printf '%b\n' "$(pkg_field "$id" USAGE)"
    done
}

# ============================================================================
# Reusable install functions (referenced by a package's INSTALL field)
# ============================================================================

# pkg_install_apt <ID>
# Generic apt installer: installs NAME at the fixed VERSION and holds it,
# or the latest upstream when -l is given. Use this for any package that is
# installed the standard apt way (most packages).
pkg_install_apt() {
    local id="$1" name version
    name="$(pkg_field "$id" NAME)"
    version="$(pkg_field "$id" VERSION)"
    sudo apt update
    sudo apt-mark unhold "$name" || true  # release any hold from a previous run
    if [ "$FLAG_LATEST" = "yes" ]; then
        sudo apt install -y "$name"
    else
        sudo apt install -y "${name}=${version}"
        sudo apt-mark hold "$name"
    fi
}

# ============================================================================
# Package-specific install functions (only for non-standard installs, e.g.
# git clone + colcon build). Standard apt packages use pkg_install_apt above.
# ============================================================================

# pkg_install_px4_msgs <ID>
# Build px4_msgs from source: fresh clone of the requested branch (VERSION),
# then colcon build into ~/ros2_ws. With -l, clone the default branch (main).
# The px4_msgs source is always re-cloned so the checked-out branch matches the
# request; only src/px4_msgs is removed (the rest of the workspace is kept).
pkg_install_px4_msgs() {
    local id="$1" branch ws url dst
    branch="$(pkg_field "$id" VERSION)"
    ws="${HOME}/ros2_ws"
    url="https://github.com/PX4/px4_msgs.git"
    dst="${ws}/src/px4_msgs"
    printf 'NOTE: px4_msgs is built from source with colcon -- this may take a while.\n'
    mkdir -p "${ws}/src"
    rm -rf "$dst"
    if [ "$FLAG_LATEST" = "yes" ]; then
        git clone --depth 1 "$url" "$dst"
    else
        git clone --depth 1 --branch "$branch" "$url" "$dst"
    fi
    # Build only msg/DistanceSensor and msg/Sensor*: px4_msgs globs msg/*.msg
    # and srv/*.srv, so removing the rest from the clone reduces the package.
    if [ "$FLAG_ALL_PX4_MSGS" = "no" ]; then
        find "$dst/msg" -name '*.msg' ! -name 'DistanceSensor.msg' ! -name 'Sensor*.msg' -delete
        find "$dst/srv" -name '*.srv' -delete
        printf 'WARNING: This script only builds necessary messages for the T1 usecase.\n'
        printf '         For full message support, rerun with --all-px4-msgs.\n'
    fi
    printf 'Building px4_msgs with %s messages.\n' "$(find "$dst/msg" -name '*.msg' | wc -l)"
    # colcon needs the ROS2 build system (ament_cmake) sourced, which the
    # prerequisite check does not guarantee. Source it if not already active.
    if [ -z "${AMENT_PREFIX_PATH:-}" ]; then
        set +u                # ROS setup files reference some unset vars
        # shellcheck disable=SC1090
        source "$ROS_SETUP_BASH"
        set -u
    fi
    ( cd "$ws" && colcon build --packages-select px4_msgs --cmake-args -DBUILD_TESTING=OFF )
}

# ============================================================================
# Main
# ============================================================================
printf 'ROS2 Jazzy package installer -- mode: '
if [ "$FLAG_INTERACTIVE" = "yes" ]; then
    printf 'interactive'
else
    printf 'non-interactive'
fi
printf ', version: '
if [ "$FLAG_LATEST" = "yes" ]; then
    printf 'latest upstream packages\n'
else
    printf 'fixed versions\n'
fi

# Install (loop over the selected packages)
for id in "${SELECTED_IDS[@]}"; do
    name="$(pkg_field "$id" NAME)"
    if [ "$FLAG_LATEST" = "yes" ]; then
        desc="Install ${name} (latest upstream)"
    else
        desc="Install ${name} (fixed $(pkg_field "$id" VERSION))"
    fi
    pkg_run_install "$id" "$desc" "$(pkg_field "$id" INSTALL)"
done

pkg_report

printf '\nSUCCESS. All requested packages completed.\n'

pkg_usage
