# 案件対策: S3バケットポリシー変更の影響調査・設定変更・証跡取得

## 1. 目的

このドキュメントは、某銀行案件で想定される「S3バケットポリシー変更」を、自宅AWSラボ環境で案件型に練習するための実行手順である。

面談で見えた実作業は、単にAWSリソースを新規作成することではなく、既存AWS環境に対して以下を行う作業である。

```text
影響調査済み項目に対して、設定変更、テスト、手順書作成、証跡取得を行う
```

特にS3については、以下のような話が出ている。

```text
S3やバケットポリシーの変更が20個程度ある。
これを担当してほしい。
```

そのため、今日の練習では、S3バケットを対象に以下を一通り行う。

1. 変更対象の現状確認
2. 変更前証跡の取得
3. 影響範囲の確認
4. バケットポリシー変更
5. 変更後確認
6. アプリケーション動作確認
7. CloudTrailで変更イベント確認
8. 切り戻し手順確認
9. 作業記録として残せる形に整理

## 2. 今日の対象

今日の対象は、Rails Active Storageのアップロード先として使っているS3バケットである。

| 項目 | 値 |
| :--- | :--- |
| AWS Profile | `learning` |
| Region | `ap-northeast-1` |
| Bucket | `nobu-terraform-iac-lab-upload` |
| Web EC2 IAM Role | `sample-role-web` |
| Inline Policy | `sample-policy-web-s3-upload` |
| Rails URL | `https://www.nobu-iac-lab.com` |

対象バケットは、`11_s3_setup.sh` で作成している。

現在の設計では、以下の設定を入れている。

| 設定 | 内容 |
| :--- | :--- |
| Public Access Block | 全項目有効 |
| Object Ownership | `BucketOwnerEnforced` |
| ACL | 無効 |
| Default Encryption | SSE-S3 / AES256 |
| Bucket Policy | `DenyInsecureTransport` |
| Web EC2 Role | 対象バケット限定のインラインポリシー |

## 3. 今日やる変更

今日の変更テーマは、以下である。

```text
S3バケットポリシーにより、HTTPによる非暗号化アクセスを拒否し、TLS通信のみ許可される状態を確認する
```

実際のBucket Policyでは、以下のStatementを扱う。

```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::nobu-terraform-iac-lab-upload",
    "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

この設定により、HTTPSではないS3アクセスを明示的に拒否する。

`Public Access Block` は公開許可を防ぐ設定であり、TLS強制とは役割が異なる。

そのため、Public Access Blockが有効でも、Bucket Policyによる `DenyInsecureTransport` は別途確認対象になる。

## 4. 実務で重要な注意点

S3 Bucket Policyの変更で一番危険なのは、既存Policyを丸ごと上書きして、他のStatementを消してしまうことである。

本番作業では、以下を必ず守る。

```text
既存Bucket Policyを取得してから、差分を確認し、必要なStatementだけ追加・修正する
```

今回のラボでは、現在のBucket Policyが `DenyInsecureTransport` のみであるため、同じ内容を再適用しても影響は小さい。

しかし実案件では、以下のようなStatementが既に入っている可能性がある。

- アプリケーション用IAM Roleへの許可
- 外部連携先AWSアカウントへの許可
- CloudFront OAC / OAI用の許可
- S3 Server Access Logs配送用の許可
- SES受信メール保存用の許可
- 特定VPC Endpointからのみ許可する条件

そのため、実務では「置き換え」ではなく「差分反映」の考え方が重要である。

## 5. 作業全体の流れ

今日の作業は以下の順番で行う。

```text
事前確認
  ↓
変更前証跡取得
  ↓
変更内容確認
  ↓
Bucket Policy適用
  ↓
変更後証跡取得
  ↓
アプリケーション動作確認
  ↓
CloudTrail確認
  ↓
切り戻し手順確認
  ↓
