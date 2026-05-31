#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Security Groupを作成する対象VPCのNameタグ。
VPC_NAME="sample-vpc"

# 作成するSecurity Groupの名前。
# Bastion用はSSH接続、ELB用はHTTP/HTTPS接続を受けるために使う。
BASTION_SG_NAME="sample-sg-bastion"
ELB_SG_NAME="sample-sg-elb"

# 現在の自分のグローバルIPを取得する。
# BastionへのSSHをインターネット全体ではなく、自分のIPだけに絞るため。
MY_GLOBAL_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')

# グローバルIPが取得できなかった場合は、SSH許可ルールを作れないためここで止める。
if [ -z "$MY_GLOBAL_IP" ]; then
  echo "Error: Could not detect global IP address."
  exit 1
fi

# /32 は「このIPアドレス1つだけ」を意味する。
# 例: 203.0.113.10/32 なら、そのIPからのSSHだけを許可する。
SSH_ALLOWED_CIDR="${MY_GLOBAL_IP}/32"

# ALBは外部からHTTP/HTTPSを受ける想定なので、全体から許可する。
# 学習環境ではこの形にしているが、実運用では要件に応じて制限する。
HTTP_ALLOWED_CIDR="0.0.0.0/0"
HTTPS_ALLOWED_CIDR="0.0.0.0/0"

echo "SSH allowed CIDR: $SSH_ALLOWED_CIDR"

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

# Security Groupを作成または再利用するための関数。
# Security Group名はVPC内で一意であるため、既存があれば新規作成しない。
ensure_security_group() {
  local group_name="$1"
  local description="$2"
  local group_count
  local group_id

  group_count=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$group_name" \
    --query 'length(SecurityGroups)' \
    --output text)

  if [ "$group_count" -gt 1 ]; then
    echo "Error: multiple Security Groups found for $group_name in $VPC_ID. Please investigate duplicates before continuing." >&2
    exit 1
  elif [ "$group_count" -eq 1 ]; then
    group_id=$(aws ec2 describe-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$group_name" \
      --query 'SecurityGroups[0].GroupId' \
      --output text)

    echo "Security Group already exists: $group_name ($group_id)" >&2
  else
    echo "Creating Security Group: $group_name" >&2

    group_id=$(aws ec2 create-security-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --group-name "$group_name" \
      --description "$description" \
      --vpc-id "$VPC_ID" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$group_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
      --query 'GroupId' \
      --output text)
  fi

  # 既存Security Groupを再利用する場合も、期待するタグにそろえる。
  # タグは同じ値を再適用しても安全で、後続スクリプトの検索条件にも使う。
  aws ec2 create-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resources "$group_id" \
    --tags Key=Name,Value="$group_name" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "$group_id"
}

# CIDRを送信元とするIngressルールを作成またはスキップするための関数。
# 同じルールが既にある場合、authorize-security-group-ingressは重複エラーになるため事前確認する。
ensure_ingress_cidr() {
  local group_id="$1"
  local protocol="$2"
  local from_port="$3"
  local to_port="$4"
  local cidr="$5"
  local description="$6"
  local rule_count

  rule_count=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --group-ids "$group_id" \
    --filters Name=ip-permission.protocol,Values="$protocol" Name=ip-permission.from-port,Values="$from_port" Name=ip-permission.to-port,Values="$to_port" Name=ip-permission.cidr,Values="$cidr" \
    --query 'length(SecurityGroups)' \
    --output text)

  if [ "$rule_count" -gt 0 ]; then
    echo "Ingress rule already exists: $group_id $protocol $from_port-$to_port $cidr"
    return
  fi

  echo "Adding ingress rule: $group_id $protocol $from_port-$to_port $cidr"

  aws ec2 authorize-security-group-ingress \
    --profile "$PROFILE" \
    --region "$REGION" \
    --group-id "$group_id" \
    --ip-permissions "IpProtocol=$protocol,FromPort=$from_port,ToPort=$to_port,IpRanges=[{CidrIp=$cidr,Description='$description'}]"
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 想定外のアカウントにSecurity Groupを作らないための確認。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# Security GroupはVPCに紐づけて作成するため、VPC IDが必要。
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

echo "=== Configure Bastion Security Group ==="

# 踏み台サーバー用のSecurity Groupを作成または再利用する。
# この時点ではルールはまだ追加されていない。
SG_BASTION_ID=$(ensure_security_group "$BASTION_SG_NAME" "for bastion server")

# BastionへSSH接続できるように、22番ポートを許可する。
# 送信元は現在の自分のグローバルIP /32 に限定している。
ensure_ingress_cidr "$SG_BASTION_ID" "tcp" "22" "22" "$SSH_ALLOWED_CIDR" "SSH access for learning"

echo "Bastion Security Group: $SG_BASTION_ID"

echo "=== Configure ELB Security Group ==="

# ロードバランサー用のSecurity Groupを作成または再利用する。
# 後続のALB作成時に、このSecurity GroupをALBへ関連付ける。
SG_ELB_ID=$(ensure_security_group "$ELB_SG_NAME" "for load balancer")

# ALBでHTTP通信を受けるため、80番ポートを許可する。
ensure_ingress_cidr "$SG_ELB_ID" "tcp" "80" "80" "$HTTP_ALLOWED_CIDR" "HTTP access"

# ALBでHTTPS通信を受けるため、443番ポートを許可する。
# 今後HTTPS化する場合に使う想定。
ensure_ingress_cidr "$SG_ELB_ID" "tcp" "443" "443" "$HTTPS_ALLOWED_CIDR" "HTTPS access"

echo "ELB Security Group: $SG_ELB_ID"

echo "Security Groups created: Bastion($SG_BASTION_ID), ELB($SG_ELB_ID)"

echo "=== Describe Security Groups ==="

# 作成したSecurity Groupとインバウンドルールを確認する。
# Bastion用はSSH、ELB用はHTTP/HTTPSが許可されているか見る。
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$SG_BASTION_ID" "$SG_ELB_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[0].CidrIp,RuleDescription:IpRanges[0].Description}}' \
  --output table
