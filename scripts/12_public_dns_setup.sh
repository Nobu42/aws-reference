#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Route 53で管理するドメイン名。
# Hosted ZoneのNameは末尾に "." が付くため、取得時は DOMAIN_NAME_DOT を使う。
DOMAIN_NAME="nobu-iac-lab.com"
DOMAIN_NAME_DOT="${DOMAIN_NAME}."

# DNSレコードを作成する対象リソース。
# BastionとALBが同じVPCにあることを確認するため、VPC名も使う。
VPC_NAME="sample-vpc"
BASTION_INSTANCE_NAME="sample-ec2-bastion"
ALB_NAME="sample-elb"

# 作成するPublic DNSレコード名。
# 完成形:
#   bastion.nobu-iac-lab.com
#   www.nobu-iac-lab.com
BASTION_RECORD_NAME="bastion"
ALB_RECORD_NAME="www"

# BastionのAレコードに設定するTTL。
# EC2を作り直すとPublic IPが変わるため、長すぎない値にしておく。
BASTION_TTL="300"

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# IDや値の取得に失敗した場合に、分かりやすいメッセージで止めるための関数。
get_required_value() {
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

# DNSは公開設定に関わるため、操作先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Public Hosted Zone ID ==="

# Public Hosted Zoneをドメイン名から取得する。
# Private Hosted Zoneと区別するため、Config.PrivateZone == false のものだけを対象にする。
HOSTED_ZONE_COUNT=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "length(HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`])" \
  --output text)
require_single_match "Public Hosted Zone" "$HOSTED_ZONE_COUNT"

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`].Id | [0]" \
  --output text)

HOSTED_ZONE_ID=$(get_required_value "Public Hosted Zone" "$HOSTED_ZONE_ID")

# Route 53のHosted Zone IDは "/hostedzone/XXXXXXXX" の形式で返るため、ID部分だけにする。
HOSTED_ZONE_ID="${HOSTED_ZONE_ID#/hostedzone/}"

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

echo "=== Get VPC ID ==="

# VPC IDを取得する。
# BastionとALBが今回の学習用VPCに属しているか確認するために使う。
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
VPC_ID=$(get_required_value "VPC" "$VPC_ID")

echo "VPC: $VPC_ID"

echo "=== Get Bastion Public IP ==="

# BastionサーバーのPublic IPを取得する。
# bastion.nobu-iac-lab.com のAレコードには、このPublic IPを設定する。
BASTION_COUNT=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'length(Reservations[].Instances[])' \
  --output text)
require_single_match "Bastion running instance" "$BASTION_COUNT"

BASTION_ID=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId | [0]' \
  --output text)
BASTION_ID=$(get_required_value "Bastion Instance" "$BASTION_ID")

BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

BASTION_PUBLIC_IP=$(get_required_value "Bastion Public IP" "$BASTION_PUBLIC_IP")

echo "Bastion Instance: $BASTION_ID"
echo "Bastion Public IP: $BASTION_PUBLIC_IP"

echo "=== Get ALB DNS Name and Canonical Hosted Zone ID ==="

# ALBのDNS名とCanonicalHostedZoneIdを取得する。
# Route 53でALBへAliasレコードを作る場合、この2つが必要になる。
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null || true)
ALB_ARN=$(get_required_value "ALB ARN" "$ALB_ARN")

ALB_VPC_ID=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].VpcId' \
  --output text)
ALB_VPC_ID=$(get_required_value "ALB VPC ID" "$ALB_VPC_ID")

if [ "$ALB_VPC_ID" != "$VPC_ID" ]; then
  echo "Error: ALB $ALB_NAME is in $ALB_VPC_ID, expected $VPC_ID."
  exit 1
fi

ALB_TYPE=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].Type' \
  --output text)
ALB_TYPE=$(get_required_value "ALB Type" "$ALB_TYPE")

ALB_SCHEME=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].Scheme' \
  --output text)
ALB_SCHEME=$(get_required_value "ALB Scheme" "$ALB_SCHEME")

if [ "$ALB_TYPE" != "application" ] || [ "$ALB_SCHEME" != "internet-facing" ]; then
  echo "Error: ALB $ALB_NAME is $ALB_TYPE / $ALB_SCHEME, expected application / internet-facing."
  exit 1
fi

ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

ALB_DNS_NAME=$(get_required_value "ALB DNS Name" "$ALB_DNS_NAME")

ALB_CANONICAL_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' \
  --output text)

ALB_CANONICAL_HOSTED_ZONE_ID=$(get_required_value "ALB Canonical Hosted Zone ID" "$ALB_CANONICAL_HOSTED_ZONE_ID")

echo "ALB ARN: $ALB_ARN"
echo "ALB DNS Name: $ALB_DNS_NAME"
echo "ALB Canonical Hosted Zone ID: $ALB_CANONICAL_HOSTED_ZONE_ID"

echo "=== Create / Update Public DNS Records ==="

# UPSERTを使う。
# レコードがなければ作成、すでにあれば更新する。
# EC2やALBを作り直して値が変わった場合も、このスクリプトを再実行すればDNSを更新できる。
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Create or update public DNS records for learning lab",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${BASTION_RECORD_NAME}.${DOMAIN_NAME}.",
        "Type": "A",
        "TTL": ${BASTION_TTL},
        "ResourceRecords": [
          {
            "Value": "${BASTION_PUBLIC_IP}"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${ALB_RECORD_NAME}.${DOMAIN_NAME}.",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "${ALB_CANONICAL_HOSTED_ZONE_ID}",
          "DNSName": "${ALB_DNS_NAME}",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF
)

CHANGE_ID=$(aws route53 change-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "$CHANGE_BATCH" \
  --query 'ChangeInfo.Id' \
  --output text)

CHANGE_ID=$(get_required_value "Route 53 Change ID" "$CHANGE_ID")

echo "Route 53 Change ID: $CHANGE_ID"

echo "=== Wait for DNS Change to be INSYNC ==="

# Route 53上でレコード変更が反映されるまで待つ。
aws route53 wait resource-record-sets-changed \
  --profile "$PROFILE" \
  --id "$CHANGE_ID"

echo "DNS change is INSYNC."

echo "=== Describe Created Records ==="

# 作成したレコードを確認する。
aws route53 list-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name==\`${BASTION_RECORD_NAME}.${DOMAIN_NAME}.\` || Name==\`${ALB_RECORD_NAME}.${DOMAIN_NAME}.\`]" \
  --output table

echo "------------------------------------------------"
echo "Route 53 public DNS setup completed."
echo "Bastion URL:"
echo "  bastion.${DOMAIN_NAME} -> ${BASTION_PUBLIC_IP}"
echo "Web URL:"
echo "  http://${ALB_RECORD_NAME}.${DOMAIN_NAME}"
echo "------------------------------------------------"
