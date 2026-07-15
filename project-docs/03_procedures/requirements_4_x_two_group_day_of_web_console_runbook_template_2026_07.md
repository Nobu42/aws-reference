# 要件4番台 2グループ分割 当日Webコンソール作業手順書テンプレート

作成日: 2026-07-16

この資料は、要件4.1〜4.15のうち、既存EventBridge / A-gateで対応済みの要件を除外した残件について、当日作業を2グループに分けて実施するためのExcel貼り付け用テンプレートである。

既存のバッチ処理手順書と同じ考え方で、作業詳細にはWebコンソール上の操作、入力値、保存後確認、証跡取得箇所まで記載する。

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

## 3. 変更パラメータ一覧

作業前に以下のパラメータを確定する。  
未確定の値がある場合、当日作業を開始しない。

### 3.1 共通パラメータ

| パラメータ | 設定値 | 備考 |
| :--- | :--- | :--- |
| 対象アカウント | `<対象AWSアカウント名またはID>` | 作業画面右上で確認 |
| 対象リージョン | `<対象リージョン>` | CloudTrail / CloudWatch Logs / SNS / EventBridgeで揃える |
| 対象CloudTrail | `<Trail名>` | Management Eventを記録しているTrail |
| CloudWatch Logs連携先Log Group | `<CloudTrail連携先Log Group名>` | Metric Filter作成先 |
| 既存SNS Topic名 | `<既存SNS Topic名>` | 新規Topicは作成しない前提 |
| 既存SNS Topic ARN | `<既存SNS Topic ARN>` | Alarm Actionに指定する通知先 |
| 通知確認者 | `<通知確認者名またはチーム>` | メール、Teams、監視基盤の確認者 |
| 作業承認番号 | `<作業承認番号>` | 変更管理番号または作業申請番号 |
| 証跡保存先 | `<証跡保存先パスまたはチケット番号>` | スクリーンショット、確認結果の保存先 |
| 切り戻し判断者 | `<切り戻し判断者>` | 当日判断できる担当者 |

### 3.2 新規設定対象パラメータ

以下は新規Metric Filter / Alarmを作成する要件だけ記入する。  
A-gate / EventBridge対応済み要件は対応なし記録へ回す。

| 要件番号 | 対応区分 | Filter名 | Filter Pattern | Metric Namespace | Metric Name | Metric Value | Alarm名 | Period | Evaluation Periods | Threshold | Treat missing data | Alarm Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 4.1 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.2 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.3 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.4 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.5 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.6 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.7 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.9 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.10 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.11 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.12 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.13 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.14 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |
| 4.15 | `<新規/対応なし>` | `<Filter名>` | `<Filter Pattern>` | `<Namespace>` | `<Metric名>` | `1` | `<Alarm名>` | `<例: 300秒>` | `<例: 1>` | `<例: >= 1>` | `<例: notBreaching>` | `<SNS Topic ARN>` |

### 3.3 対応なし記録パラメータ

| 要件番号 | EventBridge Rule名 | Event Pattern確認 | Target | A-gate要件番号突合 | 通知経路 | 証跡保存先 | 判断者 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `<要件番号>` | `<Rule名>` | `<確認済/未確認>` | `<SNS/別アカウントEvent bus/Lambda等>` | `<確認済/未確認>` | `<通知先>` | `<証跡保存先>` | `<判断者>` |

## 4. 共通作業

