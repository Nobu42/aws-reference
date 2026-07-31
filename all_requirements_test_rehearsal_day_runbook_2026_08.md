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
共通	Metric Filter一括設定	60分	4.1〜4.15のMetric Filterは要件ごとに個別行で作業せず、変更パラメータ一覧に従ってまとめて設定する。詳細な画面操作、Pattern Test、Filter名、Metric Namespace、Metric Name、Metric Value、Default Value、作成後確認は別ファイルの「メトリックフィルター詳細手順書」を参照する。	対応区分が既存A-gate/EventBridge対応済みの要件は新規作成せず、対応なし根拠を保存する。
共通	CloudWatch Alarm作成	45分	Metric Filter一括設定後、変更パラメータ一覧に従ってCloudWatch Alarmをまとめて作成する。Metric NamespaceはCustom、StatisticはSum、欠損データの処理はnotBreaching、通知先は既存SNS Topicを使用する。詳細な入力値は変更パラメータ一覧を正とする。	Alarm名、しきい値、通知Actionは現場設計値を優先する。
共通	Alarmテスト	60分	作成または確認したAlarmについて、状態確認、メトリクス発生確認、通知Action、SNS Topic、通知受信、Alarm履歴、復旧確認を実施する。詳細なテスト手順、実イベントを使うかPattern Testで代替するかの判断、証跡取得は別ファイルの「アラームテスト詳細手順書」を参照する。	影響が大きい実イベントは無理に発生させない。承認済みの範囲で確認する。
3.4	CloudTrailログ保存先S3バケットのServer Access Logging設定	40分	S3コンソールを開き、CloudTrailログ保存先bucketをクリックする。「プロパティ」タブを開き、「サーバーアクセスのログ記録」欄までスクロールする。変更前状態を証跡保存する。「編集」をクリックし、「有効にする」を選択する。Target bucketに3.4パラメータのTarget bucketを指定し、Target prefixに3.4パラメータのprefixを入力して保存する。	Target bucketをSource bucket自身にしない。ログのループを避ける。
3.4	Server Access Logging配信確認	20分	S3コンソールでTarget bucketを開き、3.4パラメータのTarget prefixを開く。ログオブジェクトが作成されるか確認する。すぐに作成されない場合は、設定値、Target bucket、prefix、bucket policy、配信遅延を確認し、配信待ちとして記録する。	Server Access Loggingは即時配信ではない。
3.5	CloudTrailログ暗号化用CMK確認	25分	KMSコンソールを開き、左メニューの「カスタマー管理キー」をクリックする。3.5パラメータのCMKまたはAliasを検索して開く。Key typeがSymmetricであること、Key stateがEnabledであること、Key policyでCloudTrailサービスおよびログ参照者の利用が許可されていることを確認する。	新規CMKを作る場合は現場命名規則、管理者、利用者、タグを事前確認する。
3.5	CloudTrailログのCMK暗号化設定	35分	CloudTrailコンソールで対象Trailを開き、「編集」をクリックする。SSE-KMS暗号化欄で「有効」を選択し、3.5パラメータのCMK AliasまたはKey ARNを選択する。保存後、Trail詳細でKMS Key IDが設定されたことを確認する。	CMK権限不備はCloudTrailログ配信やログ参照に影響する。
3.5	CloudTrailログのCMK暗号化確認	25分	CloudTrailのTrail statusで配信エラーがないことを確認する。S3コンソールでCloudTrailログ保存先bucketを開き、作業後に配信された新規ログオブジェクトのプロパティを開く。暗号化方式がSSE-KMSで、KMS Keyが3.5パラメータのCMKであることを確認する。	既存ログは自動で再暗号化されない。新規ログで確認する。
3.6	カスタマー管理対称CMKのローテーション有効化	15分	KMSコンソールで3.6パラメータの対象CMKを開く。「キーローテーション」欄または「ローテーション」タブを開き、変更前状態を証跡保存する。「編集」または「有効化」をクリックし、自動キーローテーションを有効化して保存する。	3.5で使用するカスタマー管理対称CMKが対象である。AWS管理キーは対象外である。
3.7	VPC Flow Logs有効化	40分	VPCコンソールを開き、左メニューの「VPC」をクリックする。3.7パラメータの対象VPC IDを検索して選択し、「フローログ」タブを開く。変更前状態を証跡保存する。「フローログを作成」をクリックし、Filter、Maximum aggregation interval、Destination、Log GroupまたはS3 bucket、IAM Role、Log formatを3.7パラメータ通りに入力して作成する。	削除予定VPCや不要VPCは対象外であることを確認する。
3.7	VPC Flow Logs配信確認	20分	VPCの「フローログ」タブで作成したFlow LogのStatusがActiveであることを確認する。保存先がCloudWatch Logsの場合は対象Log GroupでLog Streamとログイベントを確認する。保存先がS3の場合は対象bucketとprefixでログオブジェクトを確認する。	保存先権限、IAM Role、KMS暗号化の設定不備で配信されない場合がある。
4-G	4番台全体の設定値確認	20分	Metric Filter一括設定、CloudWatch Alarm作成、Alarmテストの結果を要件4.1〜4.15ごとに確認する。Filter Pattern、Metric名、Alarm名、しきい値、通知先、対応区分、未実施理由を作業台帳へ記録する。	詳細な作業はメトリックフィルター詳細手順書とアラームテスト詳細手順書を正とする。
4-G	4番台全体の通知受信確認	20分	通知確認者へ通知到達を確認する。メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。通知確認者、確認時刻、証跡保存先を作業台帳へ記録する。	通知が届かない場合は、SNS Subscription、Alarm Action、Metric Filter一致条件を確認する。
4-G	4番台全体の作業後証跡取得	30分	作成または変更したMetric Filter一覧、各Metric Filter詳細、Pattern Test結果、CloudWatch Alarm一覧、各Alarm詳細、Alarm履歴、SNS Topic、通知受信画面、関連EventBridge Ruleを保存する。作業前証跡と比較し、想定外の既存設定変更がないことを確認する。	作業前後比較、設定値、通知到達を証跡として残す。
共通	変更後設定値突合	20分	変更パラメータ一覧、作業手順書、Webコンソールの設定値を突合する。差異がある場合は、差異内容、影響、判断者、対応方針を作業台帳へ記録する。	テストリハでは差異を見つけることも目的である。
共通	CloudTrail作業証跡確認	15分	CloudTrail Event historyで当日作業に関係するUpdateTrail、PutMetricFilter、PutMetricAlarm、KMS操作、S3 Logging変更、Flow Logs作成などを確認する。表示されない場合は、到達遅延、対象リージョン違い、権限不足の可能性を記録する。	Event historyの反映には遅延がある。
共通	切り戻し判断	10分	作業中に想定外のエラー、通知多発、ログ配信エラー、KMS権限エラー、既存設定への影響が発生した場合は、作業を停止し、切り戻し要否を判断する。切り戻しは今回作成または変更した設定のみを対象にする。	既存Alarm、既存Metric Filter、既存SNS Topic、既存EventBridge Ruleは削除しない。
共通	切り戻し作業	40分	切り戻し判断時は、今回作成したAlarmのAction無効化、Alarm削除、Metric Filter削除、Server Access Loggingの作業前状態復旧、CloudTrail KMS設定の作業前状態復旧、今回作成したFlow Log削除を実施する。テスト専用CMKのScheduleKeyDeletionを実施済みの場合はCancelKeyDeletion済みであることを確認する。	CMKで暗号化済みのCloudTrailログを参照するため、作成済みCMKを安易に無効化または削除しない。
共通	証跡ファイル確認	20分	作業前、作業後、通知、CloudTrail Event history、A-gate対応なし根拠、未実施理由、切り戻し有無の証跡が揃っていることを確認する。ファイル名規則に従って保存されていることを確認する。	証跡不足はレビュー指摘になりやすい。
共通	未実施項目整理	15分	A-gate対応済み、権限不足、承認未取得、配信遅延、実イベント未実施、対象外環境などの理由で実施しなかった項目を作業台帳へ記録する。	未実施項目は失敗ではなく、判断理由を残すことが重要である。
共通	作業完了報告	10分	対象環境、実施要件、対応なし要件、作業結果、通知結果、切り戻し有無、残課題、証跡保存先をまとめて関係者へ報告する。	完了判断者の確認を受ける。
```

## 3. 証跡ファイル名一覧

`202608XX` は作業日に置換する。画面キャプチャは `.png`、一覧出力や設定値は `.xlsx` または `.txt`、JSON出力がある場合は `.json` を付与する。

| No | 証跡名 | 内容 |
|---:|---|---|
| 01 | `01_共通_作業開始前確認_202608XX` | 作業申請、作業日時、承認、連絡先、証跡保存先 |
| 02 | `02_共通_アカウント確認_202608XX` | AWSアカウントIDまたはアカウント名 |
| 03 | `03_共通_リージョン確認_202608XX` | 対象リージョン |
| 04 | `04_共通_変更パラメータ一覧確認_202608XX` | 変更パラメータ一覧 |
| 05 | `05_共通_A-gate対応区分確認_202608XX` | 要件別対応区分 |
| 06 | `06_共通_EventBridgeルール一覧_202608XX` | 既存EventBridge Rule一覧 |
| 07 | `07_共通_EventBridge対象ルール詳細_202608XX` | 対象RuleのEvent patternとTarget |
| 08 | `08_共通_A-gate対応済み根拠_202608XX` | A-gateまたは既存監視で対応済みとする根拠 |
| 09 | `09_共通_CloudTrail証跡詳細_202608XX` | 対象Trail詳細 |
| 10 | `10_共通_CloudTrailイベントセレクタ_202608XX` | Event selectors |
| 11 | `11_共通_CloudWatchLogs連携変更前_202608XX` | CloudWatch Logs連携変更前 |
| 12 | `12_共通_CloudWatchLogs連携変更後_202608XX` | CloudWatch Logs連携変更後 |
| 13 | `13_共通_CloudTrail配信用IAMRole信頼関係_202608XX` | IAM Role信頼関係 |
| 14 | `14_共通_CloudTrail配信用IAMRole権限_202608XX` | IAM Role権限 |
| 15 | `15_共通_CloudWatchLogsロググループ_202608XX` | 対象Log Group |
| 16 | `16_共通_CloudWatchLogsログ到達確認_202608XX` | CloudTrailイベント到達確認 |
| 17 | `17_共通_SNSTopic詳細_202608XX` | SNS Topic ARN |
| 18 | `18_共通_SNSTopicSubscription確認_202608XX` | Subscription状態 |
| 19 | `19_共通_MetricFilter一覧_202608XX` | Metric Filter一覧 |
| 20 | `20_共通_MetricFilter詳細一覧_202608XX` | 要件別Metric Filter詳細 |
| 21 | `21_共通_MetricFilterパターンテスト結果_202608XX` | Pattern Test結果 |
| 22 | `22_共通_CloudWatchAlarm一覧_202608XX` | Alarm一覧 |
| 23 | `23_共通_CloudWatchAlarm詳細一覧_202608XX` | 要件別Alarm詳細 |
| 24 | `24_共通_Alarm通知アクション確認_202608XX` | Alarm ActionとSNS Topic |
| 25 | `25_共通_Alarmテスト結果_202608XX` | Alarmテスト結果 |
| 26 | `26_共通_通知受信確認_202608XX` | メール、Teams、監視基盤の受信確認 |
| 27 | `27_共通_CloudTrail作業イベント履歴_202608XX` | 当日作業のCloudTrail Event history |
| 28 | `28_共通_変更後設定値突合_202608XX` | パラメータと実設定の突合 |
| 29 | `29_共通_切り戻し判断記録_202608XX` | 切り戻し要否判断 |
| 30 | `30_共通_切り戻し後確認_202608XX` | 切り戻し後の状態確認 |
| 31 | `31_共通_未実施項目一覧_202608XX` | 未実施理由、対象外、権限不足 |
| 32 | `32_共通_作業完了報告_202608XX` | 作業結果、残課題、証跡保存先 |
| 33 | `33_3.4_ServerAccessLogging変更前_202608XX` | 3.4変更前 |
| 34 | `34_3.4_ServerAccessLogging変更後_202608XX` | 3.4変更後 |
| 35 | `35_3.4_TargetBucket確認_202608XX` | ログ保存先bucket |
| 36 | `36_3.4_ServerAccessLogging配信確認_202608XX` | ログ配信確認または配信待ち記録 |
| 37 | `37_3.5_CMK詳細_202608XX` | 対象CMK詳細 |
| 38 | `38_3.5_CMKKeyPolicy確認_202608XX` | Key Policy |
| 39 | `39_3.5_CloudTrailKMS設定変更前_202608XX` | KMS設定変更前 |
| 40 | `40_3.5_CloudTrailKMS設定変更後_202608XX` | KMS設定変更後 |
| 41 | `41_3.5_CloudTrailログSSEKMS確認_202608XX` | 新規ログのSSE-KMS確認 |
| 42 | `42_3.6_CMKローテーション変更前_202608XX` | Rotation変更前 |
| 43 | `43_3.6_CMKローテーション変更後_202608XX` | Rotation変更後 |
| 44 | `44_3.7_VPCFlowLogs変更前_202608XX` | Flow Logs変更前 |
| 45 | `45_3.7_VPCFlowLogs変更後_202608XX` | Flow Logs変更後 |
| 46 | `46_3.7_VPCFlowLogs配信確認_202608XX` | Flow Logs配信確認 |
| 47 | `47_3.7_VPCFlowLogs保存先確認_202608XX` | 保存先Log GroupまたはS3 |
| 48 | `48_4.1_MetricFilter詳細_202608XX` | 4.1 Metric Filter |
| 49 | `49_4.1_Alarm詳細_202608XX` | 4.1 Alarm |
| 50 | `50_4.2_MetricFilter詳細_202608XX` | 4.2 Metric Filter |
| 51 | `51_4.2_Alarm詳細_202608XX` | 4.2 Alarm |
| 52 | `52_4.3_MetricFilter詳細_202608XX` | 4.3 Metric Filter |
| 53 | `53_4.3_Alarm詳細_202608XX` | 4.3 Alarm |
| 54 | `54_4.4_MetricFilter詳細またはA-gate根拠_202608XX` | 4.4 Metric Filterまたは対応済み根拠 |
| 55 | `55_4.4_Alarm詳細または通知経路根拠_202608XX` | 4.4 Alarmまたは通知経路 |
| 56 | `56_4.5_MetricFilter詳細_202608XX` | 4.5 Metric Filter |
| 57 | `57_4.5_Alarm詳細_202608XX` | 4.5 Alarm |
| 58 | `58_4.5_UpdateTrailイベント確認_202608XX` | 4.5実イベント確認 |
| 59 | `59_4.6_MetricFilter詳細_202608XX` | 4.6 Metric Filter |
| 60 | `60_4.6_Alarm詳細_202608XX` | 4.6 Alarm |
| 61 | `61_4.7_MetricFilter詳細_202608XX` | 4.7 Metric Filter |
| 62 | `62_4.7_Alarm詳細_202608XX` | 4.7 Alarm |
| 63 | `63_4.7_テストCMK作成確認_202608XX` | テストCMK作成 |
| 64 | `64_4.7_DisableKeyイベント確認_202608XX` | DisableKey確認 |
| 65 | `65_4.7_ScheduleKeyDeletionイベント確認_202608XX` | ScheduleKeyDeletion確認 |
| 66 | `66_4.7_CancelKeyDeletion確認_202608XX` | CancelKeyDeletion確認 |
| 67 | `67_4.8_MetricFilter詳細またはA-gate根拠_202608XX` | 4.8 Metric Filterまたは対応済み根拠 |
| 68 | `68_4.8_Alarm詳細または通知経路根拠_202608XX` | 4.8 Alarmまたは通知経路 |
| 69 | `69_4.9_MetricFilter詳細_202608XX` | 4.9 Metric Filter |
| 70 | `70_4.9_Alarm詳細_202608XX` | 4.9 Alarm |
| 71 | `71_4.10_MetricFilter詳細またはA-gate根拠_202608XX` | 4.10 Metric Filterまたは対応済み根拠 |
| 72 | `72_4.10_Alarm詳細または通知経路根拠_202608XX` | 4.10 Alarmまたは通知経路 |
| 73 | `73_4.11_MetricFilter詳細_202608XX` | 4.11 Metric Filter |
| 74 | `74_4.11_Alarm詳細_202608XX` | 4.11 Alarm |
| 75 | `75_4.12_MetricFilter詳細またはA-gate根拠_202608XX` | 4.12 Metric Filterまたは対応済み根拠 |
| 76 | `76_4.12_Alarm詳細または通知経路根拠_202608XX` | 4.12 Alarmまたは通知経路 |
| 77 | `77_4.13_MetricFilter詳細またはA-gate根拠_202608XX` | 4.13 Metric Filterまたは対応済み根拠 |
| 78 | `78_4.13_Alarm詳細または通知経路根拠_202608XX` | 4.13 Alarmまたは通知経路 |
| 79 | `79_4.14_MetricFilter詳細またはA-gate根拠_202608XX` | 4.14 Metric Filterまたは対応済み根拠 |
| 80 | `80_4.14_Alarm詳細または通知経路根拠_202608XX` | 4.14 Alarmまたは通知経路 |
| 81 | `81_4.15_MetricFilter詳細_202608XX` | 4.15 Metric Filter |
| 82 | `82_4.15_Alarm詳細_202608XX` | 4.15 Alarm |
| 83 | `83_4番台_通知受信確認一覧_202608XX` | 4番台通知受信一覧 |
| 84 | `84_4番台_対応なし根拠一覧_202608XX` | A-gate/EventBridge対応済み要件の根拠 |
| 85 | `85_全要件_証跡不足確認結果_202608XX` | 証跡不足の有無 |

## 4. 変更パラメータ

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
