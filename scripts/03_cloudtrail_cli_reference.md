# 03 CloudTrail CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、AWS CloudTrailをAWS CLIで確認、作成、連携、検索するためのリファレンスである。

対象は、銀行系システムのように、AWS操作の監査証跡、設定変更履歴、MFAなし管理コンソールログイン検知、CloudWatch Logs連携、S3ログ保管が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- CloudTrailの基本概念
- Trailの確認
- TrailのS3保存設定
- Trailの作成と開始
- Event Selector / Advanced Event Selector確認
- S3 / Lambda Data Events設定
- CloudTrailイベント履歴検索
- CloudTrail Lake Event Data Store確認
- CloudTrail Lakeクエリ
- S3バケットポリシー設定
- CloudWatch Logs連携
- CloudWatch Logs上でのイベント検索
- CloudTrail変更作業の証跡取得
- よくあるエラーと確認ポイント

MFAなし管理コンソールログイン検知の詳細なMetric FilterやAlarm作成は、以下で別途扱う。

```text
06_mfa_console_login_detection.md
```

CloudWatch Logs、Metric Filter、Alarmの詳細は、以下で別途扱う。

```text
04_cloudwatch_cli_reference.md
```

## 2. 参照する共通リファレンス

AWS CLIの基本操作、証跡保存、差分確認、終了コード、BashとPowerShellの違いは、以下を参照する。

[00 共通 AWS CLI・証跡保存リファレンス](./00_common_aws_cli_reference.md)

S3バケットポリシーの確認、差分、切り戻しは、以下を参照する。

[02 S3 Bucket Policy CLIリファレンス](./02_s3_bucket_policy_cli_reference.md)

## 3. CloudTrailで見るもの

CloudTrailは、AWSアカウント内の操作履歴を記録するサービスである。

記録される代表例:

- AWS Management Consoleへのログイン
- AWS CLIやSDKによるAPI操作
- IAMユーザー作成
- IAM Role変更
- Security Group変更
- S3 Bucket Policy変更
- RDS設定変更
- Lambda関数変更
- CloudTrail自身の設定変更

CloudTrailは、単にログを保存するだけではなく、以下の用途で使う。

| 用途 | 内容 |
| :--- | :--- |
| 監査 | 誰が、いつ、何をしたか確認する |
| 変更追跡 | 設定変更の実行者、API、対象リソースを確認する |
| 影響調査 | 障害や設定差分の原因になった操作を探す |
| セキュリティ検知 | MFAなしログイン、Root利用、権限変更などを検知する |
| 証跡保管 | S3へ長期保存する |
| リアルタイム寄り監視 | CloudWatch Logsへ連携しMetric FilterやAlarmへつなげる |

## 4. CloudTrailの主な仕組み

| 仕組み | 役割 |
| :--- | :--- |
| Event History | 直近イベントをCloudTrailコンソールや `lookup-events` で確認する |
| Trail | イベントをS3バケットへ継続的に配信する |
| CloudWatch Logs連携 | TrailのイベントをCloudWatch Logsへ配信し、検索やMetric Filterに使う |
| Event Data Store | CloudTrail LakeでSQLクエリするためのイベント保管先 |
| Event Selector | Trailで記録するイベント種別を指定する |
| Advanced Event Selector | より細かくイベント種別、リソース、条件を指定する |
| Log File Validation | S3へ配信されたログファイルの整合性検証に使う |

## 5. イベント種別

CloudTrailイベントは大きく以下に分かれる。

| 種別 | 例 | 備考 |
| :--- | :--- | :--- |
| Management events | `ConsoleLogin`、`CreateUser`、`PutBucketPolicy`、`AuthorizeSecurityGroupIngress` | デフォルトで記録対象になりやすい |
| Data events | `GetObject`、`PutObject`、`DeleteObject`、Lambda Invoke | 対象リソースを指定して有効化する |
| Network activity events | VPC Endpoint経由のイベントなど | Advanced Event Selectorで扱う |
| Insights events | 異常なAPI呼び出し量など | 別途有効化が必要 |

注意:

- S3 Bucket Policy変更はManagement eventである
- S3オブジェクトの `GetObject` / `PutObject` / `DeleteObject` はData eventである
- Data eventsはログ量とコストが増えやすいため、対象バケットやPrefixを絞る

## 6. Trail / Event History / Event Data Storeの使い分け

| 機能 | 向いている用途 | 注意点 |
| :--- | :--- | :--- |
| Event History / `lookup-events` | 直近90日程度の管理イベント確認 | Data eventsの詳細分析には不向き |
| Trail + S3 | 長期保存、監査証跡、Athena連携 | S3バケットポリシー、暗号化、保管設計が必要 |
| Trail + CloudWatch Logs | Metric Filter、Alarm、ログ検索 | Log Group、IAM Role、ログ量コストが必要 |
| CloudTrail Lake Event Data Store | SQLによる詳細分析 | 利用可否、保持期間、課金に注意 |

