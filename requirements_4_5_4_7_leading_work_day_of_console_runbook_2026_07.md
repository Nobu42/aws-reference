# 要件4.5 / 4.7 先行作業 当日Webコンソール作業手順書

作成日: 2026-07-17

対象: REQ-4.5 CloudTrail設定変更監視、REQ-4.7 KMSキー無効化・削除予約監視

対象環境: 検証環境

本手順は、当日作業で画面を見ながら実施するための手順である。

## 1. 当日使用する設定値

作業前に以下を埋める。

| 項目 | 値 |
| :--- | :--- |
| 対象AWSアカウント | `<account-name-or-id>` |
| 対象リージョン | `<region>` |
| 対象Trail名 | `<trail-name>` |
| CloudWatch Logs Log Group名 | `<log-group-name>` |
| 通知先SNS Topic | `<sns-topic-name-or-arn>` |
| REQ-4.5 Metric Filter名 | `<system>-security-4-5-cloudtrail-change` |
| REQ-4.5 Metric Namespace | `<system>/SecurityMonitoring` |
| REQ-4.5 Metric Name | `Req45CloudTrailChangeCount` |
| REQ-4.5 Alarm名 | `<system>-security-4-5-cloudtrail-change-alarm` |
| REQ-4.7 Metric Filter名 | `<system>-security-4-7-kms-key-disable-or-deletion` |
| REQ-4.7 Metric Namespace | `<system>/SecurityMonitoring` |
| REQ-4.7 Metric Name | `Req47KmsKeyDisableOrDeletionCount` |
| REQ-4.7 Alarm名 | `<system>-security-4-7-kms-key-disable-or-deletion-alarm` |
| 証跡保存先 | `<evidence-path>` |

## 2. Filter Pattern

REQ-4.5:

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

REQ-4.7:

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

## 3. 作業開始

1. 作業開始を関係者へ連絡する。
2. 作業日時、作業者、確認者、対象アカウント、対象リージョンを記録する。
3. 通知テストを行う場合は、通知先担当者へ事前連絡する。
4. 証跡保存先を開く。
5. 作業開始連絡の記録を保存する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 01 | 作業開始連絡 | `01_work_start_notice.png` |

## 4. ログイン、アカウント、リージョン確認

1. AWS Management Consoleへログインする。
2. 画面右上のアカウント表示を確認する。
3. 対象AWSアカウントと一致することを確認する。
4. 画面右上のリージョンを確認する。
5. 対象リージョンと一致することを確認する。
6. 一致しない場合は作業を中断する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 02 | アカウント、リージョン確認 | 画面右上のアカウント名、リージョン | `02_account_region.png` |

## 5. CloudTrail現状確認

1. 画面上部の検索欄に `CloudTrail` と入力する。
2. `CloudTrail` を選択する。
3. 左メニューで `証跡` または `Trails` をクリックする。
4. 対象Trail名をクリックする。
5. Trail詳細画面で、以下を確認する。

| 確認項目 | 期待値 |
| :--- | :--- |
| Trail名 | 対象Trail名と一致 |
| ログ記録 | 有効 |
| マルチリージョン証跡 | 現場設計値と一致 |
| CloudWatch Logs連携 | 有効 |
| CloudWatch Logs Log Group | 作業対象Log Groupと一致 |
| CloudWatch Logs Role | 設定あり |

6. `イベントセレクター` または `Event selectors` を開く。
7. Management eventsが記録対象であることを確認する。
8. KMS管理イベントが除外されていないことを確認する。
9. 対象Trailを誤っている場合は作業を中断する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 03 | Trail詳細 | Trail名、ログ記録状態、CloudWatch Logs連携先 | `03_cloudtrail_trail_detail.png` |
| 04 | Event selectors | Management events、KMS除外有無 | `04_cloudtrail_event_selectors.png` |

## 6. CloudWatch Logs現状確認

1. 画面上部の検索欄に `CloudWatch` と入力する。
2. `CloudWatch` を選択する。
3. 左メニューで `ログ` -> `ロググループ` をクリックする。
4. 検索欄に対象Log Group名を入力する。
5. 対象Log Groupをクリックする。
6. Log Group詳細で以下を確認する。

| 確認項目 | 期待値 |
| :--- | :--- |
| Log Group名 | 作業対象Log Groupと一致 |
| Log class | Standard |
| ログイベント | 直近のCloudTrailログが存在する |

