# 全要件 テストリハ当日作業手順書

作成日: 2026-07-24

対象: 3.4、3.5、3.6、3.7、4.1〜4.15

対象外: A3、A4

前提:

- Webコンソール作業を基本とする。
- CLIは現場承認がある場合のみ補助的に使用する。
- AlarmのMetric Namespaceは `Custom` を使用する。
- CloudTrailからCloudWatch Logsへ連携するIAM Roleは、現場命名規則に沿った名前で新規作成する。
- パラメータシートまたは変更パラメータ一覧に値がある場合は、本手順書の仮値より現場資料を優先する。

## 1. 使い方

この手順書は、テストリハ当日の作業をExcelへ転記して使用する想定の表である。

列構成は、現場手順書の管理列に合わせて `要件番号`、`作業内容`、`作業にかかる時間`、`作業詳細`、`備考` の5列とする。

下記のTSV表はタブ区切りである。コードブロック内をコピーしてExcelへ貼り付けると、5列に分割される。

表内に書ききれないFilter Pattern、Metric名、Alarm名、SNS Topic、KMS Key、S3 bucket、VPC IDなどは、表の下の「変更パラメータ」に要件番号別で記載する。

A-gateまたはEventBridgeで対応可能と確定した要件は、該当する要件番号の行を削除またはスキップしても、他要件の作業に影響しない構成とする。

