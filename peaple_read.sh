#!/bin/bash
set -euo pipefail

: "${PROFILE:?Run this script through ./s3_security_check_01.sh}"
: "${BUCKET:?Run this script through ./s3_security_check_01.sh}"
: "${EVIDENCE_DIR:?Run this script through ./s3_security_check_01.sh}"

aws s3api list-buckets \
  --profile "$PROFILE" \
  --query 'Buckets[*].{Name:Name,CreationDate:CreationDate}' \
  --output table

aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --bucket "$BUCKET" \
  --output table

find "$EVIDENCE_DIR" -type f | sort
