# 06 MFAなし管理コンソールログイン検知手順

## 1. このドキュメントの目的

このドキュメントは、AWS Management ConsoleへのMFAなしログインを、CloudTrailとCloudWatch Logs / Metric Filter / Alarmで検知する一連の手順を整理する。

対象は、銀行系システムのように、AWS管理コンソールログイン、MFA利用状況、監査証跡、検知、通知、報告が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- CloudTrailでConsoleLoginイベントを確認する
- MFAなしログインイベントの見方を理解する
- CloudTrailからCloudWatch Logsへ連携されているか確認する
- CloudWatch LogsでMFAなしログインを検索する
- Metric FilterでMFAなしログインをメトリクス化する
- CloudWatch Alarmで検知状態を作る
- 通知Actionの考え方を整理する
- テスト方法を整理する
- 変更前後の証跡を取得する
- 切り戻し手順を整理する
- 案件で説明できるポイントをまとめる

関連リファレンス:

```text
03_cloudtrail_cli_reference.md
04_cloudwatch_cli_reference.md
```

## 2. 検知の全体像

MFAなし管理コンソールログイン検知は、以下の流れで作る。

```text
AWS Management Console login
  ↓
CloudTrail ConsoleLogin event
  ↓
CloudTrail Trail
  ↓
CloudWatch Logs Log Group
  ↓
CloudWatch Logs Metric Filter
  ↓
CloudWatch custom metric
  ↓
CloudWatch Alarm
  ↓
SNS / Teams / Emailなどへ通知
```

今回の主な検知条件:

```text
eventName = ConsoleLogin
responseElements.ConsoleLogin = Success
additionalEventData.MFAUsed = No
```

意味:

```text
AWS Management Consoleへのログインが成功し、
そのログインでMFAが使われていない。
```

## 3. なぜ重要か

MFAなしログインは、認証情報漏えい時の不正アクセスリスクを高める。

特に以下は重要である。

- RootユーザーのMFAなしログイン
- IAMユーザーのMFAなしログイン
- 普段と異なるIPアドレスからのログイン
- 深夜や作業時間外のログイン
- 管理者権限を持つユーザーのログイン
- ログイン後にIAM、S3、Security Group、CloudTrailなどを変更しているケース

案件での位置づけ:

```text
CloudTrail / CloudWatch / GuardDuty周辺を見ておくとよい、
という面談コメントに直結する実務テーマである。
```

## 4. CloudTrail ConsoleLoginイベントの見方

AWS Management Consoleへのサインインは、CloudTrailに `ConsoleLogin` として記録される。

代表的なフィールド:

| フィールド | 意味 |
| :--- | :--- |
| `eventSource` | `signin.amazonaws.com` |
| `eventName` | `ConsoleLogin` |
| `responseElements.ConsoleLogin` | `Success` または `Failure` |
| `additionalEventData.MFAUsed` | `Yes` または `No` |
| `userIdentity.type` | `Root`、`IAMUser`、`AssumedRole` など |
| `userIdentity.arn` | ログイン主体 |
| `sourceIPAddress` | ログイン元IPアドレス |
| `userAgent` | ブラウザやクライアント情報 |
| `eventTime` | イベント発生時刻 |
| `awsRegion` | イベントが記録されたリージョン |

重要:

- Rootユーザーの `ConsoleLogin` は `us-east-1` に記録される
- IAMユーザーのグローバルサインインは、状況により `us-east-1` 以外に記録されることがある
- Regional endpointでサインインした場合は、そのEndpointのリージョンに記録される
- そのため、Multi-Region TrailでCloudWatch Logsへ集約する構成が望ましい

## 5. 検知条件の考え方

### 5.1 推奨: 成功したMFAなしログインだけを検知する

