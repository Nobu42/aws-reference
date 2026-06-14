# Day 2 Learning

## 学習開始前に実行するスクリプト

Bucket Policy変更とAWS CLI確認だけを行う場合、開始前スクリプトは不要である。

Railsアプリケーションによる変更前・変更後・切り戻し後の動作確認まで実施する場合は、`sample-vpc`が存在しないときだけ`All_Setup.sh`を実行する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。続いてAnsibleを実行する。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

`PutBucketPolicy`はManagement Eventであるため、CloudTrail一時TrailとS3 Data Eventは不要である。変更履歴はEvent Historyで確認する。

学習終了後、アプリケーション環境を使用しない場合は次を実行する。

```bash
/Users/nobu/aws-reference/scripts/cleanup_network.sh
```

## 実行場所・CloudTrail前提・終了時の状態

Day 2のコマンドは、`02_Day_Learning/`から始まる相対パスを使用する。
作業開始前に、必ず次のディレクトリへ移動する。

```bash
cd /Users/nobu/aws-reference/day-learning
pwd
```

期待値:

```text
/Users/nobu/aws-reference/day-learning
```

### Day 2で使用するディレクトリ

| ディレクトリ | 保存内容 | 終了時の扱い |
|---|---|---|
| `02_Day_Learning/before` | 変更前Policyと適用直前Policy | 確認・報告が終わるまで残す |
| `02_Day_Learning/after` | 変更案と実際に反映されたPolicy | 確認・報告が終わるまで残す |
| `02_Day_Learning/rollback` | 切り戻し前後のPolicy | 確認・報告が終わるまで残す |
| `02_Day_Learning/evidence` | CloudTrailイベントなどの証跡 | 確認・報告が終わるまで残す |

これらはローカル証跡であり、AWSリソースではない。Git管理対象から除外されているため、学習直後に削除する必要はない。

### CloudTrailとData Eventの前提

- `PutBucketPolicy`はCloudTrailのManagement Eventである
- `PutBucketPolicy`はCloudTrail Event Historyから確認できる
- Day 2ではS3 Data Eventを有効化しない
- Day 2のためだけに一時Trailを作成する必要はない
- Day 3で作成した一時Trailが存在していても、Day 2では作成・変更・削除しない

### Day 2終了時のAWS状態

切り戻しドリルまで実施した場合、対象Bucket Policyを変更前の状態へ戻して終了する。

```text
対象バケット:
nobu-terraform-iac-lab-upload

終了時のBucket Policy:
DenyInsecureTransportのみ

削除しないもの:
・対象S3バケット
・S3オブジェクト
・ローカル証跡
```

一時Trailの削除はDay 3の手順で判断する。Day 2の終了処理として削除しない。

## 1. 作業目的・対象・前提条件の確認

S3 Bucket Policyの変更作業を想定し、変更前確認、影響調査、変更、動作確認、CloudTrail確認、切り戻しまでの一連の流れを練習する。

本ドリルでは、承認済みの設定変更だけを実施する。

### 作業管理情報

- 作業日時:
- 作業者:
- 作業番号・申請番号:
- 対象環境: 学習環境
- 作業目的: S3 Bucket Policy変更ドリル
- 変更対象: `nobu-terraform-iac-lab-upload`
- AWSアカウントID: `445405559057`
- リージョン: `ap-northeast-1`
- 変更作業: 後続手順で実施
- 切り戻し方法: 変更前Bucket Policyの再適用

### 作業前の確認事項

1. 対象AWSアカウントが正しいことを確認する
2. 対象バケット名とリージョンが正しいことを確認する
3. 作業内容が承認済みであることを確認する
4. 変更前Bucket Policyを取得できる権限があることを確認する
5. Bucket Policyを変更できる権限があることを確認する
6. 変更後の動作確認方法を確認する
7. 切り戻し条件と切り戻し方法を確認する
8. 関係者への作業開始連絡が必要か確認する

### Webコンソールで確認する場所

1. AWSマネジメントコンソールへログインする
2. 操作対象アカウントが`445405559057`であることを確認する
3. Amazon S3を開く
4. `nobu-terraform-iac-lab-upload`を開く
5. 「アクセス許可」タブを開く
6. 「バケットポリシー」を確認する
7. 「編集」「削除」は押さない

URL:

```text
https://ap-northeast-1.console.aws.amazon.com/s3/buckets/nobu-terraform-iac-lab-upload?region=ap-northeast-1&tab=permissions
```

### AWS CLIによる操作対象確認

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

対象バケットを確認する。

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

期待値:

```text
BucketArn: arn:aws:s3:::nobu-terraform-iac-lab-upload
BucketRegion: ap-northeast-1
AccessPointAlias: false
```

### 変更前に確認する利用者・アクセス経路

- Web EC2に割り当てられたIAM Role
- Rails Active Storageによる画像アップロード
- 管理者によるAWS CLI操作
- Bucket Policyによる明示的な許可・拒否
- IAM Policyによる許可
- S3 Access Pointの有無
- VPC Endpoint Policyの有無
- KMS Key Policyの影響
- クロスアカウントアクセスの有無

### 取得するスクリーンショット

```text
01_操作アカウント確認.png
02_対象バケット確認.png
03_変更前_Bucket_Policy画面.png
```

### 作業開始前の判定

次のいずれかに該当する場合は、Bucket Policyを変更しない。

- 対象アカウントまたは対象バケットが手順書と一致しない
- 変更内容が承認されていない
- 変更前Policyを取得できない
- 影響を受けるアプリケーションやアクセス経路が不明
- 動作確認方法が未確定
- 切り戻し方法が未確定
- 関係者への連絡が完了していない

### 手順書への記載例

```text
S3 Bucket Policy変更作業の事前確認を実施した。

対象AWSアカウント、リージョン、対象バケットが
承認済み作業手順書の記載内容と一致することを確認した。

変更前Policyの取得方法、変更後の動作確認方法、
および切り戻し方法を確認した。

本手順では、後続の承認済み変更手順に従って作業を実施する。
```
## 2. 変更前Bucket Policyの確認

変更前のBucket Policyを確認し、現在のアクセス制御内容を把握する。

この手順では設定変更を行わない。

### Webコンソールで確認する場所

1. Amazon S3コンソールを開く
2. `nobu-terraform-iac-lab-upload`を開く
3. 「アクセス許可」タブを開く
4. 「バケットポリシー」まで移動する
5. 現在設定されているPolicy全体を確認する
6. 「編集」「削除」は押さない

確認URL:

```text
https://ap-northeast-1.console.aws.amazon.com/s3/buckets/nobu-terraform-iac-lab-upload?region=ap-northeast-1&tab=permissions
```

