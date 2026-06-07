# Day 1 Learning

## 確認順序

1. AWSアカウント・リージョン・対象バケット確認
2. バケット存在確認
3. Account-level Public Access Block
4. Bucket-level Public Access Block
5. Bucket Policy Status
6. Bucket Policy
7. Object Ownership・ACL
8. 暗号化
9. Versioning・Server Access Logging
10. Website・CORS・Access Point・タグ
11. 結果整理・報告

## 作業管理情報

- 作業日時:
- 作業者:
- 作業番号・申請番号:
- 対象環境: 学習環境
- 作業目的: S3セキュリティ設定の変更前確認
- 変更作業: なし

実案件では、承認済みの作業手順書で対象アカウント、対象リージョン、対象バケット、作業内容を確認してから作業を開始します。

## スクリーンショット取得ルール

- 対象バケット名と確認対象の設定値が読み取れる範囲を撮影します。
- 可能な範囲で操作対象アカウントを識別できる情報を含めます。
- パスワード、アクセスキー、個人情報、不要な別システムの情報を含めません。
- 編集画面を開いた場合でも、承認前は保存や変更を行いません。
- ファイル名から確認内容が分かるようにします。

## 1. 作業対象確認

- AWSアカウントID: 445405559057
- リージョン: ap-northeast-1
- 対象バケット: nobu-terraform-iac-lab-upload
- 作業内容: S3セキュリティ設定の確認
- 設定変更: なし

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. S3を開き、対象バケットが存在することを確認する
5. 対象バケットのリージョンが東京リージョンであることを確認する

#### 取得するスクリーンショット

- `01_操作アカウント確認.png`
- `02_S3対象バケット確認.png`

### AWS CLI

#### アカウント確認

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

期待値:

```text
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
```

#### バケット存在確認

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

結果の読み方:

- 正常終了した場合、バケットが存在し、現在の認証情報でアクセス可能です。
- `403`の場合、IAM権限不足または想定した所有アカウントとの不一致などが考えられます。
- `404`の場合、バケットが存在しない可能性があります。
- 失敗時のエラーだけでは原因を断定せず、バケット名、所有アカウント、IAM権限を確認します。

#### バケットリージョン確認

```bash
aws s3api get-bucket-location \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
LocationConstraint: ap-northeast-1
```

## 2. Account-level Public Access Block

### Webコンソールで確認する場所

1. Amazon S3コンソールを開く
2. 左側メニューの「アカウントと組織の設定」を選択
3. 「このアカウントのパブリックアクセスブロック設定」を確認する
4. 4項目の有効・無効を確認する

今回は確認だけなので、「編集」は押しません。

### 取得するスクリーンショット

- `03_Account-level_Public_Access_Block確認.png`

画面内に以下が含まれるようにします。

- 「このアカウントのパブリックアクセスブロック設定」
- 4項目の現在値
- 操作対象アカウントを識別できる情報

### AWS CLI

```bash
aws s3control get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --account-id 445405559057 \
  --output table \
  --no-cli-pager
```

現在の環境では、次の結果になる想定です。

```text
NoSuchPublicAccessBlockConfiguration
```

### 結果の読み方

```text
Account-level設定: 未設定
Bucket-level設定: 後続で確認
現時点の判定: 即時変更せず、影響調査が必要な改善候補
```

- `NoSuchPublicAccessBlockConfiguration`の場合は、Account-level Public Access Blockが未設定であると判断します。
- `AccessDenied`など別のエラーの場合は未設定と判断せず、IAM権限や実行環境を確認します。
- アカウント単位の設定を有効にすると、そのアカウントが所有する全バケットとAccess Pointに影響します。
- Account、Bucket、Access Point、Organizationsで設定が異なる場合、S3は有効な設定のうち最も制限の強い組み合わせを適用します。

### 手順書への記載例

```text
Account-level Public Access Blockを確認した結果、未設定であることを確認した。
本設定を有効化した場合、AWSアカウント内の全S3バケットへ影響するため、
変更は実施せず、公開要件および利用状況の影響調査が必要と判断した。
```

