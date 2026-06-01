# Ansible Reference

このメモは、このリポジトリで実際に使ったAnsibleの基本文法、考え方、確認コマンドを整理したリファレンス。

Terraform学習後に戻ってきたときや、現場でAnsibleを書くときに、最低限ここを見れば思い出せることを目的にしている。

## Ansibleの役割

Ansibleは、サーバー内部の設定を自動化する構成管理ツール。

このリポジトリでは、AWS CLIで作成したWeb EC2に対して、MacからAnsibleを実行し、以下を自動化している。

- パッケージ導入
- deployユーザー作成
- nginx設定
- Ruby / Bundler導入
- Railsアプリケーション作成
- Puma systemd設定
- RDS接続設定
- S3 Active Storage設定
- CloudWatch Agent設定

AWSリソースそのものはAWS CLIで作成し、EC2内部の設定をAnsibleで行う役割分担。

```text
AWS CLI:
  VPC / Subnet / EC2 / ALB / RDS / S3 / Route 53 / CloudWatch などを作成

Ansible:
  EC2内部のOS、ミドルウェア、アプリケーション設定を作成
```

## 基本構成

```text
02-ansible/
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

## ansible.cfg

`ansible.cfg` はAnsibleの設定ファイル。

このリポジトリでは、`02-ansible` 配下でAnsibleを実行する前提。

よく使う設定例:

```ini
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
retry_files_enabled = False
```

主な意味:

- `inventory`
  - 接続先ホスト一覧のファイルを指定する。

- `host_key_checking`
  - SSH初回接続時のhost key確認を制御する。
  - 学習環境ではEC2を日次で作り直すため、無効化することがある。

- `retry_files_enabled`
  - 失敗時の `.retry` ファイル作成を抑制する。

## Inventory

Inventoryは、Ansibleの接続先を定義するファイル。

```text
02-ansible/inventory/hosts.ini
```

例:

```ini
[web]
web01
web02

[web:vars]
ansible_user=ec2-user
ansible_ssh_common_args='-o ProxyJump=bastion'
ansible_python_interpreter=/usr/bin/python3.9
```

意味:

- `[web]`
  - `web` というホストグループを定義する。

- `web01` / `web02`
  - Ansibleの接続先ホスト名。
  - 実際の接続先IPや踏み台設定は `~/.ssh/config` に定義する。

- `[web:vars]`
  - `web` グループ共通の変数。

- `ansible_user`
  - SSH接続に使うユーザー。

- `ansible_ssh_common_args`
  - SSH接続時の追加オプション。
  - このラボではBastion経由のため `ProxyJump=bastion` を使う。

- `ansible_python_interpreter`
  - リモートホスト側で使うPython。
  - Ansibleモジュール実行に必要。

## SSH configとの関係

AnsibleはSSHを使って対象サーバーに接続する。

このラボでは、`web01` / `web02` はPrivate Subnetにあるため、直接インターネットから接続できない。

そのため、Macの `~/.ssh/config` でBastion経由の接続を定義する。

```sshconfig
Host bastion
  HostName <bastion-public-ip>
  User ec2-user
  IdentityFile /Users/nobu/terraform-iac-lab/01-aws-cli/scripts/nobu.pem
  IdentitiesOnly yes

Host web01
  HostName <web01-private-ip>
  User ec2-user
  IdentityFile /Users/nobu/terraform-iac-lab/01-aws-cli/scripts/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion

Host web02
  HostName <web02-private-ip>
  User ec2-user
  IdentityFile /Users/nobu/terraform-iac-lab/01-aws-cli/scripts/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion
```

AnsibleはInventoryの `web01` / `web02` を見て、SSH configの同名Host設定を使って接続する。

## Playbookの基本構造

Playbookは、Ansibleで実行する処理をYAMLで書いたもの。

```yaml
---
- name: Configure web servers
  hosts: web
  become: true

  vars:
    app_dir: /var/www/nobu-iac-lab

  tasks:
    - name: Install nginx
      ansible.builtin.dnf:
        name: nginx
        state: present
