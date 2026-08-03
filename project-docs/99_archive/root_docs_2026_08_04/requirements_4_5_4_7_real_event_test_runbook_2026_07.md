# 要件4.5/4.7 実イベント発生テスト手順書

作成日: 2026-07-22

対象:

| 要件 | 内容 | 実イベント |
| :--- | :--- | :--- |
| 4.5 | CloudTrail設定変更監視 | `UpdateTrail` |
| 4.7 | カスタマー管理KMSキーの無効化・削除予約監視 | `DisableKey`、任意で`ScheduleKeyDeletion` |

本資料は、要件4.5および4.7のMetric Filter / CloudWatch Alarm / SNS通知について、実際のAWSイベントを安全に発生させて確認するための手順である。  
本番Trailの停止、削除、本番利用中KMSキーの無効化、削除予約は実施しない。

## 1. 基本方針

### 1.1 安全な実イベントの考え方

| 要件 | 推奨する実イベント | 理由 |
| :--- | :--- | :--- |
| 4.5 | CloudTrailからCloudWatch Logsへの連携有効化に伴う`UpdateTrail` | 先行作業で必要となる設定変更自体が検知対象イベントになる |
| 4.7 | テスト専用カスタマー管理KMSキーの`DisableKey` | 使用中キーへ影響を与えず、`EnableKey`で戻せる |
| 4.7 | テスト専用カスタマー管理KMSキーの`ScheduleKeyDeletion` | 削除予約検知まで確認できるが、破壊的操作のため承認時のみ実施する |

### 1.2 実施しない操作

| 操作 | 理由 |
| :--- | :--- |
| 本番Trailの`StopLogging` | 監査ログ取得停止につながる |
| 本番Trailの`DeleteTrail` | 監査証跡喪失につながる |
| 本番Trailの不要な設定変更 | 監査設定の意図しない変更になる |
| 業務利用中KMSキーの`DisableKey` | 暗号化・復号、ログ配送、アプリケーション処理に影響する |
| 業務利用中KMSキーの`ScheduleKeyDeletion` | データ復号不能につながる可能性がある |

## 2. 事前条件

### 2.1 監視設定の事前作成

実イベント発生前に、以下を作成済みであることを確認する。

| 区分 | 4.5 | 4.7 |
| :--- | :--- | :--- |
| Metric Filter | CloudTrail設定変更検知用Filter | KMSキー無効化・削除予約検知用Filter |
| CloudWatch Alarm | 4.5用Alarm | 4.7用Alarm |
| Alarm Action | 既存SNS Topic | 既存SNS Topic |
| SNS Subscription | 通知先が有効 | 通知先が有効 |

### 2.2 既存SNS Topic確認

本手順では、既存SNS Topicを利用する前提とする。  
事前に以下を確認する。

| 確認 | 確認内容 |
| :--- | :--- |
| Topic ARN | パラメータシート、設計書、通知設計資料と一致すること |
| Subscription | `Confirmed`または有効状態であること |
| 通知先 | メール、Teams、A-gate等の到達先を把握していること |
| 受信確認者 | テスト通知の受信確認者が決まっていること |
| テスト可能時間 | 通知テストを実施してよい時間帯であること |
| 他用途共用 | 他チームへ不要通知が飛ぶ可能性を把握していること |

### 2.3 CloudTrailからCloudWatch Logsへの配送確認

4.5/4.7のMetric Filterは、CloudTrailイベントがCloudWatch Logsへ届いていることが前提である。

| 確認 | OK条件 |
| :--- | :--- |
| Trail | Management Eventを記録している |
| CloudWatch Logs連携 | Log GroupとIAM Roleが設定済み、または今回有効化する |
| Log Group | CloudTrailイベントJSONが到達する |
| KMS除外 | `kms.amazonaws.com`が管理イベント除外対象になっていない |

CloudTrailからCloudWatch Logsへのイベント配送は、通常数分待つ必要がある。  
CloudWatch Logs画面の表示時刻とCloudTrailイベント内の`eventTime`は意味が異なるため、イベント本文の`eventTime`も確認する。

## 3. 4.5 実イベントテスト: UpdateTrail

### 3.1 推奨シナリオ

