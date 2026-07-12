# 要件A3/A4 セキュリティアラート監視運用手順書

作成日: 2026-07-10

この手順書は、要件A3/A4「セキュリティアラート監視の運用手順書があること」「セキュリティアラート監視が日々の運用で実施されていること」に対応するためのたたき台である。

最初に共有された評価シート由来のテキスト情報を正とし、A3/A4はAWS設定変更ではなく、運用手順、確認記録、エスカレーション、証跡整備を主な対応範囲として扱う。
確認作業はAWS Management Consoleを前提とし、CLIを使わずに実施できる内容とする。
公開リポジトリで扱うことを想定し、顧客名、案件名、会社名、具体的な環境名、AWSアカウントID、個人名、内部資料の正式名称は記載しない。

## 1. 要件整理

| 要件番号 | 要件 | 対応方針 |
|---|---|---|
| A3 | セキュリティアラートに関するモニタリング運用手順書があること | GuardDuty等のアラート確認、一次切り分け、エスカレーション、記録方法を手順書化する |
| A4 | セキュリティアラートに関するモニタリングが日々の運用で実施されていること | 日次または定期確認の記録、検知時の対応記録、レビュー証跡を残せるようにする |

A3は「手順書そのもの」、A4は「その手順に沿って運用した証跡」として整理する。

## 2. 対象範囲

本手順書では、元資料の指摘に合わせてGuardDutyのセキュリティアラート運用を主対象とする。
CloudWatch Alarm、EventBridge、SNS、メール、Teamsは、GuardDutyやCloudTrail系アラートの通知経路、既存連携、対応記録の確認観点として扱う。

| 対象 | 確認内容 |
|---|---|
| GuardDuty | Detector、Finding、Severity、Archive、Finding詳細、通知連携 |
| CloudWatch Alarm | セキュリティ関連Alarmの状態、通知Action、Alarm履歴 |
| EventBridge | GuardDutyやCloudTrailイベントの通知連携、自動対応、別アカウント送信 |
| SNS / メール / Teams | アラート通知先、購読状態、通知テスト可否 |
| 既存監視基盤 | SIEM、運用監視ツール、チケット管理、チャット通知 |
| 対応記録 | 日次確認記録、アラート対応記録、月次報告、レビュー記録 |

注意:

- GuardDutyだけを対象にするか、CloudWatch AlarmやEventBridge通知も含めるかは現場側に確認する。
- 自動隔離、自動無効化、自動チケット起票などがある場合は、影響が大きいため必ず別途確認する。
- 本手順書は運用手順のたたき台であり、実環境の正式な運用ルール、障害対応手順、インシデント対応規程を優先する。

## 3. 必要なドキュメント類

手順書作成前に、以下の資料の所在と最新版を確認する。

| ドキュメント | 必要な理由 | 確認観点 |
|---|---|---|
| セキュリティ運用設計書 | アラート監視の基本方針を確認するため | 対象サービス、監視頻度、重大度、対応時間 |
| 監視設計書 | 通知経路や監視対象を確認するため | CloudWatch Alarm、EventBridge、SNS、Teams、メール |
| インシデント対応手順書 | 検知後の判断、連絡、対応を合わせるため | 一次対応、二次対応、報告、クローズ条件 |
| エスカレーション一覧 | 連絡先と責任分界を明確にするため | 一次窓口、システム担当、セキュリティ担当、管理者 |
| 体制図または役割分担表 | 誰が確認し、誰が判断するかを明確にするため | 監視担当、確認担当、承認者、報告先 |
| AWSアカウント一覧 | 対象アカウント漏れを防ぐため | 本番、運用、開発、検証、管理アカウント |
| 対象リージョン一覧 | GuardDutyやCloudWatchはリージョン単位の確認が必要なため | 対象リージョン、除外リージョン |
| GuardDuty設定資料 | Detectorや保護プランの現状確認に必要 | Detector ID、Finding Publishing Frequency、Feature |
| CloudWatch Alarm一覧 | セキュリティアラート通知の確認に必要 | Alarm名、対象Metric、通知先、状態 |
| EventBridge Rule一覧 | 通知連携や自動対応の確認に必要 | Event Pattern、Target、別アカウント送信 |
| SNS Topic / Subscription一覧 | メールやTeams通知経路の確認に必要 | Topic、Subscription、Confirmed状態 |
| 既存月次確認資料 | A4の既存証跡として流用できるか確認するため | 実施日、確認者、対象、結果、指摘 |
| アラート対応記録 | 過去の運用実態を確認するため | 検知日時、内容、判断、対応、クローズ |
| 証跡保存ルール | 監査提出できる形を確認するため | 保存先、保存期間、ファイル形式、マスキング方針 |