### AWS CLIによる変更前Bucket Policy確認

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

今回の期待値:

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
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
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

### Bucket Policy Statusの確認

```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
IsPublic: False
```

### Statementの確認ポイント

| 項目 | 設定値 | 読み方 |
| :--- | :--- | :--- |
| `Sid` | `DenyInsecureTransport` | Statementを識別する名前 |
| `Effect` | `Deny` | 条件に一致するアクセスを拒否する |
| `Principal` | `*` | すべてのアクセス主体を対象とする |
| `Action` | `s3:*` | すべてのS3操作を対象とする |
| `Resource` | バケットARNとオブジェクトARN | バケット操作とオブジェクト操作の両方を対象とする |
| `Condition` | `aws:SecureTransport=false` | TLSを使用しない通信を拒否する |

### Principalがアスタリスクである理由

```text
"Principal": "*"
```

すべてのアクセス主体が対象となるが、`Effect`は`Deny`である。

このStatementはPublicアクセスを許可する設定ではなく、すべての利用者に対して非TLS通信を拒否する設定である。

### Resourceの確認

```text
arn:aws:s3:::nobu-terraform-iac-lab-upload
```

バケット自体に対する操作を対象とする。

```text
arn:aws:s3:::nobu-terraform-iac-lab-upload/*
```

バケット内のオブジェクトに対する操作を対象とする。

両方を指定することで、バケット操作とオブジェクト操作の両方について非TLS通信を拒否する。

### 確認結果の判定

```text
Bucket Policy: DenyInsecureTransportのみ
非TLS通信: 拒否
Publicアクセスを許可するStatement: なし
Bucket Policy Status: IsPublic=False
設定変更: なし
```

### 想定外の場合の対応

次の設定が確認された場合は、変更を行わず影響調査を実施する。

- `Effect: Allow`が存在する
- `Principal: "*"`を対象としたAllowが存在する
- 想定外のAWSアカウントやIAM RoleがPrincipalに指定されている
- `s3:*`など過剰なActionが許可されている
- Resourceの対象範囲が想定より広い
- Conditionによるアクセス制限が存在しない
- `IsPublic=True`になっている
- 手順書に記載されていないStatementが存在する

### 取得するスクリーンショット

```text
04_変更前_Bucket_Policy確認.png
05_変更前_Bucket_Policy_Status確認.png
```

### 手順書への記載例

```text
対象バケットの変更前Bucket Policyを確認した。

変更前Policyには、非TLS通信を拒否する
DenyInsecureTransport Statementのみが設定されていた。

Publicアクセスを許可するStatementは確認されず、
Bucket Policy StatusはIsPublic=Falseであった。

本確認において設定変更は実施していない。
```
## 3. 変更候補と影響範囲の整理

変更前Bucket Policyの確認結果を基に、変更候補と影響範囲を整理する。

本手順では変更内容の検討だけを行い、Bucket Policyの変更は実施しない。

### 変更前の状態

```text
Bucket Policy:
DenyInsecureTransportのみ

通信要件:
HTTP通信を拒否
HTTPS通信を許可

Bucket Policy Status:
IsPublic=False
```

現在のBucket Policyでは、`aws:SecureTransport=false`の通信を拒否している。

この設定によりHTTP通信は拒否されるが、HTTPS通信で使用されるTLSバージョンまでは制限していない。

### 今回の変更候補

今回のドリルでは、古いTLSバージョンによるアクセスを拒否するPolicyの追加を候補とする。

```text
変更候補:
TLS 1.2未満の通信を拒否する

追加予定Statement名:
DenyOutdatedTLS

変更目的:
S3への通信でTLS 1.2以上を必須とする
```

### 変更候補のStatement

```json
{
  "Sid": "DenyOutdatedTLS",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::nobu-terraform-iac-lab-upload",
    "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
  ],
  "Condition": {
    "Bool": {
      "aws:PrincipalIsAWSService": "false"
    },
    "NumericLessThan": {
      "s3:TlsVersion": "1.2"
    }
  }
}
```

### Statementの読み方

| 項目 | 設定値 | 読み方 |
| :--- | :--- | :--- |
| `Sid` | `DenyOutdatedTLS` | Statementを識別する名前 |
| `Effect` | `Deny` | 条件に一致するアクセスを拒否する |
| `Principal` | `*` | すべてのアクセス主体を対象とする |
| `Action` | `s3:*` | すべてのS3操作を対象とする |
| `Resource` | バケットARNとオブジェクトARN | バケット操作とオブジェクト操作の両方を対象とする |
| `NumericLessThan` | `s3:TlsVersion: 1.2` | TLS 1.2未満の通信を条件とする |
| `aws:PrincipalIsAWSService` | `false` | AWSサービスプリンシパル以外を対象とする |

### `aws:PrincipalIsAWSService`を指定する理由

AWSサービスがユーザーの代わりにS3へアクセスする場合、ネットワーク固有の情報がリクエストコンテキストから削除される場合がある。

TLSバージョンだけを条件にした明示的なDenyを設定すると、AWSサービスからのアクセスを意図せず拒否する可能性がある。

```text
"aws:PrincipalIsAWSService": "false"
```

を条件に追加することで、AWSサービスプリンシパルをDenyの対象から除外する。

### 変更前後の差分

変更前:

```text
DenyInsecureTransport
```

変更後候補:

```text
DenyInsecureTransport
DenyOutdatedTLS
```

既存の`DenyInsecureTransport`は削除しない。

### 想定される影響

TLS 1.2未満を使用する次のクライアントは、対象バケットへアクセスできなくなる可能性がある。

- 古いOSや古いTLSライブラリを使用するサーバー
- 古いAWS SDKを使用するアプリケーション
- 古いAWS CLIを使用する作業端末
- 古いJava RuntimeやOpenSSLを使用する処理
- オンプレミス環境から接続する既存システム
- 外部サービスや連携システム

### 影響調査対象

| 調査対象 | 確認内容 |
| :--- | :--- |
| Railsアプリケーション | 使用しているAWS SDKとTLSバージョン |
| Web EC2 | OS、OpenSSL、Ruby、AWS SDKのバージョン |
| 管理端末 | AWS CLIとTLSライブラリのバージョン |
| オンプレミス連携 | S3への接続方式とTLSバージョン |
| 外部サービス | 対象バケットへのアクセス有無 |
| AWSサービス | 対象バケットへの書き込み・読み取り有無 |
| CloudTrail | S3データイベントによるアクセス元調査の可否 |

### 変更後の動作確認候補

変更後は、最低限次の正常系テストを実施する。