## 2. テストリハ当日作業表

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
共通	作業開始前確認	10分	作業申請、作業日時、対象環境、対象アカウント、対象リージョン、作業者、確認者、連絡先、証跡保存先を確認する。作業開始承認、通知テスト承認、切り戻し判断者、通知受信確認者が未確定の場合は開始しない。	作業前の連絡、作業台帳、証跡保存先を最初に確認する。
共通	AWSログイン、アカウント、リージョン確認	5分	AWS Management Consoleへログインする。画面右上のアカウント表示をクリックし、アカウントIDまたはアカウント名が作業対象と一致することを確認する。画面右上のリージョンを開き、対象リージョンを選択する。対象外アカウントまたは対象外リージョンの場合は作業を中断する。	アカウント誤りは最も危険なため、最初に確認する。
共通	変更パラメータ一覧確認	10分	変更パラメータ一覧を開き、各要件の対応区分、対象リソース、CloudTrail Trail名、CloudWatch Logs Log Group名、CloudTrail配信用IAM Role名、Metric Namespace、Metric Name、Alarm名、SNS Topic ARN、KMS Key、S3 bucket、VPC IDを確認する。	作業中は変更パラメータ一覧の値を正とする。
共通	A-gate / EventBridge対応区分確認	10分	A-gate対応表または既存EventBridge調査結果を開き、各要件番号の対応区分を確認する。対応区分が「対応なし」または「既存A-gate対応済み」の要件は新規設定を行わず、「既存EventBridge / A-gate対応済み要件の対応なし記録」へ進む。	対応なし要件は削除せず、根拠を残してスキップする。
共通	既存EventBridge確認	15分	EventBridgeコンソールを開き、左メニューの「イベントバス」または「ルール」を開く。対象Event busを選択し、クラウドセキュリティ対応に関係するRule名、Event pattern、Target、別アカウントEvent bus、通知先を確認する。既存Ruleは変更しない。	A-gate対応可否の根拠として証跡を保存する。
共通	既存EventBridge / A-gate対応済み要件の対応なし記録	10分	対応区分が「対応なし」の要件について、要件番号、既存Rule名、A-gate管理対象、通知経路、参照資料、確認日を作業台帳へ記録する。CloudWatch Logs、Metric Filter、Alarmの新規作成は行わない。	後から該当要件行を削除してもよいが、対応なし根拠は残す。
共通	CloudTrail現状確認	10分	CloudTrailコンソールを開き、左メニューの「証跡」をクリックする。対象Trail名をクリックし、ログ記録状態、Management events、Multi-region、CloudWatch Logs連携状況、Event selectorsを確認する。対象Trailが違う場合は作業を中断する。	4番台のMetric FilterはCloudTrailログがCloudWatch Logsへ届くことが前提である。
共通	CloudTrailからCloudWatch Logsへの連携設定	25分	CloudTrailの対象Trail詳細画面で「編集」をクリックする。CloudWatch Logs欄で有効化チェックを入れる。Log Groupは「既存のロググループを使用」を選択し、パラメータシート記載の既存Log Group名を入力または選択する。IAM Roleは「新しいロールを作成」を選択し、現場命名規則に沿ったRole名を入力する。保存後、Trail詳細でLog Group ARNとRole ARNを確認する。	UpdateTrailが発生するため、4.5の実イベント確認にも使える。Role名は空欄のまま保存しない。
共通	IAM Role確認	10分	IAMコンソールを開き、左メニューの「ロール」をクリックする。CloudTrail連携設定で新規作成したRole名を検索して開く。信頼関係タブでPrincipal Serviceがcloudtrail.amazonaws.comであることを確認する。許可タブでCloudWatch LogsへのCreateLogStream、PutLogEvents相当の権限があることを確認する。	権限不足でRole確認できない場合は権限保持者へ確認を依頼する。
共通	CloudWatch Logs到達確認	20分	CloudWatchコンソールを開き、左メニューの「ログ」から「ロググループ」をクリックする。対象Log Group名で検索し、Log Groupを開く。「ログストリーム」タブで直近のLog Streamを開き、CloudTrailイベントJSONが到達していることを確認する。ログ未到達の場合はMetric Filter作成へ進まず原因確認を行う。	Metric FilterとAlarmはCloudTrailログ到達が前提である。
共通	SNS Topic確認	10分	SNSコンソールを開き、左メニューの「トピック」をクリックする。既存SNS Topicを開き、Topic ARNがパラメータと一致することを確認する。「サブスクリプション」欄で通知先がConfirmedまたは有効状態であることを確認する。	既存SNS Topic自体は変更しない。通知先情報は証跡でマスクする。
共通	Metric Filter作成共通手順	15分	CloudWatchコンソールで「ログ」から対象Log Groupを開く。「メトリクスフィルター」タブをクリックし、「メトリクスフィルターを作成」をクリックする。対象要件のFilter Patternを入力し、サンプルログを貼り付けて「パターンをテスト」を実行する。一致を確認後、Filter名、Metric Namespace、Metric Name、Metric Value 1、Default Value 0を入力して作成する。	Filter Pattern、Filter名、Metric Nameは下部の変更パラメータを使用する。
共通	CloudWatch Alarm作成共通手順	15分	CloudWatchコンソールで「アラーム」から「すべてのアラーム」を開き、「アラームの作成」をクリックする。「メトリクスの選択」でCustom配下の該当Metricを選択する。StatisticはSum、Periodは5 minutes、しきい値は1以上、Datapoints to alarmは1 out of 1、欠損データの処理はnotBreachingを選択する。通知先は既存SNS Topicを指定し、Alarm名を入力して作成する。	現場設計値がある場合は現場設計値を優先する。
3.4	CloudTrailログ保存先S3バケットのServer Access Logging設定	40分	S3コンソールを開き、CloudTrailログ保存先bucketをクリックする。「プロパティ」タブを開き、「サーバーアクセスのログ記録」欄までスクロールする。変更前状態を証跡保存する。「編集」をクリックし、「有効にする」を選択する。Target bucketに3.4パラメータのTarget bucketを指定し、Target prefixに3.4パラメータのprefixを入力して保存する。	Target bucketをSource bucket自身にしない。ログのループを避ける。
3.4	Server Access Logging配信確認	20分	S3コンソールでTarget bucketを開き、3.4パラメータのTarget prefixを開く。ログオブジェクトが作成されるか確認する。すぐに作成されない場合は、設定値、Target bucket、prefix、bucket policy、配信遅延を確認し、配信待ちとして記録する。	Server Access Loggingは即時配信ではない。
3.5	CloudTrailログ暗号化用CMK確認	25分	KMSコンソールを開き、左メニューの「カスタマー管理キー」をクリックする。3.5パラメータのCMKまたはAliasを検索して開く。Key typeがSymmetricであること、Key stateがEnabledであること、Key policyでCloudTrailサービスおよびログ参照者の利用が許可されていることを確認する。	新規CMKを作る場合は現場命名規則、管理者、利用者、タグを事前確認する。
3.5	CloudTrailログのCMK暗号化設定	35分	CloudTrailコンソールで対象Trailを開き、「編集」をクリックする。SSE-KMS暗号化欄で「有効」を選択し、3.5パラメータのCMK AliasまたはKey ARNを選択する。保存後、Trail詳細でKMS Key IDが設定されたことを確認する。	CMK権限不備はCloudTrailログ配信やログ参照に影響する。
3.5	CloudTrailログのCMK暗号化確認	25分	CloudTrailのTrail statusで配信エラーがないことを確認する。S3コンソールでCloudTrailログ保存先bucketを開き、作業後に配信された新規ログオブジェクトのプロパティを開く。暗号化方式がSSE-KMSで、KMS Keyが3.5パラメータのCMKであることを確認する。	既存ログは自動で再暗号化されない。新規ログで確認する。
3.6	カスタマー管理対称CMKのローテーション有効化	15分	KMSコンソールで3.6パラメータの対象CMKを開く。「キーローテーション」欄または「ローテーション」タブを開き、変更前状態を証跡保存する。「編集」または「有効化」をクリックし、自動キーローテーションを有効化して保存する。	3.5で使用するカスタマー管理対称CMKが対象である。AWS管理キーは対象外である。
3.7	VPC Flow Logs有効化	40分	VPCコンソールを開き、左メニューの「VPC」をクリックする。3.7パラメータの対象VPC IDを検索して選択し、「フローログ」タブを開く。変更前状態を証跡保存する。「フローログを作成」をクリックし、Filter、Maximum aggregation interval、Destination、Log GroupまたはS3 bucket、IAM Role、Log formatを3.7パラメータ通りに入力して作成する。	削除予定VPCや不要VPCは対象外であることを確認する。
3.7	VPC Flow Logs配信確認	20分	VPCの「フローログ」タブで作成したFlow LogのStatusがActiveであることを確認する。保存先がCloudWatch Logsの場合は対象Log GroupでLog Streamとログイベントを確認する。保存先がS3の場合は対象bucketとprefixでログオブジェクトを確認する。	保存先権限、IAM Role、KMS暗号化の設定不備で配信されない場合がある。
4.1	不正なAPI呼び出し監視の設定	20分	CloudWatchコンソールで「ログ」からCloudTrail連携先Log Groupを開き、「メトリクスフィルター」タブで「メトリクスフィルターを作成」をクリックする。4.1パラメータのFilter Patternを入力し、サンプルログで一致確認する。Metric NamespaceはCustom、Metric Nameは4.1パラメータ、Metric Valueは1、Default Valueは0で作成する。続けてCloudWatchの「アラーム」から該当Metricを選択し、Sum、しきい値1以上、欠損データnotBreaching、通知先に既存SNS Topicを指定する。	AccessDenied系は通常運用でも発生し得るため、1件発報でよいか作業前に確認する。
4.2	MFAなしコンソールログイン監視の設定	20分	CloudWatch Logsの対象Log Groupで「メトリクスフィルターを作成」をクリックする。4.2パラメータのFilter Patternを入力し、ConsoleLogin成功かつMFAUsedがNoのサンプルログで一致確認する。Metric NamespaceはCustom、Metric Nameは4.2パラメータで作成する。CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	MFA強制済みでも、監査要件上は検知設定が必要か確認する。
4.3	rootアカウント使用監視の設定	20分	CloudWatch Logsの対象Log Groupで4.3パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでuserIdentity.typeがRootのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.3パラメータで作成し、CloudWatch Alarmで1件以上を既存SNS Topicへ通知する。	root利用は重要度が高いため、1件発報が基本である。
4.4	IAMポリシー変更監視の設定	25分	CloudWatch Logsの対象Log Groupで4.4パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでIAM Policy作成、削除、Version変更、Inline Policy変更、Attach、Detachのいずれかのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.4パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	IAMユーザー、ロール、グループ変更まで含めるかは別要件化または設計判断が必要である。
4.5	CloudTrail設定変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.5パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでUpdateTrailのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.5パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	正当な復旧操作や設定変更でも通知されるため、通知後の確認手順を運用側で持つ。
4.5	CloudTrail設定変更監視の実イベント確認	20分	CloudTrailからCloudWatch Logsへの連携有効化により発生したUpdateTrailイベントをCloudTrail Event historyで確認する。CloudWatch Logsの対象Log Groupで同イベントが到達していることを確認する。4.5用Metric Filter作成後、Metric増加、Alarm履歴、通知到達を確認する。	StopLogging、DeleteTrailは実施しない。
4.6	コンソール認証失敗監視の設定	20分	CloudWatch Logsの対象Log Groupで4.6パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでConsoleLogin Failureのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.6パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	誤入力でも発生するため、1件発報か複数件発報かを作業前に確認する。
4.7	CMK無効化または削除予約監視の設定	20分	CloudWatch Logsの対象Log Groupで4.7パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでDisableKeyまたはScheduleKeyDeletionのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.7パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	鍵の無効化や削除予約は影響が大きいため、1件発報が基本である。
4.7	テスト専用CMKによる実イベント確認	35分	KMSコンソールでテスト専用の対称カスタマー管理CMKを作成する。対象キーを開き、「キーアクション」からDisableKeyを実行し、CloudTrailイベント、Metric増加、Alarm、通知を確認した後、すぐにEnableKeyする。ScheduleKeyDeletionを実行する場合は、検知確認後すぐにCancelKeyDeletionを実行し、必要に応じてEnableKey状態を確認する。	実データに使用しているCMKでは実施しない。CancelKeyDeletionの証跡を必ず保存する。
4.8	S3バケットポリシー変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.8パラメータのFilter Patternを使ってMetric Filterを作成する。対象バケットを限定する場合はFilter PatternにrequestParameters.bucketName条件を含める。Metric NamespaceはCustom、Metric Nameは4.8パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	既存EventBridgeで同等設定がある場合、二重通知にならないよう先に方式を確定する。
4.9	AWS Config変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.9パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでConfig Recorder、Delivery Channel、Config Rule変更のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.9パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	AWS Config未導入または一部環境のみの場合、対象範囲を確認する。
4.10	Security Group変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.10パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでIngress、Egress、Security Group作成、削除、ルール変更のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.10パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	通常変更でも通知されるため、変更管理番号との突合が必要である。
4.11	NACL変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.11パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでNetwork ACL作成、削除、Entry作成、削除、置換、関連付け変更のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.11パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	NACL変更は通信影響が大きいため、通知後の確認先を明確にする。
4.12	Network Gateway変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.12パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでInternet GatewayまたはCustomer Gateway変更のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.12パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	NAT Gateway、Transit Gateway、VPN Gatewayを含めるかは作業前に確認する。
4.13	Route Table変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.13パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでRoute作成、削除、置換、Route Table作成、削除、関連付け、関連付け解除、関連付け置換のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.13パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	通信経路変更の通知であるため、通知後の確認先を明確にする。
4.14	VPC変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.14パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern TestでVPC作成、削除、属性変更、VPC Peeringの作成、承認、拒否、削除のサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.14パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	VPC EndpointやSubnet変更まで含めるかは作業前に確認する。
4.15	AWS Organizations変更監視の設定	20分	CloudWatch Logsの対象Log Groupで4.15パラメータのFilter Patternを使ってMetric Filterを作成する。Pattern Testでorganizations.amazonaws.comのサンプルログが一致することを確認する。Metric NamespaceはCustom、Metric Nameは4.15パラメータで作成し、CloudWatch Alarmで既存SNS Topicへ通知する。	Organizationsは管理アカウント側にイベントが出る可能性があるため、対象アカウントを作業前に確認する。
4-G	4番台全体の通知テスト	30分	通知テスト承認を確認する。実イベントを起こせる要件は承認済みの軽微な操作で確認する。実イベントを起こせない要件は、CloudWatch LogsのMetric Filter画面でPattern Test結果を保存し、CloudWatch Alarm詳細画面でActions enabledと通知先SNS Topicを確認し、SNS TopicのSubscription状態を確認する。通知が発生した場合はメール、Teams、監視基盤で受信画面を保存する。	IAM、KMS、CloudTrail、ネットワーク系は影響が大きいため、実変更テストは無理に行わない。
4-G	4番台全体の通知受信確認	20分	通知確認者へ通知到達を確認する。メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。通知確認者、確認時刻、証跡保存先を作業台帳へ記録する。	通知が届かない場合は、SNS Subscription、Alarm Action、Metric Filter一致条件を確認する。
4-G	4番台全体の作業後エビデンス取得	30分	作成または変更したMetric Filter一覧、各Metric Filter詳細、CloudWatch Alarm一覧、各Alarm詳細、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。作業前エビデンスと比較し、想定外の既存設定変更がないことを確認する。	作業前後比較、設定値、通知到達を証跡として残す。
共通	変更後設定値突合	20分	変更パラメータ一覧、作業手順書、Webコンソールの設定値を突合する。差異がある場合は、差異内容、影響、判断者、対応方針を作業台帳へ記録する。	テストリハでは差異を見つけることも目的である。
共通	CloudTrail作業証跡確認	15分	CloudTrail Event historyで当日作業に関係するUpdateTrail、PutMetricFilter、PutMetricAlarm、KMS操作、S3 Logging変更、Flow Logs作成などを確認する。表示されない場合は、到達遅延、対象リージョン違い、権限不足の可能性を記録する。	Event historyの反映には遅延がある。
共通	切り戻し判断	10分	作業中に想定外のエラー、通知多発、ログ配信エラー、KMS権限エラー、既存設定への影響が発生した場合は、作業を停止し、切り戻し要否を判断する。切り戻しは今回作成または変更した設定のみを対象にする。	既存Alarm、既存Metric Filter、既存SNS Topic、既存EventBridge Ruleは削除しない。
共通	切り戻し作業	40分	切り戻し判断時は、今回作成したAlarmのAction無効化、Alarm削除、Metric Filter削除、Server Access Loggingの作業前状態復旧、CloudTrail KMS設定の作業前状態復旧、今回作成したFlow Log削除を実施する。テスト専用CMKのScheduleKeyDeletionを実施済みの場合はCancelKeyDeletion済みであることを確認する。	CMKで暗号化済みのCloudTrailログを参照するため、作成済みCMKを安易に無効化または削除しない。
共通	証跡ファイル確認	20分	作業前、作業後、通知、CloudTrail Event history、A-gate対応なし根拠、未実施理由、切り戻し有無の証跡が揃っていることを確認する。ファイル名規則に従って保存されていることを確認する。	証跡不足はレビュー指摘になりやすい。
共通	未実施項目整理	15分	A-gate対応済み、権限不足、承認未取得、配信遅延、実イベント未実施、対象外環境などの理由で実施しなかった項目を作業台帳へ記録する。	未実施項目は失敗ではなく、判断理由を残すことが重要である。
共通	作業完了報告	10分	対象環境、実施要件、対応なし要件、作業結果、通知結果、切り戻し有無、残課題、証跡保存先をまとめて関係者へ報告する。	完了判断者の確認を受ける。
```

## 3. 変更パラメータ

### 共通パラメータ

| 項目 | 値 |
| :--- | :--- |
| 対象AWSアカウント | `<account-id-or-account-name>` |
| 対象リージョン | `<region>` |
| 対象CloudTrail Trail名 | `<trail-name>` |
| CloudWatch Logs連携先Log Group名 | `<cloudtrail-log-group-name>` |
| CloudTrail配信用IAM Role名 | `<現場命名規則に沿った新規Role名>` |
| Metric Namespace | `Custom` |
| Metric Value | `1` |
| Default Value | `0` |
| Alarm Statistic | `Sum` |
| Alarm Period | `5 minutes` |
| Alarm Threshold | `>= 1` |
| Datapoints to Alarm | `1 out of 1` |
| Missing data | `notBreaching` |
| Alarm通知先 | `<既存SNS Topic ARN>` |

### 3.4 パラメータ

| 項目 | 値 |
| :--- | :--- |
| Source bucket | `<cloudtrail-log-bucket>` |
| Target bucket | `<server-access-log-target-bucket>` |
| Target prefix | `<server-access-log-prefix>` |
| Target bucket policy確認 | S3ログ配信サービスがPutObject可能であること |

### 3.5 パラメータ

| 項目 | 値 |
| :--- | :--- |
| 対象Trail | `<trail-name>` |
| CloudTrailログ保存先S3 bucket | `<cloudtrail-log-bucket>` |
| CMK Alias | `<alias/cloudtrail-log-key>` |
| CMK Key type | `Symmetric` |
| CMK Key state | `Enabled` |
| Key policy | CloudTrailサービス、鍵管理者、ログ参照者を許可 |

### 3.6 パラメータ

| 項目 | 値 |
| :--- | :--- |
| 対象CMK | 3.5で使用するカスタマー管理対称CMK |
| Rotation | Enabled |

### 3.7 パラメータ

| 項目 | 値 |
| :--- | :--- |
| 対象VPC ID | `<vpc-id>` |
| Filter | `ALL` または現場設計値 |
| Destination | `CloudWatch Logs` または `S3` |
| Destination Log Group / Bucket | `<flow-logs-destination>` |
| IAM Role | `<flow-logs-delivery-role>` |
| Log format | 現場設計値 |
| Retention | 現場設計値 |

### 4.1 パラメータ

- Metric Filter名: `<system>-security-4-1-unauthorized-api-call`
- Metric Namespace: `Custom`
- Metric Name: `Req41UnauthorizedApiCallCount`
- Alarm名: `<system>-security-4-1-unauthorized-api-call-alarm`

```text
{ ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }
```

### 4.2 パラメータ

- Metric Filter名: `<system>-security-4-2-console-login-without-mfa`
- Metric Namespace: `Custom`
- Metric Name: `Req42ConsoleLoginWithoutMfaCount`
- Alarm名: `<system>-security-4-2-console-login-without-mfa-alarm`

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }
```

