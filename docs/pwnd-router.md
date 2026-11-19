---
type: Reference
title: 下流 `$pwnd#` ルーター (エレコム製 OpenWrt) の外部観測構成
description: NAS の下流に置かれた Elecom OpenWrt ルーターのホスト名・ポート・DNS/DHCP・Wi-Fi・NAS との関係を読み取り専用で確認した記録。UCI 内部設定は未取得
generated: { by: agent, at: 2026-11-19T13:10:00Z }
status: draft
stale_after: 2027-02-17T00:00:00Z
---

# 概要

`$pwnd#` は **エレコム製ハードウェア + OpenWrt 系ファームウェア**の Wi-Fi ルーターで、
上流の TP-Link(PPPoE / 192.168.0.0/24) の配下に置かれ、
**IPv6 だけパススルーで受けて IPoE 接続**している (利用者説明 + 実測で裏取り済み)。

- 管理 IP / 既定 GW: **192.168.2.254**
- DNS 名: **OpenWrt.lan**(逆引きも `254.2.168.192.in-addr.arpa → OpenWrt.lan`)
- ドメイン: `lan`(PC の逆引きは `DELL.lan`)
- ファームの HTTP 秘跡: `Last-Modified: Sun, 19 Oct 2025 16:37:45 GMT`、
  ETag `"4e3-298-68f513d9"`、HTTP レスポンスに `Server` ヘッダなし (uhttpd 典型)

# OpenWrt / Elecom である証拠

| 証拠 | 内容 |
|---|---|
| DNS 逆引き | `Server: OpenWrt.lan` / `PTR 254.2.168.192 → OpenWrt.lan` |
| HTTP :80 | 200、`meta refresh → cgi-bin/luci/`、本文に **`LuCI - Lua Configuration Interface`** |
| HTTPS :443 | 200、同じ LuCI スプラッシュ画面 |
| MAC OUI | AP BSSID `38:97:a4:24:9b:2a`、有線 GW MAC `38:97:a4:24:9b:27` → **OUI `38:97:A4` = ELECOM CO.,LTD.** (IEEE MA-L 登録) |
| DNS 応答 | `google.com` を IPv6 `2404:6800:...` で返す = IPoE/IPv6 優先 |

# 観測されたサービス

| ポート | 状態 | 備考 |
|---|---|---|
| 53/udp+tcp | OPEN | 自前 DNS。`lan` ドメインの PTR を引ける |
| 80/tcp | OPEN | LuCI HTTP。`GET /` = 200 スプラッシュ。`GET /cgi-bin/luci/` は **403 だがこれがログイン画面** (`x-luci-login-required: yes`)。HTML に `<title>OpenWrt - LuCI</title>`、ユーザー名初期値 `root` |
| 443/tcp | OPEN | LuCI HTTPS (自己署名)。80 と同じログイン画面 |
| 22/tcp | closed | 標準 SSH は無効 |
| **2222/tcp** | **OPEN** | **SSH-2.0-dropbear** (OpenWrt 定番の代替 SSH ポート。利用者の習慣どおり) |
| **7681/tcp** | **OPEN** | **ttyd/1.7.3 (libwebsockets/4.3.3) の Web ターミナル**。`server: ttyd/1.7.3 (libwebsockets/4.3.3-unknown)`、`GET /` = 200 / `<title>ttyd - Terminal</title>` (664KB HTML)。Basic 認証なしでページが返るため、到達できる者が Web からシェルを使える可能性 → 要注意 |
| 1900/udp (SSDP) | 応答なし | UPnP 無効の可能性 |
| 8080 / 9090 | closed | — |

**ポートスキャン (2026-11-19)**: `1-10000` を並列 TCP スキャン + 代表的な高位ポート
(8000/8080/8443/8888/9000/9090/10000/22222 など) を probe → 開いているのは
**53 / 80 / 443 / 2222 / 7681 のみ**。全 1-65535 の並列スキャンは並列度/タイムアウトの
都合で取りこぼしが出たため、上記レンジ + 個別 probe で確定した。

