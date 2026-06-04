# 04 CloudWatch CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、Amazon CloudWatchとCloudWatch LogsをAWS CLIで確認、作成、検索、検知設定するためのリファレンスである。

対象は、銀行系システムのように、AWS操作の監査証跡、セキュリティイベント検知、設定変更後のテスト、証跡取得、報告が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- CloudWatch Logs Log Group確認
- Log Group作成
- Retention設定
- Log Stream確認
- `filter-log-events` によるログ検索
- CloudWatch Logs Insightsによるログ検索
- Metric Filter作成
- Metric Filterのテスト
- CloudWatch Alarm作成
- Alarm状態確認
- Alarm通知設定の考え方
- 設定変更後の確認
- 切り戻し方法
- 証跡取得
- Teams報告例

CloudTrailのTrail作成、S3保存、CloudWatch Logs連携そのものは、以下を参照する。

```text
03_cloudtrail_cli_reference.md
```

MFAなし管理コンソールログイン検知の詳細な設計は、以下で別途扱う。

```text
06_mfa_console_login_detection.md
```

## 2. CloudWatchで見るもの

CloudWatchは、AWSリソースやアプリケーションのメトリクス、ログ、アラームを扱うサービスである。

この案件対策では、特に以下が重要になる。

| 領域 | 役割 | 例 |
| :--- | :--- | :--- |
| CloudWatch Logs | ログを保存、検索する | CloudTrailログ、nginxログ、Pumaログ |
| Metric Filter | Logsの内容からメトリクスを作る | MFAなしログイン件数、CloudTrail停止操作件数 |
| CloudWatch Metrics | 数値メトリクスを保存する | CPU使用率、ALB 5xx、Metric Filter由来のカスタムメトリクス |
| CloudWatch Alarm | メトリクスが条件を満たしたら状態変化させる | `ALARM`、`OK`、`INSUFFICIENT_DATA` |
| Logs Insights | SQL風のクエリでログを調査する | CloudTrailイベントの詳細調査 |

重要な考え方:

```text
CloudTrailでAWS操作イベントを記録する。
CloudTrailをCloudWatch Logsへ連携する。
CloudWatch Logsでイベントを検索する。
Metric Filterで検知対象イベントをメトリクス化する。
CloudWatch Alarmでメトリクスを監視する。
```

## 3. 作業前の共通変数

### 3.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

PROJECT_NAME="nobu-iac-lab"

# CloudTrailをCloudWatch Logsへ連携しているLog Groupを想定する。
LOG_GROUP_NAME="/aws/cloudtrail/nobu-iac-lab"

# Metric Filterで作成するカスタムメトリクスのNamespace。
METRIC_NAMESPACE="NobuIacLab/Security"

# Alarm名のPrefix。
ALARM_PREFIX="nobu-iac-lab"

# 通知を有効化する場合に使うSNS Topic ARN。
# このリファレンスでは、まず --no-actions-enabled で通知なしAlarmを作る。
SNS_TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:nobu-iac-lab-alerts"
```

注意:

- 実案件では、Log Group名、Metric Namespace、Alarm名は現場標準に合わせる
- 通知先SNS Topicを使う場合は、メール承認、Chatbot連携、運用ルールを確認する
- Metric Filter由来のメトリクスはカスタムメトリクス課金の対象になる

### 3.2 証跡ディレクトリ

```bash
WORK_NAME="cloudwatch_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 3.3 Caller Identity保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

## 4. CloudWatch作業のクイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | Log Group存在 | 対象Log Groupが存在 | `logs describe-log-groups` |
| 2 | Retention | 要件どおり | `logs describe-log-groups` |
| 3 | KMS暗号化 | 必要に応じて設定 | `logs describe-log-groups` |
| 4 | Log Stream | 最新ログが配送されている | `logs describe-log-streams` |
| 5 | ログ検索 | 対象イベントが検索できる | `logs filter-log-events` |
| 6 | Logs Insights | 条件付き検索ができる | `logs start-query` |
| 7 | Metric Filter | 想定Filterが存在 | `logs describe-metric-filters` |
| 8 | Custom Metric | メトリクスが存在 | `cloudwatch list-metrics` |
| 9 | Alarm | Alarmが存在 | `cloudwatch describe-alarms` |
| 10 | Alarm状態 | `OK` または目的に応じた状態 | `cloudwatch describe-alarms` |
| 11 | 通知Action | 通知有効化の有無が要件どおり | `describe-alarms` |
| 12 | 証跡 | before / afterが保存済み | JSON、スクリーンショット |

