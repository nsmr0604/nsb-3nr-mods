#!/bin/sh
set -e
BASE="$HOME/opt/openssl"
SRC="$BASE/openssl-1.0.2u"
DST="$BASE/openssl-1.0.2u-backported"
PATCHROOT="$BASE/debian-patches/debian/patches"
rm -rf "$DST"
cp -a "$SRC" "$DST"
cd "$DST"

# Debian stretch openssl1.0 1.0.2u-1~deb9u7 のセキュリティパッチのみ適用
PATTERNS='CVE-2020-1968|CVE-2020-1971|DirectoryString-is-a-CHOICE|Correctly-compare-EdiPartyName|Check-that-multi-strings|Complain-if-we-are-attempting|Add-a-test-for-GENERAL_NAME_cmp|CVE-2021-23840|CVE-2021-23841|CVE-2021-3712|CVE-2022-0778|Check-chain-extensions'
ok=0; fail=0
for f in $(grep -Ei "$PATTERNS" "$PATCHROOT/series"); do
  p="$PATCHROOT/$f"
  if [ ! -f "$p" ]; then echo "MISSING $f"; fail=$((fail+1)); continue; fi
  if patch -p1 --forward --silent < "$p" >/tmp/patch.log 2>&1; then
    ok=$((ok+1))
  else
    echo "FAILED $f"; head -4 /tmp/patch.log; fail=$((fail+1))
  fi
done
echo "APPLIED=$ok FAILED=$fail"
grep -iE 'CVE-2020-1968|CVE-2020-1971|CVE-2022-0778' CHANGES | head -5
