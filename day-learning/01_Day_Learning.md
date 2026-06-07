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

## 作業対象確認

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

