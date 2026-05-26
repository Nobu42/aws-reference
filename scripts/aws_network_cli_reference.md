# 01 VPC AWS CLI Reference

## このドキュメントの目的

このドキュメントは、`01_vpc_setup.sh` で使用するAWS CLIコマンドを、現場で素早く確認できるリファレンスとして整理したものである。

対象コマンド:

- `aws sts get-caller-identity`
- `aws ec2 create-vpc`
- `aws ec2 modify-vpc-attribute`
- `aws ec2 describe-vpcs`
- `aws ec2 describe-vpc-attribute`
- `aws ec2 describe-subnets`
- `aws ec2 describe-route-tables`
- `aws ec2 describe-security-groups`
- `aws ec2 describe-security-group-rules`
- `aws ec2 describe-network-acls`
- `aws ec2 describe-flow-logs`
- `aws ec2 describe-vpc-endpoints`
- `aws ec2 describe-network-interfaces`
- VPC調査、ネットワーク影響調査、セキュリティ確認でよく使う関連コマンド

あわせて、AWS CLIで頻出する以下の共通オプションも説明する。

- `--profile`
- `--region`
- `--query`
- `--output`
- `--filters`

## AWS CLIコマンドの基本構造

AWS CLIの基本形は以下である。

```bash
aws <service> <operation> [options]
```

例:

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16
```

| 要素 | 例 | 意味 |
| :--- | :--- | :--- |
| `aws` | `aws` | AWS CLI本体を呼び出すコマンド |
| `<service>` | `ec2` | 操作対象のAWSサービス |
| `<operation>` | `create-vpc` | 実行する操作 |
| `[options]` | `--cidr-block 10.0.0.0/16` | 操作に渡す設定値や出力形式 |

## aws

### 名前

`aws` - AWS CLIを実行するためのコマンド

### 説明

`aws` はAWS CLIのエントリーポイントである。

この後ろにサービス名と操作名を続けることで、AWSリソースの作成、変更、削除、確認などを行う。

### 書式

```bash
aws <service> <operation> [options]
```

### 例

```bash
aws sts get-caller-identity --profile learning
aws ec2 describe-vpcs --profile learning --region ap-northeast-1
```

### よく使う確認

AWS CLIのバージョン確認:

```bash
aws --version
```

設定済みプロファイルの確認:

```bash
aws configure list --profile learning
```

## sts

### 名前

`sts` - AWS Security Token Serviceを操作するサービス名

### 説明

`sts` は、AWSの認証情報や一時認証情報を扱うサービスである。

VPC作成スクリプトでは、`get-caller-identity` を使って、現在のAWS CLIがどのAWSアカウント、IAMユーザー、IAMロールとして動作しているかを確認する。

リソース作成前の安全確認としてよく使う。

## aws sts get-caller-identity

### 名前

`get-caller-identity` - 現在の認証情報のAWSアカウントとIAM主体を表示する

### 書式

```bash
aws sts get-caller-identity \
  --profile <profile-name> \
  --output <output-format>
```

### 説明

現在使用しているAWS CLI認証情報が、どのAWSアカウント、IAMユーザー、IAMロールに対応しているかを表示する。

作成系コマンドを実行する前に、操作対象のAWSアカウントを取り違えていないか確認するために使用する。

### 使用例

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table
```

### 主な出力項目

| 項目 | 意味 |
| :--- | :--- |
| `Account` | AWSアカウントID |
| `Arn` | 実行主体のARN |
| `UserId` | IAMユーザーまたはロールの一意なID |

### 出力例

```txt
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
UserId: AIDAXXXXXXXXXXXXXXXX
```

### 確認ポイント

- `Account` が想定したAWSアカウントIDであること
- `Arn` が想定したIAMユーザーまたはIAMロールであること
- 本番アカウントと検証アカウントを取り違えていないこと

## ec2

### 名前

`ec2` - Amazon EC2関連リソースを操作するサービス名

### 説明

`ec2` は、Amazon EC2だけでなく、VPC、Subnet、Route Table、Internet Gateway、NAT Gateway、Security Group、Elastic IPなど、多くのネットワーク関連リソースも扱う。

VPC作成では、以下のような操作を行う。

- VPCの作成
- VPC属性の変更
- VPC一覧や詳細の確認

## aws ec2 create-vpc

### 名前

`create-vpc` - 新しいVPCを作成する

### 書式

```bash
aws ec2 create-vpc \
  --profile <profile-name> \
  --region <region-name> \
  --cidr-block <ipv4-cidr> \
  --instance-tenancy <default|dedicated|host> \
  --tag-specifications <tag-specifications> \
  --query <jmespath-query> \
  --output <output-format>
```

### 説明

指定したIPv4 CIDRブロックを持つVPCを作成する。

VPCはAWSネットワークの基本単位である。EC2、ALB、RDS、ElastiCacheなどを配置するサブネットは、このVPCの中に作成する。

### 使用例

```bash
aws ec2 create-vpc \
  --profile learning \
  --region ap-northeast-1 \
  --cidr-block 10.0.0.0/16 \
  --instance-tenancy default \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=sample-vpc},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Vpc.VpcId' \
  --output text
```

### オプション

#### `--profile`

使用するAWS CLIプロファイルを指定する。

```bash
--profile learning
```

`~/.aws/credentials` や `~/.aws/config` に設定された認証情報を選択するために使う。

#### `--region`

AWSリソースを作成または参照するリージョンを指定する。

```bash
--region ap-northeast-1
```

`ap-northeast-1` は東京リージョンである。

VPCはリージョナルリソースなので、どのリージョンに作るかを明示する。

#### `--cidr-block`

VPCに割り当てるIPv4 CIDRブロックを指定する。

```bash
--cidr-block 10.0.0.0/16
```

`10.0.0.0/16` の場合、VPC内で `10.0.0.0` から `10.0.255.255` までの範囲を利用できる。

サブネットはこの範囲内から切り出して作成する。

#### `--instance-tenancy`

VPC内で起動するEC2インスタンスのテナンシーを指定する。

```bash
--instance-tenancy default
```

