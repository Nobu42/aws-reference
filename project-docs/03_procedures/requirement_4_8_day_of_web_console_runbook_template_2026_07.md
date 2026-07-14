# 要件4.8 当日Webコンソール作業手順書テンプレート

作成日: 2026-07-15

この資料は、要件4.8「S3バケットポリシー変更監視」の当日作業手順を、Excel管理表へ貼り付けるための雛形である。

Excel列は以下を想定する。

```text
要件番号	作業内容	作業にかかる時間	作業詳細	備考
```

通知先は既存SNS Topicを利用する前提とする。  
EventBridgeを利用する案と、当初案であるCloudTrail / CloudWatch Logs / Metric Filter / CloudWatch Alarmを利用する案を両方記載する。実施方式が確定した後、不要な案を削除する。

## 1. 作業前提

| 項目 | 前提 |
| :--- | :--- |
| 対象要件 | 4.8 S3バケットポリシー変更監視 |
| 監視対象イベント | `PutBucketPolicy`、`DeleteBucketPolicy` |
| 通知先 | 既存SNS Topicを利用 |
| 作業方式A | 既存または新規EventBridge Ruleから既存SNS Topicへ通知 |
| 作業方式B | CloudTrailをCloudWatch Logsへ連携し、Metric FilterとCloudWatch Alarmから既存SNS Topicへ通知 |
| 作業端末 | Windows上のWebブラウザ、AWS Management Console |
| 作業条件 | 作業承認、対象アカウント、対象リージョン、対象S3バケット、通知先Topic、テスト可否が確定済み |

## 2. 共通手順

以下は、EventBridge案と当初案のどちらでも必要になる共通作業である。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.8	作業開始前の前提確認	10分	AWS Management Consoleへログインし、画面右上で対象アカウントと対象リージョンを確認する。作業対象S3バケット名、既存SNS Topic名またはARN、作業時間、作業承認、通知テスト可否、切り戻し判断者を確認する。	対象アカウント、対象リージョン、対象バケットを誤ると別環境の監視設定を変更するため、最初に必ず確認する。
4.8	変更前エビデンス取得	20分	S3、CloudTrail、CloudWatch、EventBridge、SNSの関連画面を開き、変更前の状態をスクリーンショットで保存する。S3は対象バケットの「アクセス許可」タブでバケットポリシーを確認する。SNSは対象Topicの「サブスクリプション」タブで通知先がConfirm済みであることを確認する。	EventBridge案の場合も当初案の場合も、既存通知先と既存ルールの有無を作業前に残す。
4.8	対象バケットの変更前ポリシー確認	10分	S3コンソールを開き、対象バケットを選択し、「アクセス許可」タブから「バケットポリシー」を確認する。通知テストで実際にポリシー変更を行う場合は、変更前JSONを別途控える。	実イベントで通知テストする場合、テスト後に同じ内容へ戻すための基準になる。
4.8	既存SNS Topic確認	10分	SNSコンソールを開き、「トピック」から既存通知Topicを選択する。「サブスクリプション」タブでメール、Teams連携、監視基盤連携などの通知先を確認し、状態がConfirmedまたは有効であることを確認する。	既存Topicは他用途で利用されている可能性があるため、Topic自体を削除しない。
```

## 3. A案 EventBridgeを利用する場合

EventBridge RuleでCloudTrail由来のS3 APIイベントを検知し、既存SNS Topicへ通知する案である。既存Ruleが利用可能な場合は、既存Ruleの流用または変更可否を確認してから作業する。

### 3.1 設定作業

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.8-A	EventBridge既存Rule確認	15分	EventBridgeコンソールを開き、「イベントバス」から対象イベントバスを選択し、「ルール」を開く。S3、CloudTrail、BucketPolicy、PutBucketPolicy、DeleteBucketPolicyなどの名称・説明を持つ既存Ruleを確認する。対象Ruleを開き、状態、イベントパターン、ターゲット、実行ロール、デッドレターキューの有無を確認する。	既存Ruleのターゲットが別アカウントのEvent busの場合、現在のアカウントだけでは最終通知まで確認できないことがある。
4.8-A	EventBridge Rule作成または編集	20分	EventBridgeの「ルール」画面で、既存Ruleを流用する場合は対象Ruleを開いて「編集」を選択する。新規作成する場合は「ルールを作成」を選択し、名前、説明、イベントバス、状態を入力する。イベントパターンは「カスタムパターン」を選択し、sourceにaws.s3、detail-typeにAWS API Call via CloudTrail、detail.eventSourceにs3.amazonaws.com、detail.eventNameにPutBucketPolicyとDeleteBucketPolicyを指定する。対象バケットを限定する場合はdetail.requestParameters.bucketNameに対象バケット名を指定する。	対象バケットを限定するか、全S3バケットを対象にするかは設計判断である。監査指摘の対象範囲と一致させる。
4.8-A	EventBridgeターゲット設定	15分	Rule作成または編集画面の「ターゲット」で「AWSサービス」を選択し、ターゲットタイプとしてSNS Topicを指定する。Topicは既存通知Topicを選択する。入力変換を使う場合は、通知本文にアカウント、リージョン、イベント名、バケット名、実行者、イベント時刻が分かるように設定する。	既存Topicを使う前提であり、新規Topicは作成しない。別アカウントEvent busがターゲットの場合は、受信側アカウントの通知経路確認が必要である。
4.8-A	EventBridge Rule保存	5分	イベントパターン、ターゲット、状態が想定どおりであることを確認し、Ruleを保存する。保存後にRule詳細画面を開き、状態がEnabledであること、ターゲットに既存SNS Topicが設定されていることを確認する。	保存後の画面を証跡として取得する。
4.8-A	通知テスト	30分	承認済みの方法で通知テストを実施する。実イベントで確認する場合は、S3コンソールで対象バケットを開き、「アクセス許可」タブの「バケットポリシー」を編集し、承認済みの軽微な変更を保存してPutBucketPolicyを発生させる。削除イベントも確認する場合は、承認済みの範囲でDeleteBucketPolicy相当の操作可否を確認する。実イベントを起こせない場合は、EventBridge Ruleの一致条件、SNS Topic、EventBridgeメトリクス、通知先受信状況を限定証跡として整理する。	本番相当環境でのS3バケットポリシー変更は影響があり得るため、テスト内容と切り戻し方法の承認を得てから実施する。
4.8-A	通知受信確認	15分	SNS Topicの通知先で、メール、Teams、監視基盤などに通知が届いたことを確認する。通知本文にイベント名、対象バケット、実行者、発生時刻、アカウント、リージョンが含まれているか確認する。	EventBridgeターゲットが別アカウントの場合は、受信側の担当者へ通知到達の確認を依頼する。
4.8-A	作業後エビデンス取得	15分	EventBridge Rule詳細、イベントパターン、ターゲット、SNS Topic、通知受信画面、対象S3バケットポリシーの作業後状態をスクリーンショットで保存する。	作業前後比較、通知到達、設定値の3点を残す。
```

