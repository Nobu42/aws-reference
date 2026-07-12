# 削除予定VPCのクラウドセキュリティ対応影響確認メモ

作成日: 2026-07-11

このメモは、インフラチーム側で削除予定のVPCについて、担当中のクラウドセキュリティ対応へ影響がないか確認するための整理である。

## 結論

VPCを削除しても、CloudTrail、CloudWatch Logs、CloudWatch Alarm、EventBridge、GuardDuty、SNS、KMS、S3などの管理サービス自体が直ちに停止するわけではない。

そのため、削除対象VPCが今回の対応対象外であり、関連するVPC Flow Logs、通知設定、監視対象、証跡取得対象に含まれていなければ、担当作業への直接影響は小さいと考えられる。

ただし、以下に該当する場合は影響が出る可能性があるため、削除前に確認する。

- 削除予定VPCが、要件3.7のVPC Flow Logs有効化対象に含まれている
- 削除予定VPCに既存のVPC Flow Logsがあり、ログ保存先や保持方針を確認する必要がある
- VPC削除に伴うCloudTrailイベントが、4番台の監視設定や既存通知に反応する
- EventBridge Rule、CloudWatch Alarm、Teams、メール通知などでVPC変更を通知している
- 削除予定VPCが設計書、手順書、WBS、対象範囲一覧に残っている

## 影響が小さいと考える理由

CloudTrailのTrail、CloudWatch LogsのLog Group、CloudWatch Alarm、EventBridge Rule、GuardDuty Detectorは、多くの場合、アカウント単位またはリージョン単位で管理される。

VPCはネットワークの入れ物であり、VPC削除そのものがこれらの管理サービスを削除するわけではない。

一方で、VPC Flow LogsはVPC、Subnet、ENIなどのネットワーク対象に紐づくため、削除対象VPCと直接関係する。今回のクラウドセキュリティ対応で最も注意するべき点は、VPC Flow Logsと、削除イベントを検知する監視・通知である。

## 担当機能ごとの影響確認

| 担当領域 | 影響の可能性 | 確認理由 |
| :--- | :--- | :--- |
| CloudTrail | VPC削除、Subnet削除、Route Table変更、Security Group削除、NACL削除、Internet Gateway detach/deleteなどのイベントが記録される | 予定作業のイベントが、監視や通知の検知対象になる可能性があるため |
| CloudWatch Logs | VPC Flow LogsのLog Groupが残る、または今後ログが入らなくなる可能性がある | 残すログ、削除するログ、保持期間の判断が必要になるため |
| Metric Filter / CloudWatch Alarm | VPC変更系のMetric FilterやAlarmがある場合、削除作業を異常として検知する可能性がある | 予定作業による通知を障害・セキュリティインシデントと誤認しないため |
| EventBridge | VPC変更、Route変更、Security Group変更などを検知するRuleがある場合、別アカウント、メール、Teamsなどへ通知される可能性がある | 既存通知の有無と通知先を把握しておく必要があるため |
| GuardDuty | Detector自体には直接影響しにくいが、削除予定VPC内のEC2、ENI、通信に関するFindingが残る可能性がある | Findingの扱い、Archive方針、手順書への記載要否を判断するため |
| VPC Flow Logs | 削除予定VPCがFlow Logs対象の場合、ログ取得が停止する。削除後は対象として設定できない | 要件3.7の対象範囲から除外するか、削除前に証跡を取得するか判断するため |
| AWS Config | Configを利用している場合、VPC削除や関連リソース変更がConfiguration Itemとして記録される | 要件4.9のAWS Config変更監視や証跡確認に関係する可能性があるため |
| S3 Server Access Logging | 通常は直接影響しない | ただしVPC Endpoint経由でS3へアクセスしている業務がある場合、VPC削除は業務側に影響する可能性があるため |
| KMS / CMK | 通常は直接影響しない | ただしCloudTrail、CloudWatch Logs、S3ログの暗号化設計とは別途整合性確認が必要なため |
| SNS / メール / Teams通知 | VPC削除に伴う通知が飛ぶ可能性がある | 予定作業として扱う通知か、抑止・事前周知が必要か判断するため |

## インフラチームへ確認すること

