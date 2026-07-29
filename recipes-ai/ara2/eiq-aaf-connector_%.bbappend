FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = "\
    file://0001-Fix-Python3.13-for-runtime-venv.patch \
"
