# Day 18 Learning: AWSセキュリティ横断チェック

## 学習開始前に実行するスクリプト

Day 18はS3、VPC、EC2、RDS、CloudWatchなどを横断確認するハンズオンである。`sample-vpc`が存在しない場合は最初に日次ラボ環境を構築する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

アプリケーション状態とアプリログも横断確認へ含める場合は、Ansibleも実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

CloudTrail一時Trail、CloudWatch Logs連携、GuardDuty Detectorなどは既存状態を評価する。Day 18のためだけに作成・有効化しない。S3 Data Eventも有効化しない。

横断確認の入口として、アカウント、S3、VPC、EC2、RDSを先に一覧で見る。

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager

aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

学習終了後は`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

## 1. 今日の目的

AWS環境をサービス単位で個別に見るのではなく、外部公開、認証認可、暗号化、監査ログ、検知、復旧の観点で横断確認する。

```text
外部公開されていないか
  -> S3 / VPC / EC2 / RDS / Lambda

誰が何をできるか
  -> IAM / Resource Policy / Security Group

データが保護されているか
  -> S3 / EBS / RDS / KMS / Secrets

変更と異常を追跡できるか
  -> CloudTrail / CloudWatch / GuardDuty / Flow Logs

事故時に復旧・説明できるか
  -> Backup / Versioning / 証跡 / 報告
```

本ドリルでは、[AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)を入口として、CriticalとHighの確認項目を優先する。

設定変更は行わない。Webコンソールと読み取り専用AWS CLIで現在状態を確認し、良好、改善候補、要確認、対象なしに分類する。

関連資料:

- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [共通AWS CLI・証跡保存リファレンス](../docs/references/00_common_aws_cli_reference.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [GuardDuty CLIリファレンス](../docs/references/05_guardduty_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [RDS Security CLIリファレンス](../docs/references/09_rds_security_cli_reference.md)
- [Lambda Security CLIリファレンス](../docs/references/10_lambda_security_cli_reference.md)
- [Day 15 EC2・RDS Security確認](./15_Day_Learning.md)
- [Day 16 Lambda Security確認](./16_Day_Learning.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)

---

## 2. 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象AWS環境について、セキュリティ設定をサービス横断で確認してください。

CriticalおよびHighに該当する項目を優先し、
現在状態、良好な設定、改善候補、影響調査が必要な項目を整理してください。

不足している証跡と追加確認事項も報告してください。
本日は設定変更を実施しないでください。
```

## 今日の確認順序

1. AWSアカウント、実行主体、リージョンを確認する
2. 対象環境と確認対象サービスを確定する
3. Critical / Highの判定基準を確認する
4. IAMとRoot User保護を確認する
5. CloudTrailと監査ログを確認する
6. GuardDutyとFindingを確認する
7. S3の公開防止、Policy、暗号化を確認する
8. VPC、Route、Security Group、Flow Logsを確認する
9. EC2の公開状態、IAM Role、IMDSv2、EBS暗号化を確認する
10. RDSの公開状態、暗号化、Backupを確認する
11. Lambdaの公開経路、Role、秘密情報を確認する
12. CloudWatch Logs、Metric Filter、Alarmを確認する
13. KMSとSecretsの利用状況を確認する
14. Critical / High項目を分類する
15. 不足証跡、影響調査、報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象環境 | 個人ラボAWS環境 |
| 優先度 | Critical / High |
| 設定変更 | なし |
| AWS CLI | 読み取り専用コマンドのみ |
| 主な成果物 | セキュリティ横断チェック結果、改善候補一覧、不足証跡一覧 |

## 今日実行しない操作

- IAM User、Role、Policy、Access Key、MFAの変更
- CloudTrail、CloudWatch、GuardDutyの有効化・無効化・設定変更
- S3 Bucket Policy、Public Access Block、暗号化の変更
- VPC、Route Table、Security Group、Network ACL、Flow Logsの変更
- EC2、RDS、Lambda、KMS、Secrets Managerの設定変更
- GuardDuty Sample Findingの生成
- 本番環境を想定した設定値への変更
- 承認されていない診断、疎通、負荷試験

---

## 3. 横断確認の考え方

個別サービスの設定が良好でも、関連する別サービスの設定によってリスクが残る場合がある。

```text
S3 Bucket Policyが非Public
  + Bucket-level Public Access Blockが有効
  + IAM権限が最小
  + CloudTrail Data Eventが必要に応じて有効
  + 暗号化とVersioning
  = S3全体の安全性を説明しやすい
```

```text
RDS PubliclyAccessible=false
  + Private Subnet
  + Route Table
  + Security Group
  + 暗号化
  + Backup
  + ログ
  = RDS全体の安全性を説明しやすい
```

単一設定だけで「安全」と断定しない。

## 確認する6つの軸