重要:

```text
CloudTrail Lakeは、2026年5月31日以降、新規のお客様には開放されない旨の公式注記がある。
既存のお客様は通常どおり利用可能とされている。
```

そのため、案件でEvent Data Storeを扱う場合は、現場アカウントで既にCloudTrail Lakeを利用しているか確認する。

## 7. 作業前の共通変数

### 7.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

TRAIL_NAME="nobu-iac-lab-trail"
TRAIL_BUCKET="nobu-iac-lab-cloudtrail-${ACCOUNT_ID}"
TRAIL_PREFIX="cloudtrail"
TRAIL_ARN="arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME}"

# S3 Data eventsを記録する場合の調査対象バケット。
# Trailログ保存先バケットとは分けて考える。
S3_DATA_EVENT_BUCKET="nobu-terraform-iac-lab-upload"

LOG_GROUP_NAME="/aws/cloudtrail/nobu-iac-lab"
CLOUDTRAIL_CW_ROLE_NAME="CloudTrail_CloudWatchLogs_Role"
EDS_NAME="nobu-iac-lab-eds"
```

注意:

- `TRAIL_BUCKET` はグローバル一意である必要がある
- 実案件ではバケット名、Trail名、Log Group名は設計書に合わせる
- Organization Trailの場合、管理アカウント、委任管理者、Organizations IDを確認する

### 7.2 証跡ディレクトリ

```bash
WORK_NAME="cloudtrail_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 7.3 Caller Identity保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

## 8. CloudTrail確認のクイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | Trail一覧 | 想定Trailが存在 | `describe-trails`、`list-trails` |
| 2 | Multi-Region | 有効 | `describe-trails` |
| 3 | Logging状態 | `IsLogging=true` | `get-trail-status` |
| 4 | S3保存先 | 監査ログ用Bucket | `describe-trails` |
| 5 | Log File Validation | 有効 | `describe-trails` |
| 6 | Event Selector | Management events記録 | `get-event-selectors` |
| 7 | Data Events | 必要バケットだけ | `get-event-selectors` |
| 8 | CloudWatch Logs連携 | 必要に応じて有効 | `describe-trails`、`logs describe-log-groups` |
| 9 | Event History検索 | 直近変更を確認 | `lookup-events` |
| 10 | Event Data Store | 既存利用があるか | `list-event-data-stores` |
| 11 | CloudTrail自身の変更履歴 | 想定外変更なし | `lookup-events` |

## 9. Trail一覧確認

### 9.1 describe-trails

CloudTrail Trailの一覧を確認する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[*].{Name:Name,TrailARN:TrailARN,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,OrgTrail:IsOrganizationTrail,S3Bucket:S3BucketName,LogValidation:LogFileValidationEnabled,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn}' \
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

- 監査用Trailが存在する
- `IsMultiRegionTrail=true` である
- `HomeRegion` が想定どおりである
- S3保存先が監査ログ用バケットである
- `LogFileValidationEnabled=true` である
- CloudWatch Logs連携が必要な場合、Log Group ARNが設定されている

### 9.2 list-trails

Trail ARNを簡潔に確認する。

```bash
aws cloudtrail list-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Trails[*].{Name:Name,TrailARN:TrailARN,HomeRegion:HomeRegion}' \
  --output table
```

## 10. Trail詳細確認

### 10.1 get-trail

Trail名またはTrail ARNを指定して詳細を確認する。

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output table
```

証跡保存:

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/02_get_trail.json"
```

確認ポイント:

- `Name`
- `TrailARN`
- `HomeRegion`
- `S3BucketName`
- `S3KeyPrefix`
- `IsMultiRegionTrail`
- `LogFileValidationEnabled`
- `CloudWatchLogsLogGroupArn`
- `CloudWatchLogsRoleArn`
- `KmsKeyId`

## 11. Trail Logging状態確認

### 11.1 get-trail-status

Trailが記録中か確認する。

```bash
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
  > "$EVIDENCE_DIR/before/03_get_trail_status.json"
```

確認ポイント:

- `IsLogging=true`
- `LatestDeliveryError` が空、または問題ない
- `LatestNotificationError` が空、または問題ない
- `LatestCloudWatchLogsDeliveryError` が空、または問題ない
- `LatestDeliveryTime` が古すぎない
- `StopLoggingTime` がない

注意:

- S3バケットポリシーやKMS Key Policyが不適切だとDelivery Errorになる
- 誤設定のTrailは再配信試行により課金が続く可能性があるため、放置しない

## 12. Event Selector確認

