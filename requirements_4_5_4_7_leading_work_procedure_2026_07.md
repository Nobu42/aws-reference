# 要件4.5 / 4.7 先行作業 Webコンソール作業手順書

作成日: 2026-07-17

この手順書は、AWSセキュリティ監査指摘対応の先行作業として、要件4.5「CloudTrail設定変更監視」と要件4.7「カスタマー管理KMSキーの無効化・削除予約監視」を、検証環境で設定・確認するための作業手順である。

公開リポジトリで扱うことを想定し、顧客名、案件名、具体的なアカウントID、リージョン名、通知先、リソース名は記載しない。

## 1. 作業目的

CloudTrailのManagement EventをCloudWatch Logsへ連携し、CloudWatch Logs Metric Filter、CloudWatch Alarm、通知先を設定することで、以下の操作を検知できるようにする。

| 要件 | 監視対象 | 目的 |
| :--- | :--- | :--- |
| REQ-4.5 | CloudTrail設定変更 | 監査ログ取得設定の作成、変更、停止、削除を検知する |
| REQ-4.7 | カスタマー管理KMSキーの無効化・削除予約 | ログ暗号化やデータ暗号化に影響するKMSキーの危険操作を検知する |

この先行作業で、以下の型を確認する。

```text
CloudTrail
  -> CloudWatch Logs
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS等の通知先
  -> 証跡取得
```

## 2. 作業対象

| 項目 | 内容 |
| :--- | :--- |
| 対象環境 | 検証環境 |
| 対象要件 | REQ-4.5, REQ-4.7 |
| 作業日 | 2026-07-24予定 |
| 作業方式 | AWS Management Consoleを基本とする |
| 通知テスト | 承認済みの方法で実施する |
| 本番環境変更 | 本手順では実施しない |

注意:

- 現場口頭では「開発環境」と呼ばれる場合があるが、本資料では実態に合わせて「検証環境」と記載する。
- 本番環境での作業は、別途テストリハまたは本番作業手順で扱う。

## 3. 前提条件

作業開始前に、以下が確定していること。

| No. | 前提 | 確認内容 |
| :--- | :--- | :--- |
| 1 | 対象アカウント | 検証環境の対象AWSアカウントであること |
| 2 | 対象リージョン | CloudTrailイベントとCloudWatch Logsを確認するリージョンが確定していること |
| 3 | CloudTrail | Management Eventを記録しているTrailが存在すること |
| 4 | CloudWatch Logs連携 | CloudTrailがCloudWatch LogsのLog Groupへイベントを送信していること |
| 5 | Log Group | Metric Filter作成対象のLog Group名が確定していること |
| 6 | Log Class | 対象Log GroupがMetric Filter対応のStandard log classであること |
| 7 | 通知先 | 既存SNS Topicまたは既存通知基盤の利用可否が確定していること |
| 8 | 通知テスト | 通知テストの実施可否、実施時刻、周知先が承認済みであること |
| 9 | 切り戻し判断者 | 異常時に切り戻し判断する担当者が明確であること |
| 10 | 既存監視 | 既存EventBridge Ruleや既存監視基盤との重複有無を確認済みであること |
| 11 | KMS管理イベント | CloudTrailのManagement Event設定で`kms.amazonaws.com`が除外されていないこと |

CloudTrailからCloudWatch Logsへ送信されるイベントは、Trail側の設定に一致するイベントのみである。Management Eventが対象外になっているTrailでは、今回のMetric Filterは期待どおりに検知できない。

## 4. 設定値案

現場の命名規則がある場合は、以下の仮名を現場ルールへ読み替える。

| 項目 | REQ-4.5 | REQ-4.7 |
| :--- | :--- | :--- |
| Metric Filter名 | `<system>-security-4-5-cloudtrail-change` | `<system>-security-4-7-kms-key-disable-or-deletion` |
| Metric Namespace | `<system>/SecurityMonitoring` | `<system>/SecurityMonitoring` |
| Metric Name | `Req45CloudTrailChangeCount` | `Req47KmsKeyDisableOrDeletionCount` |
| Metric Value | `1` | `1` |
| Default Value | `0` | `0` |
| Statistic | `Sum` | `Sum` |
| Period | `300`秒 | `300`秒 |
| Evaluation Periods | `1` | `1` |
| Datapoints to Alarm | `1` | `1` |
| Threshold | `>= 1` | `>= 1` |
| Treat missing data | `notBreaching` | `notBreaching` |
| Alarm Action | 既存SNS Topicまたは既存通知先 | 既存SNS Topicまたは既存通知先 |
| OK Action | 原則なし | 原則なし |
| Insufficient Data Action | 原則なし | 原則なし |