## 5. CloudWatch Logs Log Group確認

### 5.1 Log Group一覧

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays,KmsKeyId:kmsKeyId,StoredBytes:storedBytes,Class:logGroupClass,Arn:logGroupArn}' \
  --output table
```

証跡保存:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/01_describe_log_groups.json"
```

### 5.2 対象Log Group確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].{Name:logGroupName,Retention:retentionInDays,KmsKeyId:kmsKeyId,StoredBytes:storedBytes,Class:logGroupClass,Arn:logGroupArn}" \
  --output table
```

確認ポイント:

- 対象Log Groupが存在する
- Retentionが設定されている
- 必要に応じてKMS Keyが設定されている
- StoredBytesが異常に増えていない
- Log Group Classが要件どおりである

注意:

- Log Groupはデフォルトではログが期限切れしない
- 本番ではRetention期間を要件に合わせる
- CloudTrailログには利用者、IPアドレス、操作内容が含まれるため、証跡の扱いに注意する

## 6. Log Group作成

CloudTrail連携、アプリログ、検証用ログなどでLog Groupを作成する例である。

### 6.1 create-log-group

```bash
aws logs create-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME"
```

確認:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output table
```

### 6.2 Retention設定

```bash
aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days 90
```

確認:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].{Name:logGroupName,Retention:retentionInDays}" \
  --output table
```

確認ポイント:

- `retentionInDays` が想定値になっている
- 監査ログとして長期保管が必要な場合、S3保存や別保管も設計されている
- 短すぎるRetentionに変更すると、調査に必要なログが消える可能性がある

### 6.3 Retention削除

Log Groupを無期限保持に戻す。

```bash
aws logs delete-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME"
```

注意:

- 無期限保持はコスト増につながる
- 本番では削除前に保管要件を確認する

### 6.4 KMS暗号化の確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].{Name:logGroupName,KmsKeyId:kmsKeyId}" \
  --output table
```

KMS Keyを関連付ける例:

```bash
KMS_KEY_ARN="<kms-key-arn>"

aws logs associate-kms-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --kms-key-id "$KMS_KEY_ARN"
```

注意:

- CloudWatch Logsは対称KMS Keyを使う
- KMS Key PolicyでCloudWatch Logsサービスが利用できる必要がある
- 暗号化設定変更はログ参照権限にも影響する可能性がある

## 7. Log Stream確認

### 7.1 Log Stream一覧

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 20 \
  --query 'logStreams[*].{Stream:logStreamName,LastEventTime:lastEventTimestamp,LastIngestionTime:lastIngestionTime}' \
  --output table
```

証跡保存:

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/before/02_describe_log_streams.json"
```

確認ポイント:

- 新しいLog Streamが作成されている
- `LastEventTime` が古すぎない
- CloudTrail連携の場合、CloudTrail用のLog Streamが存在する
- アプリログの場合、EC2やホスト単位のLog Streamが存在する

### 7.2 最新Log Stream名を取得

```bash
LATEST_LOG_STREAM=$(aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

echo "$LATEST_LOG_STREAM"
```

### 7.3 get-log-events

特定Log Streamのログを取得する。

```bash
aws logs get-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --log-stream-name "$LATEST_LOG_STREAM" \
  --limit 20 \
  --output json \
  > "$EVIDENCE_DIR/after/03_get_log_events.json"
```

注意:

- `get-log-events` はLog Streamを指定する
- Log Group全体から横断検索する場合は `filter-log-events` やLogs Insightsを使う

## 8. ログ検索の時間指定

CloudWatch Logsの検索では、時間範囲を指定すると調査しやすい。

`filter-log-events` の `--start-time` / `--end-time` はUnix時刻ミリ秒で指定する。

### 8.1 LinuxでJST時刻をミリ秒へ変換

```bash
START_TIME_MS=$(TZ=Asia/Tokyo date -d '2026-06-04 09:00:00' +%s000)
END_TIME_MS=$(TZ=Asia/Tokyo date -d '2026-06-04 18:00:00' +%s000)

echo "$START_TIME_MS"
echo "$END_TIME_MS"
```

### 8.2 macOSでJST時刻をミリ秒へ変換

