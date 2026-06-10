# 01 S3 セキュリティ設定 CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、Amazon S3バケットのセキュリティ設定をAWS CLIで確認するためのリファレンスである。

対象は、銀行系システムのように、S3の公開範囲、暗号化、ACL、ログ、バケットポリシー、Access Point、証跡取得が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- S3バケットの存在、リージョン、所有者確認
- Account / Bucket単位のBlock Public Access確認
- Bucket Policy StatusによるPublic判定
- ACLとObject Ownership確認
- デフォルト暗号化確認
- S3 Server Access Logging確認
- Versioning確認
- Website / CORS / Access Pointなどの公開リスク確認
- 変更前後の証跡保存
- S3セキュリティ設定変更時の注意点

Bucket Policyの詳細な変更、差分、切り戻しは、次のリファレンスで扱う。

```text
02_s3_bucket_policy_cli_reference.md
```

## 2. 参照する共通リファレンス

AWS CLIの基本操作、証跡保存、差分確認、終了コード、BashとPowerShellの違いは、以下を参照する。

[00 共通 AWS CLI・証跡保存リファレンス](./00_common_aws_cli_reference.md)

## 3. S3セキュリティ確認の全体像

S3のセキュリティ確認では、次の順番で見ると整理しやすい。

```text
アカウント確認
  ↓
対象バケット確認
  ↓
リージョン確認
  ↓
Account-level Block Public Access確認
  ↓
Bucket-level Block Public Access確認
  ↓
Bucket Policy Status確認
  ↓
Bucket Policy確認
  ↓
Object Ownership / ACL確認
  ↓
Default Encryption確認
  ↓
Versioning / Logging確認
  ↓
Website / CORS / Access Point確認
  ↓
IAM Role / KMS / CloudTrail確認
```

S3の公開可否は、1つの設定だけでは判断しない。

以下の組み合わせで確認する。

| 観点 | 主な確認コマンド |
| :--- | :--- |
| Account-level Block Public Access | `aws s3control get-public-access-block` |
| Bucket-level Block Public Access | `aws s3api get-public-access-block` |
| Public判定 | `aws s3api get-bucket-policy-status` |
| Bucket Policy | `aws s3api get-bucket-policy` |
| ACL | `aws s3api get-bucket-acl` |
| Object Ownership | `aws s3api get-bucket-ownership-controls` |
| Access Point | `aws s3control list-access-points` |
| Website Hosting | `aws s3api get-bucket-website` |
| CORS | `aws s3api get-bucket-cors` |

## 4. 重要な前提

### 4.1 S3バケット名はグローバルで一意

S3バケット名は、AWSアカウント内ではなく、全AWSアカウントでグローバルに一意である。

そのため、同じバケット名が存在する場合でも、自分のAWSアカウントのバケットとは限らない。

`head-bucket` に失敗した場合は、以下の可能性がある。

- バケットが存在しない
- バケットは存在するが別アカウント所有である
- 権限がない
- リージョンやエンドポイントが誤っている

### 4.2 S3はリージョンを持つが、一部操作はグローバルに見える

`list-buckets` はアカウント内のバケット一覧を返す。

一方、バケットそのものはリージョンを持つ。

設定変更や詳細確認では、対象バケットのリージョンを確認してから作業する。

### 4.3 Directory bucketsは対象外

このリファレンスは、通常のS3 general purpose bucketを対象にする。

S3 Express One Zoneのdirectory bucketでは、一部のS3 APIやエンドポイント指定が異なる。

実案件でdirectory bucketが出てきた場合は、別途確認する。

### 4.4 Public Access Blockだけで安全と判断しない

S3 Block Public Accessは非常に重要だが、以下もあわせて確認する。

- Bucket Policy
- Access Point Policy
- ACL
- Object Ownership
- IAM Policy
- VPC Endpoint Policy
- KMS Key Policy
- Organizations SCP / RCP

S3は複数のポリシーや設定が重なってアクセス可否が決まる。

## 5. 作業前の共通変数

### 5.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"
BUCKET="nobu-terraform-iac-lab-upload"
EXPECTED_ACCOUNT_ID="445405559057"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

