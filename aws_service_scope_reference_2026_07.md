# AWS機能別 対象範囲確認リファレンス

作成日: 2026-07-11

この資料は、クラウドセキュリティ対応で確認する AWS 機能について、「どこまでが対象範囲か」「デフォルトで何を見ているか」「対象範囲をどこで確認するか」を整理したものである。

主な対象は、CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、EventBridge、GuardDuty、VPC Flow Logs、S3、KMS、SNS、AWS Config とする。

## 1. 対象範囲確認の基本

AWS の設定確認では、単に「有効か無効か」だけでは不十分である。

同じ機能でも、以下のどの範囲に対して有効なのかを確認する必要がある。

| 範囲 | 意味 | 例 |
|---|---|---|
| アカウント | どの AWS アカウントが対象か | 開発運用アカウント、本番アカウント、監査アカウント |
| Organizations | 組織配下の複数アカウントを対象にしているか | Organization Trail、GuardDuty 管理アカウント |
| リージョン | どのリージョンの設定か | ap-northeast-1、us-east-1 |
| リソース | 個別リソース単位の設定か | S3 バケット、VPC、KMS キー |
| ログ保存先 | どこへログを保存しているか | S3、CloudWatch Logs、Firehose |
| 通知先 | 誰に、どの経路で通知するか | SNS、メール、Teams、EventBridge、監視基盤 |

現場での確認では、次の順で整理するとよい。

1. 対象アカウント
2. 対象環境
3. 対象リージョン
4. 対象リソース
5. 既存ログ保存先
6. 既存通知先
7. 対象外条件
8. 本番と開発運用の差異

## 2. 機能別の対象範囲一覧

| 機能 | 主な対象範囲 | デフォルトで見ている範囲 | 確認で特に見るもの |
|---|---|---|---|
| CloudTrail | アカウント、リージョン、Trail、Organizations | 管理イベントは対象。データイベントは通常、明示設定が必要 | Multi-Region、Organization Trail、Event Selector、CloudWatch Logs 連携 |
| CloudTrail Event History | アカウント、リージョン | 管理イベントの履歴確認用途 | 対象リージョン、検索対象イベント、保持期間 |
| CloudWatch Logs | リージョン、Log Group | Log Group に送られたログのみ | Log Group、Retention、KMS、Log Stream |
| Metric Filter | リージョン、Log Group | 作成後に取り込まれたログのみ | Filter Pattern、Namespace、Metric Name、Default Value |
| CloudWatch Alarm | リージョン、Metric、Alarm | 指定したメトリクスのみ | Alarm 条件、Action、SNS、状態履歴 |
| EventBridge | リージョン、Event Bus、Rule | Event Bus に届くイベントのうち Rule に一致したもの | Event Bus、Rule、Event Pattern、Target、別アカウント送信 |
| GuardDuty | アカウント、リージョン、Detector、Organizations | 有効化リージョンの基本データソースを分析 | Detector、Feature、Protection Plan、Finding、通知連携 |
| VPC Flow Logs | VPC、Subnet、ENI、リージョン | 作成した Flow Log の対象リソースのみ | 対象リソース、Traffic Type、保存先、ログ形式 |
| S3 Server Access Logging | S3 バケット | 有効化したソースバケットのみ | Source Bucket、Target Bucket、Prefix、配信権限 |
| S3 Bucket Policy / Public Access | S3 バケット、アカウント | バケット単位。Account-level Block Public Access はアカウント全体 | Bucket Policy、Public Access Block、Ownership、ACL |
| KMS CMK | アカウント、リージョン、Key | キー単位 | KeyManager、Key Policy、Rotation、CloudTrail 利用有無 |
| SNS | リージョン、Topic、Subscription | Topic に publish された通知のみ | Topic、Subscription、Protocol、確認済み状態、配信先 |
| AWS Config | アカウント、リージョン、Recorder、Resource Type、Aggregator | 設定した Recorder の対象リソースのみ | Recorder、記録対象、Delivery Channel、Aggregator |

## 3. CloudTrail

### 3.1 対象範囲

