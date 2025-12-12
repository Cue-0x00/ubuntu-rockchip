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
# 修改开始：使用 Armbian 配置并调整 VA_BITS
# -----------------------------------------------------------

# 1. 下载 Armbian 配置文件覆盖当前的 .config
echo "Downloading Armbian config..."
curl -sL "https://github.com/armbian/build/raw/main/config/kernel/linux-rk35xx-vendor.config" -o .config

# 2. 使用 scripts/config 工具安全地修改配置
# 相比 sed，这个工具能处理依赖关系，更安全
echo "Setting CONFIG_ARM64_VA_BITS=39..."
./scripts/config --enable CONFIG_ARM64_VA_BITS_39
./scripts/config --disable CONFIG_ARM64_VA_BITS_48
./scripts/config --set-val CONFIG_ARM64_VA_BITS 39

# 3. 运行 olddefconfig 
# 这会清理配置文件，计算依赖，并确保所有新选项都有默认值（非交互式）
make olddefconfig

# -----------------------------------------------------------
# 修改结束
# -----------------------------------------------------------

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true v=1