EXPECTED_BUCKET_OWNER="$ACCOUNT_ID"
```

### 5.2 証跡ディレクトリ

```bash
WORK_NAME="s3_security_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/screenshots"
```

### 5.3 まずCaller Identityを保存する

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

確認:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

期待値:

- `Account` が作業対象アカウントである
- `Arn` が作業用IAMユーザーまたは作業用ロールである

## 6. S3確認のクイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | バケット存在 | アクセス可能 | `head-bucket` |
| 2 | バケットリージョン | 想定リージョン | `get-bucket-location` |
| 3 | Account-level BPA | 4項目true | `s3control get-public-access-block` |
| 4 | Bucket-level BPA | 4項目true | `s3api get-public-access-block` |
| 5 | Public判定 | `IsPublic=false` | `get-bucket-policy-status` |
| 6 | Bucket Policy | 想定Statementのみ | `get-bucket-policy` |
| 7 | Object Ownership | `BucketOwnerEnforced` | `get-bucket-ownership-controls` |
| 8 | ACL | Ownerのみ | `get-bucket-acl` |
| 9 | Default Encryption | SSE-S3またはSSE-KMS | `get-bucket-encryption` |
| 10 | Versioning | 要件どおり | `get-bucket-versioning` |
| 11 | Server Access Logging | 要件どおり | `get-bucket-logging` |
| 12 | Website Hosting | 原則未設定 | `get-bucket-website` |
| 13 | CORS | 必要最小限 | `get-bucket-cors` |
| 14 | Access Point | `NetworkOrigin`確認 | `s3control list-access-points` |
| 15 | Tags | 管理タグあり | `get-bucket-tagging` |

## 7. バケット一覧確認

### 7.1 aws s3api list-buckets

アカウント内で見えるS3バケット一覧を確認する。

```bash
aws s3api list-buckets \
  --profile "$PROFILE" \
  --query 'Buckets[*].{Name:Name,CreationDate:CreationDate}' \
  --output table
```

証跡保存:

```bash
aws s3api list-buckets \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/01_list_buckets.json"
```

確認ポイント:

- 想定外のバケットがないか
- 命名規則に沿っているか
- 不要な検証バケットが残っていないか
- メール受信、ログ保存、アップロード用など用途が分かるか

注意:

- バケット名から業務情報が推測できる場合がある
- 証跡や画面共有時の扱いは現場ルールに従う

## 8. バケット存在確認

### 8.1 aws s3api head-bucket

バケットが存在し、現在の認証情報でアクセスできるか確認する。

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER"
```

確認ポイント:

- 終了コード `0` ならアクセス可能
- 標準出力は通常表示されない
- 失敗時は存在しない、権限がない、別アカウント所有などを疑う

終了コード確認:

```bash
echo $?
```

証跡としては、成功時の画面または実行ログを残す。

JSON出力が必要な設定確認は、後続の `get-*` 系コマンドで取得する。

## 9. バケットリージョン確認

### 9.1 aws s3api get-bucket-location

対象バケットがどのリージョンに存在するか確認する。

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json
```

証跡保存:

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/02_bucket_location.json"
```

確認ポイント:

- `LocationConstraint` が想定リージョンであること
- `us-east-1` の場合、`LocationConstraint` が `null` または `None` として扱われる場合がある
- S3 Server Access Loggingの送信元と送信先バケットは同じリージョン、同じアカウントである必要がある

## 10. Account-level Block Public Access確認

### 10.1 aws s3control get-public-access-block

アカウント単位のBlock Public Access設定を確認する。

```bash
aws s3control get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --output table
```

証跡保存:

```bash
aws s3control get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/03_account_public_access_block.json"
```

確認ポイント:

| 項目 | 期待値 | 意味 |
| :--- | :--- | :--- |
| `BlockPublicAcls` | `true` | Public ACLの新規設定をブロックする |
| `IgnorePublicAcls` | `true` | 既存Public ACLを無視する |
| `BlockPublicPolicy` | `true` | Public Policyの設定をブロックする |
| `RestrictPublicBuckets` | `true` | Public Policyがあるバケットへのアクセスを制限する |

