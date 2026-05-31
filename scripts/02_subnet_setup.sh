#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# サブネットを作成する対象VPCのNameタグ。
# 前の手順 01_vpc_setup.sh で作成したVPCを名前で探す。
VPC_NAME="sample-vpc"

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

# Subnetを作成または再利用するための関数。
# 同じVPC内に同じNameタグのSubnetがあれば、それを使う。
# 再実行時に同じCIDRのSubnetを重複作成しないことが目的である。
ensure_subnet() {
  local subnet_name="$1"
  local cidr_block="$2"
  local availability_zone="$3"
  local subnet_type="$4"
  local map_public_ip="$5"
  local subnet_count
  local subnet_id
  local existing_cidr
  local existing_az

  subnet_count=$(aws ec2 describe-subnets \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
    --query 'length(Subnets)' \
    --output text)

  if [ "$subnet_count" -gt 1 ]; then
    echo "Error: multiple subnets found for $subnet_name in $VPC_ID. Please investigate duplicates before continuing." >&2
    exit 1
  elif [ "$subnet_count" -eq 1 ]; then
    subnet_id=$(aws ec2 describe-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
      --query 'Subnets[0].SubnetId' \
      --output text)

    existing_cidr=$(aws ec2 describe-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-ids "$subnet_id" \
      --query 'Subnets[0].CidrBlock' \
      --output text)

    existing_az=$(aws ec2 describe-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-ids "$subnet_id" \
      --query 'Subnets[0].AvailabilityZone' \
      --output text)

    if [ "$existing_cidr" != "$cidr_block" ]; then
      echo "Error: $subnet_name CIDR is $existing_cidr, expected $cidr_block." >&2
      exit 1
    fi

    if [ "$existing_az" != "$availability_zone" ]; then
      echo "Error: $subnet_name AZ is $existing_az, expected $availability_zone." >&2
      exit 1
    fi

    echo "Subnet already exists: $subnet_name ($subnet_id)" >&2
  else
    echo "Creating Subnet: $subnet_name" >&2

    subnet_id=$(aws ec2 create-subnet \
      --profile "$PROFILE" \
      --region "$REGION" \
      --vpc-id "$VPC_ID" \
      --cidr-block "$cidr_block" \
      --availability-zone "$availability_zone" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=$subnet_type}]" \
      --query 'Subnet.SubnetId' \
      --output text)
  fi

  # 既存Subnetを再利用する場合も、学習環境として期待するタグにそろえる。
  # タグは同じ値を再適用しても安全で、後続スクリプトの検索条件にも使う。
  aws ec2 create-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resources "$subnet_id" \
    --tags Key=Name,Value="$subnet_name" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning Key=Type,Value="$subnet_type"

  if [ "$map_public_ip" = "true" ]; then
    # Public Subnetでは、EC2起動時にPublic IPを自動割り当てする設定にする。
    # 既に有効でも再適用できるため、再実行時も安全に実行する。
    aws ec2 modify-subnet-attribute \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-id "$subnet_id" \
      --map-public-ip-on-launch
  else
    # Private Subnetでは、Public IP自動割り当てを無効化する。
    # 誤って有効化されていた場合の修正にもなる。
    aws ec2 modify-subnet-attribute \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-id "$subnet_id" \
      --no-map-public-ip-on-launch
  fi

  echo "$subnet_id"
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 想定外のアカウントにリソースを作らないための確認。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# サブネット作成にはVPC IDが必要。
# 同じNameタグのVPCが複数ある場合、先頭を自動選択すると誤作業につながる。
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

echo "=== Configure Public Subnet 01 ==="

# 1つ目のPublic Subnetを作成または再利用する。
# Public Subnetは、後でInternet Gatewayへのルートを設定して外部公開用に使う。
PUB01_ID=$(ensure_subnet "sample-subnet-public01" "10.0.0.0/20" "ap-northeast-1a" "public" "true")

echo "=== Configure Public Subnet 02 ==="

# 2つ目のPublic Subnetを作成または再利用する。
# AZを分けることで、ALBなど複数AZが必要なサービスに対応できる。
PUB02_ID=$(ensure_subnet "sample-subnet-public02" "10.0.16.0/20" "ap-northeast-1c" "public" "true")

echo "=== Configure Private Subnet 01 ==="

# 1つ目のPrivate Subnetを作成または再利用する。
# Private Subnetには、外部から直接到達させたくないWebサーバーやDBを配置する。
PRI01_ID=$(ensure_subnet "sample-subnet-private01" "10.0.64.0/20" "ap-northeast-1a" "private" "false")

echo "=== Configure Private Subnet 02 ==="

# 2つ目のPrivate Subnetを作成または再利用する。
# こちらもAZを分けておき、将来的に冗長構成を組めるようにする。
PRI02_ID=$(ensure_subnet "sample-subnet-private02" "10.0.80.0/20" "ap-northeast-1c" "private" "false")

# 作成されたSubnet IDを表示する。
# 後続のIGW、NAT Gateway、Route Table、EC2作成でこのIDを使う。
echo "Subnets created:"
echo "  Public : $PUB01_ID, $PUB02_ID"
echo "  Private: $PRI01_ID, $PRI02_ID"

echo "=== Describe Subnets ==="

# VPC内のサブネット一覧を確認する。
# Name、public/privateの種別、AZ、CIDR、Public IP自動割り当て設定を表形式で表示する。
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table
