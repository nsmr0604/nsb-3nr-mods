#!/usr/bin/env python3
"""Generate an opkg-compatible Packages index for the GitHub Pages feed.

Usage: python3 tools/make-index.py [feed_dir]
Reads *.ipk under <feed_dir>/bin and writes <feed_dir>/Packages and
<feed_dir>/Packages.gz.
"""
import gzip
import hashlib
import os
import subprocess
import sys
import tarfile
import io

feed = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "feed"
)
pkgdir = os.path.join(feed, "bin")


def ipk_control(path):
    data = subprocess.check_output(["ar", "p", path, "control.tar.gz"])
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        for name in ("./control", "control"):
            try:
                return tf.extractfile(name).read().decode("utf-8", "replace")
            except KeyError:
                pass
    raise RuntimeError("control not found in %s" % path)


paragraphs = []
for name in sorted(os.listdir(pkgdir)):
    if not name.endswith(".ipk"):
        continue
    path = os.path.join(pkgdir, name)
    raw = open(path, "rb").read()
    control = ipk_control(path)
    fields = {}
    for line in control.splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fields[k.strip()] = v.strip()
    lines = [
        "Package: %s" % fields.get("Package", name.split("_")[0]),
        "Version: %s" % fields.get("Version", "0"),
        "Depends: %s" % fields.get("Depends", ""),
        "Section: %s" % fields.get("Section", "misc"),
        "Priority: %s" % fields.get("Priority", "optional"),
        "Maintainer: %s" % fields.get("Maintainer", "unknown"),
        "Architecture: %s" % fields.get("Architecture", "all"),
        "Installed-Size: %s" % fields.get("Installed-Size", ""),
        "Filename: bin/%s" % name,
        "Size: %d" % len(raw),
        "MD5sum: %s" % hashlib.md5(raw).hexdigest(),
        "SHA256sum: %s" % hashlib.sha256(raw).hexdigest(),
        "Description: %s" % fields.get("Description", ""),
    ]
    paragraphs.append("\n".join(lines) + "\n")

out = "\n".join(paragraphs)
open(os.path.join(feed, "Packages"), "w").write(out)
with gzip.open(os.path.join(feed, "Packages.gz"), "wb") as f:
    f.write(out.encode())
print("wrote %d packages, %d bytes" % (len(paragraphs), len(out)))
