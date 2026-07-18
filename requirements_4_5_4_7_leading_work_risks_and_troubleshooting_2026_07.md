# 要件4.5 / 4.7 先行作業 懸念点・注意点・トラブルシューティング

作成日: 2026-07-18

本資料は、要件4.5「CloudTrail設定変更監視」および要件4.7「カスタマー管理KMSキーの無効化・削除予約監視」の先行作業について、作業前の懸念点、実作業時の注意点、失敗時の切り分け観点を整理するものである。

対象は検証環境での先行作業とする。  
本番環境作業は、検証環境で手順、設定値、通知、証跡取得方法を確認した後に別途扱う。

## 1. 現時点の確認状況

| 項目 | 状況 | 作業上の意味 |
| :--- | :--- | :--- |
| 作業用アカウント | 未払い出し | 実作業権限、参照権限、テスト権限が未確定 |
| A-gate / EventBridgeの扱い | PM確認待ち | 既存対応扱いにする要件と新規設定する要件が確定していない |
| CloudTrail -> CloudWatch Logs連携 | 未設定を確認 | Metric Filter方式の前提が未充足 |
| パラメータシート | CloudWatch Logs連携値が空欄 | 連携設定を今回追加するか確認が必要 |
| Log Group | 存在するが未使用に見える | 既存Log Group利用可否、保持期間、暗号化、権限確認が必要 |
| IAM Role | コンソール上は空欄表示 | 保存時にデフォルトRoleが指定される可能性があるが、保存後確認が必要 |
| Metric Filter構文テスト | `Forbidden`発生 | `logs:TestMetricFilter`権限不足の可能性が高い |
| 通知先SNS Topic | 既存Topic利用想定 | 通知先、Subscription状態、利用可否の確認が必要 |

## 2. 作業開始条件

以下が揃うまで、Metric Filter / Alarm作成へ進まない。

| No. | 作業開始条件 | 未充足時の扱い |
| :--- | :--- | :--- |
| 1 | 作業用アカウントが払い出されている | 作業不可。手順書レビューと机上確認に留める |
| 2 | 作業用アカウントの権限範囲が確認できている | 作業不可または確認作業のみ実施 |
| 3 | CloudTrail -> CloudWatch Logs連携を追加してよい方針が確認済み | Metric Filter方式の作業不可 |
| 4 | 既存Log Groupを利用するか新規作成するか確定済み | Log Group選択不可 |
| 5 | CloudTrail配信用IAM Roleの扱いが確認済み | Trail更新不可 |
| 6 | 既存SNS Topicを通知先として使ってよいことが確認済み | Alarm Action設定不可 |
| 7 | A-gate / EventBridge対応済み要件の扱いが確定済み | 二重通知リスクがあるため新規設定不可 |
| 8 | 通知テスト方法と通知確認者が確定済み | 通知到達確認不可 |
| 9 | 切り戻し判断者が確定済み | 変更作業不可 |

## 3. 先行作業で特に大きい懸念点

| 懸念 | 内容 | 影響 | 対応 |
| :--- | :--- | :--- | :--- |
| CloudWatch Logs連携が未設定 | CloudTrailイベントがLog Groupへ届いていない | Metric Filterを作成しても検知できない | 24日の検証で連携有効化とログ到達を確認する |
| 作業用アカウントがない | 実際の権限で操作確認できない | 手順どおりに進められるか不明 | アカウント払い出し時期と権限範囲を確認する |
| `logs:TestMetricFilter`がForbidden | 構文テストAPIが許可されていない可能性が高い | 事前にFilter PatternをCLIで確認できない | エラー全文を証跡化し、権限付与または権限者による代行確認を依頼する |
| A-gate / EventBridge方針が未確定 | 既存通知で要件を満たすか未判断 | 新規Alarm追加で二重通知になる可能性 | PM回答待ちとして記録し、A案/B案を保持する |
| 既存SNS Topicの通知先不明 | 通知が誰に届くか不明 | テスト通知時に混乱する | Subscription、通知先、受信確認者を確定する |
| テストイベントが危険 | 4.5/4.7は対象イベント自体の影響が大きい | Trail停止やKMSキー無効化が業務影響になる | 実リソースではなくサンプルログ、Pattern Test、テスト用リソースで確認する |
| 監査要件とのズレ | Security Hub/CIS相当のFilter Patternと現場拡張が混ざる | 準拠確認で不一致になる可能性 | 必須Filterと拡張Filterを分ける |

## 4. CloudTrail -> CloudWatch Logs連携の注意点

### 4.1 連携はMetric Filter方式の前提

4.5 / 4.7の基本構成は以下である。

