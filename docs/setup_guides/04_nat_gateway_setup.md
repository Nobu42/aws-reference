# 04_nat_gateway_setup.sh 解説

## 概要

`04_nat_gateway_setup.sh` は、Private Subnetからインターネットへ外向き通信するためのNAT Gatewayを作成するスクリプトである。

NAT GatewayはPrivate Subnetに配置したEC2などが、OSパッケージ更新、外部API接続、S3やSESなどのPublic Endpoint利用を行うための出口として使う。外部からPrivate Subnet内のリソースへ直接接続するための入口ではない。

本構成では、可用性とAZ単位の経路分離を意識し、Public SubnetごとにNAT Gatewayを1台ずつ作成する。

| 名前 | 配置先Public Subnet | AZ | 用途 |
| :--- | :--- | :--- | :--- |
| sample-ngw-01 | sample-subnet-public01 | ap-northeast-1a | Private Subnet 01からの外向き通信 |
| sample-ngw-02 | sample-subnet-public02 | ap-northeast-1c | Private Subnet 02からの外向き通信 |

NAT GatewayにはElastic IPを割り当てる。Elastic IPはNAT Gatewayのインターネット側Public IPv4アドレスとして使われる。

このスクリプトの完了時点では、NAT Gateway自体は `available` になる。ただし、Private Subnetからインターネットへ通信するには、後続のRoute Table設定が必要である。

## 前提条件

このスクリプトを実行する前に、以下のスクリプトが完了している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public Subnet / Private Subnetを作成する |
| `03_internetgateway_setup.sh` | Internet Gatewayを作成し、VPCへアタッチする |

NAT GatewayはPublic Subnetに作成する。Public SubnetがInternet Gatewayへ到達できる経路は後続のRoute Tableで設定するが、構成上はInternet Gatewayの存在が前提になる。

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-subnet-public01,sample-subnet-public02 \
  --query 'Subnets[*].{ID:SubnetId,Name:Tags[?Key==`Name`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch}' \
  --output table

aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=attachment.vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

また、AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではVPC、Subnet、NAT Gateway、Elastic IPを操作するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`
- `ec2:DescribeNatGateways`
- `ec2:AllocateAddress`
- `ec2:CreateNatGateway`
- `ec2:CreateTags`

削除運用まで含める場合は、以下も必要になる。

- `ec2:DeleteNatGateway`
- `ec2:ReleaseAddress`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、VPC名、Subnet名、NAT Gateway名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `sample-vpc` のVPC IDを取得する
6. VPC IDとNameタグでPublic Subnet 01 / 02を取得する
7. 既存の `sample-ngw-01` を確認する
8. 存在しない場合、Elastic IP 01を確保し、NAT Gateway 01を作成する
9. 既存の `sample-ngw-02` を確認する
10. 存在しない場合、Elastic IP 02を確保し、NAT Gateway 02を作成する
11. NAT Gatewayが `available` になるまで待つ
12. NAT Gatewayの状態、Subnet、Public IP、Allocation IDを確認する

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

NAT GatewayとElastic IPは課金対象である。途中の失敗を見落として後続処理が進むと、不要な課金リソースが残る可能性があるため、失敗時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
PUBLIC_SUBNET_01_NAME="sample-subnet-public01"
PUBLIC_SUBNET_02_NAME="sample-subnet-public02"
NAT_GATEWAY_01_NAME="sample-ngw-01"
NAT_GATEWAY_02_NAME="sample-ngw-02"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、NAT Gatewayを作成するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`VPC_NAME` は、NAT Gatewayを作成する対象VPCのNameタグである。

`PUBLIC_SUBNET_01_NAME` と `PUBLIC_SUBNET_02_NAME` は、NAT Gatewayを配置するPublic SubnetのNameタグである。

`NAT_GATEWAY_01_NAME` と `NAT_GATEWAY_02_NAME` は、作成または確認するNAT GatewayのNameタグである。

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続する可能性がある。

このスクリプトは実AWSにNAT GatewayとElastic IPを作成するため、LocalStack関連設定を無効化する。

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

NAT Gatewayは起動時間に応じた料金が発生する。作成前に操作先アカウントを確認する意義が大きい。

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

このVPC IDは、後続のSubnet検索とNAT Gateway既存確認で使用する。SubnetをNameタグだけで検索すると、別VPCに同名Subnetが存在する場合に誤取得する可能性がある。そのため、VPC IDで検索範囲を絞る。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `--profile "$PROFILE"` | 使用するAWS CLIプロファイル |
| `--region "$REGION"` | 操作対象リージョン |
| `--filters Name=tag:Name,Values="$VPC_NAME"` | Nameタグが `sample-vpc` のVPCに絞り込む |
| `--query 'Vpcs[0].VpcId'` | 検索結果の先頭VPCからVPC IDだけを取り出す |
| `--output text` | VPC IDだけを文字列として取得する |

## VPC未検出時の停止処理

```bash
if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "Error: VPC not found. Please run 01_vpc_setup.sh first."
  exit 1
