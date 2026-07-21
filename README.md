# AWS Reference

クラウドセキュリティ対応の作業資料入口。

README直下は、WBS、作業手順書、切り戻し、通知確認に関係する資料だけを掲載する。

## 計画・WBS

| 用途 | 資料 |
| :--- | :--- |
| 最新の作業計画、対象要件、スケジュール、対応不要項目を確認する | [AWSセキュリティ監査指摘対応 WBS案](./aws_security_remediation_wbs_2026_07.md) |
| 開発環境設定テストとテストリハの違いを確認する | [開発環境設定テストとテストリハの違い](./development_environment_test_vs_rehearsal_2026_07.md) |

## 4番台

| 用途 | 資料 |
| :--- | :--- |
| 4番台の監視設定値案を確認する | [要件4番台 監視設定値一覧 設計パラメータ案](./project-docs/03_procedures/requirements_4_x_monitoring_parameter_design_2026_07.md) |
| 先行作業4.5/4.7のWebコンソール設定・テストを行う | [要件4.5/4.7 先行作業 Webコンソール作業手順書](./requirements_4_5_4_7_leading_work_procedure_2026_07.md) |
| 先行作業4.5/4.7の当日作業でクリック箇所と証跡を確認する | [要件4.5/4.7 先行作業 当日Webコンソール作業手順書](./requirements_4_5_4_7_leading_work_day_of_console_runbook_2026_07.md) |
| ラボシステムで4.5/4.7のWebコンソール予行練習を行う | [ラボシステム 要件4.5/4.7 Webコンソール予行練習手順書](./sample_system_4_5_4_7_console_rehearsal_runbook_2026_07.md) |
| 先行作業4.5/4.7で安全に実イベントを発生させる方法を確認する | [要件4.5/4.7 実イベント発生テスト手順書](./requirements_4_5_4_7_real_event_test_runbook_2026_07.md) |
| 先行作業4.5/4.7の懸念点、注意点、失敗時の切り分けを確認する | [要件4.5/4.7 先行作業 懸念点・注意点・トラブルシューティング](./requirements_4_5_4_7_leading_work_risks_and_troubleshooting_2026_07.md) |
| CloudTrailからCloudWatch Logsへの連携の懸念点と確認事項を確認する | [CloudTrail -> CloudWatch Logs連携 確認事項・懸念点整理](./cloudtrail_cloudwatch_logs_integration_review_points_2026_07.md) |
| 4.5/4.7で使うCloudWatch関連設定の公式根拠URLを確認する | [要件4.5/4.7 CloudWatch関連公式ドキュメント根拠整理](./cloudwatch_official_docs_basis_for_4_5_4_7_work_2026_07.md) |
| 先行作業4.5/4.7のレビュー前日に確認することを確認する | [要件4.5/4.7 先行作業 レビュー前日確認チェックリスト](./review_eve_checklist_for_4_5_4_7_leading_work_2026_07.md) |
| 4番台のWebコンソール設定・テストを行う | [要件4番台 Webコンソール作業実施手順書](./project-docs/03_procedures/requirements_4_x_web_console_work_procedure_2026_07.md) |
| 4番台の当日作業手順をExcel形式で整理する | [要件4番台 当日Webコンソール作業手順書テンプレート](./project-docs/03_procedures/requirements_4_x_day_of_web_console_runbook_template_2026_07.md) |
| 4番台を2グループに分けて当日作業する | [要件4番台 2グループ分割 当日Webコンソール作業手順書テンプレート](./project-docs/03_procedures/requirements_4_x_two_group_day_of_web_console_runbook_template_2026_07.md) |

## 3番台

| 用途 | 資料 |
| :--- | :--- |
| 3番台のWebコンソール設定・テストを行う | [要件3番台 Webコンソール作業実施手順書](./project-docs/03_procedures/requirements_3_x_web_console_work_procedure_2026_07.md) |

## A3/A4

| 用途 | 資料 |
| :--- | :--- |
| A3/A4で必要な作業と他部署連携を整理する | [要件A3/A4 必要作業・他部署連携整理](./project-docs/03_procedures/requirements_A3_A4_work_items_and_coordination_2026_07.md) |
| A3/A4のセキュリティアラート監視運用手順を確認する | [要件A3/A4 セキュリティアラート監視運用手順書](./project-docs/03_procedures/requirements_A3_A4_security_alert_monitoring_operation_procedure_2026_07.md) |
| A3/A4の運用証跡テンプレートを確認する | [要件A3/A4 セキュリティアラート運用証跡テンプレート](./project-docs/03_procedures/requirements_A3_A4_security_alert_operation_evidence_template_2026_07.md) |

## 通知確認

| 用途 | 資料 |
| :--- | :--- |
| 通知先と通知テストを整理する | [通知設計・通知先一覧・通知テスト手順](./project-docs/03_procedures/notification_design_and_test_plan_2026_07.md) |

## 本番作業・切り戻し

| 用途 | 資料 |
| :--- | :--- |
| 本番作業と切り戻しの流れを確認する | [本番作業手順書・切り戻し手順書](./project-docs/03_procedures/production_release_and_rollback_runbook_2026_09.md) |

## 注意事項

- 機密情報、顧客名、アカウントID、IPアドレス、メールアドレス、証跡の生ログは公開用資料に含めない。
- Webコンソールで作業する前提の手順書を優先する。
- README直下は、本作業で使用する手順書の入口に限定する。