| 確認事項 | 質問例 | 確認理由 |
| :--- | :--- | :--- |
| 削除対象の特定 | 削除予定のVPC ID、VPC名、アカウント、リージョン、環境区分を教えてください | クラウドセキュリティ対応の対象範囲と照合するため |
| 削除予定日 | 削除予定日、変更管理番号、作業時間帯、作業者、承認状況を教えてください | CloudTrailや通知で検知された場合に、予定作業として判断するため |
| 対象範囲からの除外可否 | このVPCは今回のクラウドセキュリティ対応の設定対象から除外してよいでしょうか | 削除予定のVPCに対してFlow Logsや監視設定を追加しないようにするため |
| VPC Flow Logsの有無 | 削除予定VPCにVPC Flow Logsは設定されていますか。保存先はCloudWatch Logsですか、S3ですか | 要件3.7に直接関係し、証跡取得や保持判断が必要になるため |
| Flow Logsの保存方針 | 削除前にFlow Logs設定、Log Group、S3保存先、保持期間の証跡を取得する必要はありますか | 削除後に現状確認できなくなる情報があるため |
| 既存通知の有無 | VPC変更、Route Table変更、Security Group変更、NACL変更を検知するEventBridge Rule、CloudWatch Alarm、Teams、メール通知はありますか | 削除作業で既存通知が発生する可能性を把握するため |
| 通知の扱い | 削除作業により通知が発生した場合、予定作業として扱ってよいでしょうか | 通知発生時の一次判断を明確にするため |
| 関連リソース | 削除対象VPCにEC2、RDS、ALB/NLB、Lambda VPC設定、VPC Endpoint、Private Hosted Zone、Transit Gateway、VPN、Peeringなどは残っていますか | 削除による業務影響や監視対象変更の有無を確認するため |
| GuardDuty Finding | 削除対象VPCや配下リソースに関連するGuardDuty Findingはありますか | 手順書でFinding確認やArchive判断が必要になる可能性があるため |
| AWS Config | VPC削除はAWS Configで記録されていますか。また関連するConfig Ruleや通知はありますか | 要件4.9との関係を確認するため |
| 設計書との整合 | 削除予定VPCは設計書、構成図、運用手順書、監視一覧に残っていますか | 削除後にドキュメントと実環境が不一致になることを防ぐため |
| 今回作業への反映 | 削除予定VPCはWBS、対象範囲一覧、手順書、テスト対象から除外してよいでしょうか | 作業計画と手順書に反映するため |

## チャットでの確認文例

以下のように確認すると、質問の意図が伝わりやすい。

```text
削除予定のVPCについて、私の担当しているクラウドセキュリティ対応への影響有無を確認させてください。

現時点では、VPC削除そのものがCloudTrail、CloudWatch、EventBridge、GuardDutyなどの管理サービスを停止させるものではないため、直接影響は小さいと考えています。

ただし、VPC Flow Logsの対象範囲、既存のEventBridge/CloudWatch通知、AWS Config記録、GuardDuty Finding、手順書・WBS上の対象範囲には影響する可能性があるため、以下を確認したいです。

1. 削除予定のVPC ID、アカウント、リージョン、環境区分
2. このVPCを今回のクラウドセキュリティ対応の対象範囲から除外してよいか
3. VPC Flow Logsの有無、保存先、削除前に証跡取得が必要か
4. VPC変更、Route Table変更、Security Group変更、NACL変更に関する既存通知があるか
5. 削除作業により通知が発生した場合、予定作業として扱ってよいか
6. 削除対象VPCに関連するGuardDuty Finding、AWS Config記録、監視設定、手順書の更新要否

上記を確認できれば、今回の作業対象一覧、手順書、テスト対象に反映します。
```

## 影響判定の目安

| 判定 | 条件 | 対応 |
| :--- | :--- | :--- |
| 影響なし | 削除予定VPCが今回の対象範囲外で、Flow Logs、既存通知、GuardDuty Finding、AWS Config確認に関係しない | WBSや対象範囲一覧に対象外として記録する |
| 軽微な影響あり | 削除イベントがCloudTrail、EventBridge、CloudWatch Alarm、Teams、メールなどに通知される | 予定作業として扱うことを事前共有する |
| 対応が必要 | 削除予定VPCがVPC Flow Logs有効化対象、監視設定対象、手順書上の対象に含まれている | 対象範囲、設計、手順、テストから除外または変更する |
| 要エスカレーション | 削除対象VPCに用途不明のEndpoint、Route、Peering、VPN、TGW、Private Hosted Zone、業務リソースが残っている | インフラチーム判断待ちとし、担当範囲だけで進めない |

## 担当作業への反映ポイント

- 要件3.7のVPC Flow Logs対象一覧から削除予定VPCを除外するか確認する
- 要件4.10から4.14の監視設定で、削除作業による通知が出る可能性を記録する
- 既存EventBridge Ruleがある場合、通知先と用途を確認する
- 削除予定VPCを手順書、テスト対象、WBS、エビデンス取得対象に含めるか決める
- 削除前後で構成図や設計書との差分が出る場合は、現場側へ更新要否を確認する

## ひとことで説明する場合

削除予定VPCは、CloudTrailやCloudWatchなどの管理サービス自体には直接影響しない想定です。ただし、VPC Flow Logs、既存通知、AWS Config記録、GuardDuty Finding、対象範囲一覧には影響する可能性があるため、削除対象VPCを今回のクラウドセキュリティ対応から除外してよいかをインフラチームへ確認します。