```text
・AWS CLIでバケットへアクセスできること
・Rails Active Storageから画像をアップロードできること
・アップロードした画像を表示できること
・既存オブジェクトを取得できること
・Bucket Policy StatusがIsPublic=Falseのままであること
```

異常系テストとして、TLS 1.2未満のクライアントからアクセスした場合に拒否されることを確認する。

ただし、TLS 1.2未満のテスト環境を安全に準備できない場合は、無理に異常系テストを実施しない。

### 切り戻し条件

次のいずれかが発生した場合は、変更前Bucket Policyへ切り戻す。

- RailsアプリケーションからS3へアクセスできない
- 画像アップロードまたは画像表示に失敗する
- 管理用AWS CLIからS3へアクセスできない
- 想定していたAWSサービス連携が失敗する
- 想定外のアクセス拒否が発生する
- 関係者から切り戻し指示を受ける

### 取得するスクリーンショット

```text
06_変更候補_Policy確認.png
07_影響調査結果確認.png
```

### 手順書への記載例

```text
変更前Bucket Policyを基に、TLS 1.2未満の通信を拒否する
DenyOutdatedTLS Statementの追加を変更候補として整理した。

変更により、古いTLSライブラリ、AWS SDK、AWS CLIなどを使用する
既存システムが対象バケットへアクセスできなくなる可能性がある。

Railsアプリケーション、管理端末、オンプレミス連携、
外部サービスおよびAWSサービスからのアクセス有無を
影響調査対象として整理した。

本手順では影響範囲の整理のみを行い、設定変更は実施していない。
```

## 4. 変更前Bucket Policyのバックアップ

Bucket Policy変更前に、現在のPolicyを切り戻し用ファイルとして保存する。

バックアップを取得・確認できるまで、Bucket Policyの変更は実施しない。

### バックアップの目的

変更後に問題が発生した場合、変更前Bucket Policyを再適用して切り戻すために使用する。

```text
バックアップ対象:
nobu-terraform-iac-lab-uploadの変更前Bucket Policy

バックアップ用途:
Bucket Policy変更失敗時または動作確認失敗時の切り戻し
```

### Webコンソールによる確認

1. 対象バケットの「アクセス許可」タブを開く
2. 「バケットポリシー」を確認する
3. Policy全体が表示されていることを確認する
4. Policy全体を作業手順書または承認済みの保存場所へ記録する
5. 「編集」「削除」は押さない

Webコンソールから取得したPolicyと、AWS CLIで取得したPolicyの内容が一致することを確認する。

### AWS CLIによるバックアップ取得

バックアップ保存用ディレクトリを作成する。

```bash
mkdir -p 02_Day_Learning/before
```

変更前Bucket Policyを保存する。

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/before/bucket-policy-before.json
```

このコマンドはBucket Policyを取得してローカルファイルへ保存するだけであり、AWS設定は変更しない。

### バックアップファイルの存在確認

```bash
ls -l 02_Day_Learning/before/bucket-policy-before.json
```

ファイルの内容を確認する。

```bash
cat 02_Day_Learning/before/bucket-policy-before.json
```

期待するPolicy:

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
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
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

### バックアップ取得後の再確認

AWS上の現在のBucket Policyを再取得する。

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

次の3つが一致することを確認する。

```text
・Webコンソールに表示されたBucket Policy
・AWS CLIで表示されたBucket Policy
・bucket-policy-before.jsonに保存したBucket Policy
```

### 切り戻し用コマンド

問題発生時は、保存した変更前Policyを再適用する。

```bash
aws s3api put-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --policy file://02_Day_Learning/before/bucket-policy-before.json \
  --no-cli-pager
```

このコマンドはAWS設定を変更するため、現時点では実行しない。

### バックアップ取得時の注意点

- バックアップファイルが空でないことを確認する
- 対象バケット名が正しいことを確認する
- 保存したPolicyに必要なStatementがすべて含まれていることを確認する
- バックアップファイルを変更後Policyで上書きしない
- 切り戻しコマンドのファイルパスが正しいことを確認する
- 実案件では、承認済みの保存場所とファイル命名規則を使用する

### 作業中止条件

次のいずれかに該当する場合は、変更作業へ進まない。

- 変更前Bucket Policyを取得できない
- バックアップファイルが空である
- Webコンソールとバックアップファイルの内容が一致しない
- 想定外のStatementが存在する
- 切り戻し用コマンドまたは保存先が未確認である

### 取得するスクリーンショット

```text
08_変更前_Bucket_Policyバックアップ確認.png
```
### 手順書への記載例

```text
対象バケットの変更前Bucket Policyを取得し、
切り戻し用ファイルとして保存した。

Webコンソール、AWS CLIの取得結果、およびバックアップファイルの
Policy内容が一致することを確認した。

切り戻し用コマンドとバックアップファイルの保存場所を確認した。

本手順ではバックアップ取得のみを行い、設定変更は実施していない。
```
## 5. 変更後Bucket Policy案の作成と事前検証

変更後のBucket Policy案をローカルファイルとして作成し、AWSへ反映する前に内容・差分・構文を確認する。

この手順ではAWS上の設定変更を行わない。

### 変更内容

既存の`DenyInsecureTransport`を維持し、TLS 1.2未満の通信を拒否する`DenyOutdatedTLS`を追加する。

`aws:PrincipalIsAWSService`を使用し、AWSサービスプリンシパルからの呼び出しを拒否対象から除外する。

### 変更後Policyファイルの作成

```bash
mkdir -p 02_Day_Learning/after

vi 02_Day_Learning/after/bucket-policy-after.json
```

以下を入力する。

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
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    },
    {
      "Sid": "DenyOutdatedTLS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
      ],
      "Condition": {
        "Bool": {
          "aws:PrincipalIsAWSService": "false"
        },
        "NumericLessThan": {
          "s3:TlsVersion": "1.2"
        }
      }
    }
  ]
}
```

### JSON構文の確認

```bash
python3 -m json.tool \
  02_Day_Learning/after/bucket-policy-after.json
```

正常な場合、整形されたJSONが表示される。

構文エラーが表示された場合はAWSへ反映せず、カンマ・括弧・引用符などを修正する。

### 変更前後の差分確認

```bash
diff -u \
  02_Day_Learning/before/bucket-policy-before.json \
  02_Day_Learning/after/bucket-policy-after.json
```

変更前ファイルが1行JSONのため、差分が読みにくい場合は整形版を作成する。

