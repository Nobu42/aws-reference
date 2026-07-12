# AWS公式ドキュメント S3要約

作成日: 2026-07-12

この資料は、AWS公式ドキュメントをもとに、Amazon S3を現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. Amazon S3とは

Amazon S3は、AWSのオブジェクトストレージサービスである。

主な用途:

- ファイル保管
- ログ保管
- バックアップ
- 静的Webサイトホスティング
- データレイク
- アプリケーションのアップロード先
- CloudTrail、VPC Flow Logs、S3 Server Access Logsなどのログ保存先

S3では、データはオブジェクトとしてバケット内に保存される。ファイルシステムのディレクトリ構造ではなく、バケット、オブジェクトキー、メタデータを中心に扱う。

## 2. バケットとオブジェクト

| 用語 | 意味 | 現場での確認観点 |
| :--- | :--- | :--- |
| Bucket | オブジェクトを入れるコンテナ | リージョン、所有アカウント、ポリシー、暗号化 |
| Object | S3に保存されるデータ本体 | キー、サイズ、暗号化、バージョン |
| Key | バケット内でオブジェクトを識別する名前 | プレフィックス、命名規則、ログ保存先 |
| Metadata | オブジェクトに付随する情報 | Content-Type、暗号化、タグ |
| Version ID | バージョニング有効時の世代識別子 | 復旧、削除保護、調査 |

現場では「どのバケットが、何の用途で、誰がアクセスし、どこへログを出しているか」を最初に整理する。

## 3. アクセス制御の全体像

S3のアクセス制御は複数の設定が組み合わさる。

| 設定 | 種類 | 主な用途 |
| :--- | :--- | :--- |
| IAM Policy | アイデンティティベース | ユーザー、Role、アプリの権限付与 |
| Bucket Policy | リソースベース | バケット単位の許可・拒否 |
| ACL | 旧来のアクセス制御 | 原則無効化が推奨される |
| Object Ownership | バケットレベル設定 | ACLの有効・無効と所有権制御 |
| Block Public Access | アカウントまたはバケット設定 | 意図しない公開を防止 |
| Access Point | 専用エンドポイント | 大規模データ共有や用途別アクセス制御 |
| VPC Endpoint Policy | ネットワーク経路側の制御 | VPC内からのS3アクセス制御 |

金融系の環境では、Bucket Policy、Block Public Access、Object Ownership、暗号化、ログ設定が重点確認対象になりやすい。

## 4. Bucket Policy

Bucket Policyは、S3バケットとその中のオブジェクトへのアクセス許可を定義するリソースベースポリシーである。

主な確認項目:

| 項目 | 確認内容 |
| :--- | :--- |
| `Version` | ポリシー言語バージョン |
| `Statement` | 許可・拒否のルール一覧 |
| `Sid` | ルール識別子 |
| `Effect` | `Allow` または `Deny` |
| `Principal` | 対象主体 |
| `Action` | 許可・拒否するS3 API |
| `Resource` | 対象バケットまたはオブジェクト |
| `Condition` | 条件指定 |

現場で特に確認する条件:

| 条件 | 意味 |
| :--- | :--- |
| `aws:SecureTransport` | HTTPS通信を強制する |
| `s3:TlsVersion` | TLSバージョンを制限する |
| `aws:PrincipalIsAWSService` | AWSサービス主体を例外扱いする |
| `aws:SourceVpce` | 特定VPC Endpoint経由に制限する |
| `aws:SourceVpc` | 特定VPCからのアクセスに制限する |
| `aws:SourceArn` | CloudTrailなど特定AWSリソースからのアクセスに制限する |
| `aws:SourceAccount` | 混同代理問題を防ぐため送信元アカウントを制限する |

Bucket Policy変更は業務影響が大きくなり得る。変更前には既存の利用元、クロスアカウント、VPC Endpoint、AWSサービス連携、ログ配信を確認する。

## 5. Block Public Access

S3 Block Public Accessは、意図しないパブリックアクセスを防ぐための安全装置である。

設定はアカウントレベルとバケットレベルに存在する。

| 設定 | 意味 |
| :--- | :--- |
| `BlockPublicAcls` | 新しいパブリックACLの付与をブロックする |
| `IgnorePublicAcls` | 既存パブリックACLを評価しない |
| `BlockPublicPolicy` | 新しいパブリックBucket Policyをブロックする |
| `RestrictPublicBuckets` | パブリックポリシーを持つバケットへのアクセスを制限する |

現場での確認観点:

- アカウントレベルで有効か
- バケットレベルで有効か
- 静的Webサイトなど公開が必要な例外バケットがあるか
- 例外がある場合、承認済みか
- Access Analyzer for S3でPublic判定が出ていないか

