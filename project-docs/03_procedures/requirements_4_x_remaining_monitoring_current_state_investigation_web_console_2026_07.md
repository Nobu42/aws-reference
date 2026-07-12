# 要件4番台 残り監視項目 一括現状調査手順書 Webコンソール版

作成日: 2026-07-10

この手順書は、要件4.8「S3バケットポリシー変更監視」の現状確認後に、要件4.1〜4.7、4.9〜4.15の監視設定をAWS Management Consoleでまとめて現状調査するための手順である。

最初に共有された評価シート由来のテキスト情報を正とし、元要件では「CloudTrailをCloudWatch Logsに連携し、Metric FilterおよびCloudWatch Alarmで発報する」方針として扱う。
EventBridge、GuardDuty、既存監視基盤は、既存監視、別アカウント連携、重複通知、代替監視の確認観点として扱う。
本手順は現状調査用であり、設定変更は行わない。

## 1. 背景

要件4.8の現状確認では、おおよそ監査指摘どおりであることに加えて、以下の既存設定が確認された。

| 確認できたこと | 残り4番台調査への影響 |
|---|---|
| `PutBucketPolicy` をEventBridgeで別アカウントへ送信している設定がある | 残り4番台でも、同様のEventBridge連携が既に存在しないか確認する |
| 既存通知設定としてメール通知がある | 新規通知先を検討する前に既存通知先を確認する |
| 既存通知設定としてTeams通知がある | 通知経路、運用担当、重複通知、テスト可否を確認する |
| GuardDutyの月次確認が既に運用されている可能性がある | GuardDutyでの確認実態と、即時通知不足を切り分ける |

## 2. 調査対象

4.8は現状確認済みのため、本手順では主に以下を対象とする。

| 要件番号 | 確認項目 | 主な確認観点 |
|---|---|---|
| 4.1 | 不正なAPI呼び出し監視 | `UnauthorizedOperation`、`AccessDenied` など |
| 4.2 | MFAなし管理コンソールサインイン監視 | `ConsoleLogin`、`MFAUsed = No` |
| 4.3 | rootアカウント使用監視 | `userIdentity.type = Root` |
| 4.4 | IAMポリシー変更監視 | IAM Policy作成、更新、削除、Attach、Detach |
| 4.5 | CloudTrail設定変更監視 | Trail作成、更新、停止、削除、Event Selector変更 |
| 4.6 | AWS Management Console認証失敗監視 | `ConsoleLogin = Failure` |
| 4.7 | カスタマー管理KMSキーの無効化・削除予約監視 | `DisableKey`、`ScheduleKeyDeletion` など |
| 4.9 | AWS Config設定変更監視 | Configuration Recorder、Delivery Channel、Config Rule変更 |
| 4.10 | Security Group変更監視 | Ingress/Egress許可、取消、Security Group作成・削除 |
| 4.11 | Network ACL変更監視 | NACL作成・削除、Entry変更、Association変更 |
| 4.12 | Network Gateway変更監視 | 元要件上はInternet Gateway、Customer Gatewayが中心。NAT Gateway、Transit Gateway、VPN Gatewayは現場確認のうえ対象に含める候補 |
| 4.13 | Route Table変更監視 | Route作成・削除・置換、Route Table関連付け変更 |
| 4.14 | VPC変更監視 | VPC作成・削除・属性変更、VPC Peering変更 |
| 4.15 | AWS Organizations変更監視 | Organization、OU、Account、Policy変更 |

補足:

- 4.2は、元資料上「MFAを強制している場合はこのメトリクス/アラーム設定は不要」とされているため、MFA強制の有無を現場側に確認する。
- 4.12は、元資料上はInternet GatewayまたはCustomer Gatewayの変更監視が中心である。NAT Gateway、Transit Gateway、VPN Gatewayまで含めるかは、対象システムの構成と監査側の意図を確認してから判断する。

## 3. 調査方針

```text
AWSアカウントとリージョンを確認する
  ↓
CloudTrailが対象イベントを記録できるか確認する
  ↓
CloudWatch Logs連携先を確認する
  ↓
Metric Filterがあるか確認する
  ↓
CloudWatch Alarmがあるか確認する
  ↓
SNS、メール、Teams通知先を確認する
  ↓
EventBridgeや別アカウント連携を確認する
  ↓
GuardDutyや既存月次確認で同等確認が行われていないか確認する
  ↓
要件ごとに対応済み / 不足 / 要確認 / 対象外を整理する
```