注意:

- Metric FilterにDimensionを付けると、Default Valueを設定できない。
- Dimensionをユーザー名、ARN、リソース名などで付けると、メトリクス系列が増え、費用や管理が増える。
- 先行作業では、まずDimensionなしで作成することを推奨する。
- `Default Value = 0` は、ログは取り込まれているが一致イベントがない期間に0を出すための設定である。
- ログ自体が取り込まれていない期間は、Default Valueを設定していてもデータポイントが出ない場合がある。

## 5. Filter Pattern

### 5.1 REQ-4.5 CloudTrail設定変更監視

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

このFilter Patternは、AWS Security HubのCloudWatch.5およびCIS AWS Foundations Benchmark相当の是正確認で示されている形式に合わせる。
Security Hub CSPMでは、CISで規定された正確なMetric Filterが使用されていない場合にFAILEDとなる可能性があるため、本手順の必須設定では`eventSource`条件や追加イベントを入れない。

対象イベント:

| イベント | 意味 | 注意 |
| :--- | :--- | :--- |
| `CreateTrail` | Trail作成 | テスト用Trail作成でも検知する |
| `UpdateTrail` | Trail設定変更 | 正常な設定変更でも検知する |
| `DeleteTrail` | Trail削除 | 監査ログ取得停止につながるため重要 |
| `StartLogging` | ログ記録開始 | 復旧操作でも検知する |
| `StopLogging` | ログ記録停止 | 高リスク。原則テストで実行しない |

参考:

Event Selector変更やInsight Selector変更も運用上検知したい場合は、REQ-4.5本体のMetric Filterへ混ぜず、レビュー承認後に任意の拡張監視として別Filterを作成する。

```text
{($.eventName=PutEventSelectors) || ($.eventName=PutInsightSelectors)}
```

拡張監視を追加する場合は、監査是正用のREQ-4.5 Filterとは別名、別Metric、別Alarmとして管理し、Security Hub/CIS準拠確認用の基本Filterを変更しない。

### 5.2 REQ-4.7 KMSキー無効化・削除予約監視

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

このFilter Patternは、AWS Security HubのCloudWatch.7およびCIS AWS Foundations Benchmark相当の是正確認で示されている形式に合わせる。
CloudTrailのManagement Event設定で`kms.amazonaws.com`が除外されている場合、KMS関連イベントがCloudWatch Logsへ届かず、検知できない可能性がある。

対象イベント:

| イベント | 意味 | 注意 |
| :--- | :--- | :--- |
| `DisableKey` | カスタマー管理KMSキーの無効化 | キーは即時に暗号化処理で利用不能になる可能性がある |
| `ScheduleKeyDeletion` | カスタマー管理KMSキーの削除予約 | 削除待機期間後は復旧不能になるため極めて高リスク |

対象はカスタマー管理KMSキーである。AWS managed keysやAWS owned keysは利用者が無効化・削除予約する対象ではない。

## 6. 想定される影響

### 6.1 設定作業自体の影響

今回の基本作業は、CloudWatch Logs Metric FilterとCloudWatch Alarmの追加である。CloudTrail、KMSキー、既存アプリケーションの設定値を直接変更する作業ではない。

通常の影響は以下である。

| 影響 | 内容 |
| :--- | :--- |
| 通知増加 | 対象イベント発生時に通知が出る |
| CloudWatchメトリクス増加 | Metric Filterによりカスタムメトリクスが作成される |
| CloudWatch Alarm増加 | 4.5、4.7用のAlarmが追加される |
| 運用対応増加 | 正常な変更作業でもアラート対応が必要になる |
| 費用影響 | カスタムメトリクス、Alarm、通知に伴う費用が発生する可能性がある |

