# 要件4.8 S3バケットポリシー変更監視 現状調査手順書 Webコンソール版

作成日: 2026-07-09

この手順書は、要件4.8「S3バケットポリシーの変更が監視されていること」について、AWS Management Consoleを使って現状調査を行うための手順である。

最初に共有された評価シート由来のテキスト情報を正とし、元要件では「CloudTrailをCloudWatchに連携し、メトリクスおよびアラーム設定で発報する」方針として扱う。
EventBridgeは元要件の必須方式ではなく、既存監視や重複通知の確認観点として扱う。

## 1. 調査目的

要件4.8では、S3バケットポリシーの変更を検知し、アラート発報できる状態か確認する。

主に確認するイベントは以下。

| イベント名 | 意味 |
|---|---|
| `PutBucketPolicy` | S3バケットポリシーを作成または更新した |
| `DeleteBucketPolicy` | S3バケットポリシーを削除した |

## 2. 前提

| 項目 | 内容 |
|---|---|
| 作業方法 | AWS Management Console |
| 対象ログ | CloudTrail Management Event |
| 監視方式 | CloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> 通知 |
| 補足確認 | EventBridge Rule、既存監視製品、SIEM等 |
| 注意 | 本手順は調査手順であり、設定変更は行わない |

## 3. 調査で確認するもの

| No | 確認対象 | 確認内容 |
|---|---|---|
| 1 | 対象アカウント・リージョン | 正しいAWSアカウント、対象リージョンで作業しているか |
| 2 | CloudTrail | Trailが存在し、Management Eventを記録しているか |
| 3 | CloudWatch Logs連携 | CloudTrailがCloudWatch Logsへ配送されているか |
| 4 | CloudTrail Event History | `PutBucketPolicy` / `DeleteBucketPolicy` の過去イベントがあるか |
| 5 | CloudWatch Logs | CloudTrailイベントがLog Groupに届いているか |
| 6 | Metric Filter | S3バケットポリシー変更用のMetric Filterがあるか |
| 7 | CloudWatch Alarm | Metric Filterに紐づくAlarmがあるか |
| 8 | 通知先 | SNS等の通知Actionが設定されているか |
| 9 | 補足確認 | EventBridgeや既存監視製品で同等監視がないか |

## 4. 調査手順

### 4.1 AWSアカウントとリージョンを確認する

1. AWS Management Consoleへログインする。
2. 画面右上のアカウント表示を確認する。
3. 対象アカウントであることを確認する。
4. 画面右上のリージョンを確認する。
5. 対象リージョンを選択する。

取得する証跡:

- アカウント表示が分かる画面キャプチャ
- リージョン表示が分かる画面キャプチャ

注意:

- Organizations配下の場合、監査対象Trailが管理アカウント側にある可能性がある。
- Multi-Region Trailの場合、TrailのHome Regionで詳細確認する。

### 4.2 CloudTrail Trailを確認する

1. AWS Consoleの検索欄で `CloudTrail` を開く。
2. 左側メニューから `証跡` または `Trails` を開く。
3. 対象Trailを選択する。
4. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Trail名 | 対象Trailか |
| 証跡ログ記録 | Loggingが有効か |
| Multi-Region | 全リージョン対象か |
| Management events | 記録対象か |
| Read/Write | Writeイベントが記録対象か |
| S3バケット | CloudTrailログ保存先 |
| CloudWatch Logs | 連携先Log Groupが設定されているか |
| IAM Role | CloudTrailがCloudWatch Logsへ書き込むRole |

判定:

| 状態 | 判断 |
|---|---|
| Management Eventが有効 | 4.8のイベント記録前提を満たす |
| Write Eventが記録対象 | `PutBucketPolicy` / `DeleteBucketPolicy` を記録できる |
| CloudWatch Logs連携あり | Metric Filter/Alarm方式へ進める |
| CloudWatch Logs連携なし | 4.8監視設定の前提不足。別途連携設定が必要 |

取得する証跡:

- Trail詳細画面
- Management Event設定画面
- CloudWatch Logs連携設定画面

### 4.3 CloudTrail Event HistoryでS3バケットポリシー変更履歴を確認する

1. CloudTrailの左側メニューから `イベント履歴` または `Event history` を開く。
2. 検索条件を設定する。
3. まず `イベント名` または `Event name` で検索する。
4. 以下のイベントをそれぞれ確認する。

```text
PutBucketPolicy
DeleteBucketPolicy
```

確認する項目:

| 項目 | 見る内容 |
|---|---|
| イベント時刻 | いつ変更されたか |
| イベント名 | `PutBucketPolicy` または `DeleteBucketPolicy` か |
| ユーザー名/Role | 誰が実行したか |
| リソース名 | 対象S3バケット |
| 送信元IP | 操作元 |
| Event ID | 追跡用ID |

補足:

- 対象バケットが決まっている場合は、検索属性で `リソース名` を使って対象バケット名を検索する。
- Event Historyは監視設定そのものではなく、過去イベント確認に使う。

取得する証跡:

- `PutBucketPolicy` 検索結果
- `DeleteBucketPolicy` 検索結果
- 対象イベントの詳細画面

### 4.4 CloudWatch LogsでCloudTrailイベント配送を確認する

