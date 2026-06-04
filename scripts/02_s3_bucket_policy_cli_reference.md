# 02 S3 Bucket Policy CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、Amazon S3 Bucket PolicyをAWS CLIで調査、変更、確認、切り戻しするためのリファレンスである。

対象は、銀行系システムのように、S3バケットポリシー変更、影響調査、手順書作成、証跡取得、CloudTrail確認が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- Bucket Policyの取得
- Bucket Policy StatusによるPublic判定
- Bucket Policyの読み解き方
- 危険なStatementの見分け方
- TLS必須化Policyの確認
- 既存Policyを消さない変更手順
- JSON構文確認
- IAM Access AnalyzerによるPolicy検証
- 変更前後の差分確認
- `put-bucket-policy` による設定変更
- `delete-bucket-policy` による削除
- 切り戻し
- CloudTrailでの変更イベント確認
- 手順書と証跡に残す観点

S3全体のセキュリティ設定確認は、以下を参照する。

[01 S3 セキュリティ設定 CLIリファレンス](./01_s3_security_cli_reference.md)

AWS CLIの共通操作、証跡保存、差分確認、終了コードは、以下を参照する。

[00 共通 AWS CLI・証跡保存リファレンス](./00_common_aws_cli_reference.md)

## 2. Bucket Policyとは

Bucket Policyは、S3バケットに付与するリソースベースポリシーである。

IAMユーザーやIAM Roleに付与するIdentity-based Policyとは異なり、Bucket PolicyはS3バケット側に設定する。

主な用途:

- 別AWSアカウントへアクセス許可する
- 特定IAM Roleへアクセス許可する
- CloudFront OAC / OAIからのアクセスを許可する
- ALBログ、S3ログ、SES受信メールなどの配送元サービスへ書き込み許可する
- HTTPアクセスを拒否してTLSを強制する
- 特定VPC Endpoint経由のみ許可する
- 特定Organization配下のPrincipalだけ許可する
- 想定外のPrincipalや条件を明示的に拒否する

重要:

```text
Bucket Policyは、既存Policy全体をJSONとして管理する。
put-bucket-policy は、部分追記ではなくPolicy全体を適用する。
```

つまり、作業時に一番危険なのは以下である。

```text
既存Statementを取得せず、新しいPolicyだけを適用してしまい、
既存の許可や拒否条件を消してしまうこと
```

## 3. Bucket Policy変更で特に危険なこと

| 危険な操作 | 起きること |
| :--- | :--- |
| 既存Policyを取得せずに新Policyを適用 | 既存Statementが消える |
| `Principal: "*"` のAllowを追加 | インターネット公開につながる可能性 |
| `Action: "s3:*"` のAllowを追加 | 過剰権限になる可能性 |
| `Resource: "*"` を使う | 対象が広がりすぎる |
| バケットARNとオブジェクトARNを混同 | List系またはObject系権限が効かない |
| Deny条件を誤る | 正常アクセスまで拒否する |
| Block Public Accessを理解せずPublic許可を追加 | `put-bucket-policy` が失敗、または公開リスク |
| 切り戻し用Policyを保存しない | 異常時に戻せない |
| JSONの整形差分だけを見て変更内容を誤認 | レビュー漏れにつながる |

## 4. Bucket Policy変更の基本フロー

```text
対象確認
  ↓
変更前Policy取得
  ↓
Policy Status確認
  ↓
Public Access Block確認
  ↓
既存Statementの読み解き
  ↓
変更JSON作成
  ↓
JSON構文確認
  ↓
Access Analyzer Policy検証
  ↓
差分確認
  ↓
レビュー・承認
  ↓
put-bucket-policy
  ↓
変更後Policy取得
  ↓
Policy Status再確認
  ↓
アプリ・連携動作確認
  ↓
CloudTrail確認
  ↓
作業結果整理
```

## 5. 作業前の共通変数

### 5.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"
BUCKET="nobu-terraform-iac-lab-upload"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

EXPECTED_BUCKET_OWNER="$ACCOUNT_ID"
```

### 5.2 証跡ディレクトリ

```bash
WORK_NAME="s3_bucket_policy_change"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 5.3 作業アカウント確認

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

確認ポイント:

- `Account` が作業対象AWSアカウントである
- `Arn` が作業用IAMユーザーまたは作業用ロールである
- 本番、検証、開発を取り違えていない

