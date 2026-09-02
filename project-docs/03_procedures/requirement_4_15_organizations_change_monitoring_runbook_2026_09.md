# 要件4.15 AWS Organizations変更監視 設定・テスト手順書

作成日: 2026-09-02  
対象要件: 4.15「AWS Organizationsの変更が監視されていること」  
追補要件: 4.9「AWS Configの設定変更が監視されていること」  
作業方式: AWS Management Console

## 1. 目的

AWS Organizationsの操作をCloudTrailからCloudWatch Logsへ取り込み、Metric Filter、CloudWatch Alarm、既存SNS Topicを使用して通知する。

本書には次の2案を記載する。作業時は承認済みのどちらか一方だけを採用し、両方を作成しない。

| 案 | 検知対象 | 特徴 |
| :--- | :--- | :--- |
| A: 参照系の除外なし | Organizationsの全イベント | 参照操作でもテストできるが、List、Describe、Get系で通知が増える |
| B: 参照系を除外 | `readOnly`が`false`のOrganizationsイベント | 変更監視の要件に合いやすいが、End-to-End試験にはOrganizationsの変更権限が必要 |

## 2. 作業前確認

1. 作業対象のAWSアカウント、環境、リージョンを確認する。
2. AWS Organizationsの管理アカウントまたは委任管理者アカウントを確認する。
3. OrganizationsのCloudTrailイベントが記録されるTrailを確認する。
4. 対象TrailからCloudWatch Logsへ配信されるLog Groupを確認する。
5. Organizationsのイベントが対象Log Groupに存在するか確認する。
6. 既存のMetric Filter、Alarm、EventBridge Rule、A-gate側監視との重複を確認する。
7. 通知先の既存SNS TopicとSubscriptionの状態を確認する。
8. 採用するFilter Pattern、名称、Alarm設定値、通知先について承認を得る。

重要:

- OU、SCP、アカウント移動などのOrganizations管理操作は、原則としてOrganizations管理アカウントで実行される。委任管理者が操作できる範囲は、委任されたAWSサービスごとに異なる。
- Prod/OPERがメンバーアカウントの場合、そのLog GroupにOrganizations変更イベントが届かない可能性がある。
- Organizationsはグローバルサービスであり、CloudTrailイベント履歴では`us-east-1`側も確認する。
- Metric Filter作成前のログイベントはメトリクスへ遡及反映されない。実イベント試験はFilter作成後に実施する。

## 3. 設定値

現場の変更パラメータ一覧、命名規則、承認値を優先する。

| 項目 | 設定値 |
| :--- | :--- |
| Filter名 | `<現場命名規則>-security-4-15-organizations-change` |
| Metric Namespace | `Custom` |
| Metric Name | `Req415OrganizationsChangeCount` |
| Metric Value | `1` |
| Default Value | `0` |
| Unit | `Count` |
| Alarm名 | `<現場命名規則>-security-4-15-organizations-change-alarm` |
| Statistic | `Sum` |
| Period | `5 minutes` |
| Evaluation Periods | `1` |
| Datapoints to Alarm | `1 out of 1` |
| Threshold | `1以上` |
| Missing data | `Treat missing data as good (not breaching threshold)` |
| Alarm action | 有効 |
| 通知先 | 承認済みの既存SNS Topic |

### 3.1 案A: 参照系の除外なし

```text
{ ($.eventSource = "organizations.amazonaws.com") }
```

Organizationsの変更系と参照系をすべて検知する。

### 3.2 案B: 参照系を除外

```text
{ ($.eventSource = "organizations.amazonaws.com") && ($.readOnly IS FALSE) }
```

CloudTrailレコードの`readOnly`が`false`のイベントだけを検知する。変更監視を目的とする最終設定では、原則として案Bを第一候補とする。ただし、対象イベントで`readOnly`が記録されることを実ログまたはPattern Testで確認する。

## 4. Metric Filter作成

