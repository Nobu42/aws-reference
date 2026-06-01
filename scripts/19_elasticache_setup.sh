#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
PROFILE="learning"
REGION="ap-northeast-1"

# ElastiCacheを配置するVPC。
VPC_NAME="sample-vpc"

# ElastiCache for Redis設定。
# クラスターモード有効構成として、複数シャードを作成する。
REPLICATION_GROUP_ID="sample-elasticache"
REPLICATION_GROUP_DESCRIPTION="Sample Elasticache"
ENGINE="redis"
CACHE_NODE_TYPE="cache.t3.micro"

# セキュリティ設定。
# 銀行案件対策として、保存時暗号化と転送時暗号化を明示して有効化する。
# 転送時暗号化を有効にすると、クライアント側はTLS対応で接続する必要がある。
AT_REST_ENCRYPTION_ENABLED="true"
TRANSIT_ENCRYPTION_ENABLED="true"

# クラスターモード有効時の構成。
# 2シャード、各シャードにReplicaを2台作成する。
# 合計ノード数は 2 * (1 Primary + 2 Replica) = 6台。
NUM_NODE_GROUPS="2"
REPLICAS_PER_NODE_GROUP="2"

# ElastiCache Subnet Group。
# 名前は指定どおり sample-elasticache-sg とする。
# ただし、この "sg" はSecurity GroupではなくSubnet Group名として扱う。
CACHE_SUBNET_GROUP_NAME="sample-elasticache-sg"
CACHE_SUBNET_GROUP_DESCRIPTION="Sample ElastiCache Subnet Group"

# ElastiCache用Security Group。
# WebサーバーからRedisへ接続するため、6379/tcpをsample-sg-webから許可する。
ELASTICACHE_SG_NAME="sample-sg-elasticache"
WEB_SG_NAME="sample-sg-web"

# Redisのデフォルトポート。
REDIS_PORT="6379"

# ElastiCache作成完了待ちの設定。
# 6ノード構成はAWS CLI標準のwaiter時間を超えることがあるため、
# 状態を表示しながら長めに待てるようにする。
ELASTICACHE_WAIT_MAX_ATTEMPTS="80"
ELASTICACHE_WAIT_INTERVAL_SECONDS="30"

# LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

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
# Nameタグだけで誤ったVPCやSecurity Groupを拾わないようにする。
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

# Replication Groupがavailableになるまで待つ。
# AWS CLI標準のwaiterは進捗が見えず、6ノード構成では待機上限に達することがあるため、
# 現在のStatus、作成済みノード数、Configuration Endpointを表示しながら待つ。
wait_for_replication_group_available() {
  local attempt
  local group_info
  local status
  local member_count
  local configuration_endpoint

  for ((attempt = 1; attempt <= ELASTICACHE_WAIT_MAX_ATTEMPTS; attempt++)); do
    group_info=$(aws elasticache describe-replication-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --replication-group-id "$REPLICATION_GROUP_ID" \
      --query 'ReplicationGroups[0].[Status,length(MemberClusters),ConfigurationEndpoint.Address]' \
      --output text 2>/dev/null || true)

    if [ -z "$group_info" ] || [ "$group_info" = "None" ]; then
      status="not-found"
      member_count="-"
      configuration_endpoint="-"
    else
      read -r status member_count configuration_endpoint <<< "$group_info"
      configuration_endpoint="${configuration_endpoint:-None}"
    fi

    echo "Wait attempt ${attempt}/${ELASTICACHE_WAIT_MAX_ATTEMPTS}: status=${status}, nodes=${member_count}, endpoint=${configuration_endpoint}"

    if [ "$status" = "available" ]; then
      return 0
    fi

    if [ "$status" = "deleting" ] || [ "$status" = "create-failed" ]; then
      echo "Error: ElastiCache Replication Group status is $status."
      exit 1
    fi

    sleep "$ELASTICACHE_WAIT_INTERVAL_SECONDS"
  done

  echo "Error: ElastiCache Replication Group did not become available within the expected time."
  echo "Please check the current status and events in the ElastiCache console or with describe-replication-groups."
  exit 1
}

