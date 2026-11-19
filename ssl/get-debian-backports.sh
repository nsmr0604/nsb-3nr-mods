#!/bin/sh
set -e
cd /root/opt/openssl
URL='https://mirror-conova-archive.debian.org/debian-security/pool/updates/main/o/openssl1.0/openssl1.0_1.0.2u-1~deb9u7.debian.tar.xz'
[ -f debian-backports.tar.xz ] || curl -fkL --retry 3 --max-time 300 -o debian-backports.tar.xz "$URL"
ls -lh debian-backports.tar.xz
rm -rf debian-patches
mkdir debian-patches
tar xf debian-backports.tar.xz -C debian-patches
echo "=== patch files ==="
ls debian-patches/debian/patches | head -40
echo "=== series tail ==="
tail -25 debian-patches/debian/patches/series