| 軸 | 主な質問 |
|---|---|
| 公開範囲 | Internet、別Account、不要なPrincipalから到達できないか |
| 認証認可 | 誰が何を実行できるか、過剰権限がないか |
| データ保護 | 保存時・通信時暗号化、秘密情報管理が適切か |
| 監査 | 変更履歴、アクセス履歴、ログ保持が十分か |
| 検知 | 異常をFinding、Alarm、通知で把握できるか |
| 復旧 | Backup、Versioning、切り戻し、手順があるか |

---

## 4. 重要度と判定区分

## 重要度

| 重要度 | 意味 | 例 |
|---|---|---|
| Critical | 重大事故や情報漏えいへ直接つながる可能性 | S3 Public、RDS Public、CloudTrail停止、無条件管理者権限 |
| High | 侵害時の影響拡大、監査不備、データ保護不備 | 暗号化なし、GuardDuty無効、Backupなし |
| Medium | 調査困難、運用リスク、将来の障害につながる | Log Retention未設定、タグ不足 |
| Low | 標準化や文書整備の改善候補 | 命名規則、証跡配置 |

## 今日使用する判定区分

| 判定 | 意味 |
|---|---|
| 良好 | 現在設定が期待値を満たす |
| 改善候補 | 変更を検討する価値がある |
| 要確認 | 要件、利用状況、影響範囲が不明で判断できない |
| 対象なし | サービスまたは機能を現在利用していない |
| 確認不可 | 権限不足、環境制約、証跡不足で確認できない |

重要:

```text
ラボで無効
  !=
金融本番でも無効でよい

本番で一般的に推奨
  !=
影響調査なしで直ちに変更してよい
```

---

## 5. 作業開始条件と中止条件

## 作業開始条件

- 対象AWSアカウントIDが明確である
- 対象リージョンが明確である
- 読み取り専用確認である
- 対象サービスと確認範囲が合意されている
- 証跡保存先が準備されている
- 個人ラボの費用優先設定と本番期待値を分けて評価する

## 作業中止・確認条件

- Caller Identityが想定アカウントと一致しない
- 読み取り専用確認中に設定変更が必要になった
- Critical設定を発見したが、利用要件を確認できない
- IAM PolicyやResource Policyの内容を取得できない
- 秘密情報の値を証跡へ保存しようとしている
- 複数Accountまたは複数Regionの確認範囲が不明である

## 即時共有する状態

- S3、RDS、EC2、Lambdaなどが意図せず外部公開されている
- CloudTrailが停止している、または重要ログを追跡できない
- 無条件の`Principal=*` Allowや管理者権限がある
- GuardDutyに未対応のHighまたはCritical Findingがある
- 暗号化されていない重要データがある
- Access Key、Password、Tokenなどが平文保存されている
- 重要データのBackupまたは復旧手段がない

---

## 6. 作業用変数と証跡保存先

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

VPC_NAME="sample-vpc"
BUCKET_NAME="nobu-terraform-iac-lab-upload"
RDS_INSTANCE_ID="sample-db"

WORK_NAME="aws_security_cross_service_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"
```

```bash
mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/01_iam" \
  "$EVIDENCE_DIR/02_cloudtrail" \
  "$EVIDENCE_DIR/03_guardduty" \
  "$EVIDENCE_DIR/04_s3" \
  "$EVIDENCE_DIR/05_vpc" \
  "$EVIDENCE_DIR/06_ec2" \
  "$EVIDENCE_DIR/07_rds" \
  "$EVIDENCE_DIR/08_lambda" \
  "$EVIDENCE_DIR/09_cloudwatch" \
  "$EVIDENCE_DIR/10_kms_secrets" \
  "$EVIDENCE_DIR/screenshots" \
  "$EVIDENCE_DIR/report"
```

変数確認:

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nBUCKET_NAME=%s\nRDS_INSTANCE_ID=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" "$BUCKET_NAME" "$RDS_INSTANCE_ID" "$EVIDENCE_DIR"
```

---

## 7. AWSアカウントと対象範囲の確認

## Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. 東京リージョンを選択する
4. Resource Explorerまたは各サービス画面で対象サービスを確認する
5. 設定変更画面の「編集」は押さない

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_対象リージョン確認.png
03_対象サービス一覧.png
```

## AWS CLI

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

想定Account IDとの一致確認:

```bash
ACTUAL_ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACTUAL_ACCOUNT_ID" = "$EXPECTED_ACCOUNT_ID" ]; then
  echo "OK: AWS account matches."
else
  echo "ERROR: Unexpected AWS account: $ACTUAL_ACCOUNT_ID" >&2
