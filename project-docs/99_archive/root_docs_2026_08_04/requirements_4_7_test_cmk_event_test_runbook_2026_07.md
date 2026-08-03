# 要件4.7 テスト専用CMK 実イベントテスト手順書

作成日: 2026-07-23

対象要件: 4.7 カスタマー管理KMSキーの無効化・削除予約監視

本資料は、要件4.7のMetric Filter / CloudWatch Alarm / SNS通知について、テスト専用のカスタマー管理KMSキーを作成し、`DisableKey`および必要に応じて`ScheduleKeyDeletion`の実イベントを安全に発生させるための手順である。  
PM判断待ちの作業案として使用する。

## 1. 方針

### 1.1 テスト対象イベント

| イベント | 目的 | 実施方針 |
| :--- | :--- | :--- |
| `DisableKey` | KMSキー無効化検知の確認 | テスト専用CMKで実施し、確認後すぐ`EnableKey`で戻す |
| `ScheduleKeyDeletion` | KMSキー削除予約検知の確認 | PM承認がある場合のみ、テスト専用CMKで実施する |
| `CancelKeyDeletion` | 削除予約の取消確認 | 削除予約を戻す場合に実施する |
| `EnableKey` | 無効化状態からの復旧 | `DisableKey`確認後に実施する |

### 1.2 安全方針

| 方針 | 内容 |
| :--- | :--- |
| 業務利用中キーを触らない | S3、CloudTrail、RDS、EBS、Secrets Manager、アプリケーション等で使用中のKMSキーは対象外 |
| テスト専用CMKを作成する | 4.7実イベントテストだけに使用する |
| Key usersを付けない | 暗号化用途で使われない状態を保つ |
| AliasとTagで用途を明示する | 後から見てもテスト用と分かる状態にする |
| `DisableKey`後は即時`EnableKey`で戻す | 不要な無効化状態を残さない |
| 削除は即時ではなく削除予約である | AWS KMSキーは即時削除できず、7〜30日の待機期間が必要 |
| `ScheduleKeyDeletion`は承認時のみ | 削除予約は破壊的操作として扱う |

### 1.3 実施しない操作

| 操作 | 理由 |
| :--- | :--- |
| 業務利用中CMKの`DisableKey` | 復号、暗号化、ログ配送、アプリケーション処理へ影響する可能性がある |
| 業務利用中CMKの`ScheduleKeyDeletion` | データ復号不能につながる可能性がある |
| AWS managed keyの削除予約 | AWS managed keyやAWS owned keyは削除予約対象外 |
| テスト専用CMKの即時削除 | AWS KMSには即時削除操作がない |

### 1.4 CMK料金感

2026-07-23時点のAWS公式料金では、AWS KMSで作成したKMSキーは1キーあたり1 USD/月のキーストレージ料金が発生する。料金は時間単位で按分される。  
テスト専用CMKを1本だけ作成する場合、料金影響は主にこのキーストレージ料金である。

概算:

| 利用期間 | 概算料金 | 備考 |
| :--- | :--- | :--- |
| 1日だけ存在 | 約0.03 USD | 1 USD/月を30日換算した概算 |
| 7日間存在 | 約0.23 USD | `ScheduleKeyDeletion`の最小待機期間7日を想定 |
| 30日間存在 | 約1.00 USD | 1 CMKを1か月保持した場合 |

料金上の注意:

| 項目 | 料金観点 |
| :--- | :--- |
| テスト専用CMK作成 | カスタマー管理KMSキーとして1 USD/月の時間按分対象 |
| `DisableKey` | キーを無効化しても、キーが存在する限りキーストレージ料金は残る |
| `EnableKey` | 料金を止める操作ではなく、キーを再利用可能に戻す操作 |
| `ScheduleKeyDeletion` | 削除予約後も、待機期間中はキーが存在するため時間按分対象として見込む |
| `CancelKeyDeletion` | 削除予約を取消すため、キーが残り続ける。不要なら再度削除予約が必要 |
| 自動ローテーション | テスト専用CMKでは有効化しない。ローテーションは追加料金要因になる |
| KMS APIリクエスト | 20,000リクエスト/月の無料利用枠がある。今回のテスト程度のリクエスト数なら通常は小さい |
| CloudWatch / SNS | CloudWatch Logs、Metric、Alarm、SNS通知の料金はKMS料金とは別枠 |