### 12.1 get-event-selectors

Trailがどのイベントを記録しているか確認する。

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/04_get_event_selectors.json"
```

確認:

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output table
```

確認ポイント:

- Management eventsを記録している
- `ReadWriteType` が `All` か
- `IncludeManagementEvents=true` か
- Data eventsが必要な場合、対象リソースが絞られている
- `EventSelectors` と `AdvancedEventSelectors` のどちらを使っているか

注意:

- `EventSelectors` と `AdvancedEventSelectors` は同時に使えない
- `put-event-selectors` で片方を設定すると、既存のもう片方を上書きする可能性がある
- 設定変更前に必ず変更前Selectorを保存する

## 13. Management events設定

### 13.1 管理イベントをすべて記録する

```bash
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --event-selectors '[
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": true
    }
  ]'
```

影響:

- 管理イベントを記録する
- S3オブジェクト操作やLambda InvokeなどのData eventsは記録しない
- 多くの設定変更調査はManagement eventsで確認できる

## 14. S3 Data events設定

S3オブジェクト操作を記録したい場合は、Data eventsを有効化する。

### 14.1 特定バケットのS3 Object Data eventsを記録する

```bash
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --event-selectors "[
    {
      \"ReadWriteType\": \"All\",
      \"IncludeManagementEvents\": true,
      \"DataResources\": [
        {
          \"Type\": \"AWS::S3::Object\",
          \"Values\": [\"arn:aws:s3:::$S3_DATA_EVENT_BUCKET/\"]
        }
      ]
    }
  ]"
```

注意:

- `Values` には対象バケットやPrefixのARNを指定する
- S3 Data eventsはログ量とコストが増えやすい
- 本番では全S3バケットではなく、対象バケットや重要Prefixへ絞る
- S3 Bucket Policy変更自体はManagement eventなので、Data eventsなしでも確認できる

### 14.2 Advanced Event SelectorでS3 Data eventsを絞る

```bash
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --advanced-event-selectors "[
    {
      \"Name\": \"Log S3 write data events for selected bucket\",
      \"FieldSelectors\": [
        {\"Field\": \"eventCategory\", \"Equals\": [\"Data\"]},
        {\"Field\": \"resources.type\", \"Equals\": [\"AWS::S3::Object\"]},
        {\"Field\": \"resources.ARN\", \"StartsWith\": [\"arn:aws:s3:::$S3_DATA_EVENT_BUCKET/\"]},
        {\"Field\": \"eventName\", \"Equals\": [\"PutObject\", \"DeleteObject\"]}
      ]
    }
  ]"
```

確認ポイント:

- Data eventsが本当に必要か
- 読み取りまで必要か、書き込みだけでよいか
- 対象バケットやPrefixを絞っているか
- 設定変更後に想定イベントが記録されるか

## 15. Lambda Data events設定

Lambda Invokeなどを記録したい場合は、Lambda Data eventsを有効化する。

```bash
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --event-selectors '[
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": true,
      "DataResources": [
        {
          "Type": "AWS::Lambda::Function",
          "Values": ["arn:aws:lambda"]
        }
      ]
    }
  ]'
```

注意:

- Lambda Data eventsもログ量が増える
- 重要関数だけに絞る設計を検討する
- 管理イベントの `UpdateFunctionCode` や `UpdateFunctionConfiguration` とは別である

## 16. Trail用S3バケット確認

### 16.1 S3保存先確認

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME" \
  --query 'trailList[*].{Name:Name,S3Bucket:S3BucketName,S3Prefix:S3KeyPrefix}' \
  --output table
```

### 16.2 S3バケット存在確認

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$ACCOUNT_ID"
```

### 16.3 S3バケットポリシー確認

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$ACCOUNT_ID" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/before/05_cloudtrail_bucket_policy.json"
```

確認ポイント:

- `cloudtrail.amazonaws.com` に `s3:GetBucketAcl` が許可されている
- `cloudtrail.amazonaws.com` に `s3:PutObject` が許可されている
- `s3:x-amz-acl = bucket-owner-full-control` 条件がある
- `aws:SourceArn` で対象Trail ARNに制限している
- Log PrefixとBucket PolicyのResourceが一致している

## 17. Trail用S3バケット作成の例

実案件では既存ログバケットを使うことが多い。

ラボや検証で作る場合の例を示す。

### 17.1 バケット作成

```bash
aws s3api create-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --create-bucket-configuration LocationConstraint="$REGION"
```

### 17.2 Public Access Block

```bash
aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 17.3 Object Ownership

```bash
aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --ownership-controls '{
    "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
    ]
  }'
```

### 17.4 暗号化

