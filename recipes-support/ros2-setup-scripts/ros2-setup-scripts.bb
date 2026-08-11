SUMMARY = "ROS2 environment setup scripts for NavQ95"
DESCRIPTION = "Deploys ROS2 environment setup scripts to the rootfs"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "file://install_ros2_base.sh"

inherit allarch

do_install() {
    install -d ${D}${bindir}
    install -m 755 ${UNPACKDIR}/install_ros2_base.sh ${D}${bindir}/install_ros2_base
}

FILES:${PN} += "${bindir}/install_ros2_base"