このドキュメントでは、基本の検知条件を以下にする。

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }
```

理由:

- 実際にログイン成功したイベントだけを検知できる
- 失敗ログインによるノイズを減らせる
- 調査時に優先度を上げやすい

### 5.2 広め: MFAを使っていない可能性があるログイン試行を検知する

CIS系の確認では、より広めの条件として以下のようなパターンが使われることがある。

```text
{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") }
```

特徴:

- `MFAUsed` が `Yes` ではないイベントを拾う
- 成功だけでなく失敗ログインも含む可能性がある
- 監査チェックとしては有用だが、通知に使うとノイズが増える場合がある

このリファレンスでは、通知用Alarmは「成功したMFAなしログイン」を推奨し、広めの条件は調査用または監査用として扱う。

## 6. 作業前の共通変数

### 6.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

PROJECT_NAME="nobu-iac-lab"

# CloudTrailをCloudWatch Logsへ連携しているLog Group。
LOG_GROUP_NAME="/aws/cloudtrail/nobu-iac-lab"

# Metric Filterで作成するカスタムメトリクス。
METRIC_NAMESPACE="NobuIacLab/Security"
METRIC_NAME="ConsoleLoginWithoutMFA"

# Metric Filter / Alarm名。
FILTER_NAME="ConsoleLoginWithoutMFA"
ALARM_NAME="${PROJECT_NAME}-security-console-login-without-mfa"

# 通知を有効化する場合のSNS Topic。
# 初回は通知なしでAlarmを作り、動作確認後に有効化する。
SNS_TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:nobu-iac-lab-alerts"

# 推奨Filter Pattern。
FILTER_PATTERN='{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }'
```

注意:

- 実案件ではLog Group名、Namespace、Alarm名は現場標準に合わせる
- Rootログインは `us-east-1` に記録されるため、CloudTrailがMulti-RegionでCloudWatch Logsへ連携されているか確認する
- 通知先を有効化する前に、通知ルール、宛先、運用時間、エスカレーション先を確認する

### 6.2 証跡ディレクトリ

```bash
WORK_NAME="mfa_console_login_detection"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/test" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 6.3 Caller Identity保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

## 7. 作業全体のチェックリスト

| No. | 作業 | 期待値 |
| :--- | :--- | :--- |
| 1 | Caller Identity確認 | 想定アカウント |
| 2 | CloudTrail確認 | Trailが存在し、Logging有効 |
| 3 | Multi-Region確認 | Root/IAMログインを拾える |
| 4 | CloudWatch Logs連携確認 | Log Group ARN設定あり |
| 5 | Log Group確認 | 対象Log Groupが存在 |
| 6 | ConsoleLogin検索 | CloudWatch Logsで検索できる |
| 7 | Filter Patternテスト | MFAなしログイン成功だけMatch |
| 8 | Metric Filter作成 | Filterが作成される |
| 9 | Custom Metric確認 | Metricが作成される |
| 10 | Alarm作成 | Alarmが作成される |
| 11 | テスト | 検知または通知経路を確認 |
| 12 | 証跡保存 | before/change/after/testを保存 |
| 13 | 切り戻し | Filter/Alarm/通知Actionを戻せる |

## 8. 変更前確認: CloudTrail

### 8.1 Trail一覧確認

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[*].{Name:Name,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,S3Bucket:S3BucketName,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,LogValidation:LogFileValidationEnabled}' \
  --output table
```

証跡保存:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  > "$EVIDENCE_DIR/before/01_describe_trails.json"
```

確認ポイント:

- Trailが存在する
- `IsMultiRegionTrail=true`
- CloudWatch Logs連携用の `CloudWatchLogsLogGroupArn` がある
- S3保存先も設定されている
- Log File Validationが有効である

### 8.2 Trail Logging状態確認

```bash
TRAIL_NAME="<trail-name>"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output table
```

証跡保存:

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/02_get_trail_status.json"
```

確認ポイント:

- `IsLogging=true`
- `LatestDeliveryError` が空、または問題なし
- `LatestCloudWatchLogsDeliveryError` が空、または問題なし
- `StopLoggingTime` がない

### 8.3 Event Selector確認

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/03_get_event_selectors.json"
```

確認ポイント:

- Management eventsが記録対象
- `IncludeManagementEvents=true`
- `ReadWriteType` が `All` または要件どおり

ConsoleLoginはManagement Eventであるため、Management eventsが記録されている必要がある。

## 9. 変更前確認: CloudWatch Logs

### 9.1 Log Group確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].{Name:logGroupName,Retention:retentionInDays,KmsKeyId:kmsKeyId,StoredBytes:storedBytes,Arn:logGroupArn}" \
  --output table
```

証跡保存:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/04_describe_log_group.json"
```

確認ポイント:

- 対象Log Groupが存在する
- CloudTrailからログが届く設計になっている
- Retentionが要件どおり
- KMS暗号化が必要なら設定されている

### 9.2 Log Stream確認

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
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
  --max-items 10 \
  --output json \
  > "$EVIDENCE_DIR/before/05_describe_log_streams.json"
```

確認ポイント:

- 新しいLog Streamがある
- `LastEventTime` が古すぎない
- CloudTrailからCloudWatch Logsへ配送されている

## 10. 変更前確認: 既存Metric Filter / Alarm

### 10.1 Metric Filter確認

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output table
```

証跡保存:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/06_describe_metric_filters.json"
```

確認ポイント:

- 同名Filterがないか
- 既存Filter Patternと重複しないか
- Namespace / Metric Nameが既存設計と衝突しないか

### 10.2 Alarm確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output table
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/07_describe_alarms.json"
```

確認ポイント:

- 同名Alarmがないか
- 既存Alarmと通知先が重複しないか
- 既に同目的の監視がないか

## 11. ConsoleLoginイベントをCloudTrailで確認する

### 11.1 lookup-eventsでConsoleLoginを検索

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/before/08_lookup_console_login_${REGION}.json"
```

注意:

- Rootログインは `us-east-1` に記録される
- IAMユーザーのグローバルサインインも `us-east-1` などに記録される場合がある
- `ap-northeast-1` だけで見つからない場合は `us-east-1` も確認する

### 11.2 us-east-1でも確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region us-east-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/before/09_lookup_console_login_us-east-1.json"
```

確認ポイント:

- `EventName` が `ConsoleLogin`
- `Username`
- `EventTime`
- `CloudTrailEvent` 内の `additionalEventData.MFAUsed`
- `CloudTrailEvent` 内の `responseElements.ConsoleLogin`

## 12. CloudWatch LogsでMFAなしログインを検索する

### 12.1 ConsoleLogin全体を検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "ConsoleLogin" }' \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/before/10_filter_console_login.json"
```

確認ポイント:

- CloudTrailのConsoleLoginイベントがCloudWatch Logsで検索できる
- `eventName`
- `responseElements.ConsoleLogin`
- `additionalEventData.MFAUsed`
- `sourceIPAddress`
- `userIdentity`

### 12.2 成功したMFAなしログインを検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/before/11_filter_console_login_without_mfa_success.json"
```

確認ポイント:

- 検索結果が0件なら、直近では成功したMFAなしログインが見つかっていない
- 検索結果がある場合、ユーザー、IP、時刻、ログイン先を確認する
- 想定された検証ログインか、不審ログインか切り分ける

### 12.3 広めの条件で検索

```bash
BROAD_FILTER_PATTERN='{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") }'

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "$BROAD_FILTER_PATTERN" \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/before/12_filter_console_login_mfa_not_yes.json"
```

注意:

- 失敗ログインも含む可能性がある
- 監査確認や広めの調査には有用
- 通知Alarmに使う場合はノイズ増に注意する

## 13. Logs Insightsで調査する

CloudWatch Logs Insightsを使うと、ConsoleLoginイベントを見やすく抽出できる。

### 13.1 時間範囲を指定する

macOS:

```bash
START_TIME_SEC=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-05 09:00:00' +%s)
END_TIME_SEC=$(TZ=Asia/Tokyo date -j -f '%Y-%m-%d %H:%M:%S' '2026-06-05 18:00:00' +%s)
```

Linux:

```bash
START_TIME_SEC=$(TZ=Asia/Tokyo date -d '2026-06-05 09:00:00' +%s)
END_TIME_SEC=$(TZ=Asia/Tokyo date -d '2026-06-05 18:00:00' +%s)
```

### 13.2 ConsoleLogin成功かつMFAなしを検索

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME_SEC" \
  --end-time "$END_TIME_SEC" \
  --query-string 'fields @timestamp, eventTime, userIdentity.type, userIdentity.arn, userIdentity.userName, sourceIPAddress, responseElements.ConsoleLogin, additionalEventData.MFAUsed, awsRegion | filter eventName = "ConsoleLogin" and responseElements.ConsoleLogin = "Success" and additionalEventData.MFAUsed = "No" | sort @timestamp desc | limit 50' \
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
  > "$EVIDENCE_DIR/before/13_logs_insights_console_login_without_mfa.json"
```

確認ポイント:

- `status` が `Complete`
- 対象イベントがあるか
- ユーザーとIPアドレスが妥当か
- 作業予定時間内か

## 14. Filter Patternをテストする

Metric Filter作成前に、`test-metric-filter` で条件を確認する。

```bash
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern "$FILTER_PATTERN" \
  --log-event-messages '[
    "{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"No\"},\"sourceIPAddress\":\"203.0.113.10\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}",
    "{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"Yes\"},\"sourceIPAddress\":\"203.0.113.20\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/mfa-user\"}}",
    "{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Failure\"},\"additionalEventData\":{\"MFAUsed\":\"No\"},\"sourceIPAddress\":\"203.0.113.30\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/failed-user\"}}"
  ]' \
  --output json \
  > "$EVIDENCE_DIR/test/14_test_metric_filter.json"
```

期待結果:

- 1件目だけMatchする
- `Success` かつ `MFAUsed=No` のイベントだけ検知する
- `MFAUsed=Yes` は検知しない
- `ConsoleLogin=Failure` は検知しない

## 15. Metric Filterを作成する

### 15.1 put-metric-filter

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --metric-transformations \
    metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count
```

注意:

- 同じFilter名がある場合は更新になる
- 変更前に既存Metric Filterを保存しておく
- カスタムメトリクス課金の対象になる
- Dimensionを付けると高カーディナリティになりやすいため、まずはDimensionなしを推奨する

### 15.2 Metric Filter作成後確認

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output table
```

証跡保存:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/15_describe_metric_filter_after.json"
```

確認ポイント:

- `filterName`
- `filterPattern`
- `metricTransformations.metricName`
- `metricTransformations.metricNamespace`
- `metricTransformations.metricValue`
- `metricTransformations.defaultValue`

## 16. カスタムメトリクスを確認する

### 16.1 list-metrics

```bash
aws cloudwatch list-metrics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output table
```

注意:

- Metric Filter作成直後は表示されないことがある
- 条件に一致するログイベントが取り込まれてから見えることがある
- 検知テスト後に再確認する

### 16.2 get-metric-statistics

```bash
aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "2026-06-05T00:00:00Z" \
  --end-time "2026-06-05T23:59:59Z" \
  --period 300 \
  --statistics Sum \
  --output table
```

確認ポイント:

- `Datapoints` があるか
- `Sum` が検知件数
- UTC/JSTの時刻変換を間違えていないか

## 17. CloudWatch Alarmを作成する

初回は通知Actionなしで作成する。

理由:

- 不要なメールやTeams通知を飛ばさない
- Alarm状態の動きを先に確認できる
- 通知先設定は運用ルール確認後に追加できる

### 17.1 put-metric-alarm

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "AWS Management Console login without MFA was detected from CloudTrail logs" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled
```

設定の意味:

| 項目 | 値 | 意味 |
| :--- | :--- | :--- |
| `statistic` | `Sum` | 5分間の検知件数 |
| `period` | `300` | 5分単位 |
| `evaluation-periods` | `1` | 1回でも条件を満たせば判定 |
| `threshold` | `1` | 1件以上 |
| `comparison-operator` | `GreaterThanOrEqualToThreshold` | 1以上でALARM |
| `treat-missing-data` | `notBreaching` | データなしを正常扱い |
| `--no-actions-enabled` | 通知なし | 初回検証向け |

### 17.2 Alarm作成後確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Metric:MetricName,Namespace:Namespace,Threshold:Threshold,ActionsEnabled:ActionsEnabled,TreatMissingData:TreatMissingData}' \
  --output table
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/16_describe_alarm_after.json"
```

確認ポイント:

- Alarmが作成されている
- Metric Namespace / Metric NameがMetric Filterと一致している
- `ActionsEnabled=false`
- `TreatMissingData=notBreaching`
- 作成直後は `INSUFFICIENT_DATA` になる場合がある

## 18. 通知Actionを追加する場合

### 18.1 SNS Topic確認

```bash
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### 18.2 SNS Subscription確認

```bash
aws sns list-subscriptions-by-topic \
  --profile "$PROFILE" \
  --region "$REGION" \
  --topic-arn "$SNS_TOPIC_ARN" \
  --output table
```

確認ポイント:

- メール購読が `Confirmed`
- 通知先が正しい
- 本番では通知先に関係者が含まれている
- Teams連携がある場合は、現場標準の通知経路を確認する

### 18.3 Alarmへ通知Actionを追加

同じAlarm名で `put-metric-alarm` を実行すると更新になる。

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "AWS Management Console login without MFA was detected from CloudTrail logs" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$SNS_TOPIC_ARN" \
  --actions-enabled
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/17_describe_alarm_with_action.json"
```

注意:

- 通知を有効化する前に宛先と運用ルールを確認する
- 本番ではテスト通知も事前連絡する
- Alarm Actionを有効化すると、状態変化時に通知が飛ぶ

## 19. テスト方法

### 19.1 推奨: test-metric-filterで条件テスト

本番環境では、実際にMFAなしログインを発生させるのではなく、まず `test-metric-filter` でFilter Patternを確認する。

```bash
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern "$FILTER_PATTERN" \
  --log-event-messages '[
    "{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"No\"}}"
  ]' \
  --output json \
  > "$EVIDENCE_DIR/test/18_test_metric_filter_single_match.json"