```

主な要素:

- `---`
  - YAMLファイルの開始を表す。

- `name`
  - PlayやTaskの説明。
  - 実行ログに表示されるため、何をしているか分かる名前にする。

- `hosts`
  - 実行対象のInventoryグループ。
  - このラボでは主に `web`。

- `become`
  - `sudo` するかどうか。
  - パッケージ導入や `/etc` 配下の変更では `true` が必要。

- `vars`
  - Playbook内で使う変数。

- `tasks`
  - 実行する処理の一覧。

## よく使う実行コマンド

Ansibleの疎通確認:

```bash
cd /Users/nobu/terraform-iac-lab/02-ansible
ansible-playbook playbooks/01_ping.yml
```

Playbook実行:

```bash
ansible-playbook playbooks/04_nginx.yml
```

構文チェック:

```bash
ansible-playbook --syntax-check playbooks/08_sample_app_rails72.yml
```

Inventoryを明示する場合:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/01_ping.yml
```

詳細ログを出す:

```bash
ansible-playbook playbooks/08_sample_app_rails72.yml -v
```

さらに詳細:

```bash
ansible-playbook playbooks/08_sample_app_rails72.yml -vvv
```

## まとめPlaybook

複数のPlaybookを順番に実行したい場合は、`import_playbook` を使う。

`site.yml` の例:

```yaml
---
- import_playbook: 01_ping.yml
- import_playbook: 04_nginx.yml
- import_playbook: 08_sample_app_rails72.yml
- import_playbook: 09_cloudwatch_agent.yml
```

日次再構築では、カスタムAMIを使ってRuby導入済みのWeb EC2を作成するため、`02_packages.yml`、`03_deploy_user.yml`、`05_ruby.yml` を省略できる。

公式AMIからRubyビルドも含めて構築する場合は、`site_full.yml` を使う。

## 変数

Playbook内では `vars` で変数を定義できる。

```yaml
vars:
  deploy_user: deploy
  app_name: nobu-iac-lab
  app_dir: /var/www/nobu-iac-lab
  rails_env: production
```

変数を使うときは `{{ }}` で参照する。

```yaml
- name: Ensure application directory exists
  ansible.builtin.file:
    path: "{{ app_dir }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
```

変数を使う理由:

- 同じ値を何度も書かなくてよい
- パスやユーザー名を変更しやすい
- Playbookの意図が分かりやすくなる

## 環境変数

このラボでは、RDSパスワードやRailsの `SECRET_KEY_BASE` をMac側の環境変数として渡する。

```bash
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site.yml
```

Playbook側では、`lookup('env', '環境変数名')` で取得できる。

```yaml
db_password: "{{ lookup('env', 'DB_MASTER_PASSWORD') }}"
secret_key_base: "{{ lookup('env', 'SECRET_KEY_BASE') }}"
```

重要:

`SECRET_KEY_BASE` は `web01` / `web02` で同じ値にする必要がある。

値がEC2ごとに異なると、ALB経由でGETとPOSTが別EC2へ振り分けられたときに、RailsのCSRF検証やCookie検証で失敗することがある。

## assert

`assert` は、必要な前提条件をチェックするために使う。

```yaml
- name: Require DB_MASTER_PASSWORD on Ansible controller
  ansible.builtin.assert:
    that:
      - lookup('env', 'DB_MASTER_PASSWORD') | length > 0
    fail_msg: "DB_MASTER_PASSWORD is required. Export it before running this playbook."
  run_once: true
  delegate_to: localhost
```

意味:

- `DB_MASTER_PASSWORD` が空ならPlaybookを止める。
- `run_once: true` で1回だけ実行する。
- `delegate_to: localhost` でAnsible実行元のMac上で評価する。

## become

`become: true` は、リモートホスト上でsudoして実行する指定。

Play全体で指定する例:

```yaml
- name: Configure Rails application
  hosts: web
  become: true
```

Task単位でユーザーを切り替える例:

```yaml
- name: Run bundle install
  ansible.builtin.shell: |
    bundle install
  args:
    chdir: "{{ app_dir }}"
  become_user: "{{ deploy_user }}"
```

使い分け:

- root権限が必要
  - パッケージ導入
  - `/etc/systemd/system` へのUnit配置
  - systemd操作

- deployユーザーで実行したい
  - Railsアプリ作成
  - bundle install
  - rails db:prepare

## よく使ったモジュール

### ansible.builtin.ping

Ansible接続確認に使う。

```yaml
- name: Ping web servers
  ansible.builtin.ping:
```

成功すると `pong` が返る。

### ansible.builtin.dnf

Amazon Linux 2023でパッケージを導入する。

```yaml
- name: Install common packages
  ansible.builtin.dnf:
    name:
      - git
      - nginx
      - gcc
      - make
    state: present
```

### ansible.builtin.user

ユーザーを作成する。

```yaml
- name: Create deploy user
  ansible.builtin.user:
    name: deploy
    shell: /bin/bash
    create_home: true
```

### ansible.builtin.file

ディレクトリやファイルの状態、所有者、権限を管理する。

```yaml
- name: Ensure Puma directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  loop:
    - "{{ app_dir }}/tmp"
    - "{{ app_dir }}/tmp/sockets"
    - "{{ app_dir }}/tmp/pids"
    - "{{ app_dir }}/log"
```

主な `state`:

- `directory`
  - ディレクトリを作る。

- `file`
  - ファイルとして扱う。

- `touch`
  - ファイルがなければ作成する。

- `absent`
  - 削除する。

### ansible.builtin.copy

ファイルを配置する。

固定内容を直接書く場合:

```yaml
- name: Create Puma configuration
  ansible.builtin.copy:
    dest: "{{ app_dir }}/config/puma.rb"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0644'
    content: |
      environment "{{ rails_env }}"
      bind "unix://{{ puma_socket }}"
```

ローカルファイルをコピーする場合:

```yaml
- name: Copy fixed application image
  ansible.builtin.copy:
    src: ../../images/Suneteruzu.JPG
    dest: "{{ app_dir }}/app/assets/images/Suneteruzu.JPG"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0644'
```

### ansible.builtin.template

Jinja2テンプレートを使ってファイルを生成するときに使う。

このリポジトリでは主に `copy: content:` で直接生成しているが、設定ファイルが大きくなる場合は `template` が向いている。

```yaml
- name: Create nginx config from template
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/conf.d/nobu-iac-lab.conf
```

### ansible.builtin.lineinfile

既存ファイルに1行追加、変更するときに使う。

```yaml
- name: Allow external host names in Rails development
  ansible.builtin.lineinfile:
    path: "{{ app_dir }}/config/environments/development.rb"
    line: "  config.hosts.clear"
    insertbefore: "^end$"
    state: present
```

同じ行がすでにあれば追加しないため、冪等性を保ちやすい。

### ansible.builtin.git

Gitリポジトリをcloneする。

```yaml
- name: Clone rbenv
  ansible.builtin.git:
    repo: https://github.com/rbenv/rbenv.git
    dest: /home/deploy/.rbenv
    version: master
```

### ansible.builtin.command

シェルを介さずコマンドを実行する。

```yaml
- name: Check nginx configuration syntax
  ansible.builtin.command:
    cmd: nginx -t
  changed_when: false
```

特徴:

- パイプ、リダイレクト、環境変数展開、`source` などのシェル機能は使えない。
- 単純なコマンド実行に向いている。

### ansible.builtin.shell

シェルを介してコマンドを実行する。

```yaml
- name: Prepare production database
  ansible.builtin.shell: |
    set -a
    source /etc/nobu-iac-lab.env
    set +a
    export RBENV_ROOT="/home/deploy/.rbenv"
    export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
    bin/rails db:prepare
  args:
    chdir: "{{ app_dir }}"
  become_user: "{{ deploy_user }}"
```

特徴:

- 複数行コマンドを書ける。
- 環境変数を使える。
- `source`、パイプ、リダイレクトを使える。

