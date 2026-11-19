---
type: Guide
title: NSB-3NR を Web サーバーとして使う — 動的サイト公開の手段
description: nginx 0.7.67 + fcgiwrap の実測構成、CGI/FastCGI/リバースプロキシ/PHP の比較と、公開 URL・権限・セキュリティ上の注意
generated: { by: agent, at: 2026-11-19T14:20:00Z }
status: draft
stale_after: 2027-02-17T00:00:00Z
---

# 現状 (2026-11-19 実測)

- Web サーバ: **nginx 0.7.67**(:80 / :9090)、設定 `/etc/nginx/{nginx.conf,sites-enabled/*}`
- 公開ドキュメントルート: `/volNAS/Disk1/.html` → symlink → **`/volNAS/Disk1/share/public_html`**
- **fcgiwrap 1.0.3-1 が 4 プロセス常駐** (`/usr/bin/fcgiwrap`、2025 年から)、
  unix socket **`/tmp/cgi.sock`** をリッスン
- nginx の両 server block に以下が既に設定済み:
  ```
  location ~ \.pl|cgi$ {
      gzip off;
      fastcgi_pass unix:/tmp/cgi.sock;
      fastcgi_index index.pl;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      include /etc/nginx/fastcgi_params;
  }
  ```
- 利用可能な言語: perl 5.10 / microperl / **perl-fcgi 0.74** / CGI::Fast / fcgi /
  lua 5.1 / python 2.7 / **PHP は未インストール**
- 公開ホスト名の実測:
  - `http://nullpower.ddns.net/` → 200、`HTML5 sample`(2157 bytes)= 独自サイト
  - `http://x00.f5.si/` → 200、`TEST`(933 bytes)(別ドキュメントルート? 要確認)
  - `http://nsmr0604.f5.si/` → 200(1204 bytes)= ルータ側 DDNS の可能性

# 実測: 動的 CGI はすでに動く

`/volNAS/Disk1/share/public_html/__dyn_test.cgi` に以下を置いて chmod +x し、
公開 URL からアクセスした結果:

```
#!/usr/bin/perl
print "Content-Type: text/plain; charset=utf-8\r\n\r\n";
print "CGI_OK\n"; print "time=" . scalar(localtime) . "\n"; ...
```

```
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
CGI_OK
time=Thu Nov 19 23:15:59 2026
method=GET  uri=/__dyn_test.cgi  server=nginx/0.7.67
```

→ **追加インストールなしで動的サイトを公開できる**(テスト後ファイルは削除済み)。
存在しない `.cgi` を叩くと fcgiwrap がエラーになり **502** が返る点に注意。

# 手段の比較

| # | 方式 | 準備 | 性能 | 評価 |
|---|---|---|---|---|
| 1 | **CGI (Perl / sh / Python) via fcgiwrap** | ファイルを置いて chmod +x だけ | リクエスト毎プロセス起動 | **最も手軽。まずこれ** |
| 2 | **Perl FastCGI (`CGI::Fast`)** | 常駐アプリ + 専用 socket + nginx location 追加 | 中〜高 | 中程度のトラフィック向け |
| 3 | **Python WSGI / CGI + nginx proxy** | 別ポートでアプリを起動し `proxy_pass` | 中 | 既存 Django (:8001) と分離すれば安全 |
| 4 | **静的 HTML + CGI で JSON 生成 + JS fetch** | 1 と同じ | 高(キャッシュ可) | 参照系ダッシュボードに最適。`data.json`(781KB) の活用例 |
| 5 | **PHP** | php-cgi の導入が必要 | — | **非推奨**。下記注意参照 |
| 6 | 外部バックエンド (Cloudflare Workers / VPS) | nginx `proxy_pass` で中継 | 高 | NAS に処理を載せたくない場合 |

# 推奨の実装パターン

## パターン A: すぐ動かす (Perl CGI)

`public_html/hello.cgi` に shebang `#!/usr/bin/perl` を付けて `chmod 755`。
`Content-Type` ヘッダ + 空行 + HTML を出力する。`REQUEST_METHOD` / `QUERY_STRING` /
`REQUEST_URI` 等の環境変数でリクエスト情報が取れる(実測で確認済み)。

## パターン B: アプリを分離してリバースプロキシ

NAS 管理 UI(Django :8001) とは別に、自作アプリを `127.0.0.1:8xxx` で起動し、
nginx に専用ロケーションを追加:
```
location /app/ {
    proxy_pass http://127.0.0.1:8xxx/;
    proxy_set_header Host $host;
}
```
Django 開発サーバをそのまま公開せず、アプリ側でバインド先を loopback に限定する。

# セキュリティ上の注意 (重要)

