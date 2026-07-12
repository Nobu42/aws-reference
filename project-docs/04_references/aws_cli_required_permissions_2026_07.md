# AWS CLI必要権限一覧

作成日: 2026-07-07

この資料は、AWSセキュリティ監査指摘対応をAWS CLIで調査・設定・証跡取得する場合に必要になりやすいIAM権限を整理したものである。

目的は、最初から強い変更権限を要求することではない。
まずは参照系権限で現状調査と証跡取得を行い、変更作業が必要な項目だけ、承認された範囲で追加権限または権限保有者による実施を依頼する。

## 1. 基本方針

現場での説明例:

```text
まずは参照系権限で、CloudTrail、CloudWatch Logs、Metric Filter、Alarm、SNS、KMS、VPC Flow Logsなどの現状を確認したいです。
変更系権限は、作業手順と承認が確定した項目に限定して確認します。
```

権限の考え方:

| 区分 | 用途 | 例 |
|---|---|---|
| 参照系 | 現状調査、証跡取得、設計確認 | `Describe*`, `Get*`, `List*`, `LookupEvents` |
| 変更系 | 承認済み設定変更 | `Put*`, `Create*`, `Update*`, `Delete*`, `Enable*`, `Disable*` |
| 高注意権限 | 可用性・監査証跡に大きく影響 | KMS Key Policy変更、CloudTrail停止、Trail削除、KMS削除予約など |

## 2. 最初に必要な共通権限

最初の疎通確認とアカウント確認に必要。

| 権限 | 用途 |
|---|---|
| `sts:GetCallerIdentity` | 自分がどのAWSアカウント・IAM User・Roleで作業しているか確認する |

確認コマンド:

```bash
aws sts get-caller-identity \
  --profile "<profile-name>" \
  --region "ap-northeast-1" \
  --output json \
  --no-cli-pager
```

## 3. 現状調査に必要な参照系権限

まずはこの範囲があると、作業計画と設計確認を進めやすい。

