# 要件4.8 S3バケットポリシー変更監視 作業実施手順書 Webコンソール版

作成日: 2026-07-09

この手順書は、要件4.8「S3バケットポリシーの変更が監視されていること」について、AWS Management Consoleを使って監視設定を作成・確認するための作業実施手順である。

最初に共有された評価シート由来のテキスト情報を正とし、元要件では「CloudTrailをCloudWatchに連携し、メトリクスおよびアラーム設定で発報する」方針として扱う。
本手順では、CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、SNS等の通知先を使う。

## 1. 作業目的

S3バケットポリシー変更イベントをCloudTrailで記録し、CloudWatch LogsのMetric Filterで検知し、CloudWatch Alarmで通知する。

対象イベント:

| イベント名 | 意味 |
|---|---|
| `PutBucketPolicy` | S3バケットポリシーを作成または更新した |
| `DeleteBucketPolicy` | S3バケットポリシーを削除した |

## 2. 作業前提

| 項目 | 前提 |
|---|---|
| 作業方法 | AWS Management Console |
| 対象ログ | CloudTrail Management Event |
| 監視方式 | CloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> 通知 |
| 作業対象 | 承認された対象アカウント・対象リージョン |
| テスト | 可能であれば検証用S3バケットで実施 |

## 3. 作業前チェック

作業前に以下を確認する。

| No | チェック項目 | 確認 |
|---|---|---|
| 1 | 対象アカウント・対象リージョンが正しい | |
| 2 | 作業承認がある | |
| 3 | 変更対象のCloudTrail Log Groupが決まっている | |
| 4 | 既存Metric FilterやAlarmとの重複確認が済んでいる | |
| 5 | 通知先SNS Topicまたは通知経路が決まっている | |
| 6 | 通知テストの事前周知が済んでいる | |
| 7 | 戻し手順が確認済み | |

## 4. 命名例

現場の命名規則がある場合は、それを優先する。

| 種別 | 命名例 |
|---|---|
| Metric Filter名 | `S3BucketPolicyChange` |
| Metric Namespace | `Security/CloudTrail` |
| Metric Name | `S3BucketPolicyChangeCount` |
| Alarm名 | `S3BucketPolicyChangeDetected` |
| SNS Topic | 既存通知Topicを利用 |

注意:

- 本番では、必ず現場の命名規則に合わせる。
- 新規SNS Topicを作るか既存Topicを使うかは、事前に確認する。

## 5. CloudTrailとCloudWatch Logs連携を確認する

### 5.1 CloudTrail側確認

1. AWS Consoleの検索欄で `CloudTrail` を開く。
2. 左側メニューから `証跡` または `Trails` を開く。
3. 対象Trailを選択する。
4. `CloudWatch Logs` の設定を確認する。

確認する項目:

| 項目 | 確認内容 |
|---|---|
| CloudWatch Logs | Enabledか |
| Log Group | 対象Log Groupが設定されているか |
| IAM Role | CloudTrail配送用Roleが設定されているか |
| Management Event | Writeイベントが記録対象か |

### 5.2 未連携の場合

CloudWatch Logs連携がない場合は、4.8のMetric Filter/Alarm方式を実施できない。
この場合、次のいずれかを関係者へ確認する。

- CloudTrailをCloudWatch Logsへ連携する作業を今回含めるか
- 既存の別監視基盤で対応するか
- 4.8の作業を保留し、前提整備を別作業にするか

CloudTrailとCloudWatch Logsを新たに連携する場合は、影響範囲と権限が大きいため、別途承認を取得する。

## 6. Metric Filterを作成する

### 6.1 CloudWatch Logsを開く

1. AWS Consoleの検索欄で `CloudWatch` を開く。
2. 左側メニューから `ログ` -> `ロググループ` を開く。
3. CloudTrail連携先Log Groupを選択する。
4. `Metric filters` または `メトリクスフィルター` タブを開く。
5. `Create metric filter` または `メトリクスフィルターを作成` を選択する。

### 6.2 Filter Patternを入力する

Filter Patternには以下を入力する。

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

意味:

| 条件 | 意味 |
|---|---|
| `eventSource = s3.amazonaws.com` | S3のAPI操作である |
| `eventName = PutBucketPolicy` | バケットポリシー作成・更新 |
| `eventName = DeleteBucketPolicy` | バケットポリシー削除 |

### 6.3 Filter Patternをテストする

画面上でFilter Patternのテスト欄がある場合は、CloudTrailイベントのサンプルを使って一致確認する。

一致すべきサンプル:

```json
{
  "eventSource": "s3.amazonaws.com",
  "eventName": "PutBucketPolicy",
  "requestParameters": {
    "bucketName": "example-bucket"
  }
}
```

一致すべきサンプル:

```json
{
  "eventSource": "s3.amazonaws.com",
  "eventName": "DeleteBucketPolicy",
  "requestParameters": {
    "bucketName": "example-bucket"
  }
}
```

一致しないサンプル:

```json
{
  "eventSource": "s3.amazonaws.com",
  "eventName": "GetBucketPolicy",
  "requestParameters": {
    "bucketName": "example-bucket"
  }
}
```

### 6.4 Metricを設定する

Metric Filter作成画面で、以下を設定する。

| 項目 | 設定例 |
|---|---|
| Filter name | `S3BucketPolicyChange` |
| Metric namespace | `Security/CloudTrail` |
| Metric name | `S3BucketPolicyChangeCount` |
| Metric value | `1` |
| Default value | `0` |
| Unit | Count |

注意:

- Dimensionsを設定する場合、Default valueを設定できない場合がある。
- 最初の実装ではDimensionなしで作成するとシンプルである。
- 現場の命名規則がある場合は、上記の名称を置き換える。

### 6.5 作成後確認

Metric Filter作成後、以下を確認する。

| 確認項目 | 期待値 |
|---|---|
| Filter name | 作成した名称 |
| Filter pattern | S3のPutBucketPolicy/DeleteBucketPolicy条件 |
| Metric namespace | 設計どおり |
| Metric name | 設計どおり |

取得する証跡:

- Metric Filter一覧
- Metric Filter詳細

## 7. CloudWatch Alarmを作成する

### 7.1 Alarm作成画面を開く

1. CloudWatchの左側メニューから `アラーム` -> `すべてのアラーム` を開く。
2. `Create alarm` または `アラームの作成` を選択する。
3. `Select metric` を選択する。
4. 作成したMetric Namespaceを選択する。
5. 作成したMetric Nameを選択する。

### 7.2 Metric条件を設定する

設定例:

| 項目 | 設定例 |
|---|---|
| Statistic | Sum |
| Period | 5 minutes |
| Threshold type | Static |
| Condition | Greater/Equal |
| Threshold | 1 |
| Datapoints to alarm | 1 out of 1 |
| Missing data | Not breaching |

意味:

- 5分間に1回以上S3バケットポリシー変更があればALARMにする。
- データがない場合は正常扱いにする。

### 7.3 通知Actionを設定する

1. `Notification` または `通知` の設定画面を開く。
2. `In alarm` の通知Actionを設定する。
3. 既存SNS Topicを選択する。
4. 必要に応じて `OK` 戻り時の通知も設定する。

確認する項目:

| 項目 | 確認内容 |
|---|---|
| Alarm state trigger | In alarm |
| SNS Topic | 承認された通知先か |
| Actions enabled | 有効か |

注意:

- 新規SNS Topicを作る場合は、購読承認が必要になる。
- 通知先に個人情報が含まれる場合、証跡取得時に注意する。

### 7.4 Alarm名を設定して作成する

設定例:

| 項目 | 設定例 |
|---|---|
| Alarm name | `S3BucketPolicyChangeDetected` |
| Description | `Detects PutBucketPolicy and DeleteBucketPolicy events from CloudTrail logs.` |

作成後、Alarm一覧で以下を確認する。

| 確認項目 | 期待値 |
|---|---|
| Alarm名 | 作成した名称 |
| State | OK または INSUFFICIENT_DATA |
| Actions enabled | true |
| Metric | 作成したMetric |

取得する証跡:

- Alarm一覧
- Alarm詳細
- Alarm Action設定

## 8. テスト

テストは、可能であれば検証用S3バケットで実施する。
本番バケットでテストする場合は、必ず事前承認を取得する。

### 8.1 Metric Filter単体テスト

Metric Filter作成時のTest Patternで、以下を確認する。

| サンプル | 期待結果 |
|---|---|
| `PutBucketPolicy` | 一致する |
| `DeleteBucketPolicy` | 一致する |
| `GetBucketPolicy` | 一致しない |

### 8.2 実イベントテスト

承認された検証用S3バケットで以下を実施する。

1. S3 Consoleを開く。
2. 検証用S3バケットを選択する。
3. `Permissions` または `アクセス許可` を開く。
4. Bucket Policyを一時的に変更する。
5. 保存する。
6. 変更後、元のPolicyへ戻す。

発生する想定イベント:

```text
PutBucketPolicy
```

必要に応じて、Bucket Policy削除テストを実施する。
ただし削除テストは影響が大きいため、実施可否を事前確認する。

発生する想定イベント:

```text
DeleteBucketPolicy
```

### 8.3 CloudTrail配送待ち

CloudTrailからCloudWatch Logsへイベントが届くまで、数分待つ。

目安:

```text
5分〜15分程度
```

注意:

- 配送時間は保証されない。
- すぐにAlarmが変わらなくても、一定時間待ってから確認する。

### 8.4 Alarm確認

1. CloudWatchを開く。
2. `アラーム` -> `すべてのアラーム` を開く。
3. 作成したAlarmを選択する。
4. Stateが `ALARM` になるか確認する。
5. `History` または `履歴` を確認する。
6. 通知先に通知が届いたか確認する。

取得する証跡:

- CloudTrail Event Historyの該当イベント
- CloudWatch Logsの該当ログイベント
- Metric Filter一致結果
- Alarm状態
- Alarm履歴
- 通知受信結果

## 9. 作業後確認

| 確認項目 | 期待値 |
|---|---|
| Metric Filter | 作成済み |
| CloudWatch Metric | 発生確認済み |
| Alarm | 作成済み |
| Alarm Action | 有効 |
| 通知 | 受信確認済み |
| テスト用Policy | 元に戻っている |
| 証跡 | 保存済み |

## 10. 戻し手順

戻しが必要な場合は、以下を実施する。

### 10.1 Alarmを無効化または削除する

1. CloudWatchを開く。
2. `アラーム` -> `すべてのアラーム` を開く。
3. 対象Alarmを選択する。
4. 一時停止の場合はActionを無効化する。
5. 完全に戻す場合はAlarmを削除する。

### 10.2 Metric Filterを削除する

1. CloudWatch Logsの対象Log Groupを開く。
2. `Metric filters` を開く。
3. 対象Metric Filterを選択する。
4. 削除する。

### 10.3 テスト用S3 Bucket Policyを戻す

1. S3 Consoleを開く。
2. 検証用S3バケットを開く。
3. `Permissions` を開く。
4. Bucket Policyがテスト前の状態に戻っているか確認する。

注意:

- CloudTrail Trail、CloudWatch Logs Log Group、既存SNS Topicは、4.8用に新規作成していない限り削除しない。
- 既存通知先を削除しない。

## 11. 完了条件

作業完了条件は以下。

- `PutBucketPolicy` / `DeleteBucketPolicy` を検知するMetric Filterが作成されている
- Metric FilterからCloudWatch Metricが作成されている
- CloudWatch Alarmが作成されている
- Alarm Actionが有効である
- 通知先が確認できている
- テスト結果と証跡が保存されている
- 手順書、作業結果、戻し手順がレビュー可能な状態である

## 12. 注意点

- 元要件はCloudTrail、CloudWatch Logs、Metric Filter、Alarmによる発報である。
- EventBridgeは必須方式ではなく、既存監視の確認観点として扱う。
- 本番S3バケットのBucket Policy変更は影響が大きいため、検証用バケットでのテストを優先する。
- `DeleteBucketPolicy` の実イベントテストは影響が大きいため、原則として事前承認を必須とする。
- 通知テストは、運用担当へ事前周知する。
- Metric Filterは作成後のログイベントからMetricを発行する。過去ログには遡ってMetricを作成しない。

## 13. 参考

- AWS CloudTrail: Sending events to CloudWatch Logs
  - English: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html
- Amazon CloudWatch Logs: Creating metrics from log events using filters
  - English: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html