**ファームウェア**: ログインページより **OpenWrt 24.10.4 r28959-29397011cc**、
テーマ `openwrt2020`、LuCI リソース版 `25.340.26705~d88390b`。
→ 「`:80` で Web UI が開かない」は故障ではなく **LuCI が 403 + `x-luci-login-required` で
ログインを要求している**だけ。管理者パスワードがあればログイン可能。

# DHCP / アドレス付与 (PC 側から観測)

- PC `Wi-Fi 3`: DHCP 有効、**DHCP サーバー = 192.168.2.254**(ルータ自身)
- IPv4 リース: 取得 2026-11-18 04:50 / 有効期限 2026-11-19 23:35 (約 43 時間 = 短期リースの設定?)
- IPv6 は SLAAC で `2400:4052:3700:cc00::/64` (global) と `fdaf:8f93:d1f1:1::/64` (ULA) が付与
- デフォルト GW: IPv4 `192.168.2.254` / IPv6 `fe80::3a97:a4ff:fe24:9b27`
- 配布 DNS: **`2a10:50c0::ad1:ff`, `2a10:50c0::ad2:ff`**(外部 IPv6 DNS。ルータ自身ではない)
- Wi-Fi: SSID `$pwnd#` / WPA3-Personal (H2E) / 5GHz ch40 / BSSID `38:97:a4:24:9b:2a`
  / 信号 -50dBm (1201Mbps リンク)

# 上流との関係と NAS への影響

```
TP-Link (PPPoE, 192.168.0.0/24) ── NAS eth0 192.168.0.222
        │ (IPv6 パススルー)
        └─ $pwnd# (IPoE, 192.168.2.0/24) ── NAS eth1 (IPv6 のみ / IPv4 未設定)
                                          └─ PC 192.168.2.42
```

- NAS eth1 の IPv6 デフォルト GW `fe80::3a97:a4ff:fe24:9b27` はこのルータの LAN 側リンクローカル
- PC と NAS eth1 は同じ `2400:4052:3700:cc00::/64` に居るため IPv6 ping は 1〜3ms で通る
- 一方 IPv4 は二重 NAT で NAS eth0 (192.168.0.222) に到達できない
- NAS eth1 に一時的に `192.168.2.253/24` を付けたところ PC から ping 1ms / Web UI(8001) が
  200 で開けた → **ルータ側のファイアウォールが原因ではない** (NAS 側 UCI 設定の問題)

# UCI 設定の実測 (2026-11-19、SSH :2222 でログインして読み取り)

`uname -a`: **Linux OpenWrt 6.6.110 #0 SMP ... aarch64 GNU/Linux**(ビルド 2025-10-19)。
設定ファイル一式の複製: `V:\NAS\analysis\pwnd-router\config\*`。

## network

- `lan`: `br-lan`(lan1〜lan4)、`192.168.2.254/24`、`ip6assign 64` + `ip6hint 1`
  → ULA **`fdaf:8f93:d1f1:1::/64`** (観測値と一致)
- `wan6`: device `wan` / proto `dhcpv6` / `reqaddress try` / `ip6ifaceid eui64` / `extendprefix 1`
- `wan`: **proto `map` / `map-e`** — peeraddr `2001:380:a120::9`、ipaddr `153.151.80.0`、
  ip4prefixlen 20、ip6prefix `2400:4052:3400::/38`、ealen 18 / psidlen 6 / offset 6、
  mtu 1460、tunlink `wan6`、DNS 1.1.1.1/8.8.8.8
- `ipoe`: proto `dslite`、peeraddr `ksk01-aftr01-ngnintf.i.open.ad.jp`、**`auto 0` = 無効**
- `tailscale`: proto none / device `tailscale0`
- **IPv6 は DHCPv6-PD(IPoE)、IPv4 は MAP-E**。利用者の「IPoE」は IPv6 側を指し、
  厳密にはハイブリッド構成
