# ラボシステム 要件4.5/4.7 Webコンソール予行練習手順書

作成日: 2026-07-20

対象リポジトリ: `aws-reference`

対象システム: `docs/design/Design_Specification.md` に記載されたAWS Webアプリケーション基盤

対象要件:

| 要件 | 内容 | 予行練習で確認すること |
| :--- | :--- | :--- |
| 4.5 | CloudTrail設定変更監視 | CloudTrail設定変更イベントをCloudWatch Logs Metric Filterで検知する設定を作成する |
| 4.7 | カスタマー管理KMSキーの無効化・削除予約監視 | KMS危険操作イベントをCloudWatch Logs Metric Filterで検知する設定を作成する |

本手順は、現場作業前にラボ環境で操作感、証跡取得、通知確認、切り戻しを予行練習するための手順である。  
作業は原則AWS Webコンソールで実施する。

## 1. 予行練習の目的

この予行練習の目的は、アプリケーションそのものの疎通確認ではない。  
目的は、CloudTrailイベントをCloudWatch Logsへ連携し、Metric Filterで検知対象イベントをメトリクス化し、CloudWatch AlarmからSNS通知へつなげる一連の作業を確認することである。

```text
CloudTrail
  -> CloudWatch Logs
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS Topic
  -> Email
```

## 2. この手順で作成するもの

| 種別 | 名称例 | 備考 |
| :--- | :--- | :--- |
| SNS Topic | `nobu-iac-lab-security-monitoring-rehearsal` | 予行練習用。既存通知先を使わない |
| SNS Subscription | 作業者メールアドレス | メール確認が必要 |
| Metric Namespace | `NobuIacLab/Rehearsal/SecurityMonitoring` | 予行練習用Namespace |
| REQ-4.5 Metric Filter | `nobu-iac-lab-rehearsal-req45-cloudtrail-change` | CloudTrail設定変更検知 |
| REQ-4.5 Metric Name | `Req45CloudTrailChangeCount` | Count用途 |
| REQ-4.5 Alarm | `nobu-iac-lab-rehearsal-req45-cloudtrail-change-alarm` | 予行練習用Alarm |
| REQ-4.7 Metric Filter | `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion` | KMSキー無効化・削除予約検知 |
| REQ-4.7 Metric Name | `Req47KmsKeyDisableOrDeletionCount` | Count用途 |
| REQ-4.7 Alarm | `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion-alarm` | 予行練習用Alarm |

CloudTrailからCloudWatch Logsへの連携が未設定の場合、CloudTrail側にCloudWatch Logs連携を追加する。  
この設定はTrail自体の設定変更であるため、変更前の値を必ず記録する。

## 3. 予行練習の前提

### 3.1 ラボシステム起動

必要に応じて、以下のラボ構成を起動しておく。

| 作業 | 目的 |
| :--- | :--- |
| `All_Setup.sh` | VPC、EC2、ALB、RDS、S3等のラボ基盤を作成する |
| `run_site_local.sh` | Webサーバ内部設定をAnsibleで反映する |

ただし、4.5/4.7の練習だけなら、ALB、RDS、Redis、Railsアプリは必須ではない。  
必須なのは、CloudTrail、CloudWatch Logs、CloudWatch Alarm、SNSを操作できることである。

### 3.2 事前確認

| 確認項目 | 確認内容 |
| :--- | :--- |
| AWSアカウント | ラボ用アカウントであること |
| リージョン | `ap-northeast-1` を使用すること |
| Trail | `nobu-iac-lab-trail` 等、ラボ用Trailを使用すること |
| Log Group | CloudTrail連携先Log Groupを確認すること |
| 既存設定 | 同名のMetric Filter、Alarm、SNS Topicがないこと |
| 通知先 | 作業者が確認できるメールアドレスを使用すること |

### 3.3 実施しないこと

| 操作 | 理由 |
| :--- | :--- |
| 本番Trailの停止 | 監査ログ取得停止につながる |
| 本番Trailの削除 | 監査証跡喪失につながる |
| アプリで使用中のKMSキーの無効化 | 暗号化済みデータやサービス利用に影響する |
| アプリで使用中のKMSキーの削除予約 | 復旧困難な影響が出る可能性がある |
| 既存SNS Topicの削除 | 他用途通知を壊す可能性がある |
| 既存Metric Filter / Alarmの削除 | 既存監視を壊す可能性がある |

