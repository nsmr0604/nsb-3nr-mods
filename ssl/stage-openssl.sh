#!/bin/sh
set -e
SRC="$HOME/opt/openssl/openssl-1.0.2u"
OUT="/mnt/v/NAS/analysis/webui/openssl-out"
mkdir -p "$OUT/usr/lib" "$OUT/usr/bin"
cp "$SRC/libcrypto.so.1.0.0" "$SRC/libssl.so.1.0.0" "$OUT/usr/lib/"
cp "$SRC/apps/openssl" "$OUT/usr/bin/"
ls -lh "$OUT/usr/lib" "$OUT/usr/bin"
echo "=== readelf both ==="
TC="$HOME/opt/toolchains/OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
STAGING="$TC/toolchain-arm_cortex-a9+neon_gcc-4.8-linaro_uClibc-0.9.33.2_eabi"
"$STAGING/bin/arm-openwrt-linux-uclibcgnueabi-readelf" -d "$OUT/usr/lib/libssl.so.1.0.0" | grep -E 'SONAME|NEEDED'
