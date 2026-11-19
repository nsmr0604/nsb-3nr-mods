# QuickJS (サーバーサイド JavaScript)

NAS の Node.js は glibc 前提で動かせないため、軽量な QuickJS を
musl ARM クロスで静的ビルドし、fcgiwrap 経由で CGI として動かします。

- `build-qjs.sh` — quickjs-2024-01-13 を `arm-linux-musleabihf-gcc` でビルド
  (`-latomic` は **LIBS** 側に指定するのがポイント)
- `bin/qjs` — ビルド済み ARM 静的バイナリ (4.4MB、実機で動作確認済み)
- `js-hello.js` / `jshello.cgi` — 公開 Web サーバで動くサンプル (`/jshello.cgi`)
- `dyn_test.cgi` / `qjs-test.js` — Perl CGI との比較用

## 実機への配置例

```sh
mkdir -p /volNAS/Disk1/share/public_html/.qjs
cp qjs /volNAS/Disk1/share/public_html/.qjs/
cp js-hello.js /volNAS/Disk1/share/public_html/.qjs/hello.js
cp jshello.cgi /volNAS/Disk1/share/public_html/jshello.cgi
chmod +x /volNAS/Disk1/share/public_html/jshello.cgi
```

`http://nullpower.ddns.net/jshello.cgi` で動的 HTML が返ります。

## 注意

- fcgiwrap 経由では `std.getenv('REQUEST_URI')` が `undefined` になるため、
  ラッパーから `exec qjs app.js "$REQUEST_URI"` として渡し、
  JS 側は `scriptArgs[1]` を使うこと
- CGI は root 権限で動くので入力検証を徹底してください
