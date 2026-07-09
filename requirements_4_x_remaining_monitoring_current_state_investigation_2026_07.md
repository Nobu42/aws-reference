# 要件4番台 残り監視項目 一括現状調査手順書

作成日: 2026-07-10

この手順書は、要件4.8「S3バケットポリシー変更監視」の現状確認後に、要件4.1〜4.7、4.9〜4.15の監視設定をまとめて現状調査するための手順である。

最初に共有された評価シート由来のテキスト情報を正とし、元要件では「CloudTrailをCloudWatch Logsに連携し、Metric FilterおよびCloudWatch Alarmで発報する」方針として扱う。
EventBridgeは元要件の必須方式ではなく、既存監視、別アカウント連携、重複通知の確認観点として扱う。

## 1. 背景

要件4.8の現状確認では、おおよそ監査指摘どおりであることに加えて、以下の既存設定が確認された。

| 確認できたこと | 残り4番台調査への影響 |
|---|---|
| `PutBucketPolicy` をEventBridgeで別アカウントへ送信している設定がある | 残り4番台でも、同様のEventBridge連携が既に存在しないか確認する |
| 既存通知設定としてメール通知がある | 新規SNS TopicやAlarm Actionを作る前に既存通知先を確認する |
| 既存通知設定としてTeams通知がある | 通知経路、運用担当、重複通知、テスト可否を確認する |

このため、残り4番台は単純に「Metric Filterがないから作る」と判断せず、以下をまとめて確認する。

```text
CloudTrailで対象イベントを記録できるか
  ↓
CloudTrailがCloudWatch Logsへ連携されているか
  ↓
既存Metric Filterがあるか
  ↓
既存CloudWatch Alarmがあるか
  ↓
既存通知先があるか
  ↓
EventBridgeや別アカウント連携で同等監視がないか
  ↓
要件ごとに「対応済み / 不足 / 要確認 / 対象外」を整理する
```

## 2. 調査対象

4.8は現状確認済みのため、本手順では主に以下を対象とする。

| 要件番号 | 確認項目 | 主な確認観点 |
|---|---|---|
| 4.1 | 不正なAPI呼び出し監視 | `UnauthorizedOperation`、`AccessDenied` など |
| 4.2 | MFAなし管理コンソールサインイン監視 | `ConsoleLogin`、`MFAUsed = No` |
| 4.3 | rootアカウント使用監視 | `userIdentity.type = Root` |
| 4.4 | IAMポリシー変更監視 | IAM Policy作成、更新、削除、Attach、Detach |
| 4.5 | CloudTrail設定変更監視 | Trail作成、更新、停止、削除、Event Selector変更 |
| 4.6 | AWS Management Console認証失敗監視 | `ConsoleLogin = Failure` |
| 4.7 | カスタマー管理KMSキーの無効化・削除予約監視 | `DisableKey`、`ScheduleKeyDeletion` など |
| 4.9 | AWS Config設定変更監視 | Configuration Recorder、Delivery Channel、Config Rule変更 |
| 4.10 | Security Group変更監視 | Ingress/Egress許可、取消、Security Group作成・削除 |
| 4.11 | Network ACL変更監視 | NACL作成・削除、Entry変更、Association変更 |
| 4.12 | Network Gateway変更監視 | Internet Gateway、NAT Gateway、VPN Gateway、Customer Gateway、Transit Gateway等 |
| 4.13 | Route Table変更監視 | Route作成・削除・置換、Route Table関連付け変更 |
| 4.14 | VPC変更監視 | VPC作成・削除・属性変更、VPC Peering変更 |
| 4.15 | AWS Organizations変更監視 | Organization、OU、Account、Policy変更 |

注意:

- 4.15は管理アカウント側で確認が必要な場合がある。
- OrganizationsやIAM、ConsoleLoginなどはグローバルサービスのため、CloudTrailのMulti-Region設定やHome Regionを確認する。
- この手順は現状調査であり、設定変更は行わない。

## 3. 作業前提

### 3.1 作業端末

Windows端末のGit Bashで作業する想定。