## 6. 対象バケット確認

### 6.1 head-bucket

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER"
```

確認ポイント:

- 終了コード `0` である
- 対象バケットへアクセスできる
- `--expected-bucket-owner` により、別アカウント所有バケットの誤操作を避ける

### 6.2 バケットリージョン確認

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/01_bucket_location.json"
```

確認ポイント:

- `LocationConstraint` が想定リージョンである
- `us-east-1` の場合は `None` または `null` の扱いに注意する

## 7. 変更前Bucket Policy取得

### 7.1 get-bucket-policy

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/before/02_bucket_policy_before.json"
```

確認:

```bash
cat "$EVIDENCE_DIR/before/02_bucket_policy_before.json"
```

確認ポイント:

- Bucket Policyが存在するか
- 既存Statementがいくつあるか
- `Allow` と `Deny` がどちらも含まれるか
- 外部アカウントやAWSサービスへの許可があるか
- 変更対象Statement以外を消してはいけない

### 7.2 Bucket Policyが存在しない場合

Bucket Policyが未設定の場合、以下のようなエラーになる。

```text
NoSuchBucketPolicy
```

この場合は、以下を記録する。

```bash
echo "No bucket policy before change." \
  > "$EVIDENCE_DIR/before/02_bucket_policy_before.txt"
```

注意:

- Policy未設定が正常かどうかは、バケット用途による
- 変更後に切り戻す場合は、`delete-bucket-policy` が切り戻し手順になる
- 変更前Policyが存在しないことも証跡として残す

### 7.3 JSON出力形式の注意

`get-bucket-policy --output json` では、`Policy` がJSON文字列として返るため、エスケープされて見づらいことがある。

証跡としてPolicy本文を扱う場合は、以下のようにする。

```bash
--query 'Policy' --output text
```

これにより、Policy本文をそのままファイルに保存しやすい。

## 8. 変更前Policy Status確認

### 8.1 get-bucket-policy-status

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/03_bucket_policy_status_before.json"
```

