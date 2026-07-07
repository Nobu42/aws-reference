# 要件4.8 S3バケットポリシー変更監視 パイロット作業手順書

作成日: 2026-07-07

この資料は、第三者検証評価シートの **要件番号4.8「S3バケットポリシーの変更が監視されていること」** を、最初のパイロット作業として実施するための手順書である。

本手順では、S3バケットポリシーの変更イベントをCloudTrailで記録し、CloudWatch Logs Metric Filter、CloudWatch Alarm、SNS等の通知先へ連携できることを確認する。

## 1. 要件概要

### 1.1 対象要件

| 項目 | 内容 |
|---|---|
| 要件番号 | 4.8 |
| 種別 | AWS |
| セクション | モニタリング |
| 要件 | S3バケットポリシーの変更が監視されていること |

### 1.2 評価シート上の指摘内容

評価シートでは、Prod・OPER環境でGuardDutyが導入され、不正挙動のアクティビティログ蓄積や月次イベント確認は実施されているが、通知設定がないため指摘対象となっている。

是正方針は、CloudTrailをCloudWatchへ連携させ、S3バケットポリシー変更を監視し、検知時にアラートが発報されるよう構成することである。

### 1.3 監視対象イベント

| 操作 | CloudTrail EventName |
|---|---|
| S3バケットポリシー作成・更新 | `PutBucketPolicy` |
| S3バケットポリシー削除 | `DeleteBucketPolicy` |

## 2. この作業を最初のパイロットにする理由

### 2.1 イベント名が明確

要件4.8は、主に `PutBucketPolicy` と `DeleteBucketPolicy` を検知すればよいため、Metric Filterの条件を作りやすい。

### 2.2 業務影響が比較的小さい

この作業の中心は監視設定の追加であり、アプリケーションの通信経路やDB、既存データを直接変更しない。

ただし、実際にS3バケットポリシー変更イベントを発生させるテストは、対象バケットを誤ると影響が出るため、検証環境または検証用バケットで実施する。

### 2.3 横展開しやすい

要件4.8で以下の流れを確認できれば、4.1〜4.15の多くに横展開できる。

```text
CloudTrailイベント
  ↓
CloudWatch Logs
  ↓
Metric Filter
  ↓
CloudWatch Alarm
  ↓
SNS等の通知
  ↓
証跡取得
```

## 3. 作業全体の流れ

```text
1. 作業前確認
2. 既存CloudTrail確認
3. CloudWatch Logs連携確認
4. 既存Metric Filter / Alarm / SNS確認
5. 4.8用Metric Filter作成
6. 4.8用CloudWatch Alarm作成
7. Metric Filter単体テスト
8. 検証用バケットで実イベントテスト
9. 通知確認
10. 証跡整理
11. 切り戻し手順確認
12. 横展開可否判断
```

## 4. 作業前確認

### 4.1 リーダー・PMに確認する事項

作業前に以下を確認する。

| 確認事項 | 理由 |
|---|---|
| 4.8を最初のパイロットとして実施してよいか | 作業順序の合意 |
| 対象環境はProdかOPERか開発環境か | 誤環境作業防止 |
| 検証用S3バケットがあるか | 安全にイベント発生テストを行うため |
| 本番S3バケットでテストイベントを発生させてよいか | 本番ポリシー変更は承認が必要 |
| 通知先は既存SNS Topicか新規作成か | Alarm Action設定に必要 |
| 通知先はメール、Teams、監視基盤、SIEM、運用ツールのどれか | 運用設計に影響 |
| 既存Metric Filter / Alarm命名規則 | 既存ルールとの整合性 |
| 証跡保存先と命名規則 | 成果物提出に必要 |
| 作業後に設定を残すか、いったん切り戻すか | パイロット完了条件に影響 |

### 4.2 注意事項

- 本番バケットのBucket Policyを直接変更するテストは、承認なしで実施しない。
- まずは `aws logs test-metric-filter` でMetric Filter単体テストを行う。
- 実イベントテストは、検証用バケットまたは承認済みバケットで行う。
- 既存通知先に不要なアラートを飛ばさないよう、通知先とテスト時間を事前に合意する。
- 既存設定がある場合は、新規作成ではなく既存設定の改修になる可能性がある。

