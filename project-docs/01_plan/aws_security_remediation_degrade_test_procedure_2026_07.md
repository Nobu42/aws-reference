# AWSセキュリティ監査指摘対応 デグレードテスト手順書

作成日: 2026-07-10

この手順書は、監査指摘対応の設定反映後に、既存のログ取得、監視、通知、運用確認が壊れていないことを確認するためのデグレードテスト手順である。
最初に共有された評価シート由来の情報を正とし、対象は主にCloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、通知、S3 Server Access Logging、KMS CMK、VPC Flow Logs、GuardDuty運用手順とする。

本手順書はAWS Management Consoleでの確認を前提とし、CLIを使わずに実施できる内容として整理する。

## 1. デグレードテストの目的

デグレードテストとは、今回の変更によって、既存の機能や運用が悪化していないことを確認するテストである。

今回の案件では、業務アプリケーションそのものではなく、監視、ログ、通知、KMS、Flow Logsなど周辺基盤の変更が中心である。
そのため、以下を確認する。

| 確認対象 | 確認したいこと |
|---|---|
| 既存ログ | CloudTrail、CloudWatch Logs、S3ログ、VPC Flow Logsが継続して取得できること |
| 既存通知 | 既存メール、Teams、EventBridge、SNS通知が止まっていないこと |
| 新規通知 | 新規Alarmが期待した条件で通知し、不要な大量通知を出さないこと |
| ログ参照 | 運用者が必要なログを参照できること |
| KMS | CloudTrailログ配送とログ参照に影響がないこと |
| 運用 | GuardDuty確認、月次確認、対応記録と矛盾しないこと |
| 費用・ログ量 | 想定外のログ量増加や費用増加がないこと |

## 2. 実施タイミング

WBS上は、8月後半のリリース準備工程で実施する想定である。

| フェーズ | 実施内容 |
|---|---|
| 変更前 | 既存状態をベースラインとして記録する |
| 変更直後 | 新規設定が期待どおり作成され、既存設定が消えていないことを確認する |
| テスト通知後 | 通知、Alarm履歴、ログ出力を確認する |
| 一定時間経過後 | CloudTrail、S3ログ、VPC Flow Logsなど遅延配送されるログを確認する |
| レビュー前 | 証跡、結果、未解決事項を整理する |

注意:

- CloudTrail、S3 Server Access Logging、VPC Flow Logsは配送に時間がかかる場合がある。
- 通知テストはメールやTeamsへ実通知が飛ぶため、事前承認を取る。
- 本番環境で意図的な危険操作を行わない。必要な場合は検証環境や承認済みの安全な手順で行う。

## 3. 事前に準備するもの

| 項目 | 内容 |
|---|---|
| 対象アカウント一覧 | 本番、運用、開発、検証、管理アカウントなど |
| 対象リージョン一覧 | CloudTrail、GuardDuty、CloudWatch、VPCの確認対象 |
| 対象Trail一覧 | CloudTrail Trail名、Home Region、S3保存先、CloudWatch Logs連携先 |
| 対象Log Group一覧 | CloudTrail連携先、VPC Flow Logs保存先 |
| 対象Alarm一覧 | 新規作成分と既存分 |
| 通知先一覧 | SNS、メール、Teams、EventBridge、別アカウント連携 |
| KMSキー一覧 | CloudTrailログ暗号化に使うCMK、Key Policy、Rotation状態 |
| S3ログ保存先 | CloudTrailログ保存先、Server Access Logging保存先 |
| VPC一覧 | Flow Logs有効化対象 |
| 証跡保存先 | 画面キャプチャ、確認結果、テスト結果の保存先 |

## 4. 変更前ベースライン取得

目的:
変更後に「既存設定が壊れていない」と比較できるようにする。

### 4.1 CloudTrail

確認手順:

1. AWS Management ConsoleでCloudTrailを開く。
2. 対象Trailを開く。
3. 以下を確認する。

