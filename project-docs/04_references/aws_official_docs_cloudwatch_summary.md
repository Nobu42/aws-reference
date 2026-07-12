# AWS公式ドキュメント CloudWatch / CloudWatch Logs要約

作成日: 2026-07-12

この資料は、AWS公式ドキュメントをもとに、CloudWatchとCloudWatch Logsを現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. CloudWatchとは

Amazon CloudWatchは、AWSリソースやAWS上で動くアプリケーションを監視するためのサービスである。

主に次の情報を扱う。

- メトリクス
- ログ
- アラーム
- ダッシュボード
- イベントや通知の起点
- アプリケーションやインフラの可視化

現場では、CloudWatchを「監視・可視化・発報の中心」として扱う。

CloudTrailが「誰が、いつ、どのAWS APIを実行したか」を記録する証跡サービスであるのに対し、CloudWatchは「ログやメトリクスを確認し、状態を監視し、必要なら通知する」サービスである。

## 2. CloudWatchとCloudWatch Logsの違い

| 項目 | 役割 | 現場での見方 |
| :--- | :--- | :--- |
| CloudWatch Metrics | 数値データを保存する | CPU使用率、エラー数、検知件数などを確認する |
| CloudWatch Alarm | メトリクスを監視して状態変化を検知する | OK / ALARM / INSUFFICIENT_DATAを確認する |
| CloudWatch Logs | ログイベントを保存・検索する | CloudTrailログ、アプリログ、VPC Flow Logsなどを確認する |
| Metric Filter | Logsからメトリクスを作る | CloudTrailイベントをカウントしてAlarmにつなげる |
| Logs Insights | ログをクエリ検索する | 調査時にイベントを絞り込む |
| Dashboard | 状態を画面でまとめる | 複数メトリクスやAlarmを一覧化する |

今回のクラウドセキュリティ対応では、特に次の流れが重要である。

```text
CloudTrail Event
  -> CloudWatch Logs Log Group
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS / メール / Teamsなど
```

## 3. CloudWatch Logsとは

CloudWatch Logsは、AWSサービスやアプリケーションから送られるログを集約し、保存、検索、分析するサービスである。

ログの主な送信元:

- CloudTrail
- VPC Flow Logs
- Lambda
- ECS / EKS
- EC2上のCloudWatch Agent
- アプリケーションログ
- Route 53 Resolver Query Logsなど

現場で確認する主な要素:

| 要素 | 意味 |
| :--- | :--- |
| Log Group | ログのまとまり。保持期間、KMS、Metric Filterなどの設定単位 |
| Log Stream | 同じソースから届くログイベントの流れ |
| Log Event | 実際の1件ごとのログ |
| Retention | ログ保持期間 |
| KMS Key | CloudWatch Logs側の暗号化キー |
| Metric Filter | ログからメトリクスを生成する設定 |
| Subscription Filter | ログを別サービスへリアルタイム転送する設定 |

## 4. Log GroupとLog Stream

Log Groupは、保持期間、アクセス制御、KMS、Metric Filterなどを設定する単位である。

Log Streamは、同じソースから来るログイベントの並びである。

例:

```text
Log Group:
  /aws/cloudtrail/management-events

Log Stream:
  123456789012_CloudTrail_ap-northeast-1
  123456789012_CloudTrail_us-east-1
```

現場での確認ポイント:

- Log Group名
- Log Group Class
- Retention
- KMS Key
- Metric Filter数
- Log Streamに最新イベントが届いているか
- Stored bytes
- 削除保護の有無

## 5. Retention

CloudWatch Logsのログデータは、デフォルトでは無期限に保存される。

ただし、Log Groupごとに保持期間を設定できる。

現場での確認ポイント:

- 保持期間が要件に合っているか
- `失効しない` のままになっていないか
- 短すぎて調査に必要なログが消えないか
- 長すぎてコストが増えすぎないか
- CloudTrail連携先Log Groupの保持期間が監査要件と合っているか

注意点:

- 保持期間を短くすると、対象より古いログは削除対象になる
- 削除対象になったログが実際に削除されるまで時間差がある
- 保持期間変更は調査可能期間に影響するため、変更前後の証跡を残す

## 6. Metric Filter

Metric Filterは、CloudWatch Logsに届いたログを検索し、条件に一致したログからCloudWatch Metricsを作る機能である。

公式ドキュメントでは、Metric Filterはログデータを数値のCloudWatchメトリクスに変換し、グラフやアラームに利用できると説明されている。