```text
CloudTrail
  -> CloudWatch Logs
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS等の通知先
```

CloudTrailがCloudWatch Logsへ連携されていない場合、Metric Filterは作成できても、CloudTrailイベントを検知できない。

### 4.2 コンソール上のIAM Role欄

CloudTrailの通知設定またはCloudWatch Logs連携設定で、IAM Role欄が空に見える場合がある。  
コンソール保存時にデフォルトの`CloudTrail_CloudWatchLogs_Role`が指定または作成される可能性がある。

ただし、推測で完了扱いにしない。保存後に以下を確認する。

| 確認箇所 | 確認内容 |
| :--- | :--- |
| Trail詳細 | CloudWatch Logs Log Group ARNが入っている |
| Trail詳細 | CloudWatch Logs Role ARNが入っている |
| IAM Role | `CloudTrail_CloudWatchLogs_Role`または指定Roleが存在する |
| 信頼ポリシー | `cloudtrail.amazonaws.com`がAssumeRoleできる |
| Role権限 | 対象Log Groupへ`logs:CreateLogStream`、`logs:PutLogEvents`できる |
| CloudWatch Logs | Log Streamが作成される |
| CloudWatch Logs | 数分後にCloudTrailイベントが届く |

## 5. 実作業時の注意点

### 5.1 作業前

- 対象アカウント、対象リージョン、対象Trail、対象Log Groupを確認する
- 本番環境ではなく検証環境であることを確認する
- 既存EventBridge / A-gateで同等監視がないか確認する
- 既存SNS Topicの通知先と受信確認者を確認する
- CloudTrail -> CloudWatch Logs連携が未設定の場合、Metric Filter作成へ進まない
- 作業開始前のスクリーンショットを取得する

### 5.2 CloudTrail連携時

- Log Groupが想定どおり自動入力または選択されるか確認する
- IAM Role欄が空の場合、保存後にRole ARNを確認する
- CloudTrailのEvent SelectorでManagement Eventが対象であることを確認する
- KMSイベントがCloudTrail側で除外されていないことを確認する
- 連携保存後、CloudWatch Logsにイベントが届くまで数分待つ
- 配信エラーが出た場合、Role権限とLog Group ARNを確認する

### 5.3 Metric Filter作成時

- 対象Log GroupがStandard log classであることを確認する
- Filter Patternはパラメータシートまたは承認済み手順書の値を使う
- 4.5の必須Filterには、監査準拠確認用の基本イベントだけを入れる
- Event Selector変更などの拡張監視は、必要であれば別Filterとして扱う
- Dimensionは初期設定では付けない
- Metric Valueは`1`、Default Valueは`0`を基本とする
- Pattern Test結果を証跡として保存する

### 5.4 Alarm作成時

- Statisticは`Sum`を基本とする
- Periodは`300秒`を基本とする
- Thresholdは`>= 1`を基本とする
- Treat missing dataは`notBreaching`を基本とする
- Alarm Actionは`ALARM`遷移時のみ設定する
- OK Action、Insufficient Data Actionは原則設定しない
- 既存SNS Topicを指定し、新規Topicは作成しない

### 5.5 通知テスト時

- 実イベントを起こす場合は、検証環境かつ承認済みの範囲に限定する
- `StopLogging`はテスト目的で実施しない
- 本物のKMSキーで`DisableKey`または`ScheduleKeyDeletion`を実施しない
- KMSテストを行う場合は使い捨てのテスト用カスタマー管理KMSキーに限定する
- 通知到達確認者、通知時刻、通知本文、対象Alarmを記録する

## 6. やってはいけないこと

| NG操作 | 理由 |
| :--- | :--- |
| 本番Trailで`StopLogging`を実行する | 監査ログ取得停止につながる |
| 本番Trailを削除する | 監査証跡が失われる |
| 本物のKMSキーを無効化する | 暗号化済みデータやAWSサービス利用へ影響する |
| 本物のKMSキーに削除予約を入れる | 待機期間後に復旧不能になる可能性がある |
| 既存SNS Topicを削除する | 他の通知経路を壊す可能性がある |
| 既存EventBridge Ruleを削除する | 既存監視や別アカウント連携を壊す可能性がある |
| CloudWatch Logs Log Groupを削除する | 既存ログや監査証跡を失う |
| Filter Patternを独自判断で狭める | 監査要件を満たさなくなる可能性がある |

## 7. トラブルシューティング

### 7.1 `aws logs test-metric-filter`がForbiddenになる

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | `logs:TestMetricFilter`権限不足 |
| 確認する証跡 | CLIエラー全文、CloudTrailの`TestMetricFilter`失敗イベント |
| 見るべき文言 | `AccessDeniedException`、`not authorized to perform: logs:TestMetricFilter` |
| 対応 | 権限付与可否を確認する。不可の場合は権限者に代行テストを依頼する |
| 代替 | WebコンソールのPattern Test、机上確認、24日の作業用アカウント払い出し後に再実施 |