## 4. 事前に現場側へ確認すること

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 4.1〜4.15はCloudWatch Alarm方式で統一するのか | 元要件の方式と既存EventBridge方式の整合を取るため |
| 2 | 4.8で見つかったEventBridge別アカウント送信は正式な監視経路か | 同等監視として扱えるか判断するため |
| 3 | 別アカウント送信先の運用主体はどこか | 通知確認、証跡確認、問い合わせ先に必要 |
| 4 | 既存メール通知とTeams通知はどの要件で使うか | 新規通知先作成や重複通知を避けるため |
| 5 | GuardDuty月次確認は4番台の監視要件の一部として扱うのか | GuardDuty運用とCloudWatch Alarm通知の役割分担を整理するため |
| 6 | 通知テストを実施してよいか | メール/Teamsへ実通知が飛ぶ可能性があるため |
| 7 | 4.15のOrganizationsは管理アカウントで確認する必要があるか | 作業アカウント権限に影響するため |
| 8 | 監視対象イベントの範囲をどこまで含めるか | IAM、Gateway、VPC系はイベント種類が多いため |

## 5. 必要なドキュメント類

| ドキュメント | 必要な理由 |
|---|---|
| 監視設計書 | 既存のMetric Filter、Alarm、通知方式を確認する |
| CloudTrail設計書 | Trail、Management Event、CloudWatch Logs連携を確認する |
| CloudWatch Logs設計書 | CloudTrail連携先Log Group、保持期間、KMSを確認する |
| CloudWatch Alarm一覧 | 既存Alarmと通知Actionを確認する |
| SNS Topic / Subscription一覧 | メール、Teams、監視基盤への通知経路を確認する |
| EventBridge Rule一覧 | 別アカウント送信、既存通知、自動対応を確認する |
| GuardDuty運用資料 | 月次確認、Finding確認、通知連携、対応記録を確認する |
| 運用手順書 | アラート発生後の確認、記録、エスカレーション先を確認する |
| 証跡保存ルール | 画面キャプチャや確認結果の保存先を確認する |

## 6. AWSアカウントとリージョンを確認する

1. AWS Management Consoleへログインする。
2. 画面右上のアカウント表示を確認する。
3. 対象AWSアカウントであることを確認する。
4. 画面右上のリージョンを確認する。
5. 対象リージョンを選択する。

取得する証跡:

- アカウント表示が分かる画面
- リージョン表示が分かる画面

注意:

- IAM、CloudTrail、Organizationsなど、グローバルサービスに近いイベントは、TrailのHome Regionや管理アカウント側の確認が必要な場合がある。

## 7. CloudTrailの記録状態を確認する

目的:
4番台の監視対象イベントがCloudTrailで記録される前提を満たしているか確認する。

手順:

1. AWS Consoleの検索欄で `CloudTrail` を開く。
2. 左側メニューから `証跡` または `Trails` を開く。
3. 対象Trailを選択する。
4. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Trail名 | 対象Trailか |
| Home Region | 詳細確認するリージョン |
| Multi-Region | 全リージョン対象か |
| Organization Trail | Organizations配下のTrailか |
| Management events | 有効か |
| Read/Write events | Writeイベントを記録するか |
| Event selectors | 対象イベントが除外されていないか |
| CloudWatch Logs | 連携先Log Groupがあるか |

取得する証跡:

- Trail詳細画面
- Management events設定画面
- Event selectors設定画面
- CloudWatch Logs連携設定画面

判定:

| 状態 | 判断 |
|---|---|
| Management eventsが有効 | 4番台の前提を満たす候補 |
| Write eventsが記録対象 | 設定変更イベントを記録できる |
| CloudWatch Logs連携あり | Metric Filter/Alarm方式へ進める |
| CloudWatch Logs連携なし | 4番台の発報設定の前提不足 |

## 8. CloudWatch Logs連携先を確認する

目的:
Metric Filterを確認する対象Log Groupを特定する。

