---
type: Reference
title: NSB-3NR の SSL/TLS セキュリティ監査 (2026-11-20)
description: 公开 HTTPS(:443 lighttpd) と NAS 管理 HTTPS(:8443 stunnel) のプロトコル・暗号・証明書・SSH ホスト鍵の実測監査と対策余地
generated: { by: agent, at: 2026-11-20T00:00:00Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# 結論

**「脆弱性対策は部分的にされているが、証明書は完全に失効しており実質的に信頼できない」** 状態。

| 項目 | :443 (公開 / lighttpd) | :8443 (NAS 管理 / stunnel) |
|---|---|---|
| TLS 1.0 / 1.1 | **拒否** ✅ | **拒否** ✅ |
| TLS 1.2 | 使用可、Cipher `AES256-GCM-SHA384` ✅ | 使用可、`ECDHE-RSA-AES256-GCM-SHA384` (P-256 ECDHE、前方秘密) ✅ |
| TLS 1.3 | 拒否(実機 OpenSSL 1.0.2f が非対応) | 同左 |
| RC4 / 3DES / MD5 / DES | cipher-list で明示除外 ✅ | stunnel `options = NO_SSLv2` + sslVersion=all |
| 証明書 | **期限切れ(2022-04-02)** ❌ | **期限切れ(2019-03-20)** ❌ |
| 署名アルゴリズム | sha384WithRSA / 2048bit ✅ | **sha1WithRSA / 1024bit** ❌❌ |
| 発行者 | ZeroSSL RSA Domain Secure Site CA (実在 CA) | 自己署名(Elecom Inc) |
| CN / SAN | `nullpower.f5.si` + www (SAN あり) | `http://www.elecom.co.jp/...` (意味不明、SAN なし) |

# 詳細

## OpenSSL / 実装

- 実機 OpenSSL **1.0.2f (2016)** — 古く、TLS 1.3 非対応、既知 CVE 多数
  (Heartbleed は 1.0.1 系なので本DLLには直接影響しないが、1.0.2 系にも多数の修正後 CVE)
- lighttpd `nullpower-inc.conf` に硬めの cipher-list:
  `EECDH+AESGCM:EDH+AESGCM:AES128+EECDH:AES128+EDH:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4:!SSLv3`
- ただし **`ssl.use-sslv3 = "disable"` はコメントアウト**、`ssl.honor-cipher-order` もコメント。
  SSLv3 無効化は cipher-list の `!SSLv3` に依存している状態
- stunnel は `sslVersion = all` + `options = NO_SSLv2` のみ。SSLv3/TLS1.0/1.1 の明示拒否は
  設定に無いが、**実測ではクライアント(OpenSSL 3.x @SECLEVEL=0)から TLS1.0/1.1 は拒否された**
  (stunnel 側のビルド/デフォルトによるもの)

## 証明書の問題 (最も深刻)

`:443`:
```
Subject: CN=nullpower.f5.si / SAN: nullpower.f5.si, www.nullpower.f5.si
Issuer: ZeroSSL RSA Domain Secure Site CA
Valid: 2022-01-02 ~ 2022-04-02  ← 3年半以上期限切れ
Public-Key: 2048 bit / sha384WithRSA
```

`:8443` (stunnel):
```
Subject: C=JA, O=Elecom Inc, CN=http://www.elecom.co.jp//emailAddress=...
Valid: 2018-03-20 ~ 2019-03-20  ← 6年以上期限切れ
Public-Key: 1024 bit / sha1WithRSA  ← 現在の基準で完全に脆弱
```

→ どちらもブラウザで **警告が出るため、実質的に「暗号化はされているが認証は不能」**。
公開サイト(:443)は無料の Let's Encrypt / ZeroSSL で更新すべき。管理画面(:8443)は
せめて 2048bit + SHA256 の自己署名に作り直すべき。

## SSH ホスト鍵

- `/etc/ssh/ssh_host_rsa_key` (RSA 2048、2018 作成) と **`ssh_host_dsa_key`** が存在
- 接続時にサーバが提示するのは **ssh-rsa / ssh-dss のみ** (旧 OpenSSH 5.8p1)
  - ssh-dss(DSA) は OpenSSH 7.0+ で既定無効、現代では脆弱
  - ssh-rsa(SHA-1 署名) も OpenSSH 8.8+ で既定無効
  - Windows 側は `~/.ssh/config` で `HostKeyAlgorithms`/`PubkeyAcceptedAlgorithms` に
    ssh-rsa を明示して回避済み (`nas.md` 参照)
- `/etc/ssh/sshd_config` の暗号設定はコメント/既定のまま (Ciphers/MACs/Kex の明記なし)
- **根本対策は OpenSSH の更新**だが、この古い uClibc 環境では容易でない

# 推奨対策 (優先順)

1. **:443 の証明書を更新** — ZeroSSL/ACME で `nullpower.f5.si` の証明書を再取得。
   lighttpd の `ssl.pemfile` / `ssl.ca-file` を差し替え、`ssl.use-sslv3 = "disable"` の
   コメントを外す
2. **:8443 の stunnel 証明書を作り直す** — RSA 2048 + SHA256、CN を `homenas` 等に。
   できれば stunnel を `sslVersion = TLSv1.2` 固定にする
3. **SSH を modern 化** — 可能なら OpenSSH 9.x を静的ビルドして配置
   (Ed25519 ホスト鍵 + rsa-sha2-256/512)。不可能なら DSA ホスト鍵を削除し、
   `HostKey /etc/ssh/ssh_host_rsa_key` に限定するだけでも改善
4. 可能なら nginx を SSL/SNI 対応で再ビルドし、公開口を統一 (dynamic-web.md 参照)

# 対策: OpenSSL 1.0.2u + Debian LTS バックポート ipk (2026-11-20 作成)

## 背景 (バックポートの可能性)

- OpenSSL **1.0.2u(2019-12)** が公開版の最終。以降の **1.0.2w / 1.0.2x は有償サポート限定**で
  ソース非公開:
  - 1.0.2w = **CVE-2020-1968**(Raccoon、DH 暗号の pre-master 推測)
  - 1.0.2x = **CVE-2020-1971**(EDIPARTYNAME NULL deref、DoP)
- ただし **公開 git の `OpenSSL_1_0_2-stable` ブランチは 1.0.2u どまり**(`Prepare for
  1.0.2v-dev` が最終コミット)。自前で 1.1.1 のコミットを移植するのは困難
- **Debian LTS の `openssl1.0 1.0.2u-1~deb9u7`(2022-03) の security patches が公開されており、
  1.0.2u に対してそのまま適用可能**。これが最も現実的なバックポート経路
  - 適用した 23 パッチ: CVE-2020-1968 / CVE-2020-1971(5本) / CVE-2021-23840 /
    CVE-2021-23841 / CVE-2021-3712(多数) / CVE-2022-0778 / 関連 X.509 修正
  - **23/23 が conflict なしで適用成功**
- 2023 年以降の CVE は 1.0.2 には公開修正が無く、このバックポートでも未対策。
  恒久策はモダンな TLS 終端(ルータ Node / Cloudflare 等)への移行

## ビルドと検証

- クロスツールチェーン: **Gateworks OpenWrt 14.08 imx6**
  `OpenWrt-Toolchain-imx6-for-arm_cortex-a9+neon-gcc-4.8-linaro_uClibc-0.9.33.2_eabi`
  (NAS と同じ **uClibc / armv7 / Cortex-A9+NEON / softfp** なので ABI 互換)
- `./Configure linux-armv4 --cross-compile-prefix=arm-openwrt-linux-uclibcgnueabi- \
   --prefix=/usr --openssldir=/etc/ssl shared`
  ※ `-mfpu/-mfloat-abi` を渡すとサブディレクトリの CFLAG と食い違い VFP エラーになるため**渡さない**
- 生成物: `libssl.so.1.0.0` / `libcrypto.so.1.0.0` / `apps/openssl`
  - SONAME は既存と同じ `libssl.so.1.0.0` / `libcrypto.so.1.0.0`
  - NEEDED: `libc.so.0`, `libgcc_s.so.1`, `libdl.so.0` ( Nas に存在確認済み )
- **ステージング検証**: `/tmp/ossl-bp` に配置し `LD_LIBRARY_PATH=/tmp/ossl-bp curl --version`
  → `OpenSSL/1.0.2u` をロードして動作 ✅ (soname 互換を実証)
- 一時ステージングディレクトリは削除済み

## 成果物 (未インストール)

- ipk: **`V:\NAS\ipk-build\packages\openssl-uclibc-bp\out\openssl-uclibc-bp_1.0.2u-2_g2.ipk`**
  (1.23MB、Architecture `g2`)
- 内容: `usr/lib/libssl.so.1.0.0`, `usr/lib/libcrypto.so.1.0.0`, `usr/bin/openssl`
- ビルドスクリプト: `V:\NAS\analysis\webui\{get-uclibc-toolchain,get-debian-backports,
  apply-backports,build-backported,stage-backported}.sh`
- **システムの libssl を置き換えるため、適用前に必ずバックアップ**:
  ```
  cp /usr/lib/libssl.so.1.0.0 /usr/lib/libssl.so.1.0.0.bak
  cp /usr/lib/libcrypto.so.1.0.0 /usr/lib/libcrypto.so.1.0.0.bak
  opkg install --force-reinstall openssl-uclibc-bp_1.0.2u-2_g2.ipk
  ```
  切り戻しは `.bak` を戻す。**現在は未適用** (利用者の承認待ち)

# 監査に使ったスクリプト

`V:\NAS\analysis\webui\{sslcheck,sslcert,tlsprobe,cipherprobe,proto}.sh` (WSL から実行)