## 3. Bucket-level Public Access Block確認

### Webコンソール

1. 対象バケットのアクセス許可画面を開く
2. 「ブロックパブリックアクセス（バケット設定）」を確認する
3. 「すべてのパブリックアクセスをブロック」がオンであることを確認する
4. 4項目がすべてオンであることを確認する
5. 「編集」は押さない

確認項目

```text
BlockPublicAcls
IgnorePublicAcls
BlockPublicPolicy
RestrictPublicBuckets
```

取得するスクリーンショット

- `04_Bucket-level_Public_Access_Block確認.png`

### AWS CLI

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待結果

```text
BlockPublicAcls        True
IgnorePublicAcls       True
BlockPublicPolicy      True
RestrictPublicBuckets  True
```

### 結果の読み方

- 4項目すべてが`True`なら、対象バケット単位の公開防止設定は良好です。
- Public Access Blockだけでは安全性を完全には判断できないため、後続でBucket Policy、ACL、Access Pointも確認します。

### 手順書への記載例

```text
対象バケットのBucket-level Public Access Blockを確認した。
4つの公開防止設定はすべて有効であり、設定状態は良好である。
設定変更は実施していない。
```

## 4. Bucket Policy StatusによるPublic判定確認
対象バケットのBucket Policyなどが、S3からPublicと判定されていないことを確認する。設定変更は行わない。

### Webコンソール
- 対象バケットを開く
- 「アクセス許可」タブを開く
- 「ブロックパブリックアクセス」と「バケットポリシー」を確認する
- パブリックアクセスに関する警告が表示されていないことを確認する
- 「このバケットに対してブロックパブリックアクセス設定が有効」と表示されていることを確認する
URL: https://ap-northeast-1.console.aws.amazon.com/s3/buckets/nobu-terraform-iac-lab-upload?region=ap-northeast-1&tab=permissions

Webコンソールでは、必ずしもIsPublic=Falseという値が直接表示されるとは限らない。正確なPublic判定はAWS CLIで確認する。

取得するスクリーンショット
05_Bucket_Policy_Status確認.png

以下が読み取れる範囲を撮影する。

- 対象バケット名
- パブリックアクセスがブロックされていること
- バケットポリシーの設定状態
- Publicアクセスに関する警告がないこと

### AWS CLI
```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待結果:
```text
-------------------------
| GetBucketPolicyStatus |
+-----------------------+
||    PolicyStatus     ||
|+-----------+---------+|
||  IsPublic |  False  ||
|+-----------+---------+|
```
値だけを確認する場合:
```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query 'PolicyStatus.IsPublic' \
  --output text \
  --no-cli-pager
```

期待結果:
False

### 結果の読み方
- IsPublic=False: Bucket PolicyなどによりPublicと判定されていない
- IsPublic=True: Publicアクセスを許可する設定が存在する可能性があるため、影響調査が必要
- AccessDenied: Publicではないという意味ではなく、確認権限が不足している可能性がある

IsPublic=Falseでも、次の設定確認は継続する。
```text
Bucket Policy
ACL
Access Point Policy
IAM Policy
VPC Endpoint Policy
```

### 手順書への記載例
```text
対象バケットのBucket Policy Statusを確認した結果、
IsPublicはFalseであり、Publicと判定されていないことを確認した。

なお、IsPublic=Falseのみではアクセス制御全体の安全性を判断できないため、
Bucket Policy、ACLおよびAccess Pointについても継続して確認する。