CloudTrailからCloudWatch Logsへの連携が未設定の場合、連携を有効化する操作で`UpdateTrail`を発生させる。  
この`UpdateTrail`が4.5のMetric Filterに一致し、Alarmと通知につながることを確認する。

```text
CloudTrail連携設定変更
  -> UpdateTrailイベント発生
  -> CloudWatch Logsへ配送
  -> 4.5 Metric Filter一致
  -> 4.5 Metric発生
  -> 4.5 Alarm遷移
  -> 既存SNS Topicへ通知
```

### 3.2 変更前確認

1. AWS Management Consoleへログインする。
2. 対象アカウント、対象リージョンを確認する。
3. CloudTrailコンソールを開く。
4. 左メニューで`証跡`を開く。
5. 対象Trailを開く。
6. 以下を記録する。

| 確認項目 | 記録内容 |
| :--- | :--- |
| Trail名 | 対象Trail名 |
| Home Region | Trailのホームリージョン |
| ログ記録 | 有効であること |
| Multi-Region | 設計値と一致すること |
| Management Event | 有効であること |
| CloudWatch Logs Log Group | 変更前値 |
| CloudWatch Logs Role | 変更前値 |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 01 | Trail詳細変更前 | `01_req45_trail_before.png` |
| 02 | Event selectors変更前 | `02_req45_event_selectors_before.png` |

### 3.3 CloudWatch Logs連携有効化

CloudWatch Logs連携が未設定の場合のみ実施する。  
既に連携済みの場合、無理に無効化・再有効化しない。

1. 対象Trail詳細画面で`CloudWatch Logs`欄を確認する。
2. `編集`または`Edit`をクリックする。
3. `CloudWatch Logs`を有効化する。
4. Log Groupは、パラメータシートで指定されたLog Groupを選択する。
5. Log Groupが未作成の場合、承認済みの名称で新規作成する。
6. IAM Roleは、承認済みのCloudTrail配信用Roleを選択する。
7. Role欄が空の場合、保存前に作業を止めて確認する。
8. `Save changes`をクリックする。
9. 保存後、Trail詳細画面でCloudWatch Logs Log GroupとRoleが設定済みであることを確認する。

注意:

- デフォルトRoleとして`CloudTrail_CloudWatchLogs_Role`が使われる場合がある。
- 現場命名規則のRoleを使う場合、`CloudTrail_CloudWatchLogs_Role`の別名ではなく、別のIAM Roleとして扱う。
- RoleにはCloudTrailがCloudWatch Logsへ`CreateLogStream`、`PutLogEvents`できる権限が必要である。
- CloudTrailのCloudWatch Logs連携先Log Groupは、同一AWSアカウント内に存在する必要がある。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 03 | CloudWatch Logs連携設定画面 | `03_req45_cloudwatch_logs_setting.png` |
| 04 | Trail詳細変更後 | `04_req45_trail_after.png` |

### 3.4 UpdateTrailイベント確認

1. CloudTrailコンソールを開く。
2. 左メニューで`イベント履歴`を開く。
3. 検索属性で`イベント名`を選択する。
4. `UpdateTrail`で検索する。
5. 作業時刻の`UpdateTrail`が表示されることを確認する。
6. イベント詳細を開き、以下を確認する。

| フィールド | 確認内容 |
| :--- | :--- |
| `eventName` | `UpdateTrail` |
| `eventSource` | `cloudtrail.amazonaws.com` |
| `userIdentity` | 作業者または作業Role |
| `eventTime` | 作業時刻と一致 |
| `requestParameters` | CloudWatch Logs関連設定が含まれること |
| `errorCode` | ないこと |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 05 | CloudTrail Event historyのUpdateTrail | `05_req45_update_trail_event_history.png` |
| 06 | UpdateTrailイベント詳細 | `06_req45_update_trail_event_detail.png` |

### 3.5 CloudWatch Logs配送確認

1. CloudWatchコンソールを開く。
2. 左メニューで`ログ` -> `ロググループ`を開く。
3. CloudTrail連携先Log Groupを開く。
4. 直近のLog Streamを開く。
5. `UpdateTrail`イベントが届いていることを確認する。
6. イベント本文の`eventTime`、`eventName`、`userIdentity`を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 07 | CloudWatch LogsのUpdateTrail | `07_req45_update_trail_in_logs.png` |

### 3.6 Metric Filter / Alarm / 通知確認

