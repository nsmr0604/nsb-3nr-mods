#!/bin/sh
set -e
URL='http://dev.gateworks.com/openwrt/14.08/imx6/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi.tar.bz2'
DEST="$HOME/opt/toolchains"
mkdir -p "$DEST"
cd "$DEST"
F=$(basename "$URL")
if [ ! -f "$F" ]; then
  echo "downloading $F ..."
  curl -fL --retry 3 --max-time 1800 -o "$F" "$URL"
fi
ls -lh "$F"
echo "extracting..."
tar xjf "$F"
ls -d OpenWrt-Toolchain-* | head -3
find . -path '*/bin/*gcc' -name 'arm-openwrt-linux*gcc' | head -3
