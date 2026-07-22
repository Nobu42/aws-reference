# CloudWatch Metric Namespace 設計確認メモ

作成日: 2026-07-23

対象: 要件4.5、要件4.7、および4番台のCloudWatch Metric Filter / CloudWatch Alarm設定

## 1. この資料の目的

CloudWatch LogsのMetric Filterで作成するメトリクスについて、どのMetric Namespaceを使用するかを整理する。

今回の先行作業では、既存環境に`Custom/`配下のメトリクスが存在し、Hinemos関連のAlarmが設定されていることを確認している。そのため、`Custom/`を今回のCloudTrail監視用にも使用してよいかを事前確認する。

## 2. 結論

`AWS/`で始まるNamespaceは使用しない。

`Custom/`を使用する場合は、既存Hinemos監視との役割分担を確認してから使用する。

現場側の命名規則が未確定の場合は、次のいずれかを候補とする。

| 候補 | 評価 | 理由 |
| :--- | :--- | :--- |
| `Custom/CloudSecurity` | 推奨候補 | 既存の`Custom/`配下に置きつつ、CloudTrail監視用途を分離できる |
| `Custom/CloudTrailSecurity` | 推奨候補 | CloudTrail由来の監視であることが明確になる |
| `<システム名>/Security` | 要命名規則確認 | 現場のシステム名ベース命名に合わせやすい |
| `<システム名>/CloudTrail` | 要命名規則確認 | CloudTrail監視用途として分かりやすい |
| `Custom/`単体 | 要確認 | Hinemos既存監視と混在する可能性がある |
| `AWS/CloudTrail`など`AWS/`配下 | 不採用 | AWSサービス由来のNamespaceと誤認されるため、独自Metric Filter用には使わない |

## 3. 用語整理

| 用語 | 意味 |
| :--- | :--- |
| Namespace | CloudWatchメトリクスを分類する入れ物 |
| Metric Name | メトリクス名。例: `CloudTrailChanges`、`KMSKeyDisabledOrScheduledDeletion` |
| Metric Filter | CloudWatch Logsに届いたログイベントから、条件に一致した件数などをCloudWatchメトリクスへ変換する設定 |
| CloudWatch Alarm | 指定したNamespace、Metric Name、条件を監視し、しきい値を超えた場合にAlarm状態へ遷移する設定 |

Metric Filterで指定するNamespaceとMetric Nameは、Alarm側でも同じ値を指定する必要がある。

## 4. 今回の観測事項

| 項目 | 確認内容 |
| :--- | :--- |
| 既存Namespace | `Custom/`配下のメトリクスを確認 |
| 既存Alarm | Hinemos関連のAlarmを確認 |
| 判断が必要な点 | `Custom/`がHinemos専用なのか、汎用的な独自監視用Namespaceなのか |
| リスク | CloudTrail監視用メトリクスを同じ場所に追加すると、Hinemos由来の監視と混在して管理しにくくなる可能性がある |

## 5. 確認すべきこと

| 確認対象 | 確認内容 | 理由 |
| :--- | :--- | :--- |
| パラメータシート | `MetricNamespace`、`Namespace`、`メトリクス名前空間`、`監視Namespace`に相当する項目があるか | 設計値として指定済みか確認する |
| 既存Hinemos Alarm | `Custom/`配下のAlarmがHinemos専用か | 既存監視の管理責任範囲と混在しないようにする |
| 既存CloudWatch Alarm | 4番台に相当するAlarmが既にあるか | 二重通知や重複設定を避ける |
| 通知設計 | Namespaceごとに通知経路や監視製品連携が分かれているか | 追加後の運用確認先を明確にする |
| 命名規則 | Namespace、Metric Name、Alarm Nameの命名規則があるか | レビュー指摘や運用混乱を防ぐ |
| 本番・検証差異 | 本番環境と検証環境で同じNamespaceを使うか | 環境差異によるテスト漏れを防ぐ |

## 6. Webコンソールでの確認手順

### 6.1 既存Namespaceを確認する

1. AWS Management Consoleにログインする
2. CloudWatchを開く
3. 左ペインで「メトリクス」を開く
4. 「すべてのメトリクス」または「参照」を開く
5. `AWS/`、`Custom/`、その他の独自Namespaceを確認する
6. `Custom/`配下にあるメトリクス名、ディメンション、関連Alarmを確認する

### 6.2 既存AlarmのNamespaceを確認する

