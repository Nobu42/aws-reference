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

## 5. パラメータシートで確認すること

設計書本文にEventBridgeの記載がない場合でも、パラメータシートに設定値として記載されている可能性がある。

パラメータシートに記載がある場合、実環境だけに存在する未整理設定ではなく、設定管理上は把握されている既存設定として扱える可能性がある。

### 5.1 パラメータシート確認の目的

| 確認目的 | 内容 |
| :--- | :--- |
| 既存設定の管理有無 | EventBridge Ruleが管理対象として記載されているか |
| 設定値の正当性 | 実環境のRule、Target、Event Patternがパラメータシートと一致するか |
| 送信先の把握 | Targetが別アカウントEvent Busの場合、送信先アカウントや用途が分かるか |
| 管理者の把握 | インフラチーム、監視チーム、Terraform管理などの責任範囲が分かるか |
| 通知経路の確認 | メール、Teams、監視基盤、チケット連携の記載があるか |
| 設計書差分の整理 | 設計書本文にないが、パラメータシートにはある設定として扱えるか |

### 5.2 パラメータシートで見る項目

| 項目 | 確認内容 |
| :--- | :--- |
| EventBridge Rule名 | 実環境のRule名と一致するか |
| Event Bus名 | defaultか、カスタムEvent Busか |
| Rule状態 | Enabled / Disabled |
| Event Pattern | 4番台要件の対象イベントを拾う条件か |
| 対象イベント名 | PutBucketPolicy、DeleteBucketPolicyなど |
| Target種別 | SNS、Lambda、別アカウントEvent Busなど |
| Target ARN | 実環境のTarget ARNと一致するか |
| 送信先アカウントID | 別アカウントEvent Busの場合に確認する |
| 送信先アカウント名 / 用途 | 監視アカウント、ログ集約アカウント、セキュリティアカウントなど |
| IAM Role | EventBridgeがTargetを呼び出すRole |
| Retry Policy | 再試行設定 |
| Dead-letter Queue | 失敗時の退避先 |
| Input Transformer | 通知本文や連携イベントの整形有無 |
| 通知先 | メール、Teams、監視基盤、チケットなど |
| 管理方法 | Terraform、CloudFormation、手動など |
| 管理チーム | インフラチーム、監視チーム、運用チームなど |
| 備考 | 設計意図、例外、確認事項 |

### 5.3 パラメータシート確認後の判断

| 状態 | 判断 |
| :--- | :--- |
| 設計書にもパラメータシートにも記載なし | 実環境だけに存在する未整理設定。要確認度が高い |
| 設計書にはないがパラメータシートに記載あり | 設定値としては管理済みの可能性。通知到達と運用資料を確認 |
| 設計書にもパラメータシートにも記載あり | 正式な設計・管理対象の可能性が高い |
| 設計書に記載あり、パラメータシートに記載なし | 設計記載と設定管理の差分として確認 |
| パラメータシートのTargetと実環境が不一致 | 設定変更漏れ、資料未更新、別環境差分の可能性 |
| 送信先アカウントは記載あり、通知先は未記載 | 受信側アカウントまたは監視基盤側の確認が必要 |

### 5.4 パラメータシート確認時のメモ例

```text
EventBridge Rule名:
Event Bus:
Rule状態:
Event Pattern:
Target種別:
Target ARN:
送信先アカウント:
通知先:
管理方法:
管理チーム:
設計書記載:
パラメータシート記載:
実環境との差分:
確認事項:
```

### 5.5 PM・リーダーへの共有文案

```text
設計書本文にはEventBridge設定の記載を確認できていないが、パラメータシートに記載がある可能性があるため確認する。

パラメータシートにRule名、Event Pattern、Target、送信先アカウント、用途が記載されていれば、既存管理対象として扱い、通知到達確認や受信側確認に進む。

記載がない場合は、設計書・パラメータシート外の実環境差分として整理する。
```

## 6. リーダー・PMへの確認文案

### 6.1 調査開始前

```text
4番台の一部について、既存EventBridge Ruleが設定済みであることを確認済み。

ただし、現時点ではTargetの先で実際にメール、Teams、監視基盤、チケットへ通知されているかまでは未確認。

本日は、既存RuleのEvent Pattern、Target、Target先の通知経路、CloudWatchメトリクス、必要に応じて受信側アカウントを確認し、既存設定を流用できるか、新規作成が必要か整理する。
```

### 6.2 別アカウントEvent BusがTargetの場合

```text
対象EventBridge RuleのTargetが別アカウントEvent Busになっているものがある。

送信元アカウントではEventBridgeから別アカウントへ送っているところまでは確認できるが、
受信側アカウントでどのRuleが拾い、最終的にどこへ通知しているかは追加確認が必要である。

受信側アカウントのRule、Target、通知先をインフラチームまたは監視基盤側に確認する。
```

### 6.3 既存設定を流用したい場合

```text
既存EventBridge Ruleで4番台要件の一部を検知していることを確認済み。

既存経路が通知まで到達していることを確認できれば、同じ方式を流用し、不足しているイベントのみ追加または別Ruleで補完する方針が妥当である。

既存Ruleを編集してよいか、新規Ruleで追加するべきか、管理方針を確認する。
```

## 7. 既存EventBridge Ruleの調査手順

### 7.1 Rule一覧を確認する

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

### 7.2 Event Patternを確認する

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

### 7.3 Targetを確認する

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

## 8. 本当に通知しているか確認する方法

### 8.1 確認レベル

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

### 8.2 CloudWatchメトリクスを確認する

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

### 8.3 SNS Targetの場合

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

### 8.4 Lambda Targetの場合

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

### 8.5 別アカウントEvent Bus Targetの場合

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

### 8.6 権限不足で確認できない場合

EventBridge通知調査では、付与されたAWSアカウント権限や担当範囲によって、確認できる範囲が途中で止まることがある。

これは調査漏れではなく、アカウント境界、権限境界、運用責任分界点による制約として扱う。

権限不足で詰まりやすい箇所:

| 確認対象 | 必要になりやすい権限 | 権限不足時に起きること |
| :--- | :--- | :--- |
| EventBridge Rule一覧 | EventBridge閲覧権限 | Rule一覧が確認できない |
| Rule詳細 | EventBridge閲覧権限 | Event Patternや状態が確認できない |
| Target一覧 | EventBridge Target閲覧権限 | SNS、Lambda、別アカウントEvent Busなどの宛先が確認できない |
| Event Bus Policy | EventBridge Event Bus閲覧権限 | 別アカウント連携の許可状態が確認できない |
| CloudWatch Metrics | CloudWatch Metrics閲覧権限 | Rule発火、Target呼び出し、失敗有無が確認できない |
| SNS Topic | SNS閲覧権限 | Topic属性やSubscriptionが確認できない |
| Lambda | Lambda閲覧権限 | 通知処理内容やトリガーが確認できない |
| Lambda Logs | CloudWatch Logs閲覧権限 | 実行成功、失敗、通知送信結果が確認できない |
| SQS / DLQ | SQS閲覧権限 | 失敗イベントの退避状況が確認できない |
| IAM Role | IAM閲覧権限 | EventBridgeがTargetを呼ぶためのRoleが確認できない |
| CloudTrail | CloudTrail閲覧権限 | RuleやTargetを誰がいつ変更したか確認できない |
| 別アカウントEvent Bus受信側 | 受信側アカウント権限 | 受信側Rule、Target、最終通知先が確認できない |

権限不足時の整理方法:

| 区分 | 記載例 |
| :--- | :--- |
| 確認済み | 送信元EventBridge Rule、Event Pattern、Target ARNまでは確認済み |
| 一部確認 | CloudWatch MetricsでTarget呼び出し有無までは確認済み |
| 未確認 | 受信側Event Bus、受信側Rule、最終通知先は権限不足により未確認 |
| 追加確認先 | インフラチーム、監視基盤担当、受信側アカウント管理者 |
| 判断 | 通知到達確認は未完了。受信側確認後に流用可否を判断 |

報告文例:

```text
現アカウントの権限では、EventBridge Rule、Event Pattern、Targetまでは確認済み。

ただし、Targetが別アカウントEvent Busになっているため、受信側アカウントでどのRuleが拾い、最終的にメール、Teams、監視基盤、チケットへ通知しているかは確認できない。

通知到達確認のため、受信側アカウントのEventBridge Rule、Target、SNS/Lambda/Teams等の通知経路確認が必要である。
```

この場合の結論は、以下のように表現する。

```text
送信元からTargetまでの設定は確認済み。
最終通知先は権限境界により未確認。
既存設定の流用可否は、受信側確認後に判断する。
```

### 8.7 CloudTrailで設定変更履歴を確認する

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

## 9. 既存設定を使う場合

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

## 10. 新規作成する場合

既存設定が使えない場合、新規Ruleを作成する。

### 10.1 新規作成が必要なケース

| ケース | 理由 |
| :--- | :--- |
| 対象イベントを拾うRuleがない | 新規検知が必要 |
| 既存Ruleの管理者が別チーム | 既存設定を触れない |
| 既存Ruleの通知先が不明 | 運用に使えない |
| 既存RuleのTargetが別アカウントで確認不能 | 最終通知を保証できない |
| 既存RuleがDisabled | 現行運用で使っていない可能性 |
| 既存通知が要件と粒度不一致 | 監査要件に合わせた通知が必要 |

### 10.2 新規Rule作成の流れ

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

### 10.3 4.8用Event Pattern例

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

### 10.4 TargetをSNSにする場合

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

### 10.5 TargetをLambdaにする場合

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

### 10.6 Targetを別アカウントEvent Busにする場合

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

## 11. Input Transformerの確認

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

## 12. テスト方法

### 12.1 最小テスト

既存イベント履歴とメトリクスを確認する。

```text
過去に対象イベントが発生
  -> EventBridge RuleにMatchedEventsあり
  -> Invocationsあり
  -> FailedInvocationsなし
  -> Target先で処理履歴あり
```

この方法は影響が少ないが、最終通知到達まで確認できない場合がある。

### 12.2 通知到達テスト

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

### 12.3 テストイベントの扱い

EventBridgeにはパターン検証やテストイベント投入の方法があるが、現場では本番イベントと同じ経路で通知されるかが重要である。

判断:

| テスト方法 | 確認できること | 限界 |
| :--- | :--- | :--- |
| Event Patternテスト | Patternに一致するか | 通知到達は確認できない |
| 過去メトリクス確認 | Rule/Target動作の可能性 | 最終通知到達は弱い |
| 実イベント発生 | 実際の通知経路を確認できる | 承認と切り戻しが必要 |

## 13. エビデンス取得

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

## 14. 調査結果のまとめ方

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

## 15. 判断基準

| 状態 | 判断 |
| :--- | :--- |
| 既存Ruleあり、通知到達確認済み | 既存設定を流用できる可能性が高い |
| 既存Ruleあり、Target呼び出しのみ確認 | Target先の通知確認が必要 |
| 既存Ruleあり、Targetが別アカウントEvent Bus | 受信側アカウント確認が必要 |
| 既存Ruleあり、Targetなし | 通知設定としては未完成 |
| 既存Ruleあり、Disabled | 現行運用で使っていない可能性 |
| 既存Ruleなし | 新規Rule作成を検討 |
| 既存Ruleの対象イベントが不足 | 既存Rule編集または補完Rule作成を検討 |

## 16. EventBridgeを使わず当初案で進める場合

既存EventBridge Ruleの調査が行き詰まる場合、EventBridgeを流用せず、当初案で進める選択肢がある。

当初案:

```text
CloudTrail
  -> CloudWatch Logs
  -> Metric Filter
  -> CloudWatch Alarm
  -> SNS / Teams / メール
```

この構成は、今回対応範囲内で検知条件、アラーム、通知先、テスト、エビデンスを整理しやすい。

### 16.1 当初案を選ぶ判断条件

| 状態 | 判断 |
| :--- | :--- |
| EventBridge Targetが別アカウントEvent Bus | 受信側確認ができない場合、当初案を検討 |
| 受信側Ruleが確認できない | 最終通知先を説明できないため、当初案を検討 |
| 通知到達が確認できない | 監査・レビュー用証跡が弱いため、当初案を検討 |
| 既存Ruleの管理者が不明 | 変更影響を判断できないため、当初案を検討 |
| 既存Ruleが設計書未記載 | 既存設定の目的確認が必要。流用不可なら当初案 |
| 既存Ruleの編集が許可されない | 新規でCloudWatch Alarm系を作る方が安全 |
| 4番台全体で統一した通知設計にしたい | 当初案の方が横展開しやすい |

### 16.2 当初案の利点

| 利点 | 内容 |
| :--- | :--- |
| 説明しやすい | CloudTrailログからMetric Filter、Alarm、通知まで1本の流れで説明できる |
| 証跡を残しやすい | Filter、Alarm、通知テスト、スクリーンショットを取得しやすい |
| 作業範囲を管理しやすい | 受信側別アカウントの設定に依存しない |
| 横展開しやすい | 4.1から4.15のイベント監視に同じ構成を使える |
| 通知到達を確認しやすい | SNSやTeamsの到達確認を今回のテスト範囲に含めやすい |
| 切り戻ししやすい | 作成したMetric Filter、Alarm、SNS連携を戻す範囲が明確 |

### 16.3 当初案の注意点

| 注意点 | 内容 |
| :--- | :--- |
| 二重通知 | 既存EventBridge通知が生きている場合、重複通知になる可能性がある |
| CloudTrail to CloudWatch Logs連携 | CloudTrailがCloudWatch Logsへ配信されている必要がある |
| Metric Filter設計 | 対象イベント名、エラー条件、除外条件を正しく設計する必要がある |
| 通知先承認 | SNS、Teams、メールの通知先承認が必要 |
| Alarm設計 | 閾値、評価期間、欠損データ扱いを決める必要がある |
| テストイベント | 実イベントを発生させるか、ログ投入で確認するかを決める必要がある |

### 16.4 当初案で進める場合の確認項目

| 確認項目 | 内容 |
| :--- | :--- |
| CloudTrail | 対象アカウント・リージョンの管理イベントが記録されているか |
| CloudWatch Logs連携 | CloudTrailログがCloudWatch Logsへ配信されているか |
| Log Group | 対象ロググループ名、保持期間、KMS設定 |
| Metric Filter | 4番台のイベント条件を拾えるか |
| Metric Namespace / Name | 命名規則に合っているか |
| CloudWatch Alarm | 閾値、評価期間、欠損データ扱い |
| SNS Topic | 既存Topic流用か、新規作成か |
| Teams / メール | 通知先、受信者、運用担当 |
| テスト方法 | 実イベント、テストログ、承認要否 |
| 切り戻し | Filter、Alarm、通知設定の戻し方 |

### 16.5 EventBridge既存経路との扱い

当初案で進める場合でも、既存EventBridge設定を無視しない。

整理方針:

```text
既存EventBridge:
  既存設定として記録する
  Targetが別アカウントの場合は受信側未確認として残す
  今回の通知要件を満たす証跡としては扱わない

当初案:
  今回対応の正式な監視・通知経路として設計する
  通知到達テストを実施する
  エビデンスを取得する
```

二重通知の確認:

| 確認 | 内容 |
| :--- | :--- |
| 既存EventBridgeが通知しているか | 通知している場合、二重通知の可能性 |
| 既存EventBridgeが別アカウント送信のみか | 最終通知未確認なら、当初案の必要性が高い |
| 新規Alarm通知先 | 既存通知先と同じか、別か |
| 運用担当 | どちらの通知を正式に見るか |

### 16.6 PMへの説明文案

```text
既存EventBridge Ruleは確認済み。ただし、Targetが別アカウントEvent Busになっているため、送信元アカウントでは最終通知先まで確認できない。

受信側アカウントのRule、Target、通知先まで確認できれば既存EventBridgeの流用を検討できる。
一方で、受信側確認ができない場合、既存経路を今回の監視通知として採用すると、通知到達の証跡が弱くなる。

その場合は、当初案のCloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> SNS/Teams通知の構成で進める方が、検知条件、通知先、テスト結果、エビデンスを今回対応範囲内で明確にできる。

既存EventBridge設定は参考情報として記録しつつ、正式な通知経路は当初案で設計する方針を検討する。
```

短縮版:

```text
既存EventBridgeはTargetが別アカウントのため、送信元では通知到達まで確認できない。
受信側確認が難しい場合は、当初案のCloudWatch Logs + Metric Filter + Alarm構成で新規に通知経路を作る方が、テストと証跡を明確にできる。
```

### 16.7 推奨判断

推奨は以下である。

```text
既存EventBridgeの受信側と通知到達まで確認できる
  -> 既存EventBridge流用を検討

受信側や通知到達が確認できない
  -> 当初案で新規に監視・通知経路を作る

ただし、既存EventBridgeとの二重通知は確認する
```

## 17. 現場向け報告文例

### 17.1 既存Ruleが通知まで確認できた場合

```text
4番台の対象イベントについて、既存EventBridge Ruleが存在し、Target経由で通知先まで到達していることを確認済み。

既存設定を流用できる可能性が高いため、不足イベントの有無を整理し、追加が必要なものだけ補完する方針で進める。
```

### 17.2 Targetまでは確認できたが通知先が不明な場合

```text
既存EventBridge RuleとTargetは確認済み。ただし、Targetの先で実際にメール、Teams、監視基盤へ通知されているかは未確認。

次にSNS Subscription、Lambdaログ、または別アカウントEvent Busの受信側Ruleを確認し、既存経路を流用できるか判断する。
```

### 17.3 新規作成が必要な場合

```text
対象イベントを拾う既存EventBridge Rule、または通知まで到達する既存経路は確認できなかった。

そのため、対象イベント用のEventBridge Ruleを新規作成し、承認済み通知先へ連携する方針で設計する。
```

## 18. 参照資料

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
