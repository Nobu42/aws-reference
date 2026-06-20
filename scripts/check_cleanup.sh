#!/bin/bash
set -euo pipefail

PROFILE="${AWS_PROFILE:-learning}"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
DOMAIN_NAME="nobu-iac-lab.com"
DOMAIN_NAME_DOT="${DOMAIN_NAME}."
PRIVATE_ZONE_NAME="home"
PRIVATE_ZONE_NAME_DOT="${PRIVATE_ZONE_NAME}."

EC2_NAMES="sample-ec2-bastion,sample-ec2-web01,sample-ec2-web02"
SUBNET_NAMES="sample-subnet-public01,sample-subnet-public02,sample-subnet-private01,sample-subnet-private02"
ROUTE_TABLE_NAMES="sample-rt-public,sample-rt-private01,sample-rt-private02"
SECURITY_GROUP_NAMES="sample-sg-bastion,sample-sg-elb,sample-sg-web,sample-sg-db,sample-sg-elasticache"
NAT_GATEWAY_NAMES="sample-ngw-01,sample-ngw-02"
EIP_NAMES="sample-eip-ngw-01,sample-eip-ngw-02"
ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"
RDS_INSTANCE_ID="sample-db"
DB_SUBNET_GROUP_NAME="sample-db-subnet"
DB_PARAMETER_GROUP_NAME="sample-db-pg"
DB_OPTION_GROUP_NAME="sample-db-og"
ELASTICACHE_REPLICATION_GROUP_ID="sample-elasticache"
ELASTICACHE_SUBNET_GROUP_NAME="sample-elasticache-sg"
S3_BUCKET_NAMES=(
  "nobu-terraform-iac-lab-upload"
  "nobu-iac-lab-mailbox"
)

unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
export AWS_PAGER=""

# check_cleanupはdescribe/list系の確認コマンドが多いため、このスクリプト内の
# awsコマンドをすべて --no-cli-pager 付きで実行する。
aws() {
  command aws --no-cli-pager "$@"
}

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== VPCs tagged $VPC_NAME ==="
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Daily Lab EC2 Instances ==="
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$EC2_NAMES" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,VpcId:VpcId}' \
  --output table

echo "=== Daily Lab Subnets ==="
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$SUBNET_NAMES" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,VpcId:VpcId}' \
  --output table

echo "=== Daily Lab Internet Gateways ==="
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-igw \
  --query 'InternetGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InternetGatewayId,VpcId:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table

echo "=== Daily Lab Route Tables ==="
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$ROUTE_TABLE_NAMES" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,VpcId:VpcId}' \
  --output table

echo "=== Daily Lab Security Groups ==="
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-name,Values="$SECURITY_GROUP_NAMES" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,VpcId:VpcId,Description:Description}' \
  --output table

echo "=== Daily Lab NAT Gateways except deleted history ==="
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=tag:Name,Values="$NAT_GATEWAY_NAMES" \
  --query 'NatGateways[?State!=`deleted`].{ID:NatGatewayId,State:State,VpcId:VpcId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Daily Lab Elastic IPs ==="
aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$EIP_NAMES" \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Daily Lab Load Balancers ==="
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "LoadBalancers[?LoadBalancerName==\`$ALB_NAME\`].{Name:LoadBalancerName,State:State.Code,DNS:DNSName,VpcId:VpcId}" \
  --output table

echo "=== Daily Lab Target Groups ==="
aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "TargetGroups[?TargetGroupName==\`$TARGET_GROUP_NAME\`].{Name:TargetGroupName,Port:Port,Protocol:Protocol,VpcId:VpcId}" \
  --output table

echo "=== Daily Lab RDS Instances ==="
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query "DBInstances[?DBInstanceIdentifier==\`$RDS_INSTANCE_ID\`].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Public:PubliclyAccessible}" \
  --output table

echo "=== Daily Lab RDS DB Subnet Groups ==="
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus}' \
  --output table 2>/dev/null || echo "DB Subnet Group not found: $DB_SUBNET_GROUP_NAME"

echo "=== Daily Lab RDS DB Parameter Groups ==="
aws rds describe-db-parameter-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --query 'DBParameterGroups[*].{Name:DBParameterGroupName,Family:DBParameterGroupFamily}' \
  --output table 2>/dev/null || echo "DB Parameter Group not found: $DB_PARAMETER_GROUP_NAME"

echo "=== Daily Lab RDS DB Option Groups ==="
aws rds describe-option-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --option-group-name "$DB_OPTION_GROUP_NAME" \
  --query 'OptionGroupsList[*].{Name:OptionGroupName,Engine:EngineName,MajorEngineVersion:MajorEngineVersion}' \
  --output table 2>/dev/null || echo "DB Option Group not found: $DB_OPTION_GROUP_NAME"

echo "=== Daily Lab ElastiCache Replication Groups ==="
aws elasticache describe-replication-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --replication-group-id "$ELASTICACHE_REPLICATION_GROUP_ID" \
  --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,ClusterEnabled:ClusterEnabled,MemberClusters:MemberClusters}' \
  --output table 2>/dev/null || echo "ElastiCache Replication Group not found: $ELASTICACHE_REPLICATION_GROUP_ID"

echo "=== Daily Lab ElastiCache Subnet Groups ==="
aws elasticache describe-cache-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cache-subnet-group-name "$ELASTICACHE_SUBNET_GROUP_NAME" \
  --query 'CacheSubnetGroups[*].{Name:CacheSubnetGroupName,VpcId:VpcId,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table 2>/dev/null || echo "ElastiCache Subnet Group not found: $ELASTICACHE_SUBNET_GROUP_NAME"

