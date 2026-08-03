# 要件3.4 S3 Server Access Logging確認手順・注意点

作成日: 2026-07-31

対象要件: 3.4 CloudTrail S3バケットでサーバーアクセスログが有効になっていること

## 1. 現状の読み取り

```text
検証用parameter:
Server Access Logging関連値が空欄

本番用parameter:
Server Access Logging関連値がfalse
```

上記の場合、以下の状態として扱う。

```text
検証環境:
Server Access Logging設定値が未定義または未設計

本番環境:
Server Access Loggingが明示的に無効
```

要件3.4では、CloudTrailログ保存先S3 bucketのServer Access Loggingを有効化するだけでなく、ログ保存先となるTarget bucketとTarget prefixを決める必要がある。

## 2. 先に確認すること

```text
1. 対象のSource bucketはどれか
2. 既存のServer Access Logging用Target bucketがあるか
3. 既存Target bucketを使う方針か、新規作成する方針か
4. Target prefixは何にするか
5. Target bucketの暗号化方式はSSE-S3か
6. Target bucketのObject OwnershipはBucket owner enforcedか
7. Target bucketのBucket policyでS3ログ配信を許可できるか
8. Target bucketでObject LockやRequester Paysが有効でないか
9. ProdとOPERで同じTarget bucketを使うか、環境別に分けるか
10. 検証環境にも同じ設定を追加するか
```

## 3. パラメータシート確認手順

### 3.1 対象シートを開く

```text
1. パラメータシートを開く。
2. S3、CloudTrail、Logging、ログ保存先に関係するシートを確認する。
3. 環境列がある場合、検証、Prod、OPERを分けて確認する。
4. 要件3.4に関係する行を検索する。
```

### 3.2 検索キーワード

```text
ServerAccessLogging
Server Access Logging
AccessLogging
BucketLogging
Logging
LogDelivery
TargetBucket
TargetPrefix
CloudTrailLogBucket
CloudTrail S3
サーバーアクセスログ
アクセスログ
ログ保存先
ログ記録
```

### 3.3 確認するパラメータ

```text
Source bucket:
CloudTrailログ保存先S3 bucket

Server Access Logging enabled:
true / false

Target bucket:
Server Access Loggingの保存先S3 bucket

Target prefix:
Target bucket内の保存prefix

Target bucket encryption:
SSE-S3が望ましい

Target bucket Object Ownership:
Bucket owner enforcedの場合はACLではなくBucket policyで許可する

Target bucket policy:
logging.s3.amazonaws.comにs3:PutObjectを許可する

Lifecycle:
保持期間、移行、削除ルール

Public Access Block:
全ブロック有効

Versioning:
必要に応じて確認

KMS:
Target bucketがSSE-KMSの場合は注意。S3 Server Access Loggingの保存先としてはSSE-S3方針を確認する
```

## 4. AWS Webコンソール確認手順

### 4.1 Source bucket確認

```text
1. AWS Management Consoleへログインする。
2. 対象アカウントと対象リージョンを確認する。
3. S3コンソールを開く。
4. CloudTrailログ保存先S3 bucketを検索する。
5. 対象bucketを開く。
6. 「プロパティ」タブを開く。
7. 「サーバーアクセスのログ記録」を確認する。
8. 有効/無効、Target bucket、Target prefixを確認する。
9. 変更前証跡を取得する。
```

### 4.2 Target bucket候補確認

```text
1. S3コンソールでログ保存先候補bucketを検索する。
2. 対象bucketを開く。
3. 「プロパティ」タブを開く。
4. リージョンを確認する。
5. Object Lockが無効であることを確認する。
6. Requester Paysが無効であることを確認する。
7. Default encryptionを確認する。
8. 「アクセス許可」タブを開く。
9. Block Public Accessが有効であることを確認する。
10. Object Ownershipを確認する。
11. Bucket policyを確認する。
12. Lifecycle ruleを確認する。
13. Target bucket候補として使えるか記録する。
```

### 4.3 既存Target bucketがない場合

```text
1. 新規Target bucket作成要否を確認する。
2. 命名規則を確認する。
3. 作成アカウントを確認する。
4. 作成リージョンを確認する。
5. Prod / OPER / 検証で共用するか分けるか確認する。
6. 暗号化方式を確認する。
7. Bucket policy方針を確認する。
8. Lifecycle方針を確認する。
9. 作成主体が業務側かA-gate/基盤側か確認する。
```

## 5. Target bucket要件

```text
Source bucketと同じAWSアカウントであること
Source bucketと同じAWSリージョンであること
Source bucket自身をTarget bucketにしないこと
Object Lockが有効でないこと
Requester Paysが有効でないこと
Server Access LoggingのTarget bucket自身でServer Access Loggingを有効化しないこと
S3ログ配信サービスがPutObjectできるBucket policyを持つこと
Public Access Blockが有効であること
保持期間と削除方針が決まっていること
```

