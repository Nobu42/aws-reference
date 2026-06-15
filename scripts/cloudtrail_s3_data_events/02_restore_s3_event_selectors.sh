#!/bin/bash

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
    <enable-evidence-directory>

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
    /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/20260612_070000_enable_s3_data_events
USAGE
}

json_array_has_values() {
  ! grep -Eq '^[[:space:]]*(null|\[\])[[:space:]]*$' "$1"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

readonly EVIDENCE_DIR="$1"
readonly BASIC_SELECTORS_FILE="$EVIDENCE_DIR/before/05_event_selectors_only.json"
readonly ADVANCED_SELECTORS_FILE="$EVIDENCE_DIR/before/06_advanced_event_selectors_only.json"
readonly TRAIL_NAME_FILE="$EVIDENCE_DIR/trail_name.txt"
readonly ACCOUNT_ID_FILE="$EVIDENCE_DIR/account_id.txt"
readonly REGION_FILE="$EVIDENCE_DIR/region.txt"

for required_file in \
  "$BASIC_SELECTORS_FILE" \
  "$ADVANCED_SELECTORS_FILE" \
  "$TRAIL_NAME_FILE" \
  "$ACCOUNT_ID_FILE" \
  "$REGION_FILE"; do
  if [ ! -s "$required_file" ]; then
    echo "ERROR: Required restore file not found or empty: $required_file" >&2
    echo "The specified directory is incomplete and cannot be used for restore." >&2
    echo "Use the exact Evidence directory printed by the successful enable run." >&2
    echo "Complete restore candidates:" >&2

    for candidate in "$REPOSITORY_ROOT"/evidence/cloudtrail_s3_data_events/*_enable_s3_data_events; do
      [ -d "$candidate" ] || continue
      [ -s "$candidate/before/05_event_selectors_only.json" ] || continue
      [ -s "$candidate/before/06_advanced_event_selectors_only.json" ] || continue
      [ -s "$candidate/trail_name.txt" ] || continue
      [ -s "$candidate/account_id.txt" ] || continue
      [ -s "$candidate/region.txt" ] || continue
      [ -s "$candidate/after/02_event_selectors_full.json" ] || continue
      echo "  $candidate" >&2
    done

    exit 1
  fi
done

readonly TRAIL_NAME_VALUE="$(cat "$TRAIL_NAME_FILE")"
readonly BACKUP_ACCOUNT_ID="$(cat "$ACCOUNT_ID_FILE")"
readonly REGION="$(cat "$REGION_FILE")"
readonly RESTORE_DIR="$EVIDENCE_DIR/restore_$(date +%Y%m%d_%H%M%S)"

if [ "$BACKUP_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Backup account ID is unexpected: $BACKUP_ACCOUNT_ID" >&2
  exit 1
fi

CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$CURRENT_ACCOUNT_ID" != "$BACKUP_ACCOUNT_ID" ]; then
  echo "ERROR: Current account does not match the backup account." >&2
  echo "Current: $CURRENT_ACCOUNT_ID" >&2
  echo "Backup : $BACKUP_ACCOUNT_ID" >&2
  exit 1
fi

mkdir -p "$RESTORE_DIR/before" "$RESTORE_DIR/after"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$RESTORE_DIR/before/00_caller_identity.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$RESTORE_DIR/before/01_event_selectors_before_restore.json"

echo "================================================"
echo "Restore CloudTrail Event Selectors"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Backup  : $EVIDENCE_DIR"
echo "Evidence: $RESTORE_DIR"
echo "================================================"

if json_array_has_values "$BASIC_SELECTORS_FILE"; then
  RESTORE_TYPE="basic"
  RESTORE_FILE="$BASIC_SELECTORS_FILE"
elif json_array_has_values "$ADVANCED_SELECTORS_FILE"; then
  RESTORE_TYPE="advanced"
  RESTORE_FILE="$ADVANCED_SELECTORS_FILE"
else
  echo "ERROR: No restorable Event Selectors were found in the backup." >&2
  exit 1
fi

echo "Restore type: $RESTORE_TYPE"
cat "$RESTORE_FILE"

if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  read -r -p "Type 'restore' to restore the original Event Selectors: " CONFIRM

  if [ "$CONFIRM" != "restore" ]; then
    echo "Canceled."
    exit 0
  fi
fi

if [ "$RESTORE_TYPE" = "basic" ]; then
  aws cloudtrail put-event-selectors \
    --profile "$PROFILE" \
    --region "$REGION" \
    --trail-name "$TRAIL_NAME_VALUE" \
    --event-selectors "file://$RESTORE_FILE" \
    --output json \
    > "$RESTORE_DIR/after/01_put_event_selectors_response.json"
else
  aws cloudtrail put-event-selectors \
    --profile "$PROFILE" \
    --region "$REGION" \
    --trail-name "$TRAIL_NAME_VALUE" \
    --advanced-event-selectors "file://$RESTORE_FILE" \
    --output json \
    > "$RESTORE_DIR/after/01_put_event_selectors_response.json"
fi

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$RESTORE_DIR/after/02_event_selectors_after_restore.json"

if [ "$RESTORE_TYPE" = "basic" ]; then
  aws cloudtrail get-event-selectors \
    --profile "$PROFILE" \
    --region "$REGION" \
    --trail-name "$TRAIL_NAME_VALUE" \
    --query EventSelectors \
    --output json \
    > "$RESTORE_DIR/after/03_restored_event_selectors_only.json"

  RESTORED_SELECTORS_FILE="$RESTORE_DIR/after/03_restored_event_selectors_only.json"
else
  aws cloudtrail get-event-selectors \
    --profile "$PROFILE" \
    --region "$REGION" \
    --trail-name "$TRAIL_NAME_VALUE" \
    --query AdvancedEventSelectors \
    --output json \
    > "$RESTORE_DIR/after/03_restored_advanced_event_selectors_only.json"

  RESTORED_SELECTORS_FILE="$RESTORE_DIR/after/03_restored_advanced_event_selectors_only.json"
fi

if ! cmp -s "$RESTORE_FILE" "$RESTORED_SELECTORS_FILE"; then
  echo "ERROR: Restored Event Selectors do not exactly match the backup." >&2
  echo "Compare these files:" >&2
  echo "  $RESTORE_FILE" >&2
  echo "  $RESTORED_SELECTORS_FILE" >&2
  exit 1
fi

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutEventSelectors \
  --max-results 10 \
  --query 'Events[].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output json \
  > "$RESTORE_DIR/after/04_cloudtrail_put_event_selectors_events.json"

echo "================================================"
echo "Original Event Selectors restored."
echo "Backup and restored selector files match."
echo "Evidence: $RESTORE_DIR"
echo "Review the before and after JSON files before deleting any evidence."
echo
echo "Data Events are restored. The temporary Trail still exists."
echo "If all Day 3 checks are complete, delete the temporary Trail:"
echo "  $REPOSITORY_ROOT/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh"
echo "================================================"