PM判断向けの見方:

| テスト方針 | 料金感 | 判断 |
| :--- | :--- | :--- |
| `DisableKey`後すぐ`EnableKey`し、CMKを当日中に削除予約する | 7日待機分を含めても数十円相当の規模 | 料金面の懸念は小さい |
| `DisableKey`のみ確認し、CMKを再テスト用に残す | 残置期間に応じて最大1 USD/月程度 | 残置理由と削除予定日の記録が必要 |
| `ScheduleKeyDeletion`まで確認し、`CancelKeyDeletion`で戻す | キーを残す場合は残置期間分の料金が続く | 再テスト予定がなければ最終削除予約を検討 |

本手順の費用見積りでは、為替、税、CloudWatch、SNS、CloudTrail、既存アカウントのKMS無料利用枠消化状況は別途確認事項とする。

## 2. 事前条件

### 2.1 監視設定

実イベント発生前に、4.7の監視設定が作成済みであることを確認する。

| 項目 | 期待値 |
| :--- | :--- |
| CloudTrail | Management Eventを記録している |
| CloudWatch Logs連携 | CloudTrailイベントがLog Groupへ届く |
| KMS除外 | `kms.amazonaws.com`が除外されていない |
| 4.7 Metric Filter | KMSキー無効化・削除予約検知用Filterが存在する |
| 4.7 CloudWatch Alarm | 4.7用Alarmが存在する |
| Alarm Action | 既存SNS Topicが設定されている |
| SNS Subscription | 通知先が有効状態である |

4.7 Metric FilterのPattern例:

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

### 2.2 通知先確認

既存SNS Topicを利用する前提で、以下を確認する。

| 確認 | 内容 |
| :--- | :--- |
| Topic ARN | パラメータシート、通知設計資料、実環境の値が一致すること |
| 通知先 | メール、Teams、A-gate等の到達先が分かること |
| 受信確認者 | テスト通知を受信確認する担当者が決まっていること |
| テスト時間 | 通知テストを実施してよい時間帯であること |
| 連絡方法 | テスト前後に通知先へ連絡できること |

### 2.3 必要権限

作業者または作業Roleに以下の権限が必要となる。

| 区分 | 必要Action例 | 用途 |
| :--- | :--- | :--- |
| KMS参照 | `kms:ListKeys`, `kms:ListAliases`, `kms:DescribeKey`, `kms:ListResourceTags` | 既存キーとテストキー確認 |
| KMS作成 | `kms:CreateKey`, `kms:CreateAlias`, `kms:TagResource` | テスト専用CMK作成 |
| KMS無効化/有効化 | `kms:DisableKey`, `kms:EnableKey` | 4.7実イベント発生と復旧 |
| KMS削除予約 | `kms:ScheduleKeyDeletion` | 削除予約イベント発生 |
| KMS削除予約取消 | `kms:CancelKeyDeletion` | 削除予約を戻す |
| CloudTrail参照 | `cloudtrail:LookupEvents` | 実イベント確認 |
| CloudWatch Logs参照 | `logs:FilterLogEvents`, `logs:DescribeLogGroups`, `logs:DescribeLogStreams` | CloudTrailイベント到達確認 |
| CloudWatch参照 | `cloudwatch:DescribeAlarms`, `cloudwatch:DescribeAlarmHistory` | Alarm確認 |
| SNS参照 | `sns:GetTopicAttributes`, `sns:ListSubscriptionsByTopic` | 通知先確認 |

権限不足がある場合、テスト専用CMK作成、無効化、有効化、削除予約、削除予約取消のどこで止まるかを事前に確認する。

## 3. 使用する設定値

作業前に以下を埋める。

