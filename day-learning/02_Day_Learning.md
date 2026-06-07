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



