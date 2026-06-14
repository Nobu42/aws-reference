# Day 10 Learning: VPC・Subnet・Route Table確認ドリル

## 学習開始前に実行するスクリプト

Day 10は`sample-vpc`、Subnet、Route Table、IGW、NAT Gatewayを実物確認するため、`sample-vpc`が存在しない場合は最初に日次ラボ環境を構築する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

Ansible、CloudTrail一時Trail、S3 Data Eventは不要である。学習終了後、後続のネットワーク系Dayを続けない場合は`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

## 1. 今日の目的

AWS環境のVPC、Subnet、Route Table、Internet Gateway、NAT Gatewayを確認し、各Subnetの通信経路とPublic／Privateの役割を説明できる状態を目指す。

Day 10で最も重要なポイントは、Subnet名やタグだけでPublic／Privateを判断せず、実際に使用されるRoute Tableとデフォルトルートを確認することである。

```text
Subnet名がpublicでも、Internet Gateway向けRouteがなければ
Public Subnetとして外部通信できない。

Subnet名がprivateでも、Internet Gateway向けRouteが関連付いていれば
意図しない外部公開につながる可能性がある。
```

本ドリルでは設定変更を行わない。VPC、Subnet、Route Table、Gatewayの現在設定を確認し、設計書との一致、通信経路、影響調査項目、証跡、報告内容を整理する。

関連資料:

- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)
- [Route Table構築スクリプト](../scripts/05_route_table_setup.sh)
- [Day 7 CloudTrail・CloudWatch総合調査ドリル](./07_Day_Learning.md)
- [Day 9 GuardDutyサンプルFinding調査・後片付け](./09_Day_Learning.md)

## 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象VPC内のSubnetとRoute Table設定を確認してください。

各SubnetがPublic／Privateのどちらとして動作するか、
Internet向け通信がIGW、NAT Gateway、閉域経路のどれを通るか、
Main Route Tableまたは明示関連付けのどちらを使用するかを整理してください。

設定変更は実施しないでください。
```

## 今日の確認順序

1. AWSアカウント、リージョン、対象VPCを確認する
2. 証跡保存先を準備する
3. VPCのCIDR、状態、DNS属性を確認する
4. VPC内のSubnet一覧、CIDR、AZ、Public IP自動割当を確認する
5. Route Table一覧とRouteを確認する
6. Main Route Tableを確認する
7. 各Subnetの明示的なRoute Table関連付けを確認する
8. 明示関連付けがないSubnetのMain Route Table利用を確認する
9. デフォルトルートの宛先とTargetを確認する
10. Internet GatewayとNAT Gatewayを確認する
11. Public／Private SubnetをRoute Tableから判定する
12. Routeの`blackhole`と想定外経路を確認する
13. EC2、ALB、RDSなどの配置とSubnet役割を照合する
14. CloudTrailでネットワーク変更履歴を確認する
15. 証跡、調査結果、要確認事項、Teams報告を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象VPC名 | `sample-vpc` |
| 想定VPC CIDR | `10.0.0.0/16` |
| 主な確認対象 | VPC、Subnet、Route Table、IGW、NAT Gateway |
| 設定変更 | なし |

## ラボ環境の期待構成

| Subnet | AZ | CIDR | 期待Route Table | 期待デフォルトルート |
|---|---|---|---|---|
| `sample-subnet-public01` | `ap-northeast-1a` | `10.0.0.0/20` | `sample-rt-public` | `0.0.0.0/0 -> IGW` |
| `sample-subnet-public02` | `ap-northeast-1c` | `10.0.16.0/20` | `sample-rt-public` | `0.0.0.0/0 -> IGW` |
| `sample-subnet-private01` | `ap-northeast-1a` | `10.0.64.0/20` | `sample-rt-private01` | `0.0.0.0/0 -> NAT Gateway 01` |
| `sample-subnet-private02` | `ap-northeast-1c` | `10.0.80.0/20` | `sample-rt-private02` | `0.0.0.0/0 -> NAT Gateway 02` |

## 今日実行しない操作

- VPC、Subnet、Route Tableの作成・削除
- Routeの作成、置換、削除
- Route Table Associationの作成、置換、解除
- Main Route Tableの変更
- Internet GatewayのAttach、Detach
- NAT Gatewayの作成、削除
- Public IP自動割当設定の変更
- VPC DNS属性の変更
- Security Group、NACL、VPC Endpointの変更
- 疎通試験目的の一時的なRoute変更

---

## 2. Public／Private Subnetの考え方

AWSに「Public Subnet」や「Private Subnet」というリソース種別が存在するわけではない。Subnetへ関連付くRoute Table、Gateway、Public IP、Security Groupなどの組み合わせによって役割が決まる。

## Public Subnetの基本

IPv4で一般的にPublic Subnetと判断する中心条件は、Subnetが使用するRoute TableにInternet Gateway向けRouteがあることである。

```text
0.0.0.0/0 -> igw-xxxxxxxx
```