2グループの作業に共通する手順である。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	作業開始前の前提確認	15分	AWS Management Consoleへログインする。画面右上のアカウント名またはアカウントIDを確認する。画面右上のリージョンが「<対象リージョン>」であることを確認する。作業対象要件、対象CloudTrail名、CloudWatch Logs連携先Log Group名、既存SNS Topic名またはARN、作業承認番号、通知テスト可否、通知確認者、切り戻し判断者を作業台帳と突合する。	アカウント、リージョン、Log Group、通知先Topicを誤ると別環境または別通知先へ設定するため、最初に必ず確認する。
4.x	変更パラメータ確認	20分	本手順書の「変更パラメータ一覧」を開く。新規設定対象と対応なし対象を確認する。新規設定対象について、Filter名、Filter Pattern、Metric Namespace、Metric Name、Alarm名、Period、Evaluation Periods、Threshold、Treat missing data、Alarm Actionがすべて記入済みであることを確認する。未記入項目がある場合は作業を開始しない。	設定値が未確定のまま作業すると、レビュー不能または切り戻し不能になる。
4.x	A-gate / EventBridge対応済み要件の除外確認	20分	A-gate側資料、EventBridge Rule一覧、要件番号突合資料を確認する。既存設定で対応済みの要件番号を作業対象から除外する。除外対象は要件番号、Rule名、イベントパターン、ターゲット、通知経路、証跡保存先を作業台帳に記録する。	対応なしは何もしないという意味ではない。既存設定確認と証跡取得をもって対応なし判断とする。
4.x	変更前エビデンス取得	30分	CloudTrailコンソールで対象Trail詳細を表示し、Management Event、CloudWatch Logs連携先、S3保存先を撮影する。CloudWatch Logsコンソールで対象Log Groupを開き、Metric Filter一覧を撮影する。CloudWatchコンソールでAlarm一覧を表示し、対象Namespaceまたは命名規則で検索した結果を撮影する。SNSコンソールで対象Topicを開き、Subscription一覧と状態を撮影する。EventBridgeコンソールで関連Rule一覧とTargetを撮影する。	作業前後比較と切り戻しの基準になる。
4.x	CloudTrail設定確認	15分	CloudTrailコンソールを開く。「証跡」を選択する。対象Trail「<Trail名>」を選択する。Management Eventが記録対象であること、Read / Writeの対象範囲、CloudWatch Logs連携先Log Group、CloudWatch Logs Roleを確認する。CloudWatch Logs未連携の場合は作業を停止し、方針確認へ回す。	4番台はManagement Eventを前提とする。CloudWatch Logs未連携の場合はMetric Filter方式で検知できない。
4.x	CloudWatch Logs到達確認	10分	CloudWatchコンソールを開く。左メニュー「ログ」から「ロググループ」を選択する。CloudTrail連携先Log Group「<CloudTrail連携先Log Group名>」を開く。最新Log Streamまたはログイベントを開き、CloudTrailイベントが届いていることを確認する。	ログが届いていない場合、Metric Filterを作成しても検知できない。
4.x	既存SNS Topic確認	10分	SNSコンソールを開く。左メニュー「トピック」を選択する。既存通知Topic「<既存SNS Topic名>」を開く。「サブスクリプション」タブでメール、Teams連携、監視基盤連携などの通知先を確認する。状態がConfirmedまたは有効であることを確認する。	既存Topicは他用途で利用されている可能性があるため、Topic自体を削除しない。
4.x	既存EventBridge重複確認	20分	EventBridgeコンソールを開く。左メニュー「イベントバス」を選択する。対象イベントバスを選択し、「ルール」を開く。CloudTrail、IAM、KMS、Config、SecurityGroup、NACL、Gateway、RouteTable、Organizationsなどの関連Ruleが存在するか確認する。対象Ruleがある場合はイベントパターン、ターゲット、別アカウント送信有無、通知先を確認する。	同等監視が既にある場合、新規Metric Filter / Alarmを追加すると二重通知になる可能性がある。
```

## 5. Metric Filter / Alarm作成の詳細操作

新規設定対象の各要件で共通して実施する詳細操作である。  
各要件固有の値は「変更パラメータ一覧」に従う。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	Metric Filter作成	20分	CloudWatchコンソールを開く。左メニュー「ログ」から「ロググループ」を選択する。Log Group「<CloudTrail連携先Log Group名>」を開く。「メトリクスフィルター」タブを選択する。「メトリクスフィルターを作成」を押す。Filter Pattern欄に「<Filter Pattern>」を入力する。サンプルログを指定できる場合は「パターンをテスト」で一致結果を確認する。Filter nameに「<Filter名>」を入力する。Metric namespaceに「<Metric Namespace>」を入力する。Metric nameに「<Metric Name>」を入力する。Metric valueに「1」を入力する。内容を確認し、Metric Filterを作成する。	過去ログはメトリクス化されない。Metric Filter作成後に到着したログからメトリクスが生成される。
4.x	Metric Filter作成後確認	10分	CloudWatch Logsの対象Log Groupを開く。「メトリクスフィルター」タブを開く。作成したFilter名「<Filter名>」が一覧に存在することを確認する。Filter Pattern、Metric Namespace、Metric Name、Metric Valueが変更パラメータ一覧と一致することを確認する。作成後画面を証跡として保存する。	作成直後はMetricのデータポイントが存在しない場合がある。
4.x	CloudWatch Alarm作成	20分	CloudWatchコンソールを開く。左メニュー「アラーム」から「すべてのアラーム」を選択する。「アラームの作成」を押す。「メトリクスの選択」を押す。作成したMetric Namespace「<Metric Namespace>」を開き、Metric Name「<Metric Name>」を選択する。Statisticは「Sum」を選択する。Periodに「<Period>」を指定する。条件でThreshold「<Threshold>」を指定する。追加設定でDatapoints to alarmまたはEvaluation Periodsに「<Evaluation Periods>」を指定する。Treat missing dataに「<Treat missing data>」を指定する。通知設定でAlarm state triggerを選択し、既存SNS Topic「<SNS Topic ARN>」を指定する。Alarm nameに「<Alarm名>」を入力する。内容を確認し、Alarmを作成する。	既存SNS Topicを利用する。新規Topicは作成しない。
4.x	Alarm作成後確認	10分	CloudWatchコンソールで作成したAlarm「<Alarm名>」を開く。Metric、Statistic、Period、Threshold、Evaluation Periods、Treat missing data、Actions enabled、通知先SNS Topicが変更パラメータ一覧と一致することを確認する。Alarm詳細画面を証跡として保存する。	Alarm作成直後はINSUFFICIENT_DATAになることがある。
```

