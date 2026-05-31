#!/bin/bash
set -euo pipefail

# /Users/nobu/aws-reference/scripts 直下の 01 〜 04 の作成系スクリプトで
# 作成したネットワークリソースを削除する。
#
# 対象スクリプト:
# - 01_vpc_setup.sh
# - 02_subnet_setup.sh
# - 03_internetgateway_setup.sh
# - 04_nat_gateway_setup.sh
#
# 削除対象:
# - NAT Gateway
# - NAT Gateway用Elastic IP
# - Internet Gateway
# - Subnet
# - VPC
#
# 削除順:
# 1. NAT Gatewayを削除する
# 2. NAT Gatewayがdeletedになるまで待つ
# 3. Elastic IPを解放する
# 4. Internet GatewayをVPCからdetachして削除する
# 5. Subnetを削除する
# 6. VPCを削除する
#
# 注意:
# - NAT GatewayとElastic IPは課金対象である。
# - このスクリプトは実AWSリソースを削除する。
# - 実行前にCaller Identityと対象VPCを必ず確認する。
# - Route Table、EC2、ALB、RDSなど、05以降で作成する予定のリソースは対象外である。

# 使用するAWS CLIプロファイルとリージョン。
PROFILE="learning"
REGION="ap-northeast-1"

# 削除対象のVPC名。
VPC_NAME="sample-vpc"

# 削除対象のSubnet名。
SUBNET_NAMES=(
  "sample-subnet-public01"
  "sample-subnet-public02"
  "sample-subnet-private01"
  "sample-subnet-private02"
)

# 削除対象のNAT Gateway名。
NAT_GATEWAY_NAMES=(
  "sample-ngw-01"
  "sample-ngw-02"
)

# 削除対象のNAT Gateway用Elastic IP名。
EIP_NAMES=(
  "sample-eip-ngw-01"
  "sample-eip-ngw-02"
)

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで削除を行うため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "================================================"
echo "Cleanup network resources created by 01-04 scripts."
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "VPC Name: $VPC_NAME"
echo "================================================"

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 削除系コマンドを実行する前に、想定したアカウントか必ず確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Confirmation ==="

# 誤操作を避けるため、明示的な入力がない限り削除しない。
# 自動実行したい場合は、SKIP_CONFIRM=true を付けて実行する。
if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  read -r -p "Type 'delete' to delete network resources in $VPC_NAME: " CONFIRM

  if [ "$CONFIRM" != "delete" ]; then
    echo "Canceled."
    exit 0
  fi
fi

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# VPCがない場合でも、タグ付きElastic IPだけ残っている可能性があるため、
# 後続のElastic IP確認はVPC有無に関係なく実行する。
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  VPC_ID=""
  echo "VPC not found. VPC-related resources may already be deleted."
else
  echo "Target VPC ID: $VPC_ID"
fi

echo "=== Collect Elastic IP Allocation IDs ==="

# NAT Gateway削除後にElastic IPを解放するため、先にAllocation IDを控える。
# NAT Gatewayに紐づくEIPと、Nameタグが残っているEIPの両方を候補にする。
EIP_ALLOC_IDS=""

if [ -n "$VPC_ID" ]; then
  NAT_EIP_ALLOC_IDS=$(aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filter Name=vpc-id,Values="$VPC_ID" Name=state,Values=pending,available \
    --query 'NatGateways[].NatGatewayAddresses[].AllocationId' \
    --output text)

  EIP_ALLOC_IDS="$EIP_ALLOC_IDS $NAT_EIP_ALLOC_IDS"
fi

for eip_name in "${EIP_NAMES[@]}"; do
  TAGGED_ALLOC_IDS=$(aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=tag:Name,Values="$eip_name" \
    --query 'Addresses[].AllocationId' \
    --output text)

  EIP_ALLOC_IDS="$EIP_ALLOC_IDS $TAGGED_ALLOC_IDS"
done