### 4.3 パラメータ

- Metric Filter名: `<system>-security-4-3-root-account-usage`
- Metric Namespace: `Custom`
- Metric Name: `Req43RootAccountUsageCount`
- Alarm名: `<system>-security-4-3-root-account-usage-alarm`

```text
{ ($.userIdentity.type = "Root") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != "AwsServiceEvent") }
```

### 4.4 パラメータ

- Metric Filter名: `<system>-security-4-4-iam-policy-change`
- Metric Namespace: `Custom`
- Metric Name: `Req44IamPolicyChangeCount`
- Alarm名: `<system>-security-4-4-iam-policy-change-alarm`

```text
{ ($.eventSource = "iam.amazonaws.com") && (($.eventName = "CreatePolicy") || ($.eventName = "DeletePolicy") || ($.eventName = "CreatePolicyVersion") || ($.eventName = "DeletePolicyVersion") || ($.eventName = "SetDefaultPolicyVersion") || ($.eventName = "PutUserPolicy") || ($.eventName = "PutGroupPolicy") || ($.eventName = "PutRolePolicy") || ($.eventName = "DeleteUserPolicy") || ($.eventName = "DeleteGroupPolicy") || ($.eventName = "DeleteRolePolicy") || ($.eventName = "AttachUserPolicy") || ($.eventName = "AttachGroupPolicy") || ($.eventName = "AttachRolePolicy") || ($.eventName = "DetachUserPolicy") || ($.eventName = "DetachGroupPolicy") || ($.eventName = "DetachRolePolicy")) }
```