fi
```

対象VPCが見つからない場合、AWS CLIは `None` または空文字を返すことがある。

VPC IDがない状態でSubnet検索やNAT Gateway作成を続けると、原因が分かりにくいエラーになる。そのため、この時点で明示的に停止する。

## Public Subnet IDの取得

```bash
PUB01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUBLIC_SUBNET_01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
```

Public Subnet 01のSubnet IDを取得する。

このスクリプトでは、`Name=tag:Name` だけでなく `Name=vpc-id` でも絞り込む。これにより、別VPCに同じNameタグのSubnetがある場合の誤取得を防ぐ。

Public Subnet 02も同じ考え方で取得する。

```bash
PUB02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUBLIC_SUBNET_02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
```

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `describe-subnets` | Subnetの一覧または詳細を取得する |
| `--filters Name=vpc-id,Values="$VPC_ID"` | 対象VPC内のSubnetに絞り込む |
| `--filters Name=tag:Name,Values="$PUBLIC_SUBNET_01_NAME"` | NameタグがPublic Subnet 01のSubnetに絞り込む |
| `--query 'Subnets[0].SubnetId'` | 検索結果の先頭SubnetからSubnet IDだけを取り出す |
| `--output text` | Subnet IDだけを文字列として取得する |

## Public Subnet未検出時の停止処理

```bash
if [ "$PUB01_ID" = "None" ] || [ -z "$PUB01_ID" ]; then
  echo "Error: Public subnet 01 not found. Please run 02_subnet_setup.sh first."
  exit 1
fi
```

NAT GatewayはSubnet IDを指定して作成する。Public Subnetが見つからない状態ではNAT Gatewayを作成できないため、ここで停止する。

Public Subnet 02も同じ条件で確認する。

## 既存NAT Gateway 01の確認

```bash
EXISTING_NGW01_ID=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$NAT_GATEWAY_01_NAME" Name=state,Values=pending,available \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)
```

同じVPC内に `sample-ngw-01` がすでに存在しないか確認する。

NAT Gatewayは課金対象である。既存確認なしで再実行すると、同名用途のNAT GatewayとElastic IPを重複作成する可能性がある。そのため、`pending` または `available` のNAT Gatewayが存在する場合は既存リソースとして扱う。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `describe-nat-gateways` | NAT Gatewayの一覧または詳細を取得する |
| `--filter Name=vpc-id,Values="$VPC_ID"` | 対象VPC内のNAT Gatewayに絞り込む |
| `--filter Name=tag:Name,Values="$NAT_GATEWAY_01_NAME"` | Nameタグが `sample-ngw-01` のNAT Gatewayに絞り込む |
| `--filter Name=state,Values=pending,available` | 作成中または利用可能なNAT Gatewayに絞り込む |
| `--query 'NatGateways[0].NatGatewayId'` | 先頭のNAT Gateway IDだけを取り出す |
| `--output text` | NAT Gateway IDだけを文字列として取得する |

`describe-nat-gateways` では、EC2の他のdescribe系と異なり、オプション名が `--filter` である点に注意する。

## 既存NAT Gatewayがある場合の処理

```bash
if [ "$EXISTING_NGW01_ID" != "None" ] && [ -n "$EXISTING_NGW01_ID" ]; then
  NGW01_ID="$EXISTING_NGW01_ID"
  echo "NAT Gateway 01 already exists: $NGW01_ID"
