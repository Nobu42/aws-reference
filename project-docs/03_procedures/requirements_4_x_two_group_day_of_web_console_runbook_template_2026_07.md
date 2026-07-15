# 要件4番台 2グループ分割 当日Webコンソール作業手順書テンプレート

作成日: 2026-07-16

この資料は、要件4.1〜4.15のうち、既存EventBridge / A-gateで対応済みの要件を除外した残件について、当日作業を2グループに分けて実施するためのExcel貼り付け用テンプレートである。

Excel列は以下を想定する。

```text
要件番号	作業内容	作業にかかる時間	作業詳細	備考
```

## 1. 作業方針

| 区分 | 方針 |
| :--- | :--- |
| A-gate / EventBridge対応済み要件 | 新規Metric Filter / Alarmを作成しない。既存設定確認、通知経路確認、証跡取得、対応なし判断の記録に留める |
| 未対応要件 | CloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> 既存SNS Topicを基本案として設定する |
| 既存EventBridgeがあるが通知経路未確認の要件 | 受信側、A-gate側、通知先を確認し、対応なしにできるか判断する |
| 実イベントによる通知テスト | 作業承認、テスト承認、切り戻し手順が揃った場合のみ実施する |

## 2. グループ分け

実際の作業対象は、パラメータシートおよびA-gate / EventBridge突合結果で確定する。

| グループ | 対象候補 | 主な確認先 |
| :--- | :--- | :--- |
| グループA: 管理・認証・監査系 | 4.1、4.2、4.3、4.4、4.5、4.6、4.7、4.9 | CloudTrail、CloudWatch Logs、IAM、KMS、AWS Config、SNS、EventBridge |
| グループB: ネットワーク・組織系 | 4.10、4.11、4.12、4.13、4.14、4.15 | EC2、VPC、Security Group、NACL、Gateway、Route Table、Organizations、SNS、EventBridge |

4.8は既存EventBridge / A-gateで対応済みと判断された場合、新規設定対象から除外する。  
他の要件も同様に、A-gate側資料とEventBridge Ruleで要件番号が突合できたものは、当日設定作業ではなく対応なし記録の対象とする。

## 3. 共通作業