```bash
START_TIME_MS=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-04 09:00:00' +%s000)
END_TIME_MS=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-04 18:00:00' +%s000)

echo "$START_TIME_MS"
echo "$END_TIME_MS"
```

注意:

- 手順書ではJSTとUTCを明記する
- 実作業では、障害発生時刻、変更作業時刻、検知時刻を揃えて調査する

## 9. filter-log-eventsによるログ検索

### 9.1 キーワード検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "ConsoleLogin" \
  --max-items 20 \
  --output table
```

証跡保存:

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "ConsoleLogin" \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/04_filter_console_login_keyword.json"
```

### 9.2 時間範囲付き検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "ConsoleLogin" \
  --start-time "$START_TIME_MS" \
  --end-time "$END_TIME_MS" \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/after/05_filter_console_login_time_range.json"
```

### 9.3 JSONフィルタの基本

CloudTrailイベントはJSON形式のため、JSONフィルタを使う。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "ConsoleLogin" }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/06_filter_console_login_json.json"
```

### 9.4 MFAなしConsoleLogin検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed = "No") }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/07_filter_console_login_without_mfa.json"
```

確認ポイント:

- `eventName`
- `eventTime`
- `userIdentity`
- `sourceIPAddress`
- `responseElements.ConsoleLogin`
- `additionalEventData.MFAUsed`

### 9.5 S3 Bucket Policy変更検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "PutBucketPolicy" }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/08_filter_put_bucket_policy.json"
```

確認ポイント:

- 誰が変更したか
- どのバケットを変更したか
- 変更元IPアドレス
- 作業予定時間内のイベントか
- 想定外の `DeleteBucketPolicy` がないか

### 9.6 Security Group変更検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "AuthorizeSecurityGroupIngress") || ($.eventName = "RevokeSecurityGroupIngress") || ($.eventName = "AuthorizeSecurityGroupEgress") || ($.eventName = "RevokeSecurityGroupEgress") }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/09_filter_security_group_changes.json"
```

### 9.7 CloudTrail停止・変更検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "StopLogging") || ($.eventName = "DeleteTrail") || ($.eventName = "PutEventSelectors") || ($.eventName = "UpdateTrail")) }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/10_filter_cloudtrail_changes.json"
```

注意:

- CloudTrail停止や削除は監査ログ取得に影響する重要イベント
- 想定外イベントがあれば、作業者、時刻、対象Trail、変更内容を確認する

## 10. Filter Patternの読み方

CloudWatch LogsのFilter Patternは、Metric Filter、Subscription Filter、`filter-log-events` で使う。

| Pattern | 意味 |
| :--- | :--- |
| `ERROR` | `ERROR` という語を含むログ |
| `"Internal Server Error"` | 完全一致フレーズ |
| `ERROR -DEBUG` | `ERROR` を含み、`DEBUG` を含まない |
| `{ $.eventName = "ConsoleLogin" }` | JSONの `eventName` が `ConsoleLogin` |
| `{ $.responseElements.ConsoleLogin = "Failure" }` | ログイン失敗 |
| `{ $.additionalEventData.MFAUsed = "No" }` | MFA未使用 |
| `{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed = "No") }` | ConsoleLoginかつMFA未使用 |
| `{ $.sourceIPAddress != 10.* }` | 送信元IPが `10.*` ではない |

注意:

- Filter Patternは大文字小文字を区別する
- JSONフィルタでは `$.field` でプロパティを指定する
- `&&` と `||` で複合条件を作れる
- 複雑な条件は、まず `filter-log-events` で検索できるか確認してからMetric Filter化する

## 11. CloudWatch Logs Insightsによるログ検索

`filter-log-events` は簡易検索に向いている。

複数条件、整形表示、集計を行う場合はLogs Insightsを使う。

### 11.1 Logs Insightsの時間指定

Logs Insightsの `start-query` ではUnix時刻秒を指定する。

Linux:

```bash
START_TIME_SEC=$(TZ=Asia/Tokyo date -d '2026-06-04 09:00:00' +%s)
END_TIME_SEC=$(TZ=Asia/Tokyo date -d '2026-06-04 18:00:00' +%s)
```

macOS:

```bash
START_TIME_SEC=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-04 09:00:00' +%s)
END_TIME_SEC=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-04 18:00:00' +%s)
```