## 4. 設定値

予行練習前に以下を埋める。

| 項目 | 値 |
| :--- | :--- |
| AWSアカウント | `<lab-account>` |
| リージョン | `ap-northeast-1` |
| Trail名 | `nobu-iac-lab-trail` |
| CloudTrail連携Log Group | `<cloudtrail-log-group-name>` |
| CloudTrail連携IAM Role | `<cloudtrail-cloudwatch-logs-role-name>` |
| SNS Topic名 | `nobu-iac-lab-security-monitoring-rehearsal` |
| SNS通知先メール | `<your-mail-address>` |
| Metric Namespace | `NobuIacLab/Rehearsal/SecurityMonitoring` |
| REQ-4.5 Filter名 | `nobu-iac-lab-rehearsal-req45-cloudtrail-change` |
| REQ-4.5 Alarm名 | `nobu-iac-lab-rehearsal-req45-cloudtrail-change-alarm` |
| REQ-4.7 Filter名 | `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion` |
| REQ-4.7 Alarm名 | `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion-alarm` |

## 5. SNS Topic作成

### 5.1 Topic作成

1. AWS Management Consoleへログインする。
2. 画面右上でリージョンが `ap-northeast-1` であることを確認する。
3. 検索欄に `SNS` と入力する。
4. `Simple Notification Service` を開く。
5. 左メニューで `トピック` または `Topics` をクリックする。
6. `トピックの作成` または `Create topic` をクリックする。
7. Typeは `Standard` を選択する。
8. Nameに以下を入力する。

```text
nobu-iac-lab-security-monitoring-rehearsal
```

9. Display nameは任意とする。入力する場合は以下を使用する。

```text
nobu-iac-lab-rehearsal
```

10. 暗号化、アクセスポリシー、配信ステータスログはデフォルトのままとする。
11. `Create topic` をクリックする。
12. 作成後、Topic ARNを記録する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 01 | SNS Topic作成後の詳細画面 | `01_sns_topic_created.png` |

### 5.2 Email Subscription作成

1. 作成したSNS Topicを開く。
2. `サブスクリプションの作成` または `Create subscription` をクリックする。
3. Protocolで `Email` を選択する。
4. Endpointに作業者のメールアドレスを入力する。
5. `Create subscription` をクリックする。
6. 登録したメールアドレスに届く確認メールを開く。
7. `Confirm subscription` をクリックする。
8. SNS Topic画面に戻り、SubscriptionのStatusが `Confirmed` になっていることを確認する。

注意:

- メールアドレスは公開用証跡ではマスクする。
- `Pending confirmation` のままでは通知されない。
- 迷惑メールフォルダも確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 02 | Subscription作成後 | `02_sns_subscription_pending.png` |
| 03 | Subscription Confirmed | `03_sns_subscription_confirmed.png` |

### 5.3 SNS単体通知テスト

1. SNS Topic詳細画面を開く。
2. `メッセージの発行` または `Publish message` をクリックする。
3. Subjectに以下を入力する。

```text
rehearsal notification test
```

4. Message bodyに以下を入力する。

```text
This is a rehearsal notification for REQ-4.5 and REQ-4.7.
```

5. `Publish message` をクリックする。
6. メールで通知を受信できることを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 04 | SNS Publish画面 | `04_sns_publish_test.png` |
| 05 | メール受信結果 | `05_sns_mail_received.png` |

## 6. CloudTrailからCloudWatch Logsへの連携確認

### 6.1 Trail確認

1. 検索欄に `CloudTrail` と入力する。
2. `CloudTrail` を開く。
3. 左メニューで `証跡` または `Trails` をクリックする。
4. ラボ用Trailをクリックする。
5. 以下を確認する。

| 確認項目 | 期待値 |
| :--- | :--- |
| Trail名 | ラボ用Trail |
| ログ記録 | 有効 |
| Management events | 有効 |
| CloudWatch Logs | 有効、または予行練習で有効化予定 |
| CloudWatch Logs Log Group | ラボ用Log Group |
| IAM Role | CloudTrail配信用Role |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 06 | Trail詳細変更前 | `06_cloudtrail_trail_before.png` |

### 6.2 CloudWatch Logs連携が未設定の場合

CloudWatch Logs連携が未設定の場合のみ実施する。  
既に連携済みの場合、この章は確認だけで終了する。