else
  ...
fi
```

`EXISTING_NGW01_ID` に値がある場合、対象VPC内に `sample-ngw-01` が存在すると判断する。

この場合は、新しいElastic IPを確保せず、NAT Gatewayも作成しない。既存のNAT Gateway IDを `NGW01_ID` に代入し、後続のwaitと確認処理に進む。

NAT Gateway 02も同じ考え方で確認する。

## Elastic IPの確保

```bash
ALLOC_ID_01=$(aws ec2 allocate-address \
  --profile "$PROFILE" \
  --region "$REGION" \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=sample-eip-ngw-01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]' \
  --query 'AllocationId' \
  --output text)
```

`aws ec2 allocate-address` で、NAT Gateway 01用のElastic IPを確保する。

Public NAT Gatewayには、インターネット側で使うPublic IPv4アドレスが必要である。このPublic IPv4アドレスとしてElastic IPを割り当てる。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `allocate-address` | Elastic IPを確保する |
| `--domain vpc` | VPC内で使用するElastic IPとして確保する |
| `--tag-specifications` | 作成時にタグを付与する |
| `ResourceType=elastic-ip` | タグ付け対象がElastic IPであることを示す |
| `--query 'AllocationId'` | 作成結果からAllocation IDだけを取り出す |
| `--output text` | Allocation IDだけを文字列として取得する |

Elastic IPはNAT Gateway削除後に解放する必要がある。未関連Elastic IPが残ると、不要な課金につながる。

## NAT Gatewayの作成

```bash
NGW01_ID=$(aws ec2 create-nat-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB01_ID" \
  --allocation-id "$ALLOC_ID_01" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$NAT_GATEWAY_01_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'NatGateway.NatGatewayId' \
  --output text)
```

`aws ec2 create-nat-gateway` で、Public Subnet 01にNAT Gateway 01を作成する。

NAT Gateway 01は、後続のRoute Table設定でPrivate Subnet 01のデフォルトルートの向き先になる。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `create-nat-gateway` | NAT Gatewayを作成する |
| `--subnet-id "$PUB01_ID"` | NAT Gatewayを配置するPublic Subnet ID |
| `--allocation-id "$ALLOC_ID_01"` | NAT Gatewayへ割り当てるElastic IPのAllocation ID |
| `--tag-specifications` | 作成時にタグを付与する |
| `ResourceType=natgateway` | タグ付け対象がNAT Gatewayであることを示す |
| `--query 'NatGateway.NatGatewayId'` | 作成結果からNAT Gateway IDだけを取り出す |
| `--output text` | NAT Gateway IDだけを文字列として取得する |

NAT Gateway 02も同じ流れで、Public Subnet 02に作成する。

## NAT Gatewayの待機

```bash
aws ec2 wait nat-gateway-available \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID"
```

`aws ec2 wait nat-gateway-available` は、指定したNAT Gatewayが `available` になるまで待機するコマンドである。

NAT Gatewayは作成直後すぐに利用可能になるとは限らない。`pending` のままRoute Tableへ設定すると、後続処理で失敗する可能性がある。そのため、このスクリプトでは2台とも `available` になるまで待つ。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `wait nat-gateway-available` | NAT Gatewayが利用可能になるまで待つ |
| `--nat-gateway-ids "$NGW01_ID" "$NGW02_ID"` | 待機対象のNAT Gateway ID |

既存NAT Gatewayがある場合も、このwaitで `available` 状態を確認できる。

## NAT Gatewayの確認

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID" \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

作成または取得したNAT Gatewayの状態を確認する。

表示項目は以下である。

| 表示項目 | 取得元 | 意味 |
| :--- | :--- | :--- |
| `Name` | `Tags[?Key==\`Name\`].Value|[0]` | Nameタグの値 |
| `ID` | `NatGatewayId` | NAT Gateway ID |
| `State` | `State` | NAT Gatewayの状態 |
| `Subnet` | `SubnetId` | NAT Gatewayを配置したSubnet ID |
| `PublicIP` | `NatGatewayAddresses[0].PublicIp` | NAT Gatewayに割り当てられたPublic IPv4アドレス |
| `AllocationId` | `NatGatewayAddresses[0].AllocationId` | Elastic IPのAllocation ID |

`State` が `available` で、`PublicIP` と `AllocationId` が表示されていれば、NAT Gatewayは作成できている。

## `--query` の読み方

```bash
'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}'
```

この `--query` は、AWS CLIのJMESPath式である。

分解すると以下である。

| 式 | 意味 |
| :--- | :--- |
| `NatGateways[*]` | NAT Gateway配列の全要素を対象にする |
| `{Name:...,ID:...}` | 表示用に列名を付けたオブジェクトへ変換する |
| `Name:Tags[?Key==\`Name\`].Value|[0]` | Tags配列からKeyがNameの要素を探し、そのValueの先頭を表示する |
| `ID:NatGatewayId` | NAT Gateway IDを表示する |
| `State:State` | NAT Gatewayの状態を表示する |
| `Subnet:SubnetId` | 配置先Subnet IDを表示する |
| `PublicIP:NatGatewayAddresses[0].PublicIp` | 先頭のNAT Gateway AddressからPublic IPを表示する |
| `AllocationId:NatGatewayAddresses[0].AllocationId` | 先頭のNAT Gateway AddressからAllocation IDを表示する |

`Tags[?Key==\`Name\`]` の `?` はフィルタを意味する。Tags配列の中から、`Key` が `Name` の要素だけを抽出する。

## 実行結果

実行結果例:

```text
=== Caller Identity ===
----------------------------------------------------------------------------------
|                                GetCallerIdentity                               |
+--------------+---------------------------------------+-------------------------+
|    Account   |                  Arn                  |         UserId          |
+--------------+---------------------------------------+-------------------------+
|  445405559057|  arn:aws:iam::445405559057:user/nobu  |  AIDAWPNB5PEIRTEFNXDVZ  |
+--------------+---------------------------------------+-------------------------+
=== Get VPC ID ===
Target VPC ID: vpc-07ac1e978dfa331ad
=== Get Public Subnet IDs ===
Public Subnet 01: subnet-0f7793dab26b6a015
Public Subnet 02: subnet-002b20a5d21e91c73
=== Check Existing NAT Gateway 01 ===
=== Allocate Elastic IP for NAT Gateway 01 ===
Elastic IP Allocation ID 01: eipalloc-02d019da48331ffae
=== Create NAT Gateway 01 ===
NAT Gateway 01: nat-0ddc1b6583a7b79db
=== Check Existing NAT Gateway 02 ===
=== Allocate Elastic IP for NAT Gateway 02 ===
Elastic IP Allocation ID 02: eipalloc-063055d2e404d0398
=== Create NAT Gateway 02 ===
NAT Gateway 02: nat-0f3220449453c5bd6
=== Wait for NAT Gateways to become available ===
NAT Gateways are available.
=== Describe NAT Gateways ===
------------------------------------------------------------------------------------------------------------------------------------
|                                                        DescribeNatGateways                                                       |
+----------------------------+------------------------+----------------+----------------+-------------+----------------------------+
|        AllocationId        |          ID            |     Name       |   PublicIP     |    State    |          Subnet            |
+----------------------------+------------------------+----------------+----------------+-------------+----------------------------+
|  eipalloc-02d019da48331ffae|  nat-0ddc1b6583a7b79db |  sample-ngw-01 |  13.193.73.65  |  available  |  subnet-0f7793dab26b6a015  |
|  eipalloc-063055d2e404d0398|  nat-0f3220449453c5bd6 |  sample-ngw-02 |  54.150.189.59 |  available  |  subnet-002b20a5d21e91c73  |
+----------------------------+------------------------+----------------+----------------+-------------+----------------------------+
```

この結果では、以下を確認できる。

| 項目 | 値 | 判断 |
| :--- | :--- | :--- |
| Account | `445405559057` | 想定アカウントで実行されている |
| Arn | `arn:aws:iam::445405559057:user/nobu` | 想定IAMユーザーで実行されている |
| VPC ID | `vpc-07ac1e978dfa331ad` | `sample-vpc` が対象になっている |
| Public Subnet 01 | `subnet-0f7793dab26b6a015` | NAT Gateway 01の配置先 |
| Public Subnet 02 | `subnet-002b20a5d21e91c73` | NAT Gateway 02の配置先 |
| NAT Gateway 01 | `nat-0ddc1b6583a7b79db` | `sample-ngw-01` が作成済み |
| NAT Gateway 02 | `nat-0f3220449453c5bd6` | `sample-ngw-02` が作成済み |
| State | `available` | 2台とも利用可能 |
| Allocation ID 01 | `eipalloc-02d019da48331ffae` | NAT Gateway 01用Elastic IP |
| Allocation ID 02 | `eipalloc-063055d2e404d0398` | NAT Gateway 02用Elastic IP |

## 再実行時の動作

このスクリプトは、再実行時に既存NAT Gatewayを確認する。

すでに対象VPC内に `sample-ngw-01` と `sample-ngw-02` が存在し、状態が `pending` または `available` の場合、以下のような流れになる。

```text
=== Check Existing NAT Gateway 01 ===
NAT Gateway 01 already exists: nat-xxxxxxxxxxxxxxxxx
NAT Gateway 01: nat-xxxxxxxxxxxxxxxxx
=== Check Existing NAT Gateway 02 ===
NAT Gateway 02 already exists: nat-yyyyyyyyyyyyyyyyy
NAT Gateway 02: nat-yyyyyyyyyyyyyyyyy
=== Wait for NAT Gateways to become available ===
NAT Gateways are available.
```

この場合、新しいElastic IPもNAT Gatewayも作成しない。

既存確認処理がない場合、再実行時に以下の問題が起きる。

1. Elastic IPが新規確保される
2. NAT Gatewayが新規作成される
3. 同じ用途のNAT Gatewayが複数残る
4. NAT Gateway料金とElastic IP関連の不要コストが発生する

既存確認は、課金対象リソースの重複作成を避けるための安全策である。

## よくあるエラーと確認観点

### VPCが見つからない

```text
Error: VPC not found. Please run 01_vpc_setup.sh first.
```

`sample-vpc` が存在しない、またはNameタグが想定と異なる場合に発生する。

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table
```

### Public Subnetが見つからない

```text
Error: Public subnet 01 not found. Please run 02_subnet_setup.sh first.
```

Public Subnetが存在しない、またはNameタグが想定と異なる場合に発生する。

確認コマンド:

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}' \
  --output table
```

### Elastic IPの上限に達した

```text
An error occurred (AddressLimitExceeded) when calling the AllocateAddress operation
```

Elastic IPのリージョン上限に達している場合に発生する。

確認コマンド:

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

不要な未関連Elastic IPがある場合は、削除対象を確認してから `release-address` する。

### NAT Gateway作成が失敗する

```text
An error occurred (...) when calling the CreateNatGateway operation
```

主な確認観点:

- 指定したSubnetがPublic Subnetとして使う想定のSubnetか
- Elastic IPのAllocation IDが有効か
- 対象リージョンが正しいか
- IAM権限に `ec2:CreateNatGateway` があるか
- VPCやSubnetの状態が正常か

NAT Gateway作成に失敗した場合、直前に確保したElastic IPが残ることがある。`describe-addresses` で未関連Elastic IPを確認する。

### NAT Gatewayがavailableにならない

`wait nat-gateway-available` が長時間戻らない場合、NAT Gatewayの状態を確認する。

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,FailureCode:FailureCode,FailureMessage:FailureMessage,Subnet:SubnetId}' \
  --output table
```

`failed` になっている場合、`FailureCode` と `FailureMessage` を確認する。

### リージョンが空

```text
Invalid endpoint: https://ec2..amazonaws.com
```

`REGION` 変数が空の状態でAWS CLIを実行した場合に発生する。

確認コマンド:

```bash
echo "$REGION"
```

期待値:

```text
ap-northeast-1
```

## 作成後の確認コマンド

NAT Gatewayの状態を確認する。

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

Elastic IPの関連状態を確認する。

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[*].{Name:Tags[?Key==`Name`].Value|[0],AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,NetworkInterfaceId:NetworkInterfaceId}' \
  --output table
```

Public Subnetの一覧を確認する。

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=vpc-07ac1e978dfa331ad Name=tag:Type,Values=public \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch}' \
  --output table
