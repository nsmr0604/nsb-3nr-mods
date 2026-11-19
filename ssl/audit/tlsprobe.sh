#!/bin/bash
HOST=192.168.2.200
for port in 443 8443; do
  echo "=== port $port ==="
  for v in -ssl3 -tls1 -tls1_1 -tls1_2 -tls1_3; do
    out=$(timeout 6 openssl s_client -connect $HOST:$port $v -cipher 'DEFAULT:@SECLEVEL=0' -brief </dev/null 2>&1 | head -3 | tr '\n' ' ')
    case "$out" in
      *Protocol\ is*|*Ciphersuite*|*Verification*) echo "$v : OK $out" | cut -c1-160 ;;
      *) echo "$v : FAIL $(echo "$out" | cut -c1-120)" ;;
    esac
  done
done