### 6.2 REQ-4.5の影響

CloudTrail設定変更監視は、正当な運用作業でも通知する。

通知される可能性がある正常操作の例:

- CloudTrailの証跡設定変更
- CloudWatch Logs連携設定の変更
- Event Selector変更やInsight Selector変更を拡張監視として追加した場合の設定変更
- Trailの新規作成または整理
- 障害復旧時の`StartLogging`

注意:

- `StopLogging`や`DeleteTrail`は高リスク操作であり、検証環境であっても安易に実イベントテストしない。
- 本番環境では、CloudTrail停止やTrail削除を通知テスト目的で実施しない。

### 6.3 REQ-4.7の影響

KMSキー無効化・削除予約監視は、対象イベント自体の影響が大きい。

AWS KMSでは、カスタマー管理KMSキーを無効化すると、そのキーは暗号化処理で利用できなくなる。削除予約はさらに危険であり、待機期間後にキーが削除されると、当該キーで暗号化されたデータの復号ができなくなる可能性がある。

注意:

- 本番KMSキーで`DisableKey`や`ScheduleKeyDeletion`をテストしない。
- 検証環境でも、実データを暗号化しているKMSキーをテスト対象にしない。
- `ScheduleKeyDeletion`をテストする場合は、使い捨てのテスト用KMSキーに限定し、実施直後に`CancelKeyDeletion`と必要に応じて`EnableKey`を行う。

## 7. 誤検知・通知多発の可能性

ここでいう誤検知は、「攻撃や事故ではないが、監視条件に一致して通知される」ことを指す。今回の2要件は重要操作を広く検知するため、正常な変更作業も通知対象になる。

| 要件 | 通知多発の原因 | 対策 |
| :--- | :--- | :--- |
| 4.5 | IaCや運用作業でTrail設定を複数回更新する | 作業予定とアラートを突合する |
| 4.5 | テスト用Trailの作成・削除を繰り返す | テスト回数を事前に決める |
| 4.5 | Event Selector調整を複数回行う | 変更作業中の通知先へ事前周知する |
| 4.7 | KMSキー棚卸しや削除予約作業をまとめて行う | 変更管理番号単位で通知を確認する |
| 4.7 | テストキーの無効化・削除予約を複数回行う | テスト用キーを最小数にする |
| 4.7 | 自動化スクリプトが複数キーを処理する | 実行前に対象キー数を確認する |

## 8. 誤検知・通知多発を避ける注意点

### 8.1 Filter Patternを安易に狭めない

通知を減らすために、特定ユーザー、特定ロール、特定IPアドレスを除外することは原則避ける。

理由:

- 除外したユーザーやロールが侵害された場合に検知できなくなる。
- 正常運用者による誤操作を検知できなくなる。
- 監査要件の「設定変更を監視する」という意図から外れる可能性がある。

通知量を減らす場合は、Filter Patternで除外する前に、以下で対応する。

- 変更管理番号との突合
- 作業時間帯の周知
- 通知受信側の振り分け
- アラート対応手順で「予定作業」として記録
- 既存監視基盤との重複排除

### 8.2 Alarm ActionはALARMのみにする

初期設定では、Alarm Actionは`ALARM`遷移時のみ設定する。

以下は原則設定しない。

- OK Action
- Insufficient Data Action

理由:

- Metric Filter由来のメトリクスは、対象イベントがない期間にデータが出ないことがある。
- OK通知やINSUFFICIENT_DATA通知を有効にすると、正常状態の通知や欠損通知が増える可能性がある。

### 8.3 Missing dataはnotBreachingにする

対象イベントが発生しないことが正常であるため、Missing dataは`notBreaching`を基本とする。

`breaching`にすると、イベントが発生していないだけでAlarmになる可能性がある。

### 8.4 Dimensionは原則付けない

Dimensionを付けると、アカウント、リージョン、ユーザー、リソースごとにメトリクス系列が増える。系列が増えると、Alarm設計、費用、運用確認が複雑になる。

先行作業ではDimensionなしで設定し、必要性が明確になった場合だけ追加を検討する。

