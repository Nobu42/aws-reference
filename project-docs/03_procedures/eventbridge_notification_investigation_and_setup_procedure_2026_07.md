# EventBridge通知調査・設定手順書

作成日: 2026-07-15

この手順書は、クラウドセキュリティ対応の4番台要件において、既存EventBridge設定が本当に通知につながっているかを確認し、既存設定を流用する場合と新規作成する場合の進め方を整理するためのものである。

本手順はWebコンソール作業を前提とする。CLIは補助資料扱いとし、現場で許可された場合のみ使用する。

## 1. 目的

4番台の一部について、既存EventBridge Ruleが設定済みであることを確認している。

ただし、EventBridge Ruleが存在することと、実際にメール、Teams、監視基盤、チケットへ通知されていることは別である。

本調査では以下を確認する。

| 確認項目 | 目的 |
| :--- | :--- |
| EventBridge Ruleが何を検知しているか | 4番台要件と対応するか確認する |
| Ruleが有効か | 実際に動作する状態か確認する |
| Event Patternが正しいか | CloudTrailイベントを拾える条件か確認する |
| Targetが何か | SNS、Lambda、別アカウントEvent Busなど通知経路を確認する |
| Target呼び出し実績があるか | EventBridgeがTargetを呼んでいるか確認する |
| 最終通知先があるか | メール、Teams、監視基盤、チケットに届くか確認する |
| 既存設定を流用できるか | 新規作成が必要か判断する |

## 2. 基本構造

EventBridge通知は、以下の流れで確認する。

```text
CloudTrailイベント
  -> EventBridge Event Bus
  -> EventBridge Rule
  -> Target
  -> 最終通知先
```

Targetの種類によって、確認先が変わる。

| Target | 確認するもの |
| :--- | :--- |
| SNS Topic | Subscription、通知先、Confirmed状態 |
| Lambda | CloudWatch Logs、環境変数、送信先、エラー |
| SQS | キュー滞留、後続処理 |
| Step Functions | 実行履歴、失敗履歴 |
| 別アカウントEvent Bus | 受信側アカウントのRule、Target、通知先 |
| API Destination | 接続先、認証、実行履歴、失敗履歴 |
| CloudWatch Logs | ロググループへのイベント出力 |

重要:

- Ruleが存在しても、Targetがなければ通知されない。
- Targetが存在しても、SNS Subscriptionが未承認ならメール通知されない。
- Targetが別アカウントEvent Busの場合、送信元アカウントだけでは最終通知先まで確認できない。
- EventBridgeメトリクスは動作状況の確認に有効だが、最終通知到達の証明にはならない。

## 3. 今回の4番台で特に確認する対象

4番台は、CloudTrail管理イベントをもとに設定変更を検知する要件である。

| 要件番号 | 代表イベント |
| :--- | :--- |
| 4.1 | Unauthorized API Call系 |
| 4.2 | ConsoleLogin without MFA |
| 4.3 | root account use |
| 4.4 | IAM policy changes |
| 4.5 | CloudTrail changes |
| 4.6 | AWS Management Console authentication failures |
| 4.7 | DisableKey、ScheduleKeyDeletion |
| 4.8 | PutBucketPolicy、DeleteBucketPolicy |
| 4.9 | AWS Config changes |
| 4.10 | Security Group changes |
| 4.11 | Network ACL changes |
| 4.12 | Internet Gateway、Customer Gateway changes |
| 4.13 | Route Table changes |
| 4.14 | VPC、VPC Peering changes |
| 4.15 | AWS Organizations changes |

既存EventBridge Ruleがこれらをどこまでカバーしているかを確認する。

## 4. 調査前に確認すること

| 確認事項 | 理由 |
| :--- | :--- |
| 対象アカウント | EventBridge Ruleはアカウント単位で存在するため |
| 対象リージョン | Ruleはリージョン単位で存在するため |
| 対象Event Bus | defaultか、カスタムEvent Busかを確認するため |
| 既存通知先 | メール、Teams、監視基盤、チケットの有無を確認するため |
| 既存設定の管理者 | インフラチーム、監視チーム、Terraform管理かを確認するため |
| 設計書記載有無 | 設計書にない設定を勝手に変更しないため |
| 変更可否 | 既存Ruleの編集、Target追加、新規Rule作成の可否を確認するため |

## 5. リーダー・PMへの確認文案

### 5.1 調査開始前

```text
4番台の一部について、既存EventBridge Ruleが設定済みであることを確認済み。

ただし、現時点ではTargetの先で実際にメール、Teams、監視基盤、チケットへ通知されているかまでは未確認。

本日は、既存RuleのEvent Pattern、Target、Target先の通知経路、CloudWatchメトリクス、必要に応じて受信側アカウントを確認し、既存設定を流用できるか、新規作成が必要か整理する。
```

### 5.2 別アカウントEvent BusがTargetの場合

```text
対象EventBridge RuleのTargetが別アカウントEvent Busになっているものがある。

送信元アカウントではEventBridgeから別アカウントへ送っているところまでは確認できるが、
受信側アカウントでどのRuleが拾い、最終的にどこへ通知しているかは追加確認が必要である。

受信側アカウントのRule、Target、通知先をインフラチームまたは監視基盤側に確認する。
```

### 5.3 既存設定を流用したい場合

```text
既存EventBridge Ruleで4番台要件の一部を検知していることを確認済み。

既存経路が通知まで到達していることを確認できれば、同じ方式を流用し、不足しているイベントのみ追加または別Ruleで補完する方針が妥当である。

既存Ruleを編集してよいか、新規Ruleで追加するべきか、管理方針を確認する。
```

## 6. 既存EventBridge Ruleの調査手順

### 6.1 Rule一覧を確認する

1. AWSマネジメントコンソールで対象アカウントにログインする
2. 対象リージョンを選択する
3. Amazon EventBridgeを開く
4. 「ルール」を開く
5. Event Busを確認する
6. 4番台に関係しそうなRuleを抽出する

検索候補:

| 検索語 | 見つけたいRule |
| :--- | :--- |
| `cloudtrail` | CloudTrailイベント監視 |
| `security` | セキュリティ通知 |
| `iam` | IAM変更監視 |
| `s3` | S3変更監視 |
| `bucket` | S3バケット変更監視 |
| `config` | AWS Config変更監視 |
| `vpc` | VPC変更監視 |
| `route` | Route Table変更監視 |
| `acl` | Network ACL変更監視 |
| `organization` | Organizations変更監視 |

記録する項目:

| 項目 | 内容 |
| :--- | :--- |
| Rule名 | 既存Ruleの名前 |
| Event Bus | default / custom |
| 状態 | Enabled / Disabled |
| 説明 | Rule説明欄 |
| タグ | 管理者や用途の推定 |
| 作成・更新情報 | 画面で確認できる範囲 |

### 6.2 Event Patternを確認する

対象Ruleを開き、Event Patternを確認する。

4.8の代表例:

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

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| source | AWSサービスが一致しているか |
| detail-type | CloudTrail API Callを対象にしているか |
| detail.eventSource | 対象サービスのイベントか |
| detail.eventName | 要件の対象イベント名が含まれているか |
| account | 特定アカウントに絞っているか |
| region | 特定リージョンに絞っているか |
| resource条件 | 特定リソースに絞っているか |

注意:

- 条件が広すぎる場合、不要な通知が増える。
- 条件が狭すぎる場合、要件対象の変更を拾えない。
- 既存Ruleを編集する場合、他要件や他チーム通知へ影響する可能性がある。

### 6.3 Targetを確認する

Rule詳細でTargetを確認する。

記録する項目:

| 項目 | 内容 |
| :--- | :--- |
| Target type | SNS、Lambda、Event Busなど |
| Target ARN | 宛先リソース |
| Target ID | Target識別子 |
| Input | イベント全体、固定文字列、入力変換 |
| Input transformer | 通知本文を加工しているか |
| Retry policy | 再試行設定 |
| Dead-letter queue | 失敗時の退避先 |
| Role ARN | Target呼び出しに使うIAM Role |

判断:

| 状態 | 判断 |
| :--- | :--- |
| Targetなし | 通知はされない |
| SNS Topic | SNS Subscription確認へ進む |
| Lambda | Lambda実行ログ確認へ進む |
| 別アカウントEvent Bus | 受信側アカウント確認が必要 |
| SQS / Step Functions | 後続処理の確認が必要 |
| CloudWatch Logs | ログ出力であり通知ではない可能性がある |

## 7. 本当に通知しているか確認する方法

### 7.1 確認レベル

通知確認は、以下の段階に分ける。

| レベル | 確認できること | 通知済みと言えるか |
| :--- | :--- | :--- |
| 1 | RuleがEnabled | 言えない |
| 2 | Event Patternが対象イベントに一致 | 言えない |
| 3 | Targetが設定されている | 言えない |
| 4 | EventBridgeメトリクスでTarget呼び出しあり | まだ不十分 |
| 5 | SNS/Lambda/受信側Event Busで処理あり | かなり強い |
| 6 | メール/Teams/チケットなど最終通知の到達確認あり | 通知済みと言える |

結論:

```text
EventBridge Rule + Target + メトリクスだけでは、最終通知到達の証明にはならない。
最終通知先または受信側処理ログまで確認する。
```

### 7.2 CloudWatchメトリクスを確認する

EventBridgeは、RuleやTarget呼び出しに関するメトリクスをCloudWatchへ送る。

確認するメトリクス:

| メトリクス | 意味 |
| :--- | :--- |
| MatchedEvents | イベントがRuleに一致した数 |
| TriggeredRules | Ruleが実行され、一致した数 |
| Invocations | TargetがRuleにより呼び出された数 |
| FailedInvocations | Target呼び出しが完全に失敗した数 |
| InvocationAttempts | Target呼び出し試行回数 |
| SuccessfulInvocationAttempts | Target呼び出し成功回数 |
| RetryInvocationAttempts | Target呼び出し再試行回数 |
| InvocationsSentToDlq | DLQへ送られた呼び出し数 |
| DeadLetterInvocations | Targetが呼び出されなかった数 |

Webコンソール確認手順:

1. CloudWatchを開く
2. メトリクスを開く
3. `AWS/Events` を選択する
4. `RuleName` または `EventBusName, RuleName` のディメンションを選択する
5. 対象Rule名で絞る
6. `MatchedEvents`、`Invocations`、`FailedInvocations` を確認する

判断:

| 状態 | 意味 |
| :--- | :--- |
| MatchedEventsが0 | 対象イベントが発生していない、またはPatternが一致していない |
| MatchedEventsあり、Invocationsなし | Target設定やRule状態を確認 |
| Invocationsあり、FailedInvocationsなし | EventBridgeからTarget呼び出しは成功している可能性が高い |
| FailedInvocationsあり | Target権限、削除済みTarget、KMS、DLQ、Roleを確認 |
| DLQ関連メトリクスあり | 失敗イベントが退避されている可能性がある |

注意:

- CloudWatchメトリクスはベストエフォートであり、完全な操作履歴ではない。
- EventBridgeからTargetが呼ばれていても、メールやTeamsに届いたとは限らない。

### 7.3 SNS Targetの場合

TargetがSNS Topicの場合、SNS側を確認する。

確認手順:

1. SNSを開く
2. 対象Topicを開く
3. Subscriptionsを確認する
4. Protocol、Endpoint、Statusを確認する

記録する項目:

| 項目 | 内容 |
| :--- | :--- |
| Topic名 | 通知Topic |
| Topic ARN | Target ARNと一致するか |
| Protocol | email、https、lambda、sqsなど |
| Endpoint | メールアドレス、Webhook、Lambda、SQS |
| Status | Confirmed / Pending confirmation |
| 暗号化 | KMS利用有無 |
| Access policy | EventBridgeからPublish可能か |

判断:

| 状態 | 判断 |
| :--- | :--- |
| Subscriptionなし | 最終通知先がない |
| Pending confirmation | メール通知は未成立 |
| Confirmed email | メール通知先として成立 |
| https endpoint | Teams Webhookや中継APIの可能性 |
| lambda/sqs | 後続処理を追加確認 |

### 7.4 Lambda Targetの場合

TargetがLambdaの場合、Lambdaの中身と実行ログを確認する。

確認手順:

1. Lambdaを開く
2. 対象関数を開く
3. トリガーにEventBridge Ruleがあるか確認する
4. コード、環境変数、送信先を確認する
5. CloudWatch Logsを開く
6. 直近の実行ログ、エラー、外部送信結果を確認する

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| トリガー | EventBridge Ruleと接続しているか |
| 環境変数 | Webhook URL、通知先、チャンネル名の有無 |
| コード概要 | Teams、メール、チケットAPIへ送っているか |
| CloudWatch Logs | 実行成功、失敗、送信結果 |
| エラー | 権限、外部API失敗、タイムアウト |
| Dead-letter / Destination | 失敗時の退避先 |

判断:

- Lambdaログに通知送信成功が残っている場合、通知経路としてかなり強い根拠となる。
- Lambdaが別SNSや別Event Busへ渡している場合、さらに先を確認する。

### 7.5 別アカウントEvent Bus Targetの場合

Targetが別アカウントEvent Busの場合、送信元だけでは最終通知を確認できない。

確認すること:

| 確認先 | 内容 |
| :--- | :--- |
| 送信元Rule | Event Pattern、Target ARN、Invocations |
| 送信先Event Bus | 受信許可、Event Bus Policy |
| 受信側Rule | どのRuleが受信イベントを拾うか |
| 受信側Target | SNS、Lambda、監視基盤、チケットなど |
| 最終通知先 | メール、Teams、監視基盤 |

確認依頼文:

```text
送信元アカウントのEventBridge Ruleで、Targetが別アカウントEvent Busになっていることを確認済み。

送信元ではEventBridgeからTargetを呼び出しているところまでは確認できるが、
受信側アカウントでどのRuleが拾い、最終的にどこへ通知しているかは確認できない。

受信側Event Bus、Rule、Target、通知先の確認を依頼する。
```

### 7.6 CloudTrailで設定変更履歴を確認する

EventBridge設定変更はCloudTrailで追跡できる。

確認イベント:

| イベント名 | 意味 |
| :--- | :--- |
| PutRule | Rule作成・更新 |
| DeleteRule | Rule削除 |
| EnableRule | Rule有効化 |
| DisableRule | Rule無効化 |
| PutTargets | Target追加・更新 |
| RemoveTargets | Target削除 |
| PutPermission | Event Bus権限追加 |
| RemovePermission | Event Bus権限削除 |

確認目的:

- 誰がいつ設定したか
- 設計書にない設定がいつ作られたか
- Terraformや手作業のどちらか推定できるか
- 直近で無効化やTarget削除がないか

## 8. 既存設定を使う場合

既存EventBridge Ruleを使える条件:

| 条件 | 内容 |
| :--- | :--- |
| Event Patternが要件に一致 | 対象イベントを拾える |
| RuleがEnabled | 現在動作している |
| Targetがある | 通知または後続処理へつながる |
| Target呼び出し実績がある | EventBridgeからTargetへ送られている |
| 最終通知先が確認できる | メール、Teams、監視基盤など |
| 管理者が明確 | 変更可否を判断できる |
| 設計書差分の扱いが明確 | 既存設定として扱える |

既存設定を流用する場合の作業:

1. 既存Ruleの対象イベントを整理する
2. 4番台要件との対応表を作る
3. 不足イベントを洗い出す
4. 既存Ruleへイベントを追加できるか確認する
5. 既存Ruleを編集せず、新規Ruleで補完するか判断する
6. 通知到達確認を行う
7. 手順書とエビデンスに反映する

既存Ruleを編集する前の確認:

| 確認事項 | 理由 |
| :--- | :--- |
| Terraform管理か | 手作業編集すると差分が戻される可能性 |
| 他用途で使っていないか | 通知増加や誤通知の影響 |
| Target先の運用責任者 | 通知先の承認が必要 |
| テスト可能か | 本番イベントを発生させる場合の承認 |
| 変更後の切り戻し | Event PatternやTargetを戻せるか |

## 9. 新規作成する場合

既存設定が使えない場合、新規Ruleを作成する。

### 9.1 新規作成が必要なケース

| ケース | 理由 |
| :--- | :--- |
| 対象イベントを拾うRuleがない | 新規検知が必要 |
| 既存Ruleの管理者が別チーム | 既存設定を触れない |
| 既存Ruleの通知先が不明 | 運用に使えない |
| 既存RuleのTargetが別アカウントで確認不能 | 最終通知を保証できない |
| 既存RuleがDisabled | 現行運用で使っていない可能性 |
| 既存通知が要件と粒度不一致 | 監査要件に合わせた通知が必要 |

### 9.2 新規Rule作成の流れ

```text
対象イベント確定
  -> Event Pattern作成
  -> Event Bus選択
  -> Rule作成
  -> Target選択
  -> Input Transformer設定
  -> Retry / DLQ設定
  -> 通知先確認
  -> テスト
  -> エビデンス取得
```

### 9.3 4.8用Event Pattern例

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

対象バケットまで絞る場合は、CloudTrailイベントの実データを確認して、`requestParameters.bucketName` などの条件が使えるか判断する。

例:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutBucketPolicy", "DeleteBucketPolicy"],
    "requestParameters": {
      "bucketName": ["対象バケット名"]
    }
  }
}
```

注意:

- 本番で使うEvent Patternは、実際のCloudTrailイベントJSONと照合する。
- いきなり広い条件で有効化すると通知量が増える。
- 複数バケット対象の場合、対象一覧の管理方法を決める。

### 9.4 TargetをSNSにする場合

構成:

```text
EventBridge Rule
  -> SNS Topic
  -> email / https / Lambda / SQS
```

設定項目:

| 項目 | 内容 |
| :--- | :--- |
| SNS Topic名 | 命名規則に合わせる |
| Subscription | メール、Teams中継、Lambdaなど |
| Topic Policy | EventBridgeからPublishできるか |
| KMS | 暗号化Topicの場合、EventBridgeから利用可能か |
| Input Transformer | 通知本文を読みやすくする |

### 9.5 TargetをLambdaにする場合

構成:

```text
EventBridge Rule
  -> Lambda
  -> Teams / メール / チケット / 監視基盤
```

注意:

- Lambdaのコード、環境変数、外部送信先の管理が必要となる。
- Lambdaの実行ロール、ログ、エラー処理、リトライを確認する。
- Teamsや外部APIを呼ぶ場合、認証情報の管理方法を確認する。

### 9.6 Targetを別アカウントEvent Busにする場合

構成:

```text
送信元アカウント EventBridge Rule
  -> 別アカウント Event Bus
  -> 受信側Rule
  -> 受信側Target
```

確認事項:

| 項目 | 内容 |
| :--- | :--- |
| 送信先アカウントID | どの監視アカウントへ送るか |
| 送信先Event Bus名 | defaultかカスタムか |
| Event Bus Policy | 送信元アカウントを許可しているか |
| 受信側Rule | 受信イベントを拾うRule |
| 受信側Target | 最終通知先 |
| 責任分界点 | どこまでが今回作業範囲か |

## 10. Input Transformerの確認

Input Transformerは、Targetへ渡す通知本文を加工する機能である。

確認する理由:

- 通知文にアカウント、リージョン、イベント名、対象リソースが含まれているか
- Teamsやメールで読める形式になっているか
- 必要な情報が欠落していないか

4.8で最低限入れたい情報:

| 項目 | 例 |
| :--- | :--- |
| eventName | PutBucketPolicy |
| eventTime | CloudTrail上のイベント時刻 |
| userIdentity.arn | 実行者 |
| sourceIPAddress | 実行元IP |
| awsRegion | リージョン |
| requestParameters.bucketName | 対象バケット |
| account | アカウントID |

## 11. テスト方法

### 11.1 最小テスト

既存イベント履歴とメトリクスを確認する。

```text
過去に対象イベントが発生
  -> EventBridge RuleにMatchedEventsあり
  -> Invocationsあり
  -> FailedInvocationsなし
  -> Target先で処理履歴あり
```

この方法は影響が少ないが、最終通知到達まで確認できない場合がある。

### 11.2 通知到達テスト

承認を取ったうえで、対象イベントを実際に発生させる。

4.8の例:

```text
承認済みのS3バケットでBucket Policyを軽微変更
  -> PutBucketPolicy発生
  -> EventBridge Rule一致
  -> Target呼び出し
  -> メール/Teams/監視基盤で通知確認
  -> 必要なら元へ戻す
```

注意:

- 本番環境では必ず作業承認、時間帯、切り戻し方法を確認する。
- 実業務影響のないテスト方法を選ぶ。
- 既存通知先へ不要なアラートを飛ばす場合、事前連絡する。

### 11.3 テストイベントの扱い

EventBridgeにはパターン検証やテストイベント投入の方法があるが、現場では本番イベントと同じ経路で通知されるかが重要である。

判断:

| テスト方法 | 確認できること | 限界 |
| :--- | :--- | :--- |
| Event Patternテスト | Patternに一致するか | 通知到達は確認できない |
| 過去メトリクス確認 | Rule/Target動作の可能性 | 最終通知到達は弱い |
| 実イベント発生 | 実際の通知経路を確認できる | 承認と切り戻しが必要 |

## 12. エビデンス取得

取得するスクリーンショット:

| No. | 画面 | 目的 |
| :--- | :--- | :--- |
| 1 | EventBridge Rule一覧 | 対象Ruleの存在確認 |
| 2 | Rule詳細 | Enabled状態、Event Bus |
| 3 | Event Pattern | 対象イベント条件 |
| 4 | Target一覧 | 通知先または後続処理 |
| 5 | Input Transformer | 通知本文 |
| 6 | Retry / DLQ設定 | 失敗時の扱い |
| 7 | CloudWatch Metrics | MatchedEvents、Invocations、FailedInvocations |
| 8 | SNS Subscription | 最終通知先 |
| 9 | Lambda Logs | 実行結果 |
| 10 | 別アカウント確認結果 | 受信側通知経路 |
| 11 | 実通知画面 | メール、Teams、チケット |

ファイル名例:

```text
EventBridge_01_Rule一覧.png
EventBridge_02_Rule詳細_4_8.png
EventBridge_03_EventPattern_4_8.png
EventBridge_04_Target_4_8.png
EventBridge_05_CloudWatchMetrics_4_8.png
EventBridge_06_SNS_Subscription.png
EventBridge_07_Teams通知到達.png
```

## 13. 調査結果のまとめ方

| 項目 | 記載内容 |
| :--- | :--- |
| 要件番号 | 4.8など |
| 対象イベント | PutBucketPolicy、DeleteBucketPolicyなど |
| 既存Rule | あり / なし |
| Rule状態 | Enabled / Disabled |
| Event Pattern一致 | 要件に一致 / 一部不足 / 不一致 |
| Target | SNS / Lambda / Event Busなど |
| Target呼び出し実績 | あり / なし / 未確認 |
| 最終通知先 | メール / Teams / 監視基盤 / 不明 |
| 通知到達確認 | 確認済み / 未確認 |
| 流用可否 | 流用可 / 補完必要 / 新規作成 |
| 確認事項 | インフラチーム、監視チーム、PMへの確認 |

## 14. 判断基準

| 状態 | 判断 |
| :--- | :--- |
| 既存Ruleあり、通知到達確認済み | 既存設定を流用できる可能性が高い |
| 既存Ruleあり、Target呼び出しのみ確認 | Target先の通知確認が必要 |
| 既存Ruleあり、Targetが別アカウントEvent Bus | 受信側アカウント確認が必要 |
| 既存Ruleあり、Targetなし | 通知設定としては未完成 |
| 既存Ruleあり、Disabled | 現行運用で使っていない可能性 |
| 既存Ruleなし | 新規Rule作成を検討 |
| 既存Ruleの対象イベントが不足 | 既存Rule編集または補完Rule作成を検討 |

## 15. 現場向け報告文例

### 15.1 既存Ruleが通知まで確認できた場合

```text
4番台の対象イベントについて、既存EventBridge Ruleが存在し、Target経由で通知先まで到達していることを確認済み。

既存設定を流用できる可能性が高いため、不足イベントの有無を整理し、追加が必要なものだけ補完する方針で進める。
```

### 15.2 Targetまでは確認できたが通知先が不明な場合

```text
既存EventBridge RuleとTargetは確認済み。ただし、Targetの先で実際にメール、Teams、監視基盤へ通知されているかは未確認。

次にSNS Subscription、Lambdaログ、または別アカウントEvent Busの受信側Ruleを確認し、既存経路を流用できるか判断する。
```

### 15.3 新規作成が必要な場合

```text
対象イベントを拾う既存EventBridge Rule、または通知まで到達する既存経路は確認できなかった。

そのため、対象イベント用のEventBridge Ruleを新規作成し、承認済み通知先へ連携する方針で設計する。
```

## 16. 参照資料

| 資料 | 用途 |
| :--- | :--- |
| [AWS公式ドキュメント EventBridge要約](../04_references/aws_official_docs_eventbridge_summary.md) | EventBridgeの基本、Rule、Target、通知連携 |
| [通知設計・通知先一覧・通知テスト手順](./notification_design_and_test_plan_2026_07.md) | 通知先、通知テスト、証跡 |
| [要件4番台 監視設定値一覧 設計パラメータ案](./requirements_4_x_monitoring_parameter_design_2026_07.md) | 4番台イベント名と監視設定 |
| [要件4番台 Webコンソール作業実施手順書](./requirements_4_x_web_console_work_procedure_2026_07.md) | 4番台横展開作業 |

公式ドキュメント:

| 分類 | URL |
| :--- | :--- |
| EventBridgeモニタリング | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-monitoring.html |
| EventBridge Target | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-targets.html |
| EventBridge Rule | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-rules.html |
| Input Transformer | https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-transform-target-input.html |