| 項目 | 値 |
| :--- | :--- |
| 対象AWSアカウント | `<account-name-or-id>` |
| 対象リージョン | `<region>` |
| CloudTrail連携Log Group | `<cloudtrail-log-group-name>` |
| 4.7 Metric Filter名 | `<req47-metric-filter-name>` |
| 4.7 Alarm名 | `<req47-alarm-name>` |
| 既存SNS Topic ARN | `<sns-topic-arn>` |
| 受信確認者 | `<receiver>` |
| テスト専用CMK Alias | `alias/req47-test-cmk-<yyyymmdd>` |
| テスト専用CMK Description | `Temporary CMK for REQ-4.7 KMS event test. Do not use for application data.` |
| 削除予約待機期間 | `7`日 |
| 証跡保存先 | `<evidence-path>` |

推奨タグ:

| Key | Value |
| :--- | :--- |
| `Purpose` | `REQ-4.7 event test` |
| `Owner` | `<team-or-user>` |
| `Environment` | `<dev-or-test>` |
| `DeleteAfter` | `<yyyy-mm-dd>` |
| `DoNotUseForApplication` | `true` |

## 4. 作業開始前確認

1. 作業開始を関係者へ連絡する。
2. 通知先担当者へ、4.7テスト通知が飛ぶ可能性を連絡する。
3. AWS Management Consoleへログインする。
4. 対象AWSアカウントと対象リージョンを確認する。
5. CloudWatchで4.7 Alarmを開き、Alarm Actionが既存SNS Topicであることを確認する。
6. SNS Topicを開き、Subscriptionが有効であることを確認する。
7. CloudTrailからCloudWatch Logsへイベントが届いていることを確認する。
8. KMSコンソールで既存キー一覧を開き、今回作成するAliasが既に存在しないことを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 01 | 作業開始連絡 | `01_work_start_notice.png` |
| 02 | アカウント・リージョン確認 | `02_account_region.png` |
| 03 | 4.7 Alarm変更前 | `03_req47_alarm_before.png` |
| 04 | SNS Topic / Subscription確認 | `04_sns_topic_subscription_before.png` |
| 05 | KMS Alias重複なし確認 | `05_kms_alias_before.png` |

## 5. テスト専用CMK作成

### 5.1 KMSコンソールを開く

1. AWS Management Consoleの検索欄に`KMS`と入力する。
2. `Key Management Service`を開く。
3. 画面右上のリージョンが対象リージョンであることを確認する。
4. 左メニューで`カスタマー管理キー`をクリックする。

### 5.2 キー作成

1. `キーの作成`をクリックする。
2. Key typeで`Symmetric`を選択する。
3. Key usageで`Encrypt and decrypt`を選択する。
4. `Next`をクリックする。
5. Aliasに以下を入力する。

```text
alias/req47-test-cmk-<yyyymmdd>
```

6. Descriptionに以下を入力する。

```text
Temporary CMK for REQ-4.7 KMS event test. Do not use for application data.
```

7. Tagsに3章の推奨タグを設定する。
8. `Next`をクリックする。
9. Key administratorsは作業に必要な最小限の管理者のみ選択する。
10. `Allow key administrators to delete this key`は、削除予約テストを行う場合のみ有効化する。
11. `Next`をクリックする。
12. Key usersは原則選択しない。
13. `Next`をクリックする。
14. Review画面で、Alias、Description、Tags、Key usersが想定どおりであることを確認する。
15. `Finish`をクリックする。

注意:

- Key usersを付けると、誤って暗号化用途に使われる可能性が上がる。
- 削除予約テストまで行う場合、作業者に`kms:ScheduleKeyDeletion`と`kms:CancelKeyDeletion`が必要である。
- 削除予約権限を管理者に与える場合は、テスト専用CMKだけに限定することが望ましい。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 06 | KMSキー作成 Alias/Description | `06_cmk_create_alias_description.png` |
| 07 | KMSキー作成 Key administrators | `07_cmk_key_administrators.png` |
| 08 | KMSキー作成 Key usersなし | `08_cmk_key_users_none.png` |
| 09 | テスト専用CMK作成後 | `09_cmk_created.png` |

## 6. テスト専用CMK使用状況確認