fi
```

判定:

| 結果 | 対応 |
|---|---|
| Account ID一致 | 確認を継続する |
| Account ID不一致 | 作業を中止して共有する |
| ARNが想定外Role/User | 権限と作業主体を確認する |

---

## 8. 横断チェック結果表を先に準備する

調査開始前に記録表を準備し、確認漏れを防ぐ。

| No. | サービス | 確認項目 | 重要度 | 現在値 | 判定 | 証跡 | 改善候補・要確認 |
|---:|---|---|---|---|---|---|---|
| 1 | IAM | Root MFA | Critical |  |  |  |  |
| 2 | IAM | 管理者権限・Access Key | Critical / High |  |  |  |  |
| 3 | CloudTrail | Trail有効・停止なし | Critical |  |  |  |  |
| 4 | GuardDuty | Detector・Finding | High |  |  |  |  |
| 5 | S3 | Public Access・Policy | Critical |  |  |  |  |
| 6 | S3 | 暗号化・Versioning | High / Medium |  |  |  |  |
| 7 | VPC | Public経路・SG・Flow Logs | High |  |  |  |  |
| 8 | EC2 | Public IP・IMDSv2・EBS | High |  |  |  |  |
| 9 | RDS | Public・暗号化・Backup | Critical / High |  |  |  |  |
| 10 | Lambda | Function URL・Role・秘密情報 | High |  |  |  |  |
| 11 | CloudWatch | Logs・Alarm・Retention | High |  |  |  |  |
| 12 | KMS / Secrets | Key・秘密情報管理 | High |  |  |  |  |

判定順序:

```text
現在値を確認する
  -> 期待値と比較する
  -> 利用要件と影響を確認する
  -> 良好 / 改善候補 / 要確認 / 対象なし / 確認不可へ分類する
  -> 証跡と報告文を紐づける
```

---

## 9. IAMとRoot User保護の確認

IAMは全サービスへ影響するため最初に確認する。

## Webコンソール

1. IAM Dashboardを開く
2. Security Recommendationsを確認する
3. Root User MFAの状態を確認する
4. IAM User、Role、Policyの件数を確認する
5. Access AnalyzerのFinding有無を確認する
6. Access Keyの値そのものは表示・保存しない

取得するスクリーンショット:

```text
04_IAM_Dashboard確認.png
05_IAM_Security_Recommendations確認.png
06_Access_Analyzer確認.png
```

## AWS CLI

Account Summary:

```bash
aws iam get-account-summary \
  --profile "$PROFILE" \
  --query 'SummaryMap.{AccountMFAEnabled:AccountMFAEnabled,Users:Users,Groups:Groups,Roles:Roles,Policies:Policies,AccountAccessKeysPresent:AccountAccessKeysPresent}' \
  --output table \
  --no-cli-pager
```

IAM User一覧:

```bash
aws iam list-users \
  --profile "$PROFILE" \
  --query 'Users[].{UserName:UserName,CreateDate:CreateDate,PasswordLastUsed:PasswordLastUsed}' \
  --output table \
  --no-cli-pager
```

IAM Role一覧:

```bash
aws iam list-roles \
  --profile "$PROFILE" \
  --query 'Roles[].{RoleName:RoleName,CreateDate:CreateDate,MaxSessionDuration:MaxSessionDuration}' \
  --output table \
  --no-cli-pager
```

Access Key Metadata:

```bash
aws iam list-access-keys \
  --profile "$PROFILE" \
  --user-name nobu \
  --query 'AccessKeyMetadata[].{AccessKeyId:AccessKeyId,Status:Status,CreateDate:CreateDate}' \
  --output table \
  --no-cli-pager
```

注意:

- Access Key IDも公開資料へ掲載しない
- Secret Access Keyは取得・記録しない
- `AccountMFAEnabled`はRoot User MFAの有効状態を示す
- IAM User名や利用形態が現場で許可されているか確認する

判定例:

| 確認項目 | 良好な状態 | 重要度 |
|---|---|---|
| Root MFA | 有効 | Critical |
| 日常作業でRoot不使用 | Rootを通常利用しない | Critical |
| IAM User | 必要最小限 | High |
| Access Key | 不要・未使用・古いKeyなし | High |
| Administrator権限 | 必要性、期限、承認が明確 | Critical |

---

## 10. CloudTrailの確認

CloudTrailがないと、誰が設定変更したかを追跡しにくい。

## Webコンソール

1. CloudTrailを開く
2. Trails一覧を確認する
3. 対象TrailのLogging状態を確認する
4. Multi-region、Log File Validation、S3保存先を確認する
5. CloudWatch Logs連携を確認する
6. Event Historyで直近イベントを確認する

取得するスクリーンショット:

```text
07_CloudTrail_Trail一覧.png
08_CloudTrail_Trail詳細.png
09_CloudTrail_Event_History.png
```

## AWS CLI

Trail一覧:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,IsMultiRegionTrail:IsMultiRegionTrail,LogFileValidationEnabled:LogFileValidationEnabled,S3BucketName:S3BucketName,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn}' \
  --output table \
  --no-cli-pager
```

Trail状態:

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "<trail-name>" \
  --query '{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError,LatestCloudWatchLogsDeliveryTime:LatestCloudWatchLogsDeliveryTime,LatestCloudWatchLogsDeliveryError:LatestCloudWatchLogsDeliveryError}' \
  --output table \
  --no-cli-pager