### 8.5 実イベントテストは最小限にする

4.5と4.7は、実イベントを起こすこと自体が危険な場合がある。

特に禁止または原則回避する操作:

- 本番Trailの`StopLogging`
- 本番Trailの`DeleteTrail`
- 本番KMSキーの`DisableKey`
- 本番KMSキーの`ScheduleKeyDeletion`
- 実データを暗号化している検証環境KMSキーの`ScheduleKeyDeletion`

## 9. 作業前確認手順

### 9.1 作業開始連絡

1. 作業開始時刻を記録する。
2. 作業者、確認者、切り戻し判断者を確認する。
3. 通知先担当者へ作業開始を連絡する。
4. 通知テストを行う場合は、通知が発生する可能性を周知する。

### 9.2 AWSアカウント・リージョン確認

1. AWS Management Consoleへログインする。
2. 画面右上で対象アカウントを確認する。
3. 画面右上で対象リージョンを確認する。
4. 対象外アカウントまたは対象外リージョンの場合、作業を中断する。

取得する証跡:

- アカウント表示
- リージョン表示
- 作業開始連絡の記録

### 9.3 CloudTrail確認

1. CloudTrailコンソールを開く。
2. `証跡`を開く。
3. 対象Trailを選択する。
4. Management Eventが記録対象であることを確認する。
5. KMS管理イベントが除外されていないことを確認する。
6. CloudWatch Logs連携先Log Groupを確認する。
7. 組織Trailの場合、管理アカウントまたは適切な権限で確認していることを確認する。

取得する証跡:

- Trail詳細
- Management Event設定
- KMS管理イベント除外有無
- CloudWatch Logs連携先Log Group
- CloudWatch Logs Role

### 9.4 CloudWatch Logs確認

1. CloudWatchコンソールを開く。
2. `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. Log Streamまたはログイベントが更新されていることを確認する。
5. `eventSource = cloudtrail.amazonaws.com` または `eventSource = kms.amazonaws.com` のイベントが存在するか確認する。

注意:

- 過去ログが存在しても、Metric Filter作成前の過去ログからメトリクスは生成されない。
- Metric Filterは作成後に到着したログに対してメトリクスを発行する。

### 9.5 既存設定確認

以下を確認し、作業前証跡を取得する。

| 対象 | 確認内容 |
| :--- | :--- |
| Metric Filter | 同名または同等条件の既存Filterがないこと |
| CloudWatch Alarm | 同名または同等Metricの既存Alarmがないこと |
| SNS Topic | 通知先TopicとSubscriptionが有効であること |
| EventBridge Rule | 同等イベントを通知する既存Ruleがないこと |
| 既存監視基盤 | 4.5/4.7が既存監視でカバー済みでないこと |

同等監視が存在する場合は、新規作成せず、リーダーへ確認する。

## 10. Metric Filter作成手順

### 10.1 REQ-4.5 Metric Filter作成

1. CloudWatchコンソールを開く。
2. `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. `メトリクスフィルター` タブを開く。
5. `メトリクスフィルターを作成` を選択する。
6. Filter Patternに以下を入力する。

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

7. サンプルログまたは既存ログでPatternをテストする。
8. 公式Patternの対象イベントのみ一致することを確認する。
9. Filter名を入力する。
10. Metric Namespaceを入力する。
11. Metric Nameに`Req45CloudTrailChangeCount`を入力する。
12. Metric Valueに`1`を入力する。
13. Dimensionは設定しない。
14. Default Valueに`0`を入力する。
15. 内容を確認し、Metric Filterを作成する。

取得する証跡:

- Filter Pattern入力画面
- Patternテスト結果
- Metric設定画面
- 作成後Metric Filter詳細

### 10.2 REQ-4.7 Metric Filter作成

