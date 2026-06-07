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

・作業に必要な変数が空でないことを確認する

```bash
printf "$PROFILE\n$REGION\n$EXPECTED_ACCOUNT_ID\n$BUCKET\n"
```

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

if [ "$ACCOUNT_ID" != "EXPECTED_ACCOUNT_ID" ]; then
    echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
    return 1 2>/dev/null || exit 1
fi

echo "Account check OK: $ACCOUNT_ID"
```

## 4. 対象S3バケットの存在確認

・対象バケット名が空でないことを確認する
・対象バケットが存在することを確認する
・現在の認証情報で対象バケットへアクセスできることを確認する
・バケット所有者が想定AWSアカウントであることを確認する

## 5. S3バケット一覧の確認

・AWSアカウント内のS3バケット一覧を取得する
・対象バケットが一覧に存在することを確認する
・想定外または用途不明のバケットがないか確認する
・取得結果を証跡として保存する

## 6. 対象S3バケットのリージョン確認

・対象バケットが配置されているリージョンを確認する
・確認結果が想定リージョンと一致することを確認する
・取得結果を証跡として保存する

## 7. Account-level Public Access Blockの確認

・AWSアカウント全体のPublic Access Block設定を確認する
・4つの公開防止設定が有効か確認する
・未設定の場合はエラー内容を証跡として保存する
・設定変更時にアカウント内の全バケットへ影響することを認識する

## 8. Bucket-level Public Access Blockの確認

・対象バケットのPublic Access Block設定を確認する
・BlockPublicAclsが有効であることを確認する
・IgnorePublicAclsが有効であることを確認する
・BlockPublicPolicyが有効であることを確認する
・RestrictPublicBucketsが有効であることを確認する
・取得結果を証跡として保存する

## 9. Bucket Policy StatusによるPublic判定の確認

・対象バケットのPublic判定を確認する
・IsPublicがFalseであることを確認する
・取得結果を証跡として保存する
・IsPublicがFalseでも、他のアクセス設定を引き続き確認する

## 10. Bucket Policyの取得と内容確認

・現在設定されているBucket Policyを取得する
・ポリシーを読みやすいJSON形式で保存する
・EffectがAllowかDenyか確認する
・Principalに指定されているアクセス主体を確認する
・許可または拒否されているActionを確認する
・対象となるResourceを確認する
・アクセス条件を定義するConditionを確認する
・非TLS通信を拒否する設定が存在することを確認する
・想定外の公開許可が存在しないことを確認する

## 11. Object Ownershipの確認

・対象バケットのObject Ownership設定を確認する
・BucketOwnerEnforcedが設定されていることを確認する
・ACLを使用しないアクセス管理になっていることを確認する
・取得結果を証跡として保存する

## 12. ACLの確認

・対象バケットのACLを確認する
・バケット所有者だけが権限を持っていることを確認する
・AllUsersへの権限が存在しないことを確認する
・AuthenticatedUsersへの権限が存在しないことを確認する
・Public向けのREADまたはWRITE権限が存在しないことを確認する
・取得結果を証跡として保存する

## 13. デフォルト暗号化設定の確認

・対象バケットのデフォルト暗号化設定を確認する
・SSE-S3またはSSE-KMSが設定されていることを確認する
・使用されている暗号化方式を確認する
・SSE-KMSの場合は使用するKMSキーも確認する
・SSE-Cがブロックされているか確認する
・取得結果を証跡として保存する

## 14. Versioning設定の確認

・対象バケットのVersioning設定を確認する
・Versioningが有効、停止、未設定のどれであるか確認する
・誤削除や上書きから復旧できる構成か確認する
・未設定の場合は改善候補として整理する
・取得結果を証跡として保存する

## 15. Server Access Logging設定の確認

・対象バケットのServer Access Logging設定を確認する
・ログ保存先バケットとプレフィックスを確認する
・ログ保存先バケットのセキュリティ設定も確認する
・未設定の場合は要件やCloudTrailとの役割分担を確認する
・取得結果を証跡として保存する

## 16. Static Website Hosting設定の確認

・対象バケットのStatic Website Hosting設定を確認する
・S3 Webサイトとして公開されていないことを確認する
・設定が存在しない場合は、未設定を示すエラーを証跡として保存する
・設定が存在する場合は、公開要件と影響範囲を確認する

## 17. CORS設定の確認

・対象バケットのCORS設定を確認する
・許可されている接続元を確認する
・許可されているHTTPメソッドを確認する
・ワイルドカードによる過剰な許可がないか確認する
・設定が存在しない場合は、未設定を示すエラーを証跡として保存する

## 18. S3 Access Pointの確認

・対象バケットに関連付けられたAccess Pointを確認する
・想定外のAccess Pointが存在しないことを確認する
・Access PointのNetwork OriginがInternetまたはVPCのどちらか確認する
・Access Point Policyによる想定外のアクセス許可がないか確認する
・取得結果を証跡として保存する

## 19. バケットタグの確認

・対象バケットに設定されているタグを確認する
・所有者や管理担当者を識別できるタグがあるか確認する
・システム名、環境、用途を識別できるタグがあるか確認する
・機密区分やデータ分類を示すタグがあるか確認する
・タグが未設定の場合は運用管理上の改善候補として整理する

## 20. 保存した証跡ファイルの確認

・保存した証跡ファイルの一覧を確認する
・必要な確認結果がすべて保存されていることを確認する
・空の証跡ファイルが存在しないことを確認する
・未設定を示すエラー内容も証跡として保存されていることを確認する
・証跡ファイル名から確認内容を判断できることを確認する

## 21. 良好な設定と改善候補の整理

・現在有効になっているセキュリティ設定を整理する
・未設定または要件確認が必要な設定を整理する
・問題がある設定と、単なる改善候補を区別する
・確認結果を一覧表にまとめる

## 22. 影響調査が必要な項目の整理

・改善候補を変更した場合の影響範囲を整理する
・対象バケットを利用するアプリケーションやIAM Roleを確認する
・Account-level設定による他バケットへの影響を確認する
・暗号化やVersioningによるコストへの影響を確認する
・ログ出力による保存先、権限、コストへの影響を確認する
・変更前に関係者へ確認すべき事項を整理する

## 23. 作業結果と証跡保存先の報告

・作業対象のAWSアカウントとS3バケットを記載する
・実施した確認内容を記載する
・良好だった設定を記載する
・改善候補と影響調査が必要な項目を記載する
・設定変更を実施していないことを明記する
・証跡保存先を記載する
・関係者へ確認が必要な事項を記載する
