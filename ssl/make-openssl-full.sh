#!/bin/sh
set -e
TC="$HOME/opt/toolchains/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
STAGING="$TC/toolchain-arm_cortex-a9+neon_gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
export STAGING_DIR="$STAGING"
export PATH="$STAGING/bin:$PATH"
cd "$HOME/opt/openssl/openssl-1.0.2u"
make clean >/dev/null 2>&1 || true
make -j4 > /tmp/openssl-make-full.log 2>&1 || { tail -25 /tmp/openssl-make-full.log; exit 1; }
tail -4 /tmp/openssl-make-full.log
echo "=== outputs ==="
ls -l libssl.so.1.0.0 libcrypto.so.1.0.0 apps/openssl
file libssl.so.1.0.0 libcrypto.so.1.0.0
$STAGING/bin/arm-openwrt-linux-uclibcgnueabi-readelf -d libcrypto.so.1.0.0 | grep -E 'SONAME|NEEDED' | head -4
