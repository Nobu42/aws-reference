# AWS公式ドキュメント KMS / CMK要約

作成日: 2026-07-12

この資料は、AWS公式ドキュメントをもとに、AWS KMS、KMS key、customer managed key、現場でCMKと呼ばれる鍵の扱いを整理したものである。

現場会話では「CMK」という呼び方が残ることがある。ただし、現在のAWS公式ドキュメントでは主に `KMS key`、`customer managed key`、`AWS managed key` という用語を使う。本資料では、特に断りがない限り、CMKを「customer managed KMS key」の意味で扱う。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. AWS KMSとは

AWS KMSは、暗号化キーを作成、管理、利用するためのマネージドサービスである。

主な用途:

- S3オブジェクト暗号化
- CloudTrailログファイル暗号化
- CloudWatch Logs暗号化
- EBS、RDS、EFS、Secrets Managerなど各AWSサービスの暗号化
- キーポリシー、IAMポリシー、Grantによる鍵利用制御
- キー利用履歴のCloudTrail記録

クラウドセキュリティ対応では、KMSは「暗号化されているか」だけでなく、「誰がその鍵を使えるか」「鍵を無効化・削除したらログやデータを参照できるか」「監査人が求める管理対象鍵になっているか」を確認する対象である。

## 2. CMKという呼び方の注意点

| 呼び方 | 現在の公式用語との関係 | 現場での扱い |
| :--- | :--- | :--- |
| CMK | 旧来のCustomer Master Keyの呼び方として残ることがある | 会話上はcustomer managed keyを指すことが多い |
| KMS key | 現在の公式用語 | KMSで扱う鍵全般 |
| Customer managed key | 利用者が作成・管理するKMS key | 監査対応で「管理対象鍵」として確認する中心 |
| AWS managed key | AWSサービスが利用者アカウント内で管理するKMS key | 利用者はKey Policyを直接変更できない |
| AWS owned key | AWSが所有・管理する鍵 | 利用者アカウント内には表示されないことが多い |

要件で「CMKにする」と書かれている場合、通常は「AWS managed keyやデフォルト暗号化ではなく、customer managed keyを使う」という意味で確認する。

## 3. KMS keyの種類

| 種類 | 管理者 | Key Policy変更 | Rotation管理 | 代表例 |
| :--- | :--- | :--- | :--- | :--- |
| Customer managed key | 利用者 | 可能 | 利用者が確認・設定 | 監査対応用のS3、CloudTrail、CloudWatch Logs暗号化キー |
| AWS managed key | AWSサービス | 不可 | AWS側で管理 | `aws/s3`、`aws/cloudwatch` など |
| AWS owned key | AWS | 不可 | AWS側で管理 | 多くのAWSサービス内部利用 |

現場で「監査人が鍵の管理を気にしている」場合、主にCustomer managed keyの有無、Key Policy、Rotation、無効化・削除監視、利用サービスとの紐づきが確認対象になる。

## 4. Customer managed keyで確認する主な項目

| 項目 | 確認内容 | 代表的な値 |
| :--- | :--- | :--- |
| Key ID | 鍵の一意識別子 | UUID形式 |
| ARN | 鍵の完全な識別子 | `arn:aws:kms:region:account:key/...` |
| Alias | 人間が識別しやすい別名 | `alias/project-cloudtrail-log-key` |
| KeyManager | Customer managedかAWS managedか | `CUSTOMER` / `AWS` |
| KeyState | 鍵の状態 | `Enabled`, `Disabled`, `PendingDeletion` |
| KeySpec | 鍵の仕様 | `SYMMETRIC_DEFAULT` など |
| KeyUsage | 鍵の用途 | `ENCRYPT_DECRYPT` など |
| Origin | キーマテリアルの出所 | `AWS_KMS`, `EXTERNAL`, `AWS_CLOUDHSM` |
| MultiRegion | マルチリージョンキーか | `true` / `false` |
| Rotation | 自動ローテーションの状態 | 有効 / 無効 |
| Key Policy | 鍵の基本権限 | JSONポリシー |
| Tags | 管理用タグ | システム名、環境、用途、担当など |

