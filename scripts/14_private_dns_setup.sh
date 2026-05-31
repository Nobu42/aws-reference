#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# Private DNSを関連付けるVPC。
VPC_NAME="sample-vpc"

# 作成するPrivate Hosted Zone名。
# VPC内だけで使う内部DNS名として利用する。
PRIVATE_ZONE_NAME="home"
PRIVATE_ZONE_NAME_DOT="${PRIVATE_ZONE_NAME}."

# DNSレコードを作成する対象リソース名。
BASTION_INSTANCE_NAME="sample-ec2-bastion"
WEB01_INSTANCE_NAME="sample-ec2-web01"
WEB02_INSTANCE_NAME="sample-ec2-web02"
DB_INSTANCE_IDENTIFIER="sample-db"

# 作成するPrivate DNSレコード名。
BASTION_RECORD_NAME="bastion"
WEB01_RECORD_NAME="web01"
WEB02_RECORD_NAME="web02"
DB_RECORD_NAME="db"

# Private DNSのTTL。
TTL="300"

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

# Route 53のHosted Zone IDは "/hostedzone/XXXXXXXX" の形式で返ることがあるため、ID部分だけにする。
normalize_hosted_zone_id() {
  local hosted_zone_id="$1"
  echo "${hosted_zone_id#/hostedzone/}"
}

# 指定したNameタグのrunning EC2が、対象VPC内に1台だけあることを確認してPrivate IPを返す。
# Private DNSに古いEC2や別VPCのEC2を登録しないため、VPC IDでも絞り込む。
get_running_instance_private_ip() {
  local instance_name="$1"
  local instance_count
  local instance_id
  local private_ip

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
  instance_id=$(get_required_value "$instance_name Instance" "$instance_id")

  private_ip=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
  private_ip=$(get_required_value "$instance_name Private IP" "$private_ip")

  echo "$private_ip"
}

# Private Hosted Zone home が現在のVPCに関連付いているか確認し、
# 未関連付けであれば関連付ける。
ensure_private_hosted_zone_association() {
  local associated_count
  local associate_output
  local associate_status

  associated_count=$(aws route53 list-hosted-zones-by-vpc \
    --profile "$PROFILE" \
    --vpc-id "$VPC_ID" \
    --vpc-region "$REGION" \
    --query "length(HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME_DOT\`])" \
    --output text)

  if [ "$associated_count" -eq 1 ]; then
    echo "Private Hosted Zone is already associated with VPC: $VPC_ID"
    return
  elif [ "$associated_count" -gt 1 ]; then
    echo "Error: multiple Private Hosted Zones named $PRIVATE_ZONE_NAME_DOT are associated with $VPC_ID."
    exit 1
  fi

  echo "Associating Private Hosted Zone with VPC: $VPC_ID"

  # 同じVPC関連付けが直前に作成済みの場合、ConflictingDomainExists等が返ることがある。
  # その場合は現在の関連付け状態を再確認し、関連済みなら正常扱いにする。
  set +e
  associate_output=$(aws route53 associate-vpc-with-hosted-zone \
    --profile "$PROFILE" \
    --hosted-zone-id "$PRIVATE_HOSTED_ZONE_ID" \
    --vpc VPCRegion="$REGION",VPCId="$VPC_ID" \
    --comment "Associate $PRIVATE_ZONE_NAME_DOT with $VPC_ID" 2>&1)
  associate_status=$?
  set -e

  if [ "$associate_status" -eq 0 ]; then
    echo "$associate_output"
    return
  fi

  associated_count=$(aws route53 list-hosted-zones-by-vpc \
    --profile "$PROFILE" \
    --vpc-id "$VPC_ID" \
    --vpc-region "$REGION" \
    --query "length(HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME_DOT\`])" \
    --output text)

  if [ "$associated_count" -eq 1 ]; then
    echo "Private Hosted Zone association already exists after retry check."
    return
  fi

  echo "$associate_output"
  exit "$associate_status"
}

echo "=== Caller Identity ==="

# DNSは名前解決に関わるため、操作先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

# Private Hosted Zoneを関連付けるVPCを取得する。
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

echo "VPC ID: $VPC_ID"

echo "=== Check VPC DNS Attributes ==="

# Private Hosted Zoneの名前解決には、VPC側のDNS属性が有効である必要がある。
ENABLE_DNS_SUPPORT=$(aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --query 'EnableDnsSupport.Value' \
  --output text)

ENABLE_DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --query 'EnableDnsHostnames.Value' \
  --output text)

if [ "$ENABLE_DNS_SUPPORT" != "True" ] && [ "$ENABLE_DNS_SUPPORT" != "true" ]; then
  echo "Error: VPC enableDnsSupport is disabled. Private DNS resolution will not work."
  exit 1
fi

