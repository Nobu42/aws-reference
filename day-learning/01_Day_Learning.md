# Day 1 Learning

##  確認順序

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

## 1. 作業対象確認

- AWSアカウントID: 445405559057
- リージョン: ap-northeast-1
- 対象バケット: nobu-terraform-iac-lab-upload
- 作業内容: S3セキュリティ設定の確認
- 設定変更: なし

## Webコンソール
1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. S3を開き、対象バケットが存在することを確認する

### 取得するスクリーンショット:
01_操作アカウント確認.png
02_S3対象バケット確認.png

## 一行AWS CLI
### アカウント確認
```bash
aws sts get-caller-identity --profile learning --output table --no-cli-pager
```

期待値:
```text
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
```

### バケット存在確認
```
aws s3api head-bucket --profile learning --region ap-northeast-1 --bucket nobu-terraform-iac-lab-upload --expected-bucket-owner 445405559057 --no-cli-pager
```

## 2. Account-level Public Access Block
### Webコンソールで確認する場所
1. Amazon S3コンソールを開く
2. 左側メニューの「アカウントと組織の設定」を選択
3. 「このアカウントのパブリックアクセスブロック設定」を確認する
4. 4項目の有効・無効を確認する
今回は確認だけなので、「編集」は押しません。

### 取得するスクリーンショット
03_Account-level_Public_Access_Block確認.png

画面内に以下が含まれるようにします。
- 「このアカウントのパブリックアクセスブロック設定」
- 4項目の現在値
- 操作対象アカウントを識別できる情報

### 一行AWS CLI
```bash
aws s3control get-public-access-block --profile learning --region ap-northeast-1 --account-id 445405559057 --output table --no-cli-pager
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
アカウント単位の設定を有効にすると、アカウント内の全バケットとAccess Pointに影響します。
AWSはAccount・Bucket・Access Pointなどのうち、最も制限の強い設定を適用します。

### 手順書への記載例
```text
Account-level Public Access Blockを確認した結果、未設定であることを確認した。
本設定を有効化した場合、AWSアカウント内の全S3バケットへ影響するため、
変更は実施せず、公開要件および利用状況の影響調査が必要と判断した。
```