原則として、全有効が安全側である。ただし、公開用途のバケットでは設計上の例外があり得る。

## 6. Object OwnershipとACL

Object Ownershipは、バケット内オブジェクトの所有権とACLの扱いを制御するバケットレベル設定である。

| 値 | 意味 |
| :--- | :--- |
| `BucketOwnerEnforced` | ACLを無効化し、バケット所有者がすべてのオブジェクトを所有する |
| `BucketOwnerPreferred` | バケット所有者への所有権付与を優先する |
| `ObjectWriter` | オブジェクト作成者が所有者になる |

現在の推奨は、ACLを無効化し、ポリシーでアクセスを管理する方向である。

`BucketOwnerEnforced` の場合:

- ACLは無効
- バケット所有者がバケット内の全オブジェクトを所有する
- ACL更新は失敗する
- ACL読み取りは可能
- アクセス制御はIAM Policy、Bucket Policy、Access Point Policyなどで行う

ACL確認で注意するURI:

| URI | 意味 |
| :--- | :--- |
| `http://acs.amazonaws.com/groups/global/AllUsers` | インターネット上の全員 |
| `http://acs.amazonaws.com/groups/global/AuthenticatedUsers` | 認証済みAWSユーザー全体 |
| `http://acs.amazonaws.com/groups/s3/LogDelivery` | S3ログ配信用グループ |

`AllUsers` や `AuthenticatedUsers` に許可がある場合、公開または広範なアクセスの可能性があるため調査対象である。

## 7. 暗号化

Amazon S3では、2023年1月5日以降、新規オブジェクトは最低でもSSE-S3で自動暗号化される。

主な暗号化方式:

| 方式 | 意味 | 現場での扱い |
| :--- | :--- | :--- |
| SSE-S3 | S3管理キーによるサーバー側暗号化 | 基本暗号化 |
| SSE-KMS | AWS KMS keyによるサーバー側暗号化 | 監査要件で指定されやすい |
| DSSE-KMS | KMS keyによる二層暗号化 | 高い保護要件向け |
| SSE-C | 利用者提供キーによるサーバー側暗号化 | 運用負荷が高く、禁止対象になりやすい |

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Default encryption | SSE-S3、SSE-KMS、DSSE-KMSのどれか |
| KMS Key | Customer managed keyかAWS managed keyか |
| Bucket Key | SSE-KMSコスト削減設定が有効か |
| Blocked encryption types | SSE-Cなどが禁止されているか |
| 既存オブジェクト | デフォルト暗号化前のオブジェクトが暗号化済みか |
| クロスアカウント | KMS Key PolicyとIAM権限が足りるか |

SSE-KMSではS3権限だけでなく、KMS権限も必要になる。`kms:GenerateDataKey`、`kms:Decrypt`、Key Policy、IAM Policyの確認が必要である。

## 8. Versioning

S3 Versioningは、同じバケット内でオブジェクトの複数世代を保持する機能である。

状態:

| Status | 意味 |
| :--- | :--- |
| `Enabled` | バージョニング有効 |
| `Suspended` | 新規バージョン作成を停止 |
| `null` | 未設定 |

現場での確認観点:

- 誤削除や上書きからの復旧要件があるか
- ランサムウェア対策や監査要件に関係するか
- Lifecycleで古いバージョンを削除する設計か
- MFA Deleteを使う要件があるか
- 保管量増加と費用影響を見込んでいるか

`Status: null` は、バージョニング未設定を意味する。`MFADelete: null` は、MFA Deleteが有効ではないことを意味する。

## 9. Server Access Logging

S3 Server Access Loggingは、バケットに対するリクエストの詳細を別のS3バケットへ保存する機能である。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Source bucket | ログ取得対象バケット |
| Target bucket | ログ保存先バケット |
| Target prefix | ログ保存先プレフィックス |
| 同一リージョン | SourceとTargetが同じリージョンか |
| 同一アカウント | SourceとTargetが同じアカウントか |
| Target bucket暗号化 | SSE-S3要件に注意する |
| Object Lock | Target bucketの制約に注意する |
| Requester Pays | Target bucketでは利用不可 |
| Lifecycle | ログ削除・保管期間の設計 |

同じバケットをログ保存先にすることは可能だが、ログのログが発生し、費用増加と確認性低下につながるため推奨しない。

サーバーアクセスログはベストエフォートであり、配信遅延や欠落の可能性がある。厳密なAPI証跡にはCloudTrailも併用する。

## 10. CloudTrailとの関係