CloudTrail は、AWS アカウント内の操作履歴を記録するサービスである。

ただし、CloudTrail が「どこまで見ているか」は Trail 設定によって変わる。

| 観点 | 確認内容 |
|---|---|
| アカウント | 単一アカウントの Trail か、Organizations 配下の Organization Trail か |
| リージョン | 単一リージョン Trail か、Multi-Region Trail か |
| イベント種別 | Management Event、Data Event、Insights Event のどれを記録するか |
| グローバルサービス | IAM、STS、CloudFront などのグローバルサービスイベントを含めるか |
| 保存先 | S3、CloudWatch Logs、CloudTrail Lake など |
| 暗号化 | KMS CMK を使用しているか |

### 3.2 デフォルトでどこまで見るか

CloudTrail の証跡は、基本的に Management Event を記録する。

Management Event は、AWS リソースの作成、変更、削除、設定変更、ログインなどのコントロールプレーン操作である。

一方、S3 オブジェクトの `GetObject`、`PutObject`、`DeleteObject` のような Data Event は、通常は明示的に有効化しないと記録対象にならない。

要点:

| イベント種別 | デフォルトの扱い | 例 |
|---|---|---|
| Management Event | 記録対象 | `PutBucketPolicy`, `StopLogging`, `CreateUser`, `ConsoleLogin` |
| Data Event | 明示設定が必要 | S3 `PutObject`, Lambda `Invoke` |
| Insights Event | 明示設定が必要 | API 呼び出し量の異常検知 |

今回の 4 番台監視は、主に Management Event を対象にする。

ただし、S3 オブジェクト操作やアプリケーションからのアップロード確認は Data Event 側になるため、別扱いにする。

### 3.3 CloudTrail の範囲確認ポイント

Web コンソールで確認する場合:

1. CloudTrail を開く
2. 「証跡」を開く
3. 対象 Trail を開く
4. 以下を確認する

| 画面項目 | 見る意味 |
|---|---|
| 証跡名 | どの Trail か |
| ホームリージョン | Trail の本体があるリージョン |
| マルチリージョン証跡 | 全リージョンの Management Event を集約しているか |
| 組織の証跡 | Organizations 配下のアカウントを対象にしているか |
| ログファイル検証 | ログ改ざん検知用の検証が有効か |
| S3 バケット | CloudTrail ログ保存先 |
| CloudWatch Logs | CloudWatch Logs へ連携しているか |
| イベントセレクター | Management Event / Data Event の記録範囲 |
| KMS キー | CloudTrail ログ暗号化に CMK を使っているか |

CLI で確認する場合:

```bash
# Trail 一覧と基本範囲を確認する
aws cloudtrail describe-trails \
  --region <region> \
  --include-shadow-trails \
  --query 'trailList[].{
    Name:Name,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    CloudWatchLogs:CloudWatchLogsLogGroupArn
  }' \
  --output json
```

```bash
# 特定 Trail の詳細を確認する
aws cloudtrail get-trail \
  --region <region> \
  --name <trail-name> \
  --query 'Trail.{
    Name:Name,
    TrailARN:TrailARN,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    GlobalServiceEvents:IncludeGlobalServiceEvents,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    S3Prefix:S3KeyPrefix,
    KmsKeyId:KmsKeyId,
    CloudWatchLogs:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRole:CloudWatchLogsRoleArn
  }' \
  --output json
```

```bash
# Management Event / Data Event の記録範囲を確認する
aws cloudtrail get-event-selectors \
  --region <region> \
  --trail-name <trail-name> \
  --output json
```

### 3.4 CloudTrail で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Multi-Region Trail でない場合、別リージョンのイベントを拾えない可能性がある | 東京リージョンだけ見ても、us-east-1 の ConsoleLogin やグローバル系イベントを見落とすことがある |
| Data Event は別途有効化が必要 | S3 オブジェクト操作は Management Event ではない |
| Organizations Trail かどうかを確認する | 複数アカウントを対象にしているかが変わる |
| CloudWatch Logs 連携の有無を確認する | Metric Filter / Alarm で検知するには CloudWatch Logs 側にイベントが届いている必要がある |
| Event History だけでは監視設定ではない | 履歴検索はできるが、通知やアラームにはならない |