### 4.5 パラメータ

- Metric Filter名: `<system>-security-4-5-cloudtrail-change`
- Metric Namespace: `Custom`
- Metric Name: `Req45CloudTrailChangeCount`
- Alarm名: `<system>-security-4-5-cloudtrail-change-alarm`

```text
{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "CreateTrail") || ($.eventName = "UpdateTrail") || ($.eventName = "DeleteTrail") || ($.eventName = "StartLogging") || ($.eventName = "StopLogging") || ($.eventName = "PutEventSelectors") || ($.eventName = "PutInsightSelectors")) }
```

### 4.6 パラメータ

- Metric Filter名: `<system>-security-4-6-console-login-failure`
- Metric Namespace: `Custom`
- Metric Name: `Req46ConsoleLoginFailureCount`
- Alarm名: `<system>-security-4-6-console-login-failure-alarm`

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Failure") }
```

### 4.7 パラメータ

- Metric Filter名: `<system>-security-4-7-kms-key-disable-or-deletion`
- Metric Namespace: `Custom`
- Metric Name: `Req47KmsKeyDisableOrDeletionCount`
- Alarm名: `<system>-security-4-7-kms-key-disable-or-deletion-alarm`
- テスト専用CMK Alias: `<alias/test-req47-kms-detection>`

```text
{ ($.eventSource = "kms.amazonaws.com") && (($.eventName = "DisableKey") || ($.eventName = "ScheduleKeyDeletion")) }
```

### 4.8 パラメータ

- Metric Filter名: `<system>-security-4-8-s3-bucket-policy-change`
- Metric Namespace: `Custom`
- Metric Name: `Req48S3BucketPolicyChangeCount`
- Alarm名: `<system>-security-4-8-s3-bucket-policy-change-alarm`
- 対象バケット限定時の追加条件: `&& ($.requestParameters.bucketName = "<bucket-name>")`

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

### 4.9 パラメータ

- Metric Filter名: `<system>-security-4-9-config-change`
- Metric Namespace: `Custom`
- Metric Name: `Req49ConfigChangeCount`
- Alarm名: `<system>-security-4-9-config-change-alarm`

```text
{ ($.eventSource = "config.amazonaws.com") && (($.eventName = "StopConfigurationRecorder") || ($.eventName = "StartConfigurationRecorder") || ($.eventName = "PutConfigurationRecorder") || ($.eventName = "DeleteConfigurationRecorder") || ($.eventName = "PutDeliveryChannel") || ($.eventName = "DeleteDeliveryChannel") || ($.eventName = "PutConfigRule") || ($.eventName = "DeleteConfigRule")) }
```

### 4.10 パラメータ

- Metric Filter名: `<system>-security-4-10-security-group-change`
- Metric Namespace: `Custom`
- Metric Name: `Req410SecurityGroupChangeCount`
- Alarm名: `<system>-security-4-10-security-group-change-alarm`

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "AuthorizeSecurityGroupIngress") || ($.eventName = "AuthorizeSecurityGroupEgress") || ($.eventName = "RevokeSecurityGroupIngress") || ($.eventName = "RevokeSecurityGroupEgress") || ($.eventName = "CreateSecurityGroup") || ($.eventName = "DeleteSecurityGroup") || ($.eventName = "ModifySecurityGroupRules")) }
```