PowerShellで実施する場合、`grep`、`sed`、`tr`、`while read` の扱いが異なるため、必要に応じてコマンドを置き換える。

### 3.2 必要な情報

作業前に以下を確認する。

| 項目 | 内容 |
|---|---|
| AWS CLI Profile | 現場指定のProfile名 |
| 対象AWSアカウントID | 誤操作防止のため確認 |
| 対象リージョン | 対象リージョン。Multi-Region Trailの場合もHome Regionを確認 |
| 対象CloudTrail | Organization Trail、Multi-Region Trail、個別Trailのどれか |
| CloudWatch Logs Log Group | CloudTrail連携先 |
| 既存通知先 | SNS、メール、Teams、監視基盤、別アカウント連携 |
| 証跡保存先 | 現場ルールに従う |

### 3.3 変数設定

```bash
PROFILE="<aws-cli-profile>"
REGION="<target-region>"
EXPECTED_ACCOUNT_ID="<target-account-id>"

EVIDENCE_DIR="./evidence_4x_remaining_monitoring_$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$EVIDENCE_DIR"/{00_account,01_cloudtrail,02_cloudwatch_logs,03_metric_filters,04_alarms,05_sns,06_eventbridge,07_event_history,08_summary}
```

作業例:

```bash
PROFILE="prod-profile"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="123456789012"
```

## 4. アカウントとリージョンを確認する

目的:
誤ったAWSアカウントやリージョンで調査しないようにする。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_account/01_caller_identity.json"
```

見やすい表示:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query '{Account:Account,Arn:Arn,UserId:UserId}' \
  --output table \
  --no-cli-pager
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `Account` | 想定AWSアカウントIDと一致すること |
| `Arn` | 作業用ユーザーまたはRoleが想定どおりであること |

## 5. CloudTrailの記録状態を確認する

目的:
4番台の監視対象イベントが、CloudTrailで記録される前提を満たしているか確認する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_cloudtrail/01_describe_trails.json"
```

見やすい表示:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{
    Name:Name,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    CloudWatchLogs:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRole:CloudWatchLogsRoleArn
  }' \
  --output table \
  --no-cli-pager
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `Name` | 対象Trailか |
| `HomeRegion` | 詳細確認すべきリージョン |
| `MultiRegion` | 全リージョンのManagement Eventを拾う設計か |
| `Organization` | Organizations管理の場合、管理アカウント側のTrailか |
| `CloudWatchLogs` | CloudWatch Logs連携先があるか |
| `CloudWatchLogsRole` | CloudTrailがCloudWatch Logsへ書き込むRoleがあるか |

Trail名を設定する。

```bash
TRAIL_NAME="<trail-name>"
```

Trail詳細:

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_cloudtrail/02_get_trail.json"
```

Event Selector:

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_cloudtrail/03_event_selectors.json"
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `IncludeManagementEvents` | `true` であること |
| `ReadWriteType` | `All` または監視対象を拾える設定であること |
| `AdvancedEventSelectors` | Advanced Selector使用時は対象イベントが除外されていないこと |

## 6. CloudWatch Logs連携先を確認する

目的:
Metric Filterを作成・確認する対象Log Groupを特定する。

`get-trail` の `CloudWatchLogsLogGroupArn` からLog Group名を確認する。

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{CloudWatchLogs:CloudWatchLogsLogGroupArn,CloudWatchLogsRole:CloudWatchLogsRoleArn}' \
  --output table \
  --no-cli-pager
```

CloudWatch Logs連携先Log Group名を設定する。

```bash
LOG_GROUP_NAME="<cloudtrail-log-group-name>"
```

Log Group詳細:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_cloudwatch_logs/01_log_group.json"
```

見やすい表示:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[].{
    LogGroup:logGroupName,
    RetentionDays:retentionInDays,
    KmsKeyId:kmsKeyId,
    Class:logGroupClass,
    StoredBytes:storedBytes
  }' \
  --output table \
  --no-cli-pager
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `LogGroup` | CloudTrail連携先であること |
| `RetentionDays` | 保持期間 |
| `KmsKeyId` | CloudWatch Logs側の暗号化キー |
| `Class` | Metric Filterを使う場合は通常 `STANDARD` |
| `StoredBytes` | ログが配送されている目安 |

## 7. 既存Metric Filterを一括取得する

目的:
4番台の監視条件がMetric Filterとして既に存在するか確認する。

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_metric_filters/01_metric_filters.json"
```