- デフォルト IPv4 ルートは **`default dev map-wan`** のみ。
  **`192.168.0.0/24` へのスタティックルートは存在しない**
  → PC(192.168.2.x) から NAS eth0(192.168.0.222) へ IPv4 で行けない原因が確定

## dhcp / DNS

- dnsmasq: `domain lan`、`authoritative`、leasefile `/tmp/dhcp.leases`、
  addnhosts に adblock-fast のブロックリスト
- DHCP プール: `start 10` / `limit 220` → **192.168.2.10〜229**、`leasetime 6h`
- DHCP option 6 = `94.140.14.14,94.140.15.15` (AdGuard)、
  IPv6 DNS = `2a10:50c0::ad1:ff` / `::ad2:ff` (観測値と一致)
- dhcpv6 server + RA server (managed-config / other-config)、ndp relay、`wan6` で ra/ndp relay
- **静的リースが既に存在**: `name=homenas` / **`ip=192.168.2.200`** /
  `mac=BC:5C:4C:27:A3:8A`(NAS eth1) / `leasetime=infinite`
- 現在のリース: PC `.42`(DELL)、iPad `.90`、`.212`。**`.200` は未使用**(ping 応答なし)

## firewall / その他

- defaults: input REJECT / output ACCEPT / forward REJECT、synflood、flow offloading(hw)
- `lan` ゾーン: input/output/forward すべて ACCEPT
- `wan` ゾーン: input REJECT、masq 1、mtu_fix 1(`wan6`/`ipoe`/`wan`)、lan→wan forwarding 許可
- `tailscale` ゾーン: ACCEPT / masq、lan↔tailscale 双方向 forwarding 許可
- `192.168.0.0/24` 向けの許可ルール・ルートは無し
- `dropbear`: **Port 2222 / Interface lan / PasswordAuth on**
- `ttyd`: `interface @lan` / **`command /bin/login root`**
  → **Web ページ自体は無認証だが、端末を使うには root パスワード必須**
  (以前の「無認証でシェルが触れる」懸念は訂正)
- `uhttpd`: `0.0.0.0:80` / `[::]:80` / `:443`、`rfc1918_filter 1`、
  `cgi_prefix /cgi-bin`、`lua_prefix /cgi-bin/luci`、証明書 EC P-256 CN=OpenWrt
- `tailscale`: port 41641、`accept_routes 1`、**`advertise_exit_node 1`**、
  `advertise_routes 192.168.2.0/24`、`exit_node_allow_lan_access 1`
  → **Tailscale の exit node として稼働中**
- `ddns`: **v6.f5.si** で `nsmr0604.f5.si` を IPv6 更新(`use_ipv6 1`、`ip_network wan6`)。
  認証情報は `secret.md` に保管
- その他: adblock-fast、socat(example `enable 0`)、acme、luci(theme openwrt2020、
  session 3600s)、system(hostname `OpenWrt`、JST-9 / Asia/Tokyo)

# NAS 側 IPv4 付与の結論 (更新)

- **ルータに予約済みの正しいアドレスは `192.168.2.200`** (dhcp `config host` に NAS eth1 の
  MAC で定義済み)。一時検証で使った `.253` ではなく **`.200` を採用する**
- ルータ側の変更は**不要**(lan ゾーンは ACCEPT、NAS と同一セグメントで直接通信可能)
- NAS 側で `wan2` に `ipaddr 192.168.2.200` / `netmask 255.255.255.0` を入れ、
  `gateway 192.168.2.254` を削除(第 2 デフォルト GW 回避)、`accept_ra 1` は維持 →
  `ifdown wan2 && ifup wan2`
- 認証情報 (ルータ root / Wi-Fi / DDNS) は `secret.md` に集約済み