確認依頼文例:

```text
Metric Filterの構文確認としてlogs:TestMetricFilterを実行したところForbiddenとなった。
このAPIは設定変更を伴わない構文・一致条件確認用のAPIである。
手順書レビュー前にFilter Patternの妥当性を確認するため、logs:TestMetricFilterの付与可否を確認したい。
```

### 7.2 CloudTrailのCloudWatch Logs連携を保存できない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | `cloudtrail:UpdateTrail`不足、IAM Role指定権限不足、`iam:PassRole`不足 |
| 確認する画面 | CloudTrail Trail編集画面、IAM Role、エラー全文 |
| 対応 | 作業用RoleにCloudTrail更新権限と必要なIAM Role利用権限があるか確認する |
| 注意 | 作業者がIAM Roleを作成またはPassRoleできない場合、権限者による事前作成が必要 |

### 7.3 IAM Role欄が空のまま保存しようとしている

| 確認項目 | 内容 |
| :--- | :--- |
| 想定 | コンソール保存時にデフォルトRoleが指定される可能性がある |
| 対応 | 保存後にTrail詳細のCloudWatch Logs Role ARNを確認する |
| 保存後にRole ARNが空 | 連携が完了していない。作業停止し、Role指定方針を確認する |
| Roleが作成されたが配信されない | Trust Policy、Inline Policy、Log Group ARNを確認する |

### 7.4 Log GroupはあるがLog Streamが作成されない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | Trail連携未完了、Role権限不足、対象リージョン違い、イベント未発生 |
| 確認1 | Trail詳細でCloudWatch Logs Log Group ARNが設定済みか |
| 確認2 | CloudWatch Logs Role ARNが設定済みか |
| 確認3 | Log GroupリージョンがTrail設定と一致するか |
| 確認4 | CloudTrailのLatestDeliveryErrorまたはCloudWatch Logs配信エラーがないか |
| 対応 | 数分待機し、軽微な読み取り操作等でCloudTrailイベント発生を確認する |

### 7.5 Log Streamはあるがログイベントが届かない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | CloudTrailイベント配信遅延、Event Selector対象外、Management Event未記録 |
| 確認1 | TrailがLogging中か |
| 確認2 | Management Eventが対象か |
| 確認3 | Read/Write種別が対象操作と合っているか |
| 確認4 | 対象イベントが発生しているか |
| 対応 | 5〜15分程度待機し、CloudTrail Event history側でもイベント発生を確認する |

### 7.6 Pattern Testで一致しない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | サンプルJSON不備、Filter Pattern誤記、イベント名違い |
| 確認1 | JSONが1イベントとして正しい構造か |
| 確認2 | `eventName`がFilter Pattern内の値と完全一致しているか |
| 確認3 | 4.7では`eventSource`が`kms.amazonaws.com`になっているか |
| 確認4 | 余計な引用符、全角文字、改行の扱いに問題がないか |
| 対応 | 最小JSONで再テストする |

最小JSON例:

```json
{"eventName":"UpdateTrail"}
```

```json
{"eventSource":"kms.amazonaws.com","eventName":"DisableKey"}
```

### 7.7 Metric Filterは作成できたがMetricが出ない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | 対象イベントが作成後に発生していない、ログ未到達、Metric生成遅延 |
| 注意 | Metric Filterは過去ログをさかのぼってMetric化しない |
| 確認1 | Metric Filter作成後に対象イベントがLog Groupへ届いているか |
| 確認2 | Namespace、Metric Nameが想定どおりか |
| 確認3 | Default Value設定の有無 |
| 対応 | 作成後のログイベント到達を確認し、CloudWatch Metrics側で数分待つ |

### 7.8 Alarmが`INSUFFICIENT_DATA`のままになる

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | Metricデータポイントがまだない、対象イベント未発生 |
| 注意 | 作成直後の`INSUFFICIENT_DATA`は異常とは限らない |
| 確認1 | Metricが存在するか |
| 確認2 | Period、Statistic、Namespace、Metric Nameが一致しているか |
| 確認3 | Treat missing dataが`notBreaching`か |
| 対応 | Metric到達後にAlarm状態を再確認する |