## 4. 現場側に確認すること

### 4.1 運用範囲

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | A3/A4の対象はGuardDutyのみか、CloudWatch AlarmやEventBridge通知も含めるか | 手順書の対象範囲が変わるため |
| 2 | 対象環境は本番のみか、運用、開発、検証も含めるか | 記録対象と確認頻度が変わるため |
| 3 | 対象AWSアカウントと対象リージョンはどこまでか | 確認漏れを防ぐため |
| 4 | Organizations管理や管理アカウント側で確認するものがあるか | GuardDutyやOrganizations関連の確認に影響するため |
| 5 | 既存の月次確認をA4の証跡として流用してよいか | 新規運用を増やすか判断するため |

### 4.2 監視頻度と対応時間

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 日次確認が必要か、営業日のみか、月次確認で足りるか | A4の運用頻度を決めるため |
| 2 | 高SeverityのFindingは即時対応か、次回確認時対応か | SLAや対応優先度に影響するため |
| 3 | 夜間・休日の通知を誰が受けるか | 実運用できる通知設計にするため |
| 4 | 通知を受けた後、何分以内または何時間以内に一次確認するか | 手順書の判定基準に必要 |
| 5 | 対応不能時の代理担当や二次連絡先は誰か | 作業停滞を避けるため |

### 4.3 通知と記録

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | 通知先はメール、Teams、既存監視基盤、チケット管理のどれか | 手順書に通知確認方法を記載するため |
| 2 | 通知テストを実施してよいか | 実通知が飛ぶ可能性があるため |
| 3 | 対応記録はどこに保存するか | A4の証跡として必要 |
| 4 | 証跡はExcel、Markdown、チケット、PDF、画面キャプチャのどれで残すか | 監査提出形式を合わせるため |
| 5 | メールアドレス、Teams URL、個人名などのマスキング方針はあるか | 外部共有や証跡管理に必要 |

### 4.4 Findingの扱い

| No | 確認事項 | 理由 |
|---|---|---|
| 1 | GuardDuty FindingのArchive基準はあるか | 対応済み・対応不要の判断を統一するため |
| 2 | 誤検知や既知事象はどのように記録するか | 同じFindingの再調査を減らすため |
| 3 | FindingのSeverityごとの対応基準はあるか | 重要度に応じた対応を行うため |
| 4 | 対応不要と判断する場合の承認者は誰か | 判断責任を明確にするため |
| 5 | インシデント扱いにする条件は何か | エスカレーション判断に必要 |

## 5. 役割分担

現場の体制に合わせて、以下を埋める。

| 役割 | 主な作業 | 担当 |
|---|---|---|
| 一次確認者 | アラート確認、初期切り分け、記録作成 | 未定 |
| 二次確認者 | 技術調査、影響確認、対応方針整理 | 未定 |
| 承認者 | 対応不要判断、クローズ承認、運用手順承認 | 未定 |
| セキュリティ担当 | インシデント判断、外部報告要否判断 | 未定 |
| システム担当 | 対象リソースの業務影響確認 | 未定 |
| 運用担当 | 通知確認、チケット起票、定期確認 | 未定 |

## 6. 日次または定期確認手順

### 6.1 GuardDuty検出結果を確認する

1. AWS Management Consoleへログインする。
2. 対象アカウント、対象リージョンを確認する。
3. GuardDutyを開く。
4. `検出結果` または `Findings` を開く。
5. 未アーカイブのFindingを確認する。
6. Severityの高い順に並べる。
7. 以下を記録する。

| 記録項目 | 内容 |
|---|---|
| 確認日時 | 確認した日時 |
| 確認者 | 確認した担当者 |
| 対象アカウント | 確認対象 |
| 対象リージョン | 確認対象 |
| 未アーカイブFinding件数 | 件数 |
| High件数 | 件数 |
| Medium件数 | 件数 |
| Low件数 | 件数 |
| 要対応件数 | 件数 |
| 対応不要件数 | 件数 |
| 備考 | 補足 |

