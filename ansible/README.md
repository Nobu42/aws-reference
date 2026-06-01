# Ansible

このディレクトリでは、Ansibleを使ってPrivate Subnet上のWebサーバー `awsref-web01` / `awsref-web02` を構成管理する。

AWS CLI編で作成したVPC、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheなどのAWSリソース上に、Rails 7.2アプリケーションをデプロイする。

## 目的

- Webサーバー内部の設定をAnsibleで自動化する
- Bastion経由でPrivate Subnet上のWeb EC2を管理する
- awsref-web01 / awsref-web02 に同じ設定を反映する
- Ruby 3.3 / Rails 7.2 / Puma / nginx を構築する
- Railsアプリケーションをproduction環境で起動する
- RDS MySQLへ接続する
- Active Storageで投稿画像をS3へ保存する
- ALB + ACM + Route 53経由でHTTPS公開する
- 後続のCloudWatch監視、Terraform化、Auto Scaling構成につなげる

## 実行環境

AnsibleはMacから実行する。

```text
Mac
  |
  | Ansible / SSH
  v
Bastion
  |
  | ProxyJump
  v
awsref-web01 / awsref-web02
```

| 項目 | 値 |
| :--- | :--- |
| Ansible実行元 | Mac |
| 接続先 | awsref-web01, awsref-web02 |
| SSHユーザー | ec2-user |
| 接続経路 | Bastion経由 |
| 対象OS | Amazon Linux 2023 |
| 接続先Python | /usr/bin/python3.9 |
| Ruby | 3.3.6 |
| Rails | 7.2.3 |
| Webサーバー | nginx |
| Application Server | Puma |
| DB | RDS for MySQL |
| 画像保存 | S3 / Active Storage |

## ディレクトリ構成

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
└── playbooks/
    ├── 01_ping.yml
    ├── 02_packages.yml
    ├── 03_deploy_user.yml
    ├── 04_nginx.yml
    ├── 05_ruby.yml
    ├── 06_rails.yml
    ├── 07_puma.yml
    ├── 08_sample_app_rails72.yml
    ├── 09_cloudwatch_agent.yml
    ├── site.yml
    └── site_full.yml
```

## Notes

Ansibleの基本文法、Inventory、よく使うモジュール、実行コマンド、冪等性、トラブル対応は以下に整理している。

- [Ansible Reference](./notes/00_ansible_reference.md)
- [Rails App Deploy Result](./10_rails_app_deploy.md)

## Inventory

`inventory/hosts.ini` にAnsibleの接続先を定義する。

```ini
[web]
awsref-web01
awsref-web02

[web:vars]
ansible_user=ec2-user
ansible_python_interpreter=/usr/bin/python3.9
```

`awsref-web01`、`awsref-web02`、`awsref-bastion` は `~/.ssh/config` に定義済みであることを前提とする。

`ProxyJump` は `~/.ssh/config` の `awsref-web01` / `awsref-web02` 側に定義する。

## 事前確認

通常のSSH接続を確認する。

```bash
ssh awsref-web01
ssh awsref-web02
```

Ansibleの疎通確認:

```bash
ansible-playbook playbooks/01_ping.yml
```

## 実行順

### 通常AMIから構築する場合

Amazon Linux 2023の公式AMIからWeb EC2を作成した場合は、Rubyのビルドを含めて以下を実行する。

```bash
cd /Users/nobu/aws-reference/ansible

ansible-playbook playbooks/01_ping.yml
ansible-playbook playbooks/02_packages.yml
ansible-playbook playbooks/03_deploy_user.yml
ansible-playbook playbooks/04_nginx.yml
ansible-playbook playbooks/05_ruby.yml
```

その後、Rails 7.2サンプルアプリをデプロイする。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)

ansible-playbook playbooks/08_sample_app_rails72.yml
```

### カスタムAMIから構築する場合

Ruby 3.3.6 / Bundler / nginx / deployユーザー導入済みのカスタムAMIを使う場合、Rubyビルドを省略できる。

この場合、AWS CLI編の `08_Web_server_setup.sh` で以下の設定を使う。