### 3.2 切り戻し手順

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.8-A	切り戻し判断	5分	通知が想定どおり届かない、誤通知が多い、対象外イベントを検知する、既存通知経路へ悪影響がある、または作業継続不可と判断された場合に切り戻しを開始する。	切り戻し判断者と連絡先を作業前に決めておく。
4.8-A	EventBridge Rule切り戻し	15分	EventBridgeコンソールを開き、対象Ruleを選択する。新規作成したRuleの場合はRuleをDisableにするか、承認済みであれば削除する。既存Ruleを編集した場合は、変更前エビデンスを参照してイベントパターン、ターゲット、入力変換、状態を元に戻す。	既存Ruleを削除しない。既存Ruleの別用途ターゲットを消さない。
4.8-A	S3バケットポリシーテスト変更の切り戻し	15分	通知テストでS3バケットポリシーを変更した場合、S3コンソールで対象バケットを開き、「アクセス許可」タブの「バケットポリシー」を変更前JSONに戻して保存する。保存後、想定外のAllowまたはDenyが残っていないことを確認する。	監視設定の切り戻しとは別に、テスト操作で変更したS3ポリシーも必ず戻す。
4.8-A	切り戻し後確認	10分	EventBridge Rule詳細、対象S3バケットポリシー、SNS Topic、通知先の状態を確認する。新規Ruleを無効化または削除した場合、意図しない通知が停止していることを確認する。	切り戻し後の証跡を取得する。
```

## 4. B案 当初案を利用する場合

CloudTrailがCloudWatch Logsへ配信したイベントに対してMetric Filterを作成し、CloudWatch Alarmから既存SNS Topicへ通知する案である。

### 4.1 設定作業

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.8-B	CloudTrail配信先確認	15分	CloudTrailコンソールを開き、「証跡」から対象Trailを選択する。Trail詳細でCloudWatch Logs連携先のLog Group名とIAM Roleを確認する。CloudWatch Logs未連携の場合は、4.8だけで連携を新規追加するか、別作業として扱うかを確認する。	Metric Filter方式はCloudTrailイベントがCloudWatch Logsへ届いていることが前提である。
4.8-B	CloudWatch Logs到達確認	10分	CloudWatchコンソールを開き、「ログ」から「ロググループ」を選択する。CloudTrail連携先Log Groupを開き、最新のLog StreamまたはログイベントにCloudTrailイベントが届いていることを確認する。	ログが届いていない場合、Metric Filterを作成しても検知できない。
4.8-B	Metric Filter作成	20分	CloudWatch Logsの対象Log Groupを開き、「メトリクスフィルター」タブを選択し、「メトリクスフィルターを作成」を押す。Filter Patternに `{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }` を入力する。対象バケットを限定する場合は `&& ($.requestParameters.bucketName = "対象バケット名")` を追加する。フィルター名、Metric Namespace、Metric Name、Metric Valueを設計値どおり入力して作成する。	過去ログはメトリクス化されない。Metric Filter作成後に到着したログからメトリクスが生成される。
4.8-B	CloudWatch Alarm作成	20分	CloudWatchコンソールで「アラーム」から「アラームの作成」を選択する。Metric Filterで作成したMetricを選択し、StatisticはSum、PeriodとEvaluation Periodは設計値どおり、しきい値は1以上を基本に設定する。欠損データはnotBreaching相当の扱いにする。通知アクションとして既存SNS Topicを選択する。	通知過多を避けるため、Period、Datapoints to alarm、欠損データの扱いは設計値に合わせる。
4.8-B	Alarm保存後確認	10分	作成したAlarmの詳細画面を開き、Metric、Threshold、Evaluation、Notification、Actions enabled、SNS Topicが設計どおりであることを確認する。	Alarm作成直後はINSUFFICIENT_DATAになることがある。
4.8-B	通知テスト	30分	承認済みの方法で通知テストを実施する。実イベントで確認する場合は、S3コンソールで対象バケットの「アクセス許可」タブからバケットポリシーを承認済み内容で一時変更し、PutBucketPolicyを発生させる。CloudTrailからCloudWatch Logsへ配信され、Metric Filterがメトリクスを生成し、AlarmがALARM状態になり、既存SNS Topicから通知されることを確認する。	CloudTrailとCloudWatch Alarmは即時反映ではないため、通知まで数分から十数分かかることがある。
4.8-B	通知受信確認	15分	メール、Teams、監視基盤などで通知が届いたことを確認する。通知本文またはAlarm詳細から、要件4.8、対象Metric、対象Alarm、発生時刻が追跡できることを確認する。	通知本文にS3バケット名が直接出ない場合は、CloudWatch LogsまたはCloudTrail側の検索手順で補完する。
4.8-B	作業後エビデンス取得	15分	Metric Filter詳細、CloudWatch Alarm詳細、SNS Topic、通知受信画面、対象S3バケットポリシーの作業後状態をスクリーンショットで保存する。	設定値、通知到達、作業後状態を証跡として残す。
```

