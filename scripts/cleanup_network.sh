#!/bin/bash
set -euo pipefail

# /Users/nobu/aws-reference/scripts 直下の 01 〜 10、14、19 の作成系スクリプトで
# 作成したネットワークリソースを削除する。
#
# 対象スクリプト:
# - 01_vpc_setup.sh
# - 02_subnet_setup.sh
# - 03_internetgateway_setup.sh
# - 04_nat_gateway_setup.sh
# - 05_route_table_setup.sh
# - 06_security_group_setup.sh
# - 07_bastion_server_setup.sh
# - 08_Web_server_setup.sh
# - 09_LoadBalancer_setup.sh
# - 10_Database_setup.sh
# - 14_private_dns_setup.sh
# - 19_elasticache_setup.sh
#
# 削除対象:
# - Private Hosted Zone home
# - Private DNS Records: bastion.home / web01.home / web02.home / db.home
# - RDS DB Instance
# - DB Subnet Group
# - DB Parameter Group
# - DB Option Group
# - ElastiCache Replication Group
# - ElastiCache Subnet Group
# - Application Load Balancer
# - Target Group
# - Bastion EC2 / Web EC2
# - NAT Gateway
# - NAT Gateway用Elastic IP
# - Custom Route Table
# - Security Group
# - Internet Gateway
# - Subnet
# - VPC
#
# 削除順:
# 1. Application Load Balancerを削除する
# 2. Target Groupを削除する
# 3. RDS DB Instanceを削除する
# 4. RDS DB Instanceがdeletedになるまで待つ
# 5. DB Subnet Group / Parameter Group / Option Groupを削除する
# 6. ElastiCache Replication Groupを削除する
# 7. ElastiCache Replication Groupがdeletedになるまで待つ
# 8. ElastiCache Subnet Groupを削除する
# 9. Private Hosted Zone home のカスタムレコードを削除する
# 10. Private Hosted Zone home を削除する
# 11. Bastion EC2 / Web EC2をterminateする
# 12. EC2がterminatedになるまで待つ
# 13. NAT Gatewayを削除する
# 14. NAT Gatewayがdeletedになるまで待つ
# 15. Elastic IPを解放する
# 16. Custom Route Tableの関連付けを解除して削除する
# 17. Security Groupを削除する
# 18. Internet GatewayをVPCからdetachして削除する
# 19. Subnetを削除する
# 20. VPCを削除する
#
# 注意:
# - NAT GatewayとElastic IPは課金対象である。
# - このスクリプトは実AWSリソースを削除する。
# - 実行前にCaller Identityと対象VPCを必ず確認する。
# - S3、Public DNS、ACM、SESなどは対象外である。
# - Private Hosted Zone home は日次ラボ用の内部DNSとして削除対象に含める。
# - Key Pairはpemファイルとの対応が重要なため、このcleanupでは削除しない。

# 使用するAWS CLIプロファイルとリージョン。
PROFILE="learning"
REGION="ap-northeast-1"

# 削除対象のVPC名。
VPC_NAME="sample-vpc"

# 削除対象のPrivate Hosted Zone名。
PRIVATE_ZONE_NAME="home"
PRIVATE_ZONE_NAME_DOT="${PRIVATE_ZONE_NAME}."

# 14_private_dns_setup.sh で作成するPrivate DNSレコード。
# SOA / NS はRoute 53標準レコードのため削除対象にしない。
PRIVATE_DNS_RECORDS=(
  "bastion:A"
  "web01:A"
  "web02:A"
  "db:CNAME"
)

# 削除対象のSubnet名。
SUBNET_NAMES=(
  "sample-subnet-public01"
  "sample-subnet-public02"
  "sample-subnet-private01"
  "sample-subnet-private02"
)

# 削除対象のEC2 Nameタグ。
INSTANCE_NAMES=(
  "sample-ec2-bastion"
  "sample-ec2-web01"
  "sample-ec2-web02"
)

# 削除対象のALB名。
LOAD_BALANCER_NAMES=(
  "sample-elb"
)

# 削除対象のTarget Group名。
TARGET_GROUP_NAMES=(
  "sample-tg"
)

# 削除対象のRDS関連リソース名。
DB_INSTANCE_IDENTIFIERS=(
  "sample-db"
)

DB_SUBNET_GROUP_NAMES=(
  "sample-db-subnet"
)

DB_PARAMETER_GROUP_NAMES=(
  "sample-db-pg"
)

DB_OPTION_GROUP_NAMES=(
  "sample-db-og"
)

# 削除対象のElastiCache関連リソース名。
ELASTICACHE_REPLICATION_GROUP_IDS=(
  "sample-elasticache"
)

ELASTICACHE_SUBNET_GROUP_NAMES=(
  "sample-elasticache-sg"
)

# 削除対象のNAT Gateway名。
NAT_GATEWAY_NAMES=(
  "sample-ngw-01"
  "sample-ngw-02"
)

# 削除対象のNAT Gateway用Elastic IP名。
EIP_NAMES=(
  "sample-eip-ngw-01"
  "sample-eip-ngw-02"
)