1. CloudWatch Logsの対象Log Groupを開く。
2. `メトリクスフィルター`タブを開く。
3. 4.5用Metric Filterを開く。
4. Filter Patternが以下であることを確認する。

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

5. CloudWatchの`すべてのアラーム`を開く。
6. 4.5用Alarmを開く。
7. Alarm Historyで状態変化を確認する。
8. 既存SNS Topic経由の通知受信を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 08 | 4.5 Metric Filter確認 | `08_req45_metric_filter_after.png` |
| 09 | 4.5 Alarm履歴 | `09_req45_alarm_history.png` |
| 10 | 4.5通知受信 | `10_req45_notification_received.png` |

## 4. 4.5 実イベントテストができない場合

以下の場合は、4.5の実イベントテストを無理に実施しない。

| 状況 | 代替確認 |
| :--- | :--- |
| CloudWatch Logs連携が既に有効 | 既存設定を無理に変更せず、Pattern TestとSNS通知テストで代替する |
| 変更承認がない | 変更しない |
| 既存Topicへの通知テスト不可 | Alarm設定確認と通知先確認までに留める |
| CloudTrail変更が業務影響ありと判断された | 実イベントテスト対象外にする |

記録例:

```text
4.5実イベントテストは、対象Trailが既にCloudWatch Logs連携済みであり、追加のCloudTrail設定変更承認がないため未実施。
Metric Filter Pattern Test、Alarm設定確認、既存SNS Topic確認で代替確認とする。
```

## 5. 4.7 実イベントテスト: DisableKey

### 5.1 推奨シナリオ

テスト専用のカスタマー管理KMSキーを作成し、そのキーだけを一時的に無効化する。  
無効化後、4.7のMetric Filter、Alarm、通知を確認し、すぐに有効化へ戻す。

```text
テスト専用CMK作成
  -> DisableKey
  -> CloudTrailイベント発生
  -> CloudWatch Logsへ配送
  -> 4.7 Metric Filter一致
  -> 4.7 Alarm遷移
  -> 既存SNS Topicへ通知
  -> EnableKeyで復旧
```

### 5.2 テスト専用CMK作成

1. AWS Management Consoleへログインする。
2. 対象リージョンを確認する。
3. 検索欄で`KMS`を検索する。
4. `Key Management Service`を開く。
5. 左メニューで`カスタマー管理キー`を開く。
6. `キーの作成`をクリックする。
7. Key typeは`Symmetric`を選択する。
8. Key usageは`Encrypt and decrypt`を選択する。
9. Aliasに以下のような名称を入力する。

```text
alias/req47-rehearsal-disable-key-test
```

10. Descriptionに以下を入力する。

```text
Temporary CMK for REQ-4.7 DisableKey event test. Do not use for application data.
```

11. Key administratorsは作業に必要な最小限の管理者に限定する。
12. Key usersは原則設定しない。
13. Review画面で、業務サービスに紐づかないテスト専用キーであることを確認する。
14. `Finish`をクリックする。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 11 | テスト専用CMK作成後 | `11_req47_test_cmk_created.png` |
| 12 | テスト専用CMK Alias | `12_req47_test_cmk_alias.png` |

### 5.3 テスト専用CMKの使用状況確認

DisableKey実施前に、対象キーが業務利用されていないことを確認する。

| 確認 | OK条件 |
| :--- | :--- |
| Alias | テスト専用名である |
| 作成日時 | 今回のテスト用に作成した時刻である |
| Key users | 原則なし、またはテスト用利用者のみ |
| 関連サービス | S3、CloudTrail、RDS、EBS、Lambda等で使用していない |
| タグ | テスト用途であることが分かる |

業務利用有無が判断できないキーでは、DisableKeyを実施しない。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 13 | CMK使用状況確認 | `13_req47_test_cmk_usage_check.png` |

### 5.4 DisableKey実施

1. KMSコンソールでテスト専用CMKを開く。
2. Key ID、Alias、状態が対象と一致することを確認する。
3. チェックボックスで対象キーを選択する。
4. `キーアクション`または`Key actions`をクリックする。
5. `無効化`または`Disable`を選択する。
6. 確認ダイアログで、対象がテスト専用CMKであることを再確認する。
7. 無効化を実行する。
8. Key stateが`Disabled`になることを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 14 | DisableKey実施前確認 | `14_req47_before_disable_key.png` |
| 15 | DisableKey実施後 | `15_req47_after_disable_key.png` |

