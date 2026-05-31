#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# NAT Gatewayを作成する対象VPCのNameタグ。
# Public Subnet検索時にVPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
VPC_NAME="sample-vpc"

# NAT Gatewayを配置するPublic SubnetのNameタグ。
# NAT GatewayはPrivate Subnetではなく、Public Subnetに作成する。
PUBLIC_SUBNET_01_NAME="sample-subnet-public01"
PUBLIC_SUBNET_02_NAME="sample-subnet-public02"

# 作成するNAT GatewayのNameタグ。
# 再実行時はこのNameタグとVPC IDを使って既存NAT Gatewayを確認する。
NAT_GATEWAY_01_NAME="sample-ngw-01"
NAT_GATEWAY_02_NAME="sample-ngw-02"

# NAT Gatewayに割り当てるElastic IPのNameタグ。
# 前回実行がEIP確保後に失敗した場合でも、同じNameタグの未使用EIPを再利用する。
EIP_01_NAME="sample-eip-ngw-01"
EIP_02_NAME="sample-eip-ngw-02"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
# 前提リソースがないまま処理を続けると、原因が分かりにくいエラーになるため早めに止める。
get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}

# VPC内のSubnetをNameタグで1つだけ取得するための関数。
# 同じNameタグのSubnetが複数ある場合は、誤配置を避けるため停止する。
get_single_subnet_id() {
  local subnet_name="$1"
  local subnet_count
  local subnet_id

  subnet_count=$(aws ec2 describe-subnets \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
    --query 'length(Subnets)' \
    --output text)

  if [ "$subnet_count" -eq 0 ]; then
    echo "Error: subnet not found: $subnet_name. Please run 02_subnet_setup.sh first." >&2
    exit 1
  elif [ "$subnet_count" -gt 1 ]; then
    echo "Error: multiple subnets found for $subnet_name in $VPC_ID. Please investigate duplicates before continuing." >&2
    exit 1
  fi

  subnet_id=$(aws ec2 describe-subnets \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
    --query 'Subnets[0].SubnetId' \
    --output text)

  get_required_id "$subnet_name" "$subnet_id"
}

