# AWS Reference

AWS上にWebアプリケーション基盤を構築し、AWSセキュリティ・ネットワーク改善案件で使う確認手順、CLIリファレンス、作業手順書、証跡取得方法を整理するためのリポジトリ。

VPC、Subnet、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCache、CloudTrail、CloudWatch、GuardDutyなどを対象に、AWS CLIとシェルスクリプトで構築・確認・削除できるようにする。

![ネットワーク構成図](./docs/design/Network_Architecture.png)

## 目的別目次

| 目的 | 見るもの |
| :--- | :--- |
| 全体構成を確認したい | [設計書](./docs/design/Design_Specification.md)、[ネットワーク構成図](./docs/design/Network_Architecture.png) |
| AWS CLIの共通作法を確認したい | [共通AWS CLI・証跡保存リファレンス](./docs/references/00_common_aws_cli_reference.md) |
| AWSセキュリティ設定を横断的に確認したい | [AWS Security Settings 横断チェックリスト](./docs/references/90_aws_security_settings_checklist.md) |
| AWSネットワーク設定を横断的に確認したい | [AWS Network Settings 横断チェックリスト](./docs/references/91_aws_network_settings_checklist.md) |
| S3のセキュリティ設定を確認したい | [S3セキュリティ設定CLIリファレンス](./docs/references/01_s3_security_cli_reference.md) |
| S3バケットポリシー変更の影響調査をしたい | [S3 Bucket Policy CLIリファレンス](./docs/references/02_s3_bucket_policy_cli_reference.md)、[S3バケットポリシー変更ケーススタディ](./docs/case_studies/case_study_s3_bucket_policy_change.md) |
| オンプレミス、S3、CloudTrail、GuardDutyの関係を理解したい | [オンプレミス、S3、CloudTrail、GuardDutyのつながり](./docs/case_studies/case_study_onpremises_s3_cloudtrail_guardduty.md) |
| CloudTrailのログや変更履歴を確認したい | [CloudTrail CLIリファレンス](./docs/references/03_cloudtrail_cli_reference.md) |
| CloudWatch Logs / Alarmを確認したい | [CloudWatch CLIリファレンス](./docs/references/04_cloudwatch_cli_reference.md) |
| GuardDuty Findingを確認したい | [GuardDuty CLIリファレンス](./docs/references/05_guardduty_cli_reference.md) |
| MFAなし管理コンソールログインを検知したい | [MFAなし管理コンソールログイン検知手順](./docs/references/06_mfa_console_login_detection.md) |
| VPC / SG / NACL / Routeの通信影響調査をしたい | [VPC/Network CLIリファレンス](./docs/references/07_vpc_network_cli_reference.md) |
| EC2 / IAM Role / IMDSv2 / EBS暗号化を確認したい | [EC2 Security CLIリファレンス](./docs/references/08_ec2_security_cli_reference.md) |
| RDSのPublic設定、暗号化、SG、ログ、バックアップを確認したい | [RDS Security CLIリファレンス](./docs/references/09_rds_security_cli_reference.md) |
| LambdaのIAM Role、VPC、環境変数、ログ、Function URLを確認したい | [Lambda Security CLIリファレンス](./docs/references/10_lambda_security_cli_reference.md) |
| RailsアプリをEC2へデプロイしたい | [Railsアプリケーションデプロイ手順](./ansible/10_rails_app_deploy.md)、[Ansible README](./ansible/README.md) |
| 日次ラボ環境を一括構築したい | [All_Setup.sh](./scripts/All_Setup.sh) |
| 検証後にリソースを削除したい | [cleanup_network.sh](./scripts/cleanup_network.sh)、[check_cleanup.sh](./scripts/check_cleanup.sh) |
| 作業手順書テンプレートを使いたい | [Markdown版](./docs/templates/s3_bucket_policy_change_procedure_template.md)、[Excel版](./docs/templates/s3_bucket_policy_change_procedure_template.xlsx) |
| 案件初日までの学習計画を確認したい | [2026-06-05 to 2026-06-30 案件対策ロードマップ](./docs/roadmaps/2026-06-05_to_2026-06-30_project_preparation_roadmap.md) |

## 案件対策リファレンス

AWSセキュリティ・ネットワーク改善案件で使うことを意識したリファレンス。

