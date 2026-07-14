# 要件4番台 当日Webコンソール作業手順書テンプレート

作成日: 2026-07-15

この資料は、要件4.1〜4.15のCloudTrail系監視設定を、当日作業用のExcel管理表へ貼り付けるための雛形である。

Excel列は以下を想定する。

```text
要件番号	作業内容	作業にかかる時間	作業詳細	備考
```

基本案は、CloudTrailのManagement EventをCloudWatch Logsへ連携し、Metric Filter、CloudWatch Alarm、既存SNS Topicで通知する構成である。既存EventBridge Ruleで同等監視が存在する場合は、既存設定を流用するか、当初案で新規作成するかを作業前に決める。

## 1. 作業前提

| 項目 | 前提 |
| :--- | :--- |
| 対象要件 | 4.1〜4.15 |
| 監視方式の基本案 | CloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> 既存SNS Topic |
| 代替案 | 既存EventBridge Ruleを利用し、既存SNS Topicまたは既存通知経路へ通知 |
| 通知先 | 既存SNS Topicを利用 |
| 作業端末 | Windows上のWebブラウザ、AWS Management Console |
| 作業条件 | 対象アカウント、対象リージョン、対象CloudTrail、対象Log Group、通知先Topic、テスト可否、切り戻し判断者が確定済み |

## 2. 共通手順