注意:

- Organization-levelのBlock Public Accessが適用されている場合、アカウント設定と組み合わせて評価される
- Bucket-level設定より、より制限的な組み合わせが適用される
- このコマンドはアカウント単位であり、個別バケットだけの状態ではない

## 11. Bucket-level Block Public Access確認

### 11.1 aws s3api get-public-access-block

対象バケットのBlock Public Access設定を確認する。

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/04_bucket_public_access_block.json"
```

期待値:

```json
{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}
```

確認ポイント:

- 4項目すべて `true` であること
- 例外的に公開バケットの場合は、公開理由、対象、承認、CloudFront利用有無を確認する
- Account-level設定とBucket-level設定の両方を確認する

エラー例:

```text
NoSuchPublicAccessBlockConfiguration
```

この場合、バケット単位のBlock Public Access設定が存在しない可能性がある。

ただし、Account-levelやOrganization-levelで保護されている場合もあるため、単独で判断しない。

## 12. Bucket Policy Status確認

### 12.1 aws s3api get-bucket-policy-status

S3が対象バケットをPublicと判定しているか確認する。

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/05_bucket_policy_status.json"
```

期待値:

```json
{
  "PolicyStatus": {
    "IsPublic": false
  }
}
```

確認ポイント:

- `IsPublic` が `false` であること
- `true` の場合は、Bucket Policy、Access Point Policy、ACL、Block Public Accessの設定を調査する
- Public Access Blockが有効でも、Bucket Policy Statusを確認する

注意:

- `IsPublic=false` でも、特定IAM Roleや特定AWSアカウントへの許可は存在し得る
- Publicでないことと、最小権限であることは別の観点である

## 13. Bucket Policy確認

### 13.1 aws s3api get-bucket-policy

対象バケットのBucket Policyを取得する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'Policy' \
  --output text
```

証跡保存:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/before/06_bucket_policy.json"
```

確認ポイント:

- `Principal: "*"` のAllowがないか
- `Action: "s3:*"` のAllowが広すぎないか
- `Resource` が対象バケットとオブジェクトに正しく分かれているか
- `aws:SecureTransport` によるHTTP拒否があるか
- 特定AWSアカウント、IAM Role、CloudFront、ログ配送先などの許可が想定どおりか
- VPC Endpointや送信元IPなどの条件が設計どおりか

エラー例:

```text
NoSuchBucketPolicy
```

バケットポリシーが未設定の場合に発生する。

未設定が正常かどうかは、バケット用途と要件で判断する。

詳細な差分、変更、切り戻しは、`02_s3_bucket_policy_cli_reference.md` で扱う。

## 14. Object Ownership確認

### 14.1 aws s3api get-bucket-ownership-controls

対象バケットのObject Ownership設定を確認する。

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/07_ownership_controls.json"
```

期待値の例:

```text
BucketOwnerEnforced
```

Object Ownershipの主な値:

| 値 | ACL | 意味 |
| :--- | :--- | :--- |
| `BucketOwnerEnforced` | 無効 | バケット所有者が全オブジェクトを所有し、ACLはアクセス制御に使われない |
| `BucketOwnerPreferred` | 有効 | `bucket-owner-full-control` ACL付きでアップロードされた場合、バケット所有者が所有 |
| `ObjectWriter` | 有効 | オブジェクトを書き込んだAWSアカウントが所有 |

確認ポイント:

- 原則として `BucketOwnerEnforced` が望ましい
- ACLを使う例外要件がある場合、その理由と影響範囲を確認する
- 外部アカウント連携やS3 Server Access Loggingとの関係を確認する

## 15. ACL確認

### 15.1 aws s3api get-bucket-acl

対象バケットのACLを確認する。

```bash
aws s3api get-bucket-acl \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-acl \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/08_bucket_acl.json"
```

確認ポイント:

- `AllUsers` への許可がないこと
- `AuthenticatedUsers` への許可がないこと
- 意図しない外部AWSアカウントへのGrantがないこと
- Object Ownershipが `BucketOwnerEnforced` の場合、ACLはアクセス制御に使われないこと

注意:

- ACL無効化方針の環境でも、読み取りACL結果は表示される場合がある
- 重要なのは、ACLがアクセス制御に使われているか、公開Grantが残っていないかである

## 16. デフォルト暗号化確認

### 16.1 aws s3api get-bucket-encryption

対象バケットのデフォルト暗号化設定を確認する。

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/09_bucket_encryption.json"
```

確認ポイント:

- `SSEAlgorithm` が `AES256` または `aws:kms` であること
- SSE-KMSの場合、KMS Key IDが設計どおりであること
- Bucket Keyの利用要件がある場合、`BucketKeyEnabled` を確認する
- 暗号化設定変更が既存オブジェクトへ自動適用されると誤解しないこと

代表的な暗号化方式:

| 値 | 意味 |
| :--- | :--- |
| `AES256` | SSE-S3 |
| `aws:kms` | SSE-KMS |

注意:

- 現在のS3では、新規オブジェクトはSSE-S3で自動的に暗号化される
- ただし、監査や手順書ではバケットのデフォルト暗号化設定を明示的に確認する
- SSE-KMSを使う場合、KMS Key Policy、IAM Policy、CloudTrail、アプリ権限の確認が必要になる

### 16.2 SSE-KMSのKMSキー確認

SSE-KMSを使っている場合、KMS Key IDを確認する。

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'ServerSideEncryptionConfiguration.Rules[*].ApplyServerSideEncryptionByDefault' \
  --output table
```

KMS Key IDが分かる場合:

```bash
aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id <kms-key-id-or-arn> \
  --query 'KeyMetadata.{KeyId:KeyId,Arn:Arn,Enabled:Enabled,KeyState:KeyState,KeyManager:KeyManager,Description:Description}' \
  --output table
```

確認ポイント:

- KMSキーが有効であること
- キーの管理者、利用者、アプリIAM Roleが設計どおりであること
- S3 Server Access Loggingや他サービス連携でKMS権限不足が起きないこと

## 17. オブジェクト単位の暗号化確認

### 17.1 aws s3api head-object

特定オブジェクトの暗号化ヘッダーを確認する。

```bash
OBJECT_KEY="<object-key>"

aws s3api head-object \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --key "$OBJECT_KEY" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query '{ServerSideEncryption:ServerSideEncryption,SSEKMSKeyId:SSEKMSKeyId,BucketKeyEnabled:BucketKeyEnabled,StorageClass:StorageClass,LastModified:LastModified,Size:ContentLength}' \
  --output table
```

確認ポイント:

- `ServerSideEncryption` が想定どおりであること
- SSE-KMSの場合、`SSEKMSKeyId` が想定キーであること
- オブジェクトキーに個人情報や業務情報が含まれる場合、証跡化に注意する

注意:

- `list-objects-v2` だけでは、各オブジェクトの暗号化方式は分からない
- オブジェクト単位確認には `head-object` を使う
- オブジェクト名自体が機密情報の場合がある

## 18. Versioning確認

### 18.1 aws s3api get-bucket-versioning

対象バケットのVersioning設定を確認する。

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/10_bucket_versioning.json"
```

主な状態:

| `Status` | 意味 |
| :--- | :--- |
| `Enabled` | Versioning有効 |
| `Suspended` | Versioning一時停止 |
| 項目なし | Versioning未設定 |

確認ポイント:

- 要件上、誤削除や上書きからの復旧が必要なら `Enabled` を検討する
- Versioningを有効化すると、非現行バージョンも保存されるためコストに影響する
- 削除してもDelete Markerが作られるため、削除挙動が変わる
- Lifecycle設定と合わせて確認する

## 19. Server Access Logging確認

### 19.1 aws s3api get-bucket-logging

