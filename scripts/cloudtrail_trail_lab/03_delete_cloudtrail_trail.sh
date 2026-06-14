#!/bin/bash

# -----------------------------------------------------------------------------
# 一時検証用CloudTrail Trail削除スクリプト
#
# 目的:
#   Day 3の学習完了後、一時Trailと専用ログ保存先S3バケットを安全に削除する。
#
# 主な処理:
#   1. Caller Identity、Trail名、Home Region、保存先S3バケット名を確認する
#   2. 削除前のTrail設定、稼働状態、Event Selectorを証跡として保存する
#   3. Trailのログ記録を停止してTrailを削除する
#   4. S3 Bucket Policy、ログオブジェクト、ログ保存先S3バケットを削除する
#   5. Trail削除後の状態とDeleteTrailイベントを証跡として保存する
#
# 安全上の注意:
#   - 想定AWSアカウント以外では処理を停止する
#   - Trailが1件に特定できない場合は処理を停止する
#   - Trailの保存先が想定ラボ用バケットと一致しない場合は削除しない
#   - CloudTrailの遅延配信を考慮し、S3削除を複数回試行する
#   - 実案件の既存Trail削除には使用しない
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
  /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh \
    [trail-name] [expected-trail-bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
  SKIP_CONFIRM=true \
    /Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
USAGE
}

# Trailとログ保存先S3バケットを削除するため、実行者へ最終確認を求める。
# 自動実行時はSKIP_CONFIRM=trueで省略できるが、対象確認は別途必要となる。
confirm_delete() {
  if [ "${SKIP_CONFIRM:-false}" = "true" ]; then
    return 0
  fi

  printf 'Type "delete" to delete the temporary Trail and its log bucket: '
  read -r ANSWER
  if [ "$ANSWER" != "delete" ]; then
    echo "Canceled."
    exit 1
  fi
}

# ヘルプ表示だけの場合はAWSへ接続せず終了する。
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

# Trail名と期待するログ保存先バケット名以外の想定外引数を受け取った場合は停止する。
if [ "$#" -gt 2 ]; then
  usage >&2
  exit 2
fi

# AWS CLIがない環境では削除できないため、AWSへ接続する前に停止する。
if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: Required command not found: aws" >&2
  exit 1
fi

# 第1引数で削除対象Trail名を上書きできる。証跡は実行日時ごとに分離する。
readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_delete_trail"

# beforeは削除前状態、afterは削除結果と削除イベントを保存する。
mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/after"

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

# 対象Trailが1件だけ存在することを確認する。
# 0件または複数件の場合は安全に削除対象を特定できないため停止する。
TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  echo "No deletion was performed." >&2
  exit 1
fi

# Trailの削除はHome Regionで実施する必要があるため、想定リージョンと照合する。
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

# Trail設定から実際のログ保存先S3バケット名を取得する。
TRAIL_BUCKET=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].S3BucketName' \
  --output text)

# 第2引数がない場合は、AWSアカウントIDを含むラボ用バケット名を期待値とする。
EXPECTED_TRAIL_BUCKET="${2:-nobu-iac-lab-cloudtrail-${ACCOUNT_ID}}"

# 実際の保存先が期待値と異なる場合は、業務用・別用途バケットの可能性があるため停止する。
if [ "$TRAIL_BUCKET" != "$EXPECTED_TRAIL_BUCKET" ]; then
  echo "ERROR: Trail bucket does not match the expected lab bucket." >&2
  echo "Trail bucket   : $TRAIL_BUCKET" >&2
  echo "Expected bucket: $EXPECTED_TRAIL_BUCKET" >&2
  echo "No deletion was performed." >&2
  exit 1
fi

# 削除対象を画面へ表示し、実行者が最終確認できるようにする。
echo "================================================"
echo "Delete temporary CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

# 削除前に、実行者、Trail設定、稼働状態、Event Selectorを証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/03_event_selectors.json"

confirm_delete

# 新しいログ配信を止めてからTrailを削除する。
# 停止直前までのログが遅延してS3へ配信される場合がある。
aws cloudtrail stop-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

# Trail本体を削除する。S3へ配信済みのログはこの操作では削除されない。
aws cloudtrail delete-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

# S3バケットを削除するため、CloudTrail書き込み許可のBucket Policyを削除する。
# Policyが既にない場合などのエラーは証跡へ残し、後続の空バケット化を継続する。
if aws s3api delete-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  2> "$EVIDENCE_DIR/after/01_delete_bucket_policy_error.txt"; then

  rm -f "$EVIDENCE_DIR/after/01_delete_bucket_policy_error.txt"
fi

# CloudTrail停止・削除後もログが遅延配信される場合があるため、
# バケット内オブジェクト削除とバケット削除を最大6回繰り返す。
BUCKET_DELETED=false
ATTEMPT=1

while [ "$ATTEMPT" -le 6 ]; do
  echo "Emptying Trail log bucket. Attempt: $ATTEMPT/6"

  aws s3 rm "s3://$TRAIL_BUCKET" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --recursive

  if aws s3api delete-bucket \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$TRAIL_BUCKET" \
    --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
    2> "$EVIDENCE_DIR/after/02_delete_bucket_error_attempt_${ATTEMPT}.txt"; then

    rm -f "$EVIDENCE_DIR/after/02_delete_bucket_error_attempt_${ATTEMPT}.txt"
    BUCKET_DELETED=true
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 10
done

# Trailが削除されたことを確認するため、削除後のdescribe-trails結果を保存する。
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/03_trail_after_delete.json"

# DeleteTrailはManagement EventとしてEvent Historyへ残る。
# Event Historyへの反映に時間がかかる場合があるため、取得失敗は削除失敗とは扱わない。
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteTrail \
  --max-results 10 \
  --output json \
  > "$EVIDENCE_DIR/after/04_delete_trail_events.json" || true

# Trail削除済みでもS3バケット削除が失敗した場合は、証跡を示して手動確認を促す。
if [ "$BUCKET_DELETED" != "true" ]; then
  echo "ERROR: Trail was deleted, but the log bucket could not be deleted." >&2
  echo "Review the delete errors, wait for delayed delivery, and rerun cleanup manually." >&2
  echo "Evidence: $EVIDENCE_DIR" >&2
  exit 1
fi

echo "Temporary Trail and log bucket deletion completed."
echo "Evidence: $EVIDENCE_DIR"
echo "Local evidence was not deleted. Keep it until review and reporting are completed."
