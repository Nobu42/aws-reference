#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Internet Gatewayを接続するVPC名と、作成するInternet Gateway名。
VPC_NAME="sample-vpc"
IGW_NAME="sample-igw"

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

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 想定外のアカウントにリソースを作らないための確認。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# Internet GatewayをVPCへ接続するにはVPC IDが必要。
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

echo "=== Check Existing Internet Gateway ==="

# 対象VPCに、すでにInternet Gatewayが接続されていないか確認する。
# VPCにはInternet Gatewayを1つだけ接続できる。
# 既存IGWを確認せずに再実行すると、新しいIGWを作成した後にattachで失敗し、
# 未接続のInternet Gatewayだけが残る可能性がある。
EXISTING_IGW_ID=$(aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)

if [ "$EXISTING_IGW_ID" != "None" ] && [ -n "$EXISTING_IGW_ID" ]; then
  # すでにVPCへ接続済みのIGWがある場合は、それを利用する。
  # この分岐に入った場合、新しいIGWは作成しない。
  IGW_ID="$EXISTING_IGW_ID"
  echo "Internet Gateway already attached: $IGW_ID"
else
  echo "=== Check Unattached Internet Gateway ==="

  # 前回実行が「IGW作成後、VPCアタッチ前」に失敗した場合、
  # 同じNameタグの未接続IGWだけが残ることがある。
  # その場合は新規作成せず、残っているIGWを再利用する。
  TAGGED_IGW_COUNT=$(aws ec2 describe-internet-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=tag:Name,Values="$IGW_NAME" \
    --query 'length(InternetGateways)' \
    --output text)

  if [ "$TAGGED_IGW_COUNT" -gt 1 ]; then
    echo "Error: multiple Internet Gateways found with Name tag $IGW_NAME. Please investigate duplicates before continuing."
    exit 1
  elif [ "$TAGGED_IGW_COUNT" -eq 1 ]; then
    IGW_ID=$(aws ec2 describe-internet-gateways \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=tag:Name,Values="$IGW_NAME" \
      --query 'InternetGateways[0].InternetGatewayId' \
      --output text)

    ATTACHED_VPC_ID=$(aws ec2 describe-internet-gateways \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-ids "$IGW_ID" \
      --query 'InternetGateways[0].Attachments[0].VpcId' \
      --output text)

    if [ "$ATTACHED_VPC_ID" != "None" ] && [ -n "$ATTACHED_VPC_ID" ] && [ "$ATTACHED_VPC_ID" != "$VPC_ID" ]; then
      echo "Error: Internet Gateway $IGW_ID is already attached to another VPC: $ATTACHED_VPC_ID"
      exit 1
    fi

    echo "Reusing unattached Internet Gateway: $IGW_ID"
  else
    echo "=== Create Internet Gateway ==="

    # Internet Gatewayを作成する。
    # Internet Gatewayは、VPCをインターネットへ接続するための出口になる。
    # ただし、作成しただけではまだVPCに接続されていない。
    IGW_ID=$(aws ec2 create-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
      --query 'InternetGateway.InternetGatewayId' \
      --output text)

    echo "Created IGW ID: $IGW_ID"
  fi

  echo "=== Attach Internet Gateway to VPC ==="

  # 作成または再利用したInternet GatewayをVPCに接続する。
  # Public Subnetからインターネットへ出るには、この後のRoute Table設定も必要。
  aws ec2 attach-internet-gateway \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-id "$VPC_ID" \
    --internet-gateway-id "$IGW_ID"

  echo "Success! Attached IGW ($IGW_ID) to VPC ($VPC_ID)"
fi

# 既存IGWを再利用した場合も、期待するタグを再適用する。
# タグは同じ値を再適用しても安全で、後続スクリプトの検索条件にも使う。
aws ec2 create-tags \
  --profile "$PROFILE" \
  --region "$REGION" \
  --resources "$IGW_ID" \
  --tags Key=Name,Value="$IGW_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

echo "=== Describe Internet Gateway ==="

# Internet GatewayがVPCに接続されているか確認する。
# Stateが available で、VPCに対象VPC IDが表示されていれば接続できている。
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --internet-gateway-ids "$IGW_ID" \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