| 値 | 意味 |
| :--- | :--- |
| `default` | 通常の共有ハードウェア上でEC2を起動する |
| `dedicated` | 専有インスタンスとして起動する |
| `host` | Dedicated Hostを利用する |

通常の構成では `default` を指定する。

#### `--tag-specifications`

リソース作成時にタグを付与する。

```bash
--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=sample-vpc}]"
```

複数タグを付ける例:

```bash
--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=sample-vpc},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]"
```

| 要素 | 意味 |
| :--- | :--- |
| `ResourceType=vpc` | タグを付ける対象リソースがVPCであることを示す |
| `Key=Name` | タグキー |
| `Value=sample-vpc` | タグ値 |

タグはAWSコンソールでの識別、コスト管理、削除対象の絞り込みなどに使う。

#### `--query`

AWS CLIの出力から必要な部分だけを取り出す。

```bash
--query 'Vpc.VpcId'
```

`create-vpc` の出力にはVPC全体の情報が含まれるが、この指定によりVPC IDだけを取り出せる。

シェル変数に値を入れる時によく使う。

```bash
VPC_ID=$(aws ec2 create-vpc ... --query 'Vpc.VpcId' --output text)
```

#### `--output`

AWS CLIの出力形式を指定する。

```bash
--output text
```

`--query 'Vpc.VpcId' --output text` と組み合わせると、`vpc-xxxxxxxxxxxxxxxxx` のようなIDだけを取得できる。

### 主な出力項目

`--query` を指定しない場合、`create-vpc` は作成されたVPCの詳細を返す。

| 項目 | 意味 |
| :--- | :--- |
| `Vpc.VpcId` | 作成されたVPC ID |
| `Vpc.CidrBlock` | VPCのCIDR |
| `Vpc.State` | VPCの状態 |
| `Vpc.OwnerId` | VPCを所有するAWSアカウントID |

### よく使う確認

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-ids <vpc-id> \
  --output table
```

## aws ec2 modify-vpc-attribute

### 名前

`modify-vpc-attribute` - VPCの属性を変更する

### 書式

```bash
aws ec2 modify-vpc-attribute \
  --profile <profile-name> \
  --region <region-name> \
  --vpc-id <vpc-id> \
  --enable-dns-hostnames '{"Value":true}'
```

```bash
aws ec2 modify-vpc-attribute \
  --profile <profile-name> \
  --region <region-name> \
  --vpc-id <vpc-id> \
  --enable-dns-support '{"Value":true}'
```

### 説明

指定したVPCの属性を変更する。

`01_vpc_setup.sh` では、以下の2つのDNS関連属性を有効化している。

- `enableDnsHostnames`
- `enableDnsSupport`

### 使用例: DNSホスト名を有効化する

```bash
aws ec2 modify-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx \
  --enable-dns-hostnames '{"Value":true}'
```

### 使用例: DNS解決を有効化する

```bash
aws ec2 modify-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx \
  --enable-dns-support '{"Value":true}'
```

### オプション

#### `--vpc-id`

変更対象のVPC IDを指定する。

```bash
--vpc-id vpc-xxxxxxxxxxxxxxxxx
```

VPC IDは `create-vpc` の結果や `describe-vpcs` で確認できる。

#### `--enable-dns-hostnames`

VPC内でDNSホスト名を有効化するかどうかを指定する。

```bash
--enable-dns-hostnames '{"Value":true}'
```

有効にすると、条件を満たすEC2インスタンスにAWS管理のDNSホスト名が割り当てられる。

値はJSON形式で渡する。

| 値 | 意味 |
| :--- | :--- |
| `{"Value":true}` | 有効化する |
| `{"Value":false}` | 無効化する |

#### `--enable-dns-support`

VPC内でAWS提供DNSによる名前解決を有効化するかどうかを指定する。

```bash
--enable-dns-support '{"Value":true}'
```

有効にすると、VPC内のリソースからDNS名を解決できるようになる。

RDSエンドポイント、ElastiCacheエンドポイント、Private Hosted Zoneなどを使う構成では重要である。

| 値 | 意味 |
| :--- | :--- |
| `{"Value":true}` | 有効化する |
| `{"Value":false}` | 無効化する |

### 注意点

`modify-vpc-attribute` は、成功しても詳細なレスポンスを返しない。

設定結果を確認する場合は、`describe-vpc-attribute` を使う。

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx \
  --attribute enableDnsHostnames \
  --output table
```

## aws ec2 describe-vpcs

### 名前

`describe-vpcs` - VPCの一覧または詳細を表示する

### 書式

```bash
aws ec2 describe-vpcs \
  --profile <profile-name> \
  --region <region-name> \
  --vpc-ids <vpc-id> \
  --query <jmespath-query> \
  --output <output-format>
```

```bash
aws ec2 describe-vpcs \
  --profile <profile-name> \
  --region <region-name> \
  --filters "Name=tag:Name,Values=<name-tag-value>" \
  --output table
```

### 説明

VPCの一覧や詳細情報を表示する。

特定のVPC IDを指定して確認することも、タグやCIDRで絞り込むこともできる。

### 使用例: VPC IDを指定して確認する

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-ids vpc-xxxxxxxxxxxxxxxxx \
  --output table
```

### 使用例: Nameタグで検索する

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --output table
```

