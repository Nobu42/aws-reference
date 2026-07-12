# AWSセキュリティ監査指摘 現状調査手順書

作成日: 2026-07-07

この資料は、第三者検証評価シートの確認項目をもとに、AWS環境の現状を調査し、対応済み・不足・要確認・対象外を整理するための手順書である。

本資料は、設定変更前の調査、作業計画作成、設計レビュー、手順書作成、テスト計画作成に流用できることを目的とする。

## 1. 調査方針

今回の指摘は、個別のAWSサービス設定だけでなく、以下の流れが成立しているかを確認するものが多い。

```text
CloudTrailで操作ログを記録する
  ↓
CloudTrailログをCloudWatch Logsへ連携する
  ↓
CloudWatch Logs Metric Filterで対象イベントを検知する
  ↓
CloudWatch Alarmで発報する
  ↓
SNS等で運用担当へ通知する
  ↓
手順書に従って確認・記録・エスカレーションする
```

そのため、最初に要件ごとに個別調査するのではなく、以下をまとめて棚卸しする。

- AWSアカウント、リージョン、環境区分
- CloudTrail証跡
- CloudTrailログ保存先S3
- CloudTrailとCloudWatch Logsの連携
- CloudWatch Logs Log Group
- Metric Filter
- CloudWatch Alarm
- SNS通知先
- EventBridge Rule
- GuardDuty
- VPC Flow Logs
- KMSキー
- 運用手順書、月次確認、日次確認、アラート対応履歴

## 2. 評価シートの確認項目

この手順書で調査対象とする要件は以下。

| 要件番号 | 種別 | セクション | 確認項目 | 評価シート上の主な指摘 |
|---|---|---|---|---|
| A3 | 共通 | 共通確認項目 | セキュリティアラートに関するモニタリング運用手順書があること | GuardDutyを用いたセキュリティアラートのモニタリング手順が文書化されていない |
| A4 | 共通 | 共通確認項目 | セキュリティアラートに関するモニタリングが日々の運用で実施されていること | GuardDutyで検知されたイベント調査エビデンスが提出されていない。A3で対応 |
| 3.4 | AWS | ロギング | CloudTrail S3バケットでサーバーアクセスログが有効になっていること | Prod・OPER環境でCloudTrail S3バケットのサーバーアクセスログが無効 |
| 3.5 | AWS | ロギング | CloudTrailログがKMS CMKを使用して保存時に暗号化されていること | Prod・OPER環境でSSE-S3暗号化だがSSE-KMSではない |
| 3.6 | AWS | ロギング | カスタマー作成の対称CMKのローテーションが有効になっていること | 3.5でCMK未使用のため評価対象CMKがない。3.5で対応 |
| 3.7 | AWS | ロギング | すべてのVPCでVPCフローのログ記録が有効になっていること | Prodは有効、OPERは無効 |
| 4.1 | AWS | モニタリング | 不正なAPI呼び出しが監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.2 | AWS | モニタリング | MFAなし管理コンソールサインインが監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.3 | AWS | モニタリング | rootアカウントの使用が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.4 | AWS | モニタリング | IAMポリシーの変更が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.5 | AWS | モニタリング | CloudTrailの設定変更が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.6 | AWS | モニタリング | AWS Management Consoleの認証失敗が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.7 | AWS | モニタリング | 顧客作成CMKの無効化または削除予約が監視されていること | CMK無効化または削除予約が監視されていない |
| 4.8 | AWS | モニタリング | S3バケットポリシーの変更が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.9 | AWS | モニタリング | AWS Configの設定変更が監視されていること | AWS Configの設定変更が監視されていない |
| 4.10 | AWS | モニタリング | Security Groupの変更が監視されていること | GuardDuty月次確認はあるが通知設定がない |
| 4.11 | AWS | モニタリング | NACLの変更が監視されていること | NACLの変更が監視されていない |
| 4.12 | AWS | モニタリング | Network Gatewayの変更が監視されていること | Network Gatewayの変更が監視されていない |
| 4.13 | AWS | モニタリング | Route Tableの変更が監視されていること | Route Tableの変更が監視されていない |
| 4.14 | AWS | モニタリング | VPCの変更が監視されていること | VPCの変更が監視されていない |
| 4.15 | AWS | モニタリング | AWS Organizationsの変更が監視されていること | AWS Organizationsの変更が監視されていない |