1. CloudWatchコンソールを開く。
2. `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. `メトリクスフィルター` タブを開く。
5. `メトリクスフィルターを作成` を選択する。
6. Filter Patternに以下を入力する。

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

7. サンプルログまたは既存ログでPatternをテストする。
8. 想定イベントのみ一致することを確認する。
9. Filter名を入力する。
10. Metric Namespaceを入力する。
11. Metric Nameに`Req47KmsKeyDisableOrDeletionCount`を入力する。
12. Metric Valueに`1`を入力する。
13. Dimensionは設定しない。
14. Default Valueに`0`を入力する。
15. 内容を確認し、Metric Filterを作成する。

取得する証跡:

- Filter Pattern入力画面
- Patternテスト結果
- Metric設定画面
- 作成後Metric Filter詳細

## 11. CloudWatch Alarm作成手順

REQ-4.5とREQ-4.7で同じ流れで作成する。

1. CloudWatchコンソールを開く。
2. `アラーム` -> `すべてのアラーム` を開く。
3. `アラームの作成` を選択する。
4. `メトリクスの選択` を選択する。
5. 作成したMetric Namespaceを選択する。
6. 対象Metricを選択する。
7. Statisticを`Sum`にする。
8. Periodを`5分`にする。
9. Conditionsで`Static`を選択する。
10. 条件を`Greater/Equal`、Thresholdを`1`にする。
11. Additional configurationで以下を設定する。

| 項目 | 値 |
| :--- | :--- |
| Datapoints to alarm | `1 out of 1` |
| Missing data treatment | `notBreaching` |

12. Notificationで`In alarm`を選択する。
13. 既存SNS Topicまたは承認済み通知先を選択する。
14. OK通知、INSUFFICIENT_DATA通知は原則設定しない。
15. Alarm名を入力する。
16. Alarm説明を入力する。
17. Previewで内容を確認し、作成する。

推奨Alarm名:

| 要件 | Alarm名案 |
| :--- | :--- |
| REQ-4.5 | `<system>-security-4-5-cloudtrail-change-alarm` |
| REQ-4.7 | `<system>-security-4-7-kms-key-disable-or-deletion-alarm` |

推奨説明文:

```text
Detects requirement 4.5 CloudTrail configuration changes based on CloudTrail events delivered to CloudWatch Logs.
```

```text
Detects requirement 4.7 KMS DisableKey or ScheduleKeyDeletion events based on CloudTrail events delivered to CloudWatch Logs.
```

取得する証跡:

- Metric選択画面
- 条件設定画面
- Missing data設定画面
- Notification設定画面
- Alarm名・説明入力画面
- 作成後Alarm詳細

## 12. 通知先確認手順

既存SNS Topicを使う場合:

1. SNSコンソールを開く。
2. 対象Topicを選択する。
3. Topic ARNを確認する。
4. Subscription一覧を確認する。
5. メール、Teams、監視基盤などの通知先が有効であることを確認する。
6. メールSubscriptionの場合、Confirmedであることを確認する。
7. Alarm Actionに設定したTopic ARNと一致することを確認する。

新規SNS Topicを作る場合:

1. SNSコンソールを開く。
2. Topicを作成する。
3. Subscriptionを追加する。
4. メール通知の場合、受信者がConfirm subscriptionを完了する。
5. SubscriptionがConfirmedになったことを確認する。
6. Alarm Actionに新規Topicを設定する。

注意:

- 既存Topicを使う場合、Topic自体を変更・削除しない。
- 通知先が複数システムで利用されている場合、テスト通知の周知を必ず行う。
- メールSubscriptionがPendingConfirmationのままだと通知されない。

## 13. テスト手順

テストは、影響の小さい順に実施する。

### 13.1 Pattern Test

目的:

- Filter PatternがCloudTrailログのJSON形式に一致することを確認する。
- 実リソースに影響を与えずに条件の妥当性を確認する。

手順:

1. CloudWatch Logsの対象Log Groupを開く。
2. 対象Metric FilterのPattern Test画面を開く。
3. CloudTrailイベントのサンプルログを1行JSONで入力する。
4. REQ-4.5では`eventSource = cloudtrail.amazonaws.com`、対象`eventName`で一致することを確認する。
5. REQ-4.7では`eventSource = kms.amazonaws.com`、対象`eventName`で一致することを確認する。
6. 対象外イベントが一致しないことを確認する。

注意:

- Pattern Testは通知を発生させない。
- Pattern TestはAlarm Actionの疎通確認にはならない。
- 過去ログでPatternが一致しても、Metric Filter作成前の過去分はメトリクス化されない。

### 13.2 Alarm通知テスト

通知経路の確認は、可能であればCloudWatchの`SetAlarmState`を使う。

目的:

- 実際に危険なCloudTrail/KMS操作を起こさず、Alarm Actionと通知先を確認する。

AWS CLI例:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "<alarm-name>" \
  --state-value ALARM \
  --state-reason "Notification test for REQ-4.5/4.7 leading work"
```