DisableKey前に、対象キーがテスト専用であり、業務利用されていないことを確認する。

1. KMSの`カスタマー管理キー`一覧を開く。
2. 作成したAliasをクリックする。
3. `General configuration`でKey ID、Alias、Description、状態を確認する。
4. `Key policy`または`Key users`を確認する。
5. Key usersが原則空であることを確認する。
6. Tagsで`DoNotUseForApplication=true`等が設定されていることを確認する。
7. 関連する設計書、パラメータシート、実環境画面で、このKey ID / Aliasが利用先に登録されていないことを確認する。

確認観点:

| 確認 | OK条件 |
| :--- | :--- |
| Alias | テスト専用名である |
| Description | テスト専用であり、業務利用禁止が明記されている |
| Key users | なし、またはテスト用作業者のみ |
| Tags | テスト用途と削除予定が分かる |
| 関連サービス | S3、CloudTrail、RDS、EBS、Secrets Manager、アプリケーションに紐づかない |
| 作成日時 | 今回の作業時刻である |

業務利用有無が判断できない場合、DisableKey以降を実施しない。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 10 | CMK詳細 | `10_cmk_detail_before_test.png` |
| 11 | CMK Key users確認 | `11_cmk_key_users_before_test.png` |
| 12 | CMK Tags確認 | `12_cmk_tags_before_test.png` |

## 7. DisableKey実イベントテスト

### 7.1 DisableKey実施前連絡

1. 通知先担当者へ、これから4.7の`DisableKey`テストを実施することを連絡する。
2. 実施時刻を記録する。
3. 対象CMK Alias、Key ID、対象アカウント、対象リージョンを記録する。

### 7.2 DisableKey実施

1. KMSコンソールでテスト専用CMKを開く。
2. 対象AliasとKey IDがテスト専用CMKであることを確認する。
3. キー一覧に戻る。
4. 対象CMKのチェックボックスを選択する。
5. `キーアクション`または`Key actions`をクリックする。
6. `無効化`または`Disable`をクリックする。
7. 確認ダイアログで対象AliasとKey IDを再確認する。
8. 無効化を実行する。
9. Key stateが`Disabled`になることを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 13 | DisableKey実施前 | `13_before_disable_key.png` |
| 14 | DisableKey確認ダイアログ | `14_disable_key_confirmation.png` |
| 15 | DisableKey実施後 | `15_after_disable_key.png` |

### 7.3 CloudTrailでDisableKey確認

1. CloudTrailコンソールを開く。
2. 左メニューで`イベント履歴`を開く。
3. 検索属性で`イベント名`を選択する。
4. `DisableKey`で検索する。
5. 作業時刻の`DisableKey`イベントを開く。
6. 以下を確認する。

| フィールド | 期待値 |
| :--- | :--- |
| `eventSource` | `kms.amazonaws.com` |
| `eventName` | `DisableKey` |
| `userIdentity` | 作業者または作業Role |
| `requestParameters.keyId` | テスト専用CMK |
| `errorCode` | なし |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 16 | CloudTrail DisableKey検索結果 | `16_cloudtrail_disable_key_search.png` |
| 17 | CloudTrail DisableKey詳細 | `17_cloudtrail_disable_key_detail.png` |

### 7.4 CloudWatch Logs / Alarm / 通知確認

1. CloudWatchコンソールを開く。
2. `ログ` -> `ロググループ`を開く。
3. CloudTrail連携先Log Groupを開く。
4. 直近Log Streamを開く。
5. `DisableKey`イベントが届いていることを確認する。
6. CloudWatchの`すべてのアラーム`を開く。
7. 4.7用Alarmを開く。
8. Alarm Historyで状態変化を確認する。
9. 既存SNS Topic経由の通知受信を確認する。
10. 通知本文に`DisableKey`または4.7 Alarm名が含まれることを確認する。

注意:

- CloudTrailからCloudWatch Logsへの配送、Metric Filter、Alarm評価、SNS通知には数分かかる場合がある。
- 通知が届かない場合、15章の切り分けを行う。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 18 | CloudWatch Logs DisableKey | `18_cloudwatch_logs_disable_key.png` |
| 19 | 4.7 Alarm History | `19_req47_alarm_history_disable_key.png` |
| 20 | DisableKey通知受信 | `20_disable_key_notification_received.png` |

## 8. EnableKey復旧

DisableKeyイベント確認後、テスト専用CMKを有効化して戻す。

1. KMSコンソールでテスト専用CMKを開く。
2. Key stateが`Disabled`であることを確認する。
3. キー一覧に戻る。
4. 対象CMKのチェックボックスを選択する。
5. `キーアクション`または`Key actions`をクリックする。
6. `有効化`または`Enable`をクリックする。
7. Key stateが`Enabled`になることを確認する。
8. CloudTrailで`EnableKey`イベントを確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 21 | EnableKey実施前 | `21_before_enable_key.png` |
| 22 | EnableKey実施後 | `22_after_enable_key.png` |
| 23 | CloudTrail EnableKey詳細 | `23_cloudtrail_enable_key_detail.png` |

## 9. ScheduleKeyDeletion実イベントテスト

本章はPM承認がある場合のみ実施する。  
`ScheduleKeyDeletion`は削除予約であり、対象KMSキーは待機期間中`Pending deletion`となり、暗号化オペレーションに使用できない。

### 9.1 実施条件

| 条件 | 内容 |
| :--- | :--- |
| 対象キー | 本手順で作成したテスト専用CMKのみ |
| 業務利用 | なし |
| 承認 | PM、リーダー、必要に応じてインフラ/IAM担当の承認あり |
| 待機期間 | `7`日 |
| 通知先 | 既存SNS Topicへの通知テストを事前連絡済み |
| 復旧方針 | `CancelKeyDeletion`で戻すか、削除予定として残すか決定済み |

### 9.2 ScheduleKeyDeletion実施

1. KMSコンソールでテスト専用CMKを開く。
2. 対象AliasとKey IDを確認する。
3. Key usersが原則なしであることを再確認する。
4. キー一覧に戻る。
5. 対象CMKのチェックボックスを選択する。
6. `キーアクション`または`Key actions`をクリックする。
7. `キーの削除をスケジュール`または`Schedule key deletion`を選択する。
8. 警告内容を確認する。
9. Waiting periodに`7`日を入力する。
10. 確認チェックボックスを選択する。
11. 削除予約を実行する。
12. Key stateが`Pending deletion`になることを確認する。
13. Scheduled deletion dateを記録する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 24 | ScheduleKeyDeletion実施前 | `24_before_schedule_key_deletion.png` |
| 25 | ScheduleKeyDeletion確認画面 | `25_schedule_key_deletion_confirmation.png` |
| 26 | Pending deletion状態 | `26_after_schedule_key_deletion.png` |

### 9.3 CloudTrailでScheduleKeyDeletion確認

1. CloudTrailコンソールを開く。
2. イベント履歴で`ScheduleKeyDeletion`を検索する。
3. 作業時刻のイベントを開く。
4. 以下を確認する。

| フィールド | 期待値 |
| :--- | :--- |
| `eventSource` | `kms.amazonaws.com` |
| `eventName` | `ScheduleKeyDeletion` |
| `requestParameters.keyId` | テスト専用CMK |
| `requestParameters.pendingWindowInDays` | `7` |
| `errorCode` | なし |

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 27 | CloudTrail ScheduleKeyDeletion検索結果 | `27_cloudtrail_schedule_key_deletion_search.png` |
| 28 | CloudTrail ScheduleKeyDeletion詳細 | `28_cloudtrail_schedule_key_deletion_detail.png` |

### 9.4 CloudWatch Logs / Alarm / 通知確認

1. CloudWatch LogsのCloudTrail連携先Log Groupを開く。
2. `ScheduleKeyDeletion`イベントが届いていることを確認する。
3. 4.7用Alarm Historyを確認する。
4. 既存SNS Topic経由の通知受信を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 29 | CloudWatch Logs ScheduleKeyDeletion | `29_cloudwatch_logs_schedule_key_deletion.png` |
| 30 | 4.7 Alarm History | `30_req47_alarm_history_schedule_key_deletion.png` |
| 31 | ScheduleKeyDeletion通知受信 | `31_schedule_key_deletion_notification_received.png` |