| 領域 | 必要権限 | 確認できること |
|---|---|---|
| CloudTrail | `cloudtrail:DescribeTrails` | Trail一覧、S3保存先、CloudWatch Logs連携有無 |
| CloudTrail | `cloudtrail:GetTrail` | 個別Trail詳細 |
| CloudTrail | `cloudtrail:GetTrailStatus` | ログ記録中か、配送エラーがあるか |
| CloudTrail | `cloudtrail:GetEventSelectors` | Management Event / Data Eventの記録対象 |
| CloudTrail | `cloudtrail:LookupEvents` | Event Historyで変更履歴を検索 |
| CloudWatch Logs | `logs:DescribeLogGroups` | Log Group、保持期間、KMS、保存量 |
| CloudWatch Logs | `logs:DescribeLogStreams` | CloudTrailログが届いているか |
| CloudWatch Logs | `logs:FilterLogEvents` | CloudWatch Logs上のCloudTrailイベント検索 |
| CloudWatch Logs | `logs:DescribeMetricFilters` | 既存Metric Filter確認 |
| CloudWatch | `cloudwatch:DescribeAlarms` | 既存Alarm確認 |
| CloudWatch | `cloudwatch:DescribeAlarmsForMetric` | Metricに紐づくAlarm確認 |
| SNS | `sns:ListTopics` | 既存SNS Topic確認 |
| SNS | `sns:GetTopicAttributes` | Topic Policy、KMS設定確認 |
| SNS | `sns:ListSubscriptionsByTopic` | 通知先、承認状態確認 |
| EventBridge | `events:ListRules` | 既存Rule確認 |
| EventBridge | `events:DescribeRule` | Event Pattern、状態確認 |
| EventBridge | `events:ListTargetsByRule` | 通知先や自動対応先確認 |
| S3 | `s3:GetBucketLogging` | Server Access Logging確認 |
| S3 | `s3:GetBucketPolicy` | Bucket Policy確認 |
| S3 | `s3:GetBucketPolicyStatus` | Public判定確認 |
| S3 | `s3:GetBucketPublicAccessBlock` | Public Access Block確認 |
| S3 | `s3:GetEncryptionConfiguration` | バケット暗号化設定確認 |
| S3 | `s3:GetBucketVersioning` | Versioning確認 |
| S3 | `s3:GetBucketOwnershipControls` | Object Ownership確認 |
| S3 | `s3:GetBucketAcl` | ACL確認 |
| S3 | `s3:GetLifecycleConfiguration` | ライフサイクル設定確認 |
| KMS | `kms:ListKeys` | KMSキー一覧 |
| KMS | `kms:ListAliases` | Alias一覧、AWS managed key / customer managed key候補確認 |
| KMS | `kms:DescribeKey` | KeyManager、KeyState、KeyUsage等確認 |
| KMS | `kms:ListKeyPolicies` | Key Policy名確認 |
| KMS | `kms:GetKeyPolicy` | Key Policy確認 |
| KMS | `kms:GetKeyRotationStatus` | Rotation有効化状況確認 |
| KMS | `kms:ListGrants` | Grants確認 |
| KMS | `kms:ListResourceTags` | KMSキーのタグ確認 |
| EC2/VPC | `ec2:DescribeVpcs` | VPC一覧 |
| EC2/VPC | `ec2:DescribeSubnets` | Subnet一覧 |
| EC2/VPC | `ec2:DescribeFlowLogs` | VPC Flow Logs確認 |
| EC2/VPC | `ec2:DescribeNetworkAcls` | NACL確認 |
| EC2/VPC | `ec2:DescribeRouteTables` | Route Table確認 |
| EC2/VPC | `ec2:DescribeSecurityGroups` | Security Group確認 |
| EC2/VPC | `ec2:DescribeInternetGateways` | Internet Gateway確認 |
| EC2/VPC | `ec2:DescribeCustomerGateways` | Customer Gateway確認 |
| EC2/VPC | `ec2:DescribeVpnGateways` | VPN Gateway確認 |
| EC2/VPC | `ec2:DescribeTransitGateways` | Transit Gateway確認 |
| EC2/VPC | `ec2:DescribeVpcEndpoints` | VPC Endpoint確認 |
| GuardDuty | `guardduty:ListDetectors` | Detector有無確認 |
| GuardDuty | `guardduty:GetDetector` | GuardDuty設定、Feature確認 |
| GuardDuty | `guardduty:ListFindings` | Finding ID一覧 |
| GuardDuty | `guardduty:GetFindings` | Finding詳細確認 |
| AWS Config | `config:DescribeConfigurationRecorders` | Recorder有無確認 |
| AWS Config | `config:DescribeDeliveryChannels` | Delivery Channel確認 |
| AWS Config | `config:DescribeConfigurationRecorderStatus` | Recorder稼働状態確認 |
| Organizations | `organizations:DescribeOrganization` | Organizations利用有無確認 |
| Organizations | `organizations:ListAccounts` | 管理対象アカウント確認 |
| Organizations | `organizations:ListRoots` | Root確認 |
| Organizations | `organizations:ListOrganizationalUnitsForParent` | OU構成確認 |
| Organizations | `organizations:ListPolicies` | SCP等のPolicy確認 |

注意:

- Organizations関連は管理アカウントでないと見えない場合がある。
- KMS Key PolicyやSNS Topic Policyは機密に近い情報を含む場合があるため、証跡保存時は取り扱いに注意する。
- S3 Bucket Policy、KMS Key Policy、IAM Policyは、外部共有時にPrincipalやAccount IDをマスクする。

## 4. 要件別の必要権限

### 4.1 A3 / A4: セキュリティアラート運用手順・対応記録

主に資料確認とGuardDuty/通知基盤の参照が中心。