```bash
aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

### 17.5 Versioning

```bash
aws s3api put-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --versioning-configuration Status=Enabled
```

確認ポイント:

- CloudTrailログ用バケットは削除耐性と監査性が重要
- VersioningやLifecycleは要件に合わせる
- SSE-KMSを使う場合はKMS Key Policyも確認する

## 18. CloudTrail用S3 Bucket Policy

CloudTrailがS3へログを書き込むため、バケットポリシーが必要になる。

### 18.1 Policyファイル作成

```bash
cat > "$EVIDENCE_DIR/change/cloudtrail-bucket-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::$TRAIL_BUCKET",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "$TRAIL_ARN"
        }
      }
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$TRAIL_BUCKET/$TRAIL_PREFIX/AWSLogs/$ACCOUNT_ID/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "aws:SourceArn": "$TRAIL_ARN"
        }
      }
    }
  ]
}
EOF
```

### 18.2 Policy適用

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --policy "file://$EVIDENCE_DIR/change/cloudtrail-bucket-policy.json"
```

注意:

- 既存Bucket Policyがある場合は、既存Statementを消さずにCloudTrail用Statementを追加する
- `aws:SourceArn` で対象Trailに制限する
- Log Prefixを指定した場合、`Resource` のPrefixとTrail設定を一致させる
- Organization TrailではOrganizations IDや管理アカウントのARNを考慮する

## 19. Trail作成

### 19.1 create-trail

```bash
aws cloudtrail create-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --s3-bucket-name "$TRAIL_BUCKET" \
  --s3-key-prefix "$TRAIL_PREFIX" \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --tags-list Key=Name,Value="$TRAIL_NAME" Key=Project,Value=nobu-iac-lab Key=Environment,Value=learning \
  --output json \
  > "$EVIDENCE_DIR/change/06_create_trail.json"
```

確認ポイント:

- `IsMultiRegionTrail=true`
- `LogFileValidationEnabled=true`
- `S3BucketName` が想定バケット
- `S3KeyPrefix` がBucket Policyと一致している

注意:

- コンソールで作るTrailは基本的にMulti-Region Trailになる
- CLIではSingle-Region Trailも作れるため、意図を確認する
- Trailを作成しただけではLoggingが開始されない場合がある

### 19.2 start-logging

```bash
aws cloudtrail start-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME"
```

確認:

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output table
```

期待値:

```text
IsLogging: true
```

## 20. Trail更新

### 20.1 update-trail

Trail設定を変更する。

```bash
aws cloudtrail update-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --s3-bucket-name "$TRAIL_BUCKET" \
  --s3-key-prefix "$TRAIL_PREFIX"
```

注意:

- TrailのHome Regionで実行する
- S3保存先やPrefixを変更する場合、S3 Bucket Policy側も一致させる
- 設定変更前に `describe-trails`、`get-trail-status`、`get-event-selectors` を保存する

## 21. CloudTrailログファイル確認

CloudTrailログは、S3に以下のような構造で保存される。

```text
s3://<bucket>/<prefix>/AWSLogs/<account-id>/CloudTrail/<region>/<yyyy>/<mm>/<dd>/
```

例:

```bash
aws s3 ls \
  "s3://$TRAIL_BUCKET/$TRAIL_PREFIX/AWSLogs/$ACCOUNT_ID/CloudTrail/$REGION/" \
  --profile "$PROFILE" \
  --recursive \
  --summarize
```

確認ポイント:

- 当日のログが配信されている
- 複数リージョン分が保存されている
- Digestファイルが必要に応じて保存されている
- ログバケットが公開されていない
- ログバケットの暗号化、Versioning、Lifecycleが要件どおり

注意:

- CloudTrailログにはIAM ARN、IPアドレス、操作内容などが含まれる
- ログファイルの証跡化や持ち出しは現場ルールに従う

## 22. CloudTrailイベント検索

### 22.1 lookup-eventsの基本

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --max-results 10 \
  --output table
```

確認ポイント:

- 直近の管理イベントを確認できる
- 1回の検索で指定できるLookup Attributeは1つ
- 直近90日程度のイベント確認に使う
- 検索リクエスト数には制限があるため連打しない

### 22.2 イベント名で検索

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --max-results 10 \
  --query 'Events[*].{EventTime:EventTime,Username:Username,EventName:EventName,Resources:Resources}' \
  --output table
```

### 22.3 リソース名で検索

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$TRAIL_NAME" \
  --max-results 10 \
  --output table
```

### 22.4 時刻範囲を指定する

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --start-time "2026-06-04T00:00:00Z" \
  --end-time "2026-06-04T23:59:59Z" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/after/07_lookup_authorize_sg_ingress.json"
```

注意:

- CloudTrailのイベント時刻はUTCで扱われることが多い
- 手順書にはJSTとUTCの対応を明記すると説明しやすい

### 22.5 管理コンソールログインを検索する

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/after/08_console_login_events.json"
```