### 4.11 パラメータ

- Metric Filter名: `<system>-security-4-11-network-acl-change`
- Metric Namespace: `Custom`
- Metric Name: `Req411NetworkAclChangeCount`
- Alarm名: `<system>-security-4-11-network-acl-change-alarm`

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateNetworkAcl") || ($.eventName = "DeleteNetworkAcl") || ($.eventName = "CreateNetworkAclEntry") || ($.eventName = "DeleteNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclAssociation")) }
```

### 4.12 パラメータ

- Metric Filter名: `<system>-security-4-12-network-gateway-change`
- Metric Namespace: `Custom`
- Metric Name: `Req412NetworkGatewayChangeCount`
- Alarm名: `<system>-security-4-12-network-gateway-change-alarm`

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateInternetGateway") || ($.eventName = "DeleteInternetGateway") || ($.eventName = "AttachInternetGateway") || ($.eventName = "DetachInternetGateway") || ($.eventName = "CreateCustomerGateway") || ($.eventName = "DeleteCustomerGateway")) }
```

### 4.13 パラメータ

- Metric Filter名: `<system>-security-4-13-route-table-change`
- Metric Namespace: `Custom`
- Metric Name: `Req413RouteTableChangeCount`
- Alarm名: `<system>-security-4-13-route-table-change-alarm`

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateRoute") || ($.eventName = "DeleteRoute") || ($.eventName = "ReplaceRoute") || ($.eventName = "CreateRouteTable") || ($.eventName = "DeleteRouteTable") || ($.eventName = "AssociateRouteTable") || ($.eventName = "DisassociateRouteTable") || ($.eventName = "ReplaceRouteTableAssociation")) }
```

### 4.14 パラメータ

- Metric Filter名: `<system>-security-4-14-vpc-change`
- Metric Namespace: `Custom`
- Metric Name: `Req414VpcChangeCount`
- Alarm名: `<system>-security-4-14-vpc-change-alarm`

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateVpc") || ($.eventName = "DeleteVpc") || ($.eventName = "ModifyVpcAttribute") || ($.eventName = "AcceptVpcPeeringConnection") || ($.eventName = "CreateVpcPeeringConnection") || ($.eventName = "DeleteVpcPeeringConnection") || ($.eventName = "RejectVpcPeeringConnection")) }
```

### 4.15 パラメータ

- Metric Filter名: `<system>-security-4-15-organizations-change`
- Metric Namespace: `Custom`
- Metric Name: `Req415OrganizationsChangeCount`
- Alarm名: `<system>-security-4-15-organizations-change-alarm`

```text
{ ($.eventSource = "organizations.amazonaws.com") }
```
