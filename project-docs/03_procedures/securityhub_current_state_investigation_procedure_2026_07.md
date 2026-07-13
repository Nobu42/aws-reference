# Security Hub現状確認手順書

作成日: 2026-07-14

この手順書は、クラウドセキュリティ対応において、改善計画Excelには記載がないが、セキュリティ設計書に記載があるSecurity Hubについて、既存設定との整合を確認するための手順である。

本手順の目的は、Security Hubを新たな改善対象として追加することではない。A3/A4、GuardDuty、EventBridge、CloudWatch Alarm、通知設定との重複や連携有無を確認し、今回対応へ影響するかを判断することである。

## 1. 位置づけ

Security Hubは、AWS環境のセキュリティ検出結果やセキュリティ標準評価を集約するサービスである。

今回の改善計画ExcelにはSecurity Hubの直接記載がないため、原則としてSecurity Hub自体の設定変更は対象外とする。

ただし、セキュリティ設計書にSecurity Hubの記載がある場合、以下の理由で確認対象となる。

| 確認理由 | 内容 |
| :--- | :--- |
| GuardDuty連携 | A3/A4のGuardDuty運用手順で、Security Hub側のFinding確認が必要になる可能性がある |
| EventBridge通知 | Security Hub FindingをEventBridgeで通知している場合、今回追加する通知と重複する可能性がある |
| 既存通知経路 | メール、Teams、チケット起票、SIEM連携がSecurity Hub経由で存在する可能性がある |
| Automation Rule | Findingの抑制、重要度変更、Workflow更新が自動化されている可能性がある |
| 設計書差分 | 改善計画Excelとセキュリティ設計書の記載差分を確認事項として残す必要がある |

## 2. 関係する要件番号

Security Hubは改善計画Excel上の主担当要件ではないが、以下の要件と関係する可能性がある。

| 要件番号 | 関係 |
| :--- | :--- |
| A3 | GuardDuty異常検知後の確認手順、判断基準、対応手順と関係する可能性がある |
| A4 | GuardDutyイベント調査エビデンスの確認先として関係する可能性がある |
| 4.1から4.15 | CloudTrail系イベント監視とSecurity Hub/EventBridge通知が重複する可能性がある |
| 4.8 | S3バケットポリシー変更監視と、Security Hub側のS3関連FindingやEventBridge通知が混同される可能性がある |
| 4.10から4.14 | Security Group、NACL、Gateway、Route Table、VPC変更監視と、Security Hub標準チェックやFindingが運用上重なる可能性がある |

3番台のS3ログ、KMS、VPC Flow Logsとは直接関係は薄い。ただし、Security Hubの標準チェックやAWS Config経由で関連指摘が出ている可能性はある。

## 3. リーダーへの確認方針

リーダーへの確認は、作業範囲追加の相談ではなく、既存設計との整合確認として行う。

### 3.1 短い確認文案

```text
改善計画ExcelにはSecurity Hubの記載はありませんが、セキュリティ設計書にはSecurity Hubの記載がありました。

今回のクラウドセキュリティ対応ではSecurity Hub自体は対象外と理解していますが、
A3/A4のGuardDuty運用手順や4番台の通知設定と重複・連携がないかだけ確認しておきたいです。

Security Hub側のFinding集約、EventBridge通知、Automation Ruleの有無を確認対象に含めてよいでしょうか。
```

### 3.2 もう少し詳細に確認する場合

```text
Security Hubについて確認させてください。

改善計画Excel上は直接の対応要件がないため、Security Hub自体の設定変更は対象外と考えています。
一方で、セキュリティ設計書にはSecurity Hubの記載があり、GuardDutyやEventBridge通知と関係する可能性があります。

今回の調査では、以下のみ確認する方針で問題ないでしょうか。

・Security Hubが有効か
・対象アカウント、対象リージョン
・GuardDuty Findingを取り込んでいるか
・Security Hub Findingを拾うEventBridge Ruleがあるか
・既存のメール、Teams、チケット通知と今回追加予定の通知が重複しないか
・Automation Ruleや抑制設定があるか

Security Hubの設定変更や新規有効化は、明示的な指示がない限り実施しない想定です。
```

### 3.3 リーダーに確認する項目

