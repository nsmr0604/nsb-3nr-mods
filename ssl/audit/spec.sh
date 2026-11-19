#!/bin/sh
echo "=== cpuinfo ==="
grep -m3 -E 'model name|Processor|Hardware|cpu MHz|cpu cores' /proc/cpuinfo 2>/dev/null || head -12 /proc/cpuinfo
echo "cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)"
echo "mem=$(grep MemTotal /proc/meminfo 2>/dev/null)"
echo "arch=$(uname -m) kernel=$(uname -r)"
echo "=== packages ==="
opkg list-installed 2>/dev/null | grep -iE 'node|python3|docker' | head -12
echo "=== available node/python3 ==="
opkg list 2>/dev/null | grep -iE '^node|^nodejs|^npm|^python3 ' | head -12
echo "=== overlay ==="
df -h /overlay 2>/dev/null | tail -1
