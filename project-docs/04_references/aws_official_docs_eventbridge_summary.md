# AWS公式ドキュメント EventBridge要約

作成日: 2026-07-12

この資料は、AWS公式ドキュメントをもとに、Amazon EventBridgeを現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. Amazon EventBridgeとは

Amazon EventBridgeは、イベントをもとにAWSサービス、アプリケーション、SaaS、別アカウントなどを連携するためのサーバーレスイベントルーティングサービスである。

現場では、EventBridgeを次の用途で見ることが多い。

- AWSサービスの状態変更を検知する
- CloudTrail由来のAPI操作イベントを検知する
- 検知したイベントをSNS、Lambda、SQS、Step Functions、別アカウントのイベントバスなどへ送る
- 既存の通知・自動対応・SIEM連携がないか確認する
- CloudWatch Alarmによる通知と重複していないか確認する

今回のクラウドセキュリティ対応では、EventBridgeは「正式要件名として前面に出るサービス」というより、CloudTrailやGuardDutyの検知結果を通知・連携する経路として重要である。

## 2. 基本構成

EventBridgeの主な構成要素は以下である。

| 要素 | 意味 | 現場での確認観点 |
| :--- | :--- | :--- |
| Event | AWS環境やアプリケーションで発生した変化や操作を表すデータ | 何が発生したか |
| Event Bus | イベントを受け取り、Ruleに従ってTargetへ配信するルーター | どのバスで受けているか |
| Rule | Event Patternまたはスケジュールに基づき、イベントをTargetへ送る設定 | 何を検知しているか |
| Event Pattern | Ruleが一致判定に使うJSON条件 | 対象イベントを正しく絞れているか |
| Target | Ruleに一致したイベントの送信先 | 通知先・連携先・自動対応先 |
| Input Transformer | Targetへ渡すイベント内容を加工する設定 | 通知文面や連携形式 |
| Retry Policy | Target配信失敗時の再試行設定 | 配信失敗時の扱い |
| DLQ | 配信失敗イベントを保持するSQSキュー | 失敗イベントを追跡できるか |

基本の流れ:

```text
AWS操作・AWSサービスイベント
  -> EventBridge Event Bus
  -> Rule
  -> Event Patternで一致判定
  -> Targetへ送信
  -> SNS / Lambda / SQS / Step Functions / 別アカウントEvent Busなど
```

## 3. Event Bus

Event Busは、イベントを受け取り、関連付けられたRuleで評価し、条件に一致したイベントをTargetへ送る。

主な種類:

| 種類 | 意味 | 現場での扱い |
| :--- | :--- | :--- |
| Default event bus | AWSサービスからのイベントを受け取る標準バス | CloudTrail由来イベントの確認で重要 |
| Custom event bus | 独自アプリケーションや用途別に作成するバス | 独自連携、別アカウント連携で確認 |
| Partner event bus | SaaSパートナー連携用のバス | 外部サービス連携がある場合に確認 |

現場での確認ポイント:

- どのEvent BusにRuleが作られているか
- Default event busにCloudTrail由来のRuleがあるか
- Custom event busへ転送するRuleがあるか
- 別アカウントEvent BusへのTargetがあるか
- Event Busにリソースベースポリシーが設定されているか

## 4. Rule

Ruleは、Event Busに届いたイベントを評価し、条件に一致したイベントをTargetへ送る設定である。

Ruleには大きく2種類ある。

| 種類 | 説明 | 注意点 |
| :--- | :--- | :--- |
| Event Pattern Rule | イベント内容に一致した場合に起動する | 監視・通知で主に使用する |
| Scheduled Rule | cronまたはrateで定期実行する | 公式ではスケジュール用途はEventBridge Scheduler推奨 |

現場で確認する項目:

| 項目 | 確認理由 |
| :--- | :--- |
| Rule名 | 監視対象や用途を識別する |
| Event Bus | どのイベントを評価しているか確認する |
| State | 有効、無効、CloudTrail Readイベント対応状態を確認する |
| Event Pattern | 検知条件が要件と一致しているか確認する |
| Target | 通知先、自動対応先、別アカウント連携先を確認する |
| IAM Role | Target呼び出し権限を確認する |
| Retry / DLQ | 配信失敗時にイベントを追えるか確認する |
| Tags | 管理者、用途、環境、変更管理番号などを確認する |