設定変更は実施していない。
```

## 5. Bucket Policyの確認
現在設定されているアクセス制御ルールを読み取ります。

### Webコンソール
1. 対象バケットの「アクセス許可」タブを開く
2. 「バケットポリシー」まで移動する
3. 「編集」「削除」は押さず、JSONを確認する

取得するスクリーンショット:

06_Bucket_Policy確認.png
対象バケット名とポリシー全体が読み取れるように撮影します。

### AWS CLI
ポリシー本文を表示します。
```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager
```
### 確認ポイント
今回の期待値:
```text
Sid       : DenyInsecureTransport
Effect    : Deny
Principal : *
Action    : s3:*
Condition : aws:SecureTransport=false
```
読み方:
- Effect: Deny: 条件に一致するアクセスを拒否する
- Principal: "*": すべてのアクセス主体が対象
- Action: s3:*: すべてのS3操作が対象
- バケットARNと/*: バケット操作とオブジェクト操作の両方が対象
- aws:SecureTransport=false: HTTPSを使用しない通信だけが拒否対象
- Principal: "*"でも、今回はAllowではなく条件付きのDenyなので、Publicアクセスを許可する設定ではありません。

### 手順書への記載例
```text
対象バケットのBucket Policyを確認した。

非TLS通信を拒否するDenyInsecureTransportが設定されており、
HTTPによるすべてのS3操作が拒否されることを確認した。

Publicアクセスを許可するStatementは確認されなかった。
設定変更は実施していない。
```

## 6. Object Ownership・ACLの確認
Object OwnershipとACLを確認し、ACL経由でPublicアクセスが許可されていないことを確認します。設定変更は行いません。

### Webコンソール
対象バケットの「アクセス許可」タブで、次のセクションを確認します。

- 「オブジェクト所有者」を確認する
- 「ACL無効（推奨）」が選択されていることを確認する
- 「アクセスコントロールリスト（ACL）」を確認する
- バケット所有者以外への権限付与がないことを確認する
- 「編集」は押さない

期待する状態:
```text
オブジェクト所有者:
ACL無効
バケット所有者の強制

ACL:
バケット所有者のみFULL_CONTROL
Everyoneへの権限なし
AuthenticatedUsersへの権限なし
```
取得するスクリーンショット
```text
07_Object_Ownership確認.png
08_Bucket_ACL確認.png
```
### Object OwnershipのAWS CLI確認
```bash
aws s3api get-bucket-ownership-controls \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```
期待結果:
```text
ObjectOwnership: BucketOwnerEnforced
```
結果の読み方
- BucketOwnerEnforcedの場合:
- ACLは無効化されている
- バケット所有者がすべてのオブジェクトを所有する
- IAM PolicyやBucket Policyを使用してアクセスを管理する
- ACLを指定したオブジェクトアップロードは失敗する可能性がある

### ACLのAWS CLI確認
```bash
aws s3api get-bucket-acl \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```
期待結果:
```text
Grantee Type : CanonicalUser
Permission   : FULL_CONTROL
```
### ACLで注意する項目
以下のURIや権限が存在する場合は、Publicアクセスの可能性があるため調査します。
```url
http://acs.amazonaws.com/groups/global/AllUsers
http://acs.amazonaws.com/groups/global/AuthenticatedUsers
```
```text
READ
WRITE
READ_ACP
WRITE_ACP
FULL_CONTROL
```

今回の期待値は、バケット所有者のCanonicalUserに対するFULL_CONTROLのみです。

### 手順書への記載例
```text
対象バケットのObject OwnershipおよびACLを確認した。

Object OwnershipはBucketOwnerEnforcedであり、ACLは無効化されている。
ACLにはバケット所有者のFULL_CONTROLのみが設定されており、
AllUsersおよびAuthenticatedUsersへの権限付与は確認されなかった。

設定変更は実施していない。
```

## 7. デフォルト暗号化設定の確認

保存される新規オブジェクトが、どの暗号化方式で暗号化されるか確認します。設定変更は行いません。

### Webコンソール
- 対象バケットを開く
- **「プロパティ」**タブを開く
- 「デフォルトの暗号化」まで移動する
- 暗号化タイプを確認する
- 「編集」は押さない

今回の期待値:
```text
暗号化タイプ: Amazon S3 マネージドキーによるサーバー側の暗号化（SSE-S3）
暗号化キータイプ: SSE-S3
```
取得するスクリーンショット
```text
09_デフォルト暗号化確認.png
```
対象バケット名、暗号化タイプ、バケットキー設定などが読み取れる範囲を撮影します。

### AWS CLI
```bash
aws s3api get-bucket-encryption \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

