#!/bin/bash

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly TRAIL_PREFIX="${TRAIL_PREFIX:-cloudtrail}"

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
  ./01_create_cloudtrail_trail.sh [trail-name] [trail-bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, TRAIL_PREFIX
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  ./01_create_cloudtrail_trail.sh
  SKIP_CONFIRM=true ./01_create_cloudtrail_trail.sh
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

confirm_change() {
  if [ "${SKIP_CONFIRM:-false}" = "true" ]; then
    return 0
  fi

  printf 'Type "create" to create the temporary CloudTrail Trail: '
  read -r ANSWER
  if [ "$ANSWER" != "create" ]; then
    echo "Canceled."
    exit 1
  fi
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 2 ]; then
  usage >&2
  exit 2
fi

require_command aws

readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_create_trail"

mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/change" "$EVIDENCE_DIR/after"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

readonly TRAIL_BUCKET_VALUE="${2:-nobu-iac-lab-cloudtrail-${ACCOUNT_ID}}"
readonly TRAIL_ARN="arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME_VALUE}"

echo "================================================"
echo "Create temporary CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET_VALUE"
echo "Prefix  : $TRAIL_PREFIX"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 0 ]; then
  echo "ERROR: Trail already exists: $TRAIL_NAME_VALUE" >&2
  echo "This script will not overwrite an existing Trail." >&2
  exit 1
fi

OWN_BUCKET_COUNT=$(aws s3api list-buckets \
  --profile "$PROFILE" \
  --query "length(Buckets[?Name=='${TRAIL_BUCKET_VALUE}'])" \
  --output text)

if [ "$OWN_BUCKET_COUNT" -ne 0 ]; then
  echo "ERROR: S3 bucket already exists in this account: $TRAIL_BUCKET_VALUE" >&2
  echo "This script will not overwrite an existing bucket or bucket policy." >&2
  exit 1
fi

confirm_change

aws s3api create-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --create-bucket-configuration "LocationConstraint=$REGION" \
  --output json \
  > "$EVIDENCE_DIR/change/01_create_bucket.json"

aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --public-access-block-configuration \
    'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --server-side-encryption-configuration \
    'Rules=[{ApplyServerSideEncryptionByDefault={SSEAlgorithm=AES256}}]'

cat > "$EVIDENCE_DIR/change/02_cloudtrail_bucket_policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${TRAIL_BUCKET_VALUE}",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "${TRAIL_ARN}"
        }
      }
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${TRAIL_BUCKET_VALUE}/${TRAIL_PREFIX}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "aws:SourceArn": "${TRAIL_ARN}"
        }
      }
    }
  ]
}
POLICY

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_DIR/change/02_cloudtrail_bucket_policy.json"

aws cloudtrail create-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --s3-bucket-name "$TRAIL_BUCKET_VALUE" \
  --s3-key-prefix "$TRAIL_PREFIX" \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --output json \
  > "$EVIDENCE_DIR/change/03_create_trail.json"

cat > "$EVIDENCE_DIR/change/04_management_event_selector.json" <<'SELECTOR'
[
  {
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [],
    "ExcludeManagementEventSources": []
  }
]
SELECTOR

aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --event-selectors "file://$EVIDENCE_DIR/change/04_management_event_selector.json" \
  --output json \
  > "$EVIDENCE_DIR/change/05_put_event_selectors.json"

aws cloudtrail start-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

sleep 5

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/03_event_selectors.json"

IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" != "True" ]; then
  echo "ERROR: Trail was created, but IsLogging is not True." >&2
  echo "Use 03_delete_cloudtrail_trail.sh after investigating the evidence." >&2
  exit 1
fi

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query '{IsLogging:IsLogging,StartLoggingTime:StartLoggingTime,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError}' \
  --output table

echo "Temporary Trail creation completed."
echo "Next: ./02_check_cloudtrail_trail.sh"
echo "Evidence: $EVIDENCE_DIR"

