---
type: Reference
title: NSB-3xx ファームウェア公開ソース (nsmr0604/nsb-3xx) と実機構成の照合
description: 公開 GPL ソースの収録範囲と欠落物、Cortina CS752x (G2 / goldengate) のアーキテクチャ構成、カーネル・U-Boot・NAND レイアウト、実機 (homenas) との一致確認
generated: { by: agent, at: 2026-11-19T05:54:05Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# リポジトリ

- `https://github.com/nsmr0604/nsb-3xx` (master / 最終 push 2020-03-08 / 約 385MB / 141,109 ファイル)
- 説明: "Elecom NSB-3NR and NSB-3MS series Firemware sourcecode. GPL/LGPL licences"
- 取得先: **`V:\NAS\nsb-3xx`** (作業領域 `V:\NAS` 直下)
- **Windows ではチェックアウト不可**: `AppConfig-1.66/.../AppConfig::Args.0` のように
  ファイル名に `:` を含むため `git clone` は "unable to checkout working tree" で失敗する。
  `git ls-tree -r --name-only HEAD` → `V:\NAS\filelist.txt` (6.3MB) と
  `git show HEAD:<path>` で読む (Linux/WSL でクローンすれば作業ツリーも作れる)

# 収録範囲 (実測)

収録されているもの:
- OpenWrt パッケージのソース約 130 個 — samba 3.5.6 / netatalk 3.0.1 / proftpd 1.3.3 /
  vsftpd 3.0.2 / minidlna / transmission 2.20 / mdadm 2.6.7.2 / LVM2 / xfsprogs 3.1.7 /
  ntfs-3g / smartmontools 5.40 / nut 2.7.2 / p910nd / perl 5.10 + CGI 群 / mini_httpd 1.19 /
  openvpn 2.1.3 / libreswan 3.9 / accel-ppp 1.7.3 / udev / fuse + exfat / rsync / lsyncd
- `uClibc-0.9.32` / `busybox-1.17.3` / `u-boot-2009.11` / `linux-3.4` (3.4.86 + quilt 適用済み)
- ビルド生成物の一部: `linux-3.4/.config` (76KB) と `linux-3.4/include/config/*` (kconfig ヘッダ)

**欠落 (このソースだけではファームは作れない)**:
- OpenWrt ビルドシステム本体 — `target/` `package/` `include/` `tools/` `scripts/`
  `rules.mk` `Config.in` が **すべて 0 件** (フラットに展開されたパッケージソースのみ)
- ターゲットプロファイル / イメージ生成 (A/B パッケージ・署名) スクリプト
- ベンダ固有アプリと Web UI のソース (`/nasmiru`, `/www-ms`, `/etc/config/csmi` 等)
- ツールチェーン本体 (実機は gcc 4.5.2 Linaro 2010.12 でビルド済み)

# アーキテクチャ構成 (アーキテクチャ = Cortina CS752x "G2")

| 項目 | 値 (ソース / 実機) |
|---|---|
| SoC | Cortina **CS752x** ("G2") — `CONFIG_CS752X`, `CONFIG_MACH_CORTINA_G2` |
| CPU | ARMv7 **Cortex-A9 ×2** (CPU part `0xc09` rev 1 / NEON / VFPv3 / SMP PREEMPT) |
| RAM | 1GB (`MemTotal: 890000 kB`) |
| ボード | Cortina "goldengate" リファレンス — `CONFIG_ARCH_GOLDENGATE` |
| カーネル | 3.4.86 (`Linux version 3.4.86 ... gcc 4.5.2 20101126 (Linaro)`, SMP PREEMPT) |
| libc | uClibc 0.9.32 |
| NIC | GMAC0/1/2 RGMII 1000 + GMAC1→外部スイッチ。HW アクセラレーション (IPsec / L2TP / PPTP / RTP proxy / NAT) |
| ストレージ | `CONFIG_CS752X_AHCI` (SATA) / MD RAID 0,1,5,6,10 / DM crypt,thin / XFS,ext4,UBIFS,squashfs |
| フラッシュ | NAND 512MB (`cs752x_nand_flash`, HW BCH ECC 8bit/512B, UBI 対応) |
| 実機の識別 | `Hardware: CORTINA-G2 EB` / hostname `homenas` / `fwversion 1.08` |

# カーネルパッチ構成 (`linux-3.4/patches/platform-cs-unified/`)

| パッチ | 役割 |
|---|---|
| `1000-linux-3.4.86.patch` (4.2MB) | 3.4.86 への更新差分 |
| `2000-cortina-3.4.patch` | Cortina BSP: `arch/arm/mach-goldengate/*` (`cortina-g2.c`, SMP/hotplug, ACP, global timer)、`serial_cortina.c`、CS752x ドライバ群 |
| `4000-cs-unified-3.4.86-openwrt.patch` | OpenWrt 向け差分 (target 名は `platform-cs-unified`) |
| `5001-add-kernel-support-for-512MB-flash.patch` | 512MB NAND 対応 |

- `.pc/` に quilt の適用状態が同梱 = 「適用済みスナップショット」のドロップ
- 実効設定の複製: `V:\NAS\notes\kernel.config` (元 `linux-3.4/.config`)
- `CONFIG_CMDLINE_FROM_BOOTLOADER=y` → 起動引数は U-Boot 側が決める

# U-Boot 2009.11

- ボードディレクトリ `board/goldengate/`: `csmi_uboot_cmds.c` (CSMI コマンド)、
  `csmi_user.c`、**`everify.c` (署名検証: OTP TLV + `lib_openssl` でイメージ検証)**、
  `pwr.c`、`watchdog.c`、`lowlevel_init.S`
- 設定 `include/configs/goldengate.h` (複製: `V:\NAS\notes\u-boot-goldengate.h`)
  - `CONFIG_BOOTCOMMAND "run process setbootargs b"` → **`process` コマンドで A/B バンク選択**
    + `setbootargs`
  - `CONFIG_ENV_IS_IN_NAND` (env 2 面 = uboot-env0/1), `CONFIG_BAUDRATE 115200`,
    `CONFIG_BOOTDELAY 2`, `CONFIG_CMD_HTTP` (HTTP ダウンロード)
- **セキュアブート**: `GLOBAL_STRAP register bit 0` で secure mode 判定 → 有効なら起動時に
  署名検証。実機にも `/dump_sadb` (`dump_sadb`, `cfg_pe_fab.sh`, `r1.txt`, `r2.txt`) が存在し、
  SADB (secure area DB) 運用が生きている

# 実機の NAND レイアウト (cmdline 実測 — 512MB)

```
mtdparts=cs752x_nand_flash:1024K@0x00100000(uboot-env0),1024K@0x00300000(uboot-env1),
  1024K@0x00400000(sb0),1024K@0x00500000(sb1),153600K@0x01200000(rootfs),
  174080K@0x0A800000(rootfs_data),6144K@0x00C00000(kernel2),153600K@0x15200000(rootfs2)
```

| オフセット | サイズ | 名前 | 役割 |
|---|---|---|---|
| 0x00100000 | 1MB | uboot-env0 | U-Boot 環境 (A) |
| 0x00300000 | 1MB | uboot-env1 | U-Boot 環境 (B) |
| 0x00400000 | 1MB | sb0 | スーパーブロック (A) |
| 0x00500000 | 1MB | sb1 | スーパーブロック (B) |
| 0x01200000 | 150MB | rootfs | 現行 rootfs (squashfs 実測 82.8MB) |
| 0x0A800000 | 170MB | rootfs_data | jffs2 オーバーレイ (実測 170MB) |
| 0x00C00000 | 6MB | kernel2 | 待機系カーネル |
| 0x15200000 | 150MB | rootfs2 | 待機系 rootfs |

- `/` = `overlayfs` (`lowerdir=/` squashfs `/rom` + `upperdir=/overlay` jffs2) = OpenWrt 標準構成
- A/B 二重化 (rootfs/rootfs2 + kernel2 + env/sb の 2 面) でファーム更新のロールバックが可能

# 実機のデータ構成

- `/dev/sda` (約 1TB) を 6 分割し、`sda2〜sda5` → **`md0`〜`md3` = RAID1** (現状 1 台のみで `[2/1] [U_]`)
  - `/dev/md1` → `/nasmiru` (ext2, 938MB) = ベンダ NAS アプリのデータ領域
  - `/dev/md3` → `/openwrt/usr/local/system/backup` (ext4, 939MB)
- `/dev/sda6` (927GB / XFS) → `/volNAS/Disk1`、`/shares/{share,ftp_root,localhost,macOS,TimeMachine}` を bind
- ユーザーランドは OpenWrt 相当 (`/etc/config` の uci、`preinit`、`rc.common`、`opkg` 469 パッケージ)

# ソースと実機の一致 (確認済み)

- カーネル 3.4.86 / armv7l / `CORTINA-G2 EB` → リポジトリの `MACH_CORTINA_G2` + `arch/arm/mach-goldengate` と一致
- パッケージの版が opkg と一致 (accel-ppp 1.7.3-1 / MPlayer_New r34578 / NeoRaider-mrd6 66cda76 /
  avahi 0.6.31-5 / samba 3.5.6 ほか)
- `mtdparts` の 512MB 構成が `5001-add-kernel-support-for-512MB-flash.patch` と整合

# 未検証 / 次にやるなら

1. カーネル単体ビルド可否: armv7 クロス (gcc 4.5.2 Linaro 相当) + `linux-3.4` + 4 パッチ + `.config`
2. U-Boot ビルド: `board/goldengate/config.mk` を参照 (`make goldengate_config` 相当)
3. 書込み前に **secure strap / 署名検証の有無** を確認 (無効化されていなければ未署名イメージは起動しない)
4. ベンダアプリ (`/nasmiru`)・Web UI (`/www-ms`) は未公開 → 実機バイナリ解析で補う
