# 要件3番台 ログ保全・KMS・VPC Flow Logs 現状調査手順書

作成日: 2026-07-10

この手順書は、要件3.4〜3.7について、設定変更前に現状調査を行うための手順書である。

最初に共有された評価シート由来のテキスト情報を正とし、要件3番台は「CloudTrailログ保存先S3のログ保全」「CloudTrailログのカスタマー管理KMSキー暗号化」「カスタマー管理KMSキーのローテーション」「VPC Flow Logs有効化」を確認する。
公開リポジトリで扱うことを想定し、顧客名、案件名、会社名、具体的な環境名、AWSアカウントID、S3バケット名、KMSキーID、VPC ID、個人名、内部資料の正式名称は記載しない。

## 1. 要件整理

3番台は、4番台のようなアラート監視ではなく、ログを残す、暗号化する、鍵を管理する、通信ログを取る、という基盤設定の確認である。

特に中心になるのは、3.5と3.6のKMS/CMKである。

| 要件番号 | 確認項目 | 主な確認対象 |
|---|---|---|
| 3.4 | CloudTrailログ保存先S3のServer Access Loggingが有効であること | CloudTrailログ保存先S3、Server Access Logging、ログ保存先 |
| 3.5 | CloudTrailログがカスタマー管理KMSキーで暗号化されていること | CloudTrail `KmsKeyId`、KMS Key、Key Policy、S3暗号化 |
| 3.6 | カスタマー管理KMSキーのローテーションが有効であること | KMS Key Rotation |
| 3.7 | すべてのVPCでVPC Flow Logsが有効であること | VPC、Flow Logs、保存先、Traffic type |

## 2. 調査方針

以下の順で確認する。

```text
対象アカウント・リージョンを確認する
  ↓
CloudTrail Trailを確認する
  ↓
CloudTrailログ保存先S3を特定する
  ↓
3.4 Server Access Loggingを確認する
  ↓
3.5 CloudTrailのKmsKeyIdとS3暗号化を確認する
  ↓
3.6 KMSキーのRotationを確認する
  ↓
3.7 全VPCのFlow Logs有効化状況を確認する
  ↓
要件ごとに「対応済み / 不足 / 要確認 / 対象外」を整理する
```

注意:

- 本手順は現状調査であり、設定変更は行わない。
- KMS Key Policy、CloudTrail暗号化、VPC Flow Logs有効化は影響が大きいため、承認なしに変更しない。
- CloudTrailがOrganization Trailの場合、管理アカウント側で確認が必要なことがある。
- 3.5の確認では、S3バケットのデフォルト暗号化だけでなく、CloudTrail Trailの `KmsKeyId` を確認する。

## 3. 必要なドキュメント類

作業前に以下の資料の所在と最新版を確認する。

| ドキュメント | 必要な理由 | 確認観点 |
|---|---|---|
| AWSアカウント一覧 | 対象アカウント漏れを防ぐため | 本番、運用、開発、検証、管理アカウント |
| 対象リージョン一覧 | CloudTrail、KMS、VPC Flow Logsの確認先を決めるため | 対象リージョン、除外リージョン |
| CloudTrail設計書 | Trail構成とログ保存先を確認するため | Trail名、Home Region、Multi-Region、Organization Trail |
| CloudTrailログ保存先S3設計書 | 3.4、3.5の対象を確認するため | S3バケット、Prefix、Server Access Logging保存先 |
| S3ログ保存設計書 | Server Access Logging保存先を確認するため | ログ保存先、Prefix、ライフサイクル、保持期間 |
| KMS設計書 | 3.5、3.6の鍵設計を確認するため | 既存CMK、新規CMK、Key Policy、管理者、利用者 |
| 鍵管理手順書 | KMSキー運用ルールを確認するため | Rotation、無効化、削除予約、復号権限 |
| VPC一覧・構成図 | 3.7の対象VPCを確認するため | VPC ID、用途、環境、リージョン |
| VPC Flow Logs設計書 | Flow Logsの保存先とログ種別を確認するため | CloudWatch Logs/S3、Traffic type、保持期間 |
| 証跡保存ルール | 調査結果の保存形式を合わせるため | 画面キャプチャ、CLI出力、保存先、マスキング |