案件では、サービス側の設定だけでなく、KMS側のKey PolicyとKey Stateを必ず確認する。

## 5. Key Policy

KMS keyには必ずKey Policyがある。Key PolicyはKMS keyへのアクセス制御の中心である。

重要な考え方:

- Key PolicyはKMS keyごとのリソースポリシーである
- IAMポリシーだけではKMS keyを使えない場合がある
- Key PolicyでIAMポリシーによる許可を認めているか確認する
- サービス連携では、サービスプリンシパルや暗号化コンテキスト条件が入ることがある
- 管理者権限と利用権限を分けて確認する
- `kms:Decrypt`、`kms:GenerateDataKey`、`kms:DescribeKey` の有無が重要になる

代表的な確認観点:

| 観点 | 確認理由 |
| :--- | :--- |
| 管理者Principal | 鍵の設定変更者を確認する |
| 利用者Principal | 暗号化・復号できる主体を確認する |
| AWSサービスPrincipal | CloudTrail、CloudWatch Logs、S3などが利用できるか確認する |
| `kms:ViaService` | 特定サービス経由に制限しているか確認する |
| Encryption Context | 特定Log GroupやTrailなどに利用範囲を絞っているか確認する |
| クロスアカウント許可 | 別アカウントから利用する構成か確認する |

Key Policyを誤ると、暗号化ログの配送失敗、ログ参照不能、復号不能、運用者のロックアウトにつながる。

## 6. Rotation

Customer managed keyは自動ローテーションを設定できる。

現場での確認観点:

- 自動ローテーションが有効か
- ローテーション周期が要件に合っているか
- 対象Keyが対称暗号化キーか
- Rotation対象外のKeyではないか
- Keyの利用サービスに影響がないか

KMS keyのローテーションは、Key IDやARNを変えるものではない。新しいキーマテリアルが追加され、以後の暗号化に使われる。過去に暗号化されたデータの復号には、対応する古いキーマテリアルが使われる。

注意点:

- ローテーションは既存データを自動で再暗号化するものではない
- 無効化中や削除保留中のKeyは通常利用できない
- 監査上は、Rotation有無だけでなく、Key Policyと利用サービスの紐づきを併せて確認する

## 7. DisableとDeletion

KMS keyを無効化すると、そのKeyを暗号化オペレーションに使えなくなる。削除は破壊的であり、削除後はそのKeyで暗号化されたデータを復号できなくなる。

| 操作 | 状態 | 影響 |
| :--- | :--- | :--- |
| DisableKey | `Disabled` | 再有効化まで暗号化・復号に利用できない |
| ScheduleKeyDeletion | `PendingDeletion` | 待機期間後に削除される |
| CancelKeyDeletion | `Disabled` など | 削除予定を取り消す |
| Delete完了 | Key消滅 | 復元不可 |

削除をスケジュールできるのはCustomer managed keyである。AWS managed keyやAWS owned keyは利用者が削除できない。

現場では、KMS key削除や無効化の監視が重要である。今回の4番台要件にある「CMK disable / deletion scheduleの検知」は、`DisableKey`、`ScheduleKeyDeletion`、`CancelKeyDeletion`、`EnableKey` などのCloudTrailイベント確認につながる。

## 8. CloudTrailログ暗号化でのKMS

CloudTrailはログファイルをS3へ保存する。SSE-KMSを使う場合、CloudTrailがKMS keyを利用できるKey Policyが必要である。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Trail設定 | `KmsKeyId` が設定されているか |
| KMS key | Customer managed keyか |
| Key State | `Enabled` か |
| Key Policy | CloudTrailサービスが利用できるか |
| S3保存先 | CloudTrailログ保存バケットが正しいか |
| 復号権限 | ログ調査者が `kms:Decrypt` を持つか |
| CloudTrail配送エラー | `LatestDeliveryError` などが出ていないか |