| No. | 確認事項 | 理由 |
| :--- | :--- | :--- |
| 1 | Security Hubは今回の正式な対応対象に含めるか | 改善計画Excelに記載がないため |
| 2 | 確認だけ行う範囲でよいか | 作業範囲の膨張を防ぐため |
| 3 | 対象アカウント、対象リージョン | Security Hubはアカウント・リージョン単位で確認が必要なため |
| 4 | Security Hub管理者アカウントの有無 | Organizations配下では管理者アカウントで集約している可能性があるため |
| 5 | GuardDuty FindingをSecurity Hubに集約しているか | A3/A4の確認手順に影響するため |
| 6 | Security Hub FindingをEventBridgeで通知しているか | 4番台の通知と重複する可能性があるため |
| 7 | 通知先はメール、Teams、チケット、SIEMのどれか | 既存通知経路を把握するため |
| 8 | Automation Ruleや抑制ルールを誰が管理しているか | Findingの表示や通知に影響するため |
| 9 | Security Hubの確認結果をエビデンスに含めるか | 成果物範囲を明確にするため |
| 10 | 設計書と現行設定が違う場合の扱い | 設計書更新、別管理、現状優先のどれかを判断するため |

## 4. 事前に確認する資料

| 資料 | 確認内容 |
| :--- | :--- |
| 改善計画Excel | Security Hubが正式要件に含まれていないこと |
| セキュリティ設計書 | Security Hubの記載箇所、対象アカウント、対象リージョン |
| GuardDuty設計・運用資料 | Findingの確認先、通知先、運用手順 |
| EventBridge設計資料 | Security Hub Findingを拾うRuleの有無 |
| 通知設計資料 | SNS、メール、Teams、Chatbot、チケット連携 |
| AWSアカウント一覧 | 開発、検証、本番、運用、管理アカウントの範囲 |
| リージョン一覧 | 東京リージョンのみか、他リージョンも対象か |
| 運用手順書 | Security Hub Findingを誰が確認しているか |
| 権限一覧 | WebコンソールでSecurity Hub、EventBridge、SNSを閲覧できるか |

## 5. 必要な閲覧権限

Webコンソールでの現状確認には、最低限以下の閲覧権限が必要となる。

| AWSサービス | 必要な理由 |
| :--- | :--- |
| Security Hub | 有効化状況、Finding、統合、Automation Rule、設定確認 |
| GuardDuty | Security Hubとの連携元確認 |
| EventBridge | Security Hub Findingを拾うRule確認 |
| SNS | 通知先Topic、Subscription確認 |
| CloudWatch | AlarmやLogsとの通知重複確認 |
| AWS Chatbot / Amazon Q Developer in chat applications | TeamsやSlack通知の経路確認 |
| IAM ReadOnly | Security Hubサービスロールや連携ロール確認 |
| AWS Organizations ReadOnly | 管理者アカウント、メンバーアカウント確認 |

設定変更権限は不要である。今回のSecurity Hub確認は、原則として閲覧のみで実施する。

## 6. Webコンソール調査手順

### 6.1 対象環境を記録する

以下を作業メモに記録する。

| 項目 | 記録内容 |
| :--- | :--- |
| 確認日 | 作業日 |
| 確認者 | 作業者名 |
| AWSアカウント名 | 表示されるアカウント名 |
| AWSアカウントID | 可能な範囲で記録 |
| リージョン | 例: ap-northeast-1 |
| 環境 | 開発、検証、本番、運用など |
| 参照資料 | セキュリティ設計書、改善計画Excelなど |

### 6.2 Security Hubが有効か確認する

1. AWSマネジメントコンソールへログインする
2. 対象リージョンを選択する
3. Security Hubを開く
4. Security Hubが有効か確認する
5. 有効でない場合は、画面上の状態を記録する

記録する項目:

| 項目 | 見る内容 |
| :--- | :--- |
| Security Hub有効化状況 | 有効 / 無効 |
| 対象リージョン | 現在表示しているリージョン |
| ホームリージョン | クロスリージョン集約がある場合の集約先 |
| 使用状況 | 有効化範囲、利用状況、料金影響 |

注意:

- Security Hubが無効でも、改善計画Excel上の直接要件ではないため、その場で有効化しない。
- 無効の場合は「設計書には記載あり、現行は未使用の可能性」として確認事項にする。

### 6.3 管理者アカウントとメンバーアカウントを確認する

Security Hubの設定画面、アカウント管理画面を確認する。

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| 管理者アカウント | 設定変更主体を確認するため |
| メンバーアカウント | 対象環境が集約対象に含まれているか確認するため |
| Organizations統合 | 一元管理されているか確認するため |
| 中央設定 | 個別アカウントで設定変更してよいか判断するため |

判断:

- 管理者アカウントが存在する場合、個別アカウント側での設定変更は原則避ける。
- 調査結果は「どのアカウントで確認したか」を明記する。

### 6.4 クロスリージョン集約を確認する

Security Hubの設定から、クロスリージョン集約の有無を確認する。

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| ホームリージョン | FindingやControl結果の集約先を確認する |
| リンクリージョン | どのリージョンが集約対象か確認する |
| 東京リージョンの扱い | 対象システムの主要リージョンと合っているか確認する |

注意:

- クロスリージョン集約がある場合、各リージョンとホームリージョンの両方で見え方を確認する。
- Security Hubが有効でないリージョンは集約されない。