ただし、冪等性が崩れやすいので、`creates`、`changed_when`、`when` などで制御することが重要。

### ansible.builtin.systemd

systemdサービスを管理する。

```yaml
- name: Enable and start Puma service
  ansible.builtin.systemd:
    name: puma-nobu-iac-lab
    enabled: true
    state: restarted
```

主な指定:

- `daemon_reload: true`
  - Unitファイル変更後にsystemdへ再読み込みさせる。

- `enabled: true`
  - 自動起動を有効化する。

- `state: started`
  - 起動する。

- `state: restarted`
  - 再起動する。

### ansible.builtin.stat

ファイルやディレクトリの存在確認に使う。

```yaml
- name: Check Puma socket exists
  ansible.builtin.stat:
    path: "{{ puma_socket }}"
  register: puma_socket_status
```

結果は `register` で変数に入れて使う。

### ansible.builtin.debug

変数やメッセージを表示する。

```yaml
- name: Show application status
  ansible.builtin.debug:
    msg:
      - "Puma service: {{ puma_status.stdout }}"
      - "nginx service: {{ nginx_status.stdout }}"
```

## register

`register` は、Taskの実行結果を変数に保存する。

```yaml
- name: Check Ruby and Bundler versions
  ansible.builtin.command:
    cmd: bash -lc 'ruby -v && bundler -v'
  register: ruby_check
  changed_when: false
```

よく使う値:

- `ruby_check.stdout`
  - 標準出力。

- `ruby_check.stdout_lines`
  - 標準出力を行ごとの配列にしたもの。

- `ruby_check.stderr`
  - 標準エラー。

- `ruby_check.rc`
  - 終了コード。

## changed_when

`changed_when` は、Taskを変更扱いにするかどうかを制御する。

確認だけのコマンドは、変更ではないため `false` にする。

```yaml
- name: Check nginx configuration syntax
  ansible.builtin.command:
    cmd: nginx -t
  changed_when: false
```

## failed_when

`failed_when` は、Taskを失敗扱いにする条件を制御する。

```yaml
- name: Check Rails response through nginx
  ansible.builtin.command:
    cmd: curl --silent --show-error --fail http://localhost:3000/
  register: nginx_curl_result
  changed_when: false
  failed_when: nginx_curl_result.rc != 0
```

通常は終了コードが0以外なら失敗だが、特殊なケースでは `failed_when: false` としてログだけ取得することもある。

## when

`when` は、条件に一致したときだけTaskを実行する。

```yaml
- name: Install Ruby with rbenv
  ansible.builtin.shell: |
    /home/deploy/.rbenv/bin/rbenv install 3.3.6
  when: ruby_version_check.rc != 0
```

## loop

`loop` は、同じTaskを複数の値に対して繰り返すときに使う。

```yaml
- name: Ensure Puma directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  loop:
    - "{{ app_dir }}/tmp"
    - "{{ app_dir }}/tmp/sockets"
    - "{{ app_dir }}/tmp/pids"
    - "{{ app_dir }}/log"
```

`item` にloop内の値が1つずつ入る。

## run_once

`run_once: true` は、対象ホストが複数あってもTaskを1回だけ実行する。

このラボでは、CloudWatch Log Group作成や保持期間設定で使った。

```yaml
- name: Create CloudWatch Log Groups
  ansible.builtin.command:
    cmd: "aws logs create-log-group --log-group-name {{ item }}"
  loop: "{{ cloudwatch_log_groups }}"
  run_once: true
```

理由:

`web01` / `web02` が同じLog Groupに対して同時に操作すると、AWS側で競合することがあるため。

## delegate_to

`delegate_to` は、そのTaskだけ別ホストで実行する指定。

```yaml
- name: Require DB_MASTER_PASSWORD on Ansible controller
  ansible.builtin.assert:
    that:
      - lookup('env', 'DB_MASTER_PASSWORD') | length > 0
  delegate_to: localhost
  run_once: true
```

この例では、環境変数チェックをリモートEC2ではなくAnsible実行元のMacで行う。

