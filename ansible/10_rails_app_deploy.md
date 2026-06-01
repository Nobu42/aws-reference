# Railsアプリケーションデプロイ実行結果

## 概要

このドキュメントは、`aws-reference/ansible` 配下のAnsible Playbookを使って、Private Subnet上のWeb EC2 2台へRails 7.2アプリケーションをデプロイした実行結果をまとめたものである。

今回の作業は、広い意味ではWebアプリケーションのデプロイである。

より正確には、以下の作業をAnsibleで自動化した。

```text
AnsibleによるWebサーバー構成管理とRailsアプリケーションデプロイ
```

AWS CLI編で作成したインフラの上に、AnsibleでRailsアプリケーション実行環境を構築し、HTTPS経由でアプリケーションを表示できることを確認した。

## 実行ディレクトリ

```bash
cd /Users/nobu/aws-reference/ansible
```

ディレクトリ構成は以下である。

```text
ansible/
├── 10_rails_app_deploy.md
├── README.md
├── ansible.cfg
├── group_vars/
├── inventory/
│   └── hosts.ini
├── notes/
│   └── 00_ansible_reference.md
├── playbooks/
│   ├── 01_ping.yml
│   ├── 02_packages.yml
│   ├── 03_deploy_user.yml
│   ├── 04_nginx.yml
│   ├── 05_ruby.yml
│   ├── 06_rails.yml
│   ├── 07_puma.yml
│   ├── 08_sample_app_rails72.yml
│   ├── 09_cloudwatch_agent.yml
│   ├── site.yml
│   └── site_full.yml
└── run_site_local.sh
```

## 前提条件

Ansible実行前に、AWS CLI編で以下のリソースを作成済みである。

| 分類 | 主なリソース |
| :--- | :--- |
| Network | VPC、Public Subnet、Private Subnet、Internet Gateway、NAT Gateway、Route Table |
| Security | Bastion SG、ELB SG、Web SG、DB SG、ElastiCache SG |
| EC2 | Bastion、Web01、Web02 |
| ALB | Application Load Balancer、Target Group、HTTP/HTTPS Listener |
| RDS | MySQL DB Instance、DB Subnet Group |
| S3 | Active Storage用アップロードバケット |
| DNS | Public DNS、Private DNS |
| TLS | ACM証明書、ALB HTTPS Listener |
| Logs | CloudWatch Logs連携用IAM Role |

Web EC2はPrivate Subnetにあり、Macから直接接続しない。

AnsibleはBastion経由でWeb EC2へSSH接続する。

```text
Mac
  |
  | SSH / Ansible
  v
awsref-bastion
  |
  | ProxyJump
  v
awsref-web01 / awsref-web02
```

## Inventory

今回のInventoryは以下である。

```ini
[web]
awsref-web01
awsref-web02

[web:vars]
ansible_user=ec2-user
ansible_python_interpreter=/usr/bin/python3.9
```

`awsref-web01` / `awsref-web02` は、`~/.ssh/config` に定義したHost名を使う。

`ProxyJump` はAnsible Inventoryではなく、`~/.ssh/config` 側で管理する。

## 実行したPlaybook

今回実行したまとめPlaybookは以下である。

```bash
./run_site_local.sh
```

内部では以下を実行する。

```bash
ansible-playbook playbooks/site.yml
```

`site.yml` の内容は以下である。

```yaml
- import_playbook: 01_ping.yml
- import_playbook: 04_nginx.yml
- import_playbook: 08_sample_app_rails72.yml
- import_playbook: 09_cloudwatch_agent.yml
```

| Playbook | 役割 |
| :--- | :--- |
| `01_ping.yml` | Web EC2 2台へのAnsible疎通確認 |
| `04_nginx.yml` | nginxをPuma socketへproxyする設定を作成 |
| `08_sample_app_rails72.yml` | Rails 7.2サンプルアプリをproduction環境でデプロイ |
| `09_cloudwatch_agent.yml` | nginx / PumaログをCloudWatch Logsへ送信 |

## 環境変数