1. AWS Management Consoleで作業対象アカウントへログインする。
2. 画面右上でCloudTrailのCloudWatch Logs連携先Log Groupが存在するリージョンを選択する。
3. CloudWatchコンソールを開く。
4. 左ペインの「ログ」から「ロググループ」を選択する。
5. CloudTrail連携先のLog Groupを選択する。
6. 「メトリクスフィルター」タブを選択する。
7. 「メトリクスフィルターを作成」を選択する。
8. 承認済みの案Aまたは案BのFilter Patternを入力する。
9. 「パターンをテスト」で第5章のサンプルログを貼り付け、一致結果を確認する。
10. 「次へ」を選択する。
11. Filter名、Metric Namespace、Metric Name、Metric Value、Default Value、Unitを第3章どおり入力する。
12. 入力値を再確認し、「メトリクスフィルターを作成」を選択する。
13. 作成したMetric Filterの詳細を開き、Filter PatternとMetric設定を確認する。

## 5. Pattern Test用サンプルログ

「パターンをテスト」のサンプルログ欄へ、次のJSONを1行に1イベントの形式でまとめて貼り付ける。

### 5.1 変更系サンプル

```text
{"eventSource":"organizations.amazonaws.com","eventName":"CreateOrganization","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DeleteOrganization","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"CreateAccount","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"CloseAccount","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"InviteAccountToOrganization","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"RemoveAccountFromOrganization","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"LeaveOrganization","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"CreateOrganizationalUnit","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"UpdateOrganizationalUnit","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DeleteOrganizationalUnit","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"MoveAccount","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"CreatePolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"UpdatePolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DeletePolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"AttachPolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DetachPolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"EnablePolicyType","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DisablePolicyType","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"EnableAWSServiceAccess","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DisableAWSServiceAccess","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"RegisterDelegatedAdministrator","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DeregisterDelegatedAdministrator","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"TagResource","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"UntagResource","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
```

期待結果:

- 案Aはすべて一致する。
- 案Bもすべて一致する。
- このサンプルはPattern Test専用であり、危険なOrganizations操作の実行を指示するものではない。

### 5.2 参照系サンプル

```text
{"eventSource":"organizations.amazonaws.com","eventName":"DescribeOrganization","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DescribeAccount","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DescribeOrganizationalUnit","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"DescribePolicy","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListAccounts","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListRoots","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListPolicies","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListChildren","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListParents","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListOrganizationalUnitsForParent","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListAWSServiceAccessForOrganization","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"organizations.amazonaws.com","eventName":"ListDelegatedAdministrators","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
```

期待結果:

- 案Aはすべて一致する。
- 案Bはすべて不一致となる。

### 5.3 対象外サンプル

```text
{"eventSource":"iam.amazonaws.com","eventName":"CreatePolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"ec2.amazonaws.com","eventName":"DescribeInstances","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
```

期待結果:

- 案A、案Bともに不一致となる。

## 6. CloudWatch Alarm作成

1. CloudWatchコンソールで「アラーム」から「すべてのアラーム」を選択する。
2. 「アラームの作成」を選択する。
3. 「メトリクスの選択」を選択する。
4. カスタム名前空間の`Custom`を開く。
5. `Req415OrganizationsChangeCount`を選択する。
6. Statisticを`Sum`、Periodを`5 minutes`に設定する。
7. Threshold typeを`Static`、条件を`Greater/Equal`、値を`1`に設定する。
8. Additional configurationでDatapoints to alarmを`1 out of 1`に設定する。
9. Missing data treatmentを`Treat missing data as good (not breaching threshold)`に設定する。
10. Alarm state triggerを`In alarm`に設定する。
11. 通知先に承認済みの既存SNS Topicを指定する。
12. Alarm actionsが有効であることを確認する。
13. Alarm名と説明を入力する。
14. 設定内容を確認し、「アラームの作成」を選択する。
15. Alarmが`OK`または`データ不足`から評価されるまで待機し、Metric、条件、SNS Topicを再確認する。

## 7. 実イベント試験

### 7.1 案Aを採用した場合

1. Metric FilterとAlarmが作成済みであることを確認する。
2. Organizationsコンソールを開き、アカウント、組織単位、ポリシーのいずれかの一覧を表示する。
3. CloudTrailイベント履歴で`organizations.amazonaws.com`の参照イベントを確認する。見つからない場合は`us-east-1`も確認する。
4. CloudWatch Logsの対象Log Groupで同じイベントを確認する。
5. Metricのデータポイントが`1`以上になったことを確認する。
6. Alarmが`ALARM`へ遷移したことを確認する。
7. 既存SNS Topic経由のメール、Teamsまたは監視基盤で通知を確認する。
8. Alarmが次の評価後に`OK`へ戻ることを確認する。

注意:

- 単に画面を開くだけでは対象APIが必ず実行されるとは限らない。CloudTrailで実イベントを確認する。
- 案Aの参照操作試験は最終Filter PatternのEnd-to-End試験となるが、変更イベント固有の試験ではない。

### 7.2 案Bを採用した場合

実変更試験はPM、Organizations管理者、A-gate担当の承認を得てから実施する。

推奨する低影響候補は、承認済みのテスト用または空のOUの一時的な名称変更である。

1. 対象OUがテスト用または空であることを確認する。
2. OU ID、元のOU名、配下アカウント、付与ポリシー、タグを記録する。
3. OU名を一時名へ変更する。例: `test-ou`から`test-ou-req415-test`。
4. CloudTrailで`UpdateOrganizationalUnit`、`eventSource=organizations.amazonaws.com`、`readOnly=false`を確認する。
5. CloudWatch Logs、Metric、Alarm履歴、通知受信を確認する。
6. OU名を元の名称へ戻す。
7. CloudTrailで切り戻しの`UpdateOrganizationalUnit`を確認する。
8. OU名、配下アカウント、付与ポリシー、タグが作業前と同じであることを確認する。

OU名を参照する自動化、台帳、監視、手順書がある場合は、この方法を使用しない。代替として承認済みテストOUへの一時タグ付与と削除を検討するが、タグポリシーや自動処理への影響を事前確認する。

次の操作は試験目的で実行しない。

- Organizationの作成または削除
- アカウントの作成、閉鎖、招待、離脱、移動
- SCPなどのポリシー作成、変更、削除、Attach、Detach
- AWSサービスアクセスの有効化または無効化
- 委任管理者の登録または解除

### 7.3 実変更権限がない場合

1. 第5章のPattern Testで変更系サンプルが一致することを確認する。
2. CloudWatch Alarmの「アクション」から、承認済みの場合のみAlarm状態を一時的に`ALARM`へ変更する。
3. SNS Topic経由の通知受信を確認する。
4. Alarm状態を`OK`へ戻すか、通常のメトリクス評価へ戻ることを確認する。
5. 実イベントによるEnd-to-End試験ではないこと、未確認区間、代替試験の承認者を記録する。

Pattern Testと手動Alarm状態変更は、Filter Patternと通知経路を分けて確認する試験であり、CloudTrail実イベントから通知までのEnd-to-End証跡にはならない。

## 8. 作業後確認

1. 採用したFilter Patternだけが設定されていることを確認する。
2. Metric Namespace、Metric Name、Metric Value、Default Valueを確認する。
3. AlarmのStatistic、Period、Threshold、Datapoints、Missing dataを確認する。
4. Alarm actionsが有効で、通知先SNS Topicが正しいことを確認する。
5. SNS Subscriptionが`Confirmed`であることを確認する。
6. 実イベントまたは承認済み代替試験の結果を記録する。
7. 既存設定に想定外の変更がないことを確認する。

## 9. 切り戻し

### 9.1 テスト操作の切り戻し

- 一時変更したOU名またはタグを直ちに元へ戻す。
- OU配下アカウント、付与ポリシー、タグが作業前と一致することを確認する。

### 9.2 監視設定の切り戻し

変更承認書の切り戻し条件に該当した場合だけ実施する。

1. 新規作成したCloudWatch Alarmを削除する。
2. 新規作成したMetric Filterを削除する。
3. 既存SNS TopicとSubscriptionは削除しない。
4. Filter Pattern変更だった場合は、作業前のPatternへ戻す。
5. AlarmとMetric Filterが作業前の状態へ戻ったことを確認する。

## 10. 証跡名

```text
01_4.15_対象アカウント・リージョン_202609XX.png
02_4.15_対象CloudTrail・LogGroup_202609XX.png
03_4.15_MetricFilter_PatternTest_202609XX.png
04_4.15_MetricFilter設定後_202609XX.png
05_4.15_Alarm設定後_202609XX.png
06_4.15_CloudTrailテストイベント_202609XX.png
07_4.15_CloudWatchLogsテストイベント_202609XX.png
08_4.15_Metricデータポイント_202609XX.png
09_4.15_Alarm履歴_ALARM_202609XX.png
10_4.15_通知受信_202609XX.png
11_4.15_テスト変更切り戻し_202609XX.png
12_4.15_最終設定確認_202609XX.png
```