### 使用例: 表示項目を絞る

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table
```

### オプション

#### `--vpc-ids`

確認したいVPC IDを指定する。

```bash
--vpc-ids vpc-xxxxxxxxxxxxxxxxx
```

複数指定することもできる。

```bash
--vpc-ids vpc-aaa vpc-bbb
```

#### `--filters`

条件を指定してVPCを絞り込む。

```bash
--filters "Name=tag:Name,Values=sample-vpc"
```

よく使うフィルター:

| フィルター | 例 | 意味 |
| :--- | :--- | :--- |
| `tag:Name` | `Name=tag:Name,Values=sample-vpc` | Nameタグで絞り込む |
| `cidr-block` | `Name=cidr-block,Values=10.0.0.0/16` | CIDRで絞り込む |
| `state` | `Name=state,Values=available` | VPC状態で絞り込む |
| `vpc-id` | `Name=vpc-id,Values=vpc-xxx` | VPC IDで絞り込む |

#### `--query`

出力結果から必要な項目だけを取り出す。

```bash
--query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}'
```

`describe-vpcs` の出力は情報量が多いため、確認したい項目だけに絞ると見やすくなる。

Nameタグを取り出す例:

```bash
--query 'Vpcs[*].{Name:Tags[?Key==`Name`].Value|[0]}'
```

この式は、`Tags` 配列の中から `Key` が `Name` のタグを探し、その `Value` の先頭要素を取り出す。

### 主な出力項目

| 項目 | 意味 |
| :--- | :--- |
| `VpcId` | VPC ID |
| `CidrBlock` | VPCのIPv4 CIDR |
| `State` | VPCの状態 |
| `IsDefault` | デフォルトVPCかどうか |
| `OwnerId` | 所有するAWSアカウントID |
| `Tags` | VPCに付与されたタグ |

### 注意点

`describe-vpcs` の出力には、`enableDnsHostnames` や `enableDnsSupport` は直接含まれない。

そのため、以下のようなqueryを書いても `None` になる場合がある。

```bash
--query 'Vpcs[*].{DNSHost:EnableDnsHostnames.Value,DNSSupport:EnableDnsSupport.Value}'
```

DNS属性を確認する場合は、`describe-vpc-attribute` を使う。

## aws ec2 describe-vpc-attribute

### 名前

`describe-vpc-attribute` - VPCの特定属性を表示する

### 書式

```bash
aws ec2 describe-vpc-attribute \
  --profile <profile-name> \
  --region <region-name> \
  --vpc-id <vpc-id> \
  --attribute <attribute-name> \
  --output <output-format>
```

### 説明

指定したVPCの属性を確認する。

DNS関連の設定確認では、`describe-vpcs` ではなくこのコマンドを使う。

### 使用例: DNSホスト名の確認

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx \
  --attribute enableDnsHostnames \
  --output table
```

### 使用例: DNS解決の確認

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id vpc-xxxxxxxxxxxxxxxxx \
  --attribute enableDnsSupport \
  --output table
```

### オプション

#### `--attribute`

確認したいVPC属性を指定する。

```bash
--attribute enableDnsHostnames
```

VPC作成時によく確認する属性:

| 属性 | 意味 |
| :--- | :--- |
| `enableDnsHostnames` | VPC内でDNSホスト名を有効にするか |
| `enableDnsSupport` | VPC内でDNS解決を有効にするか |

### 出力例

```txt
EnableDnsHostnames:
  Value: True
```

```txt
EnableDnsSupport:
  Value: True
```

## VPC実務調査でよく使うコマンド

### 目的別早見表

VPC関連の影響調査、設定変更、手順書作成では、まず `describe-*` 系コマンドで現状を確認し、その後に変更系コマンドを実行する。

| 目的 | 主なコマンド |
| :--- | :--- |
| VPC一覧を確認する | `aws ec2 describe-vpcs` |
| サブネットを確認する | `aws ec2 describe-subnets` |
| ルートテーブルを確認する | `aws ec2 describe-route-tables` |
| Internet Gatewayを確認する | `aws ec2 describe-internet-gateways` |
| NAT Gatewayを確認する | `aws ec2 describe-nat-gateways` |
| Elastic IPを確認する | `aws ec2 describe-addresses` |
| Security Groupを確認する | `aws ec2 describe-security-groups` |
| Security Groupルールを確認する | `aws ec2 describe-security-group-rules` |
| Network ACLを確認する | `aws ec2 describe-network-acls` |
| VPC Endpointを確認する | `aws ec2 describe-vpc-endpoints` |
| VPC Flow Logsを確認する | `aws ec2 describe-flow-logs` |
| ENIを確認する | `aws ec2 describe-network-interfaces` |
| VPC内EC2を確認する | `aws ec2 describe-instances` |
| RDSのVPC関連設定を確認する | `aws rds describe-db-instances` |
| LambdaのVPC設定を確認する | `aws lambda get-function-configuration` |
| GuardDuty Findingsを確認する | `aws guardduty list-findings` |
| 変更履歴を確認する | `aws cloudtrail lookup-events` |

金融系や重要システムの作業では、変更前後の差分確認が重要である。

作業前に `describe-*` の結果を保存し、作業後に同じコマンドで再確認すると、手順書や作業証跡として使いやすくなる。

## aws ec2 describe-subnets

### 名前

`describe-subnets` - サブネットの一覧または詳細を表示する

### 書式

```bash
aws ec2 describe-subnets \
  --profile <profile-name> \
  --region <region-name> \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query <jmespath-query> \
  --output <output-format>
```

### 説明

VPC内のサブネットを確認する。

サブネットは、EC2、ALB、RDS、ElastiCache、Lambda ENIなどを配置するネットワーク単位である。

影響調査では、対象リソースがどのサブネット、どのAZ、どのCIDRに配置されているかを確認する。

### 使用例: VPC内のサブネットを一覧表示する

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,MapPublicIp:MapPublicIpOnLaunch,AvailableIp:AvailableIpAddressCount}' \
  --output table
```

### 使用例: Nameタグでサブネットを検索する

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-subnet-private01" \
  --output table
```

### よく使うフィルター

| フィルター | 例 | 意味 |
| :--- | :--- | :--- |
| `vpc-id` | `Name=vpc-id,Values=vpc-xxx` | VPC IDで絞り込む |
| `subnet-id` | `Name=subnet-id,Values=subnet-xxx` | Subnet IDで絞り込む |
| `tag:Name` | `Name=tag:Name,Values=sample-subnet-public01` | Nameタグで絞り込む |
| `availability-zone` | `Name=availability-zone,Values=ap-northeast-1a` | AZで絞り込む |
| `cidr-block` | `Name=cidr-block,Values=10.0.0.0/20` | CIDRで絞り込む |

### 確認ポイント

- Public SubnetとPrivate SubnetのCIDRが設計どおりか
- AZが分散されているか
- `MapPublicIpOnLaunch` がPublic Subnetだけ有効になっているか
- 使用可能IP数が不足していないか

## aws ec2 create-subnet

### 名前

`create-subnet` - VPC内にサブネットを作成する

### 書式

```bash
aws ec2 create-subnet \
  --profile <profile-name> \
  --region <region-name> \
  --vpc-id <vpc-id> \
  --cidr-block <subnet-cidr> \
  --availability-zone <az-name> \
  --tag-specifications <tag-specifications>