```

## 現時点でできること、できないこと

このスクリプトの完了時点で、Public Subnet 01 / 02にNAT Gatewayが作成されている。

できること:

- Private Subnet用Route TableのターゲットとしてNAT Gatewayを指定できる
- AZごとにPrivate Subnetからの外向き通信経路を分ける準備ができる
- NAT Gatewayに割り当てられたPublic IPを確認できる

まだできないこと:

- Private Subnetからインターネットへ通信する
- Private Subnet上のEC2からパッケージ更新を行う
- Private Subnet上のEC2から外部APIへ接続する

これらを成立させるには、後続でRoute Tableを設定する必要がある。

必要なRoute Table構成は以下である。

| Route Table | Destination | Target | 関連付け |
| :--- | :--- | :--- | :--- |
| sample-rt-public | `0.0.0.0/0` | sample-igw | public01, public02 |
| sample-rt-private01 | `0.0.0.0/0` | sample-ngw-01 | private01 |
| sample-rt-private02 | `0.0.0.0/0` | sample-ngw-02 | private02 |

## 課金上の注意

NAT Gatewayは作成後、起動時間と処理データ量に応じて料金が発生する。Elastic IPも、未関連状態や利用状況によって課金対象になり得る。

このスクリプトを実行した後、検証を中断する場合は削除運用を行う。

確認対象:

- NAT Gatewayが残っていないこと
- Elastic IPが残っていないこと
- NAT Gatewayに関連するRoute Tableが不要な参照を持っていないこと

## 削除時の考え方

NAT GatewayとElastic IPは、以下の順番で削除する。

1. Private Route TableからNAT Gateway向けのルートを削除する
2. NAT Gatewayを削除する
3. NAT Gatewayが `deleted` になるまで待つ
4. Elastic IPを解放する

削除コマンド例:

```bash
aws ec2 delete-nat-gateway \
  --profile learning \
  --region ap-northeast-1 \
  --nat-gateway-id nat-0ddc1b6583a7b79db