### 4.3 Windows Git Bashで作業する場合の注意

本手順は、Windows端末上のGit Bashから実行することを想定して利用できる。
PowerShellよりbash形式のコマンドをそのまま使いやすいため、現場端末でGit Bashが利用可能であればGit Bashで作業する。

作業前に以下を確認する。

```bash
# Git BashからAWS CLIが実行できることを確認する。
aws --version
```

```bash
# awsコマンドの場所を確認する。
# Windows版AWS CLIがGit Bashから見えていればよい。
which aws
```

```bash
# AWS CLI Profileが見えることを確認する。
aws configure list-profiles
```

```bash
# 作業対象ProfileでAWSアカウント情報を取得できることを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

Windows Git Bashで特に注意する点:

| 注意点 | 内容 |
|---|---|
| 作業ディレクトリ | スペースや日本語を含まない短いパスを推奨 |
| パス表記 | Git Bashでは `/c/work/aws-work` のようなパスを使える |
| `file://` | 相対パスなら `file://$EVIDENCE_ROOT/...` のまま使いやすい |
| `date` | Windows Git BashはLinux/GNU dateに近い書き方を使う |
| 改行コード | シェルスクリプトやJSONはLF推奨。CRLFでエラーになる場合がある |
| 文字コード | JSONや証跡ファイルはUTF-8を推奨 |

推奨する作業ディレクトリ例:

```bash
# Cドライブ直下に短い作業ディレクトリを作る例。
mkdir -p /c/work/aws-4-8
cd /c/work/aws-4-8
```

`file://` の指定例:

```bash
# 相対パスを使う場合。
--policy "file://$EVIDENCE_ROOT/03_test/04_test_bucket_policy.json"
```

```bash
# 絶対パスを使う場合。
# Windows Git Bashでは /c/work/... 形式で扱える。
--policy "file:///c/work/aws-4-8/evidence/03_test/04_test_bucket_policy.json"
```

改行コード確認:

```bash
# ファイル末尾などにCRLF由来の ^M が見える場合は注意する。
cat -vet "$EVIDENCE_ROOT/03_test/04_test_bucket_policy.json" | head
```

CRLFをLFへ寄せる例:

```bash
# sedで行末のCRを除去する。
# JSONファイルやシェルスクリプトをWindowsエディタで編集した後に有効。
sed -i 's/\r$//' "$EVIDENCE_ROOT/03_test/04_test_bucket_policy.json"
```

## 5. 変数設定

以降のコマンドは、bashまたはGit Bashを想定する。

PowerShellを使う場合は、環境変数や改行記号の書き方を現場ルールに合わせて読み替える。

```bash
# AWS CLI Profile名を指定する。
# 現場で払い出されたProfile名に変更する。
PROFILE="<aws-cli-profile>"

# 対象リージョンを指定する。
# 東京リージョンの場合は ap-northeast-1。
REGION="<target-region>"

# 誤アカウント作業を防ぐため、対象AWSアカウントIDを指定する。
EXPECTED_ACCOUNT_ID="<target-account-id>"

# 対象CloudTrail名を指定する。
# Organization Trailの場合は、管理アカウント側で確認が必要になる場合がある。
TRAIL_NAME="<cloudtrail-name>"

# CloudTrailが連携しているCloudWatch LogsのLog Group名を指定する。
CLOUDTRAIL_LOG_GROUP_NAME="<cloudtrail-cloudwatch-log-group-name>"

# 4.8用のMetric Filter名を指定する。
FILTER_NAME="S3BucketPolicyChange"

# 4.8用のCloudWatch Metric Namespaceを指定する。
METRIC_NAMESPACE="SecurityMonitoring"

# 4.8用のMetric名を指定する。
METRIC_NAME="S3BucketPolicyChangeCount"

# 4.8用のAlarm名を指定する。
ALARM_NAME="S3BucketPolicyChangeDetected"

# Alarm通知先のSNS Topic ARNを指定する。
# 既存SNS Topicを使う場合は、既存Topic ARNを指定する。
SNS_TOPIC_ARN="<sns-topic-arn>"

# 実イベントテストで使う検証用S3バケット名を指定する。
# 本番バケットを指定する場合は、必ず承認を取る。
TEST_BUCKET="<test-s3-bucket-name>"

# 証跡保存ディレクトリを作成する。
EVIDENCE_ROOT="./evidence_4_8_s3_bucket_policy_monitoring_$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$EVIDENCE_ROOT"/{00_account,01_before,02_change,03_test,04_after,05_rollback,99_report}
```

