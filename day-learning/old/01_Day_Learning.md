# 1日目の振り返り

## 1. 作業対象の環境確認

- AWS CLIプロファイルを設定する
- 作業対象リージョンを設定する
- 想定AWSアカウントIDを設定する
- 対象S3バケット名を設定する

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET="nobu-terraform-iac-lab-upload"
```

- 作業に必要な変数が空でないことを確認する

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nBUCKET=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$BUCKET"

for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID BUCKET; do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
  fi
done
```

`ERROR`が表示された場合は、後続の確認を実行せず、対象の変数を設定し直す。

## 2. 証跡保存用ディレクトリの作成

- 実行日時を含む証跡ディレクトリを作成する
- メタデータ保存用ディレクトリを作成する
- 変更前証跡保存用ディレクトリを作成する
- 変更後証跡保存用ディレクトリを作成する
- スクリーンショット保存用ディレクトリを作成する

```bash
WORK_NAME="s3_security_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

## 3. AWS操作アカウントの確認

- 現在使用しているAWSアカウントIDを取得する
- 取得したアカウントIDが想定値と一致することを確認する
- 作業に使用するIAMユーザーまたはIAMロールを確認する
- Caller Identityを証跡として保存する

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
  echo "Expected account: $EXPECTED_ACCOUNT_ID"
  echo "Do not continue."
else
  echo "Account check OK: $ACCOUNT_ID"
fi

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

`ERROR`が表示された場合は、後続の確認を実行しない。

## 4. 対象S3バケットの存在確認

- 対象バケット名が空でないことを確認する
- 対象バケットが存在することを確認する
- 現在の認証情報で対象バケットへアクセスできることを確認する
- バケット所有者が想定AWSアカウントであることを確認する

```bash
HEAD_BUCKET_RESULT="$EVIDENCE_DIR/before/00_head_bucket_result.txt"
HEAD_BUCKET_ERROR="$EVIDENCE_DIR/before/00_head_bucket_error.txt"

if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  2> "$HEAD_BUCKET_ERROR"; then

  rm -f "$HEAD_BUCKET_ERROR"
  printf 'Bucket access check succeeded.\nBucket: %s\nOwner: %s\nExitCode: 0\n' \
    "$BUCKET" "$EXPECTED_ACCOUNT_ID" \
    > "$HEAD_BUCKET_RESULT"

  cat "$HEAD_BUCKET_RESULT"
else
  HEAD_BUCKET_RC=$?
  printf 'Bucket access check failed.\nBucket: %s\nOwner: %s\nExitCode: %s\n' \
    "$BUCKET" "$EXPECTED_ACCOUNT_ID" "$HEAD_BUCKET_RC" \
    > "$HEAD_BUCKET_RESULT"

  cat "$HEAD_BUCKET_RESULT"
  cat "$HEAD_BUCKET_ERROR"
fi
```

失敗した場合は、バケット名、所有アカウント、IAM権限を確認してから後続の確認へ進む。

## 5. S3バケット一覧の確認

- AWSアカウント内のS3バケット一覧を取得する
- 対象バケットが一覧に存在することを確認する
- 想定外または用途不明のバケットがないか確認する
- 取得結果を証跡として保存する

```bash
aws s3api list-buckets \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/01_list_buckets.json"

aws s3api list-buckets \
  --profile "$PROFILE" \
  --query 'Buckets[*].{Name:Name,CreationDate:CreationDate}' \
  --output table
```
## 6. 対象S3バケットのリージョン確認

- 対象バケットが配置されているリージョンを確認する
- 確認結果が想定リージョンと一致することを確認する
- 取得結果を証跡として保存する

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/02_bucket_location.json"

aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table
```

## 7. Account-level Public Access Blockの確認

- AWSアカウント全体のPublic Access Block設定を確認する
- 4つの公開防止設定が有効か確認する
- 未設定の場合はエラー内容を証跡として保存する
- 設定変更時にアカウント内の全バケットへ影響することを認識する