1. Trail詳細画面で `CloudWatch Logs` セクションを確認する。
2. `編集` または `Edit` をクリックする。
3. `CloudWatch Logs` を `Enabled` にする。
4. Log Groupは `New` または `Existing` を選択する。
5. 予行練習では、既存のラボ用Log Groupがある場合は `Existing` を使用する。
6. 既存Log Groupがない場合は、以下のようなラボ用名で新規作成する。

```text
/nobu-iac-lab/cloudtrail/management-events-rehearsal
```

7. IAM Roleは `New` または `Existing` を選択する。
8. デフォルト表示がある場合は `CloudTrail_CloudWatchLogs_Role` を使用する。
9. 既存Roleを使用する場合、CloudTrailがCloudWatch Logsへ書き込めるRoleであることを確認する。
10. `Save changes` をクリックする。
11. 保存後、Trail詳細で以下を確認する。

| 確認項目 | 期待値 |
| :--- | :--- |
| CloudWatch Logs Log Group | 設定済み |
| CloudWatch Logs Role | 設定済み |
| Trail logging | 有効 |

注意:

- CloudTrailからCloudWatch Logsへ送信されるイベントは、Trail設定に一致するイベントのみである。
- Multi-Region Trailでは、全有効リージョンのイベントが指定Log Groupへ送られる。
- CloudWatch Logs連携先Log Groupは同一アカウント内である必要がある。
- 連携後、CloudWatch Logsへの配送には数分かかることがある。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 07 | CloudWatch Logs連携設定画面 | `07_cloudtrail_cloudwatch_logs_setting.png` |
| 08 | Trail詳細変更後 | `08_cloudtrail_trail_after.png` |

### 6.3 Log GroupでCloudTrailイベント確認

1. 検索欄に `CloudWatch` と入力する。
2. `CloudWatch` を開く。
3. 左メニューで `ログ` -> `ロググループ` をクリックする。
4. CloudTrail連携先Log Groupを開く。
5. `ログストリーム` タブを開く。
6. 直近のLog Streamを開く。
7. CloudTrailイベントJSONが表示されることを確認する。
8. イベント本文に以下が含まれることを確認する。

| フィールド | 例 |
| :--- | :--- |
| `eventSource` | `cloudtrail.amazonaws.com`, `signin.amazonaws.com`, `kms.amazonaws.com`等 |
| `eventName` | API名 |
| `eventTime` | CloudTrail上のイベント時刻 |
| `userIdentity` | 実行主体 |
| `sourceIPAddress` | 接続元 |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 09 | Log Group詳細 | `09_log_group_detail.png` |
| 10 | CloudTrailイベント表示 | `10_cloudtrail_event_in_log_group.png` |

## 7. REQ-4.5 Metric Filter作成

### 7.1 Filter Pattern

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

### 7.2 作成手順

1. CloudWatchコンソールを開く。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. CloudTrail連携先Log Groupを開く。
4. `メトリクスフィルター` タブを開く。
5. 同名または同等条件のMetric Filterがないことを確認する。
6. `メトリクスフィルターを作成` または `Create metric filter` をクリックする。
7. Filter patternに7.1のPatternを入力する。
8. Test pattern欄に以下のJSONを1行で入力する。

```json
{"eventSource":"cloudtrail.amazonaws.com","eventName":"UpdateTrail","responseElements":{}}
```

9. Pattern Testを実行する。
10. 一致することを確認する。
11. `Next` をクリックする。
12. Filter nameに以下を入力する。

```text
nobu-iac-lab-rehearsal-req45-cloudtrail-change
```

13. Metric namespaceに以下を入力する。

```text
NobuIacLab/Rehearsal/SecurityMonitoring
```

14. Metric nameに以下を入力する。

```text
Req45CloudTrailChangeCount
```

15. Metric valueに `1` を入力する。
16. Default valueに `0` を入力する。
17. Unitは指定しない。
18. Dimensionは設定しない。
19. `Create metric filter` をクリックする。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 11 | REQ-4.5 Pattern Test | `11_req45_pattern_test.png` |
| 12 | REQ-4.5 Metric設定 | `12_req45_metric_setting.png` |
| 13 | REQ-4.5 Filter作成後 | `13_req45_filter_created.png` |

## 8. REQ-4.7 Metric Filter作成

### 8.1 Filter Pattern

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

### 8.2 作成手順