```bash
USE_CUSTOM_WEB_AMI=true
CUSTOM_WEB_AMI_ID="ami-00f86224c38cc3b8c"
```

Ansible側では以下を実行する。

```bash
cd /Users/nobu/aws-reference/ansible

export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)

ansible-playbook playbooks/site.yml
```

必要に応じて `02_packages.yml`、`03_deploy_user.yml`、`05_ruby.yml` を再実行しても、基本的には冪等に処理される。

### まとめPlaybook

日次再構築では、カスタムAMIを使う前提で以下を実行する。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site.yml
```

`site.yml` の内容:

```yaml
- import_playbook: 01_ping.yml
- import_playbook: 04_nginx.yml
- import_playbook: 08_sample_app_rails72.yml
- import_playbook: 09_cloudwatch_agent.yml
```

Amazon Linux 2023の公式AMIからRubyビルドも含めて構築する場合は、以下を使う。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site_full.yml
```

`site_full.yml` の内容:

```yaml
- import_playbook: 01_ping.yml
- import_playbook: 02_packages.yml
- import_playbook: 03_deploy_user.yml
- import_playbook: 04_nginx.yml
- import_playbook: 05_ruby.yml
- import_playbook: 08_sample_app_rails72.yml
```

## Playbook一覧

| Playbook | 役割 |
| :--- | :--- |
| `01_ping.yml` | awsref-web01 / awsref-web02 へのAnsible疎通確認 |
| `02_packages.yml` | 共通パッケージ、nginx、MariaDB client、ImageMagickなどを導入 |
| `03_deploy_user.yml` | deployユーザーと `/var/www` を作成 |
| `04_nginx.yml` | nginxをPuma socketへproxyする設定を作成 |
| `05_ruby.yml` | rbenvでRuby 3.3.6とBundlerを導入 |
| `06_rails.yml` | Rails 7.2の雛形作成用。現在は検証用として残している |
| `07_puma.yml` | Puma単体設定用。現在は検証用として残している |
| `08_sample_app_rails72.yml` | Rails 7.2サンプルアプリをproduction環境でデプロイ |
| `09_cloudwatch_agent.yml` | nginx / PumaログをCloudWatch Logsへ送信 |
| `site.yml` | カスタムAMI前提の日次再構築用まとめPlaybook |
| `site_full.yml` | 公式AMIからRubyビルドも含めて構築するフル実行Playbook |

現在の主なデプロイ対象は `08_sample_app_rails72.yml`。

## 08_sample_app_rails72.yml

Rails 7.2で、書籍サンプルアプリ相当の簡易SNSアプリを構築する。

主な内容:

- Rails 7.2.3アプリ作成
- ユーザー登録
- ログイン / ログアウト
- 投稿
- 画像アップロード
- Active Storage
- S3保存
- RDS MySQL接続
- Puma / systemd
- nginx連携
- production環境でのHTTPS公開

動作確認用ユーザー:

```text
nobu@example.com
password
```

## 環境変数

`08_sample_app_rails72.yml` 実行前に、Mac側で以下を設定する。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
```

### DB_MASTER_PASSWORD

RDS作成時に指定したmaster userのパスワード。

Playbook内には直書きせず、環境変数から読み込む。

### SECRET_KEY_BASE

Rails productionでCookie署名やCSRF token検証に使う秘密鍵。

ALB配下で `awsref-web01` / `awsref-web02` の2台構成にしているため、両方のWeb EC2で同じ値を使う必要がある。

値がEC2ごとに異なると、以下のように別インスタンスへ振り分けられた場合にCSRF検証で失敗する。

```text
GET  /login   -> awsref-web01
POST /session -> awsref-web02
```

この問題を避けるため、Mac側で生成した共通値をAnsibleから `/etc/nobu-iac-lab.env` へ配布する。

## アプリケーション設定ファイル

Rails productionの環境変数は、各Web EC2上の以下に配置する。

```text
/etc/nobu-iac-lab.env
```

権限:

```text
owner: root
group: deploy
mode : 0640
```

Pumaはdeployユーザーで動作するため、deployグループに読み取り権限を付与している。

このファイルにはDBパスワードや `SECRET_KEY_BASE` が含まれるため、GitHubには保存しない。

## 確認コマンド

HTTPS公開確認:

```bash
curl -I https://www.nobu-iac-lab.com
```

期待する結果:

```text
HTTP/2 200
server: nginx/1.28.3
```

S3画像保存確認:

```bash
aws s3 ls s3://nobu-terraform-iac-lab-upload --recursive --profile learning
```

画像投稿後にオブジェクトが表示されれば、Active Storage経由でS3へ保存されている。

Puma状態確認:

```bash
ssh awsref-web01
sudo systemctl status puma-nobu-iac-lab --no-pager
```

Pumaログ確認:

```bash
sudo tail -n 120 /var/www/nobu-iac-lab/log/puma.stdout.log
sudo tail -n 120 /var/www/nobu-iac-lab/log/puma.stderr.log
```

リアルタイムログ確認:

```bash
sudo journalctl -u puma-nobu-iac-lab -f
```

nginx設定確認:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
```

