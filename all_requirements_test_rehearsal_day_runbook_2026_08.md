# 全要件 テストリハ当日作業手順書

作成日: 2026-07-24

対象: REQ-3.4、REQ-3.5、REQ-3.6、REQ-3.7、REQ-4.1〜REQ-4.15

対象外: REQ-A3、REQ-A4

前提: Webコンソール作業を基本とする。CLIは現場承認がある場合のみ補助的に使用する。

## 1. 使い方

この手順書は、テストリハ当日にExcelへ転記して使用する想定の作業表である。

最初に全要件共通の作業を実施し、その後に要件番号固有の設定を行う。A-gateまたはEventBridgeで対応可能と確定した要件は、該当する要件番号の行群を削除またはスキップしても、他要件の作業に影響しない構成とする。

Excelの1セルが長くなりすぎないよう、長いFilter Patternや確認手順は複数行へ分割している。

## 2. テストリハ当日作業表

| No. | 区分 | 要件番号 | 作業内容 | 作業詳細 | 目安 | 証跡 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 001 | 共通 | 全要件 | 作業開始判断 | 作業申請、作業日時、対象環境、対象アカウント、対象リージョン、作業者、確認者、連絡先を確認する。 | 5分 | 作業開始連絡 | 作業開始承認がない場合は開始しない |
| 002 | 共通 | 全要件 | AWSログイン確認 | AWS Management Consoleへログインし、対象アカウントと対象リージョンが作業対象と一致することを確認する。 | 3分 | アカウント、リージョン画面 | アカウント誤りは即中断 |
| 003 | 共通 | 全要件 | パラメータシート確認 | Log Group名、IAM Role名、Metric Namespace、Metric Name、Alarm名、SNS Topic ARN、KMS Key名、S3 bucket名、VPC IDを開く。 | 5分 | パラメータシート該当箇所 | 作業中は常に参照する |
| 004 | 共通 | 全要件 | 証跡保存先準備 | 証跡保存先フォルダを作成し、ファイル名規則を確認する。 | 3分 | 保存先フォルダ | 証跡は作業前、作業後、テスト、切り戻しで分ける |
| 005 | 共通 | 4番台 | A-gate対応可否確認 | A-gateまたはEventBridgeで対応可能と確定した要件番号を確認する。 | 5分 | A-gate対応表、EventBridge確認結果 | 対応可要件は該当REQ行群を削除またはスキップ |
| 006 | 共通 | 4番台 | EventBridge既存設定確認 | EventBridgeのRule、Event pattern、Target、別アカウントEvent bus、通知先を確認する。 | 10分 | EventBridge Rule、Target画面 | 既存設定は変更しない |
| 007 | 共通 | 4番台 | CloudTrail現状確認 | CloudTrailで対象Trailを開き、ログ記録、Management events、Multi-region、CloudWatch Logs連携状況を確認する。 | 5分 | Trail詳細、Event selectors | 対象Trail誤りは即中断 |
| 008 | 共通 | 4番台 | CloudWatch Logs連携設定前確認 | CloudTrail編集画面で、CloudWatch Logs連携先Log Groupがパラメータシート記載値と一致することを確認する。 | 5分 | CloudTrail編集画面 | Log Group不一致なら保存しない |
| 009 | 共通 | 4番台 | CloudWatch Logs連携有効化 | CloudTrailでCloudWatch Logs連携を有効化し、既存Log Groupを指定する。IAM Roleは新規作成を選択し、現場命名規則に沿ったRole名を入力する。 | 10分 | 保存前入力画面、保存後Trail詳細 | UpdateTrailが発生する。REQ-4.5の実イベントにもなる |
| 010 | 共通 | 4番台 | IAM Role確認 | IAMで新規作成されたRoleを開き、信頼されたエンティティが`cloudtrail.amazonaws.com`であることを確認する。 | 5分 | IAM Role信頼関係 | 権限不足でRole確認不可の場合は確認者へ依頼 |
| 011 | 共通 | 4番台 | IAM Role権限確認 | IAM RoleにCloudWatch Logsへの`logs:CreateLogStream`と`logs:PutLogEvents`相当の権限があることを確認する。 | 5分 | IAM Role権限画面 | 対象Log Group ARNに書き込めること |
| 012 | 共通 | 4番台 | Log Stream作成確認 | CloudWatch Logsで対象Log Groupを開き、CloudTrail用Log Streamが作成または更新されることを確認する。 | 10分 | Log Stream一覧 | 数分待機して確認 |
| 013 | 共通 | 4番台 | CloudTrailイベント到達確認 | 対象Log Groupの最新Log Streamを開き、CloudTrailイベントJSONが到達していることを確認する。 | 10分 | CloudTrailイベントJSON | ログ未到達の場合、Metric Filter作成へ進まない |
| 014 | 共通 | 4番台 | Metric Namespace確認 | Metric Namespaceは`Custom`を使用する。既存Hinemos関連Alarmとの混在が許容済みであることを確認する。 | 3分 | Namespace確認メモ | NamespaceはAlarm側でも同じ値を指定 |
| 015 | 共通 | 4番台 | SNS Topic確認 | SNSで既存Topicを開き、Topic ARN、Subscription、通知先、Confirmed状態を確認する。 | 5分 | SNS Topic、Subscription | 既存Topicは変更しない |
| 016 | 共通 | 4番台 | Alarm共通条件確認 | 4番台Alarmは原則、Statistic `Sum`、Period `5 minutes`、Threshold `>= 1`、Datapoints `1 out of 1`、Missing data `notBreaching`とする。 | 3分 | 設定値メモ | 現場設計値が優先 |
| 017 | 共通 | 4番台 | 通知テスト方針確認 | 通知テスト実施可否、通知先確認者、メール、Teams、A-gate側確認者、通知回数を確認する。 | 5分 | 通知テスト承認 | 未承認の場合はSNS Publishや実通知を行わない |
| 018 | 共通 | 3番台 | 3番台対象確認 | CloudTrailログ保存先S3、Server Access Logging保存先、CMK、VPC一覧、Flow Logs保存先を確認する。 | 10分 | 対象リソース一覧 | Prod、OPER、検証の差異を確認 |
| 019 | 3番台 | REQ-3.4 | Server Access Logging変更前確認 | S3でCloudTrailログ保存先bucketを開き、プロパティのServer Access Loggingが無効または想定状態であることを確認する。 | 5分 | 変更前Server Access Logging | 対象bucket誤りに注意 |
| 020 | 3番台 | REQ-3.4 | Target bucket確認 | Server Access Logging保存先bucketとprefixを確認する。Source bucket自身をTargetにしない。 | 5分 | Target bucket、prefix | ログのループが発生する設定を避ける |
| 021 | 3番台 | REQ-3.4 | Target bucket権限確認 | Target bucket policyで`logging.s3.amazonaws.com`からの書き込みが許可されていることを確認する。 | 5分 | Bucket policy | 権限不足時は保存前に中断 |
| 022 | 3番台 | REQ-3.4 | Server Access Logging有効化 | Source bucketのプロパティでServer Access Loggingを有効化し、Target bucketとprefixを設定する。 | 10分 | 設定画面、保存後画面 | 配信遅延あり |
| 023 | 3番台 | REQ-3.4 | Server Access Logging確認 | Target bucketの指定prefixにログオブジェクトが作成されるか確認する。すぐ出ない場合は遅延として記録する。 | 10分 | Target prefix一覧 | ベストエフォート配信 |
| 024 | 3番台 | REQ-3.5 | CloudTrail暗号化変更前確認 | CloudTrailで対象Trailを開き、KMS暗号化未設定または作業前設定を確認する。 | 5分 | Trail暗号化変更前 | 既存KMS設定がある場合は中断して確認 |
| 025 | 3番台 | REQ-3.5 | CMK作成または選定 | KMSでCloudTrailログ暗号化用のカスタマー管理対称CMKを作成または承認済み既存CMKを選択する。 | 15分 | KMS Key詳細 | Alias、タグ、説明は命名規則に合わせる |
| 026 | 3番台 | REQ-3.5 | Key Policy確認 | CMKのKey PolicyでCloudTrailが`kms:GenerateDataKey*`、`kms:DescribeKey`相当を利用できることを確認する。 | 10分 | Key Policy | `aws:SourceArn`に対象Trail ARNを指定できる形が望ましい |
| 027 | 3番台 | REQ-3.5 | ログ参照者権限確認 | CloudTrailログを参照する運用主体が、対象CMKのDecrypt権限を持つことを確認する。 | 5分 | Key usersまたはPolicy | 権限不足だとログ参照に影響 |
| 028 | 3番台 | REQ-3.5 | TrailへCMK設定 | CloudTrailのTrail編集でSSE-KMS暗号化を有効化し、対象CMKを指定して保存する。 | 10分 | 保存前、保存後Trail詳細 | 保存後に配信エラーを確認 |
| 029 | 3番台 | REQ-3.5 | CloudTrail配信確認 | Trail statusで配信エラーがないことを確認し、新規CloudTrailログがS3へ配信されることを確認する。 | 15分 | Trail status、S3新規ログ | 配信遅延あり |
| 030 | 3番台 | REQ-3.5 | S3オブジェクト暗号化確認 | 新規CloudTrailログオブジェクトの暗号化方式がSSE-KMSで対象CMKになっていることを確認する。 | 5分 | S3 object properties | 既存ログは自動再暗号化されない |
| 031 | 3番台 | REQ-3.6 | CMKローテーション変更前確認 | KMSでREQ-3.5のCMKを開き、自動キーローテーションの変更前状態を確認する。 | 3分 | Rotation変更前 | 対称カスタマー管理CMKが対象 |
| 032 | 3番台 | REQ-3.6 | CMKローテーション有効化 | KMSで自動キーローテーションを有効化する。 | 5分 | Rotation変更後 | Key IDは変わらない |
| 033 | 3番台 | REQ-3.7 | VPC Flow Logs変更前確認 | VPC一覧で利用中VPCを確認し、各VPCのFlow Logsタブで有効化状況を確認する。 | 10分 | VPC一覧、Flow Logs変更前 | 不要VPCや削除予定VPCは対象外確認 |
| 034 | 3番台 | REQ-3.7 | Flow Logs保存先確認 | Flow Logsの保存先を確認する。CloudWatch LogsまたはS3のどちらを使うかパラメータシートに合わせる。 | 5分 | 保存先設定値 | 保存先、保持期間、暗号化を確認 |
| 035 | 3番台 | REQ-3.7 | VPC Flow Logs作成 | 対象VPCでFlow Logsを作成する。Filterは設計値に従い、未指定なら`ALL`を候補とする。 | 10分/1VPC | Flow Log作成画面 | IAM RoleまたはS3 bucket policyに注意 |
| 036 | 3番台 | REQ-3.7 | Flow Logs配信確認 | Flow Logsの状態がActiveになり、CloudWatch LogsまたはS3へログが配信されることを確認する。 | 15分 | Flow Log詳細、ログ到着 | 配信遅延あり |
| 037 | 4番台 | REQ-4.1 | A-gate確認 | 不正なAPI呼び出し監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.1行群を削除またはスキップ |
| 038 | 4番台 | REQ-4.1 | Metric Filter作成 | CloudWatch Logsの対象Log GroupでMetric Filterを作成する。Filter Patternは`{ ($.errorCode = "*UnauthorizedOperation") \|\| ($.errorCode = "AccessDenied*") }`。 | 7分 | Filter Pattern、作成後Filter | AccessDenied系は通常運用でも発生し得る |
| 039 | 4番台 | REQ-4.1 | Alarm作成 | Metric Name `Req41UnauthorizedApiCallCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 通知過多の可能性を記録 |
| 040 | 4番台 | REQ-4.1 | テスト確認 | Pattern Testで一致確認を行う。承認済みの実イベントがない場合、実通知テストはAlarm ActionまたはSNSテストで代替する。 | 5分 | Pattern Test、通知結果 | 不用意に権限不足操作を連発しない |
| 041 | 4番台 | REQ-4.2 | A-gate確認 | MFAなしConsoleLogin監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.2行群を削除またはスキップ |
| 042 | 4番台 | REQ-4.2 | Metric Filter作成 | Filter Patternは`{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }`。 | 7分 | Filter Pattern、作成後Filter | 実環境でMFAなしログインは原則発生させない |
| 043 | 4番台 | REQ-4.2 | Alarm作成 | Metric Name `Req42ConsoleLoginWithoutMfaCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 1件発報が基本 |
| 044 | 4番台 | REQ-4.2 | テスト確認 | Pattern TestでMFAUsed `No` のサンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実ログイン試験は承認なしに行わない |
| 045 | 4番台 | REQ-4.3 | A-gate確認 | rootアカウント使用監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.3行群を削除またはスキップ |
| 046 | 4番台 | REQ-4.3 | Metric Filter作成 | Filter Patternは`{ ($.userIdentity.type = "Root") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != "AwsServiceEvent") }`。 | 7分 | Filter Pattern、作成後Filter | root使用は高リスク |
| 047 | 4番台 | REQ-4.3 | Alarm作成 | Metric Name `Req43RootAccountUsageCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 1件発報が妥当 |
| 048 | 4番台 | REQ-4.3 | テスト確認 | Pattern TestでRootサンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | root実ログインは実施しない |
| 049 | 4番台 | REQ-4.4 | A-gate確認 | IAMポリシー変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.4行群を削除またはスキップ |
| 050 | 4番台 | REQ-4.4 | Metric Filter作成 1/3 | Filter Pattern先頭は`{ ($.eventSource = "iam.amazonaws.com") && (`を入力する。 | 3分 | Filter Pattern | 長文のため分割 |
| 051 | 4番台 | REQ-4.4 | Metric Filter作成 2/3 | 対象イベントは`CreatePolicy`、`DeletePolicy`、`CreatePolicyVersion`、`DeletePolicyVersion`、`SetDefaultPolicyVersion`、`PutUserPolicy`、`PutGroupPolicy`、`PutRolePolicy`。 | 3分 | Filter Pattern | 各eventNameをOR条件で結合 |
| 052 | 4番台 | REQ-4.4 | Metric Filter作成 3/3 | 対象イベントに`DeleteUserPolicy`、`DeleteGroupPolicy`、`DeleteRolePolicy`、`AttachUserPolicy`、`AttachGroupPolicy`、`AttachRolePolicy`、`DetachUserPolicy`、`DetachGroupPolicy`、`DetachRolePolicy`を追加し、Metric Filterを作成する。 | 5分 | 作成後Filter | 完成Patternは設定値一覧と突合 |
| 053 | 4番台 | REQ-4.4 | Alarm作成 | Metric Name `Req44IamPolicyChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 通常変更でも通知される |
| 054 | 4番台 | REQ-4.4 | テスト確認 | Pattern TestでIAM Policy変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実IAM変更は承認なしに行わない |
| 055 | 4番台 | REQ-4.5 | A-gate確認 | CloudTrail設定変更監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 先行作業結果を優先 |
| 056 | 4番台 | REQ-4.5 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "CreateTrail") \|\| ($.eventName = "UpdateTrail") \|\| ($.eventName = "DeleteTrail") \|\| ($.eventName = "StartLogging") \|\| ($.eventName = "StopLogging") \|\| ($.eventName = "PutEventSelectors") \|\| ($.eventName = "PutInsightSelectors")) }`。 | 7分 | Filter Pattern、作成後Filter | CloudWatch Logs連携時のUpdateTrailが実イベントになる |
| 057 | 4番台 | REQ-4.5 | Alarm作成 | Metric Name `Req45CloudTrailChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 先行作業の設定値と一致させる |
| 058 | 4番台 | REQ-4.5 | テスト確認 | CloudTrailからCloudWatch Logsへの連携有効化に伴うUpdateTrailイベント到達、Metric増加、Alarm遷移、通知を確認する。 | 15分 | CloudTrailイベント、Metric、Alarm履歴、通知 | StopLoggingとDeleteTrailは実施しない |
| 059 | 4番台 | REQ-4.6 | A-gate確認 | Console認証失敗監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.6行群を削除またはスキップ |
| 060 | 4番台 | REQ-4.6 | Metric Filter作成 | Filter Patternは`{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Failure") }`。 | 7分 | Filter Pattern、作成後Filter | 誤入力でも発生し得る |
| 061 | 4番台 | REQ-4.6 | Alarm作成 | Metric Name `Req46ConsoleLoginFailureCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | しきい値1件でよいか記録 |
| 062 | 4番台 | REQ-4.6 | テスト確認 | Pattern TestでConsoleLogin Failureサンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実ログイン失敗試験は承認時のみ |
| 063 | 4番台 | REQ-4.7 | A-gate確認 | CMK無効化または削除予約監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 先行作業結果を優先 |
| 064 | 4番台 | REQ-4.7 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "kms.amazonaws.com") && (($.eventName = "DisableKey") \|\| ($.eventName = "ScheduleKeyDeletion")) }`。 | 7分 | Filter Pattern、作成後Filter | テスト専用CMKのみで実イベント確認 |
| 065 | 4番台 | REQ-4.7 | Alarm作成 | Metric Name `Req47KmsKeyDisableOrDeletionCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 1件発報が妥当 |
| 066 | 4番台 | REQ-4.7 | テスト専用CMK作成 | KMSでテスト専用の対称カスタマー管理CMKを作成し、Alias、説明、タグにテスト用途を明記する。 | 10分 | テストCMK詳細 | 実データ用途のCMKは使用しない |
| 067 | 4番台 | REQ-4.7 | DisableKeyテスト | テスト専用CMKでDisableKeyを実行し、CloudTrailイベント、Metric増加、Alarm、通知を確認する。確認後すぐEnableKeyする。 | 15分 | DisableKey、EnableKey、Alarm履歴 | 本物CMKでは実施しない |
| 068 | 4番台 | REQ-4.7 | ScheduleKeyDeletionテスト | テスト専用CMKでScheduleKeyDeletionを実行し、検知確認後すぐCancelKeyDeletionする。必要に応じてEnableKeyを確認する。 | 15分 | ScheduleKeyDeletion、CancelKeyDeletion | キャンセル証跡を必ず取得 |
| 069 | 4番台 | REQ-4.8 | A-gate確認 | S3バケットポリシー変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.8行群を削除またはスキップ |
| 070 | 4番台 | REQ-4.8 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") \|\| ($.eventName = "DeleteBucketPolicy")) }`。 | 7分 | Filter Pattern、作成後Filter | 既存A-gate対応済みなら新規作成しない |
| 071 | 4番台 | REQ-4.8 | Alarm作成 | Metric Name `Req48S3BucketPolicyChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | A-gateとの重複に注意 |
| 072 | 4番台 | REQ-4.8 | テスト確認 | Pattern TestでPutBucketPolicyサンプルを使用し、一致確認を行う。実バケットポリシー変更は承認時のみ実施する。 | 5分 | Pattern Test | 実変更時は切り戻しPolicyを用意 |
| 073 | 4番台 | REQ-4.9 | A-gate確認 | AWS Config設定変更監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.9行群を削除またはスキップ |
| 074 | 4番台 | REQ-4.9 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "config.amazonaws.com") && (($.eventName = "StopConfigurationRecorder") \|\| ($.eventName = "StartConfigurationRecorder") \|\| ($.eventName = "PutConfigurationRecorder") \|\| ($.eventName = "DeleteConfigurationRecorder") \|\| ($.eventName = "PutDeliveryChannel") \|\| ($.eventName = "DeleteDeliveryChannel") \|\| ($.eventName = "PutConfigRule") \|\| ($.eventName = "DeleteConfigRule")) }`。 | 7分 | Filter Pattern、作成後Filter | Config未導入環境は対象範囲を記録 |
| 075 | 4番台 | REQ-4.9 | Alarm作成 | Metric Name `Req49ConfigChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | AWS Config停止系は高リスク |
| 076 | 4番台 | REQ-4.9 | テスト確認 | Pattern TestでAWS Config変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実Config停止は実施しない |
| 077 | 4番台 | REQ-4.10 | A-gate確認 | Security Group変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.10行群を削除またはスキップ |
| 078 | 4番台 | REQ-4.10 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "AuthorizeSecurityGroupIngress") \|\| ($.eventName = "AuthorizeSecurityGroupEgress") \|\| ($.eventName = "RevokeSecurityGroupIngress") \|\| ($.eventName = "RevokeSecurityGroupEgress") \|\| ($.eventName = "CreateSecurityGroup") \|\| ($.eventName = "DeleteSecurityGroup") \|\| ($.eventName = "ModifySecurityGroupRules")) }`。 | 7分 | Filter Pattern、作成後Filter | 通常変更でも通知される |
| 079 | 4番台 | REQ-4.10 | Alarm作成 | Metric Name `Req410SecurityGroupChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | A-gateとの重複に注意 |
| 080 | 4番台 | REQ-4.10 | テスト確認 | Pattern TestでSecurity Group変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実SG変更は承認時のみ |
| 081 | 4番台 | REQ-4.11 | A-gate確認 | NACL変更監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.11行群を削除またはスキップ |
| 082 | 4番台 | REQ-4.11 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateNetworkAcl") \|\| ($.eventName = "DeleteNetworkAcl") \|\| ($.eventName = "CreateNetworkAclEntry") \|\| ($.eventName = "DeleteNetworkAclEntry") \|\| ($.eventName = "ReplaceNetworkAclEntry") \|\| ($.eventName = "ReplaceNetworkAclAssociation")) }`。 | 7分 | Filter Pattern、作成後Filter | 通信影響が大きい変更 |
| 083 | 4番台 | REQ-4.11 | Alarm作成 | Metric Name `Req411NetworkAclChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 1件発報が妥当 |
| 084 | 4番台 | REQ-4.11 | テスト確認 | Pattern TestでNACL変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実NACL変更は実施しない |
| 085 | 4番台 | REQ-4.12 | A-gate確認 | Network Gateway変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.12行群を削除またはスキップ |
| 086 | 4番台 | REQ-4.12 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateInternetGateway") \|\| ($.eventName = "DeleteInternetGateway") \|\| ($.eventName = "AttachInternetGateway") \|\| ($.eventName = "DetachInternetGateway") \|\| ($.eventName = "CreateCustomerGateway") \|\| ($.eventName = "DeleteCustomerGateway")) }`。 | 7分 | Filter Pattern、作成後Filter | 正式資料はIGW/Customer Gateway中心 |
| 087 | 4番台 | REQ-4.12 | Alarm作成 | Metric Name `Req412NetworkGatewayChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | NAT/TGW/VPNを含めるかは別途承認 |
| 088 | 4番台 | REQ-4.12 | テスト確認 | Pattern TestでNetwork Gateway変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実Gateway変更は実施しない |
| 089 | 4番台 | REQ-4.13 | A-gate確認 | Route Table変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.13行群を削除またはスキップ |
| 090 | 4番台 | REQ-4.13 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateRoute") \|\| ($.eventName = "DeleteRoute") \|\| ($.eventName = "ReplaceRoute") \|\| ($.eventName = "CreateRouteTable") \|\| ($.eventName = "DeleteRouteTable") \|\| ($.eventName = "AssociateRouteTable") \|\| ($.eventName = "DisassociateRouteTable") \|\| ($.eventName = "ReplaceRouteTableAssociation")) }`。 | 7分 | Filter Pattern、作成後Filter | 通信経路に直結 |
| 091 | 4番台 | REQ-4.13 | Alarm作成 | Metric Name `Req413RouteTableChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | A-gateとの重複に注意 |
| 092 | 4番台 | REQ-4.13 | テスト確認 | Pattern TestでRoute Table変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実Route変更は実施しない |
| 093 | 4番台 | REQ-4.14 | A-gate確認 | VPC変更監視がA-gateまたはEventBridgeで対応可能か確認する。 | 3分 | A-gate対応表、EventBridge証跡 | 対応可ならREQ-4.14行群を削除またはスキップ |
| 094 | 4番台 | REQ-4.14 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateVpc") \|\| ($.eventName = "DeleteVpc") \|\| ($.eventName = "ModifyVpcAttribute") \|\| ($.eventName = "AcceptVpcPeeringConnection") \|\| ($.eventName = "CreateVpcPeeringConnection") \|\| ($.eventName = "DeleteVpcPeeringConnection") \|\| ($.eventName = "RejectVpcPeeringConnection")) }`。 | 7分 | Filter Pattern、作成後Filter | VPC Peeringを含む |
| 095 | 4番台 | REQ-4.14 | Alarm作成 | Metric Name `Req414VpcChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | EndpointやSubnet変更を含める場合は別途承認 |
| 096 | 4番台 | REQ-4.14 | テスト確認 | Pattern TestでVPC変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実VPC変更は実施しない |
| 097 | 4番台 | REQ-4.15 | A-gate確認 | Organizations変更監視がA-gateまたはEventBridgeで対応済みか確認する。 | 3分 | A-gate対応表 | 対応可ならREQ-4.15行群を削除またはスキップ |
| 098 | 4番台 | REQ-4.15 | Metric Filter作成 | Filter Patternは`{ ($.eventSource = "organizations.amazonaws.com") }`。 | 7分 | Filter Pattern、作成後Filter | 管理アカウント側での確認が必要な場合あり |
| 099 | 4番台 | REQ-4.15 | Alarm作成 | Metric Name `Req415OrganizationsChangeCount`、Namespace `Custom`、共通Alarm条件、既存SNS TopicでAlarmを作成する。 | 7分 | Alarm設定、通知Action | 対象アカウントを確認 |
| 100 | 4番台 | REQ-4.15 | テスト確認 | Pattern TestでOrganizations変更サンプルを使用し、一致確認を行う。 | 5分 | Pattern Test | 実Organizations変更は実施しない |
| 101 | 共通 | 4番台 | Metric Filter最終確認 | 対象Log GroupのMetric Filter一覧で、作成対象要件分が存在し、Filter名とMetric Nameが設計値と一致することを確認する。 | 10分 | Metric Filter一覧 | A-gate対応要件は作成しない |
| 102 | 共通 | 4番台 | Alarm最終確認 | CloudWatch Alarm一覧で、作成対象要件分が存在し、Metric、条件、Actionが設計値と一致することを確認する。 | 10分 | Alarm一覧、Alarm詳細 | OKまたは想定状態を確認 |
| 103 | 共通 | 4番台 | 通知到達確認 | 承認済みの方法でSNS、メール、Teams、A-gate側への通知到達を確認する。 | 15分 | 通知受信結果 | 未実施の場合は未実施理由を記録 |
| 104 | 共通 | 全要件 | CloudTrail作業証跡確認 | CloudTrail Event historyで当日作業に関係する`UpdateTrail`、`PutMetricFilter`、`PutMetricAlarm`、KMS操作等を確認する。 | 10分 | CloudTrail Event history | 見えない場合は到達遅延または権限不足を記録 |
| 105 | 共通 | 全要件 | 変更後設定値突合 | パラメータシート、手順書、Webコンソールの設定値を突合し、差異を記録する。 | 10分 | 設定値突合結果 | 差異がある場合はリーダー判断 |
| 106 | 切り戻し | 4番台 | Alarm切り戻し | 切り戻し判断時は、今回作成したAlarmのActionを無効化し、承認後に今回作成分のみ削除する。 | 10分 | 切り戻し前後Alarm | 既存Alarmは削除しない |
| 107 | 切り戻し | 4番台 | Metric Filter切り戻し | 切り戻し判断時は、今回作成したMetric Filterのみ削除する。 | 10分 | 切り戻し前後Metric Filter | 既存Filterは削除しない |
| 108 | 切り戻し | REQ-3.4 | Server Access Logging切り戻し | 切り戻し判断時は、Source bucketのServer Access Loggingを作業前状態へ戻す。 | 5分 | Server Access Logging切り戻し後 | 配信済みログは保持方針に従う |
| 109 | 切り戻し | REQ-3.5 | CloudTrail CMK切り戻し | 切り戻し判断時は、TrailのKMS設定を作業前状態へ戻す。作成済みCMKは無効化または削除しない。 | 10分 | Trail暗号化設定 | 既に暗号化されたログ参照にCMKが必要 |
| 110 | 切り戻し | REQ-3.7 | VPC Flow Logs切り戻し | 切り戻し判断時は、今回作成したFlow Logのみ削除する。 | 10分 | Flow Logs切り戻し後 | 配信済みログは保持方針に従う |
| 111 | 切り戻し | REQ-4.7 | テスト専用CMK後始末 | テスト専用CMKでScheduleKeyDeletionを実施した場合、CancelKeyDeletion済みであることを確認する。最終的な削除予約は別途承認に従う。 | 5分 | CMK状態 | Pending deletionを残さない方針なら削除予約をキャンセル |
| 112 | 共通 | 全要件 | 証跡ファイル確認 | 作業前、作業後、通知、CloudTrail、切り戻し有無、未実施理由の証跡ファイルが揃っていることを確認する。 | 10分 | 証跡一覧 | ファイル名規則に合わせる |
| 113 | 共通 | 全要件 | 未実施項目整理 | A-gate対応済み、権限不足、承認未取得、配信遅延、実イベント未実施などの理由を記録する。 | 10分 | 未実施項目一覧 | テストリハ結果報告へ転記 |
| 114 | 共通 | 全要件 | 作業完了報告 | 対象環境、実施要件、作業結果、通知結果、切り戻し有無、残課題、証跡保存先をまとめて報告する。 | 5分 | 作業完了連絡 | 完了判断者の確認を受ける |