## 3. 作業前提

### 3.1 作業端末

AWS CLIを使用できる端末で実施する。

Windows端末の場合は、PowerShellまたはGit Bashを使用する。
Linux/macOS端末の場合は、bashを使用する。

### 3.2 必要な情報

作業前に以下を確認する。

| 項目 | 例 | 備考 |
|---|---|---|
| AWS CLI Profile | `prod-profile` | 現場指定のProfile名 |
| 対象リージョン | `ap-northeast-1` | 複数リージョンの場合は全対象 |
| 対象AWSアカウントID | `123456789012` | 誤操作防止 |
| 対象環境 | `Prod`, `OPER` | 評価シートではProd・OPERが対象 |
| CloudTrail名 | 現地確認 | Organization Trailの可能性あり |
| CloudTrailログ保存先S3 | 現地確認 | 3.4、3.5の対象 |
| 通知先 | SNS、メール、Teams等 | 4.1〜4.15の対象 |
| 証跡保存先 | 現地ルールに従う | 画面キャプチャ、CLI出力 |

### 3.3 変数設定

以降のコマンドでは、まず以下を設定する。

```bash
PROFILE="<aws-cli-profile>"
REGION="<target-region>"
EXPECTED_ACCOUNT_ID="<target-account-id>"

EVIDENCE_ROOT="./evidence_current_state_$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$EVIDENCE_ROOT"/{00_account,01_cloudtrail,02_s3,03_cloudwatch,04_sns,05_eventbridge,06_guardduty,07_vpc,08_kms,09_config,10_organizations,99_summary}
```

作業例:

```bash
PROFILE="prod-profile"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="123456789012"
```

## 4. AWSアカウント確認

### 4.1 Caller Identity確認

目的:
作業対象AWSアカウントが正しいことを確認する。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/00_account/01_caller_identity.json"
```

確認:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query '{Account:Account,Arn:Arn,UserId:UserId}' \
  --output table \
  --no-cli-pager
```

判定:

| 見る項目 | 確認内容 |
|---|---|
| `Account` | 想定AWSアカウントIDと一致すること |
| `Arn` | 作業用IAM User、AssumedRole、SSO Roleなど想定どおりであること |

## 5. CloudTrail現状調査

対象要件:

- 3.4
- 3.5
- 3.6
- 4.1〜4.15

### 5.1 Trail一覧確認

目的:
対象アカウントに存在するCloudTrail証跡を確認する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/01_describe_trails.json"
```

見やすい表示:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
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
    KmsKeyId:KmsKeyId,
    CloudWatchLogs:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRole:CloudWatchLogsRoleArn
  }' \
  --output table \
  --no-cli-pager
```

判定:

| 見る項目 | 確認内容 |
|---|---|
| `Name` | 対象Trail名 |
| `MultiRegion` | 全リージョン監査が必要なら `True` が望ましい |
| `Organization` | Organizations管理の場合は `True` の可能性 |
| `LogValidation` | ログファイル整合性検証の有効化状態 |
| `S3Bucket` | CloudTrailログ保存先S3 |
| `KmsKeyId` | SSE-KMS利用有無。空ならSSE-KMS未設定 |
| `CloudWatchLogs` | CloudWatch Logs連携有無 |
| `CloudWatchLogsRole` | CloudTrailがCloudWatch Logsへ書き込むIAM Role |

### 5.2 Trail単位の詳細確認

Trail名を設定する。

```bash
TRAIL_NAME="<trail-name>"
```

