# AWS公式ドキュメント VPC Flow Logs要約

作成日: 2026-07-12

この資料は、AWS公式ドキュメントをもとに、VPC Flow Logsを現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. VPC Flow Logsとは

VPC Flow Logsは、VPC内のネットワークインターフェイスとの間で行き来するIPトラフィックに関する情報を取得する機能である。

取得する情報は、パケット本文ではなく通信メタデータである。

主な用途:

- VPC内通信の可視化
- セキュリティグループやNACLの影響調査
- 許可・拒否された通信の確認
- 想定外通信の検知補助
- インシデント調査時の通信証跡確認
- 監査要件に対するネットワークログ取得確認

今回のクラウドセキュリティ対応では、要件3.7「VPC Flow Logsを全VPCで有効化する」系の確認に関係する。

## 2. 何を記録するか

VPC Flow Logsは、通信の流れをレコードとして記録する。

代表的な記録項目:

| 項目 | 意味 |
| :--- | :--- |
| `version` | Flow Logレコード形式のバージョン |
| `account-id` | 対象ENI所有者のAWSアカウントID |
| `interface-id` | 対象ネットワークインターフェイスID |
| `srcaddr` | 送信元IPアドレス |
| `dstaddr` | 送信先IPアドレス |
| `srcport` | 送信元ポート |
| `dstport` | 送信先ポート |
| `protocol` | IANAプロトコル番号 |
| `packets` | フロー内のパケット数 |
| `bytes` | フロー内のバイト数 |
| `start` | 集約期間内の開始時刻 |
| `end` | 集約期間内の終了時刻 |
| `action` | `ACCEPT` または `REJECT` |
| `log-status` | `OK`、`NODATA`、`SKIPDATA` など |

通信メタデータの要約であるため、HTTPヘッダー、リクエスト本文、ファイル内容、SQL文、認証情報などは記録しない。

## 3. 対象範囲

Flow Logsは、以下の単位で作成できる。

| 作成単位 | 対象範囲 | 現場での使い分け |
| :--- | :--- | :--- |
| VPC | VPC内の対象ENI全体 | 全体監査・全体可視化 |
| Subnet | 対象Subnet内のENI | 特定セグメントの確認 |
| Network Interface | 対象ENIのみ | 特定サーバ、NAT Gateway、ALBなどの調査 |

要件が「全VPCで有効化」であれば、まず全VPC一覧を取得し、各VPCにFlow Logsが存在するかを確認する。

注意点:

- VPC単位でFlow Logsを作成しても、すべての通信が完全に記録されるわけではない
- サブネット共有、別アカウント所有ENI、AWSサービス管理ENIでは表示項目に制約が出る場合がある
- Transit Gateway Flow Logsは別機能として扱う

## 4. 保存先

VPC Flow Logsの保存先は複数ある。

| 保存先 | 特徴 | 現場での確認観点 |
| :--- | :--- | :--- |
| CloudWatch Logs | 検索、Metric Filter、Alarm連携に使いやすい | Log Group、Retention、KMS、IAM Role |
| Amazon S3 | 長期保管、Athena分析、コスト整理に使いやすい | Bucket、Prefix、暗号化、Lifecycle |
| Amazon Data Firehose | 外部分析基盤や別サービス連携に使いやすい | Delivery Stream、変換、宛先 |

監査対応では、保存先が設計書や運用方針と一致しているかを確認する。

## 5. Traffic Type

Flow Logs作成時には、記録するトラフィック種別を指定する。

| Traffic Type | 意味 | 確認観点 |
| :--- | :--- | :--- |
| `ACCEPT` | 許可された通信のみ | 通常通信の可視化中心 |
| `REJECT` | 拒否された通信のみ | 遮断・不審通信調査中心 |
| `ALL` | 許可・拒否の両方 | 監査・調査では最も網羅的 |

要件が明確でない場合は、`ALL`が必要か、ログ量と費用を踏まえて確認する。

## 6. Log Format

Flow Logsにはデフォルト形式とカスタム形式がある。

| 形式 | 特徴 |
| :--- | :--- |
| デフォルト形式 | バージョン2の標準フィールドを固定順で出力する |
| カスタム形式 | 必要なフィールドと順序を指定できる |

現場で確認する項目:

- デフォルト形式かカスタム形式か
- `vpc-id`、`subnet-id`、`instance-id` など調査に必要な項目が入っているか
- `pkt-srcaddr`、`pkt-dstaddr` が必要か
- S3保存時にText形式かParquet形式か
- Athena分析を想定しているか

一度作成したFlow Logsの設定やレコード形式は変更できない。変更する場合は、既存Flow Logsを削除し、新しい設定で作成する。