```

`<trail-name>`は`describe-trails`で確認したTrail名またはARNへ置き換える。

直近のS3 Policy変更:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --query 'Events[0:10].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

判定例:

| 状態 | 判定 |
|---|---|
| Trail有効、停止なし、保存先あり | 良好 |
| Event HistoryのみでTrailなし | CriticalまたはHighの改善候補 |
| Multi-region無効 | 要件と対象Regionを確認 |
| CloudWatch Logs連携なし | 検知要件に応じて改善候補 |
| Log File Validation無効 | 監査要件に応じて改善候補 |

---

## 11. GuardDutyの確認

## Webコンソール

1. GuardDutyを開く
2. Detectorの有効状態を確認する
3. Finding一覧を確認する
4. Severity、Resource、Account、Region、First Seen、Last Seenを確認する
5. FindingのArchiveや抑止は行わない

取得するスクリーンショット:

```text
10_GuardDuty_有効状態.png
11_GuardDuty_Finding一覧.png
```

## AWS CLI

Detector一覧:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager
```

Finding ID一覧:

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "<detector-id>" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output table \
  --no-cli-pager
```

`<detector-id>`はWebコンソールまたは`list-detectors`の結果へ置き換える。

判定例:

| 状態 | 判定 |
|---|---|
| Detector有効、未対応Findingなし | 良好 |
| Detector無効 | Highの改善候補 |
| High / Critical Findingあり | 即時共有 |
| Medium / Low Findingあり | 調査、誤検知判定、対応方針を整理 |
| 対象Regionのみ確認 | 他Region確認の要否を整理 |

---

## 12. S3セキュリティ確認

案件でS3 Bucket Policy変更が複数予定されているため、S3は最優先で確認する。

## Webコンソール

対象バケットの「アクセス許可」と「プロパティ」を開き、次を確認する。

- Bucket-level Public Access Block
- Bucket Policy
- Object Ownership
- ACL
- Default Encryption
- Versioning
- Server Access Logging

取得するスクリーンショット:

```text
12_S3_Public_Access_Block.png
13_S3_Bucket_Policy.png
14_S3_Object_Ownership_ACL.png
15_S3_Encryption_Versioning.png
```

## AWS CLI

Account-level Public Access Block:

```bash
aws s3control get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

`NoSuchPublicAccessBlockConfiguration`の場合は、Account-level設定が未設定である。Account内の全BucketとAccess Pointへ影響するため、影響調査なしで有効化しない。

Bucket-level Public Access Block:

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

Public判定:

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

Bucket Policy:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager
```

暗号化:

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

Versioning:

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query '{Status:Status,MFADelete:MFADelete}' \
  --output table \
  --no-cli-pager
```

ラボの想定:

| 項目 | 想定状態 | 判定 |
|---|---|---|
| Bucket-level Public Access Block | 4項目すべて`True` | 良好 |
| Policy Status | `IsPublic=False` | 良好 |
| Bucket Policy | HTTPS強制 | 良好 |
| Object Ownership | `BucketOwnerEnforced` | 良好 |
| Default Encryption | SSE-S3 / AES256 | 良好 |
| Versioning | 未設定 | ラボでは許容、本番では改善候補 |
| Server Access Logging | 未設定 | 監査要件を確認 |

---

## 13. VPCとネットワーク境界の確認

## Webコンソール

1. VPC一覧を確認する
2. `sample-vpc`のSubnetを確認する
3. Route Tableを確認する
4. Security Groupを確認する
5. Network ACLを確認する
6. VPC EndpointとFlow Logsを確認する

取得するスクリーンショット:

```text
16_VPC_Subnet一覧.png
17_Route_Table確認.png
18_Security_Group確認.png
19_VPC_Flow_Logs確認.png
```

## AWS CLI

VPC:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query 'Vpcs[].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,IsDefault:IsDefault}' \
  --output table \
  --no-cli-pager
```

Route Table:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=terraform-iac-lab" \
  --query 'RouteTables[].{RouteTableId:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],Routes:Routes}' \
  --output json \
  --no-cli-pager
```

Security Group:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=terraform-iac-lab" \
  --query 'SecurityGroups[].{GroupName:GroupName,GroupId:GroupId,VpcId:VpcId,IpPermissions:IpPermissions,IpPermissionsEgress:IpPermissionsEgress}' \
  --output json \
  --no-cli-pager
```

Network ACL:

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'NetworkAcls[].{NetworkAclId:NetworkAclId,VpcId:VpcId,IsDefault:IsDefault,Associations:Associations,Entries:Entries}' \
  --output json \
  --no-cli-pager
```

VPC Endpoint:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'VpcEndpoints[].{VpcEndpointId:VpcEndpointId,VpcId:VpcId,ServiceName:ServiceName,VpcEndpointType:VpcEndpointType,State:State,PrivateDnsEnabled:PrivateDnsEnabled}' \
  --output table \
  --no-cli-pager
```

Flow Logs:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter "Name=resource-type,Values=VPC" \
  --query 'FlowLogs[].{FlowLogId:FlowLogId,ResourceId:ResourceId,TrafficType:TrafficType,LogDestinationType:LogDestinationType,FlowLogStatus:FlowLogStatus}' \
  --output table \
  --no-cli-pager
```

確認点:

- Public SubnetとPrivate Subnetの役割
- `0.0.0.0/0` Routeの送信先
- SGの`0.0.0.0/0` Ingress
- DB PortがApplication SGだけから許可されるか
- Management Portの接続元制限
- Flow Logsの有効状態と保存先

---

## 14. EC2セキュリティ確認

## Webコンソール

対象Instanceごとに次を確認する。

- Public IPv4 Address
- Subnet、Security Group
- IAM Role
- Metadata Version
- EBS Volume暗号化

取得するスクリーンショット:

```text
20_EC2_Instance一覧.png
21_EC2_Network_Security確認.png
22_EC2_IAM_Role_IMDSv2確認.png
23_EC2_EBS暗号化確認.png
```

## AWS CLI

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=terraform-iac-lab" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,SecurityGroups:SecurityGroups[*].GroupId,IamInstanceProfile:IamInstanceProfile.Arn,HttpTokens:MetadataOptions.HttpTokens}' \
  --output table \
  --no-cli-pager
```

EBS:

```bash
aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=tag:Project,Values=terraform-iac-lab" \
  --query 'Volumes[].{VolumeId:VolumeId,Encrypted:Encrypted,KmsKeyId:KmsKeyId,State:State,Attachments:Attachments[*].InstanceId}' \
  --output table \
  --no-cli-pager
```

ラボの想定:

| 対象 | Public IP | IAM Role | IMDSv2 | 主な判定 |
|---|---|---|---|---|
| Bastion | あり | 原則なし | Required | 接続元制限を要確認 |
| Web01 | なし | Web Role | Required | 良好 |
| Web02 | なし | Web Role | Required | 良好 |

---

## 15. RDSセキュリティ確認

## Webコンソール

1. RDS DB Instanceを開く
2. Connectivity & Securityを確認する
3. Publicly Accessible、Subnet Group、Security Groupを確認する
4. Configurationで暗号化、Backup、Deletion Protectionを確認する
5. Logs & Eventsを確認する

取得するスクリーンショット:

```text
24_RDS_Connectivity_Security確認.png
25_RDS_Encryption_Backup確認.png
26_RDS_Logs確認.png
```

## AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$RDS_INSTANCE_ID" \
  --query 'DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,Engine:Engine,DBInstanceStatus:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,BackupRetentionPeriod:BackupRetentionPeriod,DeletionProtection:DeletionProtection,MultiAZ:MultiAZ,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcSecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId,EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports}' \
  --output table \
  --no-cli-pager
```

ラボの想定:

| 項目 | 想定状態 | 判定 |
|---|---|---|
| PubliclyAccessible | `False` | 良好 |
| DB Subnet Group | Private Subnet 2つ | 良好 |
| SG | Web SGからTCP 3306 | 良好 |
| StorageEncrypted | `True` | 良好 |
| BackupRetentionPeriod | `0` | ラボでは費用・削除優先、本番ではHigh改善候補 |
| DeletionProtection | `False` | ラボでは削除優先、本番ではHigh改善候補 |
| MultiAZ | `False` | 可用性要件を確認 |
| Logs Export | 未設定の可能性 | 監査・運用要件を確認 |

---

## 16. Lambdaセキュリティ確認

個人ラボではLambda Functionが0件の可能性がある。0件でも確認結果として記録する。

## Webコンソール

1. Lambda Function一覧を開く
2. Function件数を確認する
3. Functionがある場合はExecution Role、Trigger、Function URLを確認する
4. Environment Variablesの値を証跡へ残さない

取得するスクリーンショット:

```text
27_Lambda_Function一覧.png
```

## AWS CLI

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Functions[].{FunctionName:FunctionName,Runtime:Runtime,Role:Role,KMSKeyArn:KMSKeyArn,VpcId:VpcConfig.VpcId,LastModified:LastModified}' \
  --output table \
  --no-cli-pager
```

Function URL一覧:

```bash
aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'FunctionUrlConfigs[].{FunctionArn:FunctionArn,AuthType:AuthType,FunctionUrl:FunctionUrl}' \
  --output table \
  --no-cli-pager
```

判定:

| 状態 | 判定 |
|---|---|
| Function 0件 | 対象なし |
| Function URLなし | 公開経路なしとして記録 |
| Function URL `AWS_IAM` | 権限設定を追加確認 |
| Function URL `NONE` | HighまたはCriticalとして公開要件を即時確認 |
| Environment Variableに秘密情報 | High改善候補 |
| Execution Roleが過剰 | HighまたはCritical改善候補 |

---

## 17. CloudWatch Logs・Alarm確認

## Webコンソール

1. CloudWatch LogsのLog Group一覧を確認する
2. CloudTrail、VPC Flow Logs、Application、RDSなどのLog Groupを確認する
3. Retentionを確認する
4. Metric Filterを確認する
5. Alarm一覧と状態を確認する

取得するスクリーンショット:

```text
28_CloudWatch_Log_Group一覧.png
29_CloudWatch_Metric_Filter確認.png
30_CloudWatch_Alarm一覧.png
```

## AWS CLI

Log Group:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'logGroups[].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId}' \
  --output table \
  --no-cli-pager
```

