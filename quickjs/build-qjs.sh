#!/bin/sh
set -e
CROSS="$HOME/opt/cross/arm-linux-musleabihf-cross/bin/arm-linux-musleabihf-"
DIR="$HOME/opt/quickjs/quickjs-2024-01-13"
cd "$DIR"
make clean >/dev/null 2>&1 || true
make -j2 CROSS_PREFIX="$CROSS" HOST_CC=gcc LDFLAGS="-static" LIBS="-lm -ldl -lpthread -latomic" qjs
file qjs
ls -lh qjs