## 4. 現場側に確認すること

### 4.1 共通確認

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 3.4〜3.7の対象環境はどこまでか | 本番、運用、開発、検証で対象が変わるため |
| 2 | 対象アカウントは単一か複数か | Organization Trailや複数VPC確認に影響するため |
| 3 | 対象リージョンはどこか | KMSとVPC Flow Logsはリージョン単位のため |
| 4 | 調査はCLIで実施してよいか | 証跡取得と一覧化を効率化するため |
| 5 | 証跡として何を提出するか | 画面キャプチャ、CLI出力、Excel一覧などを決めるため |

### 4.2 3.4 Server Access Logging確認

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | CloudTrailログ保存先S3はどれか | 調査対象を確定するため |
| 2 | Server Access Loggingの保存先は既存か新規か | 有効化設計に必要 |
| 3 | 保存先バケットは同一アカウントか別アカウントか | 権限と運用責任に影響 |
| 4 | 保存期間とライフサイクル方針はあるか | ログ増加とコストに影響 |
| 5 | 自分自身のバケットへ保存する設計を避けるか | ログのループや運用混乱を避けるため |

### 4.3 3.5/3.6 KMS/CMK確認

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 既存カスタマー管理KMSキーを使うか、新規作成するか | 設計方針が変わるため |
| 2 | 対象KMSキーは対称キーか | CloudTrailログ暗号化用途では対称キーが前提 |
| 3 | Key Policyの管理者、利用者、CloudTrail許可はどうするか | 暗号化・復号・運用に必要 |
| 4 | ログ参照者にKMS復号権限が必要か | CloudTrailログ調査に影響 |
| 5 | 自動ローテーションを有効化してよいか | 3.6の対応方針 |
| 6 | KMSキー無効化や削除予約の運用ルールはあるか | 4.7の監視要件とも関連 |
| 7 | CMK化による料金影響を確認済みか | KMSリクエスト料金が発生するため |

### 4.4 3.7 VPC Flow Logs確認

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | Flow Logs対象は全VPCか、特定環境のみか | 対象範囲を確定するため |
| 2 | 保存先はCloudWatch LogsかS3か | 権限、費用、検索方法が変わるため |
| 3 | Traffic typeは `ALL` / `ACCEPT` / `REJECT` のどれか | 取得粒度に影響 |
| 4 | 集約間隔、ログ形式、保持期間の指定はあるか | 運用・費用に影響 |
| 5 | 既存Flow Logsがある場合、その設定で要件を満たすか | 重複作成を避けるため |

## 5. 作業前提

Windows端末のGit Bashで作業する想定。

PowerShellで実施する場合、`grep`、`sed`、`tr`、`while read` の扱いが異なるため、必要に応じてコマンドを置き換える。

変数を設定する。

```bash
PROFILE="<aws-cli-profile>"
REGION="<target-region>"
EXPECTED_ACCOUNT_ID="<target-account-id>"

EVIDENCE_DIR="./evidence_3x_logging_kms_vpcflow_$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$EVIDENCE_DIR"/{00_account,01_cloudtrail,02_s3_logging,03_kms,04_vpc_flow_logs,05_summary}
```

作業例:

```bash
PROFILE="prod-profile"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="123456789012"
```

## 6. アカウントとリージョンを確認する

目的:
誤ったAWSアカウントやリージョンで調査しないようにする。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_account/01_caller_identity.json"
```

見やすい表示:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query '{Account:Account,Arn:Arn,UserId:UserId}' \
  --output table \
  --no-cli-pager
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `Account` | 想定AWSアカウントIDと一致すること |
| `Arn` | 作業用ユーザーまたはRoleが想定どおりであること |

## 7. CloudTrailとログ保存先S3を確認する

目的:
3.4〜3.6の対象となるCloudTrail Trailとログ保存先S3を特定する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_cloudtrail/01_describe_trails.json"
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
    CloudWatchLogs:CloudWatchLogsLogGroupArn
  }' \
  --output table \
  --no-cli-pager
```