ただし、EC2がInternet Gateway経由でInternetと直接通信するには、通常は次も必要になる。

- EC2にPublic IPv4アドレスまたはElastic IPがある
- Security GroupとNACLが通信を許可する
- OS・アプリケーションが通信を受け付ける

## Private Subnetの基本

Private Subnetでは、Internet Gatewayへの直接Routeを持たない。

外向き通信が必要な場合は、一般的にNAT Gateway、NAT Instance、Transit Gateway、Firewall、プロキシなどを経由する。

```text
0.0.0.0/0 -> nat-xxxxxxxx
```

または、閉域構成や完全隔離構成ではデフォルトルート自体を持たない場合がある。

## Route Tableによる判定例

| デフォルトルート | 基本的な判定 | 注意点 |
|---|---|---|
| `0.0.0.0/0 -> igw-*` | Public候補 | リソースのPublic IP、SG、NACLも必要 |
| `0.0.0.0/0 -> nat-*` | Private outbound | NAT Gatewayの配置Subnetと状態を確認 |
| `0.0.0.0/0 -> tgw-*` | 集約・閉域経路 | TGW側RouteやFirewall経路を確認 |
| `0.0.0.0/0 -> vgw-*` | VPN・閉域経路 | オンプレ側Routeも確認 |
| デフォルトルートなし | 隔離・内部専用候補 | VPC内・Endpoint通信だけの場合がある |

## IPv6の注意

IPv6を使用する場合は、`::/0`のRouteも確認する。

| Target | 意味 |
|---|---|
| Internet Gateway | IPv6 Internet通信 |
| Egress-only Internet Gateway | IPv6の外向き通信のみ |

Day 10のラボ環境ではIPv4を中心に確認するが、実案件ではIPv6利用有無も確認する。

---

## 3. Route Table関連付けの考え方

各Subnetは、必ず1つのRoute Tableを使用する。

## 明示関連付け

Subnet IDを指定してRoute Tableへ明示的に関連付けた状態である。

```text
Subnet
  ↓ explicit association
Route Table
```

## Main Route Tableの暗黙利用

Subnetに明示関連付けがない場合、そのVPCのMain Route Tableを暗黙的に使用する。

```text
Subnet
  ↓ no explicit association
Main Route Table
```

重要:

```text
association.subnet-idでRoute Tableを検索して結果が空でも、
SubnetにRoute Tableがないという意味ではない。

明示関連付けがないため、Main Route Tableを使用している可能性がある。
```

## Main Route Table確認が重要な理由

- 新規Subnetが作成された直後はMain Route Tableを使用する
- 明示関連付けが外れた場合、通信経路がMain Route Tableへ変わる
- Main Route Table変更は、暗黙利用する複数Subnetへ影響する
- 意図しないIGW Routeがあると、新規SubnetがPublic経路を持つ可能性がある

---

## 4. Route選択の基本

Route Table内では、宛先IPに最も具体的に一致するRouteが選択される。

```text
Longer Prefix Match:
より長いPrefix、つまりより具体的なRouteが優先される。
```

例:

```text
10.0.0.0/16 -> local
0.0.0.0/0   -> nat-xxxxxxxx
```

宛先`10.0.80.10`は`10.0.0.0/16 -> local`に一致するためVPC内通信となる。`8.8.8.8`はVPC CIDRに一致しないため、`0.0.0.0/0 -> NAT Gateway`が使用される。

## よく見るRoute

| Route | 用途 |
|---|---|
| VPC CIDR `-> local` | VPC内通信 |
| `0.0.0.0/0 -> igw-*` | IPv4 Internet Gateway |
| `0.0.0.0/0 -> nat-*` | NAT Gateway経由の外向き通信 |
| `pl-* -> vpce-*` | S3・DynamoDB Gateway Endpoint |
| オンプレCIDR `-> tgw-*` | Transit Gateway経由 |
| オンプレCIDR `-> vgw-*` | VPN・Direct Connect側 |
| Peering先CIDR `-> pcx-*` | VPC Peering |

## `blackhole`

RouteのTargetが削除・切断されるなどして利用できない場合、Route Stateが`blackhole`になることがある。

`blackhole`は通信断原因になり得るため、見つけた場合はTarget、影響Subnet、通信要件を確認し、早めに共有する。

---

## 5. 作業開始条件と中止・報告条件

## 作業開始条件

- 対象AWSアカウント、リージョン、VPCが明確である
- 読み取り専用の確認である
- 設計書または期待構成を確認できる
- 証跡保存先が準備されている
- VPC、Subnet、Route Tableを確認できる権限がある

## 中止・即時報告条件

- AWSアカウントまたはリージョンが想定と異なる
- 対象VPCを一意に特定できない
- 同じNameタグのVPCが複数存在する
- Private想定SubnetにIGW向けデフォルトルートがある
- Public想定SubnetにIGW向けRouteがない
- Route Stateが`blackhole`
- Main Route Tableに想定外のデフォルトルートがある
- NAT Gatewayが`available`ではない
- Route Table関連付けが設計書と異なる
- 設定変更が必要になった

