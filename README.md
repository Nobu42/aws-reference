# AWS Reference

クラウドセキュリティ対応の作業資料入口。

現場向けに文書化済みの旧資料リンクはREADMEから外す。READMEには、直近で追加または更新した資料だけを掲載する。

## 2026-09-02 更新資料

| 用途 | 資料 |
| :--- | :--- |
| 要件4.15のAWS Organizations変更監視を実施する。追補として、要件4.9のAWS Config Metric Filter、テスト用Config Rule、Alarm・SNS通知確認、切り戻しも収録する | [要件4.15 AWS Organizations変更監視 設定・テスト手順書（要件4.9追補）](./project-docs/03_procedures/requirement_4_15_organizations_change_monitoring_runbook_2026_09.md) |

## 2026-08-25 更新資料

| 用途 | 資料 |
| :--- | :--- |
| 要件3.4のServer Access Loggingターゲットバケットを新規作成し、ソース側の有効化、実ログ到着確認、切り戻しまで実施する | [要件3.4 S3 Server Access Logging ターゲットバケット作成・設定手順書](./project-docs/03_procedures/requirement_3_4_s3_server_access_logging_target_bucket_creation_runbook_2026_08.md) |

## 2026-08-17 更新資料

| 用途 | 資料 |
| :--- | :--- |
| 要件3.4のServer Access Logging送信先として、専用S3バケットを新規作成してよいかPMへ確認する | [要件3.4 S3 Server Access Logging 保存先バケット確認事項](./project-docs/03_procedures/requirement_3_4_s3_server_access_logging_pm_confirmation_2026_08.md) |
| 要件4.1～4.15について、検証環境で実AWSイベントを発生させ、CloudTrailから通知受信までEnd-to-Endで確認する | [要件4.1～4.15 検証環境End-to-Endアラーム発報手順書](./project-docs/03_procedures/requirements_4_x_validation_environment_end_to_end_alarm_test_runbook_2026_08.md) |
| 全21要件のテスト方法、代替候補、実通知の要否、採用理由を関係者へ説明する | [クラウドセキュリティ対応 全要件テスト方法説明資料](./project-docs/03_procedures/all_requirements_test_method_explanation_for_stakeholders_2026_08.md) |

## 2026-08-04 更新資料

| 用途 | 資料 |
| :--- | :--- |
| 4番台のMetric Filter、Metric、Alarm共通設計値とPattern Testサンプルを確認する | [要件4番台 監視設定値一覧 設計パラメータ案](./project-docs/03_procedures/requirements_4_x_monitoring_parameter_design_2026_07.md) |
| 4番台の監視設定値案をテキストファイルで確認する | [要件4番台 監視設定値一覧 設計パラメータ案 テキスト版](./project-docs/03_procedures/requirements_4_x_monitoring_parameter_design_2026_07.txt) |
| 3番台の設定・配信確認と、危険度が高い4番台要件の通知テストを行う | [要件3番台設定・危険度高め要件 CloudWatch Alarmテスト手順](./project-docs/03_procedures/high_risk_cloudwatch_alarm_test_procedure_2026_08.txt) |
| 今回の対応でパラメータシートへ反映が必要になり得る項目を確認する | [クラウドセキュリティ対応 パラメータシート変更対象一覧](./project-docs/03_procedures/cloud_security_parameter_sheet_change_items_2026_08.txt) |

## 注意事項

- 機密情報、顧客名、アカウントID、IPアドレス、メールアドレス、証跡の生ログは公開用資料に含めない。
- Webコンソールで作業する前提の手順書を優先する。
- 旧資料は削除せず、必要に応じて保管ディレクトリへ移動する。
