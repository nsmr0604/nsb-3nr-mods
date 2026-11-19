#!/bin/bash
for port in 443 8443; do
  echo "=== port $port ciphers (TLS1.2) ==="
  for c in RC4 3DES MD5 AES128-SHA AES256-SHA HIGH; do
    out=$(timeout 5 openssl s_client -connect 192.168.2.200:$port -tls1_2 -cipher "$c:@SECLEVEL=0" -brief </dev/null 2>&1 | head -2 | tr '\n' ' ')
    case "$out" in
      *Ciphersuite*) echo "$c : ACCEPTED $(echo "$out" | grep -o 'Ciphersuite:[^ ]*' | head -1)" ;;
      *) echo "$c : rejected" ;;
    esac
  done
done