## 5. Event Pattern

Event Patternは、Ruleがどのイベントに一致するかを定義するJSON条件である。

Event Patternは、イベント本体と同じ構造に近い形で記述する。イベントがPatternに一致した場合、EventBridgeはTargetへイベントを送る。

CloudTrail由来のS3バケットポリシー変更を検知する例:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutBucketPolicy", "DeleteBucketPolicy"]
  }
}
```

現場での注意点:

- `source`、`detail-type`、`detail.eventSource`、`detail.eventName`を確認する
- CloudTrailのEventNameと完全に一致しているか確認する
- 対象アカウントを絞る場合は`account`を使う
- 対象リージョンを絞る場合は`region`を使う
- 対象リソースを絞る場合はCloudTrailイベント内の`resources`または`detail.requestParameters`を確認する
- 広すぎるPatternは不要な通知や料金増加につながる
- 自動修復系のTargetを持つRuleでは、無限ループに注意する

公式ドキュメントでは、Rule作成・更新前にEventBridge SandboxでEvent Patternをテストできると説明されている。

## 6. CloudTrailイベントとの関係

CloudTrailは、AWS API CallなどのイベントをEventBridgeに送る。

CloudTrail由来イベントの代表的な`detail-type`:

| detail-type | 意味 |
| :--- | :--- |
| `AWS API Call via CloudTrail` | AWS APIコールを表すイベント |
| `AWS Console Signin via CloudTrail` | AWSマネジメントコンソールへのサインイン試行 |
| `AWS Console Action via CloudTrail` | コンソールで実行されたAPIではない操作 |
| `AWS Service Event via CloudTrail` | AWSサービスによって作成されたイベント |
| `AWS Insight via CloudTrail` | CloudTrail Insightsイベント |
| `AWS Network Activity Event via CloudTrail` | VPC Endpoint経由APIコールなどのネットワークアクティビティイベント |

重要な確認点:

- CloudTrailイベントはDefault event busに配信される
- Custom event busで処理したい場合は、Default event busからCustom event busへ転送するRuleが必要
- 書き込み系Management Eventは通常の有効Ruleで一致する
- 読み取り系Management EventをEventBridgeで受けるには、Rule状態に注意が必要である
- Data Eventを扱う場合は、CloudTrail側で対象Data Eventを記録する設定が必要である
- Network Activity Eventを扱う場合は、CloudTrail側のネットワークアクティビティイベントセレクタとVPC Endpoint経由APIコールが関係する

今回の4番台監視では、多くがCloudTrail Management Eventを起点にした監視である。

## 7. CloudWatch Alarmとの違い

EventBridgeとCloudWatch Alarmはどちらも通知や連携に使えるが、役割が異なる。

| 項目 | EventBridge | CloudWatch Alarm |
| :--- | :--- | :--- |
| 主な入力 | イベント | メトリクス |
| 判定方法 | Event Patternに一致するか | メトリクスがしきい値を超えるか |
| 代表用途 | AWS API操作、GuardDuty Finding、状態変更の即時連携 | CPU、エラー数、Metric Filter検知件数の監視 |
| 通知経路 | Targetへ送信 | Alarm ActionでSNSなどへ通知 |
| 確認観点 | Rule、Pattern、Target、Role、DLQ | Metric、しきい値、評価期間、Action |

今回の監視では、次の2系統があり得る。

```text
CloudTrail -> CloudWatch Logs -> Metric Filter -> Metric -> CloudWatch Alarm -> SNS
```

```text
CloudTrail -> EventBridge Rule -> SNS / Lambda / 別アカウントEvent Bus
```

既存EventBridge Ruleがある場合、新規CloudWatch Alarmを追加すると通知が重複する可能性がある。既存通知経路の確認が重要である。

## 8. Target

Targetは、Ruleに一致したイベントの送信先である。

代表的なTarget:

| Target | 用途 | 現場での確認観点 |
| :--- | :--- | :--- |
| SNS Topic | メール、Chatbot、Teams連携などの通知 | 購読先、通知重複、承認 |
| Lambda | 通知加工、自動対応、外部連携 | 実行内容、権限、影響 |
| SQS | 後続処理、キューイング | DLQとの違い、処理者 |
| Step Functions | ワークフロー実行 | 自動対応範囲、承認要否 |
| Systems Manager Automation | 自動修復 | 業務影響が大きいため要注意 |
| EventBridge event bus | 同一または別アカウントへの転送 | クロスアカウント設定、送信先責任範囲 |
| CloudWatch Logs log group | イベントのログ保管 | 調査用ログとして扱えるか |
| API Destination | HTTPSエンドポイント連携 | 認証、送信先、外部連携 |

Target確認で重要な点:

- Targetが通知だけか、自動変更を行うものか確認する
- LambdaやSSM Automationがある場合、実際に何を変更するか確認する
- 別アカウントEvent BusがTargetの場合、送信先アカウント、送信先リージョン、Event Bus ARNを確認する
- Target追加・変更後、反映まで少し時間がかかる場合がある
- 1つのRuleに複数Targetがある場合、すべての通知・連携先を確認する

## 9. IAM Roleと権限

EventBridgeがTargetを呼び出すには、Targetの種類に応じた権限が必要である。

確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| Ruleに設定されたRole ARN | EventBridgeがTargetを呼び出すため |
| RoleのTrust Policy | `events.amazonaws.com` がAssumeRoleできるか |
| RoleのPermissions Policy | Target呼び出しに必要なActionがあるか |
| Target側Resource Policy | SNS、SQS、Event Busなどで許可が必要な場合がある |
| クロスアカウントRole | 別アカウントEvent Busへ送る場合に必要な場合がある |

クロスアカウントEvent Bus Targetでは、送信側RuleのIAM Role、受信側Event Busのリソースベースポリシー、Organizationsまたはアカウント単位の許可を確認する。

## 10. クロスアカウント連携

EventBridgeは、別AWSアカウントのEvent Busへイベントを送信できる。

基本構成:

```text
送信元アカウント
  EventBridge Rule
  Target: 送信先アカウントのEvent Bus ARN
  IAM Role: events.amazonaws.com がAssumeRole