```bash
python3 -m json.tool \
  02_Day_Learning/before/bucket-policy-before.json \
  > 02_Day_Learning/before/bucket-policy-before-formatted.json

python3 -m json.tool \
  02_Day_Learning/after/bucket-policy-after.json \
  > 02_Day_Learning/after/bucket-policy-after-formatted.json
```

```bash
diff -u \
  02_Day_Learning/before/bucket-policy-before-formatted.json \
  02_Day_Learning/after/bucket-policy-after-formatted.json
```

期待する差分は`DenyOutdatedTLS`ステートメントの追加のみとなる。

### IAM Access AnalyzerによるPolicy検証

このコマンドはPolicyを検証するだけで、S3バケットへ反映しない。

```bash
aws accessanalyzer validate-policy \
  --profile learning \
  --region ap-northeast-1 \
  --policy-document file://02_Day_Learning/after/bucket-policy-after.json \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --output table \
  --no-cli-pager
```

結果の読み方:

- 出力なし: 指摘事項なし
- `ERROR`: Policyとして機能しない問題
- `SECURITY_WARNING`: 過剰な権限などのセキュリティ上の問題
- `WARNING`: Policy記述上の問題
- `SUGGESTION`: 改善提案

`AccessDenied`となった場合は、実行ユーザーにIAM Access Analyzerの検証権限がない可能性がある。権限を勝手に追加せず、JSON構文確認とレビュー結果を記録する。

### 事前確認項目

- 既存の`DenyInsecureTransport`が維持されていること
- 追加した`Sid`が`DenyOutdatedTLS`であること
- `Effect`が`Deny`であること
- TLS 1.2未満だけを拒否すること
- バケット本体とバケット内オブジェクトの両ARNが含まれること
- AWSサービスプリンシパルを拒否対象から除外していること
- 意図しない`Allow`や既存ステートメント削除がないこと

### 影響範囲

TLS 1.0またはTLS 1.1を使用するクライアントは、対象バケットへアクセスできなくなる。

変更前に以下の利用状況を確認する必要がある。

- RailsアプリケーションからのS3アクセス
- AWS CLIおよびAWS SDKのバージョン
- オンプレミス環境からのアクセス
- 外部システムやバッチ処理
- S3へアクセスするAWSサービス
- 複数AWSアカウントからのアクセス

### 作業結果記載例

```text
変更後Bucket Policy案を作成し、変更前Policyとの差分を確認した。

既存のDenyInsecureTransportを維持したまま、
TLS 1.2未満の通信を拒否するDenyOutdatedTLSを追加した。

JSON構文およびIAM Access AnalyzerによるPolicy検証を実施した。
本手順ではAWS上のBucket Policy変更は実施していない。
```

### 公式資料