S3 Server Access Loggingの設定を確認する。

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/11_bucket_logging.json"
```

確認ポイント:

- `LoggingEnabled` が存在するか
- `TargetBucket` が想定どおりか
- `TargetPrefix` が設計どおりか
- ログ保存先バケットが同じアカウント、同じリージョンにあるか
- ログ保存先バケットの公開設定、暗号化、ライフサイクルを確認したか

注意:

- S3 Server Access Loggingはデフォルトでは有効ではない
- ログ保存先バケットにログを書き込める権限が必要
- ログ保存先にSSE-KMSを使う場合、KMS Key Policyも確認する
- Object Ownershipが `BucketOwnerEnforced` の場合、ログ設定にTarget Grantsを含めない
- CloudTrail Data Eventsとは役割が異なる

## 20. Lifecycle確認

### 20.1 aws s3api get-bucket-lifecycle-configuration

ライフサイクル設定を確認する。

```bash
aws s3api get-bucket-lifecycle-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/12_lifecycle_configuration.json"
```

確認ポイント:

- オブジェクト削除や非現行バージョン削除のルールがあるか
- ログバケットの保管期間が要件に合うか
- Glacier系ストレージクラス移行の要件があるか
- 意図しない短期間削除がないか

エラー例:

```text
NoSuchLifecycleConfiguration
```

ライフサイクル未設定の場合に発生する。

未設定が正常かどうかは、保管要件、コスト、ログ保持要件で判断する。

## 21. Object Lock確認

### 21.1 aws s3api get-object-lock-configuration

Object Lock設定を確認する。

```bash
aws s3api get-object-lock-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-object-lock-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/13_object_lock_configuration.json"
```

確認ポイント:

- 金融・監査要件でWORMが必要か
- `ObjectLockEnabled` が設定されているか
- Governance / Compliance modeの要件があるか
- Retention期間が要件どおりか

注意:

- Object Lockはバケット作成時の要件が関係する
- 無効化や変更が簡単にできない設定がある
- 実案件では手順外で変更しない

## 22. Tagging確認

### 22.1 aws s3api get-bucket-tagging

バケットタグを確認する。

```bash
aws s3api get-bucket-tagging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-tagging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/14_bucket_tagging.json"
```

確認ポイント:

- システム名、環境、用途、管理者、コスト配賦タグがあるか
- 本番、検証、開発の識別ができるか
- セキュリティ調査時に所有部署を特定できるか

エラー例:

```text
NoSuchTagSet
```

タグ未設定の場合に発生する。

## 23. Website Hosting確認

### 23.1 aws s3api get-bucket-website

S3静的Webサイトホスティングの設定を確認する。

```bash
aws s3api get-bucket-website \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-website \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/15_bucket_website.json"
```

確認ポイント:

- 静的Webサイトホスティングが有効になっていないか
- 有効な場合、公開要件、CloudFront利用有無、Bucket Policyを確認する
- アップロード用、ログ用、メール保存用バケットでは原則不要

エラー例:

```text
NoSuchWebsiteConfiguration
```

静的Webサイトホスティング未設定の場合に発生する。

多くの非公開バケットでは未設定が正常である。

## 24. CORS確認

### 24.1 aws s3api get-bucket-cors

CORS設定を確認する。

```bash
aws s3api get-bucket-cors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

証跡保存:

```bash
aws s3api get-bucket-cors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/16_bucket_cors.json"
```

確認ポイント:

- `AllowedOrigins` が `*` になっていないか
- `AllowedMethods` が必要最小限か
- ブラウザから直接S3へアップロードする要件があるか
- CloudFrontやアプリケーション経由にできないか

エラー例:

```text
NoSuchCORSConfiguration
```

CORS未設定の場合に発生する。

## 25. Access Point確認

### 25.1 aws s3control list-access-points

S3 Access Point一覧を確認する。

```bash
aws s3control list-access-points \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --query 'AccessPointList[*].{Name:Name,Bucket:Bucket,NetworkOrigin:NetworkOrigin,VpcId:VpcConfiguration.VpcId}' \
  --output table
```

証跡保存:

```bash
aws s3control list-access-points \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/17_access_points.json"
```

確認ポイント:

- 対象バケットに関連するAccess Pointがあるか
- `NetworkOrigin` が `Internet` か `VPC` か
- VPC限定のはずのAccess PointがInternetになっていないか
- Access Point PolicyがPublicになっていないか