```

### 使用例

```bash
aws ec2 create-subnet \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --cidr-block 10.0.0.0/20 \
  --availability-zone ap-northeast-1a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]"
```

### 主なオプション

| オプション | 意味 |
| :--- | :--- |
| `--vpc-id` | 作成先VPC ID |
| `--cidr-block` | サブネットのCIDR |
| `--availability-zone` | 作成先AZ |
| `--tag-specifications` | 作成時に付けるタグ |

## aws ec2 modify-subnet-attribute

### 名前

`modify-subnet-attribute` - サブネット属性を変更する

### 使用例: 起動時Public IP自動付与を有効化する

```bash
aws ec2 modify-subnet-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --subnet-id <subnet-id> \
  --map-public-ip-on-launch
```

### 使用例: 起動時Public IP自動付与を無効化する

```bash
aws ec2 modify-subnet-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --subnet-id <subnet-id> \
  --no-map-public-ip-on-launch
```

### 確認ポイント

Public Subnetでは `MapPublicIpOnLaunch` を有効化することがある。

Private Subnetでは、EC2にPublic IPを付けないため、通常は無効化する。

## aws ec2 describe-route-tables

### 名前

`describe-route-tables` - ルートテーブルの一覧または詳細を表示する

### 書式

```bash
aws ec2 describe-route-tables \
  --profile <profile-name> \
  --region <region-name> \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query <jmespath-query> \
  --output <output-format>
```

### 説明

VPC内のルートテーブルを確認する。

通信経路の影響調査では、対象サブネットがどのルートテーブルに関連付いているか、`0.0.0.0/0` がInternet Gateway、NAT Gateway、Transit Gateway、VPC Peeringのどれに向いているかを確認する。

### 使用例: VPC内のルートテーブルを一覧表示する

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Associations:Associations[*].SubnetId,Routes:Routes[*].{Dest:DestinationCidrBlock,Gateway:GatewayId,Nat:NatGatewayId,Peer:VpcPeeringConnectionId,TGW:TransitGatewayId,State:State}}' \
  --output table
```

### 使用例: 特定サブネットに関連付いたルートテーブルを確認する

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=association.subnet-id,Values=<subnet-id>" \
  --output table
```

### よく使うフィルター

| フィルター | 例 | 意味 |
| :--- | :--- | :--- |
| `vpc-id` | `Name=vpc-id,Values=vpc-xxx` | VPC IDで絞り込む |
| `route-table-id` | `Name=route-table-id,Values=rtb-xxx` | Route Table IDで絞り込む |
| `association.subnet-id` | `Name=association.subnet-id,Values=subnet-xxx` | サブネット関連付けで絞り込む |
| `route.gateway-id` | `Name=route.gateway-id,Values=igw-xxx` | Internet Gateway向きルートを探す |
| `route.nat-gateway-id` | `Name=route.nat-gateway-id,Values=nat-xxx` | NAT Gateway向きルートを探す |

### 確認ポイント

- Public SubnetのデフォルトルートがInternet Gatewayを向いているか
- Private SubnetのデフォルトルートがNAT Gatewayを向いているか
- AZごとに適切なNAT Gatewayを向いているか
- 意図しない `0.0.0.0/0` や広すぎるルートがないか
- VPC PeeringやTransit Gateway向きの経路が設計どおりか

## aws ec2 create-route / replace-route / delete-route

### 名前

`create-route` - ルートテーブルに新しいルートを追加する

`replace-route` - 既存ルートのターゲットを変更する

`delete-route` - ルートテーブルからルートを削除する

### 使用例: Internet Gateway向きのデフォルトルートを追加する

```bash
aws ec2 create-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id <internet-gateway-id>
```

### 使用例: NAT Gateway向きのデフォルトルートを追加する

```bash
aws ec2 create-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <nat-gateway-id>
```

### 使用例: 既存ルートをNAT Gateway向きに変更する

```bash
aws ec2 replace-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <nat-gateway-id>
```

### 使用例: ルートを削除する

```bash
aws ec2 delete-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0
```

### 変更時の注意点

ルート変更は通信断に直結する。

本番系や金融系システムでは、変更前に以下を確認する。

- 対象ルートテーブルに関連付いているサブネット
- 対象サブネット上のEC2、RDS、Lambda ENIなど
- 変更対象ルートの現在のターゲット
- 戻し手順
- 作業時間帯
- 監視アラートや疎通確認方法

## aws ec2 associate-route-table / replace-route-table-association

### 名前

`associate-route-table` - サブネットにルートテーブルを関連付ける

`replace-route-table-association` - 既存の関連付け先ルートテーブルを変更する

### 使用例: サブネットにルートテーブルを関連付ける

```bash
aws ec2 associate-route-table \
  --profile learning \
  --region ap-northeast-1 \
  --subnet-id <subnet-id> \
  --route-table-id <route-table-id>
```

### 使用例: ルートテーブル関連付けを差し替える

```bash
aws ec2 replace-route-table-association \
  --profile learning \
  --region ap-northeast-1 \
  --association-id <route-table-association-id> \
  --route-table-id <new-route-table-id>
```

### 確認方法

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=association.subnet-id,Values=<subnet-id>" \
  --output table
```

## aws ec2 describe-internet-gateways

### 名前

`describe-internet-gateways` - Internet Gatewayの一覧または詳細を表示する

### 使用例

```bash
aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=attachment.vpc-id,Values=<vpc-id>" \
  --query 'InternetGateways[*].{Name:Tags[?Key==`Name`].Value|[0],InternetGatewayId:InternetGatewayId,State:Attachments[0].State,VpcId:Attachments[0].VpcId}' \
  --output table
```

### 確認ポイント

- 対象VPCにInternet Gatewayがアタッチされているか
- Public SubnetのルートテーブルがInternet Gatewayを向いているか
- 不要なInternet Gatewayが残っていないか