作業例:

```bash
PROFILE="prod-profile"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="123456789012"
TRAIL_NAME="example-prod-trail"
CLOUDTRAIL_LOG_GROUP_NAME="/aws/cloudtrail/management-events"
FILTER_NAME="S3BucketPolicyChange"
METRIC_NAMESPACE="SecurityMonitoring"
METRIC_NAME="S3BucketPolicyChangeCount"
ALARM_NAME="S3BucketPolicyChangeDetected"
SNS_TOPIC_ARN="arn:aws:sns:ap-northeast-1:123456789012:security-alert-topic"
TEST_BUCKET="example-test-bucket"
```

## 6. 作業対象AWSアカウント確認

目的:
誤ったAWSアカウントで作業していないことを確認する。

```bash
# 現在のAWS CLI実行主体を確認し、証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/00_account/01_caller_identity.json"
```

```bash
# 人が見やすい形式で、AccountとArnを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query '{Account:Account,Arn:Arn,UserId:UserId}' \
  --output table \
  --no-cli-pager
```

確認ポイント:

| 項目 | 確認内容 |
|---|---|
| `Account` | `EXPECTED_ACCOUNT_ID` と一致すること |
| `Arn` | 想定されたIAM User、AssumedRole、SSO Roleであること |

## 7. 既存CloudTrail確認

目的:
S3バケットポリシー変更イベントを記録するCloudTrailが存在し、ログ記録中であることを確認する。

```bash
# 対象リージョンから見えるTrail一覧を取得する。
# --include-shadow-trails により、マルチリージョンTrailの影も含めて確認する。
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/01_describe_trails.json"
```

```bash
# 対象Trailの主要項目を確認する。
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{
    Name:Name,
    TrailARN:TrailARN,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    S3Prefix:S3KeyPrefix,
    KmsKeyId:KmsKeyId,
    CloudWatchLogs:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRole:CloudWatchLogsRoleArn
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/02_get_trail.json"
```

```bash
# Trailがログ記録中か確認する。
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/03_get_trail_status.json"
```

```bash
# Event Selectorを確認する。
# S3バケットポリシー変更はManagement Eventなので、IncludeManagementEventsがtrueであることが重要。
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/04_get_event_selectors.json"
```

確認ポイント:

| 項目 | 期待値 |
|---|---|
| `IsLogging` | `true` |
| `LatestDeliveryError` | エラーなし |
| `IncludeManagementEvents` | `true` |
| `ReadWriteType` | `All` またはWriteイベントを含む設定 |
| `CloudWatchLogsLogGroupArn` | 空でないこと |
| `CloudWatchLogsRoleArn` | 空でないこと |

## 8. CloudWatch Logs連携確認

目的:
CloudTrailイベントがCloudWatch Logsに配送されていることを確認する。

```bash
# CloudTrail連携先Log Groupの情報を取得する。
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/05_describe_cloudtrail_log_group.json"
```

```bash
# Log Streamの最新イベント時刻を確認する。
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/06_describe_cloudtrail_log_streams.json"
```

```bash
# 直近のCloudTrailイベントがCloudWatch Logsに届いているか確認する。
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --limit 5 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/07_recent_cloudtrail_events_in_logs.json"
```

判定:

| 状態 | 読み方 |
|---|---|
| `events` が返る | CloudTrailからCloudWatch Logsへ配送されている |
| `events` が空 | Log Group名誤り、連携なし、配送遅延、対象期間外の可能性 |