1. AWS Consoleの検索欄で `CloudWatch` を開く。
2. 左側メニューから `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先のLog Groupを開く。
4. Log Streamにイベントが届いているか確認する。
5. 可能であれば、ログイベントを検索し、以下の文字列を確認する。

```text
PutBucketPolicy
DeleteBucketPolicy
```

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Log Group名 | CloudTrail連携先か |
| Log Group class | Standardか |
| Retention | 保持期間 |
| KMS | 暗号化キー |
| Log Stream | CloudTrailイベントが届いているか |
| eventName | `PutBucketPolicy` / `DeleteBucketPolicy` が検索可能か |

注意:

- Metric FilterはStandard log classのLog Groupで使用する。
- CloudTrailからCloudWatch Logsへの配送には遅延がある。

取得する証跡:

- Log Group一覧
- 対象Log Group詳細
- Log Stream一覧
- 該当イベント検索結果

### 4.5 既存Metric Filterを確認する

1. CloudWatchの `ロググループ` を開く。
2. CloudTrail連携先Log Groupを選択する。
3. `Metric filters` または `メトリクスフィルター` タブを開く。
4. S3バケットポリシー変更を検知するFilterがあるか確認する。

見るべき条件:

```text
eventSource = s3.amazonaws.com
eventName = PutBucketPolicy
eventName = DeleteBucketPolicy
```

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Filter name | S3ポリシー変更用と分かる名称か |
| Filter pattern | `PutBucketPolicy` / `DeleteBucketPolicy` を含むか |
| Metric namespace | 運用ルールに沿っているか |
| Metric name | Alarmから参照できる名称か |
| Metric value | 通常は `1` か |

判定:

| 状態 | 判断 |
|---|---|
| 既存Filterあり | Alarmと通知先を確認する |
| 既存Filterなし | 4.8の監視設定が不足している可能性 |
| 類似Filterあり | 対象イベントと通知先を確認し、重複作成を避ける |

取得する証跡:

- Metric Filter一覧
- 該当Filter詳細

### 4.6 既存CloudWatch Alarmを確認する

1. CloudWatchの左側メニューから `アラーム` -> `すべてのアラーム` を開く。
2. 4.8に関連するAlarmを検索する。
3. 該当Alarmがあれば詳細を開く。

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Alarm名 | 4.8用と分かる名称か |
| State | OK / ALARM / INSUFFICIENT_DATA |
| Metric | Metric FilterのMetricか |
| Statistic | Sum等 |
| Period | 評価期間 |
| Threshold | しきい値 |
| Actions enabled | 通知Actionが有効か |
| Alarm action | SNS等の通知先 |

判定:

| 状態 | 判断 |
|---|---|
| Alarmあり、Action有効 | 通知先と履歴を確認する |
| Alarmあり、Action無効 | 発報しないため要改善 |
| Alarmなし | 4.8の発報設定が不足している可能性 |

取得する証跡:

- Alarm一覧
- Alarm詳細
- Alarm Action設定

### 4.7 通知先を確認する

1. Alarm詳細の `通知` または `Actions` を確認する。
2. SNS Topic名または通知先を確認する。
3. AWS Consoleの検索欄で `SNS` を開く。
4. `Topics` を開く。
5. 該当Topicを選択する。
6. `Subscriptions` を確認する。

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Topic名 | 既存通知先か |
| Subscription | メール、チャット連携、監視基盤等 |
| Status | Confirmedか |
| Topic Policy | CloudWatch AlarmからPublishできるか |

取得する証跡:

- SNS Topic詳細
- Subscription一覧

注意:

- 通知先メールアドレスや個人情報が画面に出る場合は、証跡の取り扱いに注意する。

### 4.8 補足としてEventBridgeや既存監視製品を確認する

元要件の必須方式ではないが、重複通知を避けるため確認する。

1. AWS Consoleの検索欄で `EventBridge` を開く。
2. `Rules` を開く。
3. CloudTrailイベント、S3、GuardDuty等に関係するRuleがないか確認する。
4. 該当RuleがあればEvent PatternとTargetを確認する。

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Rule名 | S3変更監視に関係するか |
| Event pattern | `PutBucketPolicy` / `DeleteBucketPolicy` を拾うか |
| Target | SNS、Lambda、監視基盤等 |
| State | 有効か |

判定:

| 状態 | 判断 |
|---|---|
| 同等Ruleあり | CloudWatch Alarmを新規作成する前に重複確認 |
| Ruleなし | 元要件どおりCloudWatch Metric Filter/Alarm方式を検討 |

## 5. 調査結果のまとめ方

以下の表に整理する。

| 確認項目 | 結果 | 不足 | 対応方針 |
|---|---|---|---|
| CloudTrail Management Event | あり / なし | | |
| CloudWatch Logs連携 | あり / なし | | |
| PutBucketPolicy過去イベント | あり / なし | | |
| DeleteBucketPolicy過去イベント | あり / なし | | |
| Metric Filter | あり / なし | | |
| CloudWatch Alarm | あり / なし | | |
| 通知Action | 有効 / 無効 / なし | | |
| SNS Subscription | Confirmed / Pending / なし | | |
| EventBridge等の同等監視 | あり / なし | | |

## 6. 完了条件

調査完了条件は以下。

- CloudTrailが対象イベントを記録できる状態か判断できている
- CloudWatch Logs連携有無を確認できている
- 既存Metric FilterとAlarmの有無を確認できている
- 通知先の有無と状態を確認できている
- EventBridge等の同等監視有無を確認できている
- 不足している設定と次の作業方針を説明できる

## 7. 参考

- AWS CloudTrail: Sending events to CloudWatch Logs  
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
- Amazon CloudWatch Logs: Creating metrics from log events using filters  
  https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html