### 5.5 DisableKeyイベント確認

1. CloudTrailコンソールを開く。
2. 左メニューで`イベント履歴`を開く。
3. 検索属性で`イベント名`を選択する。
4. `DisableKey`で検索する。
5. 作業時刻の`DisableKey`が表示されることを確認する。
6. イベント詳細を開き、以下を確認する。

| フィールド | 確認内容 |
| :--- | :--- |
| `eventName` | `DisableKey` |
| `eventSource` | `kms.amazonaws.com` |
| `userIdentity` | 作業者または作業Role |
| `requestParameters.keyId` | テスト専用CMK |
| `errorCode` | ないこと |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 16 | CloudTrail Event historyのDisableKey | `16_req47_disable_key_event_history.png` |
| 17 | DisableKeyイベント詳細 | `17_req47_disable_key_event_detail.png` |

### 5.6 CloudWatch Logs / Alarm / 通知確認

1. CloudWatch LogsのCloudTrail連携先Log Groupを開く。
2. 直近のLog Streamを開く。
3. `DisableKey`イベントが届いていることを確認する。
4. 4.7用Metric FilterのPatternを確認する。

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

5. CloudWatchの`すべてのアラーム`を開く。
6. 4.7用Alarmを開く。
7. Alarm Historyで状態変化を確認する。
8. 既存SNS Topic経由の通知受信を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 18 | CloudWatch LogsのDisableKey | `18_req47_disable_key_in_logs.png` |
| 19 | 4.7 Metric Filter確認 | `19_req47_metric_filter_after.png` |
| 20 | 4.7 Alarm履歴 | `20_req47_alarm_history.png` |
| 21 | 4.7通知受信 | `21_req47_notification_received.png` |

### 5.7 EnableKeyで復旧

DisableKey確認後、必ず同じテスト専用CMKを有効化する。

1. KMSコンソールでテスト専用CMKを開く。
2. 対象キーが`Disabled`であることを確認する。
3. チェックボックスで対象キーを選択する。
4. `キーアクション`または`Key actions`をクリックする。
5. `有効化`または`Enable`を選択する。
6. Key stateが`Enabled`になることを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 22 | EnableKey実施後 | `22_req47_after_enable_key.png` |

## 6. 任意: 4.7 ScheduleKeyDeletion実イベントテスト

`ScheduleKeyDeletion`は削除予約であり、AWS公式ドキュメントでも破壊的で潜在的に危険な操作として扱われる。  
このテストは、テスト専用CMKであり、かつ事前承認がある場合のみ実施する。

### 6.1 実施条件

| 条件 | 内容 |
| :--- | :--- |
| 対象キー | 今回作成したテスト専用CMKのみ |
| 業務利用 | なし |
| 承認 | リーダー、PM、必要に応じてインフラ/IAM担当の承認あり |
| 待機期間 | 最小の7日を使用する |
| キャンセル | イベント確認後、即時`CancelKeyDeletion`を実施する |

### 6.2 ScheduleKeyDeletion実施

1. KMSコンソールでテスト専用CMKを開く。
2. 対象キーのAliasとKey IDを確認する。
3. `キーアクション`または`Key actions`をクリックする。
4. `キーの削除をスケジュール`または`Schedule key deletion`を選択する。
5. 待機期間を`7`日に設定する。
6. 画面の警告を確認する。
7. 対象がテスト専用CMKであることを再確認する。
8. 削除予約を実行する。
9. Key stateが`Pending deletion`になることを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 23 | ScheduleKeyDeletion実施前確認 | `23_req47_before_schedule_key_deletion.png` |
| 24 | ScheduleKeyDeletion実施後 | `24_req47_after_schedule_key_deletion.png` |

### 6.3 ScheduleKeyDeletionイベント確認