今回の期待値:
```text
SSEAlgorithm            : AES256
BucketKeyEnabled        : False
BlockedEncryptionTypes  : SSE-C
```

結果の読み方
- AES256: S3管理キーを使用するSSE-S3が設定されています。
- aws:kms: AWS KMSキーを使用するSSE-KMSです。KMS Key Policyや利用権限も確認します。
- aws:kms:dsse: 二層のKMS暗号化を使用するDSSE-KMSです。
- BucketKeyEnabled=False: SSE-S3では問題ありません。S3 Bucket Keyは主にSSE-KMSのKMSリクエストコスト削減に使用します。
- BlockedEncryptionTypes: SSE-C: 利用者が提供する暗号鍵を使うSSE-Cが拒否されています。
- Amazon S3では、すべての新規オブジェクトが最低でもSSE-S3で自動暗号化されます。ただし、金融案件では要件によりSSE-KMSやDSSE-KMSが指定される可能性があります。

### 追加の確認ポイント
SSE-KMSまたはDSSE-KMSの場合は、次も確認します。
```text
・使用しているKMSキー
・KMS Key Policy
・アプリケーションIAM Roleのkms:Encrypt / kms:Decrypt権限
・クロスアカウント利用の有無
・KMS利用料金とリクエストクォータ
```

手順書への記載例
```text
対象バケットのデフォルト暗号化設定を確認した。

暗号化方式はSSE-S3（AES256）であり、新規オブジェクトが
S3管理キーにより暗号化されることを確認した。
また、SSE-Cはブロックされている。

設定変更は実施していない。
```

## 8. Versioning・Server Access Loggingの確認

誤削除・上書きへの対策と、S3へのアクセス記録設定を確認します。設定変更は行いません。

### VersioningのWebコンソール確認

1. 対象バケットを開く
2. **「プロパティ」**タブを開く
3. 「バケットのバージョニング」を確認する
4. 「編集」は押さない

今回の期待値:

```text
バケットのバージョニング: 無効
```

取得するスクリーンショット:

```text
10_Versioning確認.png
```

### VersioningのAWS CLI確認

```bash
aws s3api get-bucket-versioning \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

現在のバケットでは、未設定のため何も表示されない可能性があります。

値を確認する場合:

```bash
aws s3api get-bucket-versioning \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query '{Status:Status,MFADelete:MFADelete}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- `Enabled`: Versioning有効
- `Suspended`: 過去に有効化され、現在は停止中
- 値が空または`None`: 一度も有効化されていない
- `MFADelete=Enabled`: バージョンの完全削除などにMFAが必要

Versioningを有効化すると、誤削除や上書きから復旧しやすくなります。一方で、旧バージョンの保存料金やライフサイクル管理を検討する必要があります。

### Server Access LoggingのWebコンソール確認

1. 同じ「プロパティ」タブを開く
2. 「サーバーアクセスのログ記録」を確認する
3. ログ記録の有効・無効を確認する
4. 有効な場合は、保存先バケットとプレフィックスを確認する
5. 「編集」は押さない

今回の期待値:

```text
サーバーアクセスのログ記録: 無効
```

取得するスクリーンショット:

```text
11_Server_Access_Logging確認.png
```

### Server Access LoggingのAWS CLI確認