詳細取得:

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/02_get_trail_${TRAIL_NAME}.json"
```

状態確認:

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/03_get_trail_status_${TRAIL_NAME}.json"
```

イベントセレクタ確認:

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/04_get_event_selectors_${TRAIL_NAME}.json"
```

判定:

| 見る項目 | 確認内容 |
|---|---|
| `IsLogging` | `true` であること |
| `LatestDeliveryError` | エラーがないこと |
| `EventSelectors[].IncludeManagementEvents` | Management Eventが記録対象か |
| `EventSelectors[].ReadWriteType` | Read/Writeの対象範囲 |
| `DataResources` | S3 Object Data Eventなどの有効化対象 |
| `AdvancedEventSelectors` | Advanced Event Selector利用有無 |

## 6. CloudTrailログ保存先S3調査

対象要件:

- 3.4
- 3.5
- 3.6

### 6.1 CloudTrailログ保存先S3を変数へ設定

Trailの `S3BucketName` を設定する。

```bash
CLOUDTRAIL_BUCKET="<cloudtrail-log-bucket-name>"
```

### 6.2 S3バケット存在確認

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

### 6.3 3.4 Server Access Logging確認

目的:
CloudTrailログ保存先S3バケットでサーバーアクセスログが有効か確認する。

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/02_s3/01_cloudtrail_bucket_logging.json"
```

判定:

| 状態 | 読み方 |
|---|---|
| `LoggingEnabled` がある | Server Access Logging有効 |
| `{}` または `LoggingEnabled` がない | Server Access Logging無効 |

追加で確認する項目:

| 項目 | 理由 |
|---|---|
| `TargetBucket` | アクセスログの保存先 |
| `TargetPrefix` | アクセスログの保存プレフィックス |
| 保存先バケットのライフサイクル | ログ増加によるコスト管理 |
| 保存先バケットの暗号化 | ログの保護 |
| 保存先バケットのアクセス制御 | ログ閲覧権限の制限 |

### 6.4 3.5 CloudTrailログSSE-KMS確認

目的:
CloudTrailログがKMS CMK、現在の表現ではカスタマー管理KMSキーで暗号化されているか確認する。

