#!/bin/bash
set -euo pipefail

# 使用するAWS CLIプロファイルとリージョン。
# "learning" には作業用IAMユーザーの認証情報を設定している。
PROFILE="learning"
REGION="ap-northeast-1"

# ACM証明書を発行するドメイン名。
# 今回はALBで公開している www.nobu-iac-lab.com 用の証明書を作成する。
DOMAIN_NAME="nobu-iac-lab.com"
CERT_DOMAIN_NAME="www.${DOMAIN_NAME}"
PUBLIC_HOSTED_ZONE_NAME="${DOMAIN_NAME}."
VPC_NAME="sample-vpc"

# HTTPS Listenerを追加するALBと、転送先Target Group。
ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"
TARGET_GROUP_PORT="3000"

# HTTPS Listener設定。
HTTPS_PORT="443"
HTTPS_PROTOCOL="HTTPS"

# ALBのTLSセキュリティポリシー。
# デフォルト任せにせず、TLS 1.2 / TLS 1.3のみ許可するポリシーを明示する。
# 金融系の設定変更では、どのTLSバージョンを許可するかを手順書に残せることが重要。
SSL_POLICY="ELBSecurityPolicy-TLS13-1-2-2021-06"

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

# 証明書とALBを操作するため、操作先アカウントを確認する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Public Hosted Zone ID ==="