| 確認項目 | 変更前に記録する内容 |
|---|---|
| Trail名 | 対象Trail名 |
| Logging | 有効か |
| Multi-Region | 有効か |
| Management events | 有効か |
| S3保存先 | バケット名、Prefix |
| CloudWatch Logs連携 | Log Group、IAM Role |
| KMS key | 設定有無、Key ID |
| Log file validation | 有効か |

取得する証跡:

- Trail詳細画面
- Event selectors画面
- S3保存先画面
- CloudWatch Logs連携設定画面

### 4.2 CloudWatch Logs / Metric Filter / Alarm

確認手順:

1. CloudWatchを開く。
2. CloudTrail連携先Log Groupを開く。
3. Metric filtersを開く。
4. Alarm一覧を開く。

| 確認項目 | 変更前に記録する内容 |
|---|---|
| Log Group | 名前、Retention、KMS、Stored bytes |
| Metric Filter | Filter名、Pattern、Metric namespace、Metric name |
| Alarm | Alarm名、Metric、Threshold、Actions enabled、通知先 |
| Alarm状態 | OK、ALARM、INSUFFICIENT_DATA |

取得する証跡:

- Log Group詳細
- Metric Filter一覧
- Alarm一覧
- 既存Alarm詳細

### 4.3 通知経路

確認手順:

1. SNS Topic一覧を確認する。
2. Subscriptionを確認する。
3. EventBridge Rule一覧を確認する。
4. 既存Teams通知やメール通知の運用資料を確認する。

| 確認項目 | 変更前に記録する内容 |
|---|---|
| SNS Topic | Topic名、用途 |
| Subscription | Protocol、Endpoint、Confirmed状態 |
| EventBridge Rule | Rule名、Event pattern、Target |
| Teams通知 | 通知経路、管理者、通知テスト可否 |
| メール通知 | 宛先、グループ、通知テスト可否 |

取得する証跡:

- SNS Topic一覧
- Subscription一覧
- EventBridge Rule一覧
- Event pattern
- Target一覧

## 5. 変更後確認

目的:
設定反映後に、期待した設定が入り、既存設定が失われていないことを確認する。

### 5.1 新規監視設定

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| Metric Filterが作成されている | 対象Log GroupにFilterが存在する | 作成漏れ、対象Log Group誤り、権限不足 |
| Filter Patternが設計どおり | 対象イベントのみ拾う条件になっている | Pattern誤り、イベント名誤り、JSON項目誤り |
| Metricが作成されている | Namespace、Metric nameが設計どおり | Metric transformation設定漏れ |
| Alarmが作成されている | 対象Metricに紐づいている | Metric名誤り、Namespace誤り |
| Alarm actionが有効 | Actions enabledが有効 | Action無効、SNS未設定 |
| 通知先が正しい | 設計したSNS、メール、Teamsに向いている | Topic誤り、Subscription未承認、EventBridge Target誤り |

### 5.2 既存設定

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| 既存Metric Filterが残っている | 変更前と同じFilterが存在する | 誤削除、Log Group誤認 |
| 既存Alarmが残っている | 変更前と同じAlarmが存在する | 誤削除、名前変更、無効化 |
| 既存通知が残っている | 既存SNS/EventBridge/Teams連携が残っている | Target変更、Subscription削除、Rule無効化 |
| 既存Alarm状態が異常化していない | OKまたは想定状態 | Metric欠落、Missing data設定、誤Pattern |

## 6. 通知デグレードテスト

目的:
既存通知が止まらず、新規通知が期待どおりで、不要な大量通知が出ないことを確認する。

確認手順:

1. 通知テスト実施可否の承認を確認する。
2. テスト対象Alarmを確認する。
3. テスト方法を確認する。
4. 通知が届くことを確認する。
5. Alarm historyに履歴が残ることを確認する。
6. 不要な通知が連続発生していないことを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| メール通知 | 期待した宛先へ届く | Subscription未承認、Topic誤り、迷惑メール振り分け |
| Teams通知 | 期待したチャネルへ届く | 連携先誤り、Webhook/Connector設定不備、EventBridge Target誤り |
| SNS | Topicに正しいSubscriptionがある | Subscription未承認、Endpoint誤り |
| EventBridge | Ruleが有効でTargetが正しい | Rule無効、Pattern誤り、Target権限不足 |
| 通知量 | 想定回数のみ通知される | Filter Patternが広すぎる、Alarm評価期間が短すぎる |

注意:

- 通知テストで実通知を出す場合、事前に通知先へ周知する。
- 本番で危険なAPI操作を発生させるテストは行わない。
- 可能であれば検証環境、サンプルログ、手動Alarm状態変更など承認済みの安全な方法で確認する。

## 7. CloudTrailデグレードテスト

目的:
CloudTrailのログ記録、S3配送、CloudWatch Logs連携が変更後も継続していることを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| Trail Logging | Loggingが有効 | StopLogging、Trail誤選択 |
| Latest delivery | 直近配送時刻が更新される | S3権限不足、KMS権限不足、配送遅延 |
| S3ログ配送 | S3に新しいCloudTrailログが作成される | Bucket Policy不備、KMS Key Policy不備 |
| CloudWatch Logs連携 | Log Groupにイベントが届く | CloudTrail CloudWatch Logs Role権限不足 |
| Event selectors | Management eventsが有効 | Event selector変更漏れ、誤設定 |

取得する証跡:

- Trail status画面
- CloudTrail S3ログ保存先の新規オブジェクト
- CloudWatch LogsのLog Stream更新
- Event selectors画面

## 8. KMS CMKデグレードテスト

目的:
CloudTrailログをCMK暗号化しても、ログ配送とログ参照に影響がないことを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| KMS key状態 | Enabled | Key無効化、削除予約 |
| Key type | Symmetric | 非対応キー種別 |
| Key policy | CloudTrailがEncrypt/GenerateDataKeyできる | CloudTrail Service Principal許可不足 |
| Trail KMS設定 | 対象CMKが設定されている | Key ID誤り、別リージョンKey |
| S3ログ配送 | CloudTrailログが継続配送される | KMS権限不足、S3権限不足 |
| ログ参照 | 運用者がログを参照できる | kms:Decrypt不足、Role未許可 |
| Rotation | 要件に応じて有効 | Rotation未設定 |

特に注意する原因:

- Key PolicyにCloudTrail用の許可がない。
- `aws:SourceArn` 条件のTrail ARNが誤っている。
- ログ調査担当のRoleに `kms:Decrypt` がない。
- CMKのリージョンとTrailのHome Regionの関係を誤っている。

## 9. S3 Server Access Loggingデグレードテスト

目的:
CloudTrailログ保存先S3に対するServer Access Logging有効化後も、CloudTrailログ配送に影響がなく、S3アクセスログが保存されることを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| Server Access Logging | 有効になっている | 設定漏れ、対象バケット誤り |
| ログ保存先 | 指定した保存先バケット/Prefixになっている | 保存先誤り、Prefix誤り |
| S3アクセスログ出力 | 一定時間後にログが保存される | 保存先権限不足、配送遅延 |
| CloudTrailログ配送 | CloudTrailログ配送が継続する | 既存Bucket Policy変更ミス |
| Lifecycle | 保存期間が設計どおり | Lifecycle未設定、保存量増加 |

注意:

- S3 Server Access Loggingは即時に出力されない場合がある。
- 同一バケットを保存先にするとログが増え続ける可能性があるため、保存先設計を確認する。

## 10. VPC Flow Logsデグレードテスト