## 6. グループA 管理・認証・監査系

対象候補は4.1、4.2、4.3、4.4、4.5、4.6、4.7、4.9である。  
A-gate / EventBridge対応済みの要件は、この表から削除する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.1	不正なAPI呼び出し監視の設定	25分	変更パラメータ一覧で4.1の対応区分を確認する。対応区分が「対応なし」の場合は「既存EventBridge / A-gate対応済み要件の対応なし記録」へ進む。対応区分が「新規」の場合は、CloudWatch Logsの対象Log Groupで4.1用のMetric Filterを作成する。Filter Pattern、Filter名、Metric Namespace、Metric Name、Alarm名、しきい値、通知先SNS Topicは変更パラメータ一覧の4.1行を使用する。作成手順は「Metric Filter / Alarm作成の詳細操作」に従う。	AccessDenied系は通常運用でも発生し得るため、しきい値と通知対象範囲を作業前に確認する。
4.2	MFAなしコンソールログイン監視の設定	25分	変更パラメータ一覧で4.2の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、ConsoleLogin成功かつMFAUsedがNoのFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。Filter名、Metric Namespace、Metric Name、Alarm名、しきい値、通知先SNS Topicは変更パラメータ一覧の4.2行を使用する。	MFA強制済みでも監査要件上の設定要否を確認する。不要判断の場合は根拠を残す。
4.3	rootアカウント使用監視の設定	25分	変更パラメータ一覧で4.3の対応区分を確認する。対応区分が「新規」の場合は、userIdentity.typeがRootのFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。通知先は既存SNS Topicを指定する。作成後、Metric Filter詳細とAlarm詳細を証跡として保存する。	root利用は重要度が高いため、1件発報が基本である。
4.4	IAMポリシー変更監視の設定	30分	変更パラメータ一覧で4.4の対応区分を確認する。対応区分が「新規」の場合は、IAM Policy作成、削除、Version変更、Inline Policy変更、Attach、Detachを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。作成後、Filter Patternが設計値どおりであることを確認する。	IAMユーザー、ロール、グループ変更まで含めるかは設計判断が必要である。
4.5	CloudTrail設定変更監視の設定	25分	変更パラメータ一覧で4.5の対応区分を確認する。対応区分が「新規」の場合は、CreateTrail、UpdateTrail、DeleteTrail、StartLogging、StopLogging、PutEventSelectors、PutInsightSelectorsを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	正当な復旧操作や設定変更でも通知されるため、通知後の確認手順を運用側で持つ。
4.6	コンソール認証失敗監視の設定	25分	変更パラメータ一覧で4.6の対応区分を確認する。対応区分が「新規」の場合は、ConsoleLogin失敗を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。しきい値は変更パラメータ一覧に従う。	誤入力でも発生するため、1件発報か複数件発報かを作業前に確認する。
4.7	CMK無効化または削除予約監視の設定	25分	変更パラメータ一覧で4.7の対応区分を確認する。対応区分が「新規」の場合は、KMSのDisableKeyとScheduleKeyDeletionを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。通知先は既存SNS Topicを指定する。	鍵の無効化や削除予約は影響が大きいため、1件発報が基本である。
4.9	AWS Config変更監視の設定	25分	変更パラメータ一覧で4.9の対応区分を確認する。対応区分が「新規」の場合は、Config Recorder、Delivery Channel、Config Ruleの作成、変更、削除を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	AWS Config未導入または一部環境のみの場合、対象範囲を確認する。
4-A	グループA通知テスト	30分	通知テスト承認を確認する。実イベントを起こせる要件は承認済みの軽微な操作で確認する。実イベントを起こせない要件は、CloudWatch LogsのMetric Filter画面でPattern Test結果を保存し、CloudWatch Alarm詳細画面でActions enabledと通知先SNS Topicを確認し、SNS TopicのSubscription状態を確認する。通知が発生した場合はメール、Teams、監視基盤で受信画面を保存する。	IAM、KMS、CloudTrailは影響が大きいため、実変更テストは無理に行わない。
4-A	グループA通知受信確認	20分	通知確認者へ通知到達を確認する。メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。通知確認者、確認時刻、証跡保存先を作業台帳へ記録する。	通知が届かない場合は、SNS Subscription、Alarm Action、Metric Filter一致条件を確認する。
4-A	グループA作業後エビデンス取得	30分	作成または変更したMetric Filter一覧、各Metric Filter詳細、CloudWatch Alarm一覧、各Alarm詳細、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。作業前エビデンスと比較し、想定外の既存設定変更がないことを確認する。	作業前後比較、設定値、通知到達を証跡として残す。
```

## 7. グループB ネットワーク・組織系

対象候補は4.10、4.11、4.12、4.13、4.14、4.15である。  
A-gate / EventBridge対応済みの要件は、この表から削除する。  
ネットワーク系はインフラチームの変更管理、通信影響確認先、対象リソース範囲を作業前に確認する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.10	Security Group変更監視の設定	25分	変更パラメータ一覧で4.10の対応区分を確認する。対応区分が「新規」の場合は、Security GroupのIngress、Egress、作成、削除、ルール変更を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。作成後、Filter Pattern、Metric、Alarm、通知先SNS Topicが変更パラメータ一覧と一致することを確認する。	通常変更でも通知されるため、変更管理番号との突合方法を確認する。
4.11	NACL変更監視の設定	25分	変更パラメータ一覧で4.11の対応区分を確認する。対応区分が「新規」の場合は、Network ACL作成、削除、Entry作成、削除、置換、関連付け変更を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	NACL変更は通信影響が大きいため、通知後の確認先を明確にする。
4.12	Network Gateway変更監視の設定	25分	変更パラメータ一覧で4.12の対応区分を確認する。対応区分が「新規」の場合は、正式資料に沿ってInternet GatewayとCustomer Gatewayの作成、削除、Attach、Detachを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	NAT Gateway、Transit Gateway、VPN Gatewayを含めるかは作業前に確認する。
4.13	Route Table変更監視の設定	25分	変更パラメータ一覧で4.13の対応区分を確認する。対応区分が「新規」の場合は、Route作成、削除、置換、Route Table作成、削除、関連付け、関連付け解除、関連付け置換を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	通信経路変更の通知であるため、通知後の確認先を明確にする。
4.14	VPC変更監視の設定	25分	変更パラメータ一覧で4.14の対応区分を確認する。対応区分が「新規」の場合は、VPC作成、削除、属性変更、VPC Peeringの作成、承認、拒否、削除を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。	VPC EndpointやSubnet変更まで含めるかは作業前に確認する。
4.15	AWS Organizations変更監視の設定	25分	変更パラメータ一覧で4.15の対応区分を確認する。対応区分が「新規」の場合は、organizations.amazonaws.comのイベントを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。管理アカウント側でイベントが記録される場合は、対象アカウントを再確認する。	Organizationsは管理アカウント側にイベントが出る可能性があるため、対象アカウントを作業前に確認する。
4-B	グループB通知テスト	30分	通知テスト承認を確認する。ネットワーク系の実変更は通信影響があり得るため、原則として実変更ではなくPattern Test、既存ログ、Alarm設定、SNS Topic、通知先受信状況を組み合わせて確認する。実イベントを起こす場合はインフラチーム承認、影響確認、切り戻し手順、実施時間を事前に確定する。	SG、NACL、Route Table、Gateway、VPCは業務通信へ影響し得るため、無承認の実変更テストを行わない。
4-B	グループB通知受信確認	20分	通知確認者へ通知到達を確認する。メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。通知確認者、確認時刻、証跡保存先を作業台帳へ記録する。	通知が届かない場合は、SNS Subscription、Alarm Action、Metric Filter一致条件を確認する。
4-B	グループB作業後エビデンス取得	30分	作成または変更したMetric Filter一覧、各Metric Filter詳細、CloudWatch Alarm一覧、各Alarm詳細、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。作業前エビデンスと比較し、想定外の既存設定変更がないことを確認する。	作業前後比較、設定値、通知到達を証跡として残す。
```

