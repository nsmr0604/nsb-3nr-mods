# SSL / OpenSSL

## 監査結果

`docs/ssl-audit.md` (docs ディレクトリ) を参照。要点:

- `:443` (lighttpd) / `:8443` (stunnel) とも TLS1.0/1.1 は拒否、強 cipher を使用
- ただし両証明書が期限切れ (`:8443` は 1024bit/SHA1 で極めて脆弱)
- SSH は `ssh-rsa` / `ssh-dss` のみ

## ipk

`openssl-uclibc-bp_1.0.2u-2_g2.ipk` は **OpenSSL 1.0.2u + Debian LTS バックポート 23 パッチ**
(CVE-2020-1968/1971, 2021-23840/23841, 2021-3712, 2022-0778) を
uClibc / Cortex-A9 向けにビルドした soname 互換 (`libssl.so.1.0.0`) の差し替え用です。

ビルド手順は `*.sh` を上から実行してください:

1. `get-uclibc-toolchain.sh` — Gateworks OpenWrt 14.08 imx6 ツールチェーン
2. `get-debian-backports.sh` — Debian `openssl1.0 1.0.2u-1~deb9u7` のパッチ
3. `apply-backports.sh` — セキュリティパッチ適用 (23/23 成功)
4. `build-backported.sh` — クロスビルド
5. `stage-backported.sh` — ステージング用ファイルを `openssl-bp-out/` に出力

## 注意

- 2023 年以降の CVE は未対策 (1.0.2 に公開修正なし)
- 導入前に `/usr/lib/libssl.so.1.0.0` と `libcrypto.so.1.0.0` をバックアップすること
- `audit/` には監査・検証用スクリプトがあります (一部は DB を書き換えるものもあるので注意)
