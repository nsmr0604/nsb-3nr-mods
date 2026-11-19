#!/bin/sh
cd "$HOME/opt/openssl"
for url in \
  'https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_1_0_2w.tar.gz' \
  'https://github.com/openssl/openssl/releases/download/OpenSSL_1_0_2w/openssl-1.0.2w.tar.gz' \
  'https://www.openssl.org/source/openssl-1.0.2w.tar.gz'; do
  echo "try $url"
  code=$(curl -sL -o /tmp/t.tgz -w '%{http_code} %{size_download}' --max-time 120 "$url")
  echo "  -> $code"
  if [ "$(stat -c%s /tmp/t.tgz)" -gt 1000000 ]; then
    cp /tmp/t.tgz openssl-1.0.2w.tar.gz
    echo "GOT IT $(stat -c%s openssl-1.0.2w.tar.gz)"
    break
  fi
done
