# 03_internetgateway_setup.sh 解説

## 概要

`03_internetgateway_setup.sh` は、`sample-vpc` にInternet Gatewayを作成し、VPCへアタッチするスクリプトである。

Internet Gatewayは、VPCとインターネットを接続するためのVPCコンポーネントである。Public Subnet上のALB、NAT Gateway、踏み台サーバーなどがインターネットと通信するための出口として使う。

ただし、このスクリプトを実行しただけでは、Public Subnetがインターネット接続できる状態にはならない。Internet GatewayをVPCへアタッチした後、Route Tableで `0.0.0.0/0` の宛先をInternet Gatewayへ向け、Public Subnetへ関連付ける必要がある。

このスクリプトで作成するリソースは以下である。

| 種別 | 名前 | 接続先 |
| :--- | :--- | :--- |
| Internet Gateway | sample-igw | sample-vpc |

## 前提条件

このスクリプトを実行する前に、`01_vpc_setup.sh` により `sample-vpc` が作成されている必要がある。

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

`02_subnet_setup.sh` の完了は、Internet Gateway作成そのものの必須条件ではない。ただし、本リポジトリの構築順では、VPC作成後にSubnetを作成し、その後にInternet Gatewayを作成する流れとしている。

また、AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではInternet Gatewayの作成、確認、VPCへのアタッチを行うため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeInternetGateways`
- `ec2:CreateInternetGateway`
- `ec2:CreateTags`
- `ec2:AttachInternetGateway`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、対象VPC名、Internet Gateway名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `sample-vpc` のVPC IDを取得する
6. 対象VPCに既存のInternet Gatewayが接続されているか確認する
7. 既存Internet Gatewayがある場合は、そのInternet Gatewayを利用する
8. 既存Internet Gatewayがない場合は、`sample-igw` を作成する
9. 作成したInternet GatewayをVPCへアタッチする
10. Internet Gatewayの状態を確認する

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

AWSリソース作成スクリプトでは、途中の失敗に気づかず後続処理が進むと、想定外のリソースが残る可能性がある。そのため、失敗した時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
IGW_NAME="sample-igw"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、Internet Gatewayを作成するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`VPC_NAME` は、Internet Gatewayを接続する対象VPCのNameタグである。前工程で作成した `sample-vpc` を検索するために使用する。

`IGW_NAME` は、作成するInternet GatewayのNameタグである。

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続する可能性がある。

このスクリプトは実AWSにInternet Gatewayを作成するため、LocalStack関連設定を無効化する。

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

`sts` はAWS Security Token Serviceである。`get-caller-identity` は、現在の認証主体を確認するための基本コマンドである。

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

Internet GatewayをVPCへアタッチするには、対象VPCのVPC IDが必要である。

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

## VPC未検出時の停止処理

```bash
if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "Error: VPC not found. Please run 01_vpc_setup.sh first."
  exit 1
fi
```

対象VPCが見つからない場合、AWS CLIは `None` または空文字を返すことがある。

VPC IDがない状態で後続の `describe-internet-gateways` や `attach-internet-gateway` を実行すると、原因が分かりにくいエラーになる。そのため、この時点で明示的に停止する。

## 既存Internet Gatewayの確認

```bash
EXISTING_IGW_ID=$(aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)
```

対象VPCに、すでにInternet Gatewayが接続されていないか確認する。

VPCにはInternet Gatewayを1つだけ接続できる。既存Internet Gatewayを確認せずに再実行すると、新しいInternet Gatewayを作成した後、`attach-internet-gateway` で失敗し、未接続のInternet Gatewayだけが残る可能性がある。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `describe-internet-gateways` | Internet Gatewayの一覧または詳細を取得する |
| `--filters Name=attachment.vpc-id,Values="$VPC_ID"` | 指定VPCへアタッチ済みのInternet Gatewayに絞り込む |
| `--query 'InternetGateways[0].InternetGatewayId'` | 先頭のInternet Gateway IDだけを取り出す |
| `--output text` | Internet Gateway IDだけを文字列として取得する |

この確認により、スクリプトの再実行時に余計なInternet Gatewayを作成しない。

## 既存Internet Gatewayがある場合の処理

```bash
if [ "$EXISTING_IGW_ID" != "None" ] && [ -n "$EXISTING_IGW_ID" ]; then
  IGW_ID="$EXISTING_IGW_ID"
  echo "Internet Gateway already attached: $IGW_ID"
else
  ...
