#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

# Clone the kernel repo
if ! git -C linux-rockchip pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" linux-rockchip --depth=2
fi

cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

# -----------------------------------------------------------
# 新增/修改：使用 Armbian 配置并调整 VA_BITS (使用 sed)
# -----------------------------------------------------------

# 1. 下载 Armbian 配置文件覆盖当前的 .config
echo "Downloading Armbian config..."
curl -sL "https://github.com/armbian/build/raw/main/config/kernel/linux-rk35xx-vendor.config" -o .config

sed -i 's/CONFIG_ARM64_VA_BITS_48=y/CONFIG_ARM64_VA_BITS_39=y/g' .config

# 3. 运行 olddefconfig 
# 解决之前遇到的非交互式配置中断问题
make olddefconfig

# -----------------------------------------------------------
# 配置修改完毕
# -----------------------------------------------------------

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true v=1