## aws ec2 create-internet-gateway / attach-internet-gateway

### 名前

`create-internet-gateway` - Internet Gatewayを作成する

`attach-internet-gateway` - Internet GatewayをVPCにアタッチする

### 使用例

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --profile learning \
  --region ap-northeast-1 \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=sample-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
```

```bash
aws ec2 attach-internet-gateway \
  --profile learning \
  --region ap-northeast-1 \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id <vpc-id>
```

## aws ec2 describe-nat-gateways

### 名前

`describe-nat-gateways` - NAT Gatewayの一覧または詳細を表示する

### 使用例

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter "Name=vpc-id,Values=<vpc-id>" \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],NatGatewayId:NatGatewayId,SubnetId:SubnetId,State:State,PublicIp:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

### 確認ポイント

- NAT Gatewayが `available` か
- Private Subnetのルートが同一AZのNAT Gatewayを向いているか
- 不要なNAT Gatewayが残っていないか

NAT Gatewayは稼働時間と通信量で課金されるため、検証後の削除確認が重要である。

## aws ec2 describe-addresses

### 名前

`describe-addresses` - Elastic IPの一覧または詳細を表示する

### 使用例

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --query 'Addresses[*].{PublicIp:PublicIp,AllocationId:AllocationId,AssociationId:AssociationId,InstanceId:InstanceId,NetworkInterfaceId:NetworkInterfaceId,Tags:Tags}' \
  --output table
```

### 確認ポイント

- 未関連付けのElastic IPが残っていないか
- NAT Gateway用のElastic IPか
- BastionなどEC2に関連付いたElastic IPか

## aws ec2 describe-security-groups

### 名前

`describe-security-groups` - Security Groupの一覧または詳細を表示する

### 書式

```bash
aws ec2 describe-security-groups \
  --profile <profile-name> \
  --region <region-name> \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --output <output-format>
```

### 説明

VPC内のSecurity Groupを確認する。

Security Groupはステートフルな仮想ファイアウォールである。EC2、ALB、RDS、ElastiCache、Lambda ENI、Interface VPC Endpointなどに関連付けられる。

### 使用例: VPC内のSecurity Group一覧

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId,VpcId:VpcId,Description:Description}' \
  --output table
```

### 使用例: Security Groupの詳細を確認する

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --group-ids <security-group-id> \
  --output table
```

### 確認ポイント

- `0.0.0.0/0` でSSHやDBポートが開いていないか
- ALB、Web、DB、ElastiCacheの接続元が設計どおりか
- 使われていないSecurity Groupが残っていないか
- 説明欄に変更理由やチケット番号を残せているか

## aws ec2 describe-security-group-rules

### 名前

`describe-security-group-rules` - Security Groupルール単位で詳細を表示する

### 説明

Security GroupのルールID、方向、プロトコル、ポート、CIDR、参照先Security Groupを確認する。

ルール単位で変更や削除を行う場合は、`SecurityGroupRuleId` を確認しておくと安全である。

### 使用例

```bash
aws ec2 describe-security-group-rules \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=group-id,Values=<security-group-id>" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,RefGroup:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table
```

### よく使うフィルター

| フィルター | 意味 |
| :--- | :--- |
| `group-id` | Security Group IDで絞り込む |
| `security-group-rule-id` | ルールIDで絞り込む |
| `is-egress` | インバウンドまたはアウトバウンドで絞り込む |
| `ip-protocol` | `tcp`、`udp`、`icmp` などで絞り込む |
| `from-port` | 開始ポートで絞り込む |
| `to-port` | 終了ポートで絞り込む |
| `cidr` | CIDRで絞り込む |

## aws ec2 authorize-security-group-ingress / revoke-security-group-ingress

### 名前

`authorize-security-group-ingress` - インバウンドルールを追加する

`revoke-security-group-ingress` - インバウンドルールを削除する

### 使用例: 特定IPからSSHを許可する

```bash
aws ec2 authorize-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <security-group-id> \
  --protocol tcp \
  --port 22 \
  --cidr <your-global-ip>/32
```

### 使用例: ルールIDを指定して削除する

```bash
aws ec2 revoke-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <security-group-id> \
  --security-group-rule-ids <security-group-rule-id>
```

### 変更時の注意点

Security Group変更は即時反映される。

変更前に、以下を確認する。

- そのSecurity Groupが関連付いているリソース
- 既存通信への影響
- 許可元CIDRが必要最小限か
- 戻し手順
- 作業後の疎通確認方法

## aws ec2 authorize-security-group-egress / revoke-security-group-egress

### 名前

`authorize-security-group-egress` - アウトバウンドルールを追加する

`revoke-security-group-egress` - アウトバウンドルールを削除する

### 使用例: HTTPSアウトバウンドを許可する

```bash
aws ec2 authorize-security-group-egress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <security-group-id> \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### 使用例: ルールIDを指定して削除する

```bash
aws ec2 revoke-security-group-egress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id <security-group-id> \
  --security-group-rule-ids <security-group-rule-id>
```

## aws ec2 describe-network-acls

### 名前

`describe-network-acls` - Network ACLの一覧または詳細を表示する

### 説明

Network ACLはサブネット単位で関連付けられるステートレスなアクセス制御である。

Security Groupとは異なり、インバウンドとアウトバウンドをそれぞれ明示的に許可する必要がある。

### 使用例: VPC内のNetwork ACL一覧

```bash
aws ec2 describe-network-acls \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkAcls[*].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,Default:IsDefault,Associations:Associations[*].SubnetId,Entries:Entries[*].{Rule:RuleNumber,Egress:Egress,Action:RuleAction,Protocol:Protocol,CIDR:CidrBlock,From:PortRange.From,To:PortRange.To}}' \
  --output table
```

### 確認ポイント

- 対象サブネットにどのNACLが関連付いているか
- 明示的な `deny` が通信を止めていないか
- エフェメラルポートの戻り通信が許可されているか
- ルール番号の優先順位が意図どおりか

## aws ec2 create-network-acl-entry / replace-network-acl-entry / delete-network-acl-entry

### 名前

`create-network-acl-entry` - NACLルールを追加する

`replace-network-acl-entry` - NACLルールを変更する

`delete-network-acl-entry` - NACLルールを削除する

### 使用例: インバウンドHTTPSを許可する

```bash
aws ec2 create-network-acl-entry \
  --profile learning \
  --region ap-northeast-1 \
  --network-acl-id <network-acl-id> \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=443,To=443