参考:

- [CloudTrail のコンセプト](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-concepts.html)
- [CloudTrail 証跡の使用](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-trails.html)
- [管理イベントのログ記録](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-management-events-with-cloudtrail.html)
- [データイベントをログ記録する](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html)

## 4. CloudWatch Logs

### 4.1 対象範囲

CloudWatch Logs は、リージョン単位のサービスである。

対象範囲は Log Group 単位で確認する。

CloudTrail のイベントを Metric Filter で監視する場合、CloudTrail が CloudWatch Logs の特定 Log Group へイベントを配信している必要がある。

### 4.2 CloudWatch Logs の範囲確認ポイント

Web コンソールで確認する場合:

1. CloudWatch を開く
2. 「ロググループ」を開く
3. CloudTrail 連携先 Log Group を確認する
4. Retention、KMS、Log Stream、保存データ量を確認する

CLI で確認する場合:

```bash
# Log Group の一覧と保持期間を確認する
aws logs describe-log-groups \
  --region <region> \
  --log-group-name-prefix <prefix> \
  --query 'logGroups[].{
    LogGroup:logGroupName,
    RetentionDays:retentionInDays,
    KmsKeyId:kmsKeyId,
    Class:logGroupClass,
    StoredBytes:storedBytes
  }' \
  --output json
```

### 4.3 CloudWatch Logs で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Log Group はリージョン単位 | 他リージョンのログは別 Log Group になる |
| Retention が未設定だと無期限保持になる | コスト・保存方針に影響する |
| KMS 暗号化がある場合は権限確認が必要 | CloudTrail や Logs が書き込めないとログ欠落につながる |
| 中央集約している場合、元アカウント/元リージョンの識別が必要 | `@aws.account`、`@aws.region` などを確認する |

参考:

- [Amazon CloudWatch Logs とは](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html)

## 5. Metric Filter

### 5.1 対象範囲

Metric Filter は、CloudWatch Logs の Log Group 単位で作成する。

つまり、対象 Log Group に届いたログだけを検索対象にする。

CloudTrail の全イベントを自動的に検索するわけではない。

### 5.2 デフォルトでどこまで見るか

Metric Filter は、作成後に CloudWatch Logs へ取り込まれたログイベントを対象にメトリクスを生成する。

過去ログを遡ってメトリクス化するものではない。

### 5.3 Metric Filter の範囲確認ポイント

Web コンソールで確認する場合:

1. CloudWatch Logs の対象 Log Group を開く
2. 「メトリクスフィルター」を開く
3. Filter Pattern を確認する
4. Metric Namespace / Metric Name を確認する
5. Alarm が紐づいているか確認する

CLI で確認する場合:

```bash
# Log Group に設定されている Metric Filter を確認する
aws logs describe-metric-filters \
  --region <region> \
  --log-group-name <log-group-name> \
  --query 'metricFilters[].{
    FilterName:filterName,
    FilterPattern:filterPattern,
    MetricTransformations:metricTransformations
  }' \
  --output json
```

### 5.4 Metric Filter で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Log Group 単位 | CloudTrail が別 Log Group に配信されていると対象外 |
| 作成後のログのみ | 過去イベントのメトリクスは作られない |
| Standard Log Class が前提 | Metric Filter は Standard ログクラスでサポートされる |
| Filter Pattern の粒度が重要 | 条件が広すぎると誤通知、狭すぎると検知漏れ |

参考:

- [フィルターを使用したログイベントからのメトリクスの作成](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html)

## 6. CloudWatch Alarm

### 6.1 対象範囲

CloudWatch Alarm は、メトリクス単位で作成する。

対象範囲は、Alarm が見ている Metric Namespace、Metric Name、Dimension、Region によって決まる。

### 6.2 CloudWatch Alarm の範囲確認ポイント

Web コンソールで確認する場合:

1. CloudWatch を開く
2. 「アラーム」を開く
3. 対象 Alarm を開く
4. 以下を確認する