## 6. Bucket policy確認観点

Target bucketには、S3ログ配信サービスがログオブジェクトを書き込める権限が必要となる。

```text
Principal:
logging.s3.amazonaws.com

Action:
s3:PutObject

Resource:
arn:aws:s3:::<target-bucket>/<target-prefix>*

Condition:
aws:SourceAccount
aws:SourceArn
```

確認すること:

```text
1. Source bucketからのログ配信だけを許可しているか
2. 他bucketからの不要なログ配信を許可していないか
3. Principalがログ配信サービスになっているか
4. Target prefixの指定が想定どおりか
5. Deny系ポリシーでログ配信が拒否されないか
6. A-gateやOrganizations SCPでPutBucketLoggingやPutBucketPolicyが拒否されないか
```

## 7. 新規Target bucketを作る場合の確認事項

```text
Bucket名:
現場命名規則に合わせる

用途:
S3 Server Access Logging保存専用

環境:
検証 / Prod / OPER / 共用のどれか

リージョン:
Source bucketと同一リージョン

暗号化:
SSE-S3を基本方針として確認

Public Access Block:
全項目有効

Object Ownership:
Bucket owner enforced

Versioning:
現場方針に従う

Lifecycle:
保持期間、移行、削除を設定

Bucket policy:
logging.s3.amazonaws.comからのPutObjectを許可

タグ:
システム名、環境、用途、管理部署、費用配賦など

作成主体:
業務側 / A-gate / 基盤側
```

## 8. 作業前に確認する質問

```text
要件3.4のServer Access Loggingについて、
パラメータシートでは検証用が空欄、本番用がfalseでした。

1. 検証環境にもServer Access Logging設定値を追加する認識でよいか
2. 本番はfalseからtrueへ変更する認識でよいか
3. OPERも対象に含める認識でよいか
4. Target bucketは既存ログ集約用bucketを使うのか
5. Target bucketを新規作成するのか
6. 新規作成の場合、命名規則、保持期間、暗号化、Lifecycle、Bucket policyはどの資料を正とするか
7. 作業主体は業務側か、A-gate/基盤側か
8. A-gate explicit denyやSCPによる制限はあるか
9. 設定変更後、ログ配信確認はどの時点まで待つか
10. 配信確認が当日中にできない場合、配信待ちとしてよいか
```

## 9. 設定変更時の注意点

```text
Source bucket自身をTarget bucketにしない。
Target bucketをSSE-KMS暗号化にする場合は事前確認する。
Bucket owner enforcedの場合、ACLやTarget grantsではなくBucket policyを使う。
Object Lock有効bucketをTarget bucketにしない。
Requester Pays有効bucketをTarget bucketにしない。
Target bucket自身のServer Access Loggingを有効化しない。
ログ配信は即時ではないため、確認に時間がかかる前提で作業計画を組む。
ログ量増加によりS3保管量とライフサイクル管理が必要になる。
既存Bucket policyを上書きしない。
変更前Bucket policyを保存してから変更する。
A-gate管理下のbucketやpolicyを業務側で直接変更してよいか確認する。
```

## 10. 証跡

```text
01_3.4_パラメータシート確認_202608XX.png
02_3.4_SourceBucketプロパティ変更前_202608XX.png
03_3.4_SourceBucketServerAccessLogging変更前_202608XX.png
04_3.4_TargetBucket候補一覧_202608XX.png
05_3.4_TargetBucketプロパティ確認_202608XX.png
06_3.4_TargetBucketアクセス許可確認_202608XX.png
07_3.4_TargetBucketLifecycle確認_202608XX.png
08_3.4_ServerAccessLogging設定画面_202608XX.png
09_3.4_SourceBucketServerAccessLogging変更後_202608XX.png
10_3.4_TargetPrefixログ配信確認_202608XX.png
11_3.4_権限エラーまたはA-gateDeny画面_202608XX.png
12_3.4_配信待ち記録_202608XX.png
```

## 11. 判断結果の書き方

```text
Target bucket既存利用:
既存ログ集約bucketをTarget bucketとして使用する。
Target bucket、Target prefix、Bucket policy、Lifecycleはパラメータシートの値を正とする。

Target bucket新規作成:
Server Access Logging保存先bucketを新規作成する。
命名規則、暗号化、Bucket policy、Lifecycle、保持期間、作成主体を確認後に作業する。

対応保留:
Target bucket / Target prefix未定義のため、Server Access Logging有効化は保留する。
保存先確定後に設定作業を実施する。

対応不要:
既存設定または別方式で要件を満たす根拠が確認できた場合のみ対応不要とする。
根拠となるパラメータ、画面、承認者を記録する。
```

## 12. 参照URL

- Amazon S3: Enabling server access logging  
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
- Amazon S3: Logging requests with server access logging  
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html
- Amazon S3: Troubleshoot server access logging  
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/troubleshooting-server-access-logging.html