# DNS検証用CNAMEを作成するPublic Hosted Zoneを取得する。
HOSTED_ZONE_COUNT=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$PUBLIC_HOSTED_ZONE_NAME" \
  --query "length(HostedZones[?Name==\`$PUBLIC_HOSTED_ZONE_NAME\` && Config.PrivateZone==\`false\`])" \
  --output text)
require_single_match "Public Hosted Zone" "$HOSTED_ZONE_COUNT"

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$PUBLIC_HOSTED_ZONE_NAME" \
  --query "HostedZones[?Name==\`$PUBLIC_HOSTED_ZONE_NAME\` && Config.PrivateZone==\`false\`].Id | [0]" \
  --output text)

HOSTED_ZONE_ID=$(get_required_value "Public Hosted Zone" "$HOSTED_ZONE_ID")
HOSTED_ZONE_ID="${HOSTED_ZONE_ID#/hostedzone/}"

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

echo "=== Get VPC ID ==="

# ALBとTarget Groupが現在のsample-vpcに属していることを確認するため、VPC IDを取得する。
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

echo "=== Find Existing ACM Certificate ==="

# すでに同じドメイン名の証明書があるか確認する。
# ISSUEDの証明書を優先し、なければPENDING_VALIDATIONの証明書を再利用する。
# 同じドメインの証明書が複数ある場合は、誤った証明書をListenerへ設定しないため停止する。
CERT_ARN=$(aws acm list-certificates \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-statuses ISSUED \
  --query "CertificateSummaryList[?DomainName==\`$CERT_DOMAIN_NAME\`].CertificateArn | [0]" \
  --output text)

ISSUED_CERT_COUNT=$(aws acm list-certificates \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-statuses ISSUED \
  --query "length(CertificateSummaryList[?DomainName==\`$CERT_DOMAIN_NAME\`])" \
  --output text)

if [ "$ISSUED_CERT_COUNT" -gt 1 ]; then
  echo "Error: multiple ISSUED ACM certificates found for $CERT_DOMAIN_NAME."
  exit 1
fi

if [ "$ISSUED_CERT_COUNT" -eq 0 ]; then
  PENDING_CERT_COUNT=$(aws acm list-certificates \
    --profile "$PROFILE" \
    --region "$REGION" \
    --certificate-statuses PENDING_VALIDATION \
    --query "length(CertificateSummaryList[?DomainName==\`$CERT_DOMAIN_NAME\`])" \
    --output text)

  if [ "$PENDING_CERT_COUNT" -gt 1 ]; then
    echo "Error: multiple PENDING_VALIDATION ACM certificates found for $CERT_DOMAIN_NAME."
    exit 1
  elif [ "$PENDING_CERT_COUNT" -eq 1 ]; then
    CERT_ARN=$(aws acm list-certificates \
      --profile "$PROFILE" \
      --region "$REGION" \
      --certificate-statuses PENDING_VALIDATION \
      --query "CertificateSummaryList[?DomainName==\`$CERT_DOMAIN_NAME\`].CertificateArn | [0]" \
      --output text)
    echo "Pending ACM Certificate found: $CERT_ARN"
  fi
fi

if [ "$CERT_ARN" = "None" ] || [ -z "$CERT_ARN" ]; then
  echo "ACM Certificate not found. Requesting new certificate: $CERT_DOMAIN_NAME"

  # DNS検証方式でACM証明書をリクエストする。
  CERT_ARN=$(aws acm request-certificate \
    --profile "$PROFILE" \
    --region "$REGION" \
    --domain-name "$CERT_DOMAIN_NAME" \
    --validation-method DNS \
    --tags Key=Name,Value="$CERT_DOMAIN_NAME" Key=Project,Value=terraform-iac-lab Key=Environment,Value=learning \
    --query 'CertificateArn' \
    --output text)

  echo "ACM Certificate requested: $CERT_ARN"
else
  echo "Existing ACM Certificate found: $CERT_ARN"
fi

CERT_ARN=$(get_required_value "ACM Certificate ARN" "$CERT_ARN")

echo "=== Get DNS Validation Record ==="

# ACMがDNS検証用CNAMEを発行するまで少し時間がかかることがある。
# 取れるまで複数回リトライする。
VALIDATION_RECORD_NAME=""
VALIDATION_RECORD_VALUE=""

for i in {1..30}; do
  VALIDATION_RECORD_NAME=$(aws acm describe-certificate \
    --profile "$PROFILE" \
    --region "$REGION" \
    --certificate-arn "$CERT_ARN" \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
    --output text)

  VALIDATION_RECORD_VALUE=$(aws acm describe-certificate \
    --profile "$PROFILE" \
    --region "$REGION" \
    --certificate-arn "$CERT_ARN" \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' \
    --output text)

  if [ "$VALIDATION_RECORD_NAME" != "None" ] && [ -n "$VALIDATION_RECORD_NAME" ] && \
     [ "$VALIDATION_RECORD_VALUE" != "None" ] && [ -n "$VALIDATION_RECORD_VALUE" ]; then
    break
  fi

  echo "Waiting for DNS validation record... ($i/30)"
  sleep 5
done

VALIDATION_RECORD_NAME=$(get_required_value "Validation Record Name" "$VALIDATION_RECORD_NAME")
VALIDATION_RECORD_VALUE=$(get_required_value "Validation Record Value" "$VALIDATION_RECORD_VALUE")

echo "Validation Record Name: $VALIDATION_RECORD_NAME"
echo "Validation Record Value: $VALIDATION_RECORD_VALUE"

echo "=== Create / Update DNS Validation Record ==="

# ACMのDNS検証用CNAMEをRoute 53に作成する。
# UPSERTなので、すでに存在する場合は更新する。
VALIDATION_CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Create or update ACM DNS validation record",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${VALIDATION_RECORD_NAME}",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${VALIDATION_RECORD_VALUE}"
          }
        ]
      }
    }
  ]
}
EOF
)

VALIDATION_CHANGE_ID=$(aws route53 change-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "$VALIDATION_CHANGE_BATCH" \
  --query 'ChangeInfo.Id' \
  --output text)

VALIDATION_CHANGE_ID=$(get_required_value "Validation Change ID" "$VALIDATION_CHANGE_ID")

echo "Route 53 Change ID: $VALIDATION_CHANGE_ID"

echo "=== Wait for DNS Validation Record to be INSYNC ==="

aws route53 wait resource-record-sets-changed \
  --profile "$PROFILE" \
  --id "$VALIDATION_CHANGE_ID"

echo "DNS validation record is INSYNC."

echo "=== Wait for ACM Certificate to be ISSUED ==="

# ACM証明書が発行済みになるまで待つ。
# DNS反映に時間がかかる場合、ここで数分待つことがある。
aws acm wait certificate-validated \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-arn "$CERT_ARN"

echo "ACM Certificate is ISSUED."

echo "=== Get ALB ARN ==="

# HTTPS Listenerを追加するALBを取得する。
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

if [ "$ALB_VPC_ID" != "$VPC_ID" ]; then
  echo "Error: ALB $ALB_NAME is in $ALB_VPC_ID, expected $VPC_ID."
  exit 1
fi

if [ "$ALB_TYPE" != "application" ] || [ "$ALB_SCHEME" != "internet-facing" ]; then
  echo "Error: ALB $ALB_NAME is $ALB_TYPE / $ALB_SCHEME, expected application / internet-facing."
  exit 1
fi

echo "ALB ARN: $ALB_ARN"
echo "ALB VPC: $ALB_VPC_ID"
echo "ALB Type/Scheme: $ALB_TYPE / $ALB_SCHEME"

echo "=== Get Target Group ARN ==="

# HTTPS ListenerのDefault actionでforwardするTarget Groupを取得する。
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names "$TARGET_GROUP_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || true)

TARGET_GROUP_ARN=$(get_required_value "Target Group ARN" "$TARGET_GROUP_ARN")

TARGET_GROUP_VPC_ID=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arns "$TARGET_GROUP_ARN" \
  --query 'TargetGroups[0].VpcId' \
  --output text)
TARGET_GROUP_VPC_ID=$(get_required_value "Target Group VPC ID" "$TARGET_GROUP_VPC_ID")

TARGET_GROUP_PROTOCOL=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arns "$TARGET_GROUP_ARN" \
  --query 'TargetGroups[0].Protocol' \
  --output text)
TARGET_GROUP_PROTOCOL=$(get_required_value "Target Group Protocol" "$TARGET_GROUP_PROTOCOL")

TARGET_GROUP_ACTUAL_PORT=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arns "$TARGET_GROUP_ARN" \
  --query 'TargetGroups[0].Port' \
  --output text)
TARGET_GROUP_ACTUAL_PORT=$(get_required_value "Target Group Port" "$TARGET_GROUP_ACTUAL_PORT")

if [ "$TARGET_GROUP_VPC_ID" != "$VPC_ID" ]; then
  echo "Error: Target Group $TARGET_GROUP_NAME is in $TARGET_GROUP_VPC_ID, expected $VPC_ID."
  exit 1
fi

if [ "$TARGET_GROUP_PROTOCOL" != "HTTP" ] || [ "$TARGET_GROUP_ACTUAL_PORT" != "$TARGET_GROUP_PORT" ]; then
  echo "Error: Target Group $TARGET_GROUP_NAME is $TARGET_GROUP_PROTOCOL:$TARGET_GROUP_ACTUAL_PORT, expected HTTP:$TARGET_GROUP_PORT."
  exit 1
fi

echo "Target Group ARN: $TARGET_GROUP_ARN"
echo "Target Group VPC: $TARGET_GROUP_VPC_ID"
echo "Target Group Protocol/Port: $TARGET_GROUP_PROTOCOL:$TARGET_GROUP_ACTUAL_PORT"

echo "=== Create or Update HTTPS Listener ==="

# すでに443 Listenerが存在するか確認する。
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`${HTTPS_PORT}\`].ListenerArn | [0]" \
  --output text)

if [ "$HTTPS_LISTENER_ARN" = "None" ] || [ -z "$HTTPS_LISTENER_ARN" ]; then
  echo "HTTPS Listener not found. Creating HTTPS Listener."

  # TLSセキュリティポリシーを明示してHTTPS Listenerを作成する。
  # Default actionはTarget Group sample-tgへのforward。
  HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
    --profile "$PROFILE" \
    --region "$REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --protocol "$HTTPS_PROTOCOL" \
    --port "$HTTPS_PORT" \
    --ssl-policy "$SSL_POLICY" \
    --certificates CertificateArn="$CERT_ARN" \
    --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
    --query 'Listeners[0].ListenerArn' \
    --output text)

  echo "HTTPS Listener created: $HTTPS_LISTENER_ARN"
else
  echo "HTTPS Listener already exists. Updating certificate and default action."

  # 既存の443 Listenerがある場合は、証明書とDefault actionを更新する。
  aws elbv2 modify-listener \
    --profile "$PROFILE" \
    --region "$REGION" \
    --listener-arn "$HTTPS_LISTENER_ARN" \
    --protocol "$HTTPS_PROTOCOL" \
    --port "$HTTPS_PORT" \
    --ssl-policy "$SSL_POLICY" \
    --certificates CertificateArn="$CERT_ARN" \
    --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" >/dev/null

  echo "HTTPS Listener updated: $HTTPS_LISTENER_ARN"
fi

HTTPS_LISTENER_ARN=$(get_required_value "HTTPS Listener ARN" "$HTTPS_LISTENER_ARN")

echo "=== Describe HTTPS Listener ==="

aws elbv2 describe-listeners \
  --profile "$PROFILE" \
  --region "$REGION" \
  --listener-arns "$HTTPS_LISTENER_ARN" \
  --query 'Listeners[*].{Port:Port,Protocol:Protocol,SslPolicy:SslPolicy,ListenerArn:ListenerArn,DefaultActions:DefaultActions[*].Type,Certificate:Certificates[0].CertificateArn}' \
  --output table

echo "=== Describe Certificate ==="

aws acm describe-certificate \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-arn "$CERT_ARN" \
  --query 'Certificate.{DomainName:DomainName,Status:Status,Type:Type,Issuer:Issuer,NotAfter:NotAfter}' \
  --output table

echo "------------------------------------------------"
echo "ACM certificate and HTTPS listener setup completed."
echo "Certificate Domain:"
echo "  ${CERT_DOMAIN_NAME}"
echo "HTTPS URL:"
echo "  https://${CERT_DOMAIN_NAME}"
echo "Listener:"
echo "  ${HTTPS_PROTOCOL}:${HTTPS_PORT} -> ${TARGET_GROUP_NAME}"
echo "TLS Security Policy:"
echo "  ${SSL_POLICY}"
echo "------------------------------------------------"