確認:

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output table
```

期待値:

```text
IsPublic: false
```

確認ポイント:

- `IsPublic=false` であること
- `IsPublic=true` の場合は、変更作業の前に影響調査を優先する
- Public Access Block、Bucket Policy、Access Point Policy、ACLを合わせて確認する

注意:

```text
IsPublic=false は、外部アクセスが一切ないことを意味しない。
特定AWSアカウントや特定IAM Roleへの許可は存在し得る。
```

## 9. Public Access Block確認

Bucket Policy変更では、Public Access Blockの影響を必ず確認する。

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/before/04_public_access_block_before.json"
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

- `BlockPublicPolicy=true` の場合、Public AllowにつながるPolicyは適用に失敗する可能性がある
- Public Access Blockを無効化する作業は、公開リスクが高いため別承認にする
- TLS必須化のDeny Policyは公開許可ではないため、通常はPublic化ではない

## 10. Bucket Policyの基本構造

Bucket Policyは、IAM JSON Policy言語で記述する。

基本要素:

| 要素 | 意味 |
| :--- | :--- |
| `Version` | Policy言語のバージョン |
| `Statement` | 許可または拒否のルール一覧 |
| `Sid` | Statement ID。説明用の識別子 |
| `Effect` | `Allow` または `Deny` |
| `Principal` | 誰に対する許可または拒否か |
| `Action` | 対象API操作 |
| `Resource` | 対象バケットまたはオブジェクトARN |
| `Condition` | 条件。IP、TLS、VPC Endpoint、MFAなど |

例:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::example-bucket",
        "arn:aws:s3:::example-bucket/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

## 11. Bucket ARNとObject ARN

S3では、バケット本体のARNとオブジェクトのARNを使い分ける。

| 対象 | ARN例 | 主なAction |
| :--- | :--- | :--- |
| バケット本体 | `arn:aws:s3:::example-bucket` | `s3:ListBucket`、`s3:GetBucketLocation` |
| オブジェクト | `arn:aws:s3:::example-bucket/*` | `s3:GetObject`、`s3:PutObject`、`s3:DeleteObject` |

よくあるミス:

- `s3:ListBucket` に `arn:aws:s3:::example-bucket/*` を指定する
- `s3:GetObject` に `arn:aws:s3:::example-bucket` だけを指定する
- バケット本体とオブジェクトの両方が必要なDenyで片方だけ指定する

TLS必須化や外部Organization拒否のように、バケットとオブジェクト両方に効かせたい場合は、両方のARNを指定する。

## 12. `Allow` と `Deny` の読み方

### 12.1 `Effect: Allow`

`Allow` は、条件に一致したPrincipalへ権限を許可する。

注意:

- `Principal: "*"` と `Effect: "Allow"` の組み合わせは公開につながる可能性が高い
- `Condition` があっても条件が広い場合は危険
- `Action: "s3:*"` は原則広すぎる
- `Resource: "*"` は原則避ける

### 12.2 `Effect: Deny`

`Deny` は、条件に一致したアクセスを拒否する。

明示的DenyはAllowより優先される。

例:

```text
IAM RoleでAllowされていても、
Bucket PolicyでDenyされればアクセスは拒否される。
```

### 12.3 `Principal: "*"` でもDenyなら意味が違う

以下は、誰にでも許可しているわけではない。

```json
{
  "Effect": "Deny",
  "Principal": "*"
}
```

意味は「条件に一致するすべてのPrincipalを拒否する」である。

TLS必須化のDeny Policyでは、`Principal: "*"` は一般的に使われる。

## 13. 危険なBucket Policyの見分け方

### 13.1 Public Allow

危険度が高い例:

```json
{
  "Effect": "Allow",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::example-bucket/*"
}
```

確認ポイント:

- 静的Webサイトや公開コンテンツなど、明確な公開要件があるか
- Public Access Blockを無効化していないか
- CloudFront経由にできないか
- 公開対象Prefixが限定されているか
- 個人情報や機微情報が含まれないか

### 13.2 過剰なAction

注意が必要な例:

```json
{
  "Effect": "Allow",
  "Action": "s3:*"
}
```

確認ポイント:

- 読み取りだけでよいのに書き込みや削除まで許可していないか
- `PutBucketPolicy` や `DeleteBucketPolicy` など管理系操作まで含めていないか
- アプリ用IAM Roleに管理系権限を与えていないか

### 13.3 過剰なResource

注意が必要な例:

```json
{
  "Resource": "*"
}
```

確認ポイント:

- 対象バケットARNへ限定できないか
- Prefix単位で限定できないか
- バケット本体とオブジェクトの指定が正しいか

### 13.4 条件なしの外部アカウント許可

確認ポイント:

- 外部AWSアカウントIDが想定どおりか
- 契約先、連携先、運用委託先などの根拠があるか
- `aws:PrincipalOrgID`、`aws:SourceArn`、`aws:SourceAccount` などで追加制限できないか
- 許可期間、用途、対象Prefixが明確か

## 14. TLS必須化Policy

### 14.1 目的

HTTPによるS3アクセスを拒否し、HTTPS通信だけを許可する。

S3のPublic Access Blockは公開許可を防ぐ設定であり、TLS強制とは別の観点である。

### 14.2 Policy例

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::example-bucket",
        "arn:aws:s3:::example-bucket/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

確認ポイント:

- `Effect` が `Deny` である
- `Principal` は `*` でよい
- `aws:SecureTransport` が `"false"` の通信だけ拒否する
- バケット本体とオブジェクト両方のARNを指定している
- 既存Statementを消していない

### 14.3 影響確認

想定影響:

- AWS SDK、AWS CLI、Rails Active Storageは通常HTTPSを使うため、正常利用への影響は小さい想定

確認すべき例外:

- 古いアプリケーションがHTTPエンドポイントを明示している
- 独自ツールがS3 HTTP URLを使っている
- 社内プロキシや検証ツールがHTTPでアクセスしている
- 署名付きURLやCloudFrontとの組み合わせで想定外がないか

## 15. 既存Policyを消さない変更方針

### 15.1 方針

Bucket Policy変更は、以下の考え方で進める。

```text
変更前Policy全体を取得する
  ↓
既存Statementを残す
  ↓
追加・修正するStatementだけを反映する
  ↓
Policy全体として再適用する
```

### 15.2 変更前Policyを作業用にコピーする

```bash
cp "$EVIDENCE_DIR/before/02_bucket_policy_before.json" \
   "$EVIDENCE_DIR/change/bucket-policy-new.json"
```

Bucket Policyが存在しなかった場合:

```bash
cat > "$EVIDENCE_DIR/change/bucket-policy-new.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": []
}
EOF
```

注意:

- 実案件では、エディタで直接修正する場合も、変更前ファイルのバックアップを残す
- 手順書には「どのStatementを追加・変更したか」を明記する
- 既存Statementの削除が必要な場合は、削除理由と影響確認を別途書く

## 16. 変更用Policy JSONの構文確認

### 16.1 Pythonで構文確認

```bash
python3 -m json.tool \
  "$EVIDENCE_DIR/change/bucket-policy-new.json" \
  > "$EVIDENCE_DIR/change/bucket-policy-new.formatted.json"
```

確認ポイント:

- コマンドがエラーなく終了する
- 整形済みJSONをレビュー対象にする
- 全角引用符、余分なカンマ、括弧不足がない

### 16.2 PowerShellで構文確認

```powershell
Get-Content "$EvidenceDir\change\bucket-policy-new.json" -Raw |
  ConvertFrom-Json |
  Out-Null
```

### 16.3 整形済みJSONを使う

構文確認後、整形済みJSONを変更用Policyとして使う場合:

```bash
cp "$EVIDENCE_DIR/change/bucket-policy-new.formatted.json" \
   "$EVIDENCE_DIR/change/bucket-policy-new.json"
```

注意:

- 整形によってキーの順序が変わる場合がある
- 差分確認時に整形差分と意味のある差分を分けて見る

## 17. IAM Access AnalyzerでPolicy検証

### 17.1 validate-policy

IAM Access AnalyzerのPolicy検証で、構文、ベストプラクティス、過剰権限につながる警告を確認する。

```bash
aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --policy-document "file://$EVIDENCE_DIR/change/bucket-policy-new.json" \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --locale JA \
  --output json \
  > "$EVIDENCE_DIR/change/01_access_analyzer_validate_policy.json"
```

確認:

```bash
aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --policy-document "file://$EVIDENCE_DIR/change/bucket-policy-new.json" \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --locale JA \
  --query 'findings[*].{Type:findingType,Issue:issueCode,Detail:findingDetails}' \
  --output table
```

確認ポイント:

- `ERROR` がないこと
- `SECURITY_WARNING` がないこと、または理由と承認があること
- `WARNING`、`SUGGESTION` は内容を確認する
- 検証結果を手順書の証跡として保存する

注意:

- Access AnalyzerのPolicy検証は、実際のアクセス可否や業務影響を完全に保証するものではない
- エラーや警告がなくても、アプリケーション動作確認とCloudTrail確認は必要

## 18. 変更前後差分確認

### 18.1 diffで確認する

```bash
diff -u \
  "$EVIDENCE_DIR/before/02_bucket_policy_before.json" \
  "$EVIDENCE_DIR/change/bucket-policy-new.json" \
  > "$EVIDENCE_DIR/change/02_bucket_policy_diff.txt" || true
```

確認:

```bash
cat "$EVIDENCE_DIR/change/02_bucket_policy_diff.txt"
```

確認ポイント:

- 想定したStatementだけが追加または変更されている
- 既存Statementが消えていない
- `Principal`、`Action`、`Resource`、`Condition` が想定どおり
- バケット名やARNに誤りがない
- Public Allowが追加されていない

### 18.2 JSON整形後に比較する

```bash
python3 -m json.tool \
  "$EVIDENCE_DIR/before/02_bucket_policy_before.json" \
  > "$EVIDENCE_DIR/change/before_policy_formatted.json"

python3 -m json.tool \
  "$EVIDENCE_DIR/change/bucket-policy-new.json" \
  > "$EVIDENCE_DIR/change/new_policy_formatted.json"

diff -u \
  "$EVIDENCE_DIR/change/before_policy_formatted.json" \
  "$EVIDENCE_DIR/change/new_policy_formatted.json" \
  > "$EVIDENCE_DIR/change/03_bucket_policy_formatted_diff.txt" || true
```

注意:

- JSON整形により、見やすくなる
- キー順序までは必ずしも正規化されない
- `jq -S` が利用できる環境ならキー順序をそろえやすい

### 18.3 WinMergeなどのGUI差分

貸与PCやVDIでは、WinMergeなどの承認済み差分ツールを使う場合がある。

確認ポイント:

- 左側が変更前、右側が変更後である
- 差分画面に対象ファイル名が見える
- 想定差分だけである
- 文字コードや改行コードだけの差分ではない
- スクリーンショットを証跡として保存する

## 19. レビュー観点

変更前に、以下をレビューする。

| 観点 | 確認内容 |
| :--- | :--- |
| 対象 | Account、Region、Bucketが正しい |
| 既存Statement | 消えていない |
| Principal | 想定Principalのみ |
| Action | 必要最小限 |
| Resource | バケットARNとオブジェクトARNが正しい |
| Condition | TLS、VPC Endpoint、SourceArnなどが正しい |
| Public | Public Allowがない、または承認済み |
| Deny | 正常アクセスを拒否しない |
| JSON | 構文エラーがない |
| 検証 | Access Analyzer確認済み |
| 切り戻し | 変更前Policy再適用または削除手順がある |

## 20. Bucket Policy適用

### 20.1 put-bucket-policy

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --policy "file://$EVIDENCE_DIR/change/bucket-policy-new.json"
```

確認ポイント:

- コマンドが正常終了する
- 標準エラーにエラーが出ていない
- CloudTrailに `PutBucketPolicy` が記録される

重要:

```text
put-bucket-policy はPolicy全体を適用する。
既存Statementを残したJSONを指定する。
```

### 20.2 実行ログを保存する

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --policy "file://$EVIDENCE_DIR/change/bucket-policy-new.json" \
  > "$EVIDENCE_DIR/change/04_put_bucket_policy_stdout.txt" \
  2> "$EVIDENCE_DIR/change/04_put_bucket_policy_stderr.txt"
```

実行後:

```bash
echo $? > "$EVIDENCE_DIR/change/04_put_bucket_policy_exit_code.txt"
```

注意:

- 正常時は標準出力が空の場合がある
- 証跡としては、終了コード、エラー出力、変更後確認結果を残す

## 21. 変更後Policy取得

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/after/01_bucket_policy_after.json"
```

確認:

```bash
cat "$EVIDENCE_DIR/after/01_bucket_policy_after.json"
```

変更用JSONとの差分確認:

```bash
diff -u \
  "$EVIDENCE_DIR/change/bucket-policy-new.json" \
  "$EVIDENCE_DIR/after/01_bucket_policy_after.json" \
  > "$EVIDENCE_DIR/after/02_expected_vs_actual_policy_diff.txt" || true
```

確認ポイント:

- 適用したPolicyと取得したPolicyが一致する
- 想定外のStatementが増減していない
- Bucket Policy StatusがPublicになっていない

## 22. 変更後Policy Status確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/after/03_bucket_policy_status_after.json"
```

期待値:

```text
IsPublic: false
```

確認ポイント:

- `IsPublic=false` である
- `IsPublic=true` になった場合は、即時切り戻しまたは作業中断を検討する
- Public Access Block設定も再確認する

## 23. 変更後Public Access Block確認

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --output json \
  > "$EVIDENCE_DIR/after/04_public_access_block_after.json"
```

確認ポイント:

- 4項目すべて `true`
- 変更作業でPublic Access Blockを弱めていない
- 例外がある場合は承認と理由がある

## 24. アプリケーション・連携確認

Bucket Policyを変更した後は、設定確認だけで終わらない。

アプリケーションや連携先が想定どおり使えるか確認する。

### 24.1 Webアプリ確認例

```bash
curl -I https://www.nobu-iac-lab.com
```

期待値:

```text
HTTP 200系
```

### 24.2 S3オブジェクト一覧確認

```bash
aws s3 ls "s3://$BUCKET" \
  --profile "$PROFILE" \
  --recursive \
  > "$EVIDENCE_DIR/after/05_s3_object_list_after.txt"
```

注意:

- オブジェクトキーに個人情報や業務情報が含まれる可能性がある
- 本番では対象Prefixを絞る
- 証跡化してよい範囲を確認する

### 24.3 IAM Roleからの確認

Web EC2やLambdaなど、実際にS3へアクセスする主体で確認する。

確認ポイント:

- `AccessDenied` が出ていない
- `PutObject`、`GetObject`、`DeleteObject` など必要操作ができる
- 正常アクセスがDeny条件に引っかかっていない

## 25. CloudTrail確認

Bucket Policy変更は、CloudTrailの管理イベントとして記録される。

### 25.1 PutBucketPolicy確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --max-results 10 \
  --output json \
  > "$EVIDENCE_DIR/after/06_cloudtrail_put_bucket_policy.json"
```

確認:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --max-results 10 \
  --query 'Events[*].{EventTime:EventTime,Username:Username,EventName:EventName,Resources:Resources}' \
  --output table
```

確認ポイント:

- `EventName` が `PutBucketPolicy`
- `EventTime` が作業時間帯と一致する
- `Username` または実行Principalが想定どおり
- 対象バケットが含まれる
- 想定外ユーザーによる変更がない

### 25.2 DeleteBucketPolicy確認

切り戻しや削除を行った場合:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteBucketPolicy \
  --max-results 10 \
  --output json \
  > "$EVIDENCE_DIR/rollback/02_cloudtrail_delete_bucket_policy.json"
```

注意:

- CloudTrail反映には時間がかかる場合がある
- S3オブジェクトの取得、PUT、DELETEなどはCloudTrail Data Eventsの設定が必要
- Bucket Policy変更は通常、管理イベントとして確認する

## 26. 切り戻し

### 26.1 変更前Policyが存在していた場合

変更前Policyを再適用する。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --policy "file://$EVIDENCE_DIR/before/02_bucket_policy_before.json"
```

切り戻し後確認:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/rollback/01_bucket_policy_rollback.json"
```

差分確認:

```bash
diff -u \
  "$EVIDENCE_DIR/before/02_bucket_policy_before.json" \
  "$EVIDENCE_DIR/rollback/01_bucket_policy_rollback.json" \
  > "$EVIDENCE_DIR/rollback/02_rollback_policy_diff.txt" || true
```

確認ポイント:

- 変更前Policyと一致する
- Policy Statusが変更前と同じ
- アプリケーションや連携が復旧している
- CloudTrailに切り戻し操作が記録される

### 26.2 変更前Policyが存在しなかった場合

変更前にBucket Policyが存在しなかった場合は、Bucket Policyを削除する。

```bash
aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER"
```

確認:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_BUCKET_OWNER"
```

期待値:

```text
NoSuchBucketPolicy
```

注意:

- 削除は影響が大きい
- 「変更前Policyが存在しなかった」証跡がある場合にのみ使う
- 他者が作業中にPolicyを追加していないか確認する

## 27. 中断・切り戻し判断基準

| 状況 | 判断 |
| :--- | :--- |
| `put-bucket-policy` が失敗した | 作業中断、エラー内容確認 |
| `IsPublic=true` になった | 即時切り戻し候補 |
| 既存Statementが消えた | 即時切り戻し候補 |
| 想定外PrincipalへのAllowが入った | 即時切り戻し候補 |
| 正常なアプリ連携がAccessDeniedになる | 原因確認、必要なら切り戻し |
| CloudTrailに想定外ユーザーの変更がある | 作業中断、関係者へ確認 |
| Public Access Blockを弱める必要が出た | 別承認、別手順に分離 |

## 28. よくあるエラーと確認ポイント

### 28.1 NoSuchBucketPolicy

意味:

- Bucket Policyが存在しない

対応:

- 変更前Policyなしとして記録する
- 切り戻しは `delete-bucket-policy` になる

### 28.2 AccessDenied

確認ポイント:

- 実行主体に `s3:GetBucketPolicy`、`s3:PutBucketPolicy`、`s3:DeleteBucketPolicy` 権限があるか
- 作業主体がバケット所有アカウントに属しているか
- Organizations SCPで制限されていないか
- VPC Endpoint Policyで制限されていないか
- Permission Boundaryで制限されていないか

### 28.3 MethodNotAllowed

確認ポイント:

- バケット所有アカウント以外のPrincipalで実行していないか
- Cross-accountでBucket Policy APIを操作しようとしていないか

### 28.4 MalformedPolicy

確認ポイント:

- JSON構文が正しいか
- `Principal`、`Action`、`Resource`、`Condition` の形式が正しいか
- バケットARNとオブジェクトARNが正しいか
- 配列と文字列の使い分けが正しいか

### 28.5 Invalid principal in policy

確認ポイント:

- IAM RoleやUserのARNが存在するか
- 削除済みPrincipalのIDが残っていないか
- 外部AWSアカウントIDが正しいか
- サービスPrincipalが正しいか
- リージョン別サービスPrincipalの要件がないか

### 28.6 Policy has invalid resource

確認ポイント:

- バケットARNが `arn:aws:s3:::bucket-name`
- オブジェクトARNが `arn:aws:s3:::bucket-name/*`
- 余分なスラッシュやスペースがないか
- バケット名を間違えていないか

## 29. GUIで確認する場合

AWS Management Consoleでは、以下を見る。

```text
S3
  -> Buckets
  -> <bucket-name>
  -> Permissions
  -> Bucket policy
```

証跡候補:

- 変更前Bucket Policy画面
- 変更後Bucket Policy画面
- Public Access Block画面
- Bucket Policy Status相当の表示
- Access Analyzerや警告表示
- CloudTrailの `PutBucketPolicy` イベント画面
- 差分ツール画面

注意:

- GUIで編集すると整形が変わる場合がある
- GUIのVisual editorがPolicyを再構成する場合がある
- 本番手順では、レビュー済みJSONファイルを使う方が差分を管理しやすい

## 30. 手順書に書く項目

Bucket Policy変更手順書には、以下を含める。

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | 何のためにPolicyを変更するか |
| 対象 | Account、Region、Bucket |
| 変更前状態 | Policy、Policy Status、Public Access Block |
| 変更内容 | 追加、変更、削除するStatement |
| 影響範囲 | アプリ、外部連携、CloudFront、ログ配送など |
| 事前確認 | Caller Identity、Bucket存在、既存Policy |
| 変更手順 | `put-bucket-policy` など |
| 変更後確認 | Policy再取得、Policy Status、動作確認 |
| CloudTrail確認 | PutBucketPolicy、DeleteBucketPolicy |
| 切り戻し | 変更前Policy再適用または削除 |
| 証跡 | CLI JSON、差分、スクリーンショット |
| 判断基準 | OK / NG / 中断条件 |

## 31. Bucket Policy調査結果テンプレート

```text
対象バケット:
  <bucket-name>

確認日時:
  <yyyy-mm-dd hh:mm>

確認者:
  <name>

Bucket Policy:
  あり / なし

Statement数:
  <number>

Public Allow:
  なし / あり / 要確認

明示的Deny:
  なし / あり

TLS必須化:
  あり / なし / 要確認

外部AWSアカウント許可:
  なし / あり / 要確認

AWSサービスPrincipal許可:
  なし / あり / 要確認

VPC Endpoint条件:
  なし / あり / 要確認

Bucket Policy Status:
  Publicではない / Public / 要確認

Access Analyzer検証:
  OK / Warningあり / Errorあり / 未実施

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 32. Teams報告例

### 32.1 作業前

```text
S3バケット <bucket-name> のBucket Policy変更について、
変更前Policy、Policy Status、Public Access Blockを取得しました。
既存Statementを保持したうえで、<変更内容> のStatementのみ追加/修正します。
変更用JSONは構文確認とAccess Analyzer検証を行い、
差分確認後にレビュー依頼します。
異常時は変更前Policyを再適用して切り戻します。
```

### 32.2 作業後

```text
S3バケット <bucket-name> のBucket Policy変更は完了しました。
変更後Policyを再取得し、差分は想定したStatementのみであることを確認しました。
Bucket Policy StatusはPublicではありません。
関連アプリ/連携の動作確認も完了し、CloudTrailにPutBucketPolicyイベントが記録されていることを確認済みです。
切り戻しは不要です。
```

### 32.3 中断時

```text
S3バケット <bucket-name> のBucket Policy変更作業で想定外の結果を確認したため、
追加作業は行わず中断しました。
事象は <事象> です。
変更前Policyは取得済みであり、必要に応じて切り戻し可能です。
影響範囲と対応案を整理して共有します。
```

## 33. 公式ドキュメント

- [get-bucket-policy - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-policy.html)
- [put-bucket-policy - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-policy.html)
- [delete-bucket-policy - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/s3api/delete-bucket-policy.html)
- [get-bucket-policy-status - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-policy-status.html)
- [Bucket policies for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-policies.html)
- [Examples of Amazon S3 bucket policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [Policies and permissions in Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-policy-language-overview.html)
- [IAM JSON policy element reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html)
- [validate-policy - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/validate-policy.html)
- [Validate policies with IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html)

