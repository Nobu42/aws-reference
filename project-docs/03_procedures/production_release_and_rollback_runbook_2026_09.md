# 本番作業手順書・切り戻し手順書

作成日: 2026-07-12

この資料は、クラウドセキュリティ対応の本番反映に向けた作業手順、確認観点、切り戻し方針を整理するためのRunbookである。

最終リリース予定日は2026-09-12である。実際の作業日時、作業者、承認者、対象環境、手順番号は現場の変更管理に合わせて確定する。

## 1. 対象作業

| 分類 | 対象 |
| :--- | :--- |
| 3番台 | CloudTrail S3 Server Access Logging、CloudTrail CMK暗号化、CMKローテーション、VPC Flow Logs |
| 4番台 | CloudWatch Logs Metric Filter、CloudWatch Alarm、通知設定 |
| A3/A4 | GuardDuty確認手順、アラート対応手順、運用証跡テンプレ |
| その他 | 通知テスト、デグレードテスト、説明資料、証跡整理 |

## 2. 作業体制

| 役割 | 担当 | 主な責務 |
| :--- | :--- | :--- |
| 作業者 | 未定 | Webコンソール作業、証跡取得 |
| 確認者 | 未定 | 作業内容のダブルチェック |
| 承認者 | 未定 | 作業開始、継続、切り戻し判断 |
| 通知確認者 | 未定 | メール、Teams、監視基盤の受信確認 |
| インフラ確認者 | 未定 | VPC、Flow Logs、KMS、S3影響確認 |
| 運用確認者 | 未定 | アラート受信後の運用手順確認 |

## 3. 作業前チェック

| No. | 確認項目 | 結果 |
| :--- | :--- | :--- |
| 1 | 作業申請が承認済み | 未確認 |
| 2 | 対象アカウントが確定済み | 未確認 |
| 3 | 対象リージョンが確定済み | 未確認 |
| 4 | 対象リソース一覧が確定済み | 未確認 |
| 5 | 設定値一覧が承認済み | 未確認 |
| 6 | 通知先が承認済み | 未確認 |
| 7 | 通知テストの可否が承認済み | 未確認 |
| 8 | 切り戻し方針が承認済み | 未確認 |
| 9 | 作業前証跡の保存先が確定済み | 未確認 |
| 10 | 作業中連絡先が確定済み | 未確認 |

## 4. 作業順序案

本番作業は、影響が小さいものから順に実施する。

| 順序 | 作業 | 理由 |
| :--- | :--- | :--- |
| 1 | 作業前証跡取得 | 切り戻しとレビューの基準にする |
| 2 | 通知先確認 | Alarm作成前に通知経路を確定する |
| 3 | Metric Filter作成 | 通知はまだ発火しない状態で検知条件を作る |
| 4 | CloudWatch Alarm作成 | Alarm Actionを確認しながら設定する |
| 5 | 3.4 Server Access Logging | ログ増加以外の業務影響が小さい |
| 6 | 3.7 VPC Flow Logs | ログ増加と権限を確認する |
| 7 | 3.5 CloudTrail CMK暗号化 | KMS権限不備がログ配信や参照に影響するため慎重に実施する |
| 8 | 3.6 CMKローテーション | 3.5のCMK確定後に実施する |
| 9 | 通知テスト | 監視経路の到達確認 |
| 10 | 作業後証跡取得 | 完了判定に使用する |

## 5. 作業中の判断基準

| 状況 | 判断 |
| :--- | :--- |
| CloudTrailログ配信エラー発生 | 作業を停止し、KMS Key Policy、S3 Bucket Policy、CloudTrail設定を確認する |
| 通知が届かない | SNS Subscription、Alarm Action、EventBridge Target、Teams連携を確認する |
| 通知が重複する | 既存EventBridge Rule、既存Alarm、SNS Subscriptionを確認する |
| VPC Flow Logsが配信されない | Destination、IAM Role、S3 Bucket Policy、Log Group権限を確認する |
| 想定外の自動処理が動く | 作業を停止し、EventBridge TargetやLambda内容を確認する |
| 業務影響が疑われる | 変更承認者へ即時連絡し、切り戻し判断を仰ぐ |

## 6. 切り戻し方針

| 作業 | 切り戻し |
| :--- | :--- |
| Metric Filter | 作成したMetric Filterを削除する |
| CloudWatch Alarm | Alarm Action無効化後にAlarmを削除する |
| SNS Topic | 新規作成分のみ削除する。既存Topicは削除しない |
| Server Access Logging | Source bucketのServer Access Loggingを無効化する |
| CloudTrail CMK暗号化 | TrailのKMS設定を作業前状態へ戻す。作成済みCMKは無効化・削除しない |
| CMKローテーション | 必要に応じて設定を戻す。CMKは削除しない |
| VPC Flow Logs | 作成したFlow Logを削除する |
| EventBridge | 本作業で新規作成したRuleのみ無効化または削除する。既存Ruleは変更しない |

重要:

- CMKで暗号化済みのCloudTrailログは、復号にCMKが必要である。
- 切り戻し時にCMKを無効化または削除しない。
- 既存通知先や既存Ruleを誤って削除しない。

## 7. 作業後確認

| No. | 確認項目 | 期待結果 |
| :--- | :--- | :--- |
| 1 | CloudTrail status | 配信エラーなし |
| 2 | CloudWatch Logs | CloudTrailイベントが配信されている |
| 3 | Metric Filter | 対象要件分が存在する |
| 4 | CloudWatch Alarm | OKまたは想定状態 |
| 5 | Alarm Action | 通知先が設定されている |
| 6 | SNS Subscription | Confirm済み |
| 7 | Teams通知 | 承認済みテストで到達確認済み |
| 8 | S3 Server Access Logging | Target bucket / prefixが設定済み |
| 9 | CloudTrail KMS | CMKが設定済み |
| 10 | KMS rotation | 自動ローテーションが有効 |
| 11 | VPC Flow Logs | 対象VPCで有効 |
| 12 | 証跡 | 作業前後、テスト結果、通知結果が保存済み |

## 8. 完了報告テンプレート

| 項目 | 内容 |
| :--- | :--- |
| 作業日時 | 未記入 |
| 対象環境 | 未記入 |
| 対象アカウント | 未記入 |
| 対象リージョン | 未記入 |
| 実施作業 | 未記入 |
| 作業結果 | 正常 / 条件付き正常 / 切り戻し |
| 通知テスト | 実施 / 未実施 / 対象外 |
| 業務影響 | なし / あり |
| 残課題 | 未記入 |
| 証跡格納先 | 未記入 |
| 確認者 | 未記入 |

