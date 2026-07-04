# AWS現状調査リファレンス

このメモは、金融系AWS環境で設定変更やアラート追加を行う前に、現在の状態を調査するためのリファレンスである。

今回のように、CloudTrail、CloudWatch Logs、Metric Filter、Alarm、EventBridge、SNS、KMS、GuardDuty、VPC Flow Logs、NACL、Route Tableなどが関係する案件では、いきなり設定を作るよりも、まず既存設定を正確に棚卸しすることが重要である。

## 1. 最初にやること

最初にやるべきことは、変更ではなく現状確認である。

現場での言い方:

```text
まず既存のCloudTrail、CloudWatch Logs連携、Metric Filter、Alarm、EventBridge、SNS、対象リソースの現状を棚卸しします。
そのうえで、既存設定と重複しない形で対応方針を整理します。
```

より短く言う場合:

```text
最初に現状設定を確認し、変更が必要なもの、既存設定で足りているもの、手順書整備で足りるものに分けます。
```

## 2. 調査の全体像

見る順番は以下が安全である。

```text
1. アカウント・リージョン・権限確認
2. CloudTrailの有無と設定確認
3. CloudTrailからCloudWatch Logsへの連携確認
4. CloudWatch LogsのLog Group、保持期間、KMS、Metric Filter確認
5. KMSキー、カスタマー管理キー、Key Policy、Rotation確認
6. CloudWatch Alarm確認
7. EventBridge Rule確認
8. SNS Topic、Subscription確認
9. S3、NACL、Route Table、VPC Flow Logs、GuardDutyの対象リソース確認
10. 既存運用、通知先、手順書、監視製品との突き合わせ
11. 対応要否と不足権限の整理
```

## 3. 調査時の注意点

### 3.1 GUIだけで判断しない

GUIは全体把握やスクリーンショットには向いている。
ただし、一覧に出ない項目、横スクロールで見落とす項目、複数リージョンの取り違えが起きやすい。

CLIでJSONを保存すると、後から見返せる証跡になる。

### 3.2 変更系コマンドは実行しない

現状調査では、原則として参照系コマンドだけを使う。

安全な参照系の例:

- `describe-*`
- `get-*`
- `list-*`
- `lookup-events`
- `filter-log-events`

注意する変更系の例:

- `put-*`
- `create-*`
- `delete-*`
- `update-*`
- `enable-*`
- `disable-*`
- `start-*`
- `stop-*`

`start-query` はCloudWatch Logs Insightsの検索開始であり設定変更ではないが、現場ルールによっては事前確認する。

### 3.3 CloudTrailの見える範囲に注意する

CloudTrailのEvent Historyは便利だが、長期調査や大量検索には向かない。
CloudTrailログがS3やCloudWatch Logsに配送されている場合は、そちらも確認する。

注意点:

- Event Historyは過去90日が基本
- `lookup-events` はスロットリングされやすい
- Organization Trailの場合、メンバーアカウントでは変更できないことがある
- Multi-Region Trailかどうかで見える範囲が変わる
- S3のPutObjectなどはData Eventが有効でないと記録されない

### 3.4 CloudWatch Logsの保持期間に注意する

CloudTrailがCloudWatch Logsへ連携されていても、Log Groupの保持期間が短いと古いログは消えている。

見るポイント:

- `retentionInDays`
- `creationTime`
- `storedBytes`
- `kmsKeyId`
- `metricFilterCount`

CloudWatch Logs Insightsで古い期間を検索すると、保持期間外やLog Group作成前でエラーになることがある。

### 3.5 通知設定は重複に注意する

既にEventBridge Rule、CloudWatch Alarm、SNS通知、監視製品連携があるかもしれない。
同じイベントを二重に通知すると運用上のノイズになる。

見るポイント:

- 既存のEventBridge Rule
- 既存のCloudWatch Alarm
- 既存のMetric Filter
- SNS TopicとSubscription
- Teams、メール、SIEM、監視製品への連携

### 3.6 三行・複数アカウントに注意する

複数銀行や複数システムが関係する場合、アカウントやリージョンを取り違えやすい。

必ず作業前に以下を確認する。

- AWSアカウントID
- アカウント名
- リージョン
- 環境種別: 本番 / 検証 / 開発
- 対象システム名
- 対象VPC
- 対象S3バケット

## 4. 証跡ディレクトリを作る

調査結果は、後から報告書や手順書へ転記できるように保存する。