4.1〜4.15の全作業に共通する手順である。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	作業開始前の前提確認	15分	AWS Management Consoleへログインし、画面右上で対象アカウントと対象リージョンを確認する。対象CloudTrail名、CloudWatch Logs連携先Log Group名、既存SNS Topic名またはARN、作業対象要件、作業時間、作業承認、通知テスト可否、切り戻し判断者を確認する。	アカウント、リージョン、Log Groupを誤ると別環境の監視設定を変更するため、最初に必ず確認する。
4.x	変更前エビデンス取得	30分	CloudTrail、CloudWatch Logs、CloudWatch Alarm、SNS、EventBridgeの関連画面を開き、変更前の状態をスクリーンショットで保存する。CloudTrailは対象Trail詳細、CloudWatch Logsは対象Log GroupとMetric Filter一覧、CloudWatchはAlarm一覧、SNSは対象TopicとSubscription一覧、EventBridgeは関連Rule一覧とTargetを取得する。	作業前後比較と切り戻しの基準になる。
4.x	CloudTrail設定確認	15分	CloudTrailコンソールを開き、「証跡」から対象Trailを選択する。Management Eventが記録対象であること、Read / Writeの対象範囲、CloudWatch Logs連携先Log Group、CloudWatch Logs Roleを確認する。	4番台はManagement Eventを前提とする。CloudWatch Logs未連携の場合は本作業前に方針確認が必要である。
4.x	CloudWatch Logs到達確認	10分	CloudWatchコンソールを開き、「ログ」から「ロググループ」を選択する。CloudTrail連携先Log Groupを開き、最新Log StreamまたはログイベントにCloudTrailイベントが届いていることを確認する。	ログが届いていない場合、Metric Filterを作成しても検知できない。
4.x	既存SNS Topic確認	10分	SNSコンソールを開き、「トピック」から既存通知Topicを選択する。「サブスクリプション」タブでメール、Teams連携、監視基盤連携などの通知先を確認し、状態がConfirmedまたは有効であることを確認する。	既存Topicは他用途で利用されている可能性があるため、Topic自体を削除しない。
4.x	既存EventBridge重複確認	20分	EventBridgeコンソールを開き、「イベントバス」から対象イベントバスを選択し、「ルール」を開く。CloudTrail、IAM、KMS、S3、Config、SecurityGroup、NACL、RouteTable、Organizationsなどの関連Ruleが存在するか確認する。対象Ruleがある場合はイベントパターン、ターゲット、別アカウント送信有無、通知先を確認する。	同等監視が既にある場合、新規Metric Filter / Alarmを追加すると二重通知になる可能性がある。
```

## 3. 基本案 CloudWatch Metric Filter / Alarm作業

4.1〜4.15を横展開する場合の主作業である。Filter Patternは後続の「要件別Filter Pattern候補」を参照する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.1	不正なAPI呼び出し監視の設定	20分	CloudWatchコンソールで「ログ」からCloudTrail連携先Log Groupを開き、「メトリクスフィルター」タブで「メトリクスフィルターを作成」を選択する。要件4.1のFilter Patternを入力し、サンプルログで一致確認する。Metric Namespace、Metric Name、Metric Valueを入力して作成する。続けてCloudWatchの「アラーム」から該当Metricを選択し、Sum、しきい値1以上、欠損データnotBreaching、通知先に既存SNS Topicを指定する。	AccessDenied系は通常運用でも発生し得るため、1件発報でよいか作業前に確認する。
4.2	MFAなしコンソールログイン監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.2のMetric Filterを作成する。Filter PatternはConsoleLogin成功かつMFAUsedがNoのイベントを対象にする。Metric作成後、CloudWatch Alarmで該当Metricを選択し、通知先に既存SNS Topicを指定する。	MFA強制済みでも、監査要件上は検知設定が必要か確認する。
4.3	rootアカウント使用監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.3のMetric Filterを作成する。Filter PatternはuserIdentity.typeがRootのイベントを対象にする。Metric作成後、CloudWatch Alarmで該当Metricを選択し、1件以上で既存SNS Topicへ通知する。	root利用は重要度が高いため、1件発報が基本である。
4.4	IAMポリシー変更監視の設定	25分	CloudWatch Logsの対象Log Groupで要件4.4のMetric Filterを作成する。Filter PatternはIAMのPolicy作成、削除、Version変更、Inline Policy変更、Attach、Detachを対象にする。Metric作成後、CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	IAMユーザー、ロール、グループ変更まで含めるかは別要件化または設計判断が必要である。
4.5	CloudTrail設定変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.5のMetric Filterを作成する。Filter PatternはCreateTrail、UpdateTrail、DeleteTrail、StartLogging、StopLogging、PutEventSelectors、PutInsightSelectorsを対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	正当な復旧操作や設定変更でも通知されるため、通知後の確認手順を運用側で持つ。
4.6	コンソール認証失敗監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.6のMetric Filterを作成する。Filter PatternはConsoleLogin失敗を対象にする。Metric作成後、CloudWatch Alarmで該当Metricを選択し、既存SNS Topicへ通知する。	誤入力でも発生するため、1件発報か複数件発報かを作業前に確認する。
4.7	CMK無効化または削除予約監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.7のMetric Filterを作成する。Filter PatternはKMSのDisableKeyとScheduleKeyDeletionを対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	鍵の無効化や削除予約は影響が大きいため、1件発報が基本である。
4.8	S3バケットポリシー変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.8のMetric Filterを作成する。Filter PatternはS3のPutBucketPolicyとDeleteBucketPolicyを対象にする。対象バケットを限定する場合はrequestParameters.bucketNameを追加する。Metric作成後、CloudWatch Alarmで既存SNS Topicへ通知する。	既存EventBridgeで同等設定がある場合、二重通知にならないよう先に方式を確定する。
4.9	AWS Config変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.9のMetric Filterを作成する。Filter PatternはConfig Recorder、Delivery Channel、Config Ruleの作成、変更、削除を対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	AWS Config未導入または一部環境のみの場合、対象範囲を確認する。
4.10	Security Group変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.10のMetric Filterを作成する。Filter PatternはIngress、Egress、Security Group作成、削除、ルール変更を対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	通常変更でも通知されるため、変更管理番号との突合が必要である。
4.11	NACL変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.11のMetric Filterを作成する。Filter PatternはNetwork ACL作成、削除、Entry作成、削除、置換、関連付け変更を対象にする。Metric作成後、CloudWatch Alarmで既存SNS Topicへ通知する。	NACL変更は通信影響が大きいため、通知後の確認先を明確にする。
4.12	Network Gateway変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.12のMetric Filterを作成する。Filter Patternは正式資料に沿ってInternet GatewayとCustomer Gatewayの作成、削除、Attach、Detachを対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	NAT Gateway、Transit Gateway、VPN Gatewayを含めるかは作業前に確認する。
4.13	Route Table変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.13のMetric Filterを作成する。Filter PatternはRoute作成、削除、置換、Route Table作成、削除、関連付け、関連付け解除、関連付け置換を対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	通信経路変更の通知であるため、通知後の確認先を明確にする。
4.14	VPC変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.14のMetric Filterを作成する。Filter PatternはVPC作成、削除、属性変更、VPC Peeringの作成、承認、拒否、削除を対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	VPC EndpointやSubnet変更まで含めるかは作業前に確認する。
4.15	AWS Organizations変更監視の設定	20分	CloudWatch Logsの対象Log Groupで要件4.15のMetric Filterを作成する。Filter Patternはorganizations.amazonaws.comのイベントを対象にする。Metric作成後、CloudWatch Alarmを作成し、既存SNS Topicへ通知する。	Organizationsは管理アカウント側にイベントが出る可能性があるため、対象アカウントを作業前に確認する。
```

