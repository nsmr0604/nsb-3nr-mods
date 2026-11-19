#!/bin/sh
# mkpkg.sh — OpenWrt(opkg 0.1.8) 用 .ipk を作る最小ツール
#
#   使い方: mkpkg.sh <パッケージディレクトリ> [出力ディレクトリ]
#
# パッケージディレクトリの構成:
#   meta       (必須) PKG_NAME / PKG_VERSION / PKG_DESC などを定義するシェル
#   build.sh   (任意) ステージング ($PKG_ROOT) にファイルを作るビルドスクリプト。
#                    無ければ何もしない (files/ のコピーのみ)
#   files/     (任意) $PKG_ROOT へそのままコピーするファイル群
#   preinst/postinst/prerm/postrm/conffiles (任意) control.tar.gz に同梱
#
# .ipk = ar アーカイブ (debian-binary, control.tar.gz, data.tar.gz)
set -e
unset CDPATH

PKGDIR=$(cd "$1" && pwd)
OUTDIR=${2:-$PKGDIR/out}
mkdir -p "$OUTDIR"
OUTDIR=$(cd "$OUTDIR" && pwd)

. "$PKGDIR/meta"
: "${PKG_NAME:?PKG_NAME 未定義}"
: "${PKG_VERSION:?PKG_VERSION 未定義 (例: 1.0-1)}"
PKG_ARCH=${PKG_ARCH:-${IPK_ARCH:-arm_cortex-a9_neon}}
PKG_SECTION=${PKG_SECTION:-utils}
PKG_PRIORITY=${PKG_PRIORITY:-optional}
PKG_MAINTAINER=${PKG_MAINTAINER:-x@windows-nas-access}
PKG_DEPENDS=${PKG_DEPENDS:-}
PKG_PROVIDES=${PKG_PROVIDES:-}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ipk.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

PKG_ROOT="$WORK/root"
CONTROL_ROOT="$WORK/control"
mkdir -p "$PKG_ROOT" "$CONTROL_ROOT"

# --- ビルド (ステージング) ---
if [ -f "$PKGDIR/build.sh" ]; then
    ( cd "$PKGDIR" && PKG_ROOT="$PKG_ROOT" PKG_BUILD="$WORK/build" sh ./build.sh )
else
    if [ -d "$PKGDIR/files" ]; then
        ( cd "$PKGDIR/files" && tar cf - . ) | ( cd "$PKG_ROOT" && tar xf - )
    fi
fi

# --- control ---
INSTALLED_SIZE=$(du -sk "$PKG_ROOT" | awk '{print $1}')
{
    echo "Package: $PKG_NAME"
    echo "Version: $PKG_VERSION"
    [ -n "$PKG_DEPENDS" ] && echo "Depends: $PKG_DEPENDS"
    [ -n "$PKG_PROVIDES" ] && echo "Provides: $PKG_PROVIDES"
    echo "Section: $PKG_SECTION"
    echo "Priority: $PKG_PRIORITY"
    echo "Maintainer: $PKG_MAINTAINER"
    echo "Architecture: $PKG_ARCH"
    echo "Installed-Size: $INSTALLED_SIZE"
    echo "Description: $PKG_DESC"
} > "$CONTROL_ROOT/control"

for f in conffiles preinst postinst prerm postrm; do
    [ -f "$PKGDIR/$f" ] && cp "$PKGDIR/$f" "$CONTROL_ROOT/$f"
done
chmod 755 "$CONTROL_ROOT"/* 2>/dev/null || true
[ -f "$CONTROL_ROOT/control" ] && chmod 644 "$CONTROL_ROOT/control"
[ -f "$CONTROL_ROOT/conffiles" ] && chmod 644 "$CONTROL_ROOT/conffiles"

# --- ar アーカイブ化 ---
printf '2.0\n' > "$WORK/debian-binary"
( cd "$CONTROL_ROOT" && tar --numeric-owner --owner=0 --group=0 -czf "$WORK/control.tar.gz" . )
( cd "$PKG_ROOT"     && tar --numeric-owner --owner=0 --group=0 -czf "$WORK/data.tar.gz" . )

PKGFILE="$OUTDIR/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk"
rm -f "$PKGFILE"
( cd "$WORK" && ar rc "$PKGFILE" debian-binary control.tar.gz data.tar.gz )
echo "built: $PKGFILE"
ar t "$PKGFILE" | sed 's/^/  member: /'