S3操作はCloudTrailで確認できる。

| 種類 | 例 | 説明 |
| :--- | :--- | :--- |
| Management Event | `PutBucketPolicy`, `DeleteBucketPolicy`, `PutBucketEncryption` | バケット設定変更など |
| Data Event | `GetObject`, `PutObject`, `DeleteObject` | オブジェクト操作 |

Event Historyでは過去90日間のManagement Eventを確認できる。S3オブジェクト操作の詳細な記録には、CloudTrail TrailまたはCloudTrail LakeでS3 Data Eventを有効化する必要がある。

今回の4.8「S3バケットポリシー変更監視」では、主に `PutBucketPolicy` と `DeleteBucketPolicy` を監視対象にする。

S3アップロードを追う場合は、Data Eventの有効化が必要になる。Data Eventは料金影響があるため、対象バケット、Read / Write、保持期間、調査目的を明確にする。

## 11. CORS

CORSはCross-Origin Resource Sharingの略であり、日本語ではクロスオリジンリソース共有と呼ばれる。

S3 CORSは、ブラウザ上のWebアプリケーションが、別オリジンのS3リソースへアクセスする場合に関係する。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| AllowedOrigins | 許可するWebサイトのオリジン |
| AllowedMethods | GET、PUT、POSTなど許可するメソッド |
| AllowedHeaders | 許可するリクエストヘッダー |
| ExposeHeaders | ブラウザへ公開するレスポンスヘッダー |
| MaxAgeSeconds | プリフライト結果のキャッシュ時間 |

サーバー側のEC2やLambdaがS3へアクセスする構成では、通常CORSは関係しない。ブラウザから直接S3へアクセスする場合に確認対象になる。

## 12. Lifecycle

S3 Lifecycleは、オブジェクトの移行や削除を自動化する機能である。

主な用途:

- 古いログを削除する
- 古いログを低頻度アクセス用ストレージへ移行する
- バージョニングの古い世代を削除する
- マルチパートアップロードの未完了パーツを削除する

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Rule有無 | Lifecycleが設定されているか |
| Filter | 対象プレフィックスやタグ |
| Transition | どのストレージクラスへ移行するか |
| Expiration | いつ削除するか |
| Noncurrent version | 旧バージョンの扱い |
| Abort multipart upload | 未完了アップロードの削除 |

重要な注意点として、Bucket Policyで全操作を拒否していても、S3 Lifecycleの削除や移行を防ぐ用途には使えない。

## 13. VPC Endpointとの関係

S3はインターネット経由だけでなく、VPC Endpoint経由でアクセスできる。

主な種類:

| 種類 | 特徴 |
| :--- | :--- |
| Gateway endpoint | S3とDynamoDB向け。Route Tableに関連付ける |
| Interface endpoint | PrivateLink経由。ENIとして作成される |

金融系のシステムでは、S3アクセスをVPC Endpoint経由に制限している可能性がある。

確認ポイント:

- Bucket Policyに `aws:SourceVpce` があるか
- Bucket Policyに `aws:SourceVpc` があるか
- VPC Endpoint PolicyがS3操作を許可しているか
- Route TableにS3 Gateway Endpointが関連付いているか
- オンプレミスや閉域網からの経路があるか
- クロスアカウント利用があるか

VPC Endpoint制限を変更すると、アプリケーション、HULFT、バッチ、認証基盤、外部連携のS3アクセスに影響する可能性がある。

## 14. Event通知とEventBridge

S3では、オブジェクト作成や削除などのイベントをSNS、SQS、Lambda、EventBridgeなどへ通知できる。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Event notifications | S3バケット側のイベント通知 |
| EventBridge有効化 | S3イベントをEventBridgeへ送る設定 |
| 通知対象イベント | ObjectCreated、ObjectRemovedなど |
| Prefix / Suffix filter | 対象オブジェクト範囲 |
| Target | SNS、SQS、Lambda、EventBridge Rule |
| 既存運用 | Teams、メール、監視製品、別アカウント連携 |

Bucket Policy変更監視はCloudTrailイベントを使うことが多い。一方、オブジェクト作成通知はS3イベント通知やEventBridgeを使うことが多い。目的によって監視方式が異なる。

## 15. 業務影響

S3設定変更は、アプリケーションやバッチ処理に直接影響する可能性がある。

