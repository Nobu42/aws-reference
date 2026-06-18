#!/bin/bash

PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET="nobu-terraform-iac-lab-upload"

for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID BUCKET
do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