1. CloudWatchコンソールを開く。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. CloudTrail連携先Log Groupを開く。
4. `メトリクスフィルター` タブを開く。
5. 同名または同等条件のMetric Filterがないことを確認する。
6. `メトリクスフィルターを作成` または `Create metric filter` をクリックする。
7. Filter patternに8.1のPatternを入力する。
8. Test pattern欄に以下のJSONを1行で入力する。

```json
{"eventSource":"kms.amazonaws.com","eventName":"DisableKey","responseElements":{}}
```

9. Pattern Testを実行する。
10. 一致することを確認する。
11. 追加で以下のJSONを1行で入力し、`ScheduleKeyDeletion` も一致することを確認する。

```json
{"eventSource":"kms.amazonaws.com","eventName":"ScheduleKeyDeletion","responseElements":{}}
```

12. `Next` をクリックする。
13. Filter nameに以下を入力する。

```text
nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion
```

14. Metric namespaceに以下を入力する。

```text
NobuIacLab/Rehearsal/SecurityMonitoring
```

15. Metric nameに以下を入力する。

```text
Req47KmsKeyDisableOrDeletionCount
```

16. Metric valueに `1` を入力する。
17. Default valueに `0` を入力する。
18. Unitは指定しない。
19. Dimensionは設定しない。
20. `Create metric filter` をクリックする。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 14 | REQ-4.7 DisableKey Pattern Test | `14_req47_disable_key_pattern_test.png` |
| 15 | REQ-4.7 ScheduleKeyDeletion Pattern Test | `15_req47_schedule_key_deletion_pattern_test.png` |
| 16 | REQ-4.7 Metric設定 | `16_req47_metric_setting.png` |
| 17 | REQ-4.7 Filter作成後 | `17_req47_filter_created.png` |

## 9. REQ-4.5 CloudWatch Alarm作成

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. `アラームの作成` または `Create alarm` をクリックする。
4. `メトリクスの選択` または `Select metric` をクリックする。
5. Namespaceから `NobuIacLab/Rehearsal/SecurityMonitoring` を選択する。
6. `Req45CloudTrailChangeCount` を選択する。
7. Statisticを `Sum` にする。
8. Periodを `5 minutes` にする。
9. Threshold typeは `Static` を選択する。
10. 条件は `Greater/Equal`、しきい値は `1` にする。
11. Datapoints to alarmを `1 out of 1` にする。
12. Missing data treatmentを `Treat missing data as not breaching` にする。
13. Notificationは `In alarm` を選択する。
14. SNS Topicに `nobu-iac-lab-security-monitoring-rehearsal` を指定する。
15. OK Action、Insufficient data Actionは設定しない。
16. Alarm nameに以下を入力する。

```text
nobu-iac-lab-rehearsal-req45-cloudtrail-change-alarm
```

17. Alarm descriptionに以下を入力する。

```text
Rehearsal alarm for REQ-4.5 CloudTrail configuration changes.
```

18. Previewで設定を確認する。
19. `Create alarm` をクリックする。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 18 | REQ-4.5 Alarm条件 | `18_req45_alarm_condition.png` |
| 19 | REQ-4.5 Alarm通知先 | `19_req45_alarm_notification.png` |
| 20 | REQ-4.5 Alarm作成後 | `20_req45_alarm_created.png` |

## 10. REQ-4.7 CloudWatch Alarm作成

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. `アラームの作成` または `Create alarm` をクリックする。
4. `メトリクスの選択` または `Select metric` をクリックする。
5. Namespaceから `NobuIacLab/Rehearsal/SecurityMonitoring` を選択する。
6. `Req47KmsKeyDisableOrDeletionCount` を選択する。
7. Statisticを `Sum` にする。
8. Periodを `5 minutes` にする。
9. Threshold typeは `Static` を選択する。
10. 条件は `Greater/Equal`、しきい値は `1` にする。
11. Datapoints to alarmを `1 out of 1` にする。
12. Missing data treatmentを `Treat missing data as not breaching` にする。
13. Notificationは `In alarm` を選択する。
14. SNS Topicに `nobu-iac-lab-security-monitoring-rehearsal` を指定する。
15. OK Action、Insufficient data Actionは設定しない。
16. Alarm nameに以下を入力する。

```text
nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion-alarm
```

17. Alarm descriptionに以下を入力する。

```text
Rehearsal alarm for REQ-4.7 KMS DisableKey or ScheduleKeyDeletion events.
```