| 区分 | 権限 |
|---|---|
| 参照 | `guardduty:ListDetectors` |
| 参照 | `guardduty:GetDetector` |
| 参照 | `guardduty:ListFindings` |
| 参照 | `guardduty:GetFindings` |
| 参照 | `events:ListRules` |
| 参照 | `events:DescribeRule` |
| 参照 | `events:ListTargetsByRule` |
| 参照 | `sns:ListTopics` |
| 参照 | `sns:ListSubscriptionsByTopic` |
| 参照 | `cloudwatch:DescribeAlarms` |

変更権限は、手順書作成だけなら不要。

### 4.2 3.4: CloudTrail S3バケットのServer Access Logging有効化

現状確認:

| 区分 | 権限 |
|---|---|
| 参照 | `s3:GetBucketLogging` |
| 参照 | `s3:GetBucketPolicy` |
| 参照 | `s3:GetBucketAcl` |
| 参照 | `s3:GetBucketOwnershipControls` |
| 参照 | `s3:GetEncryptionConfiguration` |
| 参照 | `s3:GetLifecycleConfiguration` |

設定変更:

| 区分 | 権限 |
|---|---|
| 変更 | `s3:PutBucketLogging` |
| 変更 | `s3:PutBucketPolicy` |
| 変更 | `s3:PutBucketAcl` |
| 変更 | `s3:PutEncryptionConfiguration` |
| 変更 | `s3:PutLifecycleConfiguration` |

注意:

- 保存先バケットのPolicyやObject Ownershipにより追加設定が必要になる。
- Server Access Loggingの保存先を同一バケットにする構成は避ける。
- ログ量とライフサイクル設定を確認する。

### 4.3 3.5 / 3.6: CloudTrailログのSSE-KMS/CMK化、CMKローテーション

現状確認:

| 区分 | 権限 |
|---|---|
| 参照 | `cloudtrail:DescribeTrails` |
| 参照 | `cloudtrail:GetTrail` |
| 参照 | `kms:ListKeys` |
| 参照 | `kms:ListAliases` |
| 参照 | `kms:DescribeKey` |
| 参照 | `kms:GetKeyPolicy` |
| 参照 | `kms:GetKeyRotationStatus` |
| 参照 | `kms:ListGrants` |

KMSキー作成・設定:

| 区分 | 権限 |
|---|---|
| 変更 | `kms:CreateKey` |
| 変更 | `kms:PutKeyPolicy` |
| 変更 | `kms:CreateAlias` |
| 変更 | `kms:UpdateAlias` |
| 変更 | `kms:EnableKeyRotation` |
| 変更 | `kms:TagResource` |

CloudTrail側の変更:

| 区分 | 権限 |
|---|---|
| 変更 | `cloudtrail:UpdateTrail` |

注意:

- CloudTrailがKMSキーを使ってログを書き込めるKey Policyが必要。
- 運用者がCloudTrailログを読む場合、復号に必要なKMS権限が必要になる。
- `kms:PutKeyPolicy` は強い権限のため、レビュー必須。
- `kms:ScheduleKeyDeletion` や `kms:DisableKey` は通常この対応で必要ない。誤付与を避ける。

### 4.4 3.7: VPC Flow Logs有効化

現状確認:

| 区分 | 権限 |
|---|---|
| 参照 | `ec2:DescribeVpcs` |
| 参照 | `ec2:DescribeSubnets` |
| 参照 | `ec2:DescribeFlowLogs` |
| 参照 | `logs:DescribeLogGroups` |
| 参照 | `s3:GetBucketPolicy` |
| 参照 | `kms:DescribeKey` |

設定変更:

| 区分 | 権限 |
|---|---|
| 変更 | `ec2:CreateFlowLogs` |
| 変更 | `ec2:DeleteFlowLogs` |
| 変更 | `iam:PassRole` |
| 変更 | `logs:CreateLogGroup` |
| 変更 | `logs:PutRetentionPolicy` |
| 変更 | `s3:PutBucketPolicy` |

注意:

- CloudWatch Logsへ出す場合、VPC Flow Logs配送用IAM Roleと `iam:PassRole` が必要になる場合がある。
- S3へ出す場合、保存先S3 Bucket PolicyやKMS設定を確認する。
- ログ量、TrafficType、保持期間を事前に合意する。

## 5. 監視アラート設定に必要な権限

4.1〜4.15は、基本的にCloudTrailイベントをCloudWatch Logsへ連携し、Metric Filter / Alarm / SNSで通知する想定。

共通参照:

| 区分 | 権限 |
|---|---|
| 参照 | `cloudtrail:DescribeTrails` |
| 参照 | `cloudtrail:GetTrail` |
| 参照 | `cloudtrail:GetTrailStatus` |
| 参照 | `logs:DescribeLogGroups` |
| 参照 | `logs:DescribeMetricFilters` |
| 参照 | `cloudwatch:DescribeAlarms` |
| 参照 | `sns:ListTopics` |
| 参照 | `sns:GetTopicAttributes` |
| 参照 | `sns:ListSubscriptionsByTopic` |

Metric Filter / Alarm / SNS設定:

| 区分 | 権限 |
|---|---|
| 変更 | `logs:PutMetricFilter` |
| 変更 | `logs:DeleteMetricFilter` |
| 変更 | `cloudwatch:PutMetricAlarm` |
| 変更 | `cloudwatch:DeleteAlarms` |
| 変更 | `sns:CreateTopic` |
| 変更 | `sns:Subscribe` |
| 変更 | `sns:Publish` |
| 変更 | `sns:SetTopicAttributes` |

EventBridge方式を併用する場合:

| 区分 | 権限 |
|---|---|
| 参照 | `events:ListRules` |
| 参照 | `events:DescribeRule` |
| 参照 | `events:ListTargetsByRule` |
| 変更 | `events:PutRule` |
| 変更 | `events:PutTargets` |
| 変更 | `events:EnableRule` |
| 変更 | `events:DisableRule` |
| 変更 | `events:RemoveTargets` |
| 変更 | `events:DeleteRule` |

注意:

- 評価シート上はCloudWatch Metric Filter / Alarm方式が本線に見える。
- EventBridgeを使う場合は、現場の設計方針と合っているか確認する。
- SNS Topic Policyの変更が必要になる場合がある。

## 6. 4.1〜4.15の個別確認で必要になりやすい参照権限