```

### 19.2 通知経路テスト: set-alarm-state

通知経路だけ確認したい場合、Alarm状態を手動で変更する。

```bash
aws cloudwatch set-alarm-state \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --state-value ALARM \
  --state-reason "Notification route test for MFA console login detection"
```

注意:

- 実際のMFAなしログインが発生したわけではない
- 通知経路テストであることを証跡と報告に明記する
- 本番では事前連絡する

### 19.3 ラボ環境で実イベントテストする場合

ラボでは、検証用IAMユーザーを用意し、MFA未設定の状態でログインして検知できるか確認することもできる。

ただし、本番環境では原則として推奨しない。

実施前に確認すること:

- テスト用IAMユーザーである
- 管理者権限を持たせない
- 作業時間を決める
- ログイン元IPを控える
- テスト後にユーザー削除またはMFA設定する
- 関係者へ事前連絡する

検知確認:

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/test/19_filter_after_real_test_login.json"
```

Alarm確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output table
```

## 20. 検知した場合の一次調査

MFAなしConsoleLoginを検知したら、以下を確認する。

| 確認項目 | 内容 |
| :--- | :--- |
| ログイン成功/失敗 | `responseElements.ConsoleLogin` |
| MFA利用 | `additionalEventData.MFAUsed` |
| ユーザー種別 | `userIdentity.type` |
| ユーザーARN | `userIdentity.arn` |
| 送信元IP | `sourceIPAddress` |
| 時刻 | `eventTime` |
| User Agent | `userAgent` |
| ログイン先 | `additionalEventData.LoginTo` |
| 直後の操作 | CloudTrailで後続APIを確認 |
| IAM状態 | MFA設定、権限、Access Key |

### 20.1 該当ユーザーの後続操作をCloudTrailで確認

```bash
USER_NAME="<user-name>"

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=Username,AttributeValue="$USER_NAME" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/after/20_lookup_user_events_after_login.json"
```

確認ポイント:

- IAM変更
- S3 Bucket Policy変更
- Security Group変更
- CloudTrail停止
- Access Key作成
- EC2起動
- RDS変更

### 20.2 IAMユーザーのMFA状態を確認

```bash
aws iam list-mfa-devices \
  --profile "$PROFILE" \
  --user-name "$USER_NAME" \
  --output table
