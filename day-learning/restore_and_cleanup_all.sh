#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
TRAIL_NAME="nobu-iac-lab-trail"

REPO_ROOT="/Users/nobu/aws-reference"

S3_DATA_EVENTS_EVIDENCE_DIR="${REPO_ROOT}/evidence/cloudtrail_s3_data_events"
CLOUDWATCH_LOGS_EVIDENCE_DIR="${REPO_ROOT}/evidence/cloudtrail_cloudwatch_logs_lab"

RESTORE_S3_DATA_EVENTS="${REPO_ROOT}/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh"
RESTORE_CLOUDWATCH_LOGS="${REPO_ROOT}/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh"
DELETE_TRAIL="${REPO_ROOT}/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh"
CLEANUP_NETWORK="${REPO_ROOT}/scripts/cleanup_network.sh"

find_latest_valid_dir() {
  local base_dir="$1"
  local pattern="$2"
  local required_file="$3"

  if [ ! -d "$base_dir" ]; then
    return 1
  fi

  find "$base_dir" \
    -type d \
    -name "$pattern" \
    -exec test -s "{}/$required_file" \; \
    -print \
    | sort -r \
    | head -n 1
}

echo "================================================"
echo "Restore temporary CloudTrail related settings"
echo "Profile : ${PROFILE}"
echo "Region  : ${REGION}"
echo "Trail   : ${TRAIL_NAME}"
echo "CWD     : $(pwd)"
echo "================================================"

echo
echo "1. Restore S3 Data Events"
LATEST_S3_DATA_EVENTS_DIR="$(
  find_latest_valid_dir \
    "$S3_DATA_EVENTS_EVIDENCE_DIR" \
    "*_enable_s3_data_events" \
    "trail_name.txt" || true
)"

if [ -n "$LATEST_S3_DATA_EVENTS_DIR" ]; then
  echo "Using evidence: $LATEST_S3_DATA_EVENTS_DIR"
  "$RESTORE_S3_DATA_EVENTS" "$LATEST_S3_DATA_EVENTS_DIR"
else
  echo "SKIP: valid S3 Data Events evidence directory was not found."
fi

echo
echo "2. Restore CloudTrail to CloudWatch Logs linkage"
LATEST_CLOUDWATCH_LOGS_DIR="$(
  find_latest_valid_dir \
    "$CLOUDWATCH_LOGS_EVIDENCE_DIR" \
    "*_enable_cloudwatch_logs" \
    "trail_name.txt" || true
)"

if [ -n "$LATEST_CLOUDWATCH_LOGS_DIR" ]; then
  echo "Using evidence: $LATEST_CLOUDWATCH_LOGS_DIR"
  "$RESTORE_CLOUDWATCH_LOGS" "$LATEST_CLOUDWATCH_LOGS_DIR"
else
  echo "SKIP: valid CloudWatch Logs evidence directory was not found."
fi

echo
echo "3. Check current CloudTrail settings before deleting Trail"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --query 'EventSelectors[].{ReadWriteType:ReadWriteType,ManagementEvents:IncludeManagementEvents,DataResourceCount:length(DataResources)}' \
  --output table \
  --no-cli-pager || true

aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.{Name:Name,S3Bucket:S3BucketName,CloudWatchLogs:CloudWatchLogsLogGroupArn,CloudWatchLogsRole:CloudWatchLogsRoleArn}' \
  --output table \
  --no-cli-pager || true

echo
echo "4. Delete temporary CloudTrail Trail"
"$DELETE_TRAIL"

echo
echo "5. Cleanup network resources"
"$CLEANUP_NETWORK"

echo
echo "================================================"
echo "All cleanup steps completed."
echo "Recommended final check:"
echo "  ${REPO_ROOT}/scripts/check_cleanup.sh"
echo "  ${REPO_ROOT}/scripts/check_cost.sh"
echo "================================================"