## 9. 既存Metric Filter / Alarm / SNS確認

目的:
要件4.8に対応する既存監視がないか確認し、重複作成を防ぐ。

### 9.1 Metric Filter確認

```bash
# CloudTrail Log Groupに設定済みのMetric Filterを取得する。
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/08_metric_filters_before.json"
```

```bash
# 既存Metric FilterにPutBucketPolicy / DeleteBucketPolicyが含まれるか簡易確認する。
grep -n \
  'PutBucketPolicy\|DeleteBucketPolicy' \
  "$EVIDENCE_ROOT/01_before/08_metric_filters_before.json" \
  > "$EVIDENCE_ROOT/01_before/09_existing_s3_bucket_policy_filter_grep.txt"
```

確認ポイント:

| 結果 | 読み方 |
|---|---|
| grep結果あり | 既に4.8相当のMetric Filterが存在する可能性がある |
| grep結果なし | 4.8相当のMetric Filterが未設定の可能性が高い |

### 9.2 CloudWatch Alarm確認

```bash
# 既存CloudWatch Alarm一覧を取得する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/10_alarms_before.json"
```

```bash
# 4.8用に使う予定のMetricに紐づくAlarmが既にあるか確認する。
aws cloudwatch describe-alarms-for-metric \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/11_alarms_for_metric_before.json"
```

### 9.3 SNS通知先確認

```bash
# SNS Topic一覧を取得する。
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/12_sns_topics.json"
```

```bash
# SNS Subscription一覧を取得する。
# PendingConfirmationの場合は、通知先が未承認の可能性がある。
aws sns list-subscriptions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/13_sns_subscriptions.json"
```

確認ポイント:

| 項目 | 確認内容 |
|---|---|
| `SNS_TOPIC_ARN` | Alarm通知先として使ってよいTopicか |
| `Protocol` | email、https、lambda等 |
| `Endpoint` | 運用担当、Teams連携、監視基盤等 |
| `SubscriptionArn` | `PendingConfirmation` ではないこと |

## 10. Metric Filter設計

### 10.1 基本方針

4.8では、CloudTrailログのうち、S3バケットポリシー変更イベントを検知する。

基本のFilter Pattern:

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

### 10.2 バケット名で絞るかどうか

| 方針 | メリット | 注意点 |
|---|---|---|
| 全S3バケットを対象 | 設定漏れが少ない | 通知が多くなる可能性 |
| 特定バケットのみ対象 | ノイズが少ない | 対象バケット追加時にFilter更新が必要 |

パイロットでは、まず全S3バケット対象で検知し、通知量や運用方針を確認してから絞り込み要否を判断する。

特定バケットに絞る場合の例:

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) && ($.requestParameters.bucketName = "example-bucket") }
```

## 11. Metric Filter単体テスト

目的:
AWSリソースを変更する前に、Filter Patternが期待通り一致するか確認する。

```bash
# 4.8用Filter Patternを変数に設定する。
FILTER_PATTERN='{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }'
```

```bash
# PutBucketPolicyのサンプルログに一致することを確認する。
# 1件目は一致する想定。
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern "$FILTER_PATTERN" \
  --log-event-messages '[
    "{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"PutBucketPolicy\",\"requestParameters\":{\"bucketName\":\"example-bucket\"},\"userIdentity\":{\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}",
    "{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"GetBucketPolicy\",\"requestParameters\":{\"bucketName\":\"example-bucket\"},\"userIdentity\":{\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}"
  ]' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/01_test_metric_filter_put_bucket_policy.json"
```

```bash
# DeleteBucketPolicyのサンプルログに一致することを確認する。
# 1件目は一致する想定。
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern "$FILTER_PATTERN" \
  --log-event-messages '[
    "{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"DeleteBucketPolicy\",\"requestParameters\":{\"bucketName\":\"example-bucket\"},\"userIdentity\":{\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}",
    "{\"eventSource\":\"s3.amazonaws.com\",\"eventName\":\"ListBuckets\",\"userIdentity\":{\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}"
  ]' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/02_test_metric_filter_delete_bucket_policy.json"
