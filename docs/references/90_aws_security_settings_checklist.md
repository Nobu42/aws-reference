# 90 AWS Security Settings 横断チェックリスト

## 1. このドキュメントの目的

このドキュメントは、AWS環境のセキュリティ設定をサービス横断で確認するための索引である。

個別サービスの詳細コマンドは各リファレンスに分けているため、このドキュメントでは「どの順番で」「何を見て」「どのリファレンスへ進むか」を整理する。

想定する作業は、銀行系システムのAWSセキュリティ・ネットワーク改善案件で発生しそうな以下の内容である。

- AWS設定の確認
- セキュリティ対策状況の確認
- 影響調査済み項目に対する設定変更
- 設定変更後のテスト
- 作業手順書の作成
- 証跡取得
- 報告対応

このドキュメントで重視する観点:

- 変更前確認
- 影響範囲
- 変更後確認
- 切り戻し方法
- セキュリティ上の注意点
- 証跡として残すもの
- 案件で説明できるポイント
- AWS資格試験につながるポイント

## 2. 使い方

まずこの横断チェックリストで全体像を確認し、詳細は該当リファレンスへ進む。

```text
90_aws_security_settings_checklist.md
  ↓
対象サービスを決める
  ↓
重要度と確認観点を見る
  ↓
個別CLIリファレンスへ進む
  ↓
変更前確認、変更、変更後確認、切り戻しを実施
  ↓
証跡を整理して報告
```

関連リファレンス:

| No. | リファレンス | 主な用途 |
| :--- | :--- | :--- |
| 00 | [共通AWS CLI・証跡保存リファレンス](./00_common_aws_cli_reference.md) | Account / Profile / Region確認、証跡保存 |
| 01 | [S3セキュリティ設定CLIリファレンス](./01_s3_security_cli_reference.md) | S3 Public Access Block、ACL、暗号化、ログ |
| 02 | [S3 Bucket Policy CLIリファレンス](./02_s3_bucket_policy_cli_reference.md) | バケットポリシー変更、Public判定、切り戻し |
| 03 | [CloudTrail CLIリファレンス](./03_cloudtrail_cli_reference.md) | Trail、Event Data Store、イベント検索 |
| 04 | [CloudWatch CLIリファレンス](./04_cloudwatch_cli_reference.md) | Log Group、Metric Filter、Alarm、ログ検索 |
| 05 | [GuardDuty CLIリファレンス](./05_guardduty_cli_reference.md) | Detector、Finding、重要度、調査 |
| 06 | [MFAなし管理コンソールログイン検知手順](./06_mfa_console_login_detection.md) | CloudTrailからMFAなしログイン検知 |
| 07 | [VPC/Network CLIリファレンス](./07_vpc_network_cli_reference.md) | VPC、Subnet、Route、SG、NACL、Endpoint、Flow Logs |
| 08 | [EC2 Security CLIリファレンス](./08_ec2_security_cli_reference.md) | EC2、IAM Role、IMDSv2、EBS暗号化 |
| 09 | [RDS Security CLIリファレンス](./09_rds_security_cli_reference.md) | RDS Public設定、暗号化、ログ、バックアップ |
| 10 | [Lambda Security CLIリファレンス](./10_lambda_security_cli_reference.md) | Lambda IAM Role、VPC、環境変数、Function URL |

## 3. 重要度の目安

| 重要度 | 意味 | 例 |
| :--- | :--- | :--- |
| Critical | 外部公開、権限過多、ログ欠落など重大事故に直結する | S3 Public、RDS Public、Function URL認証なし公開、CloudTrail停止 |
| High | 侵害時の影響拡大、監査不備、データ保護不備につながる | IAM FullAccess、暗号化なし、Backupなし、GuardDuty無効 |
| Medium | 運用上のリスク、調査困難、将来の障害につながる | Log Retention未設定、タグ不足、SG説明なし |
| Low | 改善余地、標準化、手順整備の対象 | 命名規則、証跡配置、報告フォーマット |

案件での優先順位:

```text
1. 外部公開されていないか
2. 認証・認可が過剰でないか
3. データが暗号化されているか
4. 監査ログが残るか
5. 検知できるか
6. 切り戻せるか
7. 証跡として説明できるか
```

## 4. 作業前の共通確認

### 4.1 操作先アカウント確認

```bash
PROFILE="learning"
REGION="ap-northeast-1"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

証跡保存:

```bash
WORK_NAME="aws_security_settings_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