### 25.2 Access Point詳細確認

```bash
ACCESS_POINT_NAME="<access-point-name>"

aws s3control get-access-point \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --name "$ACCESS_POINT_NAME" \
  --output table
```

### 25.3 Access Point Policy Status確認

```bash
aws s3control get-access-point-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --name "$ACCESS_POINT_NAME" \
  --output table
```

確認ポイント:

- `IsPublic=false` であること
- Publicの場合は、Access Point Policy、Bucket Policy、Block Public Accessを合わせて確認する

## 26. オブジェクト一覧確認の注意

### 26.1 aws s3api list-objects-v2

S3オブジェクト一覧を確認する。

```bash
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --max-items 10 \
  --query 'Contents[*].{Key:Key,LastModified:LastModified,Size:Size,StorageClass:StorageClass}' \
  --output table
```

確認ポイント:

- オブジェクトが想定プレフィックスに保存されているか
- 不要なファイルや一時ファイルがないか
- ログ、アップロード、メール保存など用途に合うか

注意:

- オブジェクトキー名に個人情報や業務情報が含まれる場合がある
- 全件取得すると大量出力や課金、証跡肥大化につながる
- 証跡として保存する場合は、対象範囲と情報管理ルールを確認する

## 27. IAM RoleのS3権限確認

S3バケット側だけでなく、利用者側のIAM Policyも確認する。

例として、Web EC2用IAM Roleを確認する。

```bash
ROLE_NAME="sample-role-web"
INLINE_POLICY_NAME="sample-policy-web-s3-upload"
```

### 27.1 インラインポリシー確認

```bash
aws iam get-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/18_web_role_inline_policy.json"
```

確認ポイント:

- 対象バケットだけに絞られているか
- `s3:*` や `Resource: "*"` になっていないか
- 必要な操作だけが許可されているか
- `GetObject`、`PutObject`、`DeleteObject` などが業務要件と一致するか

### 27.2 管理ポリシー確認

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output table
```

確認ポイント:

- `AmazonS3FullAccess` のような広い権限が付いていないか
- 一時的に付与した権限が残っていないか
- CloudWatch Agentなど、S3以外の必要権限と混同していないか

## 28. CloudTrailとの関係

S3セキュリティ設定変更は、CloudTrailの管理イベントとして記録される。

代表的なイベント:

| 操作 | CloudTrail EventName |
| :--- | :--- |
| Public Access Block変更 | `PutBucketPublicAccessBlock` |
| Bucket Policy変更 | `PutBucketPolicy` |
| Bucket Encryption変更 | `PutBucketEncryption` |
| Ownership Controls変更 | `PutBucketOwnershipControls` |
| Versioning変更 | `PutBucketVersioning` |
| Logging変更 | `PutBucketLogging` |

例:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketEncryption \
  --max-results 10 \
  --output table
```

注意:

- S3オブジェクトの取得、PUT、DELETEなどはCloudTrail Data Eventsの設定が必要になる
- Data Eventsは対象バケットやイベントタイプを明示して有効化する
- CloudTrailの詳細はCloudTrailリファレンスで扱う

## 29. 変更系コマンドの注意

このリファレンスは確認を中心にするが、代表的な変更系コマンドも整理する。

本番相当の環境では、以下を行ってから実行する。

- 変更前証跡を取得する
- 変更対象バケット名を確認する
- 変更内容のレビューを受ける
- 作業承認を得る
- 切り戻し手順を準備する
- CloudTrail確認方法を準備する

### 29.1 Block Public Accessを有効化する

```bash
aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

影響:

- Public ACL設定やPublic Policy設定がブロックされる
- 既存の公開設計がある場合、アクセスに影響する可能性がある
- CloudFrontや署名付きURLの構成と合わせて確認する

### 29.2 Object OwnershipをBucketOwnerEnforcedにする

```bash
aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --ownership-controls '{
    "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
    ]
  }'