- [条件キーを使用したS3 Bucket Policyの例](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
- [IAM Access AnalyzerでPolicyを検証する](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/access-analyzer-policy-validation.html)

## 6. 承認確認とBucket Policyの変更実施

事前検証済みの変更後Bucket Policyを対象バケットへ反映する。

この手順はAWS設定を変更するため、実施前に対象・変更内容・切り戻し方法を再確認する。

### 実施前確認

- 対象AWSアカウントが`445405559057`であること
- 対象バケットが`nobu-terraform-iac-lab-upload`であること
- 変更前Policyをバックアップ済みであること
- 変更後PolicyのJSON構文確認が完了していること
- 変更内容と影響範囲を確認済みであること
- 切り戻しコマンドを準備済みであること
- 学習環境以外では作業承認を取得済みであること

### 操作アカウントの再確認

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

### 対象バケットの再確認

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

### 現在のBucket Policyが変更前バックアップと一致することを確認

現在のPolicyを一時ファイルへ保存する。

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/before/bucket-policy-current.json
```

比較用に両方のJSONを整形する。

```bash
python3 -m json.tool \
  02_Day_Learning/before/bucket-policy-before.json \
  > 02_Day_Learning/before/bucket-policy-before-formatted.json

python3 -m json.tool \
  02_Day_Learning/before/bucket-policy-current.json \
  > 02_Day_Learning/before/bucket-policy-current-formatted.json
```

差分を確認する。

```bash
diff -u \
  02_Day_Learning/before/bucket-policy-before-formatted.json \
  02_Day_Learning/before/bucket-policy-current-formatted.json
```

出力がなければ、バックアップ取得後にBucket Policyが変更されていない。

差分が表示された場合は、他の作業者や処理によってPolicyが変更された可能性があるため、変更作業を中止して確認する。

### Webコンソールによる変更前確認

1. Amazon S3コンソールを開く
2. 対象バケットを開く
3. 「アクセス許可」タブを開く
4. 「バケットポリシー」を確認する
5. 現在のPolicyが変更前バックアップと一致することを確認する
6. 変更前画面のスクリーンショットを取得する

取得するスクリーンショット:

```text
12_Bucket_Policy変更直前確認.png
```

### Bucket Policyの変更実施

以下のコマンドはBucket Policyを実際に変更する。

```bash
aws s3api put-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --policy file://02_Day_Learning/after/bucket-policy-after.json \
  --no-cli-pager
```

正常終了した場合、通常は何も表示されない。

コマンド実行後、終了ステータスを確認する。

```bash
echo $?
```

期待値:

```text
0
```

`0`以外の場合は変更失敗として扱い、エラー内容を確認する。

### 変更直後のBucket Policy確認

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/after/bucket-policy-applied.json
```

```bash
python3 -m json.tool \
  02_Day_Learning/after/bucket-policy-applied.json \
  > 02_Day_Learning/after/bucket-policy-applied-formatted.json
```

変更後Policy案と実際に反映されたPolicyを比較する。

```bash
diff -u \
  02_Day_Learning/after/bucket-policy-after-formatted.json \
  02_Day_Learning/after/bucket-policy-applied-formatted.json
```

出力がなければ、適用予定Policyと実際に反映されたPolicyが文字列として一致している。

差分が表示された場合でも、直ちに適用失敗とは判断しない。AWSがPolicyを保存・返却するときに、JSONオブジェクト内の項目順序や値の表現を正規化する場合がある。

今回確認した正規化の例:

```diff
- "NumericLessThan": {
-   "s3:TlsVersion": 1.2
- },
  "Bool": {
    "aws:PrincipalIsAWSService": "false"
+ },
+ "NumericLessThan": {
+   "s3:TlsVersion": "1.2"
  }
```

この例では、次の差分だけが発生している。

- `Bool`と`NumericLessThan`の表示順序が変わった
- 数値表現の`1.2`が文字列表現の`"1.2"`へ変わった

JSONオブジェクト内の項目順序はPolicyの評価結果へ影響しない。また、`NumericLessThan`は数値条件演算子であるため、この例ではPolicyの評価内容は変わらない。

差分が表示された場合は、少なくとも次を確認する。

```text
・Statementの追加・削除が想定どおりか
・Effect、Principal、Action、Resourceが想定どおりか
・Condition演算子とCondition Keyが想定どおりか
・Condition値が想定どおりか
・表示順序や値表現だけの差分か
・Access AnalyzerによるPolicy検証結果に問題がないか
・変更後のアプリケーション動作に問題がないか
```

今後の不要な差分を減らすため、変更予定PolicyはAWSが返却する形式に合わせ、`Bool`を先に記載し、`s3:TlsVersion`を文字列の`"1.2"`として記載する。

### Public判定の確認

```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
IsPublic: False
```

### Webコンソールによる変更後確認

1. 対象バケットの「アクセス許可」タブを再読み込みする
2. 「バケットポリシー」を確認する
3. `DenyInsecureTransport`が残っていることを確認する
4. `DenyOutdatedTLS`が追加されていることを確認する
5. パブリックアクセスに関する警告がないことを確認する
6. 変更後画面のスクリーンショットを取得する

取得するスクリーンショット:

```text
13_Bucket_Policy変更後確認.png
```

### 異常時の対応

次の場合は後続作業へ進まず、切り戻しを検討する。

- AWS CLIが異常終了した
- 意図しないPolicyが反映された
- `IsPublic`が`True`になった
- Webコンソールにパブリックアクセス警告が表示された
- S3を利用する処理でアクセスエラーが発生した

### 作業結果記載例

```text
承認済みの変更後Bucket Policyを対象バケットへ反映した。

変更後確認の結果、既存のDenyInsecureTransportが維持され、
DenyOutdatedTLSが追加されていることを確認した。

Bucket Policy StatusはIsPublic=Falseであり、
意図しないパブリックアクセスが発生していないことを確認した。
```

### 注意事項

Webアプリケーション環境を停止している場合、S3を利用するアプリケーションの動作確認は実施できない。

その場合は、Bucket Policy変更確認までを実施し、アプリケーション動作確認を未実施項目として記録する。

## 7. 変更後Bucket Policyの動作確認

変更後Bucket Policyが意図した内容で反映され、既存のS3利用処理へ影響していないことを確認する。

この手順では設定変更を行わない。

### 確認観点

- `DenyInsecureTransport`が維持されていること
- `DenyOutdatedTLS`が追加されていること
- Bucket Policy Statusが`IsPublic=False`であること
- 通常のAWS CLIによるS3アクセスが成功すること
- RailsアプリケーションからS3を利用できること
- 想定外のアクセス拒否が発生していないこと

## AWS CLIによる変更後Policy取得

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/after/bucket-policy-applied.json
```

### Policy内容の表示

取得した1行JSONを、`awk`で作成したJSON整形スクリプトを使用して読みやすくする。

このスクリプトは表示用の改行とインデントを追加する。元の`bucket-policy-applied.json`は変更しない。

```bash
../scripts/format_json_awk.sh \
  02_Day_Learning/after/bucket-policy-applied.json \
  > 02_Day_Learning/after/bucket-policy-applied-formatted.json
```

整形結果を表示する。

```bash
cat \
  02_Day_Learning/after/bucket-policy-applied-formatted.json
```

### 必須設定の存在確認

整形後ファイルを対象に、重要項目が存在することを確認する。

```bash
grep -nE \
  'DenyInsecureTransport|DenyOutdatedTLS|s3:TlsVersion|aws:PrincipalIsAWSService' \
  02_Day_Learning/after/bucket-policy-applied-formatted.json
```

期待する確認項目:

```text
DenyInsecureTransport
DenyOutdatedTLS
s3:TlsVersion
aws:PrincipalIsAWSService
```

`grep`は項目の存在を素早く確認するために使用する。Policy内の正しい位置や条件関係までは判断できないため、整形結果と`diff -u`も併せて確認する。

### TLSバージョン設定の確認

```bash
grep -n \
  '"s3:TlsVersion"' \
  02_Day_Learning/after/bucket-policy-applied-formatted.json
```

期待値:

```text
"s3:TlsVersion": "1.2"
```

## Public判定の確認

```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
IsPublic: False
```

## Bucket-level Public Access Blockの再確認

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
BlockPublicAcls        True
IgnorePublicAcls       True
BlockPublicPolicy      True
RestrictPublicBuckets  True
```

## AWS CLIによる正常系アクセステスト

現在のAWS CLIはTLS 1.2以上で通信するため、通常のS3アクセスが成功することを確認する。

### バケットアクセス確認

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

期待結果:

```text
コマンドが正常終了する
```

### オブジェクト一覧確認

```bash
aws s3api list-objects-v2 \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --max-items 10 \
  --output table \
  --no-cli-pager
```

期待結果:

```text
オブジェクト一覧を取得できる
```

`AccessDenied`となった場合は、Bucket Policyだけでなく、実行ユーザーのIAM権限も確認する。

## Webコンソールによる確認

1. Amazon S3コンソールを開く
2. 対象バケットの「アクセス許可」タブを開く
3. Bucket Policyに2つのDenyステートメントがあることを確認する
4. パブリックアクセスに関する警告がないことを確認する
5. 「オブジェクト」タブを開く
6. オブジェクト一覧を表示できることを確認する

取得するスクリーンショット:

```text
14_Bucket_Policy変更後詳細確認.png
15_S3オブジェクト一覧確認.png
```

## Railsアプリケーションの動作確認

Webアプリケーション環境が起動している場合に実施する。

1. `https://www.nobu-iac-lab.com`へアクセスする
2. ログインする
3. 画像を含む投稿を作成する
4. 投稿と画像が正常に表示されることを確認する
5. S3コンソールで新しいオブジェクトが保存されたことを確認する

取得するスクリーンショット:

```text
16_Railsアプリケーション動作確認.png
17_S3画像保存確認.png
```

Webアプリケーション環境を削除済みの場合は、次のように記録する。

```text
Webアプリケーション環境が停止中のため、
RailsアプリケーションからのS3アップロード確認は未実施。

AWS CLIおよびWebコンソールによる正常系アクセス確認を実施した。
アプリケーション環境の再構築後に追加確認を実施する。
```

## TLS 1.2未満の拒否確認について

通常のAWS CLIではTLS 1.2未満の通信を再現できないため、AWS CLIの正常系確認だけでは`DenyOutdatedTLS`の拒否動作を直接証明できない。

TLS 1.2未満を使用する検証用クライアントが用意されている場合のみ、承認を得たうえで異常系テストを実施する。

検証用クライアントがない場合は、次の結果を証跡とする。

- Bucket Policyの設定内容
- IAM Access Analyzerの検証結果
- AWS CLIによる正常系アクセステスト
- Railsアプリケーションの動作確認
- CloudTrailによる変更履歴

## 確認結果記載例

```text
変更後Bucket Policyの設定内容および正常系動作を確認した。

DenyInsecureTransportが維持され、
DenyOutdatedTLSが追加されていることを確認した。

Bucket Policy StatusはIsPublic=Falseであり、
Bucket-level Public Access Blockの4項目はすべて有効であった。

AWS CLIによるバケットアクセスおよびオブジェクト一覧取得は正常終了した。

TLS 1.2未満を使用する検証用クライアントがないため、
TLS 1.2未満の拒否動作確認は未実施とした。
```

## 8. CloudTrailによる変更履歴の確認

CloudTrail Event historyを使用し、Bucket Policy変更の実行者、実行時刻、対象バケット、実行結果を確認する。

CloudTrail Event historyでは、リージョンごとに過去90日間の管理イベントを確認できる。

設定変更は行わない。

## Webコンソールによる確認

1. AWSマネジメントコンソールでCloudTrailを開く
2. リージョンを東京リージョンへ切り替える
3. 「イベント履歴」を開く
4. 検索属性で「イベント名」を選択する
5. `PutBucketPolicy`を入力する
6. 作業時刻付近のイベントを開く
7. イベントレコードを確認する

確認項目:

```text
eventName: PutBucketPolicy
eventSource: s3.amazonaws.com
awsRegion: ap-northeast-1
requestParameters.bucketName: nobu-terraform-iac-lab-upload
userIdentity: 想定したIAMユーザーまたはIAMロール
sourceIPAddress: 想定した接続元
errorCode: 記録なし
errorMessage: 記録なし
```

取得するスクリーンショット:

```text
18_CloudTrail_PutBucketPolicy一覧確認.png
19_CloudTrail_PutBucketPolicy詳細確認.png
```

## AWS CLIによるイベント一覧確認

対象バケットに関連するイベントを取得し、`PutBucketPolicy`だけを表示する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=nobu-terraform-iac-lab-upload \
  --query 'Events[?EventName==`PutBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

変更直後はCloudTrailへイベントが反映されていない場合がある。イベントが表示されない場合は、数分待ってから再確認する。

## Event IDを指定した詳細確認

一覧で確認したEvent IDを設定する。

```bash
EVENT_ID="<確認したEventId>"
```

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,Username:Username,ReadOnly:ReadOnly,ResourceName:Resources[0].ResourceName,ResourceType:Resources[0].ResourceType,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

`CloudTrailEvent`を含むイベント全体を`--output table`で表示すると、横長の表になり読みづらい。
画面上では上記の要約を確認し、イベントの全内容は後続手順でJSONファイルへ保存する。

## CloudTrailイベント要約の保存

```bash
mkdir -p 02_Day_Learning/evidence
```

確認と報告に使用する主要項目を、読みやすい表形式で保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,Username:Username,ReadOnly:ReadOnly,ResourceName:Resources[0].ResourceName,ResourceType:Resources[0].ResourceType,EventId:EventId}' \
  --output table \
  --no-cli-pager \
  | tee 02_Day_Learning/evidence/cloudtrail-put-bucket-policy-summary.txt