```

証跡保存:

```bash
aws iam list-mfa-devices \
  --profile "$PROFILE" \
  --user-name "$USER_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/21_iam_user_mfa_devices.json"
```

確認ポイント:

- MFAデバイスがあるか
- 検知時刻より前から設定されていたか
- 一時的にMFAが外された形跡がないか

### 20.3 IAMユーザーの権限確認

```bash
aws iam list-attached-user-policies \
  --profile "$PROFILE" \
  --user-name "$USER_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/22_iam_user_attached_policies.json"

aws iam list-user-policies \
  --profile "$PROFILE" \
  --user-name "$USER_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/23_iam_user_inline_policies.json"
```

確認ポイント:

- 管理者権限があるか
- 強い権限を持つユーザーか
- 不審な権限追加がないか

## 21. 影響範囲

この作業の影響範囲:

| 変更対象 | 影響 |
| :--- | :--- |
| CloudWatch Logs Metric Filter | 対象Log GroupにFilterが追加される |
| CloudWatch Custom Metric | カスタムメトリクスが作成される |
| CloudWatch Alarm | Alarmが追加される |
| SNS通知Action | 有効化した場合、状態変化時に通知が飛ぶ |

影響しないもの:

- 既存AWSリソースの通信経路
- アプリケーション処理
- IAMユーザーのログイン可否
- CloudTrailのログ取得自体

注意:

- CloudWatch Logs、カスタムメトリクス、Alarmは課金対象になり得る
- 通知Actionを有効化すると、関係者へ通知が飛ぶ
- Retentionや既存Log Group設定はこの手順では変更しない

## 22. セキュリティ上の注意点

- RootユーザーのMFAなしログインは最優先で確認する
- 管理者権限ユーザーのMFAなしログインも高優先度
- 失敗ログインが多い場合はブルートフォースや認証情報推測を疑う
- 検知後はログイン直後のCloudTrailイベントを必ず確認する
- MFAなしログインが正当作業だった場合も、MFA設定や運用ルールを見直す
- 証跡にはIPアドレス、ユーザー名、ARNなどが含まれるため取り扱いに注意する

## 23. 切り戻し手順

### 23.1 通知Actionを無効化する

```bash
aws cloudwatch disable-alarm-actions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME"
```

確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[*].{Name:AlarmName,ActionsEnabled:ActionsEnabled}' \
  --output table
```

