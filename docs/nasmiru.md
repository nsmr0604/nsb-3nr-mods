---
type: Reference
title: NASみる (nasumiru) エージェント解析 — NSB-3NR の遠隔監視機構
description: 実機に搭載された NASみる (クラウド遠隔管理) の構成・ファイル・API・テレメトリ/イベント・セキュリティ上の所見と現在の稼働状態
generated: { by: agent, at: 2026-11-19T08:10:00Z }
status: stable
stale_after: 2027-02-17T00:00:00Z
---

# 概要

**NASみる** = この NAS (型番 **NSB-3NR_SERIES**、コード内の `fw_printenv board` 比較で確認) に
標準搭載されたクラウド遠隔監視サービス用エージェント。ホスト名/IP/温度/SMART/RAID/UPS などを
定期収集してクラウド (API Gateway + Azure IoT Hub) へ送り、異常イベントを通知する。

- 実装言語: **Python 2.7.10 / Django + Django REST Framework**
- サービス提供元 API: `https://anuapi.nasmiru.jp/v1/devices`
  (ステージング = `http://nasmiru-app-api-st.azurewebsites.net/v1/devices`、
  `/etc/nasmiru_staging` の有無で切替)。2026-11-19 時点で DNS は
  `d-ffub34jsu9.execute-api.ap-northeast-1.amazonaws.com` に解決され、無名 GET は 403
- テレメトリ送信先: `nasmiru-iothub.azure-devices.net` (Azure IoT Hub、SAS トークン認証)

# 構成とデータの流れ

```
[Web UI (nginx :9090 / lighttpd :880,443) / ローカル REST API :8001]
    |  Django REST (Session/Basic/Token, IsAuthenticated)
    v
/etc/init.d/nasmiruagentD → python /usr/bin/nasmiruagentD.py (常駐、0.5 秒メインループ)
    |-- nasmiru_registration.py / nasmiru_registration_confirm.py  → anuapi.nasmiru.jp
    |-- nasmiru_status_regular_get.py  → .status パケット生成
    |-- nasmiru_status_regular_upload.py → LIOTUPLD.py → Azure IoT Hub
    |-- nasmiru_event_regular.py       → /nasmiru/eventpool へイベント JSON
    |-- nasmiru_send_pow_sts.py / nasmiru_tmp_clear.py / nasmiru_event_test.py
    v
/nasmiru/eventpool ( kept 30 days or <=10MB ) → LIOTUPLD.py → IoT Hub
```

- 設定: `/etc/nasmiru/{setting.json,uploader.json,uploaderconfig.json,event_monitor.json,trigger_event.xml}`
- コード本体: `/root/celestial_NAS/nasmiru/*.py` (`/rom` にも同一のものが存在)
- 一時: `/var/nasmiru_agenttmp.json`、`/var/nasmiru_statustmp.json`、`/var/LIOTUPLD.lock`
- UI からの停止要求: `/var/nasmiru_uireq` / 応答 `/var/nasmiru_uiack` のファイル握握手
- 設定変更時は `/openwrt/usr/local/system/backup/etc/nasmiru` へバックアップ

# ローカル API (`urls.py` / `views.py`)

| パス | 内容 |
|---|---|
| `/nasmiru/` | 設定の GET / PUT (`nasmiru_service` の on/off、エージェント開始/停止) |
| `/nasmiru_test/` | テストイベント送信 |
| `/nasmiru_status/` | 任意タイミングのステータス更新 |
| `/nasmiru_detail/` | 温度・ファン閾値などの詳細設定 |
| `/register/` | メール/パスワード/機器名/シリアルでクラウド登録 |
| `/regist_confirm/` | 登録確認 (dev_id / 変更フラグ) |

- `DEFAULT_PERMISSION_CLASSES = IsAuthenticated` (Session / Basic / Token) が設定されており、
  実機の `curl http://127.0.0.1:8001/nasmiru/` は **`403 {"detail":"Authentication credentials were not provided."}`**
- ただしリスナーは `0.0.0.0:8001`、`iptables INPUT` は ACCEPT で、LAN から到達可能な状態

# 収集項目 (ステータス)

`nasmiru_status_regular_get.py` の 17 関数:
`get_dev_id` / `get_date` / `get_uptime` / `get_ng_type` / `get_cpu_load` / `get_mem_load` /
`get_host_name` / `get_cpu` / `get_case_fan` / `get_hd` / `get_vlm` / `get_ex_dev` /
`get_ntwk` / `get_bkup` / `get_ups` など。取得には `i2c_test`、`hdparm`、`smartctl`、
`fw_printenv`、`ifconfig`、`df`、syslog DB などを呼び出す。

周期: `agt_status_sec` = 271 秒、`agt_daily_sec` = 271 秒 (設定ファイルの初期値)、
登録確認とイベント監視は 60 秒間隔。

# 監視イベント (`nasmiru_event_regular.py` / `event_monitor.json`)

イベント ID → 内容 (抜粋):