```bash
# 必要な変数を確認する
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$EVIDENCE_DIR"

# 証跡ファイル名を変数化する
ACCOUNT_PAB_JSON="$EVIDENCE_DIR/before/03_account_public_access_block.json"
ACCOUNT_PAB_ERROR="$EVIDENCE_DIR/before/03_account_public_access_block_error.txt"

if aws s3control get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$ACCOUNT_PAB_JSON" \
  2> "$ACCOUNT_PAB_ERROR"; then

  rm -f "$ACCOUNT_PAB_ERROR"

  echo "Account-level Public Access Block is configured."
  cat "$ACCOUNT_PAB_JSON"
elif grep -q "NoSuchPublicAccessBlockConfiguration" "$ACCOUNT_PAB_ERROR"; then

  rm -f "$ACCOUNT_PAB_JSON"

  echo "Account-level Public Access Block is not configured."
  cat "$ACCOUNT_PAB_ERROR"
else

  rm -f "$ACCOUNT_PAB_JSON"

  echo "ERROR: Account-level Public Access Block could not be retrieved."
  cat "$ACCOUNT_PAB_ERROR"
fi

# 設定済みの場合は、保存したJSONで4項目を確認する。
if [ -s "$ACCOUNT_PAB_JSON" ]; then
  jq '.PublicAccessBlockConfiguration' "$ACCOUNT_PAB_JSON"

  jq -e '
    .PublicAccessBlockConfiguration
    | .BlockPublicAcls == true
      and .IgnorePublicAcls == true
      and .BlockPublicPolicy == true
      and .RestrictPublicBuckets == true
  ' "$ACCOUNT_PAB_JSON" >/dev/null \
    && echo "All account-level Public Access Block settings are true." \
    || echo "WARNING: One or more account-level Public Access Block settings are not true."
fi

# 証跡確認
find "$EVIDENCE_DIR/before" \
    -name '03_account_public_access_block*' \
    -type f \
    -print
```

## 8. Bucket-level Public Access Blockの確認

- 対象バケットのPublic Access Block設定を確認する
- BlockPublicAclsが有効であることを確認する
- IgnorePublicAclsが有効であることを確認する
- BlockPublicPolicyが有効であることを確認する
- RestrictPublicBucketsが有効であることを確認する
- 取得結果を証跡として保存する

```bash
# 作業対象を確認する
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nBUCKET=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$BUCKET" "$EVIDENCE_DIR"

# 証跡ファイル名を設定する
BUCKET_PAB_JSON="$EVIDENCE_DIR/before/04_bucket_public_access_block.json"
BUCKET_PAB_ERROR="$EVIDENCE_DIR/before/04_bucket_public_access_block_error.txt"

# Bucket-level Public Access Blockを取得する
if aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$BUCKET_PAB_JSON" \
  2> "$BUCKET_PAB_ERROR"; then

  rm -f "$BUCKET_PAB_ERROR"

  echo "Bucket-level Public Access Block is configured."
  cat "$BUCKET_PAB_JSON"

elif grep -q "NoSuchPublicAccessBlockConfiguration" "$BUCKET_PAB_ERROR"; then

  rm -f "$BUCKET_PAB_JSON"

  echo "WARNING: Bucket-level Public Access Block is not configured."
  cat "$BUCKET_PAB_ERROR"

else

  rm -f "$BUCKET_PAB_JSON"

  echo "ERROR: Bucket-level Public Access Block could not be retrieved."
  cat "$BUCKET_PAB_ERROR"
fi
```
4項目がすべてtrueであることを確認する。
```bash
if [ -s "$BUCKET_PAB_JSON" ]; then
  echo "=== Public Access Block settings ==="

  jq '.PublicAccessBlockConfiguration' "$BUCKET_PAB_JSON"

  if jq -e '
    .PublicAccessBlockConfiguration
    | .BlockPublicAcls == true
      and .IgnorePublicAcls == true
      and .BlockPublicPolicy == true
      and .RestrictPublicBuckets == true
  ' "$BUCKET_PAB_JSON" >/dev/null; then

    echo "OK: All bucket-level Public Access Block settings are true."
  else
    echo "WARNING: One or more bucket-level Public Access Block settings are not true."
  fi
fi
```

証跡ファイルを確認する。
```bash
find "$EVIDENCE_DIR/before" \
  -name '04_bucket_public_access_block*' \
  -type f \
  -print
```
期待結果
```text
BlockPublicAcls: true
IgnorePublicAcls: true
BlockPublicPolicy: true
RestrictPublicBuckets: true

OK: All bucket-level Public Access Block settings are true.
```
## 9. Bucket Policy StatusによるPublic判定の確認

- 対象バケットのPublic判定を確認する
- IsPublicがFalseであることを確認する
- 取得結果を証跡として保存する
- IsPublicがFalseでも、他のアクセス設定を引き続き確認する

## 10. Bucket Policyの取得と内容確認

