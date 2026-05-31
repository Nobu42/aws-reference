#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# RDSを作成するVPCとPrivate Subnet。
# DBは外部公開しないため、Private Subnetに配置する。
VPC_NAME="sample-vpc"
PRIVATE_SUBNET_01_NAME="sample-subnet-private01"
PRIVATE_SUBNET_02_NAME="sample-subnet-private02"

# Webサーバー用Security Group。
# DBはWebサーバーからのMySQL接続だけを許可する。
WEB_SG_NAME="sample-sg-web"
DB_SG_NAME="sample-sg-db"

# RDS関連リソース名。
DB_PARAMETER_GROUP_NAME="sample-db-pg"
DB_OPTION_GROUP_NAME="sample-db-og"
DB_SUBNET_GROUP_NAME="sample-db-subnet"
DB_INSTANCE_IDENTIFIER="sample-db"

# MySQL設定。
DB_ENGINE="mysql"
DB_ENGINE_VERSION="8.0"
DB_PARAMETER_GROUP_FAMILY="mysql8.0"
DB_MAJOR_ENGINE_VERSION="8.0"
DB_PORT="3306"

# RDSインスタンス設定。
# 学習用の小さい構成。利用できるクラスはアカウントやリージョンで確認する。
DB_INSTANCE_CLASS="db.t3.micro"
DB_ALLOCATED_STORAGE="20"
DB_MASTER_USERNAME="adminuser"

# DBパスワードはスクリプトに直書きしない。
# 実行前に以下のように設定する。
# export DB_MASTER_PASSWORD='任意の強いパスワード'
if [ -z "${DB_MASTER_PASSWORD:-}" ]; then
  echo "Error: DB_MASTER_PASSWORD is not set."
  echo "Please run: export DB_MASTER_PASSWORD='your-strong-password'"
  exit 1
fi

# RDS MySQLのマスターパスワード制約を最低限確認する。
# 実運用ではSecrets ManagerやSSM Parameter Storeを使い、平文の環境変数だけに頼らない。
if [ "${#DB_MASTER_PASSWORD}" -lt 8 ] || [ "${#DB_MASTER_PASSWORD}" -gt 41 ]; then
  echo "Error: DB_MASTER_PASSWORD must be 8 to 41 characters for RDS MySQL."
  exit 1
fi