作業結果整理
```

## 6. 作業ディレクトリ

作業は以下のディレクトリで行う。

```bash
cd /Users/nobu/aws-reference
```

証跡保存用ディレクトリを作成する。

```bash
EVIDENCE_DIR="evidence/s3_bucket_policy_change_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EVIDENCE_DIR"/before "$EVIDENCE_DIR"/after "$EVIDENCE_DIR"/rollback
```

このディレクトリに、変更前後のCLI結果を保存する。

## 7. 共通変数

以降のコマンドでは、以下の変数を使う。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
BUCKET="nobu-terraform-iac-lab-upload"
ROLE_NAME="sample-role-web"
INLINE_POLICY_NAME="sample-policy-web-s3-upload"
```

## 8. 作業前アカウント確認

最初に、操作対象のAWSアカウントを確認する。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

期待値:

```text
Account: 445405559057
Arn    : arn:aws:iam::445405559057:user/nobu
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json > "$EVIDENCE_DIR/before/00_caller_identity.json"
```

## 9. 変更前確認

### 9.1 バケット存在確認

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET"
```

終了コードが0であれば、バケットにアクセスできる。

### 9.2 バケットリージョン確認

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/01_bucket_location.json"
```

期待値:

```text
ap-northeast-1
```

### 9.3 Public Access Block確認

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/02_public_access_block.json"
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

### 9.4 Object Ownership確認

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/03_ownership_controls.json"
```

期待値:

```text
BucketOwnerEnforced
```

この設定により、ACLは無効化され、オブジェクト所有者はバケット所有者に統一される。

### 9.5 デフォルト暗号化確認

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/04_bucket_encryption.json"
```

期待値:

```text
SSEAlgorithm: AES256
```

### 9.6 Bucket Policy確認

Bucket Policyを取得する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --query Policy \
  --output text > "$EVIDENCE_DIR/before/05_bucket_policy.json"
```

内容確認:

```bash
cat "$EVIDENCE_DIR/before/05_bucket_policy.json"
```

確認する観点:

- `DenyInsecureTransport` があるか
- `Principal` が `*` でも `Effect` が `Deny` であること
- `aws:SecureTransport` が `false` の時だけ拒否していること
- 対象Resourceがバケット本体とオブジェクト両方を含んでいること

### 9.7 Bucket Policy Status確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/06_bucket_policy_status.json"
```

期待値:

```text
IsPublic: false
```

### 9.8 Server Access Logging確認

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/before/07_bucket_logging.json"
```

このラボでは、アップロード用S3バケットにServer Access Loggingを必須設定していない。

案件では、ログ設定の有無も影響調査対象になりやすい。

### 9.9 IAM RoleのS3権限確認

Web EC2用IAM Roleのインラインポリシーを確認する。

```bash
aws iam get-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --output json > "$EVIDENCE_DIR/before/08_web_role_inline_policy.json"
```

確認する観点:

- 対象バケットが `nobu-terraform-iac-lab-upload` に限定されているか
- `AmazonS3FullAccess` のような広い権限が残っていないか
- `GetObject` / `PutObject` / `DeleteObject` が必要範囲に入っているか

管理ポリシーの付与状況も確認する。

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json > "$EVIDENCE_DIR/before/09_web_role_attached_policies.json"
```

## 10. 影響範囲確認

今回のBucket Policy変更で影響を受ける可能性があるものを確認する。

| 対象 | 影響確認 |
| :--- | :--- |
| Rails Active Storage | 画像アップロード、画像表示ができるか |
| Web EC2 IAM Role | 対象バケットへPutObject/GetObjectできるか |
| Public Access Block | 変更後も全項目trueか |
| S3暗号化 | SSE-S3設定が維持されているか |
| CloudTrail | PutBucketPolicyイベントが記録されるか |

今回の変更はHTTPアクセス拒否であり、AWS SDKやRails Active Storageは通常HTTPSでS3へアクセスする。

そのため、想定影響は以下である。

```text
通常のRails画像アップロードには影響しない想定
```

ただし、万が一アプリや外部連携がHTTPエンドポイントでS3へアクセスしている場合は失敗する。

本番作業では、HTTPでS3へアクセスしている古い連携がないかを確認する。

## 11. 変更用Bucket Policy作成

変更用Bucket Policyをファイルとして作成する。

```bash
cat > "$EVIDENCE_DIR/after/bucket-policy-new.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$BUCKET",
        "arn:aws:s3:::$BUCKET/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF
```

