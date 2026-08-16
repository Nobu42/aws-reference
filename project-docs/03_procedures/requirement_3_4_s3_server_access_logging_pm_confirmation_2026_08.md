# 要件3.4 S3 Server Access Logging 保存先バケット確認事項

作成日: 2026-08-17  
対象要件: 3.4 CloudTrailログ保存先S3バケットでServer Access Loggingが有効になっていること

## 1. PMへの確認文案

以下をチャットまたはメールで確認する。

```text
要件3.4のS3 Server Access Loggingについて確認させてください。

パラメータシートにはServer Logging関連の項目がありますが、確認した範囲では値が空欄でした。
Server Access Loggingを有効化するには、CloudTrailログ保存先バケットとは別に、アクセスログの送信先S3バケットを決める必要があります。

既存の承認済みログ集約バケットが見当たらない場合、Server Access Logging保存専用のS3バケットを新規作成する方針で進めてよいでしょうか。

既存バケットを使用する方針の場合は、対象のバケット名と管理担当をご教示ください。
新規作成する場合は、環境ごとに分けるか、同一アカウント・同一リージョン内で共用するかについても確認をお願いします。
```

## 2. 確認の目的

Server Access Loggingを有効化するには、次の値を確定する必要がある。

- ログ取得元となるCloudTrailログ保存先S3バケット
- Server Access Loggingの送信先S3バケット
- 送信先プレフィックス
- 送信先バケットのアクセス許可
- 保存期間とLifecycle
- 環境、アカウント、リージョンごとの構成

パラメータシートの値が空欄である場合、`false`または無効と断定せず、設計値が未記載または未確定の状態として扱う。

## 3. 提案方針

既存の承認済みログ集約バケットがない場合、Server Access Logging保存専用のS3バケットを新規作成する。

専用バケット案には次の利点がある。

- CloudTrailログ本体とServer Access Logを分離できる
- ログ取得元バケット自身を送信先にした場合のログ無限生成を回避できる
- Server Access Log専用のBucket Policy、保持期間、Lifecycleを設定できる
- 証跡確認、障害調査、費用確認の対象を明確にできる
- 将来の設定変更時にCloudTrailログ本体へ与える影響を抑えられる

新規作成は必須ではない。条件を満たす既存ログ集約バケットがある場合は、プレフィックスを分離した上で流用できる。

## 4. PMに判断を依頼する事項

### 4.1 保存先の方針

- [ ] Server Access Logging保存専用のS3バケットを新規作成する
- [ ] 既存のログ集約S3バケットを使用する
- [ ] 基盤・統制担当側で保存先S3バケットを作成する
- [ ] その他の方式とする

既存バケットを使用する場合:

```text
バケット名:
AWSアカウント:
リージョン:
管理担当:
使用するプレフィックス:
```

### 4.2 新規作成を認める場合

```text
作成主体                 : 業務側 / 基盤・統制担当側 / その他
対象環境                 : 検証 / Prod / OPER
バケットの分け方         : 環境別 / アカウント別 / リージョン別 / 共用
命名規則                 : 
送信先プレフィックス     : 
保持期間                 : 
Lifecycle                : 
Versioning               : 有効 / 無効
タグ                     : 
費用負担先               : 
```

### 4.3 パラメータシートの扱い

- [ ] 今回の対応で空欄を設計値に更新する
- [ ] 別の設計書または管理資料を正とする
- [ ] 基盤・統制担当側で更新する

更新対象候補:

```text
Server Access Logging     : Enabled
Source Bucket             : <CloudTrailログ保存先バケット>
Target Bucket             : <Server Access Logging送信先バケット>
Target Prefix             : <送信先プレフィックス>
Target Object Key Format  : <SimplePrefix / PartitionedPrefix>
Encryption                : SSE-S3
Bucket Policy             : logging.s3.amazonaws.comのPutObjectを許可
Retention / Lifecycle     : <承認された期間とルール>
```

## 5. 新規または既存バケットの確認条件

### 5.1 AWSのサービス条件

- ログ取得元バケットと同じAWSアカウントにある
- ログ取得元バケットと同じAWSリージョンにある
- S3 Object Lockのデフォルト保持期間が設定されていない
- Requester Paysが有効になっていない
- デフォルト暗号化にSSE-S3を使用する
- Object OwnershipがBucket owner enforcedの場合、ACLではなくBucket Policyを使用する
- `logging.s3.amazonaws.com`に対象プレフィックスへの`s3:PutObject`を許可する
- Bucket PolicyのDeny、SCP、統制ポリシーがログ配信を拒否しない

### 5.2 本案件で採用する推奨条件

- ログ取得元バケット自身を送信先にしない
- 送信先バケット自身のServer Access Loggingを有効にしない
- Public Access Blockを有効にする
- 保存期間、Lifecycle、管理担当が決まっている

AWSではログ取得元バケット自身を送信先に指定できるが、ログの無限生成につながるため推奨されていない。本案件では専用バケットまたは条件を満たす既存ログ集約バケットを使用する方針を提案する。

## 6. 作業への影響

保存先方針が決まらない場合、次の作業値を確定できない。

- Server Access Loggingの送信先
- Bucket Policy
- プレフィックス
- 保存期間とLifecycle
- 作業手順書の設定値
- テスト時のログ配信確認先
- パラメータシートの変更値

したがって、送信先バケットの新規作成可否または既存バケット名が確定するまで、Server Access Loggingの有効化作業には進まない。

## 7. 変更・テスト時の注意

- S3コンソールから設定する場合、送信先バケットのBucket Policyが更新されるため、変更前後の差分を確認する
- 既存Bucket Policyを上書きせず、既存Statementを保持する
- ログ配信は即時ではなく、送信先への到着まで数時間かかる場合がある
- Server Access Logはベストエフォート型であり、完全性と即時性は保証されない
- ログ機能自体に追加料金はないが、保存容量とログ参照には通常のS3料金が発生する
- 作業後は設定画面だけでなく、送信先バケットへのログオブジェクト配信まで確認する

## 8. PM回答欄

```text
回答日:
回答者:

採用方針:
[ ] 新規専用バケットを作成
[ ] 既存バケットを使用
[ ] 基盤・統制担当側で対応
[ ] その他

対象環境:
対象アカウント:
対象リージョン:
送信先バケット名:
送信先プレフィックス:
保持期間 / Lifecycle:
作成・変更担当:
パラメータシート更新担当:
補足:
```

## 9. AWS公式ドキュメント

- [Amazon S3 サーバーアクセスログを有効にする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [サーバーアクセスログによるリクエストのログ記録](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html)
- [サーバーアクセスログ記録のトラブルシューティング](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/troubleshooting-server-access-logging.html)