### 23.2 Alarmを削除する

```bash
aws cloudwatch delete-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME"
```

確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output table
```

### 23.3 Metric Filterを削除する

```bash
aws logs delete-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME"
```

確認:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output table
```

注意:

- Metric Filter削除後もメトリクスデータは一定期間残ることがある
- Alarm削除は検知停止になるため、本番では承認を取る
- 通知がうるさいだけなら、Alarm削除ではなくAction無効化で済む場合がある

## 24. 変更前後に保存する証跡

| タイミング | 証跡 | ファイル例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `00_caller_identity.json` |
| 変更前 | Trail一覧 | `01_describe_trails.json` |
| 変更前 | Trail状態 | `02_get_trail_status.json` |
| 変更前 | Event Selector | `03_get_event_selectors.json` |
| 変更前 | Log Group | `04_describe_log_group.json` |
| 変更前 | Log Stream | `05_describe_log_streams.json` |
| 変更前 | Metric Filter | `06_describe_metric_filters.json` |
| 変更前 | Alarm | `07_describe_alarms.json` |
| 変更前 | ConsoleLogin検索 | `10_filter_console_login.json` |
| テスト | Filter Patternテスト | `14_test_metric_filter.json` |
| 変更後 | Metric Filter確認 | `15_describe_metric_filter_after.json` |
| 変更後 | Alarm確認 | `16_describe_alarm_after.json` |
| 変更後 | 通知Action確認 | `17_describe_alarm_with_action.json` |
| テスト | Alarm状態変更 | `set-alarm-state` 実行記録 |
| 画面 | Consoleスクリーンショット | Trail、Log Group、Metric Filter、Alarm |