```

### 使用例: アウトバウンドHTTPSを許可する

```bash
aws ec2 create-network-acl-entry \
  --profile learning \
  --region ap-northeast-1 \
  --network-acl-id <network-acl-id> \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=443,To=443
```

### 使用例: NACLルールを削除する

```bash
aws ec2 delete-network-acl-entry \
  --profile learning \
  --region ap-northeast-1 \
  --network-acl-id <network-acl-id> \
  --rule-number 100 \
  --ingress
```

アウトバウンドルールを削除する場合は `--egress` を付ける。

```bash
aws ec2 delete-network-acl-entry \
  --profile learning \
  --region ap-northeast-1 \
  --network-acl-id <network-acl-id> \
  --rule-number 100 \
  --egress
```

## aws ec2 describe-vpc-endpoints

### 名前

`describe-vpc-endpoints` - VPC Endpointの一覧または詳細を表示する

### 説明

VPC Endpointは、VPC内からAWSサービスへプライベートに接続するためのリソースである。

S3やDynamoDBではGateway Endpoint、Secrets ManagerやSSMなどではInterface Endpointを使うことが多い。

### 使用例

```bash
aws ec2 describe-vpc-endpoints \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'VpcEndpoints[*].{Name:Tags[?Key==`Name`].Value|[0],EndpointId:VpcEndpointId,Type:VpcEndpointType,Service:ServiceName,State:State,Subnets:SubnetIds,RouteTables:RouteTableIds,PrivateDns:PrivateDnsEnabled}' \
  --output table
```

### 確認ポイント

- S3向け通信がNAT Gateway経由ではなくGateway Endpoint経由になっているか
- Interface EndpointのSecurity Groupが適切か
- Private DNSが必要なEndpointで有効になっているか
- エンドポイントポリシーが広すぎないか

## aws ec2 describe-vpc-endpoint-services

### 名前

`describe-vpc-endpoint-services` - 利用可能なVPC Endpointサービス名を確認する

### 使用例: S3のサービス名を確認する

```bash
aws ec2 describe-vpc-endpoint-services \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.s3" \
  --output table
```

## aws ec2 create-vpc-endpoint

### 名前

`create-vpc-endpoint` - VPC Endpointを作成する

### 使用例: S3 Gateway Endpointを作成する

```bash
aws ec2 create-vpc-endpoint \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.ap-northeast-1.s3 \
  --route-table-ids <route-table-id>
```

### 使用例: Interface Endpointを作成する

```bash
aws ec2 create-vpc-endpoint \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.ap-northeast-1.secretsmanager \
  --subnet-ids <subnet-id-1> <subnet-id-2> \
  --security-group-ids <security-group-id> \
  --private-dns-enabled
```

## aws ec2 describe-flow-logs

### 名前

`describe-flow-logs` - VPC Flow Logsの設定を表示する

### 説明

VPC Flow Logsは、VPC、Subnet、ENI単位でIPトラフィックのメタデータを記録する機能である。

通信影響調査、セキュリティ調査、GuardDuty Findingsの裏取りでよく使う。

### 使用例

```bash
aws ec2 describe-flow-logs \
  --profile learning \
  --region ap-northeast-1 \
  --filter "Name=resource-id,Values=<vpc-id>" \
  --query 'FlowLogs[*].{FlowLogId:FlowLogId,ResourceId:ResourceId,TrafficType:TrafficType,LogDestinationType:LogDestinationType,LogDestination:LogDestination,Status:FlowLogStatus}' \
  --output table
```

### 確認ポイント

- VPCまたは重要SubnetでFlow Logsが有効か
- `TrafficType` が `ACCEPT`、`REJECT`、`ALL` のどれか
- 出力先がCloudWatch LogsかS3か
- ログ保存期間やアクセス権限が運用要件に合っているか

## aws ec2 create-flow-logs

### 名前

`create-flow-logs` - VPC Flow Logsを作成する

### 使用例: CloudWatch Logsへ出力する

```bash
aws ec2 create-flow-logs \
  --profile learning \
  --region ap-northeast-1 \
  --resource-type VPC \
  --resource-ids <vpc-id> \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs/sample-vpc \
  --deliver-logs-permission-arn arn:aws:iam::<account-id>:role/<flowlogs-role-name>
```

### 主なオプション

| オプション | 意味 |
| :--- | :--- |
| `--resource-type` | `VPC`、`Subnet`、`NetworkInterface` を指定 |
| `--resource-ids` | Flow Logs対象のリソースID |
| `--traffic-type` | `ACCEPT`、`REJECT`、`ALL` |
| `--log-destination-type` | `cloud-watch-logs` または `s3` |
| `--log-group-name` | CloudWatch Logsのロググループ名 |
| `--deliver-logs-permission-arn` | Flow Logs配信用IAMロールARN |

## aws ec2 describe-network-interfaces

### 名前

`describe-network-interfaces` - ENIの一覧または詳細を表示する

### 説明

ENIはElastic Network Interfaceの略である。

EC2だけでなく、ALB、NAT Gateway、RDS、Lambda、VPC Endpointなど、多くのAWSリソースがENIを作成する。

通信調査では、IPアドレスからどのAWSリソースかを特定するためによく使う。

### 使用例: VPC内のENIを一覧表示する

```bash
aws ec2 describe-network-interfaces \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'NetworkInterfaces[*].{ENI:NetworkInterfaceId,Description:Description,Status:Status,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,Groups:Groups[*].GroupId,Attachment:Attachment.InstanceId}' \
  --output table
```

### 使用例: Private IPからENIを探す

```bash
aws ec2 describe-network-interfaces \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=addresses.private-ip-address,Values=<private-ip>" \
  --output table