### 11.2 ConsoleLogin検索

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME_SEC" \
  --end-time "$END_TIME_SEC" \
  --query-string 'fields @timestamp, eventTime, eventName, userIdentity.arn, sourceIPAddress, responseElements.ConsoleLogin, additionalEventData.MFAUsed | filter eventName = "ConsoleLogin" | sort @timestamp desc | limit 50' \
  --query 'queryId' \
  --output text)

echo "$QUERY_ID"
```

結果取得:

```bash
aws logs get-query-results \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-id "$QUERY_ID" \
  --output json \
  > "$EVIDENCE_DIR/after/11_logs_insights_console_login.json"
```

確認ポイント:

- `status` が `Complete`
- 対象時間内のイベントが確認できる
- `MFAUsed` が想定どおり

### 11.3 MFAなしConsoleLogin検索

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME_SEC" \
  --end-time "$END_TIME_SEC" \
  --query-string 'fields @timestamp, eventTime, userIdentity.arn, sourceIPAddress, responseElements.ConsoleLogin, additionalEventData.MFAUsed | filter eventName = "ConsoleLogin" and additionalEventData.MFAUsed = "No" | sort @timestamp desc | limit 50' \
  --query 'queryId' \
  --output text)
```

結果取得:

```bash
aws logs get-query-results \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-id "$QUERY_ID" \
  --output json \
  > "$EVIDENCE_DIR/after/12_logs_insights_console_login_without_mfa.json"
```

### 11.4 S3 Bucket Policy変更検索

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME_SEC" \
  --end-time "$END_TIME_SEC" \
  --query-string 'fields @timestamp, eventTime, userIdentity.arn, sourceIPAddress, eventName, requestParameters.bucketName | filter eventName in ["PutBucketPolicy", "DeleteBucketPolicy"] | sort @timestamp desc | limit 50' \
  --query 'queryId' \
  --output text)
```

### 11.5 操作元IPアドレス別の集計

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME_SEC" \
  --end-time "$END_TIME_SEC" \
  --query-string 'stats count(*) as eventCount by sourceIPAddress | sort eventCount desc | limit 20' \
  --query 'queryId' \
  --output text)
```

注意:

- Logs Insightsは検索量に応じて課金される
- 時間範囲とLog Groupを絞る
- 証跡として保存する場合は、結果JSONとクエリ文字列を両方残す

## 12. Metric Filter確認

### 12.1 Metric Filter一覧

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --query 'metricFilters[*].{FilterName:filterName,Pattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output table
```

証跡保存:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/12_describe_metric_filters.json"
```

確認ポイント:

- 想定Filterが存在する
- Filter Patternが正しい
- Metric Namespaceが現場標準に合っている
- Metric NameがAlarm側と一致している
- 高カーディナリティのDimensionを使っていない

### 12.2 特定Filter確認

```bash
FILTER_NAME="ConsoleLoginWithoutMFA"

aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output table
```

## 13. Metric Filterのテスト

`test-metric-filter` を使うと、実際にLog Groupへ設定する前にFilter Patternをテストできる。

### 13.1 MFAなしConsoleLoginのテスト

```bash
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed = "No") }' \
  --log-event-messages '[
    "{\"eventName\":\"ConsoleLogin\",\"additionalEventData\":{\"MFAUsed\":\"No\"},\"sourceIPAddress\":\"203.0.113.10\"}",
    "{\"eventName\":\"ConsoleLogin\",\"additionalEventData\":{\"MFAUsed\":\"Yes\"},\"sourceIPAddress\":\"203.0.113.20\"}"
  ]' \
  --output json \
  > "$EVIDENCE_DIR/change/13_test_metric_filter_console_login_without_mfa.json"
```

確認ポイント:

- `MFAUsed=No` のイベントだけがMatchする
- `MFAUsed=Yes` のイベントはMatchしない
- Filter PatternをMetric Filter作成前に確認できる

## 14. Metric Filter作成

Metric Filterは、CloudWatch Logsに入ったログイベントを条件で抽出し、CloudWatch Metricsへ数値として出力する。

注意:

- Metric FilterはLog Groupごとに設定する
- 1つのLog Groupに設定できるMetric Filter数には上限がある
- Metric Filter由来のメトリクスはカスタムメトリクス課金の対象になる
- IPアドレス、Request ID、User ARNなどをDimensionにすると高カーディナリティになりやすい
- まずDimensionなしのCountメトリクスとして作るのが安全