## 4. 既存EventBridgeを利用する場合

既存EventBridge Ruleで同等イベントを検知している場合の作業である。4番台の半数程度で既存Ruleが存在する場合は、各Ruleを一括で確認し、通知経路が成立しているか確認する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	EventBridge既存Ruleの実態確認	30分	EventBridgeコンソールで対象イベントバスを開き、「ルール」一覧から4番台に関係するRuleを確認する。各Ruleのイベントパターン、状態、ターゲット、入力変換、実行ロール、別アカウントEvent bus送信有無を確認する。	別アカウント送信の場合、送信元だけでは最終通知を証明できない。
4.x	EventBridgeターゲット確認	20分	対象Ruleの「ターゲット」タブを開き、SNS Topic、Lambda、別アカウントEvent bus、CloudWatch Logs、Systems Managerなどのターゲットを確認する。SNS Topicの場合はSNSコンソールでSubscriptionが有効であることを確認する。	ターゲットが別アカウントEvent busの場合、受信側アカウントのRuleと通知先を確認する必要がある。
4.x	EventBridge通知テスト	30分	承認済みの方法で対象イベントを発生させるか、実イベントを起こせない場合はRuleのイベントパターン、メトリクス、ターゲット到達、通知先受信状況を限定証跡として整理する。通知が届いた場合は、イベント名、対象リソース、実行者、発生時刻が追跡できることを確認する。	本番相当環境で実イベントを起こす場合は、影響と切り戻しを承認済みにする。
4.x	EventBridge方式の切り戻し	20分	新規Ruleを作成した場合はRuleをDisableまたは削除する。既存Ruleを編集した場合は、変更前エビデンスを参照してイベントパターン、ターゲット、入力変換、状態を元に戻す。既存Ruleの別用途ターゲットは削除しない。	EventBridgeを使わない方針へ戻す場合は、CloudWatch Metric Filter / Alarm方式の作業へ切り替える。
```

## 5. 作業後確認

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	作業後設定確認	30分	作成または変更したMetric Filter、CloudWatch Alarm、EventBridge Rule、SNS Topicの設定を確認する。対象要件、Filter Pattern、Metric Name、Alarm名、通知先、状態が設計値と一致していることを確認する。	4.1〜4.15を一括実施した場合、要件番号と設定名の対応表を必ず残す。
4.x	通知受信確認	30分	承認済みのテストで通知が届くことを確認する。メール、Teams、監視基盤などの通知先で受信を確認し、通知本文またはAlarm詳細から要件番号、イベント名、発生時刻、対象リソースを追跡できることを確認する。	実イベントを起こせない要件は、Pattern Testと設定証跡を限定的な確認結果として扱う。
4.x	作業後エビデンス取得	30分	CloudWatch LogsのMetric Filter一覧、各Metric Filter詳細、CloudWatch Alarm一覧、各Alarm詳細、SNS Topic、通知受信画面、EventBridge関連Ruleをスクリーンショットで保存する。	作業前後比較、設定値、通知到達を証跡として残す。
4.x	完了報告	15分	作業対象要件、作成または変更した設定、通知テスト結果、未確認事項、切り戻し不要の判断、残課題を整理し、リーダーまたはレビュー担当者へ報告する。	未確認の既存EventBridgeや別アカウント通知がある場合は残課題として明記する。
```

## 6. 共通切り戻し手順

CloudWatch Metric Filter / Alarm方式の切り戻しである。EventBridge方式の切り戻しは「4. 既存EventBridgeを利用する場合」を参照する。