aws ec2 wait nat-gateway-deleted \
  --profile learning \
  --region ap-northeast-1 \
  --nat-gateway-ids nat-0ddc1b6583a7b79db

aws ec2 release-address \
  --profile learning \
  --region ap-northeast-1 \
  --allocation-id eipalloc-02d019da48331ffae
```

実際の削除は、構築全体の依存関係を考慮し、cleanupスクリプト側でまとめて行う。

## 次のステップ

次はRoute Tableを作成し、Public SubnetとPrivate Subnetの経路を定義する。

作成する主な構成:

| リソース | 設定 |
| :--- | :--- |
| Public Route Table | `0.0.0.0/0 -> sample-igw` |
| Public Route Table関連付け | `sample-subnet-public01`, `sample-subnet-public02` |
| Private Route Table 01 | `0.0.0.0/0 -> sample-ngw-01` |
| Private Route Table 01関連付け | `sample-subnet-private01` |
| Private Route Table 02 | `0.0.0.0/0 -> sample-ngw-02` |
| Private Route Table 02関連付け | `sample-subnet-private02` |

NAT GatewayはPrivate Subnetの出口であり、Route Tableはその出口へ向かう経路を定義する。NAT GatewayとRoute Tableが揃って、Private Subnetからの外向き通信経路が成立する。