```

確認:

```bash
# matchesにeventNumberが含まれることを確認する。
cat "$EVIDENCE_ROOT/03_test/01_test_metric_filter_put_bucket_policy.json"
cat "$EVIDENCE_ROOT/03_test/02_test_metric_filter_delete_bucket_policy.json"
```

判定:

| 結果 | 判定 |
|---|---|
| `matches` に `PutBucketPolicy` が含まれる | OK |
| `matches` に `DeleteBucketPolicy` が含まれる | OK |
| `GetBucketPolicy` や `ListBuckets` が一致しない | OK |

## 12. Metric Filter作成

目的:
CloudTrail Log Groupに4.8用Metric Filterを作成する。

```bash
# 変更前のMetric Filter一覧を保存する。
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/14_metric_filters_before_create.json"
```

```bash
# 4.8用Metric Filterを作成する。
# metric-value 1 は、対象イベント1件につきメトリクスを1加算する意味。
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --metric-transformations \
    metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1 \
  --no-cli-pager
```

```bash
# 作成後のMetric Filterを確認する。
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/02_change/01_metric_filter_created.json"
```

確認ポイント:

| 項目 | 期待値 |
|---|---|
| `filterName` | `$FILTER_NAME` |
| `filterPattern` | `PutBucketPolicy` / `DeleteBucketPolicy` を含む |
| `metricNamespace` | `$METRIC_NAMESPACE` |
| `metricName` | `$METRIC_NAME` |
| `metricValue` | `1` |

## 13. CloudWatch Alarm作成

目的:
4.8用メトリクスが1回以上発生したらAlarm状態にする。

```bash
# 変更前のAlarm状態を保存する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_before/15_alarm_before_create.json"
```

```bash
# 4.8用Alarmを作成する。
# evaluation-periods 1 / threshold 1 により、1期間内に1件以上検知したら発報する。
# treat-missing-data notBreaching により、イベントがない通常時はOK扱いにする。
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Detect S3 bucket policy changes: PutBucketPolicy or DeleteBucketPolicy" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$SNS_TOPIC_ARN" \
  --actions-enabled \
  --no-cli-pager
```

```bash
# 作成後のAlarm設定を確認する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/02_change/02_alarm_created.json"
```

確認ポイント:

| 項目 | 期待値 |
|---|---|
| `AlarmName` | `$ALARM_NAME` |
| `Namespace` | `$METRIC_NAMESPACE` |
| `MetricName` | `$METRIC_NAME` |
| `Threshold` | `1` |
| `ComparisonOperator` | `GreaterThanOrEqualToThreshold` |
| `TreatMissingData` | `notBreaching` |
| `AlarmActions` | `$SNS_TOPIC_ARN` |
| `ActionsEnabled` | `true` |

## 14. 実イベントテスト前確認

目的:
実際にS3バケットポリシー変更イベントを発生させる前に、対象バケットと現在のPolicyを保存する。

```bash
# 検証用バケットが存在するか確認する。
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

```bash
# 検証用バケットの現在のBucket Policyを取得する。
# バケットポリシーがない場合はNoSuchBucketPolicyになるため、その場合は「ポリシーなし」と記録する。
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/03_bucket_policy_before_test.json"
```

注意:
上記が `NoSuchBucketPolicy` で失敗した場合は、既存ポリシーなしとして扱う。
その場合、テスト後は `delete-bucket-policy` でポリシーなし状態へ戻す。

## 15. 実イベントテスト

### 15.1 テスト方針

以下のどちらかで実施する。

| 方法 | 内容 | 推奨 |
|---|---|---|
| 方法A | 検証用バケットにテスト用Bucket Policyを適用する | 推奨 |
| 方法B | 本番バケットに承認済みの軽微なPolicy変更を行う | 承認がある場合のみ |

### 15.2 テスト用Bucket Policyを作成

この例では、HTTPS必須のDenyポリシーを使用する。
既存ポリシーがあるバケットでは、既存ポリシーを上書きしないよう注意する。

