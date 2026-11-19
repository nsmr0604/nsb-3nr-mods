---
type: Guide
title: NAS (NSB-3xx) 用 ipk ビルド環境
description: WSL(Ubuntu 24.04) + ARM musl クロスコンパイラ (gcc 11.2.1) で静的バイナリを作り、実機 opkg 0.1.8 用 .ipk を作成・転送・インストールする手順と実測結果
generated: { by: agent, at: 2026-11-19T06:20:00Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# 結論 (できること)

- **ユーザーランドの .ipk を作って実機に入れられる**。2026-11-19 に
  ビルド → `scp` → `opkg install` → 実行 → `opkg remove` まで実測で通した
- 方式: **静的リンク (musl, `-static -no-pie`)**。実機 libc が uClibc 0.9.32-rc2 のため、
  glibc/musl の動的リンクは不可
- カーネルモジュールは不可 (カーネル 3.4.86 と完全一致するツリー + 署名が必要)

# 環境

| 項目 | 値 |
|---|---|
| ホスト | WSL2 Ubuntu 24.04.3 (`wsl -e bash`)、既定ユーザー root |
| ツールチェーン | `~/opt/cross/arm-linux-musleabihf-cross` — **gcc 11.2.1 (musl)** |
| 取得 | `https://musl.cc/arm-linux-musleabihf-cross.tgz` (102,391,022 bytes) |
| セットアップ | `wsl bash /mnt/v/NAS/setup/fetch-toolchain.sh` (レジューム付き再試行) |
| ターゲット flags | `-O2 -pipe -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard -static -no-pie` |
| 作業場所 | `V:\NAS\ipk-build\` (WSL からは `/mnt/v/NAS/ipk-build`) |

**罠**: musl.cc のダウンロードが 19MB で切れたことがある (期待 102MB)。
`curl -C -` + サイズ検証のループをスクリプト化してある。切れた tarball は `gzip -t` で検出できる。

# 実機側の受入条件 (実測)

- `opkg version 0.1.8` (OpenWrt Attitude 系)
- `/etc/opkg.conf` の arch: `all 1` / `noarch 1` / **`g2 10`** / **`arm_cortex-a9 100`** /
  `arm_cortex-a9_neon 100` / `arm_cortex-a9_vpf3 100` / `bcm53xx 200`
  → ipk の `Architecture:` は `arm_cortex-a9_neon` (一般) か `g2` (機種固有) を使う
- `data.tar.gz` は **gzip** 必須 (`xz` は不可)
- 署名検証は無効 (opkg.conf に `check_signature` なし) → 自作 ipk をそのまま install できる
- 空き: `/overlay` 144MB、`/tmp` 429MB

# 成果物 (V:\NAS\ipk-build)

| ファイル | 役割 |
|---|---|
| `toolchain.env` | CC/CFLAGS/LDFLAGS/IPK_ARCH の定義 (WSL で `.` 読み込み) |
| `mkpkg.sh` | `ar` で `debian-binary` + `control.tar.gz` + `data.tar.gz` を固める |
| `build.ps1` | Windows から `wsl` を呼んでビルド → 必要なら scp + `opkg install` |
| `packages/hello-nas/` | 動作確認用サンプル (`meta` / `build.sh` / `src/` / `conffiles`) |
| `README.md` | 使い方 |

パッケージ仕様は `packages/<name>/meta` に `PKG_NAME`/`PKG_VERSION`/`PKG_DESC` などを書き、
`build.sh` で `$PKG_ROOT` 配下へ配置する (例: `hello-nas`)。

# 実測ログ (2026-11-19)

```
> .\ipk-build\build.ps1 hello-nas -Deploy -Force
built: .../hello-nas_1.0-1_arm_cortex-a9_neon.ipk
  member: debian-binary / control.tar.gz / data.tar.gz
installed on HomeNAS

$ /usr/bin/hello-nas a b
hello-nas: musl static build
  sysname=Linux release=3.4.86 machine=armv7l nodename=homenas
  args: a b
$ opkg list-installed | grep hello        → hello-nas - 1.0-1
$ opkg remove hello-nas                   → 削除成功 (/usr/bin, /etc の conffile とも消える)
```

- バイナリは `ELF 32-bit LSB executable, ARM, EABI5, statically linked, stripped` (13KB ipk)
- 転送は `scp -O` (legacy プロトコル)。実機は sftp-server も持つので `scp` 既定でも可

# 既知の注意点

- 実機 `/etc/opkg.conf` に `src/gz snapshots` の重複行があり、opkg 実行ごとに
  `Duplicate src declaration ... Skipping` が出る (動作に影響なし。消すなら 1 行削除)
- 実機にはベンダ由来の `/usr/lib/opkg/info/bash.postinst` 不整合があり、
  インストール時に `default_postinst: not found` が出るが、対象パッケージの
  インストール自体は成功する (postinst を持たない自作パッケージなら無関係)
- **動的リンクが必要になったら** uClibc 0.9.32 のツールチェーンを別途ビルドする必要がある
  (リポジトリに `uClibc-0.9.32` / `binutils-2.20.1` はあるが gcc 4.5.2 の取得とビルドに時間がかかる)。
  現状の静的リンクで足りないケースが出たときの選択肢