異常を見つけても、独断でRouteやAssociationを変更しない。通信影響が大きいため、対象Subnet、関連リソース、通信要件を整理して報告する。

---

## 6. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
VPC_NAME="sample-vpc"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID VPC_NAME
do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

---

## 7. 証跡保存用ディレクトリの作成

```bash
WORK_NAME="vpc_subnet_route_table_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/vpc" \
  "$EVIDENCE_DIR/subnets" \
  "$EVIDENCE_DIR/routes" \
  "$EVIDENCE_DIR/gateways" \
  "$EVIDENCE_DIR/resources" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/report" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 証跡ディレクトリ確認

```bash
find "$EVIDENCE_DIR" \
  -maxdepth 1 \
  -type d \
  -print \
  | sort
```

| ディレクトリ | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、作業対象 |
| `vpc` | VPC一覧、VPC属性 |
| `subnets` | Subnet一覧、Subnet属性 |
| `routes` | Route Table、Association、判定結果 |
| `gateways` | IGW、NAT Gateway |
| `resources` | EC2、ALB、RDSなどのSubnet配置 |
| `cloudtrail` | ネットワーク変更履歴 |
| `report` | 調査結果、Teams報告 |
| `screenshots` | Webコンソール証跡 |

---

## 8. AWSアカウントと対象VPCを確認する

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. AWSアカウントと東京リージョンを確認する
3. VPCコンソールを開く
4. 「VPC」を開く
5. `sample-vpc`が存在することを確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_対象VPC確認.png
```

### Caller Identity

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

### 対象VPC候補数を確認する

```bash
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text \
  --no-cli-pager)

echo "VPC_COUNT=$VPC_COUNT"
```

期待値:

```text
1
```

### VPC ID取得

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --no-cli-pager)

echo "VPC_ID=$VPC_ID"
```

### 必須チェック

```bash
if [ "$VPC_COUNT" != "1" ] || [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "ERROR: Target VPC could not be uniquely identified."
else
  echo "Target VPC check OK: $VPC_ID"
fi
```

---

## 9. VPCの基本設定を確認する

### AWS CLI: 対象VPC

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[].{VpcId:VpcId,State:State,Cidr:CidrBlock,OwnerId:OwnerId,IsDefault:IsDefault,Tenancy:InstanceTenancy,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/vpc/01_target_vpc.json"
```

### 確認ポイント

| 項目 | 期待値 |
|---|---|
| VPC ID | 取得した対象VPC ID |
| State | `available` |
| CIDR | `10.0.0.0/16` |
| IsDefault | `False` |
| OwnerId | 想定AWSアカウント |
| Name | `sample-vpc` |

## VPC DNS属性

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/vpc/02_dns_support.json"

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/vpc/03_dns_hostnames.json"
```

期待値:

```text
EnableDnsSupport: True
EnableDnsHostnames: True
```

---

## 10. Subnet一覧を確認する

### Webコンソール

1. VPCコンソールの「サブネット」を開く
2. 対象VPCで絞り込む
3. Subnet名、Subnet ID、CIDR、AZを確認する
4. Public IPv4自動割当を確認する

取得するスクリーンショット:

```text
03_Subnet一覧.png
```

### AWS CLI

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],SubnetId:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock,AvailableIp:AvailableIpAddressCount,MapPublicIp:MapPublicIpOnLaunch,State:State,TypeTag:Tags[?Key==`Type`].Value|[0]}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/subnets/01_subnets.json"
```

### 確認ポイント

- 4つのSubnetが存在する
- CIDRが重複していない
- `ap-northeast-1a`と`ap-northeast-1c`へ分散している
- Public想定Subnetの`MapPublicIpOnLaunch=True`
- Private想定Subnetの`MapPublicIpOnLaunch=False`
- Available IPが枯渇していない
- Name・Typeタグと実際のRouteが一致するかは後続で確認する

---

## 11. Subnet IDを取得する

各SubnetをRoute Tableと照合するため、Subnet IDを取得する。

```bash
PUBLIC01_SUBNET_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values=sample-subnet-public01 \
  --query 'Subnets[0].SubnetId' \
  --output text \
  --no-cli-pager)

PUBLIC02_SUBNET_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values=sample-subnet-public02 \
  --query 'Subnets[0].SubnetId' \
  --output text \
  --no-cli-pager)

PRIVATE01_SUBNET_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values=sample-subnet-private01 \
  --query 'Subnets[0].SubnetId' \
  --output text \
  --no-cli-pager)

PRIVATE02_SUBNET_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values=sample-subnet-private02 \
  --query 'Subnets[0].SubnetId' \
  --output text \
  --no-cli-pager)
```

### 確認

```bash
printf 'PUBLIC01_SUBNET_ID=%s\nPUBLIC02_SUBNET_ID=%s\nPRIVATE01_SUBNET_ID=%s\nPRIVATE02_SUBNET_ID=%s\n' \
  "$PUBLIC01_SUBNET_ID" "$PUBLIC02_SUBNET_ID" \
  "$PRIVATE01_SUBNET_ID" "$PRIVATE02_SUBNET_ID"
```

値が`None`または空の場合は、Nameタグ、VPC ID、Subnet作成状態を確認する。

---

## 12. Route Table一覧を確認する

### Webコンソール

1. VPCコンソールの「ルートテーブル」を開く
2. 対象VPCで絞り込む
3. Route Table名、ID、Main、Subnet関連付けを確認する
4. 各Route Tableの「ルート」タブを確認する

取得するスクリーンショット:

```text
04_Route_Table一覧.png
05_Route_Tableルート一覧.png
```

### AWS CLI: Route Table一覧

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Main:Associations[?Main==`true`].Main|[0],AssociatedSubnets:Associations[?SubnetId!=`null`].SubnetId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/routes/01_route_tables.json"
```

### Route一覧

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Routes:Routes[].{Destination:DestinationCidrBlock,DestinationIpv6:DestinationIpv6CidrBlock,PrefixList:DestinationPrefixListId,Gateway:GatewayId,NatGateway:NatGatewayId,TransitGateway:TransitGatewayId,VpcPeering:VpcPeeringConnectionId,State:State,Origin:Origin}}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- Public用、Private01用、Private02用Route Tableが存在する
- VPC CIDR向け`local` Routeがある
- Public用に`0.0.0.0/0 -> igw-*`
- Private用に`0.0.0.0/0 -> nat-*`
- Route Stateが`active`
- `blackhole`がない
- 想定外のTGW、VGW、Peering、Endpoint Routeがない

---

## 13. Main Route Tableを確認する

### AWS CLI

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=association.main,Values=true \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Associations:Associations,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=association.main,Values=true \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/routes/02_main_route_table.json"
```

### 確認ポイント

- Main Route Table ID
- Main Route TableのRoute
- IGW向けデフォルトルートが意図せずないか
- 暗黙利用するSubnetが存在するか
- 新規Subnet作成時に適用されても安全なRouteか

Main Route Tableに外部向けRouteがある場合は、暗黙利用する全Subnetへの影響を確認する。

---

## 14. 各Subnetの明示関連付けを確認する

### Public Subnet 01

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$PUBLIC01_SUBNET_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Associations:Associations,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

### Public Subnet 02

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$PUBLIC02_SUBNET_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

### Private Subnet 01

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$PRIVATE01_SUBNET_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

### Private Subnet 02

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$PRIVATE02_SUBNET_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

### 全Subnetの関連付けを証跡保存

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Main:Associations[?Main==`true`].Main|[0],Associations:Associations[].{SubnetId:SubnetId,AssociationId:RouteTableAssociationId,Main:Main},Routes:Routes}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/routes/03_route_table_associations.json"
```

### 結果の読み方

```text
結果あり:
Subnetは表示されたRoute Tableへ明示関連付けされている。