# 削除対象のカスタムRoute Table名。
# main route tableはVPC標準リソースのため、単体削除しない。
ROUTE_TABLE_NAMES=(
  "sample-rt-public"
  "sample-rt-private01"
  "sample-rt-private02"
)

# 削除対象のSecurity Group名。
# default Security GroupはVPC標準リソースのため、単体削除しない。
SECURITY_GROUP_NAMES=(
  "sample-sg-db"
  "sample-sg-elasticache"
  "sample-sg-web"
  "sample-sg-bastion"
  "sample-sg-elb"
)

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで削除を行うため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# AWS CLI v2のページャーを、このcleanupスクリプト内だけ無効化する。
# 削除処理の途中でlessなどが起動し、キー入力待ちになることを防ぐ。
export AWS_PAGER=""

# cleanupは確認出力やwait処理が多いため、このスクリプト内のawsコマンドを
# すべて --no-cli-pager 付きで実行する。
aws() {
  command aws --no-cli-pager "$@"
}

# AWS CLIの --output text は、値をスペースではなくタブ区切りで返すことがある。
# 削除対象IDをまとめる時は空白文字全般で分割し、重複を取り除く。
normalize_id_list() {
  printf '%s\n' "$@" | tr '[:space:]' '\n' | sed '/^$/d' | sed 's#^/hostedzone/##' | sort -u | tr '\n' ' '
}

# ALBを削除した直後は、Target GroupへのListener参照が短時間残ることがある。
# ResourceInUse の場合だけ少し待って再試行し、伝播待ちで残るTarget Groupを減らす。
delete_target_group_with_retry() {
  local target_group_arn="$1"
  local max_attempts=18
  local attempt=1
  local delete_output
  local delete_status

  while [ "$attempt" -le "$max_attempts" ]; do
    set +e
    delete_output=$(aws elbv2 delete-target-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --target-group-arn "$target_group_arn" 2>&1)
    delete_status=$?
    set -e

    if [ "$delete_status" -eq 0 ]; then
      echo "Target Group deleted: $target_group_arn"
      return 0
    fi

    case "$delete_output" in
      *ResourceInUse*)
        echo "Target Group still in use. Retrying in 10 seconds ($attempt/$max_attempts): $target_group_arn"
        sleep 10
        attempt=$((attempt + 1))
        ;;
      *)
        echo "$delete_output"
        echo "Skip: could not delete Target Group $target_group_arn"
        return 0
        ;;
    esac
  done

  echo "Skip: Target Group is still in use after retries: $target_group_arn"
  return 0
}

echo "================================================"
echo "Cleanup network resources created by 01-10 and 14 scripts."
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "VPC Name: $VPC_NAME"
echo "================================================"

echo "=== Caller Identity ==="

# いま操作しているAWSアカウントとIAMユーザーを確認する。
# 削除系コマンドを実行する前に、想定したアカウントか必ず確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Confirmation ==="

# 誤操作を避けるため、明示的な入力がない限り削除しない。
# 自動実行したい場合は、SKIP_CONFIRM=true を付けて実行する。
if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  read -r -p "Type 'delete' to delete network resources in $VPC_NAME: " CONFIRM

  if [ "$CONFIRM" != "delete" ]; then
    echo "Canceled."
    exit 0
  fi
fi

echo "=== Get VPC ID ==="

# Nameタグが sample-vpc のVPCを探し、VPC IDだけを取得する。
# VPCがない場合でも、タグ付きElastic IPだけ残っている可能性があるため、
# 後続のElastic IP確認はVPC有無に関係なく実行する。
# 同じNameタグのVPCが複数ある場合、どれを削除すべきか判断できないため停止する。
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text)

if [ "$VPC_COUNT" -gt 1 ]; then
  echo "Error: multiple VPCs found with Name tag $VPC_NAME. Please investigate duplicates before cleanup."
  exit 1
fi

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  VPC_ID=""
  echo "VPC not found. VPC-related resources may already be deleted."
else
  echo "Target VPC ID: $VPC_ID"
fi

echo "=== Delete Load Balancers ==="

# 09_LoadBalancer_setup.sh で作成したALBを削除する。
# ALBが残っていると、関連付いたSecurity GroupやVPCを削除できない。
if [ -n "$VPC_ID" ]; then
  LOAD_BALANCER_ARNS=""

  for load_balancer_name in "${LOAD_BALANCER_NAMES[@]}"; do
    FOUND_LB_ARNS=$(aws elbv2 describe-load-balancers \
      --profile "$PROFILE" \
      --region "$REGION" \
      --names "$load_balancer_name" \
      --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
      --output text 2>/dev/null || true)

    LOAD_BALANCER_ARNS="$LOAD_BALANCER_ARNS $FOUND_LB_ARNS"
  done

  LOAD_BALANCER_ARNS=$(normalize_id_list "$LOAD_BALANCER_ARNS")

  if [ -n "$LOAD_BALANCER_ARNS" ]; then
    for load_balancer_arn in $LOAD_BALANCER_ARNS; do
      echo "Deleting Load Balancer: $load_balancer_arn"
      aws elbv2 delete-load-balancer \
        --profile "$PROFILE" \
        --region "$REGION" \
        --load-balancer-arn "$load_balancer_arn"
    done

    echo "Waiting for Load Balancers to be deleted..."
    aws elbv2 wait load-balancers-deleted \
      --profile "$PROFILE" \
      --region "$REGION" \
      --load-balancer-arns $LOAD_BALANCER_ARNS
  else
    echo "No Load Balancers found."
  fi
