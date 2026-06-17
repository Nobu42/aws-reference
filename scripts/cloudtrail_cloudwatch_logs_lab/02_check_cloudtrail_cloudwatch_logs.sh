#!/bin/bash

# -----------------------------------------------------------------------------
# CloudTrail -> CloudWatch Logs配信確認スクリプト
#
# 目的:
#   一時TrailからCloudWatch LogsへManagement Eventが届いているかを確認する。
#
# 注意:
#   CloudTrailからCloudWatch Logsへの配信は数分遅れる場合がある。
# -----------------------------------------------------------------------------

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly LOG_GROUP_NAME="${LOG_GROUP_NAME:-/nobu-iac-lab/cloudtrail/management-events}"
readonly MAX_ATTEMPTS="${MAX_ATTEMPTS:-6}"
readonly WAIT_SECONDS="${WAIT_SECONDS:-30}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_cloudwatch_logs_lab}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_check_cloudwatch_logs"

export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

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

TRAIL_LOG_GROUP_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsLogGroupArn' \
  --output text)

TRAIL_ROLE_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsRoleArn' \
  --output text)

echo "================================================"
echo "Check CloudTrail to CloudWatch Logs"
echo "Profile     : $PROFILE"
echo "Region      : $REGION"
echo "Account     : $ACCOUNT_ID"
echo "Trail       : $TRAIL_NAME"
echo "Log Group   : $LOG_GROUP_NAME"
echo "Trail CWLogs: $TRAIL_LOG_GROUP_ARN"
echo "Trail Role  : $TRAIL_ROLE_ARN"
echo "Evidence    : $EVIDENCE_DIR"
echo "================================================"

if [ "$TRAIL_LOG_GROUP_ARN" = "None" ] || [ -z "$TRAIL_LOG_GROUP_ARN" ]; then
  echo "ERROR: Trail is not connected to CloudWatch Logs." >&2
  echo "Run this first:" >&2
  echo "  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh" >&2
  exit 1
fi

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output table \
  --no-cli-pager

# 配信確認用に読み取りAPIを実行する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/01_generate_sts_get_caller_identity.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/02_generate_get_trail_status.json"

START_TIME_MS=$(( ($(date +%s) - 7200) * 1000 ))
ATTEMPT=1
EVENT_COUNT=0

while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
  echo "Checking CloudWatch Logs delivery. Attempt: ${ATTEMPT}/${MAX_ATTEMPTS}"

  aws logs describe-log-streams \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by LastEventTime \
    --descending \
    --max-items 10 \
    --query 'logStreams[].{LogStream:logStreamName,LastEventTime:lastEventTimestamp,StoredBytes:storedBytes}' \
    --output table \
    --no-cli-pager \
    > "$EVIDENCE_DIR/03_log_streams_attempt_${ATTEMPT}.txt" || true

  cat "$EVIDENCE_DIR/03_log_streams_attempt_${ATTEMPT}.txt"

  aws logs filter-log-events \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP_NAME" \
    --start-time "$START_TIME_MS" \
    --limit 20 \
    --output json \
    > "$EVIDENCE_DIR/04_filter_log_events_attempt_${ATTEMPT}.json"

  EVENT_COUNT=$(aws logs filter-log-events \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP_NAME" \
    --start-time "$START_TIME_MS" \
    --limit 20 \
    --query 'length(events)' \
    --output text)

  if [ "$EVENT_COUNT" -gt 0 ]; then
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  if [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; then
    sleep "$WAIT_SECONDS"
  fi
done

echo "================================================"
echo "CloudTrail CloudWatch Logs check completed."
echo "Event count: $EVENT_COUNT"
echo "Evidence   : $EVIDENCE_DIR"
echo "================================================"

if [ "$EVENT_COUNT" -eq 0 ]; then
  echo "No CloudTrail events were found in CloudWatch Logs yet."
  echo "Wait a few minutes and run this script again."
  exit 1
fi

echo "OK: CloudTrail events are delivered to CloudWatch Logs."