## 8. 既存EventBridge / A-gate対応済み要件の対応なし記録

新規設定を行わない要件は、以下の形式で作業台帳または証跡一覧へ記録する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	既存EventBridge / A-gate対応済み確認	15分	A-gate側資料を開き、対象要件番号を確認する。EventBridgeコンソールを開き、対象Ruleを選択する。Rule名、状態、イベントパターン、ターゲット、入力変換、別アカウントEvent bus送信有無を確認する。A-gate資料上の要件番号とEventBridge Ruleの対象イベントが対応していることを確認する。確認結果とスクリーンショットを証跡として保存する。	新規Metric Filter / Alarmは作成しない。
4.x	対応なし判断の記録	10分	既存EventBridge / A-gate設定により要件を満たすと判断した根拠を作業台帳へ記録する。記録内容は要件番号、既存設定名、イベントパターン、通知経路、A-gate資料名、証跡保存先、判断者、確認日とする。	対応なしの理由を残さないと、未対応と誤認される可能性がある。
```

## 9. 共通切り戻し手順

CloudWatch Metric Filter / Alarm方式の切り戻しである。  
EventBridge方式の切り戻しは、既存Ruleを編集した場合のみ変更前エビデンスに従って戻す。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	切り戻し判断	10分	通知が想定どおり届かない、誤通知が多い、既存通知Topicへ想定外の通知が出る、Alarmが不要にALARMを継続する、または作業継続不可と判断された場合に切り戻しを開始する。	切り戻し判断者と連絡先を作業前に決めておく。
4.x	CloudWatch Alarm切り戻し	30分	CloudWatchコンソールを開く。左メニュー「アラーム」から「すべてのアラーム」を選択する。今回作成した4番台用Alarmを選択する。まずActionsを無効化できる場合は無効化する。その後、承認済み手順に従ってAlarmを削除する。既存Alarmを編集した場合は、変更前エビデンスを参照して元に戻す。	既存Alarmを誤って削除しない。削除対象は今回作成したAlarmに限定する。
4.x	Metric Filter切り戻し	30分	CloudWatch Logsで対象Log Groupを開く。「メトリクスフィルター」タブを開く。今回作成した4番台用Metric Filterを選択し、削除する。既存Metric Filterを編集した場合は、変更前エビデンスを参照して元に戻す。	CloudTrail連携先Log Group自体は削除しない。
4.x	通知先切り戻し	10分	既存SNS Topicを利用した場合、Topic自体は削除しない。新規SubscriptionやAlarm Actionのみ追加した場合は、承認済み範囲で追加分だけ戻す。	既存通知経路を止めない。
4.x	切り戻し後確認	20分	CloudWatch Alarm一覧、CloudWatch LogsのMetric Filter一覧、SNS Topic、EventBridge Ruleを確認し、作業前状態へ戻っていることを確認する。切り戻し後の証跡を保存する。	作業前エビデンスと比較する。
```

