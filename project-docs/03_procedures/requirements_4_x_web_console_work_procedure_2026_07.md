# 要件4番台 Webコンソール作業実施手順書

作成日: 2026-07-12

この手順書は、要件4.1〜4.15の監視設定をAWS Management Consoleで実施するための作業手順である。

正式な評価シート由来の情報を正とする。4.8は先行作業として扱うが、本手順では4番台全体に横展開する共通手順を整理する。

## 1. 作業目的

CloudTrailのManagement EventをCloudWatch Logsへ連携し、Metric Filter、CloudWatch Alarm、通知先を設定することで、要件4.1〜4.15の監視不足を是正する。

## 2. 作業対象

| 要件 | 作業対象 |
| :--- | :--- |
| 4.1 | 不正なAPI呼び出し |
| 4.2 | MFAなし管理コンソールサインイン |
| 4.3 | rootアカウント使用 |
| 4.4 | IAMポリシー変更 |
| 4.5 | CloudTrail設定変更 |
| 4.6 | AWS Management Console認証失敗 |
| 4.7 | CMK無効化または削除予約 |
| 4.8 | S3バケットポリシー変更 |
| 4.9 | AWS Config設定変更 |
| 4.10 | Security Group変更 |
| 4.11 | NACL変更 |
| 4.12 | Network Gateway変更 |
| 4.13 | Route Table変更 |
| 4.14 | VPC変更 |
| 4.15 | AWS Organizations変更 |

## 3. 作業前提

| 前提 | 内容 |
| :--- | :--- |
| CloudTrail | 対象Management Eventを記録している |
| CloudWatch Logs連携 | CloudTrailがCloudWatch Logsへ配信されている |
| Log Group | Metric Filter作成対象Log Groupが確定している |
| 通知先 | SNS / メール / Teams / 監視基盤のどれを使うか確定している |
| 既存EventBridge | 既存通知・別アカウント連携との重複を確認済み |
| 変更承認 | 作業対象、作業時間、通知テスト可否が承認済み |

## 4. 作業前確認

1. AWS Management Consoleへログインする。
2. 対象アカウントであることを確認する。
3. 対象リージョンを選択する。
4. CloudTrailを開く。
5. 対象Trailを開く。
6. Management Eventが有効であることを確認する。
7. CloudWatch Logs連携先Log Groupを確認する。
8. CloudWatchを開く。
9. 対象Log Groupを開く。
10. 最新のCloudTrailイベントが届いていることを確認する。

取得する証跡:

- 対象アカウント表示
- 対象リージョン表示
- Trail詳細
- CloudWatch Logs連携先
- Log Group詳細
- 最新Log Stream

## 5. 既存設定のバックアップ

作業前に以下の画面を証跡として保存する。

| 対象 | 証跡 |
| :--- | :--- |
| CloudTrail Trail詳細 | CloudWatch Logs連携、Management Event |
| CloudWatch Logs Log Group | Metric Filter一覧 |
| CloudWatch Alarm | 既存Alarm一覧 |
| SNS Topic | Topic一覧、Subscription一覧 |
| EventBridge Rule | 関連Rule一覧、Target |

目的:

- 作業前後比較
- 既存設定の上書き防止
- 切り戻し時の参照

## 6. Metric Filter作成

