
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRCBRANCH = "imx95-navq-lf-6.18.y-Q2"
UBOOT_SRC = "git://git@github.com/NXP-Robotics/uboot-imx.git;protocol=https;branch=${SRCBRANCH}"
SRCREV = "0ebf4f19a3d99add0673f704f20e5bb903908df4"

SRC_URI:append:imx95-navq = " \
    file://${TARGET_NAME}.cfg \
"