判定:

| 状態 | 判断 |
|---|---|
| 未アーカイブFindingなし | 異常なしとして記録する |
| Lowのみ | 内容を確認し、対応要否を記録する |
| Medium以上あり | 詳細確認し、必要に応じてエスカレーションする |
| Highあり | 速やかに二次確認者またはセキュリティ担当へ連絡する |

### 6.2 CloudWatch Alarmを確認する

1. CloudWatchを開く。
2. `アラーム` を開く。
3. セキュリティ関連Alarmを確認する。
4. `ALARM` 状態のものがないか確認する。
5. `INSUFFICIENT_DATA` が継続していないか確認する。
6. Alarm履歴を確認する。

確認項目:

| 項目 | 確認内容 |
|---|---|
| Alarm名 | セキュリティ監視対象か |
| State | OK / ALARM / INSUFFICIENT_DATA |
| State reason | 状態理由 |
| Actions enabled | 通知Actionが有効か |
| Alarm actions | 通知先 |
| Last state update | 最終更新日時 |

### 6.3 通知経路を確認する

メール、Teams、監視基盤、チケットのどれで通知されるかを確認する。

確認項目:

| 項目 | 確認内容 |
|---|---|
| 通知受信有無 | 期待どおり通知されているか |
| 通知時刻 | AlarmまたはFinding発生時刻と大きくずれていないか |
| 通知先 | 正しい宛先か |
| 通知内容 | 対象、重要度、リンク、対応先が分かるか |
| チケット起票 | 必要な場合、起票されているか |

## 7. アラート検知時の対応手順

### 7.1 一次確認

1. 通知またはGuardDuty Findingを確認する。
2. 発生日時、対象アカウント、対象リージョンを確認する。
3. Finding TypeまたはAlarm名を確認する。
4. 対象リソースを確認する。
5. Severityを確認する。
6. 同様のFindingまたはAlarmが過去に発生していないか確認する。
7. 業務予定作業、保守作業、変更作業と一致するか確認する。
8. 一次判断を記録する。

一次判断の分類:

| 分類 | 意味 |
|---|---|
| 要対応 | 不審または影響が否定できない |
| 要確認 | 担当者、運用資料、変更予定との突合が必要 |
| 対応不要 | 既知事象、検証、予定作業、誤検知と判断できる |
| 対象外 | 対象外環境または対象外リソース |

### 7.2 二次確認

必要に応じて以下を確認する。

| 確認対象 | 確認内容 |
|---|---|
| CloudTrail | 誰が、いつ、どのAPIを実行したか |
| 対象リソース | EC2、IAM、S3、VPC、KMS等の設定状態 |
| 変更管理 | 予定された作業か |
| 通信ログ | VPC Flow Logs、ALBログ、WAFログ等 |
| 認証情報 | IAM User、Role、Access Key、SSO利用状況 |
| 関連アラート | 同時刻に他のFindingやAlarmがないか |

### 7.3 エスカレーション

以下に該当する場合、二次確認者またはセキュリティ担当へエスカレーションする。

| 条件 | 対応 |
|---|---|
| High SeverityのFinding | 即時エスカレーション |
| rootアカウント使用 | 正当性確認。予定外ならエスカレーション |
| IAM権限変更 | 変更予定との突合。予定外ならエスカレーション |
| KMSキー無効化・削除予約 | 暗号化データへの影響があるためエスカレーション |
| CloudTrail停止・削除 | 監査ログ欠落リスクがあるためエスカレーション |
| Security Group、NACL、Route変更 | 通信影響や公開リスクを確認 |
| 対応要否を判断できない | 自己判断でクローズせずエスカレーション |

## 8. クローズ条件

アラート対応は、以下を満たした場合にクローズする。

| 条件 | 内容 |
|---|---|
| 原因確認済み | 予定作業、既知事象、誤検知、要対応のいずれかが判断済み |
| 影響確認済み | 対象リソース、業務影響、セキュリティ影響を確認済み |
| 対応記録済み | 対応記録に必要事項を記載済み |
| 必要なエスカレーション済み | 必要な関係者へ連絡済み |
| 承認済み | 対応不要またはクローズ判断が承認済み |
| 証跡保存済み | Finding詳細、Alarm履歴、通知、調査結果を保存済み |

## 9. 対応記録テンプレート

