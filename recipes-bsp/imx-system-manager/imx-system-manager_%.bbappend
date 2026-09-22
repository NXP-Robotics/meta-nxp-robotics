
SRCBRANCH = "robotics-0.7.0"
IMX_SYSTEM_MANAGER_SRC = "git://git@github.com/nxp-robotics/robotics-sm.git;protocol=https;branch=${SRCBRANCH}"
SRCREV = "13a4387592b3afb7897858004facd10813e16004"

LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=f2a70813bc08547f509361c08b718861"

do_configure:prepend() {
    # Remove comments from all files in configs to fix the configtool parsing bugs
    for f in ${S}/configs/*.cfg; do
        [ -f "$f" ] && sed -i 's/#.*//' "$f"
    done
}