else
  echo "Skip Load Balancer deletion because VPC was not found."
fi

echo "=== Delete Target Groups ==="

# Target GroupはALB Listenerから参照されている間は削除できないため、
# ALB削除完了後に削除する。
for target_group_name in "${TARGET_GROUP_NAMES[@]}"; do
  if [ -n "$VPC_ID" ]; then
    TARGET_GROUP_ARNS=$(aws elbv2 describe-target-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --names "$target_group_name" \
      --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
      --output text 2>/dev/null || true)
  else
    # VPC削除後にTarget Groupだけ残った場合でも後始末できるように、
    # VPC IDが取れない時はTarget Group名で取得する。
    TARGET_GROUP_ARNS=$(aws elbv2 describe-target-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --names "$target_group_name" \
      --query 'TargetGroups[].TargetGroupArn' \
      --output text 2>/dev/null || true)
  fi

  TARGET_GROUP_ARNS=$(normalize_id_list "$TARGET_GROUP_ARNS")

  if [ -z "$TARGET_GROUP_ARNS" ]; then
    echo "Target Group not found: $target_group_name"
    continue
  fi

  for target_group_arn in $TARGET_GROUP_ARNS; do
    echo "Deleting Target Group: $target_group_name ($target_group_arn)"
    delete_target_group_with_retry "$target_group_arn"
  done
done

echo "=== Delete RDS DB Instances ==="

