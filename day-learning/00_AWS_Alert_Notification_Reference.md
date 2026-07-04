# AWSアラート通知設定リファレンス

このメモは、金融系AWS環境でアラート通知設定を検討・実装するための確認資料である。
目的は、いきなり設定を作ることではなく、現場の既存運用、通知先、承認ルール、証跡要件を確認したうえで、安全に監視設定を追加することである。

想定する主な対象は以下。

- S3 Bucket Policy変更検知
- NACL変更検知
- Route Table変更検知
- VPC Flow Logs有効化状況の確認
- GuardDuty Finding通知
- CloudTrail / EventBridge / SNS / CloudWatch Logs / CloudWatch Alarmの組み合わせ

## 1. 基本方針

金融現場では、アラート通知設定そのものよりも、通知の意味、通知先、対応手順、証跡が重要になる。

技術的にはEventBridgeやCloudWatch Alarmを設定すれば通知は出せる。
ただし、通知先や運用ルールを確認しないまま作ると、重複通知、誤通知、対応者不明、夜間通知の扱い不明などが発生する。

現場での基本姿勢:

```text
既存の監視方式、通知先、対応フローを確認したうえで、
必要な変更イベントだけを検知する形で設定します。
変更前後の設定値とテスト結果は証跡として残します。
```

短く言う場合:

```text
まず既存通知先と運用フローを確認してから、EventBridgeやSNSで必要なイベントだけ通知する形にします。
```

## 2. よくある通知構成

### 2.1 EventBridge + SNS

CloudTrailに記録されたAPI操作をEventBridgeで拾い、SNSへ通知する構成。
S3 Bucket Policy、NACL、Route Tableなどの設定変更検知に向いている。

```text
AWS API操作
  ↓
CloudTrail Management Event
  ↓
EventBridge Rule
  ↓
SNS Topic
  ↓
メール / Teams連携 / 監視製品 / SIEM
```

向いている用途:

- 設定変更が発生したら即時通知したい
- CloudTrailのEventName単位で検知したい
- 通知先をSNSや外部連携に流したい
- 変更系APIだけを拾いたい

### 2.2 CloudTrail + CloudWatch Logs + Metric Filter + Alarm + SNS

CloudTrailログをCloudWatch Logsへ配送し、Metric Filterで特定イベントをメトリクス化し、CloudWatch Alarmで通知する構成。

```text
CloudTrail
  ↓
CloudWatch Logs
  ↓
Metric Filter
  ↓
CloudWatch Metric
  ↓
CloudWatch Alarm
  ↓
SNS Topic
```

向いている用途:

- CloudWatch Alarmとして管理したい
- メトリクス化して件数を見たい
- しきい値や評価期間を持たせたい
- 既存監視がCloudWatch Alarm中心である

注意点:

- CloudTrailからCloudWatch Logsへの連携が必要
- Metric Filterのパターン設計が必要
- アラーム評価タイミングにより即時性はEventBridgeよりやや落ちる

### 2.3 GuardDuty + EventBridge + SNS

GuardDuty FindingをEventBridgeで拾い、SNSや監視製品へ通知する構成。

```text
GuardDuty Finding
  ↓
EventBridge Rule
  ↓
SNS Topic / Lambda / 監視製品
  ↓
一次対応
```

向いている用途:

- GuardDuty Finding発生時に即時通知したい
- SeverityやFinding Typeで通知条件を分けたい
- 手順書に沿った一次対応へつなげたい

## 3. 金融現場で最初にヒアリングすること

### 3.1 作業範囲

```text
今回のタスクは、通知設定の新規作成まで実施しますか。
それとも現状確認、設定案作成、手順書作成まででしょうか。
```

```text
対象は本番環境ですか。検証環境ですか。
本番反映前に検証環境で同じ設定を試す流れはありますか。
```

```text
対象AWSアカウントは1つですか。複数アカウントですか。
三行・複数システム・複数テナントで分かれていますか。
```

### 3.2 既存監視

```text
既存の監視基盤は何を使っていますか。
CloudWatch、EventBridge、SNS、Teams、メール、SIEM、JP1、Hinemos、監視製品などのどれでしょうか。
```

```text
既に同じようなEventBridge RuleやCloudWatch Alarmはありますか。
重複通知にならないように既存設定を確認したいです。
```

```text
アラート通知は既存のSNS Topicを使いますか。
それとも今回新規でTopicを作成しますか。
```

### 3.3 通知先

