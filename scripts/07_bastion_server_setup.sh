#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Bastionを作成するために参照するリソース名。
# BastionはPublic Subnetに配置し、SSHの入口として使う。
VPC_NAME="sample-vpc"
PUBLIC_SUBNET_NAME="sample-subnet-public01"
BASTION_SG_NAME="sample-sg-bastion"

# EC2に設定するKey Pair名と秘密鍵ファイル名。
# AWS側のKey Pairとローカルのpemファイルは対応している必要がある。
KEY_NAME="nobu"
KEY_FILE="${KEY_NAME}.pem"

# 作成するBastion EC2のNameタグとインスタンスタイプ。
# t3.microは今回の無料枠対象として確認したため使用している。
INSTANCE_NAME="sample-ec2-bastion"
INSTANCE_TYPE="t3.micro"

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

# AWS側のKey Pairとローカルpemファイルを安全に用意する。
# KeyMaterialはKey Pair作成時にしか取得できない。
# そのため、AWS側にKey Pairがあるのにpemがない場合は復元できないため停止する。
ensure_key_pair_for_launch() {
  local key_pair_count

  key_pair_count=$(aws ec2 describe-key-pairs \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=key-name,Values="$KEY_NAME" \
    --query 'length(KeyPairs)' \
    --output text)

  if [ "$key_pair_count" -gt 1 ]; then
    echo "Error: multiple Key Pairs found with name $KEY_NAME. Please investigate before continuing."
    exit 1
  fi

  if [ "$key_pair_count" -eq 1 ] && [ -f "$KEY_FILE" ]; then
    # AWS側のKey Pairとローカルpemが両方ある場合は再利用する。
    # 秘密鍵の権限だけSSHが受け入れる状態にそろえる。
    chmod 400 "$KEY_FILE"
    echo "Key Pair already exists and local private key was found: $KEY_NAME"
    return
  fi

  if [ "$key_pair_count" -eq 1 ] && [ ! -f "$KEY_FILE" ]; then
    # AWS側のKey Pairが存在しても、秘密鍵の中身は後から取得できない。
    # ここでKey Pairを削除して作り直すと、既存EC2との対応が崩れる可能性があるため停止する。
    echo "Error: AWS Key Pair $KEY_NAME exists, but local private key $KEY_FILE was not found."
    echo "KeyMaterial cannot be downloaded again. Restore the pem file or choose a new Key Pair name."
    exit 1
  fi

  if [ "$key_pair_count" -eq 0 ] && [ -f "$KEY_FILE" ]; then
    # ローカルpemだけが残っている場合、AWS側のKey Pairと対応している保証がない。
    # 誤った秘密鍵を使ったまま進めるとSSH不能になるため停止する。
    echo "Error: local private key $KEY_FILE exists, but AWS Key Pair $KEY_NAME was not found."
    echo "Move or remove the stale pem file, or choose a new Key Pair name before continuing."
    exit 1
  fi

  echo "=== Create Key Pair ==="

  # AWS側にもローカルにもKey Pairがない場合だけ、新しく作成する。
  # KeyMaterialは作成時にしか取得できないため、ここで必ずpemファイルとして保存する。
  aws ec2 create-key-pair \
    --profile "$PROFILE" \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$KEY_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'KeyMaterial' \
    --output text > "$KEY_FILE"

  chmod 400 "$KEY_FILE"

  echo "Key pair created: $KEY_NAME"
  echo "Private key saved: $KEY_FILE"
}

# SSHコマンドを表示するため、ローカル秘密鍵が存在することを確認する。
# 既存Bastionを再利用する場合でも、pemがなければSSHできないため停止する。
ensure_private_key_file_for_ssh() {
  if [ ! -f "$KEY_FILE" ]; then
    echo "Error: local private key $KEY_FILE was not found. Cannot build a usable SSH command."
    exit 1
  fi

  chmod 400 "$KEY_FILE"
}

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# EC2は課金対象なので、作成前に操作先アカウントを必ず確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="

# VPC IDを取得する。
# 同じNameタグのVPCが複数ある場合、先頭を自動選択すると誤作業につながる。
# そのため、対象VPCが1つだけであることを確認してからVPC IDを取得する。
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

# Bastionを配置するPublic SubnetのIDを取得する。
# NameタグだけでなくVPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
PUB01_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUBLIC_SUBNET_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Public Subnet 01" "$PUB01_COUNT"

PUB01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUBLIC_SUBNET_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PUB01_ID=$(get_required_id "Public Subnet 01" "$PUB01_ID")

# Bastion用Security GroupのIDを取得する。
# SSH接続を許可するルールが入っているSecurity GroupをEC2に関連付ける。
SG_BASTION_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)
require_single_match "Bastion Security Group" "$SG_BASTION_COUNT"

SG_BASTION_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
SG_BASTION_ID=$(get_required_id "Bastion Security Group" "$SG_BASTION_ID")

# 取得した値を表示し、想定したリソースを使うことを確認する。
echo "VPC: $VPC_ID"
echo "Public Subnet: $PUB01_ID"
echo "Bastion Security Group: $SG_BASTION_ID"

echo "=== Check Existing Bastion Instance ==="

# 既存Bastion EC2を確認する。
# 再実行時に同じNameタグのEC2を重複作成しないため、pending/running/stopping/stoppedを対象に探す。
BASTION_COUNT=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$INSTANCE_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'length(Reservations[].Instances[])' \
  --output text)

if [ "$BASTION_COUNT" -gt 1 ]; then
  echo "Error: multiple Bastion instances found with Name tag $INSTANCE_NAME. Please investigate duplicates before continuing."
  exit 1
elif [ "$BASTION_COUNT" -eq 1 ]; then
  # 既存Bastionがある場合は、新規作成せず再利用する。
  BASTION_ID=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$INSTANCE_NAME" Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId | [0]' \
    --output text)
  BASTION_ID=$(get_required_id "Bastion Instance" "$BASTION_ID")

  INSTANCE_KEY_NAME=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$BASTION_ID" \
    --query 'Reservations[0].Instances[0].KeyName' \
    --output text)

  if [ "$INSTANCE_KEY_NAME" != "$KEY_NAME" ]; then
    echo "Error: existing Bastion uses Key Pair $INSTANCE_KEY_NAME, expected $KEY_NAME."
    exit 1
  fi

  ensure_private_key_file_for_ssh

  BASTION_STATE=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$BASTION_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)

  if [ "$BASTION_STATE" = "stopped" ]; then
    echo "Starting existing Bastion: $BASTION_ID"
    aws ec2 start-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$BASTION_ID" >/dev/null
  elif [ "$BASTION_STATE" = "stopping" ]; then
    echo "Waiting for existing Bastion to stop: $BASTION_ID"
    aws ec2 wait instance-stopped \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$BASTION_ID"

    echo "Starting existing Bastion: $BASTION_ID"
    aws ec2 start-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids "$BASTION_ID" >/dev/null
  else
    echo "Reusing existing Bastion: $BASTION_ID ($BASTION_STATE)"
  fi
else
  echo "=== Prepare Key Pair ==="

  # 新規Bastionを起動する場合だけ、Key Pairを安全に用意する。
  # 既存Key Pairやpemを無条件削除しない。
  ensure_key_pair_for_launch

  echo "=== Get Latest Amazon Linux 2023 AMI ==="

  # Amazon Linux 2023の最新AMI IDをSSM Parameter Storeから取得する。
  # AMI IDはリージョンや時期で変わるため、固定値ではなくAWS管理のパラメータから取得する。
  AMI_ID=$(aws ssm get-parameter \
    --profile "$PROFILE" \
    --region "$REGION" \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameter.Value' \
    --output text)
  AMI_ID=$(get_required_id "Amazon Linux 2023 AMI" "$AMI_ID")

  echo "AMI: $AMI_ID"

  echo "=== Launch Bastion Instance ==="

  # Bastion用EC2を起動する。
  # Public Subnetに配置し、Public IPを自動割り当てしてSSHできるようにする。
  # IMDSv2を必須にし、インスタンスメタデータ取得の安全性も高める。
  BASTION_ID=$(aws ec2 run-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_BASTION_ID" \
    --subnet-id "$PUB01_ID" \
    --associate-public-ip-address \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" "ResourceType=volume,Tags=[{Key=Name,Value=$INSTANCE_NAME-root},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
fi

echo "Waiting for Bastion ($BASTION_ID) to be running..."

# EC2の状態が running になるまで待つ。
# 起動完了前にPublic IPを取得したりSSHしようとすると失敗することがある。
aws ec2 wait instance-running \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID"

# BastionのPublic IPを取得する。
# ローカルPCからSSH接続するために使う。
PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# BastionのPrivate IPを取得する。
# VPC内での通信確認や、構成把握のために表示する。
PRIVATE_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

ensure_private_key_file_for_ssh

echo "Bastion is running."
echo "Instance ID: $BASTION_ID"
echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

echo "=== SSH Command ==="

# Bastionへ接続するためのSSHコマンドを表示する。
# Amazon Linux 2023の標準ユーザーは ec2-user。
echo "ssh -i $KEY_FILE ec2-user@$PUBLIC_IP"

echo "=== Describe Bastion Instance ==="

# 作成または再利用したBastion EC2の状態を確認する。
# running、PublicIP、PrivateIP、Subnetが期待通りか見る。
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,KeyName:KeyName,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