1. CloudTrailコンソールを開く。
2. イベント履歴で`ScheduleKeyDeletion`を検索する。
3. 作業時刻のイベントを開く。
4. `eventSource`が`kms.amazonaws.com`であることを確認する。
5. 対象Key IDがテスト専用CMKであることを確認する。
6. CloudWatch Logs、4.7 Alarm、通知受信を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 25 | CloudTrail Event historyのScheduleKeyDeletion | `25_req47_schedule_key_deletion_event_history.png` |
| 26 | 4.7 Alarm履歴 | `26_req47_schedule_key_deletion_alarm_history.png` |
| 27 | 4.7通知受信 | `27_req47_schedule_key_deletion_notification_received.png` |

### 6.4 CancelKeyDeletionで戻す

1. KMSコンソールでテスト専用CMKを開く。
2. Key stateが`Pending deletion`であることを確認する。
3. `キーアクション`または`Key actions`をクリックする。
4. `キー削除をキャンセル`または`Cancel key deletion`を選択する。
5. 実行後、Key stateが`Disabled`になることを確認する。
6. 必要に応じて`EnableKey`で`Enabled`へ戻す。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 28 | CancelKeyDeletion実施後 | `28_req47_after_cancel_key_deletion.png` |
| 29 | EnableKey再実施後 | `29_req47_after_re_enable_key.png` |

## 7. 実イベントテスト後の確認

### 7.1 共通確認

| 確認 | OK条件 |
| :--- | :--- |
| CloudTrail Event history | `UpdateTrail`、`DisableKey`等が確認できる |
| CloudWatch Logs | 対象イベントJSONが連携先Log Groupに届いている |
| Metric Filter | Patternが対象イベントに一致している |
| CloudWatch Alarm | 状態変化または履歴を確認できる |
| SNS通知 | 既存Topic経由で通知受信を確認できる |
| 切り戻し | 変更した設定やキー状態が想定どおり戻っている |

### 7.2 通知が届かない場合

| 観点 | 確認内容 |
| :--- | :--- |
| SNS Topic | Alarm Actionに正しいTopic ARNが設定されているか |
| Subscription | 通知先がConfirmedまたは有効状態か |
| Alarm Action | Actions enabledが有効か |
| Metric | 対象MetricにDatapointが発生しているか |
| Filter Pattern | 実イベントJSONに一致するPatternか |
| CloudWatch Logs | CloudTrailイベントがLog Groupへ届いているか |
| CloudTrail | 対象イベントがCloudTrailに記録されているか |
| 待機時間 | CloudTrailからCloudWatch Logsへの配送、Metric、Alarm評価に数分待っているか |

## 8. 切り戻し

### 8.1 4.5

CloudTrailからCloudWatch Logs連携を今回新規に有効化した場合、残置するか戻すかを事前判断に従って処理する。

| 方針 | 対応 |
| :--- | :--- |
| 残置 | Trail詳細で連携先Log GroupとRoleを記録する |
| 切り戻し | CloudWatch Logs連携欄を変更前値に戻す |

4.5の監視設定そのものを残すか削除するかは、開発環境設定テストの方針に従う。

### 8.2 4.7

テスト専用CMKは、以下のいずれかで処理する。

| 方針 | 対応 |
| :--- | :--- |
| 再利用 | `Enabled`状態で残置し、テスト専用タグを付ける |
| 削除予定 | 承認後、`ScheduleKeyDeletion`を設定する |
| 即時削除 | KMSキーは即時削除できないため不可 |

テスト専用CMKを残す場合、不要なコストと混乱を避けるため、用途、作成日、削除予定を記録する。

## 9. 完了報告テンプレート

```text
対象環境:
対象AWSアカウント:
対象リージョン:

REQ-4.5:
実イベント:
発生時刻:
CloudTrail確認:
CloudWatch Logs確認:
Alarm確認:
通知確認:
切り戻し:

REQ-4.7:
実イベント:
対象テストCMK:
発生時刻:
CloudTrail確認:
CloudWatch Logs確認:
Alarm確認:
通知確認:
復旧操作:

未実施項目:
未実施理由:
証跡保存先:
残課題:
```

## 10. 公式ドキュメント

- [CloudTrail: CloudWatch Logsへのイベントの送信](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html)
- [CloudTrail: 証跡の使用](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-trails.html)
- [CloudTrail: CloudTrailコンソールで証跡を更新する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-update-a-trail-console.html)
- [AWS KMS: キーの有効化と無効化](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/enabling-keys.html)
- [AWS KMS: キーを削除する](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys.html)
- [AWS KMS: キー削除をスケジュールする](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html)