if [ "$ENABLE_DNS_HOSTNAMES" != "True" ] && [ "$ENABLE_DNS_HOSTNAMES" != "true" ]; then
  echo "Error: VPC enableDnsHostnames is disabled. Private DNS resolution may not work as expected."
  exit 1
fi

echo "enableDnsSupport: $ENABLE_DNS_SUPPORT"
echo "enableDnsHostnames: $ENABLE_DNS_HOSTNAMES"

echo "=== Create or Get Private Hosted Zone ==="

# Private Hosted Zoneがすでに存在するか確認する。
# Config.PrivateZone == true のものだけを対象にする。
ASSOCIATED_PRIVATE_HOSTED_ZONE_COUNT=$(aws route53 list-hosted-zones-by-vpc \
  --profile "$PROFILE" \
  --vpc-id "$VPC_ID" \
  --vpc-region "$REGION" \
  --query "length(HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME_DOT\`])" \
  --output text)

if [ "$ASSOCIATED_PRIVATE_HOSTED_ZONE_COUNT" -gt 1 ]; then
  echo "Error: multiple Private Hosted Zones named $PRIVATE_ZONE_NAME_DOT are associated with $VPC_ID."
  exit 1
elif [ "$ASSOCIATED_PRIVATE_HOSTED_ZONE_COUNT" -eq 1 ]; then
  ASSOCIATED_PRIVATE_HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-vpc \
    --profile "$PROFILE" \
    --vpc-id "$VPC_ID" \
    --vpc-region "$REGION" \
    --query "HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME_DOT\`].HostedZoneId | [0]" \
    --output text)
  PRIVATE_HOSTED_ZONE_ID=$(normalize_hosted_zone_id "$ASSOCIATED_PRIVATE_HOSTED_ZONE_ID")
  echo "Private Hosted Zone already associated with this VPC: $PRIVATE_HOSTED_ZONE_ID"
else
  PRIVATE_HOSTED_ZONE_COUNT=$(aws route53 list-hosted-zones-by-name \
    --profile "$PROFILE" \
    --dns-name "$PRIVATE_ZONE_NAME_DOT" \
    --query "length(HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`])" \
    --output text)

  if [ "$PRIVATE_HOSTED_ZONE_COUNT" -gt 1 ]; then
    echo "Error: multiple Private Hosted Zones named $PRIVATE_ZONE_NAME_DOT found. Please investigate before continuing."
    exit 1
  fi

  PRIVATE_HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --profile "$PROFILE" \
    --dns-name "$PRIVATE_ZONE_NAME_DOT" \
    --query "HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`].Id | [0]" \
    --output text)

  if [ "$PRIVATE_HOSTED_ZONE_ID" = "None" ] || [ -z "$PRIVATE_HOSTED_ZONE_ID" ]; then
    echo "Private Hosted Zone not found. Creating: $PRIVATE_ZONE_NAME"

    # Private Hosted Zoneを作成し、sample-vpcに関連付ける。
    # CallerReferenceは作成リクエストを一意にするための値。
    PRIVATE_HOSTED_ZONE_ID=$(aws route53 create-hosted-zone \
      --profile "$PROFILE" \
      --name "$PRIVATE_ZONE_NAME" \
      --vpc VPCRegion="$REGION",VPCId="$VPC_ID" \
      --caller-reference "terraform-iac-lab-${PRIVATE_ZONE_NAME}-$(date +%Y%m%d%H%M%S)" \
      --hosted-zone-config Comment="Private hosted zone for learning lab",PrivateZone=true \
      --query 'HostedZone.Id' \
      --output text)

    echo "Private Hosted Zone created: $PRIVATE_HOSTED_ZONE_ID"
  else
    PRIVATE_HOSTED_ZONE_ID=$(normalize_hosted_zone_id "$PRIVATE_HOSTED_ZONE_ID")
    echo "Private Hosted Zone already exists: $PRIVATE_HOSTED_ZONE_ID"
    ensure_private_hosted_zone_association
  fi
fi

# Route 53のHosted Zone IDは "/hostedzone/XXXXXXXX" の形式で返るため、ID部分だけにする。
PRIVATE_HOSTED_ZONE_ID=$(normalize_hosted_zone_id "$PRIVATE_HOSTED_ZONE_ID")

echo "Private Hosted Zone ID: $PRIVATE_HOSTED_ZONE_ID"

echo "=== Get Private IP Addresses ==="

# BastionのPrivate IPを取得する。
BASTION_PRIVATE_IP=$(get_running_instance_private_ip "$BASTION_INSTANCE_NAME")

# Web01のPrivate IPを取得する。
WEB01_PRIVATE_IP=$(get_running_instance_private_ip "$WEB01_INSTANCE_NAME")

# Web02のPrivate IPを取得する。
WEB02_PRIVATE_IP=$(get_running_instance_private_ip "$WEB02_INSTANCE_NAME")