### 14.1 MFAなしConsoleLogin

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "ConsoleLoginWithoutMFA" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed = "No") }' \
  --metric-transformations \
    metricName=ConsoleLoginWithoutMFA,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

確認:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "ConsoleLoginWithoutMFA" \
  --output table
```

### 14.2 Root ConsoleLogin

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "RootConsoleLogin" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.userIdentity.type = "Root") }' \
  --metric-transformations \
    metricName=RootConsoleLogin,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

### 14.3 S3 Bucket Policy変更

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "S3BucketPolicyChanged" \
  --filter-pattern '{ ($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy") }' \
  --metric-transformations \
    metricName=S3BucketPolicyChanged,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

### 14.4 Security Group変更

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "SecurityGroupChanged" \
  --filter-pattern '{ ($.eventName = "AuthorizeSecurityGroupIngress") || ($.eventName = "RevokeSecurityGroupIngress") || ($.eventName = "AuthorizeSecurityGroupEgress") || ($.eventName = "RevokeSecurityGroupEgress") }' \
  --metric-transformations \
    metricName=SecurityGroupChanged,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

### 14.5 CloudTrail設定変更

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "CloudTrailChanged" \
  --filter-pattern '{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "StopLogging") || ($.eventName = "DeleteTrail") || ($.eventName = "PutEventSelectors") || ($.eventName = "UpdateTrail")) }' \
  --metric-transformations \
    metricName=CloudTrailChanged,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

### 14.6 IAM Policy変更

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "IAMPolicyChanged" \
  --filter-pattern '{ ($.eventSource = "iam.amazonaws.com") && (($.eventName = "AttachUserPolicy") || ($.eventName = "AttachRolePolicy") || ($.eventName = "PutUserPolicy") || ($.eventName = "PutRolePolicy") || ($.eventName = "DetachUserPolicy") || ($.eventName = "DetachRolePolicy") || ($.eventName = "DeleteUserPolicy") || ($.eventName = "DeleteRolePolicy")) }' \
  --metric-transformations \
    metricName=IAMPolicyChanged,metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

証跡保存:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/14_describe_metric_filters_after.json"
```

## 15. カスタムメトリクス確認

### 15.1 list-metrics

```bash
aws cloudwatch list-metrics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --output table
```

注意:

- Metric Filter作成直後はメトリクスが表示されないことがある
- 条件に一致するログが取り込まれてからメトリクスが見えることがある
- `defaultValue=0` を設定していても、ログイベント取り込みのタイミングに依存する

### 15.2 get-metric-statistics

```bash
aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "ConsoleLoginWithoutMFA" \
  --start-time "2026-06-04T00:00:00Z" \
  --end-time "2026-06-04T23:59:59Z" \
  --period 300 \
  --statistics Sum \
  --output table
```

確認ポイント:

- `Datapoints` がある
- `Sum` が想定件数
- 時刻はUTCで指定している

## 16. Alarm確認

### 16.1 Alarm一覧

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Metric:MetricName,Namespace:Namespace,Threshold:Threshold,Comparison:ComparisonOperator,ActionsEnabled:ActionsEnabled}' \
  --output table
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_PREFIX" \
  --output json \
  > "$EVIDENCE_DIR/before/15_describe_alarms.json"