Excelへ貼り付ける場合は、以下のTSVを使用する。

```tsv
記録ID	アラート発生日時	確認日時	確認者	対応者	対象アカウント	対象リージョン	検知元	アラート名/Finding Type	Severity	対象リソース	通知経路	一次判断	調査内容	原因	実施内容	エスカレーション先	完了日時	クローズ判断	承認者	証跡保存先	備考
ALERT-YYYYMMDD-001	YYYY-MM-DD HH:MM	YYYY-MM-DD HH:MM	未定	未定	未定	未定	GuardDuty	未定	未定	未定	メール/Teams	未確認	未記入	未記入	未記入	未定	YYYY-MM-DD HH:MM	未確認	未定	未定	
```

日次確認記録として残す場合は、以下を使用する。

```tsv
確認日	確認時刻	確認者	対象アカウント	対象リージョン	GuardDuty未アーカイブ件数	High件数	Medium件数	Low件数	CloudWatch Alarm件数	ALARM状態件数	通知異常有無	要対応件数	対応記録ID	備考
YYYY-MM-DD	HH:MM	未定	未定	未定	0	0	0	0	未確認	0	なし	0		
```

## 10. A3/A4の成果物

| 成果物 | 内容 |
|---|---|
| セキュリティアラート監視運用手順書 | 本手順書を現場ルールに合わせて正式化したもの |
| 日次確認記録テンプレート | A4の運用証跡として使う記録様式 |
| アラート対応記録テンプレート | FindingやAlarm検知時の対応記録 |
| エスカレーション一覧 | 連絡先、担当、承認者 |
| 証跡サンプル | GuardDuty画面、Alarm画面、通知メール/Teams、対応記録 |
| 運用試験記録 | 手順に沿って確認、記録、エスカレーション判断ができることを確認した結果 |
| レビュー記録 | 手順書の確認者、指摘、反映結果 |

## 11. 最低限必要な参照権限

手順書作成と現状確認に必要な参照権限の例。

| サービス | 主な参照権限 |
|---|---|
| STS | `sts:GetCallerIdentity` |
| GuardDuty | `guardduty:ListDetectors`, `guardduty:GetDetector`, `guardduty:ListFindings`, `guardduty:GetFindings`, `guardduty:GetFindingsStatistics` |
| CloudWatch | `cloudwatch:DescribeAlarms`, `cloudwatch:DescribeAlarmHistory` |
| CloudWatch Logs | `logs:DescribeLogGroups`, `logs:DescribeMetricFilters`, `logs:FilterLogEvents`, `logs:StartQuery`, `logs:GetQueryResults` |
| EventBridge | `events:ListRules`, `events:DescribeRule`, `events:ListTargetsByRule`, `events:ListEventBuses` |
| SNS | `sns:ListTopics`, `sns:ListSubscriptionsByTopic`, `sns:GetTopicAttributes` |
| CloudTrail | `cloudtrail:LookupEvents`, `cloudtrail:DescribeTrails`, `cloudtrail:GetTrail` |

注意:

- FindingのArchive、通知設定変更、Alarm変更などは変更権限であり、本手順書作成段階では原則不要。
- 現場ルールにより、画面閲覧だけで進める場合はCLI権限は不要なこともある。

## 12. 完了条件

A3/A4の完了条件は以下。

| 要件 | 完了条件 |
|---|---|
| A3 | セキュリティアラート監視運用手順書が作成され、レビュー済みである |
| A4 | 日次または定期確認の記録様式があり、サンプル記録または既存運用証跡で実施実態を説明できる |

具体的には以下を満たすこと。

- 対象アラート範囲が明確である
- 確認頻度が明確である
- 一次確認者、二次確認者、承認者が明確である
- エスカレーション条件が明確である
- 対応記録の保存先が明確である
- 証跡形式が明確である
- 既存月次資料を流用するか、新規日次記録を作成するか判断済みである
- 運用試験を実施し、手順と記録様式に不足がないことを確認済みである
- 手順書レビュー担当が確認済みである

## 13. 参考

- Amazon GuardDuty User Guide
  - English: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/what-is-guardduty.html
- GuardDuty findings
  - English: https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings.html
- Amazon CloudWatch alarms
  - English: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
- Amazon EventBridge event patterns
  - English: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html
  - 日本語: https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-event-patterns.html