```bash
aws s3api get-bucket-logging \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

未設定の場合、何も表示されない可能性があります。

設定済みの場合は、次のような情報が表示されます。

```text
LoggingEnabled
TargetBucket
TargetPrefix
```

### 結果の読み方

- 出力なし: Server Access Logging未設定
- `TargetBucket`: ログ保存先バケット
- `TargetPrefix`: ログオブジェクトの先頭文字列

Server Access Loggingは、S3バケットへのリクエストを記録します。CloudTrailのS3データイベントとは目的、形式、料金、配信方法が異なるため、要件に応じて使い分けます。

有効化する場合は、次の影響調査が必要です。

- ログ保存先バケットは同一AWSアカウント・同一リージョンか
- 保存先バケットポリシーで`logging.s3.amazonaws.com`を許可できるか
- ログ保存料金とライフサイクル設定
- 保存先自身のログ記録によるログループが発生しないか
- CloudTrailデータイベントとの役割分担

### 手順書への記載例

```text
対象バケットのVersioningおよびServer Access Loggingを確認した。

Versioningは未設定であり、誤削除・上書き時の復旧対策として
有効化を検討する余地がある。

Server Access Loggingは未設定であり、アクセス監査要件および
CloudTrailデータイベントとの役割分担を確認する必要がある。

設定変更は実施していない。
```

## 9. Website・CORS・Access Point・タグの確認

対象バケットに、想定外の公開経路やアクセス経路が設定されていないか確認します。設定変更は行いません。

### Static Website HostingのWebコンソール確認

1. 対象バケットを開く
2. **「プロパティ」**タブを開く
3. 「静的ウェブサイトホスティング」を確認する
4. 「編集」は押さない

今回の期待値:

```text
静的ウェブサイトホスティング: 無効
```

取得するスクリーンショット:

```text
12_Static_Website_Hosting確認.png
```

### Static Website HostingのAWS CLI確認

```bash
aws s3api get-bucket-website \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

未設定の場合の期待結果:

```text
NoSuchWebsiteConfiguration
```

### 結果の読み方

- `NoSuchWebsiteConfiguration`: Static Website Hosting未設定
- `IndexDocument`: Webサイトのインデックスドキュメント
- `ErrorDocument`: エラー表示用ドキュメント
- `RedirectAllRequestsTo`: 別のホストなどへのリダイレクト設定

Static Website Hostingが有効な場合は、公開要件、Bucket Policy、CloudFront利用状況などを確認します。

---

### CORSのWebコンソール確認

1. 対象バケットの**「アクセス許可」**タブを開く
2. 「Cross-Origin Resource Sharing（CORS）」を確認する
3. 設定されている場合は、許可するオリジンやHTTPメソッドを確認する
4. 「編集」は押さない

今回の期待値:

```text
CORS設定: 未設定
```

取得するスクリーンショット:

```text
13_CORS確認.png
```

### CORSのAWS CLI確認

```bash
aws s3api get-bucket-cors \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

未設定の場合の期待結果:

```text
NoSuchCORSConfiguration
```

### 結果の読み方

- `NoSuchCORSConfiguration`: CORS未設定
- `AllowedOrigins`: S3へのクロスオリジンアクセスを許可する接続元
- `AllowedMethods`: 許可するHTTPメソッド
- `AllowedHeaders`: ブラウザから送信可能なHTTPヘッダー
- `ExposeHeaders`: ブラウザから参照可能なレスポンスヘッダー

次のような設定がある場合は、要件と影響範囲を確認します。

```text
AllowedOrigins: *
AllowedMethods: PUT、POST、DELETE
AllowedHeaders: *
```

CORSはブラウザによるクロスオリジンアクセスを制御する設定です。CORSで許可されていても、Bucket PolicyやIAM Policyによるアクセス許可が別途必要です。

---

### S3 Access PointのWebコンソール確認

1. 対象バケットを開く
2. **「アクセスポイント」**タブを開く
3. 対象バケットに関連付けられたAccess Pointを確認する
4. Access Pointが存在する場合は、ネットワークオリジンとポリシーを確認する
5. 作成や編集は行わない

今回の期待値:

```text
Access Point: なし
```

取得するスクリーンショット:

```text
14_S3_Access_Point確認.png
```

### S3 Access PointのAWS CLI確認

```bash
aws s3control list-access-points \
  --profile learning \
  --region ap-northeast-1 \
  --account-id 445405559057 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table \
  --no-cli-pager
