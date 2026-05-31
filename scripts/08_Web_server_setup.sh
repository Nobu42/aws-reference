#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# このスクリプト自身が置かれているディレクトリを取得する。
# nobu.pem は scripts ディレクトリに置く運用のため、実行場所に依存しないよう絶対パスで扱う。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Webサーバー作成で参照するリソース名。
# WebサーバーはPrivate Subnetに配置し、Bastion経由でSSHする。
VPC_NAME="sample-vpc"
PRIVATE_SUBNET_01_NAME="sample-subnet-private01"
PRIVATE_SUBNET_02_NAME="sample-subnet-private02"
BASTION_INSTANCE_NAME="sample-ec2-bastion"
BASTION_SG_NAME="sample-sg-bastion"
ELB_SG_NAME="sample-sg-elb"
WEB_SG_NAME="sample-sg-web"

# EC2で使うKey Pair名と秘密鍵ファイル。
# Bastion作成時に作ったKey PairをWebサーバーでも使う。
KEY_NAME="nobu"
KEY_FILE="${KEY_NAME}.pem"
KEY_PATH="${SCRIPT_DIR}/${KEY_FILE}"

# WebサーバーのインスタンスタイプとNameタグ。
INSTANCE_TYPE="t3.small"
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"

# ~/.ssh/config に表示するHost名。
# 旧環境の Host bastion / web01 / web02 と衝突しないよう、aws-reference用の名前にする。
SSH_BASTION_HOST="awsref-bastion"
SSH_WEB01_HOST="awsref-web01"
SSH_WEB02_HOST="awsref-web02"

# Webサーバー起動時に使用するAMIの切り替え設定。
#
# false:
#   Amazon Linux 2023の最新AMIをSSM Parameter Storeから取得して使用する。
#
# true:
#   事前に作成したカスタムAMIを使用する。
#   trueにする場合は、CUSTOM_WEB_AMI_ID がこのアカウント・リージョンで available であることを確認する。
#
# この構成では、Ruby / Bundler / nginx / deployユーザーを導入済みの
# カスタムAMIを使う前提にする。
# 既存Web EC2がある場合は再利用するため、この値を変えても既存EC2のAMIは変わらない。
USE_CUSTOM_WEB_AMI=true
CUSTOM_WEB_AMI_ID="ami-00f86224c38cc3b8c"

# ALBからWebサーバーへ転送するアプリケーション用ポート。
# 後続のALB設定でもこのポートを使う。
APP_PORT="3000"

# AMI IDは、新規EC2を起動する場合だけ取得する。
# 既存Web EC2を再利用するだけの場合、AMI確認で止まらないよう遅延取得にしている。
AMI_ID=""
AMI_SOURCE=""

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
# 必要なリソースが見つからないままEC2作成へ進むのを防ぐ。
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

# Web EC2に使うKey Pairとローカル秘密鍵がそろっていることを確認する。
# WebサーバーはBastionと同じKey Pairを使うため、ここでは新規作成せず、07の成果物を確認する。
ensure_key_pair_for_ssh() {
  local key_pair_count

  key_pair_count=$(aws ec2 describe-key-pairs \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=key-name,Values="$KEY_NAME" \
    --query 'length(KeyPairs)' \
    --output text)

  if [ "$key_pair_count" -eq 0 ]; then
    echo "Error: AWS Key Pair $KEY_NAME was not found. Run 07_bastion_server_setup.sh first."
    exit 1
  elif [ "$key_pair_count" -gt 1 ]; then
    echo "Error: multiple Key Pairs found with name $KEY_NAME. Please investigate before continuing."
    exit 1
  fi

  if [ ! -f "$KEY_PATH" ]; then
    echo "Error: local private key was not found: $KEY_PATH"
    echo "Web SSH uses the same pem file as Bastion. Restore the pem file before continuing."
    exit 1
  fi

  chmod 400 "$KEY_PATH"
}

# 新規Web EC2を起動するときだけAMI IDを解決する。
# カスタムAMIを使う場合は、存在とavailable状態を確認してから使う。
resolve_ami_id() {
  local image_state

  if [ -n "$AMI_ID" ]; then
    return
  fi

  if [ "$USE_CUSTOM_WEB_AMI" != "true" ] && [ "$USE_CUSTOM_WEB_AMI" != "false" ]; then
    echo "Error: USE_CUSTOM_WEB_AMI must be true or false."
    exit 1
  fi

  if [ "$USE_CUSTOM_WEB_AMI" = "true" ]; then
    AMI_ID="$CUSTOM_WEB_AMI_ID"
    AMI_SOURCE="custom web base AMI"

    image_state=$(aws ec2 describe-images \
      --profile "$PROFILE" \
      --region "$REGION" \
      --image-ids "$AMI_ID" \
      --query 'Images[0].State' \
      --output text 2>/dev/null || true)

    if [ "$image_state" != "available" ]; then
      echo "Error: custom AMI $AMI_ID is not available in $REGION."
      echo "Set USE_CUSTOM_WEB_AMI=false or update CUSTOM_WEB_AMI_ID."
      exit 1
    fi
  else
    AMI_ID=$(aws ssm get-parameter \
      --profile "$PROFILE" \
      --region "$REGION" \
      --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
      --query 'Parameter.Value' \
      --output text)
    AMI_ID=$(get_required_id "Amazon Linux 2023 AMI" "$AMI_ID")
    AMI_SOURCE="latest Amazon Linux 2023 AMI from SSM Parameter Store"
  fi

  echo "AMI: $AMI_ID" >&2
  echo "AMI Source: $AMI_SOURCE" >&2
}

# Security Groupを作成または再利用する。
# 同じVPC内に同名Security Groupがあれば再利用し、重複作成を防ぐ。
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
    echo "Error: multiple Security Groups found for $group_name in $VPC_ID." >&2
    exit 1
  elif [ "$group_count" -eq 1 ]; then
    group_id=$(aws ec2 describe-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$group_name" \
      --query 'SecurityGroups[0].GroupId' \
      --output text)
    group_id=$(get_required_id "$group_name Security Group" "$group_id")

    echo "Reusing Security Group: $group_name ($group_id)" >&2
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

  # 既存Security Groupを再利用する場合もタグをそろえる。
  aws ec2 create-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resources "$group_id" \
    --tags Key=Name,Value="$group_name" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "$group_id"
}

# 送信元Security Groupを指定したIngress Ruleを作成またはスキップする。
# WebサーバーではCIDRではなく、Bastion SG / ELB SGを送信元にする。
ensure_ingress_from_sg() {
  local target_sg_id="$1"
  local protocol="$2"
  local from_port="$3"
  local to_port="$4"
  local source_sg_id="$5"
  local description="$6"
  local rule_output
  local rule_status

  echo "Adding ingress rule: $target_sg_id $protocol $from_port-$to_port from $source_sg_id"

  # 同じIngress Ruleが既にある場合、AWS CLIは InvalidPermission.Duplicate を返す。
  # その場合は正常な再実行として扱い、それ以外のエラーだけ停止する。
  set +e
  rule_output=$(aws ec2 authorize-security-group-ingress \
    --profile "$PROFILE" \
    --region "$REGION" \
    --group-id "$target_sg_id" \
    --ip-permissions "[{\"IpProtocol\":\"$protocol\",\"FromPort\":$from_port,\"ToPort\":$to_port,\"UserIdGroupPairs\":[{\"GroupId\":\"$source_sg_id\",\"Description\":\"$description\"}]}]" 2>&1)
  rule_status=$?
  set -e

  if [ "$rule_status" -eq 0 ]; then
    echo "$rule_output"
    return
  fi

  if echo "$rule_output" | grep -q "InvalidPermission.Duplicate"; then
    echo "Ingress rule already exists: $target_sg_id $protocol $from_port-$to_port from $source_sg_id"
    return
  fi

  echo "$rule_output"
  exit "$rule_status"
}

# Bastion EC2が1台だけ存在し、runningであることを確認する。
# 停止中の場合は、Webサーバーへの踏み台として使えるよう起動する。
ensure_running_bastion() {
  local bastion_count
  local bastion_id
  local bastion_state

  bastion_count=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'length(Reservations[].Instances[])' \
    --output text)

  require_single_match "Bastion Instance" "$bastion_count"

  bastion_id=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId | [0]' \
    --output text)
  bastion_id=$(get_required_id "Bastion Instance" "$bastion_id")

  bastion_state=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$bastion_id" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)

  if [ "$bastion_state" = "stopped" ]; then
    echo "Starting Bastion: $bastion_id" >&2
    aws ec2 start-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$bastion_id" >/dev/null
  elif [ "$bastion_state" = "stopping" ]; then
    echo "Waiting for Bastion to stop: $bastion_id" >&2
    aws ec2 wait instance-stopped \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$bastion_id"

    echo "Starting Bastion: $bastion_id" >&2
    aws ec2 start-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$bastion_id" >/dev/null
  else
    echo "Bastion found: $bastion_id ($bastion_state)" >&2
  fi

  aws ec2 wait instance-running \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$bastion_id"

  echo "$bastion_id"
}

# Web EC2を作成または再利用する。
# 同じNameタグのWeb EC2が存在する場合は重複作成せず、停止中なら起動する。
ensure_web_instance() {
  local instance_name="$1"
  local subnet_id="$2"
  local instance_count
  local instance_id
  local instance_state
  local instance_key_name
  local instance_subnet_id
  local instance_has_web_sg
  local instance_public_ip

  instance_count=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$instance_name" Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'length(Reservations[].Instances[])' \
    --output text)

  if [ "$instance_count" -gt 1 ]; then
    echo "Error: multiple Web instances found with Name tag $instance_name. Please investigate duplicates before continuing." >&2
    exit 1
  elif [ "$instance_count" -eq 1 ]; then
    instance_id=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$instance_name" Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId | [0]' \
      --output text)
    instance_id=$(get_required_id "$instance_name" "$instance_id")

    instance_key_name=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].KeyName' \
      --output text)

    if [ "$instance_key_name" != "$KEY_NAME" ]; then
      echo "Error: existing $instance_name uses Key Pair $instance_key_name, expected $KEY_NAME." >&2
      exit 1
    fi

    instance_subnet_id=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].SubnetId' \
      --output text)

    if [ "$instance_subnet_id" != "$subnet_id" ]; then
      echo "Error: existing $instance_name is in $instance_subnet_id, expected $subnet_id." >&2
      exit 1
    fi

    # 既存Web EC2を再利用する場合も、想定したWeb Security Groupが関連付いているか確認する。
    # 異なるSGのまま進めると、SSHやALB疎通の結果が設計とずれるため停止する。
    instance_has_web_sg=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --query "contains(Reservations[0].Instances[0].SecurityGroups[].GroupId, '$WEB_SG_ID')" \
      --output text)

    if [ "$instance_has_web_sg" != "True" ] && [ "$instance_has_web_sg" != "true" ]; then
      echo "Error: existing $instance_name is not associated with Web Security Group $WEB_SG_ID." >&2
      exit 1
    fi

    # Web EC2はPrivate Subnet配置のため、Public IPを持っていないことを確認する。
    # Public IPがある場合、外部から直接到達できる可能性があるため停止する。
    instance_public_ip=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text)

    if [ "$instance_public_ip" != "None" ] && [ -n "$instance_public_ip" ]; then
      echo "Error: existing $instance_name has a Public IP: $instance_public_ip" >&2
      exit 1
    fi

    instance_state=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text)

    if [ "$instance_state" = "stopped" ]; then
      echo "Starting existing Web instance: $instance_name ($instance_id)" >&2
      aws ec2 start-instances \
        --profile "$PROFILE" \
        --region "$REGION" \
        --instance-ids "$instance_id" >/dev/null
    elif [ "$instance_state" = "stopping" ]; then
      echo "Waiting for existing Web instance to stop: $instance_name ($instance_id)" >&2
      aws ec2 wait instance-stopped \
        --profile "$PROFILE" \
        --region "$REGION" \
        --instance-ids "$instance_id"

      echo "Starting existing Web instance: $instance_name ($instance_id)" >&2
      aws ec2 start-instances \
        --profile "$PROFILE" \
        --region "$REGION" \
        --instance-ids "$instance_id" >/dev/null
    else
      echo "Reusing existing Web instance: $instance_name ($instance_id / $instance_state)" >&2
    fi
  else
    resolve_ami_id

    echo "Launching Web instance: $instance_name" >&2
    instance_id=$(aws ec2 run-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --image-id "$AMI_ID" \
      --count 1 \
      --instance-type "$INSTANCE_TYPE" \
      --key-name "$KEY_NAME" \
      --security-group-ids "$WEB_SG_ID" \
      --subnet-id "$subnet_id" \
      --no-associate-public-ip-address \
      --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" "ResourceType=volume,Tags=[{Key=Name,Value=$instance_name-root},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
      --query 'Instances[0].InstanceId' \
      --output text)
  fi

  aws ec2 wait instance-running \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$instance_id"

  echo "$instance_id"
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# EC2は課金対象なので、作成前に操作先アカウントを必ず確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="

# VPC IDを取得する。
# 同じNameタグのVPCが複数ある場合、先頭を自動選択すると誤作業につながるため停止する。
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

# Web01を配置するPrivate Subnet 01のIDを取得する。
# VPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
PRI01_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 01" "$PRI01_COUNT"

PRI01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI01_ID=$(get_required_id "Private Subnet 01" "$PRI01_ID")

# Web02を配置するPrivate Subnet 02のIDを取得する。
PRI02_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_02_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 02" "$PRI02_COUNT"

PRI02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI02_ID=$(get_required_id "Private Subnet 02" "$PRI02_ID")

# WebサーバーへSSHするため、Bastion EC2がrunningであることを確認する。
BASTION_ID=$(ensure_running_bastion)

# BastionのPublic IPを取得する。
# SSHのProxyJump先として使う。
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
BASTION_PUBLIC_IP=$(get_required_id "Bastion Public IP" "$BASTION_PUBLIC_IP")

# Bastion用Security GroupのIDを取得する。
# Webサーバー側のSecurity Groupで、このSGからのSSHだけを許可する。
BASTION_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)
require_single_match "Bastion Security Group" "$BASTION_SG_COUNT"

BASTION_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
BASTION_SG_ID=$(get_required_id "Bastion Security Group" "$BASTION_SG_ID")

# ELB用Security GroupのIDを取得する。
# Webサーバー側のSecurity Groupで、このSGからのアプリ通信だけを許可する。
ELB_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELB_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)
require_single_match "ELB Security Group" "$ELB_SG_COUNT"

ELB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
ELB_SG_ID=$(get_required_id "ELB Security Group" "$ELB_SG_ID")

# Web EC2へのSSHに使うKey Pairとローカル秘密鍵を確認する。
ensure_key_pair_for_ssh

# 取得した値を表示し、想定したリソースを使うことを確認する。
echo "VPC: $VPC_ID"
echo "Private Subnet 01: $PRI01_ID"
echo "Private Subnet 02: $PRI02_ID"
echo "Bastion Instance: $BASTION_ID"
echo "Bastion Public IP: $BASTION_PUBLIC_IP"
echo "Bastion Security Group: $BASTION_SG_ID"
echo "ELB Security Group: $ELB_SG_ID"
echo "Key Pair: $KEY_NAME"
echo "Private Key: $KEY_PATH"

echo "=== Configure Web Security Group ==="

# Webサーバー用のSecurity Groupを作成または再利用する。
# SSHはBastionからのみ、アプリ通信はALBからのみ許可する。
WEB_SG_ID=$(ensure_security_group "$WEB_SG_NAME" "for web servers")

# Bastion SGからのSSH接続だけを許可する。
# 送信元にCIDRではなくSecurity Groupを指定している点がポイント。
ensure_ingress_from_sg "$WEB_SG_ID" "tcp" "22" "22" "$BASTION_SG_ID" "SSH from bastion"

# ALB SGからのアプリケーション通信だけを許可する。
# 後続のALB Target Groupでは、このポートへ転送する想定。
ensure_ingress_from_sg "$WEB_SG_ID" "tcp" "$APP_PORT" "$APP_PORT" "$ELB_SG_ID" "Application traffic from ALB"

echo "Web Security Group: $WEB_SG_ID"

echo "=== Configure Web Servers ==="

# Web01をPrivate Subnet 01に起動または再利用する。
# Public IPは付与しないため、外部から直接SSHできない。
WEB01_ID=$(ensure_web_instance "$WEB01_NAME" "$PRI01_ID")

# Web02をPrivate Subnet 02に起動または再利用する。
# Web01とは別AZのPrivate Subnetに配置している。
WEB02_ID=$(ensure_web_instance "$WEB02_NAME" "$PRI02_ID")

echo "Web01: $WEB01_ID"
echo "Web02: $WEB02_ID"

# Webサーバー2台のPrivate IPを取得する。
IP01=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB01_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)
IP01=$(get_required_id "Web01 Private IP" "$IP01")

IP02=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB02_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)
IP02=$(get_required_id "Web02 Private IP" "$IP02")

echo "Web01 Private IP: $IP01"
echo "Web02 Private IP: $IP02"

echo "=== SSH Commands via Bastion ==="

# Bastionを踏み台にしてWeb01へSSHするコマンドを表示する。
# -J は ProxyJump の指定。
echo "ssh -i $KEY_PATH -J ec2-user@$BASTION_PUBLIC_IP ec2-user@$IP01"

# Bastionを踏み台にしてWeb02へSSHするコマンドを表示する。
echo "ssh -i $KEY_PATH -J ec2-user@$BASTION_PUBLIC_IP ec2-user@$IP02"

echo "=== Describe Web Instances ==="

# 作成または再利用したWebサーバー2台の状態を確認する。
# PublicIPが None で、PrivateIPが割り当てられていればPrivate Subnet配置として期待通り。
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB01_ID" "$WEB02_ID" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,KeyName:KeyName,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId,MetadataHttpTokens:MetadataOptions.HttpTokens}' \
  --output table

echo "=== Describe Web Security Group ==="

# Web Security GroupのIngress Ruleを確認する。
# SSHはBastion SGから、アプリ通信はELB SGからのみ許可されていることを見る。
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$WEB_SG_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceSecurityGroups:UserIdGroupPairs[*].GroupId,Description:UserIdGroupPairs[*].Description}}' \
  --output table

echo "=== SSH config block ==="

# ~/.ssh/config に貼り付けるための設定例を表示する。
# 個人環境のSSH設定をスクリプトで直接変更せず、確認してから手動で反映する。
# 旧環境の Host bastion / web01 / web02 と衝突しないよう、awsref-* のHost名で表示する。
cat <<EOF
Host $SSH_BASTION_HOST
  HostName $BASTION_PUBLIC_IP
  User ec2-user
  IdentityFile $KEY_PATH
  IdentitiesOnly yes

Host $SSH_WEB01_HOST
  HostName $IP01
  User ec2-user
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  ProxyJump $SSH_BASTION_HOST

Host $SSH_WEB02_HOST
  HostName $IP02
  User ec2-user
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  ProxyJump $SSH_BASTION_HOST
EOF
