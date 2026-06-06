#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROFILE="learning"
REGION="ap-northeast-1"
BUCKET="nobu-terraform-iac-lab-upload"
EXPECTED_ACCOUNT_ID="445405559057"

EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_s3_security_check"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/screenshots"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "Error: Unexpected AWS account: $ACCOUNT_ID"
  exit 1
fi

echo "Evidence: $EVIDENCE_DIR"
echo "Account : $ACCOUNT_ID"
echo "Bucket  : $BUCKET"
