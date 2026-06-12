#!/bin/bash

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_trail_lab}"

export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  ./02_check_cloudtrail_trail.sh [trail-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, EVIDENCE_BASE_DIR
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: Required command not found: aws" >&2
  exit 1
fi

readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_check_trail"

mkdir -p "$EVIDENCE_DIR"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_caller_identity.json"

TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  exit 1
fi

HOME_REGION=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].HomeRegion' \
  --output text)

if [ "$HOME_REGION" != "$REGION" ]; then
  echo "ERROR: Trail Home Region is $HOME_REGION, expected $REGION." >&2
  exit 1
fi

TRAIL_BUCKET=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].S3BucketName' \
  --output text)

TRAIL_PREFIX=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].S3KeyPrefix' \
  --output text)

if [ "$TRAIL_PREFIX" = "None" ]; then
  TRAIL_PREFIX=""
fi

echo "================================================"
echo "Check CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET"
echo "Prefix  : ${TRAIL_PREFIX:-<none>}"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/03_event_selectors.json"

aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/04_bucket_public_access_block.json"

aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/05_bucket_ownership_controls.json"

aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/06_bucket_encryption.json"

aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/07_bucket_policy_status.json"

if [ -n "$TRAIL_PREFIX" ]; then
  LOG_PREFIX="${TRAIL_PREFIX}/AWSLogs/${ACCOUNT_ID}/CloudTrail/"
else
  LOG_PREFIX="AWSLogs/${ACCOUNT_ID}/CloudTrail/"
fi

aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --prefix "$LOG_PREFIX" \
  --max-items 10 \
  --output json \
  > "$EVIDENCE_DIR/08_recent_log_objects.json"

echo "=== Trail configuration ==="
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].{Name:Name,HomeRegion:HomeRegion,S3BucketName:S3BucketName,S3KeyPrefix:S3KeyPrefix,IsMultiRegionTrail:IsMultiRegionTrail,IncludeGlobalServiceEvents:IncludeGlobalServiceEvents,LogFileValidationEnabled:LogFileValidationEnabled}' \
  --output table

echo "=== Trail status ==="
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query '{IsLogging:IsLogging,StartLoggingTime:StartLoggingTime,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError}' \
  --output table

echo "=== Event selectors ==="
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[].{ReadWriteType:ReadWriteType,IncludeManagementEvents:IncludeManagementEvents,DataResourceCount:length(DataResources)}' \
  --output table

echo "=== Recent CloudTrail log objects ==="
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --prefix "$LOG_PREFIX" \
  --max-items 10 \
  --query 'Contents[].{LastModified:LastModified,Size:Size,Key:Key}' \
  --output table

IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" = "True" ]; then
  echo "OK: Trail is logging."
else
  echo "WARNING: Trail is not logging."
fi

echo "Trail check completed."
echo "Evidence: $EVIDENCE_DIR"