7. `ログストリーム` タブを開く。
8. 直近のLog Streamが更新されていることを確認する。
9. `メトリクスフィルター` タブを開く。
10. REQ-4.5、REQ-4.7と同名または同等条件のMetric Filterがないことを確認する。
11. 同等設定がある場合は新規作成せず、リーダーへ確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 05 | Log Group詳細 | Log Group名、Log class | `05_log_group_detail.png` |
| 06 | Log Stream更新状況 | 直近Log Stream、更新日時 | `06_log_stream_latest.png` |
| 07 | Metric Filter変更前 | Metric filters一覧 | `07_metric_filters_before.png` |

## 7. 通知先SNS確認

1. 画面上部の検索欄に `SNS` と入力する。
2. `Simple Notification Service` を選択する。
3. 左メニューで `トピック` または `Topics` をクリックする。
4. 対象SNS Topicをクリックする。
5. Topic ARNが作業対象と一致することを確認する。
6. `サブスクリプション` または `Subscriptions` を確認する。
7. 通知先のステータスが `Confirmed` または有効状態であることを確認する。
8. 通知先メールアドレス、Webhook URL、内部宛先が表示される場合は、公開用証跡ではマスクする。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 08 | SNS Topic詳細 | Topic名、Topic ARN | `08_sns_topic_detail.png` |
| 09 | Subscription状態 | Subscription一覧、ステータス | `09_sns_subscriptions.png` |

## 8. REQ-4.5 Metric Filter作成

1. CloudWatchコンソールへ戻る。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. 対象Log Groupをクリックする。
4. `メトリクスフィルター` タブをクリックする。
5. `メトリクスフィルターを作成` または `Create metric filter` をクリックする。
6. `Filter pattern` に以下を入力する。

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

7. `Test pattern` にサンプルログを入力できる場合は、以下を1行で入力する。

```json
{"eventSource":"cloudtrail.amazonaws.com","eventName":"UpdateTrail","responseElements":{}}
```

8. Pattern Testを実行する。
9. 一致することを確認する。
10. `Next` をクリックする。
11. Metric Filter名を入力する。

```text
<system>-security-4-5-cloudtrail-change
```

12. Metric Namespaceを入力する。

```text
<system>/SecurityMonitoring
```

13. Metric Nameを入力する。

```text
Req45CloudTrailChangeCount
```

14. Metric Valueに `1` を入力する。
15. Default Valueに `0` を入力する。
16. Unitは指定しない。
17. Dimensionは設定しない。
18. `Create metric filter` をクリックする。
19. 作成後、Metric Filter一覧に作成したFilterが表示されることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 10 | REQ-4.5 Filter Pattern入力 | Filter pattern、Test pattern結果 | `10_req45_filter_pattern.png` |
| 11 | REQ-4.5 Metric設定 | Filter名、Namespace、Metric Name、Metric Value、Default Value | `11_req45_metric_setting.png` |
| 12 | REQ-4.5 Metric Filter作成後 | Metric filters一覧、作成したFilter | `12_req45_metric_filter_created.png` |

## 9. REQ-4.7 Metric Filter作成

1. CloudWatchコンソールで対象Log Groupを開いた状態にする。
2. `メトリクスフィルター` タブをクリックする。
3. `メトリクスフィルターを作成` または `Create metric filter` をクリックする。
4. `Filter pattern` に以下を入力する。

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

5. `Test pattern` にサンプルログを入力できる場合は、以下を1行で入力する。

```json
{"eventSource":"kms.amazonaws.com","eventName":"DisableKey","responseElements":{}}
```

6. Pattern Testを実行する。
7. 一致することを確認する。
8. `Next` をクリックする。
9. Metric Filter名を入力する。

```text
<system>-security-4-7-kms-key-disable-or-deletion
```

10. Metric Namespaceを入力する。

```text
<system>/SecurityMonitoring
```

11. Metric Nameを入力する。

```text
Req47KmsKeyDisableOrDeletionCount
```

