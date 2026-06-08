# Day 2 Learning

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
    "NumericLessThan": {
      "s3:TlsVersion": "1.2"
    },
    "Bool": {
      "aws:PrincipalIsAWSService": "false"
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
        "NumericLessThan": {
          "s3:TlsVersion": 1.2
        },
        "Bool": {
          "aws:PrincipalIsAWSService": "false"
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

- [S3 Policy condition keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
- [IAM Access Analyzer validate-policy](https://docs.aws.amazon.com/cli/latest/reference/accessanalyzer/validate-policy.html)

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

出力がなければ、想定したPolicyが反映されている。

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