結果なし:
SubnetはMain Route Tableを暗黙的に使用している可能性がある。
Main Route Tableを確認する。
```

---

## 15. Public／PrivateをRoute Tableから判定する

各Subnetについて、名前ではなくRoute TableとDefault Routeを根拠に判定する。

## 判定表

| Subnet | 使用Route Table | Default Route | 判定 | 根拠 |
|---|---|---|---|---|
| public01 | `<rtb-id/name>` | `<target>` | Public / Private / 要確認 | `<route>` |
| public02 | `<rtb-id/name>` | `<target>` | Public / Private / 要確認 | `<route>` |
| private01 | `<rtb-id/name>` | `<target>` | Public / Private / 要確認 | `<route>` |
| private02 | `<rtb-id/name>` | `<target>` | Public / Private / 要確認 | `<route>` |

## 判定例

```text
sample-subnet-public01:
明示関連付けされたsample-rt-publicに
0.0.0.0/0 -> Internet GatewayがあるためPublic Subnetと判定する。

sample-subnet-private01:
明示関連付けされたsample-rt-private01に
0.0.0.0/0 -> NAT Gatewayがあり、
Internet Gatewayへの直接RouteがないためPrivate Subnetと判定する。
```

## 注意

`MapPublicIpOnLaunch=True`だけではPublic Subnetとは判定しない。Public IPが付与されてもIGW Routeがなければ、Internet Gateway経由の直接通信はできない。

---

## 16. デフォルトルートを横断確認する

### IPv4デフォルトルート

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,DefaultRoutes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].{Gateway:GatewayId,NatGateway:NatGatewayId,TransitGateway:TransitGatewayId,VpcPeering:VpcPeeringConnectionId,State:State}}' \
  --output table \
  --no-cli-pager
```

### IPv6デフォルトルート

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,DefaultIpv6Routes:Routes[?DestinationIpv6CidrBlock==`::/0`]}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- Public用だけがIGW向きか
- Private用はNAT Gateway向きか
- Main Route Tableの向き
- IPv6 Routeの有無
- `blackhole`がないか
- 想定外のTGW、Peering、VGW向けRouteがないか

---

