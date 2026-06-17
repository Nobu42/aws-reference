# Day 4 Learning: CloudWatch Logs・Metric Filter・Alarm確認

## 学習開始前に実行するスクリプト

Day 4以降は、可能な限り実リソースを起動して確認する。Day 4はCloudWatch Logsを実物で見る日であるため、原則として日次ラボ環境とアプリケーションを起動してから進める。

`sample-vpc`が存在しない場合:

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。続いてAnsibleを実行する。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

起動後、CloudWatch Logsへ送る対象アプリケーションが動いていることを確認する。

```bash
cd /Users/nobu/aws-reference/ansible

ansible web \
  --become \
  --module-name shell \
  --args 'systemctl is-active puma-nobu-iac-lab && curl --silent --show-error --fail http://localhost:3000/ >/dev/null && echo "Rails response: OK"'
```

CloudWatch LogsのLog Groupが見えることを確認する。

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output table \
  --no-cli-pager
```

Day 4のためだけにCloudTrail一時Trailを作成しない。Day 3から一時Trailを残している場合だけ、状態確認スクリプトを実行する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

S3 Data Eventは有効化しない。

学習終了後、Day 5以降で同じ環境を使わない場合は、課金対象リソースを削除する。

```bash
/Users/nobu/aws-reference/scripts/cleanup_network.sh
/Users/nobu/aws-reference/scripts/check_cleanup.sh
```

## 1. 今日の目的

CloudWatch Logsに保存されたログを確認し、ログから異常を検知してAlarmへつなげる流れを理解する。

Day 4では設定変更を行わず、既存設定の確認、ログ検索、検知設計の整理を行う。

関連資料:

- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [MFAなし管理コンソールログイン検知手順](../docs/references/06_mfa_console_login_detection.md)
- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)

## 実行場所・開始前提・終了処理

AWS CLIコマンド自体はどのディレクトリからでも実行できるが、学習時の実行場所を統一する。

```bash
cd /Users/nobu/aws-reference/day-learning
pwd
```

期待値:

```text
/Users/nobu/aws-reference/day-learning
```

### 開始前に確認する状態

| 項目 | Day 4での扱い |
|---|---|
| アプリケーション環境 | `/nobu-iac-lab`配下のアプリログを確認する場合は、`All_Setup.sh`とAnsibleによる構築・設定が完了していることを確認する |
| 一時Trail | Day 3から残っている場合は確認対象にできる。存在しない場合もDay 4のためだけに再作成しない |
| TrailのCloudWatch Logs連携 | 設定済みか未設定かを確認する。Day 4では変更しない |
| S3 Data Event | Day 4では不要。有効化せず、Day 3で有効化した場合は切り戻し済みであることを確認する |
| CloudWatch設定 | Log Group、Metric Filter、Alarmの現在値を確認する。Day 4では作成・変更・削除しない |

一時Trailが存在する場合は、必要に応じて次のスクリプトで状態を確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

`DataResourceCount=0`であれば、一時TrailにS3 Data Eventは設定されていない。

一時Trailが存在しない場合、上記確認スクリプトは実行しない。CloudTrail Event Historyおよび既存CloudWatch設定の確認を続ける。

### Day 4終了時の判断

Day 4では設定変更を行わないため、CloudWatch設定の切り戻しは不要である。

| 状態 | 終了時の対応 |
|---|---|
| Day 3の追加検証などで一時Trailを明示的に使用する | 一時Trailを残し、S3 Data Eventが無効であることを確認する |
| 一時Trailを後続学習で使用しない | Day 3の専用削除スクリプトで一時Trailとログ保存先バケットを削除する |
| アプリケーション環境を当日これ以上使用しない | 課金対象リソースを通常のクリーンアップ手順で削除する |
| ローカル証跡 | 確認・報告が終わるまで残す |

一時Trailを削除する場合:

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

アプリケーション環境を削除する場合:

```bash
/Users/nobu/aws-reference/scripts/cleanup_network.sh
```

一時Trail削除スクリプトは、Rails画像保存先の`nobu-terraform-iac-lab-upload`を削除しない。

## 今日の確認順序

1. 作業対象のAWSアカウントとリージョンを確認する
2. CloudWatch Logsの役割を整理する
3. Log Group一覧を確認する
4. 対象Log Groupの設定を確認する
5. Log Streamと最新ログを確認する
6. `filter-log-events`でログを検索する
7. Logs Insightsでログを検索する
8. CloudTrailからCloudWatch Logsへの連携状況を確認する
9. Metric Filterの役割と既存設定を確認する
10. Filter Patternをテストする
11. CloudWatch Alarmの役割と既存設定を確認する
12. 検知の流れ、影響範囲、報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 主な確認対象 | CloudWatch Logs、CloudTrail連携、Metric Filter、CloudWatch Alarm |
| 設定変更 | なし |
| 主な証跡 | Webコンソール画面、AWS CLI確認結果 |

## 今日実行しない操作

次の操作はCloudWatch設定や課金へ影響するため、Day 4では実行しない。

- Log Groupの作成・削除
- Retentionの変更
- Metric Filterの作成・削除
- CloudWatch Alarmの作成・削除
- CloudTrailからCloudWatch Logsへの連携設定
- SNS通知先の設定

---

## 2. CloudWatchの役割を理解する

CloudWatchは、AWSリソースやアプリケーションの状態を監視するためのサービスである。

CloudWatch Logs、Metrics、Metric Filter、Alarmは役割が異なる。

| 機能 | 役割 |
|---|---|
| CloudWatch Logs | ログをLog Groupへ保存し、検索・監視する |
| Log Group | 同じ用途のログをまとめる単位 |
| Log Stream | Log Group内でログ送信元ごとに分ける単位 |
| Logs Insights | CloudWatch Logsをクエリで検索・集計する |
| Metric Filter | ログ内の特定パターンを検出し、数値メトリクスへ変換する |
| CloudWatch Metrics | 時系列の数値データを保存する |
| CloudWatch Alarm | メトリクスが指定条件を満たした場合に状態を変更する |
| SNS | Alarm発生時にメールや外部通知先へ通知する |

## ログ検知の基本的な流れ

```text
AWSサービスまたはアプリケーション
↓
CloudWatch Logs Log Group
↓
Metric Filter
↓
CloudWatch Custom Metric
↓
CloudWatch Alarm
↓
SNSなどの通知先
```

CloudTrailイベントを監視する場合は、次の流れになる。

```text
AWS API操作
↓
CloudTrail
↓
CloudWatch Logs Log Group
↓
Metric Filter
↓
CloudWatch Alarm
↓
通知・調査
```

## 重要な違い

CloudTrail Event Historyでイベントを検索できても、CloudTrailからCloudWatch Logsへ連携済みとは限らない。

| 状態 | 意味 |
|---|---|
| Event Historyで確認可能 | CloudTrailのManagement Eventを過去90日間検索できる |
| TrailがS3へ配信 | Trailが継続的にイベントをS3へ保存する |
| TrailがCloudWatch Logsへ配信 | Metric Filterなどによるリアルタイムに近いログ検知が可能になる |

---

## 3. 作業対象の確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. CloudWatchコンソールを開く
5. 左側メニューから「ロググループ」を開く

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_CloudWatch_Log_Group一覧.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

期待値:

```text
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
```

### 結果の読み方

- `Account`が想定AWSアカウントIDと一致することを確認する
- `Arn`から操作主体を確認する
- 想定外のアカウントの場合は後続作業を中止する

### 報告例

```text
作業対象AWSアカウントおよび東京リージョンであることを確認した。
本作業ではCloudWatch Logs、Metric Filter、Alarmの設定確認のみを行い、
設定変更は実施しない。
```

---

## 4. Log Group一覧の確認

Log Groupは、同じ用途のログをまとめる保存単位である。

現在のラボでは、Ansibleから次のLog Groupを作成している。

| Log Group | 主なログ |
|---|---|
| `/nobu-iac-lab/nginx/access` | nginxアクセスログ |
| `/nobu-iac-lab/nginx/error` | nginxエラーログ |
| `/nobu-iac-lab/puma/stdout` | Puma標準出力 |
| `/nobu-iac-lab/puma/stderr` | Puma標準エラー |

### Webコンソール

1. CloudWatchを開く
2. 「ログ」から「ロググループ」を開く
3. `/nobu-iac-lab`で検索する
4. 4つのLog Groupが存在することを確認する
5. 各Log GroupのRetention、保存済みバイト、KMS Key IDを確認する

取得するスクリーンショット:

```text
03_nobu_iac_lab_Log_Group一覧.png
```

### AWS CLI

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

| 項目 | 確認内容 |
|---|---|
| `LogGroup` | 対象のLog Group名 |
| `RetentionDays` | ログ保持日数 |
| `StoredBytes` | 保存済みログ容量 |
| `KmsKeyId` | カスタマー管理KMSキーのARN |
| `Class` | Log Group Class |

`RetentionDays`が`None`または空の場合、ログは無期限保持となる。

`KmsKeyId`が`None`または空の場合、暗号化されていないという意味ではない。CloudWatch Logsのデフォルト暗号化が使用され、カスタマー管理KMSキーは関連付けられていない状態である。

### 今回の期待値

```text
Log Group: /nobu-iac-lab/nginx/access
Log Group: /nobu-iac-lab/nginx/error
Log Group: /nobu-iac-lab/puma/stdout
Log Group: /nobu-iac-lab/puma/stderr
RetentionDays: 7
```

### 影響調査の観点

Retentionを変更する場合は、次を確認する。

- 監査要件で必要な保存期間
- 障害調査に必要な期間
- ログ容量と保存料金
- 既存ログが削除対象になる時期
- S3などへの長期保管有無

### 報告例

```text
CloudWatch Logsで対象アプリケーションの4つのLog Groupを確認した。
各Log Groupの保持期間、保存容量、KMSキー関連付け状況を確認した。
設定変更は実施していない。
```

---

## 5. 対象Log Groupの設定確認

nginxアクセスログを対象に、Log Groupの詳細設定を確認する。

### Webコンソール

1. `/nobu-iac-lab/nginx/access`を開く
2. 「詳細」またはLog Group情報を確認する
3. Retention、ARN、作成時刻、KMS Key ID、Log Group Classを確認する
4. 「メトリクスフィルター」タブの有無を確認する
5. 「サブスクリプションフィルター」タブの有無を確認する

取得するスクリーンショット:

```text
04_nginx_access_Log_Group詳細.png
```

### AWS CLI

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab/nginx/access \
  --query 'logGroups[].{LogGroup:logGroupName,Arn:arn,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 対象Log Groupが1件表示されることを確認する
- Retentionが運用・監査要件と一致するか確認する
- KMSキー関連付けが要件と一致するか確認する
- Log Group名が命名規則に沿っているか確認する

---

## 6. Log Streamと最新ログの確認

Log Streamは、Log Group内でログ送信元を分ける単位である。

現在のラボでは、Webサーバーごとに異なるLog Streamが作成される。

### Webコンソール

1. `/nobu-iac-lab/nginx/access`を開く
2. Log Stream一覧を確認する
3. 最新イベント時刻が新しいLog Streamを開く
4. Webアクセスログが記録されていることを確認する
5. ブラウザまたは`curl`でWebサイトへアクセスし、ログが増えることを確認する

取得するスクリーンショット:

```text
05_nginx_access_Log_Stream一覧.png
06_nginx_access_最新ログ.png
```

### AWS CLI: Log Stream一覧

```bash
aws logs describe-log-streams \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[].{LogStream:logStreamName,LastEventTimestamp:lastEventTimestamp,StoredBytes:storedBytes}' \
  --output table \
  --no-cli-pager
