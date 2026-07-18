# 要件4.5/4.7 CloudWatch関連公式ドキュメント根拠整理

作成日: 2026-07-19

本資料は、要件4.5「CloudTrail設定変更監視」および要件4.7「カスタマー管理KMSキーの無効化・削除予約監視」で使用するCloudWatch / CloudWatch Logs関連設定について、AWS公式ドキュメント上の根拠URLを整理するものである。

PM、レビュー担当、インフラ担当から「その設定根拠は公式のどこにあるか」と確認された場合に、本資料のURLを提示する。

## 1. 今回の構成と公式根拠

今回の監視方式は以下の構成を前提とする。

```text
CloudTrail Management Event
  -> CloudWatch Logs Log Group
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS等の通知先
```

この構成は、以下の公式ドキュメントを根拠とする。

| 項目 | 作業上の意味 | 公式URL |
| :--- | :--- | :--- |
| CloudTrailイベントをCloudWatch Logsへ送信する | Metric Filterの入力元ログを作る | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| CloudTrail配信用IAM Roleが必要 | CloudTrailがCloudWatch Logsへ書き込む | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html |
| Metric Filterでログをメトリクス化する | CloudTrailイベントをCloudWatch Metricへ変換する | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| Filter Patternで検知条件を定義する | `eventName`や`eventSource`を条件にする | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html |
| CloudWatch Alarmでメトリクスを監視する | しきい値到達時にALARM状態へ遷移させる | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html |
| Alarm ActionでSNS通知する | ALARM遷移時に通知先へ連携する | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html |
| 欠落データの扱いを設定する | `notBreaching`等で誤検知を抑える | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html |
| CloudWatch LogsのKMS暗号化を確認する | Log Group暗号化要件を確認する | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |

## 2. CloudTrailからCloudWatch Logsへの連携

### 2.1 根拠

公式ドキュメントでは、CloudTrailがモニタリングのためにイベントをCloudWatch Logsへ送信するように証跡を設定できると説明されている。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| CloudTrailはCloudWatch Logsロググループをログイベントの配信エンドポイントとして使用する | Metric Filter方式の前提としてCloudWatch Logs連携を有効化する |
| ロググループは新規作成または既存ロググループを指定できる | パラメータシート上の既存Log Groupを使うか、新規作成するか確認する |
| マルチリージョンTrailは有効リージョンのログを指定ロググループへ送る | 対象Trailがマルチリージョンの場合、監視範囲の確認が必要 |
| CloudTrailからCloudWatch Logsロググループへ配信する場合、ロググループは現在のアカウント内に存在する必要がある | 別アカウントLog Groupを直接指定する前提にしない |
| CloudTrailは通常、APIコールから平均5分以内にロググループへ配信するが保証ではない | テスト時は数分待機する。即時到達しないことを失敗扱いしない |

### 2.2 PMに聞かれた時の返し

```text
CloudTrailイベントをMetric Filterで検知するには、CloudTrailイベントがCloudWatch Logsへ配信されている必要がある。
AWS公式ドキュメントのCloudTrail「CloudWatch Logs へのイベントの送信」に、証跡からCloudWatch Logsロググループへイベントを送信する設定手順が記載されている。
```

## 3. CloudTrail配信用IAM Role

### 3.1 根拠

公式ドキュメントでは、CloudTrailがCloudWatch Logsへイベントを配信するためにIAM Roleを割り当てると説明されている。  
デフォルトRole名として`CloudTrail_CloudWatchLogs_Role`が示されているが、別Roleを指定する場合も必要なRole Policyを付与する必要がある。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| デフォルトでは`CloudTrail_CloudWatchLogs_Role`が指定される | 現場命名規則を使う場合は、デフォルト名ではなく同用途の別Roleとして扱う |
| 別Roleも指定可能 | 現場命名規則に沿ったRole名を使える |
| 別Roleを使う場合、必要なRole Policyを既存Roleへ付与する必要がある | Role名だけでは不十分。信頼関係と権限ポリシーを確認する |
| Role Policy例に`logs:CreateLogStream`と`logs:PutLogEvents`が含まれる | CloudTrail配信用Roleの最小要点として確認する |
| Organization Trailではデフォルトポリシーの変更が必要になる場合がある | 組織Trailかどうかを作業前に確認する |

### 3.2 PMに聞かれた時の返し

```text
CloudTrailからCloudWatch Logsへ配信するには、CloudTrailがAssumeRoleするIAM Roleが必要となる。
公式ドキュメントではデフォルトRole名としてCloudTrail_CloudWatchLogs_Roleが示されているが、別Roleも指定可能である。
ただし、別Roleを使う場合もlogs:CreateLogStream、logs:PutLogEvents等のCloudWatch Logs書き込み権限が必要となる。
```

