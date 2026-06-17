#!/bin/bash

# -----------------------------------------------------------------------------
# CloudTrailログS3保存先からPutObject Data Eventを探す確認スクリプト
#
# 目的:
#   01_enable_s3_data_events.shでS3 Data Eventを有効化した後、
#   Rails / Active StorageなどのS3アップロードがCloudTrailにPutObjectとして
#   記録されたか確認する。
#
# 重要な前提:
#   - CloudTrail lookup-eventsはManagement Event検索用であり、
#     S3 Object Data EventのPutObject確認には向かない。
#   - Data EventはTrailのS3保存先にgzip圧縮JSONとして配信される。
#   - このスクリプトはTrail保存先S3から最近の .json.gz を取得し、
#     sed/awk/grepに近い素朴な方法でPutObjectを抽出する。
#
# 主な処理:
#   1. AWSアカウント、Trail、Trail保存先S3を確認する
#   2. Event Selectorに対象バケットのData Eventがあるか確認する
#   3. 昨日・今日のCloudTrailログファイル一覧を取得する
#   4. 直近ログをローカルEvidenceへダウンロードする
#   5. gzip展開し、PutObjectかつ対象bucketNameのイベントを抽出する
#   6. IAM Role ARN、userAgent、object keyなどの要約を表示する
#
# 注意:
#   - CloudTrailログ配信には数分から十数分の遅延がある。
#   - 大きなファイルではPutObject以外にMultipart Upload系APIが使われる場合がある。
# -----------------------------------------------------------------------------

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly DEFAULT_BUCKET_NAME="${BUCKET_NAME:-nobu-terraform-iac-lab-upload}"
readonly MAX_LOG_FILES="${MAX_LOG_FILES:-100}"

# 実行場所に依存せずEvidence保存先を固定する。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_s3_data_events}"

# ページャ停止とLocalStack等への誤接続防止。
export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
    [trail-name] [bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, BUCKET_NAME
  EVIDENCE_BASE_DIR, MAX_LOG_FILES

Notes:
  - CloudTrail Event History and lookup-events do not search S3 object data events.
  - This script downloads recent CloudTrail log files from the Trail S3 bucket.
  - CloudTrail log delivery can take several minutes.
USAGE
}

previous_utc_date() {
  # GNU dateとmacOS BSD dateの両方に対応する。
  # CloudTrailのS3パスはUTC日付で切られるため、昨日分も見る。
  if date -u -d yesterday +%Y/%m/%d >/dev/null 2>&1; then
    date -u -d yesterday +%Y/%m/%d
  else
    date -u -v-1d +%Y/%m/%d
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
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_check_s3_putobject"

# trail: Trail設定と対象ログキー
# logs : ダウンロードしたCloudTrail .json.gz
# result: 展開・抽出したPutObject結果
mkdir -p "$EVIDENCE_DIR/trail" "$EVIDENCE_DIR/logs" "$EVIDENCE_DIR/result"

# 誤アカウントでTrailログバケットを参照しないための確認。
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  exit 1
fi

# 実行者とTrail設定を証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/trail/00_caller_identity.json"

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/trail/01_trail.json"

# TrailのS3保存先バケットとプレフィックスを取得する。
# Data EventはEvent Historyではなく、このS3保存先のログファイルから探す。
TRAIL_BUCKET=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].S3BucketName' \
  --output text)

TRAIL_PREFIX=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].S3KeyPrefix' \
  --output text)

if [ "$TRAIL_BUCKET" = "None" ] || [ -z "$TRAIL_BUCKET" ]; then
  echo "ERROR: Trail S3 bucket was not found." >&2
  exit 1
fi

# S3KeyPrefixが未設定の場合、AWS CLIはNoneを返すため空文字に変換する。
if [ "$TRAIL_PREFIX" = "None" ]; then
  TRAIL_PREFIX=""
fi

# 現在のEvent Selectorを保存する。
# 対象バケットのData Eventが未設定なら、PutObjectが見つからない可能性を警告する。
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/trail/02_event_selectors.json"

if ! grep -Fq "arn:aws:s3:::$BUCKET_NAME_VALUE/" "$EVIDENCE_DIR/trail/02_event_selectors.json"; then
  echo "WARNING: Target bucket ARN was not found in the current Event Selectors." >&2
  echo "PutObject may not be recorded by this Trail." >&2
fi

# CloudTrailログの標準S3プレフィックスを組み立てる。
# 例: cloudtrail/AWSLogs/<account-id>/CloudTrail/ap-northeast-1/yyyy/mm/dd/
BASE_PREFIX="${TRAIL_PREFIX:+$TRAIL_PREFIX/}AWSLogs/$ACCOUNT_ID/CloudTrail/$REGION"
TODAY_UTC=$(date -u +%Y/%m/%d)
YESTERDAY_UTC=$(previous_utc_date)

# CloudTrailログ配信遅延とUTC日付境界を考慮し、昨日と今日のログを候補にする。
for utc_date in "$YESTERDAY_UTC" "$TODAY_UTC"; do
  aws s3api list-objects-v2 \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$TRAIL_BUCKET" \
    --prefix "$BASE_PREFIX/$utc_date/" \
    --query 'Contents[].Key' \
    --output text \
    2>/dev/null \
    | tr '\t' '\n' \
    >> "$EVIDENCE_DIR/trail/03_candidate_log_keys.txt" || true