| 領域 | リンク | 主な内容 |
| :--- | :--- | :--- |
| 共通 | [共通AWS CLI・証跡保存リファレンス](./docs/references/00_common_aws_cli_reference.md) | Account / Profile / Region確認、証跡保存、差分確認、秘密情報の扱い |
| 横断チェックリスト | [AWS Security Settings 横断チェックリスト](./docs/references/90_aws_security_settings_checklist.md) | サービス横断の確認順序、重要度、証跡、切り戻し観点 |
| ネットワーク横断チェックリスト | [AWS Network Settings 横断チェックリスト](./docs/references/91_aws_network_settings_checklist.md) | 通信経路、Route、SG、NACL、DNS、Endpoint、Flow Logsの確認索引 |
| S3 | [S3セキュリティ設定CLIリファレンス](./docs/references/01_s3_security_cli_reference.md) | Public Access Block、ACL、Object Ownership、暗号化、ログ、Versioning |
| S3 Bucket Policy | [S3 Bucket Policy CLIリファレンス](./docs/references/02_s3_bucket_policy_cli_reference.md) | Policy取得、Public判定、差分確認、変更、切り戻し、CloudTrail確認 |
| CloudTrail | [CloudTrail CLIリファレンス](./docs/references/03_cloudtrail_cli_reference.md) | Trail、Event Data Store、イベント検索、S3保存、CloudWatch Logs連携 |
| CloudWatch | [CloudWatch CLIリファレンス](./docs/references/04_cloudwatch_cli_reference.md) | Log Group、Metric Filter、Alarm、ログ検索、証跡取得 |
| GuardDuty | [GuardDuty CLIリファレンス](./docs/references/05_guardduty_cli_reference.md) | Detector、Finding、重要度、サンプルFinding、調査手順 |
| MFA検知 | [MFAなし管理コンソールログイン検知手順](./docs/references/06_mfa_console_login_detection.md) | CloudTrail、Metric Filter、Alarm、調査、切り戻し |
| VPC/Network | [VPC/Network CLIリファレンス](./docs/references/07_vpc_network_cli_reference.md) | VPC、Subnet、Route Table、SG、NACL、Endpoint、Flow Logs、通信影響調査 |
| EC2 Security | [EC2 Security CLIリファレンス](./docs/references/08_ec2_security_cli_reference.md) | EC2、IAM Role、IMDSv2、EBS暗号化、Security Group、変更履歴確認 |
| RDS Security | [RDS Security CLIリファレンス](./docs/references/09_rds_security_cli_reference.md) | Public設定、暗号化、Security Group、Parameter Group、ログ、バックアップ確認 |
| Lambda Security | [Lambda Security CLIリファレンス](./docs/references/10_lambda_security_cli_reference.md) | IAM Role、VPC、環境変数、KMS、CloudWatch Logs、Function URL確認 |
| S3変更ケーススタディ | [S3バケットポリシー変更の影響調査・設定変更・証跡取得](./docs/case_studies/case_study_s3_bucket_policy_change.md) | 変更前確認、影響調査、設定変更、テスト、切り戻し、証跡取得 |
| オンプレ・S3・監査検知ケーススタディ | [オンプレミス、S3、CloudTrail、GuardDutyのつながり](./docs/case_studies/case_study_onpremises_s3_cloudtrail_guardduty.md) | 閉域接続、S3アクセス経路、CloudTrail監査、GuardDuty検知の関係 |
| 作業手順書テンプレート | [Markdown版](./docs/templates/s3_bucket_policy_change_procedure_template.md)、[Excel版](./docs/templates/s3_bucket_policy_change_procedure_template.xlsx) | 作業概要、事前確認、変更手順、変更後確認、切り戻し、証跡一覧 |
| 汎用セキュリティ調査 | [AWSセキュリティ調査用CLIリファレンス](./docs/references/aws_security_investigation_cli_reference.md) | EC2、S3、RDS、Lambda、GuardDuty、IAM、KMS、CloudTrail、Security Hub |
| 汎用ネットワーク調査 | [AWSネットワーク調査用CLIリファレンス](./docs/references/aws_network_cli_reference.md) | VPC、Subnet、Route Table、Security Group、NACL、VPC Endpoint、Flow Logs |

