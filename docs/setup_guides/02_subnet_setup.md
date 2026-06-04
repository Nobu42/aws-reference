# 02_subnet_setup.sh 解説

## 概要

`02_subnet_setup.sh` は、`01_vpc_setup.sh` で作成したVPC内に、Public SubnetとPrivate Subnetをそれぞれ2つずつ作成するスクリプトである。

この段階では、Internet Gateway、NAT Gateway、Route Tableはまだ作成しない。まずはEC2、ALB、RDS、ElastiCacheなどを配置するためのネットワーク領域をAZごとに分割する。

作成するサブネットは以下である。

| 種別 | サブネット名 | AZ | CIDR | Public IP自動割り当て |
| :--- | :--- | :--- | :--- | :--- |
| Public | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 | 有効 |
| Public | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 | 有効 |
| Private | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 | 無効 |
| Private | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 | 無効 |

## 前提条件

このスクリプトを実行する前に、`01_vpc_setup.sh` により `sample-vpc` が作成されている必要がある。

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}' \
  --output table
```

また、AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではサブネット作成とサブネット属性変更を行うため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:CreateSubnet`
- `ec2:CreateTags`
- `ec2:ModifySubnetAttribute`
- `ec2:DescribeSubnets`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、対象VPC名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `sample-vpc` のVPC IDを取得する
6. Public Subnet 01を作成する
7. Public Subnet 01のPublic IP自動割り当てを有効化する
8. Public Subnet 02を作成する
9. Public Subnet 02のPublic IP自動割り当てを有効化する
10. Private Subnet 01を作成する
11. Private Subnet 02を作成する
12. 作成されたSubnet IDを表示する
13. VPC内のサブネット一覧を確認する

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

AWSリソース作成スクリプトでは、途中の失敗に気づかず後続処理が進むと、想定外のリソースが作成される可能性がある。そのため、失敗した時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、サブネットを作成するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`VPC_NAME` は、サブネットを作成する対象VPCのNameタグである。前工程で作成した `sample-vpc` を検索するために使用する。

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続する可能性がある。

このスクリプトは実AWSにサブネットを作成するため、LocalStack関連設定を無効化する。

| コマンド | 目的 |
| :--- | :--- |
| `unalias aws` | `aws` コマンドに設定されたaliasを解除する |
| `unset AWS_ENDPOINT_URL` | AWS CLIの接続先上書き設定を解除する |
| `unset LOCALSTACK_HOST` | LocalStackホスト設定を解除する |

## Caller Identityの確認

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

現在のAWS CLI認証情報が、どのAWSアカウント、IAMユーザー、IAMロールとして実行されているかを確認する。

確認ポイント:

- `Account` が想定したAWSアカウントIDであること
- `Arn` が想定したIAMユーザーまたはIAMロールであること
- 本番、検証、開発アカウントを取り違えていないこと

## VPC IDの取得

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
```

`aws ec2 describe-vpcs` で、Nameタグが `sample-vpc` のVPCを検索し、VPC IDを取得する。

サブネット作成には、対象VPCのVPC IDが必要である。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `--profile "$PROFILE"` | 使用するAWS CLIプロファイル |
| `--region "$REGION"` | 操作対象リージョン |
| `--filters Name=tag:Name,Values="$VPC_NAME"` | Nameタグが `sample-vpc` のVPCに絞り込む |
| `--query 'Vpcs[0].VpcId'` | 検索結果の先頭VPCからVPC IDだけを取り出す |
| `--output text` | VPC IDだけを文字列として取得する |

`Vpcs[0].VpcId` は、検索結果の先頭要素を使用する指定である。

同じNameタグのVPCが複数ある場合、意図しないVPCを選ぶ可能性がある。再作成や検証を繰り返す場合は、事前にVPCが1つだけであることを確認する。

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}' \
  --output table
```

## VPC未検出時の停止処理

```bash
if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "Error: VPC not found. Please run 01_vpc_setup.sh first."
  exit 1
fi
```

対象VPCが見つからない場合、AWS CLIは `None` または空文字を返すことがある。

VPC IDがない状態で後続の `create-subnet` を実行すると、原因が分かりにくいエラーになる。そのため、この時点で明示的に停止する。