## 7. 集約間隔と配信遅延

Flow Logsは通信を即時に1パケット単位で出すものではない。一定期間の通信を集約してレコード化する。

| 項目 | 内容 |
| :--- | :--- |
| 最大集約間隔 | 1分または10分 |
| デフォルト傾向 | 最大10分 |
| Nitro系ENI | 指定に関係なく1分以下になる |
| CloudWatch Logs配信 | 通常約5分が目安 |
| S3配信 | 通常約10分が目安 |

配信はベストエフォートであり、通常時間を超えて遅れることがある。

テスト時の注意:

- 作成直後はログが出ない場合がある
- 対象ENIに通信がなければ `NODATA` になる
- 短時間の確認では未配信と未発生を誤認しやすい
- テストでは、対象VPC内で明示的に通信を発生させる

## 8. `action` と `log-status`

Flow Logs確認で特に重要なフィールドは `action` と `log-status` である。

### action

| 値 | 意味 |
| :--- | :--- |
| `ACCEPT` | セキュリティグループまたはNACLで許可された通信 |
| `REJECT` | セキュリティグループまたはNACLで拒否された通信 |

`REJECT` は必ずしも障害や攻撃を意味しない。想定された遮断、スキャン、設定ミス、通信先誤りなど複数の可能性がある。

### log-status

| 値 | 意味 |
| :--- | :--- |
| `OK` | 正常に記録された |
| `NODATA` | 集約間隔内に対象通信がなかった |
| `SKIPDATA` | 一部レコードがスキップされた |

`SKIPDATA` は内部的な容量制限や内部エラーで発生する場合がある。大量通信や分析時は、`SKIPDATA` の有無も確認する。

## 9. 記録されない通信

VPC Flow LogsはすべてのIPトラフィックを記録するわけではない。

代表的に記録されない通信:

- Amazon DNSサーバーへの通信
- Instance Metadata Service `169.254.169.254` との通信
- Amazon Time Sync Service `169.254.169.123` との通信
- DHCPトラフィック
- ARPトラフィック
- Windowsライセンスアクティベーション関連通信
- デフォルトVPCルーター予約アドレスへの通信
- 一部のNetwork Load Balancer関連通信
- 短時間で削除されるリージョンNAT Gateway上の通信

調査で「ログに出ない」場合、Flow Logsの未設定だけでなく、公式上記録対象外の通信かどうかも確認する。

## 10. CloudWatch Logs保存時の確認

CloudWatch Logsへ発行する場合、Log GroupとIAM Roleが重要である。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Log Group | 保存先Log Groupが設計どおりか |
| Retention | 保持期間が要件に合うか |
| KMS Key | Log Group暗号化要件に合うか |
| IAM Role | Flow LogsがCloudWatch Logsへ書き込めるか |
| Log Stream | 対象ENIやFlow Logからログが届いているか |
| Metric Filter | 既存の監視やアラームがあるか |

CloudWatch Logs保存は検索やAlarm連携に向くが、ログ量が多いと費用や画面表示の重さに影響する。

## 11. S3保存時の確認

S3へ発行する場合、長期保管やAthena分析に向く。

確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| Bucket | 保存先バケットが設計どおりか |
| Prefix | 環境、アカウント、リージョンで整理されているか |
| File format | Plain textかParquetか |
| Hive-compatible prefix | Athena分析前提か |
| Partition | 日付や時間で分割されるか |
| Encryption | SSE-S3かSSE-KMSか |
| Lifecycle | 保持期間とコスト削減策があるか |
| Bucket Policy | Flow Logs配信に必要な許可があるか |

監査対応では、S3保存先の暗号化、ライフサイクル、アクセス制御、保管期間をセットで確認する。

## 12. 費用影響

VPC Flow Logsを有効化すると、ログの取り込み、保存、分析に費用が発生する。

主な費用要素:

- Vended Logsの取り込み
- CloudWatch Logs保存
- S3保存
- Athenaクエリ
- KMSリクエスト
- Firehose利用

費用が増えやすい条件:

- `Traffic Type = ALL`
- 対象VPCやENIが多い
- 通信量が多い
- 集約間隔が短い
- 保持期間が長い
- CloudWatch LogsとS3の両方に保存する
- Parquet変換やAthena分析を頻繁に行う

設計時は、対象VPC、保存先、保持期間、ログ形式、暗号化、分析方式を合わせて確認する。

## 13. 業務影響

VPC Flow Logsはネットワークトラフィックのパス外で収集されるため、作成や削除によってネットワークのスループットやレイテンシーに直接影響しない。