手順:

1. CloudTrailの対象Trail詳細画面で `CloudWatch Logs` の連携先Log Groupを確認する。
2. AWS Consoleの検索欄で `CloudWatch` を開く。
3. 左側メニューから `ログ` -> `ロググループ` を開く。
4. CloudTrail連携先Log Groupを開く。
5. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Log Group名 | CloudTrail連携先か |
| Log Group class | Metric Filter利用対象か |
| Retention | 保持期間 |
| KMS | CloudWatch Logs側の暗号化キー |
| Log Stream | CloudTrailイベントが届いているか |
| Stored bytes | ログ蓄積の目安 |

取得する証跡:

- Log Group詳細画面
- Log Stream一覧
- RetentionやKMS設定が分かる画面

## 9. Metric Filterを確認する

目的:
4番台の監視条件がMetric Filterとして既に存在するか確認する。

手順:

1. CloudWatchの `ロググループ` を開く。
2. CloudTrail連携先Log Groupを選択する。
3. `Metric filters` または `メトリクスフィルター` タブを開く。
4. 4.1〜4.7、4.9〜4.15に関係するFilterがあるか確認する。
5. 該当Filterを開き、Filter patternとMetricを確認する。

探すキーワード例:

| 要件 | 探す文字列 |
|---|---|
| 4.1 | `UnauthorizedOperation`, `AccessDenied` |
| 4.2 | `ConsoleLogin`, `MFAUsed`, `No` |
| 4.3 | `Root` |
| 4.4 | `PutUserPolicy`, `AttachRolePolicy`, `CreatePolicy`, `DeletePolicy` |
| 4.5 | `CreateTrail`, `UpdateTrail`, `DeleteTrail`, `StopLogging`, `PutEventSelectors` |
| 4.6 | `ConsoleLogin`, `Failure` |
| 4.7 | `DisableKey`, `ScheduleKeyDeletion` |
| 4.9 | `ConfigurationRecorder`, `DeliveryChannel`, `ConfigRule` |
| 4.10 | `SecurityGroup`, `AuthorizeSecurityGroup`, `RevokeSecurityGroup` |
| 4.11 | `NetworkAcl` |
| 4.12 | `InternetGateway`, `CustomerGateway`。必要に応じて `NatGateway`, `TransitGateway`, `VpnGateway` も現場確認する |
| 4.13 | `Route`, `RouteTable` |
| 4.14 | `Vpc`, `VpcPeering` |
| 4.15 | `Organizations`, `CreateOrganization`, `MoveAccount`, `AttachPolicy` |

取得する証跡:

- Metric Filter一覧
- 該当Filter詳細
- Filter pattern
- Metric namespace / Metric name

判定:

| 状態 | 判断 |
|---|---|
| 対象Filterあり | Alarmと通知先を確認する |
| 類似Filterあり | 対象イベントと通知先を確認し、重複作成を避ける |
| Filterなし | 監視設定不足の可能性 |

## 10. CloudWatch Alarmを確認する

目的:
Metric FilterのMetricに対してAlarmが設定されているか確認する。

手順:

1. CloudWatchの左側メニューから `アラーム` -> `すべてのアラーム` を開く。
2. 要件に関係するAlarm名やMetric名で検索する。
3. 該当Alarmを開く。
4. 以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Alarm名 | 監視対象が分かる名称か |
| State | OK / ALARM / INSUFFICIENT_DATA |
| Metric | Metric FilterのMetricか |
| Statistic | 通常はSum等 |
| Period | 評価期間 |
| Threshold | しきい値 |
| Actions enabled | 通知Actionが有効か |
| Alarm action | SNS等の通知先 |
| Alarm history | 過去の発報履歴 |

取得する証跡:

- Alarm一覧
- Alarm詳細
- Alarm action設定
- Alarm history

判定:

| 状態 | 判断 |
|---|---|
| Alarmあり、Action有効 | 通知先を確認する |
| Alarmあり、Action無効 | 発報しないため要改善候補 |
| Alarmなし | 発報設定不足の可能性 |

## 11. SNS、メール、Teams通知を確認する

目的:
既存の通知先と通知経路を確認し、重複通知や通知漏れを避ける。

