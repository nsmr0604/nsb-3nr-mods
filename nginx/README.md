# nginx / lighttpd 設定と proxy 例

`*.conf` は実機から取得した設定のコピーです。

- `nginx.conf` — nginx 0.7.67 本体 (`/etc/nginx/nginx.conf`)
- `nullpower.conf` — `server_name x00.f5.si ...` の公開サイト (`:80`)
- `Disk1-html.conf` — default server (`:80`)、`root /volNAS/Disk1/.html`
- `ms-cgi.conf` — `/www-ms` メディアサーバ (`:9090`)
- `lighttpd.conf` / `nullpower-inc.conf` — lighttpd 本体と HTTPS (`:443`) の設定

## NAS Web UI を 80 番に戻さず公開する

NAS の nginx 0.7.67 は **SSL モジュール無し** (SNI も不可) なので、
Cloudflare Workers などの HTTPS 宛に直接 `proxy_pass` はできません。
次の 2 段構成的が現実的です。

```
クライアント → NAS nginx :80 --HTTP--> ルータ Node.js --HTTPS(SNI)--> Worker
```

### ルータ Node へ中継する例 (NAS 側)

```nginx
location /node/ {
    proxy_pass http://192.168.2.254:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
}
```

### ホスト名 vhost で NAS 管理 UI (Django :8001) を出す例

```nginx
server {
    listen 80;
    server_name nas-ui.lan;
    location / {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_redirect off;
    }
}
```

`:880` の LuCI と `:80` の既存サイトには影響しません。
