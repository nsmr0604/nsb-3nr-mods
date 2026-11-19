---
type: Guide
title: NSB-3NR の Web サーバ / エレコム NAS Web UI のポート構成
description: nginx 0.7.67・lighttpd(LuCI)・Django(celestial_NAS = エレコム NAS Web UI)・stunnel の実測ポート割当てと、Web UI を 80 に戻さず nginx エンジンで公開する設定例
generated: { by: agent, at: 2026-11-19T12:15:00Z }
status: draft
stale_after: 2027-02-17T00:00:00Z
---

# 現状 (2026-11-19 実測・未変更)

| ポート | バインド | プロセス | 内容 |
|---|---|---|---|
| 80 | 0.0.0.0 | nginx 0.7.67 | `sites-enabled/nullpower.conf` (`server_name x00.f5.si nullpower.f5.si *.nullpower.f5.si`) と `Disk1-html.conf` (server_name なし = default)。両方 `root /volNAS/Disk1/.html` → `share/public_html` への symlink = **利用者の独自サイト** (HTML5 sample) |
| 9090 | 0.0.0.0 | nginx | `ms-cgi.conf` = `/www-ms` メディアサーバ Perl CGI |
| **880** | 0.0.0.0 | lighttpd | **OpenWrt 系 LuCI**。`server.document-root = "/www/"`, `server.port = 880`, `cgi.assign = ("luci" => "/usr/bin/lua", ...)`。NAS 管理 UI ではない |
| **8001** | 0.0.0.0 | python 2.7.10 | **エレコム NAS 本体の Web UI** = Django アプリ `/root/celestial_NAS/manage.py runserver 0.0.0.0:8001 --insecure`。`GET /` は 200 で `<title>Loginpage</title>` (celestial ブランド、`/static/js/common/login.js`)。`urls.py` に `/dashboard/`, `/drives/`, `/filesharing/`, `/syslog_get/`, `/shutdown/` 等多数 |
| **8443** | 0.0.0.0 | stunnel | `/root/celestial_NAS/stunnel/dev_https`: `accept=8443` → `connect=8001` = **NAS Web UI の HTTPS 入口** |
| 443 | 0.0.0.0 | lighttpd | HTTPS |

- **重要 (2026-11-19 訂正)**: 以前「880 = Web UI」と記録したが誤り。880 は OpenWrt の LuCI で、
  利用者が探しているエレコム製 NAS 管理 Web UI は **Django の 8001 (HTTP) / 8443 (HTTPS)** にある
- 実機に 8080 のリスナーは無い (`netstat -lntp | grep 8080` → なし)
- nginx 0.7.67 は gcc 4.5.2 / uClibc 0.9.32 / `-march=armv7-a -mtune=cortex-a9 -mfloat-abi=softfp` ビルド。
  バイナリ内に `proxy_pass` がありリバースプロキシ可能
- Django 側は `ALLOWED_HOSTS = ['*']`、`CSRF_COOKIE_SECURE`/`SESSION_COOKIE_SECURE` はコメントアウト、
  `--insecure` で静的ファイルも配信 → **nginx からの proxy でそのまま動く**
- `/etc/nginx` 内に 8001 への `proxy_pass` は存在せず、iptables NAT のリダイレクトも無し
  (= 現在 80 → 8001 の中継は存在しない)

# 「NAS Web UI にアクセスできない」の原因切り分け (2026-11-19 実測)

- **NAS 側は正常**: 装置自身から `http://127.0.0.1:8001/` と `http://192.168.0.222:8001/`
  はともに **HTTP 200 (Loginpage)**、`https://127.0.0.1:8443/` (stunnel) も **200**
- **原因は経路**: このセッションの PC は 192.168.2.42/24 (SSID `$pwnd#`) に居り、
  `192.168.0.222` の **全ポート (80 / 880 / 8001 / 8443 / 8080) がタイムアウト**。
  グローバル (`nullpower.ddns.net`) で開いているのは **80 (独自サイト) と 2222 (SSH) のみ**、
  8001 / 8443 / 8080 は転送されていない
- → Web UI 自体の不具合ではなく、**TP-Link 網 (192.168.0.x) に居るか、SSH トンネル /
  ルータ転送を使う**必要がある
- **SSH トンネルで動作確認済み** (LuCI 880 には一切触れない):
  ```
  ssh -N -L 127.0.0.1:18080:127.0.0.1:8001 HomeNAS
  # 別ターミナル: http://127.0.0.1:18080/ → HTTP 200, <title>Loginpage</title>
  ```
  旧 NAS の認証が遅く ** listens が立つまで 15〜20 秒かかる** (5 秒待ちでは失敗した)。
  `~/.ssh/config` の `Host HomeNAS` に `LocalForward 18080 127.0.0.1:8001` と
  `ExitOnForwardFailure yes` を書けば `ssh HomeNAS` 一発で使える

# 最終的なアクセス先 (2026-11-19 適用済み)

NAS eth1 に `192.168.2.200/24` を設定したため、下流 `$pwnd#` 側からは IPv4 で直接アクセスできる:

| URL | 内容 | 状態 |
|---|---|---|
| `http://192.168.2.200:8001/` | **エレコム NAS Web UI (Django)** | 200 Loginpage ✅ |
| `https://192.168.2.200:8443/` | 同上 (stunnel 経由) | 200 Loginpage ✅ |
| `http://192.168.2.200:880/` | OpenWrt LuCI (変更なし) | 200 ✅ |
| `http://192.168.2.200:80/` | 独自サイト (変更なし) | 200 HTML5 sample ✅ |

- 上流 TP-Link 側からは従来どおり `http://192.168.0.222:8001/` / `:880` / `:80` も有効
- 外部からは引き続き SSH トンネル (`ssh -N -L 127.0.0.1:18080:127.0.0.1:8001 HomeNAS`) を使用
- 適用内容: `/etc/config/network` の `wan2` に `ipaddr 192.168.2.200`、
  `gateway` 削除、`accept_ra 1` 維持。バックアップ `network.bak-20261119` あり

## ログイン動作検証 (2026-11-19)

- ログイン画面: `username` は `admin` 固定(readonly)、`password` 入力、
  `csrfmiddlewaretoken` hidden、submit 先は `/dashboard/`
- **`admin` のパスワードは 2026-11-19 に利用者依頼で既定値 `admin` にリセット済み**
  (Django シェルで既定値へ更新。DB バックアップ `db.sqlite3.bak-20261119` あり)。
  `admin` / `admin` で HTTPS `:8443` からログイン成功、`/dashboardview/` (title
  `Elecom NAS|Top`) を確認。**ただし `admin` は `is_staff=False` / `is_superuser=False` の
  一般ユーザー**で、superuser は `stack` アカウント(認証情報は `secret.md`)
- 実機 Django DB に存在するアカウント **`stack`** でログイン成功
  (認証情報は `secret.md`)。POST は **HTTPS `:8443` 経由**で行うこと:
  HTTP `:8001` から POST すると `https://<host>:8001/` へ 302 され、
  そのポートは平 HTTP なので失敗する
- 成功時: `http=200`、最終 URL `/dashboardview/`、`<title>Elecom NAS|Top</title>`、
  `Loginpage` 文字列なし。セッション Cookie で `/filesharing/` も 200。
  `/drives/` はアプリ側で 500 (認証とは無関係)
- 検証用の Cookie/HTML 一時ファイルは削除済み

# 選択肢 (比較)

| # | 方式 | 中継先 | ユーザーの URL | 評価 |
|---|---|---|---|---|
| 1A | nginx を 8080 でリバースプロキシ | `127.0.0.1:8001` | `http://NAS:8080/` | **推奨**。80 は独自サイトのまま、NAS Web UI を nginx エンジンで配信 |
| 1B | nginx :80 にホスト名 vhost を追加 | `127.0.0.1:8001` | `http://nas-ui.lan/` | ポート番号不要。DNS/hosts 要準備。default server (独自サイト) は維持 |
| 2 | 既存の stunnel :8443 を使う | `127.0.0.1:8001` | `https://NAS:8443/` | 設定変更ゼロ、暗号化済み。 Ports 8443 を開けておくだけ |
| 3 | SSH ポートフォワード | `127.0.0.1:8001` | 手元 `http://localhost:8080/` | 装置側設定ゼロ・安全。毎回 ssh が必要 |
| 4 | IP エイリアスにバインド | 別 IP:8001 | `http://192.168.0.223:8001/` | 同一ポート 80 を複数用途に使いたい場合 |
| 5 | nginx 単体で NAS Web UI を配信 | — | — | Django を nginx 直配信するには WSGI ブリッジが必要。0.7 + 古い uClibc では非推奨 |

# 推奨設定例 (1A: nginx 8080 → Django 8001)

`/etc/nginx/sites-enabled/webui-proxy.conf` を新規作成:
```
server {
    listen 8080;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_redirect off;
        proxy_read_timeout 120;
    }
}
```

Django 側は変更不要 (ALLOWED_HOSTS='*')。80 番の既存 vhost には影響しない。

適用と検証:
```
nginx -t
/etc/init.d/nginx reload
curl -I http://127.0.0.1:8080/          # 200 + Loginpage が返ること
curl -s http://127.0.0.1:8080/ | grep -i Loginpage
curl -I http://127.0.0.1:8080/dashboard/ # ログインへリダイレクトされれば配信 OK
```
切り戻し: `/etc/nginx/sites-enabled/webui-proxy.conf` を削除して `nginx reload` のみ。

# 注意

- LuCI (880) の `/cgi-bin/luci` 絶対リダイレクト問題は 8001 側には無い。ただし **Django の
  `STATIC_URL = /static/` 等はルート基準**なので、やはり「別ポート/別ホスト名でルートごと proxy」する
- 既存の `Disk1-html.conf` は server_name 無しの default server なので、
  `server_name` 付き vhost を 1B で追加しても独自サイトは壊れない
- 8001 は `0.0.0.0` で公開されている。nginx 経由に統一するなら Django を
  `127.0.0.1:8001` にバインドし直す (起動スクリプトの `runserver` 引数変更、要バックアップ)
- **未適用**。どの方式を採るかは利用者の判断待ち