Metric Filter:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'metricFilters[].{FilterName:filterName,LogGroupName:logGroupName,FilterPattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output json \
  --no-cli-pager
```

Alarm:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,StateValue:StateValue,ActionsEnabled:ActionsEnabled,MetricName:MetricName,Namespace:Namespace}' \
  --output table \
  --no-cli-pager
```

確認点:

- 重要ログが存在するか
- Retentionが未設定で無期限保存になっていないか
- KMS暗号化要件があるか
- MFAなしConsole Loginなどの検知があるか
- Alarm Actionが無効のままになっていないか
- 通知先と対応手順があるか

---

## 18. KMSとSecretsの確認

## Webコンソール

1. KMS Customer Managed Key一覧を確認する
2. Key State、Rotation、Key Policyを確認する
3. Secrets ManagerのSecret一覧を確認する
4. Secretの値は表示・保存しない

取得するスクリーンショット:

```text
31_KMS_Key一覧.png
32_Secrets_Manager一覧.png
```

## AWS CLI

KMS Alias:

```bash
aws kms list-aliases \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Aliases[].{AliasName:AliasName,TargetKeyId:TargetKeyId}' \
  --output table \
  --no-cli-pager
```

KMS Key一覧:

```bash
aws kms list-keys \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager
```

対象Keyの状態:

```bash
aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "<key-id-or-arn>" \
  --query 'KeyMetadata.{KeyId:KeyId,KeyManager:KeyManager,KeyState:KeyState,Enabled:Enabled,KeyUsage:KeyUsage,Origin:Origin,MultiRegion:MultiRegion}' \
  --output table \
  --no-cli-pager
```

Secrets一覧:

```bash
aws secretsmanager list-secrets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'SecretList[].{Name:Name,ARN:ARN,KmsKeyId:KmsKeyId,LastChangedDate:LastChangedDate,LastAccessedDate:LastAccessedDate}' \
  --output table \
  --no-cli-pager
```

注意:

- `get-secret-value`は実行しない
- Secret値をスクリーンショットへ含めない
- AWS Managed KeyとCustomer Managed Keyの使い分けを確認する
- Key Policy、IAM Policy、Grantを組み合わせて権限を判断する
- Key削除予定がある場合は即時共有する

---

## 19. Critical項目の抽出

確認結果から、最初にCritical候補を抽出する。

| No. | Critical候補 | 確認結果 | 即時対応 |
|---:|---|---|---|
| 1 | Root MFA無効 |  | 利用状況と有効化方針を確認 |
| 2 | 無条件の管理者権限 |  | Principal、用途、期限を確認 |
| 3 | CloudTrail停止・未構築 |  | 監査要件と有効化方針を確認 |
| 4 | S3 Public |  | Public要件と影響を即時確認 |
| 5 | RDS Public |  | 接続要件、SG、Subnetを即時確認 |
| 6 | Lambda認証なし公開 |  | Function用途と認証を即時確認 |
| 7 | KMS Key削除予定 |  | 利用サービスと復旧可否を即時確認 |
| 8 | 平文秘密情報・Credential露出 |  | 値の無効化、Rotation、報告手順を確認 |

Critical候補を見つけても、承認なしで設定を変更しない。事実、影響、緊急度、確認事項を整理して共有する。

---

## 20. High項目の抽出

| No. | High候補 | 確認結果 | 主な影響調査 |
|---:|---|---|---|
| 1 | GuardDuty無効 |  | 対象Account・Region、費用、運用担当 |
| 2 | S3 Versioningなし |  | 誤削除対策、容量、Lifecycle |
| 3 | Flow Logsなし |  | 保存先、費用、監視・調査用途 |
| 4 | EC2 EBS暗号化なし |  | Snapshot、再作成、停止時間 |
| 5 | RDS Backupなし |  | RPO、RTO、保持期間、費用 |
| 6 | RDS Deletion Protectionなし |  | 削除手順、運用自動化 |
| 7 | 過剰IAM Role |  | Application利用Action、Resource |
| 8 | CloudWatch Alarm・通知なし |  | 通知先、対応時間、運用体制 |
| 9 | 秘密情報Rotationなし |  | 利用Application、更新手順 |
| 10 | 重要ログRetention不明 |  | 監査期間、費用、削除要件 |

---

## 21. ラボ環境と金融本番の評価差

| 設定 | 個人ラボでの考え方 | 金融本番での考え方 |
|---|---|---|
| RDS Backup `0` | 日次削除と費用を優先 | RPO・RTOに基づく保持が必要 |
| RDS Deletion Protection無効 | Cleanupを優先 | 誤削除防止を検討 |
| Multi-AZ無効 | 費用を優先 | 可用性要件を確認 |
| Alarm Action無効 | 学習用に通知なし | 運用通知と対応手順が必要 |
| S3 Versioning無効 | 容量とCleanupを優先 | 誤削除・上書き対策を検討 |
| GuardDuty Sample Finding | 学習で生成可能 | 本番では承認と運用手順が必要 |
| Bastion Public IP | 学習接続用 | SSM、接続元制限、閉域経路を検討 |