| 画面項目 | 見る意味 |
|---|---|
| メトリクス | 何を監視しているか |
| Namespace | 監視メトリクスの分類 |
| 条件 | 何回発生したら ALARM にするか |
| Missing data | データ欠落時の扱い |
| Action | 通知先や自動対応先 |
| Alarm history | 実際に状態変化した履歴 |

CLI で確認する場合:

```bash
# Alarm の設定を確認する
aws cloudwatch describe-alarms \
  --region <region> \
  --alarm-names <alarm-name> \
  --query 'MetricAlarms[].{
    AlarmName:AlarmName,
    Namespace:Namespace,
    MetricName:MetricName,
    State:StateValue,
    ActionsEnabled:ActionsEnabled,
    AlarmActions:AlarmActions,
    TreatMissingData:TreatMissingData
  }' \
  --output json
```

### 6.3 CloudWatch Alarm で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Alarm はリージョン単位 | 別リージョンのメトリクスは別 Alarm が必要になることがある |
| Action が無効だと通知されない | Alarm 状態になっても通知が飛ばない |
| SNS Topic が存在しても購読者確認が必要 | Topic だけでは受信できない |
| Alarm history は 30 日保存 | 過去の状態変化確認には期限がある |

参考:

- [Amazon CloudWatch でのアラームの使用](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)

## 7. EventBridge

### 7.1 対象範囲

EventBridge は、リージョン、Event Bus、Rule、Target 単位で確認する。

同じアカウントでも、リージョンが違えば Rule も別である。

### 7.2 EventBridge の範囲確認ポイント

Web コンソールで確認する場合:

1. EventBridge を開く
2. 対象リージョンを確認する
3. 「イベントバス」を確認する
4. 「ルール」を確認する
5. 各 Rule の Event Pattern と Target を確認する

見る項目:

| 画面項目 | 見る意味 |
|---|---|
| Event Bus | default か custom か |
| Rule Name | どの監視・連携か |
| Event Pattern | どのイベントに反応するか |
| Target | SNS、Lambda、別アカウント Event Bus などの送信先 |
| Role | Target 実行に使う IAM Role |
| Enabled / Disabled | Rule が有効か |

CLI で確認する場合:

```bash
# Event Bus を確認する
aws events list-event-buses \
  --region <region> \
  --output json
```

```bash
# Rule 一覧を確認する
aws events list-rules \
  --region <region> \
  --event-bus-name <event-bus-name> \
  --query 'Rules[].{
    Name:Name,
    State:State,
    EventBusName:EventBusName,
    Description:Description
  }' \
  --output json
```

```bash
# Rule の Target を確認する
aws events list-targets-by-rule \
  --region <region> \
  --event-bus-name <event-bus-name> \
  --rule <rule-name> \
  --output json
```

### 7.3 EventBridge で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Event Bus 単位 | Rule は紐づく Event Bus に届いたイベントだけを見る |
| リージョン単位 | 別リージョンの Rule は別確認 |
| 別アカウント Target | 送信先アカウント、運用主体、権限、通知経路の確認が必要 |
| Managed Rule | AWS サービスが作成した Rule は不用意に変更しない |
| Rule があっても通知とは限らない | Target が Lambda、別 Event Bus、監視基盤などの場合がある |

参考:

- [Amazon EventBridge のイベントバス](https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-bus.html)
- [Amazon EventBridge のルール](https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-rules.html)
- [Amazon EventBridge の AWS アカウント間でイベントを送受信する](https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-cross-account.html)

## 8. GuardDuty

### 8.1 対象範囲

GuardDuty はリージョン単位の脅威検知サービスである。

対象範囲は、アカウント、リージョン、Detector、Organizations 管理、Feature / Protection Plan によって変わる。

### 8.2 デフォルトでどこまで見るか

GuardDuty を有効化すると、基本データソースとして CloudTrail 管理イベント、VPC Flow Logs 相当の情報、DNS ログなどを分析する。

ただし、S3 Protection、RDS Protection、Lambda Protection、Runtime Monitoring などの保護プランは、Feature の状態を確認する必要がある。