内容を確認する。

```bash
cat "$EVIDENCE_DIR/after/bucket-policy-new.json"
```

本番作業では、この時点でレビュー対象にする。

確認観点:

- `Effect` が `Deny` である
- `Principal` が `*` でもDeny条件付きなので公開許可ではない
- `aws:SecureTransport` が `false` の通信だけ拒否する
- バケット本体とオブジェクト両方を対象にしている
- 既存Statementを消していない

## 12. 設定変更

Bucket Policyを適用する。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --policy "file://$EVIDENCE_DIR/after/bucket-policy-new.json"
```

実務では、このコマンド実行前に以下を確認する。

```text
作業対象アカウント、リージョン、バケット名、変更JSON、切り戻しファイル
```

## 13. 変更後確認

### 13.1 Bucket Policy再取得

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --query Policy \
  --output text > "$EVIDENCE_DIR/after/01_bucket_policy_after.json"
```

確認:

```bash
cat "$EVIDENCE_DIR/after/01_bucket_policy_after.json"
```

### 13.2 Bucket Policy Status確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/after/02_bucket_policy_status_after.json"
```

期待値:

```text
IsPublic: false
```

### 13.3 Public Access Block確認

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/after/03_public_access_block_after.json"
```

期待値:

```text
BlockPublicAcls       true
IgnorePublicAcls      true
BlockPublicPolicy     true
RestrictPublicBuckets true
```

### 13.4 暗号化確認

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --output json > "$EVIDENCE_DIR/after/04_bucket_encryption_after.json"
```

期待値:

```text
SSEAlgorithm: AES256
```

## 14. アプリケーション動作確認

### 14.1 HTTPS表示確認

```bash
curl -I https://www.nobu-iac-lab.com
```

期待値:

```text
HTTP/2 200
```

### 14.2 Rails画面確認

ブラウザで以下へアクセスする。

```text
https://www.nobu-iac-lab.com
```

確認すること:

- トップページが表示される
- 固定画像が表示される
- ログインできる
- 投稿一覧が表示される

### 14.3 画像アップロード確認

Railsアプリで画像付き投稿を行う。

期待値:

- 投稿が成功する
- 画像が表示される
- S3にオブジェクトが作成される

S3側確認:

```bash
aws s3 ls "s3://$BUCKET" \
  --profile "$PROFILE" \
  --recursive > "$EVIDENCE_DIR/after/05_s3_object_list_after.txt"
```

## 15. Web EC2 IAM RoleからのS3確認

Web EC2上で、IAM Roleを使ってS3へアクセスできるか確認する。

```bash
ssh awsref-web01
```

Web EC2上で実行:

```bash
aws sts get-caller-identity --region ap-northeast-1
aws s3 ls s3://nobu-terraform-iac-lab-upload --region ap-northeast-1
```

期待値:

- `sample-role-web` 由来の認証情報で実行される
- 対象バケットを一覧できる
- AccessDeniedにならない

もしWeb EC2にAWS CLIが無い場合は、Rails画像アップロード結果で代替確認する。

## 16. CloudTrail確認

Bucket Policy変更はCloudTrailの管理イベントとして記録される。

直近の `PutBucketPolicy` イベントを確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --max-results 10 \
  --output json > "$EVIDENCE_DIR/after/06_cloudtrail_put_bucket_policy.json"
```

確認する観点:

- `EventName` が `PutBucketPolicy`
- `Username` または実行Principalが想定通り
- `EventTime` が作業時刻と一致する
- 対象バケットが `nobu-terraform-iac-lab-upload`

実務では、CloudTrailイベントは「誰が、いつ、何を変更したか」の監査証跡になる。

## 17. 切り戻し手順

### 17.1 変更前Policyが存在していた場合

変更前に取得したPolicyを再適用する。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --policy "file://$EVIDENCE_DIR/before/05_bucket_policy.json"
```

切り戻し後確認:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --query Policy \
  --output text > "$EVIDENCE_DIR/rollback/01_bucket_policy_rollback.json"
```

### 17.2 変更前Policyが存在しなかった場合

変更前にBucket Policyが存在しなかった場合は、削除で切り戻す。