1. CloudWatchを開く。
2. `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. `メトリクスフィルター` を開く。
5. `メトリクスフィルターを作成` を選択する。
6. 対象要件のFilter Patternを入力する。
7. サンプルCloudTrailイベントでPatternをテストする。
8. 一致結果が想定どおりであることを確認する。
9. Filter名、Metric Namespace、Metric Name、Metric Valueを入力する。
10. 作成内容を確認して作成する。

入力値は `requirements_4_x_monitoring_parameter_design_2026_07.md` を参照する。

取得する証跡:

- 作成前Metric Filter一覧
- Filter Pattern入力画面
- Patternテスト結果
- 作成後Metric Filter詳細

注意:

- Metric Filterは作成後に到着したログからメトリクスを生成する。
- 過去ログを遡ってメトリクス化するものではない。
- Filter Patternが広すぎると通知過多になる。
- Dimensionを追加する場合、メトリクス数増加に注意する。

## 7. CloudWatch Alarm作成

1. CloudWatchを開く。
2. `アラーム` を開く。
3. `アラームの作成` を選択する。
4. Metric Filterで作成したMetricを選択する。
5. Statisticを`Sum`にする。
6. Periodを設計値に合わせる。
7. Thresholdを`1以上`にする。
8. Treat missing dataを`notBreaching`相当に設定する。
9. Alarm Actionに通知先SNS Topicを指定する。
10. Alarm名と説明を入力する。
11. 内容を確認して作成する。

推奨する説明文:

```text
Requirement <要件番号>. Detects <監視対象> based on CloudTrail events delivered to CloudWatch Logs.
```

取得する証跡:

- Alarm作成画面
- Metric選択画面
- Threshold設定画面
- Notification設定画面
- 作成後Alarm詳細

## 8. 通知先設定

通知先は、既存SNS Topicを使う場合と新規SNS Topicを作る場合で手順が異なる。

既存SNS Topicを使う場合:

1. SNS Topic名とARNを確認する。
2. Subscription一覧を確認する。
3. メール、Teams、監視基盤などの通知先を確認する。
4. 対象AlarmのActionにTopic ARNを指定する。

新規SNS Topicを作る場合:

1. SNSを開く。
2. Topicを作成する。
3. Subscriptionを追加する。
4. メール購読の場合はConfirm済みであることを確認する。
5. Teams連携の場合は既存方式に合わせる。
6. 通知テストの承認を得る。

取得する証跡:

- SNS Topic詳細
- Subscription一覧
- Alarm Action設定
- 通知テスト結果

## 9. 動作確認

動作確認は、承認された範囲で実施する。

確認方法:

| 方法 | 内容 | 注意 |
| :--- | :--- | :--- |
| Metric Filter Pattern Test | サンプルログで一致確認 | 実通知は飛ばない |
| 既存CloudTrailイベント検索 | 過去イベントでPattern妥当性確認 | Metricは過去分に生成されない |
| 承認済みテスト操作 | 実イベントを発生させる | 通知が飛ぶため承認必須 |
| Alarm状態確認 | AlarmがOK / ALARM / INSUFFICIENT_DATAになるか確認 | Missing data設定を確認 |
| 通知受信確認 | メール / Teams / 監視基盤で受信確認 | 宛先と文面を確認 |

作業直後にAlarmが`INSUFFICIENT_DATA`になる場合がある。欠損データの扱いが`notBreaching`であれば、一定時間後に`OK`へ遷移することを確認する。

## 10. 作業後確認

| 確認項目 | 期待結果 |
| :--- | :--- |
| Metric Filter | 対象要件分が作成されている |
| Metric | NamespaceとMetric Nameが設計値と一致している |
| Alarm | 対象Metricを参照している |
| Alarm Action | 通知先SNS Topicが設定されている |
| Alarm State | OKまたは想定状態である |
| SNS | Subscriptionが有効である |
| EventBridge | 既存Ruleと意図しない重複がない |
| 証跡 | 作業前後の画面が保存されている |

## 11. 切り戻し

切り戻しは、変更した設定を作業前状態へ戻す。

基本順序:

1. 作成したCloudWatch AlarmのActionを無効化する。
2. 作成したCloudWatch Alarmを削除する。
3. 作成したMetric Filterを削除する。
4. 新規SNS Topicを作成した場合、SubscriptionとTopicを削除する。
5. 既存SNS Topicを使った場合、追加したActionのみ戻す。
6. 作業前証跡と一致することを確認する。

注意:

- 既存Alarm、既存Metric Filter、既存SNS Topicを誤って削除しない。
- 通知先が他用途で使われている場合は削除しない。
- 切り戻し後もCloudTrailとCloudWatch Logs連携自体は維持する。

## 12. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 設定完了 | 対象要件のMetric FilterとAlarmが存在する |
| 通知完了 | 設計された通知先にAlarm Actionが設定されている |
| 試験完了 | Patternテストまたは承認済み通知テストが完了している |
| 証跡完了 | 作業前、作業後、テスト結果が保存されている |
| レビュー完了 | リーダーまたは関係者レビューが完了している |