## 4. Metric Filter

### 4.1 根拠

公式ドキュメントでは、CloudWatch Logsに送信されたログデータをMetric Filterで検索・フィルタリングし、数値のCloudWatch Metricへ変換できると説明されている。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| Metric FilterはCloudWatch Logsに送信されたログデータを検索・フィルタリングする | CloudTrailイベントがLog Groupへ届いていることが前提 |
| Metric FilterはログデータをCloudWatch Metricへ変換する | AlarmはこのMetricを監視する |
| Metric FilterはStandard log classのLog Groupでのみサポートされる | 対象Log GroupのLog Classを確認する |
| Filter作成後に発生したイベントのみメトリクス化する | 過去イベントを後から検知する用途ではない |
| Metric ValueとDefault Valueを指定できる | 今回は一致時`1`、Default Value`0`を基本とする |
| Dimensionを付けるとDefault Valueを指定できない | 先行作業ではDimensionなしを基本とする |
| 高カーディナリティDimensionは費用増や自動無効化リスクがある | `userIdentity.arn`や`sourceIPAddress`をDimensionにしない |
| JSONログイベントの条件指定、AND/OR条件を使える | CloudTrail JSONの`eventName`、`eventSource`条件に使う |

### 4.2 今回のFilter Pattern根拠

要件4.5:

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

要件4.7:

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

公式ドキュメント上の根拠は、CloudWatch Logs Metric FilterがJSONログイベントのフィールド条件を評価できること、AND/OR条件を使えること、Metric Valueを一致ごとに加算できることである。  
具体的な監査用Filter Pattern自体は、Security Hub / CIS Foundations Benchmark相当の要件に合わせる。

### 4.3 PMに聞かれた時の返し

```text
Metric FilterはCloudWatch Logsに入ったログイベントを条件一致で拾い、CloudWatch Metricへ変換する機能である。
AWS公式ドキュメントのCloudWatch Logs「フィルターを使用したログイベントからのメトリクスの作成」と「メトリクスフィルターのフィルターパターン構文」に、ログデータをメトリクス化する考え方、Metric Value、Default Value、JSONフィールド条件、AND/OR条件が記載されている。
```

## 5. CloudWatch Alarm

### 5.1 根拠

公式ドキュメントでは、CloudWatch Alarmはメトリクスを監視し、しきい値を超過した場合に通知等のアクションを実行できると説明されている。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| Alarmはメトリクスを監視し、しきい値超過時にアクションを実行できる | Metric Filterで作成したMetricをAlarm監視する |
| Alarm ActionとしてSNS Topic通知を使える | 既存SNS TopicをAlarm Actionに指定する |
| Alarm Actionは状態遷移時に実行される | 既にALARM状態のままでは通知が再実行されない可能性がある |
| AlarmはOK、ALARM、INSUFFICIENT_DATA等の状態を持つ | 証跡では状態と状態理由を取得する |
| 欠落データの扱いを指定できる | 今回はイベント発生時のみデータが出る性質のため`notBreaching`を基本とする |
| 欠落データのデフォルト動作は`missing` | 設計値として`notBreaching`を明示する |

### 5.2 今回のAlarm設定値の根拠

| 設定 | 今回の基本値 | 根拠 |
| :--- | :--- | :--- |
| Statistic | `Sum` | Metric Filterの一致回数を合計する |
| Period | `300秒` | CloudTrail配信遅延と運用通知の実用性を考慮する |
| Evaluation Periods | `1` | 1期間内で1回でも検知したら通知する |
| Datapoints to Alarm | `1` | 1データポイントでALARMにする |
| Threshold | `>= 1` | 対象イベントが1回以上発生したら通知する |
| Treat missing data | `notBreaching` | 対象イベントがない状態を正常扱いにする |
| Alarm Action | 既存SNS Topic | 公式でSNS Topic通知がAlarm Actionとしてサポートされる |
| OK Action | 原則なし | 今回は検知通知が目的であり復旧通知は要件外 |
| Insufficient Data Action | 原則なし | 欠落データによる不要通知を避ける |

### 5.3 PMに聞かれた時の返し

```text
CloudWatch AlarmはCloudWatch Metricを監視し、しきい値を超過した場合に通知等のActionを実行できる。
今回のMetricは対象イベント発生時に1加算されるため、Sum >= 1を条件にする。
対象イベントが発生しない期間は正常であるため、欠落データはnotBreachingとして扱う。
```

## 6. Alarm ActionとSNS通知

### 6.1 根拠