報告では「設定が無効」という事実だけでなく、その環境での意図と本番要件との差を記載する。

---

## 22. 証跡不足の整理

次の表で、不足している証跡を明確にする。

| No. | 確認項目 | 必要な証跡 | 現在状態 | 取得方法 | 担当・期限 |
|---:|---|---|---|---|---|
| 1 | Root MFA | IAM Dashboard画面 |  | Webコンソール |  |
| 2 | CloudTrail状態 | Trail詳細、Status |  | GUI / CLI |  |
| 3 | GuardDuty Finding | Finding一覧 |  | GUI / CLI |  |
| 4 | S3 Public判定 | PAB、Policy Status |  | GUI / CLI |  |
| 5 | VPC公開経路 | Route、SG |  | GUI / CLI |  |
| 6 | RDS Backup | Configuration画面 |  | GUI / CLI |  |
| 7 | CloudWatch通知 | Alarm Action |  | GUI / CLI |  |
| 8 | KMS権限 | Key Policy |  | GUI / CLI |  |

証跡がない項目は「問題なし」と判定しない。`確認不可`または`要確認`として残す。

---

## 23. 影響調査が必要な項目

改善候補を見つけた場合は、変更前に次を確認する。

| 観点 | 確認内容 |
|---|---|
| 利用主体 | Application、運用者、Batch、連携先、別Account |
| 通信経路 | Internet、VPN、Direct Connect、VPC Endpoint、NAT |
| 認証認可 | IAM Role、User、Resource Policy、Security Group |
| データ | 種別、機密度、保存期間、暗号化 |
| 監査 | 必要ログ、保持期間、閲覧者 |
| 運用 | 通知先、対応時間、当番、手順 |
| 費用 | Logs、GuardDuty、Backup、KMS、Data Event |
| 切り戻し | 変更前設定、復元コマンド、復旧時間 |
| 試験 | Application動作、接続、ログ、Alarm、CloudTrail |

---

## 24. 横断チェック結果の記載例

```text
対象AWS環境について、Critical / Highを優先したセキュリティ横断確認を実施した。

良好:
- 対象S3バケットはBucket-level Public Access Blockの4項目が有効
- S3 Policy StatusはIsPublic=False
- Web EC2はPrivate Subnetに配置され、IMDSv2が必須
- RDSはPubliclyAccessible=FalseかつStorageEncrypted=True

改善候補:
- Account-level S3 Public Access Blockは未設定
- RDS Backup RetentionおよびDeletion Protectionは無効
- S3 Versioningは未設定
- Alarm Actionは学習用途のため無効

要確認:
- CloudTrail TrailとCloudWatch Logs連携の本番要件
- GuardDutyの対象Account・RegionとFinding対応運用
- VPC Flow Logsの保存・監査要件
- KMS Customer Managed KeyとSecrets Rotationの要否

本日は読み取り専用確認のみを実施し、設定変更は実施していない。
```

---

## 25. Teams向け報告例

```text
AWS環境のセキュリティ横断確認を実施しました。

S3の公開防止、EC2のPrivate配置・IMDSv2、RDSの非Public・暗号化は良好です。

一方、Account-level S3 Public Access Block、RDS Backup・Deletion Protection、
S3 Versioning、監視通知などは改善候補または要件確認事項として整理しました。

Criticalな外部公開は現時点で確認されていません。
不足証跡と追加確認事項を一覧化しています。
設定変更は実施していません。
```

Criticalを発見した場合:

```text
セキュリティ横断確認中にCritical候補を確認しました。

対象:
現在状態:
想定される影響:
確認済み証跡:
未確認事項:

設定変更は実施していない。影響と対応方針の確認が必要である。
```

---

## 26. よくある判断ミス

| 判断ミス | 正しい考え方 |
|---|---|
| Public IPがないため安全と判断する | Route、SG、ALB、VPN、別経路も確認する |
| `IsPublic=False`だけでS3を安全と判断する | IAM、Policy、ACL、Access Point、暗号化も確認する |
| `PubliclyAccessible=False`だけでRDSを安全と判断する | Subnet、Route、SG、認証も確認する |
| 暗号化済みなので安全と判断する | Key Policy、利用権限、通信、Backupも確認する |
| GuardDuty有効なので対応済みと判断する | Finding、通知、対応手順を確認する |
| CloudTrail Event HistoryがあるためTrail不要と判断する | 長期保存、全Region、検知連携を確認する |
| 対象サービス0件を確認漏れにする | `対象なし`として証跡と結果を残す |
| ラボ設定を本番の期待値として使う | 費用・Cleanupと本番要件を分ける |
| 推奨設定を影響調査なしで変更する | 利用要件、影響、試験、切り戻しを確認する |

---

## 27. トラブルシューティング

## AccessDenied

確認すること:

1. Caller Identity
2. 対象AccountとRegion
3. IAM Permission
4. SCP、Permissions Boundary、Session Policy
5. Resource Policy
6. 必要な閲覧権限の申請

`AccessDenied`を「対象なし」と扱わない。

## 対象サービスが0件

```text
対象なし
  -> 正常な確認結果

権限不足で一覧取得できない
  -> 確認不可
```

## Regionによって結果が異なる

GuardDuty、EC2、RDS、Lambda、CloudWatchなどはRegion単位で確認する。全Region確認が必要か、対象Regionだけでよいかを確認する。

## 出力が大きすぎる

- AWS CLIの`--query`で必要項目へ絞る
- GUIでは対象リソース単位で証跡を取得する
- 一覧証跡と詳細証跡を分ける
- 機密情報を含まないことを確認する

---

## 28. 案件で説明できるポイント

- Critical / Highを優先してAWS環境を横断確認できる
- 単一設定だけで安全性を断定しない
- S3、VPC、EC2、RDS、Lambdaの公開経路を関連付けて確認できる
- IAM PolicyとResource Policyの違いを意識できる
- CloudTrail、CloudWatch、GuardDutyの役割を分けて説明できる
- 暗号化設定だけでなくKMS権限も確認できる
- 対象なし、確認不可、改善候補を分けて報告できる
- ラボ設定と金融本番の期待値を分けて評価できる
- 改善候補を見つけても、影響調査なしで変更しない
- 不足証跡と要確認事項を明確にできる

---

## 29. 資格試験につながるポイント

- Shared Responsibility Model
- IAM最小権限、MFA、Role、Resource Policy
- CloudTrailの監査ログ
- CloudWatch Logs、Metric Filter、Alarm
- GuardDuty Findingと脅威検知
- S3 Public Access Block、Bucket Policy、暗号化
- VPC Route Table、Security Group、Network ACL、Flow Logs
- EC2 IMDSv2、IAM Role、EBS暗号化
- RDS PubliclyAccessible、暗号化、Backup、Multi-AZ
- Lambda Execution Role、Resource Policy、Function URL
- KMS Key Policy、Secrets Manager

---

## 30. 要確認事項

7月案件へ参画後、次を確認する。

- 対象AWSアカウントとRegionの一覧
- Critical / High / Mediumの現場定義
- セキュリティ基準、チェックシート、例外申請
- IAM Identity Center、IAM User、AssumeRoleの利用方式
- CloudTrailの組織Trail、保存先、保持期間
- GuardDutyの管理AccountとFinding対応フロー
- S3 Bucket Policy変更対象約20件の一覧
- VPC、EC2、RDS、Lambdaの対象範囲
- CloudWatch Alarmと通知先
- KMSと秘密情報管理の標準
- GUI証跡とCLI証跡の必要粒度
- Critical発見時の連絡先とエスカレーション方法

---

## 31. Day 18完了チェックリスト

### 作業前確認

- [ ] Caller Identityを確認した
- [ ] 対象Account、Region、サービスを確認した
- [ ] 読み取り専用確認であることを確認した
- [ ] 証跡保存先を準備した
- [ ] Critical / Highの判定基準を確認した

### 横断確認

- [ ] IAMとRoot MFAを確認した
- [ ] CloudTrailと監査ログを確認した
- [ ] GuardDutyとFindingを確認した
- [ ] S3の公開防止、Policy、暗号化を確認した
- [ ] VPC、Route、SG、Flow Logsを確認した
- [ ] EC2の公開状態、IAM Role、IMDSv2、EBSを確認した
- [ ] RDSの公開状態、暗号化、Backupを確認した
- [ ] Lambdaの利用状況と公開経路を確認した
- [ ] CloudWatch Logs、Metric Filter、Alarmを確認した
- [ ] KMSとSecretsの利用状況を確認した

### 結果整理

- [ ] 良好、改善候補、要確認、対象なし、確認不可へ分類した
- [ ] Critical候補を抽出した
- [ ] High候補を抽出した
- [ ] ラボと本番の期待値を分けた
- [ ] 不足証跡を整理した
- [ ] 影響調査が必要な項目を整理した
- [ ] 設定変更を実施していないことを記録した
- [ ] 報告文を作成した

## Day 18の完了条件

次を自分の言葉で説明できればDay 18は完了とする。

```text
AWSセキュリティ横断確認では、外部公開、認証認可、データ保護、
監査、検知、復旧の観点から複数サービスを確認する。

CriticalとHighを優先し、現在値を良好、改善候補、要確認、
対象なし、確認不可へ分類する。

S3のIsPublic=False、RDSのPubliclyAccessible=Falseなど、
単一設定だけで安全と断定せず、IAM、Policy、Route、SG、
暗号化、ログ、Backupを関連付けて判断する。

改善候補を見つけても直ちに変更せず、利用要件、影響範囲、
試験、切り戻し、証跡を整理して承認を得る。

個人ラボの費用・Cleanup優先設定と、
金融本番環境のセキュリティ期待値を分けて報告する。
```