| ID | 内容 | ID | 内容 |
|---|---|---|---|
| 1010 | 予期せぬシャットダウン | 4010 | SMART 注意変化 |
| 1050 | システム起動 | 4020 | SMART 値変化 |
| 1060 | シャットダウン | 4030 | UPS 通信切断/復旧 |
| 1070 | ホスト名変更 | 4060 | 温度異常/復旧 |
| 1080 | IP 変更 | 4070 | ファン回転数異常/復旧 |
| 1090 | DNS 変更 | 4090 | デバイス接続 |
| 1100 | デフォルト GW 変更 | 4100 | デバイス取外し |
| 1120 | FW アップデート | 4120 | HDD ボリューム離脱 etc. |
| 2010 | バックアップ失敗/成功 | 4150 | HDD エラー |
| 3010 | RAID 冗長性障害/修復 | 5040 | メール通知設定変更 |
| 3030 | 残容量低下/回復 | 5060 | エージェント初期化 |

状態は `current_sts` に 1=要注意/2=対応中/3=復旧 で保持し、前回値 `last_val` と比較して
変化のみを通知する。

# 現在の状態 (2026-11-19 実測)

- `/etc/nasmiru/setting.json`: `nasmiru_service=on`、**`registered=n`**、`device_id` 空
  → エージェントプロセスは常駐しているが、登録済みでないため定期送信は実質動作していない
- `event_monitor.json` の `last_run_time` = **2022-02-04 08:46:09**
- アップローダの SAS 有効期限も **2022-02-04** (`se=1643933178`) で失効済み
- → クラウド側との連携は 2022 年初頭以降停止した状態。API ドメイン自体は存続

# セキュリティ上の所見

1. **平文のメール資格情報**: `/etc/nasmiru/event_monitor.json` の `events.5040` に Gmail の
   ユーザー/アプリパスワード/宛先が平文で保存 (取得した値は `secret.md` に隔離し、
   ローカル解析コピーはマスキング済み)。通知メール設定変更イベント用
2. **base64 の Device SAS**: `/etc/nasmiru/uploader.json` に IoT Hub の SAS トークンと
   デバイス固有 URL が base64 で同梱 (暗号化ではない)。失効済みだがファームに焼き込まれている
3. **TLS 検証の無効化**: `nasmiru_registration.py` が
   `ssl._create_default_https_context = ssl._create_unverified_context` を設定 →
   登録 API への通信は MITM に対して無防備
4. **コマンド注入の可能性**: `views.py:RegisterAPI` が POST の mail/password/device_name/
   serial/device_id をほぼエスケープせずにシェル文字列へ連結し `commands.getoutput()` に渡す
   (`escape()` は `\` と `"` のみ)。DRF 認証が掛かっているため即時の公開 RCE ではないが、
   認証済みユーザーからは任意コマンド実行が可能
5. ポート 8001 が `0.0.0.0` でリッスン、iptables INPUT が ACCEPT (認証は required)
6. コード品質: `FILE_UPLOADLOCK = '/var/LIOTUPLD.lock"'` の余分な引用符、
   `pResponse(...)` タイポ、`e.args` を文字列連結する例外処理など。Python 2.7 / Django 開発サーバを
   本番で使っており保守性・安全性は低い

# 後継サービス「アドミリンク」への移行可否 (2026-11-19 調査)

- エレコム公式: **NASみるは 2022-05-05 で終了**、後継の **アドミリンク (AdminLink) は
  2022-05-09 に開始**。NASみる自体は NSB-3 シリーズ (ファーム 1.07-1522 以上) も対象だった
  (= 本機の 1.08 は旧サービスの対象) が、**サービス終了により無効**
- Linux NAS 用アドミリンクの配布物は `Adminlink_1.02.00.zip` (22,571,051 bytes、
  2022-12-05、最終版)。中身は **`Adminlink_1.02.00.qpkg` = QNAP/QTS 用 QPKG パッケージ**
  (`/sbin/getcfg`、`/share/MD0_DATA`、"Install QNAP package on TS-NAS" 等を確認)
- 対応機種は **NSB-5A / NSB-7A シリーズのみ**、必要条件は **ファームウェア 4.3.6.1256 以降**。
  説明書には「4.3.3.0776 以前のバージョン、及び**他の製品には使用しないでください**」と明記
- → 本機 (NSB-3NR / OpenWrt 系 1.08 / uClibc / kernel 3.4 / Cortex-A9) には
  **公式・非公式を問わず移植は事実上不可能** (OS/ABI/アーキテクチャが異なる QTS QPKG、
  クラウド側もサポート対象外で登録できない)
- 現実的な選択肢:
  1. **完全一致を諦めて代替監視を自作** — 本セッションの `ipk-build.md` の環境で
     同等のステータス/イベント収集エージェントを作り、自前のサーバへ送る (推奨)
  2. アドミリンク対応機 (NSB-5A/7A) へ本体を交換
  3. 何もしない (旧エージェントは死亡したクラウド向けに何も送信していないため実害は少ない)
- 調査用に取得した QPKG: `V:\NAS\analysis\adminlink\Adminlink_1.02.00.zip` と
  `pkg\Adminlink_1.02.00.qpkg`

# 成果物 (V:\NAS\analysis\nasmiru)

- `nasmiru/` — エージェント Python 一式 + JSON 設定 (機密値はマスキング)
- `nasmiruagentD.py` / `nasmiruagentD` / `nasmiruagentD.control` — デーモン本体と opkg 情報
- `www-ms/` — Web UI (Perl CGI + Template Toolkit、nginx :9090 / lighttpd :880,443)。
  NASみる本体とは別のメディアサーバアプリで、README には `grabber.pl` での
  メタデータ DB 構築手順が書かれている
- `extract_secrets.ps1` — 資格情報を `secret.md` へ隔離しローカルコピーをマスキングしたスクリプト