```

## CloudTrailイベントレコードの保存

調査用の正式証跡として、CloudTrailイベントの全内容を生JSONのまま保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

生JSONは1行で保存されるため、通常確認では`cat`による全内容表示を行わない。
ファイルが作成され、空でないことを確認する。

```bash
ls -l \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json

wc -c \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

## grepによるイベント詳細確認

生JSON全体を表示せず、確認が必要な主要項目だけを抽出する。

```bash
grep -o \
  '"eventTime":"[^"]*"\|"eventName":"[^"]*"\|"eventSource":"[^"]*"\|"awsRegion":"[^"]*"\|"sourceIPAddress":"[^"]*"\|"bucketName":"[^"]*"\|"errorCode":"[^"]*"\|"errorMessage":"[^"]*"' \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

IAMユーザーまたはIAMロールのARNを確認する。

```bash
grep -o \
  '"arn":"[^"]*"' \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

通信に使用されたTLSバージョンを確認する。

```bash
grep -o \
  '"tlsVersion":"[^"]*"' \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

変更したBucket Policyに、想定したステートメントが含まれることを確認する。

```bash
grep -o \
  '"Sid":"DenyInsecureTransport"\|"Sid":"DenyOutdatedTLS"\|"s3:TlsVersion":[^,}]*' \
  02_Day_Learning/evidence/cloudtrail-put-bucket-policy-event.json
```

`errorCode`および`errorMessage`が表示されない場合、CloudTrailイベントにはAPIエラーが記録されていない。

## 結果の読み方

- `eventName=PutBucketPolicy`: Bucket Policy変更操作
- `eventSource=s3.amazonaws.com`: S3 APIへの操作
- `bucketName`: 操作対象バケット
- `userIdentity`: 操作を実行したIAMユーザーまたはIAMロール
- `sourceIPAddress`: 操作元IPアドレス
- `userAgent`: AWS CLI、Webコンソール、SDKなどの操作方法
- `errorCode`なし: API操作が正常終了した可能性が高い
- `errorCode`あり: API操作が失敗している
- `requestParameters`: APIへ渡された変更内容
- `eventID`: CloudTrailイベントを一意に識別するID

CloudTrailイベントが記録されていても、変更後設定が正しいことまでは証明できない。

Bucket Policyの変更後確認、アプリケーション動作確認、CloudTrail確認を組み合わせて作業結果を判断する。

## 確認結果記載例

```text
CloudTrail Event historyでPutBucketPolicyイベントを確認した。

実行者、実行時刻、対象AWSアカウント、対象バケットおよび
接続元IPアドレスが想定どおりであることを確認した。

イベントレコードにerrorCodeおよびerrorMessageは記録されておらず、
Bucket Policy変更APIが正常終了したことを確認した。

CloudTrail Event ID:
<EventId>
```

## イベントが確認できない場合の記載例

```text
CloudTrail Event historyでPutBucketPolicyイベントを検索したが、
確認時点では対象イベントを確認できなかった。