# NAT Gatewayを作成または再利用するための関数。
# 既にpendingまたはavailableのNAT Gatewayがある場合は新規作成しない。
# 途中失敗で未使用EIPだけ残っている場合は、そのEIPを再利用して余計な課金リソースを増やさない。
ensure_nat_gateway() {
  local nat_gateway_name="$1"
  local subnet_id="$2"
  local eip_name="$3"
  local nat_gateway_count
  local nat_gateway_id
  local eip_count
  local allocation_id
  local association_id

  nat_gateway_count=$(aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$nat_gateway_name" Name=state,Values=pending,available \
    --query 'length(NatGateways)' \
    --output text)

  if [ "$nat_gateway_count" -gt 1 ]; then
    echo "Error: multiple NAT Gateways found for $nat_gateway_name in $VPC_ID. Please investigate duplicates before continuing." >&2
    exit 1
  elif [ "$nat_gateway_count" -eq 1 ]; then
    nat_gateway_id=$(aws ec2 describe-nat-gateways \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$nat_gateway_name" Name=state,Values=pending,available \
      --query 'NatGateways[0].NatGatewayId' \
      --output text)

    echo "NAT Gateway already exists: $nat_gateway_name ($nat_gateway_id)" >&2
    echo "$nat_gateway_id"
    return
  fi

  eip_count=$(aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=tag:Name,Values="$eip_name" \
    --query 'length(Addresses)' \
    --output text)

  if [ "$eip_count" -gt 1 ]; then
    echo "Error: multiple Elastic IPs found with Name tag $eip_name. Please investigate duplicates before continuing." >&2
    exit 1
  elif [ "$eip_count" -eq 1 ]; then
    allocation_id=$(aws ec2 describe-addresses \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=tag:Name,Values="$eip_name" \
      --query 'Addresses[0].AllocationId' \
      --output text)

    association_id=$(aws ec2 describe-addresses \
      --profile "$PROFILE" \
      --region "$REGION" \
      --allocation-ids "$allocation_id" \
      --query 'Addresses[0].AssociationId' \
      --output text)

    if [ "$association_id" != "None" ] && [ -n "$association_id" ]; then
      echo "Error: Elastic IP $allocation_id is already associated: $association_id" >&2
      exit 1
    fi

    echo "Reusing unassociated Elastic IP for $nat_gateway_name: $allocation_id" >&2
  else
    echo "Allocating Elastic IP for $nat_gateway_name" >&2

    allocation_id=$(aws ec2 allocate-address \
      --profile "$PROFILE" \
      --region "$REGION" \
      --domain vpc \
      --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$eip_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
      --query 'AllocationId' \
      --output text)
  fi

  echo "Creating NAT Gateway: $nat_gateway_name" >&2

  nat_gateway_id=$(aws ec2 create-nat-gateway \
    --profile "$PROFILE" \
    --region "$REGION" \
    --subnet-id "$subnet_id" \
    --allocation-id "$allocation_id" \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$nat_gateway_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

  echo "$nat_gateway_id"
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# NAT Gatewayは課金対象なので、作成前に操作先アカウントを必ず確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# SubnetをNameタグだけで検索すると、別VPCに同名Subnetがある場合に誤取得する可能性がある。
# そのため、後続のSubnet検索ではこのVPC IDでも絞り込む。
# 同じNameタグのVPCが複数ある場合は、先頭を自動選択せず停止する。
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
  echo "Error: multiple VPCs found with Name tag $VPC_NAME. Please clean up duplicates before continuing."
  exit 1
fi

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
VPC_ID=$(get_required_id "VPC" "$VPC_ID")

echo "Target VPC ID: $VPC_ID"

echo "=== Get Public Subnet IDs ==="

# 1つ目のPublic Subnet IDを取得する。
# NAT Gateway 01はこのサブネットに配置する。
# NameタグだけではなくVPC IDでも絞り込み、対象VPC内のPublic Subnetだけを取得する。
PUB01_ID=$(get_single_subnet_id "$PUBLIC_SUBNET_01_NAME")

# 2つ目のPublic Subnet IDを取得する。
# NAT Gateway 02はこのサブネットに配置する。
# こちらもVPC IDで絞り込み、別VPCの同名Subnetを使わないようにする。
PUB02_ID=$(get_single_subnet_id "$PUBLIC_SUBNET_02_NAME")

echo "Public Subnet 01: $PUB01_ID"
echo "Public Subnet 02: $PUB02_ID"

echo "=== Configure NAT Gateway 01 ==="

# NAT Gateway 01を作成または再利用する。
# 途中失敗で未使用EIPだけ残っている場合は、そのEIPを再利用する。
NGW01_ID=$(ensure_nat_gateway "$NAT_GATEWAY_01_NAME" "$PUB01_ID" "$EIP_01_NAME")

echo "NAT Gateway 01: $NGW01_ID"

echo "=== Configure NAT Gateway 02 ==="

# NAT Gateway 02を作成または再利用する。
# 2つのAZに分けてNAT Gatewayを作ることで、AZごとの経路を分けられる。
NGW02_ID=$(ensure_nat_gateway "$NAT_GATEWAY_02_NAME" "$PUB02_ID" "$EIP_02_NAME")

echo "NAT Gateway 02: $NGW02_ID"

echo "=== Wait for NAT Gateways to become available ==="

# NAT Gatewayは作成直後すぐに利用できるとは限らない。
# available になる前にRoute Tableへ設定すると失敗することがあるため、ここで待つ。
aws ec2 wait nat-gateway-available \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID"

echo "NAT Gateways are available."

echo "=== Describe NAT Gateways ==="

# 作成したNAT Gatewayの状態を確認する。
# Stateが available で、Public IPとAllocationIdが表示されていれば作成できている。
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID" \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