2グループの作業に共通する手順である。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	作業開始前の前提確認	15分	AWS Management Consoleへログインし、画面右上で対象アカウントと対象リージョンを確認する。対象CloudTrail名、CloudWatch Logs連携先Log Group名、既存SNS Topic名またはARN、作業対象要件、作業時間、作業承認、通知テスト可否、切り戻し判断者を確認する。	アカウント、リージョン、Log Group、通知先Topicを誤ると別環境または別通知先へ設定するため、最初に必ず確認する。
4.x	A-gate / EventBridge対応済み要件の除外確認	20分	A-gate側資料、EventBridge Rule一覧、要件番号突合資料を確認し、既存設定で対応済みの要件番号を作業対象から除外する。除外対象は要件番号、Rule名、イベントパターン、ターゲット、通知経路、証跡保存先を作業台帳に記録する。	対応なしは何もしないという意味ではない。既存設定確認と証跡取得をもって対応なし判断とする。
4.x	変更前エビデンス取得	30分	CloudTrail、CloudWatch Logs、CloudWatch Alarm、SNS、EventBridgeの関連画面を開き、変更前の状態をスクリーンショットで保存する。CloudTrailは対象Trail詳細、CloudWatch Logsは対象Log GroupとMetric Filter一覧、CloudWatchはAlarm一覧、SNSは対象TopicとSubscription一覧、EventBridgeは関連Rule一覧とTargetを取得する。	作業前後比較と切り戻しの基準になる。
4.x	CloudTrail設定確認	15分	CloudTrailコンソールを開き、「証跡」から対象Trailを選択する。Management Eventが記録対象であること、Read / Writeの対象範囲、CloudWatch Logs連携先Log Group、CloudWatch Logs Roleを確認する。	4番台はManagement Eventを前提とする。CloudWatch Logs未連携の場合は本作業前に方針確認が必要である。
4.x	CloudWatch Logs到達確認	10分	CloudWatchコンソールを開き、「ログ」から「ロググループ」を選択する。CloudTrail連携先Log Groupを開き、最新Log StreamまたはログイベントにCloudTrailイベントが届いていることを確認する。	ログが届いていない場合、Metric Filterを作成しても検知できない。
4.x	既存SNS Topic確認	10分	SNSコンソールを開き、「トピック」から既存通知Topicを選択する。「サブスクリプション」タブでメール、Teams連携、監視基盤連携などの通知先を確認し、状態がConfirmedまたは有効であることを確認する。	既存Topicは他用途で利用されている可能性があるため、Topic自体を削除しない。
4.x	既存EventBridge重複確認	20分	EventBridgeコンソールを開き、「イベントバス」から対象イベントバスを選択し、「ルール」を開く。CloudTrail、IAM、KMS、Config、SecurityGroup、NACL、Gateway、RouteTable、Organizationsなどの関連Ruleが存在するか確認する。対象Ruleがある場合はイベントパターン、ターゲット、別アカウント送信有無、通知先を確認する。	同等監視が既にある場合、新規Metric Filter / Alarmを追加すると二重通知になる可能性がある。
```

## 4. グループA 管理・認証・監査系

対象候補は4.1、4.2、4.3、4.4、4.5、4.6、4.7、4.9である。  
A-gate / EventBridge対応済みの要件は、この表から削除する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.1	不正なAPI呼び出し監視の設定	20分	CloudWatchコンソールで「ログ」からCloudTrail連携先Log Groupを開き、「メトリクスフィルター」タブで「メトリクスフィルターを作成」を選択する。AccessDenied系またはUnauthorizedOperation系のFilter Patternを入力し、サンプルログで一致確認する。Metric Namespace、Metric Name、Metric Valueを入力して作成する。続けてCloudWatchの「アラーム」から該当Metricを選択し、Sum、しきい値、欠損データの扱い、通知先に既存SNS Topicを指定する。	AccessDenied系は通常運用でも発生し得るため、しきい値と通知対象範囲を作業前に確認する。
4.2	MFAなしコンソールログイン監視の設定	20分	CloudWatch Logsの対象Log GroupでConsoleLogin成功かつMFAUsedがNoのイベントを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	MFA強制済みでも監査要件上の設定要否を確認する。不要判断の場合は根拠を残す。
4.3	rootアカウント使用監視の設定	20分	CloudWatch Logsの対象Log GroupでuserIdentity.typeがRootのイベントを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmで該当Metricを選択し、1件以上で既存SNS Topicへ通知する。	root利用は重要度が高いため、1件発報が基本である。
4.4	IAMポリシー変更監視の設定	25分	CloudWatch Logsの対象Log GroupでIAMのPolicy作成、削除、Version変更、Inline Policy変更、Attach、Detachを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	IAMユーザー、ロール、グループ変更まで含めるかは設計判断が必要である。
4.5	CloudTrail設定変更監視の設定	20分	CloudWatch Logsの対象Log GroupでCreateTrail、UpdateTrail、DeleteTrail、StartLogging、StopLogging、PutEventSelectors、PutInsightSelectorsを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	正当な復旧操作や設定変更でも通知されるため、通知後の確認手順を運用側で持つ。
4.6	コンソール認証失敗監視の設定	20分	CloudWatch Logsの対象Log GroupでConsoleLogin失敗を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	誤入力でも発生するため、1件発報か複数件発報かを作業前に確認する。
4.7	CMK無効化または削除予約監視の設定	20分	CloudWatch Logsの対象Log GroupでKMSのDisableKeyとScheduleKeyDeletionを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	鍵の無効化や削除予約は影響が大きいため、1件発報が基本である。
4.9	AWS Config変更監視の設定	20分	CloudWatch Logsの対象Log GroupでConfig Recorder、Delivery Channel、Config Ruleの作成、変更、削除を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	AWS Config未導入または一部環境のみの場合、対象範囲を確認する。
4-A	グループA通知テスト	30分	承認済みの方法で通知テストを実施する。実イベントを起こせる要件は承認済みの軽微な操作で確認する。実イベントを起こせない要件はMetric FilterのPattern Test、Alarm設定、SNS Topic、通知先受信状況を組み合わせて限定証跡として整理する。	IAM、KMS、CloudTrailは影響が大きいため、実変更テストは無理に行わない。
4-A	グループA通知受信確認	20分	メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。	通知確認者、確認時刻、証跡保存先を記録する。
4-A	グループA作業後エビデンス取得	30分	作成または変更したMetric Filter、CloudWatch Alarm、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。	作業前後比較、設定値、通知到達を証跡として残す。
```