12. Metric Valueに `1` を入力する。
13. Default Valueに `0` を入力する。
14. Unitは指定しない。
15. Dimensionは設定しない。
16. `Create metric filter` をクリックする。
17. 作成後、Metric Filter一覧に作成したFilterが表示されることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 13 | REQ-4.7 Filter Pattern入力 | Filter pattern、Test pattern結果 | `13_req47_filter_pattern.png` |
| 14 | REQ-4.7 Metric設定 | Filter名、Namespace、Metric Name、Metric Value、Default Value | `14_req47_metric_setting.png` |
| 15 | REQ-4.7 Metric Filter作成後 | Metric filters一覧、作成したFilter | `15_req47_metric_filter_created.png` |

## 10. REQ-4.5 Alarm作成

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. `アラームの作成` または `Create alarm` をクリックする。
4. `メトリクスの選択` または `Select metric` をクリックする。
5. `Browse` で作成したMetric Namespaceを選択する。
6. `Req45CloudTrailChangeCount` を選択する。
7. `Select metric` をクリックする。
8. Statisticを `Sum` にする。
9. Periodを `5 minutes` にする。
10. Threshold typeは `Static` を選択する。
11. 条件は `Greater/Equal`、しきい値は `1` にする。
12. `Additional configuration` を開く。
13. Datapoints to alarmを `1 out of 1` にする。
14. Missing data treatmentを `Treat missing data as not breaching` にする。
15. `Next` をクリックする。
16. Notificationで `In alarm` を選択する。
17. 通知先SNS Topicを選択する。
18. OK Action、Insufficient data Actionは設定しない。
19. `Next` をクリックする。
20. Alarm名を入力する。

```text
<system>-security-4-5-cloudtrail-change-alarm
```

21. Alarm説明を入力する。

```text
Detects REQ-4.5 CloudTrail configuration changes.
```

22. `Next` をクリックする。
23. Previewで設定内容を確認する。
24. `Create alarm` をクリックする。
25. 作成後、Alarm一覧に表示されることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 16 | REQ-4.5 Metric選択 | Namespace、Metric Name | `16_req45_alarm_metric.png` |
| 17 | REQ-4.5 Alarm条件 | Sum、5 minutes、>= 1、1 out of 1、notBreaching | `17_req45_alarm_condition.png` |
| 18 | REQ-4.5 Alarm通知 | In alarm、SNS Topic | `18_req45_alarm_notification.png` |
| 19 | REQ-4.5 Alarm作成後 | Alarm名、状態、Action | `19_req45_alarm_created.png` |

## 11. REQ-4.7 Alarm作成

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. `アラームの作成` または `Create alarm` をクリックする。
4. `メトリクスの選択` または `Select metric` をクリックする。
5. `Browse` で作成したMetric Namespaceを選択する。
6. `Req47KmsKeyDisableOrDeletionCount` を選択する。
7. `Select metric` をクリックする。
8. Statisticを `Sum` にする。
9. Periodを `5 minutes` にする。
10. Threshold typeは `Static` を選択する。
11. 条件は `Greater/Equal`、しきい値は `1` にする。
12. `Additional configuration` を開く。
13. Datapoints to alarmを `1 out of 1` にする。
14. Missing data treatmentを `Treat missing data as not breaching` にする。
15. `Next` をクリックする。
16. Notificationで `In alarm` を選択する。
17. 通知先SNS Topicを選択する。
18. OK Action、Insufficient data Actionは設定しない。
19. `Next` をクリックする。
20. Alarm名を入力する。

```text
<system>-security-4-7-kms-key-disable-or-deletion-alarm
```

21. Alarm説明を入力する。

```text
Detects REQ-4.7 KMS DisableKey or ScheduleKeyDeletion events.
```

22. `Next` をクリックする。
23. Previewで設定内容を確認する。
24. `Create alarm` をクリックする。
25. 作成後、Alarm一覧に表示されることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 20 | REQ-4.7 Metric選択 | Namespace、Metric Name | `20_req47_alarm_metric.png` |
| 21 | REQ-4.7 Alarm条件 | Sum、5 minutes、>= 1、1 out of 1、notBreaching | `21_req47_alarm_condition.png` |
| 22 | REQ-4.7 Alarm通知 | In alarm、SNS Topic | `22_req47_alarm_notification.png` |
| 23 | REQ-4.7 Alarm作成後 | Alarm名、状態、Action | `23_req47_alarm_created.png` |

## 12. SNS単体通知テスト

実施可否は当日承認に従う。