目的:
VPC Flow Logs有効化後に、通信経路を変えずにログが出力され、保存先に配送されることを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| Flow Logs作成 | 対象VPCにFlow Logsが存在する | 対象VPC誤り、作成漏れ |
| Status | Active | IAM Role権限不足、保存先権限不足 |
| Traffic type | 設計どおり | ALL/ACCEPT/REJECTの選択誤り |
| 保存先 | CloudWatch LogsまたはS3が設計どおり | 保存先誤り、Log Group誤り |
| ログ出力 | 一定時間後にログが確認できる | 配送遅延、通信量不足、権限不足 |
| 費用影響 | 想定範囲内 | 対象範囲が広すぎる、Retention未設定 |

注意:

- VPC Flow Logsは通信内容そのものではなく、通信メタデータを記録する。
- 有効化しても通信経路は変わらないが、ログ量と費用は増える可能性がある。

## 11. GuardDuty運用デグレードテスト

目的:
新規監視や通知設定が、既存のGuardDuty確認運用やA3/A4手順と矛盾しないことを確認する。

| 確認項目 | OK条件 | NG時の原因候補 |
|---|---|---|
| GuardDuty Detector | 有効 | 対象リージョン誤り、Detectorなし |
| Finding確認 | 未アーカイブFindingを確認できる | 権限不足、対象リージョン誤り |
| 対応記録 | 発生日時、対応者、原因、完了日時を記録できる | 記録様式不足 |
| 月次確認との関係 | 月次確認と即時通知の役割が整理されている | 手順書不整合 |
| Archive基準 | 対応済み/対応不要の基準がある | 判断基準未整備 |

確認する資料:

- 要件A3/A4 セキュリティアラート監視運用手順書
- GuardDuty運用資料
- 既存月次確認資料
- 対応記録テンプレート

## 12. デグレードテストケース一覧

Excelへ貼り付ける場合は、以下のTSVを使用する。

```tsv
テストID	分類	確認対象	確認内容	期待結果	確認方法	証跡	結果	NG時の主な原因候補	備考
DG-001	CloudTrail	Trail	Loggingが継続していること	Loggingが有効	WebコンソールでTrail status確認	Trail status画面	未実施	StopLogging、Trail誤選択	
DG-002	CloudTrail	S3配送	CloudTrailログがS3へ配送されていること	新規ログオブジェクトが確認できる	S3保存先を確認	S3オブジェクト一覧	未実施	S3 Bucket Policy不備、KMS権限不足、配送遅延	
DG-003	CloudTrail	CloudWatch Logs連携	CloudTrailイベントがLog Groupへ届いていること	Log Stream更新あり	CloudWatch Logsを確認	Log Stream画面	未実施	CloudWatch Logs Role権限不足	
DG-004	CloudWatch	既存Metric Filter	既存Filterが残っていること	変更前と同じFilterが存在	Metric filters確認	Filter一覧	未実施	誤削除、Log Group誤認	
DG-005	CloudWatch	新規Metric Filter	新規Filterが設計どおりであること	Pattern、Metricが設計どおり	Metric Filter詳細確認	Filter詳細	未実施	Pattern誤り、Metric名誤り	
DG-006	CloudWatch	Alarm	Alarm Actionが有効であること	Actions enabledが有効	Alarm詳細確認	Alarm詳細	未実施	Action無効、通知先誤り	
DG-007	通知	SNS/メール	期待した通知先へ通知されること	通知受信を確認	通知テストまたは履歴確認	通知画面/メール	未実施	Subscription未承認、Topic誤り	
DG-008	通知	Teams	Teams通知が期待どおりであること	対象チャネルへ通知される	通知テストまたは履歴確認	Teams画面	未実施	連携先誤り、EventBridge Target誤り	
DG-009	EventBridge	既存Rule	既存Ruleが有効でTargetが残っていること	Rule有効、Targetあり	EventBridge Rule確認	Rule詳細	未実施	Rule無効化、Target削除	
DG-010	KMS	CloudTrail CMK	CloudTrailログ配送に必要なKMS権限があること	ログ配送が継続	Key Policyと配送状況確認	Key Policy/配送画面	未実施	Key Policy不備、SourceArn誤り	
DG-011	KMS	ログ参照	運用者がCloudTrailログを参照できること	必要なログを開ける	S3ログ参照確認	ログ参照画面	未実施	kms:Decrypt不足、Role未許可	
DG-012	S3	Server Access Logging	S3アクセスログが出力されること	一定時間後にログ保存先へ出力	S3保存先確認	S3オブジェクト一覧	未実施	保存先権限不足、配送遅延	
DG-013	VPC Flow Logs	Flow Logs	StatusがActiveでログ出力されること	Status Active、ログ出力あり	VPC Flow Logs確認	Flow Logs画面	未実施	IAM Role不備、保存先権限不足	
DG-014	GuardDuty	運用手順	対応記録が作成できること	必要項目を記録できる	手順書と記録様式確認	対応記録	未実施	記録項目不足、担当未定	
DG-015	費用/ログ量	ログ量	想定外のログ量増加がないこと	増加傾向が説明可能	CloudWatch/S3使用量確認	使用量画面	未実施	対象範囲過大、Retention未設定	
```