## 10. 削除予約後の戻し方針

`ScheduleKeyDeletion`後は、以下のどちらかを選択する。

| 方針 | 内容 | 使う場面 |
| :--- | :--- | :--- |
| A. 削除予約をキャンセルする | `CancelKeyDeletion`後、必要に応じて`EnableKey`を実施する | 再テスト予定がある場合、削除を残したくない場合 |
| B. 削除予約を残す | `Pending deletion`のまま待機期間終了後にAWS KMSが削除する | テスト専用CMKを不要として削除完了させる場合 |

PM判断待ちの場合は、Aを基本方針とする。  
Bを選ぶ場合、削除予定日、対象Key ID、Alias、証跡保存先を記録する。

## 11. A案: CancelKeyDeletionで戻す

1. KMSコンソールでテスト専用CMKを開く。
2. Key stateが`Pending deletion`であることを確認する。
3. `キーアクション`または`Key actions`をクリックする。
4. `キー削除をキャンセル`または`Cancel key deletion`を選択する。
5. 削除予約取消を実行する。
6. Key stateが`Disabled`になることを確認する。
7. 必要に応じて`EnableKey`を実行する。
8. Key stateが`Enabled`になることを確認する。
9. CloudTrailで`CancelKeyDeletion`と`EnableKey`を確認する。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 32 | CancelKeyDeletion実施前 | `32_before_cancel_key_deletion.png` |
| 33 | CancelKeyDeletion実施後 | `33_after_cancel_key_deletion.png` |
| 34 | EnableKey再実施後 | `34_after_re_enable_key.png` |
| 35 | CloudTrail CancelKeyDeletion詳細 | `35_cloudtrail_cancel_key_deletion_detail.png` |

## 12. B案: 削除予約を残して削除完了させる

本案は、テスト専用CMKを今後使用しないことが確定している場合のみ選択する。  
AWS KMSは、待機期間終了後にKMSキー、Alias、関連メタデータを削除する。

### 12.1 削除予約を残す場合の記録

| 記録項目 | 内容 |
| :--- | :--- |
| Key ID | テスト専用CMKのKey ID |
| Alias | `alias/req47-test-cmk-<yyyymmdd>` |
| Key state | `Pending deletion` |
| Waiting period | `7`日 |
| Scheduled deletion date | コンソール表示値 |
| 承認者 | PM / リーダー |
| 証跡保存先 | 証跡格納場所 |

### 12.2 削除完了確認

待機期間終了後に以下を確認する。

1. KMSコンソールでカスタマー管理キー一覧を開く。
2. 対象AliasまたはKey IDを検索する。
3. 対象キーが表示されないことを確認する。
4. CloudTrailイベント履歴で、実際の削除イベントが記録されているか確認する。
5. 証跡を保存する。

注意:

- AWS KMSキーの実際の削除時刻は、設定した待機期間より最大24時間長くなる場合がある。
- 待機期間終了後に削除されたKMSキーは復元できない。
- 削除されたKMSキーで暗号化されたデータは復号できなくなる可能性がある。

取得する証跡:

| No. | 証跡 | ファイル名例 |
| :--- | :--- | :--- |
| 36 | Pending deletion記録 | `36_pending_deletion_record.png` |
| 37 | 削除完了確認 | `37_cmk_deleted_after_waiting_period.png` |

## 13. DisableKeyのみで終了する場合の後片付け

`ScheduleKeyDeletion`を実施しない場合、以下のどちらかを選択する。

| 方針 | 対応 |
| :--- | :--- |
| 再テスト用に残す | Key stateを`Enabled`に戻し、テスト専用タグを残す |
| 不要として削除予約する | PM承認後に9章の`ScheduleKeyDeletion`を実施する |

テスト専用CMKを残す場合、不要なキーとして放置しないよう、削除予定日または再利用予定を記録する。