```text
通知先はメール、Teams、監視製品、SIEM、チケットシステムのどれですか。
```

```text
通知先のメールアドレス、Teamsチャネル、監視連携先は誰が管理していますか。
```

```text
通知先に本番運用チーム、セキュリティチーム、アプリチームのどこまで含めますか。
```

```text
夜間・休日も通知対象ですか。
営業時間内のみの一次確認ですか。
```

### 3.4 通知条件

```text
変更が発生したらすべて通知しますか。
未承認変更と思われるものだけ通知しますか。
```

```text
対象リソースを絞りますか。
例: 特定S3バケット、特定VPC、特定Route Table、特定NACLのみ。
```

```text
ReadOnlyのAPIも通知しますか。
それとも設定変更を伴うWrite系APIだけ通知しますか。
```

```text
通知除外したいメンテナンス作業、定期作業、自動化Roleはありますか。
```

### 3.5 対応フロー

```text
通知を受けた後、誰が一次確認しますか。
```

```text
一次確認で見るべき項目は決まっていますか。
例: 実行者、実行時刻、送信元IP、対象リソース、変更内容、承認有無。
```

```text
緊急度の分類はありますか。
例: High / Medium / Low、即時対応 / 翌営業日対応。
```

```text
GuardDuty Finding発生時の連絡先、起票先、エスカレーション先は決まっていますか。
```

### 3.6 証跡

```text
作業証跡として、CLIのJSON出力と画面スクリーンショットの両方を残す認識でよいですか。
```

```text
証跡ファイルの保存先、命名規則、提出形式はありますか。
```

```text
変更前、変更後、テスト結果、切り戻し確認をそれぞれ保存する認識でよいですか。
```

### 3.7 料金・ログ量

```text
通知対象のイベント量は多くなりそうですか。
大量通知やログ増加の懸念があるため、対象イベントを絞ってよいですか。
```

```text
VPC Flow Logsを有効化する場合、保存先、保持期間、対象トラフィック、ログ量の見積もりは確認済みですか。
```

```text
CloudWatch Logsの保持期間とKMS暗号化要件はありますか。
```

## 4. 検知対象イベント一覧

### 4.1 S3 Bucket Policy変更

| 検知したい操作 | CloudTrail EventName |
|---|---|
| Bucket Policy作成・更新 | `PutBucketPolicy` |
| Bucket Policy削除 | `DeleteBucketPolicy` |

確認ポイント:

- 対象バケットを絞るか
- 全S3バケットを対象にするか
- 実行者が人かRoleか
- Terraformや運用自動化Roleによる変更をどう扱うか

### 4.2 NACL変更

| 検知したい操作 | CloudTrail EventName |
|---|---|
| NACL作成 | `CreateNetworkAcl` |
| NACL削除 | `DeleteNetworkAcl` |
| NACL Entry作成 | `CreateNetworkAclEntry` |
| NACL Entry変更 | `ReplaceNetworkAclEntry` |
| NACL Entry削除 | `DeleteNetworkAclEntry` |
| Subnet関連付け変更 | `ReplaceNetworkAclAssociation` |

確認ポイント:

- 変更対象NACLを絞るか
- 全VPCのNACLを対象にするか
- Security Group変更も対象に含めるか
- ネットワークチームの承認フローと突き合わせるか

### 4.3 Route Table変更

| 検知したい操作 | CloudTrail EventName |
|---|---|
| Route Table作成 | `CreateRouteTable` |
| Route Table削除 | `DeleteRouteTable` |
| Route作成 | `CreateRoute` |
| Route変更 | `ReplaceRoute` |
| Route削除 | `DeleteRoute` |
| Route Table関連付け | `AssociateRouteTable` |
| Route Table関連付け変更 | `ReplaceRouteTableAssociation` |
| Route Table関連付け解除 | `DisassociateRouteTable` |

確認ポイント:

- デフォルトルート `0.0.0.0/0` の変更を特に重視するか
- Transit Gateway、NAT Gateway、Internet Gateway、VPC Endpoint向けルートをどう扱うか
- 既存ネットワーク設計書との突き合わせが必要か

### 4.4 VPC Flow Logs

VPC Flow Logsは、通信そのものを通知するというより、通信メタデータを保存して調査可能にする機能である。
アラート対象としては、Flow Logs設定変更も確認候補になる。

| 検知したい操作 | CloudTrail EventName |
|---|---|
| Flow Logs作成 | `CreateFlowLogs` |
| Flow Logs削除 | `DeleteFlowLogs` |

