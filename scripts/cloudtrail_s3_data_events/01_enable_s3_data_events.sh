#!/bin/bash

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly DEFAULT_BUCKET_NAME="${BUCKET_NAME:-nobu-terraform-iac-lab-upload}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_s3_data_events}"

export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
    [trail-name] [bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, BUCKET_NAME
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
    nobu-iac-lab-trail nobu-terraform-iac-lab-upload
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
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

readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly BUCKET_NAME_VALUE="${2:-$DEFAULT_BUCKET_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_enable_s3_data_events"

require_command aws
mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/change" "$EVIDENCE_DIR/after"

echo "================================================"
echo "Enable CloudTrail S3 write-only data events"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $BUCKET_NAME_VALUE"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

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
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  > "$EVIDENCE_DIR/before/01_head_bucket.json"

TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  echo "Check the Trail name and Home Region." >&2
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
  echo "Run this script with REGION=$HOME_REGION." >&2
  exit 1
fi

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/02_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/03_trail_status.json"

IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" != "True" ]; then
  echo "ERROR: Trail is not logging: $TRAIL_NAME_VALUE" >&2
  exit 1
fi

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/04_event_selectors_full.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query EventSelectors \
  --output json \
  > "$EVIDENCE_DIR/before/05_event_selectors_only.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query AdvancedEventSelectors \
  --output json \
  > "$EVIDENCE_DIR/before/06_advanced_event_selectors_only.json"

BASIC_SELECTOR_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors || `[]`)' \
  --output text)

ADVANCED_SELECTOR_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(AdvancedEventSelectors || `[]`)' \
  --output text)

if [ "$ADVANCED_SELECTOR_COUNT" -ne 0 ]; then
  echo "ERROR: Advanced Event Selectors are configured." >&2
  echo "This learning script will not overwrite them." >&2
  exit 1
fi

if [ "$BASIC_SELECTOR_COUNT" -ne 1 ]; then
  echo "ERROR: Expected one basic Event Selector, found: $BASIC_SELECTOR_COUNT" >&2
  echo "This learning script will not overwrite a custom selector configuration." >&2
  exit 1
fi

READ_WRITE_TYPE=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[0].ReadWriteType' \
  --output text)

INCLUDE_MANAGEMENT_EVENTS=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[0].IncludeManagementEvents' \
  --output text)

DATA_RESOURCE_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors[0].DataResources || `[]`)' \
  --output text)

EXCLUDED_SOURCE_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors[0].ExcludeManagementEventSources || `[]`)' \
  --output text)

if [ "$READ_WRITE_TYPE" != "All" ] \
  || [ "$INCLUDE_MANAGEMENT_EVENTS" != "True" ] \
  || [ "$DATA_RESOURCE_COUNT" -ne 0 ] \
  || [ "$EXCLUDED_SOURCE_COUNT" -ne 0 ]; then
  echo "ERROR: Existing Event Selector is not the expected default management-event configuration." >&2
  echo "This learning script will not overwrite it." >&2
  exit 1
fi

cat > "$EVIDENCE_DIR/change/01_desired_event_selectors.json" <<EOF
[
  {
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [],
    "ExcludeManagementEventSources": []
  },
  {
    "ReadWriteType": "WriteOnly",
    "IncludeManagementEvents": false,
    "DataResources": [
      {
        "Type": "AWS::S3::Object",
        "Values": [
          "arn:aws:s3:::$BUCKET_NAME_VALUE/"
        ]
      }
    ],
    "ExcludeManagementEventSources": []
  }
]
EOF

printf '%s\n' "$TRAIL_NAME_VALUE" > "$EVIDENCE_DIR/trail_name.txt"
printf '%s\n' "$BUCKET_NAME_VALUE" > "$EVIDENCE_DIR/bucket_name.txt"
printf '%s\n' "$ACCOUNT_ID" > "$EVIDENCE_DIR/account_id.txt"
printf '%s\n' "$REGION" > "$EVIDENCE_DIR/region.txt"

echo "=== Desired Event Selectors ==="
cat "$EVIDENCE_DIR/change/01_desired_event_selectors.json"

echo
echo "This change keeps all management events and adds write-only S3 object data events."
echo "Write-only data events include PutObject, DeleteObject, and multipart-upload writes."
echo "CloudTrail data event charges will apply."

if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  read -r -p "Type 'enable' to apply this Event Selector change: " CONFIRM

  if [ "$CONFIRM" != "enable" ]; then
    echo "Canceled. Before-change evidence remains at: $EVIDENCE_DIR"
    exit 0
  fi
fi

aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --event-selectors "file://$EVIDENCE_DIR/change/01_desired_event_selectors.json" \
  --output json \
  > "$EVIDENCE_DIR/after/01_put_event_selectors_response.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/02_event_selectors_full.json"

if ! grep -Fq "arn:aws:s3:::$BUCKET_NAME_VALUE/" "$EVIDENCE_DIR/after/02_event_selectors_full.json"; then
  echo "ERROR: Target bucket ARN was not found after the change." >&2
  echo "Restore immediately using:" >&2
  echo "  $SCRIPT_DIR/02_restore_s3_event_selectors.sh '$EVIDENCE_DIR'" >&2
  exit 1
fi

# 復元時に「有効化処理を最後まで完了した証跡」だけを判別できるようにする。
printf '%s\n' "S3 Data Event enable completed." > "$EVIDENCE_DIR/ENABLE_COMPLETED"

cat > "$EVIDENCE_DIR/NEXT_STEPS.txt" <<EOF
1. Event Selectorの反映を待つため、5分程度待機する。
2. Railsアプリケーションから新しい画像をアップロードする。
3. CloudTrailログ配信を待つため、5分から15分程度待機する。
4. PutObjectを確認する:
   $SCRIPT_DIR/03_check_s3_putobject_events.sh "$TRAIL_NAME_VALUE" "$BUCKET_NAME_VALUE"
5. 確認後、変更前のEvent Selectorへ切り戻す:
   $SCRIPT_DIR/02_restore_s3_event_selectors.sh "$EVIDENCE_DIR"
6. Day 3の確認完了後、一時Trailを削除する:
   $REPOSITORY_ROOT/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
EOF

echo "================================================"
echo "S3データイベントを有効化した。"
echo "証跡ディレクトリ: $EVIDENCE_DIR"
echo "切り戻し時は、上記の証跡ディレクトリをそのまま指定する。"
echo
cat "$EVIDENCE_DIR/NEXT_STEPS.txt"
echo "================================================"