18. Previewで設定を確認する。
19. `Create alarm` をクリックする。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 21 | REQ-4.7 Alarm条件 | `21_req47_alarm_condition.png` |
| 22 | REQ-4.7 Alarm通知先 | `22_req47_alarm_notification.png` |
| 23 | REQ-4.7 Alarm作成後 | `23_req47_alarm_created.png` |

## 11. 通知確認

### 11.1 Webコンソールだけで確認できること

Webコンソールだけで確実に確認できる範囲は以下である。

| 確認 | 方法 |
| :--- | :--- |
| SNS Topicからメールへ通知できるか | SNS Topicの`Publish message`で確認する |
| Metric FilterのPatternが一致するか | Metric Filter作成時の`Test pattern`で確認する |
| AlarmがSNS TopicをActionに持つか | Alarm詳細画面で確認する |
| Alarmの履歴が見えるか | Alarm詳細の`History`で確認する |

Webコンソールだけでは、Alarm Actionを任意のタイミングで強制発火する操作が難しい。  
Alarm Actionまで確実に通知確認する場合は、CLIの`set-alarm-state`を使うか、実イベントを発生させる必要がある。

### 11.2 SNS単体通知テスト

1. SNS Topic `nobu-iac-lab-security-monitoring-rehearsal` を開く。
2. `Publish message` をクリックする。
3. Subjectに以下を入力する。

```text
rehearsal alarm notification route test
```

4. Message bodyに以下を入力する。

```text
This message confirms that the rehearsal SNS topic can deliver notifications.
```

5. `Publish message` をクリックする。
6. メール受信を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 24 | SNS通知テスト送信 | `24_sns_publish_alarm_route_test.png` |
| 25 | SNS通知テスト受信 | `25_sns_alarm_route_mail_received.png` |

### 11.3 任意: Alarm Action通知まで確認する方法

本項はWebコンソール手順の範囲外である。  
Alarm Actionまで確実に確認したい場合にのみ、CLIで以下を実行する。

REQ-4.5:

```bash
aws cloudwatch set-alarm-state \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-rehearsal-req45-cloudtrail-change-alarm" \
  --state-value ALARM \
  --state-reason "Rehearsal notification test for REQ-4.5" \
  --no-cli-pager
```

REQ-4.7:

```bash
aws cloudwatch set-alarm-state \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion-alarm" \
  --state-value ALARM \
  --state-reason "Rehearsal notification test for REQ-4.7" \
  --no-cli-pager
```

確認後、CloudWatch Alarm詳細の`History`で状態変更を確認する。  
通知メールが届くことを確認する。

## 12. 実イベントテストの扱い

### 12.1 REQ-4.5

ラボ環境であっても、CloudTrailの停止や削除は行わない。  
REQ-4.5は、Metric FilterのTest pattern、Alarm設定、SNS通知テストで代替確認する。

追加で実イベントを確認する場合は、影響の小さいTrail設定変更のみを承認後に行う。  
例: CloudTrail -> CloudWatch Logs連携を今回新規に有効化した場合、その`UpdateTrail`イベントがCloudWatch Logsへ配送される可能性がある。

### 12.2 REQ-4.7

アプリケーションやCloudTrailログ暗号化で使用しているKMSキーでは、`DisableKey`や`ScheduleKeyDeletion`を実施しない。  
REQ-4.7は、Metric FilterのTest pattern、Alarm設定、SNS通知テストで代替確認する。

実イベント確認を行う場合の最低条件:

| 条件 | 内容 |
| :--- | :--- |
| 検証専用KMSキー | アプリ、S3、CloudTrail、RDS等で使用していないキー |
| 操作範囲 | `DisableKey`後にすぐ`EnableKey`で戻す |
| 削除予約 | 原則実施しない |
| 承認 | 事前承認を取る |

## 13. 作業後確認

1. CloudWatch Logsの対象Log Groupを開く。
2. `メトリクスフィルター` タブでREQ-4.5/REQ-4.7のFilterが存在することを確認する。
3. CloudWatchの`すべてのアラーム`を開く。
4. REQ-4.5/REQ-4.7のAlarmが存在することを確認する。
5. Alarm ActionにSNS Topicが設定されていることを確認する。
6. SNS TopicでSubscriptionがConfirmedであることを確認する。
7. CloudTrailイベント履歴で、以下のイベントを必要に応じて確認する。