実行前に、RDS作成時のDB master passwordをMac側で設定する。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
```

`SECRET_KEY_BASE` は未設定の場合、`run_site_local.sh` が自動生成する。

```bash
SECRET_KEY_BASE=$(openssl rand -hex 64)
```

`SECRET_KEY_BASE` は、ALB配下のWeb EC2 2台で同じ値にする必要がある。

値がWeb EC2ごとに異なると、ログイン画面表示とPOST先が別インスタンスに振り分けられた場合、CSRF token検証に失敗する。

```text
GET  /login   -> awsref-web01
POST /session -> awsref-web02
```

## Ansible実行結果

Ansibleの実行結果は以下である。

```text
PLAY RECAP
awsref-web01 : ok=69 changed=45 unreachable=0 failed=0 skipped=5 rescued=0 ignored=0
awsref-web02 : ok=67 changed=45 unreachable=0 failed=0 skipped=5 rescued=0 ignored=0
```

重要なのは以下である。

```text
unreachable=0
failed=0
```

これにより、Bastion経由でWeb EC2 2台へ接続でき、Playbook全体が失敗なく完了したことを確認できた。

## CloudWatch Agent確認

`09_cloudwatch_agent.yml` により、Web EC2 2台へCloudWatch Agentを導入した。

実行結果では、両方のインスタンスでAgentが `running` になっていた。

```text
awsref-web01:
  status: running
  configstatus: configured
  version: 1.300064.2

awsref-web02:
  status: running
  configstatus: configured
  version: 1.300064.2
```

収集対象ログは以下である。

| Log Group | 収集元 |
| :--- | :--- |
| `/nobu-iac-lab/nginx/access` | `/var/log/nginx/access.log` |
| `/nobu-iac-lab/nginx/error` | `/var/log/nginx/error.log` |
| `/nobu-iac-lab/puma/stdout` | `/var/www/nobu-iac-lab/log/puma.stdout.log` |
| `/nobu-iac-lab/puma/stderr` | `/var/www/nobu-iac-lab/log/puma.stderr.log` |

CloudWatch LogsのLog Group確認コマンド:

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --output table
```

## HTTPS表示確認

Ansible実行後、Macから以下を実行した。

```bash
curl https://www.nobu-iac-lab.com
```

RailsアプリケーションのHTMLが返ってきた。

確認できた主な内容は以下である。

| 確認項目 | 結果 |
| :--- | :--- |
| HTTPSアクセス | 成功 |
| Rails HTMLレスポンス | 成功 |
| CSRF token生成 | 成功 |
| CSS asset配信 | 成功 |
| 固定画像 `Suneteruzu.JPG` 配信 | 成功 |
| 投稿一覧表示 | 成功 |
| RDS初期データ表示 | 成功 |

レスポンス内では、以下の文言を確認できた。

```text
Rails 7.2 on AWS
Nobu IAC Lab
Private EC2上のRailsアプリから、RDSへの保存とS3への画像アップロードを確認します。
```

また、固定画像もassets経由で配信されていた。

```text
/assets/Suneteruzu-...JPG
```

これにより、Rails production環境でasset pipelineが機能していることも確認できた。

## ALB Target Health確認

Target Group `sample-tg` のARNを取得する。

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
```

Target Healthを確認する。

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn "$TG_ARN" \
  --output table
```

実行結果では、Web EC2 2台とも `healthy` だった。

| Target | Port | State |
| :--- | :--- | :--- |
| `i-08429bd7ddd6c919a` | `3000` | `healthy` |
| `i-020bcecc6702e0d45` | `3000` | `healthy` |

これにより、ALBからWeb EC2上のnginx / Puma / Railsへ正常にヘルスチェックできていることを確認できた。

## 確認できた通信経路

今回の確認で、以下の通信経路が成立していることを確認できた。

```text
Internet
  |
  v
Route 53
  |
  v
ALB HTTPS:443
  |
  v
Target Group sample-tg
  |
  v
Web EC2 :3000
  |
  v
nginx
  |
  v
Puma
  |
  v
Rails 7.2
  |
  +--> RDS MySQL
  |
  +--> S3 Active Storage
```

