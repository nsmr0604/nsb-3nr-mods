# NAS (NSB-3xx) 用 ipk ビルド環境

WSL(Ubuntu 24.04)上の ARM musl クロスコンパイラで **静的リンク** バイナリを作り、
OpenWrt の `opkg` (実機 0.1.8) 用 `.ipk` に固める環境です。

## 構成要素

| 役割 | 実体 |
|---|---|
| クロスコンパイラ | `~/opt/cross/arm-linux-musleabihf-cross` (gcc 11.2.1 / musl / hard-float) |
| ターゲット | Cortex-A9 ×2 / NEON / VFPv3 (`-mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard`) |
| リンク | `-static -no-pie` (実機 uClibc 0.9.32 に依存しない) |
| パッケージ化 | `mkpkg.sh` — `ar`(debian-binary + control.tar.gz + data.tar.gz) |
| 実機 Arch | `arm_cortex-a9_neon` (実機 opkg.conf の許容値。機種固有は `g2` も可) |

初回セットアップ(WSL 内):
```
wsl bash /mnt/v/NAS/setup/fetch-toolchain.sh
```

## 使い方

```
# ビルドのみ (V:\NAS で)
.\ipk-build\build.ps1 hello-nas

# ビルドして NAS へ転送 + インストール
.\ipk-build\build.ps1 hello-nas -Deploy

# 既存版を上書き
.\ipk-build\build.ps1 hello-nas -Deploy -Force
```

## パッケージの作り方

`ipk-build\packages\<name>\` を作り、以下を置きます。

- `meta` (必須) — `PKG_NAME` / `PKG_VERSION` / `PKG_DESC` / 必要なら
  `PKG_ARCH`(既定 `arm_cortex-a9_neon`) / `PKG_DEPENDS` / `PKG_SECTION`
- `build.sh` (任意) — `$CC $CFLAGS` でコンパイルし `$PKG_ROOT` 配下へ配置。
  `$LDFLAGS` は必ず付ける(静的リンク)
- `files/` (任意) — `build.sh` が無い場合のファイル一式
- `postinst` / `prerm` / `conffiles` (任意) — そのまま `control.tar.gz` に入る

例は `packages\hello-nas\` を参照。

## 注意点

- **動的リンク不可**: 実機は uClibc 0.9.32-rc2。glibc/musl の動的バイナリは動きません。
  動的に作るなら uClibc 0.9.32 のツールチェーン(ベンダ BSP 由来)が別途必要
- カーネルモジュールは作れません (実機カーネル 3.4.86 と完全一致するビルドツリー + 署名が必要)
- 実機 `/etc/opkg.conf` に `src/gz snapshots` の重複行があり、opkg 実行ごとに警告が出ます
  (動作には影響なし。直すなら 1 行削除)
- 実機の opkg は古いため、`data.tar.xz` ではなく **gzip** で固めています