echo "=== Caller Identity ==="

# ElastiCacheは課金対象のため、操作先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="

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

echo "=== Get Private Subnet IDs ==="

# ElastiCacheは外部公開せず、Private Subnetに配置する。
# 02_subnet_setup.shで付与している Type=private タグを使って取得する。
PRIVATE_SUBNET_IDS=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Type,Values=private \
  --query 'Subnets[].SubnetId' \
  --output text)

PRIVATE_SUBNET_IDS=$(get_required_value "Private Subnets" "$PRIVATE_SUBNET_IDS")
PRIVATE_SUBNET_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Type,Values=private \
  --query 'length(Subnets)' \
  --output text)

if [ "$PRIVATE_SUBNET_COUNT" -lt 2 ]; then
  echo "Error: ElastiCache Subnet Group should include at least two private subnets."
  exit 1
fi

PRIVATE_SUBNET_AZS=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Type,Values=private \
  --query 'Subnets[].AvailabilityZone' \
  --output text)
PRIVATE_SUBNET_AZ_COUNT=$(printf '%s\n' "$PRIVATE_SUBNET_AZS" | tr '[:space:]' '\n' | sed '/^$/d' | sort -u | wc -l | tr -d ' ')

if [ "$PRIVATE_SUBNET_AZ_COUNT" -lt 2 ]; then
  echo "Error: private subnets should span at least two Availability Zones for Multi-AZ ElastiCache."
  exit 1
fi

echo "Private Subnets: $PRIVATE_SUBNET_IDS"
echo "Private Subnet Count: $PRIVATE_SUBNET_COUNT"
echo "Private Subnet AZ Count: $PRIVATE_SUBNET_AZ_COUNT"

echo "=== Get Web Security Group ID ==="

# Redisへの接続元として許可するWebサーバー用Security Groupを取得する。
WEB_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$WEB_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)
require_single_match "Web Security Group" "$WEB_SG_COUNT"

WEB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$WEB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

WEB_SG_ID=$(get_required_value "Web Security Group" "$WEB_SG_ID")

echo "Web Security Group: $WEB_SG_ID"

echo "=== Create ElastiCache Security Group ==="

# ElastiCache用Security Groupが存在するか確認する。
ELASTICACHE_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELASTICACHE_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text)

if [ "$ELASTICACHE_SG_COUNT" -gt 1 ]; then
  echo "Error: multiple ElastiCache Security Groups found in $VPC_ID."
  exit 1
fi

ELASTICACHE_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELASTICACHE_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)

if [ "$ELASTICACHE_SG_ID" = "None" ] || [ -z "$ELASTICACHE_SG_ID" ]; then
  echo "ElastiCache Security Group not found. Creating: $ELASTICACHE_SG_NAME"

  ELASTICACHE_SG_ID=$(aws ec2 create-security-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --group-name "$ELASTICACHE_SG_NAME" \
    --description "for ElastiCache Redis" \
    --vpc-id "$VPC_ID" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$ELASTICACHE_SG_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
    --query 'GroupId' \
    --output text)

  echo "ElastiCache Security Group created: $ELASTICACHE_SG_ID"
else
  echo "ElastiCache Security Group already exists: $ELASTICACHE_SG_ID"
fi

echo "=== Authorize Redis Access from Web Security Group ==="