見やすい表示:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --query 'metricFilters[].{
    FilterName:filterName,
    Pattern:filterPattern,
    MetricName:metricTransformations[0].metricName,
    Namespace:metricTransformations[0].metricNamespace,
    MetricValue:metricTransformations[0].metricValue
  }' \
  --output table \
  --no-cli-pager
```

調査時に探すキーワード:

```bash
grep -Ei \
  'UnauthorizedOperation|AccessDenied|ConsoleLogin|MFAUsed|Root|PutUserPolicy|PutRolePolicy|PutGroupPolicy|AttachUserPolicy|AttachRolePolicy|AttachGroupPolicy|DetachUserPolicy|DetachRolePolicy|DetachGroupPolicy|CreatePolicy|DeletePolicy|CreatePolicyVersion|DeletePolicyVersion|CreateTrail|UpdateTrail|DeleteTrail|StartLogging|StopLogging|PutEventSelectors|DisableKey|ScheduleKeyDeletion|DisableKeyRotation|StopConfigurationRecorder|DeleteConfigurationRecorder|PutConfigurationRecorder|PutDeliveryChannel|DeleteDeliveryChannel|PutConfigRule|DeleteConfigRule|AuthorizeSecurityGroup|RevokeSecurityGroup|CreateSecurityGroup|DeleteSecurityGroup|ModifySecurityGroupRules|CreateNetworkAcl|CreateNetworkAclEntry|DeleteNetworkAcl|DeleteNetworkAclEntry|ReplaceNetworkAcl|CreateInternetGateway|DeleteInternetGateway|AttachInternetGateway|DetachInternetGateway|CreateNatGateway|DeleteNatGateway|CreateTransitGateway|DeleteTransitGateway|CreateRoute|DeleteRoute|ReplaceRoute|CreateRouteTable|DeleteRouteTable|AssociateRouteTable|DisassociateRouteTable|CreateVpc|DeleteVpc|ModifyVpcAttribute|CreateVpcPeeringConnection|AcceptVpcPeeringConnection|DeleteVpcPeeringConnection|Organizations|CreateOrganization|DeleteOrganization|CreateOrganizationalUnit|DeleteOrganizationalUnit|MoveAccount|AttachPolicy|DetachPolicy' \
  "$EVIDENCE_DIR/03_metric_filters/01_metric_filters.json" \
  > "$EVIDENCE_DIR/03_metric_filters/02_metric_filter_keyword_hits.txt" || true
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `filterName` | 要件番号または監視対象が分かる名前か |
| `filterPattern` | 対象イベントまたは条件を拾う内容か |
| `metricNamespace` | 既存運用ルールに沿っているか |
| `metricName` | Alarmから参照されているか |

## 8. 既存CloudWatch Alarmを一括取得する

目的:
Metric FilterのMetricに対してAlarmが設定されているか確認する。

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-types MetricAlarm \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_alarms/01_metric_alarms.json"
```

見やすい表示:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-types MetricAlarm \
  --query 'MetricAlarms[].{
    AlarmName:AlarmName,
    State:StateValue,
    ActionsEnabled:ActionsEnabled,
    Namespace:Namespace,
    MetricName:MetricName,
    Threshold:Threshold,
    ComparisonOperator:ComparisonOperator
  }' \
  --output table \
  --no-cli-pager
```

キーワード検索:

```bash
grep -Ei \
  'Unauthorized|AccessDenied|ConsoleLogin|MFA|Root|IAM|Policy|CloudTrail|KMS|Config|SecurityGroup|NetworkAcl|Gateway|Route|Vpc|Organizations|Organization' \
  "$EVIDENCE_DIR/04_alarms/01_metric_alarms.json" \
  > "$EVIDENCE_DIR/04_alarms/02_alarm_keyword_hits.txt" || true
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `AlarmName` | 監視対象が分かる名前か |
| `StateValue` | 現在の状態 |
| `ActionsEnabled` | 通知Actionが有効か |
| `AlarmActions` | SNS等の通知先が設定されているか |
| `MetricName` / `Namespace` | Metric FilterのMetricと一致するか |

## 9. SNS通知先とメール・Teams連携を確認する

目的:
既存のメール通知、Teams通知、監視基盤連携がどのTopicから行われているか確認する。

```bash
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/05_sns/01_topics.json"
```

Topic ARN一覧を保存する。

```bash
aws sns list-topics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Topics[].TopicArn' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | sed '/^$/d' \
  > "$EVIDENCE_DIR/05_sns/02_topic_arns.txt"
```

TopicごとのSubscriptionを取得する。

```bash
while read -r TOPIC_ARN
do
  SAFE_NAME=$(echo "$TOPIC_ARN" | sed 's#[/:]#_#g')

  aws sns list-subscriptions-by-topic \
    --profile "$PROFILE" \
    --region "$REGION" \
    --topic-arn "$TOPIC_ARN" \
    --output json \
    --no-cli-pager \
    > "$EVIDENCE_DIR/05_sns/subscriptions_${SAFE_NAME}.json"
done < "$EVIDENCE_DIR/05_sns/02_topic_arns.txt"
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `TopicArn` | Alarm Actionから参照されているTopicか |
| `Protocol` | `email`、`https`、`lambda`など |
| `Endpoint` | メール、Teams連携、外部監視基盤などの可能性 |
| `SubscriptionArn` | `PendingConfirmation` ではないか |

注意:

- メールアドレスやWebhook URLが含まれる場合、証跡の取り扱いに注意する。
- Teams通知はSNS直接ではなく、Lambda、Webhook、外部監視基盤、EventBridge経由の場合もある。
- 既存Topicを使うのか、新規Topicを作るのかは、運用担当に確認してから判断する。

## 10. EventBridgeの既存連携を一括確認する

目的:
4.8で見つかった別アカウント送信と同様に、残り4番台でも既存EventBridge Ruleがないか確認する。

Event Bus一覧:

```bash
aws events list-event-buses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/06_eventbridge/01_event_buses.json"
```

Event Bus名一覧:

```bash
aws events list-event-buses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'EventBuses[].Name' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | sed '/^$/d' \
  > "$EVIDENCE_DIR/06_eventbridge/02_event_bus_names.txt"
```

Event BusごとのRule一覧とTargetを取得する。

```bash
while read -r EVENT_BUS_NAME
do
  SAFE_BUS=$(echo "$EVENT_BUS_NAME" | sed 's#[/:]#_#g')

  aws events list-rules \
    --profile "$PROFILE" \
    --region "$REGION" \
    --event-bus-name "$EVENT_BUS_NAME" \
    --output json \
    --no-cli-pager \
    > "$EVIDENCE_DIR/06_eventbridge/rules_${SAFE_BUS}.json"

  aws events list-rules \
    --profile "$PROFILE" \
    --region "$REGION" \
    --event-bus-name "$EVENT_BUS_NAME" \
    --query 'Rules[].Name' \
    --output text \
    --no-cli-pager \
    | tr '\t' '\n' \
    | sed '/^$/d' \
    > "$EVIDENCE_DIR/06_eventbridge/rule_names_${SAFE_BUS}.txt"

  while read -r RULE_NAME
  do
    SAFE_RULE=$(echo "$RULE_NAME" | sed 's#[/:]#_#g')

    aws events describe-rule \
      --profile "$PROFILE" \
      --region "$REGION" \
      --event-bus-name "$EVENT_BUS_NAME" \
      --name "$RULE_NAME" \
      --output json \
      --no-cli-pager \
      > "$EVIDENCE_DIR/06_eventbridge/rule_${SAFE_BUS}_${SAFE_RULE}.json"

    aws events list-targets-by-rule \
      --profile "$PROFILE" \
      --region "$REGION" \
      --event-bus-name "$EVENT_BUS_NAME" \
      --rule "$RULE_NAME" \
      --output json \
      --no-cli-pager \
      > "$EVIDENCE_DIR/06_eventbridge/targets_${SAFE_BUS}_${SAFE_RULE}.json"
  done < "$EVIDENCE_DIR/06_eventbridge/rule_names_${SAFE_BUS}.txt"
done < "$EVIDENCE_DIR/06_eventbridge/02_event_bus_names.txt"
```