## 25. 作業手順書に書く項目

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | MFAなしConsoleLogin検知設定 |
| 対象 | Account、Region、Trail、Log Group、Metric Filter、Alarm |
| 前提 | CloudTrailがCloudWatch Logsへ連携済み |
| 変更前確認 | Trail、Log Group、既存Filter、既存Alarm |
| 変更内容 | Metric Filter追加、Alarm追加 |
| 影響範囲 | 検知、通知、カスタムメトリクス課金 |
| テスト | test-metric-filter、set-alarm-state、必要に応じて実ログイン |
| 変更後確認 | Filter、Metric、Alarm、通知Action |
| 切り戻し | Alarm Action無効化、Alarm削除、Metric Filter削除 |
| 証跡 | CLI JSON、Consoleスクリーンショット |
| 報告 | 検知条件、設定結果、残課題 |

## 26. よくあるエラーと確認ポイント

### 26.1 ConsoleLoginが検索できない

確認ポイント:

- CloudTrailが有効か
- Management eventsを記録しているか
- Multi-Region Trailか
- Rootログインやグローバルログインを `us-east-1` で確認したか
- CloudWatch Logs連携が設定されているか
- イベント発生から数分待ったか

### 26.2 Metric Filterが作れない

確認ポイント:

- Log Group名が正しいか
- Filter Patternのクォートが壊れていないか
- 同名Filterを更新してよいか
- IAM権限が足りているか
- `test-metric-filter` で先に確認したか