Trail名を設定する。

```bash
TRAIL_NAME="<trail-name>"
```

Trail詳細を保存する。

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_cloudtrail/02_get_trail.json"
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `S3BucketName` | CloudTrailログ保存先S3。3.4、3.5の対象 |
| `S3KeyPrefix` | CloudTrailログのPrefix |
| `KmsKeyId` | CloudTrailログ暗号化に使用するKMSキー。空ならSSE-KMS未設定 |
| `IsMultiRegionTrail` | 全リージョン対象か |
| `IsOrganizationTrail` | Organization Trailか |

CloudTrailログ保存先S3を変数に設定する。

```bash
CLOUDTRAIL_LOG_BUCKET="<cloudtrail-log-bucket-name>"
```

## 8. 要件3.4 Server Access Loggingを確認する

目的:
CloudTrailログ保存先S3バケットでServer Access Loggingが有効か確認する。

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_LOG_BUCKET" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_s3_logging/01_bucket_logging.json"
```

見やすい表示:

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_LOG_BUCKET" \
  --query 'LoggingEnabled.{TargetBucket:TargetBucket,TargetPrefix:TargetPrefix}' \
  --output table \
  --no-cli-pager
```

確認:

| 状態 | 判断 |
|---|---|
| `LoggingEnabled` がある | Server Access Loggingは有効 |
| `TargetBucket` が設定されている | アクセスログ保存先がある |
| `TargetPrefix` が設定されている | 保存Prefixがある |
| 結果が空または `LoggingEnabled` なし | Server Access Loggingは未有効 |

補足確認として、ログ保存先S3の暗号化とPublic Access Blockも確認する。

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_LOG_BUCKET" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_s3_logging/02_bucket_encryption.json"
```

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$CLOUDTRAIL_LOG_BUCKET" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_s3_logging/03_public_access_block.json"
```

注意:

- Server Access Loggingの保存先は、原則として別バケットを推奨する。
- 同じバケットを保存先にすると、ログのログが出続けるなど運用上わかりにくくなる可能性がある。
- 有効化は設定変更なので、この調査手順では実施しない。

## 9. 要件3.5 CloudTrailログのKMS/CMK暗号化を確認する

目的:
CloudTrailログがカスタマー管理KMSキーで暗号化されているか確認する。

最重要確認ポイント:

| 見る場所 | 意味 |
|---|---|
| CloudTrail Trailの `KmsKeyId` | CloudTrailがログファイル暗号化に使用するKMSキー |
| S3バケットのデフォルト暗号化 | バケットに保存されるオブジェクトのデフォルト暗号化 |
| KMS Key | カスタマー管理キーか、AWS管理キーか、Rotation可能か |

TrailのKMS設定を表示する。

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{Name:Name,KmsKeyId:KmsKeyId,S3Bucket:S3BucketName,S3Prefix:S3KeyPrefix}' \
  --output table \
  --no-cli-pager
```

KMSキーが設定されている場合、変数に設定する。

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
  > "$EVIDENCE_DIR/03_kms/01_describe_key.json"
```

見やすい表示:

```bash
aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --query 'KeyMetadata.{
    KeyId:KeyId,
    Arn:Arn,
    Description:Description,
    KeyManager:KeyManager,
    KeySpec:KeySpec,
    KeyUsage:KeyUsage,
    Origin:Origin,
    Enabled:Enabled,
    KeyState:KeyState,
    MultiRegion:MultiRegion
  }' \
  --output table \
  --no-cli-pager
```

Key Policy:

```bash
aws kms get-key-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --policy-name default \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_kms/02_key_policy.json"
```