CloudTrailログの暗号化で問題になりやすい点:

- TrailにKMS keyを設定したが、Key PolicyにCloudTrail許可がない
- S3バケットポリシーは正しいが、KMS側で拒否される
- ログ保存はできているが、調査者が復号できない
- Keyを無効化したため、過去ログ参照に支障が出る
- クロスアカウントのログ集約でKey Policy不足になる

## 9. CloudWatch Logs暗号化でのKMS

CloudWatch Logsのデータは常に暗号化される。Log GroupにKMS keyを関連付けると、そのKeyで暗号化できる。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Log Group | 対象Log Groupが正しいか |
| KMS Key ID | Log GroupにKMS keyが関連付いているか |
| Key State | KMS keyが有効か |
| Key Policy | CloudWatch Logsが利用できるか |
| `kms:ViaService` | CloudWatch Logs経由に制限しているか |
| Encryption Context | Log Group ARNで利用範囲を制限しているか |

注意点:

- KMS key関連付け後に取り込まれるログが対象になる
- 関連付け解除後も、過去にKMS keyで暗号化されたログはそのKeyに依存する
- Keyを無効化すると、暗号化済みログを読めなくなる可能性がある
- CloudTrail監視用Log GroupをKMS暗号化する場合、ログ配送とログ参照の両方を確認する

## 10. S3 SSE-KMSでのKMS

S3では、バケットのデフォルト暗号化としてSSE-S3またはSSE-KMSを設定できる。監査要件でCustomer managed keyが求められる場合、SSE-KMSのKMS keyがCustomer managed keyかを確認する。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Default encryption | SSE-S3かSSE-KMSか |
| KMS Key ARN | Customer managed keyか |
| Bucket Key | S3 Bucket Keyを使うか |
| Key Policy | S3経由利用を許可しているか |
| IAM権限 | アップロード者に `kms:GenerateDataKey`、参照者に `kms:Decrypt` があるか |
| クロスアカウント | 別アカウントから利用する場合のKey PolicyとIAM権限 |

重要な注意点:

- SSE-KMSではS3権限だけでなくKMS権限も必要になる
- AWS managed keyはクロスアカウント利用で制約になる場合がある
- Server Access Loggingの保存先バケットは、SSE-KMSではなくSSE-S3が必要になるケースがあるため、要件3.4と3.5は分けて確認する
- KMSリクエスト数が増えると料金に影響する

## 11. KMSとCloudTrail監査

AWS KMSの管理操作と暗号化操作はCloudTrailで確認できる。

監視候補イベント:

| イベント | 意味 |
| :--- | :--- |
| `CreateKey` | KMS key作成 |
| `PutKeyPolicy` | Key Policy変更 |
| `ScheduleKeyDeletion` | Key削除スケジュール |
| `CancelKeyDeletion` | Key削除キャンセル |
| `DisableKey` | Key無効化 |
| `EnableKey` | Key有効化 |
| `EnableKeyRotation` | 自動ローテーション有効化 |
| `DisableKeyRotation` | 自動ローテーション無効化 |
| `Decrypt` | 復号 |
| `GenerateDataKey` | データキー生成 |

今回の4番台監視要件では、特にKey無効化と削除スケジュールが重要である。Key Policy変更も、実質的には暗号化ログ参照やサービス連携に影響するため、監視候補に含める価値がある。

## 12. Webコンソールで確認する順番

KMS / CMKをWebコンソールで確認する場合は、次の順番が確認しやすい。

