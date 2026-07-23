# 全要件 テストリハ当日作業手順書

作成日: 2026-07-24

対象: 3.4、3.5、3.6、3.7、4.1〜4.15

対象外: A3、A4

前提: Webコンソール作業を基本とする。CLIは現場承認がある場合のみ補助的に使用する。

## 1. 使い方

この手順書は、テストリハ当日の作業をExcelへ転記して使用する想定の表である。

列構成は、現場手順書の管理列に合わせて `要件番号`、`作業内容`、`作業にかかる時間`、`作業詳細`、`備考` の5列とする。

最初に全要件共通の準備、確認、共通設定を行い、その後に要件番号固有の設定を行う。A-gateまたはEventBridgeで対応可能と確定した要件は、該当する要件番号の行を削除またはスキップしても、他要件の作業に影響しない構成とする。

Excelの1セルが長くなりすぎる手順は、同じ要件番号で複数行に分割する。

## 2. テストリハ当日作業表

| 要件番号 | 作業内容 | 作業にかかる時間 | 作業詳細 | 備考 |
| :--- | :--- | :--- | :--- | :--- |
| 共通 | 作業開始前確認 | 10分 | 作業申請、作業日時、対象環境、対象アカウント、対象リージョン、作業者、確認者、連絡先、証跡保存先を確認する。作業開始承認が取れていない場合は開始しない。 | 作業前の連絡、作業台帳、証跡保存先を確認する。 |
| 共通 | AWSログイン、アカウント、リージョン確認 | 5分 | AWS Management Consoleへログインし、画面右上のアカウントとリージョンが作業対象と一致することを確認する。対象外アカウントまたは対象外リージョンの場合は作業を中断する。 | アカウント誤りは最も危険なため、最初に確認する。 |
| 共通 | 変更パラメータ一覧確認 | 10分 | 変更パラメータ一覧を開き、各要件の対応区分、対象リソース、Log Group名、IAM Role名、Metric Namespace、Metric Name、Alarm名、SNS Topic ARN、KMS Key名、S3 bucket名、VPC IDを確認する。 | 作業中は変更パラメータ一覧の値を正とする。 |
| 共通 | A-gate / EventBridge対応区分確認 | 10分 | A-gateまたはEventBridgeで対応可能と確認済みの要件番号を確認する。対応区分が「対応なし」の要件は新規設定を行わず、「既存EventBridge / A-gate対応済み要件の対応なし記録」へ進む。 | 対応なし要件は削除せず、根拠を残してスキップする。 |
| 共通 | 既存EventBridge確認 | 15分 | EventBridgeのRule一覧を開き、クラウドセキュリティ対応に関係するRule、Event pattern、Target、別アカウントEvent bus、通知先を確認する。既存Ruleは変更しない。 | A-gate対応可否の根拠として証跡を保存する。 |
| 共通 | 既存EventBridge / A-gate対応済み要件の対応なし記録 | 10分 | 対応区分が「対応なし」の要件について、要件番号、既存Rule名またはA-gate管理対象、通知経路、確認資料、確認日を作業台帳へ記録する。設定変更は行わない。 | 後から該当要件行を削除してもよいが、対応なし根拠は残す。 |
| 共通 | CloudTrail現状確認 | 10分 | CloudTrailで対象Trailを開き、ログ記録状態、Management events、Multi-region、CloudWatch Logs連携状況、Event selectorsを確認する。対象Trailが違う場合は作業を中断する。 | 4番台の前提確認。 |
| 共通 | CloudTrail -> CloudWatch Logs連携確認 | 20分 | CloudTrail編集画面でCloudWatch Logs連携を有効化する。Log Groupはパラメータシート記載の既存Log Groupを使用する。IAM Roleは新規作成を選択し、現場命名規則に沿ったRole名を入力する。保存後、Trail詳細でLog Group ARNとRole ARNを確認する。 | UpdateTrailが発生するため、4.5の実イベント確認にも使える。 |
| 共通 | IAM Role確認 | 10分 | IAMで新規作成されたCloudTrail CloudWatch Logs連携用Roleを開き、信頼されたエンティティが`cloudtrail.amazonaws.com`であること、CloudWatch Logsへの書き込み権限があることを確認する。 | 権限不足でRole確認できない場合は確認者または権限保持者へ確認を依頼する。 |
| 共通 | CloudWatch Logs到達確認 | 20分 | CloudWatch Logsで対象Log Groupを開き、Log Streamが作成または更新されることを確認する。最新Log Streamを開き、CloudTrailイベントJSONが到達していることを確認する。ログ未到達の場合はMetric Filter作成へ進まず原因確認を行う。 | Metric FilterとAlarmはCloudTrailログ到達が前提である。 |
| 共通 | Metric Filter / Alarm共通設定確認 | 10分 | Metric Namespaceは`Custom`を使用する。Alarm条件は原則としてStatistic `Sum`、Period `5 minutes`、Threshold `>= 1`、Datapoints `1 out of 1`、Missing data `notBreaching`とする。現場設計値がある場合は現場設計値を優先する。 | Namespace、Metric Name、Alarm名は変更パラメータ一覧と一致させる。 |
| 共通 | SNS Topic確認 | 10分 | SNSで既存Topicを開き、Topic ARN、Subscription、通知先、Confirmed状態を確認する。Alarm Actionには変更パラメータ一覧で指定された既存SNS Topicを設定する。 | 既存SNS Topic自体は変更しない。 |
| 共通 | Metric Filter / Alarm作成の詳細操作 | 15分 | CloudWatch Logsの対象Log Groupを開き、Metric Filterを作成する。Filter Patternを入力し、可能な場合はPattern Testを実施する。Filter名、Metric Namespace、Metric Name、Metric Value、Default Valueを入力して保存する。その後CloudWatch Alarmを作成し、対象Metric、しきい値、Missing data、SNS Topicを設定する。 | 各要件行からこの共通手順を参照する。 |
| 3.4 | CloudTrailログ保存先S3バケットのServer Access Logging設定 | 35分 | 変更パラメータ一覧で3.4の対象Source bucket、Target bucket、Target prefixを確認する。S3でCloudTrailログ保存先bucketを開き、Server Access Loggingの変更前状態を証跡保存する。Target bucketがSource bucket自身でないこと、Target bucket policyでログ配信サービスの書き込みが許可されていることを確認してから、Server Access Loggingを有効化する。 | Target bucketを自身にするとログのループが発生するため避ける。ログ配信は遅延する場合がある。 |
| 3.4 | Server Access Logging配信確認 | 20分 | Target bucketの指定prefixを開き、Server Access Loggingのログオブジェクトが作成されるか確認する。すぐに作成されない場合は、設定値、Target bucket、prefix、権限を確認し、配信遅延として記録する。 | Server Access Loggingはベストエフォート配信であり、即時確認できない場合がある。 |
| 3.5 | CloudTrailログのCMK暗号化設定 1/2 | 35分 | 変更パラメータ一覧で3.5の対象Trail、CloudTrailログ保存先S3 bucket、使用するカスタマー管理CMK、Alias、Key Policy方針を確認する。KMSでCloudTrailログ暗号化用の対称CMKを作成または承認済み既存CMKを選定する。Key PolicyでCloudTrailが利用できること、ログ参照者にDecrypt権限があることを確認する。 | CMK権限不備はCloudTrailログ配信やログ参照に影響する。 |
| 3.5 | CloudTrailログのCMK暗号化設定 2/2 | 30分 | CloudTrailで対象Trailを開き、SSE-KMS暗号化を有効化して対象CMKを指定する。保存後、Trail statusで配信エラーがないことを確認する。新規CloudTrailログがS3に配信され、S3オブジェクトの暗号化方式がSSE-KMSかつ対象CMKであることを確認する。 | 既存ログは自動で再暗号化されない。作業後は新規ログで確認する。 |
| 3.6 | カスタマー管理対称CMKのローテーション有効化 | 15分 | 変更パラメータ一覧で3.6の対象CMKを確認する。KMSで対象CMKを開き、変更前のキーローテーション設定を証跡保存する。自動キーローテーションを有効化し、変更後の状態を証跡保存する。 | 3.5で使用するカスタマー管理対称CMKが対象である。AWS管理キーは対象外である。 |
| 3.7 | VPC Flow Logs有効化 1/2 | 30分 | 変更パラメータ一覧で3.7の対象VPC、対象環境、保存先、Traffic type、Log format、保持期間、暗号化方針を確認する。VPC一覧で利用中VPCを確認し、各VPCのFlow Logsタブで変更前状態を証跡保存する。削除予定VPCや不要VPCは対象外であることを確認する。 | 対象VPCの取り違えに注意する。 |
| 3.7 | VPC Flow Logs有効化 2/2 | 35分 | 対象VPCでFlow Logsを作成する。保存先は変更パラメータ一覧に従い、CloudWatch LogsまたはS3を指定する。Filterは設計値に従い、未指定の場合は`ALL`を候補とする。作成後、Flow Logsの状態がActiveになり、保存先へログが配信されることを確認する。 | ログ量増加と保存先権限に注意する。 |
| 4.1 | 不正なAPI呼び出し監視の設定 | 25分 | 変更パラメータ一覧で4.1の対応区分を確認する。対応区分が「対応なし」の場合は「既存EventBridge / A-gate対応済み要件の対応なし記録」へ進む。対応区分が「新規」の場合は、CloudWatch Logsの対象Log Groupで4.1用のMetric Filterを作成する。Filter Pattern、Filter名、Metric Namespace、Metric Name、Alarm名、しきい値、通知先SNS Topicは変更パラメータ一覧の4.1行を使用する。作成手順は「Metric Filter / Alarm作成の詳細操作」に従う。 | AccessDenied系は通常運用でも発生し得るため、しきい値と通知対象範囲を作業前に確認する。 |
| 4.2 | MFAなしコンソールログイン監視の設定 | 25分 | 変更パラメータ一覧で4.2の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、ConsoleLogin成功かつMFAUsedがNoのFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。Filter名、Metric Namespace、Metric Name、Alarm名、しきい値、通知先SNS Topicは変更パラメータ一覧の4.2行を使用する。 | MFA強制済みでも監査要件上の設定要否を確認する。不要判断の場合は根拠を残す。 |
| 4.3 | rootアカウント使用監視の設定 | 25分 | 変更パラメータ一覧で4.3の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、userIdentity.typeがRootのFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。通知先は既存SNS Topicを指定する。作成後、Metric Filter詳細とAlarm詳細を証跡として保存する。 | root利用は重要度が高いため、1件発報が基本である。 |
| 4.4 | IAMポリシー変更監視の設定 | 30分 | 変更パラメータ一覧で4.4の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、IAM Policy作成、削除、Version変更、Inline Policy変更、Attach、Detachを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。作成後、Filter Patternが設計値どおりであることを確認する。 | IAMユーザー、ロール、グループ変更まで含めるかは設計判断が必要である。 |
| 4.5 | CloudTrail設定変更監視の設定 | 25分 | 変更パラメータ一覧で4.5の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、CreateTrail、UpdateTrail、DeleteTrail、StartLogging、StopLogging、PutEventSelectors、PutInsightSelectorsを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | 正当な復旧操作や設定変更でも通知されるため、通知後の確認手順を運用側で持つ。 |
| 4.5 | CloudTrail設定変更監視の実イベント確認 | 20分 | CloudTrail -> CloudWatch Logs連携有効化により発生したUpdateTrailイベントが対象Log Groupへ届いていることを確認する。4.5用Metric Filterが作成済みの場合は、Metric増加、Alarm状態、通知到達を確認する。 | StopLogging、DeleteTrailは実施しない。 |
| 4.6 | コンソール認証失敗監視の設定 | 25分 | 変更パラメータ一覧で4.6の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、ConsoleLogin失敗を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。しきい値は変更パラメータ一覧に従う。 | 誤入力でも発生するため、1件発報か複数件発報かを作業前に確認する。 |
| 4.7 | CMK無効化または削除予約監視の設定 | 25分 | 変更パラメータ一覧で4.7の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、KMSのDisableKeyとScheduleKeyDeletionを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。通知先は既存SNS Topicを指定する。 | 鍵の無効化や削除予約は影響が大きいため、1件発報が基本である。 |
| 4.7 | テスト専用CMKによる実イベント確認 | 35分 | KMSでテスト専用の対称カスタマー管理CMKを作成する。DisableKeyを実行し、CloudTrailイベント、Metric増加、Alarm、通知を確認した後、すぐにEnableKeyする。ScheduleKeyDeletionを実行する場合は、検知確認後すぐにCancelKeyDeletionを実行し、必要に応じてEnableKey状態を確認する。 | 実データに使用しているCMKでは実施しない。CancelKeyDeletionの証跡を必ず保存する。 |
| 4.8 | S3バケットポリシー変更監視の設定 | 25分 | 変更パラメータ一覧で4.8の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、PutBucketPolicyとDeleteBucketPolicyを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。Filter名、Metric Namespace、Metric Name、Alarm名、通知先SNS Topicは変更パラメータ一覧の4.8行を使用する。 | A-gateまたは既存EventBridgeで対応済みの場合は新規作成しない。実バケットポリシー変更を行う場合は切り戻しPolicyを用意する。 |
| 4.9 | AWS Config変更監視の設定 | 25分 | 変更パラメータ一覧で4.9の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、Config Recorder、Delivery Channel、Config Ruleの作成、変更、削除を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | AWS Config未導入または一部環境のみの場合、対象範囲を確認する。 |
| 4.10 | Security Group変更監視の設定 | 25分 | 変更パラメータ一覧で4.10の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、Security GroupのIngress、Egress、作成、削除、ルール変更を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | 通常の作業変更でも通知されるため、変更管理との突合が必要である。 |
| 4.11 | NACL変更監視の設定 | 25分 | 変更パラメータ一覧で4.11の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、Network ACLの作成、削除、Entry作成、Entry削除、Entry置換、Association置換を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | NACL変更は通信影響が大きいため、1件発報が基本である。 |
| 4.12 | Network Gateway変更監視の設定 | 25分 | 変更パラメータ一覧で4.12の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、Internet GatewayとCustomer Gatewayの作成、削除、Attach、Detachを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | 正式資料はInternet Gateway / Customer Gateway中心である。NAT Gateway、Transit Gateway、VPN Gatewayを含める場合は別途承認を得る。 |
| 4.13 | Route Table変更監視の設定 | 25分 | 変更パラメータ一覧で4.13の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、Route作成、削除、置換、Route Table作成、削除、関連付け、関連付け解除、関連付け置換を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | ルート変更は通信経路に直結するため、通知後の確認観点を運用側で持つ。 |
| 4.14 | VPC変更監視の設定 | 25分 | 変更パラメータ一覧で4.14の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、VPC作成、削除、属性変更、VPC Peering作成、承諾、拒否、削除を対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | VPC EndpointやSubnet変更まで含める場合は別途設計判断が必要である。 |
| 4.15 | AWS Organizations変更監視の設定 | 25分 | 変更パラメータ一覧で4.15の対応区分を確認する。対応区分が「対応なし」の場合は対応なし記録へ進む。対応区分が「新規」の場合は、eventSourceがorganizations.amazonaws.comであるCloudTrailイベントを対象にするFilter PatternでMetric Filterを作成し、CloudWatch Alarmを作成する。 | 管理アカウント側での設定確認が必要な場合がある。 |
| 4-G | 4番台全体の通知テスト | 30分 | 通知テスト承認を確認する。実イベントを起こせる要件は承認済みの軽微な操作で確認する。実イベントを起こせない要件は、CloudWatch LogsのMetric Filter画面でPattern Test結果を保存し、CloudWatch Alarm詳細画面でActions enabledと通知先SNS Topicを確認し、SNS TopicのSubscription状態を確認する。通知が発生した場合はメール、Teams、監視基盤で受信画面を保存する。 | IAM、KMS、CloudTrail、ネットワーク系は影響が大きいため、実変更テストは無理に行わない。 |
| 4-G | 4番台全体の通知受信確認 | 20分 | 通知確認者へ通知到達を確認する。メール、Teams、監視基盤などの通知先で受信を確認する。通知本文またはAlarm詳細から、要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。通知確認者、確認時刻、証跡保存先を作業台帳へ記録する。 | 通知が届かない場合は、SNS Subscription、Alarm Action、Metric Filter一致条件を確認する。 |
| 4-G | 4番台全体の作業後エビデンス取得 | 30分 | 作成または変更したMetric Filter一覧、各Metric Filter詳細、CloudWatch Alarm一覧、各Alarm詳細、SNS Topic、通知受信画面、関連EventBridge Ruleをスクリーンショットで保存する。作業前エビデンスと比較し、想定外の既存設定変更がないことを確認する。 | 作業前後比較、設定値、通知到達を証跡として残す。 |
| 共通 | 変更後設定値突合 | 20分 | 変更パラメータ一覧、作業手順書、Webコンソールの設定値を突合する。差異がある場合は、差異内容、影響、判断者、対応方針を作業台帳へ記録する。 | テストリハでは差異を見つけることも目的である。 |
| 共通 | CloudTrail作業証跡確認 | 15分 | CloudTrail Event historyで当日作業に関係するUpdateTrail、PutMetricFilter、PutMetricAlarm、KMS操作、S3 Logging変更、Flow Logs作成などを確認する。表示されない場合は、到達遅延、対象リージョン違い、権限不足の可能性を記録する。 | Event historyの反映には遅延がある。 |
| 共通 | 切り戻し判断 | 10分 | 作業中に想定外のエラー、通知多発、ログ配信エラー、KMS権限エラー、既存設定への影響が発生した場合は、作業を停止し、切り戻し要否を判断する。切り戻しは今回作成または変更した設定のみを対象にする。 | 既存Alarm、既存Metric Filter、既存SNS Topic、既存EventBridge Ruleは削除しない。 |
| 共通 | 切り戻し作業 | 40分 | 切り戻し判断時は、今回作成したAlarmのAction無効化、Alarm削除、Metric Filter削除、Server Access Loggingの作業前状態復旧、CloudTrail KMS設定の作業前状態復旧、今回作成したFlow Log削除を実施する。テスト専用CMKのScheduleKeyDeletionを実施済みの場合はCancelKeyDeletion済みであることを確認する。 | CMKで暗号化済みのCloudTrailログを参照するため、作成済みCMKを安易に無効化または削除しない。 |
| 共通 | 証跡ファイル確認 | 20分 | 作業前、作業後、通知、CloudTrail Event history、A-gate対応なし根拠、未実施理由、切り戻し有無の証跡が揃っていることを確認する。ファイル名規則に従って保存されていることを確認する。 | 証跡不足はレビュー指摘になりやすい。 |
| 共通 | 未実施項目整理 | 15分 | A-gate対応済み、権限不足、承認未取得、配信遅延、実イベント未実施、対象外環境などの理由で実施しなかった項目を作業台帳へ記録する。 | 未実施項目は失敗ではなく、判断理由を残すことが重要である。 |
| 共通 | 作業完了報告 | 10分 | 対象環境、実施要件、対応なし要件、作業結果、通知結果、切り戻し有無、残課題、証跡保存先をまとめて関係者へ報告する。 | 完了判断者の確認を受ける。 |
