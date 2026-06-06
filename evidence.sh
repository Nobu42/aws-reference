#!/bin/bash
set -euo pipefail

: "${PROFILE:?Run this script through ./s3_security_check_01.sh}"
: "${REGION:?Run this script through ./s3_security_check_01.sh}"
: "${BUCKET:?Run this script through ./s3_security_check_01.sh}"
: "${ACCOUNT_ID:?Run this script through ./s3_security_check_01.sh}"
: "${EVIDENCE_DIR:?Run this script through ./s3_security_check_01.sh}"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"

aws s3api list-buckets \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/01_list_buckets.json"

aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --bucket "$BUCKET" \
  --output json \
  > "$EVIDENCE_DIR/before/02_bucket_location.json"

if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$ACCOUNT_ID"; then
  echo "head-bucket exit code: 0"
else
  status=$?
  echo "head-bucket exit code: $status"
  exit "$status"
fi
