# nsb-3nr-mods

Elecom **NSB-3NR** (Cortina CS752x / ARMv7 Cortex-A9 / OpenWrt 系 / uClibc 0.9.32) を
いじるための**単一リポジトリ**。アプリごとに分けず、ディレクトリで管理します。

- Web / ドキュメント: <https://nsmr0604.github.io/nsb-3nr-mods/>
- opkg フィード: <https://nsmr0604.github.io/nsb-3nr-mods/>
  (`Packages` / `Packages.gz` を gh-pages ルートに配置)

## ディレクトリ

| パス | 内容 |
|---|---|
| `ssl/` | OpenSSL 1.0.2u + Debian LTS バックポートのビルド、監査スクリプト、stunnel/lighttpd 設定、ipk |
| `nginx/` | nginx / lighttpd の実機設定と proxy 設定例 |
| `quickjs/` | QuickJS の musl ARM 静的ビルド手順と CGI サンプル |
| `ipk-build/` | opkg (.ipk) を組む共通ツール (`mkpkg.sh` 等) |
| `docs/` | 実測ナレッジ (nas.md, ssl-audit.md, network-topology.md 等) |
| `tools/make-index.py` | opkg フィードの `Packages` インデックス生成 |
| `feed/` | GitHub Pages で配信する `Packages` / `Packages.gz` と `.ipk` 本体 |

## opkg フィードの使い方 (NAS 側)

```sh
# /etc/opkg.conf に 1 行追加 (既存の bcm53xx feed は壊れているので無効化してもよい)
src/gz nsb3nr https://nsmr0604.github.io/nsb-3nr-mods/

opkg update
opkg list | grep openssl-uclibc-bp
opkg install openssl-uclibc-bp
```

**注意**: `openssl-uclibc-bp` はシステムの `libssl.so.1.0.0` / `libcrypto.so.1.0.0`
を置き換えます。導入前に必ずバックアップしてください (詳細 `docs/ssl-audit.md`):

```sh
cp /usr/lib/libssl.so.1.0.0 /usr/lib/libssl.so.1.0.0.bak
cp /usr/lib/libcrypto.so.1.0.0 /usr/lib/libcrypto.so.1.0.0.bak
```

## パッケージを追加したとき

```sh
python3 tools/make-index.py feed
# feed/Packages と feed/Packages.gz を gh-pages ブランチに反映して push
```

## 注意

- 認証情報 (パスワード等) は **絶対にコミットしない** (ローカルの `secret.md` にのみ保管)
- 公開前にリポジトリ全体をスキャンし、パスワード/トークン/メールアドレス等の断片が
  含まれていないことを確認している。今後も追加時に同じ確認を行うこと
- 元の GPL ソースは `nsmr0604/nsb-3xx` を参照
