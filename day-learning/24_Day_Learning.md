# Day 24 Learning: 構成図読解・影響範囲整理

## 学習開始前に実行するスクリプト

Day 24はシステム構成図を読み、AWS設定変更の影響範囲を整理するローカルハンズオンである。AWSリソースの作成、変更、削除は行わない。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

既存環境の値を確認する場合は、読み取り専用のAWS CLIだけを使用する。

実行場所を統一し、構成図と設計資料を確認する。

```bash
cd /Users/nobu/aws-reference

ls docs/design/
ls docs/case_studies/
```

読み取り専用で、構成図に出てきやすいS3、VPC、CloudTrailの入口だけ確認してもよい。

```bash
aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

---

## 目的

銀行系システムのAWSセキュリティ対応では、S3、IAM、KMS、VPC Endpoint、CloudTrail、CloudWatchだけでなく、HULFT、Linux認証サーバ、ジョブ、監視、運用端末などが複雑に絡む可能性がある。

この日の目的は、構成図を設計者レベルで完全に説明することではない。作業者として、次を判断できる状態を目指す。

```text
この設定を変更すると、誰が困る可能性があるか。
どの確認をしてから変更すべきか。
変更後にどこを見れば影響有無を判断できるか。
```

---

## 今日のゴール

- 構成図から作業対象のAWSアカウント、リージョン、サービスを拾える
- S3を中心に、アクセス元、認証主体、ネットワーク経路、ログ記録先を整理できる
- Bucket Policy変更時に影響しそうな利用者、アプリ、バッチ、連携を洗い出せる
- HULFTやLinux認証サーバが図に出てきた場合の見方を説明できる
- 変更前確認、変更後確認、切り戻し確認の観点へ落とし込める
- 不明点を現場へ質問する形に変換できる

---

## 構成図を見るときの基本姿勢

構成図は最初から全体を理解しようとしない。まず、作業対象を中心に次の3つだけを追う。

```text
1. データの流れ
   誰がS3へ置くか。誰がS3から取るか。

2. 認証・権限の流れ
   どのIAM Role、IAM User、AWSアカウント、サービスがアクセスするか。

3. 監査・ログの流れ
   CloudTrail、CloudWatch Logs、S3ログ、監査アカウントへどこから記録されるか。
```

この3つを押さえると、作業対象の設定変更がどこに影響し得るか見えやすくなる。

---

## 理解レベルの目安

## レベル1: 作業対象を間違えない

初日から必要な理解である。

```text
対象AWSアカウント
対象リージョン
対象S3バケット
対象環境: 本番、検証、開発
変更対象設定
変更してはいけない範囲
```

このレベルで重要なのは、設定変更前に対象を間違えないことである。

## レベル2: 影響範囲を拾う

作業前レビューで必要になる理解である。

```text
どのアプリ、バッチ、HULFT、ジョブが対象S3を使うか
どのIAM Role、IAM User、外部アカウントが許可されているか
KMSキーを使っているか
VPC Endpoint経由か、インターネット経由か
ファイル連携の実行時間帯はいつか
失敗時にどのログを見るか
```

このレベルを目指すと、変更後確認が具体的になる。

## レベル3: 設計意図を説明する

参画直後から必須ではないが、徐々に深める領域である。

```text
なぜこの構成になっているか
代替設計は何か
監査要件、可用性要件、運用要件は何か
IaCや共通シェルでどこまで管理されているか
```

最初からレベル3を完璧に目指す必要はない。まずはレベル1とレベル2を確実にする。

---

## S3を中心に構成図を読む

S3バケットを中心に、次の関係を整理する。

```text
利用者・利用システム
  ↓
認証主体
  ↓
ネットワーク経路
  ↓
S3 Bucket Policy / IAM Policy / KMS Key Policy
  ↓
S3 Bucket
  ↓
CloudTrail / CloudWatch / 監査ログ
```

## 確認する構成要素

| 観点 | 見るもの | 確認内容 |
|---|---|---|
| 利用者 | アプリ、バッチ、HULFT、運用端末 | 誰が読み書きするか |
| 認証 | IAM Role、IAM User、AssumedRole、外部アカウント | Principalと対応するか |
| 権限 | Bucket Policy、IAM Policy、ACL、Object Ownership | 許可・拒否の条件は何か |
| 暗号化 | SSE-S3、SSE-KMS、KMS Key Policy | KMS利用権限が必要か |
| 経路 | VPC Endpoint、NAT、Proxy、Direct Connect | S3へどの経路で到達するか |
| 監査 | CloudTrail、Trail保存先S3、CloudWatch Logs | 操作履歴をどこで見るか |
| 運用 | JP1、HULFT、cron、手順書 | 変更時間帯とジョブ影響は何か |

---

## HULFTが図に出てきた場合の見方

HULFTはファイル転送・ファイル連携の役割を持つことが多い。S3周りでは、次のように見る。

```text
HULFT
  ↓
