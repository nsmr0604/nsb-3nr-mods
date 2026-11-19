#!/bin/sh
cd "$HOME/opt/openssl/openssl-1.0.2u"
sed -n '1,60p' Makefile | grep -iE 'CFLAGS|SHARED|CC|TARGET|CROSS' | head -20
echo "--- crypto ---"
grep -iE 'CFLAGS=|SHAREDFLAGS=' crypto/Makefile | head -10