CloudTrailへの反映遅延の可能性を考慮し、時間を置いて再確認する。
後続作業は、変更後Bucket Policyの確認結果を基に継続可否を判断する。
```

## 注意事項

- Event historyはリージョン単位で確認する
- 検索時は東京リージョンを選択する
- Event historyで確認できる期間は過去90日間となる
- Event historyは管理イベントが対象となる
- S3オブジェクトの取得や保存などのデータイベント確認には、別途CloudTrail TrailまたはEvent Data Storeの設定が必要となる

## 9. Bucket Policyの切り戻し

変更後に障害や想定外の影響が発生した場合、変更前にバックアップしたBucket Policyを再適用する。

切り戻しもAWS設定変更に該当するため、原則として責任者へ状況を報告し、切り戻し承認を得てから実施する。

## 切り戻し判断基準

次の事象が発生した場合、切り戻しを検討する。

- RailsアプリケーションからS3へアクセスできない
- 既存バッチや外部システムのS3アクセスが失敗する
- 想定外の`AccessDenied`が発生する
- Bucket Policyに意図しない設定が反映されている
- `IsPublic`が`True`になっている
- AWSサービスからのアクセスが失敗する
- 変更作業の継続が困難と判断された

## 切り戻し前の確認

### 操作アカウント確認

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

期待値:

```text
Account: 445405559057
```

### 対象バケット確認

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

### 変更前Policyバックアップ確認

```bash
ls -l \
  02_Day_Learning/before/bucket-policy-before.json
```

```bash
cat \
  02_Day_Learning/before/bucket-policy-before.json
```

次の内容を確認する。

- `DenyInsecureTransport`が存在すること
- `DenyOutdatedTLS`が存在しないこと
- 対象バケットARNが正しいこと
- ファイルが空でないこと

### 切り戻し直前Policyの保存

障害調査に利用できるよう、切り戻し前の現在Policyを保存する。

```bash
mkdir -p 02_Day_Learning/rollback
```

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/rollback/bucket-policy-before-rollback.json
```

```bash
cat \
  02_Day_Learning/rollback/bucket-policy-before-rollback.json
```

取得するスクリーンショット:

```text
20_Bucket_Policy切り戻し前確認.png
```

## 切り戻し実施

以下のコマンドは、変更前にバックアップしたBucket Policyを対象バケットへ再適用する。

```bash
aws s3api put-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --policy file://02_Day_Learning/before/bucket-policy-before.json \
  --no-cli-pager
```

正常終了時は通常何も表示されない。

実行直後に終了ステータスを確認する。

```bash
echo $?
```

期待値:

```text
0
```

`0`以外の場合は切り戻し失敗として扱い、後続の設定変更を行わず、エラー内容を報告する。

## 切り戻し後Policyの確認

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --query Policy \
  --output text \
  --no-cli-pager \
  > 02_Day_Learning/rollback/bucket-policy-after-rollback.json
```

変更前バックアップと切り戻し後Policyを比較する。

```bash
cmp \
  02_Day_Learning/before/bucket-policy-before.json \
  02_Day_Learning/rollback/bucket-policy-after-rollback.json
```

実行直後に終了ステータスを確認する。

```bash
echo $?
```

結果の読み方:

```text
0: ファイル内容が一致する
1: ファイル内容が異なる
2: ファイルの読み込みなどでエラーが発生した
```

Policy内の重要項目を確認する。

```bash
grep -n \
  'DenyInsecureTransport\|DenyOutdatedTLS\|s3:TlsVersion' \
  02_Day_Learning/rollback/bucket-policy-after-rollback.json
```

期待結果:

```text
DenyInsecureTransportが存在する
DenyOutdatedTLSが存在しない
s3:TlsVersionが存在しない
```

## Public判定の確認

```bash
aws s3api get-bucket-policy-status \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
IsPublic: False
```

## Bucket-level Public Access Blockの確認

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --output table \
  --no-cli-pager
```

期待値:

```text
BlockPublicAcls        True
IgnorePublicAcls       True
BlockPublicPolicy      True
RestrictPublicBuckets  True
```

## 正常系アクセステスト

```bash
aws s3api list-objects-v2 \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --max-items 10 \
  --output table \
  --no-cli-pager
```

期待結果:

```text
オブジェクト一覧を取得できる
```

Webアプリケーション環境が起動している場合は、Railsアプリケーションからの画像表示・アップロードも再確認する。

## Webコンソールによる切り戻し後確認

1. 対象バケットの「アクセス許可」タブを開く
2. 「バケットポリシー」を確認する
3. `DenyInsecureTransport`が存在することを確認する
4. `DenyOutdatedTLS`が削除されていることを確認する
5. パブリックアクセスに関する警告がないことを確認する
6. 正常系動作が復旧していることを確認する

取得するスクリーンショット:

```text
21_Bucket_Policy切り戻し後確認.png
22_切り戻し後動作確認.png
```

## CloudTrailによる切り戻し履歴確認

切り戻し操作も`PutBucketPolicy`イベントとして記録される。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=nobu-terraform-iac-lab-upload \
  --query 'Events[?EventName==`PutBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

変更時と切り戻し時の両方で`PutBucketPolicy`が記録されるため、イベント時刻とEvent IDを使用して切り戻し操作を識別する。

## 切り戻し結果記載例

```text
Bucket Policy変更後、既存処理でアクセスエラーが発生したため、
責任者へ報告し、承認後に切り戻しを実施した。

変更前に取得したBucket Policyを再適用し、
切り戻し後Policyが変更前バックアップと一致することを確認した。

Bucket Policy StatusはIsPublic=Falseであり、
正常系アクセステストが成功することを確認した。

CloudTrailで切り戻し時のPutBucketPolicyイベントを確認した。
```

## 注意事項

- 元からBucket Policyが存在するため、`delete-bucket-policy`は使用しない
- 切り戻し前の現在Policyも証跡として保存する
- 切り戻し後はPolicy確認だけでなく、既存処理の復旧も確認する
- 切り戻しが失敗した場合は、繰り返し変更せず責任者へ報告する
- 本番環境では緊急時の承認方法と連絡先を事前に確認する

## 10. 作業結果・証跡・報告内容の整理

Bucket Policy変更作業の結果と証跡を整理し、第三者が作業内容、確認結果、問題の有無を判断できる状態にする。

本番作業では、現場指定のExcel手順書、証跡台帳、チケット、Teamsなどへ結果を記録する。

## 作業完了条件

次の項目がすべて完了していることを確認する。

- 対象AWSアカウントと対象バケットを確認した
- 変更前Bucket Policyをバックアップした
- 変更内容と影響範囲を確認した
- 承認済みのBucket Policyを反映した
- 変更後Bucket Policyが想定どおりであることを確認した
- `IsPublic=False`であることを確認した
- Bucket-level Public Access Blockがすべて有効であることを確認した
- AWS CLIによる正常系アクセステストが成功した
- アプリケーション動作確認を実施した、または未実施理由を記録した
- CloudTrailで`PutBucketPolicy`イベントを確認した
- 切り戻し手順を準備した
- 証跡と作業結果を整理した