手順:

1. Alarm詳細の `通知` または `Actions` を確認する。
2. SNS Topic名または通知先を確認する。
3. AWS Consoleの検索欄で `SNS` を開く。
4. `Topics` を開く。
5. 該当Topicを選択する。
6. `Subscriptions` を確認する。
7. メール、Teams、Webhook、Lambda、監視基盤らしきSubscriptionがないか確認する。

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Topic名 | 既存通知先か |
| Subscription protocol | email, https, lambda等 |
| Endpoint | メール、Teams、監視基盤等 |
| Status | Confirmedか |
| Topic policy | CloudWatch AlarmからPublishできるか |

取得する証跡:

- SNS Topic詳細
- Subscription一覧
- Alarm Actionとの対応が分かる画面

注意:

- メールアドレスやWebhook URLが画面に出る場合は、証跡のマスキング方針を確認する。
- Teams通知はSNSから直接ではなく、Lambda、Webhook、EventBridge、外部監視基盤経由の場合もある。

## 12. EventBridgeの既存連携を確認する

目的:
4.8で見つかった別アカウント送信と同様に、残り4番台でも既存EventBridge Ruleがないか確認する。

手順:

1. AWS Consoleの検索欄で `EventBridge` を開く。
2. 左側メニューから `Event buses` を開く。
3. `default` および関係しそうなEvent Busを確認する。
4. 左側メニューから `Rules` を開く。
5. CloudTrail、GuardDuty、Security、IAM、VPC、KMS、Config等に関係するRuleを探す。
6. 該当Ruleを開き、以下を確認する。

| 確認項目 | 見る内容 |
|---|---|
| Rule名 | 監視対象が分かる名称か |
| Event bus | defaultか、カスタムEvent Busか |
| State | Enabledか |
| Event pattern | 対象イベントを拾うか |
| Target | SNS、Lambda、別アカウントEvent Bus、監視基盤等 |
| Target ARN | 別アカウント送信か |
| Input transformer | 通知内容を加工しているか |

取得する証跡:

- Event Bus一覧
- Rule一覧
- 該当Rule詳細
- Event pattern
- Target一覧

判定:

| 状態 | 判断 |
|---|---|
| EventBridgeで同等監視あり | CloudWatch Alarm方式と同等として扱えるか確認 |
| 別アカウント送信あり | 送信先、運用主体、証跡保存先を確認 |
| CloudWatch AlarmもEventBridgeもあり | 重複通知の可能性を確認 |
| どちらもなし | 監視不足の可能性 |

## 13. GuardDutyの既存確認状況を確認する

目的:
評価シート上で言及されているGuardDutyの月次確認や既存運用が、4番台の監視要件にどの程度対応しているか確認する。

手順:

1. AWS Consoleの検索欄で `GuardDuty` を開く。
2. 対象リージョンを確認する。
3. `設定` または `Settings` でDetectorの有効状態を確認する。
4. 左側メニューの `保護プラン`、`使用状況`、`検出結果` を確認する。
5. `検出結果` で未アーカイブFindingがあるか確認する。
6. SeverityやFinding Typeを確認する。
7. GuardDuty FindingがEventBridgeや通知先へ連携されているか確認する。

確認する項目:

| 項目 | 見る内容 |
|---|---|
| Detector status | GuardDutyが有効か |
| Finding publishing frequency | Finding反映頻度 |
| Protection plan / Feature | CloudTrail、DNS、Flow Logs、S3、RDS等の有効状態 |
| Findings | 未アーカイブFinding、高Severity Finding |
| EventBridge連携 | Finding通知Ruleがあるか |
| 運用記録 | 月次確認資料や対応記録があるか |

取得する証跡:

- GuardDuty設定画面
- 保護プランまたは使用状況画面
- 検出結果一覧
- Finding詳細
- EventBridge連携が分かる画面

判定:

| 状態 | 判断 |
|---|---|
| GuardDuty有効、月次確認のみ | A3/A4の運用証跡には使えるが、4番台の即時通知不足は残る可能性 |
| GuardDuty有効、EventBridge/SNS通知あり | 通知経路と対象Findingを確認し、4番台要件との対応関係を整理 |
| GuardDuty無効 | A3/A4および脅威検知運用として不足の可能性 |
| Finding確認記録なし | A4の運用証跡が不足している可能性 |

