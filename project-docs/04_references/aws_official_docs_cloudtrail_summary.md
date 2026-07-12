# AWS公式ドキュメント CloudTrail要約

作成日: 2026-07-11

この資料は、AWS公式ドキュメントをもとに、CloudTrailを現場作業で確認するための要点を整理したものです。

日本語版ドキュメントは機械翻訳の場合があります。表現に迷う場合や手順の正確性を確認する場合は、英語版も併せて確認します。

## 1. CloudTrailとは

CloudTrailは、AWSアカウント内で実行された操作をイベントとして記録するサービスです。

記録対象には、以下のような操作が含まれます。

- AWSマネジメントコンソールでの操作
- AWS CLIでの操作
- AWS SDKでの操作
- AWS APIによる操作
- IAMユーザー、IAM Role、AWSサービスによる操作

現場では、CloudTrailは「誰が、いつ、どのAWS APIを、どのリソースに対して実行したか」を確認するための基本的な証跡サービスとして扱います。

## 2. Event History、Trail、CloudTrail Lakeの違い

| 種類 | 主な用途 | 保存・検索範囲 | 現場での見方 |
| :--- | :--- | :--- | :--- |
| Event History | 直近の管理イベント確認 | 過去90日間のManagement Event | まず手早く確認する場所 |
| Trail | 継続的な証跡保存 | S3へ保存。必要に応じてCloudWatch LogsやEventBridgeへ連携 | 監査、長期保管、通知設定の前提 |
| CloudTrail Lake | SQLによる高度な検索・分析 | Event Data Storeに保存 | 大量検索、横断分析、長期分析向け |

Event Historyはアカウント作成時から自動的に利用できますが、長期保存やCloudWatch Logs連携、監視発報にはTrailの設定が重要になります。

## 3. Event Historyのポイント

Event Historyは、CloudTrailで最初に確認することが多い画面です。

確認ポイント:

- 過去90日間のManagement Eventを確認できる
- リージョン単位で確認する
- データイベント、Insightsイベント、ネットワークアクティビティイベントは表示されない
- 検索属性は一度に複数指定できない
- TrailやEvent Data Storeとは独立している

現場での注意点:

- S3の`PutObject`など、S3オブジェクトレベルのData EventはEvent Historyだけでは確認できない
- 複数リージョン、複数アカウントを横断して調べる場合は、Trail、CloudTrail Lake、または別の集約基盤を確認する
- 「Event Historyに出ない」ことは「CloudTrailに記録できない」という意味ではない

## 4. Trailのポイント

Trailは、AWSアクティビティを継続的に記録し、S3バケットへ配信する設定です。

Trailで確認する主な項目:

| 項目 | 確認する意味 |
| :--- | :--- |
| Trail名 | 対象の証跡を特定する |
| Home Region | Trailの管理リージョンを確認する |
| Multi-Region | 全リージョンのイベントを収集しているか確認する |
| Organization Trail | 組織全体のアカウントを対象にしているか確認する |
| Management Events | 管理イベントを記録しているか確認する |
| Data Events | S3 Objectなどのデータイベントを記録しているか確認する |
| S3 Bucket | CloudTrailログの保存先を確認する |
| S3 Prefix | S3内の保存パスを確認する |
| CloudWatch Logs | 監視・Metric Filter・Alarmに使う連携先を確認する |
| KMS Key | ログ暗号化にCMKを使っているか確認する |
| Log File Validation | ログ改ざん検証が有効か確認する |

AWS公式ドキュメントでは、コンソールで作成するTrailはマルチリージョンTrailになります。単一リージョンTrailはCLIまたはAPIで作成する形になります。

## 5. Management Event

Management Eventは、AWSリソースに対する管理操作を記録するイベントです。

例:

- IAM Policyの変更
- CloudTrailの作成、更新、停止、削除
- Security Groupの作成、変更、削除
- Route Tableの変更
- VPCやSubnetの作成、削除
- ConsoleLogin

CloudTrailの監視要件で扱う4番台の多くは、Management EventをCloudWatch Logsへ連携し、Metric FilterとCloudWatch Alarmで検知する考え方になります。

確認観点:

- Management Eventが記録対象になっているか
- Read / Writeのうち、Writeイベントを記録しているか
- KMSイベントを除外していないか
- グローバルサービスイベントを含めているか

## 6. Data Event

Data Eventは、リソース内のデータに対する操作を記録するイベントです。

代表例:

- S3 Objectの`GetObject`
- S3 Objectの`PutObject`
- S3 Objectの`DeleteObject`
- Lambda関数の`Invoke`

Data Eventは高頻度になりやすいため、通常は必要な対象に絞って有効化します。

現場での注意点:

- S3バケットポリシー変更はManagement Event
- S3オブジェクトのアップロードや削除はData Event
- S3 Object-levelの証跡が必要な場合は、Data Eventの設定対象に該当バケットが含まれているか確認する
- Data Eventはコストに注意する

## 7. CloudWatch Logs連携

CloudTrailは、Trail設定に一致するイベントをCloudWatch Logsへ送信できます。

CloudWatch Logs連携で必要なもの:

- Trail
- CloudWatch Logs Log Group
- CloudTrailがLog Groupへ書き込むためのIAM Role
- Roleに付与された`logs:CreateLogStream`、`logs:PutLogEvents`などの権限

現場での確認ポイント:

| 項目 | 確認する理由 |
| :--- | :--- |
| Log Group名 | Metric Filterの設定先になるため |
| IAM Role ARN | CloudTrailがCloudWatch Logsへ書けるか判断するため |
| Log Stream | 実際にイベントが届いているか確認するため |
| Retention | ログ保持期間が要件に合っているか確認するため |
| KMS Key | CloudWatch Logs側の暗号化設定を確認するため |

CloudTrailイベントがCloudWatch Logsに届くまでには遅延があります。公式ドキュメントでは、通常は平均5分以内に配信されると説明されていますが、保証ではありません。

また、CloudWatch Logs画面の時刻はLog Groupに配信された時刻です。実際のAWS操作時刻を確認する場合は、イベント内の`eventTime`を確認します。

## 8. Metric Filter / CloudWatch Alarmとの関係

CloudTrail自体は「記録するサービス」です。

アラートを出すには、CloudTrailイベントをCloudWatch Logsへ連携し、そのLog GroupにMetric Filterを設定し、CloudWatch Alarmでしきい値を監視します。

基本の流れ:

```text
AWS操作
  -> CloudTrail Event
  -> CloudWatch Logs Log Group
  -> Metric Filter
  -> CloudWatch Metric
  -> CloudWatch Alarm
  -> SNS / メール / Teamsなど
```

現場で見るべきこと:

- TrailがCloudWatch Logsへ連携されているか
- 対象Log GroupにMetric Filterがあるか
- Filter Patternが監視要件と一致しているか
- CloudWatch Alarmが該当Metricを見ているか
- Alarm Actionに通知先が設定されているか
- 既存EventBridge Ruleと重複していないか

## 9. S3保存先

TrailのログはS3バケットに保存されます。

確認ポイント:

- 保存先S3バケット名
- Prefix
- バケットポリシー
- CloudTrail Service Principalへの許可
- `s3:GetBucketAcl`
- `s3:PutObject`
- `s3:x-amz-acl = bucket-owner-full-control`
- `aws:SourceArn`で対象Trailを制限しているか

現場での注意点:

- CloudTrailログ保存先S3バケットは、通常のアプリケーション用S3バケットとは役割が違う
- CloudTrailがログを書き込めるバケットポリシーが必要
- ログ保存先S3バケットの暗号化、アクセスログ、バージョニング、保持方針も確認対象になりやすい

## 10. Log File Validation

Log File Validationは、CloudTrailログが配信後に変更、削除、改ざんされていないかを検証するための機能です。

仕組みの概要:

- CloudTrailがログファイルごとにハッシュを作成する
- 1時間ごとにダイジェストファイルを作成する
- ダイジェストファイルにはログファイルのハッシュが含まれる
- ダイジェストファイルはデジタル署名される
- CLIなどで整合性を検証できる

現場での意味:

- 監査・フォレンジックで重要
- 「ログが後から書き換えられていない」ことを確認する材料になる
- 有効化しているかはTrail詳細で確認する

## 11. KMS / CMK暗号化

CloudTrailログはS3へ保存されるため、S3側の暗号化設定とCloudTrail側のKMS設定が関係します。

SSE-KMSを使用する場合の確認ポイント:

- KMS Key IDまたはAlias
- CloudTrailがKMS Keyを使えるKey Policyになっているか
- ログ参照者がS3 Read権限とKMS Decrypt権限を持っているか
- KMS Keyがログ保存先S3バケットと同じリージョンにあるか
- Organization Trailの場合、複数アカウントからの利用を許可できているか

注意点:

- KMS Key Policyに不備があると、CloudTrailのログ配信やログ参照に影響する
- 暗号化を有効にするだけでなく、誰が復号できるかまで確認する
- 監査では「AWS管理キーか、カスタマー管理キーか」が見られることがある

## 12. Organization Trail

Organization Trailは、AWS Organizations配下の複数アカウントを対象にしたTrailです。

確認ポイント:

- Organization Trailか
- 管理アカウントまたは委任管理者アカウントで管理されているか
- メンバーアカウントのイベントが対象に含まれているか
- Multi-Regionか
- CloudWatch Logs連携やKMS権限が組織向けに正しく設定されているか

現場での注意点:

- メンバーアカウント側でTrailが見えても、変更権限は管理アカウント側に限られることがある
- CloudWatch Logs連携、S3バケットポリシー、KMS Key Policyの不備で配信エラーになることがある
- 複数アカウント環境では「どのアカウントで確認するのか」を最初に決める

## 13. 料金で注意する点

CloudTrailの料金は設定内容によって変わります。

特に注意するもの:

| 項目 | 料金観点 |
| :--- | :--- |
| Event History | 閲覧は追加料金なし |
| TrailのManagement Event | S3への最初のコピーは無料枠がある |
| Data Event | イベント数に応じて課金される |
| CloudWatch Logs連携 | CloudTrailイベント配信料金とCloudWatch Logs取り込み料金が関係する |
| CloudTrail Lake | 取り込み、保存、クエリに料金が発生する |
| Insights | 分析対象イベント数に応じて課金される |

現場では、Data Event、CloudWatch Logs連携、CloudTrail Lake、長期保持を設定するときに料金影響を確認します。

## 14. 現場での確認チェックリスト

CloudTrailを確認するときは、以下を順番に見ると整理しやすいです。

| No. | 確認項目 | 見る理由 |
| :--- | :--- | :--- |
| 1 | Trailが存在するか | 継続的な証跡保存があるか確認する |
| 2 | Multi-Region Trailか | 全リージョンを対象にしているか確認する |
| 3 | Organization Trailか | 複数アカウントを対象にしているか確認する |
| 4 | Management Eventが有効か | 4番台の監視要件の前提になるため |
| 5 | Read / Writeの範囲 | 書き込み系変更イベントを拾えるか確認する |
| 6 | Data Eventが有効か | S3 Object-levelなどを記録しているか確認する |
| 7 | S3保存先 | ログ保管先と権限を確認する |
| 8 | CloudWatch Logs連携 | Metric Filter / Alarmの前提を確認する |
| 9 | IAM Role | CloudTrailがCloudWatch Logsへ書けるか確認する |
| 10 | KMS Key | CMK化、復号権限、Key Policyを確認する |
| 11 | Log File Validation | ログ改ざん検証が有効か確認する |
| 12 | EventBridge連携 | 既存通知や別アカウント送信がないか確認する |
| 13 | 料金影響 | Data EventやCloudWatch Logs連携の費用を確認する |

## 15. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| CloudTrailを有効にしないと何も見られない | Event Historyはデフォルトで利用できる。ただし長期保存や通知にはTrailが重要 |
| Event Historyに出ないなら記録できない | Event HistoryはManagement Event中心。Data EventはTrail設定が必要 |
| Trailがあれば自動でアラートが出る | Trailは記録。アラートにはCloudWatch Logs、Metric Filter、Alarm、通知先が必要 |
| S3バケットポリシー変更とS3ファイルアップロードは同じ | バケットポリシー変更はManagement Event、Object操作はData Event |
| KMSを設定すれば全員が安全に読める | 読む側にはS3 Read権限とKMS Decrypt権限が必要 |

## 16. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| CloudTrailとは | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-user-guide.html |
| CloudTrailのコンセプト | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-concepts.html |
| Event History | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/view-cloudtrail-events.html |
| Trail作成 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-create-a-trail-using-the-console-first-time.html |
| Management Event | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-management-events-with-cloudtrail.html |
| Data Event | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html |
| CloudWatch Logs連携 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| Log File Validation | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-intro.html |
| SSE-KMS暗号化 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html |
| Organization Trail | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/creating-trail-organization.html |
| CloudTrail料金 | https://aws.amazon.com/jp/cloudtrail/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| What is CloudTrail | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html |
| CloudTrail concepts | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-concepts.html |
| Event history | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html |
| Sending events to CloudWatch Logs | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| Encrypting CloudTrail log files with SSE-KMS | https://docs.aws.amazon.com/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html |

