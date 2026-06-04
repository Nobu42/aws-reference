# 06_security_group_setup.sh 解説

## 概要

`06_security_group_setup.sh` は、`sample-vpc` にBastion用とELB用のSecurity Groupを作成し、必要なインバウンドルールを設定するスクリプトである。

この段階で作成するSecurity Groupは以下である。

| Security Group | 用途 | インバウンド | 送信元 |
| :--- | :--- | :--- | :--- |
| sample-sg-bastion | 踏み台サーバー | SSH 22/tcp | 自分のグローバルIP /32 |
| sample-sg-elb | ALB | HTTP 80/tcp | 0.0.0.0/0 |
| sample-sg-elb | ALB | HTTPS 443/tcp | 0.0.0.0/0 |

設計書では、Webサーバー用、RDS用、ElastiCache用のSecurity Groupも定義している。ただし、このスクリプトではまずBastionとELBの外部入口に関わるSecurity Groupだけを作成する。

Security Groupはステートフルな仮想ファイアウォールであり、EC2、ALB、RDS、ElastiCacheなどのリソースに関連付けて通信を制御する。

## 前提条件

このスクリプトを実行する前に、以下のスクリプトが完了している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |

Security GroupはVPCに紐づくため、VPCが存在している必要がある。

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

また、Bastion用Security Groupでは現在の自分のグローバルIPを取得するため、以下の外部エンドポイントへ到達できる必要がある。

```bash
https://checkip.amazonaws.com
```

AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではSecurity GroupとIngress Ruleを操作するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeSecurityGroups`
- `ec2:CreateSecurityGroup`
- `ec2:CreateTags`
- `ec2:AuthorizeSecurityGroupIngress`

削除運用まで含める場合は、以下も必要になる。

- `ec2:DeleteSecurityGroup`
- `ec2:RevokeSecurityGroupIngress`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、VPC名、Security Group名を定義する
3. 現在の自分のグローバルIPを取得する
4. SSH許可CIDRを `<自分のグローバルIP>/32` として定義する
5. ALB用のHTTP / HTTPS許可CIDRを `0.0.0.0/0` として定義する
6. LocalStack向けの設定が残っていないように無効化する
7. 共通関数を定義する
8. 実行対象のAWSアカウントとIAMユーザーを確認する
9. `sample-vpc` が1つだけ存在することを確認し、VPC IDを取得する
10. Bastion用Security Groupを作成または再利用する
11. Bastion用Security GroupにSSH許可ルールを追加またはスキップする
12. ELB用Security Groupを作成または再利用する
13. ELB用Security GroupにHTTP許可ルールを追加またはスキップする
14. ELB用Security GroupにHTTPS許可ルールを追加またはスキップする
15. 作成または再利用したSecurity GroupとIngress Ruleを確認する

## Bashの安全設定

```bash
#!/bin/bash
set -euo pipefail
```

`set -euo pipefail` は、シェルスクリプトを安全に実行するための設定である。

| 設定 | 意味 |
| :--- | :--- |
| `-e` | コマンドが失敗した時点でスクリプトを終了する |
| `-u` | 未定義の変数を使った場合にエラーにする |
| `-o pipefail` | パイプ処理の途中で失敗した場合もエラーとして扱う |

Security Groupは通信許可に直結する。途中の失敗を見落として後続処理が進むと、意図しない公開や接続不可につながる可能性があるため、失敗時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"

BASTION_SG_NAME="sample-sg-bastion"
ELB_SG_NAME="sample-sg-elb"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、Security Groupを作成するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`VPC_NAME` は、Security Groupを作成する対象VPCを検索するために使用する。

`BASTION_SG_NAME` と `ELB_SG_NAME` は、作成または再利用するSecurity Group名である。

Security Group名はVPC内で一意である。同じ名前のSecurity Groupが既にある場合、このスクリプトでは新規作成せず既存Security Groupを再利用する。

## 自分のグローバルIP取得

```bash
MY_GLOBAL_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')
```

`checkip.amazonaws.com` を利用して、現在の作業端末から見えるグローバルIPアドレスを取得する。

このIPアドレスは、BastionへのSSH接続元を絞るために使用する。

```bash
SSH_ALLOWED_CIDR="${MY_GLOBAL_IP}/32"
```

`/32` は、1つのIPv4アドレスだけを表すCIDRである。

例:

```text
203.0.113.10/32
```

この設定により、BastionへのSSHは現在の自分のグローバルIPからのみ許可される。

## ALB用CIDR

```bash
HTTP_ALLOWED_CIDR="0.0.0.0/0"
HTTPS_ALLOWED_CIDR="0.0.0.0/0"
```

ALBは外部からHTTP / HTTPSを受ける想定であるため、学習環境では `0.0.0.0/0` を許可している。

ただし、実運用では要件に応じて制限する。銀行案件のような環境では、WAF、CloudFront、特定接続元、閉域網、VPN、Direct Connectなど、上位の制御や接続元要件とあわせて確認する。

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続する可能性がある。

このスクリプトは実AWSのSecurity Groupを変更するため、LocalStack関連設定を無効化する。

## ID取得チェック関数

```bash
get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}
```

AWS CLIの検索結果が存在しない場合、`--output text` では `None` または空文字が返ることがある。

Security GroupはVPCに作成するため、VPC IDが取得できない状態では処理を続けない。

## Security Groupの作成または再利用

```bash
ensure_security_group() {
  local group_name="$1"
  local description="$2"
  ...
}
```

`ensure_security_group` は、同じVPC内に同じSecurity Group名が存在するか確認する。

既存Security Groupがある場合は、そのSecurity Group IDを返す。存在しない場合は、新しくSecurity Groupを作成する。

この設計により、スクリプトを再実行してもSecurity Groupを重複作成しない。

また、同じSecurity Group名が複数存在する場合は、先頭を自動選択せずエラーで停止する。

既存Security Groupを再利用する場合も、以下のタグを再適用する。

```bash
Key=Name,Value=<Security Group名>
Key=Project,Value=terraform-iac-lab
Key=Environment,Value=learning
```

タグは同じ値を再適用しても安全であり、後続スクリプトや調査時の検索条件として使える。

## Ingress Ruleの作成またはスキップ

```bash
ensure_ingress_cidr "$SG_BASTION_ID" "tcp" "22" "22" "$SSH_ALLOWED_CIDR" "SSH access for learning"
ensure_ingress_cidr "$SG_ELB_ID" "tcp" "80" "80" "$HTTP_ALLOWED_CIDR" "HTTP access"
ensure_ingress_cidr "$SG_ELB_ID" "tcp" "443" "443" "$HTTPS_ALLOWED_CIDR" "HTTPS access"
```

`ensure_ingress_cidr` は、CIDRを送信元とするIngress Ruleを追加またはスキップする関数である。

処理内容は以下である。

| 状態 | 処理 |
| :--- | :--- |
| 同じプロトコル、ポート、CIDRのルールが存在する | 何もしない |
| ルールが存在しない | `authorize-security-group-ingress` で追加する |

同じIngress Ruleを再度追加しようとすると、AWS CLIは重複エラーを返す。そのため、事前に `describe-security-groups` でルールの有無を確認している。

## VPC IDでの絞り込み

このスクリプトでは、Security Group取得時にVPC IDで絞り込む。

例:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$group_name" \
  --query 'length(SecurityGroups)' \
  --output text
```

Security Group名はVPC内で一意だが、別VPCには同じ名前のSecurity Groupを作成できる。

Nameだけ、またはGroupNameだけで検索すると、別VPCのSecurity Groupを誤って参照する可能性があるため、VPC IDで検索範囲を限定する。

## 実行結果

実行コマンド:

```bash
./06_security_group_setup.sh
```

実行時に確認された主なリソースIDと許可CIDR:

| 種別 | 値 |
| :--- | :--- |
| VPC | vpc-09872a034f259a5f3 |
| Bastion Security Group | sg-04d7173674c03abb7 |
| ELB Security Group | sg-0b3b4f92ca2be5015 |
| SSH許可CIDR | 210.194.88.203/32 |

作成されたIngress Rule:

| Security Group | Protocol | Port | Source | Description |
| :--- | :--- | :--- | :--- | :--- |
| sample-sg-bastion | tcp | 22 | 210.194.88.203/32 | SSH access for learning |
| sample-sg-elb | tcp | 80 | 0.0.0.0/0 | HTTP access |
| sample-sg-elb | tcp | 443 | 0.0.0.0/0 | HTTPS access |

払い出されたSecurity Group Rule ID:

| Rule | Security Group Rule ID |
| :--- | :--- |
| Bastion SSH 22/tcp | sgr-0517b24d64c42d517 |
| ELB HTTP 80/tcp | sgr-04300dda8c7ed0bad |
| ELB HTTPS 443/tcp | sgr-054f274d16b6f6abd |

確認結果として、Bastion用Security Groupは自分のグローバルIP `/32` からのSSHのみを許可し、ELB用Security GroupはHTTP / HTTPSをインターネット向けに許可する構成になった。

`210.194.88.203/32` は実行時点のグローバルIPである。作業場所や回線が変わると、このCIDRからSSHできなくなる可能性がある。その場合は、古いSSH許可ルールを削除し、新しいグローバルIP `/32` を追加する。

確認例:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<VPC_ID> Name=group-name,Values=sample-sg-bastion,sample-sg-elb \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[0].CidrIp,RuleDescription:IpRanges[0].Description}}' \
  --output table
```

## 変更前確認

Security Group変更前には、少なくとも以下を確認する。

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<VPC_ID> \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

確認ポイント:

- 対象VPCが正しいこと
- 同じ名前のSecurity Groupが既に存在するか
- 既存Ingress Ruleがあるか
- BastionのSSH許可CIDRが現在の作業場所と一致しているか
- ALB用Security GroupがHTTP / HTTPSをどこから許可しているか
- 既存Security GroupがEC2、ALB、RDSなどに関連付いていないか

案件作業では、変更前のSecurity Group設定をJSONで保存すると、変更後比較と切り戻し判断に使いやすい。

## 変更後確認

スクリプト実行後は、以下を確認する。

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<VPC_ID> Name=group-name,Values=sample-sg-bastion,sample-sg-elb \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Ingress:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[*].CidrIp,Description:IpRanges[*].Description}}' \
  --output json
```

確認ポイント:

- `sample-sg-bastion` が存在すること
- `sample-sg-bastion` にSSH 22/tcpが許可されていること
- SSHの送信元が自分のグローバルIP `/32` であること
- `sample-sg-elb` が存在すること
- `sample-sg-elb` にHTTP 80/tcpが許可されていること
- `sample-sg-elb` にHTTPS 443/tcpが許可されていること
- 余計なIngress Ruleが追加されていないこと

将来的にEC2やALBを作成した後は、以下の疎通確認も行う。

- 自分のグローバルIPからBastionへSSHできること
- 許可していないIPからBastionへSSHできないこと
- インターネットからALBのHTTP / HTTPSへ到達できること
- ALBからWebサーバーへ転送できること

## 切り戻し方法

Ingress Ruleを削除する場合は、`revoke-security-group-ingress` を使う。

BastionのSSH許可ルールを削除する例:

```bash
aws ec2 revoke-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <BASTION_SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 22 \
  --cidr <SSH_ALLOWED_CIDR>
```

ELBのHTTP許可ルールを削除する例:

```bash
aws ec2 revoke-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <ELB_SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

ELBのHTTPS許可ルールを削除する例:

```bash
aws ec2 revoke-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <ELB_SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

Security Group自体を削除する場合:

```bash
aws ec2 delete-security-group \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <SECURITY_GROUP_ID>
```

Security Groupは、EC2、ALB、RDSなどに関連付いている場合は削除できない。削除前に関連リソースを確認する。

## 削除時の注意

`06_security_group_setup.sh` を実行すると、以下のSecurity Groupが作成または再利用される。

- `sample-sg-bastion`
- `sample-sg-elb`

`cleanup_network.sh` では、`01` から `06` までの作成リソースとして、これらのSecurity Groupも削除対象にしている。