# 10_Database_setup.sh で作成したRDS DB Instanceを削除する。
# RDSが残っていると、DB Subnet GroupやDB Security Group、Subnetを削除できない。
for db_instance_identifier in "${DB_INSTANCE_IDENTIFIERS[@]}"; do
  DB_STATUS=$(aws rds describe-db-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$db_instance_identifier" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || true)

  if [ "$DB_STATUS" = "None" ] || [ -z "$DB_STATUS" ]; then
    echo "RDS DB Instance not found: $db_instance_identifier"
    continue
  fi

  if [ "$DB_STATUS" = "deleting" ]; then
    echo "RDS DB Instance is already deleting: $db_instance_identifier"
  else
    echo "Deleting RDS DB Instance: $db_instance_identifier ($DB_STATUS)"
    aws rds delete-db-instance \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$db_instance_identifier" \
      --skip-final-snapshot \
      --delete-automated-backups
  fi

  echo "Waiting for RDS DB Instance to be deleted: $db_instance_identifier"
  aws rds wait db-instance-deleted \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$db_instance_identifier"
done

echo "=== Delete RDS DB Subnet Groups ==="

# DB Subnet GroupはRDS DB Instance削除後に削除する。
for db_subnet_group_name in "${DB_SUBNET_GROUP_NAMES[@]}"; do
  DB_SUBNET_GROUP_EXISTS=$(aws rds describe-db-subnet-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-subnet-group-name "$db_subnet_group_name" \
    --query 'length(DBSubnetGroups)' \
    --output text 2>/dev/null || true)

  if [ "$DB_SUBNET_GROUP_EXISTS" = "None" ] || [ -z "$DB_SUBNET_GROUP_EXISTS" ] || [ "$DB_SUBNET_GROUP_EXISTS" -eq 0 ]; then
    echo "DB Subnet Group not found: $db_subnet_group_name"
    continue
  fi

  echo "Deleting DB Subnet Group: $db_subnet_group_name"
  aws rds delete-db-subnet-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-subnet-group-name "$db_subnet_group_name"
done

echo "=== Delete RDS DB Parameter Groups ==="

# DB Parameter GroupはDB Instance削除後に削除する。
for db_parameter_group_name in "${DB_PARAMETER_GROUP_NAMES[@]}"; do
  DB_PARAMETER_GROUP_EXISTS=$(aws rds describe-db-parameter-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-parameter-group-name "$db_parameter_group_name" \
    --query 'length(DBParameterGroups)' \
    --output text 2>/dev/null || true)

  if [ "$DB_PARAMETER_GROUP_EXISTS" = "None" ] || [ -z "$DB_PARAMETER_GROUP_EXISTS" ] || [ "$DB_PARAMETER_GROUP_EXISTS" -eq 0 ]; then
    echo "DB Parameter Group not found: $db_parameter_group_name"
    continue
  fi

  echo "Deleting DB Parameter Group: $db_parameter_group_name"
  aws rds delete-db-parameter-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-parameter-group-name "$db_parameter_group_name"
done

echo "=== Delete RDS DB Option Groups ==="

# DB Option GroupはDB Instance削除後に削除する。
for db_option_group_name in "${DB_OPTION_GROUP_NAMES[@]}"; do
  DB_OPTION_GROUP_EXISTS=$(aws rds describe-option-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --option-group-name "$db_option_group_name" \
    --query 'length(OptionGroupsList)' \
    --output text 2>/dev/null || true)

  if [ "$DB_OPTION_GROUP_EXISTS" = "None" ] || [ -z "$DB_OPTION_GROUP_EXISTS" ] || [ "$DB_OPTION_GROUP_EXISTS" -eq 0 ]; then
    echo "DB Option Group not found: $db_option_group_name"
    continue
  fi

  echo "Deleting DB Option Group: $db_option_group_name"
  aws rds delete-option-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --option-group-name "$db_option_group_name"
done

echo "=== Delete ElastiCache Replication Groups ==="

# 19_elasticache_setup.sh で作成したElastiCache Replication Groupを削除する。
# ElastiCacheが残っていると、Subnet Group、Security Group、Subnet、VPCを削除できない。
for replication_group_id in "${ELASTICACHE_REPLICATION_GROUP_IDS[@]}"; do
  REPLICATION_GROUP_STATUS=$(aws elasticache describe-replication-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --replication-group-id "$replication_group_id" \
    --query 'ReplicationGroups[0].Status' \
    --output text 2>/dev/null || true)

  if [ "$REPLICATION_GROUP_STATUS" = "None" ] || [ -z "$REPLICATION_GROUP_STATUS" ]; then
    echo "ElastiCache Replication Group not found: $replication_group_id"
    continue
  fi

  if [ "$REPLICATION_GROUP_STATUS" = "deleting" ]; then
    echo "ElastiCache Replication Group is already deleting: $replication_group_id"
  else
    echo "Deleting ElastiCache Replication Group: $replication_group_id ($REPLICATION_GROUP_STATUS)"
    aws elasticache delete-replication-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --replication-group-id "$replication_group_id" \
      --no-retain-primary-cluster >/dev/null
  fi

  echo "Waiting for ElastiCache Replication Group to be deleted: $replication_group_id"
  aws elasticache wait replication-group-deleted \
    --profile "$PROFILE" \
    --region "$REGION" \
    --replication-group-id "$replication_group_id"
done

echo "=== Delete ElastiCache Subnet Groups ==="

# ElastiCache Subnet GroupはReplication Group削除後に削除する。
for elasticache_subnet_group_name in "${ELASTICACHE_SUBNET_GROUP_NAMES[@]}"; do
  ELASTICACHE_SUBNET_GROUP_EXISTS=$(aws elasticache describe-cache-subnet-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cache-subnet-group-name "$elasticache_subnet_group_name" \
    --query 'length(CacheSubnetGroups)' \
    --output text 2>/dev/null || true)

  if [ "$ELASTICACHE_SUBNET_GROUP_EXISTS" = "None" ] || [ -z "$ELASTICACHE_SUBNET_GROUP_EXISTS" ] || [ "$ELASTICACHE_SUBNET_GROUP_EXISTS" -eq 0 ]; then
    echo "ElastiCache Subnet Group not found: $elasticache_subnet_group_name"
    continue
  fi

  echo "Deleting ElastiCache Subnet Group: $elasticache_subnet_group_name"
  aws elasticache delete-cache-subnet-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cache-subnet-group-name "$elasticache_subnet_group_name"
done

echo "=== Delete Private Hosted Zone home ==="

# 14_private_dns_setup.sh で作成したPrivate Hosted Zoneと内部DNSレコードを削除する。
# Route 53のHosted Zone削除は、SOA / NS以外のレコードが残っていると失敗する。
# そのため、先に bastion.home / web01.home / web02.home / db.home を削除する。
PRIVATE_HOSTED_ZONE_IDS=""

if [ -n "$VPC_ID" ]; then
  ASSOCIATED_PRIVATE_ZONE_IDS=$(aws route53 list-hosted-zones-by-vpc \
    --profile "$PROFILE" \
    --vpc-id "$VPC_ID" \
    --vpc-region "$REGION" \
    --query "HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME_DOT\`].HostedZoneId" \
    --output text 2>/dev/null || true)

  PRIVATE_HOSTED_ZONE_IDS="$PRIVATE_HOSTED_ZONE_IDS $ASSOCIATED_PRIVATE_ZONE_IDS"
fi

if [ -z "$(normalize_id_list "$PRIVATE_HOSTED_ZONE_IDS")" ]; then
  PRIVATE_ZONE_COUNT=$(aws route53 list-hosted-zones-by-name \
    --profile "$PROFILE" \
    --dns-name "$PRIVATE_ZONE_NAME_DOT" \
    --query "length(HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`])" \
    --output text 2>/dev/null || true)

  if [ "$PRIVATE_ZONE_COUNT" = "None" ] || [ -z "$PRIVATE_ZONE_COUNT" ] || [ "$PRIVATE_ZONE_COUNT" -eq 0 ]; then
    echo "Private Hosted Zone not found: $PRIVATE_ZONE_NAME_DOT"
  elif [ "$PRIVATE_ZONE_COUNT" -gt 1 ]; then
    echo "Error: multiple Private Hosted Zones named $PRIVATE_ZONE_NAME_DOT found. Please investigate before cleanup."
    exit 1
  else
    FOUND_PRIVATE_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
      --profile "$PROFILE" \
      --dns-name "$PRIVATE_ZONE_NAME_DOT" \
      --query "HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`].Id | [0]" \
      --output text)
    PRIVATE_HOSTED_ZONE_IDS="$PRIVATE_HOSTED_ZONE_IDS $FOUND_PRIVATE_ZONE_ID"
  fi