## serial

`serial` は、複数ホストへ同時に適用せず、何台ずつ実行するかを制御する。

```yaml
- name: Configure and start Puma for Rails application
  hosts: web
  become: true
  serial: 1
```

`serial: 1` なら、`web01`、`web02` を1台ずつ順番に処理する。

アプリケーション更新時に全台同時停止を避けたい場合に有効。

## notify / handlers

設定ファイルが変わったときだけサービスを再起動したい場合は、`notify` と `handlers` を使う。

```yaml
tasks:
  - name: Create nginx config
    ansible.builtin.copy:
      dest: /etc/nginx/conf.d/nobu-iac-lab.conf
      content: |
        server {
          listen 3000;
        }
    notify: Restart nginx

handlers:
  - name: Restart nginx
    ansible.builtin.systemd:
      name: nginx
      state: restarted
```

このリポジトリでは明示的に `systemd` Taskで再起動する書き方も使っているが、実務ではhandlersを使うと変更時だけ再起動できてきれい。

## 冪等性

冪等性は「同じ処理を何度実行しても、最終状態が同じになる性質」。

読み方:

```text
冪等性 = べきとうせい
```

Ansibleでは、この考え方が重要。

```yaml
- name: Install nginx
  ansible.builtin.dnf:
    name: nginx
    state: present
```

1回目はnginxをインストールする。

2回目は、すでにnginxが入っていれば何もしない。

このように、Ansibleは「指定した状態にする」ことを目的にする。

## commandとshellの使い分け

基本は `command` を優先する。

```yaml
ansible.builtin.command:
  cmd: systemctl is-active nginx
```

以下が必要なときだけ `shell` を使う。

- 複数行コマンド
- 環境変数展開
- `source`
- パイプ
- リダイレクト
- `if` 文

`shell` は便利だが、変更判定や冪等性が曖昧になりやすいため注意する。

## args

Taskに追加条件を指定する。

### chdir

コマンド実行ディレクトリを指定する。

```yaml
- name: Run bundle install
  ansible.builtin.shell: |
    bundle install
  args:
    chdir: "{{ app_dir }}"
```

### creates

指定したファイルが存在する場合はTaskを実行しない。

```yaml
- name: Create Rails application
  ansible.builtin.shell: |
    rails new .
  args:
    chdir: "{{ app_dir }}"
    creates: "{{ app_dir }}/Gemfile"
```

冪等性を保つために有効。

## ファイル権限

Ansibleでは `mode` を文字列で書くのが安全。

```yaml
mode: '0644'
```

よく使う権限:

```text
0644
  通常ファイル。

0755
  ディレクトリや実行ファイル。

0640
  秘密情報を含む設定ファイル。
```

このラボでは、Rails環境変数ファイル `/etc/nobu-iac-lab.env` にDBパスワードや `SECRET_KEY_BASE` を入れるため、権限を絞っている。

## systemd Unit

Pumaはsystemdサービスとして管理している。

Unitファイル配置先:

```text
/etc/systemd/system/puma-nobu-iac-lab.service
```

Ansibleでは `copy` でUnitファイルを作成し、`systemd` で反映する。

```yaml
- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Enable and start Puma service
  ansible.builtin.systemd:
    name: puma-nobu-iac-lab
    enabled: true
    state: restarted
```

Unitファイルを変更したら `daemon_reload: true` が必要。

## nginxとPuma

このラボでは、nginxをWebサーバー、PumaをRailsアプリケーションサーバーとして使う。

```text
ALB
  |
nginx
  |
Puma
  |
Rails
```

PumaはUnix Socketで待ち受ける。

```text
/var/www/nobu-iac-lab/tmp/sockets/puma.sock
```

nginxはこのSocketへリクエストを転送する。

ALBでHTTPS終端し、nginxからRailsへHTTPで転送する構成では、`X-Forwarded-Proto` を正しく渡すことが重要。

## RDS接続

DB通信は、Puma上で動くRailsアプリケーションが行う。

```text
Rails
  |
Active Record
  |
RDS MySQL
```