- 現在設定されているBucket Policyを取得する
- ポリシーを読みやすいJSON形式で保存する
- EffectがAllowかDenyか確認する
- Principalに指定されているアクセス主体を確認する
- 許可または拒否されているActionを確認する
- 対象となるResourceを確認する
- アクセス条件を定義するConditionを確認する
- 非TLS通信を拒否する設定が存在することを確認する
- 想定外の公開許可が存在しないことを確認する

## 11. Object Ownershipの確認

- 対象バケットのObject Ownership設定を確認する
- BucketOwnerEnforcedが設定されていることを確認する
- ACLを使用しないアクセス管理になっていることを確認する
- 取得結果を証跡として保存する

## 12. ACLの確認

- 対象バケットのACLを確認する
- バケット所有者だけが権限を持っていることを確認する
- AllUsersへの権限が存在しないことを確認する
- AuthenticatedUsersへの権限が存在しないことを確認する
- Public向けのREADまたはWRITE権限が存在しないことを確認する
- 取得結果を証跡として保存する

## 13. デフォルト暗号化設定の確認

- 対象バケットのデフォルト暗号化設定を確認する
- SSE-S3またはSSE-KMSが設定されていることを確認する
- 使用されている暗号化方式を確認する
- SSE-KMSの場合は使用するKMSキーも確認する
- SSE-Cがブロックされているか確認する
- 取得結果を証跡として保存する

## 14. Versioning設定の確認

- 対象バケットのVersioning設定を確認する
- Versioningが有効、停止、未設定のどれであるか確認する
- 誤削除や上書きから復旧できる構成か確認する
- 未設定の場合は改善候補として整理する
- 取得結果を証跡として保存する

## 15. Server Access Logging設定の確認

- 対象バケットのServer Access Logging設定を確認する
- ログ保存先バケットとプレフィックスを確認する
- ログ保存先バケットのセキュリティ設定も確認する
- 未設定の場合は要件やCloudTrailとの役割分担を確認する
- 取得結果を証跡として保存する

## 16. Static Website Hosting設定の確認

- 対象バケットのStatic Website Hosting設定を確認する
- S3 Webサイトとして公開されていないことを確認する
- 設定が存在しない場合は、未設定を示すエラーを証跡として保存する
- 設定が存在する場合は、公開要件と影響範囲を確認する

## 17. CORS設定の確認

- 対象バケットのCORS設定を確認する
- 許可されている接続元を確認する
- 許可されているHTTPメソッドを確認する
- ワイルドカードによる過剰な許可がないか確認する
- 設定が存在しない場合は、未設定を示すエラーを証跡として保存する

## 18. S3 Access Pointの確認

- 対象バケットに関連付けられたAccess Pointを確認する
- 想定外のAccess Pointが存在しないことを確認する
- Access PointのNetwork OriginがInternetまたはVPCのどちらか確認する
- Access Point Policyによる想定外のアクセス許可がないか確認する
- 取得結果を証跡として保存する

## 19. バケットタグの確認

- 対象バケットに設定されているタグを確認する
- 所有者や管理担当者を識別できるタグがあるか確認する
- システム名、環境、用途を識別できるタグがあるか確認する
- 機密区分やデータ分類を示すタグがあるか確認する
- タグが未設定の場合は運用管理上の改善候補として整理する

## 20. 保存した証跡ファイルの確認

- 保存した証跡ファイルの一覧を確認する
- 必要な確認結果がすべて保存されていることを確認する
- 空の証跡ファイルが存在しないことを確認する
- 未設定を示すエラー内容も証跡として保存されていることを確認する
- 証跡ファイル名から確認内容を判断できることを確認する

## 21. 良好な設定と改善候補の整理

- 現在有効になっているセキュリティ設定を整理する
- 未設定または要件確認が必要な設定を整理する
- 問題がある設定と、単なる改善候補を区別する
- 確認結果を一覧表にまとめる

## 22. 影響調査が必要な項目の整理

- 改善候補を変更した場合の影響範囲を整理する
- 対象バケットを利用するアプリケーションやIAM Roleを確認する
- Account-level設定による他バケットへの影響を確認する
- 暗号化やVersioningによるコストへの影響を確認する
- ログ出力による保存先、権限、コストへの影響を確認する
- 変更前に関係者へ確認すべき事項を整理する

## 23. 作業結果と証跡保存先の報告

- 作業対象のAWSアカウントとS3バケットを記載する
- 実施した確認内容を記載する
- 良好だった設定を記載する
- 改善候補と影響調査が必要な項目を記載する
- 設定変更を実施していないことを明記する
- 証跡保存先を記載する
- 関係者へ確認が必要な事項を記載する