fi
```

`EXISTING_IGW_ID` に値がある場合、すでに対象VPCへInternet Gatewayが接続されていると判断する。

この場合は、新しいInternet Gatewayを作成しない。既存のInternet Gateway IDを `IGW_ID` に代入し、最後の確認処理で状態を表示する。

この分岐は再実行時の安全性を高めるための処理である。

## Internet Gatewayの作成

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
```

`aws ec2 create-internet-gateway` で、Internet Gatewayを作成する。

Internet Gatewayは作成直後の時点では、まだVPCに接続されていない。VPCへ接続するには、後続の `attach-internet-gateway` が必要である。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `create-internet-gateway` | Internet Gatewayを作成する |
| `--tag-specifications` | 作成時にタグを付与する |
| `ResourceType=internet-gateway` | タグ付け対象がInternet Gatewayであることを示す |
| `Tags=[...]` | 作成するInternet Gatewayへ付与するタグ一覧 |
| `--query 'InternetGateway.InternetGatewayId'` | 作成結果からInternet Gateway IDだけを取り出す |
| `--output text` | Internet Gateway IDだけを文字列として取得する |

付与するタグは以下である。

| Key | Value | 用途 |
| :--- | :--- | :--- |
| `Name` | `sample-igw` | AWSコンソールやCLIで識別するための名前 |
| `Project` | `terraform-iac-lab` | プロジェクト単位でリソースを識別するための値 |
| `Environment` | `learning` | 環境種別を識別するための値 |

## VPCへのアタッチ

```bash
aws ec2 attach-internet-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID"
```

`aws ec2 attach-internet-gateway` で、作成したInternet GatewayをVPCへ接続する。

主なオプションの意味は以下である。

| オプション | 意味 |
| :--- | :--- |
| `attach-internet-gateway` | Internet GatewayをVPCへアタッチする |
| `--vpc-id "$VPC_ID"` | 接続先VPC ID |
| `--internet-gateway-id "$IGW_ID"` | 接続するInternet Gateway ID |

この処理により、VPCはInternet Gatewayを経由したインターネット通信の経路を持てる状態になる。

ただし、アタッチだけではサブネット単位の通信経路は作られない。Public Subnetからインターネットへ通信するには、Route Tableに以下のルートを追加する必要がある。

| Destination | Target |
| :--- | :--- |
| `0.0.0.0/0` | `sample-igw` |

また、そのRoute TableをPublic Subnetへ関連付ける必要がある。

## Internet Gatewayの確認

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --internet-gateway-ids "$IGW_ID" \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

作成または取得したInternet Gatewayの状態を確認する。

表示項目は以下である。

| 表示項目 | 取得元 | 意味 |
| :--- | :--- | :--- |
| `ID` | `InternetGatewayId` | Internet Gateway ID |
| `Name` | `Tags[?Key==\`Name\`].Value|[0]` | Nameタグの値 |
| `VPC` | `Attachments[0].VpcId` | アタッチ先VPC ID |
| `State` | `Attachments[0].State` | アタッチ状態 |

`State` が `available` で、`VPC` に `sample-vpc` のVPC IDが表示されていれば、Internet GatewayはVPCへ接続されている。

## `--query` の読み方

```bash
'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}'
```

この `--query` は、AWS CLIのJMESPath式である。

分解すると以下である。