nginxやALBはDBへ直接接続しない。

Railsの `database.yml` では、Private Hosted Zoneの `db.home` を接続先にする。

```yaml
host: db.home
username: adminuser
password: <環境変数から取得>
```

Security Groupでは、Web EC2のSecurity GroupからRDSの3306番だけを許可する。

## S3 Active Storage

画像アップロードはRails Active Storage経由でS3へ保存する。

```text
Browser
  |
Rails
  |
Active Storage
  |
S3
```

EC2からS3へアクセスするため、Web EC2に付与されたIAM RoleへS3アクセス権限を設定する。

## CloudWatch Agent

`09_cloudwatch_agent.yml` では、CloudWatch Agentをインストールし、nginx / PumaログをCloudWatch Logsへ送信する。

主な処理:

- CloudWatch Agentインストール
- Log Group作成
- Log Group保持期間7日設定
- Agent設定ファイル作成
- Agent起動
- Agent status確認

複数ホストで共有するLog Group作成や保持期間設定は、`run_once: true` で1回だけ実行する。

## このリポジトリで発生した主なAnsible関連エラー

### curl-minimalとcurlの競合

Amazon Linux 2023では `curl-minimal` が標準で入っていることがある。

通常の `curl` パッケージを入れようとすると競合することがあるため、Playbookでは `curl-minimal` を前提にした。

### Active Storage migration衝突

`web01` / `web02` でそれぞれ `active_storage:install` を実行すると、別timestampのmigrationが生成され、同じRDSに対して `active_storage_blobs already exists` が発生した。

対応:

- generator実行ではなく、固定名のmigrationをAnsibleで配置
- `table_exists?` を使って冪等化

### SECRET_KEY_BASE不一致によるCSRFエラー

`web01` / `web02` で `SECRET_KEY_BASE` が異なると、ALB配下でログインPOST時にCSRFエラーが発生した。

対応:

- Mac側で1つの `SECRET_KEY_BASE` を生成
- Ansibleでweb01 / web02へ同じ値を配布

### Log Group保持期間設定の競合

`web01` / `web02` が同じLog Groupに同時に `put-retention-policy` を実行し、CloudWatch Logs側で競合した。

対応:

- 共有AWSリソースを操作するTaskに `run_once: true` を設定

## Play Recapの見方

Ansible実行後には、以下のような結果が出る。

```text
PLAY RECAP
web01 : ok=50 changed=8 failed=0 skipped=5
web02 : ok=50 changed=9 failed=0 skipped=5
```

意味:

- `ok`
  - 正常に完了したTask数。

- `changed`
  - 対象ホストの状態を変更したTask数。

- `failed`
  - 失敗したTask数。

- `skipped`
  - 条件により実行されなかったTask数。

冪等性が高いPlaybookでは、2回目以降の `changed` が少なくなる。

## この構成での実装要点

### Ansibleの役割

```text
AWS CLIで作成したPrivate Subnet上のWeb EC2に対して、Ansibleでnginx、Puma、Ruby、Railsアプリケーション、CloudWatch Agentを構成した。
Bastion経由でweb01 / web02へ接続し、同じ設定を2台に反映している。
```

### 冪等性

```text
Ansibleでは、パッケージ導入やディレクトリ作成をstateで管理し、同じPlaybookを再実行しても同じ状態に収束するように意識した。
確認系Taskにはchanged_when: falseを使い、共有リソース操作にはrun_onceを使っている。
```

### トラブル対応

```text
RailsのCSRFエラーでは、ALB配下の2台構成でSECRET_KEY_BASEが一致していないことが原因でした。
Ansibleで同じSECRET_KEY_BASEをweb01 / web02へ配布するように修正し、ログインできる状態にした。
```

### CloudWatch連携

```text
AnsibleでCloudWatch Agentを導入し、nginxとPumaのログをCloudWatch Logsへ送信した。
Log Group作成や保持期間設定は複数ホストで同時実行すると競合するため、run_onceで1回だけ実行するようにした。
```