```bash
# AWS CLIで使うプロファイル名。
# 現場では "prod-a" や "system01-readonly" など、付与されたプロファイル名に置き換える。
PROFILE_NAME="project-prod"

# 調査対象リージョン。
# 東京リージョンなら ap-northeast-1。
REGION="ap-northeast-1"

# 対象AWSアカウントID。
# sts get-caller-identity の結果と照合する。
EXPECTED_ACCOUNT_ID="123456789012"

# 調査名。
# 何のための調査か分かる名前にする。
INVESTIGATION_NAME="current-state-investigation"

# 証跡ディレクトリ。
# 日時を入れておくと、同じ調査を複数回実施しても混ざりにくい。
EVIDENCE_DIR="evidence/$(date '+%Y%m%d_%H%M%S')_${INVESTIGATION_NAME}"

# 用途別にディレクトリを分ける。
# 00_metadata: アカウントや実行環境
# cloudtrail: CloudTrail関連
# cloudwatch: CloudWatch Logs / Alarm関連
# eventbridge: EventBridge関連
# sns: SNS関連
# kms: KMSキー、Key Policy、Rotation関連
# s3: S3関連
# network: VPC / NACL / Route Table / Flow Logs関連
# guardduty: GuardDuty関連
# report: 調査結果まとめ
mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/cloudwatch" \
  "$EVIDENCE_DIR/eventbridge" \
  "$EVIDENCE_DIR/sns" \
  "$EVIDENCE_DIR/kms" \
  "$EVIDENCE_DIR/s3" \
  "$EVIDENCE_DIR/network" \
  "$EVIDENCE_DIR/guardduty" \
  "$EVIDENCE_DIR/report"

# 作成した証跡ディレクトリを表示する。
echo "EVIDENCE_DIR=$EVIDENCE_DIR"
```

PowerShellの場合:

```powershell
# AWS CLIで使うプロファイル名。
$ProfileName = "project-prod"

# 調査対象リージョン。
$Region = "ap-northeast-1"

# 対象AWSアカウントID。
$ExpectedAccountId = "123456789012"

# 調査名。
$InvestigationName = "current-state-investigation"

# 証跡ディレクトリ。
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$EvidenceDir = "evidence\${Timestamp}_${InvestigationName}"

# 用途別ディレクトリを作成する。
New-Item -ItemType Directory -Force -Path `
  "$EvidenceDir\00_metadata", `
  "$EvidenceDir\cloudtrail", `
  "$EvidenceDir\cloudwatch", `
  "$EvidenceDir\eventbridge", `
  "$EvidenceDir\sns", `
  "$EvidenceDir\kms", `
  "$EvidenceDir\s3", `
  "$EvidenceDir\network", `
  "$EvidenceDir\guardduty", `
  "$EvidenceDir\report"

Write-Output "EvidenceDir=$EvidenceDir"
```

## 5. アカウント・リージョン・権限確認

最初に、自分がどのAWSアカウントで作業しているかを確認する。

```bash
# 現在の認証情報で、どのAWSアカウント・IAM User・IAM Roleとして実行しているかを確認する。
# これを最初に保存しておくと、後で「どのアカウントで取った証跡か」が分かる。
aws sts get-caller-identity \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"

# 画面にも表示して確認する。
cat "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

確認ポイント:

- `Account` が対象AWSアカウントか
- `Arn` が想定されたIAM UserまたはAssumedRoleか
- 本番と検証を取り違えていないか

簡易チェック:

```bash
# Account IDだけを取り出して、想定アカウントIDと一致するか確認する。
ACTUAL_ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'Account' \
  --output text \
  --no-cli-pager)