if [[ "$DB_MASTER_PASSWORD" == *"/"* || "$DB_MASTER_PASSWORD" == *\"* || "$DB_MASTER_PASSWORD" == *"@"* ]]; then
  echo "Error: DB_MASTER_PASSWORD must not contain '/', double quote, or '@' for RDS MySQL."
  exit 1
fi

# LocalStack用のaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続してしまう。
# 実AWSで作業するため、念のためここで無効化する。
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 取得したIDが空、または None の場合にスクリプトを止めるための関数。
# 必要なリソースが見つからないままRDS作成へ進むのを防ぐ。
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

# DB用Security Groupを作成または再利用する。
# Security Group名はVPC内で一意のため、VPC IDで絞り込んで確認する。
ensure_db_security_group() {
  local group_count
  local group_id

  group_count=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$DB_SG_NAME" \
    --query 'length(SecurityGroups)' \
    --output text)

  if [ "$group_count" -gt 1 ]; then
    echo "Error: multiple DB Security Groups found for $DB_SG_NAME in $VPC_ID." >&2
    exit 1
  elif [ "$group_count" -eq 1 ]; then
    group_id=$(aws ec2 describe-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$DB_SG_NAME" \
      --query 'SecurityGroups[0].GroupId' \
      --output text)
    group_id=$(get_required_id "DB Security Group" "$group_id")
    echo "Reusing DB Security Group: $DB_SG_NAME ($group_id)" >&2
  else
    echo "Creating DB Security Group: $DB_SG_NAME" >&2
    group_id=$(aws ec2 create-security-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --group-name "$DB_SG_NAME" \
      --description "for RDS database" \
      --vpc-id "$VPC_ID" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$DB_SG_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
      --query 'GroupId' \
      --output text)
  fi

  # 既存SGを再利用する場合もタグをそろえる。
  aws ec2 create-tags \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resources "$group_id" \
    --tags Key=Name,Value="$DB_SG_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning

  echo "$group_id"
}

# 送信元Security Groupを指定したIngress Ruleを作成またはスキップする。
# DBではCIDRではなく、Web Security Groupを送信元にする。
ensure_mysql_ingress_from_web_sg() {
  local rule_output
  local rule_status

  echo "Adding ingress rule if needed: $DB_SG_ID tcp $DB_PORT from $WEB_SG_ID"

  # 同じIngress Ruleが既にある場合、AWS CLIは InvalidPermission.Duplicate を返す。
  # その場合は正常な再実行として扱い、それ以外のエラーだけ停止する。
  set +e
  rule_output=$(aws ec2 authorize-security-group-ingress \
    --profile "$PROFILE" \
    --region "$REGION" \
    --group-id "$DB_SG_ID" \
    --ip-permissions "[{\"IpProtocol\":\"tcp\",\"FromPort\":$DB_PORT,\"ToPort\":$DB_PORT,\"UserIdGroupPairs\":[{\"GroupId\":\"$WEB_SG_ID\",\"Description\":\"MySQL access from web servers\"}]}]" 2>&1)
  rule_status=$?
  set -e

  if [ "$rule_status" -eq 0 ]; then
    echo "$rule_output"
    return
  fi

  if echo "$rule_output" | grep -q "InvalidPermission.Duplicate"; then
    echo "Ingress rule already exists: $DB_SG_ID tcp $DB_PORT from $WEB_SG_ID"
    return
  fi

  echo "$rule_output"
  exit "$rule_status"
}

# DB Parameter Groupを作成または再利用する。
# 既存Parameter Groupがある場合は、familyが期待値と一致するか確認する。
ensure_db_parameter_group() {
  local group_name
  local group_family
  local group_arn

  group_name=$(aws rds describe-db-parameter-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
    --query 'DBParameterGroups[0].DBParameterGroupName' \
    --output text 2>/dev/null || true)

  if [ "$group_name" != "None" ] && [ -n "$group_name" ]; then
    group_family=$(aws rds describe-db-parameter-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
      --query 'DBParameterGroups[0].DBParameterGroupFamily' \
      --output text)

    if [ "$group_family" != "$DB_PARAMETER_GROUP_FAMILY" ]; then
      echo "Error: existing DB Parameter Group family is $group_family, expected $DB_PARAMETER_GROUP_FAMILY."
      exit 1
    fi

    echo "Reusing DB Parameter Group: $DB_PARAMETER_GROUP_NAME" >&2
  else
    echo "Creating DB Parameter Group: $DB_PARAMETER_GROUP_NAME" >&2
    aws rds create-db-parameter-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
      --db-parameter-group-family "$DB_PARAMETER_GROUP_FAMILY" \
      --description "sample parameter group" \
      --tags Key=Name,Value="$DB_PARAMETER_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null
  fi

  group_arn=$(aws rds describe-db-parameter-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
    --query 'DBParameterGroups[0].DBParameterGroupArn' \
    --output text)
  group_arn=$(get_required_id "DB Parameter Group ARN" "$group_arn")

  aws rds add-tags-to-resource \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resource-name "$group_arn" \
    --tags Key=Name,Value="$DB_PARAMETER_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning
}

# DB Option Groupを作成または再利用する。
# 既存Option Groupがある場合は、engineとmajor versionが期待値と一致するか確認する。
ensure_db_option_group() {
  local option_group_name
  local engine_name
  local major_engine_version
  local option_group_arn

  option_group_name=$(aws rds describe-option-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --option-group-name "$DB_OPTION_GROUP_NAME" \
    --query 'OptionGroupsList[0].OptionGroupName' \
    --output text 2>/dev/null || true)

  if [ "$option_group_name" != "None" ] && [ -n "$option_group_name" ]; then
    engine_name=$(aws rds describe-option-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --option-group-name "$DB_OPTION_GROUP_NAME" \
      --query 'OptionGroupsList[0].EngineName' \
      --output text)

    major_engine_version=$(aws rds describe-option-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --option-group-name "$DB_OPTION_GROUP_NAME" \
      --query 'OptionGroupsList[0].MajorEngineVersion' \
      --output text)

    if [ "$engine_name" != "$DB_ENGINE" ] || [ "$major_engine_version" != "$DB_MAJOR_ENGINE_VERSION" ]; then
      echo "Error: existing DB Option Group is $engine_name/$major_engine_version, expected $DB_ENGINE/$DB_MAJOR_ENGINE_VERSION."
      exit 1
    fi

    echo "Reusing DB Option Group: $DB_OPTION_GROUP_NAME" >&2
  else
    echo "Creating DB Option Group: $DB_OPTION_GROUP_NAME" >&2
    aws rds create-option-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --option-group-name "$DB_OPTION_GROUP_NAME" \
      --engine-name "$DB_ENGINE" \
      --major-engine-version "$DB_MAJOR_ENGINE_VERSION" \
      --option-group-description "sample option group" \
      --tags Key=Name,Value="$DB_OPTION_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null
  fi

  option_group_arn=$(aws rds describe-option-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --option-group-name "$DB_OPTION_GROUP_NAME" \
    --query 'OptionGroupsList[0].OptionGroupArn' \
    --output text)
  option_group_arn=$(get_required_id "DB Option Group ARN" "$option_group_arn")

  aws rds add-tags-to-resource \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resource-name "$option_group_arn" \
    --tags Key=Name,Value="$DB_OPTION_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning
}

# DB Subnet Groupを作成または再利用する。
# 既存Subnet Groupがある場合も、対象Private Subnet 2つへそろえる。
ensure_db_subnet_group() {
  local subnet_group_name
  local subnet_group_vpc_id
  local subnet_group_arn

  subnet_group_name=$(aws rds describe-db-subnet-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --query 'DBSubnetGroups[0].DBSubnetGroupName' \
    --output text 2>/dev/null || true)

  if [ "$subnet_group_name" != "None" ] && [ -n "$subnet_group_name" ]; then
    subnet_group_vpc_id=$(aws rds describe-db-subnet-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
      --query 'DBSubnetGroups[0].VpcId' \
      --output text)

    if [ "$subnet_group_vpc_id" != "$VPC_ID" ]; then
      echo "Error: existing DB Subnet Group is in $subnet_group_vpc_id, expected $VPC_ID."
      exit 1
    fi

    echo "Reusing DB Subnet Group: $DB_SUBNET_GROUP_NAME" >&2
    aws rds modify-db-subnet-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
      --db-subnet-group-description "sample db subnet group" \
      --subnet-ids "$SUBNET_PRIV01" "$SUBNET_PRIV02" >/dev/null
  else
    echo "Creating DB Subnet Group: $DB_SUBNET_GROUP_NAME" >&2
    aws rds create-db-subnet-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
      --db-subnet-group-description "sample db subnet group" \
      --subnet-ids "$SUBNET_PRIV01" "$SUBNET_PRIV02" \
      --tags Key=Name,Value="$DB_SUBNET_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null
  fi

  subnet_group_arn=$(aws rds describe-db-subnet-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --query 'DBSubnetGroups[0].DBSubnetGroupArn' \
    --output text)
  subnet_group_arn=$(get_required_id "DB Subnet Group ARN" "$subnet_group_arn")

  aws rds add-tags-to-resource \
    --profile "$PROFILE" \
    --region "$REGION" \
    --resource-name "$subnet_group_arn" \
    --tags Key=Name,Value="$DB_SUBNET_GROUP_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning
}

# RDS DB Instanceを作成または再利用する。
# 既存DBがある場合は、停止中なら起動し、利用可能になるまで待つ。
ensure_db_instance() {
  local db_exists
  local db_status
  local db_engine
  local publicly_accessible
  local db_subnet_group
  local has_db_sg

  db_exists=$(aws rds describe-db-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
    --query 'length(DBInstances)' \
    --output text 2>/dev/null || true)

  if [ "$db_exists" != "None" ] && [ -n "$db_exists" ] && [ "$db_exists" -gt 0 ]; then
    db_status=$(aws rds describe-db-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --query 'DBInstances[0].DBInstanceStatus' \
      --output text)

    db_engine=$(aws rds describe-db-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --query 'DBInstances[0].Engine' \
      --output text)

    if [ "$db_engine" != "$DB_ENGINE" ]; then
      echo "Error: existing DB engine is $db_engine, expected $DB_ENGINE."
      exit 1
    fi

    publicly_accessible=$(aws rds describe-db-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --query 'DBInstances[0].PubliclyAccessible' \
      --output text)

    if [ "$publicly_accessible" != "False" ] && [ "$publicly_accessible" != "false" ]; then
      echo "Error: existing DB is publicly accessible. Please investigate before continuing."
      exit 1
    fi

    db_subnet_group=$(aws rds describe-db-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' \
      --output text)

    if [ "$db_subnet_group" != "$DB_SUBNET_GROUP_NAME" ]; then
      echo "Error: existing DB subnet group is $db_subnet_group, expected $DB_SUBNET_GROUP_NAME."
      exit 1
    fi

    has_db_sg=$(aws rds describe-db-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --query "contains(DBInstances[0].VpcSecurityGroups[].VpcSecurityGroupId, '$DB_SG_ID')" \
      --output text)

    if [ "$has_db_sg" != "True" ] && [ "$has_db_sg" != "true" ]; then
      echo "Updating DB Security Group association: $DB_SG_ID"
      aws rds modify-db-instance \
        --profile "$PROFILE" \
        --region "$REGION" \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --vpc-security-group-ids "$DB_SG_ID" \
        --apply-immediately >/dev/null
    fi

    if [ "$db_status" = "stopped" ]; then
      echo "Starting existing RDS instance: $DB_INSTANCE_IDENTIFIER"
      aws rds start-db-instance \
        --profile "$PROFILE" \
        --region "$REGION" \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" >/dev/null
    elif [ "$db_status" = "deleting" ] || [ "$db_status" = "failed" ] || [ "$db_status" = "incompatible-restore" ] || [ "$db_status" = "incompatible-parameters" ]; then
      echo "Error: existing RDS instance is in status $db_status. Please investigate before continuing."
      exit 1
    else
      echo "Reusing existing RDS instance: $DB_INSTANCE_IDENTIFIER ($db_status)"
    fi
  else
    echo "Creating RDS instance: $DB_INSTANCE_IDENTIFIER"
    # --storage-encrypted は銀行案件対策としても重要な暗号化設定。
    # 学習環境ではAWS管理KMSキーを使い、追加のKMSキー指定はしない。
    aws rds create-db-instance \
      --profile "$PROFILE" \
      --region "$REGION" \
      --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
      --engine "$DB_ENGINE" \
      --engine-version "$DB_ENGINE_VERSION" \
      --db-instance-class "$DB_INSTANCE_CLASS" \
      --allocated-storage "$DB_ALLOCATED_STORAGE" \
      --storage-type gp2 \
      --storage-encrypted \
      --master-username "$DB_MASTER_USERNAME" \
      --master-user-password "$DB_MASTER_PASSWORD" \
      --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
      --vpc-security-group-ids "$DB_SG_ID" \
      --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
      --option-group-name "$DB_OPTION_GROUP_NAME" \
      --no-publicly-accessible \
      --backup-retention-period 0 \
      --no-multi-az \
      --no-deletion-protection \
      --tags Key=Name,Value="$DB_INSTANCE_IDENTIFIER" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning >/dev/null
  fi

  echo "Waiting for RDS instance to be available..."
  aws rds wait db-instance-available \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
}

echo "=== Caller Identity ==="

# RDSは課金対象なので、作成前に操作先アカウントを必ず確認する。
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

# DBを配置するPrivate Subnet 2つを取得する。
# VPC IDでも絞り込み、別VPCの同名Subnetを誤って使わないようにする。
SUBNET_PRIV01_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 01" "$SUBNET_PRIV01_COUNT"

SUBNET_PRIV01=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
SUBNET_PRIV01=$(get_required_id "Private Subnet 01" "$SUBNET_PRIV01")

SUBNET_PRIV01_AZ=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PRIV01" \
  --query 'Subnets[0].AvailabilityZone' \
  --output text)

SUBNET_PRIV02_COUNT=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_02_NAME" \
  --query 'length(Subnets)' \
  --output text)
require_single_match "Private Subnet 02" "$SUBNET_PRIV02_COUNT"

SUBNET_PRIV02=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
SUBNET_PRIV02=$(get_required_id "Private Subnet 02" "$SUBNET_PRIV02")

SUBNET_PRIV02_AZ=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PRIV02" \
  --query 'Subnets[0].AvailabilityZone' \
  --output text)

if [ "$SUBNET_PRIV01_AZ" = "$SUBNET_PRIV02_AZ" ]; then
  echo "Error: DB Subnet Group should use subnets in at least two Availability Zones. Both subnets are in $SUBNET_PRIV01_AZ."
  exit 1
fi

# Webサーバー用Security Groupを取得する。
# DB用Security Groupでは、このSGからの3306番だけを許可する。
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
WEB_SG_ID=$(get_required_id "Web Security Group" "$WEB_SG_ID")

echo "VPC: $VPC_ID"
echo "Private Subnet 01: $SUBNET_PRIV01 ($SUBNET_PRIV01_AZ)"
echo "Private Subnet 02: $SUBNET_PRIV02 ($SUBNET_PRIV02_AZ)"
echo "Web Security Group: $WEB_SG_ID"

echo "=== Configure DB Security Group ==="

DB_SG_ID=$(ensure_db_security_group)
ensure_mysql_ingress_from_web_sg

echo "DB Security Group: $DB_SG_ID"

echo "=== Configure DB Parameter Group ==="

ensure_db_parameter_group

echo "DB Parameter Group: $DB_PARAMETER_GROUP_NAME"

echo "=== Configure DB Option Group ==="

ensure_db_option_group

echo "DB Option Group: $DB_OPTION_GROUP_NAME"

echo "=== Configure DB Subnet Group ==="

ensure_db_subnet_group

echo "DB Subnet Group: $DB_SUBNET_GROUP_NAME"

echo "=== Configure RDS Instance ==="

ensure_db_instance

echo "RDS Instance is available."

echo "=== Describe RDS Instance ==="

# 作成または再利用したRDSの状態、エンドポイント、公開設定を確認する。
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,MultiAZ:MultiAZ,DBSubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcSecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table

echo "=== Describe DB Security Group ==="

# DB Security GroupがWeb Security GroupからのMySQLだけを許可していることを確認する。
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$DB_SG_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceSecurityGroups:UserIdGroupPairs[*].GroupId,Description:UserIdGroupPairs[*].Description}}' \
  --output table