echo "=== Daily Lab S3 Buckets ==="
for bucket_name in "${S3_BUCKET_NAMES[@]}"; do
  if aws s3api head-bucket \
    --profile "$PROFILE" \
    --bucket "$bucket_name" >/dev/null 2>&1; then
    echo "Bucket exists: $bucket_name"
  else
    echo "Bucket not found: $bucket_name"
  fi
done

echo "=== Public Hosted Zone ==="
PUBLIC_HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`].Id | [0]" \
  --output text 2>/dev/null || true)

if [ "$PUBLIC_HOSTED_ZONE_ID" != "None" ] && [ -n "$PUBLIC_HOSTED_ZONE_ID" ]; then
  PUBLIC_HOSTED_ZONE_ID="${PUBLIC_HOSTED_ZONE_ID#/hostedzone/}"
  echo "Public Hosted Zone ID: $PUBLIC_HOSTED_ZONE_ID"

  echo "=== Public DNS temporary records ==="
  aws route53 list-resource-record-sets \
    --profile "$PROFILE" \
    --hosted-zone-id "$PUBLIC_HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name==\`bastion.${DOMAIN_NAME}.\` || Name==\`www.${DOMAIN_NAME}.\` || (Name==\`${DOMAIN_NAME}.\` && Type==\`MX\`)]" \
    --output table

  echo "=== Public DNS kept records for ACM / SES ==="
  aws route53 list-resource-record-sets \
    --profile "$PROFILE" \
    --hosted-zone-id "$PUBLIC_HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?(Type==\`CNAME\` && contains(Name, \`${DOMAIN_NAME}.\`)) || Name==\`_dmarc.${DOMAIN_NAME}.\` || (Name==\`${DOMAIN_NAME}.\` && Type==\`TXT\`)]" \
    --output table
else
  echo "Public Hosted Zone not found."
fi

echo "=== Private Hosted Zone home ==="
PRIVATE_HOSTED_ZONE_IDS=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$PRIVATE_ZONE_NAME_DOT" \
  --query "HostedZones[?Name==\`$PRIVATE_ZONE_NAME_DOT\` && Config.PrivateZone==\`true\`].Id" \
  --output text 2>/dev/null || true)

if [ -z "$PRIVATE_HOSTED_ZONE_IDS" ] || [ "$PRIVATE_HOSTED_ZONE_IDS" = "None" ]; then
  echo "Private Hosted Zone not found: $PRIVATE_ZONE_NAME_DOT"
else
  for private_hosted_zone_id in $PRIVATE_HOSTED_ZONE_IDS; do
    private_hosted_zone_id="${private_hosted_zone_id#/hostedzone/}"
    echo "Private Hosted Zone ID: $private_hosted_zone_id"

    echo "=== Private Hosted Zone VPC associations ==="
    aws route53 get-hosted-zone \
      --profile "$PROFILE" \
      --id "$private_hosted_zone_id" \
      --query '{Name:HostedZone.Name,Private:HostedZone.Config.PrivateZone,VPCs:VPCs}' \
      --output table

    echo "=== Private Hosted Zone temporary records ==="
    aws route53 list-resource-record-sets \
      --profile "$PROFILE" \
      --hosted-zone-id "$private_hosted_zone_id" \
      --query "ResourceRecordSets[?Name==\`bastion.${PRIVATE_ZONE_NAME}.\` || Name==\`web01.${PRIVATE_ZONE_NAME}.\` || Name==\`web02.${PRIVATE_ZONE_NAME}.\` || Name==\`db.${PRIVATE_ZONE_NAME}.\`]" \
      --output table
  done
fi

echo "=== SES Active Receipt Rule Set ==="
aws ses describe-active-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query '{Name:Metadata.Name,CreatedTimestamp:Metadata.CreatedTimestamp}' \
  --output table 2>/dev/null || echo "No active receipt rule set."

echo "=== SES Receipt Rule Set sample-ruleset ==="
aws ses describe-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule-set-name sample-ruleset \
  --query 'Rules[*].{Name:Name,Enabled:Enabled,Recipients:Recipients,ScanEnabled:ScanEnabled}' \
  --output table 2>/dev/null || echo "Receipt Rule Set sample-ruleset not found."

echo "=== ACM Certificates kept ==="
aws acm list-certificates \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-statuses ISSUED PENDING_VALIDATION \
  --query 'CertificateSummaryList[*].{DomainName:DomainName,Status:Status,Arn:CertificateArn}' \
  --output table

echo "=== SES Identities kept ==="
aws sesv2 list-email-identities \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'EmailIdentities[*].{IdentityName:IdentityName,IdentityType:IdentityType,SendingEnabled:SendingEnabled,VerificationStatus:VerificationStatus}' \
  --output table

echo "=== Cleanup check completed ==="
echo "Expected after cleanup:"
echo "  - No $VPC_NAME"
echo "  - No daily lab EC2: $EC2_NAMES"
echo "  - No daily lab Subnet / IGW / Route Table / Security Group"
echo "  - No available daily lab NAT Gateway"
echo "  - No daily lab Elastic IP"
echo "  - No daily lab ALB / Target Group"
echo "  - No daily lab RDS instance"
echo "  - No daily lab RDS DB Subnet Group / Parameter Group / Option Group"
echo "  - No daily lab ElastiCache Replication Group / Subnet Group"
echo "  - No temporary DNS records: bastion, www, MX"
echo "  - No Private Hosted Zone: home"
echo "  - S3 buckets for daily lab should be deleted"
echo ""
echo "Expected to remain:"
echo "  - Public Hosted Zone: ${DOMAIN_NAME}"
echo "  - ACM certificate"
echo "  - SES Domain Identity / DKIM / SPF / DMARC"
echo "  - SES SMTP IAM user"
