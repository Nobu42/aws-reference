# Day 5 Learning: MFAなし管理コンソールログイン検知の設計理解

## 学習開始前に実行するスクリプト

Day 5はAWSリソースを新規作成しないが、CLIで実際のCloudTrail Event History、CloudWatch Logs、Metric Filterの状態を確認するハンズオンとして進める。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

既存TrailやCloudWatch Logs連携がない場合も、その状態を確認結果として扱う。Day 5のためだけに新規作成しない。

実行場所を統一する。

```bash
cd /Users/nobu/aws-reference/day-learning
pwd
```

最初に作業対象アカウントを確認する。

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

`ConsoleLogin`イベントの有無を実際に確認する。AWSサインイン系イベントは`us-east-1`側に現れることがあるため、東京とバージニア北部の両方を確認する。

```bash
for REGION in ap-northeast-1 us-east-1; do
  echo "=== ${REGION} ==="
  aws cloudtrail lookup-events \
    --profile learning \
    --region "$REGION" \
    --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
    --max-results 5 \
    --query 'Events[].{EventTime:EventTime,Username:Username,EventId:EventId}' \
    --output table \
    --no-cli-pager
done
```

## 1. 今日の目的

CloudTrailに記録されるAWS Management Consoleへのログインイベントを理解し、MFAなしログインをCloudWatch Logs、Metric Filter、CloudWatch Alarmで検知する設計を説明できるようにする。

Day 5では、既存設定の確認、イベント調査、Filter Patternのテスト、変更手順と切り戻し手順の整理を行う。

Metric Filter、CloudWatch Alarm、SNS通知の作成・変更・削除は実施しない。

関連資料:

- [MFAなし管理コンソールログイン検知手順](../docs/references/06_mfa_console_login_detection.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)
- [Day 4 CloudWatch Logs・Metric Filter・Alarm確認](./04_Day_Learning.md)

## 今日の確認順序

1. 作業対象のAWSアカウントとリージョンを確認する
2. MFAなし管理コンソールログイン検知の目的を理解する
3. CloudTrailの`ConsoleLogin`イベントを理解する
4. CloudTrailで`ConsoleLogin`イベントを検索する
5. CloudTrailからCloudWatch Logsへの連携状況を確認する
6. CloudWatch Logsで既存の`ConsoleLogin`イベントを検索する
7. 推奨Filter Patternを理解する
8. `test-metric-filter`で一致・不一致を確認する
9. Metric FilterとCustom Metricの設計を整理する
10. CloudWatch Alarmと通知の設計を整理する
11. 変更手順、テスト、切り戻し手順を整理する
12. 検知時の一次調査と報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| 主な確認リージョン | `ap-northeast-1` |
| 追加確認リージョン | `us-east-1` |
| AWS CLIプロファイル | `learning` |
| 主な確認対象 | CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm |
| 実行可能なテスト | `test-metric-filter`によるFilter Patternテスト |
| 設定変更 | なし |

## 今日実行しない操作

次の操作は監視設定、通知、課金、運用へ影響するため、Day 5では実行しない。

- CloudTrail Trailの作成・変更・削除
- CloudTrailからCloudWatch Logsへの連携設定
- Log Groupの作成・削除
- Metric Filterの作成・更新・削除
- CloudWatch Alarmの作成・更新・削除
- Alarm Actionの有効化・無効化
- SNS TopicやSubscriptionの作成・変更・削除
- MFAなしの実ログインテスト
- `set-alarm-state`による通知テスト

---

## 2. MFAなし管理コンソールログイン検知の全体像

AWS Management Consoleへログインすると、CloudTrailに`ConsoleLogin`イベントが記録される。

そのイベントをCloudWatch Logsへ配信し、Metric Filterで条件に一致したイベントをCustom Metricへ変換する。CloudWatch AlarmはCustom Metricを監視し、必要に応じてSNSなどへ通知する。

```text
AWS Management Consoleへのログイン
↓
CloudTrail ConsoleLoginイベント
↓
CloudTrail Trail
↓
CloudWatch Logs Log Group
↓
Metric Filter
↓
CloudWatch Custom Metric
↓
CloudWatch Alarm
↓
SNS、メール、Teamsなど
↓
担当者による一次調査
```

## 面談で求められた内容との関係

面談では、重点キャッチアップ領域の具体例として次が挙げられた。

```text
CloudTrailをCloudWatchに連携し、
MFAなし管理コンソールログインを検知する。
```

この作業には、単一サービスではなく次の知識が必要になる。

| 領域 | 必要な理解 |
|---|---|
| IAM・認証 | MFAの目的、IAMユーザー、Root、Federation |
| CloudTrail | `ConsoleLogin`イベント、実行者、時刻、送信元IP |
| CloudWatch Logs | CloudTrailイベントの保存・検索 |
| Metric Filter | JSONログの条件判定 |
| CloudWatch Metrics | 検知件数の数値化 |
| CloudWatch Alarm | しきい値、評価期間、状態遷移 |
| SNS・通知 | 通知先、通知試験、運用ルール |
| インシデント対応 | 後続操作、権限、送信元IPの調査 |

---

## 3. なぜMFAなしログインを検知するのか

MFAを利用しないログインでは、パスワードが漏えいした場合に第三者がAWS Management Consoleへログインできる可能性が高くなる。

特に次のケースは優先して調査する。

- RootユーザーによるMFAなしログイン
- 管理者権限を持つIAMユーザーによるMFAなしログイン
- 通常と異なる送信元IPアドレスからのログイン
- 作業時間外や深夜のログイン
- ログイン直後にIAM、S3、Security Group、CloudTrailなどを変更したケース
- 複数回のログイン失敗後に成功したケース

## 検知と予防の違い

MFAなしログイン検知は、MFAなしログインを禁止する設定ではない。

```text
予防:
MFAを必須化し、MFAなしでは操作できないようにする

検知:
MFAなしログインが発生した事実をログから見つけて通知する
```

金融系案件では、予防統制と発見的統制の両方を確認する必要がある。

---

## 4. ConsoleLoginイベントを理解する

AWS Management Consoleへのサインインは、CloudTrailに`ConsoleLogin`イベントとして記録される。

### 主な確認フィールド

| フィールド | 意味 | 確認例 |
|---|---|---|
| `eventSource` | イベント発生元サービス | `signin.amazonaws.com` |
| `eventName` | API・イベント名 | `ConsoleLogin` |
| `eventTime` | 発生時刻 | UTCで記録される |
| `userIdentity.type` | ログイン主体の種類 | `Root`、`IAMUser`、`AssumedRole`など |
| `userIdentity.arn` | ログイン主体のARN | IAMユーザーARNなど |
| `responseElements.ConsoleLogin` | ログイン結果 | `Success`または`Failure` |
| `additionalEventData.MFAUsed` | MFA利用有無 | `Yes`または`No` |
| `sourceIPAddress` | 送信元IPアドレス | ログイン元グローバルIPなど |
| `userAgent` | ブラウザ・クライアント情報 | ブラウザ情報など |
| `awsRegion` | イベント記録リージョン | `ap-northeast-1`、`us-east-1`など |

### 検知対象とするイベント

Day 5では、次の3条件をすべて満たすイベントを検知対象とする。

```text
eventName = ConsoleLogin
responseElements.ConsoleLogin = Success
additionalEventData.MFAUsed = No
```

意味:

```text
AWS Management Consoleへのログインに成功し、
そのログインでMFAが使用されていない。
```

### 成功したMFAなしログインを優先する理由

- 実際にAWS Management Consoleへログインできたイベントを優先できる
- ログイン失敗イベントによる通知ノイズを減らせる
- 検知後に後続操作の調査へ進みやすい
- Alarmの意味を関係者へ説明しやすい

### 広めの検知条件

監査目的では、次のような広い条件を使う場合がある。

```text
eventName = ConsoleLogin
additionalEventData.MFAUsed != Yes
```

この条件は、失敗ログインや`MFAUsed`が存在しないイベントも含む可能性がある。

通知用と監査用では、Filter Patternを分けて検討する。

---

## 5. 作業対象の確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のAWSアカウント情報を確認する
3. 東京リージョンへ切り替える
4. CloudTrailコンソールを開く
5. 「イベント履歴」を開く

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_CloudTrailイベント履歴画面.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

期待値:

```text
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
```

### 結果の読み方

- `Account`が想定AWSアカウントIDと一致することを確認する
- `Arn`から操作主体を確認する
- 想定外のAWSアカウントの場合は後続作業を中止する

---

## 6. CloudTrail Event HistoryでConsoleLoginを確認する

CloudTrail Event Historyを使い、`ConsoleLogin`イベントが記録されているか確認する。

### Webコンソール

1. CloudTrailの「イベント履歴」を開く
2. 検索属性で「イベント名」を選択する
3. `ConsoleLogin`を入力する
4. 対象期間を必要最小限に絞る
5. イベントがある場合は詳細を開く
6. ログイン結果、MFA利用有無、実行者、送信元IPを確認する

取得するスクリーンショット:

```text
03_ConsoleLoginイベント一覧.png
04_ConsoleLoginイベント詳細.png
```

### AWS CLI: 東京リージョン

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --query 'Events[].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### AWS CLI: バージニア北部リージョン

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region us-east-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --query 'Events[].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### なぜus-east-1も確認するのか

AWSサインインはグローバルサービスに関係するため、Rootユーザーのログインなどが`us-east-1`で記録される場合がある。

東京リージョンで見つからない場合でも、イベントが存在しないと即断せず、`us-east-1`やTrailの構成を確認する。

### 結果の読み方

- イベントあり: Event IDを控えて詳細を確認する
- イベントなし: 対象期間、リージョン、ログイン方法を確認する
- Event Historyにイベントがないことだけでは、ログインが一度も発生していないとは断定しない

---

## 7. ConsoleLoginイベント詳細の確認

対象イベントがある場合は、Event IDを使って詳細を確認する。

### Event IDを設定する

```bash
EVENT_ID="<確認対象のEventId>"
```

### 読みやすい要約を確認する

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

対象イベントが`us-east-1`に存在する場合は、`--region us-east-1`へ変更する。

### 生イベントを確認する

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager
```

### 確認する内容

```text
誰が:
userIdentity.type
userIdentity.arn
userIdentity.userName

いつ:
eventTime

ログイン結果:
responseElements.ConsoleLogin

MFA利用:
additionalEventData.MFAUsed

どこから:
sourceIPAddress
userAgent

どのリージョンで記録されたか:
awsRegion

エラー:
errorCode
errorMessage
```

### 注意事項

CloudTrailイベントにはAWSアカウントID、ARN、送信元IP、Access Key IDなどが含まれる場合がある。

証跡を外部公開する場合は、必要な情報をマスクする。

---

## 8. CloudTrailからCloudWatch Logsへの連携確認

Metric Filterで`ConsoleLogin`イベントを検知するには、CloudTrailイベントがCloudWatch Logsへ配信されている必要がある。

### Webコンソール

1. CloudTrailコンソールを開く
2. 「証跡」を開く
3. 対象Trailを開く
4. CloudWatch Logs連携設定を確認する
5. 配信先Log GroupとIAM Roleを確認する
6. 「編集」は押さない

取得するスクリーンショット:

```text
05_CloudTrail_CloudWatch_Logs連携確認.png
```

### AWS CLI

```bash
aws cloudtrail describe-trails \
  --profile learning \
  --region ap-northeast-1 \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

| 項目 | 確認内容 |
|---|---|
| `IsMultiRegionTrail` | 複数リージョンのイベントを記録する構成か |
| `CloudWatchLogsLogGroupArn` | 配信先CloudWatch Logs Log Group ARN |
| `CloudWatchLogsRoleArn` | CloudTrailがログを配信するIAM Role ARN |

### 結果の読み方

```text
CloudWatchLogsLogGroupArnあり:
CloudTrailからCloudWatch Logsへの連携設定あり

CloudWatchLogsLogGroupArnがNoneまたは空:
CloudWatch Logs連携設定なし

CloudWatchLogsRoleArnがNoneまたは空:
CloudWatch Logsへの配信Roleが未設定
```

### 未連携の場合の判断

未連携は即時障害とは限らない。

次を確認してから、改善候補または変更対象として整理する。

- MFAなしログインをリアルタイムに近い形で検知する要件があるか
- 既存SIEMや監視製品へ別経路で連携しているか
- CloudTrail TrailがS3へログを保存しているか
- Multi-Region Trailが必要か
- Log GroupのRetention要件
- CloudTrail連携用IAM Roleの作成・変更影響
- CloudWatch Logs取り込み料金と保存料金

---

## 9. CloudWatch LogsでConsoleLoginを検索する

CloudTrail連携先Log Groupが存在する場合は、CloudWatch Logsで`ConsoleLogin`イベントを検索する。

連携先Log Groupがない場合は、この章を手順確認として読み、実行結果を「未連携のため実施不可」と記録する。

### 対象Log Group名を確認する

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes}' \
  --output table \
  --no-cli-pager
```

### Log Group名を設定する

```bash
LOG_GROUP_NAME="<CloudTrail連携先Log Group名>"
```

### ConsoleLogin全体を検索する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "ConsoleLogin" }' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### 成功したMFAなしログインを検索する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 出力あり: 条件に一致するイベントを詳細調査する
- 出力なし: 対象時間帯に一致イベントがない可能性がある
- 出力なしでも、Filter PatternやCloudTrail連携不備の可能性を確認する
- ログがCloudWatch Logsへ到着するまで時間差がある場合がある

---

## 10. Logs InsightsでConsoleLoginを調査する

Logs Insightsを使うと、必要なフィールドを抽出して読みやすく確認できる。

### Webコンソール

1. CloudWatchを開く
2. 「ログ」から「ログのインサイト」を開く
3. CloudTrail連携先Log Groupを選択する
4. 時間範囲を必要最小限へ絞る
5. 次のクエリを実行する

```text
fields @timestamp,
       eventTime,
       userIdentity.type,
       userIdentity.arn,
       userIdentity.userName,
       sourceIPAddress,
       responseElements.ConsoleLogin,
       additionalEventData.MFAUsed,
       awsRegion
| filter eventName = "ConsoleLogin"
  and responseElements.ConsoleLogin = "Success"
  and additionalEventData.MFAUsed = "No"
| sort @timestamp desc
| limit 50
```

取得するスクリーンショット:

```text
06_MFAなしConsoleLogin検索結果.png
```

### 確認ポイント

- ログイン主体
- ログイン成功・失敗
- MFA利用有無
- 送信元IPアドレス
- イベント発生時刻
- 記録リージョン
- 想定した作業時間・利用者と一致するか

### 注意事項

Logs Insightsは検索対象データ量に応じて料金が発生する。

対象Log Groupと時間範囲を必要最小限へ絞る。

---

## 11. 推奨Filter Patternを理解する

Day 5で使用する推奨Filter Pattern:

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }
```

### 条件を分解する

| 条件 | 意味 |
|---|---|
| `$.eventName = "ConsoleLogin"` | AWS Management Consoleへのログインイベント |
| `$.responseElements.ConsoleLogin = "Success"` | ログイン成功 |
| `$.additionalEventData.MFAUsed = "No"` | MFAを使用していない |
| `&&` | すべての条件を満たす |

### 一致するイベント

```json
{
  "eventName": "ConsoleLogin",
  "responseElements": {
    "ConsoleLogin": "Success"
  },
  "additionalEventData": {
    "MFAUsed": "No"
  }
}
```

### 一致しないイベント

MFAを使用したログイン:

```json
{
  "eventName": "ConsoleLogin",
  "responseElements": {
    "ConsoleLogin": "Success"
  },
  "additionalEventData": {
    "MFAUsed": "Yes"
  }
}
```

ログイン失敗:

```json
{
  "eventName": "ConsoleLogin",
  "responseElements": {
    "ConsoleLogin": "Failure"
  },
  "additionalEventData": {
    "MFAUsed": "No"
  }
}
```

---

## 12. test-metric-filterで条件をテストする

`test-metric-filter`は、Metric Filterを作成せずにFilter Patternの一致結果を確認するコマンドである。

既存Log Group、Metric Filter、Custom Metric、Alarmは変更されない。

### 3種類のサンプルイベントをテストする

```bash
aws logs test-metric-filter \
  --profile learning \
  --region ap-northeast-1 \
  --filter-pattern '{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }' \
  --log-event-messages '["{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"No\"},\"sourceIPAddress\":\"203.0.113.10\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/test-user\"}}","{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"Yes\"},\"sourceIPAddress\":\"203.0.113.20\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/mfa-user\"}}","{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Failure\"},\"additionalEventData\":{\"MFAUsed\":\"No\"},\"sourceIPAddress\":\"203.0.113.30\",\"userIdentity\":{\"type\":\"IAMUser\",\"arn\":\"arn:aws:iam::123456789012:user/failed-user\"}}"]' \
  --output table \
  --no-cli-pager
```

### 期待結果

```text
1件目:
ConsoleLogin=Success、MFAUsed=No
一致する

2件目:
ConsoleLogin=Success、MFAUsed=Yes
一致しない

3件目:
ConsoleLogin=Failure、MFAUsed=No
一致しない
```

### テスト結果の判断

推奨Filter Patternでは、成功したMFAなしログインだけが一致する。

このテストでは、実際のMFAなしログイン、Metric Filter作成、Alarm通知は発生しない。

### 証跡として残す内容

```text
実行したFilter Pattern
テストに使用したサンプルイベント
一致したイベント番号
一致しなかったイベント番号
期待結果と実際の結果
実AWS環境の設定変更がないこと
```

---

## 13. 既存Metric FilterとAlarmを確認する

設定変更前には、同じ目的のMetric FilterやAlarmが既に存在しないか確認する。

既存設定がある場合、重複通知、メトリクス重複、命名競合が発生する可能性がある。

### 既存Metric Filter確認

CloudTrail連携先Log Groupが存在する場合に実行する。

```bash
aws logs describe-metric-filters \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name "$LOG_GROUP_NAME" \
  --query 'metricFilters[].{FilterName:filterName,FilterPattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output table \
  --no-cli-pager
```

### 既存Alarm確認

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,Namespace:Namespace,MetricName:MetricName,Threshold:Threshold,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- 同じ目的のFilter Patternが存在しないか
- 命名規則が定められているか
- Metric NamespaceとMetric Nameが重複しないか
- Alarmが同じMetricを監視していないか
- Alarm Actionが有効か
- 通知先が現行運用と一致するか

---

## 14. Metric FilterとCustom Metricの設計

Metric Filterは、MFAなしログインイベントを検知するとCustom Metricへ数値を出力する。

### 設計例

| 項目 | 設計例 | 意味 |
|---|---|---|
| Filter Name | `ConsoleLoginWithoutMFA` | Metric Filter名 |
| Filter Pattern | 成功かつMFAなし | 検知条件 |
| Metric Namespace | `NobuIacLab/Security` | Custom Metricの分類 |
| Metric Name | `ConsoleLoginWithoutMFA` | Alarmが監視するMetric名 |
| Metric Value | `1` | 1件検知時に1を記録 |
| Default Value | `0` | 一致イベントがない場合の値 |
| Unit | `Count` | 件数 |

### 設計時の確認事項

- 現場の命名規則
- 既存Metricとの重複
- Filter Patternの誤検知・見逃し
- 対象Log Group
- Custom Metricの課金
- Dimensionの必要性
- 複数AWSアカウントでの識別方法

### Dimensionを慎重に扱う理由

ユーザー名や送信元IPをDimensionにすると、値の種類が増えて高カーディナリティになりやすい。

最初はDimensionなしで検知件数を記録し、詳細はCloudTrailイベントを調査する構成が扱いやすい。

---

## 15. CloudWatch Alarmの設計

CloudWatch Alarmは、Metric Filterが出力したCustom Metricを評価する。

### 設計例

| 項目 | 設計例 | 意味 |
|---|---|---|
| Alarm Name | `nobu-iac-lab-security-console-login-without-mfa` | Alarm名 |
| Namespace | `NobuIacLab/Security` | Metric Filterと一致させる |
| Metric Name | `ConsoleLoginWithoutMFA` | Metric Filterと一致させる |
| Statistic | `Sum` | 評価期間内の検知件数 |
| Period | `300` | 5分単位 |
| Evaluation Periods | `1` | 1評価期間で判定 |
| Threshold | `1` | 1件以上でALARM |
| Comparison Operator | `GreaterThanOrEqualToThreshold` | しきい値以上 |
| Treat Missing Data | `notBreaching` | データなしを正常扱い |
| Actions Enabled | 初回は無効 | 誤通知を防止する |

### Alarm状態

| 状態 | 意味 |
|---|---|
| `OK` | しきい値を超えていない |
| `ALARM` | 1件以上の検知など、設定条件を満たした |
| `INSUFFICIENT_DATA` | 評価に必要なデータが不足している |

### 初回は通知なしで作成する理由

- 不要なメールやTeams通知を防止できる
- Metric FilterとAlarm状態の動作を先に確認できる
- 通知先と運用ルールを確認してから有効化できる
- テスト通知と実検知を区別しやすい

---

## 16. 通知設計

Alarm Actionを有効化すると、Alarm状態変化時にSNSなどへ通知できる。

### 確認する内容

- 通知先SNS Topic
- Subscriptionの状態
- メール、Teams、監視システムなどの通知経路
- 通知対象の関係者
- 通知可能な時間帯
- テスト通知の事前連絡方法
- ALARM受信後の一次対応者
- エスカレーション先

### 通知メッセージに必要な情報

```text
検知名
発生時刻
対象AWSアカウント
対象リージョン
Alarm名
検知条件
CloudTrail確認手順
一次対応者
連絡先
```

### 通知だけでは不足する理由

CloudWatch AlarmはMFAなしログインが発生した可能性を通知する。

正当な作業か不正アクセスかは、CloudTrailイベント、作業予定、ユーザー権限、送信元IP、後続操作を確認して判断する。

---

## 17. 承認後に実施する変更手順

この章は、実際に検知設定を作成する場合の作業順序を整理したものである。

Day 5では実行しない。

### 変更作業の順序

```text
1. 作業申請・承認内容を確認する
2. 対象AWSアカウント、リージョン、Trailを確認する
3. 変更前設定と証跡を取得する
4. CloudTrailからCloudWatch Logsへの連携を確認・設定する
5. Log GroupのRetentionとIAM Roleを確認する
6. test-metric-filterでFilter Patternを確認する
7. Metric Filterを作成する
8. Custom Metricの出力を確認する
9. 通知なしでCloudWatch Alarmを作成する
10. Alarm状態と設定値を確認する
11. 承認後に通知Actionを追加する
12. テストを実施する
13. CloudTrailで変更履歴を確認する
14. 証跡と結果を手順書へ記録する
15. 関係者へ結果を報告する
```

### 変更前に必ず確認する項目

- 既存TrailとCloudWatch Logs連携
- 既存Metric FilterとAlarm
- Log GroupのRetention
- CloudTrail連携用IAM Role
- Metric NamespaceとMetric Name
- Alarm名と命名規則
- Alarm Actionと通知先
- 変更可能時間
- 切り戻し条件
- 作業後の監視担当者

---

## 18. 変更後テストの考え方

### 推奨するテスト順序

```text
1. test-metric-filterでFilter Patternをテストする
2. Metric Filter設定値を確認する
3. Custom Metricの出力を確認する
4. CloudWatch Alarm設定値を確認する
5. 通知なしでAlarm状態の変化を確認する
6. 承認後に通知経路をテストする
7. 必要な場合のみ、管理されたテスト用ユーザーで実イベントを確認する
```

### 本番環境でMFAなしログインを安易に実施しない理由

- セキュリティルール違反になる可能性がある
- 実インシデントと誤認される可能性がある
- 関係者へ不要な通知が発生する可能性がある
- テスト用ユーザーの権限管理が必要になる
- ログイン後の操作制限を確認する必要がある

### 実イベントテストが必要な場合

次を事前に確認する。

- テスト用IAMユーザーであること
- 管理者権限を持たないこと
- 作業申請と承認があること
- テスト時間帯と送信元IPを記録すること
- 関係者へ事前連絡すること
- テスト後にMFA設定またはユーザー削除を行うこと
- テスト結果をCloudTrailとCloudWatchで確認すること

---

## 19. 切り戻し手順の考え方

切り戻しは、作成した設定を逆順に戻す。

### 切り戻し順序

```text
1. Alarm Actionを無効化する
2. CloudWatch Alarmを削除または変更前へ戻す
3. Metric Filterを削除または変更前へ戻す
4. 必要な場合のみCloudTrailとCloudWatch Logs連携を変更前へ戻す
5. 変更前状態と一致することを確認する
6. CloudTrailで切り戻し操作を確認する
7. 切り戻し結果を報告する
```

### CloudTrail連携を安易に解除しない理由

CloudTrailからCloudWatch Logsへの連携は、MFAなしログイン以外の検知や監査にも使われている可能性がある。

Metric FilterやAlarmだけを追加した作業では、原則として追加した設定だけを切り戻す。

### 切り戻し条件例

- 想定外の大量検知が発生した
- 誤通知が継続している
- Filter Patternが要件と一致していない
- 既存監視へ影響が発生した
- Custom MetricまたはAlarm設定に誤りがある
- 承認された変更内容と異なる設定になった

---

## 20. 検知時の一次調査

MFAなし`ConsoleLogin`を検知した場合は、Alarmを確認するだけで終わらず、CloudTrailで詳細と後続操作を調査する。

### 一次調査項目

| 確認項目 | 内容 |
|---|---|
| ログイン結果 | `responseElements.ConsoleLogin` |
| MFA利用 | `additionalEventData.MFAUsed` |
| ユーザー種別 | `userIdentity.type` |
| ユーザーARN | `userIdentity.arn` |
| 送信元IP | `sourceIPAddress` |
| 発生時刻 | `eventTime` |
| User Agent | `userAgent` |
| 記録リージョン | `awsRegion` |
| 作業予定 | 承認済み作業時間・作業者と一致するか |
| 後続操作 | IAM、S3、VPC、CloudTrailなどの変更有無 |
| IAM状態 | MFA設定、権限、Access Keyの状態 |

### 調査の流れ

```text
Alarmの発生時刻と対象AWSアカウントを確認する
↓
CloudWatch LogsまたはCloudTrailで対象ConsoleLoginを特定する
↓
ユーザー、送信元IP、ログイン結果、MFA利用を確認する
↓
作業予定・利用者情報と照合する
↓
ログイン後のCloudTrailイベントを確認する
↓
不審な変更やデータアクセスの有無を確認する
↓
必要に応じてアカウント停止、認証情報無効化、関係者連絡を行う
```

### 後続操作の確認例

対象ユーザー名が分かる場合に使用する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=Username,AttributeValue="<対象ユーザー名>" \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,EventSource:EventSource,ReadOnly:ReadOnly,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 重大度を上げる例

- Rootユーザー
- 管理者権限を持つユーザー
- 未知の送信元IP
- 深夜・休日のログイン
- CloudTrail停止や削除
- IAMユーザー・Policy変更
- S3 Bucket PolicyやPublic Access Block変更
- Security Groupの公開設定
- 大量のデータ参照・削除

---

## 21. 証跡取得

### 変更前確認で取得する証跡

| No. | 証跡 | 確認内容 |
|---|---|---|
| 01 | 操作アカウント | AWSアカウントID、操作主体 |
| 02 | CloudTrail Event History | `ConsoleLogin`イベントの有無 |
| 03 | Trail設定 | Multi-Region、CloudWatch Logs連携 |
| 04 | Trail Status | ログ記録状態と配信エラー |
| 05 | CloudWatch Log Group | Log Group、Retention、KMS |
| 06 | 既存Metric Filter | Filter Pattern、Metric変換 |
| 07 | 既存Alarm | Alarm状態、Metric、Action |

### テストで取得する証跡

| No. | 証跡 | 確認内容 |
|---|---|---|
| 08 | Filter Pattern | 検知条件 |
| 09 | `test-metric-filter`結果 | 一致・不一致 |
| 10 | Logs Insights結果 | 既存MFAなしログインの有無 |

### 変更作業を行う場合の追加証跡

| No. | 証跡 | 確認内容 |
|---|---|---|
| 11 | 変更後Metric Filter | Filter Pattern、Metric Name |
| 12 | Custom Metric | Metric出力 |
| 13 | 変更後Alarm | しきい値、状態、Action |
| 14 | 通知テスト | 通知受信結果 |
| 15 | CloudTrail変更履歴 | 実行者、時刻、変更API |
| 16 | 切り戻し結果 | 変更前状態との一致 |

### スクリーンショット取得時の注意

- AWSアカウント、リージョン、対象リソースを識別できるようにする
- 設定値と対象名を同じ画面に含める
- 長い画面は確認項目ごとに分ける
- AWSアカウントID、ARN、IPアドレスなどの取り扱いルールを確認する
- 認証情報、Secret、個人情報を含めない
- テスト結果と実イベントを区別する

---

## 22. 影響範囲

### CloudTrailからCloudWatch Logsへの連携

- CloudWatch Logs取り込み料金が発生する
- Log Group保存料金が発生する
- IAM Role作成・変更が必要になる
- Multi-Region Trailでは複数リージョンのイベントが集約される
- 既存SIEM連携や監視設計との役割分担が必要になる

### Metric Filter

- Custom Metric料金が発生する
- Filter Pattern不備により誤検知・見逃しが発生する
- 同じイベントを複数Filterで数える可能性がある
- 同名Filterを更新すると既存設定へ影響する

### CloudWatch Alarm

- Alarm料金が発生する
- しきい値や欠損データの扱いにより状態が変わる
- Alarm Action有効化により通知が発生する
- 同じMetricを複数Alarmで監視すると重複通知が発生する

### SNS・通知

- 誤った宛先へ通知する可能性がある
- テスト通知が実インシデントと誤認される可能性がある
- Subscription未承認の場合は通知されない
- Teamsなど外部連携の運用ルール確認が必要になる

---

## 23. セキュリティ上の注意点

- MFAなしログインの実イベントテストは、承認なしで実施しない
- RootユーザーのMFAなしログインは特に高い優先度で調査する
- `ConsoleLogin`イベントだけでなく、ログイン後の操作を確認する
- CloudTrailやLog Groupの削除・停止・Retention短縮を安易に行わない
- CloudTrail連携用IAM Roleは最小権限とする
- Alarm Actionの通知先を事前に確認する
- CloudTrailイベント証跡にはIAM情報、IPアドレス、Access Key IDなどが含まれる可能性がある
- 公開資料へ証跡を掲載する場合は機密情報をマスクする
- 検知が存在することを理由にMFA必須化などの予防策を省略しない

---

## 24. よくある確認漏れ

### ConsoleLoginイベントが見つからない

- 東京リージョンだけを検索している
- `us-east-1`を確認していない
- 対象期間が間違っている
- Event Historyの対象期間外である
- FederationやIAM Identity Centerなど別のログイン方式を利用している
- CloudTrail TrailやEvent Data Storeの構成を確認していない

### CloudWatch Logsでイベントが見つからない

- CloudTrailからCloudWatch Logsへ連携されていない
- 対象Log Groupが間違っている
- Multi-Region Trailではない
- Log Groupへイベントが到着する前に検索している
- Filter Patternが実際のJSON構造と一致していない

### Metric Filterが期待どおり一致しない

- `MFAUsed`の値やフィールド名が間違っている
- `Success`と`Failure`を区別していない
- 実際のCloudTrailイベント形式を確認していない
- `test-metric-filter`で一致・不一致の両方を試していない

### AlarmがALARMにならない

- Metric FilterとAlarmのNamespaceが一致していない
- Metric Nameが一致していない
- Custom Metricがまだ出力されていない
- Period、Evaluation Periods、Thresholdが要件と合っていない
- `treat-missing-data`の設定が想定と異なる

### 通知が届かない

- Alarm Actionが無効
- SNS Topic ARNが間違っている
- Subscriptionが未承認
- Alarm状態が変化していない
- 通知テストの事前連絡や受信確認が不足している

---

## 25. 報告例

### 設計確認結果

```text
MFAなし管理コンソールログイン検知の設計確認を実施した。

検知条件:
- eventName = ConsoleLogin
- responseElements.ConsoleLogin = Success
- additionalEventData.MFAUsed = No

確認内容:
- CloudTrail Event HistoryでConsoleLoginイベントの確認方法を整理した
- CloudTrailからCloudWatch Logsへの連携状況を確認した
- Metric Filter、Custom Metric、CloudWatch Alarmの設定項目を整理した
- test-metric-filterで成功かつMFAなしのイベントだけが一致することを確認した
- 変更手順、テスト方法、切り戻し手順、一次調査項目を整理した

設定変更:
なし

要確認事項:
- 既存SIEM・監視製品との役割分担
- CloudTrail連携先Log GroupとRetention
- Metric Namespace、Metric Name、Alarm名の命名規則
- Alarm通知先と運用ルール
```

### 検知なしの場合

```text
対象期間のCloudTrailおよびCloudWatch Logsを確認した結果、
成功したMFAなし管理コンソールログインに該当するイベントは確認されなかった。

確認対象リージョン:
ap-northeast-1、us-east-1

確認条件:
ConsoleLogin、Success、MFAUsed=No

設定変更は実施していない。
```

### 検知ありの場合

```text
成功したMFAなし管理コンソールログインを確認した。

発生時刻:
<eventTime>

ログイン主体:
<userIdentity.type / userIdentity.arn>

送信元IP:
<sourceIPAddress>

確認結果:
作業予定および利用者情報との照合を実施中。
CloudTrailでログイン後の操作を確認中。

対応:
関係者へ連絡し、必要に応じて認証情報の無効化および権限確認を行う。
```

---

## 26. 案件で説明できるポイント

### 検知の流れ

```text
CloudTrailのConsoleLoginイベントをCloudWatch Logsへ配信し、
Metric FilterでSuccessかつMFAUsed=NoのイベントをCustom Metricへ変換する。

CloudWatch AlarmはCustom Metricを監視し、1件以上を検知した場合に
ALARM状態へ遷移する。必要に応じてSNSなどへ通知する。
```

### 作業時の重要点

```text
変更前にTrail、Log Group、既存Metric Filter、Alarm、通知先を確認する。

Filter Patternはtest-metric-filterで一致・不一致を確認し、
初回は通知なしでAlarmの動作を確認する。

通知先と運用ルールを確認した後にAlarm Actionを有効化する。
```

### 検知後の対応

```text
MFAなしログインを検知した場合は、
CloudTrailでユーザー、送信元IP、時刻、ログイン結果、後続操作を確認する。

承認済み作業か不正アクセスかを判断し、
必要に応じて認証情報無効化や関係者へのエスカレーションを行う。
```

---

## 27. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| CloudTrail | AWS API操作とConsoleLoginイベントを記録する |
| Event History | 主にManagement Eventを過去90日間検索する |
| Multi-Region Trail | 複数リージョンのイベントを記録する |
| CloudWatch Logs | CloudTrailイベントの保存・検索・監視に利用できる |
| Metric Filter | ログパターンをCustom Metricへ変換する |
| Custom Metric | Metric Filterの検知件数を保存する |
| CloudWatch Alarm | Metricを評価して状態を変更する |
| SNS | Alarmの通知先として利用できる |
| MFA | パスワード漏えい時の不正ログインリスクを軽減する |
| Rootユーザー | MFA設定と利用制限が特に重要 |

---

## 28. 要確認事項

現在のラボ環境および案件環境では、次の項目を個別に確認する必要がある。

- CloudTrailからCloudWatch Logsへの連携有無
- Multi-Region Trailの有無
- CloudTrail連携先Log Group名
- Log GroupのRetention
- CloudTrail連携用IAM Role
- 既存Metric FilterとAlarm
- 既存SIEM・監視製品との役割分担
- Metric Namespace、Metric Name、Alarm名の命名規則
- SNS、Teams、メールなどの通知経路
- MFAなしログインを検知した場合の一次対応者
- Federation、IAM Identity Center、IAMユーザーなど実際のログイン方式
- Rootユーザーの監視・運用ルール

不明な項目は作業を停止する理由として扱うのではなく、変更前の確認事項、未確認事項、影響調査項目として明示する。

---

## 29. Day 5完了チェックリスト

- [ ] AWSアカウントと確認対象リージョンを確認した
- [ ] `ConsoleLogin`イベントの主なフィールドを説明できる
- [ ] `Success`かつ`MFAUsed=No`を検知する理由を説明できる
- [ ] 東京リージョンと`us-east-1`でEvent Historyを確認した
- [ ] CloudTrailからCloudWatch Logsへの連携状況を確認した
- [ ] CloudWatch Logsで`ConsoleLogin`を検索する方法を確認した
- [ ] Logs Insightsの検索クエリを確認した
- [ ] 推奨Filter Patternを分解して説明できる
- [ ] `test-metric-filter`で一致・不一致を確認した
- [ ] 既存Metric FilterとAlarmの確認方法を理解した
- [ ] Metric Filter、Custom Metric、Alarmの関係を説明できる
- [ ] 初回は通知なしでAlarmを作成する理由を説明できる
- [ ] 変更手順、テスト方法、切り戻し手順を説明できる
- [ ] 検知時の一次調査項目を説明できる
- [ ] 設定変更を行っていないことを確認した
- [ ] 設計確認結果と要確認事項を報告文へ整理した

## Day 5の完了条件

次を自分の言葉で説明できればDay 5は完了とする。

```text
AWS Management Consoleへのログインは、
CloudTrailにConsoleLoginイベントとして記録される。

CloudTrailイベントをCloudWatch Logsへ配信し、
Metric FilterでConsoleLogin=SuccessかつMFAUsed=Noを検知する。

Metric Filterは検知件数をCustom Metricへ出力し、
CloudWatch AlarmがCustom Metricを評価して必要に応じて通知する。

検知後はCloudTrailでログイン主体、送信元IP、発生時刻、
ログイン後の操作を確認し、正当な作業か不正アクセスかを判断する。
```