## 13. 結果記録テンプレート

```tsv
テストID	実施日	実施者	対象アカウント	対象リージョン	結果	確認内容	証跡保存先	NGの場合の原因	対応方針	完了日	承認者	備考
DG-001	YYYY-MM-DD	未定	未定	未定	未実施	未記入	未記入	未記入	未記入	YYYY-MM-DD	未定	
```

## 14. 判定基準

| 判定 | 意味 |
|---|---|
| OK | 期待結果を満たし、既存運用への悪影響がない |
| 条件付きOK | 軽微な注意点はあるが、運用回避または既知事項として説明できる |
| NG | 既存ログ、通知、参照、運用に影響がある |
| 保留 | 権限、資料、時間経過待ち、関係者確認が必要 |
| 対象外 | 対象外環境または対象外リソースであることを確認済み |

NGの場合は、原因、暫定対応、恒久対応、再テスト予定を記録する。

## 15. 完了条件

以下を満たしたらデグレードテスト完了とする。

- 既存CloudTrail記録が継続している。
- CloudTrailログのS3配送とCloudWatch Logs連携が継続している。
- 既存Metric Filter、Alarm、通知が失われていない。
- 新規Alarmが期待どおりの通知を行い、過通知になっていない。
- KMS CMK化後もCloudTrailログ配送とログ参照に問題がない。
- S3 Server Access Loggingが出力され、CloudTrailログ配送に影響がない。
- VPC Flow LogsがActiveで、保存先にログが出力されている。
- GuardDuty運用手順と対応記録に矛盾がない。
- ログ量、通知量、費用影響について説明できる。
- NGまたは保留事項がある場合、原因と対応方針が記録されている。

## 16. リーダー向け説明例

```text
今回の変更は、監視、ログ、通知、KMS、Flow Logsなど周辺基盤の変更が中心です。
そのため、業務機能そのもののテストに加えて、既存のログ取得、通知、ログ参照、運用確認が壊れていないことを確認するデグレードテストを行います。

特に、CloudTrailログ配送、KMS権限、既存通知との重複、VPC Flow Logsのログ量については影響が出やすいため、変更後確認と一定時間経過後の確認を分けて実施します。
```

## 17. 関連資料

- [AWSセキュリティ監査指摘対応 WBS案](./aws_security_remediation_wbs_2026_07.md)
- [AWSセキュリティ監査指摘対応 業務影響整理](./aws_security_remediation_business_impact_2026_07.md)
- [要件3番台 Webコンソール現状調査手順書](./requirements_3_x_logging_kms_vpcflow_current_state_investigation_web_console_2026_07.md)
- [要件4番台 Webコンソール一括現状調査手順書](./requirements_4_x_remaining_monitoring_current_state_investigation_web_console_2026_07.md)
- [要件A3/A4 セキュリティアラート監視運用手順書](./requirements_A3_A4_security_alert_monitoring_operation_procedure_2026_07.md)