1. SNSコンソールを開く。
2. 左メニューで `トピック` または `Topics` をクリックする。
3. 対象SNS Topicをクリックする。
4. `メッセージの発行` または `Publish message` をクリックする。
5. Subjectに以下を入力する。

```text
REQ-4.5/4.7 notification test
```

6. Message bodyに以下を入力する。

```text
Notification test for REQ-4.5/REQ-4.7 leading work.
```

7. `Publish message` をクリックする。
8. 通知先で受信を確認する。
9. 受信時刻、受信者、通知先を記録する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 24 | SNS Publish画面 | Subject、Message、Topic | `24_sns_publish_test.png` |
| 25 | 通知受信結果 | 受信通知、受信時刻 | `25_notification_received.png` |

## 13. Alarm Action通知テスト

CloudWatch AlarmからSNS Actionが動くことを確認する場合は、AWS CLIの`set-alarm-state`を使用する。

Webコンソールのみで作業する場合、この手順は実施せず、SNS単体通知テストとAlarm設定確認で代替する。

REQ-4.5:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "<system>-security-4-5-cloudtrail-change-alarm" \
  --state-value ALARM \
  --state-reason "Notification test for REQ-4.5 leading work"
```

REQ-4.7:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "<system>-security-4-7-kms-key-disable-or-deletion-alarm" \
  --state-value ALARM \
  --state-reason "Notification test for REQ-4.7 leading work"
```

確認手順:

1. コマンド実行前に通知先へ連絡する。
2. コマンドを1回だけ実行する。
3. 通知先で受信を確認する。
4. CloudWatchコンソールを開く。
5. `アラーム` -> `すべてのアラーム` をクリックする。
6. 対象Alarmをクリックする。
7. `履歴` または `History` タブを開く。
8. `ALARM` への状態変更履歴を確認する。
9. Alarmが実状態へ戻ることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 26 | set-alarm-state実行結果 | コマンド結果または実行記録 | `26_set_alarm_state_result.png` |
| 27 | Alarm履歴 | ALARM状態変更履歴 | `27_alarm_history.png` |
| 28 | Alarm通知受信 | 通知本文、受信時刻 | `28_alarm_notification_received.png` |

## 14. 作業後確認

1. CloudWatchコンソールを開く。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. 対象Log Groupをクリックする。
4. `メトリクスフィルター` タブをクリックする。
5. REQ-4.5、REQ-4.7のMetric Filterが存在することを確認する。
6. それぞれのFilter Pattern、Namespace、Metric Name、Metric Value、Default Valueを確認する。
7. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
8. REQ-4.5、REQ-4.7のAlarmが存在することを確認する。
9. それぞれのAlarm条件を確認する。
10. Alarm Actionに対象SNS Topicが設定されていることを確認する。
11. 作業結果を記録する。

期待値:

| 項目 | 期待値 |
| :--- | :--- |
| REQ-4.5 Metric Filter | 作成済み |
| REQ-4.7 Metric Filter | 作成済み |
| REQ-4.5 Alarm | 作成済み |
| REQ-4.7 Alarm | 作成済み |
| Statistic | Sum |
| Period | 5 minutes |
| Threshold | >= 1 |
| Datapoints to alarm | 1 out of 1 |
| Missing data | notBreaching |
| Alarm Action | In alarmのみ通知設定あり |

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 29 | Metric Filter最終確認 | 4.5/4.7のMetric Filter一覧 | `29_metric_filters_after.png` |
| 30 | Alarm最終確認 | 4.5/4.7のAlarm一覧 | `30_alarms_after.png` |
| 31 | Alarm詳細確認 | 条件、通知Action | `31_alarm_detail_after.png` |

## 15. CloudTrail変更履歴確認

1. CloudTrailコンソールを開く。
2. 左メニューで `イベント履歴` または `Event history` をクリックする。
3. 検索条件で `イベント名` または `Event name` を選択する。
4. 以下を必要に応じて検索する。

```text
PutMetricFilter
PutMetricAlarm
SetAlarmState
Publish
```

5. 当日作業時刻のイベントがあることを確認する。
6. 作業対象アカウント、リージョン、実行ユーザーが想定どおりであることを確認する。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 32 | CloudTrailイベント履歴 | PutMetricFilter、PutMetricAlarm等 | `32_cloudtrail_event_history.png` |

## 16. 実イベントテスト

実イベントテストは承認がある場合のみ実施する。

