#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# 作成するS3バケット名。
# S3バケット名は全AWSアカウントでグローバルに一意である必要がある。
BUCKET_NAME="nobu-terraform-iac-lab-upload"

# Web EC2を取得するためのVPC名。
# 同じNameタグのEC2が別VPCに存在しても誤ってIAM Roleを付けないよう、VPC IDで絞り込む。
VPC_NAME="sample-vpc"

# IAMロール設定。
# Web EC2からS3へ画像などをアップロードするためのロール。
ROLE_NAME="sample-role-web"
ROLE_DESCRIPTION="upload images"
INSTANCE_PROFILE_NAME="$ROLE_NAME"

# IAM Policy設定。
# S3は案件対策として、AWS管理ポリシーのAmazonS3FullAccessではなく
# 対象バケットだけに絞ったインラインポリシーを付与する。
S3_INLINE_POLICY_NAME="sample-policy-web-s3-upload"
S3_FULL_ACCESS_POLICY_ARN="arn:aws:iam::aws:policy/AmazonS3FullAccess"

# CloudWatch Agent:
# 後続のCloudWatch編で、Web EC2上のnginx / Pumaログを
# CloudWatch Logsへ送信するために利用する。
CLOUDWATCH_AGENT_POLICY_ARN="arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

# IAMロールを適用するWebサーバー。
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
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

echo "=== Caller Identity ==="

# IAMとS3を操作するため、作業先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Create S3 Bucket ==="

# S3バケットを作成または再利用する。
# head-bucketに成功した場合でも、想定リージョンと一致するか確認する。
if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" >/dev/null 2>&1; then
  BUCKET_LOCATION=$(aws s3api get-bucket-location \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$BUCKET_NAME" \
    --query 'LocationConstraint' \
    --output text)

  # us-east-1 の場合は LocationConstraint が None になる。
  if [ "$BUCKET_LOCATION" = "None" ]; then
    BUCKET_LOCATION="us-east-1"
  fi

  if [ "$BUCKET_LOCATION" != "$REGION" ]; then
    echo "Error: bucket $BUCKET_NAME exists in $BUCKET_LOCATION, expected $REGION."
    exit 1
  fi

  echo "Bucket already exists and is accessible: $BUCKET_NAME"
else
  # ap-northeast-1 のようなus-east-1以外のリージョンでは LocationConstraint の指定が必要。
  aws s3api create-bucket \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$BUCKET_NAME" \
    --create-bucket-configuration LocationConstraint="$REGION"

  echo "Bucket created: $BUCKET_NAME"
fi

echo "=== Block Public Access ==="

# バケットのパブリックアクセスをすべてブロックする。
# 外部公開用ではなく、EC2からアプリ経由で利用する想定。
aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "=== Disable ACLs ==="

# ACLを無効化する。
# BucketOwnerEnforcedにすると、オブジェクト所有者はバケット所有者に統一され、ACLは使わない運用になる。
aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --ownership-controls '{
    "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
    ]
  }'

echo "=== Default Encryption ==="

# S3は現在、新規オブジェクトを自動的にSSE-S3で暗号化する。
# ただし設定値として明示されていた方が影響調査・監査で説明しやすいため、
# バケットのデフォルト暗号化としてSSE-S3を明示的に設定する。
aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

echo "Default bucket encryption enabled: SSE-S3"

echo "=== Enforce TLS Access ==="

# HTTPでのS3アクセスを拒否するBucket Policyを設定する。
# Public Access Blockは公開許可を防ぐ設定であり、TLS強制のDenyポリシーとは目的が異なる。
BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF
)

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --policy "$BUCKET_POLICY"

echo "Bucket policy applied: DenyInsecureTransport"

echo "=== Create IAM Role for EC2 ==="

# EC2がこのロールを引き受けられるようにする信頼ポリシー。
# Principalに ec2.amazonaws.com を指定する。
TRUST_POLICY=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

# IAMロールがなければ作成する。
# 既存ロールを再利用する場合も、信頼ポリシーとタグを設計値へそろえる。
if aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "IAM Role already exists: $ROLE_NAME"

  aws iam update-assume-role-policy \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-document "$TRUST_POLICY"
else
  aws iam create-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --description "$ROLE_DESCRIPTION" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --tags Key=Name,Value="$ROLE_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "IAM Role created: $ROLE_NAME"
fi

aws iam tag-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --tags Key=Name,Value="$ROLE_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

echo "=== Attach Policy to IAM Role ==="

# Web EC2から対象S3バケットを操作できるように、バケット限定のインラインポリシーを付与する。
# Rails Active Storageのアップロード、取得、削除、マルチパートアップロードに必要な操作へ絞る。
S3_INLINE_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListUploadBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME"
    },
    {
      "Sid": "UseUploadObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$S3_INLINE_POLICY_NAME" \
  --policy-document "$S3_INLINE_POLICY"

echo "Inline policy applied: $S3_INLINE_POLICY_NAME"

# 以前の実行でAmazonS3FullAccessが付いていた場合は外す。
# 対象バケット以外へアクセスできる状態を残さないため。
aws iam detach-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-arn "$S3_FULL_ACCESS_POLICY_ARN" >/dev/null 2>&1 || true

# CloudWatch AgentがCloudWatch Logsへログを送信できるようにする。
# この権限がないと、AgentをインストールしてもLog Group / Log Stream作成や
# PutLogEventsに失敗し、nginx / PumaログがCloudWatch Logsへ届かない。
aws iam attach-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-arn "$CLOUDWATCH_AGENT_POLICY_ARN"

echo "Policy attached: $CLOUDWATCH_AGENT_POLICY_ARN"

echo "=== Create Instance Profile ==="

# EC2にIAMロールを付けるには、IAM RoleをInstance Profileに入れる必要がある。
if aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" >/dev/null 2>&1; then
  echo "Instance Profile already exists: $INSTANCE_PROFILE_NAME"
else
  aws iam create-instance-profile \
    --profile "$PROFILE" \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" \
    --tags Key=Name,Value="$INSTANCE_PROFILE_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "Instance Profile created: $INSTANCE_PROFILE_NAME"
fi

# Instance ProfileにRoleを追加する。
# Instance Profileには基本的に1つのRoleだけを入れるため、別Roleが入っている場合は停止する。
PROFILE_ROLE_NAMES=$(aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --query 'InstanceProfile.Roles[].RoleName' \
  --output text)

if [ -z "$PROFILE_ROLE_NAMES" ] || [ "$PROFILE_ROLE_NAMES" = "None" ]; then
  aws iam add-role-to-instance-profile \
    --profile "$PROFILE" \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" \
    --role-name "$ROLE_NAME"
elif [ "$PROFILE_ROLE_NAMES" = "$ROLE_NAME" ]; then
  echo "Role is already added to Instance Profile: $ROLE_NAME"
else
  echo "Error: Instance Profile $INSTANCE_PROFILE_NAME already has another role: $PROFILE_ROLE_NAMES"
  exit 1
fi

echo "Waiting for IAM propagation..."
sleep 15

echo "=== Get VPC ID ==="

# VPC IDを取得する。
# Web EC2をVPC IDで絞り込むために使う。
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

echo "VPC: $VPC_ID"

echo "=== Get Web Instance IDs ==="

# 指定したNameタグのrunning EC2が、対象VPC内に1台だけあることを確認してIDを返す。
# IAM Roleを誤ったEC2に関連付けないため、VPC IDでも絞り込む。
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

WEB01_ID=$(get_running_instance_id "$WEB01_NAME")
WEB02_ID=$(get_running_instance_id "$WEB02_NAME")

echo "Web01: $WEB01_ID"
echo "Web02: $WEB02_ID"

EXPECTED_PROFILE_ARN=$(aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --query 'InstanceProfile.Arn' \
  --output text)
EXPECTED_PROFILE_ARN=$(get_required_id "Instance Profile ARN" "$EXPECTED_PROFILE_ARN")

attach_or_replace_instance_profile() {
  local instance_id="$1"

  # EC2にすでにIAM Instance Profileが付いているか確認する。
  local association_id
  local current_profile_arn
  association_id=$(aws ec2 describe-iam-instance-profile-associations \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=instance-id,Values="$instance_id" \
    --query 'IamInstanceProfileAssociations[0].AssociationId' \
    --output text)

  if [ "$association_id" = "None" ] || [ -z "$association_id" ]; then
    echo "Associating Instance Profile to $instance_id"

    aws ec2 associate-iam-instance-profile \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-id "$instance_id" \
      --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" >/dev/null
  else
    current_profile_arn=$(aws ec2 describe-iam-instance-profile-associations \
      --profile "$PROFILE" \
      --region "$REGION" \
      --association-ids "$association_id" \
      --query 'IamInstanceProfileAssociations[0].IamInstanceProfile.Arn' \
      --output text)

    if [ "$current_profile_arn" = "$EXPECTED_PROFILE_ARN" ]; then
      echo "Instance Profile is already associated with $instance_id"
      return
    fi

    echo "Replacing Instance Profile on $instance_id"

    aws ec2 replace-iam-instance-profile-association \
      --profile "$PROFILE" \
      --region "$REGION" \
      --association-id "$association_id" \
      --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" >/dev/null
  fi
}

echo "=== Attach IAM Role to Web EC2 Instances ==="

attach_or_replace_instance_profile "$WEB01_ID"
attach_or_replace_instance_profile "$WEB02_ID"

echo "=== Describe S3 Bucket Settings ==="

# パブリックアクセスブロック設定を確認する。
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output table

# ACL無効化の設定を確認する。
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output table

# デフォルト暗号化設定を確認する。
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output table

echo "=== Describe IAM Role Policies ==="

# Web EC2用Roleに、S3のバケット限定インラインポリシーとCloudWatch Agent用管理ポリシーがあることを確認する。
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output table

aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output table

echo "=== Describe IAM Instance Profile Associations ==="

# Web EC2にInstance Profileが関連付いているか確認する。
# JMESPathのsplit関数は使えない環境があるため、ProfileArnをそのまま表示する。
aws ec2 describe-iam-instance-profile-associations \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=instance-id,Values="$WEB01_ID","$WEB02_ID" \
  --query 'IamInstanceProfileAssociations[*].{InstanceId:InstanceId,State:State,ProfileArn:IamInstanceProfile.Arn}' \
  --output table

echo "------------------------------------------------"
echo "S3 setup completed."
echo "Bucket: $BUCKET_NAME"
echo "IAM Role: $ROLE_NAME"
echo "Applied to: $WEB01_ID, $WEB02_ID"
echo "------------------------------------------------"