echo "Bastion Private IP: $BASTION_PRIVATE_IP"
echo "Web01 Private IP: $WEB01_PRIVATE_IP"
echo "Web02 Private IP: $WEB02_PRIVATE_IP"

echo "=== Get RDS Endpoint ==="

# RDSのEndpointを取得する。
# db.home はこのEndpointへCNAMEで向ける。
DB_STATUS=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text)
DB_STATUS=$(get_required_value "RDS Status" "$DB_STATUS")

if [ "$DB_STATUS" != "available" ]; then
  echo "Error: RDS instance $DB_INSTANCE_IDENTIFIER is $DB_STATUS, expected available."
  exit 1
fi

DB_VPC_ID=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBSubnetGroup.VpcId' \
  --output text)
DB_VPC_ID=$(get_required_value "RDS VPC ID" "$DB_VPC_ID")

if [ "$DB_VPC_ID" != "$VPC_ID" ]; then
  echo "Error: RDS instance $DB_INSTANCE_IDENTIFIER is in $DB_VPC_ID, expected $VPC_ID."
  exit 1
fi

DB_PUBLICLY_ACCESSIBLE=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].PubliclyAccessible' \
  --output text)
DB_PUBLICLY_ACCESSIBLE=$(get_required_value "RDS PubliclyAccessible" "$DB_PUBLICLY_ACCESSIBLE")

if [ "$DB_PUBLICLY_ACCESSIBLE" != "False" ] && [ "$DB_PUBLICLY_ACCESSIBLE" != "false" ]; then
  echo "Error: RDS instance $DB_INSTANCE_IDENTIFIER is publicly accessible. Please investigate before creating db.home."
  exit 1
fi

DB_ENDPOINT=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

DB_ENDPOINT=$(get_required_value "RDS Endpoint" "$DB_ENDPOINT")

echo "RDS Status: $DB_STATUS"
echo "RDS VPC ID: $DB_VPC_ID"
echo "RDS PubliclyAccessible: $DB_PUBLICLY_ACCESSIBLE"
echo "RDS Endpoint: $DB_ENDPOINT"

echo "=== Create / Update Private DNS Records ==="

# UPSERTを使う。
# レコードがなければ作成、すでにあれば更新する。
# EC2やRDSを作り直してIPやEndpointが変わった場合も、このスクリプトを再実行すれば更新できる。
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Create or update private DNS records for learning lab",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${BASTION_RECORD_NAME}.${PRIVATE_ZONE_NAME}.",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${BASTION_PRIVATE_IP}"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WEB01_RECORD_NAME}.${PRIVATE_ZONE_NAME}.",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${WEB01_PRIVATE_IP}"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WEB02_RECORD_NAME}.${PRIVATE_ZONE_NAME}.",
        "Type": "A",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${WEB02_PRIVATE_IP}"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DB_RECORD_NAME}.${PRIVATE_ZONE_NAME}.",
        "Type": "CNAME",
        "TTL": ${TTL},
        "ResourceRecords": [
          {
            "Value": "${DB_ENDPOINT}"
          }
        ]
      }
    }
  ]
}
EOF
)

CHANGE_ID=$(aws route53 change-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$PRIVATE_HOSTED_ZONE_ID" \
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

echo "=== Describe Created Private DNS Records ==="

# 作成したPrivate DNSレコードを確認する。
aws route53 list-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$PRIVATE_HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name==\`${BASTION_RECORD_NAME}.${PRIVATE_ZONE_NAME}.\` || Name==\`${WEB01_RECORD_NAME}.${PRIVATE_ZONE_NAME}.\` || Name==\`${WEB02_RECORD_NAME}.${PRIVATE_ZONE_NAME}.\` || Name==\`${DB_RECORD_NAME}.${PRIVATE_ZONE_NAME}.\`]" \
  --output table

echo "------------------------------------------------"
echo "Route 53 private DNS setup completed."
echo "Private DNS records:"
echo "  ${BASTION_RECORD_NAME}.${PRIVATE_ZONE_NAME} -> ${BASTION_PRIVATE_IP}"
echo "  ${WEB01_RECORD_NAME}.${PRIVATE_ZONE_NAME}   -> ${WEB01_PRIVATE_IP}"
echo "  ${WEB02_RECORD_NAME}.${PRIVATE_ZONE_NAME}   -> ${WEB02_PRIVATE_IP}"
echo "  ${DB_RECORD_NAME}.${PRIVATE_ZONE_NAME}      -> ${DB_ENDPOINT}"
echo "------------------------------------------------"
echo "Check from EC2 instances in the VPC:"
echo "  dig ${WEB01_RECORD_NAME}.${PRIVATE_ZONE_NAME}"
echo "  dig ${DB_RECORD_NAME}.${PRIVATE_ZONE_NAME}"
echo "------------------------------------------------"