- **fcgiwrap は root で動作しており、CGI スクリプトも root 権限で実行される**。
  CGI 内で `system()` / バッククォートに外部入力を渡すと **-root で任意コマンド実行**になる。
  入力検証を徹底し、可能なら `fcgiwrap -u nobody` で権限降格を検討する
  (現在の起動方法は要確認・変更時は :9090 のメディアサーバ CGI にも影響)
- **PHP ソースが丸見え**: `/clientinfo.php` は PHP ハンドラが無いため
  `Content-Type: text/plain` で **PHP ソースがそのまま配信されている**(実測)。
  公開したくない場合はファイルを削除するか、nginx に
  `location ~ \.php$ { return 404; }` を追加すること
- PHP を導入する場合、opkg.conf の feed は `bcm53xx` スナップショットを向いており
  **この機種 (Cortina/armv7/uClibc) と ABI が合わない**。無理に入れず、
  静的ビルドするなら `ipk-build.md` の musl クロス環境を使う(工数大)
- `:80` はグローバルに公開済み (`nullpower.ddns.net` で到達確認)。CGI を置くなら
  IP 制限や Basic 認証を nginx 側で掛けることも検討する

# サーバーサイド JavaScript の検討 (2026-11-19)

## ランタイム比較と本機での現実性

| ランタイム | 本機での可否 | 理由 |
|---|---|---|
| **Node.js (公式 linux-armv7l)** | × | glibc 前提。本機は uClibc 0.9.32。カーネル 3.4.86 も古い |
| **unofficial-builds の musl 版** | × | `arm64-musl` / `x64-musl` のみ提供、`armv7l-musl` は無い (確認済み) |
| **Deno / Bun** | × | 近代カーネル + glibc 要件 |
| **QuickJS / Duktape / MuJS 等軽量エンジン** | **○** | C ソースを musl クロスで静的ビルド可能。npm は無いが JS 言語は動く |
| **Node アプリを外部で動かし nginx から proxy** | ○ | WSL / VPS / Cloudflare Workers 側で動かし、`proxy_pass` で中継 |

## QuickJS をビルドして実機検証 (成功)

- ソース: `https://bellard.org/quickjs/quickjs-2024-01-13.tar.xz`
- WSL の musl ARM クロス(gcc 11.2.1)で静的ビルド:
  ```
  make CROSS_PREFIX=<arm-linux-musleabihf-> HOST_CC=gcc LDFLAGS="-static" \
       LIBS="-lm -ldl -lpthread -latomic" qjs
  ```
  (`-latomic` は **LIBS 側**に置くこと。LDFLAGS だとリンカが object より前に置いて unresolved になる)
- 生成物: `qjs` = **ELF 32-bit ARM / statically linked / 4.4MB**
  (`V:\NAS\analysis\webui\qjs-arm` に複製)
- 実機で動作確認: `QJS_OK 3 <ISO日時>`、`std.getenv()` も CLI では正常
- **CGI としても公開成功**:
  - `/volNAS/Disk1/share/public_html/.qjs/` に qjs と JS を配置
  - ラッパー `jshello.cgi` (`#!/bin/sh` + `exec .../qjs .../hello.js`) を chmod +x
  - `http://nullpower.ddns.net/jshello.cgi` → **HTTP 200**、動的時刻・HTML を出力 ✅
- **注意**: fcgiwrap 経由では `std.getenv('REQUEST_URI')` 等が `undefined` になった
  (shell CGI からは env が見えているので QuickJS 側の問題)。実用では
  ラッパーから `exec qjs script.js "$REQUEST_URI" "$REQUEST_METHOD"` と
  **コマンドライン引数で渡し、JS 側は `scriptArgs[1]` 等を使う**のが確実
- デモ用 CGI は公開中。削除する場合:
  `rm -f /volNAS/Disk1/share/public_html/jshello.cgi` (`.qjs/` も不要なら削除)

## 結論

- ** lightweight JS なら今すぐ動く**(QuickJS + fcgiwrap)。npm は無いが、
  動的 HTML / JSON API を JS で書ける
- **本格的な Node アプリ(Express/Next.js 等)は NAS 上では非現実的**。
  必要なら外部ランタイム + `proxy_pass` を選ぶ

# NAS と `$pwnd#` ルータのスペック比較 (2026-11-19 実測)

| 項目 | NAS (NSB-3NR) | `$pwnd#` ルータ (Elecom / MediaTek MT7622) |
|---|---|---|
| CPU | **Cortina CS752x / Cortex-A9 ×2** (armv7l, NEON) | **ARMv8 aarch64 / Cortex-A53 ×2** (`CPU part 0xd03`, AES/SHA/CRC 拡張) |
| BogoMIPS | 1594.16 / core | 25.00 / core (aarch64 では参考値) |
| RAM | **890,000 kB (約 869MB)** | **500,500 kB (約 489MB)** |
| Kernel | 3.4.86 | **6.6.110** |
| libc | uClibc 0.9.32 | musl (OpenWrt 24.10.4) |
| 永続ストレージ | NAND 512MB + overlay **144MB 空き** + SATA 1TB | overlay **7.9MB 中 1.3MB 空きのみ** |
| 一時領域 | /tmp 429MB | /tmp(tmpfs) 173MB 空き |