例:

```text
CloudTrailログ:
  eventName = "PutBucketPolicy"

Metric Filter:
  PutBucketPolicyを検知したら 1 を出す

CloudWatch Metric:
  S3BucketPolicyChangeCount = 1

CloudWatch Alarm:
  1以上になったらALARM
```

確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| Filter Name | 監視対象を識別するため |
| Filter Pattern | 検知条件が要件と一致しているか確認するため |
| Metric Namespace | どの名前空間にメトリクスを作るか確認するため |
| Metric Name | Alarmが参照する名前と一致しているか確認するため |
| Metric Value | 一致時にいくつ加算するか確認するため |
| Default Value | イベントがない期間の扱いを確認するため |
| Dimensions | アカウントやリージョン別に分けるか確認するため |

重要な注意点:

- Metric Filterは作成後に届いたログに対して動作する
- 過去ログを遡ってメトリクス化するものではない
- Metric FilterはStandard Log ClassのLog Groupでサポートされる
- Filter Patternは作成前にテストする
- Dimensionを使う場合、メトリクス数が増えすぎないよう注意する

## 7. CloudWatch Alarm

CloudWatch Alarmは、CloudWatch Metricを監視し、しきい値を超えた場合などに状態を変える機能である。

主な状態:

| 状態 | 意味 |
| :--- | :--- |
| OK | 条件に違反していない |
| ALARM | 条件に違反している |
| INSUFFICIENT_DATA | 判定に必要なデータが不足している |

Alarmで確認する項目:

- Alarm Name
- Metric Namespace
- Metric Name
- Statistic
- Period
- Evaluation Periods
- Datapoints to Alarm
- Threshold
- Comparison Operator
- Treat missing data
- Alarm Actions
- OK Actions
- Insufficient Data Actions
- Actions enabled
- Alarm History

現場で特に重要な点:

- Alarmは状態が変わったときにActionを呼び出す
- 通知先が存在するかはCloudWatch側では完全には検証してくれない
- `INSUFFICIENT_DATA` は必ずしも異常ではない
- 欠損データの扱いによって通知の出方が変わる
- Alarm Historyで、いつ、なぜ状態が変わったかを確認する

## 8. Alarm Actionと通知先

Alarm Actionでは、SNS Topicなどを通知先として指定できる。

現場での確認ポイント:

- Alarm Actionが設定されているか
- Actions enabledが有効か
- SNS Topic ARN
- SNS Topicの購読先
- メール、Teams、Webhook、別アカウント連携の有無
- 通知先が既存運用と重複していないか
- テスト通知の承認が必要か

注意点:

- Alarmを作っただけでは通知されない。Action設定が必要
- SNS Topicが存在していても購読先が有効とは限らない
- メール購読はConfirm済みか確認する
- Teams連携はChatbot、Webhook、Lambda、EventBridgeなど複数方式があり得る

## 9. CloudWatch Logs Insights

CloudWatch Logs Insightsは、CloudWatch Logs上のログをクエリで検索・分析する機能である。

用途:

- CloudTrailログから特定イベントを探す
- 期間を絞ってログを確認する
- EventName、UserIdentity、Source IPなどで絞る
- アプリケーションログのエラーを調査する
- VPC Flow Logsを条件検索する

例:

```text
fields @timestamp, eventName, userIdentity.arn, sourceIPAddress
| filter eventName = "PutBucketPolicy"
| sort @timestamp desc
| limit 50
```

現場での注意点:

- 検索対象のLog Groupと時間範囲を正しく指定する
- 長期間・大量ログを検索するとコストと時間が増える
- CloudTrailの操作時刻は`eventTime`を確認する
- CloudWatch Logsの`@timestamp`はログイベントとして扱われる時刻であり、必ずしも操作時刻の意味だけではない

## 10. KMS暗号化

CloudWatch Logsのデータは常に暗号化される。

デフォルト暗号化とは別に、AWS KMSキーをLog Groupへ関連付けることで、KMSキーによる暗号化もできる。

確認ポイント:

- Log GroupにKMS Keyが関連付けられているか
- KMS Keyが有効か
- Key PolicyでCloudWatch Logsが利用できるか
- `kms:ViaService` 条件を使っているか
- 暗号化コンテキストで対象Log Groupを制限しているか
- ログ参照者が必要な権限を持っているか

注意点:

