# リーダー確認事項

作成日: 2026-07-07

この資料は、AWSセキュリティ監査指摘対応を進めるにあたり、リーダーへ確認したい事項を整理したものである。
目的は、作業着手前に必要な資料、権限、既存運用、作業方式、レビュー体制を明確にし、手戻りや権限不足による停滞を減らすことである。

## 1. 確認の前提

今回の対応は、主に以下の3系統に分かれる。

| 分類 | 内容 |
|---|---|
| 運用手順整備 | GuardDuty等のセキュリティアラート対応手順、対応記録の整備 |
| ログ保全強化 | CloudTrailログ保存先S3、SSE-KMS/CMK、CMKローテーション、VPC Flow Logs |
| 監視アラート設定 | CloudTrailイベントをCloudWatch Logs / Metric Filter / Alarm等で検知・通知 |

作業を進める前に、既存資料、既存設定、通知先、作業権限、レビュー体制を確認する必要がある。

## 2. まず確認したいこと

リーダーへ最初に確認したい事項は以下。

```text
今回の21項目について、まず既存資料と既存AWS設定を棚卸ししたいです。
そのため、セキュリティ設計書、運用設計書、既存手順書、CloudTrail/CloudWatch関連のエビデンス格納先、
およびAWS CLI利用可否と権限範囲を確認させてください。
```

## 3. 資料・エビデンスの所在

第三者検証評価シートの参照エビデンスに記載されている資料の所在を確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| セキュリティ設計書の最新版はどこにあるか | 監視要件、GuardDuty、CloudTrail、通知先の設計根拠を確認するため |
| 運用設計書の最新版はどこにあるか | 既存の運用フロー、対応者、エスカレーションを確認するため |
| CloudTrail / CloudWatch / GuardDutyの既存エビデンスはどこにあるか | 監査指摘時点の状態と現在の状態を比較するため |
| WAF、不正アクセス分析手順書はどこにあるか | A3/A4の手順書作成時に既存運用と整合させるため |
| 月次不正アクセス集計資料はどこにあるか | 月次確認から通知/即時対応へ移行する際の現行運用を確認するため |
| Unauthorized Access関連の既存手順書はどこにあるか | GuardDuty手順書のベースにできるか確認するため |
| 追加指摘対応資料の最新版はどこにあるか | 銀行側・監査側との合意済み内容を確認するため |
| AWSエビデンス取得資料の格納先はどこか | 同じ形式で証跡を残すため |

聞き方:

```text
評価シートの参照エビデンスに出ている設計書、運用設計書、既存手順書、AWSエビデンスの格納先を確認したいです。
最新版がどれか分からないと、既存運用と異なる手順や設定案を作ってしまう可能性があります。
```

## 4. 既存手順書の所在

A3/A4では、セキュリティアラートに関する運用手順書と対応記録が論点になっている。

| 確認事項 | 確認したい理由 |
|---|---|
| GuardDutyの確認手順書は存在するか | 新規作成か既存手順書改訂か判断するため |
| Deep Security / WAF / Shieldの手順書は流用可能か | 既存の書式、エスカレーション、記録項目に合わせるため |
| インシデント対応手順書は存在するか | GuardDuty Finding発生時の連絡先や判断基準を合わせるため |
| 対応記録テンプレートは存在するか | A4のエビデンス保管方式を決めるため |
| Teams通知やメール通知の運用ルールはあるか | 通知後の一次対応者と確認方法を明確にするため |

聞き方:

```text
GuardDuty向けの手順書が未整備であれば新規作成しますが、
既存のWAFや不正アクセス対応手順と書式やエスカレーション先を合わせたいです。
既存手順書と対応記録テンプレートの所在を教えてください。
```

## 5. AWSアカウント・環境情報

対象環境を取り違えないため、最初に確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| 対象AWSアカウントはProd/OPERで分かれているか | 環境別に作業対象と証跡を分けるため |
| 対象リージョンはどこか | CloudTrail、CloudWatch、VPC Flow Logsの確認先を決めるため |
| AWS Organizations配下か | Organization TrailやOrganizations変更監視の扱いを確認するため |
| 管理アカウントとメンバーアカウントの関係 | OrganizationsやCloudTrailの設定権限に影響するため |
| 開発環境・検証環境は本番相当か | 本番前のテスト可否を判断するため |

聞き方:

```text
Prod/OPERそれぞれのAWSアカウント、対象リージョン、Organizations管理有無を確認したいです。
CloudTrailやOrganizationsの設定は、管理アカウント側でしか確認・変更できない可能性があります。
```

## 6. AWS CLI利用可否と権限

GUIでの画面確認は行いつつ、設定値の棚卸しと証跡取得はAWS CLIで実施できるか確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| AWS CLIを利用してよいか | 設定値をJSONで保存し、証跡と差分確認に使うため |
| 作業端末はPowerShellかGit Bashか | コマンド形式、改行、パス表記が変わるため |
| 認証方式はSSO/SAML/一時認証情報/アクセスキーのどれか | `.aws`設定方式が変わるため |
| 参照系権限はどこまであるか | 現状調査ができるか判断するため |
| 変更系権限は付与されるか | 設定作業を自分で行うか、権限者に依頼するか判断するため |
| 権限不足時の相談先は誰か | 作業停滞時の連絡ルートを明確にするため |

聞き方:

```text
GUIでの画面確認とスクリーンショット取得は行います。
併せて、設定値の確認と変更前後の証跡取得はAWS CLIでJSON保存したいです。
まず参照系コマンドの利用可否と、付与される権限範囲を確認させてください。
```

必要になりやすい参照系権限:

| 領域 | 主な権限 |
|---|---|
| CloudTrail | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrailStatus`, `cloudtrail:GetEventSelectors`, `cloudtrail:LookupEvents` |
| CloudWatch Logs | `logs:DescribeLogGroups`, `logs:DescribeMetricFilters`, `logs:FilterLogEvents` |
| CloudWatch Alarm | `cloudwatch:DescribeAlarms`, `cloudwatch:DescribeAlarmsForMetric` |
| SNS | `sns:ListTopics`, `sns:GetTopicAttributes`, `sns:ListSubscriptionsByTopic` |
| EventBridge | `events:ListRules`, `events:DescribeRule`, `events:ListTargetsByRule` |
| KMS | `kms:ListKeys`, `kms:ListAliases`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `kms:GetKeyRotationStatus` |
| VPC | `ec2:DescribeVpcs`, `ec2:DescribeFlowLogs`, `ec2:DescribeNetworkAcls`, `ec2:DescribeRouteTables` |
| GuardDuty | `guardduty:ListDetectors`, `guardduty:GetDetector`, `guardduty:ListFindings`, `guardduty:GetFindings` |

## 7. CloudTrail / CloudWatch連携

4.1〜4.15はCloudTrailとCloudWatchを使った監視が中心になるため、既存構成を確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| CloudTrailは有効か | 監視対象イベントの元データになるため |
| Multi-Region Trailか | グローバルサービスや複数リージョンのイベント監視に影響するため |
| Organization Trailか | 設定権限や対象範囲に影響するため |
| CloudWatch Logs連携は有効か | Metric Filter / Alarm方式の前提になるため |
| 連携先Log Group名は何か | Metric Filter作成先を決めるため |
| Log Groupの保持期間は何日か | 監査・調査可能期間に影響するため |
| 既存Metric Filterはあるか | 重複作成を避けるため |
| 既存Alarmはあるか | 重複通知を避けるため |
| 通知先SNS Topicは既存利用か新規作成か | 通知設計に影響するため |

聞き方:

```text
4.1〜4.15はCloudTrailをCloudWatch Logsへ連携し、Metric FilterとAlarmで通知する方針に見えます。
既存のCloudTrail、Log Group、Metric Filter、Alarm、SNS Topicの有無を先に確認したいです。
```

## 8. 通知先・運用フロー

アラートを設定しても、通知先と対応者が決まっていないと運用に乗らない。

| 確認事項 | 確認したい理由 |
|---|---|
| 通知先はメール、Teams、監視製品、SIEMのどれか | 設定方式が変わるため |
| 既存SNS Topicを使うか | 新規作成の要否を判断するため |
| 通知先の管理者は誰か | サブスクリプション承認や宛先変更が必要になるため |
| 一次対応者は誰か | A3/A4の手順書に記載するため |
| 夜間・休日通知の扱い | 通知条件、エスカレーションに影響するため |
| 通知文面の要件はあるか | 運用者が判断できる内容にするため |
| アラート対応記録はどこに保存するか | A4の証跡管理に必要なため |

聞き方:

```text
アラート通知先と一次対応者、対応記録の保存先を確認したいです。
通知設定だけ作っても、誰が見てどこに記録するかが決まっていないとA3/A4の改善になりにくいです。
```

## 9. KMS / CMK関連

3.5、3.6、4.7はKMS関連のため、Key Policyや運用者権限を慎重に確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| CloudTrailログ用CMKは新規作成か既存利用か | 設計と作業範囲が変わるため |
| Key Policyのレビュー担当は誰か | CloudTrail書込不能やログ参照不能を避けるため |
| CloudTrailがKMSキーを使ってログを書き込める権限をどう設計するか | 3.5の中心論点 |
| 運用者が復号・参照できる権限はどうするか | ログ調査運用に影響するため |
| 自動ローテーションを有効にしてよいか | 3.6対応のため |
| CMK無効化/削除予約の監視はCloudWatch Alarmで実施するか | 4.7対応のため |

聞き方:

```text
CloudTrailログのSSE-KMS/CMK化では、KMS Key Policyが重要になります。
CloudTrailの書込権限、運用者の参照権限、Key Policyレビュー担当、新規CMKか既存CMKかを確認したいです。
```

## 10. VPC Flow Logs

3.7ではProd/OPERのVPC Flow Logs有効化状況が論点になっている。

| 確認事項 | 確認したい理由 |
|---|---|
| 対象VPC一覧はどこにあるか | すべてのVPCを確認するため |
| OPERでFlow Logsが無効な理由はあるか | 意図的に無効か、単なる未対応か判断するため |
| 保存先はCloudWatch LogsかS3か | 設定方法、料金、保持期間が変わるため |
| TrafficTypeはALL/ACCEPT/REJECTのどれか | ログ量と調査観点に影響するため |
| 保持期間とライフサイクルはどうするか | コストと監査要件に影響するため |
| KMS暗号化要件はあるか | 保存先の暗号化設計に影響するため |

聞き方:

```text
OPER環境でVPC Flow Logsが無効とのことなので、対象VPC、保存先、TrafficType、保持期間、暗号化要件を確認したいです。
ログ量と料金に影響するため、設定値は事前に合意しておきたいです。
```

## 11. 作業方式・承認・レビュー

本番作業まで見据えて、作業方式とレビュー体制を確認する。

| 確認事項 | 確認したい理由 |
|---|---|
| 実作業はGUI、CLI、IaC、申請ツールのどれか | 手順書と証跡取得方法が変わるため |
| 開発環境で先に検証できるか | 本番リスクを下げるため |
| 作業手順書のレビュー担当は誰か | レビュー待ちを計画に入れるため |
| 銀行様レビューはいつ必要か | 9/12リリースまでの逆算に必要 |
| ITセキュリティ統括部への確認は必要か | 監査指摘対応としての妥当性確認に必要 |
| 本番作業の作業者・確認者・承認者は誰か | リリース体制を決めるため |
| 切り戻し判断者は誰か | 障害時の判断を明確にするため |

聞き方:

```text
来週以降の開発に入る前に、GUI/CLI/IaCなどの作業方式、レビュー担当、本番作業時の作業者・確認者・承認者を確認したいです。
9/12リリースから逆算すると、8月中旬以降はレビューと本番準備に時間を確保した方がよいと考えています。
```

## 12. 優先順位の確認

21項目すべてを同時に進めるより、共通部分を先に固めた方が効率がよい。

優先順位案:

| 優先 | 対象 | 理由 |
|---|---|---|
| 1 | 既存資料・既存AWS設定の棚卸し | 全作業の前提になるため |
| 2 | CloudTrail / CloudWatch Logs連携確認 | 4.1〜4.15の共通基盤になるため |
| 3 | 通知先・運用フロー確認 | A3/A4と監視アラートの共通論点になるため |
| 4 | KMS/CloudTrailログ保全設計 | 3.5は影響が大きく、設計レビューが必要なため |
| 5 | Metric Filter / Alarmの共通テンプレート | 4.1〜4.15を横展開しやすくするため |
| 6 | VPC Flow Logs | ログ量・保存先・料金影響の確認が必要なため |

聞き方:

```text
まずCloudTrail/CloudWatch/通知先の共通基盤を確認し、その後に4.1〜4.15を横展開する進め方でよいでしょうか。
KMSとVPC Flow Logsは個別リスクがあるため、並行して設計確認を進めたいです。
```

## 13. リーダーへ送る短い確認文

Teamsなどで短く送る場合の例。

```text
今回の21項目について、今週中に作業計画を固めるため、以下を確認させてください。

1. 評価シートに記載されている設計書・運用設計書・AWSエビデンス・既存手順書の格納先
2. Prod/OPERのAWSアカウント、リージョン、Organizations管理有無
3. AWS CLI利用可否と、参照系権限の範囲
4. CloudTrailとCloudWatch Logs連携、既存Metric Filter/Alarm/SNSの有無
5. 通知先、一次対応者、対応記録の保存先
6. CloudTrailログ用CMK、Key Policy、Rotationの方針
7. VPC Flow Logsの保存先、保持期間、TrafficTypeの方針
8. 作業方式、レビュー担当、本番作業の承認ルート

まずは既存設定を棚卸しし、既存設定で足りているもの、新規設定が必要なもの、手順書整備が必要なものに分けたいです。
```