Alias:

```bash
aws kms list-aliases \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Aliases[?TargetKeyId!=null].{AliasName:AliasName,TargetKeyId:TargetKeyId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_kms/03_aliases.json"
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `KmsKeyId` | CloudTrailにKMSキーが設定されているか |
| `KeyManager` | `CUSTOMER` ならカスタマー管理KMSキー |
| `KeySpec` | 通常は `SYMMETRIC_DEFAULT` |
| `KeyUsage` | `ENCRYPT_DECRYPT` |
| `Enabled` | `true` |
| `KeyState` | `Enabled` |
| Key Policy | CloudTrailが暗号化に使用できる許可があるか |
| Key Policy | ログ調査者が必要に応じて復号できる設計か |

判定:

| 状態 | 判断 |
|---|---|
| Trailの `KmsKeyId` が空 | CloudTrailログはカスタマー管理KMSキー暗号化ではない可能性が高い |
| `KeyManager = CUSTOMER` | カスタマー管理KMSキー |
| `KeyManager = AWS` | AWS管理キーであり、要件のCMKとは異なる可能性 |
| `KeyState != Enabled` | ログ配送や復号に影響する可能性 |

## 10. 要件3.6 KMSキーRotationを確認する

目的:
3.5で使用するカスタマー管理KMSキーの自動ローテーションが有効か確認する。

```bash
aws kms get-key-rotation-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_kms/04_key_rotation_status.json"
```

見やすい表示:

```bash
aws kms get-key-rotation-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --query '{KeyRotationEnabled:KeyRotationEnabled}' \
  --output table \
  --no-cli-pager
```

確認:

| 状態 | 判断 |
|---|---|
| `KeyRotationEnabled = true` | 自動ローテーション有効 |
| `KeyRotationEnabled = false` | 自動ローテーション未有効 |
| コマンドがエラー | キー種別や権限を確認する |

注意:

- Rotation有効化は設定変更なので、この調査手順では実施しない。
- AWS管理キーは利用者側でRotation設定を変更する対象ではない。
- 3.5でCMK未使用の場合、3.6は「対象キーなし」または「3.5対応後に確認」と整理する。

## 11. 要件3.7 VPC Flow Logsを確認する

目的:
すべての対象VPCでVPC Flow Logsが有効か確認する。

VPC一覧:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_vpc_flow_logs/01_vpcs.json"
```

見やすい表示:

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
  --output table \
  --no-cli-pager
```

Flow Logs一覧:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_vpc_flow_logs/02_flow_logs.json"
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
    LogGroupName:LogGroupName,
    FlowLogStatus:FlowLogStatus
  }' \
  --output table \
  --no-cli-pager
```

VPCごとの有効化状況を確認する。

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[].VpcId' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | sed '/^$/d' \
  > "$EVIDENCE_DIR/04_vpc_flow_logs/03_vpc_ids.txt"
```

```bash
while read -r VPC_ID
do
  echo "=== ${VPC_ID} ==="

  aws ec2 describe-flow-logs \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filter "Name=resource-id,Values=${VPC_ID}" \
    --query 'FlowLogs[].{
      FlowLogId:FlowLogId,
      ResourceId:ResourceId,
      TrafficType:TrafficType,
      LogDestinationType:LogDestinationType,
      LogDestination:LogDestination,
      LogGroupName:LogGroupName,
      FlowLogStatus:FlowLogStatus
    }' \
    --output json \
    --no-cli-pager
done < "$EVIDENCE_DIR/04_vpc_flow_logs/03_vpc_ids.txt" \
  > "$EVIDENCE_DIR/04_vpc_flow_logs/04_flow_logs_by_vpc.json"
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `ResourceType` | `VPC` か、Subnet/ENI単位か |
| `ResourceId` | 対象VPC IDか |
| `TrafficType` | `ALL` / `ACCEPT` / `REJECT` |
| `LogDestinationType` | `cloud-watch-logs` または `s3` |
| `LogDestination` | 保存先 |
| `FlowLogStatus` | `ACTIVE` か |