送信先アカウント
  Event Bus Resource Policy
  受信イベントに一致するRule
  Target: SNS / Lambda / SIEMなど
```

現場での確認ポイント:

- 送信元アカウントID
- 送信先アカウントID
- 送信先Event Bus ARN
- 送信元Rule名
- 送信元RuleのTarget
- 送信元RuleのIAM Role
- 送信先Event BusのResource Policy
- 送信先側RuleとTarget
- Organizations単位の許可か、個別アカウント許可か
- 通知先やSIEM連携が送信先側にあるか

公式ドキュメントでは、別アカウントからイベントを受信する場合、Event Busのアクセス許可をリソースベースポリシーで制御すると説明されている。

注意点:

- 送信元から別アカウントに送ったイベントは、さらに第三のアカウントへ転送されない制約がある
- 受信側で広い許可をしている場合、Event Patternに`account`を入れて想定外アカウントのイベントを除外する
- クロスアカウントイベントは送信側に課金される

## 11. Retry PolicyとDLQ

EventBridgeは、Targetへのイベント配信に失敗した場合、再試行を行う。

公式ドキュメントでは、デフォルトで最大24時間、最大185回、指数バックオフとジッタを使って再試行すると説明されている。

確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| Maximum age of event | どのくらい古いイベントまで再試行するか |
| Retry attempts | 何回再試行するか |
| DLQ | 配信失敗イベントを保存するか |
| DLQのSQS Queue | どこに失敗イベントが残るか |
| DLQ権限 | EventBridgeがSQSへ送信できるか |
| CloudWatch Metrics | FailedInvocationsなどを確認できるか |

DLQは、Targetに配信できなかったイベントをSQS標準キューへ退避する仕組みである。

DLQで確認できる主な情報:

- Rule ARN
- Target ARN
- Error Code
- Error Message
- Retry Attempts
- Retry上限に達した理由

現場での意味:

- 通知失敗や連携失敗を後から調査できる
- 重要なアラート連携ではDLQ有無を確認する価値がある
- DLQがない場合、再試行上限後にイベントが失われる可能性がある

## 12. GuardDutyとの関係

GuardDuty FindingはEventBridgeイベントとして扱える。

一般的な流れ:

```text
GuardDuty Finding
  -> EventBridge Rule
  -> SNS / Lambda / Incident Manager / Teams連携など
