#!/bin/sh
set -e
TC="$HOME/opt/toolchains/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
STAGING="$TC/toolchain-arm_cortex-a9+neon_gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
export STAGING_DIR="$STAGING"
export PATH="$STAGING/bin:$PATH"
cd "$HOME/opt/openssl/openssl-1.0.2u"
rm -f Makefile
./Configure linux-armv4 \
  --cross-compile-prefix=arm-openwrt-linux-uclibcgnueabi- \
  --prefix=/usr --openssldir=/etc/ssl \
  -march=armv7-a -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=softfp \
  shared > /tmp/openssl-conf.log 2>&1
tail -4 /tmp/openssl-conf.log
echo "=== after ==="
grep -E '^(CC|CFLAGS|SHAREDFLAGS|TARGET)=' Makefile | head -5