| 要件 | 監視対象 | 追加で見たい権限 |
|---|---|---|
| 4.1 | 不正なAPI呼び出し | `cloudtrail:LookupEvents`, `logs:FilterLogEvents` |
| 4.2 | MFAなしConsoleLogin | `cloudtrail:LookupEvents`, `logs:FilterLogEvents` |
| 4.3 | root使用 | `cloudtrail:LookupEvents`, `logs:FilterLogEvents` |
| 4.4 | IAM Policy変更 | `iam:ListPolicies`, `iam:GetPolicy`, `iam:GetPolicyVersion`, `iam:ListRoles`, `iam:ListUsers` |
| 4.5 | CloudTrail設定変更 | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrailStatus`, `cloudtrail:GetEventSelectors` |
| 4.6 | Console認証失敗 | `cloudtrail:LookupEvents`, `logs:FilterLogEvents` |
| 4.7 | CMK無効化/削除予約 | `kms:ListKeys`, `kms:DescribeKey`, `kms:GetKeyPolicy` |
| 4.8 | S3 Bucket Policy変更 | `s3:GetBucketPolicy`, `s3:GetBucketPolicyStatus` |
| 4.9 | AWS Config設定変更 | `config:DescribeConfigurationRecorders`, `config:DescribeDeliveryChannels`, `config:DescribeConfigurationRecorderStatus` |
| 4.10 | Security Group変更 | `ec2:DescribeSecurityGroups` |
| 4.11 | NACL変更 | `ec2:DescribeNetworkAcls` |
| 4.12 | Network Gateway変更 | `ec2:DescribeInternetGateways`, `ec2:DescribeCustomerGateways`, `ec2:DescribeVpnGateways`, `ec2:DescribeTransitGateways` |
| 4.13 | Route Table変更 | `ec2:DescribeRouteTables` |
| 4.14 | VPC変更 | `ec2:DescribeVpcs`, `ec2:DescribeVpcPeeringConnections` |
| 4.15 | Organizations変更 | `organizations:DescribeOrganization`, `organizations:ListAccounts`, `organizations:ListRoots`, `organizations:ListPolicies` |

## 7. 高注意権限

以下は影響が大きいため、必要性・作業者・承認者を明確にする。

| 権限 | 注意理由 |
|---|---|
| `cloudtrail:StopLogging` | CloudTrailログ記録を停止できる |
| `cloudtrail:DeleteTrail` | Trailを削除できる |
| `cloudtrail:UpdateTrail` | CloudTrail保存先やKMS設定を変更できる |
| `cloudtrail:PutEventSelectors` | CloudTrailの記録対象を変更できる |
| `kms:PutKeyPolicy` | KMSキーの管理権限を変更できる |
| `kms:DisableKey` | 暗号化データにアクセスできなくなる可能性がある |
| `kms:ScheduleKeyDeletion` | KMSキー削除予約によりデータ復号不能リスクがある |
| `s3:PutBucketPolicy` | S3アクセス許可を変更できる |
| `s3:PutBucketLogging` | S3 Server Access Logging設定を変更できる |
| `ec2:CreateFlowLogs` | ログ量・料金に影響する |
| `ec2:DeleteFlowLogs` | 通信ログ取得を停止できる |
| `events:PutRule` / `events:PutTargets` | 通知や自動対応を作成できる |
| `cloudwatch:PutMetricAlarm` | アラート発報に影響する |
| `sns:SetTopicAttributes` | 通知Topic Policyを変更できる |

## 8. 権限不足時の伝え方

権限不足時は、単に「権限がありません」ではなく、以下の3点をセットで伝える。

- 不足しているAPI
- そのAPIで確認・変更したい内容
- 影響する要件番号

例:

```text
cloudtrail:GetEventSelectors が不足しているため、
TrailでManagement Event/Data Eventの記録対象を確認できません。
4.1〜4.15の監視設定設計に必要なため、参照権限の追加可否を確認したいです。
```

例:

```text
kms:GetKeyPolicy が不足しているため、
CloudTrailログ用CMKのKey Policyを確認できません。
3.5、3.6、4.7の設計確認に必要です。
```

例:

```text
events:ListRules が不足しているため、
既存EventBridge Ruleの有無を確認できません。
既存通知との重複確認に必要です。
```

## 9. リーダーへ確認する短い文面

```text
AWS CLIで現状調査と証跡取得を行うため、まず参照系権限の範囲を確認したいです。
CloudTrail、CloudWatch Logs、Metric Filter、Alarm、SNS、KMS、VPC Flow Logs、GuardDuty、Organizationsあたりを確認する必要があります。
変更系権限は、作業手順と承認が確定した項目に限定して確認します。
```

もう少し具体的に言う場合:

```text
最初はReadOnly相当で構いませんが、CloudTrail、CloudWatch Logs、CloudWatch Alarm、SNS、KMS、EC2/VPC、GuardDuty、Organizationsの参照権限が必要になりそうです。
権限不足が出た場合は、不足API名と影響する要件番号を整理して相談します。
```

## 10. まとめ

最初に必要なのは、強い変更権限ではなく、広めの参照権限である。
現状調査ができれば、既存設定、重複通知、KMS設計、VPC Flow Logsの状態を把握できる。

変更権限は、以下のように段階的に確認する。

```text
1. 参照系権限で現状調査
2. 設定変更が必要な項目を特定
3. 作業手順・切り戻し手順・テスト方法を作成
4. 必要な変更権限を要件単位で確認
5. 承認後に変更作業
```