公式ドキュメントでは、Alarm ActionとしてAmazon SNS Topicを使用し、サブスクライバーへ通知できると説明されている。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| Alarmは状態変化時にActionを実行できる | ALARM遷移時の通知を設定する |
| Alarm ActionとしてSNS Topic通知がサポートされる | 既存SNS Topicを利用する |
| Actionは状態遷移時に発生する | テスト時はALARM状態への遷移を確認する |
| AlarmはEventBridgeにも状態変化イベントを出力できる | 既存EventBridge / A-gateとの二重通知有無を確認する |

### 6.2 PMに聞かれた時の返し

```text
CloudWatch AlarmのActionとしてSNS Topic通知は公式にサポートされている。
ただし、Alarm Actionは状態遷移時に実行されるため、通知テストではALARM状態への遷移と受信確認をセットで確認する。
```

## 7. CloudWatch LogsのKMS暗号化

### 7.1 根拠

公式ドキュメントでは、CloudWatch Logsのロググループデータは常に暗号化され、デフォルトではCloudWatch Logsのサーバー側暗号化が使われると説明されている。  
AWS KMSを使う場合は、KMS Keyをロググループに関連付けることでロググループレベルで有効化する。

公式URL:

```text
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
```

作業への反映:

| 公式記載から分かること | 作業での扱い |
| :--- | :--- |
| CloudWatch Logsのデータは常に暗号化される | KMS未指定でも暗号化なしとは判断しない |
| KMS Keyを関連付けるとロググループレベルでKMS暗号化される | CMK要件がある場合はLog GroupのKMS Keyを確認する |
| KMS Key関連付け後、新規取り込みデータがそのKeyで暗号化される | 過去ログへの扱いと新規ログへの扱いを分ける |
| KMS Keyの関連付け解除後も、過去にKMS暗号化されたデータはそのKeyで暗号化されたまま残る | 切り戻し時の説明に使う |
| KMS Keyを無効化すると、そのKeyで暗号化されたログを読めなくなる可能性がある | 4.7で本物のCMKを無効化テストしない |
| CloudWatch Logsは対称KMS Keyのみサポートする | 非対称Keyを指定しない |

### 7.2 PMに聞かれた時の返し

```text
CloudWatch Logsはデフォルトでも保管時暗号化される。
ただしCMK要件がある場合は、ロググループにKMS Keyを関連付ける必要がある。
また、KMS Keyを無効化すると、そのKeyで暗号化されたCloudWatch Logsデータを読めなくなる可能性があるため、4.7の通知テストで本物のCMKを無効化しない。
```

## 8. レビューで確認するべき論点

| 論点 | 確認内容 | 根拠URL |
| :--- | :--- | :--- |
| CloudTrail -> CloudWatch Logs連携を今回追加するか | Metric Filter方式の前提 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| 既存Log Groupを使うか | CloudTrailは既存Log Groupを指定可能 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| IAM Role名はデフォルトか現場命名規則か | デフォルトRoleまたは別Roleを指定可能 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| IAM Roleの権限は足りるか | `logs:CreateLogStream`と`logs:PutLogEvents`が必要 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html |
| Metric Filter作成先Log GroupはStandardか | Metric FilterはStandard log classのみサポート | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| Dimensionを付けない方針でよいか | Dimension付与時はDefault Value不可、高カーディナリティ注意 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html |
| Alarmの欠落データを`notBreaching`にするか | 欠落データ処理を指定可能 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html |
| Alarm Actionは既存SNS Topicでよいか | SNS Topic通知がAlarm Actionとしてサポートされる | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html |
| Log GroupのKMS暗号化要否 | KMS KeyはLog Groupへ関連付ける | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |

## 9. PM向け短文

```text
今回の4.5/4.7は、CloudTrailのManagement EventをCloudWatch Logsへ連携し、Metric Filterで対象イベントをCloudWatch Metric化し、CloudWatch AlarmでSum >= 1を検知して既存SNS Topicへ通知する構成である。

CloudTrail -> CloudWatch Logs連携、Metric Filter、Alarm、Alarm Action、欠落データ処理、Log GroupのKMS暗号化については、AWS公式ドキュメント上の根拠URLを整理済みである。
レビューでは、既存Log Group利用可否、CloudTrail配信用IAM Role名、既存SNS Topic利用可否、KMS暗号化要否、検証環境での設定残置/切り戻し方針を確認する。
```

## 10. 参照URL一覧

| 分類 | URL |
| :--- | :--- |
| CloudTrail -> CloudWatch Logs連携 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| CloudTrail配信用IAM Role Policy | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html |
| Metric Filter概念 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| Metric Filter構文 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html |
| CloudWatch Alarm | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html |
| Alarm Action | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html |
| Alarm欠落データ | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html |
| CloudWatch Logs KMS暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |
