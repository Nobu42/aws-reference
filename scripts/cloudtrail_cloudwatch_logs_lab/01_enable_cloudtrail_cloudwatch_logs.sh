#!/bin/bash

# -----------------------------------------------------------------------------
# 一時TrailをCloudWatch Logsへ連携する学習用スクリプト
#
# 目的:
#   Day 5〜7でCloudTrailイベントがCloudWatch Logsへ配信される流れを
#   実環境で確認できるようにする。
#
# 主な処理:
#   1. Caller Identityと一時Trailの存在を確認する
#   2. 変更前のCloudWatch Logs連携設定を証跡へ保存する
#   3. 学習用Log GroupとCloudTrail連携用IAM Roleを作成・設定する
#   4. TrailへCloudWatch Logs Log GroupとRoleを紐づける
#   5. 確認用の読み取りAPIを実行し、CloudTrailイベントを発生させる
#
# 安全上の注意:
#   - 想定AWSアカウント以外では処理を停止する
#   - 一時Trailが存在しない場合は処理を停止する
#   - 実案件の既存Trail変更には使用しない
# -----------------------------------------------------------------------------

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly LOG_GROUP_NAME="${LOG_GROUP_NAME:-/nobu-iac-lab/cloudtrail/management-events}"
readonly ROLE_NAME="${ROLE_NAME:-nobu-iac-lab-cloudtrail-cwlogs-role}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-7}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_cloudwatch_logs_lab}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_enable_cloudwatch_logs"

export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME
  LOG_GROUP_NAME, ROLE_NAME, RETENTION_DAYS
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh
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

  printf 'Type "enable" to connect the temporary Trail to CloudWatch Logs: '
  read -r ANSWER
  if [ "$ANSWER" != "enable" ]; then
    echo "Canceled."
    exit 1
  fi
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage >&2
  exit 2
fi

require_command aws

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

TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Temporary Trail was not found: $TRAIL_NAME" >&2
  echo "Run this first:" >&2
  echo "  /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh" >&2
  exit 1
fi

TRAIL_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.TrailARN' \
  --output text)

BEFORE_LOG_GROUP_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsLogGroupArn' \
  --output text)

BEFORE_ROLE_ARN=$(aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --query 'Trail.CloudWatchLogsRoleArn' \
  --output text)

echo "$TRAIL_NAME" > "$EVIDENCE_DIR/trail_name.txt"
echo "$LOG_GROUP_NAME" > "$EVIDENCE_DIR/log_group_name.txt"
echo "$ROLE_NAME" > "$EVIDENCE_DIR/role_name.txt"
echo "$BEFORE_LOG_GROUP_ARN" > "$EVIDENCE_DIR/before_cloudwatch_logs_log_group_arn.txt"
echo "$BEFORE_ROLE_ARN" > "$EVIDENCE_DIR/before_cloudwatch_logs_role_arn.txt"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/02_trail_status.json"

if aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/03_log_groups.json"; then
  :
fi

LOG_GROUP_EXISTS=false
if aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[].logGroupName' \
  --output text \
  | tr '\t' '\n' \
  | grep -Fx "$LOG_GROUP_NAME" >/dev/null 2>&1; then
  LOG_GROUP_EXISTS=true
fi

ROLE_EXISTS=false
if aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/04_role.json" 2> "$EVIDENCE_DIR/before/04_role_error.txt"; then
  ROLE_EXISTS=true
  rm -f "$EVIDENCE_DIR/before/04_role_error.txt"
fi

echo "$LOG_GROUP_EXISTS" > "$EVIDENCE_DIR/log_group_existed_before.txt"
echo "$ROLE_EXISTS" > "$EVIDENCE_DIR/role_existed_before.txt"

echo "================================================"
echo "Enable CloudTrail to CloudWatch Logs"
echo "Profile           : $PROFILE"
echo "Region            : $REGION"
echo "Account           : $ACCOUNT_ID"
echo "Trail             : $TRAIL_NAME"
echo "Trail ARN         : $TRAIL_ARN"
echo "Log Group         : $LOG_GROUP_NAME"
echo "IAM Role          : $ROLE_NAME"
echo "Retention days    : $RETENTION_DAYS"
echo "Before Log Group  : $BEFORE_LOG_GROUP_ARN"
echo "Before Role       : $BEFORE_ROLE_ARN"
echo "Evidence          : $EVIDENCE_DIR"
echo "================================================"
echo "This creates or updates lab-only CloudWatch Logs and IAM Role settings."
echo "CloudTrail management event delivery to CloudWatch Logs may take several minutes."

confirm_change

if [ "$LOG_GROUP_EXISTS" = "false" ]; then
  aws logs create-log-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP_NAME"
fi

aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days "$RETENTION_DAYS"

LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query "logGroups[?logGroupName=='${LOG_GROUP_NAME}'].arn | [0]" \
  --output text)

if [ "$LOG_GROUP_ARN" = "None" ] || [ -z "$LOG_GROUP_ARN" ]; then
  echo "ERROR: Could not resolve Log Group ARN: $LOG_GROUP_NAME" >&2
  exit 1
fi

cat > "$EVIDENCE_DIR/change/01_cloudtrail_assume_role_policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

if [ "$ROLE_EXISTS" = "false" ]; then
  aws iam create-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$EVIDENCE_DIR/change/01_cloudtrail_assume_role_policy.json" \
    --description "Day learning temporary role for CloudTrail to CloudWatch Logs" \
    --tags Key=Project,Value=nobu-iac-lab Key=Purpose,Value=cloudtrail-cloudwatch-logs-lab \
    --output json \
    > "$EVIDENCE_DIR/change/02_create_role.json"
fi

aws iam update-assume-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-document "file://$EVIDENCE_DIR/change/01_cloudtrail_assume_role_policy.json"

ROLE_ARN=$(aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)

LOG_STREAM_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP_NAME}:log-stream:${ACCOUNT_ID}_CloudTrail_*"

cat > "$EVIDENCE_DIR/change/03_cloudtrail_logs_policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "${LOG_STREAM_ARN}"
      ]
    },
    {
      "Sid": "AWSCloudTrailPutLogEvents",
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${LOG_STREAM_ARN}"
      ]
    }
  ]
}
POLICY

aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "CloudTrailToCloudWatchLogsLabPolicy" \
  --policy-document "file://$EVIDENCE_DIR/change/03_cloudtrail_logs_policy.json"

# IAM Roleの作成・Policy反映直後はCloudTrailからAssumeRoleできない場合があるため少し待つ。
sleep 10

aws cloudtrail update-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --cloud-watch-logs-log-group-arn "$LOG_GROUP_ARN" \
  --cloud-watch-logs-role-arn "$ROLE_ARN" \
  --output json \
  > "$EVIDENCE_DIR/change/04_update_trail.json"

aws cloudtrail start-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME"

# CloudTrailへ記録される読み取りAPIを実行し、CloudWatch Logs配信確認用のイベントを作る。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/change/05_generate_sts_get_caller_identity.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/change/06_generate_get_trail_status.json"

aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/01_trail.json"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/02_log_group.json"

echo "================================================"
echo "CloudTrail to CloudWatch Logs was enabled."
echo "Evidence: $EVIDENCE_DIR"
echo
echo "Next:"
echo "  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh"
echo
echo "Restore when Day 5〜7 checks are finished:"
echo "  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \\"
echo "    \"$EVIDENCE_DIR\""
echo "================================================"