ファイルを受信または送信
  ↓
Linuxサーバやバッチが処理
  ↓
S3へアップロード、またはS3からダウンロード
```

確認すること:

```text
HULFT自身が直接S3を触るのか
HULFT連携後のLinuxサーバがS3を触るのか
どのIAM Roleまたは認証情報でS3へアクセスするのか
ファイル連携の時間帯はいつか
失敗時の再送やリカバリ手順はあるか
```

S3 Bucket Policyを変更する場合、HULFT連携の送受信が影響を受けないか確認する。

---

## Linux認証サーバが図に出てきた場合の見方

Linux認証サーバは、直接S3を操作するサーバとは限らない。LDAP、AD連携、踏み台、運用者認証、ジョブ実行ユーザー管理などに関係する可能性がある。

確認すること:

```text
運用者がどの経路で対象サーバへログインするか
ジョブ実行ユーザーはどこで管理されているか
S3操作を行うLinuxサーバの実行ユーザーは何か
AWS認証はIAM Roleか、アクセスキーか
作業時に踏み台や認証サーバを経由する必要があるか
```

LinuxユーザーとAWSのPrincipalは別物である。構成図では、Linux認証とAWS認可を分けて読む。

---

## Principalと構成図を対応させる

Bucket Policyに出てくる`Principal`は、構成図上の利用者やシステムへ対応づける。

例:

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/app-batch-role"
  }
}
```

読み方:

```text
123456789012アカウントのapp-batch-roleが対象
構成図上のどのアプリ、バッチ、HULFT連携に対応するか確認する
```

Principalが`*`の場合は、ConditionやEffectを必ず併せて読む。

```text
Principal=* かつ Effect=Deny:
全員に対する明示的拒否。セキュリティ制御でよく使う。

Principal=* かつ Effect=Allow:
公開や広い許可の可能性があるため、ConditionとPublic Access Blockを慎重に確認する。
```

---

## ネットワーク経路を読む

S3はインターネット越しに見えるサービスだが、企業環境ではVPC EndpointやProxy、閉域網が関係する場合がある。

確認すること:

```text
S3 Gateway Endpointを使っているか
S3 Interface Endpointを使っているか
Endpoint Policyがあるか
NAT Gateway経由か
Proxy経由か
オンプレミスからDirect ConnectやVPN経由か
```

S3アクセスが失敗した場合、Bucket Policyだけでなく、Endpoint Policy、Route Table、Security Group、Proxyも確認対象になる。

---

## KMSが絡む場合の見方

S3の暗号化がSSE-KMSの場合、S3権限だけでは足りない。

確認すること:

```text
対象バケットのSSEAlgorithmがaws:kmsか
KMS Key ARNは何か
KMS Key PolicyでPrincipalが許可されているか
IAM Policyでkms:Decryptやkms:GenerateDataKeyが許可されているか
別アカウントからのアクセスがあるか
```

S3 Bucket Policyを直しても、KMS権限が不足しているとアクセスは失敗する。

---

## CloudTrailとCloudWatchの見る場所

構成図では、監査ログとアプリログを分ける。

```text
CloudTrail:
AWS API操作の履歴を見る
例: PutBucketPolicy、PutObject、PutEventSelectors

CloudWatch Logs:
OS、ミドルウェア、アプリケーションのログを見る
例: nginx error、Puma stderr、Railsログ
```

S3 Bucket Policy変更後の確認では、両方を見る可能性がある。

```text
CloudTrail:
誰がいつBucket Policyを変更したか

CloudWatch Logs:
変更後にアプリエラーや5xxが発生していないか
```

---

## 構成図から作る影響範囲メモ

構成図を見たら、次の形式でメモする。

```text
対象:
  S3バケット:
  AWSアカウント:
  リージョン:
  環境: 本番 / 検証 / 開発

利用システム:
  アプリ:
  バッチ:
  HULFT:
  外部連携:
  運用者:

認証主体:
  IAM Role:
  IAM User:
  外部アカウント:
  AWSサービスPrincipal:

ネットワーク経路:
  VPC Endpoint:
  NAT / Proxy:
  Direct Connect / VPN:

関連設定:
  Bucket Policy:
  IAM Policy:
  KMS Key Policy:
  Endpoint Policy:
  Public Access Block:
  Object Ownership:

ログ・監査:
  CloudTrail:
  Trail保存先:
  CloudWatch Logs:
  監査アカウント:

変更後確認:
  AWS設定値:
  アプリ動作:
  バッチ / HULFT連携:
  CloudTrail:
  CloudWatch Logs:
```

---

## S3 Bucket Policy変更時の影響確認

## 変更前に確認すること

```text
対象Bucket Policyの現在値
Public Access Block
Object Ownership
ACL
暗号化方式
KMSキー有無
Access Point有無
VPC Endpoint Policy有無
対象バケットを利用するシステム一覧
変更時間帯に動くジョブやHULFT連携
切り戻し用Policyバックアップ
```

