#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Route Table設定で参照する各リソースのNameタグ。
# これまでの手順で作成したVPC、IGW、NAT Gateway、Subnetを名前で探す。
VPC_NAME="sample-vpc"
IGW_NAME="sample-igw"
NGW01_NAME="sample-ngw-01"
NGW02_NAME="sample-ngw-02"
PUB01_NAME="sample-subnet-public01"
PUB02_NAME="sample-subnet-public02"
PRI01_NAME="sample-subnet-private01"
PRI02_NAME="sample-subnet-private02"

# 作成または再利用するRoute TableのNameタグ。
# 再実行時はこのNameタグとVPC IDで既存Route Tableを探し、重複作成を防ぐ。
RT_PUB_NAME="sample-rt-public"
RT_PRI01_NAME="sample-rt-private01"
RT_PRI02_NAME="sample-rt-private02"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
# Route Tableは前段のリソースに依存するため、ID取得漏れを早めに検知する。
get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}

# 検索結果が1件だけであることを確認するための関数。
# 0件なら前提不足、2件以上なら誤変更の危険があるため停止する。
require_single_match() {
  local label="$1"
  local count="$2"

  if [ "$count" -eq 0 ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  elif [ "$count" -gt 1 ]; then
    echo "Error: multiple resources found for $label. Please investigate duplicates before changing routes."
    exit 1
  fi
}

# Route Tableを作成または再利用するための関数。
# 同じVPC内に同じNameタグのRoute Tableがあれば、それを使う。
# 案件作業では、再実行や途中失敗後のリカバリで重複Route Tableを作らないことが重要。
ensure_route_table() {
  local route_table_name="$1"
  local route_table_count
  local route_table_id

  route_table_count=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$route_table_name" \
    --query 'length(RouteTables)' \
    --output text)

  if [ "$route_table_count" -gt 1 ]; then
    echo "Error: multiple Route Tables found for $route_table_name in $VPC_ID. Please investigate duplicates before changing routes." >&2
    exit 1
  fi

  route_table_id=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$route_table_name" \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

  if [ "$route_table_id" != "None" ] && [ -n "$route_table_id" ]; then
    echo "Route Table already exists: $route_table_name ($route_table_id)" >&2
    echo "$route_table_id"
    return
  fi

  echo "Creating Route Table: $route_table_name" >&2

  route_table_id=$(aws ec2 create-route-table \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$route_table_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

  echo "$route_table_id"
}

# 0.0.0.0/0 のルートを作成または更新するための関数。
# 既に期待通りの向き先であれば何もしない。
# ルートは通信経路そのものなので、向き先が違う場合は明示的にreplace-routeで修正する。
ensure_default_route() {
  local route_table_id="$1"
  local target_type="$2"
  local target_id="$3"
  local label="$4"
  local existing_route_count
  local existing_target

  existing_route_count=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --route-table-ids "$route_table_id" \
    --query 'length(RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`])' \
    --output text)

  if [ "$target_type" = "igw" ]; then
    existing_target=$(aws ec2 describe-route-tables \
      --profile "$PROFILE" \
      --region "$REGION" \
      --route-table-ids "$route_table_id" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0]' \
      --output text)

    if [ "$existing_target" = "$target_id" ]; then
      echo "$label default route already points to IGW: $target_id"
    elif [ "$existing_route_count" = "0" ]; then
      echo "Creating $label default route: 0.0.0.0/0 -> $target_id"
      aws ec2 create-route \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-id "$route_table_id" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$target_id" >/dev/null
    else
      # 0.0.0.0/0 が既に存在するが、期待するIGWではない場合は置き換える。
      # たとえば誤ってNAT Gatewayに向いている場合も、この分岐で修正する。
      echo "Replacing $label default route: 0.0.0.0/0 -> $target_id"
      aws ec2 replace-route \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-id "$route_table_id" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$target_id"
    fi
  elif [ "$target_type" = "nat" ]; then
    existing_target=$(aws ec2 describe-route-tables \
      --profile "$PROFILE" \
      --region "$REGION" \
      --route-table-ids "$route_table_id" \
      --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]' \
      --output text)

    if [ "$existing_target" = "$target_id" ]; then
      echo "$label default route already points to NAT Gateway: $target_id"
    elif [ "$existing_route_count" = "0" ]; then
      echo "Creating $label default route: 0.0.0.0/0 -> $target_id"
      aws ec2 create-route \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-id "$route_table_id" \
        --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$target_id" >/dev/null
    else
      # 0.0.0.0/0 が既に存在するが、期待するNAT Gatewayではない場合は置き換える。
      # Route Table変更では通信断に直結するため、向き先の差分を明示して修正する。
      echo "Replacing $label default route: 0.0.0.0/0 -> $target_id"
      aws ec2 replace-route \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-id "$route_table_id" \
        --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$target_id"
    fi
  else
    echo "Error: unknown route target type: $target_type"
    exit 1
  fi
}

# SubnetとRoute Tableの関連付けを作成または更新するための関数。
# 既に期待通りの関連付けであれば何もしない。
# 別Route Tableに関連付いている場合は、replace-route-table-associationで差し替える。
ensure_route_table_association() {
  local subnet_id="$1"
  local route_table_id="$2"
  local label="$3"
  local current_route_table_id
  local association_id

  current_route_table_id=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=association.subnet-id,Values="$subnet_id" \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

  association_id=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=association.subnet-id,Values="$subnet_id" \
    --query "RouteTables[0].Associations[?SubnetId=='$subnet_id'].RouteTableAssociationId|[0]" \
    --output text)

  if [ "$current_route_table_id" = "$route_table_id" ]; then
    echo "$label is already associated with Route Table: $route_table_id"
  elif [ "$association_id" != "None" ] && [ -n "$association_id" ]; then
    echo "Replacing $label Route Table association: $association_id -> $route_table_id"
    aws ec2 replace-route-table-association \
      --profile "$PROFILE" \
      --region "$REGION" \
      --association-id "$association_id" \
      --route-table-id "$route_table_id" >/dev/null
  else
    echo "Associating $label with Route Table: $route_table_id"
    aws ec2 associate-route-table \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-id "$subnet_id" \
      --route-table-id "$route_table_id" >/dev/null
  fi
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 想定外のアカウントにリソースを作らないための確認。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="

# VPC IDを取得する。
# Route TableはVPCに作成するため、VPC IDが必要。
# 同じNameタグのVPCが複数ある場合、先頭を自動選択すると誤変更につながる。
# そのため、対象VPCが1つだけであることを確認してからVPC IDを取得する。
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text)