## 5. グループB ネットワーク・組織系

対象候補は4.10、4.11、4.12、4.13、4.14、4.15である。  
A-gate / EventBridge対応済みの要件は、この表から削除する。  
ネットワーク系はインフラチームの変更管理、通信影響確認先、対象リソース範囲を作業前に確認する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.10	Security Group変更監視の設定	20分	CloudWatch Logsの対象Log GroupでSecurity GroupのIngress、Egress、作成、削除、ルール変更を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	通常変更でも通知されるため、変更管理番号との突合方法を確認する。
4.11	NACL変更監視の設定	20分	CloudWatch Logsの対象Log GroupでNetwork ACL作成、削除、Entry作成、削除、置換、関連付け変更を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmで既存SNS Topicへ通知する。	NACL変更は通信影響が大きいため、通知後の確認先を明確にする。
4.12	Network Gateway変更監視の設定	20分	CloudWatch Logsの対象Log Groupで正式資料に沿ってInternet GatewayとCustomer Gatewayの作成、削除、Attach、Detachを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	NAT Gateway、Transit Gateway、VPN Gatewayを含めるかは作業前に確認する。
4.13	Route Table変更監視の設定	20分	CloudWatch Logsの対象Log GroupでRoute作成、削除、置換、Route Table作成、削除、関連付け、関連付け解除、関連付け置換を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	通信経路変更の通知であるため、通知後の確認先を明確にする。
4.14	VPC変更監視の設定	20分	CloudWatch Logsの対象Log GroupでVPC作成、削除、属性変更、VPC Peeringの作成、承認、拒否、削除を対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	VPC EndpointやSubnet変更まで含めるかは作業前に確認する。
4.15	AWS Organizations変更監視の設定	20分	CloudWatch Logsの対象Log Groupでorganizations.amazonaws.comのイベントを対象にMetric Filterを作成する。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	Organizationsは管理アカウント側にイベントが出る可能性があるため、対象アカウントを作業前に確認する。
4-B	グループB通知テスト	30分	承認済みの方法で通知テストを実施する。ネットワーク系の実変更は通信影響があり得るため、原則として実変更ではなくPattern Test、既存ログ、Alarm設定、SNS Topic、通知先受信状況を組み合わせて確認する。実イベントを起こす場合はインフラチーム承認と切り戻し手順を事前に確定する。	SG、NACL、Route Table、Gateway、VPCは業務通信へ影響し得るため、無承認の実変更テストを行わない。
4-B	グループB通知受信確認	20分	メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。	通知確認者、確認時刻、証跡保存先を記録する。
4-B	グループB作業後エビデンス取得	30分	作成または変更したMetric Filter、CloudWatch Alarm、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。	作業前後比較、設定値、通知到達を証跡として残す。
```

## 6. 既存EventBridge / A-gate対応済み要件の対応なし記録

新規設定を行わない要件は、以下の形式で作業台帳または証跡一覧へ記録する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	既存EventBridge / A-gate対応済み確認	15分	A-gate側資料とEventBridge Ruleを確認し、要件番号、Rule名、イベントパターン、ターゲット、通知経路が対応していることを確認する。確認結果とスクリーンショットを証跡として保存する。	新規Metric Filter / Alarmは作成しない。
4.x	対応なし判断の記録	10分	既存EventBridge / A-gate設定により要件を満たすと判断した根拠を作業台帳へ記録する。記録内容は要件番号、既存設定名、通知経路、証跡保存先、判断者、確認日とする。	対応なしの理由を残さないと、未対応と誤認される可能性がある。
```