# 重複したAllocation IDを削除する。
EIP_ALLOC_IDS=$(echo "$EIP_ALLOC_IDS" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')

if [ -n "$EIP_ALLOC_IDS" ]; then
  echo "Elastic IP Allocation IDs: $EIP_ALLOC_IDS"
else
  echo "No Elastic IP Allocation IDs found."
fi

echo "=== Delete NAT Gateways ==="

# NAT GatewayはSubnetやElastic IPに依存するため、先に削除する。
# pending / available のNAT Gatewayを削除対象とする。
# deleted 状態のNAT Gatewayは削除済み履歴として表示されることがあるため、対象外にする。
NAT_GATEWAY_IDS=""

if [ -n "$VPC_ID" ]; then
  for nat_gateway_name in "${NAT_GATEWAY_NAMES[@]}"; do
    FOUND_NAT_IDS=$(aws ec2 describe-nat-gateways \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$nat_gateway_name" Name=state,Values=pending,available \
      --query 'NatGateways[].NatGatewayId' \
      --output text)

    NAT_GATEWAY_IDS="$NAT_GATEWAY_IDS $FOUND_NAT_IDS"
  done

  NAT_GATEWAY_IDS=$(echo "$NAT_GATEWAY_IDS" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')

  if [ -n "$NAT_GATEWAY_IDS" ]; then
    for nat_gateway_id in $NAT_GATEWAY_IDS; do
      echo "Deleting NAT Gateway: $nat_gateway_id"
      aws ec2 delete-nat-gateway \
        --profile "$PROFILE" \
        --region "$REGION" \
        --nat-gateway-id "$nat_gateway_id" >/dev/null
    done

    echo "Waiting for NAT Gateways to be deleted..."
    aws ec2 wait nat-gateway-deleted \
      --profile "$PROFILE" \
      --region "$REGION" \
      --nat-gateway-ids $NAT_GATEWAY_IDS
  else
    echo "No NAT Gateways found."
  fi
else
  echo "Skip NAT Gateway deletion because VPC was not found."
fi

echo "=== Release Elastic IPs ==="

# NAT Gateway削除後にElastic IPを解放する。
# NAT Gatewayが削除される前はEIPが関連付いたままになるため、
# 必ずNAT Gateway deleted待機後にrelease-addressを実行する。
if [ -n "$EIP_ALLOC_IDS" ]; then
  for allocation_id in $EIP_ALLOC_IDS; do
    ASSOCIATION_ID=$(aws ec2 describe-addresses \
      --profile "$PROFILE" \
      --region "$REGION" \
      --allocation-ids "$allocation_id" \
      --query 'Addresses[0].AssociationId' \
      --output text 2>/dev/null || true)

    if [ "$ASSOCIATION_ID" != "None" ] && [ -n "$ASSOCIATION_ID" ]; then
      echo "Skip releasing associated EIP: $allocation_id ($ASSOCIATION_ID)"
      continue
    fi

    echo "Releasing Elastic IP: $allocation_id"
    aws ec2 release-address \
      --profile "$PROFILE" \
      --region "$REGION" \
      --allocation-id "$allocation_id" || echo "Skip: could not release $allocation_id"
  done
else
  echo "No Elastic IPs to release."
fi

echo "=== Detach and Delete Internet Gateway ==="

# Internet GatewayはVPCにアタッチされたままでは削除できない。
# 先にdetachし、その後deleteする。
if [ -n "$VPC_ID" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=attachment.vpc-id,Values="$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)

  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    echo "Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID" \
      --vpc-id "$VPC_ID"

    echo "Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID"
  else
    echo "No Internet Gateway attached to VPC."
  fi
else
  echo "Skip Internet Gateway deletion because VPC was not found."
fi

echo "=== Delete Subnets ==="

# Subnetは、NAT Gatewayなどの依存リソースが残っていると削除できない。
# ここまででNAT GatewayとInternet Gatewayを削除した後、Nameタグで対象Subnetだけ削除する。
if [ -n "$VPC_ID" ]; then
  for subnet_name in "${SUBNET_NAMES[@]}"; do
    SUBNET_ID=$(aws ec2 describe-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
      --query 'Subnets[0].SubnetId' \
      --output text)

    if [ "$SUBNET_ID" != "None" ] && [ -n "$SUBNET_ID" ]; then
      echo "Deleting Subnet: $subnet_name ($SUBNET_ID)"
      aws ec2 delete-subnet \
        --profile "$PROFILE" \
        --region "$REGION" \
        --subnet-id "$SUBNET_ID"
    else
      echo "Subnet not found: $subnet_name"
    fi
  done
else
  echo "Skip Subnet deletion because VPC was not found."
fi

echo "=== Delete VPC ==="

# SubnetやInternet Gatewayなどの依存リソースを削除した後、最後にVPCを削除する。
# default Security Group、default Network ACL、Main Route TableはVPC削除時に一緒に削除される。
if [ -n "$VPC_ID" ]; then
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-id "$VPC_ID"
else
  echo "Skip VPC deletion because VPC was not found."
fi

echo "=== Cleanup Verification ==="

# 削除後の残存確認を行う。
# 空の表またはNoneであれば、01〜04で作成した主なリソースは削除されている。
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table

aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[?State!=`deleted`].{ID:NatGatewayId,Name:Tags[?Key==`Name`].Value|[0],State:State,VpcId:VpcId}' \
  --output table

aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "================================================"
echo "Network cleanup completed."
echo "================================================"
