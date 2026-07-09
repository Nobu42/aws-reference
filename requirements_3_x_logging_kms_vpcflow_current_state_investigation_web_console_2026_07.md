# 要件3番台 ログ保全・KMS・VPC Flow Logs 現状調査手順書 Webコンソール版

作成日: 2026-07-10

この手順書は、要件3.4〜3.7について、AWS Management Consoleで現状調査を行うための手順書である。

最初に共有された評価シート由来のテキスト情報を正とし、要件3番台は「CloudTrailログ保存先S3のログ保全」「CloudTrailログのカスタマー管理KMSキー暗号化」「カスタマー管理KMSキーのローテーション」「VPC Flow Logs有効化」を確認する。
本手順は現状調査用であり、設定変更は行わない。

## 1. 要件整理

| 要件番号 | 確認項目 | 主な確認対象 |
|---|---|---|
| 3.4 | CloudTrailログ保存先S3のServer Access Loggingが有効であること | CloudTrailログ保存先S3、Server Access Logging、ログ保存先 |
| 3.5 | CloudTrailログがカスタマー管理KMSキーで暗号化されていること | CloudTrailのKMS設定、KMSキー、Key Policy、S3暗号化 |
| 3.6 | カスタマー管理KMSキーのローテーションが有効であること | KMS Key Rotation |
| 3.7 | すべてのVPCでVPC Flow Logsが有効であること | VPC、Flow Logs、保存先、Traffic type |

## 2. 調査方針

```text
AWSアカウントとリージョンを確認する
  ↓
CloudTrail Trailを確認する
  ↓
CloudTrailログ保存先S3を特定する
  ↓
3.4 Server Access Loggingを確認する
  ↓
3.5 CloudTrailのKMS設定とKMSキーを確認する
  ↓
3.6 KMSキーのRotationを確認する
  ↓
3.7 VPC Flow Logsを確認する
  ↓
要件ごとに対応済み / 不足 / 要確認 / 対象外を整理する
```

## 3. 事前に現場側へ確認すること

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 対象環境は本番、運用、開発、検証のどこまでか | 調査範囲を確定するため |
| 2 | 対象AWSアカウントは単一か複数か | Organization Trailや複数VPC確認に影響するため |
| 3 | 対象リージョンはどこか | KMSとVPC Flow Logsはリージョン単位のため |
| 4 | CloudTrailがOrganization Trailか個別Trailか | 管理アカウント側の確認が必要な場合があるため |
| 5 | Server Access Logging保存先は既存か新規予定か | 3.4の設計に必要 |
| 6 | 既存CMKを使うか、新規CMKを作る予定か | 3.5/3.6の設計に必要 |
| 7 | VPC Flow Logsの保存先はCloudWatch LogsかS3か | 3.7の設計に必要 |
| 8 | 証跡は画面キャプチャ、Excel、PDFなど何で残すか | 監査提出形式を合わせるため |

## 4. 必要なドキュメント類

| ドキュメント | 必要な理由 |
|---|---|
| AWSアカウント一覧 | 対象アカウント漏れを防ぐ |
| 対象リージョン一覧 | CloudTrail、KMS、VPC Flow Logsの確認先を決める |
| CloudTrail設計書 | Trail名、Home Region、Multi-Region、Organization Trailを確認する |
| CloudTrailログ保存先S3設計書 | 3.4、3.5の対象S3を確認する |
| S3ログ保存設計書 | Server Access Loggingの保存先、保持期間、ライフサイクルを確認する |
| KMS設計書 | CMK、Key Policy、管理者、利用者、Rotation方針を確認する |
| 鍵管理手順書 | KMSキーの無効化、削除予約、復号権限、Rotation運用を確認する |
| VPC一覧・構成図 | 3.7の対象VPCを確認する |
| VPC Flow Logs設計書 | 保存先、Traffic type、保持期間、ログ形式を確認する |
| 証跡保存ルール | 画面キャプチャや確認結果の保存先を確認する |

## 5. AWSアカウントとリージョンを確認する

1. AWS Management Consoleへログインする。
2. 画面右上のアカウント表示を確認する。
3. 対象AWSアカウントであることを確認する。
4. 画面右上のリージョンを確認する。
5. 対象リージョンを選択する。

取得する証跡:

- アカウント表示が分かる画面
- リージョン表示が分かる画面

注意:

- CloudTrailがMulti-Region Trailの場合でも、TrailのHome Regionで詳細確認する。
- Organization Trailの場合、管理アカウントまたは委任管理アカウント側で確認が必要なことがある。

## 6. CloudTrail Trailとログ保存先S3を確認する

目的:
3.4〜3.6の対象となるCloudTrail Trailとログ保存先S3を特定する。

手順:

1. AWS Consoleの検索欄で `CloudTrail` を開く。
2. 左側メニューから `証跡` または `Trails` を開く。
3. 対象Trailを選択する。
4. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Trail名 | 対象Trailか |
| Home Region | 詳細確認するリージョン |
| Multi-Region | 全リージョン対象か |
| Organization Trail | Organizations配下のTrailか |
| Log file validation | ログファイル検証が有効か |
| S3 bucket | CloudTrailログ保存先S3 |
| S3 prefix | ログ保存Prefix |
| KMS key | CloudTrailログ暗号化に使うKMSキー |

取得する証跡:

- Trail詳細画面
- S3 bucket名が分かる画面
- KMS key設定が分かる画面

判定:

| 状態 | 判断 |
|---|---|
| S3 bucketが確認できる | 3.4、3.5の対象S3を特定できた |
| KMS keyが設定されている | 3.5のKMS確認へ進む |
| KMS keyが未設定 | CloudTrailログがCMK暗号化されていない可能性 |

## 7. 要件3.4 Server Access Loggingを確認する

目的:
CloudTrailログ保存先S3でServer Access Loggingが有効か確認する。

手順:

1. AWS Consoleの検索欄で `S3` を開く。
2. CloudTrailログ保存先S3バケットを開く。
3. `プロパティ` タブを開く。
4. `サーバーアクセスのログ記録` または `Server access logging` を確認する。
5. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Server access logging | 有効 / 無効 |
| Target bucket | アクセスログ保存先バケット |
| Target prefix | アクセスログ保存Prefix |

補足確認:

1. 同じS3バケットの `プロパティ` で `デフォルト暗号化` を確認する。
2. `アクセス許可` タブで `ブロックパブリックアクセス` を確認する。
3. 必要に応じてバケットポリシーの有無を確認する。

取得する証跡:

- Server access logging設定画面
- Target bucket / Target prefixが分かる画面
- デフォルト暗号化画面
- ブロックパブリックアクセス画面

判定:

| 状態 | 判断 |
|---|---|
| Server access loggingが有効 | 3.4は設定済み候補 |
| Target bucketが設定されている | ログ保存先あり |
| Server access loggingが無効 | 3.4は不足候補 |

注意:

- 有効化は設定変更なので、この調査では実施しない。
- 保存先を同じバケットにすると運用上分かりにくくなるため、既存設計を確認する。

## 8. 要件3.5 CloudTrailログのCMK暗号化を確認する

目的:
CloudTrailログがカスタマー管理KMSキーで暗号化されているか確認する。

確認ポイント:

| 見る場所 | 意味 |
|---|---|
| CloudTrail TrailのKMS key | CloudTrailログファイル暗号化に使うKMSキー |
| KMS key詳細 | カスタマー管理キーか、AWS管理キーか |
| Key Policy | CloudTrailが暗号化に使用できるか、運用者が復号できるか |
| S3デフォルト暗号化 | S3バケット側の暗号化設定 |

手順:

1. CloudTrailの対象Trail詳細画面を開く。
2. `KMS key` または `Log file SSE-KMS encryption` の設定を確認する。
3. KMS keyが設定されている場合、リンクまたはキーIDを控える。
4. AWS Consoleの検索欄で `KMS` を開く。
5. 左側メニューから `カスタマー管理型のキー` または `Customer managed keys` を開く。
6. 対象KMSキーを検索して開く。
7. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Key type | Symmetricか |
| Key usage | Encrypt and decryptか |
| Key status | Enabledか |
| Key material origin | AWS_KMS等 |
| Multi-Region | Multi-Region keyか |
| Key policy | CloudTrailと運用者に必要な許可があるか |
| Aliases | 運用上分かる名前が付いているか |

取得する証跡:

- CloudTrail TrailのKMS key設定画面
- KMS Key詳細画面
- Key Policy画面
- Aliasが分かる画面

判定:

| 状態 | 判断 |
|---|---|
| CloudTrailにKMS keyあり、KMS側でCustomer managed keyとして確認できる | 3.5は設定済み候補 |
| CloudTrailにKMS keyなし | 3.5は不足候補 |
| AWS managed keyのみ | 要件の「カスタマー管理KMSキー」と異なる可能性 |
| Key statusがEnabled以外 | ログ配送や復号に影響する可能性 |

注意:

- S3バケットのデフォルト暗号化がSSE-S3やSSE-KMSでも、CloudTrail Trail側のKMS key確認を省略しない。
- Key Policy変更は影響が大きいため、この調査では変更しない。

## 9. 要件3.6 KMSキーRotationを確認する

目的:
3.5で使用するカスタマー管理KMSキーの自動ローテーションが有効か確認する。

手順:

1. AWS Consoleの検索欄で `KMS` を開く。
2. `カスタマー管理型のキー` または `Customer managed keys` を開く。
3. 対象KMSキーを開く。
4. `Key rotation` または `キーローテーション` の項目を確認する。
5. 自動ローテーションが有効か確認する。

取得する証跡:

- KMS Key詳細画面
- Key rotation設定が分かる画面

判定:

| 状態 | 判断 |
|---|---|
| 自動ローテーション有効 | 3.6は設定済み候補 |
| 自動ローテーション無効 | 3.6は不足候補 |
| 対象CMKなし | 3.5対応後に3.6確認が必要 |

注意:

- Rotation有効化は設定変更なので、この調査では実施しない。
- AWS管理キーは利用者側でRotation設定を変更する対象ではない。

## 10. 要件3.7 VPC Flow Logsを確認する

目的:
すべての対象VPCでVPC Flow Logsが有効か確認する。

手順:

1. AWS Consoleの検索欄で `VPC` を開く。
2. 左側メニューから `お使いのVPC` または `Your VPCs` を開く。
3. 対象VPC一覧を確認する。
4. VPCごとに選択し、詳細画面の `Flow logs` タブを開く。
5. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Flow log ID | Flow Logsが存在するか |
| Resource type | VPC / Subnet / Network Interface |
| Resource ID | 対象VPCか |
| Traffic type | ALL / ACCEPT / REJECT |
| Destination type | CloudWatch Logs / S3 |
| Destination | Log GroupまたはS3 |
| Status | Activeか |
| Creation time | 作成日時 |

取得する証跡:

- VPC一覧画面
- 各VPCのFlow logsタブ
- Flow Log詳細画面
- 保存先CloudWatch LogsまたはS3が分かる画面

判定:

| 状態 | 判断 |
|---|---|
| 対象VPCごとにFlow Logsあり、StatusがActive | 3.7は設定済み候補 |
| 一部VPCのみFlow Logsあり | 不足VPCの確認が必要 |
| Flow Logsなし | 3.7は不足候補 |
| Subnet/ENI単位のみ | 要件が「すべてのVPC」なら対象範囲を確認 |

注意:

- Flow Logs有効化は設定変更なので、この調査では実施しない。
- 保存先、Traffic type、保持期間は現場設計に合わせる必要がある。

## 11. 調査結果のまとめ表

以下をExcel等に転記して整理する。

```tsv
要件番号	確認項目	対象リソース	現在値	判定	不足/確認事項	次アクション
3.4	Server Access Logging	CloudTrailログ保存先S3	未確認	未確認	未記入	未記入
3.5	CloudTrail KMS key	CloudTrail Trail	未確認	未確認	未記入	未記入
3.5	KMS Key種別	KMS Key	未確認	未確認	未記入	未記入
3.5	Key Policy	KMS Key	未確認	未確認	未記入	未記入
3.6	Key Rotation	KMS Key	未確認	未確認	未記入	未記入
3.7	VPC Flow Logs	全対象VPC	未確認	未確認	未記入	未記入
```

判定の目安:

| 判定 | 意味 |
|---|---|
| 対応済み | 要件を満たす設定が確認できた |
| 一部対応 | 一部リソースのみ対応、または関連設定が不足 |
| 不足 | 要件を満たす設定が確認できない |
| 要確認 | 設計書や運用判断が必要 |
| 対象外 | 対象外環境や対象外リソースであることを確認済み |

## 12. 最低限必要な参照権限

Webコンソールで参照する場合も、作業アカウントには以下相当の参照権限が必要。

| サービス | 主な参照権限 |
|---|---|
| CloudTrail | Trail詳細、KMS設定、S3保存先の参照 |
| S3 | バケットプロパティ、Server Access Logging、暗号化、Public Access Blockの参照 |
| KMS | KMS Key詳細、Key Policy、Rotation、Aliasの参照 |
| VPC | VPC一覧、Flow Logsの参照 |
| CloudWatch Logs | Flow Logs保存先Log Groupの参照 |

変更時に追加で必要になり得る権限:

| 要件 | 変更時に必要になり得る操作 |
|---|---|
| 3.4 | S3 Server Access Logging有効化 |
| 3.5 | CloudTrail KMS key設定、KMSキー作成、Key Policy変更 |
| 3.6 | KMS Key Rotation有効化 |
| 3.7 | VPC Flow Logs作成、IAM Role指定 |

## 13. 完了条件

以下を満たしたら、3番台の現状調査は完了とする。

- CloudTrail Trailとログ保存先S3を特定済み
- CloudTrailログ保存先S3のServer Access Logging有無を確認済み
- Server Access Logging保存先とPrefixを確認済み
- CloudTrail TrailのKMS key設定を確認済み
- KMSキーがカスタマー管理キーか確認済み
- KMS Key Policy確認要否を整理済み
- KMS Rotation有効化状態を確認済み
- 全対象VPCのFlow Logs有効化状況を確認済み
- 要件3.4〜3.7ごとに、対応済み/不足/要確認/対象外を整理済み

## 14. 参考

- AWS CloudTrail: Encrypting CloudTrail log files with AWS KMS keys
  - English: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html
- Amazon S3: Logging requests using server access logging
  - English: https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html
- AWS KMS: Rotating keys
  - English: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/rotate-keys.html
- Amazon VPC: Flow logs
  - English: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html