## 14. 完了確認

| 確認 | OK条件 |
| :--- | :--- |
| DisableKey | CloudTrail、CloudWatch Logs、Alarm、通知で確認済み |
| EnableKey | テスト専用CMKが`Enabled`へ戻っている |
| ScheduleKeyDeletion | 実施した場合のみ、CloudTrail、CloudWatch Logs、Alarm、通知で確認済み |
| CancelKeyDeletion | 実施した場合のみ、CloudTrailで確認済み |
| 削除予約残置 | PM承認、削除予定日、対象Key IDを記録済み |
| 通知 | 受信確認者と受信時刻を記録済み |
| 証跡 | 全スクリーンショットを保存済み |

## 15. 通知が届かない場合の切り分け

| 観点 | 確認内容 |
| :--- | :--- |
| CloudTrail | `DisableKey`または`ScheduleKeyDeletion`が記録されているか |
| CloudWatch Logs | CloudTrailイベントがLog Groupへ届いているか |
| Metric Filter | Filter PatternがイベントJSONに一致しているか |
| Metric | 4.7 MetricにDatapointが発生しているか |
| Alarm | Alarm条件が`Sum >= 1`等になっているか |
| Alarm Actions | Actions enabledが有効か |
| SNS Topic | Alarm ActionのTopic ARNが正しいか |
| Subscription | 通知先が有効状態か |
| 通知経路 | Teams、A-gate、メール等の下流経路が有効か |
| 待機時間 | CloudTrail配送、Metric、Alarm評価、SNS通知に数分待っているか |

## 16. 完了報告テンプレート

```text
対象環境:
対象AWSアカウント:
対象リージョン:

要件:
REQ-4.7 KMSキー無効化・削除予約監視

テスト専用CMK:
Alias:
Key ID:

DisableKey:
実施有無:
実施時刻:
CloudTrail確認:
CloudWatch Logs確認:
Alarm確認:
通知確認:
EnableKey復旧:

ScheduleKeyDeletion:
実施有無:
実施時刻:
待機期間:
Scheduled deletion date:
CloudTrail確認:
CloudWatch Logs確認:
Alarm確認:
通知確認:

削除予約後の扱い:
CancelKeyDeletion実施 / Pending deletion残置 / 未実施

未実施項目:
未実施理由:
証跡保存先:
残課題:
```

## 17. PM判断ポイント

| 判断事項 | 推奨 |
| :--- | :--- |
| テスト専用CMK作成 | 実施可 |
| DisableKey実イベントテスト | 実施可 |
| DisableKey後のEnableKey | 必須 |
| ScheduleKeyDeletion実イベントテスト | 承認時のみ実施 |
| ScheduleKeyDeletion後の扱い | 原則CancelKeyDeletionで戻す |
| テスト専用CMKの最終削除 | 再テスト不要が確定してから削除予約 |

PMへ確認する内容:

```text
要件4.7の実イベント確認について、以下を確認する。

1. 業務利用していないテスト専用CMKを新規作成し、DisableKey後すぐEnableKeyで戻す手順で実施してよいか
2. ScheduleKeyDeletionまで実施するか
3. ScheduleKeyDeletionを実施する場合、テスト専用CMKに限定し、確認後CancelKeyDeletionで戻す方針でよいか
4. テスト通知の通知先、受信確認者、実施時間帯に問題がないか
5. テスト専用CMKの最終扱いを、再テスト用に残置するか、削除予約で削除完了させるか

KMSキー削除予約は破壊的操作に該当するため、ScheduleKeyDeletionはPM承認時のみ実施する。
```

## 18. 公式ドキュメント

- [AWS KMS料金](https://aws.amazon.com/jp/kms/pricing/)
- [AWS KMS keys](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/concepts.html)
- [AWS KMS: キーの有効化と無効化](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/enabling-keys.html)
- [AWS KMS: キーを削除する](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys.html)
- [AWS KMS: キー削除をスケジュールする](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html)
- [CloudTrail: CloudTrailイベント履歴を表示する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/view-cloudtrail-events.html)
