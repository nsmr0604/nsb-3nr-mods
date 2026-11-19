#!/bin/sh
set -e
SRC="$HOME/opt/openssl/openssl-1.0.2u-backported"
OUT="/mnt/v/NAS/analysis/webui/openssl-bp-out"
rm -rf "$OUT"
mkdir -p "$OUT/usr/lib" "$OUT/usr/bin"
cp "$SRC/libcrypto.so.1.0.0" "$SRC/libssl.so.1.0.0" "$OUT/usr/lib/"
cp "$SRC/apps/openssl" "$OUT/usr/bin/"
ls -lh "$OUT/usr/lib" "$OUT/usr/bin"