| 変更 | 主な影響 |
| :--- | :--- |
| Bucket Policy変更 | アクセス拒否、クロスアカウント連携停止、VPC Endpoint経由アクセス制限 |
| Block Public Access変更 | 公開用途バケットのアクセス不可または意図しない公開防止 |
| Object Ownership変更 | ACL前提の連携が失敗する可能性 |
| Default encryption変更 | KMS権限不足によるアップロード・ダウンロード失敗 |
| Server Access Logging有効化 | ログ量とS3費用増加 |
| Versioning有効化 | 保存量増加、削除動作の見え方変更 |
| Lifecycle変更 | オブジェクト削除・移行による復旧不可や参照遅延 |
| CORS変更 | ブラウザ直接アクセスの成否に影響 |
| Event通知変更 | 通知増加、重複通知、後続処理起動 |

S3はデータ保管先であるため、設定変更前には利用元、業務時間、切り戻し方法、既存通知、ログ保存先を確認する。

## 16. Webコンソールで確認する順番

S3をWebコンソールで確認する場合は、次の順番が確認しやすい。

1. S3コンソールを開く
2. 対象バケットを開く
3. `プロパティ` を確認する
4. バージョニングを確認する
5. デフォルト暗号化を確認する
6. Server Access Loggingを確認する
7. Event通知を確認する
8. `アクセス許可` を確認する
9. Block Public Accessを確認する
10. Bucket Policyを確認する
11. Object Ownershipを確認する
12. ACLを確認する
13. CORSを確認する
14. `管理` を確認する
15. Lifecycleを確認する
16. CloudTrail Event HistoryまたはCloudTrail Lakeで設定変更履歴を確認する

## 17. 現場チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | 対象バケット一覧 | 変更対象範囲を確定する |
| 2 | バケット用途 | 業務影響を判断する |
| 3 | Bucket Policy | 既存許可・拒否条件を確認する |
| 4 | Block Public Access | 公開制御を確認する |
| 5 | Object Ownership | ACL無効化状態を確認する |
| 6 | ACL | Publicまたはクロスアカウント許可を確認する |
| 7 | Default encryption | SSE-S3 / SSE-KMS / DSSE-KMSを確認する |
| 8 | KMS Key | Customer managed keyか確認する |
| 9 | Versioning | 復旧要件と費用影響を確認する |
| 10 | Server Access Logging | 監査ログ取得状態を確認する |
| 11 | Lifecycle | ログ保管期間と削除を確認する |
| 12 | CORS | ブラウザ直接アクセスの有無を確認する |
| 13 | Event通知 | 既存通知や後続処理を確認する |
| 14 | VPC Endpoint制限 | 閉域アクセス制御を確認する |
| 15 | CloudTrail履歴 | 設定変更者と変更時刻を確認する |

## 18. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| バケットにフォルダがある | 実体はオブジェクトキーのプレフィックスである |
| S3はデフォルトで公開される | デフォルトではプライベートである |
| Block Public Accessだけ確認すればよい | Bucket Policy、ACL、Object Ownership、Access Pointも確認する |
| ACLが空なら問題ない | Object OwnershipがBucketOwnerEnforcedか確認する |
| 暗号化されていればKMS要件を満たす | SSE-S3とSSE-KMSは意味が異なる |
| SSE-KMSでもS3権限だけで利用できる | KMS権限も必要である |
| Server Access Loggingは厳密な監査証跡である | ベストエフォートであり、CloudTrailと役割が異なる |
| CORSはサーバー間通信にも必須 | ブラウザのクロスオリジンアクセスに関係する |
| Data Eventは常に記録される | 明示的に有効化する必要がある |

## 19. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| Amazon S3とは | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/Welcome.html |
| バケット概要 | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/UsingBucket.html |
| Bucket Policy | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/bucket-policies.html |
| Block Public Access | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/access-control-block-public-access.html |
| Object Ownership | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/about-object-ownership.html |
| ACL概要 | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/acl-overview.html |
| デフォルト暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/default-bucket-encryption.html |
| SSE-KMS | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| Server Access Logging | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html |
| Versioning | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/Versioning.html |
| CORS | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/cors.html |
| Lifecycle | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/object-lifecycle-mgmt.html |
| CloudTrailによるS3 APIログ記録 | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/cloudtrail-logging.html |
| S3料金 | https://aws.amazon.com/jp/s3/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| What is Amazon S3 | https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html |
| Buckets overview | https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingBucket.html |
| Bucket policies | https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-policies.html |
| Block Public Access | https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html |
| Object Ownership | https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html |
| ACL overview | https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html |
| Default encryption | https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html |
| SSE-KMS | https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| Server access logging | https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html |
| Versioning | https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html |
| CORS | https://docs.aws.amazon.com/AmazonS3/latest/userguide/cors.html |
| Lifecycle | https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html |
| Logging S3 API calls with CloudTrail | https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudtrail-logging.html |