```tsv
要件番号	作業内容	作業にかかる時間	作業詳細	備考
4.x	切り戻し判断	10分	通知が想定どおり届かない、誤通知が多い、既存通知Topicへ想定外の通知が出る、Alarmが不要にALARMを継続する、または作業継続不可と判断された場合に切り戻しを開始する。	切り戻し判断者と連絡先を作業前に決めておく。
4.x	CloudWatch Alarm切り戻し	30分	CloudWatchコンソールで「アラーム」を開き、今回作成した4番台用Alarmを選択する。まずActionsを無効化できる場合は無効化し、その後、承認済み手順に従ってAlarmを削除する。既存Alarmを編集した場合は、変更前エビデンスを参照して元に戻す。	既存Alarmを誤って削除しない。削除対象は今回作成したAlarmに限定する。
4.x	Metric Filter切り戻し	30分	CloudWatch Logsで対象Log Groupを開き、「メトリクスフィルター」タブから今回作成した4番台用Metric Filterを削除する。既存Metric Filterを編集した場合は、変更前エビデンスを参照して元に戻す。	CloudTrail連携先Log Group自体は削除しない。
4.x	通知先切り戻し	10分	既存SNS Topicを利用した場合、Topic自体は削除しない。新規SubscriptionやAlarm Actionのみ追加した場合は、承認済み範囲で追加分だけ戻す。	既存通知経路を止めない。
4.x	切り戻し後確認	20分	CloudWatch Alarm一覧、CloudWatch LogsのMetric Filter一覧、SNS Topic、EventBridge Ruleを確認し、作業前状態へ戻っていることを確認する。切り戻し後の証跡を保存する。	作業前エビデンスと比較する。
```

## 7. 要件別Filter Pattern候補

以下はCloudWatch Logs Metric Filter用の候補である。正式な設定値は、現場命名規則、対象アカウント、対象リージョン、既存EventBridge設定、通知先確認後に確定する。

| 要件 | 監視対象 | Filter Pattern |
| :--- | :--- | :--- |
| 4.1 | 不正なAPI呼び出し | 後続コードブロック参照 |
| 4.2 | MFAなし管理コンソールサインイン | 後続コードブロック参照 |
| 4.3 | rootアカウント使用 | 後続コードブロック参照 |
| 4.4 | IAMポリシー変更 | 後続コードブロック参照 |
| 4.5 | CloudTrail設定変更 | 後続コードブロック参照 |
| 4.6 | AWS Management Console認証失敗 | 後続コードブロック参照 |
| 4.7 | CMK無効化または削除予約 | 後続コードブロック参照 |
| 4.8 | S3バケットポリシー変更 | 後続コードブロック参照 |
| 4.9 | AWS Config設定変更 | 後続コードブロック参照 |
| 4.10 | Security Group変更 | 後続コードブロック参照 |
| 4.11 | NACL変更 | 後続コードブロック参照 |
| 4.12 | Network Gateway変更 | 後続コードブロック参照 |
| 4.13 | Route Table変更 | 後続コードブロック参照 |
| 4.14 | VPC変更 | 後続コードブロック参照 |
| 4.15 | AWS Organizations変更 | 後続コードブロック参照 |

GitHub表示でCloudWatch LogsのJSON Filter Patternが数式扱いされることを避けるため、Filter Patternは表内ではなくコードブロックで記載する。

### 4.1 不正なAPI呼び出し

```text
{ ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }
```

### 4.2 MFAなし管理コンソールサインイン

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }
```

### 4.3 rootアカウント使用

```text
{ ($.userIdentity.type = "Root") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != "AwsServiceEvent") }
```

### 4.4 IAMポリシー変更

```text
{ ($.eventSource = "iam.amazonaws.com") && (($.eventName = "CreatePolicy") || ($.eventName = "DeletePolicy") || ($.eventName = "CreatePolicyVersion") || ($.eventName = "DeletePolicyVersion") || ($.eventName = "SetDefaultPolicyVersion") || ($.eventName = "PutUserPolicy") || ($.eventName = "PutGroupPolicy") || ($.eventName = "PutRolePolicy") || ($.eventName = "DeleteUserPolicy") || ($.eventName = "DeleteGroupPolicy") || ($.eventName = "DeleteRolePolicy") || ($.eventName = "AttachUserPolicy") || ($.eventName = "AttachGroupPolicy") || ($.eventName = "AttachRolePolicy") || ($.eventName = "DetachUserPolicy") || ($.eventName = "DetachGroupPolicy") || ($.eventName = "DetachRolePolicy")) }
```

### 4.5 CloudTrail設定変更

```text
{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "CreateTrail") || ($.eventName = "UpdateTrail") || ($.eventName = "DeleteTrail") || ($.eventName = "StartLogging") || ($.eventName = "StopLogging") || ($.eventName = "PutEventSelectors") || ($.eventName = "PutInsightSelectors")) }
```

### 4.6 AWS Management Console認証失敗

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Failure") }
```