| 式 | 意味 |
| :--- | :--- |
| `InternetGateways[*]` | Internet Gateway配列の全要素を対象にする |
| `{ID:InternetGatewayId,...}` | 表示用に列名を付けたオブジェクトへ変換する |
| `ID:InternetGatewayId` | Internet Gateway IDを `ID` 列として表示する |
| `Name:Tags[?Key==\`Name\`].Value|[0]` | Tags配列からKeyがNameの要素を探し、そのValueの先頭を表示する |
| `VPC:Attachments[0].VpcId` | Attachments配列の先頭からVPC IDを表示する |
| `State:Attachments[0].State` | Attachments配列の先頭からアタッチ状態を表示する |

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
=== Check Existing Internet Gateway ===
=== Create Internet Gateway ===
Created IGW ID: igw-05e4019103b0fa219
=== Attach Internet Gateway to VPC ===
Success! Attached IGW (igw-05e4019103b0fa219) to VPC (vpc-07ac1e978dfa331ad)
=== Describe Internet Gateway ===
-------------------------------------------------------------------------------
|                          DescribeInternetGateways                           |
+------------------------+-------------+------------+-------------------------+
|           ID           |    Name     |   State    |           VPC           |
+------------------------+-------------+------------+-------------------------+
|  igw-05e4019103b0fa219 |  sample-igw |  available |  vpc-07ac1e978dfa331ad  |
+------------------------+-------------+------------+-------------------------+
```

この結果では、以下を確認できる。

| 項目 | 値 | 判断 |
| :--- | :--- | :--- |
| Account | `445405559057` | 想定アカウントで実行されている |
| Arn | `arn:aws:iam::445405559057:user/nobu` | 想定IAMユーザーで実行されている |
| VPC ID | `vpc-07ac1e978dfa331ad` | `sample-vpc` が対象になっている |
| IGW ID | `igw-05e4019103b0fa219` | Internet Gatewayが作成されている |
| Name | `sample-igw` | Nameタグが付与されている |
| State | `available` | VPCへアタッチ済みで利用可能 |

## 再実行時の動作

このスクリプトは、再実行時に既存Internet Gatewayを確認する。

すでに対象VPCへInternet Gatewayが接続されている場合、以下のような流れになる。

```text
=== Check Existing Internet Gateway ===
Internet Gateway already attached: igw-xxxxxxxxxxxxxxxxx
=== Describe Internet Gateway ===
...
```

この場合、新しいInternet Gatewayは作成しない。

既存Internet Gateway確認処理がない場合、再実行時に以下の問題が起きる可能性がある。

1. 新しいInternet Gatewayが作成される
2. 対象VPCにはすでに別のInternet Gatewayが接続されている
3. `attach-internet-gateway` が失敗する
4. 未接続のInternet Gatewayだけが残る

既存確認は、この未接続リソースを残さないための安全策である。

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

### 権限不足

```text
An error occurred (UnauthorizedOperation) when calling the CreateInternetGateway operation
```

IAMユーザーまたはIAMロールに、Internet Gateway作成やアタッチの権限が不足している。

確認対象の権限:

- `ec2:CreateInternetGateway`
- `ec2:CreateTags`
- `ec2:AttachInternetGateway`
- `ec2:DescribeInternetGateways`

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

### VPCにすでにInternet Gatewayがある

既存確認処理がないスクリプトでは、再実行時に以下のようなエラーになることがある。

```text
An error occurred (Resource.AlreadyAssociated) when calling the AttachInternetGateway operation: network vpc-xxxxxxxx already has an internet gateway attached
```

本スクリプトでは、既存Internet Gatewayを先に確認するため、このケースでは新規作成を行わない。

## 作成後の確認コマンド

Internet Gatewayの状態を確認する。

```bash
aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=attachment.vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

VPC、Subnet、Internet Gatewayの現時点の状態をまとめて確認する。

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
  --filters Name=vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table

aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=attachment.vpc-id,Values=vpc-07ac1e978dfa331ad \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

## 現時点でできること、できないこと

このスクリプトの完了時点で、VPCにはInternet Gatewayが接続されている。

できること:

- VPCにインターネット接続用のゲートウェイを持たせる
- 後続のRoute TableでInternet Gatewayをターゲットにできる
- Public Subnet用のデフォルトルート作成に進める

まだできないこと:

- Public Subnetからインターネットへ通信する
- インターネットからPublic Subnet上のEC2へ到達する
- Private SubnetからNAT Gateway経由で外向き通信する

これらを成立させるには、後続でRoute Table、NAT Gateway、Security Group、EC2などの設定が必要である。

## 削除時の考え方

Internet Gatewayは、VPCにアタッチされたままでは削除できない。

削除する場合は、以下の順番で処理する。

1. Internet Gatewayを参照するRoute Tableのルートを削除する
2. Internet GatewayをVPCからデタッチする
3. Internet Gatewayを削除する

削除コマンド例:

```bash
aws ec2 detach-internet-gateway \
  --profile learning \
  --region ap-northeast-1 \
  --internet-gateway-id igw-05e4019103b0fa219 \
  --vpc-id vpc-07ac1e978dfa331ad

aws ec2 delete-internet-gateway \
  --profile learning \
  --region ap-northeast-1 \
  --internet-gateway-id igw-05e4019103b0fa219
```

実際の削除は、構築全体の依存関係を考慮し、cleanupスクリプト側でまとめて行う。

## 次のステップ

次はRoute Tableを作成し、Public SubnetからInternet Gatewayへ向かうデフォルトルートを設定する。

作成する主な構成:

| リソース | 設定 |
| :--- | :--- |
| Public Route Table | `0.0.0.0/0 -> sample-igw` |
| 関連付け | `sample-subnet-public01`, `sample-subnet-public02` |
| Private Route Table | 後続でNAT Gateway向けルートを設定 |

Internet GatewayはVPCの出口であり、Route Tableはサブネットごとの経路制御である。この2つが揃って、Public Subnetのインターネット通信経路が成立する。