```

### 確認ポイント

- 対象IPがどのENIに紐づいているか
- ENIがどのSubnetにあるか
- どのSecurity Groupが付いているか
- LambdaやVPC Endpointが作ったENIではないか

## aws ec2 describe-instances

### 名前

`describe-instances` - EC2インスタンスの一覧または詳細を表示する

### 使用例: VPC内のEC2を確認する

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SGs:SecurityGroups[*].GroupId}' \
  --output table
```

### 確認ポイント

- Public IPを持つべきでないインスタンスにPublic IPが付いていないか
- サブネット配置が設計どおりか
- 付与Security Groupが設計どおりか

## aws rds describe-db-instances

### 名前

`describe-db-instances` - RDS DBインスタンスの一覧または詳細を表示する

### VPC調査での用途

RDSはVPC内のDB Subnet Groupに配置される。

ネットワーク調査では、RDSのSubnet Group、Security Group、Publicly Accessible、Endpointを確認する。

### 使用例

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DBInstances[*].{DB:DBInstanceIdentifier,Engine:Engine,Endpoint:Endpoint.Address,Public:PubliclyAccessible,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcId:DBSubnetGroup.VpcId,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table
```

## aws rds describe-db-subnet-groups

### 名前

`describe-db-subnet-groups` - RDS DB Subnet Groupを表示する

### 使用例

```bash
aws rds describe-db-subnet-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table
```

## aws lambda get-function-configuration

### 名前

`get-function-configuration` - Lambda関数の設定を表示する

### VPC調査での用途

LambdaがVPC接続されている場合、対象SubnetとSecurity Groupを確認できる。

### 使用例

```bash
aws lambda get-function-configuration \
  --profile learning \
  --region ap-northeast-1 \
  --function-name <function-name> \
  --query '{FunctionName:FunctionName,State:State,VpcConfig:VpcConfig}' \
  --output table
```

## aws guardduty list-detectors / list-findings / get-findings

### 名前

`list-detectors` - GuardDuty Detector IDを取得する

`list-findings` - GuardDuty Finding IDを一覧表示する

`get-findings` - Findingの詳細を取得する

### VPC調査での用途

GuardDuty Findingsには、EC2、IAM、S3、Kubernetesなどさまざまな種類がある。

EC2関連Findingでは、疑わしい通信先IP、対象インスタンス、ENI、VPC、Security Groupなどを確認するきっかけになる。

### 使用例: Detector IDを取得する

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DetectorIds[0]' \
  --output text)
```

### 使用例: Finding IDを一覧表示する

```bash
aws guardduty list-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "$DETECTOR_ID" \
  --output table
```

### 使用例: Finding詳細を確認する

```bash
aws guardduty get-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "$DETECTOR_ID" \
  --finding-ids <finding-id> \
  --output json
```

## aws cloudtrail lookup-events

### 名前

`lookup-events` - CloudTrailイベント履歴を検索する

### VPC調査での用途

Security Group、Route Table、NACL、VPC Endpointなどの設定変更が、いつ、誰によって行われたかを確認するために使う。

### 使用例: VPC IDを含むイベントを検索する

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<vpc-id> \
  --output table
```

### 使用例: Security Group IDを含むイベントを検索する

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<security-group-id> \
  --output table
```

### 確認ポイント

- 設定変更を行ったIAMユーザーまたはロール
- 実行されたAPI名
- 実行日時
- 変更対象リソース

## aws ec2 create-network-insights-path / start-network-insights-analysis

### 名前

`create-network-insights-path` - Reachability Analyzerの解析パスを作成する

`start-network-insights-analysis` - 到達性解析を開始する

### 説明

Reachability Analyzerは、送信元から宛先までのネットワーク到達性を解析する機能である。

Security Group、NACL、Route Tableなどが複雑な環境で、通信できない原因を調査する際に役立つ。

### 使用例: 解析パスを作成する

```bash
PATH_ID=$(aws ec2 create-network-insights-path \
  --profile learning \
  --region ap-northeast-1 \
  --source <source-resource-id> \
  --destination <destination-resource-id> \
  --protocol tcp \
  --destination-port 443 \
  --query 'NetworkInsightsPath.NetworkInsightsPathId' \
  --output text)
```

### 使用例: 到達性解析を開始する

```bash
ANALYSIS_ID=$(aws ec2 start-network-insights-analysis \
  --profile learning \
  --region ap-northeast-1 \
  --network-insights-path-id "$PATH_ID" \
  --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' \
  --output text)
```

### 使用例: 解析結果を確認する

```bash
aws ec2 describe-network-insights-analyses \
  --profile learning \
  --region ap-northeast-1 \
  --network-insights-analysis-ids "$ANALYSIS_ID" \
  --output table
```

## aws ec2 describe-vpc-peering-connections

### 名前

`describe-vpc-peering-connections` - VPC Peering Connectionを表示する

### 使用例

```bash
aws ec2 describe-vpc-peering-connections \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=requester-vpc-info.vpc-id,Values=<vpc-id>" \
  --query 'VpcPeeringConnections[*].{PeeringId:VpcPeeringConnectionId,Status:Status.Code,Requester:RequesterVpcInfo.VpcId,Accepter:AccepterVpcInfo.VpcId}' \
  --output table
```

### 確認ポイント

- Peeringの状態が `active` か
- 双方のRoute Tableに戻り経路があるか
- CIDRが重複していないか

## aws ec2 describe-transit-gateways / describe-transit-gateway-attachments

### 名前

`describe-transit-gateways` - Transit Gatewayを表示する

`describe-transit-gateway-attachments` - Transit Gateway Attachmentを表示する

### 使用例: Transit Gateway一覧

```bash
aws ec2 describe-transit-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

### 使用例: VPC Attachmentを確認する

```bash
aws ec2 describe-transit-gateway-attachments \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=resource-id,Values=<vpc-id>" \
  --output table
```

## aws ec2 describe-vpn-connections

### 名前

`describe-vpn-connections` - Site-to-Site VPN接続を表示する

### 使用例

```bash
aws ec2 describe-vpn-connections \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

### 確認ポイント

- VPNトンネルの状態
- Customer GatewayのIP
- Transit GatewayまたはVirtual Private Gatewayとの関連
- オンプレミス向けルート

## 変更作業前後の基本確認セット

### 作業前に取得する情報

```bash
aws sts get-caller-identity --profile learning --output table
```

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --output table
```

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --output table
```

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --output table
```

```bash
aws ec2 describe-network-acls \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --output table
```

### 作業後に確認する観点

- 変更対象リソースが想定どおり変わっていること
- 変更対象外のリソースに差分がないこと
- 通信経路が設計どおりであること
- Security GroupやNACLが必要最小限であること
- CloudTrailに作業履歴が残っていること
- VPC Flow Logsやアプリケーションログで異常が出ていないこと

## 共通オプション

## --profile

### 名前

`--profile` - 使用するAWS CLIプロファイルを指定する

### 書式

```bash
--profile <profile-name>
```

### 説明

AWS CLIの認証情報セットを指定する。

例:

```bash
--profile learning
```

プロファイルは通常、以下のファイルに保存されている。

```txt
~/.aws/credentials
~/.aws/config
```

### 確認コマンド

```bash
aws configure list --profile learning
```

## --region

### 名前

`--region` - 操作対象のAWSリージョンを指定する

### 書式

```bash
--region <region-name>
```

### 説明

AWSリソースを作成、変更、参照するリージョンを指定する。

例:

```bash
--region ap-northeast-1
```

よく使うリージョン:

| リージョン | 場所 |
| :--- | :--- |
| `ap-northeast-1` | 東京 |
| `ap-northeast-3` | 大阪 |
| `us-east-1` | バージニア北部 |
| `us-west-2` | オレゴン |

## --output

### 名前

`--output` - AWS CLIの出力形式を指定する

### 書式

```bash
--output <json|yaml|yaml-stream|text|table>
```

### 説明

AWS CLIの結果表示形式を指定する。

| 値 | 用途 |
| :--- | :--- |
| `json` | デフォルトに近い形式。プログラム処理しやすい |
| `yaml` | 人間が読みやすいYAML形式 |
| `text` | 値だけを取り出したい時に便利 |
| `table` | ターミナル上で表形式で確認したい時に便利 |

### 使用例

表形式で確認:

```bash
--output table
```

シェル変数にIDだけを入れる:

```bash
--query 'Vpc.VpcId' --output text
```

## --query

### 名前

`--query` - AWS CLIの出力をJMESPathで絞り込む

### 書式

```bash
--query '<jmespath-expression>'
```

### 説明

AWS CLIのレスポンスから、必要な値だけを取り出すために使う。

AWS CLIの出力はJSON構造になっているため、`--query` で階層を指定すると必要な項目だけを表示できる。

### 使用例: VPC IDだけ取り出す

```bash
--query 'Vpc.VpcId'
```

### 使用例: VPC一覧を見やすく整形する

```bash
--query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}'
```

### 使用例: Nameタグを取り出す

```bash
--query 'Vpcs[*].{Name:Tags[?Key==`Name`].Value|[0]}'
```

### よく使う記法

| 記法 | 意味 |
| :--- | :--- |
| `Vpc.VpcId` | `Vpc` オブジェクトの中の `VpcId` を取り出す |
| `Vpcs[*]` | `Vpcs` 配列の全要素を対象にする |
| `{ID:VpcId}` | 出力項目名を `ID` として表示する |
| `Tags[?Key==\`Name\`]` | Tags配列からKeyがNameのものを選ぶ |
| `Value|[0]` | Value配列の先頭要素を取り出す |

## --filters

### 名前

`--filters` - AWSリソースの検索条件を指定する

### 書式

```bash
--filters "Name=<filter-name>,Values=<value1>,<value2>"
```

### 説明

`describe-*` 系コマンドで、表示対象を条件で絞り込むために使う。

### 使用例: Nameタグで絞る

```bash
--filters "Name=tag:Name,Values=sample-vpc"
```

### 使用例: CIDRで絞る

```bash
--filters "Name=cidr-block,Values=10.0.0.0/16"
```

### 使用例: available状態のVPCだけ表示する

```bash
--filters "Name=state,Values=available"
```

## よく使う組み合わせ

### 現在のAWSアカウントを確認する

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table
```

### VPCを作成してVPC IDだけ取得する

```bash
VPC_ID=$(aws ec2 create-vpc \
  --profile learning \
  --region ap-northeast-1 \
  --cidr-block 10.0.0.0/16 \
  --instance-tenancy default \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=sample-vpc}]" \
  --query 'Vpc.VpcId' \
  --output text)
