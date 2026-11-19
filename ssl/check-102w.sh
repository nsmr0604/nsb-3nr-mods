#!/bin/sh
cd "$HOME/opt/openssl"
for v in 1.0.2w 1.0.2v; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -I --max-time 20 "https://www.openssl.org/source/old/1.0.2/openssl-$v.tar.gz")
  echo "$v -> $code"
done