### 8.3 GuardDuty の範囲確認ポイント

Web コンソールで確認する場合:

1. GuardDuty を開く
2. 対象リージョンを確認する
3. Detector が有効か確認する
4. 「使用状況」または「保護プラン」で Feature を確認する
5. 「検出結果」で Finding を確認する
6. Organizations 管理の場合は管理アカウント・メンバーアカウントを確認する

CLI で確認する場合:

```bash
# Detector を確認する
aws guardduty list-detectors \
  --region <region> \
  --output json
```

```bash
# Detector の状態と Feature を確認する
aws guardduty get-detector \
  --region <region> \
  --detector-id <detector-id> \
  --query '{
    Status:Status,
    FindingPublishingFrequency:FindingPublishingFrequency,
    ServiceRole:ServiceRole,
    Features:Features
  }' \
  --output json
```

### 8.4 GuardDuty で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| リージョン単位 | 東京で有効でも他リージョンで無効の可能性がある |
| Detector 単位 | Detector がないリージョンは GuardDuty が有効ではない |
| Organizations 管理 | 管理アカウント側でメンバー設定を見る必要がある |
| Feature / Protection Plan | S3、RDS、Lambda、Runtime などは有効状態を個別確認 |
| Finding は検知結果であり設定変更履歴ではない | CloudTrail / Config / CloudWatch Alarm と役割が違う |

参考:

- [Amazon GuardDuty とは](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/what-is-guardduty.html)
- [GuardDuty の開始方法](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_settingup.html)
- [AWS Organizations を使用した GuardDuty アカウントの管理](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_organizations.html)
- [Amazon GuardDuty の検出結果の理解と生成](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings.html)

## 9. VPC Flow Logs

### 9.1 対象範囲

VPC Flow Logs は、VPC、Subnet、ENI のいずれかを対象に作成する。

要件が「全 VPC の Flow Logs 有効化」であれば、まず対象アカウント・対象リージョン内の全 VPC を棚卸しする必要がある。

### 9.2 VPC Flow Logs の範囲確認ポイント

Web コンソールで確認する場合:

1. VPC コンソールを開く
2. 対象リージョンを確認する
3. 「お使いの VPC」を開く
4. 各 VPC の Flow Logs タブを確認する
5. 保存先、Traffic Type、ログ形式、IAM Role を確認する

CLI で確認する場合:

```bash
# VPC 一覧を確認する
aws ec2 describe-vpcs \
  --region <region> \
  --query 'Vpcs[].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output json
```

```bash
# Flow Logs を確認する
aws ec2 describe-flow-logs \
  --region <region> \
  --query 'FlowLogs[].{
    FlowLogId:FlowLogId,
    ResourceType:ResourceType,
    ResourceId:ResourceId,
    TrafficType:TrafficType,
    LogDestinationType:LogDestinationType,
    LogDestination:LogDestination,
    FlowLogStatus:FlowLogStatus
  }' \
  --output json
```

### 9.3 VPC Flow Logs で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| VPC / Subnet / ENI のどの単位か確認する | VPC 全体を見ているとは限らない |
| Traffic Type を確認する | ACCEPT / REJECT / ALL のどれかで記録範囲が変わる |
| 保存先を確認する | CloudWatch Logs、S3、Firehose で確認方法が変わる |
| TGW Flow Logs は別扱い | VPC Flow Logs とは別サービス領域として確認する |
| 通信内容そのものは見えない | IP、ポート、プロトコル、許可/拒否などの通信メタデータ |

参考:

- [VPC フローログを使用した IP トラフィックのログ記録](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html)
- [フローログの使用](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/working-with-flow-logs.html)
- [フローログレコードの例](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs-records-examples.html)

## 10. S3 Server Access Logging

### 10.1 対象範囲

S3 Server Access Logging は、S3 バケット単位で有効化する。

CloudTrail が API 操作履歴を見るのに対し、S3 Server Access Logging は S3 バケットへのリクエスト詳細をログとして保存する。

### 10.2 S3 Server Access Logging の範囲確認ポイント

Web コンソールで確認する場合:

1. S3 を開く
2. 対象バケットを開く
3. 「プロパティ」を開く
4. 「サーバーアクセスのログ記録」を確認する
5. 有効な場合、ターゲットバケットとプレフィックスを確認する

CLI で確認する場合:

```bash
# S3 Server Access Logging の設定を確認する
aws s3api get-bucket-logging \
  --bucket <bucket-name> \
  --expected-bucket-owner <account-id> \
  --output json
```

### 10.3 S3 Server Access Logging で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| ソースバケット単位 | 全 S3 バケットを自動で記録するものではない |
| ターゲットバケットが必要 | どこにログを保存するかを設計する必要がある |
| 同一バケット保存は非推奨 | ログがログを生み、見づらくなりコストも増える |
| 配信はベストエフォート | 完全性や即時性は保証されない |
| ターゲットバケットの権限が必要 | `logging.s3.amazonaws.com` の書き込み許可を確認する |

参考:

- [サーバーアクセスログによるリクエストのログ記録](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html)

## 11. S3 Bucket Policy / Public Access

### 11.1 対象範囲

S3 の公開設定やバケットポリシーは、主にバケット単位で確認する。

ただし、Account-level Public Access Block はアカウント単位で効く。

### 11.2 確認ポイント

Web コンソールで確認する場合:

1. S3 を開く
2. 対象バケットを開く
3. 「アクセス許可」を開く
4. Block Public Access、Bucket Policy、ACL、Object Ownership を確認する
5. アカウントレベルの Block Public Access も確認する

CLI で確認する場合:

```bash
# バケットポリシーが Public と判定されているか確認する
aws s3api get-bucket-policy-status \
  --bucket <bucket-name> \
  --expected-bucket-owner <account-id> \
  --query 'PolicyStatus.IsPublic' \
  --output json
```

```bash
# バケット単位の Public Access Block を確認する
aws s3api get-public-access-block \
  --bucket <bucket-name> \
  --expected-bucket-owner <account-id> \
  --output json
```

### 11.3 注意点

| 注意点 | 理由 |
|---|---|
| バケット単位とアカウント単位を分ける | Account-level と Bucket-level の両方がある |
| BucketOwnerEnforced なら ACL は無効 | ACL ではなく Policy 中心で確認する |
| EventBridge でバケットポリシー変更通知がある場合がある | 既存監視と重複しないよう確認する |
| CloudTrail では `PutBucketPolicy` / `DeleteBucketPolicy` を見る | S3 オブジェクト操作とは別 |

参考:

- [Amazon S3 汎用バケットへのアクセス](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/access-bucket-intro.html)

## 12. KMS CMK

### 12.1 対象範囲

KMS キーは、アカウント、リージョン、Key 単位で管理される。

カスタマー管理 KMS キーを使う場合は、キーそのものだけでなく、Key Policy、Rotation、CloudTrail や S3 からの利用権限も確認する。

### 12.2 KMS の範囲確認ポイント

Web コンソールで確認する場合:

1. KMS を開く
2. 対象リージョンを確認する
3. 「カスタマー管理型のキー」を開く
4. キー状態、キーローテーション、Key Policy、Alias、利用サービスを確認する

CLI で確認する場合:

```bash
# キー一覧を確認する
aws kms list-keys \
  --region <region> \
  --output json
```

```bash
# キー詳細を確認する
aws kms describe-key \
  --region <region> \
  --key-id <key-id-or-arn> \
  --query 'KeyMetadata.{
    KeyId:KeyId,
    Arn:Arn,
    Description:Description,
    KeyManager:KeyManager,
    KeyState:KeyState,
    KeyUsage:KeyUsage,
    Origin:Origin,
    MultiRegion:MultiRegion
  }' \
  --output json
```

```bash
# ローテーション状態を確認する
aws kms get-key-rotation-status \
  --region <region> \
  --key-id <key-id-or-arn> \
  --output json
```