## 10. 当日作業で特に注意する点

| 注意点 | 理由 |
| :--- | :--- |
| 変更パラメータ未確定の要件を作業しない | 作業後レビューと切り戻しが困難になる |
| A-gate / EventBridge対応済み要件を新規設定対象から外す | 二重通知と二重管理を避けるため |
| 既存SNS Topicを削除しない | 他の監視通知で共用されている可能性がある |
| 既存EventBridge Ruleを削除しない | 別アカウント連携や既存監視で利用されている可能性がある |
| 対象アカウントと対象リージョンを誤らない | 監視対象外環境へ設定しても検知できない |
| Organizationsは管理アカウント側を確認する | メンバーアカウントだけではイベントを拾えない可能性がある |
| ネットワーク系の実変更テストを安易に行わない | SG、NACL、Route Table、Gateway変更は業務通信へ影響し得る |

## 11. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 作業対象確定 | A-gate / EventBridge対応済み要件と新規設定対象要件が分離されている |
| 変更パラメータ確定 | 新規設定対象のFilter、Metric、Alarm、通知先、しきい値が確定している |
| 設定完了 | 新規設定対象要件のMetric Filter / AlarmまたはEventBridge Ruleが存在する |
| 対応なし記録 | 既存対応済み要件のRule、A-gate資料、通知経路、証跡保存先が記録されている |
| 通知先 | 既存SNS Topicまたは既存通知経路が設定されている |
| 通知確認 | 承認済みの方法で通知到達を確認している |
| 証跡 | 作業前、設定後、通知確認、切り戻し確認の証跡がある |
| 切り戻し | 切り戻し手順と判断基準が手順書内にある |