案Aの参照操作試験では`11_4.15_テスト変更切り戻し_202609XX.png`は不要とする。不要な証跡番号は欠番のままとし、後続番号を振り直さない。

## 11. トラブルシューティング

| 事象 | 確認内容 |
| :--- | :--- |
| CloudTrailにイベントがない | 操作したアカウント、管理アカウント、委任管理者、`us-east-1`、検索期間、イベントソースを確認する |
| CloudTrailにはあるがLog Groupにない | TrailのCloudWatch Logs連携、管理イベント、マルチリージョン設定、Log Group、配信遅延を確認する |
| Pattern Testで案Bが一致しない | サンプルに`"readOnly":false`がBoolean値で存在するか確認する。文字列`"false"`にしない |
| Log GroupにはあるがMetricが増えない | Filter作成後のイベントか、Filter Pattern、Metric Namespace、Metric Nameを確認する |
| Metricは増えたがAlarmが遷移しない | Statistic、Period、Threshold、Datapoints、MetricのDimension有無を確認する |
| Alarmは遷移したが通知されない | Alarm actions、SNS Topic、Subscriptionの`Confirmed`、通知先側の受信設定を確認する |
| AccessDeniedまたは明示的拒否 | IAM AllowだけでなくSCP、Permissions Boundary、Session Policy、A-gate統制を確認する |

## 12. 必要権限

### 12.1 監視設定と確認

```text
logs:DescribeLogGroups
logs:DescribeMetricFilters
logs:FilterLogEvents
logs:TestMetricFilter
logs:PutMetricFilter
cloudwatch:ListMetrics
cloudwatch:DescribeAlarms
cloudwatch:DescribeAlarmHistory
cloudwatch:PutMetricAlarm
cloudwatch:SetAlarmState
sns:GetTopicAttributes
sns:ListSubscriptionsByTopic
cloudtrail:LookupEvents
```

削除を伴う切り戻しには次の権限も必要となる。

```text
logs:DeleteMetricFilter
cloudwatch:DeleteAlarms
```

### 12.2 OU名称変更試験

```text
organizations:DescribeOrganization
organizations:ListRoots
organizations:ListOrganizationalUnitsForParent
organizations:DescribeOrganizationalUnit
organizations:ListAccountsForParent
organizations:ListPoliciesForTarget
organizations:ListTagsForResource
organizations:UpdateOrganizationalUnit
```

IAMで許可されていても、SCPやA-gateポリシーで明示的に拒否されている場合は実行できない。

## 13. 公式ドキュメント

