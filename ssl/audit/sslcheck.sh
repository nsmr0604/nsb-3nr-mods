#!/bin/sh
echo "=== openssl ==="
openssl version -a 2>/dev/null | head -4
echo "=== stunnel cfg ==="
cat /root/celestial_NAS/stunnel/dev_https 2>/dev/null
echo "=== stunnel cert ==="
openssl x509 -in /root/celestial_NAS/stunnel/stunnel.pem -noout -subject -issuer -dates -text 2>/dev/null | grep -E 'Subject:|Issuer:|Not Before|Not After|Public-Key|Signature Algorithm|DNS:' | head -12
echo "=== lighttpd ssl cfg ==="
grep -rn -iE 'ssl\.|ssl ' /etc/lighttpd 2>/dev/null | head -20
echo "=== sshd cfg ==="
grep -iE 'Protocol|Ciphers|MACs|KexAlgorithms|HostKey|PermitRootLogin|PasswordAuthentication|UsePAM|PermitEmptyPasswords' /etc/ssh/sshd_config 2>/dev/null | head -25
echo "=== ssh host keys ==="
ls -l /etc/ssh/ssh_host_* 2>/dev/null | head -10