## 7. 共通切り戻し手順

CloudWatch Metric Filter / Alarm方式の切り戻しである。  
EventBridge方式の切り戻しは、既存Ruleを編集した場合のみ変更前エビデンスに従って戻す。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	切り戻し判断	10分	通知が想定どおり届かない、誤通知が多い、既存通知Topicへ想定外の通知が出る、Alarmが不要にALARMを継続する、または作業継続不可と判断された場合に切り戻しを開始する。	切り戻し判断者と連絡先を作業前に決めておく。
4.x	CloudWatch Alarm切り戻し	30分	CloudWatchコンソールで「アラーム」を開き、今回作成した4番台用Alarmを選択する。まずActionsを無効化できる場合は無効化し、その後、承認済み手順に従ってAlarmを削除する。既存Alarmを編集した場合は、変更前エビデンスを参照して元に戻す。	既存Alarmを誤って削除しない。削除対象は今回作成したAlarmに限定する。
4.x	Metric Filter切り戻し	30分	CloudWatch Logsで対象Log Groupを開き、「メトリクスフィルター」タブから今回作成した4番台用Metric Filterを削除する。既存Metric Filterを編集した場合は、変更前エビデンスを参照して元に戻す。	CloudTrail連携先Log Group自体は削除しない。
4.x	通知先切り戻し	10分	既存SNS Topicを利用した場合、Topic自体は削除しない。新規SubscriptionやAlarm Actionのみ追加した場合は、承認済み範囲で追加分だけ戻す。	既存通知経路を止めない。
4.x	切り戻し後確認	20分	CloudWatch Alarm一覧、CloudWatch LogsのMetric Filter一覧、SNS Topic、EventBridge Ruleを確認し、作業前状態へ戻っていることを確認する。切り戻し後の証跡を保存する。	作業前エビデンスと比較する。
```

## 8. 当日作業で特に注意する点

| 注意点 | 理由 |
| :--- | :--- |
| A-gate / EventBridge対応済み要件を新規設定対象から外す | 二重通知と二重管理を避けるため |
| 既存SNS Topicを削除しない | 他の監視通知で共用されている可能性がある |
| 既存EventBridge Ruleを削除しない | 別アカウント連携や既存監視で利用されている可能性がある |
| 対象アカウントと対象リージョンを誤らない | 監視対象外環境へ設定しても検知できない |
| Organizationsは管理アカウント側を確認する | メンバーアカウントだけではイベントを拾えない可能性がある |
| ネットワーク系の実変更テストを安易に行わない | SG、NACL、Route Table、Gateway変更は業務通信へ影響し得る |

## 9. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 作業対象確定 | A-gate / EventBridge対応済み要件と新規設定対象要件が分離されている |
| 設定完了 | 新規設定対象要件のMetric Filter / AlarmまたはEventBridge Ruleが存在する |
| 対応なし記録 | 既存対応済み要件のRule、A-gate資料、通知経路、証跡保存先が記録されている |
| 通知先 | 既存SNS Topicまたは既存通知経路が設定されている |
| 通知確認 | 承認済みの方法で通知到達を確認している |
| 証跡 | 作業前、設定後、通知確認、切り戻し確認の証跡がある |
| 切り戻し | 切り戻し手順と判断基準が手順書内にある |
