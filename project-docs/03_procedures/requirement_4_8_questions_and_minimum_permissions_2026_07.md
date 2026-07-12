# 要件4.8 確認事項・最低限必要権限整理

作成日: 2026-07-07

この資料は、第三者検証評価シートの **要件番号4.8「S3バケットポリシーの変更が監視されていること」** について、関係者へ事前確認する事項と、AWS CLIで作業する場合に最低限必要となるIAM権限を整理するための資料である。

目的は、作業前に監視対象、通知先、テスト方法、権限範囲を明確にし、不要な設定変更や通知の重複を避けることである。

## 1. 要件4.8の確認対象

| 項目 | 内容 |
|---|---|
| 要件番号 | 4.8 |
| 要件 | S3バケットポリシーの変更が監視されていること |
| 主なCloudTrail EventName | `PutBucketPolicy`, `DeleteBucketPolicy` |
| 想定構成 | CloudTrail -> CloudWatch Logs -> Metric Filter -> CloudWatch Alarm -> SNS等 |
| 主な論点 | 監視対象バケット、通知先、既存監視との重複、テスト方法 |

要件4.8では、S3バケットポリシーの内容そのものを修正することが主目的ではない。
主目的は、S3バケットポリシーが変更された場合に、速やかに検知・通知できる状態にすることである。

## 2. 最初に確認するべき重要事項

まず以下の3点を確認する。

```text
1. 監視対象は全S3バケットか、特定の業務・監査対象バケットのみか。
2. PutBucketPolicy / DeleteBucketPolicy の2イベント監視で要件4.8を満たす認識でよいか。
3. 通知先は既存の通知基盤を使うのか、新規に用意するのか。
```

この3点が決まらないと、Metric Filter、Alarm、SNS、テスト方法、証跡範囲が確定しない。

## 3. 関係者へ確認する質問一覧

### 3.1 監視対象範囲

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 要件4.8の監視対象は、対象AWSアカウント内の全S3バケットでよいか | 全バケット監視か、一部バケット監視かでFilter設計が変わる |
| 2 | 業務対象バケット、監査対象バケット、ログ保管バケットなど、対象バケットの一覧はあるか | 対象バケットを限定する場合に必要 |
| 3 | CloudTrailログ保存先S3バケットも4.8の監視対象に含めるか | ログ保全上は重要だが、運用対象外扱いの場合もある |
| 4 | 検証用、開発用、一時作業用バケットも通知対象に含めるか | 通知ノイズを抑えるため |
| 5 | 既に廃止予定または利用実態不明のバケットはあるか | 監視対象整理に影響 |
| 6 | 対象バケットをタグや命名規則で判定できるか | 自動棚卸しや設計資料化に使える |
| 7 | 今後新規作成されるS3バケットも自動的に監視対象に含める方針か | 全バケット監視にするか、個別追加にするかの判断材料 |

確認時の聞き方例:

```text
要件4.8について確認です。
本日アカウント内を確認したところS3バケットが多数ありました。
監視対象は、対象アカウント内の全S3バケットに対する PutBucketPolicy / DeleteBucketPolicy でよいでしょうか。
それとも、業務対象バケットや監査対象バケットなど、対象を限定する方針でしょうか。
```

### 3.2 対象環境・対象アカウント

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 対象環境はProd、OPER、開発、検証のどこまでか | 評価シートではProd・OPERが出ているため、対象範囲を確定する |
| 2 | 対象AWSアカウントは単一か複数か | 複数アカウントの場合、同じ設定を横展開する必要がある |
| 3 | Organizations配下全体で見る必要があるか | Organization Trailや管理アカウント側の確認が必要になる場合がある |
| 4 | 対象リージョンは東京リージョンのみか、全リージョンか | CloudTrail、CloudWatch、SNSの設定場所に影響 |
| 5 | CloudTrailはアカウント個別TrailかOrganization Trailか | 監視設定の場所と権限に影響 |
| 6 | 環境ごとに通知先を分けるか | Prodと開発で通知先を変える場合がある |

### 3.3 監視イベントの範囲

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | `PutBucketPolicy` と `DeleteBucketPolicy` の2イベントで要件4.8を満たす認識でよいか | 監査要件との認識合わせ |
| 2 | `PutPublicAccessBlock` も監視対象に含める必要があるか | Public Access Block変更も公開リスクに関係する |
| 3 | `PutBucketAcl` / `DeleteBucketPolicy` / ACL関連イベントを含める必要があるか | ACLを使っている環境では公開リスクに関係する |
| 4 | `PutBucketOwnershipControls` を含める必要があるか | Object Ownership変更がアクセス制御に影響する可能性がある |
| 5 | `PutBucketCors` を含める必要があるか | Webアクセス経路や外部連携に影響する可能性がある |
| 6 | 今回は評価シートどおりS3 Bucket Policy変更だけに絞るか | スコープ拡大を防ぐため |

推奨:

```text
最初のパイロットでは、要件4.8の文言に合わせて PutBucketPolicy / DeleteBucketPolicy に絞る。
追加でPublic Access BlockやACLも監視する場合は、別要件または追加スコープとして扱う。
```

### 3.4 既存監視との重複確認

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 既にCloudWatch Logs Metric Filterで同等監視があるか | 重複作成を防ぐ |
| 2 | EventBridge RuleでS3ポリシー変更を拾っているか | CloudWatch Alarm以外の通知経路がある可能性 |
| 3 | SIEM、監視製品、ログ分析基盤で同等監視があるか | AWS側設定だけでは全体像が分からない場合がある |
| 4 | GuardDutyやSecurity Hubで代替監視として扱っているものがあるか | 評価シート上の指摘理由と整合させる |
| 5 | 月次確認の運用資料にS3ポリシー変更確認が含まれているか | A3/A4の手順書にも関係する |
| 6 | 既存の通知先や運用フローに追加してよいか | 運用部門への通知増加を避ける |

### 3.5 通知設計

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 通知先は既存SNS Topicを使うか、新規SNS Topicを作るか | Alarm Action設定に必要 |
| 2 | 通知先はメール、Teams、監視基盤、チケット管理、SIEMのどれか | 実運用での対応に影響 |
| 3 | 通知先の受信者、確認担当、一次対応担当は誰か | アラート後の対応を明確にする |
| 4 | ProdとOPERで通知先を分けるか | 誤通知や対応漏れを防ぐ |
| 5 | 通知文面に含めるべき情報は何か | バケット名、操作ユーザー、EventTime、EventId等 |
| 6 | テスト通知を飛ばしてよい時間帯はいつか | 不要な混乱を避ける |
| 7 | 通知後の記録先はどこか | A3/A4の運用手順、対応履歴に関係 |

通知に最低限含めたい情報:

```text
要件番号
Alarm名
対象AWSアカウント
対象環境
検知イベント名
対象バケット名
発生時刻
操作主体
CloudTrail EventId
一次確認手順へのリンク
```

### 3.6 Alarm設計

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 全バケットまとめて1つのAlarmでよいか | シンプルだが通知粒度は粗い |
| 2 | 重要バケットごとにAlarmを分ける必要があるか | 通知先や重要度を分ける場合に必要 |
| 3 | Alarm名、Metric Namespace、Metric名の命名規則はあるか | 既存運用との整合 |
| 4 | しきい値は1回以上で発報してよいか | S3ポリシー変更は頻度が低いため1回発報が自然 |
| 5 | `TreatMissingData` は `notBreaching` でよいか | 通常時にデータなしでOK扱いにするため |
| 6 | Alarmを手動でOKに戻す運用か、自動復帰に任せるか | 運用手順に影響 |

### 3.7 テスト方法

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 検証用S3バケットで `PutBucketPolicy` を発生させてよいか | 実イベントテストに必要 |
| 2 | `DeleteBucketPolicy` もテスト対象に含めるか | ポリシー削除テストは影響が大きい場合がある |
| 3 | 本番バケットで実イベントテストを行ってよいか | 原則は避ける。承認が必要 |
| 4 | Metric Filter単体テストのみでよいか | 本番変更を避ける場合の代替案 |
| 5 | 通知テストを行う時間帯はいつか | 運用側の混乱防止 |
| 6 | テスト後、監視設定を残すか切り戻すか | パイロット完了条件に影響 |
| 7 | テスト証跡として何を保存するか | レビュー、監査説明に必要 |

推奨:

```text
1. まず aws logs test-metric-filter でFilter Patternを単体確認する。
2. 次に検証用S3バケットで PutBucketPolicy を発生させる。
3. DeleteBucketPolicy は、既存ポリシーがない検証用バケットでのみ実施する。
4. 本番バケットでのテストは承認がある場合のみ行う。
```

### 3.8 証跡・成果物

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 証跡はどこに保存するか | 共有・提出のため |
| 2 | CLI出力、画面キャプチャ、設計書反映のどれが必要か | レビュー観点に影響 |
| 3 | 変更前後の比較資料は必要か | 監査説明に使いやすい |
| 4 | Alarm通知メールやTeams通知のスクリーンショットは必要か | 通知確認の証跡 |
| 5 | 作業手順書、切り戻し手順書、テスト結果票の様式はあるか | 現場の成果物に合わせる |
| 6 | 承認履歴やレビューコメントをどこに残すか | 本番作業の監査証跡 |

### 3.9 運用手順

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | アラート発報後、誰が一次確認するか | 対応漏れ防止 |
| 2 | CloudTrailで何を確認するか | 操作者、対象バケット、EventIdなど |
| 3 | 正常な変更か、想定外変更かを誰が判断するか | インシデント判定に必要 |
| 4 | 想定外変更だった場合のエスカレーション先はどこか | A3の手順書に必要 |
| 5 | 対応記録はどこに残すか | A4の運用証跡に必要 |
| 6 | 誤検知や定常変更が多い場合の抑制方針はあるか | 通知疲れを防ぐ |

## 4. 確認時に使える短い質問文

会議やチャットでそのまま使える形。

```text
要件4.8のS3バケットポリシー変更監視について確認です。
監視対象は、対象アカウント内の全S3バケットに対する PutBucketPolicy / DeleteBucketPolicy でよいでしょうか。
それとも、業務対象バケットや監査対象バケットなど、対象を限定する方針でしょうか。
```

```text
要件4.8について、まずは PutBucketPolicy / DeleteBucketPolicy の2イベントをCloudTrailから検知し、
CloudWatch Logs Metric Filter、CloudWatch Alarm、SNS通知へ連携する構成で進める認識でよいでしょうか。
```

```text
通知先について確認です。
既存のSNS Topicや監視通知基盤を利用する方針でしょうか。
それとも、要件4.8用に新規の通知先を作成する方針でしょうか。
```

```text
テスト方法について確認です。
検証用S3バケットで PutBucketPolicy を発生させて、CloudTrail、Metric Filter、Alarm、通知まで確認する進め方でよいでしょうか。
本番バケットでの実イベントテストは、承認がある場合のみ実施する認識です。
```

## 5. 最低限必要なAWSアカウント権限

権限は、調査のみ、監視設定変更、実イベントテスト、切り戻しで分けて考える。

最初から強い権限を広く要求するのではなく、以下の順で依頼する。

```text
1. 参照系権限で現状調査する
2. 監視設定を作成する権限を限定的に付与してもらう
3. 実イベントテスト用S3バケットだけS3ポリシー変更権限を付与してもらう
4. 本番バケットへの変更権限は原則要求せず、必要時のみ承認ベースにする
```

## 6. 調査に最低限必要な参照系権限

要件4.8の現状確認だけなら、まず以下が必要。

| サービス | 権限 | 用途 |
|---|---|---|
| STS | `sts:GetCallerIdentity` | 作業アカウント・Role確認 |
| CloudTrail | `cloudtrail:DescribeTrails` | Trail一覧確認 |
| CloudTrail | `cloudtrail:GetTrail` | Trail詳細確認 |
| CloudTrail | `cloudtrail:GetTrailStatus` | Trailが記録中か確認 |
| CloudTrail | `cloudtrail:GetEventSelectors` | Management Event記録有無確認 |
| CloudTrail | `cloudtrail:LookupEvents` | `PutBucketPolicy` / `DeleteBucketPolicy` の過去イベント確認 |
| CloudWatch Logs | `logs:DescribeLogGroups` | CloudTrail連携先Log Group確認 |
| CloudWatch Logs | `logs:DescribeLogStreams` | Log Stream確認 |
| CloudWatch Logs | `logs:FilterLogEvents` | CloudWatch Logs上のCloudTrailイベント確認 |
| CloudWatch Logs | `logs:DescribeMetricFilters` | 既存Metric Filter確認 |
| CloudWatch Logs | `logs:TestMetricFilter` | Filter Pattern単体テスト |
| CloudWatch | `cloudwatch:DescribeAlarms` | 既存Alarm確認 |
| CloudWatch | `cloudwatch:DescribeAlarmHistory` | Alarm履歴確認 |
| CloudWatch | `cloudwatch:ListMetrics` | Metric存在確認 |
| CloudWatch | `cloudwatch:GetMetricStatistics` | Metric発生確認 |
| SNS | `sns:ListTopics` | 既存SNS Topic確認 |
| SNS | `sns:ListSubscriptions` | 通知先確認 |
| SNS | `sns:GetTopicAttributes` | Topic詳細確認 |
| S3 | `s3:ListAllMyBuckets` | S3バケット棚卸し |
| S3 | `s3:GetBucketPolicy` | 対象バケットの現行Policy確認 |
| S3 | `s3:GetBucketPolicyStatus` | Public判定確認 |
| S3 | `s3:GetBucketPublicAccessBlock` | Public Access Block確認 |
| S3 | `s3:GetBucketTagging` | タグによる対象判定 |
| S3 | `s3:GetBucketLocation` | バケットリージョン確認 |

補足:
S3の参照系権限は、全バケットが対象か一部バケットが対象かでResource指定が変わる。
全S3バケットを棚卸しする場合、最低限 `s3:ListAllMyBuckets` と対象バケットごとの参照権限が必要になる。

## 7. 監視設定作成に必要な変更系権限

Metric FilterとAlarmを作成する場合に必要。

| サービス | 権限 | 用途 |
|---|---|---|
| CloudWatch Logs | `logs:PutMetricFilter` | 4.8用Metric Filter作成・更新 |
| CloudWatch Logs | `logs:DeleteMetricFilter` | 切り戻し時にMetric Filter削除 |
| CloudWatch | `cloudwatch:PutMetricAlarm` | 4.8用Alarm作成・更新 |
| CloudWatch | `cloudwatch:DeleteAlarms` | 切り戻し時にAlarm削除 |
| CloudWatch | `cloudwatch:DisableAlarmActions` | テスト時に通知を止める場合 |
| CloudWatch | `cloudwatch:EnableAlarmActions` | 通知アクションを戻す場合 |

注意:
既存Alarmを変更する場合は影響範囲が広がる。
パイロットでは新規Alarmを作成し、既存Alarmは変更しない方が安全である。

## 8. SNS通知先を新規作成する場合に必要な権限

既存SNS Topicを使う場合は、原則として新規作成権限は不要である。
新規TopicやSubscriptionを作る場合のみ、以下が必要。

| サービス | 権限 | 用途 |
|---|---|---|
| SNS | `sns:CreateTopic` | 新規Topic作成 |
| SNS | `sns:SetTopicAttributes` | Topic属性設定 |
| SNS | `sns:Subscribe` | メール等の購読設定 |
| SNS | `sns:Unsubscribe` | 切り戻し時の購読解除 |
| SNS | `sns:DeleteTopic` | 切り戻し時のTopic削除 |
| SNS | `sns:Publish` | 通知テストを直接行う場合 |

推奨:

```text
最初のパイロットでは、可能であれば既存SNS Topicを利用する。
新規Topicを作る場合は、通知先、購読者、メール承認、削除方針を事前に合意する。
```

## 9. 実イベントテストに必要なS3権限

検証用S3バケットで `PutBucketPolicy` / `DeleteBucketPolicy` を発生させる場合に必要。

| サービス | 権限 | 用途 |
|---|---|---|
| S3 | `s3:GetBucketPolicy` | テスト前後のBucket Policy確認 |
| S3 | `s3:PutBucketPolicy` | `PutBucketPolicy` イベント発生 |
| S3 | `s3:DeleteBucketPolicy` | `DeleteBucketPolicy` イベント発生 |
| S3 | `s3:GetBucketPolicyStatus` | Public判定確認 |
| S3 | `s3:GetBucketPublicAccessBlock` | Public Access Block確認 |

重要:

```text
これらの変更系権限は、原則として検証用S3バケットに限定する。
本番バケットへの s3:PutBucketPolicy / s3:DeleteBucketPolicy は、承認された作業時のみ利用する。
```

Resource指定の考え方:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetBucketPolicy",
    "s3:PutBucketPolicy",
    "s3:DeleteBucketPolicy",
    "s3:GetBucketPolicyStatus",
    "s3:GetBucketPublicAccessBlock"
  ],
  "Resource": "arn:aws:s3:::<test-bucket-name>"
}
```

## 10. 最小権限の依頼単位

### 10.1 まず依頼したい参照系権限

```text
sts:GetCallerIdentity
cloudtrail:DescribeTrails
cloudtrail:GetTrail
cloudtrail:GetTrailStatus
cloudtrail:GetEventSelectors
cloudtrail:LookupEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:FilterLogEvents
logs:DescribeMetricFilters
logs:TestMetricFilter
cloudwatch:DescribeAlarms
cloudwatch:DescribeAlarmHistory
cloudwatch:ListMetrics
cloudwatch:GetMetricStatistics
sns:ListTopics
sns:ListSubscriptions
sns:GetTopicAttributes
s3:ListAllMyBuckets
s3:GetBucketPolicy
s3:GetBucketPolicyStatus
s3:GetBucketPublicAccessBlock
s3:GetBucketTagging
s3:GetBucketLocation
```

### 10.2 パイロット設定時に追加で必要な変更系権限

```text
logs:PutMetricFilter
logs:DeleteMetricFilter
cloudwatch:PutMetricAlarm
cloudwatch:DeleteAlarms
cloudwatch:DisableAlarmActions
cloudwatch:EnableAlarmActions
```

### 10.3 検証用S3バケットで実イベントテストを行う場合

```text
s3:GetBucketPolicy
s3:PutBucketPolicy
s3:DeleteBucketPolicy
s3:GetBucketPolicyStatus
s3:GetBucketPublicAccessBlock
```

対象Resource:

```text
arn:aws:s3:::<test-bucket-name>
```

## 11. 変更権限を依頼する際の説明文

```text
要件4.8のパイロット作業では、まず参照系権限でCloudTrail、CloudWatch Logs、Metric Filter、Alarm、SNS、S3バケットの現状確認を行います。

設定作業では、CloudWatch LogsのMetric Filter作成とCloudWatch Alarm作成が必要です。
また、実イベントテストを行う場合は、検証用S3バケットに限定して PutBucketPolicy / DeleteBucketPolicy を実行できる権限が必要です。

本番バケットへのBucket Policy変更権限は原則要求せず、必要な場合のみ承認された作業として実施する想定です。
```

## 12. 権限不足時の切り分け

| エラー例 | 想定原因 | 確認する権限 |
|---|---|---|
| `AccessDenied` on `DescribeTrails` | CloudTrail参照不可 | `cloudtrail:DescribeTrails` |
| `AccessDenied` on `DescribeMetricFilters` | Metric Filter参照不可 | `logs:DescribeMetricFilters` |
| `AccessDenied` on `PutMetricFilter` | Metric Filter作成不可 | `logs:PutMetricFilter` |
| `AccessDenied` on `PutMetricAlarm` | Alarm作成不可 | `cloudwatch:PutMetricAlarm` |
| `AccessDenied` on `ListTopics` | SNS Topic参照不可 | `sns:ListTopics` |
| `AccessDenied` on `PutBucketPolicy` | S3 Policy変更不可 | `s3:PutBucketPolicy` |
| `AccessDenied` on `DeleteBucketPolicy` | S3 Policy削除不可 | `s3:DeleteBucketPolicy` |

## 13. 確認後に決めること

質問・確認が終わったら、以下を決める。

| 決定事項 | 内容 |
|---|---|
| 監視対象 | 全S3バケット / 対象バケット限定 |
| 対象環境 | Prod / OPER / 開発 / 検証 |
| 対象アカウント | 単一 / 複数 / Organizations配下 |
| 対象イベント | `PutBucketPolicy`, `DeleteBucketPolicy` のみ / 追加イベントあり |
| 監視方式 | CloudWatch Logs Metric Filter / EventBridge / 既存監視基盤 |
| Alarm粒度 | 全体1つ / 環境別 / バケット別 |
| 通知先 | 既存SNS / 新規SNS / 監視基盤 / Teams等 |
| テスト方式 | Filter単体テスト / 検証用バケット実イベント / 本番承認テスト |
| 証跡 | CLI出力 / 画面キャプチャ / 通知受信 / 手順書 |
| 切り戻し | パイロット後に残す / 削除する |

## 14. 推奨する進め方

```text
1. 参照系権限で現状調査する
2. 監視対象が全S3バケットか限定バケットか確認する
3. PutBucketPolicy / DeleteBucketPolicy の2イベントで要件を満たすか確認する
4. 既存通知先と運用フローを確認する
5. 検証用バケットでパイロット実施する
6. 証跡と手順を固める
7. 4.1〜4.15の同種監視へ横展開する
```