fi

PRIVATE_HOSTED_ZONE_IDS=$(normalize_id_list "$PRIVATE_HOSTED_ZONE_IDS")

for private_hosted_zone_id in $PRIVATE_HOSTED_ZONE_IDS; do
  ZONE_NAME=$(aws route53 get-hosted-zone \
    --profile "$PROFILE" \
    --id "$private_hosted_zone_id" \
    --query 'HostedZone.Name' \
    --output text 2>/dev/null || true)

  ZONE_PRIVATE=$(aws route53 get-hosted-zone \
    --profile "$PROFILE" \
    --id "$private_hosted_zone_id" \
    --query 'HostedZone.Config.PrivateZone' \
    --output text 2>/dev/null || true)

  if [ "$ZONE_NAME" != "$PRIVATE_ZONE_NAME_DOT" ] || { [ "$ZONE_PRIVATE" != "True" ] && [ "$ZONE_PRIVATE" != "true" ]; }; then
    echo "Skip unexpected hosted zone: $private_hosted_zone_id ($ZONE_NAME / Private=$ZONE_PRIVATE)"
    continue
  fi

  VPC_ASSOC_COUNT=$(aws route53 get-hosted-zone \
    --profile "$PROFILE" \
    --id "$private_hosted_zone_id" \
    --query 'length(VPCs)' \
    --output text)

  if [ "$VPC_ASSOC_COUNT" -gt 1 ]; then
    if [ -n "$VPC_ID" ]; then
      CURRENT_VPC_ASSOC_COUNT=$(aws route53 get-hosted-zone \
        --profile "$PROFILE" \
        --id "$private_hosted_zone_id" \
        --query "length(VPCs[?VPCId==\`$VPC_ID\` && VPCRegion==\`$REGION\`])" \
        --output text)

      if [ "$CURRENT_VPC_ASSOC_COUNT" -eq 1 ]; then
        echo "Disassociating Private Hosted Zone from current VPC: $private_hosted_zone_id -> $VPC_ID"
        aws route53 disassociate-vpc-from-hosted-zone \
          --profile "$PROFILE" \
          --hosted-zone-id "$private_hosted_zone_id" \
          --vpc VPCRegion="$REGION",VPCId="$VPC_ID" \
          --comment "Disassociate daily lab VPC before cleanup" >/dev/null
      fi
    fi

    echo "Skip deleting shared Private Hosted Zone: $private_hosted_zone_id"
    echo "Reason: it is associated with $VPC_ASSOC_COUNT VPCs."
    continue
  fi

  # Private Hosted Zoneに関連付くVPCが1つだけの場合、Route 53は最後のVPC関連付け解除を許可しない。
  # この場合は、カスタムレコードを削除した後にHosted Zone自体を削除することで関連付けも消える。
  if [ "$VPC_ASSOC_COUNT" -eq 1 ] && [ -n "$VPC_ID" ]; then
    CURRENT_VPC_ASSOC_COUNT=$(aws route53 get-hosted-zone \
      --profile "$PROFILE" \
      --id "$private_hosted_zone_id" \
      --query "length(VPCs[?VPCId==\`$VPC_ID\` && VPCRegion==\`$REGION\`])" \
      --output text)

    if [ "$CURRENT_VPC_ASSOC_COUNT" -eq 0 ]; then
      echo "Warning: Private Hosted Zone $private_hosted_zone_id is not associated with current VPC $VPC_ID."
      echo "It is the only Private Hosted Zone named $PRIVATE_ZONE_NAME_DOT, so cleanup treats it as a daily lab leftover."
    fi
  fi

  for private_record in "${PRIVATE_DNS_RECORDS[@]}"; do
    RECORD_SHORT_NAME="${private_record%%:*}"
    RECORD_TYPE="${private_record##*:}"
    RECORD_NAME="${RECORD_SHORT_NAME}.${PRIVATE_ZONE_NAME_DOT}"

    RECORD_TTL=$(aws route53 list-resource-record-sets \
      --profile "$PROFILE" \
      --hosted-zone-id "$private_hosted_zone_id" \
      --query "ResourceRecordSets[?Name==\`$RECORD_NAME\` && Type==\`$RECORD_TYPE\`].TTL | [0]" \
      --output text)

    RECORD_VALUES=$(aws route53 list-resource-record-sets \
      --profile "$PROFILE" \
      --hosted-zone-id "$private_hosted_zone_id" \
      --query "ResourceRecordSets[?Name==\`$RECORD_NAME\` && Type==\`$RECORD_TYPE\`].ResourceRecords[].Value" \
      --output text)

    if [ "$RECORD_TTL" = "None" ] || [ -z "$RECORD_TTL" ] || [ "$RECORD_VALUES" = "None" ] || [ -z "$RECORD_VALUES" ]; then
      echo "Private DNS record not found: $RECORD_NAME $RECORD_TYPE"
      continue
    fi

    RESOURCE_RECORDS_JSON=""
    for record_value in $RECORD_VALUES; do
      RESOURCE_RECORDS_JSON="${RESOURCE_RECORDS_JSON}{\"Value\":\"$record_value\"},"
    done
    RESOURCE_RECORDS_JSON="[${RESOURCE_RECORDS_JSON%,}]"

    CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Delete private DNS record for daily lab cleanup",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME",
        "Type": "$RECORD_TYPE",
        "TTL": $RECORD_TTL,
        "ResourceRecords": $RESOURCE_RECORDS_JSON
      }
    }
  ]
}
EOF
)

    echo "Deleting Private DNS record: $RECORD_NAME $RECORD_TYPE"
    PRIVATE_RECORD_CHANGE_ID=$(aws route53 change-resource-record-sets \
      --profile "$PROFILE" \
      --hosted-zone-id "$private_hosted_zone_id" \
      --change-batch "$CHANGE_BATCH" \
      --query 'ChangeInfo.Id' \
      --output text)

    aws route53 wait resource-record-sets-changed \
      --profile "$PROFILE" \
      --id "$PRIVATE_RECORD_CHANGE_ID"
  done

  echo "Deleting Private Hosted Zone: $private_hosted_zone_id"
  aws route53 delete-hosted-zone \
    --profile "$PROFILE" \
    --id "$private_hosted_zone_id" >/dev/null