**評価**:
- **純粋な計算・OS の新しさはルータ側が上**(A53 は A9 より新しい ARMv8 で 64bit、
  カーネルも 6.6、Node 20 がそのまま入る)。ただしコア数は両方 2
- **メモリ・ストレージ・I/O は NAS が圧倒的に上**(RAM 約 1.7 倍、実際のディスクあり)
- Web サーバとしての「公開口」は NAS(:80) なので、
  **NAS をフロントにしてルータへ処理を投げる**形が自然

# ルータ側へ処理を投げる方法 (可能)

- ルータの opkg feed は **OpenWrt 24.10.4 / aarch64_cortex-a53** 正式リポジトリを向いており、
  `opkg update` で**Node.js 20.20.2-r2 と node-npm が利用可能**(実測)。
  `python3 3.11.18` も利用可
- ただし **overlay 空き 1.3MB** では root へインストール不可。
  `opkg install --dest ram node node-npm` で **/tmp(tmpfs, 173MB 空き)** に入れるなら
  Node 本体 14MB(圧縮) 程度で余裕あり。**再起動で消える**点に注意
  (起動スクリプトで再導入するか、USB ストレージ/extroot の検討が必要)
- 公開フロー例:
  ```
  クライアント → TP-Link → NAS nginx :80
                    └─ location /node/ { proxy_pass http://192.168.2.254:3000/; }
                                          ↑ ルータ上で動く Node アプリ
  ```
  NAS とルータは同じ 192.168.2.0/24 に居り、ルータの lan ゾーンは ACCEPT なので
  LAN 内通信は通る(実測で NAS からルータ SSH 到達済み)
- Node アプリは **LAN 側アドレス `192.168.2.254` にバインド**し、WAN 側へは出さないこと
- 注意: ルータは RAM 489MB のうち既に 70MB 程度を使用。Node + npm を常駐させると
  余裕がさらに減るため、軽量な API 处理に留めるのが安全。重い処理は外部 VPS / Workers へ

# Cloudflare Workers への `proxy_pass` 検討 (2026-11-20)

## Workers でできること(サーバー JS 以外)

- 言語: JS/TS の他、**WebAssembly**(Rust/C/C++ 等)、**Python**(Pyodide)、他 WASM 言語
- 実行モデル: Workers(HTTP)、**Durable Objects**(状態保持・WebSocket・調整)、
  **Cron Triggers**(定期実行)、**Queues**(非同期キュー)、**Workflows**(永続実行)、
  Service Bindings、Email Workers
- ストレージ: **KV**(分散 KVS)、**D1**(SQLite)、**R2**(オブジェクト/S3 互換)、
  Hyperdrive(Postgres)、Vectorize(ベクトル検索)、Analytics Engine
- ネットワーク/変換: fetch、WebSocket、TCP socket、**HTMLRewriter**(ストリーミング HTML 書換)、
  Image Resizing、mTLS、Smart Placement、Cloudflare Access / Tunnel
- AI/ observability: **Workers AI**、AI Gateway、Tail Workers、Logpush、Rate Limiting
- 静的: Workers Assets / Pages

## 本機からの `proxy_pass` の落とし穴 (重要)

**NAS の nginx 0.7.67 は SSL モジュール無し** (`nginx -V` に `--with-http_ssl_module` が無く、
バイナリに `https protocol requires SSL support` の文字列)。したがって
`proxy_pass https://<worker>.<account>.workers.dev/` は **そのままでは使えない**
(HTTPS も SNI も不可)。対策:

1. **ルータ上の Node.js を TLS 対応リバースプロキシにする**(推奨) —
   Node の https モジュールは SNI を自動処理。`NAS nginx --HTTP--> router Node --HTTPS(SNI)--> Worker`
2. nginx を SSL/SNI 対応で静的ビルドし直す(工数中)
3. ユーザーを直接 Worker のカスタムドメインへ飛ばし、Worker 側から Cloudflare Tunnel で
   自宅 NAS を参照する構成(公開口を NAS に置く前提を見直す案)
4. HTTP で呼んでリダイレクトを追う方式は非推奨

認証は Worker 側で共有シークレット ヘッダを検証するか Cloudflare Access を使う。
無料枠は代表的に 10 万 req/日・10ms CPU/req 程度 (2026 時点、要確認)。

# 未確認

- `x00.f5.si` / `nsmr0604.f5.si` がどの server block / ホストに着地しているか
  (DNS と nginx `server_name` の対応を次回確認)
- fcgiwrap の起動スクリプト/権限降格の可否