```

### VPCをNameタグで検索する

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-vpc" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}' \
  --output table
```

### DNS Hostnamesを確認する

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --attribute enableDnsHostnames \
  --output table
```

### DNS Supportを確認する

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --attribute enableDnsSupport \
  --output table
```

## トラブルシュート

### `Unable to locate credentials`

AWS CLIの認証情報が見つからない状態である。

確認:

```bash
aws configure list --profile learning
```

設定:

```bash
aws configure --profile learning
```

### `The config profile (learning) could not be found`

指定したプロファイルが存在しない。

`--profile learning` を使う場合は、事前に `learning` プロファイルを作成しておく必要がある。

### `UnauthorizedOperation`

IAM権限が不足している。

VPC作成では、少なくとも以下のようなEC2権限が必要である。

- `ec2:CreateVpc`
- `ec2:CreateTags`
- `ec2:ModifyVpcAttribute`
- `ec2:DescribeVpcs`
- `ec2:DescribeVpcAttribute`

### `InvalidVpcID.NotFound`

指定したVPC IDが見つかりない。

主な原因:

- VPC IDが間違っている
- 指定したリージョンが違う
- 別のAWSアカウントを見ている

確認:

```bash
aws sts get-caller-identity --profile learning
aws ec2 describe-vpcs --profile learning --region ap-northeast-1 --output table
```

### `DNSHost` や `DNSSupport` が `None` と表示される

`describe-vpcs` の `--query` で存在しない属性を参照している可能性がある。

DNS属性は以下で確認する。

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --attribute enableDnsHostnames \
  --output table
```

```bash
aws ec2 describe-vpc-attribute \
  --profile learning \
  --region ap-northeast-1 \
  --vpc-id <vpc-id> \
  --attribute enableDnsSupport \
  --output table
```