# WebサーバーからRedisへ接続できるように、6379/tcpを許可する。
# すでに同じルールがある場合だけ正常扱いにし、それ以外のエラーは停止する。
set +e
REDIS_RULE_OUTPUT=$(aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$ELASTICACHE_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$REDIS_PORT,ToPort=$REDIS_PORT,UserIdGroupPairs=[{GroupId=$WEB_SG_ID,Description='Redis access from web servers'}]" 2>&1)
REDIS_RULE_STATUS=$?
set -e

if [ "$REDIS_RULE_STATUS" -eq 0 ]; then
  echo "Redis ingress rule added."
elif echo "$REDIS_RULE_OUTPUT" | grep -q "InvalidPermission.Duplicate"; then
  echo "Redis ingress rule already exists."
else
  echo "$REDIS_RULE_OUTPUT"
  exit "$REDIS_RULE_STATUS"
fi

echo "=== Create or Get ElastiCache Subnet Group ==="

# ElastiCache Subnet Groupは、ElastiCacheをどのSubnetに配置するかを定義する。
# 今回は作成済みのPrivate Subnetすべてを指定する。
SUBNET_GROUP_EXISTS="true"
aws elasticache describe-cache-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" >/dev/null 2>&1 || SUBNET_GROUP_EXISTS="false"

if [ "$SUBNET_GROUP_EXISTS" = "false" ]; then
  echo "ElastiCache Subnet Group not found. Creating: $CACHE_SUBNET_GROUP_NAME"

  aws elasticache create-cache-subnet-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --cache-subnet-group-description "$CACHE_SUBNET_GROUP_DESCRIPTION" \
    --subnet-ids $PRIVATE_SUBNET_IDS \
    --tags Key=Name,Value="$CACHE_SUBNET_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null

  echo "ElastiCache Subnet Group created: $CACHE_SUBNET_GROUP_NAME"
else
  echo "ElastiCache Subnet Group already exists: $CACHE_SUBNET_GROUP_NAME"

  EXISTING_SUBNET_GROUP_VPC_ID=$(aws elasticache describe-cache-subnet-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --query 'CacheSubnetGroups[0].VpcId' \
    --output text)

  if [ "$EXISTING_SUBNET_GROUP_VPC_ID" != "$VPC_ID" ]; then
    echo "Error: existing ElastiCache Subnet Group is in $EXISTING_SUBNET_GROUP_VPC_ID, expected $VPC_ID."
    exit 1
  fi

  # 既存Subnet Groupを再利用する場合も、現在のPrivate Subnetにそろえる。
  # すでに同じ設定の場合は "No modifications were requested" になるため、
  # その場合だけ正常扱いにし、それ以外のエラーは停止する。
  set +e
  SUBNET_GROUP_MODIFY_OUTPUT=$(aws elasticache modify-cache-subnet-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --cache-subnet-group-description "$CACHE_SUBNET_GROUP_DESCRIPTION" \
    --subnet-ids $PRIVATE_SUBNET_IDS 2>&1)
  SUBNET_GROUP_MODIFY_STATUS=$?
  set -e

  if [ "$SUBNET_GROUP_MODIFY_STATUS" -eq 0 ]; then
    echo "ElastiCache Subnet Group updated with current private subnets."
  elif echo "$SUBNET_GROUP_MODIFY_OUTPUT" | grep -q "No modifications were requested"; then
    echo "ElastiCache Subnet Group already has current private subnets."
  else
    echo "$SUBNET_GROUP_MODIFY_OUTPUT"
    exit "$SUBNET_GROUP_MODIFY_STATUS"
  fi
fi

echo "=== Create or Get ElastiCache Replication Group ==="

# Replication Groupがすでに存在するか確認する。
REPLICATION_GROUP_STATUS=$(aws elasticache describe-replication-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --replication-group-id "$REPLICATION_GROUP_ID" \
  --query 'ReplicationGroups[0].Status' \
  --output text 2>/dev/null || true)

if [ "$REPLICATION_GROUP_STATUS" = "None" ] || [ -z "$REPLICATION_GROUP_STATUS" ]; then
  echo "ElastiCache Replication Group not found. Creating: $REPLICATION_GROUP_ID"

  # Cluster Mode Enabled相当のRedis構成を作成する。
  # --num-node-groups がシャード数。
  # --replicas-per-node-group が各シャードごとのReplica数。
  #
  # Replicaを持つ構成ではAutomatic Failoverを有効化する。
  # Availability Zoneは明示指定せず、AWS側に配置を任せる。
  aws elasticache create-replication-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --replication-group-id "$REPLICATION_GROUP_ID" \
    --replication-group-description "$REPLICATION_GROUP_DESCRIPTION" \
    --engine "$ENGINE" \
    --cache-node-type "$CACHE_NODE_TYPE" \
    --num-node-groups "$NUM_NODE_GROUPS" \
    --replicas-per-node-group "$REPLICAS_PER_NODE_GROUP" \
    --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
    --security-group-ids "$ELASTICACHE_SG_ID" \
    --at-rest-encryption-enabled \
    --transit-encryption-enabled \
    --automatic-failover-enabled \
    --multi-az-enabled \
    --tags Key=Name,Value="$REPLICATION_GROUP_ID" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null

  echo "ElastiCache Replication Group creation started: $REPLICATION_GROUP_ID"
else
  echo "ElastiCache Replication Group already exists: $REPLICATION_GROUP_ID"
  echo "Current status: $REPLICATION_GROUP_STATUS"

  if [ "$REPLICATION_GROUP_STATUS" = "deleting" ]; then
    echo "Error: ElastiCache Replication Group is deleting. Please wait and rerun."
    exit 1
  fi
fi

echo "=== Wait for ElastiCache Replication Group to be available ==="

# ElastiCacheの作成には時間がかかる。
# availableになるまで待つ。
wait_for_replication_group_available

echo "ElastiCache Replication Group is available."

echo "=== Describe ElastiCache Replication Group ==="

aws elasticache describe-replication-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --replication-group-id "$REPLICATION_GROUP_ID" \
  --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,Description:Description,ClusterEnabled:ClusterEnabled,AtRestEncryptionEnabled:AtRestEncryptionEnabled,TransitEncryptionEnabled:TransitEncryptionEnabled,MemberClusters:MemberClusters,ConfigurationEndpoint:ConfigurationEndpoint.Address,ConfigurationPort:ConfigurationEndpoint.Port}' \
  --output table

echo "=== Describe ElastiCache Security Group ==="

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$ELASTICACHE_SG_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceGroup:UserIdGroupPairs[0].GroupId,Description:UserIdGroupPairs[0].Description}}' \
  --output table

echo "=== Describe ElastiCache Subnet Group ==="

aws elasticache describe-cache-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-subnet-group-name "$CACHE_SUBNET_GROUP_NAME" \
  --query 'CacheSubnetGroups[*].{Name:CacheSubnetGroupName,Description:CacheSubnetGroupDescription,VpcId:VpcId,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table

echo "------------------------------------------------"
echo "ElastiCache setup completed."
echo "Replication Group:"
echo "  ${REPLICATION_GROUP_ID}"
echo "Engine:"
echo "  ${ENGINE}"
echo "Node type:"
echo "  ${CACHE_NODE_TYPE}"
echo "Shards:"
echo "  ${NUM_NODE_GROUPS}"
echo "Replicas per shard:"
echo "  ${REPLICAS_PER_NODE_GROUP}"
echo "At-rest encryption:"
echo "  ${AT_REST_ENCRYPTION_ENABLED}"
echo "Transit encryption:"
echo "  ${TRANSIT_ENCRYPTION_ENABLED}"
echo "Subnet Group:"
echo "  ${CACHE_SUBNET_GROUP_NAME}"
echo "Security Group:"
echo "  ${ELASTICACHE_SG_NAME} (${ELASTICACHE_SG_ID})"
echo "------------------------------------------------"
echo "Note:"
echo "  This configuration creates 6 cache nodes."
echo "  Delete it after learning to avoid unnecessary cost."
echo "------------------------------------------------"