## 動作確認項目

- `https://www.nobu-iac-lab.com` でトップページが表示されること
- 固定画像 `Suneteruzu.JPG` が表示されること
- `nobu@example.com` / `password` でログインできること
- 新規ユーザー登録できること
- 投稿できること
- 画像付き投稿ができること
- 画像投稿後、S3にオブジェクトが作成されること
- awsref-web01 / awsref-web02 のPumaとnginxがactiveであること

## Railsアプリの機能範囲

現時点では、AWS上でのデプロイ、RDS接続、S3画像保存、複数Web EC2構成の確認を目的としているため、Railsアプリの機能は最小限にしている。

実装済み:

- ユーザー登録
- ログイン / ログアウト
- 投稿
- 画像アップロード
- 投稿画像のS3保存

現時点では追加しないもの:

- フォロー機能
- いいね機能
- コメント機能
- パスワードリセット
- メール認証

Railsアプリ自体を大きくするよりも、AWS構成、Ansibleによる再現性、ログ調査、運用改善を優先する。

## 対応した主なトラブル

今回のAnsible実行結果は [Rails App Deploy Result](./10_rails_app_deploy.md) に整理している。

- ALB配下のRailsでHTTPSリダイレクトループが発生した
- Web EC2 2台構成でログイン時にCSRFエラーが発生した
- Active StorageのmigrationがWeb EC2ごとに生成されてRDSで衝突した
- 画像投稿時に `413 Request Entity Too Large` が発生した

## 現在の到達点

以下を確認済み。

- AnsibleでWeb EC2 2台へRails 7.2アプリをデプロイ
- Puma + nginxでRails production起動
- ALB + ACM + Route 53でHTTPS公開
- RDS MySQLへ接続
- ログイン成功
- 投稿成功
- 画像アップロード成功
- Active StorageからS3への画像保存確認
- `site.yml` によるRailsアプリ + CloudWatch Agentの一括実行確認

## site.yml実行確認

カスタムWebベースAMIから作成した `awsref-web01` / `awsref-web02` に対して、以下のまとめPlaybookでRailsアプリケーションとCloudWatch Agentを一括設定できることを確認した。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site.yml
```

`site.yml` では以下を順番に実行する。

```yaml
- import_playbook: 01_ping.yml
- import_playbook: 04_nginx.yml
- import_playbook: 08_sample_app_rails72.yml
- import_playbook: 09_cloudwatch_agent.yml
```

実行後、以下を確認した。

- `https://www.nobu-iac-lab.com` が `HTTP/2 200` を返すこと
- RailsログがCloudWatch Logsの `/nobu-iac-lab/puma/stdout` に送信されること
- nginx access logがCloudWatch Logsの `/nobu-iac-lab/nginx/access` に送信されること

## 今後の予定

- EC2 / ALB / RDSのメトリクス監視
- ALB Target GroupのHealthyHostCount / 5xx監視
- CloudWatch Alarm作成
- CloudWatch Dashboard作成
- RDS / S3 / AMIのバックアップ設計強化
- Terraform化
- Auto Scaling Group化
- ECS/Fargate化
- CI/CD構成
