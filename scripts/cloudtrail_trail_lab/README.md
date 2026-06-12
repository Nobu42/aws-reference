# CloudTrail一時Trail検証スクリプト

## 目的

Day 3の学習でCloudTrail Trail、ログ保存先S3バケット、Event Selector、ログ配信状態を実物で確認するため、一時的な検証用Trailを作成する。

`All_Setup.sh`とは独立している。検証時だけ明示的に作成し、学習終了後に専用削除スクリプトで削除する。

学習全体の進め方は、[Day 3 Learning: CloudTrail基礎・変更履歴調査](../../day-learning/03_Day_Learning.md)を参照する。

## スクリプト

| スクリプト | 用途 |
| :--- | :--- |
| `01_create_cloudtrail_trail.sh` | 一時Trailとログ保存先S3バケットを作成する |
| `02_check_cloudtrail_trail.sh` | Trail設定、稼働状態、Event Selector、S3ログ配信を確認する |
| `03_delete_cloudtrail_trail.sh` | 一時Trailとログ保存先S3バケットを削除する |

既定値:

```text
Profile: learning
Region: ap-northeast-1
Expected account: 445405559057
Trail: nobu-iac-lab-trail
Trail log bucket: nobu-iac-lab-cloudtrail-445405559057
S3 key prefix: cloudtrail
```

## 安全設計

- Caller IdentityのAWSアカウントIDが想定値と一致しない場合は停止する
- 同名Trailが存在する場合、作成スクリプトは上書きせず停止する
- 同名ログ保存先S3バケットが自アカウントに存在する場合、作成スクリプトは上書きせず停止する
- 作成と削除の直前に確認文字列の入力を求める
- 削除スクリプトはTrailの保存先が想定したラボ用バケットと一致しない場合は停止する
- `jq`およびPythonは使用しない

確認を省略して実行する場合は、内容を確認したうえで`SKIP_CONFIRM=true`を指定する。

## 作成される設定

- Multi-region Trail: 有効
- Global service events: 記録
- Log file validation: 有効
- Management events: Read / Writeを記録
- Data events: 初期状態では記録しない
- Trailログ保存先S3 Public Access Block: 4項目すべて有効
- Object Ownership: `BucketOwnerEnforced`
- デフォルト暗号化: SSE-S3
- S3 Versioning: 一時検証用バケットの削除を単純にするため未設定

本番の監査ログ保存先では、Versioning、Object Lock、SSE-KMS、ライフサイクル、ログ保持期間などを要件に基づいて別途設計する。

## 実行順序

### 1. 一時Trailを作成する

```bash
cd /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab

./01_create_cloudtrail_trail.sh
```

### 2. Trailを確認する

Trail作成直後は、最初のログファイルがS3へ配信されるまで数分かかる場合がある。

```bash
./02_check_cloudtrail_trail.sh
```

主な確認項目:

- TrailのHome Regionが東京であること
- `IsMultiRegionTrail`が`True`であること
- `LogFileValidationEnabled`が`True`であること
- `IsLogging`が`True`であること
- Management eventsが有効であること
- Trailログ保存先S3にログオブジェクトが配信されること

### 3. S3 Data eventsとPutObjectを確認する

Rails Active StorageからS3へ画像をアップロードし、`PutObject`を確認する場合は、次の資料を使用する。

- [CloudTrail S3 Data Events検証スクリプト](../cloudtrail_s3_data_events/README.md)

実施順序:

1. 対象バケットに限定してWrite-only Data eventsを有効化する
2. Railsから新しい画像をアップロードする
3. Trailログ保存先S3から`PutObject`を検索する
4. Event Selectorを変更前の状態へ切り戻す

### 4. 一時Trailを削除する

S3 Data eventsを有効化した場合は、先にEvent Selectorを切り戻してから削除する。

```bash
cd /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab

./03_delete_cloudtrail_trail.sh
```

CloudTrailから停止・削除後のログが遅延配信され、S3バケット削除が一時的に失敗する場合がある。削除スクリプトはログ削除とバケット削除を複数回試行する。

## 証跡

証跡は以下へ保存する。

```text
evidence/cloudtrail_trail_lab/
```

主な証跡:

- Caller Identity
- Trail作成結果
- Trail設定と稼働状態
- Event Selector
- Trailログ保存先S3のセキュリティ設定
- S3へ配信されたログオブジェクト一覧
- Trail削除前後の状態

CloudTrailログにはIAM ARN、送信元IP、APIリクエスト内容などが含まれる。外部共有やGit登録の前に、証跡の取り扱いルールを確認する。

## 公式ドキュメント

- [AWS CloudTrail証跡の作成](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-create-a-trail-using-the-console-first-time.html)
- [AWS CLIを使用した証跡の作成、更新、管理](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-create-and-update-a-trail-by-using-the-aws-cli.html)
- [CloudTrailが使用するAmazon S3バケットポリシー](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html)
- [CloudTrailのイベントセレクター](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-management-events-with-cloudtrail.html)
- [CloudTrailのデータイベントを記録する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html)
- [AWS CloudTrailの料金](https://aws.amazon.com/jp/cloudtrail/pricing/)
