#!/bin/bash

# -----------------------------------------------------------------------------
# 一時検証用CloudTrail Trail確認スクリプト
#
# 目的:
#   作成済みTrailが想定どおり設定され、CloudTrailログをS3へ配信できる状態かを
#   読み取り専用コマンドで確認し、調査証跡を保存する。
#
# 主な確認項目:
#   - Caller Identityと対象AWSアカウント
#   - TrailのHome Region、Multi-region設定、ログファイル検証
#   - Trailのログ記録状態と配信エラー
#   - Management Event / Data EventのEvent Selector
#   - ログ保存先S3のPublic Access Block、所有権、暗号化、Public判定
#   - S3へ配信されたCloudTrailログオブジェクト
#
# このスクリプトは設定変更を行わない。
# -----------------------------------------------------------------------------

# 未定義変数、コマンド失敗、パイプ途中の失敗を検知して処理を停止する。
set -euo pipefail

# 環境変数が指定されていない場合に使用する学習環境の既定値。
readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"

# 実行場所に依存せず、リポジトリ配下のevidenceへ証跡を保存する。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_trail_lab}"

# AWS CLIのページャー停止を防ぎ、LocalStackなど別エンドポイントへの誤接続を避ける。
export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# 引数と上書き可能な環境変数を表示する。
usage() {
  cat <<'USAGE'
Usage:
  ./02_check_cloudtrail_trail.sh [trail-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, EVIDENCE_BASE_DIR
USAGE
}

# ヘルプ表示だけの場合はAWSへ接続せず終了する。
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

# 確認対象Trail名以外の想定外引数を受け取った場合は停止する。
if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

# AWS CLIがない環境では確認できないため、AWSへ接続する前に停止する。
if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: Required command not found: aws" >&2
  exit 1
fi

# 第1引数で確認対象Trail名を上書きできる。証跡は実行日時ごとに分離する。
readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_check_trail"

mkdir -p "$EVIDENCE_DIR"

# 最重要の誤操作防止。現在の認証情報が想定AWSアカウントを向いているか確認する。
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

# 作業実行者と対象AWSアカウントを証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_caller_identity.json"

# 対象Trailが1件だけ存在することを確認する。
# 0件では確認不能、複数件では対象を一意に判断できないため停止する。
TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  exit 1
fi

# Trailの更新・状態確認はHome Regionで実施する必要があるため、想定リージョンと照合する。
HOME_REGION=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].HomeRegion' \
  --output text)

if [ "$HOME_REGION" != "$REGION" ]; then
  echo "ERROR: Trail Home Region is $HOME_REGION, expected $REGION." >&2
  exit 1
fi

# Trail設定からログ保存先S3バケットと任意のS3キープレフィックスを取得する。
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

# AWS CLIは未設定値を文字列Noneで返すため、パス組み立て用に空文字へ変換する。
if [ "$TRAIL_PREFIX" = "None" ]; then
  TRAIL_PREFIX=""
fi

# 確認対象を画面へ表示し、証跡の対象が分かるようにする。
echo "================================================"
echo "Check CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET"
echo "Prefix  : ${TRAIL_PREFIX:-<none>}"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

# Trail設定、稼働状態、Event Selectorを加工前JSONの証跡として保存する。
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/03_event_selectors.json"

# Trailログ保存先S3が公開防止、ACL無効化、暗号化、非Publicの状態か確認する。
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/04_bucket_public_access_block.json"

aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/05_bucket_ownership_controls.json"

aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/06_bucket_encryption.json"

aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  > "$EVIDENCE_DIR/07_bucket_policy_status.json"

# CloudTrailログの標準保存パスを、S3キープレフィックスの有無に応じて組み立てる。
if [ -n "$TRAIL_PREFIX" ]; then
  LOG_PREFIX="${TRAIL_PREFIX}/AWSLogs/${ACCOUNT_ID}/CloudTrail/"
else
  LOG_PREFIX="AWSLogs/${ACCOUNT_ID}/CloudTrail/"
fi

# S3へ実際に配信されたログオブジェクトを最大10件保存する。
# Trail作成直後は配信待ちのためContentsが空になる場合がある。
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --prefix "$LOG_PREFIX" \
  --max-items 10 \
  --output json \
  > "$EVIDENCE_DIR/08_recent_log_objects.json"

# 証跡JSONとは別に、実行者が読みやすい主要設定を表形式で表示する。
echo "=== Trail configuration ==="
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].{Name:Name,HomeRegion:HomeRegion,S3BucketName:S3BucketName,S3KeyPrefix:S3KeyPrefix,IsMultiRegionTrail:IsMultiRegionTrail,IncludeGlobalServiceEvents:IncludeGlobalServiceEvents,LogFileValidationEnabled:LogFileValidationEnabled}' \
  --output table

echo "=== Trail status ==="
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query '{IsLogging:IsLogging,StartLoggingTime:StartLoggingTime,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError}' \
  --output table

echo "=== Event selectors ==="
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[].{ReadWriteType:ReadWriteType,IncludeManagementEvents:IncludeManagementEvents,DataResourceCount:length(DataResources)}' \
  --output table

echo "=== Recent CloudTrail log objects ==="
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --prefix "$LOG_PREFIX" \
  --max-items 10 \
  --query 'Contents[].{LastModified:LastModified,Size:Size,Key:Key}' \
  --output table

# IsLoggingを単独取得し、ログ記録中かを明確なメッセージで表示する。
# 配信エラーや最新配信時刻は上のTrail status表と証跡JSONで確認する。
IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" = "True" ]; then
  echo "OK: Trail is logging."
else
  echo "WARNING: Trail is not logging."
fi

echo "Trail check completed."
echo "Evidence: $EVIDENCE_DIR"
