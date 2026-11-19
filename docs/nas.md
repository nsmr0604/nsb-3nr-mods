---
type: Concept
title: 自宅 NAS (HomeNAS) への SSH 接続
description: TP-Link 網内 192.168.0.222 / 外部 nullpower.ddns.net:2222 の使い分け、OpenSSH 5.8 サーバゆえの ssh-rsa 制約、RSA 鍵認証の設定手順と落とし穴
generated: { by: agent, at: 2026-11-19T04:10:47Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# このディレクトリの使い方

- `nas/nas.md` が NAS 関連の親 concept。接続・設定・実測の知見はここに集約する
- NAS 関連の実測ログ・取得した設定ファイル・補助スクリプト・スクリーンショットは
  `V:\OpenCode\knowledge\nas\` 配下に置く (ルートへ散らかさない)
- **作業領域 (セッションのカレントディレクトリ) は `V:\NAS`**。NAS を触るセッションは
  ここをワークスペースにする (`session_move` で移動済み)
  - 公開ソースのクローン: `V:\NAS\nsb-3xx` / ファイル一覧 `V:\NAS\filelist.txt` /
    抽出物 `V:\NAS\notes\` (kernel.config, u-boot-goldengate.h)
- 資格情報 (パスワード等) は置かない。値はルートの `secret.md` のみ

# ハードウェア (実測)

- SoC: Cortina **CS752x ("G2")** / ARMv7 **Cortex-A9 デュアルコア** (rev 1, NEON) / RAM 1GB
- `Hardware: CORTINA-G2 EB`、hostname `homenas`、ファーム `fwversion 1.08`
- NAND 512MB (A/B 2 面 = uboot-env0/1, sb0/1, rootfs/rootfs2, kernel2, rootfs_data)
- SATA 1 台 (約 1TB): `md0〜md3` は RAID1 (`/nasmiru` ext2, backup ext4)、`sda6` XFS 927GB
  を `/volNAS/Disk1` と `/shares/*` に使用
- 公開ソース (Elecom NSB-3xx GPL ドロップ) との照合結果: `nsb-3xx-source.md`
- 搭載アプリの解析: `nasmiru.md` (NASみる = クラウド遠隔監視エージェント)、
  ipk ビルド環境: `ipk-build.md`、Web サーバの端口構成: `webui-ports.md`

# Web サーバ / Web UI のポート構成 (2026-11-19 実測)

| ポート | プロセス | 内容 |
|---|---|---|
| 80 | nginx 0.7.67 | `sites-enabled/nullpower.conf` (`server_name x00.f5.si` 等) と `Disk1-html.conf` (default。両方 `root /volNAS/Disk1/.html` → `share/public_html` = **利用者の独自サイト**) |
| 9090 | nginx 0.7.67 | `ms-cgi.conf` = `/www-ms` メディアサーバ CGI |
| 880 | lighttpd | **OpenWrt 系 LuCI** (`server.document-root = /www/`, `cgi.assign` で `/usr/bin/lua`)。NAS 管理 UI ではない |
| **8001** | python 2.7 | **エレコム NAS 本体の Web UI** = Django アプリ `/root/celestial_NAS/manage.py runserver 0.0.0.0:8001 --insecure`。ルート `/` が `views.userlogin` (Loginpage)、`/dashboard/`, `/drives/`, `/filesharing/` 等 |
| 8443 | stunnel | HTTPS フロントエンド。`/root/celestial_NAS/stunnel/dev_https`: `accept=8443` → `connect=8001` (NAS Web UI を SSL 化) |
| 443 | lighttpd | HTTPS (LuCI / メディアサーバ側) |

- **利用者の探している「NAS 本体用エレコム Web UI」は 8001 (HTTP) / 8443 (HTTPS)**。
  880 は OpenWrt の LuCI で別物 (利用者の指摘どおり)
- 実機に 8080 のリスナーは無い (`netstat` で確認)
- Django は `ALLOWED_HOSTS = ['*']`、Cookie は Secure 指定なし、`--insecure` で静的ファイルも配信
  → nginx から `proxy_pass http://127.0.0.1:8001/` すればそのまま動く
- nginx は `proxy_pass` モジュール入り。LuCI の `/cgi-bin/luci` 絶対リダイレクト問題は 8001 側には無い
- Web UI を 80 に戻さず nginx エンジンを使う選択肢 (未適用・要選択):
  1. **nginx を 8080 でリバースプロキシ → `127.0.0.1:8001`** (推奨)
  2. nginx の `:80` に `server_name` 付き vhost を追加し、ホスト名で 8001 へ proxy
  3. SSH ポートフォワード (`ssh -L 8080:127.0.0.1:8001 HomeNAS`)
  4. stunnel の 8443 (既存の HTTPS 入口) を使う
- 設定・手順の詳細は `webui-ports.md`


# 接続経路の使い分け

| 状況 | 接続先 | ポート | エイリアス |
|---|---|---|---|
| TP-Link の SSID (192.168.0.0/24) に接続中 | `192.168.0.222` | 22 | `HomeNAS-LAN` |
| それ以外 (別 SSID / 外部回線) | `nullpower.ddns.net` (= 223.217.36.89) | 2222 | `HomeNAS` |

- 判定は Wi-Fi SSID と自 PC の IPv4 で行う: `netsh wlan show interfaces` / `Get-NetIPAddress -AddressFamily IPv4`
- 2026-11-19 実測: 自宅 Wi-Fi `$pwnd#` 接続時は PC が 192.168.2.42/24 になり
  **192.168.0.222:22 は 4 秒タイムアウトで到達不可** → グローバル経路 (`HomeNAS`) を使う
- DDNS 名は `nullpower.tplinkdns.com` も同一ホスト (known_hosts に履歴あり)
- 認証情報は root の `../secret.md`。通常運用は鍵認証でパスワード不要

# サーバ側の素性 (実測)

- `OpenSSH_5.8p1, OpenSSL 1.0.2f` / `Linux 3.4.86 armv7l` / hostname `homenas`
- rootfs は OpenWrt 系 (`/rom`・`/overlay`・`/openwrt`)。データは `/volNAS/Disk1`、
  共有は `/shares/{share,macOS,TimeMachine,ftp_root}`
- LAN 側アドレスは `192.168.0.222/24` (eth0)
- **ホスト鍵は ssh-rsa / ssh-dss のみ**提示。Windows OpenSSH 9.5 は ssh-rsa を既定無効化
  しているため、素の `ssh root@nullpower.ddns.net -p 2222` は
  `no matching host key type found. Their offer: ssh-rsa,ssh-dss` で失敗する

# クライアント設定 (`~/.ssh/config`)

```
Host HomeNAS
	HostName nullpower.ddns.net
	User root
	Port 2222
	IdentityFile ~/.ssh/id_rsa_nas
	IdentitiesOnly yes
	PreferredAuthentications publickey
	PubkeyAcceptedAlgorithms +ssh-rsa
	HostKeyAlgorithms <既存の長いリスト (末尾に ssh-rsa を含む)>
```

- `HostKeyAlgorithms` に ssh-rsa が入っていないと KEX で落ちる
- `PubkeyAcceptedAlgorithms +ssh-rsa` が無いと「Server accepts key」の直後に
  `we did not send a packet, disable method` となり認証失敗 (サーバが rsa-sha2-* を解さないため)
- 旧 config は `~/.ssh/config.bak-20261119` に退避済み

# 鍵認証 (2026-11-19 設定済み)

- クライアント鍵: `~/.ssh/id_rsa_nas` (RSA 4096 / **パスフレーズ無し** / コメント `x@windows-nas-access`)
- サーバ: `/root/.ssh/authorized_keys` (600) に 1 行。既存の `~/.ssh/id_rsa` (2018 作成) は温存
- **ed25519 は使えない**: サーバが OpenSSH 5.8 で ed25519 未対応 (6.5 以降で対応)
- 追加手順の要点: `~/.ssh` を 700 / `authorized_keys` を 600 にし、既存行を消さずに追記する

# 落とし穴

- PowerShell で `ssh-keygen -N '""'` と書くと **文字列 `""` がパスフレーズになる**。
  BatchMode では無言の認証失敗 (`we did not send a packet, disable method`) になるだけなので
  気付きにくい。空パスフレーズは `cmd /c 'ssh-keygen ... -N "" ...'` 経由で作る
- パスワード認証の自動化は `SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force` で行える
  (plink/sshpass は未導入、WSL は swap vhdx 警告が出る)。パスワードを書いた一時ファイルは
  使用直後に削除し、コマンド出力にも値を出さない

# 実測ログ (2026-11-19)

- `ssh HomeNAS "..."` → 鍵認証で成功 (exit 0)、`up 380 days`
- `df -h`: `/dev/root 82.8M` が 100% だが `/rom` は読み取り専用のため正常、
  `/overlay` は 15% 使用