CloudTrail側:

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{Name:Name,S3Bucket:S3BucketName,KmsKeyId:KmsKeyId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/05_trail_kms_status_${TRAIL_NAME}.json"
```

S3バケット側:

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/02_s3/02_cloudtrail_bucket_encryption.json"
```

判定:

| 見る項目 | 読み方 |
|---|---|
| Trailの `KmsKeyId` | CloudTrailログ暗号化に使うKMSキー。空ならCloudTrail側SSE-KMS未設定 |
| S3の `SSEAlgorithm` が `aws:kms` | バケットデフォルト暗号化がSSE-KMS |
| S3の `SSEAlgorithm` が `AES256` | SSE-S3 |

注意:
評価シートでは、SSE-S3ではなくSSE-KMS、かつCMKを使用することが指摘されている。
CloudTrailの `KmsKeyId` とS3バケット暗号化は両方確認する。

### 6.5 3.6 カスタマー管理KMSキーのローテーション確認

3.5で使用されているKMSキーIDを設定する。

```bash
KMS_KEY_ID="<kms-key-id-or-arn>"
```

KMSキー詳細:

```bash
aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/08_kms/01_describe_key.json"
```

ローテーション確認:

```bash
aws kms get-key-rotation-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/08_kms/02_key_rotation_status.json"
```

Key Policy確認:

```bash
aws kms get-key-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --policy-name default \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/08_kms/03_key_policy.json"
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `KeyManager` | `CUSTOMER` ならカスタマー管理KMSキー |
| `KeySpec` | 対称キーなら `SYMMETRIC_DEFAULT` |
| `KeyState` | `Enabled` であること |
| `KeyRotationEnabled` | `true` であること |
| Key Policy | CloudTrailから利用できる権限があること |

## 7. VPC Flow Logs調査

対象要件:

- 3.7

### 7.1 VPC一覧確認

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[].{
    VpcId:VpcId,
    CidrBlock:CidrBlock,
    IsDefault:IsDefault,
    Name:Tags[?Key==`Name`].Value|[0]
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/07_vpc/01_vpcs.json"
```

### 7.2 VPC Flow Logs確認

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/07_vpc/02_flow_logs.json"
```

見やすい表示:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'FlowLogs[].{
    FlowLogId:FlowLogId,
    ResourceId:ResourceId,
    ResourceType:ResourceType,
    TrafficType:TrafficType,
    LogDestinationType:LogDestinationType,
    LogDestination:LogDestination,
    FlowLogStatus:FlowLogStatus
  }' \
  --output table \
  --no-cli-pager
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `ResourceType` | `VPC`、`Subnet`、`NetworkInterface` のどの単位か |
| `ResourceId` | 対象VPC IDが含まれているか |
| `TrafficType` | `ALL` が望ましい場合が多い |
| `FlowLogStatus` | `ACTIVE` であること |
| `LogDestinationType` | CloudWatch LogsまたはS3 |

注意:
評価シートでは、Prodは有効、OPERは無効とされている。
Prod/OPERそれぞれのVPC IDを突き合わせて、全VPCで有効かを確認する。

## 8. CloudWatch Logs連携調査

対象要件:

- 4.1〜4.15

### 8.1 CloudTrail連携先Log Group確認

TrailからCloudWatch Logs Log Group ARNを確認する。

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/01_cloudtrail_cloudwatch_logs_link.json"
```

Log Group名を設定する。

```bash
CLOUDTRAIL_LOG_GROUP_NAME="<cloudtrail-cloudwatch-log-group-name>"
```

例:

```bash
CLOUDTRAIL_LOG_GROUP_NAME="/aws/cloudtrail/management-events"
```

### 8.2 Log Group確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/02_cloudtrail_log_group.json"
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `logGroupName` | CloudTrail連携先Log Group |
| `retentionInDays` | 保持期間 |
| `kmsKeyId` | CloudWatch Logs暗号化に使うKMSキー |
| `storedBytes` | ログ蓄積量 |
| `metricFilterCount` | Metric Filter数 |

### 8.3 Log Stream確認

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/03_cloudtrail_log_streams.json"
```

### 8.4 CloudTrailイベントがCloudWatch Logsに届いているか確認

直近のイベントを確認する。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --limit 5 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/04_recent_cloudtrail_events_in_logs.json"
```

判定:

| 状態 | 読み方 |
|---|---|
| eventsが返る | CloudWatch Logsへ配送されている |
| eventsが空 | 配送遅延、連携なし、期間外、Log Group誤りの可能性 |

## 9. Metric Filter現状調査

対象要件:

- 4.1〜4.15

### 9.1 CloudTrail Log Group上のMetric Filter確認

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/05_metric_filters_cloudtrail_log_group.json"
```

見やすい表示:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --query 'metricFilters[].{
    FilterName:filterName,
    Pattern:filterPattern,
    MetricName:metricTransformations[0].metricName,
    Namespace:metricTransformations[0].metricNamespace,
    MetricValue:metricTransformations[0].metricValue
  }' \
  --output table \
  --no-cli-pager
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `filterName` | 監視名 |
| `filterPattern` | どのイベントを拾うか |
| `metricNamespace` | メトリクス名前空間 |
| `metricName` | Alarmが参照するメトリクス名 |

## 10. CloudWatch Alarm現状調査

対象要件:

- 4.1〜4.15

### 10.1 Alarm一覧確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/03_cloudwatch/06_cloudwatch_alarms.json"
```

見やすい表示:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[].{
    AlarmName:AlarmName,
    State:StateValue,
    Namespace:Namespace,
    MetricName:MetricName,
    Threshold:Threshold,
    Comparison:ComparisonOperator,
    ActionsEnabled:ActionsEnabled,
    AlarmActions:AlarmActions
  }' \
  --output table \
  --no-cli-pager
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `AlarmName` | 対象要件に対応するAlarmか |
| `Namespace` / `MetricName` | Metric Filterの出力先と一致するか |
| `ActionsEnabled` | 通知アクションが有効か |
| `AlarmActions` | SNS Topic等が紐づいているか |
| `StateValue` | `OK`, `ALARM`, `INSUFFICIENT_DATA` |

## 11. SNS通知先調査

対象要件:

- 4.1〜4.15
- A3
- A4

### 11.1 SNS Topic一覧

```bash
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/04_sns/01_topics.json"
```

### 11.2 SNS Subscription一覧

```bash
aws sns list-subscriptions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/04_sns/02_subscriptions.json"
```

判定:

| 見る項目 | 読み方 |
|---|---|
| `TopicArn` | Alarm Actionに設定されているTopicか |
| `Protocol` | email、https、lambda等 |
| `Endpoint` | 通知先 |
| `SubscriptionArn` | `PendingConfirmation` の場合は未確認 |

注意:
金融現場では、直接メール通知ではなく、Teams、監視基盤、ServiceNow、JP1、Hinemos、SIEM等へ連携している可能性がある。
SNSだけで完結しているとは限らない。

## 12. EventBridge現状調査

対象要件:

- GuardDuty通知
- 自動対応の有無
- 4.1〜4.15の代替通知経路確認

### 12.1 Rule一覧

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/05_eventbridge/01_rules.json"
```

### 12.2 GuardDuty関連Rule確認

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Rules[?contains(Name, `GuardDuty`) || contains(Description, `GuardDuty`)].{
    Name:Name,
    State:State,
    EventBusName:EventBusName,
    Description:Description
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/05_eventbridge/02_guardduty_related_rules.json"
```

### 12.3 Rule詳細とTarget確認

Rule名を設定する。

```bash
EVENTBRIDGE_RULE_NAME="<eventbridge-rule-name>"
```

```bash
aws events describe-rule \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$EVENTBRIDGE_RULE_NAME" \
  --output json \
  --no-cli-pager
```

```bash
aws events list-targets-by-rule \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule "$EVENTBRIDGE_RULE_NAME" \
  --output json \
  --no-cli-pager
```

確認ポイント:

| 見る項目 | 理由 |
|---|---|
| `EventPattern` | GuardDutyやCloudTrailイベントを拾っているか |
| `Targets` | SNS、Lambda、Step Functions、SSM Automation等 |
| 自動対応の有無 | Security Group隔離、IAM無効化などの影響確認 |

## 13. GuardDuty現状調査

対象要件:

- A3
- A4
- 4.1〜4.3等の既存運用確認

### 13.1 Detector一覧

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/06_guardduty/01_detectors.json"
```

Detector IDを設定する。

```bash
DETECTOR_ID="<guardduty-detector-id>"
```

### 13.2 Detector詳細

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/06_guardduty/02_detector_detail.json"
```

見やすい表示:

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{
    Status:Status,
    FindingPublishingFrequency:FindingPublishingFrequency,
    ServiceRole:ServiceRole,
    Features:Features[].{Name:Name,Status:Status,UpdatedAt:UpdatedAt}
  }' \
  --output json \
  --no-cli-pager
```

### 13.3 Finding件数確認

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-statistic-types COUNT_BY_SEVERITY \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/06_guardduty/03_finding_statistics.json"
```

### 13.4 未アーカイブFinding確認

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/06_guardduty/04_unarchived_findings.json"
```

確認ポイント:

| 見る項目 | 理由 |
|---|---|
| Detectorが有効か | GuardDuty運用の前提 |
| Findingがあるか | A4の運用実績確認 |
| 月次確認記録があるか | 評価シートで指摘されている点 |
| 通知連携があるか | 4.1等の通知不足指摘に関係 |
| 対応手順書があるか | A3の対象 |

## 14. AWS Config現状調査

対象要件:

- 4.9

### 14.1 Configuration Recorder確認

```bash
aws configservice describe-configuration-recorders \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/09_config/01_configuration_recorders.json"
```

### 14.2 Recorder状態確認

```bash
aws configservice describe-configuration-recorder-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/09_config/02_configuration_recorder_status.json"
```

### 14.3 Delivery Channel確認

```bash
aws configservice describe-delivery-channels \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/09_config/03_delivery_channels.json"
```

監視観点:

AWS Config自体の変更監視では、CloudTrail上のAWS Config関連イベントをMetric FilterやAlarmで拾う必要がある。

代表イベント例:

```text
PutConfigurationRecorder
StopConfigurationRecorder
DeleteConfigurationRecorder
PutDeliveryChannel
DeleteDeliveryChannel
```

## 15. AWS Organizations現状調査

対象要件:

- 4.15

### 15.1 Organization確認

```bash
aws organizations describe-organization \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/10_organizations/01_organization.json"
```

権限がない場合は、組織管理アカウント側で確認が必要。

### 15.2 Organizations変更監視観点

代表イベント例:

```text
CreateAccount
CloseAccount
MoveAccount
CreateOrganizationalUnit
DeleteOrganizationalUnit
AttachPolicy
DetachPolicy
CreatePolicy
UpdatePolicy
DeletePolicy
EnablePolicyType
DisablePolicyType
InviteAccountToOrganization
RemoveAccountFromOrganization
```

注意:
Organizationsイベントは管理アカウントや委任管理アカウント側の確認が必要になる場合がある。

## 16. 要件4.1〜4.15の監視イベント対応表

現状のMetric Filter / Alarmが、以下のイベントを検知しているか確認する。

| 要件番号 | 監視対象 | 代表的なCloudTrail条件・イベント |
|---|---|---|
| 4.1 | 不正なAPI呼び出し | `errorCode = "*UnauthorizedOperation"`、`errorCode = "AccessDenied*"` |
| 4.2 | MFAなしコンソールログイン | `eventName = "ConsoleLogin"` かつ `additionalEventData.MFAUsed = "No"` |
| 4.3 | rootアカウント使用 | `userIdentity.type = "Root"` |
| 4.4 | IAMポリシー変更 | `PutGroupPolicy`, `PutRolePolicy`, `PutUserPolicy`, `CreatePolicy`, `DeletePolicy`, `AttachRolePolicy`, `DetachRolePolicy` 等 |
| 4.5 | CloudTrail設定変更 | `CreateTrail`, `UpdateTrail`, `DeleteTrail`, `StartLogging`, `StopLogging`, `PutEventSelectors` 等 |
| 4.6 | コンソール認証失敗 | `eventName = "ConsoleLogin"` かつ `responseElements.ConsoleLogin = "Failure"` |
| 4.7 | CMK無効化・削除予約 | `DisableKey`, `ScheduleKeyDeletion` |
| 4.8 | S3バケットポリシー変更 | `PutBucketPolicy`, `DeleteBucketPolicy` |
| 4.9 | AWS Config設定変更 | `PutConfigurationRecorder`, `StopConfigurationRecorder`, `DeleteConfigurationRecorder`, `PutDeliveryChannel`, `DeleteDeliveryChannel` |
| 4.10 | Security Group変更 | `AuthorizeSecurityGroupIngress`, `RevokeSecurityGroupIngress`, `AuthorizeSecurityGroupEgress`, `RevokeSecurityGroupEgress`, `CreateSecurityGroup`, `DeleteSecurityGroup` 等 |
| 4.11 | NACL変更 | `CreateNetworkAcl`, `DeleteNetworkAcl`, `CreateNetworkAclEntry`, `DeleteNetworkAclEntry`, `ReplaceNetworkAclEntry`, `ReplaceNetworkAclAssociation` |
| 4.12 | Network Gateway変更 | `CreateInternetGateway`, `DeleteInternetGateway`, `AttachInternetGateway`, `DetachInternetGateway`, `CreateCustomerGateway`, `DeleteCustomerGateway` 等 |
| 4.13 | Route Table変更 | `CreateRoute`, `DeleteRoute`, `ReplaceRoute`, `CreateRouteTable`, `DeleteRouteTable`, `AssociateRouteTable`, `DisassociateRouteTable`, `ReplaceRouteTableAssociation` |
| 4.14 | VPC変更 | `CreateVpc`, `DeleteVpc`, `ModifyVpcAttribute`, `AcceptVpcPeeringConnection`, `CreateVpcPeeringConnection`, `DeleteVpcPeeringConnection` 等 |
| 4.15 | AWS Organizations変更 | `AttachPolicy`, `DetachPolicy`, `CreateAccount`, `MoveAccount`, `CreatePolicy`, `UpdatePolicy`, `DeletePolicy` 等 |

注意:
上記は調査時の確認候補である。
実際のMetric Filter条件は、現場の既存設計書、監査要件、通知方針、ノイズ量に合わせて確定する。

## 17. Metric Filterの存在確認方法

### 17.1 特定イベント名が既存Filterに含まれるか確認

`describe-metric-filters` の結果を保存した後、ローカルで検索する。

```bash
grep -n \
  'PutBucketPolicy\|DeleteBucketPolicy\|StopLogging\|DisableKey\|ScheduleKeyDeletion' \
  "$EVIDENCE_ROOT/03_cloudwatch/05_metric_filters_cloudtrail_log_group.json"
```

読み方:

| 結果 | 読み方 |
|---|---|
| 該当行あり | 既存Filterが対象イベントを拾っている可能性あり。内容を精査する |
| 該当行なし | 既存Filterでは拾っていない可能性が高い |

注意:
grepはあくまで簡易確認である。
最終的にはFilter Pattern全体とAlarm紐付きを確認する。

### 17.2 Metric FilterとAlarmの紐付け確認

Metric Filterの `metricNamespace` と `metricName` を控える。

```bash
METRIC_NAMESPACE="<metric-namespace>"
METRIC_NAME="<metric-name>"
```

該当メトリクスを参照するAlarmを確認する。

```bash
aws cloudwatch describe-alarms-for-metric \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --no-cli-pager
```

## 18. CloudTrail Event Historyで過去イベント確認

Metric FilterやAlarmがなくても、CloudTrail Event Historyに過去イベントがあるか確認する。

### 18.1 S3バケットポリシー変更

```bash
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
  > "$EVIDENCE_ROOT/01_cloudtrail/06_lookup_put_bucket_policy.json"
```

### 18.2 CloudTrail設定変更

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$TRAIL_NAME" \
  --max-results 50 \
  --query 'Events[?EventName==`UpdateTrail` || EventName==`StopLogging` || EventName==`StartLogging` || EventName==`PutEventSelectors` || EventName==`DeleteTrail`].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    EventId:EventId
  }' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_ROOT/01_cloudtrail/07_lookup_cloudtrail_change_events.json"
```

注意:
`lookup-events` は連続実行でThrottlingになりやすい。
大量調査はCloudWatch Logs Insights、Athena、SIEM等の利用を検討する。

## 19. CloudWatch Logs Insightsで確認する場合

対象Log Groupと時間範囲を指定して、CloudTrailイベントを検索する。

```bash
START_TIME="<start-epoch-seconds>"
END_TIME="<end-epoch-seconds>"
```

S3バケットポリシー変更:

```bash
aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string 'fields @timestamp, eventName, userIdentity.arn, sourceIPAddress, requestParameters.bucketName, errorCode
| filter eventName in ["PutBucketPolicy", "DeleteBucketPolicy"]
| sort @timestamp desc
| limit 50' \
  --output json \
  --no-cli-pager
```

CloudTrail設定変更:

```bash
aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$CLOUDTRAIL_LOG_GROUP_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string 'fields @timestamp, eventName, userIdentity.arn, sourceIPAddress, errorCode
| filter eventSource = "cloudtrail.amazonaws.com"
| sort @timestamp desc
| limit 50' \
  --output json \
  --no-cli-pager
```

## 20. 現状整理表

調査後、以下の形式で整理する。

| 要件番号 | 現状 | 判定 | 不足内容 | 対応方針 | 備考 |
|---|---|---|---|---|---|
| A3 | 例: GuardDuty手順書なし | 不足 | 運用手順書がない | 手順書作成 | 既存WAF手順書は参考 |
| A4 | 例: 月次確認はあるが日次証跡なし | 要確認 | 日々の運用証跡が不足 | 運用記録様式確認 | A3と合わせて対応 |
| 3.4 | 例: CloudTrail S3 Logging無効 | 不足 | Server Access Loggingなし | 有効化設計 | 保存先バケット要確認 |
| 3.5 | 例: SSE-S3 | 不足 | SSE-KMS CMK未使用 | CMK設計 | Key Policy要確認 |
| 3.6 | 例: CMK未作成 | 3.5依存 | Rotation対象なし | 3.5対応後に確認 | |
| 3.7 | 例: OPER VPC無効 | 不足 | Flow Logsなし | 有効化設計 | 保存先確認 |
| 4.1〜4.15 | 例: Metric Filterなし | 不足 | 通知設定なし | 共通設計後に横展開 | |

判定区分:

| 判定 | 意味 |
|---|---|
| 対応済み | 既存設定で要件を満たす |
| 不足 | 設定追加または手順書作成が必要 |
| 要確認 | 設計書、運用手順、別アカウント等の確認が必要 |
| 対象外 | 利用サービスや環境条件により対象外。ただし理由を記録する |

## 21. リーダーへ確認する事項

調査結果と合わせて、以下を確認する。

| 確認事項 | 理由 |
|---|---|
| Prod / OPERのAWSアカウントIDと対象リージョン | 調査漏れ防止 |
| Organization Trailかアカウント個別Trailか | CloudTrail調査範囲に影響 |
| CloudTrailログ保存先S3の正式名 | 3.4、3.5の対象確定 |
| VPC一覧とProd / OPERの対応 | 3.7の対象確定 |
| 既存通知基盤 | 4.1〜4.15の通知先設計 |
| 既存Metric Filter / Alarmの設計書 | 重複作成防止 |
| GuardDuty運用手順書の有無 | A3 |
| GuardDuty確認履歴、月次報告、対応記録 | A4 |
| KMSキー管理方針 | 3.5、3.6、4.7 |
| 本番でテストイベントを発生させてよいか | テスト方式に影響 |
| 証跡の保存場所と命名規則 | 提出資料化に必要 |

## 22. 調査完了条件

以下が揃ったら、現状調査完了とする。

- 要件番号ごとの現状判定表
- CloudTrail一覧
- CloudTrailログ保存先S3のLogging / Encryption確認結果
- KMSキー利用有無とRotation確認結果
- VPC Flow Logs確認結果
- CloudWatch Logs連携確認結果
- Metric Filter一覧
- CloudWatch Alarm一覧
- SNS / EventBridge通知経路確認結果
- GuardDuty Detector / Finding / 運用状況確認結果
- AWS Config / Organizationsの確認結果
- 不足設定一覧
- パイロット作業候補
- リーダー確認事項

## 23. 次工程

現状調査後は、以下の順で進める。

```text
1. 現状調査結果をリーダーへ共有
2. 要件ごとに対応済み / 不足 / 要確認 / 対象外を合意
3. 4.8 S3バケットポリシー変更監視など、影響が小さい項目をパイロット対応
4. Metric Filter / Alarm / 通知 / 証跡取得の型を確定
5. 4.1〜4.15へ横展開
6. 3.4、3.5、3.7など設定変更系を設計・手順化
7. A3、A4の運用手順書と運用記録様式を作成
8. テスト、レビュー、リリース判定へ進む
```