## AWS CLI構築手順

AWS CLI編の構築スクリプトと解説。

| No. | 領域 | スクリプト | 解説 |
| :--- | :--- | :--- | :--- |
| 01 | VPC | [01_vpc_setup.sh](./scripts/01_vpc_setup.sh) | [01_vpc_setup.md](./docs/setup_guides/01_vpc_setup.md) |
| 02 | Subnet | [02_subnet_setup.sh](./scripts/02_subnet_setup.sh) | [02_subnet_setup.md](./docs/setup_guides/02_subnet_setup.md) |
| 03 | Internet Gateway | [03_internetgateway_setup.sh](./scripts/03_internetgateway_setup.sh) | [03_internetgateway_setup.md](./docs/setup_guides/03_internetgateway_setup.md) |
| 04 | NAT Gateway | [04_nat_gateway_setup.sh](./scripts/04_nat_gateway_setup.sh) | [04_nat_gateway_setup.md](./docs/setup_guides/04_nat_gateway_setup.md) |
| 05 | Route Table | [05_route_table_setup.sh](./scripts/05_route_table_setup.sh) | [05_route_table_setup.md](./docs/setup_guides/05_route_table_setup.md) |
| 06 | Security Group | [06_security_group_setup.sh](./scripts/06_security_group_setup.sh) | [06_security_group_setup.md](./docs/setup_guides/06_security_group_setup.md) |
| 07 | Bastion EC2 | [07_bastion_server_setup.sh](./scripts/07_bastion_server_setup.sh) | [07_bastion_server_setup.md](./docs/setup_guides/07_bastion_server_setup.md) |
| 08 | Web EC2 | [08_Web_server_setup.sh](./scripts/08_Web_server_setup.sh) | なし |
| 09 | ALB | [09_LoadBalancer_setup.sh](./scripts/09_LoadBalancer_setup.sh) | [09_LoadBalancer_setup.md](./docs/setup_guides/09_LoadBalancer_setup.md) |
| 10 | RDS | [10_Database_setup.sh](./scripts/10_Database_setup.sh) | [10_Database_setup.md](./docs/setup_guides/10_Database_setup.md) |
| 11 | S3 / IAM Role | [11_s3_setup.sh](./scripts/11_s3_setup.sh) | [11_s3_setup.md](./docs/setup_guides/11_s3_setup.md) |
| 12 | Public DNS | [12_public_dns_setup.sh](./scripts/12_public_dns_setup.sh) | [12_public_dns_setup.md](./docs/setup_guides/12_public_dns_setup.md) |
| 13 | DNS Packet Capture | なし | [13_public_dns_packet_capture.md](./docs/operations/13_public_dns_packet_capture.md) |
| 14 | Private DNS | [14_private_dns_setup.sh](./scripts/14_private_dns_setup.sh) | [14_private_dns_setup.md](./docs/setup_guides/14_private_dns_setup.md) |
| 15 | ACM / HTTPS | [15_acm_certificate_setup.sh](./scripts/15_acm_certificate_setup.sh) | [15_acm_certificate_setup.md](./docs/setup_guides/15_acm_certificate_setup.md) |
| 16 | SES送信設定 | [16_ses_setup.sh](./scripts/16_ses_setup.sh) | なし |
| 17 | SES送信テスト | [17_sendmail_test.py](./scripts/17_sendmail_test.py) | [17_sendmail_test.md](./docs/operations/17_sendmail_test.md) |
| 18 | SES受信設定 | [18_ses_receiving_setup.sh](./scripts/18_ses_receiving_setup.sh) | [18_ses_receiving_setup.md](./docs/setup_guides/18_ses_receiving_setup.md) |
| 19 | ElastiCache | [19_elasticache_setup.sh](./scripts/19_elasticache_setup.sh) | [19_elasticache_setup.md](./docs/setup_guides/19_elasticache_setup.md) |
| 20 | Web Base AMI | [20_create_web_base_ami.sh](./scripts/20_create_web_base_ami.sh) | なし |

## 一括構築・削除・確認

日次ラボ運用でよく使う入口。

