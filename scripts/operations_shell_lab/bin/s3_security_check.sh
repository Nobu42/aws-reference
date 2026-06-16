#!/bin/bash

# -----------------------------------------------------------------------------
# Day 17 hands-on entry script.
#
# It sources a config file and a common function file, then performs read-only
# S3 security checks. Default RUN_MODE is mock, so no AWS API is called unless
# DAY17_RUN_MODE=real is specified.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"

COMMON_FILE="${LAB_DIR}/lib/aws_api_common_functions.sh"
DEFAULT_CONF="${LAB_DIR}/conf/s3_security_check.conf"
ACCOUNTS_CONF="${LAB_DIR}/conf/accounts.conf"

usage() {
  cat <<'USAGE'
Usage:
  s3_security_check.sh --conf <conf-file>

Examples:
  ./bin/s3_security_check.sh --conf conf/s3_security_check.conf

  DAY17_MOCK_SCENARIO=wrong_account \
    ./bin/s3_security_check.sh --conf conf/s3_security_check.conf

  DAY17_RUN_MODE=real \
    ./bin/s3_security_check.sh --conf conf/s3_security_check.conf
USAGE
}

CONF_FILE="$DEFAULT_CONF"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --conf)
      CONF_FILE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# shellcheck source=/dev/null
source "$COMMON_FILE"

op_require_file "$CONF_FILE" || exit "$?"
op_require_file "$ACCOUNTS_CONF" || exit "$?"

# This lab intentionally uses source for conf files to mirror many operations
# shells. Conf files in this lab are trusted learning files.
# shellcheck source=/dev/null
source "$CONF_FILE"
# shellcheck source=/dev/null
source "$ACCOUNTS_CONF"

# Environment overrides used by hands-on abnormal tests.
RUN_MODE="${DAY17_RUN_MODE:-${RUN_MODE:-mock}}"
MOCK_SCENARIO="${DAY17_MOCK_SCENARIO:-${MOCK_SCENARIO:-ok}}"

check_usage_vars() {
  op_require_vars \
    RUN_MODE \
    AWS_CMD \
    AWS_PROFILE \
    AWS_REGION \
    EXPECTED_ACCOUNT_ID \
    TARGET_BUCKET \
    EVIDENCE_ROOT
}

check_caller_identity() {
  local stdout_file="${OP_EVIDENCE_DIR}/stdout/01_caller_identity.json"
  local stderr_file="${OP_EVIDENCE_DIR}/stderr/01_caller_identity.err"
  local l_aws_cmd

  l_aws_cmd="${AWS_CMD} sts get-caller-identity --profile ${AWS_PROFILE} --output json"

  op_run_aws \
    "sts_get_caller_identity" \
    "$stdout_file" \
    "$stderr_file" \
    "$l_aws_cmd" \
    "$AWS_CMD" sts get-caller-identity \
      --profile "$AWS_PROFILE" \
      --output json || return "$?"

  op_assert_account "$EXPECTED_ACCOUNT_ID" "$stdout_file" || return "$?"
  op_report_result "caller_identity" "OK" "expected_account=${EXPECTED_ACCOUNT_ID}"
  return 0
}

check_public_access_block() {
  local stdout_file="${OP_EVIDENCE_DIR}/stdout/02_public_access_block.json"
  local stderr_file="${OP_EVIDENCE_DIR}/stderr/02_public_access_block.err"
  local l_aws_cmd

  if ! op_bool_is_true "${CHECK_PUBLIC_ACCESS_BLOCK:-true}"; then
    op_report_result "public_access_block" "SKIP" "disabled_by_conf"
    return 0
  fi

  l_aws_cmd="${AWS_CMD} s3api get-public-access-block --profile ${AWS_PROFILE} --region ${AWS_REGION} --bucket ${TARGET_BUCKET}"

  op_run_aws \
    "get_public_access_block" \
    "$stdout_file" \
    "$stderr_file" \
    "$l_aws_cmd" \
    "$AWS_CMD" s3api get-public-access-block \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --bucket "$TARGET_BUCKET" \
      --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
      --output json || return "$?"

  for required_text in \
    '"BlockPublicAcls": true' \
    '"IgnorePublicAcls": true' \
    '"BlockPublicPolicy": true' \
    '"RestrictPublicBuckets": true'; do
    op_json_has_text "$required_text" "$stdout_file" || {
      op_report_result "public_access_block" "NG" "missing=${required_text}"
      return "$OP_RC_VALIDATION"
    }
  done

  op_report_result "public_access_block" "OK" "all_four_settings_true"
  return 0
}

