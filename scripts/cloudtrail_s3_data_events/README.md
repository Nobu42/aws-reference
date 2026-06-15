# CloudTrail S3 Data Events検証スクリプト

## 目的

Rails Active StorageからS3へ画像をアップロードした際の`PutObject`を、CloudTrail S3 Data eventsで確認する。

学習全体の進め方は、[Day 3 Learning: CloudTrail基礎・変更履歴調査](../../day-learning/03_Day_Learning.md)を参照する。

この検証では、以下を関連付けて確認する。

- Rails Active Storageによる画像アップロード
- AWS SDK for RubyによるS3 API呼び出し
- Web EC2へ割り当てたIAM Role
- CloudTrailのS3 Object-level Data event
- CloudTrailログ保存先S3バケット

## スクリプト

| スクリプト | 用途 |
| :--- | :--- |
| `01_enable_s3_data_events.sh` | 変更前Event Selectorを保存し、対象バケットのData eventsを有効化する |
| `03_check_s3_putobject_events.sh` | Trail保存先S3からログを取得し、`PutObject`を検索する |
| `02_restore_s3_event_selectors.sh` | 保存した変更前Event Selectorへ切り戻す |

## 前提

- 対象Trailが作成済みで、ログ記録中であること
- TrailがS3へログを配信していること
- 対象S3バケットが存在すること
- AWS CLI、`grep`、`sed`、`gzip`が利用できること
- `jq`およびPythonは使用しない

既定値:

```text
Profile: learning
Region: ap-northeast-1
Trail: nobu-iac-lab-trail
Target bucket: nobu-terraform-iac-lab-upload
Expected account: 445405559057
```

Trail名が異なる場合は、実行時の第1引数で指定する。

`All_Setup.sh`はCloudTrail Trailを作成しない。最初にTrail一覧を確認し、対象Trailが存在しない場合は、[CloudTrail一時Trail検証スクリプト](../cloudtrail_trail_lab/README.md)を使用して検証用Trailとログ保存先S3バケットを準備する。

```bash
aws cloudtrail describe-trails \
  --profile learning \
  --region ap-northeast-1 \
  --include-shadow-trails \
  --output table \
  --no-cli-pager
```

## 実行順序

## 実行場所と切り戻しルール

スクリプトはどのディレクトリからでも、絶対パスで実行できる。`cd`は不要。

```text
スクリプト:
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/

有効化・切り戻し証跡:
/Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/
```

Data Eventは有料であるため、次のいずれかの時点で必ず切り戻す。

```text
・PutObject確認が完了した直後
・PutObjectが見つからず、検証をいったん終了するとき
・Day 3を途中で終了するとき
・一時Trailを削除する前
```

Data Eventを切り戻しても、一時TrailとTrailログ保存先S3バケットは残る。Day 3全体の終了時に、`cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh`で削除する。

### 1. Data eventsを有効化する

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

スクリプトは、既存Event Selectorが次の単純な管理イベント設定である場合だけ変更を許可する。

- Basic Event Selectorが1件
- `ReadWriteType=All`
- Management eventsが有効
- 既存Data resourcesなし
- Exclude Management Event Sourcesなし
- Advanced Event Selectorsなし

既存設定が上記と異なる場合は、安全のため処理を停止する。実案件では既存Selectorへ追加する変更案を個別に設計・レビューする。

適用後はEvent Selectorを次の2つに分ける。

- 従来どおり、Read / Write両方のManagement eventsを記録する
- 対象S3バケットのWrite-only Data eventsを追加する

これにより、`PutObject`などの書き込み操作を確認しつつ、不要な`GetObject`記録と料金増加を抑える。

### 2. Railsから新しい画像をアップロードする

Event Selectorの変更が反映される前にアップロードすると、Data eventが記録されない可能性がある。
有効化スクリプトの完了後、5分程度待ってから新しい画像をアップロードする。

WebブラウザからRailsアプリケーションへログインし、新しい画像をアップロードする。

確認する情報:

- 操作時刻
- 操作ユーザー
- 投稿または画像の識別情報
- アプリケーション上の成功結果

### 3. PutObjectを確認する

CloudTrailログ配信まで5分から15分程度待ってから実行する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

確認項目:

- `eventName`: `PutObject`
- `userIdentity.arn`: Web EC2のIAM Roleを引き受けたSession
- `userAgent`: `aws-sdk-ruby`を示す情報
- `requestParameters.bucketName`: 対象バケット
- `requestParameters.key`: Active Storageが作成したObject Key
- `eventTime`: Railsから画像をアップロードした時刻と対応すること
- `errorCode`、`errorMessage`: APIエラーが記録されていないこと

CloudTrail Event Historyと`lookup-events`は、S3 Object-level Data eventsの検索には使用できない。この確認スクリプトは、Trail保存先S3からCloudTrailログを取得して検索する。

### 4. Event Selectorを切り戻す

有効化スクリプトの完了時に表示された証跡ディレクトリを指定する。

パスを忘れた場合は、有効化証跡を新しい順に表示する。

```bash
ls -dt \
  /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/*_enable_s3_data_events
```

有効化に成功した際、`01_enable_s3_data_events.sh`が表示した`Evidence`ディレクトリをそのまま指定して切り戻す。

```bash
ENABLE_EVIDENCE_DIR="/Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/REPLACE_WITH_SUCCESSFUL_ENABLE_EVIDENCE"

/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  "$ENABLE_EVIDENCE_DIR"
```

`ls -dt ... | head -n 1`で最新ディレクトリを自動選択しない。失敗した有効化処理が、復元に使用できない未完了ディレクトリを残す場合がある。

切り戻し後、変更前と変更後のEvent Selectorを比較し、対象バケットのData events設定が削除されていることを確認する。

## 証跡

証跡は以下へ保存する。

```text
evidence/cloudtrail_s3_data_events/
```

主な証跡:

- Caller Identity
- Trail設定・状態
- 変更前Event Selector
- 適用したEvent Selector
- 変更後Event Selector
- Trail保存先から取得したCloudTrailログ
- `PutObject`イベント生データ
- `PutObject`主要項目の要約
- 切り戻し前後Event Selector
- `PutEventSelectors`管理イベント

CloudTrailログにはIAM ARN、送信元IP、Object Keyなどが含まれる。外部共有やGit登録の前に、証跡の取り扱いルールを確認する。

## 料金と切り戻し

CloudTrail S3 Data eventsは有料である。対象バケットへ限定して有効化し、検証完了後は必ず元のEvent Selectorへ切り戻す。

`All_Setup.sh`には組み込まず、承認済みの独立した変更・検証・切り戻し作業として扱う。

## 公式ドキュメント

- [CloudTrailのデータイベントを記録する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html)
- [CloudTrailでAmazon S3 APIコールをログに記録する](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/cloudtrail-logging.html)
- [AWS CloudTrailの料金](https://aws.amazon.com/jp/cloudtrail/pricing/)