### 4.7 CMK無効化または削除予約

```text
{ ($.eventSource = "kms.amazonaws.com") && (($.eventName = "DisableKey") || ($.eventName = "ScheduleKeyDeletion")) }
```

### 4.8 S3バケットポリシー変更

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

### 4.9 AWS Config設定変更

```text
{ ($.eventSource = "config.amazonaws.com") && (($.eventName = "StopConfigurationRecorder") || ($.eventName = "StartConfigurationRecorder") || ($.eventName = "PutConfigurationRecorder") || ($.eventName = "DeleteConfigurationRecorder") || ($.eventName = "PutDeliveryChannel") || ($.eventName = "DeleteDeliveryChannel") || ($.eventName = "PutConfigRule") || ($.eventName = "DeleteConfigRule")) }
```

### 4.10 Security Group変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "AuthorizeSecurityGroupIngress") || ($.eventName = "AuthorizeSecurityGroupEgress") || ($.eventName = "RevokeSecurityGroupIngress") || ($.eventName = "RevokeSecurityGroupEgress") || ($.eventName = "CreateSecurityGroup") || ($.eventName = "DeleteSecurityGroup") || ($.eventName = "ModifySecurityGroupRules")) }
```

### 4.11 NACL変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateNetworkAcl") || ($.eventName = "DeleteNetworkAcl") || ($.eventName = "CreateNetworkAclEntry") || ($.eventName = "DeleteNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclAssociation")) }
```

### 4.12 Network Gateway変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateInternetGateway") || ($.eventName = "DeleteInternetGateway") || ($.eventName = "AttachInternetGateway") || ($.eventName = "DetachInternetGateway") || ($.eventName = "CreateCustomerGateway") || ($.eventName = "DeleteCustomerGateway")) }
```

### 4.13 Route Table変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateRoute") || ($.eventName = "DeleteRoute") || ($.eventName = "ReplaceRoute") || ($.eventName = "CreateRouteTable") || ($.eventName = "DeleteRouteTable") || ($.eventName = "AssociateRouteTable") || ($.eventName = "DisassociateRouteTable") || ($.eventName = "ReplaceRouteTableAssociation")) }
```

### 4.14 VPC変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateVpc") || ($.eventName = "DeleteVpc") || ($.eventName = "ModifyVpcAttribute") || ($.eventName = "AcceptVpcPeeringConnection") || ($.eventName = "CreateVpcPeeringConnection") || ($.eventName = "DeleteVpcPeeringConnection") || ($.eventName = "RejectVpcPeeringConnection")) }
```

### 4.15 AWS Organizations変更

```text
{ ($.eventSource = "organizations.amazonaws.com") }
```

## 8. 当日作業で特に注意する点

| 注意点 | 理由 |
| :--- | :--- |
| 既存SNS Topicを削除しない | 他の監視通知で共用されている可能性がある |
| 既存EventBridge Ruleを削除しない | 別アカウント連携や既存監視で利用されている可能性がある |
| 対象アカウントと対象リージョンを誤らない | 監視対象外環境へ設定しても検知できない |
| Organizationsは管理アカウント側を確認する | メンバーアカウントだけではイベントを拾えない可能性がある |
| 通知テストで実変更を起こす場合は承認を取る | IAM、KMS、CloudTrail、ネットワーク系は影響が大きい |
| 既存EventBridgeとCloudWatch Alarmの二重通知を避ける | 通知過多と運用混乱につながる |

## 9. 完了条件

| 条件 | 内容 |
| :--- | :--- |
| 設定完了 | 対象要件のMetric Filter / AlarmまたはEventBridge Ruleが存在する |
| 通知先 | 既存SNS Topicまたは既存通知経路が設定されている |
| 通知確認 | 承認済みの方法で通知到達を確認している |
| 証跡 | 作業前、設定後、通知確認、切り戻し確認の証跡がある |
| 切り戻し | 切り戻し手順と判断基準が手順書内にある |
