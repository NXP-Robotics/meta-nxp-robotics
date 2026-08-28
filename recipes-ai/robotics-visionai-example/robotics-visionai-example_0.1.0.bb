SUMMARY = "Vision AI web viewer for MR-NavQ95 (camera -> inference -> MJPEG)"
DESCRIPTION = "Captures from the attached CSI camera, runs inference on the \
Kinara ARA2 accelerator, the i.MX Neutron NPU, the Vivante GPU or the CPU, \
and streams the annotated video as MJPEG plus JSON stats to a browser. \
Provides the 'robotics-visionai-example' command."
HOMEPAGE = "https://bitbucket.sw.nxp.com/projects/TARS/repos/robotics-visionai-example"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE;md5=d8ff2d641cc45adce1b1882be29d1e35"

SRC_URI = "${ROBOTICS_VISIONAI_EXAMPLE_SRC};branch=${SRCBRANCH}"
ROBOTICS_VISIONAI_EXAMPLE_SRC ?= "git://bitbucket.sw.nxp.com/tars/robotics-visionai-example.git;protocol=ssh;user=git"
SRCBRANCH = "robotics-0.7.0"

SRCREV = "f4f8ee1885e90397d4704ba6f1fe0698f77a3c7c"

inherit python_setuptools_build_meta allarch

APP_DIR = "${datadir}/${BPN}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/robotics-visionai-example ${D}${bindir}

    install -d ${D}${datadir}/python-wheels
    install -m 0644 ${UNPACKDIR}/../dist/*.whl ${D}${datadir}/python-wheels

    install -d ${D}${APP_DIR}
    install -m 0755 ${S}/install.sh ${D}${APP_DIR}/install.sh
    install -m 0644 ${S}/README.md  ${D}${APP_DIR}/README.md

    install -d ${D}${docdir}/${BPN}
    install -m 0644 ${S}/README.md ${D}${docdir}/${BPN}/README.md
}

FILES:${PN} += " \
	${datadir}/python-wheels \
	${APP_DIR} \
	${docdir}/${BPN} \
"

pkg_postrm:${PN} () {
	rm -rf ${APP_DIR}/venv
}

RDEPENDS:${PN} = " \
	bash \
    imx-nxp-ara2 \
"
COMPATIBLE_MACHINE = "(imx95-navq)"