判定:

| 状態 | 判断 |
|---|---|
| 対象VPCごとにFlow Logsあり | 有効化済み |
| 一部VPCのみFlow Logsあり | 不足VPCの確認が必要 |
| Flow Logsなし | 3.7未対応の可能性 |
| Subnet/ENI単位のみ | 要件が「すべてのVPC」なら対象範囲を確認 |

## 12. 調査結果のまとめ表

以下の形式で整理する。

```tsv
要件番号	確認項目	対象リソース	現在値	判定	不足/確認事項	次アクション
3.4	Server Access Logging	CloudTrailログ保存先S3	未確認	未確認	未記入	未記入
3.5	CloudTrail KmsKeyId	CloudTrail Trail	未確認	未確認	未記入	未記入
3.5	KMS Key Manager	KMS Key	未確認	未確認	未記入	未記入
3.5	Key Policy	KMS Key	未確認	未確認	未記入	未記入
3.6	Key Rotation	KMS Key	未確認	未確認	未記入	未記入
3.7	VPC Flow Logs	全対象VPC	未確認	未確認	未記入	未記入
```

判定の目安:

| 判定 | 意味 |
|---|---|
| 対応済み | 要件を満たす設定が確認できた |
| 一部対応 | 一部リソースのみ対応、または関連設定が不足 |
| 不足 | 要件を満たす設定が確認できない |
| 要確認 | 設計書や運用判断が必要 |
| 対象外 | 対象外環境や対象外リソースであることを確認済み |

## 13. 最低限必要な参照権限

現状調査だけなら、まずは参照系権限が必要。

| サービス | 主な参照権限 |
|---|---|
| STS | `sts:GetCallerIdentity` |
| CloudTrail | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrail`, `cloudtrail:GetTrailStatus` |
| S3 | `s3:GetBucketLogging`, `s3:GetEncryptionConfiguration`, `s3:GetBucketPublicAccessBlock`, `s3:GetBucketPolicyStatus` |
| KMS | `kms:DescribeKey`, `kms:GetKeyPolicy`, `kms:GetKeyRotationStatus`, `kms:ListAliases` |
| EC2/VPC | `ec2:DescribeVpcs`, `ec2:DescribeFlowLogs` |
| CloudWatch Logs | `logs:DescribeLogGroups` |

設定変更は別権限であり、この調査手順では使用しない。

変更時に追加で必要になり得る権限の例:

| 要件 | 変更時に必要になり得る権限 |
|---|---|
| 3.4 | `s3:PutBucketLogging` |
| 3.5 | `cloudtrail:UpdateTrail`, `kms:CreateKey`, `kms:PutKeyPolicy`, `kms:CreateAlias` |
| 3.6 | `kms:EnableKeyRotation` |
| 3.7 | `ec2:CreateFlowLogs`, `iam:PassRole` |

## 14. 完了条件

以下を満たしたら、3番台の現状調査は完了とする。

- CloudTrail Trailとログ保存先S3を特定済み
- CloudTrailログ保存先S3のServer Access Logging有無を確認済み
- Server Access Logging保存先とPrefixを確認済み
- CloudTrail Trailの `KmsKeyId` を確認済み
- KMSキーがカスタマー管理キーか確認済み
- KMS Key Policy確認要否を整理済み
- KMS Rotation有効化状態を確認済み
- 全対象VPCのFlow Logs有効化状況を確認済み
- 要件3.4〜3.7ごとに、対応済み/不足/要確認/対象外を整理済み

## 15. 参考

- AWS CloudTrail: Encrypting CloudTrail log files with AWS KMS keys
  - English: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html
- Amazon S3: Logging requests using server access logging
  - English: https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html
- AWS KMS: Rotating keys
  - English: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/rotate-keys.html
- Amazon VPC: Flow logs
  - English: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html