有効化時の確認ポイント:

- 対象単位: VPC / Subnet / ENI
- トラフィックタイプ: `ACCEPT` / `REJECT` / `ALL`
- 保存先: CloudWatch Logs / S3
- Log Format: デフォルト / カスタム
- 保持期間
- KMS暗号化
- ログ量と料金
- 既存SIEM連携の有無

### 4.5 GuardDuty Finding

GuardDutyは、FindingをEventBridgeへ送ることができる。
Finding TypeやSeverityで通知条件を絞ることがある。

確認ポイント:

- すべてのFindingを通知するか
- High / Medium以上だけ通知するか
- Sample Findingを本番で作成してよいか
- Archive済みFindingの扱い
- Suppression Ruleの有無
- 対応手順書の有無

## 5. EventBridge + SNSで作る場合

### 5.1 設定の流れ

```text
1. CloudTrailが有効であることを確認する
2. 通知先SNS Topicを確認または作成する
3. SNS Subscriptionを確認または作成する
4. Emailの場合は購読確認を完了する
5. EventBridge Ruleを作成する
6. EventBridge RuleのTargetにSNS Topicを設定する
7. テスト通知を実施する
8. CloudTrailで実イベントが拾えることを確認する
9. 証跡を保存する
```

### 5.2 CloudTrail確認

```bash
PROFILE_NAME="project-prod"
REGION="ap-northeast-1"

aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager
```

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --trail-name "<trail-name>" \
  --output json \
  --no-cli-pager
```

見るポイント:

- Trailが存在するか
- Management Eventを記録しているか
- Multi-Region Trailか
- Organization Trailか
- CloudWatch Logs連携があるか
- S3保存先はどこか

### 5.3 SNS Topic作成

既存Topicを使う場合は新規作成しない。
新規作成が承認された場合のみ作成する。

```bash
TOPIC_NAME="project-security-change-alert"

aws sns create-topic \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$TOPIC_NAME" \
  --output json \
  --no-cli-pager
```

Topic ARN確認:

```bash
aws sns list-topics \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

### 5.4 SNS Email Subscription作成

メール通知の場合。

```bash
TOPIC_ARN="arn:aws:sns:ap-northeast-1:123456789012:project-security-change-alert"
ALERT_EMAIL="security-alert@example.co.jp"

aws sns subscribe \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$ALERT_EMAIL" \
  --output json \
  --no-cli-pager
```

重要:

- Email Subscriptionは確認メールの承認が必要
- 承認されるまで通知は届かない
- メーリングリストを使う場合は解除操作の扱いを確認する
- 社内メールゲートウェイでSNSメールが弾かれないか確認する

Subscription確認:

```bash
aws sns list-subscriptions-by-topic \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --output json \
  --no-cli-pager
```

`SubscriptionArn` が `PendingConfirmation` の場合、まだメール承認が終わっていない。

### 5.5 SNSテスト通知

```bash
aws sns publish \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --subject "AWS alert notification test" \
  --message "This is a test notification from AWS SNS." \
  --output json \
  --no-cli-pager
```

確認ポイント:

- 通知メールが届くか
- 件名がわかりやすいか
- 迷惑メールや隔離に入っていないか
- 監視製品側で受信できるか

## 6. EventBridge Ruleの設定

### 6.1 既存Rule確認

```bash
aws events list-rules \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

特定Rule確認:

```bash
RULE_NAME="project-alert-s3-bucket-policy-change"

aws events describe-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$RULE_NAME" \
  --output json \
  --no-cli-pager
```

Target確認:

```bash
aws events list-targets-by-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --output json \
  --no-cli-pager
```

### 6.2 S3 Bucket Policy変更検知パターン

`event-pattern-s3-bucket-policy-change.json`

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

特定バケットに絞る場合は、CloudTrailイベントの形を確認してから条件を追加する。
環境によって `requestParameters.bucketName` や `resources` の見え方を確認する。

例:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutBucketPolicy", "DeleteBucketPolicy"],
    "requestParameters": {
      "bucketName": ["example-bucket"]
    }
  }
}
```

### 6.3 NACL変更検知パターン