確認事項:

- SNS、メール、Teams、監視基盤のいずれかで通知を受信できること。
- Alarm Historyに一時的な状態変更が記録されること。
- Metric Alarmは次回評価で実状態へ戻ること。

注意:

- `SetAlarmState`はMetric Filterが実イベントを検知したことの確認ではない。
- 通知経路とAlarm Actionの確認として扱う。
- テスト通知の実施時刻と対象Alarm名を事前周知する。
- 複数回実施すると通知が多発するため、原則各Alarm 1回にする。

### 13.3 実イベントテスト

実イベントテストは、承認された場合のみ実施する。

REQ-4.5:

- 本番Trailの`StopLogging`、`DeleteTrail`は実施しない。
- 検証環境でも、監査ログ取得に使っている主要Trailでは実施しない。
- 実施する場合は、テスト用Trailまたは承認済みの可逆操作に限定する。
- 実イベント発生後、CloudWatch Logsへの到着、Metric増加、Alarm遷移、通知を確認する。

REQ-4.7:

- 本番KMSキーでは実施しない。
- 実データを暗号化している検証環境KMSキーでも実施しない。
- `DisableKey`をテストする場合は、使い捨てのテスト用カスタマー管理KMSキーに限定し、確認後すぐに`EnableKey`する。
- `ScheduleKeyDeletion`をテストする場合は、使い捨てのテスト用KMSキーに限定し、確認後すぐに`CancelKeyDeletion`し、必要に応じて`EnableKey`する。

実イベントテストの証跡:

- 実施承認
- 実施対象リソース
- 実施時刻
- CloudTrailイベント
- Metric Filter一致
- Metric増加
- Alarm状態
- 通知受信
- 戻し操作
- 戻し後状態

## 14. 作業後確認

| 確認項目 | 期待結果 |
| :--- | :--- |
| REQ-4.5 Metric Filter | 作成済みでFilter Patternが設計値と一致している |
| REQ-4.7 Metric Filter | 作成済みでFilter Patternが設計値と一致している |
| REQ-4.5 Metric | Namespace、Metric Name、Metric Valueが設計値と一致している |
| REQ-4.7 Metric | Namespace、Metric Name、Metric Valueが設計値と一致している |
| REQ-4.5 Alarm | Sum、5分、1以上、1 out of 1、notBreachingである |
| REQ-4.7 Alarm | Sum、5分、1以上、1 out of 1、notBreachingである |
| Alarm Action | ALARM時のみ通知先が設定されている |
| SNS Subscription | Confirmedまたは有効状態である |
| 通知テスト | 承認済みの方法で受信確認済みである |
| 証跡 | 作業前、作業後、テスト、通知、戻し確認が保存されている |

## 15. 切り戻し手順

切り戻しは、今回追加した設定のみを対象にする。

### 15.1 切り戻し判断条件

以下のいずれかに該当する場合は、リーダーまたは切り戻し判断者へ確認し、切り戻しを検討する。

- Alarmが想定外にALARMを継続する。
- 通知が想定外の宛先へ送信される。
- 通知が多発し、運用へ支障が出る。
- 既存監視基盤と二重通知になる。
- Metric FilterのPatternが広すぎる、または対象外イベントを検知する。
- 作業対象アカウントまたはリージョンを誤った。

### 15.2 CloudWatch Alarm切り戻し

1. CloudWatchコンソールを開く。
2. `アラーム` -> `すべてのアラーム` を開く。
3. 今回作成したREQ-4.5 / REQ-4.7のAlarmを選択する。
4. 可能であればAlarm Actionを無効化する。
5. 承認後、今回作成したAlarmを削除する。
6. 既存Alarmは削除しない。