```

### AWS CLI: 最新ログの確認

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 複数のWebサーバーからLog Streamが作成されているか確認する
- 最新アクセスがCloudWatch Logsへ送信されているか確認する
- CloudWatch Agent停止や権限不足によるログ欠落がないか確認する

### 注意事項

`storedBytes`は常に最新値を示すとは限らない。

ログ本文にはIPアドレス、URL、ユーザー識別情報などが含まれる可能性があるため、証跡の外部公開前にマスクする。

---

## 7. filter-log-eventsによるログ検索

`filter-log-events`は、Log Group内のログを簡単な条件で検索するコマンドである。

### nginxアクセスログからHTTP 200を検索する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --filter-pattern '" 200 "' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### nginxエラーログからerrorを検索する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/error \
  --filter-pattern 'error' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### Puma標準エラーを確認する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stderr \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 検索結果なしは、必ずしも異常ではない
- Log Group、検索文字列、時間範囲、ログ形式を確認する
- エラーログが空の場合は、現在エラーが記録されていない可能性がある
- 期待するログ自体が存在しない場合は、CloudWatch Agentやログ出力元を確認する

### 実務での注意点

大量ログを無制限に検索すると、確認に時間がかかり証跡も読みにくくなる。

実務では次の条件を先に絞る。

```text
対象AWSアカウント
対象リージョン
対象Log Group
対象時間帯
検索するイベント名またはエラー文字列
対象リソース名
```

---

## 8. Logs Insightsによるログ検索

Logs Insightsは、CloudWatch Logsをクエリで検索・集計する機能である。

`filter-log-events`より複雑な検索、並び替え、件数集計に向いている。

### Webコンソール

1. CloudWatchを開く
2. 「ログ」から「ログ分析」を開く
3. `/nobu-iac-lab/nginx/access`を選択する
4. 時間範囲を直近15分または1時間へ絞る
5. クエリを入力して実行する

基本クエリ:

```text
fields @timestamp, @message, @logStream
| sort @timestamp desc
| limit 20
```

`error`を含むログの検索例:

```text
fields @timestamp, @message, @logStream
| filter @message like /error/
| sort @timestamp desc
| limit 20
```

取得するスクリーンショット:

```text
07_Logs_Insights検索結果.png
```

### AWS CLI

`start-query`の`--start-time`と`--end-time`はUnix時刻の秒で指定する。

まず、検索対象時間の値を決める。Macで直近1時間を検索する場合は、次を実行する。

```bash
START_TIME=$(date -v-1H +%s)
END_TIME=$(date +%s)

printf 'START_TIME=%s\nEND_TIME=%s\n' \
  "$START_TIME" "$END_TIME"
```

`START_TIME`には現在時刻の1時間前、`END_TIME`には現在時刻のUnix秒が設定される。

特定のJST時間帯を検索する場合は、次のように指定する。

```bash
START_TIME=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-16 05:00:00' +%s)
END_TIME=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-16 06:00:00' +%s)

printf 'START_TIME=%s\nEND_TIME=%s\n' \
  "$START_TIME" "$END_TIME"
```

検索したいJST日時へ置き換えて使用する。Unix秒へ変換された値を手入力する必要はない。

クエリを開始する。

```bash
QUERY_ID=$(aws logs start-query \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string 'fields @timestamp, @message, @logStream | sort @timestamp desc | limit 20' \
  --query queryId \
  --output text \
  --no-cli-pager)
```

Query IDを確認する。

```bash
printf 'QUERY_ID=%s\n' "$QUERY_ID"
```

検索結果を確認する。

```bash
aws logs get-query-results \
  --profile learning \
  --region ap-northeast-1 \
  --query-id "$QUERY_ID" \
  --output table \
  --no-cli-pager
```

### 結果の読み方

| Status | 意味 |
|---|---|
| `Scheduled` | 実行待ち |
| `Running` | 検索中 |
| `Complete` | 検索完了 |
| `Failed` | 検索失敗 |
| `Cancelled` | 検索中止 |
| `Timeout` | タイムアウト |

`Running`の場合は、少し待ってから`get-query-results`を再実行する。

### 料金と検索範囲

Logs Insightsは検索対象データ量に応じて料金が発生する。

次を守る。

- 対象Log Groupを絞る
- 時間範囲を必要最小限にする
- 必要なフィールドだけ表示する
- `limit`を設定する

---

## 9. CloudTrailからCloudWatch Logsへの連携確認

CloudTrailイベントをMetric Filterで検知するには、TrailからCloudWatch Logsへの配信設定が必要である。

Day 3でEvent Historyを検索できたことだけでは、CloudWatch Logs連携済みとは判断できない。

### Webコンソール

1. CloudTrailコンソールを開く
2. 「証跡」を開く
3. 対象Trailを開く
4. CloudWatch Logs連携先を確認する
5. Log Group名とIAM Roleを確認する

取得するスクリーンショット:

```text
08_CloudTrail_CloudWatch_Logs連携確認.png
```

### AWS CLI

```bash
aws cloudtrail describe-trails \
  --profile learning \
  --region ap-northeast-1 \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,IsMultiRegionTrail:IsMultiRegionTrail,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

| 項目 | 意味 |
|---|---|
| `CloudWatchLogsLogGroupArn` | CloudTrailイベントの配信先Log Group ARN |
| `CloudWatchLogsRoleArn` | CloudTrailがCloudWatch Logsへ書き込むIAM Role ARN |
| 値が表示される | CloudWatch Logs連携が設定されている |
| `None`または空 | CloudWatch Logs連携が設定されていない |

### 連携済みの場合の追加確認

`CloudWatchLogsLogGroupArn`からLog Group名を確認し、CloudWatch Logs側で存在を確認する。

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes}' \
  --output table \
  --no-cli-pager
```

### 未連携の場合の判断

CloudWatch Logs連携が未設定でも、CloudTrail Event HistoryやS3配信が利用できる場合がある。

未連携は即時障害とは限らない。次を確認してから改善候補として扱う。

- リアルタイムに近い検知が必要か
- Metric FilterとAlarmを利用する要件があるか
- 既存のSIEMや監視製品へ別経路で連携しているか
- ログ保存期間と料金要件
- CloudTrailが使用するIAM Roleの作成・変更影響

### 報告例

```text
CloudTrailからCloudWatch Logsへの連携状況を確認した。
CloudWatchLogsLogGroupArnおよびCloudWatchLogsRoleArnは未設定であった。
Event Historyの利用可否とは別の設定であり、Metric Filterによる検知要件を
確認したうえで連携要否を判断する必要がある。
設定変更は実施していない。
```

---

## 10. Metric Filterの役割と既存設定確認

Metric Filterは、CloudWatch Logs内のログがFilter Patternへ一致した回数や値をCloudWatch Metricsへ変換する。

Metric Filter自体は通知しない。通知にはCloudWatch AlarmやSNSなどを組み合わせる。

### 検知例

| 検知対象 | CloudTrail EventName例 |
|---|---|
| S3 Bucket Policy変更 | `PutBucketPolicy`、`DeleteBucketPolicy` |
| Public Access Block変更 | `PutPublicAccessBlock`、`DeletePublicAccessBlock` |
| Security Group受信ルール変更 | `AuthorizeSecurityGroupIngress`、`RevokeSecurityGroupIngress` |
| CloudTrail停止 | `StopLogging`、`DeleteTrail` |
| MFAなし管理コンソールログイン | `ConsoleLogin`かつ`MFAUsed = No` |

### Webコンソール

1. CloudWatch Logsの対象Log Groupを開く
2. 「メトリクスフィルター」タブを開く
3. Metric Filter名、Filter Pattern、Metric Namespace、Metric Nameを確認する
4. 作成・編集・削除は行わない

取得するスクリーンショット:

```text
09_Metric_Filter一覧.png
```

### AWS CLI: アプリLog Groupの既存Metric Filter確認

```bash
aws logs describe-metric-filters \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --query 'metricFilters[].{FilterName:filterName,FilterPattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 出力あり: 対象Log GroupにMetric Filterが設定されている
- 出力なし: 対象Log GroupにMetric Filterが設定されていない
- 出力なしでもLog Groupやログ収集に異常があるとは限らない

### Metric Filter確認時の重要項目

| 項目 | 確認内容 |
|---|---|
| Filter Name | 用途を識別できる名前か |
| Filter Pattern | 検知対象イベントへ正しく一致するか |
| Metric Namespace | 現場の命名規則に沿っているか |
| Metric Name | Alarmが参照するメトリクスと一致するか |
| Metric Value | 一致時に加算する値が適切か |
| Default Value | ログが一致しない場合の値が要件に合うか |

---

## 11. Filter Patternのテスト

`test-metric-filter`を使うと、Metric Filterを作成せずにFilter Patternの一致結果を確認できる。

この操作はLog GroupやMetric Filterを変更しない。

### PutBucketPolicyイベントのテスト

```bash
aws logs test-metric-filter \
  --profile learning \
  --region ap-northeast-1 \
  --filter-pattern '{ ($.eventSource = "s3.amazonaws.com") && ($.eventName = "PutBucketPolicy") }' \
  --log-event-messages '["{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"PutBucketPolicy\"}"]' \
  --output table \
  --no-cli-pager
```

### 一致しないイベントのテスト

```bash
aws logs test-metric-filter \
  --profile learning \
  --region ap-northeast-1 \
  --filter-pattern '{ ($.eventSource = "s3.amazonaws.com") && ($.eventName = "PutBucketPolicy") }' \
  --log-event-messages '["{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"GetBucketPolicy\"}"]' \
  --output table \
  --no-cli-pager
```

### 期待結果

```text
PutBucketPolicy:
一致結果が表示される

GetBucketPolicy:
一致結果が表示されない
```

### Filter Patternの読み方

```text
$.eventSource = "s3.amazonaws.com"
かつ
$.eventName = "PutBucketPolicy"
```

`$`はJSONログ全体を表し、`$.eventName`はJSON内の`eventName`フィールドを表す。

### 実務での確認順序

```text
実際のログ形式を確認する
↓
検知したいフィールドと値を決める
↓
test-metric-filterで一致・不一致を確認する
↓
誤検知と見逃しの可能性を確認する
↓
承認後にMetric Filterを設定する
↓
テストイベントでCustom MetricとAlarmを確認する
```

---

## 12. CloudWatch Alarmの役割と既存設定確認

CloudWatch Alarmは、指定したメトリクスが条件を満たした場合に状態を変更する。

Alarmの主な状態:

| 状態 | 意味 |
|---|---|
| `OK` | しきい値を超えていない |
| `ALARM` | しきい値条件を満たしている |
| `INSUFFICIENT_DATA` | 判定に必要なデータが不足している |

### Webコンソール

1. CloudWatchを開く
2. 「アラーム」から「すべてのアラーム」を開く
3. Alarm名、状態、Metric、しきい値を確認する
4. Alarm Actionが有効か確認する
5. 通知先が設定されている場合はSNS Topicを確認する
6. 作成・編集・削除は行わない

取得するスクリーンショット:

```text
10_CloudWatch_Alarm一覧.png
```

### AWS CLI

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,Namespace:Namespace,MetricName:MetricName,Statistic:Statistic,Period:Period,EvaluationPeriods:EvaluationPeriods,Threshold:Threshold,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

| 項目 | 確認内容 |
|---|---|
| `AlarmName` | 用途が識別できる名前か |
| `State` | 現在のAlarm状態 |
| `Namespace` | 監視対象メトリクスの名前空間 |
| `MetricName` | 監視するメトリクス |
| `Statistic` | Average、Sum、Maximumなど |
| `Period` | 1回の評価期間 |
| `EvaluationPeriods` | Alarm判定に使う評価回数 |
| `Threshold` | しきい値 |
| `ActionsEnabled` | 通知・自動アクションが有効か |

### Alarmが表示されない場合

Alarmが表示されない場合は、次を確認する。

- `--alarm-name-prefix`が正しいか
- 対象リージョンが正しいか
- Alarmが未作成か
- Composite Alarmのみ存在していないか
- 別AWSアカウントに作成されていないか

### Metric FilterとAlarmの対応確認

Metric Filterが出力する`Namespace`と`Metric Name`が、Alarmの監視対象と一致する必要がある。

```text
Metric Filter:
Namespace = SecurityMonitoring
Metric Name = PutBucketPolicyCount

Alarm:
Namespace = SecurityMonitoring
Metric Name = PutBucketPolicyCount
```

名前が一致しない場合、ログがMetric Filterに一致してもAlarmは反応しない。

---

## 13. 検知設計の整理

### S3 Bucket Policy変更検知

```text
PutBucketPolicyまたはDeleteBucketPolicyを実行
↓
CloudTrailがManagement Eventとして記録
↓
CloudTrailがCloudWatch Logsへイベントを配信
↓
Metric Filterが対象EventNameを検出
↓
Custom Metricへ1を記録
↓
CloudWatch AlarmがALARMへ遷移
↓
担当者がCloudTrail詳細と変更後設定を確認
```

### MFAなし管理コンソールログイン検知

```text
ConsoleLoginイベントが発生
↓
CloudTrailがイベントを記録
↓
CloudWatch Logsへ配信
↓
Metric FilterがConsoleLoginかつMFAUsed=Noを検出
↓
CloudWatch AlarmがALARMへ遷移
↓
担当者が利用者、送信元IP、時刻、結果を調査
```

MFAなしログイン検知の具体的な作成・テストはDay 5で扱う。

### Metric Filterだけでは判断できないこと

Metric Filterは、ログ内の文字列やJSONフィールドが条件へ一致したことを数える仕組みである。

次の判断は別途必要になる。

- 変更が承認済みか
- 正当な作業者による操作か
- 設定変更後の状態が正しいか
- アプリケーションへ影響が発生したか
- 切り戻しが必要か

---

## 14. 証跡取得と報告

### 取得する証跡一覧

| No. | 証跡 | 確認内容 |
|---|---|---|
| 01 | 操作アカウント確認 | AWSアカウントID、操作主体 |
| 02 | Log Group一覧 | 対象Log Groupの存在 |
| 03 | Log Group詳細 | Retention、KMS、保存容量 |
| 04 | Log Stream一覧 | ログ送信元と最新イベント |
| 05 | 最新ログ | ログが継続して保存されていること |
| 06 | Logs Insights結果 | 指定条件でログ検索できること |
| 07 | CloudTrail連携設定 | CloudWatch Logs連携先とIAM Role |
| 08 | Metric Filter一覧 | Filter Patternと出力Metric |
| 09 | Alarm一覧 | Alarm状態、しきい値、Action |

### スクリーンショット取得時の注意

- AWSアカウント、リージョン、対象リソースを識別できるようにする
- 対象設定と現在値が同じ画面に入るようにする
- 不要なブラウザタブ、個人情報、認証情報を含めない
- 長い画面は確認項目ごとに分ける
- 取得時刻と手順番号を作業記録へ残す

### CloudWatch確認結果の報告例

```text
CloudWatch Logs設定確認を実施した。

対象:
AWSアカウント 445405559057
リージョン ap-northeast-1

確認結果:
- アプリケーション用Log Group 4件が存在することを確認した
- 各Log GroupのRetentionは7日であることを確認した
- nginxアクセスログが継続して保存されていることを確認した
- Logs Insightsで対象ログを検索できることを確認した
- CloudTrailからCloudWatch Logsへの連携状況を確認した
- 既存Metric FilterおよびCloudWatch Alarmの設定状況を確認した

設定変更:
なし

要確認事項:
- CloudTrailイベントのリアルタイム検知要件
- 必要なログ保持期間
- Metric Filter、Alarm、通知先の運用設計
```

---

## 15. トラブルシューティング

### Log Groupが表示されない

確認項目:

- AWSアカウントが正しいか
- リージョンが`ap-northeast-1`か
- Log Group名またはprefixが正しいか
- AnsibleのCloudWatch Agent Playbookが完了しているか
- CloudWatch Agentが稼働しているか
- EC2のIAM Roleにログ送信権限があるか

### Log Streamはあるが最新ログがない

確認項目:

- アプリケーションやnginxがログを出力しているか
- CloudWatch Agentの設定ファイルが正しいか
- CloudWatch Agentが稼働しているか
- ログファイルのパスと読み取り権限が正しいか
- EC2からCloudWatch Logs APIへ通信できるか

### filter-log-eventsで結果がない

確認項目:

- 対象Log Groupが正しいか
- Filter Patternが実際のログ形式と一致しているか
- 対象時間帯にログが存在するか
- 大文字・小文字が一致しているか
- Log Streamへログが配信済みか

### Logs Insightsが完了しない

確認項目:

- `get-query-results`のStatusが`Running`ではないか
- 時間範囲が広すぎないか
- 対象Log Groupが正しいか
- クエリ構文が正しいか
- 同時実行クエリ数の上限へ達していないか

### Metric Filterがログへ一致しない

確認項目:

- 実際のログがJSON形式かプレーンテキスト形式か
- JSONフィールド名が正しいか
- EventNameや値の大文字・小文字が正しいか
- `test-metric-filter`で一致するか
- 対象イベントがCloudWatch Logsへ配信されているか

### AlarmがALARMにならない

確認項目:

- Metric FilterからCustom Metricが出力されているか
- NamespaceとMetric NameがAlarm設定と一致しているか
- Period、Evaluation Periods、Thresholdが適切か
- Alarm作成前に発生したログだけを見ていないか
- `treat-missing-data`の設定が要件に合っているか

---

## 16. 案件で説明できるポイント

### Log Group

```text
Log Groupは、同じ用途のログをまとめて保存する単位である。
確認時はLog Groupの存在だけでなく、Retention、KMSキー関連付け、
保存容量、Log Stream、最新イベント時刻を確認する。
```

### Metric Filter

```text
Metric Filterは、CloudWatch Logs内の特定ログパターンを検出し、
CloudWatch Custom Metricへ数値として出力する。
作成前に実際のログ形式を確認し、test-metric-filterで一致・不一致を検証する。
```

### CloudWatch Alarm

```text
CloudWatch Alarmは、メトリクスを一定期間評価し、
条件を満たした場合にALARM状態へ遷移する。
通知にはSNSなどのAlarm Actionを組み合わせる。
```

### CloudTrailとの関係

```text
CloudTrail Event Historyは変更履歴の検索に使えるが、
Metric FilterでCloudTrailイベントを検知するには
CloudTrailからCloudWatch Logsへの配信設定が必要になる。
```

---

## 17. セキュリティ上の注意点

- CloudWatch Logsにはユーザー名、IPアドレス、URL、リクエスト内容などが含まれる可能性がある
- 証跡をGitHubや外部へ公開する場合は、AWSアカウントID、ARN、IPアドレスなどをマスクする
- Log Groupの削除やRetention短縮は、監査ログの消失につながる
- Metric Filterの条件不備は、誤検知または見逃しにつながる
- Alarm Actionの誤設定は、不要な通知や意図しない自動処理につながる
- CloudTrail連携用IAM Roleは最小権限で設定する
- Logs Insightsは検索対象データ量に応じて料金が発生する

---

## 18. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| CloudWatch Logs | ログ保存、検索、Metric Filterの元データ |
| Logs Insights | CloudWatch Logsのクエリ検索・集計 |
| Metric Filter | ログパターンをCustom Metricへ変換 |
| CloudWatch Metrics | 時系列の数値データ |
| CloudWatch Alarm | Metricを評価して状態を変更 |
| SNS | Alarm通知先として利用可能 |
| CloudTrail | AWS API操作の監査ログ |
| CloudTrailとCloudWatch Logs連携 | CloudTrailイベントをMetric Filterで検知可能にする |
| Retention | Log Group単位のログ保持期間 |
| KMS | 必要に応じてCloudWatch Logsへカスタマー管理キーを関連付ける |

---

## 19. 要確認事項

現在のラボ環境では、次の項目が未確認または未設定の可能性がある。

- CloudTrailからCloudWatch Logsへの連携先Log Group
- CloudTrail連携用IAM Role
- CloudTrailイベントを対象にしたMetric Filter
- Metric Filterが出力するCustom Metric
- Custom Metricを監視するCloudWatch Alarm
- Alarm通知先SNS Topic

これらが未設定でも、Day 4では異常と断定しない。

Day 4では現在値を確認し、Day 5以降のMFAなし管理コンソールログイン検知で必要になる構成として整理する。

---

## 20. Day 4完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] CloudWatch Logs、Metric Filter、Alarmの役割を説明できる
- [ ] `/nobu-iac-lab`配下のLog Groupを確認した
- [ ] Retention、KMSキー関連付け、保存容量を確認した
- [ ] Log Streamと最新ログを確認した
- [ ] `filter-log-events`でログを検索した
- [ ] Logs Insightsでログを検索した
- [ ] CloudTrailからCloudWatch Logsへの連携状況を確認した
- [ ] 既存Metric Filterを確認した
- [ ] `test-metric-filter`で一致・不一致を確認した
- [ ] 既存CloudWatch Alarmを確認した
- [ ] CloudTrailからAlarmまでの検知の流れを説明できる
- [ ] 設定変更を行っていないことを確認した
- [ ] 確認結果と要確認事項を報告文へ整理した

## Day 4の完了条件

次を自分の言葉で説明できればDay 4は完了とする。

```text
Log Groupはログを保存する単位である。

Metric Filterは、ログ内の特定パターンをCustom Metricへ変換する。

CloudWatch Alarmは、Metricを評価して条件を満たした場合に
ALARM状態へ遷移し、必要に応じてSNSなどへ通知する。

CloudTrailイベントをMetric Filterで検知するには、
CloudTrailからCloudWatch Logsへの配信設定が必要になる。
```

## Day 4終了時チェック

- [ ] `/Users/nobu/aws-reference/day-learning`から学習を開始した
- [ ] Day 4ではCloudWatch設定を変更していない
- [ ] 一時Trailの有無とCloudWatch Logs連携状況を記録した
- [ ] S3 Data Eventを有効化していない、またはDay 3で切り戻し済みである
- [ ] 後続学習で一時Trailを使用するか判断した
- [ ] 不要な一時Trailは専用削除スクリプトで削除した
- [ ] 当日使用しない課金対象のアプリケーションリソースをクリーンアップした
- [ ] ローカル証跡を確認・報告用として残した