`event-pattern-nacl-change.json`

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": [
      "CreateNetworkAcl",
      "DeleteNetworkAcl",
      "CreateNetworkAclEntry",
      "ReplaceNetworkAclEntry",
      "DeleteNetworkAclEntry",
      "ReplaceNetworkAclAssociation"
    ]
  }
}
```

### 6.4 Route Table変更検知パターン

`event-pattern-route-table-change.json`

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": [
      "CreateRouteTable",
      "DeleteRouteTable",
      "CreateRoute",
      "ReplaceRoute",
      "DeleteRoute",
      "AssociateRouteTable",
      "ReplaceRouteTableAssociation",
      "DisassociateRouteTable"
    ]
  }
}
```

### 6.5 VPC Flow Logs設定変更検知パターン

`event-pattern-vpc-flow-logs-change.json`

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": ["CreateFlowLogs", "DeleteFlowLogs"]
  }
}
```

### 6.6 GuardDuty Finding検知パターン

`event-pattern-guardduty-finding.json`

```json
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"]
}
```

High相当だけに絞る場合は、GuardDutyイベントのSeverity値を確認してから条件を設計する。
GuardDutyのSeverityは数値で扱われるため、現場の基準に合わせる。

## 7. Event Patternのテスト

EventBridgeでは、Event Patternがサンプルイベントに一致するか確認できる。

```bash
aws events test-event-pattern \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --event-pattern file://event-pattern-s3-bucket-policy-change.json \
  --event file://sample-put-bucket-policy-event.json \
  --output json \
  --no-cli-pager
```

結果の見方:

```json
{
  "Result": true
}
```

`true` なら一致する。
`false` ならイベントパターンが対象イベントを拾えていない。

## 8. EventBridge Rule作成

```bash
RULE_NAME="project-alert-s3-bucket-policy-change"

aws events put-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$RULE_NAME" \
  --description "Alert when S3 bucket policy is changed" \
  --event-pattern file://event-pattern-s3-bucket-policy-change.json \
  --state ENABLED \
  --output json \
  --no-cli-pager
```

確認:

```bash
aws events describe-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$RULE_NAME" \
  --output json \
  --no-cli-pager
```

## 9. EventBridgeからSNSへPublishする権限

EventBridge RuleのTargetをSNSにする場合、SNS Topic側のPolicyでEventBridgeからのPublishを許可する必要がある。
コンソール操作では自動で設定されることがあるが、CLIやIaCでは明示的に確認する。

Topic Policy確認:

```bash
aws sns get-topic-attributes \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --topic-arn "$TOPIC_ARN" \
  --output json \
  --no-cli-pager
```

Topic Policy例:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEventBridgePublish",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:ap-northeast-1:123456789012:project-security-change-alert",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:events:ap-northeast-1:123456789012:rule/project-alert-s3-bucket-policy-change"
        }
      }
    }
  ]
}
```

注意:

- 既存Topic Policyがある場合は上書きしない
- 既存Statementへ追加する
- 本番では必ず差分確認とレビューを行う

## 10. EventBridge Target設定

単純にSNSへ送る場合:

```bash
aws events put-targets \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --targets "Id"="sns-target","Arn"="$TOPIC_ARN" \
  --output json \
  --no-cli-pager
```

確認:

```bash
aws events list-targets-by-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --output json \
  --no-cli-pager
```

## 11. 通知本文を整える場合

EventBridgeからSNSへそのまま流すと、通知本文が長くなることがある。
運用で読みやすくする場合はInput Transformerを使う。

通知に入れたい項目:

- アラート名
- AWSアカウントID
- リージョン
- EventName
- 実行者ARN
- 実行時刻
- 送信元IP
- 対象リソース
- CloudTrail Event ID
- Request ID
- 対応手順書の場所

Input Transformerを使う場合は、GUIで設定する方が安全な場合がある。
CLIで設定する場合はJSONのクォートが崩れやすいため、事前に検証環境で確認する。

## 12. CloudWatch Logs Metric Filterで作る場合

### 12.1 前提

CloudTrailがCloudWatch Logsへ配送されている必要がある。

確認:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output json \
  --no-cli-pager
```

### 12.2 Metric Filter作成例

S3 Bucket Policy変更検知:

```bash
LOG_GROUP_NAME="/aws/cloudtrail/management-events"
FILTER_NAME="S3BucketPolicyChange"
METRIC_NAMESPACE="Security/ChangeDetection"
METRIC_NAME="S3BucketPolicyChangeCount"

aws logs put-metric-filter \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern '{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }' \
  --metric-transformations metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1 \
  --no-cli-pager
