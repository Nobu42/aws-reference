#!/bin/bash

# -----------------------------------------------------------------------------
# CloudTrail -> CloudWatch Logs連携切り戻しスクリプト
#
# 目的:
#   01_enable_cloudtrail_cloudwatch_logs.shで変更したTrailのCloudWatch Logs連携を
#   変更前状態へ戻す。
#
# 安全上の注意:
#   - enable時のEvidenceディレクトリを必ず指定する
#   - 変更前にCloudWatch Logs連携がなかった場合は連携を解除する
#   - 変更前に連携があった場合は元のARNへ戻す
# -----------------------------------------------------------------------------

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly KEEP_LOG_GROUP="${KEEP_LOG_GROUP:-false}"

# 実行場所に依存せずEvidence候補を扱えるようにする。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_cloudwatch_logs_lab}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"

# AWS CLIのページャ停止とLocalStack等への誤接続防止。
export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
    <enable-evidence-dir>

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, KEEP_LOG_GROUP, SKIP_CONFIRM

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
    /Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab/20260617_090000_enable_cloudwatch_logs
USAGE
}

confirm_restore() {
  # TrailのCloudWatch Logs連携を変更するため、手動実行時は確認文字列を要求する。
  # 自動片付け用スクリプトから呼ぶ場合はSKIP_CONFIRM=trueで省略できる。
  if [ "${SKIP_CONFIRM:-false}" = "true" ]; then
    return 0
  fi

  printf 'Type "restore" to restore CloudTrail CloudWatch Logs settings: '
  read -r ANSWER
  if [ "$ANSWER" != "restore" ]; then
    echo "Canceled."
    exit 1
  fi
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

ENABLE_EVIDENCE_DIR="$1"

required_file() {
  # 復元はenable時の証跡ファイルに依存する。
  # 空ファイルや指定間違いでは安全に戻せないため停止する。
  local file_path="$1"
  if [ ! -s "$file_path" ]; then
    echo "ERROR: Required restore file not found or empty: $file_path" >&2
    exit 1
  fi
}

required_file "$ENABLE_EVIDENCE_DIR/trail_name.txt"
required_file "$ENABLE_EVIDENCE_DIR/log_group_name.txt"
required_file "$ENABLE_EVIDENCE_DIR/role_name.txt"
required_file "$ENABLE_EVIDENCE_DIR/before_cloudwatch_logs_log_group_arn.txt"
required_file "$ENABLE_EVIDENCE_DIR/before_cloudwatch_logs_role_arn.txt"
required_file "$ENABLE_EVIDENCE_DIR/log_group_existed_before.txt"
required_file "$ENABLE_EVIDENCE_DIR/role_existed_before.txt"

# enable時に保存した復元材料を読み込む。
# before_* はTrailに元々設定されていたCloudWatch Logs連携先である。
TRAIL_NAME=$(cat "$ENABLE_EVIDENCE_DIR/trail_name.txt")
LOG_GROUP_NAME=$(cat "$ENABLE_EVIDENCE_DIR/log_group_name.txt")
ROLE_NAME=$(cat "$ENABLE_EVIDENCE_DIR/role_name.txt")
BEFORE_LOG_GROUP_ARN=$(cat "$ENABLE_EVIDENCE_DIR/before_cloudwatch_logs_log_group_arn.txt")
BEFORE_ROLE_ARN=$(cat "$ENABLE_EVIDENCE_DIR/before_cloudwatch_logs_role_arn.txt")
LOG_GROUP_EXISTED_BEFORE=$(cat "$ENABLE_EVIDENCE_DIR/log_group_existed_before.txt")
ROLE_EXISTED_BEFORE=$(cat "$ENABLE_EVIDENCE_DIR/role_existed_before.txt")

# 復元作業のEvidenceは、enable Evidence配下にrestore_<timestamp>として保存する。
# 「どの有効化を、いつ戻したか」がディレクトリ構造で分かるようにする。
RESTORE_EVIDENCE_DIR="$ENABLE_EVIDENCE_DIR/restore_${RUN_ID}"
mkdir -p "$RESTORE_EVIDENCE_DIR/before" "$RESTORE_EVIDENCE_DIR/after"

# 誤アカウントでTrailを更新しないため、現在の認証情報を確認する。
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

# 復元前の現在Trail設定を保存する。
# restore後にCloudWatchLogsLogGroupArn / RoleArnがどう変わったか比較できる。
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$RESTORE_EVIDENCE_DIR/before/01_trail.json"

echo "================================================"
echo "Restore CloudTrail CloudWatch Logs settings"
echo "Profile              : $PROFILE"
echo "Region               : $REGION"
echo "Account              : $ACCOUNT_ID"
echo "Trail                : $TRAIL_NAME"
echo "Log Group            : $LOG_GROUP_NAME"
echo "Role                 : $ROLE_NAME"
echo "Before Log Group ARN : $BEFORE_LOG_GROUP_ARN"
echo "Before Role ARN      : $BEFORE_ROLE_ARN"
echo "Log Group existed    : $LOG_GROUP_EXISTED_BEFORE"
echo "Role existed         : $ROLE_EXISTED_BEFORE"
echo "Keep Log Group       : $KEEP_LOG_GROUP"
echo "Evidence             : $RESTORE_EVIDENCE_DIR"
echo "================================================"

confirm_restore

# enable前にCloudWatch Logs連携がなかった場合は、空文字を指定して連携を解除する。
# つまり「ラボで追加した連携を外す」動きになる。
if [ "$BEFORE_LOG_GROUP_ARN" = "None" ] || [ -z "$BEFORE_LOG_GROUP_ARN" ]; then
  aws cloudtrail update-trail \
    --profile "$PROFILE" \
    --region "$REGION" \
    --name "$TRAIL_NAME" \
    --cloud-watch-logs-log-group-arn "" \
    --cloud-watch-logs-role-arn "" \
    --output json \
    > "$RESTORE_EVIDENCE_DIR/after/01_update_trail_restore.json"
else
  # enable前に既存連携があった場合は、そのARNへ戻す。
  # 既存の監視・ログ配信を消さないための分岐である。
  aws cloudtrail update-trail \
    --profile "$PROFILE" \
    --region "$REGION" \
    --name "$TRAIL_NAME" \
    --cloud-watch-logs-log-group-arn "$BEFORE_LOG_GROUP_ARN" \
    --cloud-watch-logs-role-arn "$BEFORE_ROLE_ARN" \
    --output json \
    > "$RESTORE_EVIDENCE_DIR/after/01_update_trail_restore.json"
fi

# 復元後のTrail設定を証跡として保存する。
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  > "$RESTORE_EVIDENCE_DIR/after/02_trail.json"

# enable前にRoleが存在しなかった場合だけ、ラボで作成したRoleとして削除する。
# 既存Roleだった場合は、業務用途の可能性があるため削除しない。
if [ "$ROLE_EXISTED_BEFORE" = "false" ]; then
  aws iam delete-role-policy \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-name "CloudTrailToCloudWatchLogsLabPolicy" \
    2> "$RESTORE_EVIDENCE_DIR/after/03_delete_role_policy_error.txt" || true

  aws iam delete-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    2> "$RESTORE_EVIDENCE_DIR/after/04_delete_role_error.txt" || true
fi

# enable前にLog Groupが存在しなかった場合だけ、ラボで作成したLog Groupとして削除する。
# KEEP_LOG_GROUP=trueならログ確認用に残すこともできる。
if [ "$LOG_GROUP_EXISTED_BEFORE" = "false" ] && [ "$KEEP_LOG_GROUP" != "true" ]; then
  aws logs delete-log-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP_NAME" \
    2> "$RESTORE_EVIDENCE_DIR/after/05_delete_log_group_error.txt" || true
fi

echo "================================================"
echo "CloudTrail CloudWatch Logs settings restored."
echo "Evidence: $RESTORE_EVIDENCE_DIR"
echo
echo "If all Day 5〜7 checks are finished, delete the temporary Trail:"
echo "  /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh"
echo "================================================"