確認ポイント:

- `eventSource` が `signin.amazonaws.com`
- `eventName` が `ConsoleLogin`
- `responseElements.ConsoleLogin` が `Success` または `Failure`
- `additionalEventData.MFAUsed` が `Yes` または `No`
- `userIdentity.sessionContext.attributes.mfaAuthenticated` が `true` または `false`

MFAなしログイン検知のMetric Filter化は、別リファレンスで扱う。

## 23. 代表的なEventName

| 用途 | EventName |
| :--- | :--- |
| 管理コンソールログイン | `ConsoleLogin` |
| S3 Bucket Policy変更 | `PutBucketPolicy` |
| S3 Public Access Block変更 | `PutBucketPublicAccessBlock` |
| Security Group Ingress追加 | `AuthorizeSecurityGroupIngress` |
| Security Group Ingress削除 | `RevokeSecurityGroupIngress` |
| Route Table変更 | `CreateRoute`、`ReplaceRoute`、`DeleteRoute` |
| IAMユーザー作成 | `CreateUser` |
| IAMポリシー付与 | `AttachUserPolicy`、`AttachRolePolicy`、`PutRolePolicy` |
| Access Key作成 | `CreateAccessKey` |
| CloudTrail停止 | `StopLogging` |
| CloudTrail削除 | `DeleteTrail` |
| RDS変更 | `ModifyDBInstance` |
| Lambda変更 | `UpdateFunctionCode`、`UpdateFunctionConfiguration` |

## 24. CloudTrail自身の変更確認

CloudTrail設定の変更は重要な監査対象である。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=cloudtrail.amazonaws.com \
  --max-results 50 \
  --query 'Events[*].{EventTime:EventTime,Username:Username,EventName:EventName,Resources:Resources}' \
  --output table
```

確認ポイント:

- `StopLogging`
- `StartLogging`
- `CreateTrail`
- `UpdateTrail`
- `DeleteTrail`
- `PutEventSelectors`
- `CreateEventDataStore`
- `UpdateEventDataStore`
- `DeleteEventDataStore`

想定外の `StopLogging` や `DeleteTrail` は重要インシデント候補である。

## 25. CloudWatch Logs連携

CloudTrailイベントをCloudWatch Logsへ送ると、以下ができる。

- CloudWatch Logsでイベント検索する
- Metric Filterを作る
- CloudWatch Alarmを作る
- MFAなしConsoleLoginを検知する
- IAM権限変更やSecurity Group変更を検知する

## 26. CloudWatch Logs Log Group作成

```bash
aws logs create-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME"
```

Retention設定:

```bash
aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days 90
```

Log Group ARN取得:

```bash
LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].logGroupArn | [0]" \
  --output text)

echo "$LOG_GROUP_ARN"
```

確認ポイント:

- Log GroupがTrailと同じアカウントにある
- Retentionが要件どおりである
- 必要ならKMS暗号化を設定する

## 27. CloudTrailがCloudWatch Logsへ書き込むIAM Role

### 27.1 Trust Policy作成

```bash
cat > "$EVIDENCE_DIR/change/cloudtrail-cwlogs-trust-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### 27.2 IAM Role作成

```bash
aws iam create-role \
  --profile "$PROFILE" \
  --role-name "$CLOUDTRAIL_CW_ROLE_NAME" \
  --assume-role-policy-document "file://$EVIDENCE_DIR/change/cloudtrail-cwlogs-trust-policy.json"
```

Role ARN取得:

```bash
CLOUDTRAIL_CW_ROLE_ARN=$(aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$CLOUDTRAIL_CW_ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)

echo "$CLOUDTRAIL_CW_ROLE_ARN"
```

### 27.3 権限Policy作成

CloudTrailがCloudWatch Logsへログストリーム作成とログ投入を行うためのPolicyを作る。

```bash
cat > "$EVIDENCE_DIR/change/cloudtrail-cwlogs-role-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "arn:aws:logs:$REGION:$ACCOUNT_ID:log-group:$LOG_GROUP_NAME:log-stream:$ACCOUNT_ID*_CloudTrail_$REGION*"
      ]
    },
    {
      "Sid": "AWSCloudTrailPutLogEvents",
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:$REGION:$ACCOUNT_ID:log-group:$LOG_GROUP_NAME:log-stream:$ACCOUNT_ID*_CloudTrail_$REGION*"
      ]
    }
  ]
}
EOF
```

Policy付与:

```bash
aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$CLOUDTRAIL_CW_ROLE_NAME" \
  --policy-name CloudTrailCloudWatchLogsDeliveryPolicy \
  --policy-document "file://$EVIDENCE_DIR/change/cloudtrail-cwlogs-role-policy.json"
```