```

### 12.3 CloudWatch Alarm作成例

```bash
ALARM_NAME="Security-S3BucketPolicyChange"

aws cloudwatch put-metric-alarm \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "S3 bucket policy was changed" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --output json \
  --no-cli-pager
```

確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager
```

## 13. GUIで設定する場合

### 13.1 SNS

1. Amazon SNSコンソールを開く
2. Topicsを開く
3. 既存Topicを使うか、新規Topicを作成する
4. Subscriptionsを作成する
5. ProtocolにEmailなどを選ぶ
6. Endpointに通知先を入れる
7. 確認メールを承認する
8. テストPublishを行う

取得する証跡:

- Topic一覧
- Topic詳細
- Subscription一覧
- SubscriptionのStatus
- テスト通知結果

### 13.2 EventBridge

1. Amazon EventBridgeコンソールを開く
2. Rulesを開く
3. Default event busを選ぶ
4. Ruleを作成する
5. Event patternを設定する
6. TargetにSNS Topicを設定する
7. Ruleを有効化する
8. Target設定を確認する

取得する証跡:

- Rule一覧
- Rule詳細
- Event pattern
- Target
- StateがEnabledであること

### 13.3 CloudWatch Alarm

1. CloudWatchコンソールを開く
2. LogsでLog Groupを確認する
3. Metric Filterを確認または作成する
4. Metricsに出ていることを確認する
5. Alarmを作成する
6. Alarm actionにSNS Topicを設定する
7. 状態と通知先を確認する

取得する証跡:

- Log Group
- Metric Filter
- Metric
- Alarm詳細
- Alarm action

## 14. テスト方法

### 14.1 低リスクなテスト

- SNSへ直接テストPublishする
- EventBridgeの `test-event-pattern` でパターン一致を確認する
- 検証環境で実際の変更操作を行う
- GuardDutyはSample Findingを使う。ただし本番で作る場合は承認を取る

### 14.2 本番で注意するテスト

本番で以下を実施する場合は必ず承認を取る。

- S3 Bucket Policyを実際に変更する
- NACLを実際に変更する
- Route Tableを実際に変更する
- GuardDuty Sample Findingを作成する
- VPC Flow Logsを新規有効化する

### 14.3 テスト時に確認すること

- 通知が届くか
- 何分程度で届くか
- 件名・本文で何が起きたか分かるか
- 実行者、対象リソース、EventNameが分かるか
- 既存監視と重複しないか
- 通知が多すぎないか

## 15. 変更前後の証跡

推奨ディレクトリ構成:

```text
evidence/
  20260704_alert_notification_setting/
    00_metadata/
    before/
    change/
    after/
    test/
    screenshots/
    report/
```

変更前に取るもの:

- 対象Trail
- Event Selectors
- CloudWatch Logs連携
- 既存EventBridge Rule
- 既存SNS Topic
- 既存Subscription
- 対象サービスの現在設定

変更後に取るもの:

- 作成したRule
- Event Pattern
- Target
- SNS Topic Policy
- Subscription状態
- テスト通知結果
- CloudTrailに記録された変更イベント

## 16. 切り戻し

EventBridge Ruleの場合:

```bash
aws events disable-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$RULE_NAME" \
  --no-cli-pager
```

Target削除:

```bash
aws events remove-targets \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --ids "sns-target" \
  --no-cli-pager
```

Rule削除:

```bash
aws events delete-rule \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --name "$RULE_NAME" \
  --no-cli-pager
```

CloudWatch Alarm削除:

```bash
aws cloudwatch delete-alarms \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --no-cli-pager
```

Metric Filter削除:

```bash
aws logs delete-metric-filter \
  --profile "$PROFILE_NAME" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --no-cli-pager
```

注意:

- 既存Topicや既存Subscriptionは勝手に削除しない
- 新規作成したものだけ削除対象にする
- Topic Policyを変更した場合は、変更前Policyへ戻す
- 切り戻し後も証跡を残す

## 17. 必要になりやすいIAM権限

参照系:

- `cloudtrail:DescribeTrails`
- `cloudtrail:GetTrailStatus`
- `cloudtrail:GetEventSelectors`
- `cloudtrail:LookupEvents`
- `events:ListRules`
- `events:DescribeRule`
- `events:ListTargetsByRule`
- `sns:ListTopics`
- `sns:GetTopicAttributes`
- `sns:ListSubscriptionsByTopic`
- `logs:DescribeLogGroups`
- `logs:DescribeMetricFilters`
- `cloudwatch:DescribeAlarms`
- `ec2:DescribeFlowLogs`
- `ec2:DescribeNetworkAcls`
- `ec2:DescribeRouteTables`
- `guardduty:ListDetectors`
- `guardduty:GetDetector`
- `guardduty:ListFindings`
- `guardduty:GetFindings`