## 証跡ファイルの確認

```bash
find 02_Day_Learning \
  -type f \
  -print
```

想定するファイル構成:

```text
02_Day_Learning/
├── before/
│   ├── bucket-policy-before.json
│   ├── bucket-policy-current.json
│   └── bucket-policy-before-formatted.json
├── after/
│   ├── bucket-policy-after.json
│   ├── bucket-policy-applied.json
│   └── bucket-policy-after-formatted.json
├── rollback/
│   ├── bucket-policy-before-rollback.json
│   └── bucket-policy-after-rollback.json
└── evidence/
    └── cloudtrail-put-bucket-policy-event.json
```

ファイルが空でないことを確認する。

```bash
find 02_Day_Learning \
  -type f \
  -size 0 \
  -print
```

何も表示されなければ、空ファイルは存在しない。

## スクリーンショット一覧

```text
01_操作アカウント確認.png
02_S3対象バケット確認.png
03_Bucket_Policy変更前確認.png
04_変更候補と影響範囲確認.png
05_Bucket_Policyバックアップ確認.png
06_変更後Policy案確認.png
07_Policy事前検証結果.png
08_Bucket_Policy変更直前確認.png
09_Bucket_Policy変更後確認.png
10_Public判定確認.png
11_S3正常系アクセス確認.png
12_Railsアプリケーション動作確認.png
13_CloudTrail_PutBucketPolicy一覧確認.png
14_CloudTrail_PutBucketPolicy詳細確認.png
```

スクリーンショットには、可能な範囲で次の情報を含める。

- 対象AWSアカウント
- 対象リージョン
- 対象バケット
- 確認した設定項目
- 設定値
- 作業日時

認証情報、秘密情報、不要な個人情報は含めない。

## 作業結果一覧

| 確認項目 | 変更前 | 変更後 | 判定 |
|---|---|---|---|
| 対象バケット | nobu-terraform-iac-lab-upload | 同左 | 正常 |
| Bucket Policy Status | IsPublic=False | IsPublic=False | 正常 |
| DenyInsecureTransport | 設定あり | 設定あり | 正常 |
| DenyOutdatedTLS | 設定なし | 設定あり | 正常 |
| Bucket-level Public Access Block | 4項目すべて有効 | 4項目すべて有効 | 正常 |
| AWS CLIアクセステスト | 成功 | 成功 | 正常 |
| Railsアプリケーション動作確認 | 実施状況を記載 | 実施結果を記載 | 判定を記載 |
| CloudTrail変更履歴 | 対象外 | PutBucketPolicy確認 | 正常 |
| 切り戻し手順 | 準備済み | 準備済み | 正常 |

## 作業報告記載例

```text
作業名:
S3 Bucket Policy TLS制限追加

対象AWSアカウント:
445405559057

対象リージョン:
ap-northeast-1

対象バケット:
nobu-terraform-iac-lab-upload

実施内容:
既存のDenyInsecureTransportを維持したまま、
TLS 1.2未満の通信を拒否するDenyOutdatedTLSを追加した。

変更前確認:
Bucket Policy StatusがIsPublic=Falseであることを確認した。
Bucket-level Public Access Blockの4項目がすべて有効であることを確認した。
変更前Bucket Policyをバックアップした。

変更後確認:
DenyInsecureTransportが維持されていることを確認した。
DenyOutdatedTLSが追加されていることを確認した。
Bucket Policy StatusがIsPublic=Falseであることを確認した。
AWS CLIによる正常系アクセステストが成功した。

アプリケーション動作確認:
実施結果または未実施理由を記載する。

CloudTrail確認:
PutBucketPolicyイベントを確認した。
実行者、実行時刻、対象バケットおよび実行結果が想定どおりであることを確認した。

切り戻し:
変更前Bucket Policyを使用した切り戻し手順を準備済み。

作業結果:
正常終了
```

## 未実施項目がある場合の記載例

```text
Bucket Policy変更およびAWS CLIによる正常系確認は完了した。

Webアプリケーション環境が停止中のため、
RailsアプリケーションからのS3アクセス確認は未実施とした。

アプリケーション環境の再構築後に追加確認を実施する必要がある。
```

## 異常が発生した場合の報告項目

- 発生日時
- 発生した手順番号
- 対象AWSアカウント
- 対象バケット
- 実行した操作
- エラーメッセージ
- AWS CLIの終了ステータス
- 影響範囲
- 後続作業の停止状況
- 切り戻し実施の有無
- 切り戻し結果
- CloudTrail Event ID
- 関係者への報告状況

## Teams報告例

```text
S3 Bucket Policy変更作業が完了した。

対象:
nobu-terraform-iac-lab-upload

実施内容:
TLS 1.2未満の通信を拒否するDenyOutdatedTLSを追加した。

確認結果:
・変更後Policyは想定どおり
・IsPublic=False
・Public Access Blockは4項目すべて有効
・AWS CLI正常系アクセス成功
・CloudTrailでPutBucketPolicyイベント確認済み

問題:
なし

切り戻し:
変更前Policyをバックアップ済み
```

## Day 2で習得した内容

- Bucket Policy変更前の状態確認
- Bucket Policyのバックアップ
- 変更候補と影響範囲の整理
- 変更後Policy案の作成と事前検証
- 承認後の設定変更
- 変更後設定と正常系動作の確認
- CloudTrailによる変更履歴確認
- 切り戻し手順の準備と実施
- 証跡整理と作業報告

## Day 2完了後の状態

Day 2完了時点で、S3 Bucket Policy変更について次の一連の作業を説明・実施できる状態となる。

```text
変更前確認
→ 影響調査
→ バックアップ
→ 変更案作成
→ 事前検証
→ 承認確認
→ 設定変更
→ 変更後確認
→ CloudTrail確認
→ 切り戻し
→ 作業報告
```

## Day 2終了時チェック

- [ ] `/Users/nobu/aws-reference/day-learning`からコマンドを実行した
- [ ] 変更前Policy、変更後Policy、切り戻し用Policyを保存した
- [ ] `PutBucketPolicy`をManagement EventとしてEvent Historyで確認した
- [ ] S3 Data Eventを有効化していない
- [ ] 切り戻しドリル後のBucket Policyが変更前の状態と一致した
- [ ] 対象S3バケットとオブジェクトを削除していない
- [ ] ローカル証跡を確認・報告用として残した
- [ ] 一時Trailの扱いはDay 3の終了手順に従って判断した