if [ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected account. expected=$EXPECTED_ACCOUNT_ID actual=$ACTUAL_ACCOUNT_ID"
  exit 1
fi

echo "Account check OK: $ACTUAL_ACCOUNT_ID"
```

利用可能リージョン確認:

```bash
# 現場によっては複数リージョンを使うことがある。
# 対象リージョンが本当に有効か確認する。
aws ec2 describe-regions \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'Regions[].RegionName' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/02_regions.json"
```

## 6. CloudTrailの現状確認

CloudTrailは、AWS API操作の証跡を確認する中心になる。

見るポイント:

- Trailが存在するか
- Organization Trailか
- Multi-Region Trailか
- Management Eventを記録しているか
- Data Eventを記録しているか
- S3保存先はどこか
- CloudWatch Logs連携があるか
- Log File Validationが有効か

### 6.1 Trail一覧

```bash
# Trail一覧を取得する。
# include-shadow-trailsを付けると、Multi-Region TrailのShadow Trailも確認できる。
aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/01_describe_trails.json"

# 調査しやすいように重要項目だけ表示する。
aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{
    Name:Name,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    S3Prefix:S3KeyPrefix,
    CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRoleArn:CloudWatchLogsRoleArn
  }' \
  --output json \
  --no-cli-pager
```

確認ポイント:

- `CloudWatchLogsLogGroupArn` が `null` でなければCloudWatch Logs連携あり
- `CloudWatchLogsRoleArn` が `null` でなければCloudTrail配信用IAM Roleあり
- `IsOrganizationTrail` が `true` ならOrganizations管理の可能性あり
- `IsMultiRegionTrail` が `true` なら複数リージョンのManagement Eventを集約している可能性あり

### 6.2 Trail名を決める

Trailが1つだけなら、そのTrail名を使う。
複数ある場合は、対象システム・対象アカウント・運用設計書と突き合わせる。

```bash
# Trail名を手動で設定する。
# describe-trailsの結果から対象Trail名に置き換える。
TRAIL_NAME="<trail-name>"

echo "TRAIL_NAME=$TRAIL_NAME"
```

### 6.3 Trail詳細

```bash
# 対象Trailの詳細設定を取得する。
aws cloudtrail get-trail \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/02_get_trail.json"

# 調査でよく見る項目だけを表示する。
aws cloudtrail get-trail \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{
    Name:Name,
    TrailARN:TrailARN,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    GlobalServiceEvents:IncludeGlobalServiceEvents,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    S3Prefix:S3KeyPrefix,
    KmsKeyId:KmsKeyId,
    CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRoleArn:CloudWatchLogsRoleArn,
    SnsTopic:SnsTopicARN
  }' \
  --output json \
  --no-cli-pager
```

### 6.4 Trailの動作状態

```bash
# Trailが実際にログ記録中か確認する。
aws cloudtrail get-trail-status \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/03_get_trail_status.json"
```

見るポイント:

- `IsLogging` が `true` か
- `LatestDeliveryError` があるか
- `LatestDeliveryTime` が更新されているか
- `LatestCloudWatchLogsDeliveryError` があるか
- `LatestCloudWatchLogsDeliveryTime` が更新されているか

`LatestCloudWatchLogsDeliveryError` が出ている場合、CloudWatch Logs連携のIAM RoleやLog Group権限に問題がある可能性がある。

### 6.5 Event Selector確認

```bash
# CloudTrailが何を記録対象にしているか確認する。
# Management Event、S3 Object Data Event、Advanced Event Selectorの有無を見る。
aws cloudtrail get-event-selectors \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/04_get_event_selectors.json"
```

見るポイント:

- `IncludeManagementEvents` が `true` か
- `ReadWriteType` が `All` / `ReadOnly` / `WriteOnly` のどれか
- `DataResources` にS3 Objectなどが含まれるか
- `AdvancedEventSelectors` を使っているか

注意:

- S3 Bucket Policy変更はManagement Event
- S3 PutObjectはData Event
- NACLやRoute Table変更はManagement Event
- Data Eventは料金とログ量に注意

## 7. CloudTrailとCloudWatch Logs連携確認

今回のようなアラート設定では、CloudTrail単体ではなくCloudWatch Logs連携が重要になる。

確認すること:

- CloudTrailがCloudWatch Logsへ配送しているか
- 配送先Log Group名
- CloudTrail配信用IAM Role
- Log Groupの保持期間
- Log GroupのKMS暗号化
- Metric Filterの有無
- Alarmの有無

### 7.1 CloudWatch Logs連携ARNを取り出す

```bash
# CloudTrailに紐づいているCloudWatch Logs Log Group ARNを取得する。
CLOUDTRAIL_LOG_GROUP_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsLogGroupArn' \
  --output text \
  --no-cli-pager)

# CloudTrail配信用IAM Role ARNを取得する。
CLOUDTRAIL_LOGS_ROLE_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsRoleArn' \
  --output text \
  --no-cli-pager)

echo "CLOUDTRAIL_LOG_GROUP_ARN=$CLOUDTRAIL_LOG_GROUP_ARN"
echo "CLOUDTRAIL_LOGS_ROLE_ARN=$CLOUDTRAIL_LOGS_ROLE_ARN"
```

`None` や `null` の場合:

```text
CloudTrailからCloudWatch Logsへの連携は未設定。
EventBridgeで直接CloudTrail APIイベントを拾う方式か、CloudWatch Logs連携を追加する方式かを検討する。
```

### 7.2 Log Group名を確認する

CloudWatch Logs ARNは次のような形式になる。

```text
arn:aws:logs:ap-northeast-1:123456789012:log-group:/aws/cloudtrail/management-events:*
```

Log Group名はこの部分。

```text
/aws/cloudtrail/management-events
```

BashでARNから取り出す例:

```bash
# ARNから log-group: の後ろを取り出し、末尾の :* を取り除く。
# うまく取れない場合は、手動でLOG_GROUP_NAMEへ設定する。
LOG_GROUP_NAME=$(printf '%s\n' "$CLOUDTRAIL_LOG_GROUP_ARN" \
  | sed 's/^.*:log-group://; s/:\*$//')

echo "LOG_GROUP_NAME=$LOG_GROUP_NAME"
```

手動設定:

```bash
# 現場では手動設定の方が安全なこともある。
LOG_GROUP_NAME="<cloudtrail-log-group-name>"
```

### 7.3 Log Group設定確認

```bash
# CloudTrail配送先Log Groupの設定を確認する。
aws logs describe-log-groups \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/01_cloudtrail_log_group.json"

# 見るべき項目だけ表示する。
aws logs describe-log-groups \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[].{
    LogGroup:logGroupName,
    RetentionDays:retentionInDays,
    StoredBytes:storedBytes,
    KmsKeyId:kmsKeyId,
    MetricFilterCount:metricFilterCount,
    Class:logGroupClass,
    Arn:arn
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- `RetentionDays` が設定されているか
- `KmsKeyId` があるか
- `MetricFilterCount` が0か、それ以上か
- `StoredBytes` が増えているか
- `logGroupClass` が `STANDARD` か

### 7.4 Log Stream確認

```bash
# CloudTrailイベントがCloudWatch Logsへ届いているか確認する。
# LastEventTimestampが新しければ配送されている可能性が高い。
aws logs describe-log-streams \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/02_cloudtrail_log_streams.json"
```

確認ポイント:

- Log Streamが存在するか
- `lastEventTimestamp` が新しいか
- 複数リージョンや複数ストリームに分かれていないか

### 7.5 CloudWatch LogsでCloudTrailイベントを検索

```bash
# CloudWatch Logs上で、最近のCloudTrailイベントを確認する。
# まずは軽く20件だけ見る。
aws logs filter-log-events \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --limit 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/03_recent_cloudtrail_events.json"
```

特定イベントを検索する例:

```bash
# S3 Bucket Policy変更イベントをCloudWatch Logsから検索する。
aws logs filter-log-events \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }' \
  --limit 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/04_s3_bucket_policy_events.json"
```

注意:

- `filter-log-events` は大量ログでは時間がかかる
- 長期間検索はCloudWatch Logs Insightsの方が向く
- 保持期間外のログは検索できない

## 8. Metric Filter確認

CloudTrailログをCloudWatch Logsへ連携している場合、Metric Filterで重要イベントをメトリクス化していることがある。

見るポイント:

- 既存のMetric Filterがあるか
- 何のイベントを検知しているか
- Metric Namespace / Metric Name
- Filter Pattern
- Alarmへつながっているか

```bash
# 対象Log Groupに設定されているMetric Filterを確認する。
aws logs describe-metric-filters \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/05_metric_filters.json"

# 重要項目だけ表示する。
aws logs describe-metric-filters \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --query 'metricFilters[].{
    FilterName:filterName,
    FilterPattern:filterPattern,
    MetricTransformations:metricTransformations
  }' \
  --output json \
  --no-cli-pager
```

既存Filterの読み方:

- `filterName`: フィルター名
- `filterPattern`: どのログを拾うか
- `metricTransformations[].metricNamespace`: 作成されるCloudWatch Metricの名前空間
- `metricTransformations[].metricName`: 作成されるCloudWatch Metric名
- `metricTransformations[].metricValue`: 一致時に加算する値

確認観点:

- S3 Bucket Policy変更検知が既にあるか
- NACL変更検知が既にあるか
- Route Table変更検知が既にあるか
- GuardDuty FindingをLogs経由で処理しているか
- 同じイベントを複数Filterで拾っていないか

## 9. CloudWatch Alarm確認

Metric Filterがあっても、Alarmがなければ通知されない。
Alarmがあっても、Actionが無効なら通知されない。

```bash
# CloudWatch Alarm一覧を取得する。
aws cloudwatch describe-alarms \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/06_cloudwatch_alarms.json"
```

重要項目だけ表示:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'MetricAlarms[].{
    AlarmName:AlarmName,
    State:StateValue,
    Namespace:Namespace,
    MetricName:MetricName,
    Threshold:Threshold,
    ComparisonOperator:ComparisonOperator,
    EvaluationPeriods:EvaluationPeriods,
    Period:Period,
    ActionsEnabled:ActionsEnabled,
    AlarmActions:AlarmActions,
    OKActions:OKActions,
    InsufficientDataActions:InsufficientDataActions
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- `ActionsEnabled` が `true` か
- `AlarmActions` にSNS Topic ARNなどが設定されているか
- 対象MetricがMetric Filter由来か
- Alarm名の命名規則
- `treatMissingData` の扱い
- 通知先が既存運用に合っているか

特定Metricに紐づくAlarmを探す:

```bash
# Metric FilterのMetric Namespace / Metric Nameが分かっている場合に使う。
METRIC_NAMESPACE="<metric-namespace>"
METRIC_NAME="<metric-name>"

aws cloudwatch describe-alarms-for-metric \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/07_alarms_for_metric.json"
```

## 10. EventBridge Rule確認

設定変更検知は、CloudWatch Logs + Metric Filterではなく、EventBridgeで直接CloudTrailイベントを拾っている場合も多い。

見るポイント:

- Ruleが存在するか
- Event Patternが何を拾っているか
- TargetがSNS、Lambda、Step Functions、監視製品などのどれか
- StateがENABLEDか
- Default event busかCustom event busか

### 10.1 Rule一覧

```bash
# EventBridge Rule一覧を取得する。
# まずはdefault event busを見る。
aws events list-rules \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --event-bus-name default \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/eventbridge/01_eventbridge_rules.json"
```

重要項目だけ表示:

```bash
aws events list-rules \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --event-bus-name default \
  --query 'Rules[].{
    Name:Name,
    State:State,
    EventBusName:EventBusName,
    Description:Description,
    ScheduleExpression:ScheduleExpression,
    EventPattern:EventPattern
  }' \
  --output json \
  --no-cli-pager
```

### 10.2 特定Ruleの詳細

```bash
# 確認したいRule名を設定する。
RULE_NAME="<eventbridge-rule-name>"

# Ruleの詳細を取得する。
aws events describe-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --event-bus-name default \
  --name "$RULE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/eventbridge/02_describe_rule_${RULE_NAME}.json"
```

### 10.3 RuleのTarget確認

```bash
# Ruleがどこへ通知・連携しているか確認する。
aws events list-targets-by-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --event-bus-name default \
  --rule "$RULE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/eventbridge/03_targets_${RULE_NAME}.json"
```

見るポイント:

- Target ARNがSNSか
- Lambdaに飛ばしているか
- SSM AutomationやStep Functionsなど自動対応があるか
- DLQやRetry Policyが設定されているか
- Input Transformerがあるか

## 11. SNS確認

EventBridgeやCloudWatch Alarmの通知先としてSNSが使われることが多い。

見るポイント:

- Topicが存在するか
- Topic Policy
- Subscription
- Email購読が承認済みか
- Teamsや監視製品連携があるか

### 11.1 Topic一覧

```bash
# SNS Topic一覧を取得する。
aws sns list-topics \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/sns/01_sns_topics.json"
```

### 11.2 Topic属性確認

```bash
# 調査対象Topic ARNを設定する。
# AlarmActionsやEventBridge Targetに出てきたTopic ARNを使う。
TOPIC_ARN="<sns-topic-arn>"

# Topic PolicyやKMS設定などを確認する。
aws sns get-topic-attributes \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/sns/02_topic_attributes.json"
```

見るポイント:

- `Policy` にEventBridgeやCloudWatchからのPublish許可があるか
- `KmsMasterKeyId` があるか
- `DisplayName`
- `SubscriptionsConfirmed`
- `SubscriptionsPending`

### 11.3 Subscription確認

```bash
# Topicに紐づく通知先を確認する。
aws sns list-subscriptions-by-topic \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/sns/03_subscriptions_by_topic.json"
```

見るポイント:

- `Protocol` が `email` / `lambda` / `sqs` / `https` などのどれか
- `Endpoint` が通知先
- `SubscriptionArn` が `PendingConfirmation` ではないか

注意:

- Email通知は承認メールのConfirmが必要
- PendingConfirmationのままだと通知が届かない
- メーリングリストの場合、解除操作の扱いを確認する

## 12. KMS / カスタマー管理キー確認

監査で「CMKにする」「鍵の管理が終えていない」と言われる場合、主にAWS KMSのカスタマー管理キーを指していることが多い。
AWS公式では、現在は「KMSキー」「カスタマー管理キー」という呼び方が中心である。
現場では古い呼び方としてCMKと呼ばれることも多い。

確認すること:

- 対象サービスがAWS owned key、AWS managed key、Customer managed keyのどれを使っているか
- カスタマー管理キーの `KeyManager` が `CUSTOMER` か
- Key Policyで管理者と利用者が適切に分かれているか
- 自動Rotationが有効か
- 削除予約中のキーがないか
- Aliasが分かりやすい名前になっているか
- Grantsで想定外の利用許可がないか
- CloudTrail、CloudWatch Logs、SNS、S3などの暗号化設定でどのKMSキーを使っているか

### 12.1 KMSキー一覧

```bash
# KMSキー一覧を取得する。
# list-keysはKeyIdとKeyArnだけを返すため、詳細確認にはdescribe-keyを組み合わせる。
aws kms list-keys \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/01_list_keys.json"

# Alias一覧を取得する。
# alias/aws/ で始まるものはAWS managed keyであることが多い。
# alias/<システム名> のようなものはカスタマー管理キーの候補になる。
aws kms list-aliases \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/02_list_aliases.json"
```

見るポイント:

- `alias/aws/` で始まるAliasはAWS managed key
- `alias/<system-name>` のようなAliasはカスタマー管理キーの候補
- Key ARNはリージョン、アカウント、Key IDを含む

### 12.2 KMSキー詳細

```bash
# 調査対象のKMSキーを設定する。
# Key ID、Key ARN、Alias nameのいずれかを指定できる。
KMS_KEY_ID="<kms-key-id-or-arn-or-alias>"

# KMSキーの詳細を取得する。
aws kms describe-key \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/03_describe_key.json"

# 重要項目だけ表示する。
aws kms describe-key \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --query 'KeyMetadata.{
    KeyId:KeyId,
    Arn:Arn,
    Description:Description,
    Enabled:Enabled,
    KeyState:KeyState,
    KeyManager:KeyManager,
    KeyUsage:KeyUsage,
    KeySpec:KeySpec,
    Origin:Origin,
    MultiRegion:MultiRegion,
    CreationDate:CreationDate,
    DeletionDate:DeletionDate
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- `KeyManager` が `CUSTOMER` ならカスタマー管理キー
- `KeyManager` が `AWS` ならAWS managed key
- `Enabled` が `true` か
- `KeyState` が `Enabled` か
- `DeletionDate` がある場合、削除予約中
- `KeyUsage` が `ENCRYPT_DECRYPT` か
- `MultiRegion` が要件に合うか

### 12.3 Key Policy確認

```bash
# Key Policy名一覧を確認する。
aws kms list-key-policies \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/04_list_key_policies.json"

# default Key Policyを取得する。
# Key Policyは鍵の管理権限に直結するため、監査で非常に重要。
aws kms get-key-policy \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --policy-name default \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/05_key_policy_default.json"
```

見るポイント:

- 管理者Principalが誰か
- 利用者Principalが誰か
- `kms:*` が広すぎないか
- `Principal: "*"` がないか
- rootだけに依存していないか
- 対象サービスが利用できる権限を持っているか
- クロスアカウント利用があるか

### 12.4 Rotation確認

```bash
# 自動Rotationが有効か確認する。
# カスタマー管理の対称暗号KMSキーでは、自動Rotationを有効化できる。
aws kms get-key-rotation-status \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/06_key_rotation_status.json"
```

見るポイント:

- `KeyRotationEnabled` が `true` か
- 監査要件でRotationが求められているか
- 非対称キーや一部キーでは自動Rotation対象外になることがある

### 12.5 Grants確認

```bash
# KMS Grantsを確認する。
# GrantsはAWSサービスやRoleに対してKMSキー利用を許可する仕組み。
aws kms list-grants \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/07_list_grants.json"
```

見るポイント:

- `GranteePrincipal` が想定されたRoleか
- 不要なGrantが残っていないか
- AWSサービス連携に必要なGrantか

### 12.6 Tags確認

```bash
# KMSキーのタグを確認する。
# 金融現場では、システム名、環境、本番/検証、管理部署などのタグが重要になる。
aws kms list-resource-tags \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/08_list_resource_tags.json"
```

### 12.7 サービス側でKMSキーを使っているか確認

S3:

```bash
# S3バケットがSSE-KMSを使っているか確認する。
# SSEAlgorithmが aws:kms ならKMS利用。
# KMSMasterKeyIDにカスタマー管理キーのARNやAliasが出るかを見る。
aws s3api get-bucket-encryption \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/09_s3_bucket_encryption_${BUCKET_NAME}.json"
```

CloudTrail:

```bash
# CloudTrailログファイル暗号化にKMSキーを使っているか確認する。
aws cloudtrail get-trail \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{Name:Name,KmsKeyId:KmsKeyId,S3Bucket:S3BucketName,CloudWatchLogs:CloudWatchLogsLogGroupArn}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/10_cloudtrail_kms_setting.json"
```

CloudWatch Logs:

```bash
# Log GroupがKMSで暗号化されているか確認する。
aws logs describe-log-groups \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'logGroups[].{
    LogGroup:logGroupName,
    KmsKeyId:kmsKeyId,
    RetentionDays:retentionInDays,
    StoredBytes:storedBytes
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/11_cloudwatch_logs_kms_settings.json"
```

SNS:

```bash
# SNS TopicがKMSで暗号化されているか確認する。
aws sns get-topic-attributes \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/kms/12_sns_topic_kms_setting.json"
```

監査での読み方:

```text
AWS managed keyやAWS owned keyでも暗号化はされているが、
鍵のライフサイクル、Key Policy、Rotation、削除、利用監査を顧客側で制御したい場合は
カスタマー管理キーが求められることがある。
```

## 13. S3現状確認

S3関連タスクでは、対象バケットの設定と変更検知の既存有無を見る。

見るポイント:

- Bucket Policy
- Policy Status
- Public Access Block
- Server Access Logging
- Versioning
- Encryption
- Object Ownership
- EventBridge / CloudTrailでの変更検知有無

```bash
# 対象バケット名を設定する。
BUCKET_NAME="<bucket-name>"

# Bucket PolicyのPublic判定を確認する。
aws s3api get-bucket-policy-status \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/01_bucket_policy_status_${BUCKET_NAME}.json"

# Bucket Policy本体を取得する。
# Policyが存在しない場合はNoSuchBucketPolicyになることがある。
aws s3api get-bucket-policy \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/02_bucket_policy_${BUCKET_NAME}.json"

# Public Access Blockを確認する。
aws s3api get-public-access-block \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/03_public_access_block_${BUCKET_NAME}.json"

# Server Access Loggingを確認する。
aws s3api get-bucket-logging \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/04_bucket_logging_${BUCKET_NAME}.json"

# Versioningを確認する。
aws s3api get-bucket-versioning \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/05_bucket_versioning_${BUCKET_NAME}.json"

# Encryptionを確認する。
aws s3api get-bucket-encryption \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/06_bucket_encryption_${BUCKET_NAME}.json"

# Object Ownershipを確認する。
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/07_bucket_ownership_controls_${BUCKET_NAME}.json"
```

注意:

- `get-bucket-policy` はPolicyなしの場合エラーになる
- `get-bucket-encryption` は暗号化設定が明示されていない場合エラーになることがある
- 金融現場では、エラーも「設定なし」の証跡として保存する方がよい

エラーも保存したい場合:

```bash
# stdoutとstderrをまとめて保存する例。
aws s3api get-bucket-policy \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/s3/02_bucket_policy_${BUCKET_NAME}.json" \
  2> "$EVIDENCE_DIR/s3/02_bucket_policy_${BUCKET_NAME}.stderr.txt" || true
```

## 14. VPC Flow Logs確認

VPC Flow Logsは通信メタデータを保存する設定である。
有効化状況、保存先、対象リソース、ログ形式を確認する。

```bash
# VPC Flow Logs一覧を確認する。
aws ec2 describe-flow-logs \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/network/01_flow_logs.json"
```

重要項目だけ表示:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'FlowLogs[].{
    FlowLogId:FlowLogId,
    ResourceId:ResourceId,
    ResourceType:ResourceType,
    TrafficType:TrafficType,
    LogDestinationType:LogDestinationType,
    LogGroupName:LogGroupName,
    LogDestination:LogDestination,
    DeliverLogsStatus:DeliverLogsStatus,
    DeliverLogsErrorMessage:DeliverLogsErrorMessage,
    LogFormat:LogFormat,
    MaxAggregationInterval:MaxAggregationInterval,
    CreationTime:CreationTime
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- `ResourceType`: VPC / Subnet / NetworkInterface
- `TrafficType`: ACCEPT / REJECT / ALL
- `LogDestinationType`: cloud-watch-logs / s3
- `DeliverLogsStatus`: SUCCESSか
- `DeliverLogsErrorMessage`: エラーがないか
- `LogFormat`: デフォルトかカスタムか

## 15. NACL確認

NACL変更アラートを作る前に、既存NACLと対象VPCを確認する。

```bash
# NACL一覧を取得する。
aws ec2 describe-network-acls \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/network/02_network_acls.json"
```

重要項目だけ表示:

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'NetworkAcls[].{
    NetworkAclId:NetworkAclId,
    VpcId:VpcId,
    IsDefault:IsDefault,
    Associations:Associations[].SubnetId,
    Tags:Tags,
    EntryCount:length(Entries)
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- 対象VPCのNACLか
- Default NACLか
- どのSubnetに関連付いているか
- Entry数
- 既存運用でNACLを使っているか

## 16. Route Table確認

Route Table変更アラートを作る前に、既存Route Tableと関連付けを確認する。

```bash
# Route Table一覧を取得する。
aws ec2 describe-route-tables \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/network/03_route_tables.json"
```

重要項目だけ表示:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --query 'RouteTables[].{
    RouteTableId:RouteTableId,
    VpcId:VpcId,
    Associations:Associations[].{
      Main:Main,
      SubnetId:SubnetId,
      AssociationId:RouteTableAssociationId
    },
    Routes:Routes[].{
      DestinationCidrBlock:DestinationCidrBlock,
      DestinationIpv6CidrBlock:DestinationIpv6CidrBlock,
      GatewayId:GatewayId,
      NatGatewayId:NatGatewayId,
      TransitGatewayId:TransitGatewayId,
      VpcEndpointId:VpcEndpointId,
      NetworkInterfaceId:NetworkInterfaceId,
      State:State
    },
    Tags:Tags
  }' \
  --output json \
  --no-cli-pager
```

見るポイント:

- `0.0.0.0/0` の向き
- Internet Gateway向けルート
- NAT Gateway向けルート
- Transit Gateway向けルート
- VPC Endpoint向けルート
- Main Route Tableか
- どのSubnetに関連付いているか

## 17. GuardDuty確認

GuardDuty関連タスクでは、Detector、Feature、Finding、EventBridge連携を確認する。

```bash
# Detector一覧を取得する。
aws guardduty list-detectors \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/guardduty/01_list_detectors.json"
```

Detector ID設定:

```bash
# Detectorが1つの場合、手動で設定する。
DETECTOR_ID="<detector-id>"
```

Detector詳細:

```bash
# GuardDuty Detectorの設定を確認する。
aws guardduty get-detector \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/guardduty/02_get_detector.json"
```

重要項目だけ表示:

```bash
aws guardduty get-detector \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{
    Status:Status,
    FindingPublishingFrequency:FindingPublishingFrequency,
    ServiceRole:ServiceRole,
    Features:Features[].{
      Name:Name,
      Status:Status,
      UpdatedAt:UpdatedAt
    }
  }' \
  --output json \
  --no-cli-pager
```

Finding一覧:

```bash
# ArchiveされていないFindingを確認する。
aws guardduty list-findings \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/guardduty/03_active_finding_ids.json"
```

Finding詳細:

```bash
# Finding IDを手動で設定する。
FINDING_ID="<finding-id>"

# Finding詳細を取得する。
aws guardduty get-findings \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/guardduty/04_finding_detail_${FINDING_ID}.json"
```

見るポイント:

- `type`
- `severity`
- `title`
- `description`
- `resource`
- `service.action`
- `service.archived`
- `accountId`
- `region`
- `createdAt`
- `updatedAt`

## 18. CloudTrail Event Historyで変更履歴確認

特定の変更イベントが過去に発生しているか確認する。

S3 Bucket Policy変更:

```bash
# 対象バケットに関係するCloudTrailイベントを検索する。
aws cloudtrail lookup-events \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --max-results 50 \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/05_s3_bucket_policy_change_events_${BUCKET_NAME}.json"
```

NACL変更:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateNetworkAclEntry \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/06_create_network_acl_entry_events.json"
```

Route Table変更:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateRoute \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/07_create_route_events.json"
```

注意:

- `lookup-events` の `--lookup-attributes` は一度に原則1種類
- 複数条件は `--query` で絞る
- 大量に実行すると `ThrottlingException` になりやすい
- 対象期間が古い場合はS3保存ログやCloudWatch Logsを確認する

## 19. 既存設定の棚卸し表

調査後は、以下のような表にまとめる。

| 項目 | 現状 | 対応要否 | 根拠ファイル | 備考 |
|---|---|---|---|---|
| CloudTrail | あり / なし | 要 / 不要 | `cloudtrail/01_describe_trails.json` | Trail名、Organization Trailか |
| CloudWatch Logs連携 | あり / なし | 要 / 不要 | `cloudtrail/02_get_trail.json` | Log Group名 |
| Log Group保持期間 | 7日 / 30日 / 無期限 | 要 / 不要 | `cloudwatch/01_cloudtrail_log_group.json` | 監査要件と比較 |
| Metric Filter | あり / なし | 要 / 不要 | `cloudwatch/05_metric_filters.json` | 検知対象 |
| CloudWatch Alarm | あり / なし | 要 / 不要 | `cloudwatch/06_cloudwatch_alarms.json` | 通知先 |
| EventBridge Rule | あり / なし | 要 / 不要 | `eventbridge/01_eventbridge_rules.json` | 重複確認 |
| SNS Topic | あり / なし | 要 / 不要 | `sns/01_sns_topics.json` | 通知先 |
| KMSカスタマー管理キー | あり / なし | 要 / 不要 | `kms/03_describe_key.json` | KeyManager、Key Policy、Rotation |
| S3 Bucket Policy変更検知 | あり / なし | 要 / 不要 | 複数 | PutBucketPolicy/DeleteBucketPolicy |
| NACL変更検知 | あり / なし | 要 / 不要 | 複数 | 対象VPC |
| Route Table変更検知 | あり / なし | 要 / 不要 | 複数 | 対象VPC |
| VPC Flow Logs | 有効 / 無効 | 要 / 不要 | `network/01_flow_logs.json` | 保存先、TrafficType |
| GuardDuty | 有効 / 無効 | 要 / 不要 | `guardduty/02_get_detector.json` | Finding通知、手順書 |

## 20. 調査後の判断

調査後は、各タスクを次のどれかに分類する。

```text
1. 既存設定で対応済み
2. 既存設定はあるが不足あり
3. 新規設定が必要
4. 設定変更は不要で手順書整備のみ
5. 権限不足で確認不可
6. 現場確認待ち
```

報告例:

```text
CloudTrailはOrganization Trailとして有効で、Management Eventは記録されています。
CloudWatch Logs連携もあり、Log Groupの保持期間は90日です。
ただし、S3 Bucket Policy変更を検知するMetric FilterまたはEventBridge Ruleは確認できませんでした。
通知先SNS Topicは既存のものがあるため、利用可否を確認したうえで追加設定を検討します。
```

権限不足時の報告例:

```text
CloudTrailのTrail一覧は確認できましたが、events:ListRules が不足しているため、
既存EventBridge Ruleの有無を確認できません。
アラート重複確認に必要なため、参照権限の追加可否を確認したいです。
```

## 21. 調査で必要になりやすい参照権限

CloudTrail:

- `cloudtrail:DescribeTrails`
- `cloudtrail:GetTrail`
- `cloudtrail:GetTrailStatus`
- `cloudtrail:GetEventSelectors`
- `cloudtrail:LookupEvents`

CloudWatch Logs / Alarm:

- `logs:DescribeLogGroups`
- `logs:DescribeLogStreams`
- `logs:FilterLogEvents`
- `logs:DescribeMetricFilters`
- `cloudwatch:DescribeAlarms`
- `cloudwatch:DescribeAlarmsForMetric`

EventBridge:

- `events:ListRules`
- `events:DescribeRule`
- `events:ListTargetsByRule`

SNS:

- `sns:ListTopics`
- `sns:GetTopicAttributes`
- `sns:ListSubscriptionsByTopic`

KMS:

- `kms:ListKeys`
- `kms:ListAliases`
- `kms:DescribeKey`
- `kms:ListKeyPolicies`
- `kms:GetKeyPolicy`
- `kms:GetKeyRotationStatus`
- `kms:ListGrants`
- `kms:ListResourceTags`

S3:

- `s3:GetBucketPolicy`
- `s3:GetBucketPolicyStatus`
- `s3:GetBucketPublicAccessBlock`
- `s3:GetBucketLogging`
- `s3:GetBucketVersioning`
- `s3:GetEncryptionConfiguration`
- `s3:GetBucketOwnershipControls`

EC2 / VPC:

- `ec2:DescribeFlowLogs`
- `ec2:DescribeNetworkAcls`
- `ec2:DescribeRouteTables`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`

GuardDuty:

- `guardduty:ListDetectors`
- `guardduty:GetDetector`
- `guardduty:ListFindings`
- `guardduty:GetFindings`

## 22. 現場での一言まとめ

```text
まず参照系権限で既存のCloudTrail、CloudWatch Logs連携、Metric Filter、Alarm、EventBridge、SNS、対象リソースを棚卸しします。
その結果をもとに、既存設定で足りているもの、新規設定が必要なもの、手順書整備で足りるものに分類します。
```

## 23. 公式ドキュメント

- AWS KMS keys: https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html
- AWS KMS key rotation: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html
- AWS KMS CloudTrail logging: https://docs.aws.amazon.com/kms/latest/developerguide/logging-using-cloudtrail.html
- AWS KMS key policies: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