## 17. Internet Gatewayを確認する

### Webコンソール

1. VPCコンソールの「インターネットゲートウェイ」を開く
2. 対象VPCへAttachされたIGWを確認する
3. Stateとタグを確認する

取得するスクリーンショット:

```text
06_Internet_Gateway確認.png
```

### AWS CLI

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[].{Name:Tags[?Key==`Name`].Value|[0],InternetGatewayId:InternetGatewayId,Attachments:Attachments}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/gateways/01_internet_gateways.json"
```

### 確認ポイント

- 対象VPCにAttach済み
- Public Route TableのTargetと同じIGW
- Private Route Tableが直接IGWを参照していない
- 不要・未AttachのIGWがない

---

## 18. NAT Gatewayを確認する

### Webコンソール

1. VPCコンソールの「NATゲートウェイ」を開く
2. 対象VPCで絞り込む
3. State、配置Subnet、Elastic IPを確認する
4. Private Route TableのTargetと照合する

取得するスクリーンショット:

```text
07_NAT_Gateway一覧.png
```

### AWS CLI

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --query 'NatGateways[].{Name:Tags[?Key==`Name`].Value|[0],NatGatewayId:NatGatewayId,State:State,ConnectivityType:ConnectivityType,SubnetId:SubnetId,PublicIp:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/gateways/02_nat_gateways.json"
```

### 確認ポイント

- `State=available`
- Public NAT GatewayがPublic Subnetに配置されている
- Public SubnetのRoute TableにIGW Routeがある
- Private01は同一AZのNAT Gateway 01へ向く
- Private02は同一AZのNAT Gateway 02へ向く
- Private Route Tableが削除済みNAT Gatewayを参照していない
- NAT Gatewayは課金対象である

### NAT Gateway障害・削除時の影響

- Private EC2からInternetへの外向き通信
- OS Package更新
- 外部API接続
- AWSサービスへの通信がNAT経由の場合
- Ansibleやデプロイ時のPackage取得

S3や他AWSサービスへの通信は、VPC Endpoint利用によってNAT Gatewayを経由しない構成もある。

---

## 19. `blackhole` Routeを確認する

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=route.state,Values=blackhole \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,BlackholeRoutes:Routes[?State==`blackhole`]}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=route.state,Values=blackhole \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/routes/04_blackhole_routes.json"
```

期待値:

```text
該当Routeなし
```

`blackhole`を確認した場合は、対象Route Table、関連Subnet、Target、影響通信を特定して報告する。

---

## 20. リソースのSubnet配置を照合する

Route Tableの役割と、実際に配置されているAWSリソースを照合する。

## EC2配置

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/resources/01_ec2_instances.json"
```

期待構成:

| リソース | Subnet役割 | Public IP |
|---|---|---|
| Bastion | Public | あり |
| Web01・Web02 | Private | なし |

## ALB配置

```bash
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'LoadBalancers[].{Name:LoadBalancerName,Scheme:Scheme,VpcId:VpcId,State:State.Code,Subnets:AvailabilityZones[].SubnetId,DNSName:DNSName}' \
  --output table \
  --no-cli-pager
```

期待構成:

```text
Internet-facing ALB:
Public Subnetに配置
```

## RDS Subnet Group

```bash
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBSubnetGroups[].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus,Subnets:Subnets[].SubnetIdentifier}' \
  --output table \
  --no-cli-pager
```

期待構成:

```text
RDS DB Subnet Group:
Private Subnetを使用
```

### 確認ポイント

- Internet-facing ALBがPublic Subnetにある
- BastionがPublic Subnetにある
- Web EC2がPrivate SubnetにありPublic IPを持たない
- RDS、ElastiCacheがPrivate Subnet Groupを使用する
- リソースの配置とRoute Tableの役割が一致する

---

## 21. 通信経路を説明する

## InternetからWebアプリケーション

```text
Internet
↓
Internet Gateway
↓
Public Subnet上のALB
↓
Private Subnet上のWeb EC2
```

InternetからPrivate Web EC2へ直接到達するのではなく、ALBを経由する。

## Private Web EC2からInternet

```text
Private Web EC2
↓
Private Subnet Route Table
↓
同一AZのNAT Gateway
↓
Public Subnet Route Table
↓
Internet Gateway
↓
Internet
```

戻り通信はNAT Gatewayの変換状態を通じて戻る。Internet側からPrivate EC2へ新規接続を開始する経路ではない。

## Web EC2からRDS

```text
Web EC2
↓
VPC CIDR向けlocal Route
↓
RDS
```

同一VPC内通信では通常`local` Routeが利用される。到達可否はSecurity Group、NACL、RDS設定も確認する。

## Route Tableだけでは判断できないこと

- Security Groupが通信を許可しているか
- NACLが双方向通信を許可しているか
- DNSが正しく解決されるか
- DestinationサービスがListenしているか
- ALB TargetがHealthyか
- FirewallやプロキシのPolicy

Day 10はRoute中心の確認であり、SG・NACLはDay 11で詳細確認する。