```

Access Pointが存在しない場合、一覧に何も表示されない可能性があります。

### 結果の読み方

- 一覧が空: 対象バケットにAccess Pointなし
- `NetworkOrigin=VPC`: 指定VPCからのみアクセス可能
- `NetworkOrigin=Internet`: インターネット由来のアクセスが可能。ただし、実際のアクセス可否はAccess Point PolicyやBucket Policyなどにも依存する
- `VpcId`: Access Pointに関連付けられたVPC

Access Pointが存在する場合は、Access Point Policyも確認します。

---

### バケットタグのWebコンソール確認

1. 対象バケットの**「プロパティ」**タブを開く
2. 「タグ」を確認する
3. 管理用タグの有無を確認する
4. 「編集」は押さない

今回の期待値:

```text
バケットタグ: 未設定
```

取得するスクリーンショット:

```text
15_バケットタグ確認.png
```

### バケットタグのAWS CLI確認

```bash
aws s3api get-bucket-tagging \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

未設定の場合の期待結果:

```text
NoSuchTagSet
```

### 結果の読み方

- `NoSuchTagSet`: バケットタグ未設定
- `Key`: タグの分類名
- `Value`: タグの設定値

管理対象バケットでは、次のようなタグを使用する場合があります。

```text
Name
Project
Environment
Owner
System
DataClassification
```

タグを追加する場合は、組織の命名規則、コスト配分、運用管理、自動処理への影響を確認します。

### 手順書への記載例

```text
対象バケットのStatic Website Hosting、CORS、Access Pointおよび
バケットタグを確認した。

Static Website HostingおよびCORSは未設定であり、
対象バケットに関連付けられたAccess Pointも確認されなかった。

バケットタグは未設定であり、運用管理上の改善候補として、
組織のタグ付けルールを確認する必要がある。

設定変更は実施していない。
```

## 10. 確認結果の整理・報告

実施したS3セキュリティ設定確認の結果を整理し、良好な設定、改善候補、影響調査が必要な項目を明確にします。

設定変更は実施していません。

### 確認結果一覧

| 確認項目 | 確認結果 | 判定 |
| :--- | :--- | :--- |
| AWSアカウント | 想定アカウントと一致 | 正常 |
| 対象バケット | 存在およびアクセス可能 | 正常 |
| バケットリージョン | `ap-northeast-1` | 正常 |
| Account-level Public Access Block | 未設定 | 改善候補・影響調査必要 |
| Bucket-level Public Access Block | 4項目すべて有効 | 良好 |
| Bucket Policy Status | `IsPublic=False` | 良好 |
| Bucket Policy | 非TLS通信を拒否 | 良好 |
| Object Ownership | `BucketOwnerEnforced` | 良好 |
| ACL | バケット所有者のみ | 良好 |
| デフォルト暗号化 | SSE-S3（AES256） | 有効 |
| Versioning | 未設定 | 改善候補 |
| Server Access Logging | 未設定 | 要件確認・改善候補 |
| Static Website Hosting | 未設定 | 良好 |
| CORS | 未設定 | 良好 |
| Access Point | なし | 想定どおり |
| バケットタグ | 未設定 | 運用管理上の改善候補 |

### 良好な設定

- Bucket-level Public Access Blockの4項目がすべて有効です。
- Bucket Policy Statusは`IsPublic=False`です。
- Bucket Policyで非TLS通信が拒否されています。
- Object Ownershipは`BucketOwnerEnforced`です。
- ACLによるPublicアクセス許可はありません。
- 新規オブジェクトはSSE-S3により暗号化されます。
- Static Website HostingおよびCORSは未設定です。
- 対象バケットにAccess Pointはありません。

### 改善候補

- Account-level Public Access Blockが未設定です。
- Versioningが未設定です。
- Server Access Loggingが未設定です。
- バケットタグが未設定です。