check_policy_status() {
  local stdout_file="${OP_EVIDENCE_DIR}/stdout/03_bucket_policy_status.json"
  local stderr_file="${OP_EVIDENCE_DIR}/stderr/03_bucket_policy_status.err"
  local l_aws_cmd

  if ! op_bool_is_true "${CHECK_POLICY_STATUS:-true}"; then
    op_report_result "bucket_policy_status" "SKIP" "disabled_by_conf"
    return 0
  fi

  l_aws_cmd="${AWS_CMD} s3api get-bucket-policy-status --profile ${AWS_PROFILE} --region ${AWS_REGION} --bucket ${TARGET_BUCKET}"

  op_run_aws \
    "get_bucket_policy_status" \
    "$stdout_file" \
    "$stderr_file" \
    "$l_aws_cmd" \
    "$AWS_CMD" s3api get-bucket-policy-status \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --bucket "$TARGET_BUCKET" \
      --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
      --output json || return "$?"

  if op_json_has_text '"IsPublic": false' "$stdout_file"; then
    op_report_result "bucket_policy_status" "OK" "IsPublic=false"
    return 0
  fi

  op_report_result "bucket_policy_status" "NG" "IsPublic_is_not_false"
  return "$OP_RC_VALIDATION"
}

check_bucket_policy() {
  local stdout_file="${OP_EVIDENCE_DIR}/stdout/04_bucket_policy.json"
  local stderr_file="${OP_EVIDENCE_DIR}/stderr/04_bucket_policy.err"
  local l_aws_cmd

  if ! op_bool_is_true "${CHECK_BUCKET_POLICY:-true}"; then
    op_report_result "bucket_policy" "SKIP" "disabled_by_conf"
    return 0
  fi

  l_aws_cmd="${AWS_CMD} s3api get-bucket-policy --profile ${AWS_PROFILE} --region ${AWS_REGION} --bucket ${TARGET_BUCKET} --query Policy --output text"

  op_run_aws \
    "get_bucket_policy" \
    "$stdout_file" \
    "$stderr_file" \
    "$l_aws_cmd" \
    "$AWS_CMD" s3api get-bucket-policy \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --bucket "$TARGET_BUCKET" \
      --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
      --query Policy \
      --output text || return "$?"

  op_json_has_text '"Sid": "DenyInsecureTransport"' "$stdout_file" || {
    op_report_result "bucket_policy" "NG" "DenyInsecureTransport_missing"
    return "$OP_RC_VALIDATION"
  }

  op_json_has_text '"Sid": "DenyOutdatedTLS"' "$stdout_file" || {
    op_report_result "bucket_policy" "WARN" "DenyOutdatedTLS_missing"
    return 0
  }

  op_report_result "bucket_policy" "OK" "required_deny_statements_found"
  return 0
}

main() {
  local rc

  check_usage_vars || return "$?"
  op_require_command sed || return "$?"
  op_require_command awk || return "$?"

  if [ "$RUN_MODE" = "real" ]; then
    op_require_command "$AWS_CMD" || return "$?"
  fi

  op_init_evidence "$EVIDENCE_ROOT" "s3_security_check" || return "$?"
  op_log "INFO" "RUN_MODE=${RUN_MODE}"
  op_log "INFO" "MOCK_SCENARIO=${MOCK_SCENARIO}"
  op_dump_conf_summary "$CONF_FILE"

  check_caller_identity || return "$?"
  check_public_access_block || return "$?"
  check_policy_status || return "$?"
  check_bucket_policy || return "$?"

  op_log "INFO" "All checks completed."
  return 0
}

main
rc=$?

case "$rc" in
  0)
    op_log "INFO" "Script finished successfully."
    ;;
  "$OP_RC_ACCOUNT")
    op_log_error "Script failed due to account mismatch."
    ;;
  "$OP_RC_AWS")
    op_log_error "Script failed due to AWS CLI error."
    ;;
  *)
    op_log_error "Script failed: rc=$rc"
    ;;
esac

exit "$rc"
