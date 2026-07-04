# AWS CLI利用リファレンス

このメモは、現場でAWS CLIを使えるようになった場合に備えた確認用である。
目的は、GUI操作を否定することではなく、GUIでの画面確認とCLIでの設定値取得を組み合わせて、確認漏れや転記ミスを減らすことである。

## 1. 現場での基本姿勢

最初から変更作業をCLIで実施したい、と言うよりも、まずは参照系の確認と証跡取得で使いたい、と伝える。

現場向けの言い方:

```text
GUIでの画面確認とスクリーンショット取得は行います。
併せて、設定値の確認や変更前後の証跡取得はAWS CLIでJSON出力を保存したいです。
変更系コマンドの実行は、現場の作業手順・承認ルールに従います。
```

より短く言う場合:

```text
まずは参照系APIの確認と証跡取得でAWS CLIを使いたいです。
変更作業については、承認された手順に合わせます。
```

## 2. AWS CLIを使いたい理由

CLIを使う主な理由は、作業を速くすることだけではない。
監査対応では、再現性と証跡が重要になる。

- 設定値をJSONで保存できる
- 変更前後の差分を取りやすい
- 複数アカウント、複数リージョン、複数リソースを同じ手順で確認できる
- GUIの見落としや転記ミスを減らせる
- 作業結果を手順書や報告書に転記しやすい
- 権限不足時に、不足しているAPI名を明確に伝えられる

## 3. 最初に確認すること

CLI利用の可否を確認する。

```text
AWS CLIの利用は可能でしょうか。
可能な場合、参照系の確認と証跡取得に使いたいです。
```

利用端末を確認する。

```text
作業端末はWindowsで、PowerShell利用が標準でしょうか。
Git Bashの利用も可能でしょうか。
```

認証方式を確認する。

```text
CLIの認証方式は、SSO、SAML、一時クレデンシャル、アクセスキーのどれになりますか。
```

変更操作の扱いを確認する。

```text
参照系コマンドはCLIで実行してよい認識でよいでしょうか。
変更系コマンドは、承認済み手順に記載されたもののみ実行する認識でよいでしょうか。
```

証跡保存先を確認する。

```text
CLIで取得したJSONやスクリーンショットは、どのフォルダに保存すればよいでしょうか。
ファイル命名規則があれば合わせます。
```

## 4. AWS CLI利用に必要な情報

現場からもらう、または確認する情報は以下。

| 項目 | 例 | 確認理由 |
|---|---|---|
| AWSアカウントID | `123456789012` | 作業対象アカウントの確認 |
| アカウント名 | `prod-a` | 複数アカウントの取り違え防止 |
| リージョン | `ap-northeast-1` | コマンド実行先 |
| プロファイル名 | `resona-prod-a` | CLI実行時の指定 |
| 認証方式 | SSO / SAML / 一時認証情報 / アクセスキー | `.aws`設定方法が変わる |
| 操作権限 | ReadOnly / 一部変更可 / 変更可 | 実行可能範囲の確認 |
| MFA要否 | 必要 / 不要 | ログイン・セッション取得に影響 |
| プロキシ要否 | あり / なし | 社内端末でCLI通信に影響 |
| 証跡保存先 | 共有フォルダなど | 成果物格納先 |
| 通知先 | SNS / メール / Teams / 監視製品 | アラート設定で必要 |
| KMSキー情報 | Key ARN / Alias / Key Policy要件 | カスタマー管理キー化、鍵管理、監査対応で必要 |

## 5. `.aws`ディレクトリ

AWS CLIは通常、ユーザーのホームディレクトリ配下にある `.aws` ディレクトリを参照する。

Windowsの場合:

```text
C:\Users\<ユーザー名>\.aws\config
C:\Users\<ユーザー名>\.aws\credentials
```

Git BashやLinux風に見る場合:

```text
~/.aws/config
~/.aws/credentials
```

macOSやLinuxの場合:

```text
~/.aws/config
~/.aws/credentials
```

重要:

- `credentials` には秘密情報が入ることがある
- Git管理しない
- Teamsやメールに貼らない
- スクリーンショットに写さない
- 不要になった一時認証情報は削除する

## 6. `.aws/config`テンプレート

### 6.1 通常プロファイル

```ini
[profile project-dev]
region = ap-northeast-1
output = json
```

使い方:

```bash
aws sts get-caller-identity --profile project-dev --region ap-northeast-1 --output json --no-cli-pager
```

### 6.2 SSOの場合

現場がIAM Identity Centerを利用している場合は、SSO形式になることがある。

```ini
[profile project-dev]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_account_id = 123456789012
sso_role_name = ReadOnlyRole
region = ap-northeast-1
output = json
```

ログイン例:

```bash
aws sso login --profile project-dev
aws sts get-caller-identity --profile project-dev --output json --no-cli-pager
```

### 6.3 AssumeRoleの場合

手元の認証情報から別Roleを引き受ける場合。

```ini
[profile base]
region = ap-northeast-1
output = json

[profile project-prod]
role_arn = arn:aws:iam::123456789012:role/OperationReadOnlyRole
source_profile = base
region = ap-northeast-1
output = json
```

確認例:

```bash
aws sts get-caller-identity --profile project-prod --output json --no-cli-pager
```

## 7. `.aws/credentials`テンプレート

### 7.1 長期アクセスキーの場合

長期アクセスキーを利用する場合。
ただし、金融系現場では長期アクセスキーより、SSO、SAML、一時認証情報の方が自然である。

```ini
[project-dev]
aws_access_key_id = AKIAxxxxxxxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 7.2 一時認証情報の場合

STSやSAML連携で一時認証情報を受け取る場合。

```ini
[project-dev]
aws_access_key_id = ASIAxxxxxxxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
aws_session_token = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

一時認証情報では `aws_session_token` が必要になる。
これがないと認証エラーになる。

## 8. 最初に実行する疎通確認

### 8.1 AWS CLIのバージョン確認

Bash / Git Bash:

```bash
aws --version
```

PowerShell:

```powershell
aws --version
```

### 8.2 自分が誰としてログインしているか確認

Bash / Git Bash:

```bash
PROFILE_NAME="project-dev"
REGION="ap-northeast-1"

aws sts get-caller-identity \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

PowerShell:

```powershell
$ProfileName = "project-dev"
$Region = "ap-northeast-1"

aws sts get-caller-identity `
  --profile $ProfileName `
  --region $Region `
  --output json `
  --no-cli-pager
```

見るポイント:

- `Account` が対象アカウントか
- `Arn` が想定ユーザーまたは想定Roleか
- 本番、検証、開発を取り違えていないか

## 9. 参照系の確認コマンド例

### 9.1 CloudTrail

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager
```

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --trail-name "<trail-name>" \
  --output json \
  --no-cli-pager
```

### 9.2 CloudWatch Logs

```bash
aws logs describe-log-groups \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 9.3 EventBridge

```bash
aws events list-rules \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 9.4 S3

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "<bucket-name>" \
  --output json \
  --no-cli-pager
```

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --bucket "<bucket-name>" \
  --output json \
  --no-cli-pager
```

### 9.5 VPC Flow Logs

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 9.6 NACL

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 9.7 Route Table

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 9.8 GuardDuty

```bash
aws guardduty list-detectors \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

```bash
aws guardduty get-detector \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --detector-id "<detector-id>" \
  --output json \
  --no-cli-pager
```

### 9.9 KMS

現場ではCMKと呼ばれることがあるが、AWS公式では現在「KMSキー」「カスタマー管理キー」という表現が中心である。

```bash
aws kms list-keys \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

```bash
aws kms list-aliases \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

```bash
aws kms describe-key \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "<key-id-or-key-arn-or-alias-name>" \
  --output json \
  --no-cli-pager
```

```bash
aws kms get-key-policy \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --key-id "<key-id-or-key-arn-or-alias-name>" \
  --policy-name default \
  --output json \
  --no-cli-pager
```

見るポイント:

- `KeyManager` が `CUSTOMER` ならカスタマー管理キー
- `KeyManager` が `AWS` ならAWS managed key
- `KeyState` が `Enabled` か
- `DeletionDate` がないか
- Key Policyで管理者と利用者が適切に分かれているか
- Rotationが監査要件に合うか

## 10. 変更検知で見る代表的なCloudTrailイベント名

### 10.1 S3 Bucket Policy

| 操作 | CloudTrail EventName |
|---|---|
| Bucket Policy設定・更新 | `PutBucketPolicy` |
| Bucket Policy削除 | `DeleteBucketPolicy` |

### 10.2 NACL

| 操作 | CloudTrail EventName |
|---|---|
| NACL作成 | `CreateNetworkAcl` |
| NACL削除 | `DeleteNetworkAcl` |
| NACL Entry作成 | `CreateNetworkAclEntry` |
| NACL Entry変更 | `ReplaceNetworkAclEntry` |
| NACL Entry削除 | `DeleteNetworkAclEntry` |
| Subnet関連付け変更 | `ReplaceNetworkAclAssociation` |

### 10.3 Route Table

| 操作 | CloudTrail EventName |
|---|---|
| Route Table作成 | `CreateRouteTable` |
| Route Table削除 | `DeleteRouteTable` |
| Route作成 | `CreateRoute` |
| Route変更 | `ReplaceRoute` |
| Route削除 | `DeleteRoute` |
| Route Table関連付け | `AssociateRouteTable` |
| Route Table関連付け変更 | `ReplaceRouteTableAssociation` |
| Route Table関連付け解除 | `DisassociateRouteTable` |

### 10.4 VPC Flow Logs

| 操作 | CloudTrail EventName |
|---|---|
| Flow Logs作成 | `CreateFlowLogs` |
| Flow Logs削除 | `DeleteFlowLogs` |

### 10.5 KMS

| 操作 | CloudTrail EventName |
|---|---|
| KMSキー作成 | `CreateKey` |
| Key Policy変更 | `PutKeyPolicy` |
| KMSキー無効化 | `DisableKey` |
| KMSキー有効化 | `EnableKey` |
| KMSキー削除予約 | `ScheduleKeyDeletion` |
| KMSキー削除予約キャンセル | `CancelKeyDeletion` |
| 自動Rotation有効化 | `EnableKeyRotation` |
| 自動Rotation無効化 | `DisableKeyRotation` |
| Alias作成 | `CreateAlias` |
| Alias変更 | `UpdateAlias` |
| Alias削除 | `DeleteAlias` |
| Grant作成 | `CreateGrant` |
| Grant終了・取り消し | `RetireGrant` / `RevokeGrant` |

## 11. EventBridgeで検知する場合の考え方

CloudTrailのManagement EventをEventBridgeで拾い、SNSやメール、監視製品へ通知する構成が多い。

例: S3 Bucket Policy変更検知のEvent Pattern

```json
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutBucketPolicy", "DeleteBucketPolicy"]
  }
}
```

例: Route Table変更検知のEvent Pattern

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": [
      "CreateRoute",
      "ReplaceRoute",
      "DeleteRoute",
      "AssociateRouteTable",
      "ReplaceRouteTableAssociation",
      "DisassociateRouteTable"
    ]
  }
}
```

例: NACL変更検知のEvent Pattern

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": [
      "CreateNetworkAcl",
      "DeleteNetworkAcl",
      "CreateNetworkAclEntry",
      "ReplaceNetworkAclEntry",
      "DeleteNetworkAclEntry",
      "ReplaceNetworkAclAssociation"
    ]
  }
}
```

例: KMSキー管理変更検知のEvent Pattern

```json
{
  "source": ["aws.kms"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["kms.amazonaws.com"],
    "eventName": [
      "CreateKey",
      "PutKeyPolicy",
      "DisableKey",
      "ScheduleKeyDeletion",
      "EnableKeyRotation",
      "DisableKeyRotation",
      "CreateAlias",
      "UpdateAlias",
      "DeleteAlias"
    ]
  }
}
```