### 26.3 Metricが表示されない

確認ポイント:

- 条件に一致するログが取り込まれたか
- Namespace / Metric Nameが正しいか
- 少し時間を置いたか
- `defaultValue=0` が設定されているか

### 26.4 AlarmがINSUFFICIENT_DATAのまま

確認ポイント:

- MetricにDatapointがあるか
- Metric Namespace / Metric Nameが一致しているか
- PeriodとEvaluation Periodsが適切か
- `treat-missing-data` の設定を確認したか

### 26.5 通知が届かない

確認ポイント:

- Alarm Actionsが有効か
- SNS Topic ARNが正しいか
- SNS SubscriptionがConfirmedか
- メールフィルタや迷惑メールに入っていないか
- Teams連携先が正しいか
- `set-alarm-state` で通知経路だけ確認したか

## 27. 案件で説明できるポイント

この作業は、案件では次のように説明できる。

```text
CloudTrailのConsoleLoginイベントをCloudWatch Logsへ連携し、
CloudWatch LogsのMetric Filterで
「ログイン成功かつMFA未使用」のイベントを検知する設定を作成します。
検知イベントはCloudWatchのカスタムメトリクスに変換し、
CloudWatch Alarmで1件以上発生した場合にALARM化します。
初回は通知Actionなしで作成し、Filter条件とAlarm状態を確認した後、
必要に応じてSNSやTeams通知を有効化します。
変更前後のTrail、Log Group、Metric Filter、Alarm設定はCLI出力と画面証跡で残します。
```

