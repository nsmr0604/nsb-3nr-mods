#!/bin/bash
for port in 443 8443; do
 for opt in -tls1 -tls1_1 -tls1_2; do
  r=$(timeout 6 openssl s_client -connect 192.168.2.200:$port $opt </dev/null 2>&1 | grep -E '^New,|Protocol  :|Cipher    :' | tr '\n' ' ')
  echo "$port $opt -> ${r:-NO_OUTPUT}"
 done
done