### 4.2 作業前に確認すること

| 確認項目 | 内容 |
| :--- | :--- |
| Account | 操作先AWSアカウントが正しいか |
| Region | 対象リージョンが正しいか |
| Profile | 作業用Profileが正しいか |
| 承認 | 作業申請・変更承認があるか |
| 対象 | 対象リソースID、Nameタグ、ARNが明確か |
| 時間帯 | 作業時間帯、影響許容時間が明確か |
| 影響範囲 | 利用アプリ、連携先、運用監視への影響を把握したか |
| 切り戻し | 変更前設定を保存したか |
| 証跡 | コマンド結果、スクリーンショット、差分を残せるか |

## 5. サービス横断チェック一覧

### 5.1 最初に見る全体チェック

| No. | 領域 | 確認項目 | 重要度 | 詳細 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Account | RootユーザーMFA、有効なIAMユーザー、Access Key棚卸し | Critical | IAM / Security Hub |
| 2 | IAM | 管理者権限、長期Access Key、未使用権限 | Critical | 00、汎用セキュリティ調査 |
| 3 | CloudTrail | Trail有効、Multi-region、ログ保存先、停止なし | Critical | 03 |
| 4 | GuardDuty | Detector有効、Finding未対応なし | High | 05 |
| 5 | S3 | Public Access Block、Bucket Policy、暗号化、ACL | Critical | 01、02 |
| 6 | VPC | Public経路、SG、NACL、Flow Logs | High | 07 |
| 7 | EC2 | Public IP、IMDSv2、IAM Role、EBS暗号化 | High | 08 |
| 8 | RDS | PubliclyAccessible、SG、暗号化、Backup | Critical | 09 |
| 9 | Lambda | Function URL、Resource policy、環境変数、Role | High | 10 |
| 10 | CloudWatch | 重要ログのRetention、Metric Filter、Alarm | High | 04 |
| 11 | KMS | Key policy、Key state、削除予定、権限 | High | 00、各サービス |
| 12 | Secrets | 秘密情報の保管場所、平文混入、Rotation | High | Lambda / EC2 / RDS周辺 |

### 5.2 変更作業で必ず見る横断チェック

| フェーズ | 確認項目 | 証跡 |
| :--- | :--- | :--- |
| 変更前 | 対象リソースの現在設定 | `before/*.json` |
| 変更前 | 関連リソースの設定 | SG、IAM、KMS、Logs、DNSなど |
| 変更前 | CloudTrailの直近変更履歴 | `lookup-events` 結果 |
| 変更前 | 影響範囲 | 手順書、対象一覧、関係者確認 |
| 変更 | 実行コマンドまたはGUI操作 | 作業ログ、スクリーンショット |
| 変更後 | 設定値が期待どおりか | `after/*.json` |
| 変更後 | アプリ・疎通・ログ確認 | curl、dig、DB接続、CloudWatch Logs |
| 変更後 | CloudTrailに変更履歴が残るか | 変更APIイベント |
| 切り戻し | 変更前設定へ戻せるか | rollbackコマンド、差分 |

## 6. S3セキュリティ確認

S3は案件で最も出やすい領域のひとつである。特にバケットポリシー変更、Public Access Block、ACL、暗号化、ログ設定を優先して確認する。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Account-level Public Access Block | 原則4項目すべて有効 | Critical | 01 |
| Bucket-level Public Access Block | 原則4項目すべて有効 | Critical | 01 |
| Bucket Policy | `Principal=*` のAllowがない、条件付きで限定 | Critical | 02 |
| ACL | `BucketOwnerEnforced` またはPublic ACLなし | High | 01 |
| Object Ownership | ACLを使わない構成 | High | 01 |
| Default Encryption | SSE-S3またはSSE-KMS | High | 01 |
| Versioning | 重要データは有効 | Medium | 01 |
| Server Access Logging | 要件に応じて有効 | Medium | 01 |
| CloudTrail Data events | 重要バケットは検討 | High | 03 |
| Lifecycle | 保持期間と削除方針が明確 | Medium | 01 |

代表コマンド:

```bash
BUCKET_NAME="example-bucket"

aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME"

aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME"

aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME"
```

証跡:

- Public Access Block設定
- Bucket Policy
- Bucket Policy Status
- ACL / Ownership Controls
- Encryption
- Versioning
- Logging
- CloudTrail Data events
- 変更前後のPolicy差分

切り戻し:

```text
変更前のBucket Policy JSONを保存し、put-bucket-policyで戻す。
Public Access BlockやOwnership Controlsを変更した場合は、変更前値を保存して同じ項目を戻す。
```

## 7. IAM / 認証認可確認

IAMは全サービスに影響する。最小権限、長期認証情報、MFA、Resource policy、Cross-account accessを中心に確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Root MFA | 有効 | Critical | Rootユーザーは通常使わない |
| IAM User | 必要最小限 | High | 人の利用はIdentity Centerが望ましい |
| Access Key | 未使用・古いKeyなし | High | 長期Keyは漏洩リスク |
| AdministratorAccess | 必要最小限 | Critical | 作業用権限も期限や用途を限定 |
| Inline Policy | `Action=*`、`Resource=*` を確認 | High | 一時対応の残骸に注意 |
| AssumeRole Trust Policy | 信頼先が限定されている | High | 外部ID、Principal確認 |
| Resource Policy | Public / Cross-account許可を確認 | Critical | S3、Lambda、KMSなど |
| Permissions Boundary | 必要な環境では設定 | Medium | 権限上限管理 |

代表コマンド:

```bash
aws iam generate-credential-report \
  --profile "$PROFILE"

aws iam get-credential-report \
  --profile "$PROFILE" \
  --query 'Content' \
  --output text \
  | base64 -D \
  > "$EVIDENCE_DIR/investigation/iam_credential_report.csv"

aws iam list-users \
  --profile "$PROFILE" \
  --output table

aws iam list-roles \
  --profile "$PROFILE" \
  --query 'Roles[*].{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate}' \
  --output table
```

Linuxの場合、`base64 -D` の代わりに `base64 --decode` を使う。

証跡:

- Credential Report
- 対象RoleのTrust Policy
- Attached Policy
- Inline Policy
- Access Key Last Used
- MFA設定状況

## 8. CloudTrail確認

CloudTrailは「誰が、いつ、何をしたか」を確認するための監査基盤である。設定変更作業では、変更前後のCloudTrail確認が重要になる。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Trail | 有効 | Critical | 03 |
| Multi-region Trail | 有効 | High | 03 |
| Management events | Read / Writeの方針が明確 | Critical | 03 |
| S3保存先 | 暗号化、Publicでない | Critical | 01、03 |
| Log file validation | 有効が望ましい | High | 03 |
| CloudWatch Logs連携 | 検知要件がある場合は有効 | High | 03、04 |
| Data events | S3 / Lambdaなど必要に応じて有効 | High | 03 |
| Event Data Store | 調査要件に応じて利用 | Medium | 03 |

代表コマンド:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output table

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "trail-name"

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --max-results 10 \
  --output table
```

証跡:

- Trail一覧
- Trail Status
- Event Selectors
- S3保存先Bucket設定
- CloudWatch Logs連携
- 変更対象APIのEvent History

## 9. CloudWatch確認

CloudWatchはログ確認、検知、Alarm、証跡調査で使う。特にCloudTrailからCloudWatch Logsへ連携している場合、Metric FilterとAlarmが重要になる。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Log Group | 対象ログが存在 | High | 04 |
| Retention | 無期限放置ではなく要件に沿う | High | 04 |
| KMS暗号化 | 要件に応じて有効 | Medium | 04 |
| Metric Filter | 検知条件が定義済み | High | 04 |
| Alarm | 通知先や状態が妥当 | High | 04 |
| Logs Insights | 調査クエリを使える | Medium | 04 |
| Dashboard | 運用要件に応じて整備 | Low | 04 |

代表コマンド:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays,KmsKeyId:kmsKeyId,StoredBytes:storedBytes}' \
  --output table

aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

証跡:

- Log Group一覧
- Retention設定
- Metric Filter一覧
- Alarm一覧
- Alarm状態
- Logs Insights検索結果

## 10. GuardDuty確認

GuardDutyは脅威検知の入口になる。Findingの有無だけでなく、Detectorが有効か、Findingの重要度と対象リソースを確認する。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Detector | 有効 | High | 05 |
| Finding | 未対応のHigh/Criticalがない | Critical | 05 |
| Severity | 重要度別に整理 | High | 05 |
| Affected resource | EC2、IAM、S3など対象を特定 | High | 05 |
| Archive/Suppression | 誤検知対応が管理されている | Medium | 05 |
| CloudTrail連携 | 調査でCloudTrailを確認 | High | 03、05 |

代表コマンド:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION"

DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text)

aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID"
```

証跡:

- Detector ID
- Detector設定
- Finding一覧
- Finding詳細
- 調査メモ
- 対応方針

## 11. MFAなし管理コンソールログイン検知

面談でも出てきた重点テーマである。CloudTrailの `ConsoleLogin` イベントから `MFAUsed` を見て、CloudWatch LogsのMetric FilterやAlarmへつなげる。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| CloudTrail ConsoleLogin | 取得できる | Critical | 06 |
| MFAUsed | `No` を検知できる | Critical | 06 |
| Metric Filter | 条件が正しい | High | 06 |
| Alarm | 通知や状態確認ができる | High | 06 |
| 調査手順 | 対象ユーザー、IP、時刻を追える | High | 06 |

代表コマンド:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 20 \
  --output json
```

証跡:

- ConsoleLoginイベント
- `additionalEventData.MFAUsed`
- Metric Filter
- Alarm
- テスト結果
- Teams報告

## 12. VPC / ネットワーク確認

ネットワーク変更は影響範囲が広い。Route Table、Security Group、NACL、VPC Endpoint、Flow Logsをセットで見る。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| VPC | 対象VPCを識別できる | High | 07 |
| Subnet | Public / Privateの役割が明確 | High | 07 |
| Route Table | `0.0.0.0/0` の向きが妥当 | Critical | 07 |
| Internet Gateway | Public Subnetのみ経路あり | High | 07 |
| NAT Gateway | Private Subnetの外向き通信に利用 | Medium | 07 |
| Security Group | 必要Port、必要Sourceのみ | Critical | 07 |
| NACL | Deny/Allowの影響を確認 | High | 07 |
| VPC Endpoint | Private通信要件に応じて設定 | Medium | 07 |
| Flow Logs | 調査・監査要件に応じて有効 | High | 07 |

代表コマンド:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

証跡:

- VPC一覧
- Subnet一覧
- Route Table
- Security Group Rules
- NACL
- VPC Endpoint
- Flow Logs
- 変更前後の通信テスト結果

## 13. EC2確認

EC2はPublic IP、Security Group、IAM Role、IMDSv2、EBS暗号化を中心に確認する。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Public IP | Private用途ではなし | High | 08 |
| Security Group | 管理ポートを限定 | Critical | 08 |
| IAM Role | 必要最小限 | High | 08 |
| IMDSv2 | `HttpTokens=required` | High | 08 |
| EBS暗号化 | 有効 | High | 08 |
| AMI | 承認済み、脆弱性対応済み | Medium | 08 |
| SSM | 可能ならSession Manager管理 | Medium | 08 |
| Logs | CloudWatch Agentなどで収集 | Medium | 04、08 |

代表コマンド:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,Role:IamInstanceProfile.Arn,IMDS:MetadataOptions.HttpTokens}' \
  --output table
```

証跡:

- Instance一覧
- Security Group Rules
- IAM Instance Profile
- Metadata Options
- EBS Volume暗号化
- CloudWatch Agent状態

## 14. RDS確認

RDSはPublic設定、暗号化、Security Group、ログ、バックアップを重点的に見る。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| PubliclyAccessible | `false` | Critical | 09 |
| DB Subnet Group | Private Subnet | Critical | 09 |
| Security Group | アプリSGからDB Portのみ | Critical | 09 |
| StorageEncrypted | `true` | High | 09 |
| KMS Key | 要件に沿う | High | 09 |
| BackupRetention | 本番相当では0以外 | High | 09 |
| DeletionProtection | 本番相当では有効 | High | 09 |
| CloudWatch Logs Export | 必要ログを出力 | Medium | 09 |
| Snapshot Public | Public共有なし | Critical | 09 |

代表コマンド:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Public:PubliclyAccessible,Encrypted:StorageEncrypted,Backup:BackupRetentionPeriod,DeletionProtection:DeletionProtection,Endpoint:Endpoint.Address}' \
  --output table