### 12.3 KMS で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| KMS はリージョン単位 | 別リージョンには別 Key が必要になることがある |
| KeyManager を確認する | `CUSTOMER` がカスタマー管理キー、`AWS` が AWS 管理キー |
| CloudTrail 連携時は Key Policy が重要 | CloudTrail が暗号化に使えないとログ配信に影響する |
| ローテーションはキー種別で扱いが違う | Customer managed key は設定確認が必要 |
| キー無効化・削除スケジュールは高重要度 | 監視対象として扱う |

参考:

- [AWS KMS keys](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/concepts.html)
- [AWS KMS keys のローテーション](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/rotate-keys.html)
- [AWS KMS キーを使用した CloudTrail ログファイルの暗号化](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html)

## 13. SNS / 通知先

### 13.1 対象範囲

SNS は、リージョン、Topic、Subscription 単位で確認する。

CloudWatch Alarm や EventBridge の通知 Action として使われることが多い。

### 13.2 SNS の範囲確認ポイント

Web コンソールで確認する場合:

1. SNS を開く
2. 対象リージョンを確認する
3. Topic 一覧を確認する
4. Subscription を確認する
5. Protocol、Endpoint、確認済み状態を確認する

CLI で確認する場合:

```bash
# Topic 一覧を確認する
aws sns list-topics \
  --region <region> \
  --output json
```

```bash
# Subscription 一覧を確認する
aws sns list-subscriptions \
  --region <region> \
  --output json
```

### 13.3 SNS で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| Topic があっても受信できるとは限らない | Subscription の確認済み状態が必要 |
| メール、Teams、監視基盤のどこへ行くか確認する | 通知先の運用責任者が違う可能性がある |
| 既存 Topic の流用可否を確認する | 通知件数や用途が変わるため |
| 配信ステータスログの有無を確認する | 通知失敗時の調査に使える |

参考:

- [Amazon SNS トピックの作成とメッセージの発行](https://docs.aws.amazon.com/ja_jp/sns/latest/dg/sns-getting-started.html)
- [Amazon SNS トピックのサブスクリプションの作成](https://docs.aws.amazon.com/ja_jp/sns/latest/dg/sns-create-subscribe-endpoint-to-topic.html)
- [Amazon SNS メッセージ配信ステータス](https://docs.aws.amazon.com/ja_jp/sns/latest/dg/sns-topic-attributes.html)

## 14. AWS Config

### 14.1 対象範囲

AWS Config は、アカウント、リージョン、Recorder、記録対象リソースタイプ、Aggregator 単位で確認する。

CloudTrail が「誰が何をしたか」を見るのに対し、AWS Config は「リソース設定がどう変わったか」を見る。

### 14.2 AWS Config の範囲確認ポイント

Web コンソールで確認する場合:

1. AWS Config を開く
2. 対象リージョンを確認する
3. Recorder が有効か確認する
4. 記録対象リソースタイプを確認する
5. Delivery Channel、S3、SNS を確認する
6. Aggregator がある場合、対象アカウント・リージョンを確認する

CLI で確認する場合:

```bash
# Configuration Recorder を確認する
aws configservice describe-configuration-recorders \
  --region <region> \
  --output json
```

```bash
# Recorder の状態を確認する
aws configservice describe-configuration-recorder-status \
  --region <region> \
  --output json
```

```bash
# Delivery Channel を確認する
aws configservice describe-delivery-channels \
  --region <region> \
  --output json
```

### 14.3 AWS Config で注意する対象範囲

| 注意点 | 理由 |
|---|---|
| リージョン単位 | 別リージョンでは Recorder が無効の可能性 |
| 記録対象リソースタイプ | 全リソースを記録しているとは限らない |
| Aggregator の有無 | 複数アカウント・複数リージョン集約があるか |
| CloudTrail とは役割が違う | 設定履歴を見るサービスであり、即時通知は別途設計が必要 |

参考:

- [AWS Config とは?](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/WhatIsConfig.html)

## 15. 対象範囲一覧テンプレート

以下は Excel に貼り付けて使う想定の TSV である。

```tsv
機能	対象アカウント	対象環境	対象リージョン	対象リソース	対象外条件	既存設定	通知先	確認方法	確認結果	未決事項
CloudTrail	未確認	開発運用/本番	未確認	Trail	未確認	未確認	未確認	Trail詳細、Event Selector、CloudWatch Logs連携	未確認	未記入
CloudWatch Logs	未確認	開発運用/本番	未確認	Log Group	未確認	未確認	未確認	Log Group、Retention、KMS、Log Stream	未確認	未記入
Metric Filter	未確認	開発運用/本番	未確認	Log Group	未確認	未確認	未確認	Metric Filter一覧、Filter Pattern	未確認	未記入
CloudWatch Alarm	未確認	開発運用/本番	未確認	Alarm/Metric	未確認	未確認	未確認	Alarm条件、Action、History	未確認	未記入
EventBridge	未確認	開発運用/本番	未確認	Event Bus/Rule	未確認	未確認	未確認	Event Pattern、Target、別アカウント送信	未確認	未記入
GuardDuty	未確認	開発運用/本番	未確認	Detector/Feature	未確認	未確認	未確認	Detector、Feature、Finding、通知連携	未確認	未記入
VPC Flow Logs	未確認	開発運用/本番	未確認	VPC/Subnet/ENI	未確認	未確認	未確認	Flow Logs、保存先、Traffic Type	未確認	未記入
S3 Server Access Logging	未確認	開発運用/本番	未確認	S3 Bucket	未確認	未確認	未確認	Bucket Logging、Target Bucket、Prefix	未確認	未記入
S3 Public Access/Bucket Policy	未確認	開発運用/本番	未確認	S3 Bucket/Account	未確認	未確認	未確認	Public Access Block、Policy、ACL、Ownership	未確認	未記入
KMS CMK	未確認	開発運用/本番	未確認	KMS Key	未確認	未確認	未確認	KeyManager、Key Policy、Rotation、Key State	未確認	未記入
SNS	未確認	開発運用/本番	未確認	Topic/Subscription	未確認	未確認	未確認	Topic、Subscription、Endpoint、確認済み状態	未確認	未記入
AWS Config	未確認	開発運用/本番	未確認	Recorder/Resource Type/Aggregator	未確認	未確認	未確認	Recorder、Delivery Channel、Aggregator	未確認	未記入
```

## 16. リーダー・インフラチームへの確認文

```text
今回のクラウドセキュリティ対応について、各機能の対象範囲を確認させてください。

対象アカウント、対象環境、対象リージョン、対象リソースについて、
CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、EventBridge、GuardDuty、VPC Flow Logs、S3、KMS、SNS、AWS Config の範囲を整理したいです。

特に、以下を確認したいです。

・本番環境と開発運用環境は同一構成前提でよいか
・対象リージョンはどこまでか
・Organizations 管理や監査アカウント集約があるか
・CloudTrail は Organization Trail / Multi-Region Trail か
・CloudTrail の CloudWatch Logs 連携先はどの Log Group か
・既存 EventBridge Rule や別アカウント送信は正式な監視経路か
・既存 SNS / Teams / メール通知を流用してよいか
・GuardDuty はどのリージョン・どのアカウントで有効か
・VPC Flow Logs は全 VPC が対象か、一部 VPC のみか
・KMS CMK の対象キーと管理者はどこか
・対象外としてよいリソースやリージョンがあるか
```

## 17. 実務上の結論

今回のクラウドセキュリティ対応では、以下の考え方で進めると安全である。

1. CloudTrail は、まず Multi-Region / Organization / Event Selector / CloudWatch Logs 連携を確認する。
2. CloudWatch Logs、Metric Filter、Alarm は、対象 Log Group と対象リージョンをセットで確認する。
3. EventBridge は、Rule だけでなく Event Bus、Target、別アカウント送信を確認する。
4. GuardDuty は、Detector と Feature / Protection Plan をリージョンごとに確認する。
5. VPC Flow Logs は、全 VPC 対象なのか、Subnet / ENI 単位なのかを確認する。
6. S3 と KMS は、バケット単位・キー単位で対象を明確にする。
7. 通知は、既存通知の流用可否、通知先、運用責任者、通知テスト可否を確認する。
8. 本番作業前に、本番と開発運用の差異確認を必ず入れる。
