---
type: Reference
title: 自宅 NAS を取り巻く二重ルータ / IPv4 PPPoE + IPv6 IPoE 構成 (実測)
description: TP-Link(PPPoE, 192.168.0.0/24) 配下に $pwnd# ルータを置き IPv6 だけパススルーで IPoE する構成、NAS が eth0/eth1 で両網にまたがる実測と Web UI 到達性への影響
generated: { by: agent, at: 2026-11-19T12:45:00Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# 構成 (2026-11-19 実測で確認)

```
        回線
         │
   ┌─────┴──────┐        IPv4: PPPoE (TP-Link が接続)
   │  TP-Link   │        LAN: 192.168.0.0/24, gw 192.168.0.1
   └─────┬──────┘        IPv6: 対応外 → パススルー
         │ 192.168.0.x (downstream の WAN)
   ┌─────┴──────┐
   │  $pwnd#    │        IPv6: IPoE で 2400:4052:3700:cc00::/64 を取得
   └─────┬──────┘        LAN: 192.168.2.0/24, gw 192.168.2.254
         │
      PC: Wi-Fi `$pwnd#` / 192.168.2.42
          IPv6 2400:4052:3700:cc00:74fc:5fe8:bbc0:cf1f/64
          ULA   fdaf:8f93:d1f1:1:.../64
```

**2026-11-19 訂正(ルータ UCI 確認後)**: 利用者の言う「IPoE」は IPv6 側のことで、
実機は **IPv6 = DHCPv6-PD(`wan6` / `extendprefix 1`)、IPv4 = MAP-E(`wan` / `proto map`、
peeraddr `2001:380:a120::9`)** というハイブリッド構成。`ipoe`(DS-Lite) セクションは
`auto 0` で無効。詳細は `pwnd-router.md`

**NAS は二つの網にまたがっている (dual-homed)**:

| IF | 側 | アドレス | デフォルトゲートウェイ |
|---|---|---|---|
| eth0 | TP-Link 側 (上流) | `192.168.0.222/24` (IPv4 のみ) | `192.168.0.1` |
| eth1 | `$pwnd#` 側 (下流) | **IPv4 なし** / IPv6 `2400:4052:3700:cc00:be5c:4cff:fe27:a38a/64` + ULA `fdaf:8f93:d1f1:1:be5c:4cff:fe27:a38a/64` | IPv6 `fe80::3a97:a4ff:fe24:9b27` dev eth1 |

- IPv6 デフォルトゲートウェイの MAC `3a:97:a4:ff:24:9b` は `$pwnd#` の AP BSSID
  `38:97:a4:24:9b:2a` と一致 (EUI-64) → **NAS eth1 は下流 `$pwnd#` 側に接続**
- `/etc/config/network` の `wan2` は `ifname eth1`, `proto static`, `gateway 192.168.2.254`,
  `accept_ra 1` (ipaddr 指定なし = IPv4 を持たない)
- NAS の IPv6 は EUI-64 (MAC BC:5C:4C:27:A3:89 由来) で** Prefix が変わらない限り安定**

# 到達性の実測

| 経路 | 結果 |
|---|---|
| PC → NAS `192.168.0.222` の 80/880/8001/8443/8080 | **すべてタイムアウト** |
| NAS → PC `192.168.2.42` ICMP | **100% パケットロス** |
| PC → NAS IPv6 global `2400:...:a38a` へ ping6 | **1〜2ms で応答 (0% ロス)** |
| PC → NAS IPv6 ULA `fdaf:...:a38a` へ ping6 | **1〜3ms で応答 (0% ロス)** |
| PC → NAS IPv6 の TCP 8001 / 8443 / 880 / 80 | **全部 "connection refused"** |
| 外部 → `nullpower.ddns.net` | 80 と 2222 のみ OPEN。8001/8443/8080 は未転送 |
| NAS 自身 → 8001 / 8443 | HTTP 200 (Web UI は正常) |

**結論**:
1. IPv4 は二重 NAT (上流 192.168.0.0/24 → 下流 192.168.2.0/24) で PC と NAS が隔離されている
2. IPv6 は PC と NAS eth1 が**同じ /64 に居るので L3 到達可能** (ping は通る)
3. しかし NAS 上のサービス (Django 8001 / nginx / lighttpd / stunnel / sshd) はすべて
   **IPv4 (0.0.0.0) バインド**のため、IPv6 TCP は RST (refused) になる
4. `iptables` / `ip6tables` の INPUT は policy ACCEPT (ブロックが原因ではない)

# `$pwnd#` ルータ自体も OpenWrt である (2026-11-19 確認)

PC のデフォルト GW `192.168.2.254` を probing した結果:

| 確認 | 結果 |
|---|---|
| DNS 逆引き | `Server: OpenWrt.lan / Address: 192.168.2.254` ← **ホスト名が OpenWrt** |
| HTTP :80 | 200、`meta refresh → cgi-bin/luci/`、本文 `<a href="cgi-bin/luci/">LuCI - Lua Configuration Interface</a>` |
| HTTPS :443 | 200、同じ LuCI スプラッシュ (自己署名) |
| ポート | 53 (DNS) / 80 / 443 が OPEN、22 (SSH) は closed |
| DNS 応答 | `google.com` が `2404:6800:...` (IPv6) で返る = IPoE/IPv6 優先構成と整合 |
| `/cgi-bin/luci/` 直接 | 403 (要認証/ACL。未ログインのため解析は未実施) |

→ **下流 `$pwnd#` も OpenWrt 系 (LuCI) で動作**。NAS も OpenWrt 系なので、
両方が OpenWrt という環境。NAS 側の `wan2`(eth1) が wan ゾーンとして扱われる問題は
「NAS 側 LuCI の設定モデル」に起因しており、ルータ側をいじらなくても
UCI 直接編集で回避できる (下記)。

# 見直し: eth1 に IPv4 を付与できるか (2026-11-19 追加検証)

利用者から「NAS の複数 NIC の 1 つが `$pwnd#` 側に接続されているが、過去に OpenWrt 系 Web UI
(LuCI) と相性が悪く IPv4 を付加できなかった」と補足あり。**再検証の結果、eth1 に IPv4 を
付けるのは技術的に可能で、Web UI もそのまま開ける**:

- `/etc/config/network` の `wan2` (eth1) は
  `proto static` / `netmask 255.255.255.0` / `gateway 192.168.2.254` / `accept_ra 1` だが
  **`option ipaddr` が無い** → これが「IPv4 が付かない」直接原因
- このファームには `config interface lan` が存在せず、firewall では `wan2` が **wan ゾーン**
  (`option network 'wan wan2 wan3'`, `masq 1`) に属する。LuCI は eth1 を WAN として扱うため、
  LAN 側の設定画面から静的 IP を入れても保存されない/上書きされる可能性が高い
  (`_orig_ifname` / `_orig_bridge` のメタも残っている)
- `gateway 192.168.2.254` を残したまま ipaddr を入れると **第 2 のデフォルトゲートウェイ**が
  でき、eth0 (192.168.0.1) と競合する。過去の「相性が悪い」はこれが原因と考えられる

**一時検証 (既に元に戻済み)**:
```
ip addr add 192.168.2.253/24 dev eth1
# PC から: ping 1ms / 8001,8443,880,80 すべて OPEN /
#          http://192.168.2.253:8001/ → HTTP 200 Loginpage
ip addr del 192.168.2.253/24 dev eth1   # 元の状態へ復帰
```
→ **二重 NAT を完全に回避でき、LuCI:880 も nginx:80 も触らずに Web UI が開く**
最もきれいな解決策。**ただし後日ルータの UCI を読んだところ、NAS eth1 の MAC に対して
`192.168.2.200` が静的リース予約されていた (nas/pwnd-router.md 参照) → 恒久化は `.200` を使う**

**永続化手順 (LuCI を使わず UCI 直接編集・2026-11-19 適用済み)**:
```
cp /etc/config/network /etc/config/network.bak-20261119
uci set network.wan2.ipaddr=192.168.2.200   # ルータ側で homenas に予約済み
uci set network.wan2.netmask=255.255.255.0
uci delete network.wan2.gateway        # 第2デフォルトGWを作らない
uci set network.wan2.accept_ra=1       # IPv6 は維持
uci commit network
ifdown wan2 && ifup wan2
```
- `.200` はルータ DHCP の `config host name=homenas mac=BC:5C:4C:27:A3:8A` で予約済み、
  現在未使用 (ping/ARP で確認)。一時検証に使った `.253` は予約外なので使わない
- ルータ側の設定変更は不要 (lan ゾーン ACCEPT、NAS と同一セグメント)
- IPv6 (SLAAC) は `accept_ra 1` のまま維持される
- 切り戻し: `/etc/config/network.bak-20261119` を戻して `ifdown/ifup wan2`

**適用後の実測 (2026-11-19)**:
- `ip -4 addr eth1` → `192.168.2.200/24`、デフォルト GW は引き続き `192.168.0.1 dev eth0` のみ
  (第 2 デフォルト GW は無い)
- PC から `ping 192.168.2.200` 成功、8001/8443/880/80 すべて OPEN
- **`http://192.168.2.200:8001/` → HTTP 200 `Loginpage`**、
  `https://192.168.2.200:8443/` → 200 `Loginpage` (NAS Web UI に到達可能)
- `:880` の LuCI・`:80` の独自サイト(HTML5 sample)はともに 200 のまま無影響
- DDNS 経由の SSH (`ssh HomeNAS`) も継続して成功

# Web UI を開くための最善手

- **今すぐ**: SSH トンネル (`ssh -N -L 127.0.0.1:18080:127.0.0.1:8001 HomeNAS`) →
  `http://127.0.0.1:18080/` で 200 Loginpage を実測確認済み
- **IPv6 を使うなら**: nginx は `--with-ipv6` 付きビルドなので、NAS の **ULA アドレス**
  にバインドするリスナーを追加し `proxy_pass http://127.0.0.1:8001/` すれば、
  PC から `http://[fdaf:8f93:d1f1:1:be5c:4cff:fe27:a38a]:<port>/` で開ける
  - **グローバル IPv6 にバインドしないこと** (IPv6 は NAT が無く、Web UI がインターネットに
    直接露出する。ULA なら LAN 内のみ)。外部アクセスは SSH トンネルを使う
  - lighttpd :880 (LuCI) と nginx :80 (独自サイト) には影響しない
- 二重 NAT を解消したいなら、PC を TP-Link 側 (192.168.0.x) に直接つなぐか、
  `$pwnd#` の WAN 側から 192.168.0.0/24 へのルーティング/NAT を許可する設定が必要
  (いずれにせよ今回の Web UI 問題は IPv6 で回避可能)