```

影響:

- ACLが無効化される
- ACL前提の外部連携がある場合、アクセスできなくなる可能性がある
- 事前にBucket PolicyやIAM Policyへ移行できているか確認する

### 29.3 デフォルト暗号化をSSE-S3にする

```bash
aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
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

影響:

- 新規オブジェクトのデフォルト暗号化設定が変更される
- 既存オブジェクトの暗号化方式は自動的には変わらない

### 29.4 Versioningを有効化する

```bash
aws s3api put-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --versioning-configuration Status=Enabled
```

影響:

- 上書きや削除時に旧バージョンが残る
- 復旧性が上がる
- ストレージコストが増える可能性がある
- Lifecycle設定の見直しが必要になる

### 29.5 Server Access Loggingを有効化する

設定ファイル例:

```json
{
  "LoggingEnabled": {
    "TargetBucket": "example-log-bucket",
    "TargetPrefix": "s3-access-logs/example-source-bucket/"
  }
}
```

実行例:

```bash
aws s3api put-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --bucket-logging-status file://logging.json
```

影響:

- ログ保存先バケットの権限設定が必要
- ログ量に応じてS3コストが増える
- ログ保存先バケットの暗号化、Lifecycle、Public Access Blockも確認する

## 30. 切り戻しの考え方

S3セキュリティ設定の切り戻しでは、単純に無効化すればよいとは限らない。

| 設定 | 切り戻し時の注意 |
| :--- | :--- |
| Public Access Block | 無効化するとPublic化リスクが上がる |
| Object Ownership | ACL利用有無、外部連携影響を確認する |
| Default Encryption | 既存オブジェクトの暗号化は自動変更されない |
| Versioning | Suspendedにしても既存バージョンは残る |
| Server Access Logging | ログ欠損期間が発生する |
| Lifecycle | 削除済みオブジェクトは戻せない場合がある |
| Bucket Policy | 変更前Policyファイルが必要 |

本番作業では、変更前設定を保存し、変更前後の差分を確認してから切り戻しする。

## 31. S3セキュリティ調査結果テンプレート

```text
対象バケット:
  <bucket-name>

確認日時:
  <yyyy-mm-dd hh:mm>

確認者:
  <name>

Account-level Block Public Access:
  OK / NG / 対象外

Bucket-level Block Public Access:
  OK / NG / 対象外

Bucket Policy Status:
  Publicではない / Public / 要確認

Object Ownership:
  BucketOwnerEnforced / その他

ACL:
  Ownerのみ / Public Grantあり / 要確認

Default Encryption:
  SSE-S3 / SSE-KMS / 要確認

Versioning:
  Enabled / Suspended / 未設定 / 要件確認

Server Access Logging:
  Enabled / Disabled / 要件確認

Access Point:
  なし / VPC限定 / Internetあり / 要確認

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 32. Teams報告例

### 32.1 問題なしの場合

```text
S3バケット <bucket-name> のセキュリティ設定を確認しました。
Account / Bucket-levelのBlock Public Accessは有効、
Bucket Policy StatusはPublicではありません。
Object OwnershipはBucketOwnerEnforcedでACLは無効化方針、
デフォルト暗号化も有効です。
現時点で想定外公開につながる設定は確認されませんでした。
```

### 32.2 要確認の場合

```text
S3バケット <bucket-name> の確認で、以下の項目が要確認です。

- Bucket Policy Status: Public
- Access Point NetworkOrigin: Internet

Public Access BlockとBucket Policyの組み合わせ、
およびAccess Point Policyを追加確認します。
設定変更は実施せず、影響範囲を整理してから報告します。
```

## 33. 公式ドキュメント

- [Amazon S3のセキュリティのベストプラクティス](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/security-best-practices.html)
- [Amazon S3ストレージへのパブリックアクセスをブロックする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [オブジェクトの所有権を制御し、ACLを無効にする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/about-object-ownership.html)
- [暗号化によるデータの保護](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/UsingEncryption.html)
- [S3 Versioningの仕組み](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/versioning-workflows.html)
- [Amazon S3サーバーアクセスログを有効にする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [Amazon S3 Access Pointの使用](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/using-access-points.html)