| 用途 | リンク | 内容 |
| :--- | :--- | :--- |
| 一括構築 | [All_Setup.sh](./scripts/All_Setup.sh) | VPCからPrivate DNSまで主要リソースを順番に構築 |
| 削除 | [cleanup_network.sh](./scripts/cleanup_network.sh) | 日次ラボで作成した課金対象リソースを削除 |
| 削除確認 | [check_cleanup.sh](./scripts/check_cleanup.sh) | VPC、EC2、ALB、RDS、ElastiCache、DNS、S3などの残存確認 |
| コスト確認 | [check_cost.sh](./scripts/check_cost.sh) | Cost Explorerで当月コストを確認 |

## Ansible / Railsデプロイ

AWS CLIでインフラを作成した後、Private Subnet上のWeb EC2へRailsアプリを配置する。

| 用途 | リンク | 内容 |
| :--- | :--- | :--- |
| Ansible全体 | [ansible/README.md](./ansible/README.md) | Ansibleディレクトリの概要 |
| Railsデプロイ手順 | [ansible/10_rails_app_deploy.md](./ansible/10_rails_app_deploy.md) | `run_site_local.sh` 実行、RDS/S3/CloudWatch連携、確認観点 |
| Ansible参考 | [00_ansible_reference.md](./ansible/notes/00_ansible_reference.md) | Ansibleの基本確認 |
| 標準実行 | [run_site_local.sh](./ansible/run_site_local.sh) | ローカル端末からWeb EC2へPlaybookを実行 |
| 標準Playbook | [site.yml](./ansible/playbooks/site.yml) | ping、nginx、Railsアプリ、CloudWatch Agentを実行 |
| フルPlaybook | [site_full.yml](./ansible/playbooks/site_full.yml) | Rubyビルドなども含めたフル構成 |

## 補助資料

| 種別 | リンク | 内容 |
| :--- | :--- | :--- |
| 案件対策ロードマップ | [2026-06-05 to 2026-06-30 案件対策ロードマップ](./docs/roadmaps/2026-06-05_to_2026-06-30_project_preparation_roadmap.md) | 7月1日の案件初日に向けた日別学習・模擬作業計画 |
| プロジェクトメモ | [project.md](./project.md) | リポジトリや学習の全体メモ |
| 作業種別メモ | [type_of_work.md](./type_of_work.md) | 作業分類の整理 |
| 面談メモ | [mendan.md](./mendan.md) | 案件面談で確認した内容 |
| Codex作業方針 | [AGENTS.md](./AGENTS.md) | このリポジトリでのMarkdown作成・案件対策方針 |
| ネットワーク構成図ソース | [Network_Architecture.puml](./docs/design/Network_Architecture.puml) | PlantUMLの構成図ソース |
| サンプル画像 | [Suneteruzu.JPG](./images/Suneteruzu.JPG) | Railsアプリの表示確認用画像 |

## 想定構成

- Public SubnetにALB、NAT Gateway、踏み台サーバーを配置する
- Private SubnetにWebサーバー、RDS、ElastiCacheを配置する
- WebサーバーはPublic IPを持たず、踏み台サーバー経由で管理する
- ALBからPrivate Subnet上のWebサーバーへHTTP 3000番で転送する
- S3をアプリケーションのアップロード先およびSES受信メール保存先として利用する
- Route 53でPublic DNSとPrivate DNSを管理する
- ACM証明書を利用してALBをHTTPS化する
- SESでメール送信とメール受信を検証する

## 利用方針

このリポジトリは、AWS CLIによる構築手順と、実務で使う調査コマンドの参照を目的とする。

案件対策のMarkdownでは、以下の観点を入れる。

- 変更前確認
- 実施内容
- 影響範囲
- 変更後確認
- 切り戻し方法
- セキュリティ上の注意点
- 案件で説明できるポイント
- 資格試験につながるポイント

## 注意事項

- AWSリソースの作成前に、必ず `aws sts get-caller-identity` で操作対象アカウントを確認する
- 認証情報、DBパスワード、SMTPパスワード、Secret値はリポジトリに保存しない
- NAT Gateway、RDS、ElastiCacheなどの課金対象リソースは、検証後に削除する
- 調査証跡としてJSONを保存する場合は、秘密情報や個人情報が含まれていないか確認する
- 本番相当の環境では、最小権限、監査ログ、暗号化、バックアップ、監視、変更承認を前提に設計する