```

### 16.2 Alarm状態

| State | 意味 |
| :--- | :--- |
| `OK` | しきい値に抵触していない |
| `ALARM` | しきい値に抵触している |
| `INSUFFICIENT_DATA` | データ不足で判定できない |

確認ポイント:

- 作成直後は `INSUFFICIENT_DATA` になることがある
- `treat-missing-data` の設定でデータ欠損時の扱いが変わる
- 通知設定がある場合、`ActionsEnabled` を確認する

## 17. Alarm作成

このリファレンスでは、まず通知ActionなしでAlarmを作る。

通知なしで作る理由:

- 初回検証で不要なメール通知を飛ばさない
- Alarm状態の動きを先に確認できる
- 後でSNS TopicやChatbot連携を追加しやすい

### 17.1 MFAなしConsoleLogin Alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-console-login-without-mfa" \
  --alarm-description "ConsoleLogin without MFA was detected from CloudTrail logs" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "ConsoleLoginWithoutMFA" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

意味:

| 項目 | 設定 | 意味 |
| :--- | :--- | :--- |
| `statistic` | `Sum` | 5分間の検知件数 |
| `period` | `300` | 5分単位 |
| `evaluation-periods` | `1` | 1回でも条件を満たせば判定 |
| `threshold` | `1` | 1件以上 |
| `comparison-operator` | `GreaterThanOrEqualToThreshold` | 1以上でALARM |
| `treat-missing-data` | `notBreaching` | データなしを正常扱い |
| `--no-actions-enabled` | 通知なし | 初回検証向け |

### 17.2 Root ConsoleLogin Alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-root-console-login" \
  --alarm-description "Root user ConsoleLogin was detected" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "RootConsoleLogin" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 17.3 S3 Bucket Policy変更 Alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-s3-bucket-policy-changed" \
  --alarm-description "S3 Bucket Policy change was detected" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "S3BucketPolicyChanged" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 17.4 Security Group変更 Alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-security-group-changed" \
  --alarm-description "Security Group rule change was detected" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "SecurityGroupChanged" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 17.5 CloudTrail設定変更 Alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-cloudtrail-changed" \
  --alarm-description "CloudTrail setting change was detected" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "CloudTrailChanged" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 17.6 Alarm作成後確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_PREFIX" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Metric:MetricName,Namespace:Namespace,Threshold:Threshold,ActionsEnabled:ActionsEnabled,TreatMissingData:TreatMissingData}' \
  --output table
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_PREFIX" \
  --output json \
  > "$EVIDENCE_DIR/after/16_describe_alarms_after.json"
```

## 18. SNS通知Actionを付ける場合

初回検証後、通知が必要な場合はAlarm Actionを設定する。

### 18.1 SNS Topic ARN確認

```bash
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### 18.2 通知ありAlarmへ更新

`put-metric-alarm` は同じAlarm名を指定すると更新になる。

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-console-login-without-mfa" \
  --alarm-description "ConsoleLogin without MFA was detected from CloudTrail logs" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "ConsoleLoginWithoutMFA" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$SNS_TOPIC_ARN" \
  --actions-enabled
```

注意:

- SNSメール通知は購読承認が必要
- 本番で通知を有効化する前に、宛先、運用時間、エスカレーションルールを確認する
- Teams連携はAmazon Q Developer in chat applicationsや既存運用基盤の方針に従う

### 18.3 Alarm Actionを一時停止

```bash
aws cloudwatch disable-alarm-actions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "${ALARM_PREFIX}-security-console-login-without-mfa"
```

### 18.4 Alarm Actionを再開

```bash
aws cloudwatch enable-alarm-actions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "${ALARM_PREFIX}-security-console-login-without-mfa"
```

## 19. Alarm動作確認

### 19.1 実イベントで確認する

本来は、検知対象イベントを実際に発生させて確認する。

例:

- テスト用IAMユーザーでMFAなしConsoleLoginする
- テスト用S3バケットにBucket Policy変更を行う
- テスト用Security Groupでルール追加・削除を行う

注意:

- 本番では検知テスト用の変更も承認対象になる
- Root LoginやCloudTrail停止を本番でテストしない
- テスト用リソースとテスト時間を明記する

### 19.2 set-alarm-stateで通知経路だけ確認する

`set-alarm-state` はAlarm状態を手動変更する。

```bash
aws cloudwatch set-alarm-state \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-security-console-login-without-mfa" \
  --state-value ALARM \
  --state-reason "Notification route test"
```

注意:

- 実際のメトリクスで発火したわけではない
- 通知経路テスト用である
- 本番では作業承認と関係者への事前連絡が必要
- 証跡には「手動状態変更」と明記する

## 20. AWS標準メトリクスAlarmの例

Metric Filter由来ではなく、AWSサービス標準メトリクスにAlarmを作る例である。

### 20.1 EC2 CPU Alarm

```bash
INSTANCE_ID="<instance-id>"

aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-ec2-${INSTANCE_ID}-cpu-high" \
  --alarm-description "EC2 CPUUtilization is high" \
  --namespace "AWS/EC2" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 20.2 ALB 5xx Alarm

ALBのCloudWatch DimensionはARN全体ではなく、`app/name/id` の形式を使う。

```bash
ALB_NAME="sample-elb"

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"

aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-alb-5xx-high" \
  --alarm-description "ALB 5xx errors are detected" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_ELB_5XX_Count" \
  --dimensions "Name=LoadBalancer,Value=${ALB_DIMENSION}" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

### 20.3 RDS FreeStorageSpace Alarm