キーワード検索:

```bash
grep -REi \
  'PutBucketPolicy|DeleteBucketPolicy|UnauthorizedOperation|AccessDenied|ConsoleLogin|MFAUsed|Root|PutUserPolicy|PutRolePolicy|AttachRolePolicy|CreateTrail|UpdateTrail|DeleteTrail|StopLogging|DisableKey|ScheduleKeyDeletion|StopConfigurationRecorder|SecurityGroup|NetworkAcl|InternetGateway|NatGateway|TransitGateway|RouteTable|CreateRoute|DeleteRoute|CreateVpc|DeleteVpc|VpcPeering|Organizations|CreateOrganization|MoveAccount|AttachPolicy|DetachPolicy' \
  "$EVIDENCE_DIR/06_eventbridge" \
  > "$EVIDENCE_DIR/06_eventbridge/99_eventbridge_keyword_hits.txt" || true
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| `EventPattern` | 4番台の対象イベントを拾っているか |
| `State` | Ruleが有効か |
| `Targets` | SNS、Lambda、別アカウントEvent Bus、監視基盤等 |
| Target ARNのAccount ID | 別アカウント送信か |
| Input Transformer | 通知内容を加工しているか |

判断:

| 状態 | 判断 |
|---|---|
| EventBridgeで同等監視あり | 元要件の方式と同等として認めるか確認する |
| EventBridgeで別アカウント送信あり | 送信先、運用主体、通知経路、証跡保存先を確認する |
| CloudWatch AlarmもEventBridgeもあり | 重複通知の可能性を確認する |
| どちらもなし | 監視不足の可能性が高い |

## 11. CloudTrail Event Historyで過去イベントを確認する

目的:
対象イベントが実際に過去に発生しているか、CloudTrailで検索できるか確認する。

注意:

- `lookup-events` はスロットリングされやすいため、連続実行しすぎない。
- 1回の検索属性は原則1種類。
- 大量に実行する場合は、数秒待ちながら実行する。

代表イベントだけを軽く確認する場合:

```bash
for EVENT_NAME in \
  ConsoleLogin \
  CreateTrail UpdateTrail DeleteTrail StopLogging PutEventSelectors \
  DisableKey ScheduleKeyDeletion \
  StopConfigurationRecorder PutConfigurationRecorder DeleteConfigurationRecorder \
  AuthorizeSecurityGroupIngress RevokeSecurityGroupIngress CreateSecurityGroup DeleteSecurityGroup \
  CreateNetworkAcl CreateNetworkAclEntry DeleteNetworkAcl DeleteNetworkAclEntry ReplaceNetworkAclEntry \
  AttachInternetGateway DetachInternetGateway CreateNatGateway DeleteNatGateway CreateTransitGateway DeleteTransitGateway \
  CreateRoute DeleteRoute ReplaceRoute CreateRouteTable DeleteRouteTable AssociateRouteTable DisassociateRouteTable \
  CreateVpc DeleteVpc ModifyVpcAttribute CreateVpcPeeringConnection AcceptVpcPeeringConnection DeleteVpcPeeringConnection \
  CreateOrganization DeleteOrganization CreateOrganizationalUnit DeleteOrganizationalUnit MoveAccount AttachPolicy DetachPolicy
do
  echo "=== ${EVENT_NAME} ==="

  aws cloudtrail lookup-events \
    --profile "$PROFILE" \
    --region "$REGION" \
    --lookup-attributes AttributeKey=EventName,AttributeValue="$EVENT_NAME" \
    --max-results 10 \
    --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,ResourceName:Resources[0].ResourceName,EventId:EventId}' \
    --output json \
    --no-cli-pager \
    > "$EVIDENCE_DIR/07_event_history/event_${EVENT_NAME}.json" || true

  sleep 2
