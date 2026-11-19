#!/bin/sh
set -e
ROOT="$HOME/opt/openssl"
TC="$HOME/opt/toolchains/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
STAGING="$TC/toolchain-arm_cortex-a9+neon_gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
export STAGING_DIR="$STAGING"
export PATH="$STAGING/bin:$PATH"
CC=arm-openwrt-linux-uclibcgnueabi-gcc
mkdir -p "$ROOT"
cd "$ROOT"

if [ ! -f openssl-1.0.2u.tar.gz ]; then
  echo "downloading openssl 1.0.2u ..."
  curl -fL --retry 3 --max-time 600 -o openssl-1.0.2u.tar.gz \
    https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz
fi
[ -d openssl-1.0.2u ] || tar xzf openssl-1.0.2u.tar.gz
cd openssl-1.0.2u

if [ ! -f Makefile ]; then
  ./Configure linux-armv4 \
    --cross-compile-prefix=arm-openwrt-linux-uclibcgnueabi- \
    --prefix=/usr --openssldir=/etc/ssl \
    -march=armv7-a -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=softfp \
    shared
fi
echo "=== configured ==="
grep -E '^CC=|^CFLAGS=|^SHAREDFLAGS' Makefile | head -4

make -j4 build_libs 2>&1 | tail -8
echo "=== outputs ==="
ls -l libssl.so.1.0.0 libcrypto.so.1.0.0 2>/dev/null
file libssl.so.1.0.0 libcrypto.so.1.0.0 2>/dev/null
$STAGING/bin/arm-openwrt-linux-uclibcgnueabi-readelf -d libcrypto.so.1.0.0 2>/dev/null | grep -E 'SONAME|NEEDED' | head -5
