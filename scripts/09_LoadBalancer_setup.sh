#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# ALB作成で参照するリソース名。
# ALBはPublic Subnetに配置し、Private Subnet上のWeb EC2へ転送する。
VPC_NAME="sample-vpc"
PUB01_NAME="sample-subnet-public01"
PUB02_NAME="sample-subnet-public02"
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"
ELB_SG_NAME="sample-sg-elb"

# 作成するALB関連リソース名。
TARGET_GROUP_NAME="sample-tg"
ALB_NAME="sample-elb"
APP_PORT="3000"
HEALTH_CHECK_PATH="/"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
# 必要なリソースが見つからないままALB作成へ進むのを防ぐ。
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
# 0件なら前提不足、2件以上なら誤作業の危険があるため停止する。
require_single_match() {
  local label="$1"
  local count="$2"

  if [ "$count" -eq 0 ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  elif [ "$count" -gt 1 ]; then
    echo "Error: multiple resources found for $label. Please investigate duplicates before continuing."
    exit 1
  fi
}

# 指定したNameタグのrunning EC2が、対象VPC内に1台だけあることを確認してIDを返す。
# Target Groupに誤ったEC2を登録しないため、VPC IDでも絞り込む。
get_running_instance_id() {
  local instance_name="$1"
  local instance_count
  local instance_id

  instance_count=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$instance_name" Name=instance-state-name,Values=running \
    --query 'length(Reservations[].Instances[])' \
    --output text)
  require_single_match "$instance_name running instance" "$instance_count"

  instance_id=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$instance_name" Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].InstanceId | [0]' \
    --output text)
  get_required_id "$instance_name Instance" "$instance_id"
}

# Target Groupを作成または再利用する。
# 既存Target Groupを再利用する場合は、VPC、Protocol、Portが設計通りか確認する。
ensure_target_group() {
  local describe_output
  local target_group_arn
  local target_group_vpc_id
  local target_group_protocol
  local target_group_port

  describe_output=$(aws elbv2 describe-target-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --names "$TARGET_GROUP_NAME" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || true)

  if [ "$describe_output" != "None" ] && [ -n "$describe_output" ]; then
    target_group_arn="$describe_output"

    target_group_vpc_id=$(aws elbv2 describe-target-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --target-group-arns "$target_group_arn" \
      --query 'TargetGroups[0].VpcId' \
      --output text)

    if [ "$target_group_vpc_id" != "$VPC_ID" ]; then
      echo "Error: existing Target Group $TARGET_GROUP_NAME is in $target_group_vpc_id, expected $VPC_ID."
      exit 1
    fi

    target_group_protocol=$(aws elbv2 describe-target-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --target-group-arns "$target_group_arn" \
      --query 'TargetGroups[0].Protocol' \
      --output text)

    target_group_port=$(aws elbv2 describe-target-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --target-group-arns "$target_group_arn" \
      --query 'TargetGroups[0].Port' \
      --output text)

    if [ "$target_group_protocol" != "HTTP" ] || [ "$target_group_port" != "$APP_PORT" ]; then
      echo "Error: existing Target Group $TARGET_GROUP_NAME is $target_group_protocol:$target_group_port, expected HTTP:$APP_PORT."
      exit 1
    fi

    echo "Reusing Target Group: $TARGET_GROUP_NAME ($target_group_arn)" >&2
  else
    echo "Creating Target Group: $TARGET_GROUP_NAME" >&2
    target_group_arn=$(aws elbv2 create-target-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --name "$TARGET_GROUP_NAME" \
      --protocol HTTP \
      --port "$APP_PORT" \
      --target-type instance \
      --vpc-id "$VPC_ID" \
      --health-check-protocol HTTP \
      --health-check-path "$HEALTH_CHECK_PATH" \
      --tags Key=Name,Value="$TARGET_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text)
  fi

  # 既存Target Groupを再利用する場合もタグとヘルスチェック設定をそろえる。
  aws elbv2 add-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resource-arns "$target_group_arn" \
    --tags Key=Name,Value="$TARGET_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  aws elbv2 modify-target-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --target-group-arn "$target_group_arn" \
    --health-check-protocol HTTP \
    --health-check-path "$HEALTH_CHECK_PATH" >/dev/null

  echo "$target_group_arn"
}

# ALBを作成または再利用する。
# 既存ALBがある場合は、VPC、Type、Schemeを確認し、SubnetとSecurity Groupを設計値へそろえる。
ensure_load_balancer() {
  local describe_output
  local load_balancer_arn
  local load_balancer_vpc_id
  local load_balancer_type
  local load_balancer_scheme

  describe_output=$(aws elbv2 describe-load-balancers \
    --profile "$PROFILE" \
    --region "$REGION" \
    --names "$ALB_NAME" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || true)

  if [ "$describe_output" != "None" ] && [ -n "$describe_output" ]; then
    load_balancer_arn="$describe_output"

    load_balancer_vpc_id=$(aws elbv2 describe-load-balancers \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arns "$load_balancer_arn" \
      --query 'LoadBalancers[0].VpcId' \
      --output text)

    if [ "$load_balancer_vpc_id" != "$VPC_ID" ]; then
      echo "Error: existing ALB $ALB_NAME is in $load_balancer_vpc_id, expected $VPC_ID."
      exit 1
    fi

    load_balancer_type=$(aws elbv2 describe-load-balancers \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arns "$load_balancer_arn" \
      --query 'LoadBalancers[0].Type' \
      --output text)

    load_balancer_scheme=$(aws elbv2 describe-load-balancers \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arns "$load_balancer_arn" \
      --query 'LoadBalancers[0].Scheme' \
      --output text)

    if [ "$load_balancer_type" != "application" ] || [ "$load_balancer_scheme" != "internet-facing" ]; then
      echo "Error: existing ALB $ALB_NAME is $load_balancer_type / $load_balancer_scheme, expected application / internet-facing."
      exit 1
    fi

    echo "Reusing ALB: $ALB_NAME ($load_balancer_arn)" >&2

    # 既存ALBを再利用する場合も、SubnetとSecurity Groupを設計値へそろえる。
    aws elbv2 set-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arn "$load_balancer_arn" \
      --subnets "$PUB01_ID" "$PUB02_ID" >/dev/null

    aws elbv2 set-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arn "$load_balancer_arn" \
      --security-groups "$SG_ELB_ID" >/dev/null
  else
    echo "Creating ALB: $ALB_NAME" >&2
    load_balancer_arn=$(aws elbv2 create-load-balancer \
      --profile "$PROFILE" \
      --region "$REGION" \
      --name "$ALB_NAME" \
      --subnets "$PUB01_ID" "$PUB02_ID" \
      --security-groups "$SG_ELB_ID" \
      --scheme internet-facing \
      --type application \
      --ip-address-type ipv4 \
      --tags Key=Name,Value="$ALB_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text)
  fi

  aws elbv2 add-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resource-arns "$load_balancer_arn" \
    --tags Key=Name,Value="$ALB_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "$load_balancer_arn"
}

# HTTP:80 Listenerを作成または更新する。
# 既存Listenerがある場合は、転送先Target Groupを設計値へ変更する。
ensure_http_listener() {
  local listener_count
  local listener_arn

  listener_count=$(aws elbv2 describe-listeners \
    --profile "$PROFILE" \
    --region "$REGION" \
    --load-balancer-arn "$LB_ARN" \
    --query 'length(Listeners[?Protocol==`HTTP` && Port==`80`])' \
    --output text)

  if [ "$listener_count" -gt 1 ]; then
    echo "Error: multiple HTTP:80 listeners found on $ALB_NAME."
    exit 1
  elif [ "$listener_count" -eq 1 ]; then
    listener_arn=$(aws elbv2 describe-listeners \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arn "$LB_ARN" \
      --query 'Listeners[?Protocol==`HTTP` && Port==`80`].ListenerArn | [0]' \
      --output text)

    echo "Updating existing HTTP Listener: $listener_arn" >&2
    aws elbv2 modify-listener \
      --profile "$PROFILE" \
      --region "$REGION" \
      --listener-arn "$listener_arn" \
      --protocol HTTP \
      --port 80 \
      --default-actions Type=forward,TargetGroupArn="$TG_ARN" >/dev/null
  else
    echo "Creating HTTP Listener: 80 -> $TARGET_GROUP_NAME" >&2
    listener_arn=$(aws elbv2 create-listener \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arn "$LB_ARN" \
      --protocol HTTP \
      --port 80 \
      --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
      --query 'Listeners[0].ListenerArn' \
      --output text)
  fi

  echo "$listener_arn"
}

echo "=== Caller Identity ==="

# ALBは課金対象なので、作成前に操作先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="

# ALBとTarget Groupを作成するVPCを取得する。
# 同じNameタグのVPCが複数ある場合、誤作業防止のため停止する。
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text)
require_single_match "VPC" "$VPC_COUNT"

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
VPC_ID=$(get_required_id "VPC" "$VPC_ID")

# ALBを配置するPublic Subnetを2つ取得する。
# VPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
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

PUB01_AZ=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids "$PUB01_ID" \
  --query 'Subnets[0].AvailabilityZone' \
  --output text)

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

PUB02_AZ=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids "$PUB02_ID" \
  --query 'Subnets[0].AvailabilityZone' \
  --output text)

if [ "$PUB01_AZ" = "$PUB02_AZ" ]; then
  echo "Error: ALB requires subnets in at least two Availability Zones. Both subnets are in $PUB01_AZ."
  exit 1
fi

# Target Groupに登録するWebサーバー2台を取得する。
# running状態のインスタンスだけを対象にする。
WEB01_ID=$(get_running_instance_id "$WEB01_NAME")
WEB02_ID=$(get_running_instance_id "$WEB02_NAME")

# ALBに関連付けるSecurity Groupを取得する。
# このSGは、前の手順でインターネットからのHTTP/HTTPSを許可している。
SG_ELB_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELB_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)
require_single_match "ELB Security Group" "$SG_ELB_COUNT"

SG_ELB_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
SG_ELB_ID=$(get_required_id "ELB Security Group" "$SG_ELB_ID")

echo "VPC: $VPC_ID"
echo "Public Subnet 01: $PUB01_ID ($PUB01_AZ)"
echo "Public Subnet 02: $PUB02_ID ($PUB02_AZ)"
echo "Web Instances: $WEB01_ID, $WEB02_ID"
echo "ELB Security Group: $SG_ELB_ID"

echo "=== Configure Target Group ==="

TG_ARN=$(ensure_target_group)

echo "Target Group: $TG_ARN"