ただし、運用上の影響はあり得る。

| 影響 | 理由 |
| :--- | :--- |
| ログ量増加 | 対象VPCや通信量に応じて保存量が増える |
| 費用増加 | 取り込み、保存、分析、KMS利用が増える |
| 通知増加 | Metric FilterやAlarmを組み合わせた場合 |
| 調査対象増加 | CloudWatch LogsやS3に確認対象が増える |
| 既存運用との差分 | 月次確認から即時確認へ変わる可能性 |

本番通信自体を変える作業ではないが、ログ保存先、費用、通知、証跡運用には影響する。

## 14. Webコンソールで確認する順番

VPC Flow LogsをWebコンソールで確認する場合は、次の順番が確認しやすい。

1. 対象アカウントとリージョンを確認する
2. VPCコンソールを開く
3. `VPC` 一覧を確認する
4. 対象VPCを選択する
5. `Flow Logs` タブを確認する
6. Flow Log ID、Status、Traffic Typeを確認する
7. 保存先がCloudWatch Logs、S3、Firehoseのどれか確認する
8. Log Formatを確認する
9. 最大集約間隔を確認する
10. Tagsを確認する
11. 保存先のCloudWatch LogsまたはS3を開く
12. 最新ログが届いているか確認する
13. Retention、KMS、Lifecycleを確認する
14. 既存のMetric Filter、Alarm、通知設定を確認する

要件が全VPC対象の場合、VPC一覧とFlow Logs一覧を突き合わせる。

## 15. 現場チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | 対象リージョン | VPCはリージョン単位のため |
| 2 | VPC一覧 | 全VPCが対象か判断する |
| 3 | Flow Logs有無 | 3.7要件の充足確認 |
| 4 | 作成単位 | VPC、Subnet、ENIのどれか確認する |
| 5 | Traffic Type | `ALL`、`ACCEPT`、`REJECT`の妥当性確認 |
| 6 | 保存先 | CloudWatch Logs、S3、Firehoseの確認 |
| 7 | Log Format | 調査に必要な項目が含まれるか確認 |
| 8 | Aggregation Interval | ログ量と遅延の確認 |
| 9 | IAM Role / Bucket Policy | 配信権限の確認 |
| 10 | Retention / Lifecycle | 保持期間と費用の確認 |
| 11 | KMS暗号化 | 暗号化要件の確認 |
| 12 | 最新ログ | 実際に配送されているか確認 |
| 13 | `SKIPDATA` | 欠損や内部制限の兆候確認 |
| 14 | 既存通知 | 重複通知や既存監視の確認 |
| 15 | 証跡 | 作業前後の設定画面を保存する |

## 16. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| Flow Logsを有効化すると通信が遅くなる | 通信経路外で収集されるため、スループットやレイテンシーには直接影響しない |
| Flow Logsはパケット内容まで記録する | 記録するのは通信メタデータであり、本文は記録しない |
| VPC単位で有効なら全通信が完全に記録される | 公式上、記録対象外の通信や制限がある |
| ログが出ない場合は設定ミス | 通信がない、配信遅延、記録対象外、`NODATA` の可能性もある |
| 作成後に形式を変更できる | Flow Logsの設定やレコード形式は作成後に変更できない |
| `REJECT` は必ず攻撃 | 通常の遮断や設定ミスでも発生する |
| CloudWatch Logs保存なら長期保管に向く | 長期・大量保管はS3の方が向く場合がある |

## 17. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| VPC Flow Logs概要 | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html |
| Flow Logレコード | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-log-records.html |
| Flow Logs制限事項 | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-limitations.html |
| Flow Logsの使用 | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/working-with-flow-logs.html |
| CloudWatch Logsへの発行 | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-cwl.html |
| CloudWatch Logs用IAM Role | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-iam-role.html |
| S3への発行 | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-s3.html |
| Flow Logsトラブルシューティング | https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-troubleshooting.html |
| VPC料金 | https://aws.amazon.com/jp/vpc/pricing/ |
| CloudWatch料金 | https://aws.amazon.com/jp/cloudwatch/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| VPC Flow Logs overview | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html |
| Flow log records | https://docs.aws.amazon.com/vpc/latest/userguide/flow-log-records.html |
| Flow logs limitations | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-limitations.html |
| Work with flow logs | https://docs.aws.amazon.com/vpc/latest/userguide/working-with-flow-logs.html |
| Publish flow logs to CloudWatch Logs | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-cwl.html |
| IAM role for CloudWatch Logs | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-iam-role.html |
| Publish flow logs to Amazon S3 | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3.html |
| Troubleshoot VPC Flow Logs | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-troubleshooting.html |
