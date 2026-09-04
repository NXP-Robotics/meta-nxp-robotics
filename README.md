NXP Linux Yocto Project BSP for robotics platforms
==================================================

About
-----

This Yocto meta layer contains all of the required packages for building
a Desktop PoC image for NXP's robotics platforms.

Supported platforms
-------------------

This meta layer supports the following platforms:


| Platform name  |  Yocto MACHINE name |
|:--------------:|:-------------------:|
| MR-NAVQ95      |  imx95-navqdesktop  |

Supported images
----------------

This meta layer supports the following images:

1. imx-image-mr

Supported distributions
-----------------------

The only supported distribution is `imx-desktop-xwayland`.

Quick start quide
-----------------

### Install the required host packages

```sh
sudo apt-get install build-essential chrpath cpio debianutils diffstat file gawk \
	gcc git iputils-ping libacl1 libcrypt-dev locales python3 python3-git python3-jinja2 \
	python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd efitools
```

### Install the `repo` utility

This tool is required to pull all of the meta layers:

```sh
mkdir ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

### Initialize the manifest repository and pull all meta layers

```sh
mkdir imx-yocto-bsp
cd imx-yocto-bsp
repo init -u https://github.com/nxp-mobilerobotics/imx-manifest-navq95 -b imx-linux-wrynose -m imx-6.18.20-2.0.0-navq.xml
repo sync
```

### Build the image

```sh
DISTRO=imx-desktop-xwayland MACHINE=<machine_name> source imx-setup-release.sh -b build
bitbake <image_name>
```

where:

1. `machine_name` is taken from [Supported platforms](#supported-platforms)
2. `image_name` is taken from [Supported images](#supported-images)

For example:

```sh
DISTRO=imx-desktop-xwayland MACHINE=imx95-navqdesktop source imx-setup-release.sh -b build
bitbake imx-image-mr
```

will build the `imx-image-mr` image for the `imx95-navqdesktop` machine (MR-NAVQ95 platform).

Note
----
The default build will create the account `user` with the password `user`.
To add another account, you can add the following line to `<build_dir>/conf/local.conf`:

```
APTGET_ADD_USERS:append = " user1:<password hash>:${USER_SHELL_BASH} user2:<password hash>:${USER_SHELL_BASH}"
```

**📝 Note:** Each user entry should be separated by a whitespace.

To generate the password hash:

```
openssl passwd -1 <your_password_in_clear_text>
```

For example:

```
openssl passwd -1 ab123
```

will return: `$1$FP6PEJWC$e7l2p4w5ek4XDRRrdAwIo/`. Replace `password_hash` with this value.

**📝 Note:** If the value contains "$", make sure to escape it: `\\$`!