変更系:

- `events:PutRule`
- `events:PutTargets`
- `events:EnableRule`
- `events:DisableRule`
- `events:RemoveTargets`
- `events:DeleteRule`
- `sns:CreateTopic`
- `sns:Subscribe`
- `sns:Publish`
- `sns:SetTopicAttributes`
- `logs:PutMetricFilter`
- `logs:DeleteMetricFilter`
- `cloudwatch:PutMetricAlarm`
- `cloudwatch:DeleteAlarms`
- `ec2:CreateFlowLogs`
- `ec2:DeleteFlowLogs`

権限不足時の伝え方:

```text
events:PutRule が不足しているため、EventBridge Ruleを作成できません。
対象タスクはS3 Bucket Policy変更検知の通知設定です。
承認済みであれば、当該権限の付与または権限を持つ方による実施をお願いしたいです。
```

参照権限不足の場合:

```text
sns:GetTopicAttributes が不足しているため、
既存SNS TopicのPolicyと通知先を確認できません。
既存通知設定との重複確認に必要です。
```

## 18. 現場での説明例

### 18.1 初回相談

```text
今回のアラート設定は、まず既存のCloudTrail、EventBridge、SNS、CloudWatch Alarmを確認したうえで、
重複しない形で追加するのがよいと考えています。
通知先と対応フローが決まっていれば、EventBridgeで対象API操作を拾ってSNSへ通知する形がシンプルです。
```

### 18.2 GUI前提の現場でCLIを使いたい場合

```text
GUIで設定内容とスクリーンショットは確認します。
併せて、設定値の取得と変更前後の証跡保存はCLIでJSON出力を残したいです。
変更操作は承認された手順に従って実施します。
```

### 18.3 通知先が未定の場合

```text
AWS側の検知条件は作れますが、通知先と一次対応者が決まっていないと運用に乗らないため、
先に通知先、対応者、エスカレーション先を確認したいです。
```

### 18.4 テスト方法が未定の場合

```text
本番リソースを実際に変更してテストするか、検証環境またはEvent Patternのテストで確認するかを決めたいです。
本番で変更イベントを発生させる場合は、承認されたテスト手順で実施します。
```

## 19. よくある落とし穴

- SNS Email Subscriptionが未承認で通知が届かない
- EventBridge Ruleは有効だがTargetがない
- Topic Policy不足でEventBridgeからSNSへPublishできない
- CloudTrailが対象リージョンで有効になっていない
- Multi-Region Trailと思っていたが違う
- Organization Trailのため個別アカウントでは変更できない
- Event Patternの `eventSource` や `eventName` が誤っている
- 本文が長すぎて運用担当が読みにくい
- 既存監視と重複通知になる
- メンテナンス作業でもアラートが大量発報する
- 通知が来た後の対応手順がない
- 切り戻し手順がない
- 変更系権限がなく作業当日に詰まる

## 20. 判断の目安

EventBridge + SNSが向いている場合:

- 設定変更イベントを即時通知したい
- CloudTrail EventNameで条件を作れる
- 通知先がSNSや外部監視である
- しきい値よりも、発生したら通知が重要

CloudWatch Metric Filter + Alarmが向いている場合:

- CloudWatch Alarmで管理したい
- 件数やしきい値を使いたい
- 既存運用がCloudWatch Alarm中心である
- CloudTrail LogsがCloudWatch Logsへ配送済みである

GuardDuty + EventBridgeが向いている場合:

- GuardDuty Finding発生時に通知したい
- SeverityやFinding Typeで運用を分けたい
- インシデント対応手順書へつなげたい

VPC Flow Logsは別枠で考える:

- 有効化は通信調査・監査のため
- 通知設定とは別に、保存先、ログ量、保持期間、分析方法を決める
- Flow Logsの有効化・削除自体はCloudTrail/EventBridgeで変更検知できる

## 21. 公式ドキュメント

- EventBridgeでCloudTrailイベントを扱う: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-event-cloudtrail.html
- EventBridge Event Pattern: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html
- SNS Email Subscription: https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html
- GuardDuty FindingとEventBridge: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings_eventbridge.html

