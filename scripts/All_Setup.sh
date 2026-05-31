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

# このスクリプト自身が置かれているディレクトリへ移動する。
# どのディレクトリから実行しても、01〜09の相対パスが崩れないようにする。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# LocalStack向けのaliasや環境変数が残っていると、
# 実AWSではなくLocalStackへ接続してしまう。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

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
#   read -r -s -p "DB master password: " DB_MASTER_PASSWORD
#   export DB_MASTER_PASSWORD
#./10_Database_setup.sh

# S3とWeb EC2用IAM Role
#./11_s3_setup.sh

# Public DNS
#./12_public_dns_setup.sh

# Private DNS
#./14_private_dns_setup.sh

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

echo "================================================"
echo "All setup completed."
echo ""
echo "Next checks:"
echo "  aws elbv2 describe-target-health --profile learning --region ap-northeast-1 --target-group-arn <TARGET_GROUP_ARN> --output table"
echo ""
echo "Manual checks:"
echo "  - Update ~/.ssh/config with the awsref-* block printed by 08_Web_server_setup.sh."
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