原則実施しない操作:

| 要件 | 実施しない操作 |
| :--- | :--- |
| REQ-4.5 | 本番Trailの`StopLogging`、`DeleteTrail` |
| REQ-4.7 | 本番KMSキーの`DisableKey`、`ScheduleKeyDeletion` |
| REQ-4.7 | 実データを暗号化している検証環境KMSキーの`ScheduleKeyDeletion` |

実イベントテストを行わない場合:

1. Pattern Testを実施済みであることを確認する。
2. SNS単体通知テストまたはAlarm Action通知テストを実施済みであることを確認する。
3. 実イベントテスト未実施の理由を記録する。

記録例:

```text
実イベントテストは、CloudTrail停止およびKMSキー無効化の影響を避けるため未実施。
Filter Pattern Test、SNS通知テスト、Alarm設定確認で代替確認済み。
```

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 33 | 実イベントテスト判断 | 実施/未実施、理由、承認有無 | `33_real_event_test_decision.png` |

## 17. 異常時の切り戻し

切り戻しは、今回作成した設定のみを対象にする。

### 17.1 Alarm削除

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. 今回作成したREQ-4.5 Alarmを選択する。
4. `アクション` -> `削除` をクリックする。
5. 削除を確認する。
6. 今回作成したREQ-4.7 Alarmも同様に削除する。
7. 既存Alarmは削除しない。

### 17.2 Metric Filter削除

1. CloudWatchコンソールを開く。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. 対象Log Groupをクリックする。
4. `メトリクスフィルター` タブをクリックする。
5. 今回作成したREQ-4.5 Metric Filterを選択する。
6. `削除` をクリックする。
7. 削除を確認する。
8. 今回作成したREQ-4.7 Metric Filterも同様に削除する。
9. 既存Metric Filterは削除しない。

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 34 | 切り戻し前 | 削除対象Alarm、Metric Filter | `34_rollback_before.png` |
| 35 | 切り戻し後 | Alarm削除後、Metric Filter削除後 | `35_rollback_after.png` |

## 18. 作業完了

1. 作業結果を整理する。
2. 作成したMetric Filter名、Alarm名、通知先を記録する。
3. 通知テスト結果を記録する。
4. 未実施項目がある場合は理由を記録する。
5. 証跡ファイルが保存されていることを確認する。
6. 作業完了を関係者へ連絡する。

完了報告に記載する内容:

```text
対象環境:
対象アカウント:
対象リージョン:
対象Log Group:
作成したMetric Filter:
作成したAlarm:
通知先:
通知テスト結果:
実イベントテスト実施有無:
証跡保存先:
未解決事項:
```

取得する証跡:

| No. | 証跡 | スクショ箇所 | ファイル名例 |
| :--- | :--- | :--- | :--- |
| 36 | 作業完了連絡 | 完了報告、証跡保存先 | `36_work_complete_notice.png` |

## 19. 当日チェックリスト

| No. | 作業 | 結果 | 証跡 |
| :--- | :--- | :--- | :--- |
| 1 | 作業開始連絡 | 未実施 / OK / NG |  |
| 2 | アカウント、リージョン確認 | 未実施 / OK / NG |  |
| 3 | CloudTrail現状確認 | 未実施 / OK / NG |  |
| 4 | CloudWatch Logs現状確認 | 未実施 / OK / NG |  |
| 5 | SNS通知先確認 | 未実施 / OK / NG |  |
| 6 | REQ-4.5 Metric Filter作成 | 未実施 / OK / NG |  |
| 7 | REQ-4.7 Metric Filter作成 | 未実施 / OK / NG |  |
| 8 | REQ-4.5 Alarm作成 | 未実施 / OK / NG |  |
| 9 | REQ-4.7 Alarm作成 | 未実施 / OK / NG |  |
| 10 | SNS単体通知テスト | 未実施 / OK / NG |  |
| 11 | Alarm Action通知テスト | 未実施 / OK / NG |  |
| 12 | 作業後確認 | 未実施 / OK / NG |  |
| 13 | CloudTrail変更履歴確認 | 未実施 / OK / NG |  |
| 14 | 実イベントテスト判断記録 | 未実施 / OK / NG |  |
| 15 | 証跡保存確認 | 未実施 / OK / NG |  |
| 16 | 作業完了連絡 | 未実施 / OK / NG |  |
