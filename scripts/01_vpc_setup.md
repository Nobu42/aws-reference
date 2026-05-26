# 01_vpc_setup.sh 解説

## 概要

`01_vpc_setup.sh` は、AWS上にWebアプリケーション基盤の土台となるVPCを作成するためのスクリプトである。

この段階では、サブネット、Internet Gateway、NAT Gateway、Route Tableなどはまだ作成しない。まずはAWSネットワーク全体の入れ物となるVPCを作成し、後続のリソース作成で必要になるVPC IDを取得する。

作成するVPCの設定は以下である。

| 項目 | 値 |
| :--- | :--- |
| Name Tag | sample-vpc |
| IPv4 CIDR | 10.0.0.0/16 |
| Tenancy | default |
| DNS Hostnames | enabled |
| DNS Support | enabled |
| Region | ap-northeast-1 |
| AWS CLI Profile | learning |

## 前提条件

このスクリプトを実行する前に、AWS CLIで `learning` プロファイルが設定されている必要がある。

確認コマンド:

```bash
aws configure list --profile learning
```

また、作成先のAWSアカウントが想定どおりであることを確認する。

```bash
aws sts get-caller-identity --profile learning
```

このスクリプトではVPCを作成するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:CreateVpc`
- `ec2:CreateTags`
- `ec2:ModifyVpcAttribute`
- `ec2:DescribeVpcs`
- `ec2:DescribeVpcAttribute`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、VPC名、CIDRを定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. VPCを作成する
6. 作成されたVPC IDを変数に保存する
7. VPCのDNSホスト名を有効化する
8. VPCのDNS解決を有効化する
9. 作成されたVPCの状態を確認する

## Bashの安全設定

```bash
#!/bin/bash
set -euo pipefail
```

`#!/bin/bash` は、このスクリプトをBashで実行するための指定である。

`set -euo pipefail` は、シェルスクリプトを安全に実行するための設定である。

| 設定 | 意味 |
| :--- | :--- |
| `-e` | コマンドが失敗した時点でスクリプトを終了する |
| `-u` | 未定義の変数を使った場合にエラーにする |
| `-o pipefail` | パイプ処理の途中で失敗した場合もエラーとして扱う |

AWSリソース作成スクリプトでは、途中の失敗に気づかず後続処理が進むと、想定外の状態になることがある。そのため、失敗した時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"
```

`PROFILE` には、AWS CLIで利用する認証情報のプロファイル名を指定する。

このスクリプトでは `learning` プロファイルを使う。つまり、実行時には `~/.aws/credentials` または `~/.aws/config` に `learning` の設定が存在している必要がある。

`REGION` には、AWSリソースを作成するリージョンを指定する。

今回は東京リージョンである `ap-northeast-1` を使う。

## VPC設定

```bash
VPC_NAME="sample-vpc"
VPC_CIDR="10.0.0.0/16"
```

`VPC_NAME` は、作成するVPCに付与するNameタグである。

AWSのVPC IDは `vpc-xxxxxxxxxxxxxxxxx` のような自動生成IDになるため、人間が識別しやすいようにNameタグを付ける。

`VPC_CIDR` は、VPC全体で使用するプライベートIPアドレス範囲である。

`10.0.0.0/16` は、`10.0.0.0` から `10.0.255.255` までの範囲を持つ。この範囲の中から、後続でPublic SubnetやPrivate SubnetのCIDRを切り出す。

今回の設計では、以下のようにサブネットを分割する前提である。

| サブネット名 | CIDR |
| :--- | :--- |
| sample-subnet-public01 | 10.0.0.0/20 |
| sample-subnet-public02 | 10.0.16.0/20 |
| sample-subnet-private01 | 10.0.64.0/20 |
| sample-subnet-private02 | 10.0.80.0/20 |

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStackを使っていた環境では、`aws` コマンドがLocalStack向けのエンドポイントへ接続するようにaliasや環境変数が設定されている場合がある。

このスクリプトは実AWSにリソースを作成するため、LocalStack向けの設定が残っていると意図したAWSアカウントではなくローカル環境へ接続してしまう可能性がある。

そのため、実行前に以下を無効化している。

| コマンド | 目的 |
| :--- | :--- |
| `unalias aws` | `aws` コマンドに設定されたaliasを解除する |
| `unset AWS_ENDPOINT_URL` | AWS CLIの接続先上書き設定を解除する |
| `unset LOCALSTACK_HOST` | LocalStackホスト設定を解除する |

`unalias aws 2>/dev/null || true` は、aliasが存在しない場合でもスクリプトが止まらないようにするための書き方である。

## Caller Identityの確認

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

`aws sts get-caller-identity` は、現在のAWS CLI認証情報がどのAWSアカウント、どのIAMユーザーまたはIAMロールとして実行されているかを確認するコマンドである。

VPCのような実リソースを作成する前に、必ずこの確認を行う。

出力例:

```txt
Account: 445405559057
Arn:     arn:aws:iam::445405559057:user/nobu
UserId:  AIDAXXXXXXXXXXXXXXXX
```

ここで確認するポイントは以下である。

- `Account` が想定したAWSアカウントIDであること
- `Arn` が想定したIAMユーザーまたはIAMロールであること
- 個人用、検証用、本番用などのアカウントを取り違えていないこと

## VPCの作成

```bash
VPC_ID=$(aws ec2 create-vpc \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cidr-block "$VPC_CIDR" \
  --instance-tenancy default \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Vpc.VpcId' \
  --output text)
```

`aws ec2 create-vpc` でVPCを作成する。

主なオプションの意味は以下である。

| オプション | 説明 |
| :--- | :--- |
| `--profile "$PROFILE"` | 使用するAWS CLIプロファイルを指定する |
| `--region "$REGION"` | VPCを作成するリージョンを指定する |
| `--cidr-block "$VPC_CIDR"` | VPC全体のIPv4 CIDRを指定する |
| `--instance-tenancy default` | EC2を通常の共有ハードウェア上で起動する設定 |
| `--tag-specifications` | 作成時にタグを付与する |
| `--query 'Vpc.VpcId'` | コマンド結果からVPC IDだけを取り出す |
| `--output text` | 出力をプレーンテキストにする |

`--instance-tenancy default` は、通常のEC2起動方式である。

専有ホストや専有インスタンスを使う場合は別の設定になるが、一般的なWebアプリケーション基盤では `default` を利用する。

## タグ設計

```bash
--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]"
```

VPC作成時に、以下のタグを付与している。

| Key | Value | 用途 |
| :--- | :--- | :--- |
| Name | sample-vpc | AWSコンソール上で識別しやすくする |
| Project | terraform-iac-lab | 関連リソースをプロジェクト単位で識別する |
| Environment | learning | 環境種別を識別する |

タグは、後続の確認スクリプトや削除スクリプトで対象リソースを絞り込む際にも役立つ。

## VPC IDの保存

```bash
VPC_ID=$(...)
```

作成されたVPC IDを `VPC_ID` 変数に保存している。

VPC IDは、後続の処理で必要になる。

例えば、以下のようなリソースを作成する際にVPC IDを指定する。

- Subnet
- Internet Gatewayのアタッチ
- Route Table
- Security Group
- Private Hosted Zoneの関連付け

実行後には、以下のように作成されたVPC IDを表示する。

```bash
echo "New VPC ID: $VPC_ID"
```

## DNSホスト名の有効化

```bash
aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'
```

`enableDnsHostnames` を有効化する。

これは、VPC内で起動したEC2インスタンスにAWS管理のDNSホスト名を割り当てるための設定である。

この設定を有効にしておくことで、EC2やAWSサービスのDNS名を扱いやすくなる。

今回の構成では、後続でALB、RDS、Private Hosted ZoneなどDNS名を利用するリソースを扱うため、有効化しておく。

## DNS解決の有効化

```bash
aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-support '{"Value":true}'
```

`enableDnsSupport` を有効化する。

これは、VPC内でAWS提供DNSによる名前解決を利用するための設定である。

この設定が無効だと、VPC内のEC2からAWSサービスのDNS名やRoute 53 Private Hosted Zoneの名前解決が期待どおりに動作しない可能性がある。

WebサーバーからRDSエンドポイントやElastiCacheエンドポイントへ接続する構成では、DNS解決が重要になるため有効化する。

## VPC作成結果の確認

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State,DNSHost:EnableDnsHostnames.Value,DNSSupport:EnableDnsSupport.Value}' \
  --output table
```