改善候補は、問題があることを直ちに意味するものではありません。システム要件、運用設計、コスト、既存アプリケーションへの影響を調査してから変更を判断します。

### 影響調査が必要な項目

#### Account-level Public Access Block

- アカウント内にPublicアクセスを必要とするバケットが存在しないか
- Access Pointを利用しているシステムが存在しないか
- クロスアカウントアクセスへの影響がないか
- Organizationsのポリシーで同様の設定が適用されていないか

#### Versioning

- 旧バージョン保存によるストレージ料金への影響
- ライフサイクルルールの要否
- 削除済みオブジェクトや旧バージョンの保管期間
- アプリケーションのオブジェクト更新・削除方法への影響

#### Server Access Logging

- ログ保存先バケットの設計
- ログ保存料金とライフサイクル設定
- 保存先バケットポリシーへの影響
- CloudTrailデータイベントとの役割分担
- ログ保存先自身へのログ出力によるループ防止

#### バケットタグ

- 組織のタグ付けルール
- コスト配分タグの要否
- 自動処理や監視で参照されるタグの有無
- システム名、環境、管理者、データ分類の設定値

### 取得するスクリーンショット一覧

```text
01_操作アカウント確認.png
02_S3対象バケット確認.png
03_Account-level_Public_Access_Block確認.png
04_Bucket-level_Public_Access_Block確認.png
05_Bucket_Policy_Status確認.png
06_Bucket_Policy確認.png
07_Object_Ownership確認.png
08_Bucket_ACL確認.png
09_デフォルト暗号化確認.png
10_Versioning確認.png
11_Server_Access_Logging確認.png
12_Static_Website_Hosting確認.png
13_CORS確認.png
14_S3_Access_Point確認.png
15_バケットタグ確認.png
```

### 証跡確認時の注意点

- 対象アカウント、対象バケット、設定値が読み取れることを確認します。
- スクリーンショットの順番が手順書の確認順と一致していることを確認します。
- パスワード、アクセスキー、個人情報が含まれていないことを確認します。
- 設定変更を実施していないことを明記します。
- 未設定を示すエラーと、権限不足などのエラーを区別します。

### 作業結果報告例

```text
対象S3バケットのセキュリティ設定について、変更前確認を実施しました。

Bucket-level Public Access Blockは4項目すべて有効であり、
Bucket Policy StatusはIsPublic=Falseでした。

Bucket Policyでは非TLS通信が拒否されており、
Object OwnershipはBucketOwnerEnforced、ACLはバケット所有者のみでした。
デフォルト暗号化はSSE-S3が有効です。

改善候補として、Account-level Public Access Block、Versioning、
Server Access Loggingおよびバケットタグが未設定であることを確認しました。

各改善候補は、既存システムへの影響および運用要件を確認してから、
設定変更の要否を判断する必要があります。

本確認において設定変更は実施していません。
```

### Teams報告例

```text
S3セキュリティ設定の変更前確認が完了しました。

対象:
nobu-terraform-iac-lab-upload

確認結果:
・Bucket-level Public Access Block: 4項目すべて有効
・Bucket Policy Status: IsPublic=False
・Bucket Policy: 非TLS通信を拒否
・Object Ownership: BucketOwnerEnforced
・デフォルト暗号化: SSE-S3

要確認:
・Account-level Public Access Block: 未設定
・Versioning: 未設定
・Server Access Logging: 未設定
・バケットタグ: 未設定

設定変更は実施していません。
改善候補については、影響調査後に対応要否をご確認ください。
```

### CloudTrail確認について

今回は設定確認のみで、AWSリソースへの設定変更は実施していません。

そのため、変更操作を証明するCloudTrailイベントの確認は不要です。設定変更を実施した場合は、変更後にCloudTrailで次の情報を確認します。

```text
・イベント名
・実行日時
・実行ユーザーまたはIAM Role
・送信元IPアドレス
・対象バケット
・変更内容
・エラーの有無
```