## 変更後に確認すること

```text
Bucket Policyが承認済み内容と一致する
Policy StatusがPublicではない
対象アプリが正常動作する
HULFTやバッチ連携に失敗がない
CloudTrailにPutBucketPolicyが記録されている
CloudWatch Logsに新規エラーがない
ALB 5xxやTarget Group HealthyHostCountに異常がない
```

## 切り戻し時に確認すること

```text
変更前Policyへ戻っている
変更前バックアップと切り戻し後Policyが一致する
CloudTrailに切り戻し操作が記録されている
アプリ、バッチ、連携が復旧している
```

---

## 読み取り専用AWS CLI確認例

現場で実行する場合は、必ず対象アカウント、リージョン、権限、手順書の承認範囲を確認する。

## 操作アカウント確認

```bash
aws sts get-caller-identity \
  --output table \
  --no-cli-pager
```

## 対象バケット存在確認

```bash
aws s3api head-bucket \
  --bucket REPLACE_WITH_BUCKET_NAME \
  --expected-bucket-owner REPLACE_WITH_ACCOUNT_ID \
  --no-cli-pager
```

## Bucket Policy確認

```bash
aws s3api get-bucket-policy \
  --bucket REPLACE_WITH_BUCKET_NAME \
  --expected-bucket-owner REPLACE_WITH_ACCOUNT_ID \
  --query Policy \
  --output text \
  --no-cli-pager
```

## Public Access Block確認

```bash
aws s3api get-public-access-block \
  --bucket REPLACE_WITH_BUCKET_NAME \
  --expected-bucket-owner REPLACE_WITH_ACCOUNT_ID \
  --output table \
  --no-cli-pager
```

## 暗号化確認

```bash
aws s3api get-bucket-encryption \
  --bucket REPLACE_WITH_BUCKET_NAME \
  --expected-bucket-owner REPLACE_WITH_ACCOUNT_ID \
  --output table \
  --no-cli-pager
```

## VPC Endpoint確認

```bash
aws ec2 describe-vpc-endpoints \
  --filters Name=service-name,Values=com.amazonaws.REPLACE_WITH_REGION.s3 \
  --output table \
  --no-cli-pager
```

## CloudTrail変更履歴確認

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=REPLACE_WITH_BUCKET_NAME \
  --max-results 10 \
  --no-paginate \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

---

## 構成図レビュー時の質問テンプレート

```text
このS3バケットを利用しているシステムを教えてください。

HULFTやバッチから、このS3バケットへの読み書きはありますか。

Bucket Policy内のPrincipalは、構成図上のどのシステムに対応していますか。

このバケットはTerraform、CloudFormation、共通シェル、手順書のどれで管理されていますか。

KMSキーを利用している場合、KMS Key Policyも変更対象ですか。

S3 VPC EndpointやEndpoint Policyはありますか。

変更後のアプリ動作確認、バッチ確認、HULFT連携確認は誰が実施するか。

CloudTrailログは個別Trail、組織Trail、CloudTrail Lakeのどこで確認するか。

CloudWatch Logsで確認すべきロググループはどれですか。

切り戻し判断の条件と連絡先を教えてください。
```

---

## 構成図から読み取った結果の記載例

```text
対象S3バケットは、Webアプリケーション、夜間バッチ、HULFT連携後のファイル配置処理から利用される構成である。

S3アクセスは主にEC2のIAM Role経由で行われるが、一部の運用処理では別IAM Roleまたはジョブ実行基盤からのアクセスが想定される。

Bucket Policy変更時は、アプリケーション動作だけでなく、バッチ処理、HULFT連携、KMS利用権限、VPC Endpoint Policyへの影響を確認する必要がある。

変更後は、S3設定値、CloudTrail変更履歴、CloudWatch Logs、対象ジョブの実行結果を確認する。
```

---

## 現場で避ける判断

```text
S3しか変更しないため影響はS3だけ、と判断する

Bucket Policyだけ見て、IAM PolicyやKMS Key Policyを見ない

PrincipalのARNを構成図上のシステムへ対応づけない

Trailが見えないためCloudTrail未設定と判断する

HULFTやバッチの利用時間帯を確認せず変更する

CloudWatch Logsを見ずにアプリ影響なしと判断する
```

---

## Day 24完了条件

```text
・構成図からS3の利用システムを洗い出せる
・データの流れ、認証の流れ、監査ログの流れを分けて説明できる
・HULFTやLinux認証サーバが出てきた場合の確認観点を説明できる
・Principalと構成図上のシステムを対応づける必要性を説明できる
・S3変更時にIAM、KMS、VPC Endpoint、CloudTrail、CloudWatchも確認対象になる理由を説明できる
・変更前、変更後、切り戻し時の確認観点を整理できる
・不明点を現場への質問として出せる
```