`aws ec2 describe-vpcs` で、作成したVPCの状態を確認する。

このコマンドでは、以下の情報を表示しようとしている。

- VPC ID
- Nameタグ
- CIDR
- State
- DNS Hostnames
- DNS Support

ただし、`describe-vpcs` の出力には `EnableDnsHostnames` や `EnableDnsSupport` が直接含まれないため、DNS関連の列は `None` と表示される場合がある。

実際にDNS設定が有効かどうかは、次の `describe-vpc-attribute` で確認するのが確実である。

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <作成されたVPC ID> \
  --attribute enableDnsHostnames \
  --output table
```

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <作成されたVPC ID> \
  --attribute enableDnsSupport \
  --output table
```

どちらも `Value` が `True` であれば、DNS設定は正しく有効化されている。

## 実行例

```bash
./01_vpc_setup.sh
```

実行に成功すると、以下のような情報が表示される。

```txt
=== Caller Identity ===
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu

=== Create VPC ===
New VPC ID: vpc-xxxxxxxxxxxxxxxxx
```

VPCの状態が `available` であれば、VPC作成は完了している。

## 実行後に確認すること

スクリプト実行後は、以下を確認する。

1. VPCが作成されていること
2. VPCのCIDRが `10.0.0.0/16` であること
3. Nameタグが `sample-vpc` であること
4. Stateが `available` であること
5. `enableDnsHostnames` が `True` であること
6. `enableDnsSupport` が `True` であること

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table
```

## 注意点

このスクリプトは、同じNameタグのVPCが既に存在するかどうかを事前確認していない。

そのため、同じスクリプトを複数回実行すると、`sample-vpc` というNameタグを持つVPCが複数作成される可能性がある。

再実行する場合は、事前に既存VPCを確認してする。

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}' \
  --output table
```

不要なVPCが作成された場合は、後続の削除スクリプトまたはAWS CLIで削除する。

ただし、サブネット、Internet Gateway、Route Table、Security Groupなどが関連付いているVPCは、そのままでは削除できない。関連リソースを先に削除する必要がある。

## 次のステップ

VPC作成後は、このVPC IDを使ってサブネットを作成する。

設計上、次に作成するサブネットは以下の4つである。

| 区分 | サブネット名 | AZ | CIDR |
| :--- | :--- | :--- | :--- |
| Public | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 |
| Public | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 |
| Private | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 |
| Private | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 |

この時点では、VPCというネットワークの枠だけが作成された状態である。

実際にEC2、ALB、RDSなどを配置するためには、次工程でサブネット、ルートテーブル、Internet Gateway、NAT Gatewayなどを作成していく。
