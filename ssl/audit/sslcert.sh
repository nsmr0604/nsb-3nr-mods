#!/bin/sh
echo "=== lighttpd ssl dir ==="
ls -l /etc/lighttpd/ssl/ 2>/dev/null | head -12
for f in /etc/lighttpd/ssl/*_combined.pem /etc/lighttpd/ssl/*_fullchain.pem; do
  [ -f "$f" ] || continue
  echo "--- $f"
  openssl x509 -in "$f" -noout -subject -issuer -dates -text 2>/dev/null | grep -E 'Subject:|Issuer:|Not Before|Not After|Public-Key|Signature Algorithm|DNS:' | head -10
done