### 4.2 切り戻し手順

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.8-B	切り戻し判断	5分	通知が想定どおり届かない、Alarmが不要にALARMを継続する、既存通知Topicへ想定外の通知が出る、または作業継続不可と判断された場合に切り戻しを開始する。	切り戻し判断者と連絡先を作業前に決めておく。
4.8-B	CloudWatch Alarm切り戻し	10分	CloudWatchコンソールで「アラーム」を開き、要件4.8用に作成したAlarmを選択する。まずActionsを無効化できる場合は無効化し、その後、承認済み手順に従ってAlarmを削除する。既存Alarmを編集した場合は、変更前エビデンスを参照して設定を元に戻す。	既存Alarmを誤って削除しない。削除対象は作業で新規作成したAlarmに限定する。
4.8-B	Metric Filter切り戻し	10分	CloudWatch Logsで対象Log Groupを開き、「メトリクスフィルター」タブから要件4.8用に作成したMetric Filterを選択して削除する。既存Metric Filterを編集した場合は、変更前エビデンスを参照して元に戻す。	CloudTrail連携先Log Group自体は削除しない。
4.8-B	S3バケットポリシーテスト変更の切り戻し	15分	通知テストでS3バケットポリシーを変更した場合、S3コンソールで対象バケットを開き、「アクセス許可」タブの「バケットポリシー」を変更前JSONに戻して保存する。保存後、想定外のAllowまたはDenyが残っていないことを確認する。	監視設定の切り戻しとは別に、テスト操作で変更したS3ポリシーも必ず戻す。
4.8-B	切り戻し後確認	10分	CloudWatch Alarm一覧、CloudWatch LogsのMetric Filter一覧、対象S3バケットポリシー、SNS Topicを確認し、作業前状態へ戻っていることを確認する。	切り戻し後の証跡を取得する。
```

## 5. 当日作業で特に注意する点

| 注意点 | 理由 |
| :--- | :--- |
| 既存SNS Topicを削除しない | 他の監視通知で共用されている可能性がある |
| 既存EventBridge Ruleを削除しない | 別アカウント連携や既存監視で利用されている可能性がある |
| S3バケットポリシーの実変更テストは承認後に行う | バケットアクセス制御に直接影響する |
| 対象バケットを限定するか全バケット対象にするかを事前確定する | 検知漏れと通知過多のどちらにも影響する |
| CloudTrailからCloudWatch Logsへの遅延を考慮する | 通知テスト結果が即時に出ないことがある |
| EventBridgeターゲットが別アカウントの場合は受信側確認が必要 | 送信元アカウントだけでは最終通知を証明できない |

## 6. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 設定完了 | 選択した方式で要件4.8の検知設定が存在する |
| 通知先 | 既存SNS Topicが設定されている |
| 通知確認 | 承認済みの方法で通知到達を確認している |
| 証跡 | 作業前、設定後、通知確認、切り戻し確認の証跡がある |
| 切り戻し | 切り戻し手順と判断基準が手順書内にある |