```bash
# テスト用Bucket Policyファイルを作成する。
# ResourceはTEST_BUCKETに合わせる。
cat > "$EVIDENCE_ROOT/03_test/04_test_bucket_policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransportForPilotTest",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$TEST_BUCKET",
        "arn:aws:s3:::$TEST_BUCKET/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
```

### 15.3 PutBucketPolicyを発生させる

```bash
# テスト用Bucket Policyを適用し、PutBucketPolicyイベントを発生させる。
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_ROOT/03_test/04_test_bucket_policy.json" \
  --no-cli-pager
```

```bash
# 適用後のBucket Policyを取得し、証跡として保存する。
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/05_bucket_policy_after_put.json"
```

## 16. CloudTrailイベント確認

CloudTrail Event Historyへの反映には数分かかる場合がある。

```bash
# PutBucketPolicyイベントをCloudTrail Event Historyで確認する。
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --max-results 50 \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/06_lookup_put_bucket_policy_events.json"
```

```bash
# 対象バケット名で絞り込んで確認する。
# lookup-eventsは検索属性を一度に複数指定できないため、ResourceNameで検索してからqueryでEventNameを絞る。
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$TEST_BUCKET" \
  --max-results 50 \
  --query 'Events[?EventName==`PutBucketPolicy`].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/07_lookup_put_bucket_policy_by_bucket.json"
```

確認ポイント:

| 項目 | 期待値 |
|---|---|
| `EventName` | `PutBucketPolicy` |
| `ResourceName` | `$TEST_BUCKET` |
| `Username` | 作業ユーザーまたはAssumedRole |
| `EventTime` | テスト実施時刻付近 |

## 17. Metric / Alarm確認

CloudWatch Metric Filterのメトリクス反映にも数分かかる場合がある。

```bash
# メトリクス確認用の時間範囲を設定する。
# macOS / BSD dateの場合。
START_TIME="$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')"
END_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
```

Windows Git Bash / Linuxの場合:

```bash
# Windows Git Bash / Linux / GNU dateの場合。
START_TIME="$(date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')"
END_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
```

```bash
# 4.8用メトリクスが発生しているか確認する。
aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 300 \
  --statistics Sum \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/08_metric_statistics_after_put_bucket_policy.json"
```

```bash
# Alarm状態を確認する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{
    AlarmName:AlarmName,
    State:StateValue,
    StateReason:StateReason,
    StateUpdatedTimestamp:StateUpdatedTimestamp,
    ActionsEnabled:ActionsEnabled,
    AlarmActions:AlarmActions
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/09_alarm_after_put_bucket_policy.json"
```

```bash
# Alarm履歴を確認する。
aws cloudwatch describe-alarm-history \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-items 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/10_alarm_history.json"
```

確認ポイント:

| 項目 | 期待値 |
|---|---|
| `Datapoints[].Sum` | 1以上 |
| `StateValue` | 一時的に `ALARM` になる可能性 |
| `AlarmActions` | `$SNS_TOPIC_ARN` が含まれる |
| 通知 | 指定通知先で受信できる |

## 18. DeleteBucketPolicyテスト

既存ポリシーがない検証用バケットでテストした場合、削除により `DeleteBucketPolicy` も確認できる。

本番バケットや既存ポリシーがあるバケットでは、承認なしに削除しない。

```bash
# テスト用Bucket Policyを削除し、DeleteBucketPolicyイベントを発生させる。
# 既存ポリシーがあった場合は、この手順ではなく元のPolicyをput-bucket-policyで戻す。
aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

```bash
# DeleteBucketPolicyイベントを確認する。
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$TEST_BUCKET" \
  --max-results 50 \
  --query 'Events[?EventName==`DeleteBucketPolicy`].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_test/11_lookup_delete_bucket_policy_by_bucket.json"
```

## 19. Bucket Policy切り戻し

### 19.1 既存ポリシーがあった場合

```bash
# テスト前に保存したBucket Policyを戻す。
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_ROOT/03_test/03_bucket_policy_before_test.json" \
  --no-cli-pager