HTTPS、ALB Target Health、Railsレスポンス、RDSデータ表示、画像asset配信まで確認できているため、Webアプリケーションとしての基本動作は成立している。

## 今回の作業名

今回の作業は、状況に応じて以下のように表現できる。

| 表現 | 用途 |
| :--- | :--- |
| Webアプリケーションのデプロイ | 一般的な説明 |
| Railsアプリケーションのデプロイ自動化 | Ansibleで自動化した点を強調 |
| Webサーバー構成管理 | nginx / Puma / CloudWatch Agentなどを含める場合 |
| アプリケーション実行環境の構築 | Ruby / Bundler / Rails / systemdを含める場合 |
| Railsアプリケーションの本番相当環境への配置 | production環境を強調する場合 |

案件説明では、以下の言い方が自然である。

```text
AWS CLIで構築したVPC、ALB、RDS、S3環境上に、AnsibleでRailsアプリケーション実行環境を構成し、nginx + Puma構成でアプリケーションをデプロイしました。
```

もう少し具体的に言う場合は、以下のように説明できる。

```text
Private Subnet上のWeb EC2 2台に対して、Bastion経由でAnsibleを実行し、Rails 7.2アプリケーション、nginx、Puma、CloudWatch Agentを構成しました。
ALB + ACM + Route 53経由でHTTPS公開し、Target Groupの2台がhealthyになることを確認しました。
```

## 案件で説明できるポイント

今回の作業は、以下の観点で案件説明に使いやすい。

| 観点 | 説明できる内容 |
| :--- | :--- |
| 構成管理 | 複数EC2へ同じ設定をAnsibleで反映 |
| 踏み台経由管理 | Private Subnet上のWeb EC2をBastion経由で管理 |
| 再現性 | Playbook化により日次再構築後も同じ手順で復旧 |
| Web公開 | ALB + ACM + Route 53でHTTPS公開 |
| アプリ構成 | nginx + Puma + Rails production |
| DB接続 | RailsからRDS MySQLへ接続 |
| S3連携 | Active Storageで画像保存先にS3を利用 |
| ログ収集 | CloudWatch Agentでnginx / PumaログをCloudWatch Logsへ送信 |
| 可用性 | Web EC2 2台をTarget Groupへ登録しhealthy確認 |
| セキュリティ | 秘密情報は環境変数とEC2上のroot管理ファイルで扱う |

## 注意事項

`DB_MASTER_PASSWORD` や `SECRET_KEY_BASE` はGitに保存しない。

EC2上では以下のファイルに保存される。

```text
/etc/nobu-iac-lab.env
```

このファイルにはDBパスワードやRailsの秘密鍵が含まれるため、権限を以下にしている。

```text
owner: root
group: deploy
mode : 0640
```

また、学習後は課金対象リソースを削除する。

```bash
cd /Users/nobu/aws-reference/scripts
./cleanup_network.sh
./check_cleanup.sh
```

S3バケット、CloudWatch Logs、ACM証明書、SES設定など、日次cleanupで残すものと消すものは `check_cleanup.sh` の結果を見て確認する。

## 次に確認すること

次の確認項目は以下である。

- ブラウザで `https://www.nobu-iac-lab.com` を開く
- `nobu@example.com` / `password` でログインする
- 新規投稿する
- 画像付き投稿を行う
- S3にActive Storageのオブジェクトが作成されることを確認する
- CloudWatch Logsにnginx / Pumaログが届くことを確認する
- `cleanup_network.sh` で課金対象リソースを削除できることを確認する

## 今回の到達点

今回の到達点は以下である。

- AnsibleでWeb EC2 2台へRails 7.2アプリケーションをデプロイできた
- nginx + Puma + Rails production構成で起動できた
- CloudWatch Agentを導入し、状態が `running` であることを確認できた
- `https://www.nobu-iac-lab.com` でRailsアプリケーションを表示できた
- ALB Target GroupでWeb EC2 2台が `healthy` であることを確認できた
- AWS CLI編で作成したインフラとAnsible編のアプリケーションデプロイが接続できた