1. CloudWatchを開く
2. 左ペインで「アラーム」を開く
3. 対象Alarmを開く
4. 「メトリクス」または「条件」欄を確認する
5. Namespace、Metric Name、Dimensions、Statistic、Periodを確認する
6. Hinemos関連AlarmとCloudTrail監視用Alarmが混在していないか確認する

### 6.3 Metric Filter側のNamespaceを確認する

1. CloudWatchを開く
2. 左ペインで「ロググループ」を開く
3. CloudTrail連携先のLog Groupを開く
4. 「メトリクスフィルター」を開く
5. 対象Metric Filterを開く
6. Metric Namespace、Metric Name、Filter Patternを確認する

## 7. 今回の4.5/4.7における設定候補

| 要件 | 監視対象 | Metric Namespace候補 | Metric Name候補 |
| :--- | :--- | :--- | :--- |
| 4.5 | CloudTrail設定変更 | `Custom/CloudSecurity` | `CloudTrailChanges` |
| 4.7 | CMK無効化・削除予約 | `Custom/CloudSecurity` | `KMSKeyDisabledOrScheduledDeletion` |

上記は候補である。実際の設定値は、パラメータシート、命名規則、既存監視設計に合わせて確定する。

## 8. レビュー時の説明方針

今回作成するMetric Filterは、AWSサービスが自動発行する標準メトリクスではなく、CloudTrailログを条件抽出して作成する独自メトリクスである。

そのため、`AWS/`配下ではなく、独自監視用のNamespaceに配置する。

既存環境には`Custom/`配下のHinemos関連Alarmがあるため、同じ`Custom/`配下を使用してよいか、またはCloudTrail監視用に`Custom/CloudSecurity`などの用途別Namespaceを作成するかを確認する。

## 9. 確認文例

```text
CloudWatch Metric Filterで作成するメトリクスのNamespaceについて確認。

既存環境では Custom/ 配下にHinemos関連のAlarmが存在することを確認済み。
今回追加するCloudTrail監視用のMetric Filterについても、同じ Custom/ 配下を使用して問題ないか確認。

Custom/ がHinemos専用または既存監視専用のNamespaceである場合は、
CloudTrail監視用に Custom/CloudSecurity などの用途別Namespaceを作成する方針で問題ないか確認。

あわせて、Metric Namespace、Metric Name、Alarm Nameの命名規則の有無を確認。
```

## 10. パラメータシート反映案

| 項目 | 記載値例 | 備考 |
| :--- | :--- | :--- |
| MetricNamespace | `Custom/CloudSecurity` | 現場確認後に確定 |
| MetricName | `CloudTrailChanges` | 要件4.5 |
| MetricName | `KMSKeyDisabledOrScheduledDeletion` | 要件4.7 |
| AlarmName | 現場命名規則に従う | 環境名、要件番号、監視内容を含める |
| AlarmActions | 既存SNS Topic ARN | 既存Topicを使用する想定 |

## 11. 注意点

- Namespaceを変えると、Alarm側も同じNamespaceに合わせる必要がある。
- NamespaceとMetric Nameの組み合わせが違うと、Alarmが期待するメトリクスを参照できない。
- `Custom/`配下を流用する場合、既存Hinemos監視との運用責任範囲を確認する。
- `AWS/`配下はAWSサービス由来のメトリクスと誤認されるため、独自Metric Filterでは使用しない。
- 本番と検証でNamespaceが異なる場合、手順書と証跡に明記する。

## 12. CLI利用可能な場合の確認コマンド

CLI利用が許可されている場合のみ使用する。

```bash
# 既存メトリクスのNamespace一覧を確認する。
aws cloudwatch list-metrics \
  --region <region> \
  --query 'Metrics[].Namespace' \
  --output text
```

```bash
# 対象Namespace配下のメトリクスを確認する。
aws cloudwatch list-metrics \
  --region <region> \
  --namespace "Custom/CloudSecurity" \
  --output json
```

```bash
# Log Groupに設定済みのMetric FilterとMetric Namespaceを確認する。
aws logs describe-metric-filters \
  --region <region> \
  --log-group-name "<cloudtrail-log-group-name>" \
  --query 'metricFilters[].{FilterName:filterName,Pattern:filterPattern,Transformations:metricTransformations}' \
  --output json
```

## 13. 公式ドキュメント

- [Amazon CloudWatch メトリクスの概念](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html)
- [利用可能なメトリクスを表示する](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/viewing_metrics_with_cloudwatch.html)
- [フィルターを使用したログイベントからのメトリクスの作成](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
- [MetricTransformation API Reference](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatchLogs/latest/APIReference/API_MetricTransformation.html)
- [PutMetricData API Reference](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_PutMetricData.html)