### 6.5 統合サービスを確認する

Security Hubの「統合」画面を確認する。

特に以下を確認する。

| 統合 | 確認理由 |
| :--- | :--- |
| GuardDuty | A3/A4と直接関係する可能性がある |
| Inspector | 脆弱性管理と関係する可能性がある |
| Macie | S3データ保護と関係する可能性がある |
| IAM Access Analyzer | IAMやS3公開状態と関係する可能性がある |
| AWS Config | Security Hub Control評価の前提になる可能性がある |
| 外部製品 | SIEMやチケット連携と関係する可能性がある |

記録する項目:

| 項目 | 内容 |
| :--- | :--- |
| 統合名 | GuardDutyなど |
| 有効 / 無効 | 統合状態 |
| Finding取り込み有無 | 取り込み中か |
| 関係する要件 | A3/A4、4番台など |

### 6.6 GuardDuty Findingの取り込みを確認する

Security HubのFinding画面で、GuardDuty由来のFindingがあるか確認する。

フィルター例:

| フィルター | 値 |
| :--- | :--- |
| Product name | GuardDuty |
| Record state | Active |
| Workflow status | New / Notified / Resolved |
| Severity | Critical / High / Medium |

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| GuardDuty Findingが存在するか | A3/A4の確認先になる可能性がある |
| Severity | 対応優先度に関係する |
| Workflow status | 運用上の処理状態を確認する |
| Record state | Active / Archivedの扱いを確認する |
| Updated at | 継続発生か過去発生か確認する |

判断:

- GuardDuty FindingがSecurity Hubに入っている場合、A3/A4の手順書に「Security Hub側も確認するか」を確認事項として追加する。
- GuardDuty FindingがSecurity Hubにない場合、GuardDutyコンソール側が主確認先となる可能性が高い。

### 6.7 Automation Ruleを確認する

Security Hubの「自動化」またはAutomation Rule画面を確認する。

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| Rule名 | 既存ルールの識別 |
| 条件 | どのFindingに作用するか |
| 実行内容 | Severity変更、Workflow変更、抑制、メモ追加など |
| 対象製品 | GuardDuty、Security Hub Controlなど |
| 有効 / 無効 | 現在動いているか |
| 管理者 | 誰が管理しているか |

注意:

- Automation Ruleは通知ではなく、Findingの状態や重要度を変更する場合がある。
- A3/A4でFinding確認手順を作る場合、Automation Ruleの存在により表示状態が変わる可能性がある。

### 6.8 EventBridge Ruleを確認する

EventBridgeコンソールを開き、Security Hub関連Ruleを確認する。

確認するEvent Patternの例:

```json
{
  "source": ["aws.securityhub"],
  "detail-type": ["Security Hub Findings - Imported"]
}
```

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| Rule名 | 既存通知の識別 |
| Event bus | defaultか、別Event busか |
| source | `aws.securityhub` か確認する |
| detail-type | `Security Hub Findings - Imported` か確認する |
| detail条件 | Severity、ProductName、Complianceなどで絞っているか |
| Target | SNS、Lambda、SQS、Step Functions、別アカウントEvent busなど |
| 有効 / 無効 | 現在通知・自動処理されているか |

注意:

- Security Hub FindingをEventBridgeで拾って通知している場合、4番台で追加するCloudWatch Alarm通知と重複する可能性がある。
- TargetがLambdaやStep Functionsの場合、自動対応が動く可能性があるため、内容を確認する。
- Targetが別アカウントEvent busの場合、通知や集約先をインフラチームに確認する。

### 6.9 通知先を確認する

EventBridgeのTargetから通知先をたどる。

確認する候補:

| 通知先 | 確認内容 |
| :--- | :--- |
| SNS Topic | Topic名、Subscription、通知先メール |
| AWS Chatbot / Amazon Q Developer in chat applications | Teams / Slack連携先 |
| Lambda | 通知整形、自動対応、チケット起票 |
| SQS | 後続処理キュー |
| Step Functions | 自動対応フロー |
| 別アカウントEvent bus | 監視基盤やSIEM連携 |
| 外部SIEM | Splunk、ServiceNow、Teams Webhookなど |

記録する項目:

| 項目 | 内容 |
| :--- | :--- |
| 通知元 | Security Hub / GuardDuty / CloudWatch Alarm |
| 経路 | EventBridge -> SNSなど |
| 通知先 | メール、Teams、チケットなど |
| 対象イベント | GuardDuty Finding、Security Hub Control Failedなど |
| 今回対応との重複 | あり / なし / 要確認 |

### 6.10 Security StandardsとControlを確認する

Security Hubの「セキュリティ標準」「コントロール」を確認する。

確認項目:

| 項目 | 確認理由 |
| :--- | :--- |
| 有効な標準 | AWS Foundational Security Best Practices、CISなど |
| Failed Control | 既存のセキュリティ指摘を確認する |
| 無効化Control | 例外管理や対象外判断を確認する |
| Control結果 | 今回の改善計画と重なる指摘があるか確認する |

注意:

- 改善計画ExcelにないControl不合格を勝手に是正対象へ追加しない。
- 今回対応と重なる場合は、参考情報として記録し、リーダーへ確認する。

## 7. 調査結果の判断基準

| 状態 | 判断 |
| :--- | :--- |
| Security Hubが無効 | 設計書記載との差分として記録。今回対象に含めるか確認 |
| Security Hubは有効だがGuardDuty統合なし | A3/A4への影響は限定的。設計書の意図を確認 |
| GuardDuty統合あり | A3/A4手順でSecurity Hub側を確認対象に含めるか確認 |
| Security Hub EventBridge通知あり | 4番台通知と重複しないか確認 |
| Automation Ruleあり | Findingの表示・通知・重要度変更に影響するため記録 |
| 別アカウントEvent bus連携あり | 監視基盤やインフラチーム管理の可能性があるため確認 |
| Security StandardsのFailed Controlあり | 今回要件と重なる場合のみ確認事項化 |

## 8. 成果物に残す内容

Security Hub調査結果は、以下の形で残す。

| 項目 | 記載内容 |
| :--- | :--- |
| 調査目的 | 改善計画Excelには未記載だが、設計書に記載があるため整合確認 |
| 対象範囲 | アカウント、リージョン、環境 |
| Security Hub状態 | 有効 / 無効 |
| 管理方式 | 管理者アカウント、メンバーアカウント、中央設定 |
| GuardDuty統合 | あり / なし |
| EventBridge通知 | あり / なし |
| 通知先 | メール、Teams、チケット、SIEMなど |
| Automation Rule | あり / なし |
| 今回要件への影響 | A3/A4、4番台通知との関連 |
| 判断 | 対象外、参考確認、手順書へ反映、要確認 |
| 未確認事項 | リーダー、インフラチーム、運用チームへの確認事項 |

## 9. スクリーンショット取得候補

| No. | 画面 | 目的 |
| :--- | :--- | :--- |
| 1 | Security Hub概要 | 有効化状況確認 |
| 2 | Security Hub設定 | 管理者、リージョン集約、中央設定確認 |
| 3 | 統合画面 | GuardDuty連携有無確認 |
| 4 | Finding一覧 | GuardDuty Finding取り込み確認 |
| 5 | Automation Rule一覧 | 自動処理確認 |
| 6 | EventBridge Rule一覧 | Security Hub通知確認 |
| 7 | EventBridge Rule詳細 | Event PatternとTarget確認 |
| 8 | SNS Topic / Chatbot連携 | 通知先確認 |
| 9 | Security Standards | 標準とControl確認 |
| 10 | 使用状況 | 料金・利用範囲確認 |

ファイル名例:

```text
SecurityHub_01_概要_有効化状況.png
SecurityHub_02_設定_管理者リージョン集約.png
SecurityHub_03_統合_GuardDuty連携.png
SecurityHub_04_Findings_GuardDuty.png
SecurityHub_05_AutomationRule一覧.png
SecurityHub_06_EventBridge_SecurityHubRule一覧.png
SecurityHub_07_EventBridge_Target詳細.png
```

## 10. 現場向けまとめ文

調査後の報告文例:

```text
Security Hubは改善計画Excel上の直接要件ではありませんが、セキュリティ設計書に記載があるため、既存設定との整合確認として確認しました。

確認観点は、GuardDuty Findingの集約有無、Security Hub Findingを起点とするEventBridge通知、Automation Rule、既存通知先との重複有無です。

現時点ではSecurity Hub自体の設定変更は行わず、A3/A4および4番台通知設定へ影響する箇所のみ確認事項として整理します。
```

## 11. 参照資料

| 資料 | 用途 |
| :--- | :--- |
| [AWS公式ドキュメント Security Hub要約](../04_references/aws_official_docs_securityhub_summary.md) | Security Hubの概念、機能、確認観点 |
| [AWS公式ドキュメント GuardDuty要約](../04_references/aws_official_docs_guardduty_summary.md) | GuardDuty FindingとSecurity Hub連携の確認 |
| [AWS公式ドキュメント EventBridge要約](../04_references/aws_official_docs_eventbridge_summary.md) | Security Hub Finding通知の確認 |
| [要件A3/A4 セキュリティアラート監視運用手順書](./requirements_A3_A4_security_alert_monitoring_operation_procedure_2026_07.md) | GuardDuty運用手順との整合 |
| [通知設計・通知先一覧・通知テスト手順](./notification_design_and_test_plan_2026_07.md) | 既存通知との重複確認 |