```

### 19.2 既存ポリシーがなかった場合

```bash
# テスト前にBucket Policyがなかった場合は、Policyを削除して元の状態へ戻す。
aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

### 19.3 切り戻し後確認

```bash
# 切り戻し後のBucket Policy状態を確認する。
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TEST_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/05_rollback/01_bucket_policy_after_rollback.json"
```

注意:
元々Bucket Policyがない場合、このコマンドは `NoSuchBucketPolicy` で失敗する。
その場合は、ポリシーなし状態に戻ったと判断し、エラー出力を証跡として保存する。

## 20. 監視設定の切り戻し

パイロット後に設定を残さない場合は、Metric FilterとAlarmを削除する。

設定を本採用する場合は、この章は実行せず、設定内容を設計書・手順書へ反映する。

```bash
# Alarmを削除する。
aws cloudwatch delete-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --no-cli-pager
```

```bash
# Metric Filterを削除する。
aws logs delete-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --no-cli-pager
```

```bash
# 削除後のMetric Filter状態を確認する。
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/05_rollback/02_metric_filter_after_delete.json"
```

```bash
# 削除後のAlarm状態を確認する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/05_rollback/03_alarm_after_delete.json"
```

## 21. 証跡として残すもの

| 区分 | 証跡 |
|---|---|
| 作業前 | Caller Identity |
| 作業前 | Trail設定、Trail Status、Event Selector |
| 作業前 | CloudWatch Logs Log Group、Log Stream |
| 作業前 | 既存Metric Filter |
| 作業前 | 既存Alarm |
| 作業前 | SNS Topic、Subscription |
| 設定 | 作成したMetric Filter |
| 設定 | 作成したAlarm |
| テスト | test-metric-filter結果 |
| テスト | PutBucketPolicyのCloudTrailイベント |
| テスト | DeleteBucketPolicyのCloudTrailイベント |
| テスト | Metric Statistics |
| テスト | Alarm状態、Alarm履歴 |
| テスト | 通知受信証跡 |
| 切り戻し | Bucket Policy復元結果 |
| 切り戻し | Metric Filter / Alarm削除結果 |

## 22. 完了判定

以下を満たせば、4.8パイロット完了とする。

| No | 判定項目 | 結果 |
|---|---|---|
| 1 | CloudTrailで `PutBucketPolicy` を確認できる | OK / NG |
| 2 | CloudTrailで `DeleteBucketPolicy` を確認できる | OK / NG / 対象外 |
| 3 | CloudWatch Logsに対象イベントが配送される | OK / NG |
| 4 | Metric Filterが対象イベントに一致する | OK / NG |
| 5 | CloudWatch Metricが発生する | OK / NG |
| 6 | CloudWatch Alarmが発報する | OK / NG |
| 7 | SNS等の通知先で受信できる | OK / NG |
| 8 | 証跡が保存されている | OK / NG |
| 9 | 切り戻し手順が確認済み | OK / NG |

## 23. リーダー・PM向け報告例

```text
要件4.8「S3バケットポリシーの変更監視」について、パイロットとして監視設定の流れを確認しました。

CloudTrail上の PutBucketPolicy / DeleteBucketPolicy をCloudWatch Logs Metric Filterで検知し、
CloudWatch AlarmからSNS通知へ連携する構成です。

今回のパイロットで、CloudTrail、CloudWatch Logs、Metric Filter、Alarm、通知、証跡取得、切り戻しの一連の手順を確認できるため、
同じ型を4.1〜4.15のCloudTrail系監視に横展開できる見込みです。
```

## 24. 横展開時の注意

4.8の手順を横展開する場合は、以下を共通化する。

- Metric Filter命名規則
- Metric Namespace命名規則
- Alarm名命名規則
- Alarmしきい値
- Alarm評価期間
- SNS通知先
- 証跡保存形式
- テスト方法
- 切り戻し手順

要件4.1〜4.15では、検知対象イベントだけを差し替えれば共通化できるものが多い。

ただし、4.7のKMS、4.15のOrganizationsなどは権限や確認アカウントが異なる可能性があるため、個別確認が必要である。