done

echo "=== Terminate EC2 Instances ==="

# 07_bastion_server_setup.sh と 08_Web_server_setup.sh で作成したEC2を終了する。
# EC2が残っていると、Security GroupやSubnetを削除できないため、先にterminateする。
if [ -n "$VPC_ID" ]; then
  INSTANCE_IDS=""

  for instance_name in "${INSTANCE_NAMES[@]}"; do
    FOUND_INSTANCE_IDS=$(aws ec2 describe-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$instance_name" Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text)

    INSTANCE_IDS="$INSTANCE_IDS $FOUND_INSTANCE_IDS"
  done

  INSTANCE_IDS=$(normalize_id_list "$INSTANCE_IDS")

  if [ -n "$INSTANCE_IDS" ]; then
    for instance_id in $INSTANCE_IDS; do
      echo "Terminating EC2 instance: $instance_id"
      aws ec2 terminate-instances \
        --profile "$PROFILE" \
        --region "$REGION" \
        --instance-ids "$instance_id" >/dev/null
    done

    echo "Waiting for EC2 instances to be terminated..."
    aws ec2 wait instance-terminated \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids $INSTANCE_IDS
  else
    echo "No EC2 instances found."
  fi
else
  echo "Skip EC2 termination because VPC was not found."
fi

echo "=== Collect Elastic IP Allocation IDs ==="

# NAT Gateway削除後にElastic IPを解放するため、先にAllocation IDを控える。
# NAT Gatewayに紐づくEIPと、Nameタグが残っているEIPの両方を候補にする。
EIP_ALLOC_IDS=""

if [ -n "$VPC_ID" ]; then
  NAT_EIP_ALLOC_IDS=$(aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filter Name=vpc-id,Values="$VPC_ID" Name=state,Values=pending,available \
    --query 'NatGateways[].NatGatewayAddresses[].AllocationId' \
    --output text)

  EIP_ALLOC_IDS="$EIP_ALLOC_IDS $NAT_EIP_ALLOC_IDS"
fi

for eip_name in "${EIP_NAMES[@]}"; do
  TAGGED_ALLOC_IDS=$(aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=tag:Name,Values="$eip_name" \
    --query 'Addresses[].AllocationId' \
    --output text)

  EIP_ALLOC_IDS="$EIP_ALLOC_IDS $TAGGED_ALLOC_IDS"
done

# 重複したAllocation IDを削除する。
EIP_ALLOC_IDS=$(normalize_id_list "$EIP_ALLOC_IDS")

if [ -n "$EIP_ALLOC_IDS" ]; then
  echo "Elastic IP Allocation IDs: $EIP_ALLOC_IDS"
else
  echo "No Elastic IP Allocation IDs found."
fi

echo "=== Delete NAT Gateways ==="

# NAT GatewayはSubnetやElastic IPに依存するため、先に削除する。
# pending / available のNAT Gatewayを削除対象とする。
# deleted 状態のNAT Gatewayは削除済み履歴として表示されることがあるため、対象外にする。
NAT_GATEWAY_IDS=""

if [ -n "$VPC_ID" ]; then
  for nat_gateway_name in "${NAT_GATEWAY_NAMES[@]}"; do
    FOUND_NAT_IDS=$(aws ec2 describe-nat-gateways \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filter Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$nat_gateway_name" Name=state,Values=pending,available \
      --query 'NatGateways[].NatGatewayId' \
      --output text)

    NAT_GATEWAY_IDS="$NAT_GATEWAY_IDS $FOUND_NAT_IDS"
  done

  NAT_GATEWAY_IDS=$(normalize_id_list "$NAT_GATEWAY_IDS")

  if [ -n "$NAT_GATEWAY_IDS" ]; then
    for nat_gateway_id in $NAT_GATEWAY_IDS; do
      echo "Deleting NAT Gateway: $nat_gateway_id"
      aws ec2 delete-nat-gateway \
        --profile "$PROFILE" \
        --region "$REGION" \
        --nat-gateway-id "$nat_gateway_id" >/dev/null
    done

    echo "Waiting for NAT Gateways to be deleted..."
    aws ec2 wait nat-gateway-deleted \
      --profile "$PROFILE" \
      --region "$REGION" \
      --nat-gateway-ids $NAT_GATEWAY_IDS
  else
    echo "No NAT Gateways found."
  fi
else
  echo "Skip NAT Gateway deletion because VPC was not found."
fi

echo "=== Release Elastic IPs ==="

# NAT Gateway削除後にElastic IPを解放する。
# NAT Gatewayが削除される前はEIPが関連付いたままになるため、
# 必ずNAT Gateway deleted待機後にrelease-addressを実行する。
if [ -n "$EIP_ALLOC_IDS" ]; then
  for allocation_id in $EIP_ALLOC_IDS; do
    ASSOCIATION_ID=$(aws ec2 describe-addresses \
      --profile "$PROFILE" \
      --region "$REGION" \
      --allocation-ids "$allocation_id" \
      --query 'Addresses[0].AssociationId' \
      --output text 2>/dev/null || true)

    if [ "$ASSOCIATION_ID" != "None" ] && [ -n "$ASSOCIATION_ID" ]; then
      echo "Skip releasing associated EIP: $allocation_id ($ASSOCIATION_ID)"
      continue
    fi

    echo "Releasing Elastic IP: $allocation_id"
    aws ec2 release-address \
      --profile "$PROFILE" \
      --region "$REGION" \
      --allocation-id "$allocation_id" || echo "Skip: could not release $allocation_id"
  done
else
  echo "No Elastic IPs to release."
fi

echo "=== Delete Custom Route Tables ==="

# 05_route_table_setup.sh で作成したカスタムRoute Tableを削除する。
# Route TableはSubnetとの明示的な関連付けが残っていると削除できないため、
# 先に関連付けを解除してから削除する。
# main route tableはVPC削除時に一緒に削除されるため、ここでは削除対象にしない。
if [ -n "$VPC_ID" ]; then
  for route_table_name in "${ROUTE_TABLE_NAMES[@]}"; do
    ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$route_table_name" \
      --query 'RouteTables[].RouteTableId' \
      --output text)

    if [ -z "$ROUTE_TABLE_IDS" ]; then
      echo "Route Table not found: $route_table_name"
      continue
    fi

    for route_table_id in $ROUTE_TABLE_IDS; do
      IS_MAIN=$(aws ec2 describe-route-tables \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-ids "$route_table_id" \
        --query 'length(RouteTables[0].Associations[?Main==`true`])' \
        --output text)

      if [ "$IS_MAIN" -gt 0 ]; then
        echo "Skip main Route Table: $route_table_id"
        continue
      fi

      ASSOCIATION_IDS=$(aws ec2 describe-route-tables \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-ids "$route_table_id" \
        --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' \
        --output text)

      for association_id in $ASSOCIATION_IDS; do
        echo "Disassociating Route Table association: $association_id"
        aws ec2 disassociate-route-table \
          --profile "$PROFILE" \
          --region "$REGION" \
          --association-id "$association_id"
      done

      echo "Deleting Route Table: $route_table_name ($route_table_id)"
      aws ec2 delete-route-table \
        --profile "$PROFILE" \
        --region "$REGION" \
        --route-table-id "$route_table_id"
    done
  done
else
  echo "Skip Route Table deletion because VPC was not found."
fi

echo "=== Delete Security Groups ==="

# 06_security_group_setup.sh と 08_Web_server_setup.sh で作成したSecurity Groupを削除する。
# EC2やALBなどに関連付いているSecurity Groupは削除できない。
# Web SGはBastion SG / ELB SGを参照するため、先にWeb SGを削除する。
if [ -n "$VPC_ID" ]; then
  for security_group_name in "${SECURITY_GROUP_NAMES[@]}"; do
    SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$security_group_name" \
      --query 'SecurityGroups[].GroupId' \
      --output text)

    if [ -z "$SECURITY_GROUP_IDS" ]; then
      echo "Security Group not found: $security_group_name"
      continue
    fi

    for security_group_id in $SECURITY_GROUP_IDS; do
      GROUP_NAME=$(aws ec2 describe-security-groups \
        --profile "$PROFILE" \
        --region "$REGION" \
        --group-ids "$security_group_id" \
        --query 'SecurityGroups[0].GroupName' \
        --output text)

      if [ "$GROUP_NAME" = "default" ]; then
        echo "Skip default Security Group: $security_group_id"
        continue
      fi

      echo "Deleting Security Group: $security_group_name ($security_group_id)"
      aws ec2 delete-security-group \
        --profile "$PROFILE" \
        --region "$REGION" \
        --group-id "$security_group_id"
    done
  done
else
  echo "Skip Security Group deletion because VPC was not found."
fi

echo "=== Detach and Delete Internet Gateway ==="

# Internet GatewayはVPCにアタッチされたままでは削除できない。
# 先にdetachし、その後deleteする。
if [ -n "$VPC_ID" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=attachment.vpc-id,Values="$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)

  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    echo "Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID" \
      --vpc-id "$VPC_ID"

    echo "Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID"
  else
    echo "No Internet Gateway attached to VPC."
  fi
else
  echo "Skip Internet Gateway deletion because VPC was not found."
fi

echo "=== Delete Subnets ==="

# Subnetは、NAT Gatewayなどの依存リソースが残っていると削除できない。
# ここまででNAT GatewayとInternet Gatewayを削除した後、Nameタグで対象Subnetだけ削除する。
if [ -n "$VPC_ID" ]; then
  for subnet_name in "${SUBNET_NAMES[@]}"; do
    SUBNET_ID=$(aws ec2 describe-subnets \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$subnet_name" \
      --query 'Subnets[0].SubnetId' \
      --output text)

    if [ "$SUBNET_ID" != "None" ] && [ -n "$SUBNET_ID" ]; then
      echo "Deleting Subnet: $subnet_name ($SUBNET_ID)"
      aws ec2 delete-subnet \
        --profile "$PROFILE" \
        --region "$REGION" \
        --subnet-id "$SUBNET_ID"
    else
      echo "Subnet not found: $subnet_name"
    fi
  done
else
  echo "Skip Subnet deletion because VPC was not found."
fi

echo "=== Delete VPC ==="

# SubnetやInternet Gatewayなどの依存リソースを削除した後、最後にVPCを削除する。
# default Security Group、default Network ACL、Main Route TableはVPC削除時に一緒に削除される。
if [ -n "$VPC_ID" ]; then
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-id "$VPC_ID"
else
  echo "Skip VPC deletion because VPC was not found."
fi

echo "=== Cleanup Verification ==="

# 削除後の残存確認を行う。
# 空の表またはNoneであれば、01〜04で作成した主なリソースは削除されている。
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table

aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[?State!=`deleted`].{ID:NatGatewayId,Name:Tags[?Key==`Name`].Value|[0],State:State,VpcId:VpcId}' \
  --output table

aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-rt-public,sample-rt-private01,sample-rt-private02 \
  --query 'RouteTables[*].{ID:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],VpcId:VpcId}' \
  --output table

aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-ec2-bastion,sample-ec2-web01,sample-ec2-web02 Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,VpcId:VpcId}' \
  --output table

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-name,Values=sample-sg-db,sample-sg-web,sample-sg-bastion,sample-sg-elb \
  --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName,VpcId:VpcId}' \
  --output table

aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "DBInstances[?DBInstanceIdentifier=='sample-db'].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Public:PubliclyAccessible}" \
  --output table

aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name sample-db-subnet \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId}' \
  --output table 2>/dev/null || true

aws rds describe-db-parameter-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name sample-db-pg \
  --query 'DBParameterGroups[*].{Name:DBParameterGroupName,Family:DBParameterGroupFamily}' \
  --output table 2>/dev/null || true

aws rds describe-option-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --option-group-name sample-db-og \
  --query 'OptionGroupsList[*].{Name:OptionGroupName,Engine:EngineName,MajorEngineVersion:MajorEngineVersion}' \
  --output table 2>/dev/null || true

aws elasticache describe-replication-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --replication-group-id sample-elasticache \
  --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,ClusterEnabled:ClusterEnabled}' \
  --output table 2>/dev/null || true

aws elasticache describe-cache-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-subnet-group-name sample-elasticache-sg \
  --query 'CacheSubnetGroups[*].{Name:CacheSubnetGroupName,VpcId:VpcId}' \
  --output table 2>/dev/null || true

aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names sample-elb \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,VpcId:VpcId}' \
  --output table 2>/dev/null || true

aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names sample-tg \
  --query 'TargetGroups[*].{Name:TargetGroupName,Arn:TargetGroupArn,VpcId:VpcId,Port:Port,Protocol:Protocol}' \
  --output table 2>/dev/null || true

aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$PRIVATE_ZONE_NAME_DOT" \
  --query "HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`].{ID:Id,Name:Name,Private:Config.PrivateZone}" \
  --output table

echo "================================================"
echo "Network cleanup completed."
echo "================================================"