### 7.9 Alarmは発火したが通知が届かない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | SNS Topic誤り、Subscription未確認、Alarm Action無効、通知経路側の問題 |
| 確認1 | Alarm Actionに正しいSNS Topic ARNが指定されているか |
| 確認2 | Actions enabledになっているか |
| 確認3 | SNS SubscriptionがConfirmedまたは有効状態か |
| 確認4 | メール、チャット、監視基盤側で受信できているか |
| 対応 | 通知先担当者へ時刻、Alarm名、Topic名を伝え、受信ログを確認する |

### 7.10 通知が二重に届く

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | 既存EventBridge / A-gate通知と新規Alarm通知が重複 |
| 確認1 | 同じイベントをEventBridgeで拾っていないか |
| 確認2 | 既存通知基盤側の判定条件に該当していないか |
| 確認3 | SNS Topicが複数経路から呼ばれていないか |
| 対応 | 新規Alarmを残すか、既存通知基盤対応済みとして扱うか判断者へ確認する |

### 7.11 A-gate / EventBridgeの既存通知が飛ばない

| 確認項目 | 内容 |
| :--- | :--- |
| 想定原因 | イベントは発生しているが、既存通知基盤側の違反判定に該当していない |
| 確認1 | EventBridge RuleのEvent Patternに一致するイベントか |
| 確認2 | Targetへ送信されているか |
| 確認3 | 既存通知基盤側の判定条件に該当するか |
| 確認4 | 通知先で受信しているか |
| 対応 | 「イベント発生 = 通知」ではなく「判定条件該当 = 通知」として扱い、判定条件を確認する |

## 8. 切り戻し観点

切り戻し対象は、今回作成または変更したものに限定する。

| 対象 | 切り戻し内容 |
| :--- | :--- |
| CloudWatch Alarm | 今回作成したAlarmを削除またはAction無効化 |
| Metric Filter | 今回作成したMetric Filterを削除 |
| CloudTrail -> CloudWatch Logs連携 | 連携追加が問題原因の場合のみ、承認後に変更前状態へ戻す |
| IAM Role | 今回新規作成したRoleのみ削除検討。既存Roleは削除しない |
| SNS Topic | 削除しない |
| EventBridge Rule | 既存Ruleは削除しない |
| Log Group | 削除しない |

切り戻し前に、以下を確認する。

- 切り戻し判断者の承認
- 変更前エビデンス
- 今回作成したリソース名
- 通知先への作業連絡
- 切り戻し後の確認手順

## 9. エスカレーション基準

以下に該当する場合、作業を止めてリーダーまたは判断者へ確認する。

- 作業アカウントが想定環境と異なる
- CloudTrail -> CloudWatch Logs連携を保存できない
- IAM Roleが自動設定されず、Role ARNが空のままになる
- CloudTrail配信エラーが出る
- 既存SNS Topicの通知先が不明
- 既存EventBridge / A-gate通知との重複が疑われる
- 本物のKMSキーでテストする必要が出た
- Trail停止またはKMS無効化など危険操作が必要になった
- 通知が想定外の宛先へ届いた
- 手順書と画面表示が大きく異なる

## 10. レビュー時に説明する要点

レビューでは以下を説明する。

```text
4.5 / 4.7は監視設定追加であり、業務アプリケーションへの直接変更ではない。
ただし、CloudTrail -> CloudWatch Logs連携が未設定であるため、Metric Filter方式の前提として連携設定が必要である。

24日の検証では、まずCloudTrailからCloudWatch Logsへイベントが届くことを確認し、その後Metric Filter、Alarm、通知先の順に確認する。

テストでは、Trail停止や本物のKMSキー無効化などの危険操作は行わない。
構文確認はPattern Testまたはlogs:TestMetricFilterで実施し、権限不足の場合はエラーを証跡として残す。
```

## 11. 当日確認チェックリスト

| No. | 確認 | 結果 |
| :--- | :--- | :--- |
| 1 | 作業用アカウントでログインできる | 未確認 |
| 2 | 対象アカウント、対象リージョンが正しい | 未確認 |
| 3 | 対象Trailが正しい | 未確認 |
| 4 | Management Eventが記録対象である | 未確認 |
| 5 | CloudWatch Logs連携を追加してよい | 未確認 |
| 6 | Log Groupが確定している | 未確認 |
| 7 | CloudTrail配信用IAM Roleが確認できる | 未確認 |
| 8 | CloudWatch Logsへイベントが到達する | 未確認 |
| 9 | Metric FilterのPattern Testが成功する | 未確認 |
| 10 | Metric Filter作成後に一覧で確認できる | 未確認 |
| 11 | Alarm作成後に設定値が確認できる | 未確認 |
| 12 | SNS TopicとSubscriptionが確認できる | 未確認 |
| 13 | 通知到達確認者が確認できる | 未確認 |
| 14 | 切り戻し手順と判断者が確認できる | 未確認 |