## 28. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| CloudTrail | ConsoleLoginイベント、Management events |
| CloudWatch Logs | Log Group、Log Stream、Filter Pattern |
| Metric Filter | LogsをCloudWatch Metricsへ変換 |
| CloudWatch Alarm | Metricをしきい値監視 |
| SNS | Alarm通知先 |
| IAM | MFA、Rootユーザー、IAMユーザー |
| Security | MFAなしログイン、Root保護、監査ログ |

## 29. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

対象Region:
  <region>

Trail:
  <trail-name>

Multi-Region Trail:
  true / false

CloudWatch Logs Log Group:
  <log-group-name>

Metric Filter:
  <filter-name>

Filter Pattern:
  <filter-pattern>

Metric:
  <namespace>/<metric-name>

Alarm:
  <alarm-name>

Alarm State:
  OK / ALARM / INSUFFICIENT_DATA

Actions Enabled:
  true / false

MFAなしConsoleLogin検知結果:
  あり / なし

検知イベント概要:
  userIdentity:
  sourceIPAddress:
  eventTime:
  responseElements.ConsoleLogin:
  additionalEventData.MFAUsed:

一次調査:
  CloudTrail後続操作確認: 実施済み / 未実施
  IAM MFA状態確認: 実施済み / 未実施
  IAM権限確認: 実施済み / 未実施

判断:
  問題なし / 要改善 / 要追加調査 / インシデント候補

証跡:
  <evidence path>

備考:
  <調査メモ>
```

## 30. Teams報告例

### 30.1 設定完了

```text
MFAなし管理コンソールログイン検知設定を追加しました。
CloudTrailのConsoleLoginイベントをCloudWatch Logs上で検索できることを確認し、
Metric Filter <filter-name> とAlarm <alarm-name> を作成しています。
初回設定のためAlarm通知Actionは <有効/無効> です。
変更前後のTrail、Log Group、Metric Filter、Alarm設定は証跡として保存済みです。
```

### 30.2 検知なし

```text
対象期間のCloudWatch Logsを確認したところ、
ログイン成功かつMFA未使用のConsoleLoginイベントは確認されませんでした。
Metric FilterとAlarmは設定済みで、今後該当イベントが発生した場合に検知できます。
```

### 30.3 検知あり

```text
MFAなし管理コンソールログインを検知しました。
対象ユーザーは <userIdentity>、ログイン元IPは <sourceIPAddress>、
時刻は <eventTime> です。
ログイン後のCloudTrail操作履歴、IAMユーザーのMFA状態、権限設定を確認します。
```

### 30.4 通知経路テスト

```text
CloudWatch Alarmの通知経路テストを実施しました。
今回は実際のMFAなしログインではなく、set-alarm-stateによる手動ALARM状態変更です。
通知先への到達確認を目的としたテストであり、証跡にその旨を記録しています。
```

## 31. 公式ドキュメント

- [AWS Management Console sign-in events - AWS CloudTrail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-aws-console-sign-in-events.html)
- [Filter pattern syntax for CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [test-metric-filter - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/test-metric-filter.html)
- [put-metric-filter - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/put-metric-filter.html)
- [describe-metric-filters - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/describe-metric-filters.html)
- [filter-log-events - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/filter-log-events.html)
- [start-query - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/start-query.html)
- [get-query-results - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/get-query-results.html)
- [put-metric-alarm - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html)
- [describe-alarms - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarms.html)
- [set-alarm-state - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/set-alarm-state.html)

