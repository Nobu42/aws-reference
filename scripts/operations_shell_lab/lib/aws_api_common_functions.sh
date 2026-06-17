#!/bin/bash

# -----------------------------------------------------------------------------
# Day 17ハンズオン用の共通関数ファイル。
#
# 金融系の保守的な運用シェルを読めるように、関数、戻り値、declare変数、
# sed、awk、AWS CLIラッパーを意図的に多めに使っている。
# 実案件のファイルを複製したものではなく、学習用に作成した教材である。
# -----------------------------------------------------------------------------

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "ERROR: This file must be sourced, not executed." >&2
  exit 2
fi

declare -r OP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r OP_LAB_DIR="$(cd "${OP_LIB_DIR}/.." && pwd)"
declare -r OP_REPO_ROOT="$(cd "${OP_LAB_DIR}/../.." && pwd)"
declare -r OP_FIXTURE_DIR="${OP_LAB_DIR}/fixtures"

declare -r OP_RC_OK=0
declare -r OP_RC_GENERAL=1
declare -r OP_RC_USAGE=2
declare -r OP_RC_VALIDATION=10
declare -r OP_RC_AWS=20
declare -r OP_RC_ACCOUNT=30

OP_LOG_FILE=""
OP_EVIDENCE_DIR=""
OP_LAST_STDOUT=""
OP_LAST_STDERR=""
OP_LAST_RC=0

op_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

op_trim() {
  awk '{$1=$1; print}'
}

op_log() {
  local level="$1"
  shift
  local message="$*"
  local line

  line="$(printf '%s [%s] %s' "$(op_timestamp)" "$level" "$message")"
  printf '%s\n' "$line"

  if [ -n "${OP_LOG_FILE:-}" ]; then
    printf '%s\n' "$line" >> "$OP_LOG_FILE"
  fi
}

op_log_error() {
  local message="$*"
  op_log "ERROR" "$message" >&2
}

op_require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    op_log_error "Required command not found: $command_name"
    return "$OP_RC_VALIDATION"
  fi

  return "$OP_RC_OK"
}

op_require_file() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    op_log_error "File not found: $file_path"
    return "$OP_RC_VALIDATION"
  fi

  if [ ! -r "$file_path" ]; then
    op_log_error "File is not readable: $file_path"
    return "$OP_RC_VALIDATION"
  fi

  return "$OP_RC_OK"
}

op_require_var() {
  local var_name="$1"
  local var_value="${!var_name:-}"

  if [ -z "$var_value" ]; then
    op_log_error "Required variable is empty: $var_name"
    return "$OP_RC_VALIDATION"
  fi

  return "$OP_RC_OK"
}

op_require_vars() {
  local var_name

  for var_name in "$@"; do
    op_require_var "$var_name" || return "$?"
  done

  return "$OP_RC_OK"
}

op_bool_is_true() {
  case "${1:-}" in
    true|TRUE|True|1|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

op_read_conf_value() {
  local conf_file="$1"
  local key="$2"

  awk -F= -v key="$key" '
    $0 ~ /^[[:space:]]*#/ { next }
    $0 ~ /^[[:space:]]*$/ { next }
    $1 == key {
      sub(/^[^=]*=/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print $0
      exit
    }
  ' "$conf_file"
}

op_dump_conf_summary() {
  local conf_file="$1"

  op_log "INFO" "Configuration summary from $conf_file"

  sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$conf_file" \
    | awk -F= '
        {
          key=$1
          value=$0
          sub(/^[^=]*=/, "", value)
          if (key ~ /PASSWORD|SECRET|TOKEN|KEY/) {
            value="********"
          }
          printf "  %-32s %s\n", key, value
        }
      ' | while IFS= read -r line; do
        op_log "INFO" "$line"
      done
}

op_init_evidence() {
  local evidence_root="$1"
  local work_name="$2"
  local run_id

  run_id="$(date +%Y%m%d_%H%M%S)_$$"
  OP_EVIDENCE_DIR="${OP_REPO_ROOT}/${evidence_root}/${run_id}_${work_name}"
  OP_LOG_FILE="${OP_EVIDENCE_DIR}/run.log"

  mkdir -p \
    "$OP_EVIDENCE_DIR/stdout" \
    "$OP_EVIDENCE_DIR/stderr" \
    "$OP_EVIDENCE_DIR/result"

  op_log "INFO" "Evidence directory: $OP_EVIDENCE_DIR"
  return "$OP_RC_OK"
}

op_json_value() {
  local key="$1"
  local file_path="$2"

  awk -v key="$key" '
    {
      line = $0
      gsub(/[{},"\r]/, "", line)
      n = split(line, parts, ":")
      if (n >= 2) {
        k = parts[1]
        v = parts[2]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (k == key) {
          print v
          exit
        }
      }
    }
  ' "$file_path"
}

op_json_has_text() {
  local needle="$1"
  local file_path="$2"
  local compact_needle

  if grep -Fq "$needle" "$file_path"; then
    return "$OP_RC_OK"
  fi

  compact_needle="$(printf '%s' "$needle" | sed 's/[[:space:]]//g')"
  if sed 's/[[:space:]]//g' "$file_path" | grep -Fq "$compact_needle"; then
    return "$OP_RC_OK"
  fi

  return "$OP_RC_GENERAL"
}

op_fixture_path() {
  local scenario="$1"
  local operation="$2"
  local kind="$3"

  printf '%s/%s/%s.%s\n' "$OP_FIXTURE_DIR" "$scenario" "$operation" "$kind"
}

op_copy_fixture_or_default() {
  local scenario="$1"
  local operation="$2"
  local output_file="$3"
  local error_file="$4"
  local fixture
  local default_fixture

  fixture="$(op_fixture_path "$scenario" "$operation" json)"
  default_fixture="$(op_fixture_path ok "$operation" json)"

  if [ -f "$fixture" ]; then
    cp "$fixture" "$output_file"
    : > "$error_file"
    return "$OP_RC_OK"
  fi

  if [ -f "$default_fixture" ]; then
    cp "$default_fixture" "$output_file"
    : > "$error_file"
    return "$OP_RC_OK"
  fi

  printf 'Mock fixture not found: %s\n' "$operation" > "$error_file"
  : > "$output_file"
  return "$OP_RC_AWS"
}

op_run_mock_aws() {
  local operation="$1"
  local output_file="$2"
  local error_file="$3"
  local scenario="${MOCK_SCENARIO:-ok}"
  local error_fixture

  case "${scenario}:${operation}" in
    access_denied:get_bucket_policy)
      error_fixture="$(op_fixture_path access_denied get_bucket_policy_error txt)"
      cp "$error_fixture" "$error_file"
      : > "$output_file"
      return 255
      ;;
    *)
      op_copy_fixture_or_default "$scenario" "$operation" "$output_file" "$error_file"
      return "$?"
      ;;
  esac
}

op_run_real_aws() {
  local output_file="$1"
  local error_file="$2"
  shift 2

  "$@" > "$output_file" 2> "$error_file"
  return "$?"
}

op_run_aws() {
  local operation="$1"
  local output_file="$2"
  local error_file="$3"
  local display_command="$4"
  shift 4
  local rc

  op_log "INFO" "AWS command: $display_command"

  if [ "${RUN_MODE:-mock}" = "mock" ]; then
    op_run_mock_aws "$operation" "$output_file" "$error_file"
    rc=$?
  else
    op_run_real_aws "$output_file" "$error_file" "$@"
    rc=$?
  fi

  OP_LAST_STDOUT="$output_file"
  OP_LAST_STDERR="$error_file"
  OP_LAST_RC="$rc"

  if [ "$rc" -ne 0 ]; then
    op_log_error "AWS command failed: operation=$operation rc=$rc stderr=$error_file"
    return "$OP_RC_AWS"
  fi

  op_log "INFO" "AWS command succeeded: operation=$operation"
  return "$OP_RC_OK"
}

op_assert_account() {
  local expected="$1"
  local caller_identity_file="$2"
  local actual

  actual="$(op_json_value Account "$caller_identity_file")"

  if [ "$actual" != "$expected" ]; then
    op_log_error "Unexpected AWS account: actual=$actual expected=$expected"
    return "$OP_RC_ACCOUNT"
  fi

  op_log "INFO" "Account check OK: $actual"
  return "$OP_RC_OK"
}

op_report_result() {
  local check_name="$1"
  local status="$2"
  local detail="$3"
  local result_file="${OP_EVIDENCE_DIR}/result/check_summary.tsv"

  if [ ! -f "$result_file" ]; then
    printf 'check\tstatus\tdetail\n' > "$result_file"
  fi

  printf '%s\t%s\t%s\n' "$check_name" "$status" "$detail" >> "$result_file"
  op_log "INFO" "RESULT ${check_name}: ${status} - ${detail}"
}

op_return_or_exit() {
  local rc="$1"
  return "$rc"
}

return 0
