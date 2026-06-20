# Day 1-7 Learning Review: S3・CloudTrail・CloudWatch一気通し復習

## 使い方

Day 1からDay 7までの要点を、コマンド主体で一気に流す復習用ランブック。

同じターミナルで上から順に実行する。説明は最小限にし、手を動かして流れを掴むことを優先する。

```text
Day 1: S3セキュリティ設定確認
Day 2: S3 Bucket Policy変更・確認・切り戻し
Day 3: CloudTrail Trail・Event History・S3 Data Event確認
Day 4: CloudWatch Logs確認
Day 5: CloudTrail -> CloudWatch Logs連携確認
Day 6: Metric Filter / Alarmハンズオン
Day 7: CloudTrail・CloudWatch総合調査
```

## 開始前スクリプト早見表

この復習ランブックでは、必要なものだけ起動・有効化する。

```text
S3設定確認だけ:
  起動スクリプト不要

Railsアプリ・CloudWatch Agentログも確認する:
  All_Setup.sh
  Ansible

CloudTrail TrailとS3保存ログを確認する:
  cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
  cloudtrail_trail_lab/02_check_cloudtrail_trail.sh

CloudTrailをCloudWatch Logsへ流してMetric Filter / Alarmを確認する:
  cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh
  cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh

Rails画像アップロードのPutObjectをCloudTrailで確認する:
  cloudtrail_s3_data_events/01_enable_s3_data_events.sh
  cloudtrail_s3_data_events/03_check_s3_putobject_events.sh
  cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh
```

日次ラボ環境を起動する場合だけ実行する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh

read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

CloudTrail一時Trailを作成・確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh

/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

CloudTrailからCloudWatch Logsへの一時連携を作成・確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh

/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

S3 Data Eventは`PutObject`確認を行う場合だけ有効化する。確認後は必ず切り戻す。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload

/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload

S3_DATA_EVENTS_EVIDENCE_DIR=$(find /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events \
  -type d \
  -name '*_enable_s3_data_events' \
  -exec test -s '{}/trail_name.txt' \; \
  -print \
  | sort -r \
  | head -n 1)

/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  "$S3_DATA_EVENTS_EVIDENCE_DIR"
```

## 0. 共通変数・作業ディレクトリ

```bash
cd /Users/nobu/aws-reference/day-learning

export AWS_PAGER=""

PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET="nobu-terraform-iac-lab-upload"
TRAIL_NAME="nobu-iac-lab-trail"
TRAIL_LOG_BUCKET="nobu-iac-lab-cloudtrail-445405559057"
TRAIL_LOG_GROUP_NAME="/nobu-iac-lab/cloudtrail/management-events"
FORMAT_JSON_AWK="/Users/nobu/aws-reference/day-learning/format_json_awk.sh"

REVIEW_DIR="evidence/$(date +%Y%m%d_%H%M%S)_day01_07_review"

mkdir -p \
  "$REVIEW_DIR/day01_s3" \
  "$REVIEW_DIR/day02_bucket_policy" \
  "$REVIEW_DIR/day03_cloudtrail" \
  "$REVIEW_DIR/day04_cloudwatch_logs" \
  "$REVIEW_DIR/day05_cloudtrail_cloudwatch" \
  "$REVIEW_DIR/day06_metric_alarm" \
  "$REVIEW_DIR/day07_investigation" \
  "$REVIEW_DIR/report"

echo "REVIEW_DIR=$REVIEW_DIR"
```

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/00_caller_identity.json"
```

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: unexpected account: $ACCOUNT_ID"
  exit 1
fi

echo "Account OK: $ACCOUNT_ID"
```

## 1. Day 1: S3設定を一気に確認する

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/01_bucket_location.json"
```

```bash
aws s3control get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --account-id "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$REVIEW_DIR/day01_s3/02_account_public_access_block.json" \
  2> "$REVIEW_DIR/day01_s3/02_account_public_access_block.stderr" || true
```

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/03_bucket_public_access_block.json"
```

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/04_bucket_policy_status.json"
```

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  | "$FORMAT_JSON_AWK" - "$REVIEW_DIR/day01_s3/05_bucket_policy_formatted.json"
```

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/06_ownership_controls.json"
```

```bash
aws s3api get-bucket-acl \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/07_bucket_acl.json"
```

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/08_bucket_encryption.json"
```

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query '{Status:Status,MFADelete:MFADelete}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/09_bucket_versioning.json"
```

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day01_s3/10_bucket_logging.json"
```

```bash
aws s3api get-bucket-website \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$REVIEW_DIR/day01_s3/11_bucket_website.json" \
  2> "$REVIEW_DIR/day01_s3/11_bucket_website.stderr" || true
```

```bash
aws s3api get-bucket-cors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$REVIEW_DIR/day01_s3/12_bucket_cors.json" \
  2> "$REVIEW_DIR/day01_s3/12_bucket_cors.stderr" || true
```

## 2. Day 2: Bucket Policy変更・確認・切り戻し

変更前Policyを保存する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$REVIEW_DIR/day02_bucket_policy/01_policy_before.json"

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day02_bucket_policy/01_policy_before.json" \
  "$REVIEW_DIR/day02_bucket_policy/01_policy_before_formatted.json"
```

変更後Policy案を作成する。

```bash
cat > "$REVIEW_DIR/day02_bucket_policy/02_policy_after.json" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    },
    {
      "Sid": "DenyOutdatedTLS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::nobu-terraform-iac-lab-upload",
        "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
      ],
      "Condition": {
        "Bool": {
          "aws:PrincipalIsAWSService": "false"
        },
        "NumericLessThan": {
          "s3:TlsVersion": "1.2"
        }
      }
    }
  ]
}
JSON

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day02_bucket_policy/02_policy_after.json" \
  "$REVIEW_DIR/day02_bucket_policy/02_policy_after_formatted.json"
```

Policy案を検証する。

```bash
aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --policy-document "file://$REVIEW_DIR/day02_bucket_policy/02_policy_after.json" \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day02_bucket_policy/03_validate_policy.json"
```

変更を適用する。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$REVIEW_DIR/day02_bucket_policy/02_policy_after.json" \
  --no-cli-pager
```

反映後Policyを確認する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$REVIEW_DIR/day02_bucket_policy/04_policy_applied.json"

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day02_bucket_policy/04_policy_applied.json" \
  "$REVIEW_DIR/day02_bucket_policy/04_policy_applied_formatted.json"
```

差分を見る。

```bash
diff -u \
  "$REVIEW_DIR/day02_bucket_policy/02_policy_after_formatted.json" \
  "$REVIEW_DIR/day02_bucket_policy/04_policy_applied_formatted.json" \
  | tee "$REVIEW_DIR/day02_bucket_policy/05_after_vs_applied.diff" || true
```

切り戻す。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$REVIEW_DIR/day02_bucket_policy/01_policy_before.json" \
  --no-cli-pager
```

切り戻し後Policyを確認する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$REVIEW_DIR/day02_bucket_policy/06_policy_rollback_applied.json"

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day02_bucket_policy/06_policy_rollback_applied.json" \
  "$REVIEW_DIR/day02_bucket_policy/06_policy_rollback_applied_formatted.json"

diff -u \
  "$REVIEW_DIR/day02_bucket_policy/01_policy_before_formatted.json" \
  "$REVIEW_DIR/day02_bucket_policy/06_policy_rollback_applied_formatted.json" \
  | tee "$REVIEW_DIR/day02_bucket_policy/07_before_vs_rollback.diff" || true
```

## 3. Day 3: CloudTrail Trail・Event History確認

一時Trailがなければ作成し、状態を確認する。

```bash
if ! aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$REVIEW_DIR/day03_cloudtrail/00_get_trail_before.json" 2>/dev/null
then
  /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
fi
```

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

```bash
aws cloudtrail get-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day03_cloudtrail/01_get_trail.json"
```

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day03_cloudtrail/02_get_trail_status.json"
```

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day03_cloudtrail/03_event_selectors.json"
```

Bucket Policy変更イベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day03_cloudtrail/04_bucket_policy_events.json"
```

最新の`PutBucketPolicy`詳細を保存する。

```bash
EVENT_ID=$(aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy`].EventId' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | awk 'NF { print; exit }')

echo "EVENT_ID=$EVENT_ID"
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > "$REVIEW_DIR/day03_cloudtrail/05_put_bucket_policy_event_raw.json"

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day03_cloudtrail/05_put_bucket_policy_event_raw.json" \
  "$REVIEW_DIR/day03_cloudtrail/05_put_bucket_policy_event_formatted.json"
```

任意: Rails画像アップロードの`PutObject`を確認する場合だけ実行する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  "$TRAIL_NAME" \
  "$BUCKET"
```

```text
Railsアプリから画像を1枚アップロードする。
CloudTrailログ配信まで5分から15分程度待つ。
```

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
  "$TRAIL_NAME" \
  "$BUCKET"
```

任意手順を実行した場合は、必ずData Eventを戻す。

```bash
S3_DATA_EVENTS_EVIDENCE_DIR=$(find /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events \
  -type d \
  -name '*_enable_s3_data_events' \
  -exec test -s '{}/trail_name.txt' \; \
  -print \
  | sort -r \
  | head -n 1)

/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  "$S3_DATA_EVENTS_EVIDENCE_DIR"
```

## 4. Day 4: CloudWatch Logs確認

日次ラボ環境が必要な場合だけ起動する。

```bash
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'length(Vpcs)' \
  --output text \
  --no-cli-pager)

if [ "$VPC_COUNT" = "0" ]; then
  /Users/nobu/aws-reference/scripts/All_Setup.sh
else
  echo "sample-vpc already exists. Skip All_Setup.sh."
fi
```

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

Rails応答を確認する。

```bash
cd /Users/nobu/aws-reference/ansible

ansible web \
  --become \
  --module-name shell \
  --args 'systemctl is-active puma-nobu-iac-lab && curl --silent --show-error --fail http://localhost:3000/ >/dev/null && echo "Rails response: OK"'

cd /Users/nobu/aws-reference/day-learning
```

Log Groupを確認する。

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix /nobu-iac-lab \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day04_cloudwatch_logs/01_log_groups.json"
```

```bash
LOG_GROUP_NAME="/nobu-iac-lab/nginx/access"

aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --query 'logStreams[].{LogStream:logStreamName,LastEventTime:lastEventTimestamp,StoredBytes:storedBytes}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day04_cloudwatch_logs/02_nginx_access_streams.json"
```

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '"GET"' \
  --limit 10 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day04_cloudwatch_logs/03_nginx_get_events.json"
```

Logs Insightsを短時間で試す。

```bash
START_TIME=$(date -u -v-30M '+%s')
END_TIME=$(date -u '+%s')

QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20' \
  --query queryId \
  --output text \
  --no-cli-pager)

echo "QUERY_ID=$QUERY_ID"
```

```bash
sleep 5

aws logs get-query-results \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-id "$QUERY_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day04_cloudwatch_logs/04_logs_insights_result.json"
```

## 5. Day 5: CloudTrailをCloudWatch Logsへ連携する

一時Trailを確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

CloudTrail -> CloudWatch Logs連携を有効化する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh
```

配信確認を行う。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

連携状態をJSONで保存する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day05_cloudtrail_cloudwatch/01_describe_trails_cloudwatch_logs.json"
```

ConsoleLoginをCloudTrail Event Historyで確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 10 \
  --query 'Events[].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day05_cloudtrail_cloudwatch/02_console_login_events.json"
```

CloudWatch Logs側でも確認する。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$TRAIL_LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "ConsoleLogin" }' \
  --limit 5 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day05_cloudtrail_cloudwatch/03_console_login_cloudwatch_events.json"
```

## 6. Day 6: Metric Filter・Alarmを作って試す

```bash
LAB_LOG_GROUP_NAME="/nobu-iac-lab/security/mfa-console-login-lab"
LAB_LOG_STREAM_NAME="manual-test-events"
METRIC_NAMESPACE="NobuIacLab/SecurityLab"
METRIC_NAME="ConsoleLoginWithoutMFA"
FILTER_NAME="ConsoleLoginWithoutMFA-Lab"
ALARM_NAME="nobu-iac-lab-security-console-login-without-mfa-lab"
FILTER_PATTERN='{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }'
```

```bash
aws logs create-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --no-cli-pager \
  2> "$REVIEW_DIR/day06_metric_alarm/01_create_log_group.stderr" || true

aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --retention-in-days 7 \
  --no-cli-pager

aws logs create-log-stream \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --no-cli-pager \
  2> "$REVIEW_DIR/day06_metric_alarm/02_create_log_stream.stderr" || true
```

Metric Filterを作成する。

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --metric-transformations \
    metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0 \
  --no-cli-pager
```

Alarmを作成する。

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Day 1-7 review lab alarm: ConsoleLogin without MFA" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --actions-enabled false \
  --no-cli-pager
```

MFAありイベントを投入する。

```bash
TIMESTAMP_MS="$(($(date +%s) * 1000))"

EVENT_MESSAGE='{"eventSource":"signin.amazonaws.com","eventName":"ConsoleLogin","responseElements":{"ConsoleLogin":"Success"},"additionalEventData":{"MFAUsed":"Yes"},"sourceIPAddress":"203.0.113.20","userIdentity":{"type":"IAMUser","arn":"arn:aws:iam::123456789012:user/mfa-user"}}'

ESCAPED_EVENT_MESSAGE=$(printf '%s' "$EVENT_MESSAGE" \
  | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '[{"timestamp":%s,"message":"%s"}]\n' \
  "$TIMESTAMP_MS" "$ESCAPED_EVENT_MESSAGE" \
  > "$REVIEW_DIR/day06_metric_alarm/03_mfa_yes_event.json"

aws logs put-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --log-events "file://$REVIEW_DIR/day06_metric_alarm/03_mfa_yes_event.json" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/04_put_mfa_yes_result.json"
```

MFAなしイベントを投入する。

```bash
TIMESTAMP_MS="$(($(date +%s) * 1000))"

EVENT_MESSAGE='{"eventSource":"signin.amazonaws.com","eventName":"ConsoleLogin","responseElements":{"ConsoleLogin":"Success"},"additionalEventData":{"MFAUsed":"No"},"sourceIPAddress":"203.0.113.10","userIdentity":{"type":"IAMUser","arn":"arn:aws:iam::123456789012:user/test-user"}}'

ESCAPED_EVENT_MESSAGE=$(printf '%s' "$EVENT_MESSAGE" \
  | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '[{"timestamp":%s,"message":"%s"}]\n' \
  "$TIMESTAMP_MS" "$ESCAPED_EVENT_MESSAGE" \
  > "$REVIEW_DIR/day06_metric_alarm/05_mfa_no_event.json"

aws logs put-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --log-events "file://$REVIEW_DIR/day06_metric_alarm/05_mfa_no_event.json" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/06_put_mfa_no_result.json"
```

検知結果を確認する。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --limit 20 \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/07_filter_mfa_no_result.json"
```

```bash
START_TIME="$(date -u -v-15M '+%Y-%m-%dT%H:%M:%SZ')"
END_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/08_metric_statistics.json"
```

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,StateReason:StateReason,StateUpdatedTimestamp:StateUpdatedTimestamp,ActionsEnabled:ActionsEnabled}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/09_alarm_state.json"
```

```bash
aws cloudwatch describe-alarm-history \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --max-records 10 \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day06_metric_alarm/10_alarm_history.json"
```

Day 6で作成した検証用リソースを削除する。

```bash
aws cloudwatch delete-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --no-cli-pager

aws logs delete-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --no-cli-pager

aws logs delete-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --no-cli-pager
```

## 7. Day 7: 総合調査を一気に実施する

現在のS3設定を保存する。

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/01_bucket_policy_status.json"
```

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  | "$FORMAT_JSON_AWK" - "$REVIEW_DIR/day07_investigation/02_current_bucket_policy.json"
```

CloudTrailで変更履歴を追う。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/03_bucket_policy_change_events.json"
```

```bash
EVENT_ID=$(aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy`].EventId' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | awk 'NF { print; exit }')

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > "$REVIEW_DIR/day07_investigation/04_change_event_raw.json"

"$FORMAT_JSON_AWK" \
  "$REVIEW_DIR/day07_investigation/04_change_event_raw.json" \
  "$REVIEW_DIR/day07_investigation/04_change_event_formatted.json"
```

Trail、CloudWatch Logs連携、Metric Filter、Alarmを確認する。

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/05_trail_status.json"
```

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn,S3Bucket:S3BucketName}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/06_describe_trails.json"
```

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$TRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/07_cloudtrail_log_group.json"
```

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$TRAIL_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/08_metric_filters.json"
```

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix nobu-iac-lab \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/09_alarms.json"
```

CloudWatch LogsでBucket Policy変更イベントを検索する。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$TRAIL_LOG_GROUP_NAME" \
  --filter-pattern '{ ($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy") }' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName}' \
  --output json \
  --no-cli-pager \
  | tee "$REVIEW_DIR/day07_investigation/10_bucket_policy_events_from_cloudwatch.json"
```

簡易報告を作成する。

```bash
{
  echo "# Day 1-7 Review Report"
  echo
  echo "- Account: $EXPECTED_ACCOUNT_ID"
  echo "- Region: $REGION"
  echo "- Bucket: $BUCKET"
  echo "- Trail: $TRAIL_NAME"
  echo "- Evidence: $REVIEW_DIR"
  echo
  echo "## 確認した流れ"
  echo
  echo "1. S3設定確認"
  echo "2. Bucket Policy変更と切り戻し"
  echo "3. CloudTrail Event History確認"
  echo "4. CloudWatch Logs確認"
  echo "5. CloudTrail -> CloudWatch Logs連携確認"
  echo "6. Metric Filter / Alarm作成・テスト・削除"
  echo "7. CloudTrail・CloudWatch総合調査"
} > "$REVIEW_DIR/report/day01_07_review_report.md"
```

```bash
find "$REVIEW_DIR" \
  -type f \
  -size 0 \
  -print
```

## 8. 終了処理

## 8.1 現在のCloudTrail Event Selectorを確認する

S3 Data Eventを任意手順で有効化した場合は、切り戻し済みであることを確認する。

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --query 'EventSelectors[].{ReadWriteType:ReadWriteType,ManagementEvents:IncludeManagementEvents,DataResourceCount:length(DataResources)}' \
  --output json \
  --no-cli-pager
```

`DataResourceCount`が`0`なら、S3 Data Eventは切り戻し済み。

## 8.2 推奨: 一括後片付けスクリプト

Day 5のCloudTrail -> CloudWatch Logs連携、一時Trail、日次ラボ環境をまとめて戻す場合は、次を実行する。

```bash
/Users/nobu/aws-reference/day-learning/restore_and_cleanup_all.sh
```

このスクリプトで行うこと:

```text
1. 最新のS3 Data Event有効化証跡を探してEvent Selectorを戻す
2. 最新のCloudTrail -> CloudWatch Logs連携証跡を探して連携を戻す
3. 一時Trailを削除する
4. cleanup_network.shで日次ラボ環境を削除する
```

## 8.3 個別に後片付けする場合

S3 Data Eventを戻す。

```bash
S3_DATA_EVENTS_EVIDENCE_DIR=$(find /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events \
  -type d \
  -name '*_enable_s3_data_events' \
  -exec test -s '{}/trail_name.txt' \; \
  -print \
  | sort -r \
  | head -n 1)

if [ -n "$S3_DATA_EVENTS_EVIDENCE_DIR" ]; then
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
    "$S3_DATA_EVENTS_EVIDENCE_DIR"
else
  echo "SKIP: S3 Data Event enable evidence was not found."
fi
```

CloudTrail -> CloudWatch Logs連携を戻す。

```bash
CLOUDWATCH_LOGS_EVIDENCE_DIR=$(find /Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab \
  -type d \
  -name '*_enable_cloudwatch_logs' \
  -exec test -s '{}/trail_name.txt' \; \
  -print \
  | sort -r \
  | head -n 1)

if [ -n "$CLOUDWATCH_LOGS_EVIDENCE_DIR" ]; then
  /Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
    "$CLOUDWATCH_LOGS_EVIDENCE_DIR"
else
  echo "SKIP: CloudTrail CloudWatch Logs enable evidence was not found."
fi
```

一時Trailを削除する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

日次ラボ環境を削除する。

```bash
/Users/nobu/aws-reference/scripts/cleanup_network.sh
```

## 8.4 後片付け後の確認

残存リソースと料金を確認する。

```bash
/Users/nobu/aws-reference/scripts/check_cleanup.sh

/Users/nobu/aws-reference/scripts/check_cost.sh
```

## 完了条件

```text
S3の現在設定をCLIで確認できる
Bucket Policyを変更し、反映確認し、元へ戻せる
CloudTrailでPutBucketPolicyの実行者・時刻・送信元を追える
CloudTrail TrailとEvent Selectorの意味を説明できる
CloudWatch LogsでLog Group、Log Stream、イベントを確認できる
CloudTrail -> CloudWatch Logs連携の有無を確認できる
Metric FilterとAlarmを作成、テスト、削除できる
最後に一時設定と日次ラボ環境を片付けられる
```