## 12. 権限不足時の伝え方

権限不足が出た場合は、単に「できません」と言わない。
次の3点をセットで伝える。

- 不足しているAPI
- そのAPIが必要な理由
- 影響するタスク

例:

```text
cloudtrail:GetEventSelectors が不足しているため、
TrailでManagement Event/Data Eventの記録対象を確認できません。
CloudTrail設定確認タスクに影響するため、参照権限の追加可否を確認したいです。
```

別例:

```text
ec2:DescribeFlowLogs が不足しているため、
VPC Flow Logsの有効化状況を確認できません。
Flow Logs有効化タスクの事前確認に必要です。
```

変更系権限が不足している場合:

```text
参照はできていますが、変更系APIの権限が不足しています。
実施可否と作業者を確認したうえで、必要であれば権限申請します。
```

## 13. PowerShellとGit Bashの違い

### 13.1 改行継続

Bash / Git Bash:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE_NAME" \
  --output json \
  --no-cli-pager
```

PowerShell:

```powershell
aws sts get-caller-identity `
  --profile $ProfileName `
  --output json `
  --no-cli-pager
```

PowerShellの改行継続はバッククォートである。
日本語キーボードでは見落としやすいので、短いコマンドなら1行で実行してもよい。

### 13.2 変数

Bash / Git Bash:

```bash
PROFILE_NAME="project-dev"
echo "$PROFILE_NAME"
```

PowerShell:

```powershell
$ProfileName = "project-dev"
Write-Output $ProfileName
```

### 13.3 環境変数

Bash / Git Bash:

```bash
export AWS_PROFILE="project-dev"
```

PowerShell:

```powershell
$env:AWS_PROFILE = "project-dev"
```

### 13.4 grep相当

Bash / Git Bash:

```bash
aws events list-rules --output json --no-cli-pager | grep "GuardDuty"
```

PowerShell:

```powershell
aws events list-rules --output json --no-cli-pager | Select-String "GuardDuty"
```

## 14. 証跡ファイルの作り方

変更前、変更後、確認結果を分ける。

例:

```text
evidence/
  20260704_s3_bucket_policy_alert/
    before/
    change/
    after/
    screenshots/
    report/
```

CLI出力保存例:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > evidence/20260704_cloudtrail_check/before/01_describe_trails.json
```

PowerShellでの保存例:

```powershell
aws cloudtrail describe-trails `
  --profile $ProfileName `
  --region $Region `
  --include-shadow-trails `
  --output json `
  --no-cli-pager `
  > evidence\20260704_cloudtrail_check\before\01_describe_trails.json
```

## 15. 現場でよく聞くべき確認事項

```text
このタスクは設定変更まで実施しますか。それとも現状確認と手順書作成までですか。
```

```text
通知先は既存のSNS、メール、Teams、監視製品のどれを使いますか。
```

```text
既存のEventBridge RuleやCloudWatch Alarmの命名規則はありますか。
```

```text
CloudTrailはOrganization Trailですか。アカウント単位のTrailですか。
```

```text
ログ保存先はCloudWatch Logsですか。S3ですか。保持期間の指定はありますか。
```

```text
作業証跡として、CLIのJSON出力と画面スクリーンショットの両方を残す認識でよいですか。
```

```text
変更後の確認観点と、切り戻し条件は決まっていますか。
```

## 16. 注意事項

- 本番環境でCLIを使う場合、プロファイルとリージョンの取り違えに注意する
- 変更系コマンドは承認前に実行しない
- `--dry-run` が使えるサービスでは事前確認に使う
- `--output table` は見やすいが、証跡としては `--output json` の方が扱いやすい
- `--no-cli-pager` を付けて、pagerで止まらないようにする
- 認証情報やアクセストークンをGit管理しない
- 手順書には秘密情報を載せない

## 17. 現場での一言まとめ

```text
GUIで画面確認しつつ、CLIで設定値をJSON保存して証跡にします。
変更系は承認済み手順に合わせ、まずは参照系から確認します。
```