done

# 空行やNoneを除外し、重複を消し、直近MAX_LOG_FILES件だけ選ぶ。
# ダウンロード量と検索時間を抑えるためである。
sed '/^$/d;/^None$/d' "$EVIDENCE_DIR/trail/03_candidate_log_keys.txt" \
  | sort -u \
  | tail -n "$MAX_LOG_FILES" \
  > "$EVIDENCE_DIR/trail/04_selected_log_keys.txt"

SELECTED_COUNT=$(wc -l < "$EVIDENCE_DIR/trail/04_selected_log_keys.txt" | tr -d ' ')

if [ "$SELECTED_COUNT" -eq 0 ]; then
  echo "No recent CloudTrail log files were found." >&2
  echo "Wait several minutes and run the script again." >&2
  exit 3
fi

echo "Downloading $SELECTED_COUNT recent CloudTrail log files..."

# 選択したCloudTrailログファイルをEvidence/logsへ保存する。
# 後から同じログを見返せるよう、S3上のbasenameをそのまま使う。
while IFS= read -r object_key; do
  [ -n "$object_key" ] || continue
  local_name=$(basename "$object_key")

  aws s3api get-object \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$TRAIL_BUCKET" \
    --key "$object_key" \
    "$EVIDENCE_DIR/logs/$local_name" \
    >/dev/null
done < "$EVIDENCE_DIR/trail/04_selected_log_keys.txt"

# 複数のgzipログを1つのファイルに展開・連結する。
: > "$EVIDENCE_DIR/result/01_combined_cloudtrail_logs.json"

for log_file in "$EVIDENCE_DIR"/logs/*.json.gz; do
  [ -f "$log_file" ] || continue
  gzip -dc "$log_file" >> "$EVIDENCE_DIR/result/01_combined_cloudtrail_logs.json"
  printf '\n' >> "$EVIDENCE_DIR/result/01_combined_cloudtrail_logs.json"
done

# CloudTrailログはRecords配列のJSONである。
# jqを使わずにgrepしやすくするため、eventVersionの境目で1イベント1行に近い形へ分割する。
awk '{gsub(/},{"eventVersion"/, "}\n{\"eventVersion\""); print}' \
  "$EVIDENCE_DIR/result/01_combined_cloudtrail_logs.json" \
  > "$EVIDENCE_DIR/result/02_cloudtrail_records_by_line.txt"

# PutObjectかつ対象バケットのイベントだけを抽出する。
grep '"eventName":"PutObject"' \
  "$EVIDENCE_DIR/result/02_cloudtrail_records_by_line.txt" \
  | grep -F "\"bucketName\":\"$BUCKET_NAME_VALUE\"" \
  > "$EVIDENCE_DIR/result/03_putobject_events_raw.txt" || true

# 報告しやすいように、実行者ARN、時刻、送信元IP、SDK userAgent、bucket/keyを抜き出す。
grep '"eventName":"PutObject"' \
  "$EVIDENCE_DIR/result/02_cloudtrail_records_by_line.txt" \
  | grep -F "\"bucketName\":\"$BUCKET_NAME_VALUE\"" \
  | grep -o \
    '"eventTime":"[^"]*"\|"eventName":"[^"]*"\|"arn":"[^"]*"\|"sourceIPAddress":"[^"]*"\|"userAgent":"[^"]*"\|"bucketName":"[^"]*"\|"key":"[^"]*"' \
  > "$EVIDENCE_DIR/result/04_putobject_events_summary.txt" || true

PUT_OBJECT_COUNT=$(wc -l < "$EVIDENCE_DIR/result/03_putobject_events_raw.txt" | tr -d ' ')

echo "================================================"
echo "CloudTrail S3 PutObject check completed."
echo "Trail            : $TRAIL_NAME_VALUE"
echo "Target bucket    : $BUCKET_NAME_VALUE"
echo "Trail log bucket : $TRAIL_BUCKET"
echo "Downloaded logs  : $SELECTED_COUNT"
echo "PutObject events : $PUT_OBJECT_COUNT"
echo "Evidence         : $EVIDENCE_DIR"
echo "================================================"

if [ "$PUT_OBJECT_COUNT" -eq 0 ]; then
  echo "No PutObject event was found."
  echo "Wait for log delivery, upload a new image, and run this script again."
  echo "Active Storage may also use multipart-upload-related API events for large files."
  exit 4
fi

echo "=== PutObject summary ==="
cat "$EVIDENCE_DIR/result/04_putobject_events_summary.txt"
echo
echo "Confirm the IAM Role ARN, aws-sdk-ruby userAgent, object key, and event time."
echo
echo "Next: Restore S3 Data Event Selectors."
echo "Use the exact Evidence directory printed by the successful"
echo "01_enable_s3_data_events.sh run. Do not automatically select the newest directory,"
echo "because a failed enable attempt can leave an incomplete evidence directory."
echo "Restore command:"
echo "  $SCRIPT_DIR/02_restore_s3_event_selectors.sh \\"
echo "    <successful-enable-evidence-directory>"