done
```

確認:

| 見る項目 | 確認内容 |
|---|---|
| 過去イベントあり | 実際に変更が発生している |
| 過去イベントなし | 変更がないだけか、検索リージョン/Trail/期間が違う可能性 |
| Event ID | 詳細追跡に使う |

## 12. 要件別の確認観点

調査結果は、以下の観点で要件別に整理する。

| 要件 | Metric Filterで探す条件 | EventBridgeで探す条件 | 注意点 |
|---|---|---|---|
| 4.1 | `UnauthorizedOperation`、`AccessDenied` | `errorCode` 条件 | 誤検知が多い可能性があるため通知頻度確認 |
| 4.2 | `ConsoleLogin` かつ `MFAUsed = No` | `ConsoleLogin`、`MFAUsed` | 成功ログインだけ対象か、失敗も含むか確認 |
| 4.3 | `userIdentity.type = Root` | `Root` | AWSサービス起因イベントを除外するか確認 |
| 4.4 | IAM Policy変更イベント | IAM系 `eventName` | 対象イベントが多いため範囲確認 |
| 4.5 | CloudTrail変更イベント | CloudTrail系 `eventName` | `StopLogging`、`DeleteTrail`、`PutEventSelectors` は特に重要 |
| 4.6 | `ConsoleLogin = Failure` | `ConsoleLogin`、`Failure` | しきい値、連続失敗、通知頻度確認 |
| 4.7 | `DisableKey`、`ScheduleKeyDeletion` | KMS系 `eventName` | CMKが存在しない場合は3.5/3.6と合わせて判断 |
| 4.9 | Config設定変更イベント | Config系 `eventName` | Config未利用環境かどうか確認 |
| 4.10 | Security Group変更イベント | Security Group系 `eventName` | 変更頻度が高い場合は通知運用確認 |
| 4.11 | NACL変更イベント | Network ACL系 `eventName` | 対象VPC範囲確認 |
| 4.12 | Gateway変更イベント | Gateway系 `eventName` | IGW/NAT/VPN/TGWの対象範囲確認 |
| 4.13 | Route Table変更イベント | Route系 `eventName` | `0.0.0.0/0` やTGW/NAT/VPC Endpoint経路変更の扱い確認 |
| 4.14 | VPC変更イベント | VPC/Peering系 `eventName` | VPC Peeringを含めるか確認 |
| 4.15 | Organizations変更イベント | Organizations系 `eventName` | 管理アカウントでの確認が必要な場合あり |

## 13. 調査結果のまとめ表

以下の形式で整理する。

```tsv
要件番号	監視対象	CloudTrail記録前提	CloudWatch Logs連携	Metric Filter	CloudWatch Alarm	通知Action	EventBridge/別アカウント連携	既存通知先	判定	不足/確認事項
4.1	不正API呼び出し	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.2	MFAなしConsoleLogin	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.3	root使用	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.4	IAMポリシー変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.5	CloudTrail設定変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.6	Console認証失敗	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.7	CMK無効化/削除予約	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.9	AWS Config設定変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.10	Security Group変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.11	Network ACL変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.12	Network Gateway変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.13	Route Table変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.14	VPC変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
4.15	AWS Organizations変更	未確認	未確認	未確認	未確認	未確認	未確認	未確認	未確認	
```

判定の目安:

| 判定 | 意味 |
|---|---|
| 対応済み | Metric Filter/Alarm/通知、または承認済み同等監視が確認できた |
| 一部対応 | 記録やFilterはあるが、Alarmや通知など一部不足 |
| 不足 | 監視設定が確認できない |
| 要確認 | EventBridge等の代替監視があるが、要件充足として認めるか未確認 |
| 対象外 | サービス未利用など、関係者確認のうえ対象外と判断 |

## 14. 関係者へ確認すること

4番台残りを一括で進める前に、以下を確認する。

| 確認事項 | 理由 |
|---|---|
| 4.8で見つかったEventBridge別アカウント送信は、正式な監視経路か | 同等監視として扱えるか判断するため |
| 別アカウント送信先の運用主体はどこか | 通知確認、証跡確認、障害時問い合わせ先に必要 |
| 既存メール通知とTeams通知はどの要件で使うか | 新規通知先作成や重複通知を避けるため |
| 4.1〜4.15はCloudWatch Alarm方式で統一するのか | 元要件の方式と既存EventBridge方式の整合を取るため |
| EventBridgeで同等監視済みの場合、是正済みとして扱えるか | 対応方針の認識合わせ |
| 通知テストを実施してよいか | メール/Teamsへ実通知が飛ぶ可能性があるため |
| 4.15のOrganizationsは管理アカウントで確認する必要があるか | 作業アカウント権限に影響するため |
| 監視対象イベントの範囲をどこまで含めるか | IAM、Gateway、VPC系はイベント種類が多いため |

## 15. 最低限必要な参照権限

現状調査だけなら、まずは参照系権限が必要。

| サービス | 主な参照権限 |
|---|---|
| STS | `sts:GetCallerIdentity` |
| CloudTrail | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrail`, `cloudtrail:GetEventSelectors`, `cloudtrail:LookupEvents` |
| CloudWatch Logs | `logs:DescribeLogGroups`, `logs:DescribeLogStreams`, `logs:DescribeMetricFilters`, `logs:StartQuery`, `logs:GetQueryResults`, `logs:FilterLogEvents` |
| CloudWatch | `cloudwatch:DescribeAlarms`, `cloudwatch:ListMetrics`, `cloudwatch:GetMetricData`, `cloudwatch:DescribeAlarmHistory` |
| SNS | `sns:ListTopics`, `sns:ListSubscriptionsByTopic`, `sns:GetTopicAttributes` |
| EventBridge | `events:ListEventBuses`, `events:ListRules`, `events:DescribeRule`, `events:ListTargetsByRule` |
| IAM | `iam:ListPolicies`, `iam:GetPolicy`, `iam:GetPolicyVersion` など、必要に応じて |
| KMS | `kms:ListKeys`, `kms:DescribeKey`, `kms:GetKeyRotationStatus` |
| Config | `config:DescribeConfigurationRecorders`, `config:DescribeDeliveryChannels`, `config:DescribeConfigRules` |
| EC2/VPC | `ec2:DescribeVpcs`, `ec2:DescribeSecurityGroups`, `ec2:DescribeNetworkAcls`, `ec2:DescribeRouteTables`, `ec2:DescribeInternetGateways`, `ec2:DescribeNatGateways`, `ec2:DescribeTransitGateways` |
| Organizations | `organizations:DescribeOrganization`, `organizations:ListRoots`, `organizations:ListAccounts`, `organizations:ListPolicies` など |

設定変更は別権限であり、この調査手順では使用しない。

## 16. 完了条件

以下を満たしたら、4.8以外の4番台現状調査は完了とする。

- CloudTrailがManagement Eventを記録できる状態か確認済み
- CloudWatch Logs連携先Log Groupを確認済み
- 既存Metric Filterを取得済み
- 既存CloudWatch Alarmを取得済み
- Alarm ActionとSNS通知先を確認済み
- メール/Teamsなど既存通知経路を確認済み
- EventBridge RuleとTargetを確認済み
- 別アカウント送信がある場合、送信先と運用主体の確認事項を整理済み
- 要件4.1〜4.7、4.9〜4.15ごとに、対応済み/不足/要確認/対象外を整理済み

## 17. 参考

- AWS CloudTrail: Sending events to CloudWatch Logs
  - English: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
- Amazon CloudWatch Logs: Creating metrics from log events using filters
  - English: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html
- Amazon EventBridge: Event patterns
  - English: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-patterns.html
- Amazon SNS: What is Amazon SNS?
  - English: https://docs.aws.amazon.com/sns/latest/dg/welcome.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/sns/latest/dg/welcome.html