- [CloudWatch LogsのFilter Pattern構文](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [Metric FilterのFilter Pattern構文](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html)
- [AWS Organizations API呼び出しのCloudTrail記録](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/orgs_cloudtrail-integration.html)
- [AWS Organizationsの操作・リソース・条件キー](https://docs.aws.amazon.com/ja_jp/service-authorization/latest/reference/list_organizations.html)
- [UpdateOrganizationalUnit API](https://docs.aws.amazon.com/organizations/latest/APIReference/API_UpdateOrganizationalUnit.html)
- [TagResource API](https://docs.aws.amazon.com/ja_jp/organizations/latest/APIReference/API_TagResource.html)
- [CloudWatch Alarm](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)
- [CloudWatch Logs権限リファレンス](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/permissions-reference-cwl.html)
- [CloudWatchのサービス認可リファレンス](https://docs.aws.amazon.com/ja_jp/service-authorization/latest/reference/list_amazoncloudwatch.html)

---

# 追補: 要件4.9 AWS Config Metric Filter・Alarm実作業手順

この追補は要件4.9の作業手順であり、要件4.15のOrganizations監視設定とは別のMetric FilterとAlarmを作成する。

## A.1 目的と試験範囲

AWS Configの設定変更をCloudTrailから検知し、CloudWatch Logs、Metric Filter、CloudWatch Alarm、既存SNS Topicを通して通知する。

検証環境では、テスト用AWS Config Ruleを作成して`PutConfigRule`を発生させ、通知受信までEnd-to-Endで確認する。確認後はテスト用Ruleを削除し、`DeleteConfigRule`も検知されることを確認する。

本番環境では、関係者承認を条件として実Config Ruleを作成せず、Pattern Testと設定同一性の確認に置き換える。

## A.2 作業前確認

1. 作業対象アカウント、環境、リージョンを確認する。
2. CloudTrailからCloudWatch Logsへの配信先Log Groupを確認する。
3. AWS ConfigのConfiguration Recorderが稼働していることを確認する。
4. 既存のConfig Rule、Conformance Pack、Security Hubサービスリンクルールを確認する。
5. テスト用Rule名が既存Ruleと重複しないことを確認する。
6. 対象を承認済みの空またはテスト用S3バケット1個に限定できることを確認する。
7. AWS Configの評価結果を対象とするEventBridge、A-gate、SNSなどの既存通知有無を確認する。
8. テスト用Ruleに自動修復も手動修復も設定しないことを確認する。
9. `PutConfigRule`と`DeleteConfigRule`で最大2回通知される可能性を通知確認者へ連絡する。同じALARM状態中に両イベントが発生した場合、2回目は状態遷移がないため通知されない場合がある。
10. 作業者に第A.11章の権限が付与され、SCPやA-gateによる明示的拒否がないことを確認する。

重要:

- Config Ruleは対象リソースを評価するものであり、修復アクションを設定しない限りS3の設定やオブジェクトを変更しない。
- 本手順で使用するRuleはバケットレベルの公開状態を評価する。S3オブジェクトの追加、削除、上書き、ダウンロードは行わない。
- コンソールで対象をテスト用バケット1個または一意なテストタグへ限定できない場合は、全S3バケットを対象にして続行せず、作業を停止する。
- 既存Ruleを編集して`PutConfigRule`を発生させない。必ず一意な名前のテスト用Ruleを新規作成する。

## A.3 設定値

現場の変更パラメータ一覧と命名規則が本章より優先される。

| 項目 | 設定値 |
| :--- | :--- |
| Metric Filter名 | `<現場命名規則>-security-4-9-config-change` |
| Metric Namespace | `Custom` |
| Metric Name | `Req49ConfigChangeCount` |
| Metric Value | `1` |
| Default Value | `0` |
| Unit | `Count` |
| Dimension | なし |
| Alarm名 | `<現場命名規則>-security-4-9-config-change-alarm` |
| Statistic | `Sum` |
| Period | `5 minutes` |
| Evaluation Periods | `1` |
| Datapoints to Alarm | `1 out of 1` |
| Threshold | `1以上` |
| Missing data | `Treat missing data as good (not breaching threshold)` |
| Alarm action | 有効 |
| 通知先 | 承認済みの既存SNS Topic |
| テスト用Config Rule | `S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED` |
| テスト用Rule名 | `<現場命名規則>-req49-test-s3-public-access` |
| Ruleの対象 | 承認済みテスト用S3バケット1個、または一致リソースが存在しない一意なテストタグ |
| 修復アクション | 設定しない |

### A.3.1 Metric Filter Pattern

```text
{ ($.eventSource = "config.amazonaws.com") && (($.eventName = "StopConfigurationRecorder") || ($.eventName = "StartConfigurationRecorder") || ($.eventName = "PutConfigurationRecorder") || ($.eventName = "DeleteConfigurationRecorder") || ($.eventName = "PutDeliveryChannel") || ($.eventName = "DeleteDeliveryChannel") || ($.eventName = "PutConfigRule") || ($.eventName = "DeleteConfigRule")) }
```

## A.4 Pattern Test

CloudWatch Logsの「パターンをテスト」へ、次のJSONを1行に1イベントの形式でまとめて貼り付ける。

### A.4.1 一致サンプル

```text
{"eventSource":"config.amazonaws.com","eventName":"StopConfigurationRecorder","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"StartConfigurationRecorder","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"PutConfigurationRecorder","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"DeleteConfigurationRecorder","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"PutDeliveryChannel","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"DeleteDeliveryChannel","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"PutConfigRule","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"config.amazonaws.com","eventName":"DeleteConfigRule","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
```

期待結果: 8件すべてが一致する。

### A.4.2 不一致サンプル

```text
{"eventSource":"config.amazonaws.com","eventName":"DescribeConfigRules","readOnly":true,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
{"eventSource":"s3.amazonaws.com","eventName":"PutBucketPolicy","readOnly":false,"userIdentity":{"type":"AssumedRole","arn":"arn:aws:sts::123456789012:assumed-role/test-role/test-session"}}
```

期待結果: 2件とも不一致となる。

## A.5 Metric Filter作成

1. CloudWatchコンソールを開く。
2. 画面右上でCloudTrailのCloudWatch Logs連携先Log Groupが存在するリージョンを選択する。
3. 左ペインの「ログ」から「ロググループ」を選択する。
4. CloudTrail連携先Log Groupを選択する。
5. 「メトリクスフィルター」タブを選択する。
6. 同じFilter名またはMetric Nameの既存設定がないことを確認する。
7. 「メトリクスフィルターを作成」を選択する。
8. 第A.3.1章のFilter Patternを貼り付ける。
9. 第A.4.1章の一致サンプルを使用してPattern Testを実行し、8件すべてが一致することを確認する。
10. 第A.4.2章の不一致サンプルを使用してPattern Testを実行し、一致件数が0件となることを確認する。
11. 「次へ」を選択する。
12. Filter名に`<現場命名規則>-security-4-9-config-change`を入力する。
13. Metric Namespaceに`Custom`を入力する。
14. Metric Nameに`Req49ConfigChangeCount`を入力する。
15. Metric Valueに`1`を入力する。
16. Default Valueに`0`を入力する。
17. Unitに`Count`を指定する。
18. Dimensionは設定しない。
19. 設定値を再確認し、「メトリクスフィルターを作成」を選択する。
20. 作成したFilterの詳細を開き、PatternとMetric変換値を確認する。

## A.6 CloudWatch Alarm作成

1. CloudWatchコンソールの「アラーム」から「すべてのアラーム」を選択する。
2. 「アラームの作成」を選択する。
3. 「メトリクスの選択」を選択する。
4. カスタム名前空間の`Custom`を選択する。
5. Dimensionなしの`Req49ConfigChangeCount`を選択する。
6. Statisticを`Sum`に設定する。
7. Periodを`5 minutes`に設定する。
8. Threshold typeを`Static`に設定する。
9. 条件を`Greater/Equal`、しきい値を`1`に設定する。
10. Datapoints to Alarmを`1 out of 1`に設定する。
11. Missing data treatmentを`Treat missing data as good (not breaching threshold)`に設定する。
12. Alarm state triggerを`In alarm`に設定する。
13. 通知先に承認済みの既存SNS Topicを指定する。
14. OK actionとInsufficient data actionは、現場設計で指定がなければ設定しない。
15. Alarm名に`<現場命名規則>-security-4-9-config-change-alarm`を入力する。
16. 説明に`Requirement 4.9 AWS Config setting change monitoring`を入力する。
17. 設定内容を確認してAlarmを作成する。
18. Alarm actionsが有効で、SNS Topic ARNが正しいことを確認する。

## A.7 検証環境End-to-End試験

### A.7.1 テスト用Config Rule作成

1. Metric FilterとAlarmが作成済みであることを確認する。
2. Alarmが`OK`または`データ不足`であり、作業前から`ALARM`ではないことを確認する。
3. AWS Configコンソールを開く。
4. CloudWatch Logsと同じ作業対象アカウント・環境であることを確認する。
5. AWS Configの対象リージョンを選択する。
6. 左ペインから「ルール」を選択する。
7. 「ルールを追加」を選択する。
8. AWSマネージドルールから`s3-bucket-level-public-access-prohibited`を検索して選択する。
9. Rule名に`<現場命名規則>-req49-test-s3-public-access`を入力する。
10. 評価モードが表示される場合は`Detective`を選択する。
11. スコープを`AWS::S3::Bucket`に限定する。
12. リソースIDを指定できる場合は、承認済みテスト用S3バケット名を指定する。
13. リソースIDを指定できない場合は、事前確認済みの一意なテストタグを指定し、一致する既存リソースがないことを確認する。
14. コンソールが全S3バケットだけを対象にする表示の場合は作成せず、作業を停止する。
15. パラメータは現場承認値を使用する。未指定の場合は追加しない。
16. 修復アクションを設定しない。
17. Rule名、対象範囲、修復アクションなしを再確認する。
18. 「保存」または「ルールを追加」を選択する。
19. Ruleが一覧に表示され、評価状態が`EVALUATING`、`COMPLIANT`、`NON_COMPLIANT`または`INSUFFICIENT_DATA`のいずれかになったことを確認する。

評価結果は4.9の発報試験成否を決めない。4.9では`PutConfigRule`がCloudTrailから通知まで到達することを確認する。

### A.7.2 `PutConfigRule`発報確認

1. CloudTrailコンソールの「イベント履歴」を開く。
2. イベント名を`PutConfigRule`に絞り込む。
3. 作業時刻、作業者、Rule名が今回の操作と一致するイベントを開く。
4. `eventSource=config.amazonaws.com`、`eventName=PutConfigRule`、`readOnly=false`を確認する。
5. CloudWatch LogsのCloudTrail連携先Log Groupを開く。
6. `PutConfigRule`または今回のRule名で検索し、同じEvent IDのログを確認する。
7. `Custom/Req49ConfigChangeCount`のデータポイントが`1`以上になったことを確認する。
8. Alarm履歴で`ALARM`への状態遷移を確認する。
9. 既存SNS Topic経由のメール、Teamsまたは監視基盤で通知受信を確認する。
10. CloudTrail、CloudWatch Logs、Metric、Alarm履歴、通知受信の証跡を保存する。

ログ配信とAlarm評価には時間差がある。通知待ち中に同じRuleを再作成または更新しない。

### A.7.3 テスト用Config Rule削除

1. `PutConfigRule`の通知確認と証跡取得が完了していることを確認する。
2. `DeleteConfigRule`でも別の通知を確認する場合は、Alarmが`OK`へ戻ってから削除を開始する。Alarmが`ALARM`のまま削除すると、Metricは加算されても新しい状態遷移がないため2回目のSNS通知が発生しない場合がある。
3. AWS Configコンソールの「ルール」を開く。
4. 今回作成したRule名と完全一致するRuleを選択する。
5. 修復アクションが設定されていないことを再確認する。
6. 「アクション」から「削除」を選択する。
7. 削除対象が今回のテスト用Ruleだけであることを確認して削除する。
8. Ruleが`DELETING`になった場合は、一覧から消えるまで待機する。
9. CloudTrailイベント履歴で`DeleteConfigRule`を確認する。
10. CloudWatch Logs、Metric、Alarm履歴を確認する。
11. Alarmが削除前に`OK`へ戻っていた場合は、`DeleteConfigRule`による再度の`ALARM`遷移と通知受信を確認する。
12. Alarmが削除前から`ALARM`だった場合は、2回目の通知ではなく、Metricの加算とCloudTrail・CloudWatch Logsの`DeleteConfigRule`を確認する。
13. テスト用Ruleが削除され、既存Config Ruleに変更がないことを確認する。
14. テスト用S3バケットのPublic Access Block、バケットポリシー、ACLが作業前から変わっていないことを確認する。オブジェクトに対する操作を実施していないことを作業記録で確認する。

## A.8 本番環境で実イベントを発生させない場合

この試験方式は、関係者から事前承認を得た場合だけ採用する。

1. 本番環境のCloudTrailからCloudWatch Logsへの配信状態を確認する。
2. 本番環境で第A.5章のMetric Filterを作成する。
3. 第A.4章のサンプルログを使用してPattern Testを実行する。
4. 一致サンプル8件が一致した結果と、不一致サンプルの一致件数が0件となった結果を保存する。
5. 第A.6章のAlarmを作成する。
6. Filter Pattern、Metric変換、Alarm条件、既存SNS Topicを検証環境と比較する。
7. Alarm actionsが有効であることを確認する。
8. 本番環境では`PutConfigRule`または`DeleteConfigRule`を発生させていないことを試験結果へ記載する。
9. 検証環境のEnd-to-End証跡と、本番環境のPattern Test・設定同一性証跡を関連付ける。
10. 本番環境の試験完了判定について承認を得る。

試験結果への記載例:

```text
検証環境では、テスト用AWS Config Ruleの作成・削除により、
PutConfigRuleおよびDeleteConfigRuleを発生させ、CloudTrailから通知受信まで
End-to-Endで確認した。

本番環境では業務影響回避のため実Config Ruleの作成・削除は行わず、
検証環境との設定同一性、Metric FilterのPattern Test、Alarm条件、
通知先SNS Topicを確認した。本試験方式は関係者承認済みである。
```

## A.9 証跡名

```text
01_4.9_対象アカウント・リージョン_202609XX.png
02_4.9_CloudTrail・LogGroup確認_202609XX.png
03_4.9_AWSConfig既存Rule確認_202609XX.png
04_4.9_MetricFilter_PatternTest_202609XX.png
05_4.9_MetricFilter設定後_202609XX.png
06_4.9_Alarm設定後_202609XX.png
07_4.9_テストConfigRule設定値_202609XX.png
08_4.9_CloudTrail_PutConfigRule_202609XX.png
09_4.9_CloudWatchLogs_PutConfigRule_202609XX.png
10_4.9_Metricデータポイント_202609XX.png
11_4.9_Alarm履歴_PutConfigRule_202609XX.png
12_4.9_通知受信_PutConfigRule_202609XX.png
13_4.9_テストConfigRule削除後_202609XX.png
14_4.9_CloudTrail_DeleteConfigRule_202609XX.png
15_4.9_Alarm履歴_DeleteConfigRule_202609XX.png
16_4.9_通知受信_DeleteConfigRule_202609XX.png
17_4.9_S3バケット設定無変更確認_202609XX.png
18_4.9_最終設定確認_202609XX.png
```

本番環境で実イベントを発生させない場合、07から17は検証環境の証跡を参照し、本番環境ではPattern Test、設定同一性、最終設定確認を保存する。

## A.10 トラブルシューティング

| 事象 | 確認内容 |
| :--- | :--- |
| Config Ruleを作成できない | `config:PutConfigRule`、Permissions Boundary、SCP、A-gateの明示的拒否を確認する |
| テスト用S3バケットを限定できない | 全S3バケットを対象にせず停止する。一意なテストタグまたは別の承認済みテスト対象を確認する |
| Ruleが`INSUFFICIENT_DATA`になる | 対象S3バケットがConfig Recorderの記録対象か確認する。4.9では`PutConfigRule`の通知経路を優先して確認する |
| CloudTrailに`PutConfigRule`がない | 作業アカウント、リージョン、検索期間、作業完了の成否を確認する |
| CloudTrailにはあるがLog Groupにない | TrailのCloudWatch Logs連携、管理イベント、対象Log Group、配信遅延を確認する |
| Metricが増えない | Metric Filter作成後のイベントか、Filter Pattern、Namespace、Metric Nameを確認する |
| Alarmが遷移しない | Statistic、Period、Threshold、Datapoints、Missing data、Dimension有無を確認する |
| Alarmは遷移したが通知されない | Alarm actions、SNS Topic ARN、Subscription状態、通知先側の受信設定を確認する |
| Ruleを削除できない | `config:DeleteConfigRule`、サービスリンクルールではないこと、修復アクション実行中ではないことを確認する |
| 削除後もRuleが表示される | 削除は非同期である。`DELETING`状態が完了するまで待機し、再度削除しない |

## A.11 必要権限

```text
config:DescribeConfigurationRecorders
config:DescribeConfigurationRecorderStatus
config:DescribeConfigRules
config:DescribeComplianceByConfigRule
config:PutConfigRule
config:DeleteConfigRule
config:ListDiscoveredResources
cloudtrail:LookupEvents
logs:DescribeLogGroups
logs:DescribeMetricFilters
logs:FilterLogEvents
logs:TestMetricFilter
logs:PutMetricFilter
cloudwatch:ListMetrics
cloudwatch:DescribeAlarms
cloudwatch:DescribeAlarmHistory
cloudwatch:PutMetricAlarm
sns:GetTopicAttributes
sns:ListSubscriptionsByTopic
s3:ListAllMyBuckets
s3:GetBucketPublicAccessBlock
s3:GetBucketPolicy
s3:GetBucketAcl
```

監視設定を切り戻す場合は、次の権限も必要となる。

```text
logs:DeleteMetricFilter
cloudwatch:DeleteAlarms
```

## A.12 公式ドキュメント

- [AWS Config Ruleのコンポーネントとスコープ](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/evaluate-config_components.html)
- [AWS Configマネージドルール](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/evaluate-config_use-managed-rules.html)
- [s3-bucket-level-public-access-prohibited](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/s3-bucket-level-public-access-prohibited.html)
- [AWS Config Rule評価・削除時の考慮事項](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/evaluate-config.html)
- [DeleteConfigRule](https://docs.aws.amazon.com/ja_jp/config/latest/APIReference/API_DeleteConfigRule.html)
- [AWS Config Ruleのトラブルシューティング](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/troubleshooting-rules.html)
- [サービスリンクAWS Config Rule](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/service-linked-awsconfig-rules.html)
- [CloudWatch Alarmの評価と状態](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)