```

証跡:

- DB Instance設定
- DB Subnet Group
- VPC Security Groups
- Parameter Group
- Option Group
- EnabledCloudwatchLogsExports
- Snapshot設定
- Backup設定

## 15. Lambda確認

LambdaはIAM Role、Resource-based policy、VPC接続、環境変数、Function URLを重点的に見る。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Execution Role | 最小権限 | High | 10 |
| Resource Policy | Public / Cross-account許可を確認 | Critical | 10 |
| VPC Config | 必要な場合のみ設定、SG妥当 | High | 10 |
| Environment Variables | 秘密情報を平文保存しない | High | 10 |
| KMSKeyArn | 要件に応じて指定 | Medium | 10 |
| CloudWatch Logs | 出力・Retention確認 | High | 10、04 |
| Function URL | `AWS_IAM` または承認済みPublic | Critical | 10 |
| CORS | `*` の扱いを確認 | High | 10 |

代表コマンド:

```bash
FUNCTION_NAME="sample-function"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,Role:Role,VpcConfig:VpcConfig,KMSKeyArn:KMSKeyArn,LoggingConfig:LoggingConfig}' \
  --output table

aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output table
```

証跡:

- Function Configuration
- Execution Role
- Attached / Inline Policy
- Resource-based policy
- VPC Config
- Function URL
- CloudWatch Logs

## 16. KMS / Secrets確認

KMSとSecretsは複数サービスにまたがる。Key policyと利用サービスの権限を合わせて見る。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| KMS Key State | `Enabled` | High | 無効化・削除予定に注意 |
| Key Policy | 管理者、利用者が限定 | Critical | `Principal=*` に注意 |
| Rotation | 要件に応じて有効 | Medium | AWS managed keyとCMKで扱いが異なる |
| Grants | 不要なGrantなし | Medium | 一時的な許可残りに注意 |
| Secrets Manager | 秘密情報を集中管理 | High | 環境変数平文を避ける |
| Secret Rotation | 要件に応じて有効 | Medium | アプリ影響確認が必要 |

代表コマンド:

```bash
aws kms list-keys \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws secretsmanager list-secrets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'SecretList[*].{Name:Name,ARN:ARN,KmsKeyId:KmsKeyId,RotationEnabled:RotationEnabled,LastChangedDate:LastChangedDate}' \
  --output table
```

証跡:

- KMS Key一覧
- Key policy
- Key rotation
- Key state
- Secrets一覧
- Rotation設定

## 17. ALB / ACM確認

Web公開がある場合は、ALBのListener、Security Group、証明書、Target Healthを見る。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| ALB Scheme | 公開要件どおり | High | internet-facing/internal |
| Listener | HTTP/HTTPSの方針が明確 | High | 80、443 |
| TLS Policy | 古いTLSを使わない | High | セキュリティポリシー |
| ACM Certificate | `ISSUED`、期限内 | High | 更新・DNS検証 |
| Target Health | Healthy | High | アプリ疎通 |
| Security Group | 入口を必要Portに限定 | Critical | 0.0.0.0/0は公開Portのみ |

代表コマンド:

```bash
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws elbv2 describe-listeners \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --output table

aws acm list-certificates \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

## 18. Security Hub / AWS Config確認

現場によってはSecurity HubやAWS Configが有効になっている。自分で設定変更する前に、既存の統制サービスの有無を確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Security Hub | 有効化状況を確認 | High | FSBPなど |
| Findings | 未対応Findingを確認 | High | 重要度別 |
| AWS Config | Recorder有効 | High | 変更履歴・準拠状況 |
| Config Rules | 対象ルール確認 | Medium | 組織標準に従う |
| Access Analyzer | 外部公開・Cross-account確認 | High | S3、IAM、KMS、Lambda |

代表コマンド:

```bash
aws securityhub describe-hub \
  --profile "$PROFILE" \
  --region "$REGION"

aws securityhub get-enabled-standards \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws configservice describe-configuration-recorders \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

補足:

```text
Security HubやAWS Configの結果は、現場標準のチェックリストと一致している可能性がある。
手作業の確認だけでなく、既存の統制ツールが何を検知しているかを先に見る。
```

## 19. 変更手順書へ落とす時の観点

作業手順書では、以下を表として整理するとレビューされやすい。

| 項目 | 書く内容 |
| :--- | :--- |
| 作業名 | 何を変更するか |
| 対象 | Account、Region、Service、Resource ID |
| 作業理由 | セキュリティ改善、統制対応、影響調査済みなど |
| 変更前設定 | 現在値 |
| 変更後設定 | 期待値 |
| 影響範囲 | アプリ、運用、監視、他システム |
| 作業手順 | CLIまたはGUIの手順 |
| 確認手順 | 変更後確認、疎通、ログ、CloudTrail |
| 切り戻し | 具体的な戻し方 |
| 証跡 | 保存ファイル、スクリーンショット |
| 連絡先 | Teams、担当者、承認者 |

## 20. 証跡一覧テンプレート

| No. | 証跡 | ファイル例 | 用途 |
| :--- | :--- | :--- | :--- |
| 1 | Caller Identity | `00_caller_identity.json` | 操作先アカウント確認 |
| 2 | 変更前設定 | `before/*.json` | 切り戻し元 |
| 3 | 変更コマンド | `change/change_commands.txt` | 実施内容 |
| 4 | 変更後設定 | `after/*.json` | 変更結果確認 |
| 5 | 差分 | `after/*_diff.txt` | レビュー用 |
| 6 | CloudTrail | `investigation/cloudtrail_*.json` | 監査証跡 |
| 7 | CloudWatch Logs | `investigation/logs_*.json` | 動作確認 |
| 8 | スクリーンショット | `screenshots/*.png` | GUI証跡 |
| 9 | テスト結果 | `after/test_result.txt` | 疎通・アプリ確認 |
| 10 | 切り戻し手順 | `rollback/*.txt` | 障害時対応 |

## 21. Teams報告例

### 21.1 変更前確認

```text
AWSセキュリティ設定変更の変更前確認が完了しました。

対象:
- Account: 123456789012
- Region: ap-northeast-1
- Service: S3 / Lambda / RDS
- Resource: 対象リソース名

確認内容:
- 現在設定
- 関連IAM / SG / KMS / Logs
- CloudTrail変更履歴
- 影響範囲
- 切り戻し方法

現時点の懸念:
- なし

次に、承認済み手順に沿って設定変更を実施します。
```

### 21.2 変更完了

```text
AWSセキュリティ設定変更が完了しました。

実施内容:
- 対象リソースの設定を変更
- 変更後設定を確認
- CloudTrailに変更イベントが記録されていることを確認
- アプリ疎通 / ログ確認を実施

結果:
- 変更後設定: 想定どおり
- テスト: 正常
- エラー: なし

証跡:
- 変更前JSON
- 変更後JSON
- 差分
- CloudTrail
- スクリーンショット
```

### 21.3 要確認

```text
AWSセキュリティ設定確認中に、追加確認が必要な項目がありました。

対象:
- Service: Lambda
- Resource: sample-function

内容:
- Function URLがAuthType=NONEで設定されています。
- Resource-based policyにPrincipal=*のInvoke許可があります。

確認したい点:
- 外部公開が設計・承認済みか
- 認証方式、WAF/API Gateway利用有無
- 監視・ログ・Rate limitの要件

設定変更前に方針確認をお願いします。
```

## 22. 案件で説明できるポイント

- S3だけでなく、IAM、CloudTrail、CloudWatch、GuardDuty、VPC、EC2、RDS、Lambdaを横断して確認する
- まず外部公開、権限過多、暗号化、ログ、検知、切り戻しを優先して見る
- 設定変更は、変更前確認、影響範囲、変更後確認、切り戻し、証跡をセットで扱う
- CLIで確認しつつ、現場ではWebコンソールのスクリーンショット証跡も残す
- CloudTrailで変更履歴を確認し、作業実施者、時刻、API、結果を説明できる
- GuardDutyやSecurity Hubがある場合は、既存Findingや統制結果も活用する

## 23. 資格試験につながるポイント

| 分野 | 試験観点 |
| :--- | :--- |
| IAM | 最小権限、MFA、Role、Policy、Resource policy |
| S3 | Public Access Block、Bucket Policy、ACL、暗号化 |
| CloudTrail | Management events、Data events、ログ保存 |
| CloudWatch | Logs、Metric Filter、Alarm |
| GuardDuty | Finding、Severity、Detector |
| VPC | Subnet、Route Table、SG、NACL、Endpoint |
| EC2 | IMDSv2、IAM Role、EBS暗号化 |
| RDS | Public access、暗号化、Backup、Logs |
| Lambda | Execution Role、VPC、環境変数、Function URL |
| KMS | Key policy、Rotation、Decrypt権限 |

## 24. 公式ドキュメント

- AWS Well-Architected Framework Security Pillar
  - https://docs.aws.amazon.com/wellarchitected/latest/framework/security.html
- AWS Security Hub Foundational Security Best Practices
  - https://docs.aws.amazon.com/securityhub/latest/userguide/fsbp-standard.html
- IAM security audit guidelines
  - https://docs.aws.amazon.com/IAM/latest/UserGuide/security-audit-guide.html
- Amazon S3 Block Public Access
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html
- CloudTrail User Guide
  - https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html
- Amazon GuardDuty User Guide
  - https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html