```bash
aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET"
```

今回のラボでは、変更前Policyが存在する想定である。

## 18. 中断・切り戻し判断基準

以下の場合は作業を中断し、切り戻しを検討する。

| 状況 | 判断 |
| :--- | :--- |
| Bucket Policy StatusがPublicになる | 即時切り戻し |
| Rails画像アップロードが失敗する | 原因確認、必要なら切り戻し |
| Web EC2 IAM RoleからS3アクセスできない | 原因確認、必要なら切り戻し |
| 既存PolicyのStatementが消えた | 即時切り戻し |
| 想定外PrincipalへのAllowが入った | 即時切り戻し |
| CloudTrailに想定外ユーザーの変更イベントがある | 作業中断、確認 |

## 19. GUIで見る場合

現場ではGUI手順書が求められる可能性がある。

AWS Management Consoleでは、以下を見る。

```text
S3
  -> Buckets
  -> nobu-terraform-iac-lab-upload
```

確認画面:

| タブ | 見る項目 |
| :--- | :--- |
| Permissions | Block public access |
| Permissions | Bucket policy |
| Permissions | Object Ownership |
| Properties | Default encryption |
| Properties | Server access logging |
| Management | Lifecycle rules |

証跡としてスクリーンショットを取るなら、以下が候補になる。

- 変更前Bucket Policy
- 変更後Bucket Policy
- Public Access Block
- Object Ownership
- Default Encryption
- 画像アップロード成功画面
- CloudTrailのPutBucketPolicyイベント

スクリーンショットだけでなく、CLI結果も合わせて残す。

```text
スクショ: 人間が見やすい証跡
CLI結果 : 設定値を正確に残す証跡
CloudTrail: 監査証跡
```

## 20. Teamsで確認する時の文面例

作業前:

```text
S3バケット nobu-terraform-iac-lab-upload について、Bucket PolicyにTLS必須化のDeny条件が入っていることを確認し、必要に応じて同条件を適用します。
変更前Policy、Public Access Block、暗号化設定を取得し、変更後はRails画像アップロード、S3オブジェクト作成、CloudTrail PutBucketPolicyイベントを確認します。
既存Policyは事前取得し、異常時は取得済みPolicyを再適用して切り戻します。
```

作業後:

```text
S3バケットポリシー変更作業は完了しました。
変更後のBucket Policy、Public Access Block、暗号化設定を確認し、Bucket Policy StatusはPublicではありませんでした。
Railsアプリからの画像アップロード、およびS3オブジェクト作成も確認済みです。
CloudTrailにPutBucketPolicyイベントが記録されていることも確認しました。
```

## 21. 作業結果テンプレート

作業完了後、以下を埋める。

| 項目 | 結果 |
| :--- | :--- |
| 作業日時 |  |
| 作業者 |  |
| AWS Account |  |
| Region |  |
| Bucket | `nobu-terraform-iac-lab-upload` |
| 変更内容 | Bucket Policy TLS必須化確認 / 適用 |
| 変更前Policy取得 | OK / NG |
| 変更後Policy確認 | OK / NG |
| Public Access Block確認 | OK / NG |
| Encryption確認 | OK / NG |
| Rails HTTPS表示確認 | OK / NG |
| 画像アップロード確認 | OK / NG |
| S3オブジェクト確認 | OK / NG |
| CloudTrail確認 | OK / NG |
| 切り戻し要否 | 不要 / 実施 |
| 備考 |  |

## 22. 今日のゴール

今日のゴールは、S3バケットポリシー変更そのものよりも、以下の型を身につけることである。

```text
既存設定を確認する
変更前証跡を取る
影響範囲を考える
設定変更する
変更後テストする
CloudTrailで変更証跡を確認する
切り戻しできる状態にする
手順として説明できる形に残す
```

この型は、S3だけでなく、MFA、VPC、CloudTrail、CloudWatch、GuardDutyなどの設定変更にも使える。

某銀行案件では、AWSサービス横断で似たような事象が発生しているという話があった。

そのため、今日のS3練習は、今後のCloudTrail / CloudWatch / GuardDuty / VPC調査にもつながる基礎作業である。

