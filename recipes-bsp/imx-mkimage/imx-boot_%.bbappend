FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
	file://0001-i.MX95-Uboot-SPL-Relocate-to-DDR.patch \
"

# break dependency on imx-m7-demos package since it's not needed
IMX_M4_DEMOS:mx95-nxp-bsp = ""

ERROR_QA:remove = "patch-status"

do_configure[depends] += "zephyr-mcuboot:do_deploy"

do_configure:append () {
        mkdir -p ${DEPLOY_DIR_IMAGE}/mcore-demos/
        cp ${TOPDIR}/tmp/m7_mcuboot_image.bin ${DEPLOY_DIR_IMAGE}/mcore-demos/
}