if [ "$VPC_COUNT" -eq 0 ]; then
  echo "Error: VPC not found. Please run 01_vpc_setup.sh first."
  exit 1
elif [ "$VPC_COUNT" -gt 1 ]; then
  echo "Error: multiple VPCs found with Name tag $VPC_NAME. Please remove duplicates or specify the target VPC explicitly."
  exit 1
fi

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
VPC_ID=$(get_required_id "VPC" "$VPC_ID")

# Internet Gateway IDを取得する。
# Public Subnet用Route Tableのデフォルトルートに設定する。
# Nameタグだけで探すと、別VPCに同名IGWがある場合に誤取得する可能性がある。
# attachment.vpc-id でも絞り込み、対象VPCに接続済みのIGWだけを取得する。
IGW_COUNT=$(aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$IGW_NAME" \
  --query 'length(InternetGateways)' \
  --output text)
require_single_match "Internet Gateway" "$IGW_COUNT"

IGW_ID=$(aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$IGW_NAME" \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)
IGW_ID=$(get_required_id "Internet Gateway" "$IGW_ID")

# NAT Gateway 01のIDを取得する。
# available 状態のものだけを対象にする。
# Private Subnet 01の外向き通信に使う。
# NAT GatewayもVPC IDで絞り込み、別VPCの同名NAT Gatewayを使わないようにする。
NGW01_COUNT=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$NGW01_NAME" Name=state,Values=available \
  --query 'length(NatGateways)' \
  --output text)
require_single_match "NAT Gateway 01" "$NGW01_COUNT"

NGW01_ID=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$NGW01_NAME" Name=state,Values=available \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)
NGW01_ID=$(get_required_id "NAT Gateway 01" "$NGW01_ID")

# NAT Gateway 02のIDを取得する。
# Private Subnet 02の外向き通信に使う。
# こちらもVPC IDで絞り込み、対象VPC内のNAT Gatewayだけを取得する。
NGW02_COUNT=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$NGW02_NAME" Name=state,Values=available \
  --query 'length(NatGateways)' \
  --output text)
require_single_match "NAT Gateway 02" "$NGW02_COUNT"

NGW02_ID=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$NGW02_NAME" Name=state,Values=available \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)
NGW02_ID=$(get_required_id "NAT Gateway 02" "$NGW02_ID")

# Public Subnet 01のIDを取得する。
# Public用Route Tableに関連付ける。
# SubnetはNameタグだけでなくVPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
PUB01_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB01_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Public Subnet 01" "$PUB01_COUNT"

PUB01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PUB01_ID=$(get_required_id "Public Subnet 01" "$PUB01_ID")

# Public Subnet 02のIDを取得する。
# Public用Route Tableに関連付ける。
PUB02_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB02_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Public Subnet 02" "$PUB02_COUNT"

PUB02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PUB02_ID=$(get_required_id "Public Subnet 02" "$PUB02_ID")

# Private Subnet 01のIDを取得する。
# Private用Route Table 01に関連付ける。
PRI01_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRI01_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 01" "$PRI01_COUNT"

PRI01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRI01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI01_ID=$(get_required_id "Private Subnet 01" "$PRI01_ID")

# Private Subnet 02のIDを取得する。
# Private用Route Table 02に関連付ける。
PRI02_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRI02_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 02" "$PRI02_COUNT"

PRI02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRI02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI02_ID=$(get_required_id "Private Subnet 02" "$PRI02_ID")

# 取得したIDを一覧表示する。
# 後続処理の対象が正しいか確認しやすくするため。
echo "VPC: $VPC_ID"
echo "IGW: $IGW_ID"
echo "NGW01: $NGW01_ID"
echo "NGW02: $NGW02_ID"
echo "Public Subnets: $PUB01_ID, $PUB02_ID"
echo "Private Subnets: $PRI01_ID, $PRI02_ID"

echo "=== Configure Public Route Table ==="

# Public Subnet用のRoute Tableを作成または再利用する。
# 既に存在する場合は新規作成せず、同じRoute Tableにルートと関連付けを設定する。
RT_PUB_ID=$(ensure_route_table "$RT_PUB_NAME")

# 0.0.0.0/0 は「VPC内ではない全ての宛先」を意味する。
# Public Subnetでは、この通信をInternet Gatewayへ向ける。
ensure_default_route "$RT_PUB_ID" "igw" "$IGW_ID" "Public Route Table"

# Public Subnet 01にPublic用Route Tableを関連付ける。
ensure_route_table_association "$PUB01_ID" "$RT_PUB_ID" "Public Subnet 01"

# Public Subnet 02にも同じPublic用Route Tableを関連付ける。
ensure_route_table_association "$PUB02_ID" "$RT_PUB_ID" "Public Subnet 02"

echo "Public Route Table: $RT_PUB_ID"

echo "=== Configure Private Route Table 01 ==="

# Private Subnet 01用のRoute Tableを作成または再利用する。
# Private Subnetから外へ出る通信は、NAT Gateway 01へ向ける。
RT_PRI01_ID=$(ensure_route_table "$RT_PRI01_NAME")

# Private Subnet 01の外向き通信をNAT Gateway 01へ向ける。
# これにより、Private Subnet内のEC2はPublic IPなしでインターネットへ出られる。
ensure_default_route "$RT_PRI01_ID" "nat" "$NGW01_ID" "Private Route Table 01"

# Private Subnet 01にPrivate用Route Table 01を関連付ける。
ensure_route_table_association "$PRI01_ID" "$RT_PRI01_ID" "Private Subnet 01"

echo "Private Route Table 01: $RT_PRI01_ID"

echo "=== Configure Private Route Table 02 ==="

# Private Subnet 02用のRoute Tableを作成または再利用する。
# こちらはNAT Gateway 02へ向ける。
RT_PRI02_ID=$(ensure_route_table "$RT_PRI02_NAME")

# Private Subnet 02の外向き通信をNAT Gateway 02へ向ける。
ensure_default_route "$RT_PRI02_ID" "nat" "$NGW02_ID" "Private Route Table 02"

# Private Subnet 02にPrivate用Route Table 02を関連付ける。
ensure_route_table_association "$PRI02_ID" "$RT_PRI02_ID" "Private Subnet 02"

echo "Private Route Table 02: $RT_PRI02_ID"

echo "All Route Tables configured and associated."

echo "=== Describe Route Tables ==="

# VPC内のRoute Tableを確認する。
# Public用はIGW、Private用はNAT Gatewayへ 0.0.0.0/0 が向いているか確認する。
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,AssociatedSubnets:Associations[?SubnetId!=`null`].SubnetId,IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0],NGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]}' \
  --output table