## Public Subnet 01の作成

```bash
PUB01_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.0.0/20 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=public}]' \
  --query 'Subnet.SubnetId' \
  --output text)
```

`aws ec2 create-subnet` で、1つ目のPublic Subnetを作成する。

このサブネットは、後続でInternet Gatewayへのルートを設定し、ALB、NAT Gateway、踏み台サーバーなどを配置する用途で使用する。

主な設定は以下である。

| 項目 | 値 |
| :--- | :--- |
| Subnet名 | sample-subnet-public01 |
| VPC | sample-vpc |
| CIDR | 10.0.0.0/20 |
| AZ | ap-northeast-1a |
| Typeタグ | public |

## Public IP自動割り当ての有効化

```bash
aws ec2 modify-subnet-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB01_ID" \
  --map-public-ip-on-launch
```

`modify-subnet-attribute` で、サブネット属性を変更する。

`--map-public-ip-on-launch` を指定すると、このサブネットでEC2を起動した際にPublic IPが自動割り当てされる。

Public SubnetとしてEC2を外部接続させる場合に必要な設定である。

ただし、この設定だけではインターネット接続は成立しない。Internet GatewayとRoute Tableで `0.0.0.0/0` のルートを設定して初めて、外部通信できるPublic Subnetになる。

## Public Subnet 02の作成

```bash
PUB02_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.16.0/20 \
  --availability-zone ap-northeast-1c \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=public}]' \
  --query 'Subnet.SubnetId' \
  --output text)
```

2つ目のPublic Subnetを `ap-northeast-1c` に作成する。

ALBは複数AZのサブネットを指定する構成が一般的である。そのため、Public Subnetを2つのAZに分散して作成する。

Public Subnet 02でも、Public IP自動割り当てを有効化する。

```bash
aws ec2 modify-subnet-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB02_ID" \
  --map-public-ip-on-launch
```

## Private Subnet 01の作成

```bash
PRI01_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.64.0/20 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=private}]' \
  --query 'Subnet.SubnetId' \
  --output text)
```

1つ目のPrivate Subnetを `ap-northeast-1a` に作成する。

Private Subnetには、外部から直接到達させたくないWebサーバー、RDS、ElastiCacheなどを配置する。

Private Subnetでは、Public IP自動割り当てを有効化しない。

## Private Subnet 02の作成

```bash
PRI02_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.80.0/20 \
  --availability-zone ap-northeast-1c \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=private}]' \
  --query 'Subnet.SubnetId' \
  --output text)
```

2つ目のPrivate Subnetを `ap-northeast-1c` に作成する。

Webサーバー、RDS Subnet Group、ElastiCache Subnet Groupを複数AZ構成にするため、Private Subnetも2つのAZに分散する。

## tag-specificationsの意味

サブネット作成時には、以下のようなタグを付与している。

```bash
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=private}]'
```

これは、AWS CLIのshorthand syntaxである。

Python風に見ると、以下のような構造である。

```python
{
    "ResourceType": "subnet",
    "Tags": [
        {"Key": "Name", "Value": "sample-subnet-private01"},
        {"Key": "Project", "Value": "terraform-iac-lab"},
        {"Key": "Environment", "Value": "learning"},
        {"Key": "Type", "Value": "private"},
    ],
}
```

タグの意味は以下である。

| Key | Value | 用途 |
| :--- | :--- | :--- |
| Name | sample-subnet-public01 など | AWSコンソール上で識別しやすくする |
| Project | terraform-iac-lab | 関連リソースをプロジェクト単位で識別する |
| Environment | learning | 環境種別を識別する |
| Type | public / private | Public SubnetかPrivate Subnetかを識別する |

`Type` タグはAWS標準の機能ではなく、管理用に付けている任意タグである。

## 作成されたSubnet IDの表示

```bash
echo "Subnets created:"
echo "  Public : $PUB01_ID, $PUB02_ID"
echo "  Private: $PRI01_ID, $PRI02_ID"
```

作成されたSubnet IDを表示する。

Subnet IDは、後続のInternet Gateway、NAT Gateway、Route Table、EC2、ALB、RDS Subnet Group、ElastiCache Subnet Group作成で使用する。

実行例:

```txt
Subnets created:
  Public : subnet-0f7793dab26b6a015, subnet-002b20a5d21e91c73
  Private: subnet-0659fd27b43f6a41b, subnet-0708e5f5f305986e2
```

## サブネット一覧の確認

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table
```

VPC内のサブネット一覧を表示する。

表示する項目は以下である。

| 出力列 | 取得元 | 意味 |
| :--- | :--- | :--- |
| Name | `Tags[?Key==\`Name\`].Value|[0]` | Nameタグの値 |
| Type | `Tags[?Key==\`Type\`].Value|[0]` | Typeタグの値 |
| AZ | `AvailabilityZone` | サブネットのAZ |
| CIDR | `CidrBlock` | サブネットのCIDR |
| PublicIP | `MapPublicIpOnLaunch` | EC2起動時のPublic IP自動割り当て |
| ID | `SubnetId` | Subnet ID |

## JMESPathの補足

`--query` ではJMESPathを使って、AWS CLIのJSON出力を整形している。

```txt
Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}
```

`Subnets[*]` は、`Subnets` 配列の全要素を対象にする指定である。

```txt
Tags[?Key==`Name`]
```

`?` はフィルターを意味する。

`Tags[?Key==\`Name\`]` は、`Tags` 配列の中から `Key` が `Name` の要素だけを取り出す。

Python風に書くと、以下に近い。

```python
[tag for tag in Tags if tag["Key"] == "Name"]
```

その結果から `.Value` で値だけを取り出し、`|[0]` で先頭の1件を取得する。

つまり、以下は「Nameタグの値を1つ取り出す」という意味である。

```txt
Tags[?Key==`Name`].Value|[0]
```

同様に、以下は「Typeタグの値を1つ取り出す」という意味である。

```txt
Tags[?Key==`Type`].Value|[0]
```

## 実行結果

実行に成功すると、以下のような結果になる。

```txt
Subnets created:
  Public : subnet-0f7793dab26b6a015, subnet-002b20a5d21e91c73
  Private: subnet-0659fd27b43f6a41b, subnet-0708e5f5f305986e2
```

確認表では、Public Subnetの `PublicIP` が `True`、Private Subnetの `PublicIP` が `False` になっていれば期待どおりである。

```txt
sample-subnet-public01   PublicIP True
sample-subnet-public02   PublicIP True
sample-subnet-private01  PublicIP False
sample-subnet-private02  PublicIP False
```

## 実行後に確認すること

スクリプト実行後は、以下を確認する。

1. サブネットが4つ作成されていること
2. CIDRが設計どおりであること
3. AZが `ap-northeast-1a` と `ap-northeast-1c` に分散していること
4. Public Subnetの `MapPublicIpOnLaunch` が `True` であること
5. Private Subnetの `MapPublicIpOnLaunch` が `False` であること
6. Name、Project、Environment、Typeタグが付与されていること

確認コマンド:

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'sort_by(Subnets,&Tags[?Key==`Name`].Value|[0])[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table
```

`sort_by` を使うと、Nameタグ順に並べて表示できる。

## 注意点

このスクリプトは、既存サブネットの有無を事前確認していない。

そのため、同じVPC内で再実行すると、同じCIDRのサブネットを作成しようとして `InvalidSubnet.Conflict` などのエラーになる可能性がある。

再実行する場合は、事前に既存サブネットを確認する。

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,AZ:AvailabilityZone,ID:SubnetId}' \
  --output table
```

また、`sample-vpc` というNameタグを持つVPCが複数存在する場合、`Vpcs[0].VpcId` により先頭のVPCが選択される。

複数VPCがある場合は、対象VPC IDを明示的に指定する方式に変更することを検討する。

## 次のステップ

サブネット作成後は、Internet GatewayとRoute Tableを作成する。

次工程の主な作業は以下である。

- Internet Gateway `sample-igw` を作成する
- `sample-vpc` にInternet Gatewayをアタッチする
- Public Route Tableを作成する
- Public Route Tableに `0.0.0.0/0 -> sample-igw` のルートを追加する
- Public Subnet 01 / 02をPublic Route Tableに関連付ける

この作業により、Public Subnetがインターネットと通信できる状態になる。