1. AWS KMSを開く
2. リージョンを確認する
3. `カスタマーマネージドキー` を開く
4. 対象KeyのAlias、ARN、Key IDを確認する
5. Key Stateが `Enabled` か確認する
6. Key Spec、Key Usage、Origin、Multi-Regionを確認する
7. Rotation設定を確認する
8. Key Policyを確認する
9. Grantsが存在するか確認する
10. Tagsを確認する
11. 対象サービス側の設定を確認する
12. CloudTrailでKey関連イベントを確認する

対象サービス側の確認例:

| サービス | 確認場所 |
| :--- | :--- |
| CloudTrail | Trail詳細のKMS Key ID |
| CloudWatch Logs | Log Group詳細のKMS key |
| S3 | バケットのデフォルト暗号化 |
| VPC Flow Logs | 保存先Log GroupまたはS3の暗号化設定 |

## 13. 現場チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | Customer managed keyか | 監査上の管理対象鍵か判断する |
| 2 | Key StateがEnabledか | 暗号化・復号に利用できるか判断する |
| 3 | Rotationが有効か | 鍵管理要件を満たすか判断する |
| 4 | Key Policy | 管理者、利用者、サービス連携を確認する |
| 5 | CloudTrail TrailのKmsKeyId | CloudTrailログ暗号化を確認する |
| 6 | CloudWatch LogsのKMS key | 監視ログの暗号化を確認する |
| 7 | S3デフォルト暗号化 | 対象バケットの暗号化方式を確認する |
| 8 | 復号権限 | 証跡調査者がログを参照できるか確認する |
| 9 | 無効化・削除監視 | 監査要件4.7に関連する |
| 10 | クロスアカウント利用 | 集約ログや通知連携の権限不足を防ぐ |
| 11 | 料金影響 | KMSリクエスト数とKey数の増加を確認する |
| 12 | 証跡 | 作業前後の設定値を残す |

## 14. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| 暗号化されていればCMK要件を満たす | SSE-S3やAWS managed keyでは要件を満たさない場合がある |
| S3権限があればSSE-KMSオブジェクトを参照できる | KMSの復号権限も必要になる |
| Key PolicyはIAMポリシーと同じ | KMS keyごとのリソースポリシーであり、KMSでは特に重要である |
| RotationするとKey IDが変わる | Key IDやARNは変わらず、キーマテリアルが更新される |
| Keyを削除しても暗号化済みデータは参照できる | 削除後は復号できなくなる |
| Keyを無効化してもログ参照に影響しない | KMSで暗号化されたログを読めなくなる可能性がある |
| CloudTrailにKMS Keyを設定すれば完了 | Key Policy、S3保存、復号権限、配送エラー確認が必要である |

## 15. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| AWS KMSの概念 | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/concepts.html |
| KMS key作成 | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/create-keys.html |
| Key Policy | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/key-policies.html |
| Key Rotation | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/rotate-keys.html |
| Key有効化・無効化 | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/enabling-keys.html |
| Key削除 | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys.html |
| AWS KMS条件キー | https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/conditions-kms.html |
| CloudTrailログファイルのSSE-KMS暗号化 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html |
| CloudWatch LogsのKMS暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |
| S3 SSE-KMS | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| S3デフォルト暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/default-bucket-encryption.html |
| AWS KMS料金 | https://aws.amazon.com/jp/kms/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| AWS KMS concepts | https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html |
| Creating KMS keys | https://docs.aws.amazon.com/kms/latest/developerguide/create-keys.html |
| Key policies | https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html |
| Rotating keys | https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html |
| Enabling and disabling keys | https://docs.aws.amazon.com/kms/latest/developerguide/enabling-keys.html |
| Deleting KMS keys | https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html |
| AWS KMS condition keys | https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html |
| Encrypting CloudTrail log files with SSE-KMS | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html |
| Encrypt log data in CloudWatch Logs using AWS KMS | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |
| Using server-side encryption with AWS KMS keys in S3 | https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html |
| Setting default server-side encryption behavior for S3 buckets | https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html |
