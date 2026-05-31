#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# このスクリプトでは、作業用IAMユーザーを設定した profile "learning" を使う。
PROFILE="learning"
REGION="ap-northeast-1"

# 作成するVPCの名前とCIDR。
# CIDRは、このVPC全体で使うプライベートIPアドレスの範囲。
VPC_NAME="sample-vpc"
VPC_CIDR="10.0.0.0/16"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 作成系コマンドを実行する前に、必ず想定したユーザーか確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Check Existing VPC ==="

# 同じNameタグのVPCが既に存在するか確認する。
# 再実行時に同名VPCを重複作成しないため、作成前に必ず確認する。
# 案件作業では、同じ名前の環境が複数あると誤作業につながるため、複数見つかった場合は停止する。
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text)

if [ "$VPC_COUNT" -gt 1 ]; then
  echo "Error: multiple VPCs found with Name tag $VPC_NAME. Please clean up duplicates before continuing."
  exit 1
elif [ "$VPC_COUNT" -eq 1 ]; then
  # 既存VPCが1つだけ存在する場合は、そのVPCを再利用する。
  # ここでCIDRも確認し、想定外のVPCを誤って後続手順に渡さないようにする。
  VPC_ID=$(aws ec2 describe-vpcs \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=tag:Name,Values="$VPC_NAME" \
    --query 'Vpcs[0].VpcId' \
    --output text)

  EXISTING_VPC_CIDR=$(aws ec2 describe-vpcs \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-ids "$VPC_ID" \
    --query 'Vpcs[0].CidrBlock' \
    --output text)

  if [ "$EXISTING_VPC_CIDR" != "$VPC_CIDR" ]; then
    echo "Error: existing VPC CIDR is $EXISTING_VPC_CIDR, expected $VPC_CIDR."
    exit 1
  fi

  echo "VPC already exists: $VPC_ID"
else
  echo "=== Create VPC ==="

  # VPCを作成する。
  # --query と --output text を使い、作成されたVPC IDだけを変数に入れる。
  # 後続のDNS設定や確認コマンドで、このVPC IDを使う。
  VPC_ID=$(aws ec2 create-vpc \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cidr-block "$VPC_CIDR" \
    --instance-tenancy default \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'Vpc.VpcId' \
    --output text)

  echo "New VPC ID: $VPC_ID"
fi

# DNSホスト名を有効化する。
# ALBやRDSなど、DNS名を使うAWSサービスと組み合わせるために有効にしておく。
# 既に有効でも同じ設定を再適用できるため、再実行時も安全に実行する。
aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'

# DNS解決を有効化する。
# VPC内でAWSのDNSを使って名前解決できるようにする設定。
# 既に有効でも同じ設定を再適用できるため、再実行時も安全に実行する。
aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-support '{"Value":true}'

# 作成したVPCの状態を確認する。
# Nameタグ、CIDR、状態、DNS設定を表形式で表示する。
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State,DNSHost:EnableDnsHostnames.Value,DNSSupport:EnableDnsSupport.Value}' \
  --output table