注意:

- Organization Trailではログストリーム名や対象アカウントが変わるため、Policyを調整する
- 実案件ではAWS公式例、既存Role、現場標準に合わせる
- `Resource: "*"` に広げない

## 28. TrailをCloudWatch Logsへ連携する

### 28.1 update-trail

```bash
aws cloudtrail update-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --cloud-watch-logs-log-group-arn "$LOG_GROUP_ARN" \
  --cloud-watch-logs-role-arn "$CLOUDTRAIL_CW_ROLE_ARN"
```

確認:

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{Name:Name,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output table
```

注意:

- TrailのHome Regionで実行する
- CloudWatch Logs連携はTrailが記録するイベントだけを送る
- CloudTrailからCloudWatch Logsへの配送は数分遅れる場合がある
- CloudWatch Logsに送る場合でも、S3保存先はTrailの基本保存先として重要である

### 28.2 連携を停止する場合

```bash
aws cloudtrail update-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --cloud-watch-logs-log-group-arn "" \
  --cloud-watch-logs-role-arn ""
```

注意:

- 監視やAlarmに影響するため、停止は別承認にする
- 停止前後の証跡を保存する

## 29. CloudWatch Logs側でCloudTrailイベントを確認する

### 29.1 Log Stream確認

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[*].{Stream:logStreamName,LastEventTime:lastEventTimestamp}' \
  --output table
```

### 29.2 ConsoleLoginを検索する

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/09_cwlogs_console_login.json"
```

### 29.3 MFAなしConsoleLoginを検索する

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed = "No") }' \
  --max-items 20 \
  --output json \
  > "$EVIDENCE_DIR/after/10_cwlogs_console_login_without_mfa.json"
```

確認ポイント:

- `ConsoleLogin`
- `responseElements.ConsoleLogin`
- `additionalEventData.MFAUsed`
- `sourceIPAddress`
- `userIdentity`
- `eventTime`

Metric FilterとAlarm化は、CloudWatchリファレンスとMFAなしログイン検知リファレンスで扱う。

## 30. Event Data Store確認

CloudTrail Lake Event Data Storeは、SQLでCloudTrailイベントを分析するための保管先である。

重要:

```text
2026年5月31日以降、CloudTrail Lakeは新規のお客様には開放されない旨の公式注記がある。
既存利用中の環境では通常どおり利用可能とされている。
```

実案件では、まず利用可否を確認する。

### 30.1 list-event-data-stores

```bash
aws cloudtrail list-event-data-stores \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'EventDataStores[*].{Name:Name,Arn:EventDataStoreArn,Status:Status,Retention:RetentionPeriod,TerminationProtection:TerminationProtectionEnabled}' \
  --output table
```

証跡保存:

```bash
aws cloudtrail list-event-data-stores \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/06_list_event_data_stores.json"
```

### 30.2 get-event-data-store

```bash
EVENT_DATA_STORE_ARN="<event-data-store-arn>"

aws cloudtrail get-event-data-store \
  --profile "$PROFILE" \
  --region "$REGION" \
  --event-data-store "$EVENT_DATA_STORE_ARN" \
  --output json \
  > "$EVIDENCE_DIR/before/07_get_event_data_store.json"
```

確認ポイント:

- `Status` が `ENABLED`
- `RetentionPeriod`
- `TerminationProtectionEnabled`
- `MultiRegionEnabled`
- `OrganizationEnabled`
- `AdvancedEventSelectors`
- KMS利用有無

## 31. Event Data Store作成

既存利用可能な環境で、検証用にEvent Data Storeを作成する例である。

### 31.1 Management events用Event Data Store

```bash
aws cloudtrail create-event-data-store \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$EDS_NAME" \
  --retention-period 90 \
  --advanced-event-selectors '[
    {
      "Name": "Management events",
      "FieldSelectors": [
        {
          "Field": "eventCategory",
          "Equals": ["Management"]
        }
      ]
    }
  ]' \
  --output json \
  > "$EVIDENCE_DIR/change/08_create_event_data_store.json"
```

注意:

- CloudTrail Lake利用可否を確認してから実行する
- Event Data Storeは課金対象である
- Retention期間は要件とコストに合わせる
- 新規顧客利用制限の公式注記に注意する

### 31.2 S3 Data events用Event Data Store

```bash
aws cloudtrail create-event-data-store \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "${EDS_NAME}-s3-data" \
  --retention-period 90 \
  --advanced-event-selectors "[
    {
      \"Name\": \"S3 data events for selected bucket\",
      \"FieldSelectors\": [
        {\"Field\": \"eventCategory\", \"Equals\": [\"Data\"]},
        {\"Field\": \"resources.type\", \"Equals\": [\"AWS::S3::Object\"]},
        {\"Field\": \"resources.ARN\", \"StartsWith\": [\"arn:aws:s3:::$S3_DATA_EVENT_BUCKET/\"]}
      ]
    }
  ]"
```

## 32. CloudTrail Lakeクエリ

### 32.1 Event Data Store ID取得

```bash
EDS_ID=$(aws cloudtrail list-event-data-stores \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "EventDataStores[?Name=='$EDS_NAME'].EventDataStoreArn | [0]" \
  --output text | awk -F/ '{print $2}')

echo "$EDS_ID"
```

注意:

- CloudTrail Lake SQLでは、Event Data Store IDを `FROM` に指定する
- 無制限な `SELECT *` はコスト増につながるため、時間条件を必ず付ける

### 32.2 ConsoleLoginを検索する

```bash
QUERY_ID=$(aws cloudtrail start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-statement "SELECT eventTime, eventName, userIdentity.arn, sourceIPAddress, additionalEventData FROM $EDS_ID WHERE eventName = 'ConsoleLogin' AND eventTime >= timestamp '2026-06-04 00:00:00' AND eventTime <= timestamp '2026-06-04 23:59:59' ORDER BY eventTime DESC" \
  --query 'QueryId' \
  --output text)

echo "$QUERY_ID"
```

### 32.3 クエリ結果取得

```bash
aws cloudtrail get-query-results \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-id "$QUERY_ID" \
  --output json \
  > "$EVIDENCE_DIR/after/11_cloudtrail_lake_query_results.json"
```

確認ポイント:

- `QueryStatus` が `FINISHED`
- 時間条件が適切
- 対象EventNameが一致
- MFAなしログイン調査では `additionalEventData` や `userIdentity` を確認する

## 33. CloudTrail Lakeクエリ例

### 33.1 S3 Bucket Policy変更

```sql
SELECT eventTime, eventName, userIdentity.arn, sourceIPAddress, requestParameters
FROM <event-data-store-id>
WHERE eventName = 'PutBucketPolicy'
  AND eventTime >= timestamp '2026-06-04 00:00:00'
  AND eventTime <= timestamp '2026-06-04 23:59:59'
ORDER BY eventTime DESC
```

### 33.2 Security Group変更

```sql
SELECT eventTime, eventName, userIdentity.arn, sourceIPAddress, requestParameters
FROM <event-data-store-id>
WHERE eventName IN ('AuthorizeSecurityGroupIngress', 'RevokeSecurityGroupIngress')
  AND eventTime >= timestamp '2026-06-04 00:00:00'
  AND eventTime <= timestamp '2026-06-04 23:59:59'
ORDER BY eventTime DESC
```

### 33.3 IAM権限変更

```sql
SELECT eventTime, eventName, userIdentity.arn, sourceIPAddress, requestParameters
FROM <event-data-store-id>
WHERE eventName IN ('AttachUserPolicy', 'AttachRolePolicy', 'PutUserPolicy', 'PutRolePolicy')
  AND eventTime >= timestamp '2026-06-04 00:00:00'
  AND eventTime <= timestamp '2026-06-04 23:59:59'
ORDER BY eventTime DESC
```

## 34. Trail変更の切り戻し

CloudTrailの設定変更は監査へ影響するため、切り戻しも慎重に行う。

### 34.1 Event Selector切り戻し

変更前に保存したSelectorを元に戻す。

```bash
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --cli-input-json "file://$EVIDENCE_DIR/before/04_get_event_selectors.json"
```

注意:

- `get-event-selectors` の出力JSONをそのまま `put-event-selectors --cli-input-json` に使えない場合がある
- その場合は、`TrailARN` など不要項目を除き、`EventSelectors` または `AdvancedEventSelectors` を手順用JSONとして整形する

### 34.2 CloudWatch Logs連携解除

```bash
aws cloudtrail update-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --cloud-watch-logs-log-group-arn "" \
  --cloud-watch-logs-role-arn ""
```

注意:

- Metric FilterやAlarmに影響する
- 切り戻し理由と影響範囲を明記する

### 34.3 stop-loggingは原則使わない

```bash
aws cloudtrail stop-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME"
```

注意:

- 監査ログ取得が停止する
- 原則として本番では単独判断で実行しない
- 実行する場合は、承認、作業時間、切り戻し、代替証跡が必要

## 35. よくあるエラーと確認ポイント

### 35.1 S3DeliveryError

確認ポイント:

- Trail用S3バケットが存在するか
- S3 Bucket PolicyにCloudTrailの `GetBucketAcl` と `PutObject` 許可があるか
- `aws:SourceArn` が正しいか
- PrefixがTrail設定とBucket Policyで一致しているか
- KMS Key PolicyでCloudTrailが許可されているか

### 35.2 CloudWatchLogsDeliveryError

確認ポイント:

- Log Groupが存在するか
- CloudWatch Logs Role ARNが正しいか
- Trust Policyで `cloudtrail.amazonaws.com` がAssumeRoleできるか
- Role Policyに `logs:CreateLogStream` と `logs:PutLogEvents` があるか
- Resource ARNがLog Group / Log Streamに一致しているか

### 35.3 InvalidHomeRegionException

確認ポイント:

- TrailのHome Regionで `update-trail` しているか
- Multi-Region Trailを別リージョンのShadow Trailとして見ていないか

### 35.4 lookup-eventsで見つからない

確認ポイント:

- 検索リージョンが正しいか
- イベント発生から数分待ったか
- 90日を超えていないか
- EventNameが正しいか
- Data eventsは有効化されているか
- Lookup Attributeは1つだけ指定しているか

### 35.5 CloudTrail Lakeクエリが高コストになりそう

確認ポイント:

- `eventTime` 条件を付けているか
- `SELECT *` を避けているか
- 必要な列だけ指定しているか
- 対象EventNameやEventSourceで絞っているか
- Event Data Storeの保持期間が長すぎないか

## 36. 作業手順書に書く項目

CloudTrail関連の作業手順書には、以下を含める。

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | Trail確認、CloudWatch Logs連携、Data events追加など |
| 対象 | Account、Region、Trail名、Log Group名 |
| 変更前状態 | describe-trails、get-trail-status、get-event-selectors |
| 変更内容 | create-trail、update-trail、put-event-selectorsなど |
| 影響範囲 | 監査ログ、CloudWatch Logs、Alarm、コスト |
| 事前確認 | S3バケット、Bucket Policy、IAM Role、KMS |
| 変更後確認 | Logging状態、Delivery Error、ログ配送 |
| 検知確認 | ConsoleLoginなどのイベント検索 |
| 切り戻し | 更新前設定へ戻す、CloudWatch Logs連携解除など |
| 証跡 | CLI JSON、CloudTrailイベント、スクリーンショット |

## 37. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm>

Trail:
  <trail-name>

Home Region:
  <region>

Multi-Region:
  true / false

IsLogging:
  true / false

S3 Bucket:
  <bucket-name>

Log File Validation:
  enabled / disabled

Event Selectors:
  Management: 有効 / 無効
  S3 Data: 有効 / 無効 / 対象外
  Lambda Data: 有効 / 無効 / 対象外

CloudWatch Logs:
  連携あり / 連携なし

Event Data Store:
  あり / なし / 利用不可

Delivery Error:
  なし / あり

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 38. Teams報告例

### 38.1 確認完了

```text
CloudTrailの設定を確認しました。
Trail <trail-name> はMulti-RegionでLogging有効、S3保存先も設定済みです。
Management eventsは記録対象で、Delivery Errorは確認されませんでした。
CloudWatch Logs連携は <あり/なし> です。
```

### 38.2 CloudWatch Logs連携作業前

```text
CloudTrailのイベントをCloudWatch Logsへ連携する作業を実施します。
目的は、ConsoleLoginなどのCloudTrailイベントをCloudWatch Logs上で検索し、
後続のMetric Filter / AlarmによるMFAなしログイン検知へつなげることです。
変更前にTrail設定、Event Selector、S3保存先、IAM Role設定を証跡取得します。
```

### 38.3 異常時

```text
CloudTrail設定確認でDelivery Errorを確認しました。
現時点では追加変更を行わず、S3 Bucket Policy、KMS Key Policy、
CloudWatch Logs Roleの権限を確認します。
監査ログ配送に影響する可能性があるため、状況を整理して共有します。
```

## 39. 公式ドキュメント

- [create-trail - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/create-trail.html)
- [Using the create-trail command to create a trail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-create-and-update-a-trail-by-using-the-aws-cli-create-trail.html)
- [lookup-events - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/lookup-events.html)
- [put-event-selectors - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/put-event-selectors.html)
- [Amazon S3 bucket policy for CloudTrail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html)
- [Sending events to CloudWatch Logs](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html)
- [Monitoring CloudTrail Log Files with Amazon CloudWatch Logs](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/monitor-cloudtrail-log-files-with-cloudwatch-logs.html)
- [Role policy document for CloudTrail to use CloudWatch Logs for monitoring](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cw_role_policy.html)
- [CloudTrail Lake availability change](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-lake-service-availability-change.html)
- [Create, update, and manage event data stores with the AWS CLI](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/lake-eds-cli.html)
- [CloudTrail Lake queries](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-lake-queries.html)
- [start-query - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/start-query.html)
- [get-query-results - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudtrail/get-query-results.html)