echo "=== Register Web Servers to Target Group ==="

# Webサーバー2台をTarget Groupへ登録する。
# register-targetsは同じターゲットを再登録しても安全に扱える。
aws elbv2 register-targets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn "$TG_ARN" \
  --targets Id="$WEB01_ID",Port="$APP_PORT" Id="$WEB02_ID",Port="$APP_PORT"

echo "Web01 and Web02 registered to Target Group."

echo "=== Configure Application Load Balancer ==="

LB_ARN=$(ensure_load_balancer)

echo "Load Balancer: $LB_ARN"

echo "=== Wait for Load Balancer to become available ==="

# ALBが利用可能になるまで待つ。
aws elbv2 wait load-balancer-available \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$LB_ARN"

echo "Load Balancer is available."

echo "=== Configure Listener ==="

LISTENER_ARN=$(ensure_http_listener)

echo "Listener: $LISTENER_ARN"

echo "=== Get Load Balancer DNS Name ==="

# ALBのDNS名を取得する。
LB_DNS_NAME=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$LB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)
LB_DNS_NAME=$(get_required_id "Load Balancer DNS Name" "$LB_DNS_NAME")

echo "------------------------------------------------"
echo "Setup Complete!"
echo "Access URL:"
echo "http://$LB_DNS_NAME"
echo "------------------------------------------------"

echo "=== Describe Target Health ==="

# Target Groupに登録されたWebサーバーのヘルスチェック状態を確認する。
# Rails/Pumaやnginxがまだ起動していない場合、Targetはunhealthyまたはinitialになる。
aws elbv2 describe-target-health \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table

echo "=== Describe Load Balancer ==="

# 作成または再利用したALBの状態を確認する。
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$LB_ARN" \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId}' \
  --output table

echo "=== Describe Listener ==="

# HTTP ListenerがTarget Groupへforwardしていることを確認する。
aws elbv2 describe-listeners \
  --profile "$PROFILE" \
  --region "$REGION" \
  --listener-arns "$LISTENER_ARN" \
  --query 'Listeners[*].{Port:Port,Protocol:Protocol,DefaultActions:DefaultActions[*].{Type:Type,TargetGroupArn:TargetGroupArn}}' \
  --output table