## 14. CloudTrail Event Historyで過去イベントを確認する

目的:
対象イベントが実際に過去に発生しているか、CloudTrailで検索できるか確認する。

手順:

1. CloudTrailを開く。
2. 左側メニューから `イベント履歴` または `Event history` を開く。
3. 検索属性で `イベント名` または `Event name` を選択する。
4. 要件ごとの代表イベントを検索する。
5. 期間を必要に応じて絞る。
6. イベント詳細を開き、以下を確認する。

| 項目 | 見る内容 |
|---|---|
| Event time | 発生日時 |
| Event name | 対象イベントか |
| Username / Role | 実行主体 |
| Resource | 対象リソース |
| Source IP address | 操作元 |
| Event ID | 追跡用ID |

取得する証跡:

- Event history検索結果
- 代表イベントの詳細画面

注意:

- Event Historyは監視設定そのものではなく、過去イベント確認に使う。
- イベントが出ない場合、変更が発生していないだけの可能性もある。

## 15. 調査結果のまとめ表

以下をExcel等に転記して整理する。

```tsv
要件番号	監視対象	CloudTrail記録前提	CloudWatch Logs連携	Metric Filter	CloudWatch Alarm	通知Action	EventBridge/別アカウント連携	GuardDuty/既存運用	既存通知先	判定	不足/確認事項
4.1	不正API呼び出し	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.2	MFAなしConsoleLogin	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.3	root使用	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.4	IAMポリシー変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.5	CloudTrail設定変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.6	Console認証失敗	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.7	CMK無効化/削除予約	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.9	AWS Config設定変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.10	Security Group変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.11	Network ACL変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.12	Network Gateway変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.13	Route Table変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.14	VPC変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
4.15	AWS Organizations変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未記入
```

判定の目安:

| 判定 | 意味 |
|---|---|
| 対応済み | Metric Filter/Alarm/通知、または承認済み同等監視が確認できた |
| 一部対応 | 記録やFilterはあるが、Alarmや通知など一部不足 |
| 不足 | 監視設定が確認できない |
| 要確認 | EventBridgeやGuardDuty等の代替監視があるが、要件充足として認めるか未確認 |
| 対象外 | サービス未利用など、関係者確認のうえ対象外と判断 |

## 16. 最低限必要な参照権限

Webコンソールで参照する場合も、作業アカウントには以下相当の参照権限が必要。

| サービス | 主な参照権限 |
|---|---|
| CloudTrail | Trail、Event Selector、Event Historyの参照 |
| CloudWatch Logs | Log Group、Metric Filter、Log Streamの参照 |
| CloudWatch | Alarm、Alarm historyの参照 |
| SNS | Topic、Subscription、Topic policyの参照 |
| EventBridge | Event Bus、Rule、Target、Event patternの参照 |
| GuardDuty | Detector、Protection Plan、Findings、Finding statisticsの参照 |
| Organizations | Organization、Account、OU、Policyの参照 |

## 17. 完了条件

以下を満たしたら、4.8以外の4番台現状調査は完了とする。

- CloudTrailがManagement Eventを記録できる状態か確認済み
- CloudWatch Logs連携先Log Groupを確認済み
- 既存Metric Filterを確認済み
- 既存CloudWatch Alarmを確認済み
- Alarm ActionとSNS通知先を確認済み
- メール/Teamsなど既存通知経路を確認済み
- EventBridge RuleとTargetを確認済み
- GuardDuty Detector、Feature、Finding、既存運用記録を確認済み
- 別アカウント送信がある場合、送信先と運用主体の確認事項を整理済み
- 要件4.1〜4.7、4.9〜4.15ごとに、対応済み/不足/要確認/対象外を整理済み

## 18. 参考

- AWS CloudTrail: Sending events to CloudWatch Logs
  - English: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
- Amazon CloudWatch Logs: Creating metrics from log events using filters
  - English: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html
- Amazon EventBridge: Event patterns
  - English: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-patterns.html
- Amazon GuardDuty User Guide
  - English: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/what-is-guardduty.html