```bash
RDS_INSTANCE_ID="sample-db"

aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "${ALARM_PREFIX}-rds-free-storage-low" \
  --alarm-description "RDS FreeStorageSpace is low" \
  --namespace "AWS/RDS" \
  --metric-name "FreeStorageSpace" \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDS_INSTANCE_ID}" \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 5368709120 \
  --comparison-operator LessThanThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

確認ポイント:

- 標準メトリクスAlarmはNamespaceとDimensionが重要
- Dimension名はサービスごとに異なる
- Alarm作成前に `list-metrics` で対象メトリクスを確認すると安全

## 21. Metric Filter / Alarmの切り戻し

### 21.1 Metric Filter削除

```bash
aws logs delete-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "ConsoleLoginWithoutMFA"
```

確認:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "ConsoleLoginWithoutMFA" \
  --output table
```

注意:

- Metric Filterを削除しても、既存のCloudWatchメトリクスデータは一定期間残ることがある
- Alarmが同じMetricを参照している場合、Alarmが `INSUFFICIENT_DATA` になる可能性がある

### 21.2 Alarm削除

```bash
aws cloudwatch delete-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "${ALARM_PREFIX}-security-console-login-without-mfa"
```

確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "${ALARM_PREFIX}-security-console-login-without-mfa" \
  --output table
