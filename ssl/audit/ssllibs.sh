#!/bin/sh
echo "=== libssl files ==="
ls -l /usr/lib/libssl* /usr/lib/libcrypto* /lib/libssl* /lib/libcrypto* 2>/dev/null
echo "=== linked binaries ==="
for b in /usr/bin/openssl /usr/bin/stunnel /usr/sbin/sshd /usr/bin/curl /usr/bin/python /usr/sbin/lighttpd; do
  echo "--- $b"; ldd "$b" 2>/dev/null | grep -iE 'ssl|crypto|libc' | head -5
done
echo "=== openssl dir ==="
openssl version -d 2>/dev/null
echo "=== OPENSSL_CONF ==="
echo "$OPENSSL_CONF"