ただし、後続でEC2やALBを作成し、Security Groupが関連付けられている場合は削除できない。その場合は、先にEC2やALBなどの依存リソースを削除または関連解除する必要がある。

default Security GroupはVPC標準リソースであり、単体削除しない。VPC削除時に一緒に削除される。

## 影響範囲

Security Group変更は、関連付けられたリソースの通信可否に影響する。

本構成で影響を受ける想定リソースは以下である。

| Security Group | 関連予定リソース | 影響 |
| :--- | :--- | :--- |
| sample-sg-bastion | Bastion EC2 | SSH接続可否 |
| sample-sg-elb | ALB | HTTP / HTTPS公開可否 |

Security Groupを誤ると、以下のような事象が起きる。

- BastionへSSHできない
- BastionのSSHを広く公開してしまう
- ALBへHTTP / HTTPSで接続できない
- ALBを意図せず広く公開してしまう
- 後続のWeb Security Group設定で、ALBからWebサーバーへ接続できない

## 気をつける点

- Security Groupはステートフルである
- Ingressで許可した通信の戻り通信は自動的に許可される
- NACLはステートレスであり、Security Groupとは挙動が違う
- Security Group名はVPC内で一意である
- 別VPCには同名Security Groupを作成できるため、VPC IDで絞り込む
- BastionのSSHは `0.0.0.0/0` で開けない
- 自分のグローバルIPが変わると、BastionへSSHできなくなることがある
- ALBの `0.0.0.0/0` 許可は要件に応じて妥当性を確認する
- 同じIngress Ruleを再追加すると重複エラーになる
- Security Group削除前には、関連リソースがないか確認する

## 案件実務ポイント

今回の銀行案件では、影響調査済みのAWS設定変更、テスト、手順書作成が中心になる見込みである。

Security Group変更作業では、以下の観点が重要になる。

- 対象VPCとSecurity Groupが正しいことを確認する
- 変更前のIngress / Egress Ruleを証跡として保存する
- 追加、削除、変更する通信要件を明確にする
- 許可する送信元がCIDRなのか、別Security Groupなのかを確認する
- 変更後、許可されるべき通信が通ることを確認する
- 変更後、拒否されるべき通信が拒否されることを確認する
- 異常時に戻せるよう、`revoke` または再追加コマンドを用意する

説明例:

```text
Bastion用Security Groupには、自分のグローバルIP /32 からのSSHのみを許可しました。
ELB用Security Groupには、外部公開用としてHTTP 80番とHTTPS 443番を許可しました。
既存Security Groupと既存Ingress Ruleを確認してから作成・追加するため、
再実行時に重複作成や重複ルール追加が起きない構成にしています。
```

## 試験対策ポイント

AWS試験では、Security GroupとNACLの違い、送信元指定、ステートフル/ステートレスの違いが頻出である。

押さえるポイント:

- Security Groupはステートフル
- NACLはステートレス
- Security Groupは許可ルールのみを持つ
- 明示的な拒否はSecurity Groupではなく、NACLやAWS Network Firewallなどで考える
- Security Groupの送信元にはCIDRだけでなく、別Security Groupを指定できる
- Public Subnetに置いたBastionでも、SSHを広く開けるべきではない
- ALB用Security Groupは外部からHTTP / HTTPSを受ける
- Webサーバー用Security Groupでは、ALB用Security Groupからのアプリケーションポートだけを許可する設計がよく使われる
- RDS用Security Groupでは、Webサーバー用Security GroupからのDBポートだけを許可する設計がよく使われる

## 今後の確認

このスクリプトは再実行耐性を入れているため、再度実行した場合は以下のような挙動になる想定である。

- 既存Security Groupを再利用する
- 既存の同一Ingress Ruleはスキップする
- Security Groupが存在しない場合だけ作成する
- 同名Security Groupが複数ある場合は停止する

再実行確認コマンド:

```bash
./06_security_group_setup.sh
```

今後の拡張として、設計書にある以下のSecurity Groupを追加する。

- `sample-sg-web`
- `sample-sg-db`
- `sample-sg-elasticache`

これらは、送信元をCIDRではなく別Security Groupで指定する構成になる。