- KMS Keyを関連付けた後に取り込まれるデータが、そのKeyで暗号化される
- 関連付け解除後も、過去にKMS Keyで暗号化されたログはそのKeyに依存する
- Keyを無効化すると、暗号化済みログを読めなくなる可能性がある
- CloudTrail連携先Log GroupのKMS設定は、CloudTrail監査ログの参照性に影響する

## 11. CloudTrail監視での位置づけ

CloudTrailとCloudWatchの関係は、今回のクラウドセキュリティ対応で特に重要である。

```text
CloudTrail
  AWS APIイベントを記録する

CloudWatch Logs
  CloudTrailイベントを受け取る

Metric Filter
  監視したいイベントを検知してメトリクス化する

CloudWatch Alarm
  メトリクスが条件を満たしたらALARM状態にする

SNS / Teams / メール
  関係者へ通知する
```

4番台要件では、以下のようなイベントをCloudTrailから拾い、CloudWatchで発報する設計となる。

- IAM Policy変更
- CloudTrail設定変更
- S3 Bucket Policy変更
- Security Group変更
- NACL変更
- Route Table変更
- VPC変更
- Organizations変更
- Config変更
- KMS Key無効化、削除スケジュール

## 12. Webコンソールで確認する順番

CloudWatch / CloudWatch LogsをWebコンソールで確認する場合は、次の順番が確認しやすい。

1. CloudTrailのTrail詳細でCloudWatch Logs連携先Log Groupを確認する
2. CloudWatchを開く
3. `ロググループ` を開く
4. 対象Log Groupを開く
5. Retention、KMS、Log Class、Stored bytesを確認する
6. Log Streamにイベントが届いているか確認する
7. Metric Filterを確認する
8. Metric Namespace / Metric Nameを確認する
9. CloudWatchの `アラーム` を開く
10. 対象Metricを見ているAlarmを確認する
11. Alarm Actionと通知先を確認する
12. Alarm Historyを確認する

## 13. 現場チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | CloudTrail連携先Log Group | 監視対象ログの入口を確認する |
| 2 | Log GroupのRetention | 保持期間が要件に合うか確認する |
| 3 | Log GroupのKMS Key | 暗号化要件と復号可否を確認する |
| 4 | Log Class | Metric Filterが使えるか確認する |
| 5 | Log Stream最新時刻 | ログが届いているか確認する |
| 6 | Metric Filter | 検知条件が要件と一致するか確認する |
| 7 | Metric Namespace / Name | Alarmとの接続を確認する |
| 8 | CloudWatch Alarm | 発報条件を確認する |
| 9 | Treat missing data | 通知の出方に影響するため確認する |
| 10 | Alarm Actions | 通知先が設定されているか確認する |
| 11 | SNS Topic / Teams / メール | 実際の通知先を確認する |
| 12 | Alarm History | 過去の状態変化やテスト結果を確認する |
| 13 | 既存EventBridge Rule | 重複通知や別経路通知を確認する |

## 14. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| CloudWatch Logsにログがあれば自動で通知される | 通知にはMetric Filter、Alarm、Actionが必要 |
| Metric Filterは過去ログにも効く | 作成後に届いたログに対してメトリクスを発行する |
| AlarmがOKなら設定は完全に正しい | 通知先やActionが正しいとは限らない |
| INSUFFICIENT_DATAは必ず障害 | データが来ていないだけの場合もある |
| CloudWatch Logsの暗号化は未設定だと平文 | CloudWatch Logsのデータは常に暗号化される |
| KMS Keyを無効化してもログ参照に影響しない | KMSで暗号化されたログを読めなくなる可能性がある |

## 15. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| Amazon CloudWatchとは | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html |
| Amazon CloudWatch Logsとは | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html |
| Log Group / Log Stream | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html |
| Metric Filter | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| CloudWatch Alarm | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html |
| Logs Insights | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/AnalyzingLogData.html |
| Logs Insightsクエリ構文 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html |
| CloudWatch Logs KMS暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |
| CloudWatch料金 | https://aws.amazon.com/jp/cloudwatch/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| What is Amazon CloudWatch | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html |
| What is Amazon CloudWatch Logs | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html |
| Working with log groups and log streams | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html |
| Creating metrics from log events using filters | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| Using Amazon CloudWatch alarms | https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html |
| Analyzing log data with CloudWatch Logs Insights | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html |
| Encrypt log data in CloudWatch Logs using AWS KMS | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |
