#!/bin/bash
set -euo pipefail

# 1. S3 Data Eventを元に戻す
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  "/Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/20260617_174721_enable_s3_data_events"

# 2. CloudTrail -> CloudWatch Logs連携を元に戻す
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
  "/Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab/20260617_185858_enable_cloudwatch_logs"

# 3. Trail削除前に、戻ったことを確認する
aws cloudtrail get-event-selectors \
  --profile learning \
  --region ap-northeast-1 \
  --trail-name nobu-iac-lab-trail \
  --query 'EventSelectors[].{ReadWriteType:ReadWriteType,ManagementEvents:IncludeManagementEvents,DataResourceCount:length(DataResources)}' \
  --output table \
  --no-cli-pager

aws cloudtrail get-trail \
  --profile learning \
  --region ap-northeast-1 \
  --name nobu-iac-lab-trail \
  --query 'Trail.{CloudWatchLogs:CloudWatchLogsLogGroupArn,CloudWatchLogsRole:CloudWatchLogsRoleArn}' \
  --output table \
  --no-cli-pager

# 4. 一時Trailを削除する
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
