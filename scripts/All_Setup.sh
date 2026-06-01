#!/bin/bash
set -euo pipefail

# ============================================================
# All_Setup.sh
#
# AWS CLI編の主要セットアップスクリプトを順番に実行する。
#
# このスクリプトは「何も残っていない状態」からの新規構築を前提とする。
# 既存の sample-vpc が残っている状態で実行すると、
# Subnet CIDRの衝突や、古いVPCを誤って参照する問題が起きる。
#
# そのため、冒頭で sample-vpc の残存確認を行い、
# 1つでも残っていた場合は安全のため処理を停止する。
#
# 残っている場合は、先に以下を実行する。
#
#   ./cleanup_network.sh
#
# ============================================================

PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
BASTION_INSTANCE_NAME="sample-ec2-bastion"
WEB01_INSTANCE_NAME="sample-ec2-web01"
WEB02_INSTANCE_NAME="sample-ec2-web02"

# このスクリプト自身が置かれているディレクトリへ移動する。
# どのディレクトリから実行しても、01〜09の相対パスが崩れないようにする。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
KEY_FILE="$SCRIPT_DIR/nobu.pem"

# LocalStack向けのaliasや環境変数が残っていると、
# 実AWSではなくLocalStackへ接続してしまう。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 最後にSSH設定を表示するため、必要な値が取れない場合は分かりやすく停止する。
get_required_value() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found."
    exit 1
  fi

  echo "$value"
}

echo "================================================"
echo "All setup started."
echo "This script creates daily lab resources."
echo "================================================"

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Check existing VPC ==="

# sample-vpc がすでに存在するか確認する。
# 既存VPCが残っている状態でセットアップを開始すると、
# 02_subnet_setup.sh が古いVPCを拾ったり、
# Subnet CIDRが衝突したりする可能性がある。
EXISTING_VPCS=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[*].VpcId' \
  --output text)

if [ -n "$EXISTING_VPCS" ]; then
  echo "Error: Existing VPC found."
  echo "VPC Name: $VPC_NAME"
  echo "VPC IDs : $EXISTING_VPCS"
  echo ""
  echo "This script must start from a clean state."
  echo "Please delete remaining daily lab resources first:"
  echo ""
  echo "  ./cleanup_network.sh"
  echo ""
  echo "After cleanup, run this script again."
  exit 1
fi

echo "No existing $VPC_NAME found. Continue setup."

echo "=== Input RDS master password ==="
echo "This password is used by 10_Database_setup.sh."
echo "Input is hidden and will not be displayed."

# RDSのマスターパスワードを入力する。
# Caller Identityと既存VPC確認が終わってから入力し、
# 不要な場面でパスワードを打たないようにする。
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo

if [ -z "$DB_MASTER_PASSWORD" ]; then
  echo "Error: DB master password is empty."
  exit 1
fi

export DB_MASTER_PASSWORD

# スクリプト終了時に、このシェルプロセス内のDBパスワードを破棄する。
trap 'unset DB_MASTER_PASSWORD' EXIT

echo "=== Run setup scripts ==="

# ネットワーク基盤
./01_vpc_setup.sh
./02_subnet_setup.sh
./03_internetgateway_setup.sh
./04_nat_gateway_setup.sh
./05_route_table_setup.sh

# セキュリティグループ
./06_security_group_setup.sh

# EC2
./07_bastion_server_setup.sh
./08_Web_server_setup.sh

# ALB
./09_LoadBalancer_setup.sh

# RDS
# RDSを有効化する場合は、DB_MASTER_PASSWORDを環境変数で渡してから実行する。
# 例:
./10_Database_setup.sh

# S3とWeb EC2用IAM Role
./11_s3_setup.sh

# Public DNS
./12_public_dns_setup.sh

# Private DNS
./14_private_dns_setup.sh

# ACM証明書とHTTPS Listener
#./15_acm_certificate_setup.sh

# SES送信用のDomain Identity / DKIM / SPF / DMARCは初回設定済みのため、
# 毎日のセットアップでは実行しない。
#
# ./16_ses_setup.sh

# SES受信設定は、メール受信を検証する日だけ実行する。
# 実行するとMXレコード、Receipt Rule、受信用S3バケットを作成する。
#
# ./18_ses_receiving_setup.sh

# ElastiCache Redis
#./19_elasticache_setup.sh

echo "=== Get SSH config values ==="

# All_Setup.sh の最後に、現在作成されたEC2のIPを使って ~/.ssh/config 用のブロックを表示する。
# 各EC2は日次で作り直すため、Public IP / Private IP は毎回変わる。
CREATED_VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
CREATED_VPC_ID=$(get_required_value "VPC" "$CREATED_VPC_ID")

BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$CREATED_VPC_ID" Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
BASTION_PUBLIC_IP=$(get_required_value "Bastion Public IP" "$BASTION_PUBLIC_IP")

WEB01_PRIVATE_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$CREATED_VPC_ID" Name=tag:Name,Values="$WEB01_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)
WEB01_PRIVATE_IP=$(get_required_value "Web01 Private IP" "$WEB01_PRIVATE_IP")

WEB02_PRIVATE_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$CREATED_VPC_ID" Name=tag:Name,Values="$WEB02_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)
WEB02_PRIVATE_IP=$(get_required_value "Web02 Private IP" "$WEB02_PRIVATE_IP")

echo "================================================"
echo "All setup completed."
echo ""
echo "Next checks:"
echo "  aws elbv2 describe-target-health --profile learning --region ap-northeast-1 --target-group-arn <TARGET_GROUP_ARN> --output table"
echo ""
echo "Manual checks:"
echo "  - Update ~/.ssh/config with the awsref-* block printed below."
echo "  ssh awsref-bastion"
echo "  ssh awsref-web01"
echo "  ssh awsref-web02"
echo "  http://<ALB_DNS_NAME>"
echo ""
echo "Notes:"
echo "  - Target Health may be unhealthy until Rails/Puma/nginx is configured."
echo "  - Run ./18_ses_receiving_setup.sh only when testing email receiving."
echo "  - Run ./cleanup_network.sh after learning to delete chargeable resources."
echo "================================================"
echo "SSH config block:"
cat <<EOF
Host awsref-bastion
  HostName $BASTION_PUBLIC_IP
  User ec2-user
  IdentityFile $KEY_FILE
  IdentitiesOnly yes

Host awsref-web01
  HostName $WEB01_PRIVATE_IP
  User ec2-user
  IdentityFile $KEY_FILE
  IdentitiesOnly yes
  ProxyJump awsref-bastion

Host awsref-web02
  HostName $WEB02_PRIVATE_IP
  User ec2-user
  IdentityFile $KEY_FILE
  IdentitiesOnly yes
  ProxyJump awsref-bastion
EOF