```text
PutMetricFilter
PutMetricAlarm
CreateTopic
Subscribe
Publish
SetAlarmState
```

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 26 | Metric Filter最終確認 | `26_metric_filters_after.png` |
| 27 | Alarm最終確認 | `27_alarms_after.png` |
| 28 | SNS Topic最終確認 | `28_sns_topic_after.png` |
| 29 | CloudTrail変更履歴 | `29_cloudtrail_event_history.png` |

## 14. 後片付け

予行練習で作成したものだけ削除する。  
既存リソースは削除しない。

### 14.1 CloudWatch Alarm削除

1. CloudWatchコンソールを開く。
2. 左メニューで `アラーム` -> `すべてのアラーム` をクリックする。
3. `nobu-iac-lab-rehearsal-req45-cloudtrail-change-alarm` を選択する。
4. `アクション` -> `削除` をクリックする。
5. 削除を確認する。
6. `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion-alarm` も同様に削除する。

### 14.2 Metric Filter削除

1. CloudWatchコンソールを開く。
2. 左メニューで `ログ` -> `ロググループ` をクリックする。
3. CloudTrail連携先Log Groupを開く。
4. `メトリクスフィルター` タブを開く。
5. `nobu-iac-lab-rehearsal-req45-cloudtrail-change` を削除する。
6. `nobu-iac-lab-rehearsal-req47-kms-key-disable-or-deletion` を削除する。

### 14.3 SNS Topic削除

1. SNSコンソールを開く。
2. 左メニューで `トピック` をクリックする。
3. `nobu-iac-lab-security-monitoring-rehearsal` を選択する。
4. `削除` をクリックする。
5. 削除確認文字列が求められる場合は、画面表示に従って入力する。
6. Topicが削除されたことを確認する。

### 14.4 CloudTrail -> CloudWatch Logs連携の扱い

CloudTrail -> CloudWatch Logs連携を予行練習で新規に有効化した場合、残置するか戻すかを判断する。

| 方針 | 判断 |
| :--- | :--- |
| 残置 | 今後も4.5/4.7練習で使う場合 |
| 切り戻し | ラボ費用や設定差分を最小にしたい場合 |

切り戻す場合は、変更前に記録した値へ戻す。  
既存連携を誤って無効化しない。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- |
| 30 | 削除前 | `30_cleanup_before.png` |
| 31 | Alarm削除後 | `31_alarms_deleted.png` |
| 32 | Metric Filter削除後 | `32_metric_filters_deleted.png` |
| 33 | SNS Topic削除後 | `33_sns_topic_deleted.png` |

## 15. チェックリスト

| No. | 作業 | 結果 |
| :--- | :--- | :--- |
| 1 | AWSアカウントとリージョン確認 | 未実施 / OK / NG |
| 2 | SNS Topic作成 | 未実施 / OK / NG |
| 3 | Email Subscription Confirmed | 未実施 / OK / NG |
| 4 | SNS単体通知テスト | 未実施 / OK / NG |
| 5 | CloudTrail確認 | 未実施 / OK / NG |
| 6 | CloudTrail -> CloudWatch Logs連携確認 | 未実施 / OK / NG |
| 7 | CloudWatch LogsでCloudTrailイベント確認 | 未実施 / OK / NG |
| 8 | REQ-4.5 Metric Filter作成 | 未実施 / OK / NG |
| 9 | REQ-4.7 Metric Filter作成 | 未実施 / OK / NG |
| 10 | REQ-4.5 Alarm作成 | 未実施 / OK / NG |
| 11 | REQ-4.7 Alarm作成 | 未実施 / OK / NG |
| 12 | 通知経路確認 | 未実施 / OK / NG |
| 13 | CloudTrail変更履歴確認 | 未実施 / OK / NG |
| 14 | 後片付け | 未実施 / OK / NG |

## 16. 公式ドキュメント

- [CloudTrailイベントをCloudWatch Logsに送信する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html)
- [CloudTrailがCloudWatch Logsを使用するためのロールポリシー](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html)
- [ロググループのメトリクスフィルターを作成する](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/CreateMetricFilterProcedure.html)
- [フィルターを使用してログイベントからメトリクスを作成する](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
- [CloudWatchアラームを作成する](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/Create-Alarms.html)
- [Amazon SNSトピックを作成する](https://docs.aws.amazon.com/ja_jp/sns/latest/dg/sns-create-topic.html)