```

注意:

- Alarm削除は検知停止に直結する
- 本番では削除ではなく一時的なAction停止で済むか検討する
- 削除前のAlarm設定JSONを保存する

### 21.3 Retention切り戻し

変更前Retentionに戻す例:

```bash
aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days 365
```

注意:

- Retentionを短くした後にログが削除された場合、元には戻せない
- 変更前にログ保管要件を必ず確認する

## 22. 変更前後に保存する証跡

| タイミング | 証跡 | コマンド例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `sts get-caller-identity` |
| 変更前 | Log Group一覧 | `logs describe-log-groups` |
| 変更前 | Metric Filter一覧 | `logs describe-metric-filters` |
| 変更前 | Alarm一覧 | `cloudwatch describe-alarms` |
| 変更時 | Metric Filter作成結果 | `put-metric-filter` 後の `describe-metric-filters` |
| 変更時 | Alarm作成結果 | `put-metric-alarm` 後の `describe-alarms` |
| 変更後 | ログ検索結果 | `filter-log-events` |
| 変更後 | Logs Insights結果 | `get-query-results` |
| 変更後 | メトリクス確認 | `list-metrics`、`get-metric-statistics` |
| 変更後 | Alarm状態 | `describe-alarms` |
| 画面証跡 | Console画面 | Log Group、Metric Filter、Alarm画面 |

## 23. 作業手順書に書く項目

CloudWatch関連作業の手順書には、以下を含める。

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | ログ検索、Metric Filter追加、Alarm追加など |
| 対象 | Account、Region、Log Group、Metric Namespace、Alarm名 |
| 変更前状態 | Log Group、Metric Filter、Alarm、Retention |
| 変更内容 | Filter Pattern、Metric Name、Alarm条件 |
| 影響範囲 | 検知、通知、ログ保管、コスト |
| 事前確認 | CloudTrail連携、Log Stream、SNS通知先 |
| 変更後確認 | Filter存在、Metric存在、Alarm存在 |
| テスト | 実イベントまたは手動Alarm状態変更 |
| 切り戻し | Metric Filter削除、Alarm削除、Action停止 |
| 証跡 | CLI JSON、Consoleスクリーンショット |

## 24. よくあるエラーと確認ポイント

### 24.1 Log Groupが見つからない

確認ポイント:

- Regionが正しいか
- Log Group名が完全一致しているか
- CloudTrailからCloudWatch Logsへ連携済みか
- CloudTrail側の `CloudWatchLogsLogGroupArn` が設定されているか

### 24.2 filter-log-eventsで結果が出ない

確認ポイント:

- 時間範囲が正しいか
- JSTとUTCを混同していないか
- Filter Patternが正しいか
- 対象イベントがCloudWatch Logsへ配送済みか
- CloudTrailで対象イベントが記録されているか

### 24.3 Metric Filterを作ってもMetricが出ない

確認ポイント:

- 条件に一致するログが取り込まれたか
- Metric Namespace / Metric Nameが正しいか
- 反映まで少し待ったか
- `list-metrics` のRegionが正しいか
- Filter Patternを `test-metric-filter` で確認したか

### 24.4 AlarmがINSUFFICIENT_DATAのまま

確認ポイント:

- 対象MetricにDatapointがあるか
- PeriodとEvaluation Periodsが適切か
- Namespace / Metric Name / Dimensionが正しいか
- Metric Filter由来の場合、ログイベントが取り込まれているか
- `treat-missing-data` の設定が要件に合っているか

### 24.5 通知が届かない

確認ポイント:

- Alarm Actionsが有効か
- SNS Topic ARNが正しいか
- SNS Subscriptionが承認済みか
- メールフィルタや迷惑メールに入っていないか
- Chatbot連携の場合、Channel設定が正しいか

### 24.6 コストが増えそう

確認ポイント:

- Retentionが長すぎないか
- Logs Insights検索範囲が広すぎないか
- Metric Filterに高カーディナリティDimensionを設定していないか
- 不要なData eventsをCloudTrailから流していないか
- AlarmやMetricの数が増えすぎていないか

## 25. 案件で説明できるポイント

このCloudWatch作業は、案件では次のように説明できる。

```text
CloudTrailで記録したAWS操作イベントをCloudWatch Logsへ連携し、
CloudWatch Logsで検索できる状態を確認しました。
そのうえで、MFAなしConsoleLoginやS3 Bucket Policy変更など、
監視対象イベントをMetric Filterでカスタムメトリクス化し、
CloudWatch Alarmで検知できる構成を確認しました。
作業前後のLog Group、Metric Filter、Alarm設定はCLI出力として証跡化し、
必要に応じてConsole画面のスクリーンショットも取得する想定です。
```

## 26. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| CloudWatch Logs | Log Group、Log Stream、Retention |
| Metric Filter | LogsからMetricを作る |
| CloudWatch Alarm | Metricに対してしきい値監視する |
| SNS連携 | Alarm通知先として使う |
| CloudTrail連携 | CloudTrailイベントをCloudWatch Logsへ送る |
| Logs Insights | ログ検索と分析 |
| コスト | Logs保存、Insights検索、カスタムメトリクス |
| セキュリティ | MFAなしログイン、Root利用、権限変更検知 |

## 27. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

Region:
  <region>

Log Group:
  <log-group-name>

Retention:
  <days / 未設定>

CloudTrail連携:
  あり / なし

Metric Filters:
  - ConsoleLoginWithoutMFA: あり / なし
  - S3BucketPolicyChanged: あり / なし
  - SecurityGroupChanged: あり / なし
  - CloudTrailChanged: あり / なし

Alarms:
  - <alarm-name>: OK / ALARM / INSUFFICIENT_DATA

通知Action:
  有効 / 無効

ログ検索結果:
  対象イベントあり / なし

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 28. Teams報告例

### 28.1 確認完了

```text
CloudWatch Logs / Metric Filter / Alarmの設定を確認しました。
対象Log Group <log-group-name> は存在し、Retentionは <days> 日です。
Metric Filter <filter-name> とAlarm <alarm-name> が設定されており、
現時点のAlarm状態は <OK/ALARM/INSUFFICIENT_DATA> です。
変更前後のCLI出力は証跡として保存済みです。
```

### 28.2 Metric Filter追加前

```text
CloudTrailイベントをCloudWatch Logs上で検知するため、
Metric FilterとCloudWatch Alarmの追加作業を実施します。
対象は <検知対象イベント> で、初回は通知Actionなしで作成し、
Filter条件とAlarm状態を確認します。
作業後にMetric Filter、Alarm、ログ検索結果を証跡として共有します。
```

### 28.3 異常検知時

```text
CloudWatch Alarm <alarm-name> がALARM状態になりました。
CloudWatch Logsで対象イベントを確認したところ、
<eventName> が <eventTime> に発生しています。
実行者、送信元IP、対象リソースを確認し、想定作業かどうかを確認中です。
```

## 29. 公式ドキュメント

- [create-log-group - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html)
- [put-retention-policy - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html)
- [filter-log-events - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/filter-log-events.html)
- [start-query - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/start-query.html)
- [get-query-results - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/get-query-results.html)
- [Filter pattern syntax for CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [put-metric-filter - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/put-metric-filter.html)
- [test-metric-filter - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/test-metric-filter.html)
- [describe-metric-filters - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/describe-metric-filters.html)
- [put-metric-alarm - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html)
- [describe-alarms - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarms.html)
- [delete-alarms - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/delete-alarms.html)