---

## 22. 設計書と実環境を照合する

| 確認対象 | 設計値 | 実環境 | 判定 |
|---|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `<value>` | OK / NG |
| Public Subnet 01 | `10.0.0.0/20` | `<value>` | OK / NG |
| Public Subnet 02 | `10.0.16.0/20` | `<value>` | OK / NG |
| Private Subnet 01 | `10.0.64.0/20` | `<value>` | OK / NG |
| Private Subnet 02 | `10.0.80.0/20` | `<value>` | OK / NG |
| Public Default Route | IGW | `<value>` | OK / NG |
| Private01 Default Route | NAT Gateway 01 | `<value>` | OK / NG |
| Private02 Default Route | NAT Gateway 02 | `<value>` | OK / NG |
| Main Route Table | 意図確認 | `<value>` | OK / 要確認 |

差異がある場合は、実環境を即時変更せず、設計書が古い可能性と実環境誤設定の両方を考慮する。

---

## 23. CloudTrailでネットワーク変更履歴を確認する

Route TableやGateway関連の変更履歴を確認する。

### Route Table関連イベント

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[?EventName==`CreateRoute` || EventName==`ReplaceRoute` || EventName==`DeleteRoute` || EventName==`AssociateRouteTable` || EventName==`ReplaceRouteTableAssociation` || EventName==`DisassociateRouteTable`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[?EventName==`CreateRoute` || EventName==`ReplaceRoute` || EventName==`DeleteRoute` || EventName==`AssociateRouteTable` || EventName==`ReplaceRouteTableAssociation` || EventName==`DisassociateRouteTable`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/01_route_change_events.json"
```

### 確認する代表イベント

| EventName | 意味 |
|---|---|
| `CreateRoute` | Route追加 |
| `ReplaceRoute` | Route Target変更 |
| `DeleteRoute` | Route削除 |
| `AssociateRouteTable` | SubnetへRoute Table関連付け |
| `ReplaceRouteTableAssociation` | 関連付け先変更 |
| `DisassociateRouteTable` | 明示関連付け解除 |
| `ModifySubnetAttribute` | Public IP自動割当などの変更 |
| `AttachInternetGateway` | IGW Attach |
| `DetachInternetGateway` | IGW Detach |
| `CreateNatGateway` | NAT Gateway作成 |
| `DeleteNatGateway` | NAT Gateway削除 |

### 注意

- Event Historyは直近90日間のManagement Event検索
- 変更履歴がないことは、設定が正しいことを保証しない
- 変更者、時刻、対象、送信元IP、UserAgent、エラー有無を確認する

---

## 24. Route Table変更時の影響調査

Day 10では変更しないが、実案件でRoute変更を依頼された場合は次を確認する。

## 変更前確認

- 対象Route Table ID
- Main Route Tableか
- 関連Subnet一覧
- 関連リソース一覧
- 変更する宛先CIDR
- 現在Targetと変更後Target
- より具体的なRouteとの競合
- Return Path
- SG、NACL、Firewall
- メンテナンス時間と監視

## 主な影響

| 変更 | 影響例 |
|---|---|
| IGW Route削除 | Public ALB、BastionなどのInternet通信断 |
| NAT Route削除 | Private EC2の外向き通信断 |
| NAT Target変更 | 通信経路・送信元IP・AZ障害影響の変化 |
| Main Route変更 | 暗黙利用する複数Subnetへ一括影響 |
| Association変更 | Subnet内全リソースの経路変更 |
| TGW/VGW Route変更 | オンプレ・他VPC通信断 |
| S3 Endpoint Route変更 | S3アクセス経路変更・Bucket Policy影響 |

## 切り戻しに必要な情報

- 変更前Route Table JSON
- 変更前Route Target
- Route Table Association ID
- 変更前に使用していたRoute Table ID
- 変更前疎通結果
- 切り戻しコマンドと確認方法

---

## 25. 推奨するスクリーンショット証跡

| No. | ファイル名 | 画面 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント |
| 02 | `02_対象VPC確認.png` | VPC詳細 |
| 03 | `03_Subnet一覧.png` | Subnet一覧 |
| 04 | `04_Route_Table一覧.png` | Route Table一覧 |
| 05 | `05_Route_Tableルート一覧.png` | Route詳細 |
| 06 | `06_Internet_Gateway確認.png` | IGW |
| 07 | `07_NAT_Gateway一覧.png` | NAT Gateway |
| 08 | `08_Subnet_Route_Table関連付け確認.png` | Subnet Association |
| 09 | `09_Main_Route_Table確認.png` | Main Route Table |
| 10 | `10_リソース_Subnet配置確認.png` | EC2・ALB・RDS配置 |

スクリーンショットには、AWSアカウント、リージョン、VPC ID、Subnet ID、Route Table ID、確認日時を可能な範囲で含める。

---

## 26. 証跡ファイルを確認する

### 全証跡

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -print \
  | sort
```

### 空ファイル

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -size 0 \
  -print \
  | sort
```

### ファイル数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

### 証跡確認ポイント

- Caller Identity
- VPC ID、CIDR、DNS属性
- Subnet一覧とPublic IP自動割当
- Route Table一覧とRoute
- Main Route Table
- Subnet Association
- IGWとNAT Gateway
- `blackhole` Route確認結果
- リソースのSubnet配置
- CloudTrail変更履歴
- 設計書との照合結果

---

## 27. 調査結果テンプレート

```text
作業名:
VPC・Subnet・Route Table設定確認

対象AWSアカウント:
<account-id>

対象リージョン:
<region>

対象VPC:
<vpc-name / vpc-id>

確認日時:
<yyyy-mm-dd hh:mm JST>

設定変更:
なし

VPC:
CIDR:
State:
DNS Support:
DNS Hostnames:

Subnet・Route判定:
Public01:
  Route Table:
  Default Route:
  判定:

Public02:
  Route Table:
  Default Route:
  判定:

Private01:
  Route Table:
  Default Route:
  判定:

Private02:
  Route Table:
  Default Route:
  判定:

Main Route Table:
<id / routes / implicit associations>

Internet Gateway:
<id / attachment>

NAT Gateway:
<id / state / subnet>

Blackhole Route:
なし / あり

設計書との差異:
なし / あり

判断:
正常 / 要確認 / 影響あり

追加確認事項:
<内容>

証跡保存先:
<evidence-path>
```

---

## 28. Teams報告例

### 問題がない場合

```text
対象VPCのSubnetおよびRoute Table設定を確認した。

対象:
AWSアカウント <account-id>
リージョン <region>
VPC <vpc-id>

確認結果:
- Public Subnet 2つはsample-rt-publicへ明示関連付けされ、
  0.0.0.0/0はInternet Gatewayへ向いている
- Private Subnet 01はNAT Gateway 01、
  Private Subnet 02はNAT Gateway 02へ向いている
- NAT Gatewayはavailable
- blackhole Routeは確認されなかった
- リソース配置と設計書に差異は確認されなかった

設定変更は実施していない。
証跡は <evidence-path> に保存した。
```

### 要確認事項がある場合

```text
対象VPCのSubnetおよびRoute Table設定を確認した。

次の項目は要確認である。
- <Main Route Tableに想定外のDefault Routeがある>
- <SubnetがMain Route Tableを暗黙利用している>
- <NAT Gatewayがavailableではない>
- <設計書とRoute Table Associationが異なる>

Route変更は複数リソースの通信断につながる可能性があるため、
設定変更は実施していない。
対象Subnet、関連リソース、通信要件を確認後に対応要否を判断したい。
```

### `blackhole`を確認した場合

```text
対象VPCのRoute Tableにblackhole状態のRouteを確認した。

Route Table:
<route-table-id>

Destination:
<cidr>

Target:
<target>

関連Subnet:
<subnet-list>

通信影響を確認中である。
独断でRoute変更は実施せず、対象通信と切り戻し方法を整理して共有する。
```

---

## 29. よくある問題と切り分け

## 対象VPCが見つからない

- Nameタグが正しいか
- リージョンが正しいか
- VPCが作成済みか
- 別AWSアカウントではないか
- IAM権限があるか

## association.subnet-id検索が空

- SubnetがMain Route Tableを暗黙利用している可能性
- Subnet IDが正しいか
- VPCが正しいか
- Main Route Tableを確認する

## Private EC2からInternetへ接続できない

- Private SubnetのDefault RouteがNAT Gateway向きか
- NAT Gatewayが`available`か
- NAT GatewayがPublic Subnetにあるか
- Public SubnetがIGW Routeを持つか
- SG EgressとNACL
- DNS解決

## Public EC2へInternetから接続できない

- Public SubnetにIGW Routeがあるか
- EC2にPublic IPまたはElastic IPがあるか
- IGWがVPCにAttachされているか
- SG IngressとNACL
- OS FirewallとサービスListen

## VPC内通信ができない

- VPC CIDR向け`local` Route
- SG Ingress・Egress
- NACLの双方向許可
- DNS解決
- DestinationサービスのListen

## Routeが`blackhole`

- Targetが削除・切断されていないか
- NAT Gateway、TGW、Peering、VGW、ENIの状態
- 関連Subnetと影響通信
- 変更履歴

---

## 30. セキュリティ上の注意点

- Private想定SubnetにIGW Routeがないことを確認する
- Public IP自動割当とIGW Routeを組み合わせて確認する
- Main Route Table変更の影響範囲を特に注意する
- Route Table Association変更はSubnet内全リソースへ影響する
- `0.0.0.0/0`と`::/0`を確認する
- `blackhole` Routeを放置しない
- 閉域環境ではTGW、VGW、Firewall、プロキシ経路を確認する
- Routeだけで安全性や疎通可否を断定しない
- 証跡にVPC ID、Subnet ID、Public IP、構成情報が含まれる
- 実案件では承認、影響調査、疎通試験、切り戻しを準備する

---

## 31. 案件で説明できるポイント

### Public／Private判定

```text
Subnet名やTypeタグだけではなく、
実際に使用されるRoute TableとDefault Routeを確認して
Public／Privateを判定した。

0.0.0.0/0がInternet Gateway向きならPublic候補、
NAT Gateway向きまたは外部向けRouteなしならPrivate候補として整理した。
```

### Main Route Table

```text
Subnetに明示的なRoute Table関連付けがない場合は、
Main Route Tableを暗黙的に使用する。

association.subnet-id検索が空でもRoute Table未設定とは判断せず、
Main Route TableのRouteと影響Subnetを確認した。
```

### 通信経路

```text
InternetからWebアプリケーションはIGW、Public ALB、
Private Web EC2の順に到達する。

Private Web EC2の外向き通信はPrivate Route Table、
同一AZのNAT Gateway、IGWを経由する。

Web EC2からRDSなどのVPC内通信はlocal Routeを使用する。
```

### 安全な変更

```text
Route変更はSubnet内の複数リソースへ通信断を発生させる可能性がある。

対象Route Table、関連Subnet、関連リソース、現在Route、
Return Path、疎通試験、切り戻しを整理してから変更する。
```

---

## 32. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| VPC | AWS上の論理ネットワーク |
| Subnet | AZ単位のIPアドレス範囲 |
| Route Table | Subnetの通信経路を決める |
| Main Route Table | 明示関連付けがないSubnetで使用される |
| Local Route | VPC内通信 |
| Internet Gateway | Public IPv4・IPv6 Internet通信 |
| NAT Gateway | Private IPv4リソースの外向き通信 |
| Egress-only IGW | IPv6の外向きInternet通信 |
| Public Subnet | IGW向けRouteを持つSubnet |
| Private Subnet | IGWへの直接Routeを持たないSubnet |
| Longest Prefix Match | 最も具体的なRouteが選択される |
| Blackhole Route | Targetが利用できないRoute |
| Public IP | IGW経由の直接IPv4通信に必要 |
| Route Table Association | Subnetが使用するRoute Tableとの関連付け |

---

## 33. 要確認事項

実案件で同様の確認を行う場合は、次を確認する。

- 正式な対象AWSアカウント、リージョン、VPC ID
- VPC、Subnet、Route Tableの設計書
- Public／Private／閉域Subnetの正式な定義
- Main Route Table利用方針
- Shared VPCの所有者・利用者アカウント
- IPv6利用有無
- Transit Gateway、VPN、Direct Connect、Firewall経路
- NAT GatewayのAZ冗長化方針
- VPC Endpoint利用状況
- Route変更時の疎通試験項目
- 監視、Flow Logs、CloudTrailの保存先
- 変更承認者、作業時間、切り戻し条件

不明な項目は合理的に推測して設定変更せず、未確認事項として手順書と報告へ残す。

---

## 34. Day 10完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] 対象VPCを一意に特定した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] VPC CIDR、State、Owner、Default VPC有無を確認した
- [ ] VPC DNS SupportとDNS Hostnamesを確認した
- [ ] VPC内Subnet一覧を確認した
- [ ] SubnetのCIDR、AZ、Public IP自動割当を確認した
- [ ] 各Subnet IDを取得した
- [ ] Route Table一覧とRouteを確認した
- [ ] Main Route Tableを確認した
- [ ] 各Subnetの明示関連付けを確認した
- [ ] 明示関連付けがない場合のMain Route Table利用を理解した
- [ ] IPv4デフォルトルートを横断確認した
- [ ] IPv6デフォルトルートの有無を確認した
- [ ] Public／PrivateをRoute Tableから判定した
- [ ] Internet GatewayとVPC Attachを確認した
- [ ] NAT GatewayのState、Subnet、Elastic IPを確認した
- [ ] `blackhole` Routeの有無を確認した
- [ ] EC2、ALB、RDSのSubnet配置を確認した
- [ ] 設計書と実環境を照合した
- [ ] CloudTrailでRoute関連変更履歴を確認した
- [ ] Route変更時の影響範囲と切り戻し情報を整理した
- [ ] 証跡ファイルと空ファイルを確認した
- [ ] Teams報告文を作成した
- [ ] 設定変更を実施していないことを確認した

## Day 10の完了条件

次を自分の言葉で説明できればDay 10は完了とする。

```text
Public／Private Subnetは名前やタグだけではなく、
Subnetが使用するRoute TableとDefault Routeから判定する。

0.0.0.0/0がInternet Gatewayへ向くSubnetはPublic候補であり、
NAT Gatewayへ向く、またはInternet Gatewayへの直接Routeを持たない
SubnetはPrivate候補である。

Subnetに明示的なRoute Table関連付けがない場合は、
Main Route Tableを暗黙的に使用するため、
Main Route TableのRouteと影響Subnetも必ず確認する。

Route変更はSubnet内の複数リソースへ影響するため、
対象Route、関連Subnet、関連リソース、通信要件、
疎通試験、Return Path、切り戻しを整理してから実施する。
```
