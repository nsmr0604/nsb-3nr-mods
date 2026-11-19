#!/bin/sh
set -e
TC="$HOME/opt/toolchains/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
STAGING="$TC/toolchain-arm_cortex-a9+neon_gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
export STAGING_DIR="$STAGING"
export PATH="$STAGING/bin:$PATH"
cd "$HOME/opt/openssl/openssl-1.0.2u"
make -j4 build_libs > /tmp/openssl-make.log 2>&1 || { tail -25 /tmp/openssl-make.log; exit 1; }
tail -5 /tmp/openssl-make.log
echo "=== outputs ==="
ls -l libssl.so.1.0.0 libcrypto.so.1.0.0
file libssl.so.1.0.0 libcrypto.so.1.0.0
$STAGING/bin/arm-openwrt-linux-uclibcgnueabi-readelf -d libcrypto.so.1.0.0 | grep -E 'SONAME|NEEDED' | head -5
