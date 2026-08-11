
SRCBRANCH = "imx95-navq-lf-6.18.y-26Q2"
IMX_SYSTEM_MANAGER_SRC = "git://git@github.com/NXP-Robotics/imx-sm.git;protocol=https;branch=${SRCBRANCH}"
SRCREV = "958f60f7487be334cc117c1cd3f89ad9e6a0fec4"

LIC_FILES_CHKSUM = "file://LICENSE.txt;md5=f2a70813bc08547f509361c08b718861"

do_configure:prepend() {
    # Remove comments from all files in configs to fix the configtool parsing bugs
    for f in ${S}/configs/*.cfg; do
        [ -f "$f" ] && sed -i 's/#.*//' "$f"
    done
}