```

A3/A4のようなセキュリティアラート運用では、GuardDuty Findingの通知経路としてEventBridge Ruleが存在する可能性がある。

確認ポイント:

- GuardDuty Findingを対象にしたRuleがあるか
- Event PatternでSeverityやFinding Typeを絞っているか
- Targetが通知のみか、自動対応を含むか
- Sample Finding作成時に通知や自動対応が走らないか
- 既存の月次運用や手順書と即時通知が矛盾しないか

自動隔離、Security Group変更、IAM無効化などをTargetで行っている場合、業務影響が大きいため、検証Finding投入前に承認を取る。

## 13. 4番台監視での確認観点

4番台の監視要件では、CloudTrail APIイベントをEventBridgeで直接拾って通知している既存設定がある可能性がある。

確認する主なイベント例:

| 要件 | 代表イベント | EventBridge確認観点 |
| :--- | :--- | :--- |
| 4.1 Unauthorized API Calls | `errorCode`がAccessDenied系 | CloudWatch Logs側だけでなくEventBridge通知有無を確認する |
| 4.2 Console login without MFA | `ConsoleLogin`、`MFAUsed=No` | `AWS Console Signin via CloudTrail`のRule有無を確認する |
| 4.3 root account use | `userIdentity.type=Root` | root利用通知の既存Rule有無を確認する |
| 4.4 IAM Policy changes | `CreatePolicy`, `PutRolePolicy`など | IAM変更通知の対象範囲を確認する |
| 4.5 CloudTrail changes | `StopLogging`, `DeleteTrail`など | 監査証跡停止の即時通知があるか確認する |
| 4.7 CMK disable/delete | `DisableKey`, `ScheduleKeyDeletion` | KMSイベントのRule有無を確認する |
| 4.8 S3 Bucket Policy changes | `PutBucketPolicy`, `DeleteBucketPolicy` | 既存EventBridge送信先や重複通知を確認する |
| 4.9 Config changes | `PutConfigurationRecorder`, `StopConfigurationRecorder`など | AWS Config変更通知有無を確認する |
| 4.10 Security Group changes | `AuthorizeSecurityGroupIngress`など | ネットワーク変更通知有無を確認する |
| 4.11 NACL changes | `CreateNetworkAclEntry`など | NACL変更通知有無を確認する |
| 4.12 Network Gateway changes | Internet Gateway / Customer Gateway関連 | 正式要件の対象Gatewayを確認する |
| 4.13 Route Table changes | `CreateRoute`, `ReplaceRoute`, `DeleteRoute`など | Route Table変更通知有無を確認する |
| 4.14 VPC changes | `CreateVpc`, `DeleteVpc`, VPC Peering関連 | VPC変更通知有無を確認する |
| 4.15 Organizations changes | `CreateAccount`, `AttachPolicy`など | Organizations管理アカウント側の確認が必要 |

EventBridgeは、既存通知や別アカウント連携の確認対象として扱う。正式な方式がCloudWatch Alarmの場合でも、EventBridge側の既存Rule確認は重複防止のため重要である。

## 14. Webコンソールでの確認観点

Webコンソールで確認するときは、以下を見る。

EventBridge:

- Event Buses
- Rules
- Rule詳細
- Event Pattern
- Targets
- Retry policy
- Dead-letter queue
- Monitoring
- Permissions

Rule一覧で見る項目:

| 項目 | 見る理由 |
| :--- | :--- |
| Name | 監視対象を推測する |
| Event bus | Default busかCustom busか確認する |
| Status | 有効か無効か確認する |
| Event pattern | 何を検知しているか確認する |
| Target count | 複数通知や複数連携の有無を見る |
| Managed rule | AWSサービス管理Ruleか確認する |

Target詳細で見る項目:

- Target type
- Target ARN
- Role ARN
- Input transformer
- Retry policy
- DLQ
- 別アカウントEvent Bus ARN

画面上で不明なTargetがある場合は、勝手に変更せず、用途、管理者、通知先、作成経緯を確認する。

## 15. 現場での確認チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | Default event busのRule一覧 | CloudTrail由来イベントの既存通知を確認する |
| 2 | Custom event bus一覧 | 独自連携や別アカウント集約を確認する |
| 3 | CloudTrail関連Rule | 4番台監視と重複する可能性がある |
| 4 | GuardDuty関連Rule | A3/A4運用通知と関係する |
| 5 | Target一覧 | 通知先、自動対応、別アカウント送信を確認する |
| 6 | SNS Target | 既存メール、Teams通知と関係する |
| 7 | Lambda / SSM Target | 自動変更や業務影響の可能性を確認する |
| 8 | 別アカウントEvent Bus Target | 監視集約・SIEM連携の可能性を確認する |
| 9 | IAM Role | Target呼び出し権限を確認する |
| 10 | DLQ | 配信失敗時の追跡可否を確認する |
| 11 | Managed Rule | 他サービス依存のRuleを誤って変更しないため |
| 12 | CloudWatch Metrics | FailedInvocationsなどの失敗有無を確認する |
| 13 | Event Patternの広さ | 通知過多、料金増、誤検知を避ける |

## 16. 料金で注意する点

EventBridgeの料金は、主にイベント数や機能利用に関係する。

注意するもの:

- Custom event
- Cross-account event
- API Destination
- Pipes
- Scheduler
- Archive / Replay
- 大量イベントを拾う広いRule
- ループするRule

今回の用途では、CloudTrail由来の変更イベントを通知する程度であれば大きな費用になりにくい。ただし、Data Eventや大量のReadイベントを対象にする場合は、CloudTrail側の記録量、CloudWatch Logs取り込み量、EventBridgeイベント量を合わせて確認する。

## 17. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| EventBridgeはCloudWatch Alarmと同じ | EventBridgeはイベントルーティング、CloudWatch Alarmはメトリクス監視 |
| Ruleがあれば必ず通知される | Targetと権限、SNS購読、Teams連携などが必要 |
| EventBridgeだけ見ればCloudTrail監視は十分 | CloudTrail側の記録設定、CloudWatch Logs、Metric Filter、Alarmも確認する |
| TargetがSNSなら安全 | 通知先、購読状態、Teams連携、重複通知を確認する |
| Lambda Targetは通知だけ | Lambdaが自動変更を行う場合があるため内容確認が必要 |
| 別アカウントEvent Busはただの通知 | 監視集約、SIEM連携、別運用チームへの連携の可能性がある |
| Managed Ruleは消してよい | AWSサービス依存の可能性があり、削除は慎重に判断する |

## 18. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| EventBridgeとは | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-what-is.html |
| EventBridgeのイベント | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-events.html |
| Event Bus | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-bus.html |
| Rule | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-rules.html |
| Event Pattern | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-patterns.html |
| Target | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-targets.html |
| CloudTrail経由イベント | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-service-event-cloudtrail.html |
| クロスアカウントEvent Bus | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-cross-account.html |
| Retry Policy | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-rule-retry-policy.html |
| DLQ | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-rule-dlq.html |
| リソースベースポリシー | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-use-resource-based.html |
| アクセス許可リファレンス | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-permissions-reference.html |

### English

| 分類 | URL |
| :--- | :--- |
| What is EventBridge | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html |
| EventBridge events | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-events.html |
| Event buses | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-bus.html |
| Rules | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rules.html |
| Event patterns | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html |
| Targets | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html |
| CloudTrail events | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-event-cloudtrail.html |
| Cross-account event buses | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cross-account.html |
| Retry policy | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html |
| Dead-letter queues | https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-dlq.html |