### 15.3 Metric Filter切り戻し

1. CloudWatchコンソールを開く。
2. `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. `メトリクスフィルター` タブを開く。
5. 今回作成したREQ-4.5 / REQ-4.7のMetric Filterを削除する。
6. 既存Metric Filterは削除しない。

### 15.4 通知先切り戻し

既存SNS Topicを使った場合:

- Topic自体は削除しない。
- 既存Subscriptionは削除しない。
- Alarm Action削除またはAlarm削除で切り戻す。

新規SNS Topicを作った場合:

- 他用途で使われていないことを確認する。
- 追加したSubscriptionを削除する。
- 追加したTopicを削除する。

### 15.5 切り戻し後確認

| 確認項目 | 期待結果 |
| :--- | :--- |
| Alarm | 今回作成分が削除またはAction無効化されている |
| Metric Filter | 今回作成分が削除されている |
| SNS | 既存TopicとSubscriptionに影響がない |
| CloudTrail | Trail設定に意図しない変更がない |
| KMS | テスト用KMSキー以外に影響がない |
| 証跡 | 切り戻し前後の画面が保存されている |

## 16. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 設定完了 | REQ-4.5 / REQ-4.7のMetric FilterとAlarmが作成されている |
| 通知設定完了 | Alarm Actionに承認済み通知先が設定されている |
| テスト完了 | Pattern Test、通知テスト、必要に応じた実イベントテストが完了している |
| 証跡完了 | 作業前、作業後、テスト結果、通知結果が保存されている |
| 影響確認完了 | 通知多発、既存監視重複、既存通知先影響がないことを確認している |
| レビュー準備完了 | 2026-07-22レビューまたはレビュー後修正へ出せる状態である |

## 17. 公式資料リンク

設定方法と注意事項は、以下のAWS公式資料を確認して作成した。

日本語版のAWS公式ドキュメントは機械翻訳で提供されている場合がある。日本語版と英語版の内容に差異がある場合は、英語版を優先する。

| 確認内容 | 日本語版 | 英語版 |
| :--- | :--- | :--- |
| Security Hub CloudWatchコントロール、REQ-4.5/4.7相当のFilter Pattern | [Amazon CloudWatch の Security Hub CSPM コントロール](https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/cloudwatch-controls.html) | [Security Hub CSPM controls for Amazon CloudWatch](https://docs.aws.amazon.com/securityhub/latest/userguide/cloudwatch-controls.html) |
| CloudTrailイベントに対するCloudWatch Alarm例 | [CloudTrail イベントの CloudWatch アラームの作成: 例](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html) | [Creating CloudWatch alarms for CloudTrail events: examples](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html) |
| CloudTrailイベントをCloudWatch Logsへ送信する設定 | [CloudWatch Logs へのイベントの送信](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html) | [Sending events to CloudWatch Logs](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html) |
| CloudWatch Logs Metric Filter作成 | [フィルターを使用したログイベントからのメトリクスの作成](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html) | [Creating metrics from log events using filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html) |
| Filter Pattern構文 | [フィルターパターン構文](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html) | [Filter pattern syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html) |
| 静的しきい値のCloudWatch Alarm作成 | [静的しきい値に基づいて CloudWatch アラームを作成する](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/ConsoleAlarms.html) | [Create a CloudWatch alarm based on a static threshold](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ConsoleAlarms.html) |
| CloudWatch Alarmの欠落データ処理 | [CloudWatch アラームの欠落データの処理の設定](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html) | [Configuring how CloudWatch alarms treat missing data](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html) |
| CloudWatch Alarm Action | [アラームアクション](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html) | [Alarm actions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-actions.html) |
| AWS CLIによるAlarm状態変更テスト | - | [cloudwatch set-alarm-state](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/set-alarm-state.html) |
| KMSキーの有効化・無効化 | [キーの有効化と無効化](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/enabling-keys.html) | [Enable and disable keys](https://docs.aws.amazon.com/kms/latest/developerguide/enabling-keys.html) |
| KMSキー削除予約 | [キー削除をスケジュールする](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html) | [Schedule key deletion](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html) |
