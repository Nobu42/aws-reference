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
  ./03_delete_cloudtrail_trail.sh [trail-name] [expected-trail-bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  ./03_delete_cloudtrail_trail.sh
  SKIP_CONFIRM=true ./03_delete_cloudtrail_trail.sh
USAGE
}

confirm_delete() {
  if [ "${SKIP_CONFIRM:-false}" = "true" ]; then
    return 0
  fi

  printf 'Type "delete" to delete the temporary Trail and its log bucket: '
  read -r ANSWER
  if [ "$ANSWER" != "delete" ]; then
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

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: Required command not found: aws" >&2
  exit 1
fi

readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_delete_trail"

mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/after"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  echo "No deletion was performed." >&2
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

EXPECTED_TRAIL_BUCKET="${2:-nobu-iac-lab-cloudtrail-${ACCOUNT_ID}}"

if [ "$TRAIL_BUCKET" != "$EXPECTED_TRAIL_BUCKET" ]; then
  echo "ERROR: Trail bucket does not match the expected lab bucket." >&2
  echo "Trail bucket   : $TRAIL_BUCKET" >&2
  echo "Expected bucket: $EXPECTED_TRAIL_BUCKET" >&2
  echo "No deletion was performed." >&2
  exit 1
fi

echo "================================================"
echo "Delete temporary CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/03_event_selectors.json"

confirm_delete

aws cloudtrail stop-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

aws cloudtrail delete-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

if aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  2> "$EVIDENCE_DIR/after/01_delete_bucket_policy_error.txt"; then

  rm -f "$EVIDENCE_DIR/after/01_delete_bucket_policy_error.txt"
fi

BUCKET_DELETED=false
ATTEMPT=1

while [ "$ATTEMPT" -le 6 ]; do
  echo "Emptying Trail log bucket. Attempt: $ATTEMPT/6"

  aws s3 rm "s3://$TRAIL_BUCKET" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --recursive

  if aws s3api delete-bucket \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$TRAIL_BUCKET" \
    --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
    2> "$EVIDENCE_DIR/after/02_delete_bucket_error_attempt_${ATTEMPT}.txt"; then

    rm -f "$EVIDENCE_DIR/after/02_delete_bucket_error_attempt_${ATTEMPT}.txt"
    BUCKET_DELETED=true
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 10
done

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/03_trail_after_delete.json"

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteTrail \
  --max-results 10 \
  --output json \
  > "$EVIDENCE_DIR/after/04_delete_trail_events.json" || true

if [ "$BUCKET_DELETED" != "true" ]; then
  echo "ERROR: Trail was deleted, but the log bucket could not be deleted." >&2
  echo "Review the delete errors, wait for delayed delivery, and rerun cleanup manually." >&2
  echo "Evidence: $EVIDENCE_DIR" >&2
  exit 1
fi

echo "Temporary Trail and log bucket deletion completed."
echo "Evidence: $EVIDENCE_DIR"
