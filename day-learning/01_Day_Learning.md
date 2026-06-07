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

### 6. Object Ownership・ACLの確認
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


