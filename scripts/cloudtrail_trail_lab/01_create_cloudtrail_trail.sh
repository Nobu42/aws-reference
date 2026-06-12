#!/bin/bash

# -----------------------------------------------------------------------------
# 一時検証用CloudTrail Trail作成スクリプト
#
# 目的:
#   Day 3の学習でTrail設定、Event Selector、S3へのログ配信を確認するため、
#   学習用Trailと専用ログ保存先S3バケットを作成する。
#
# 主な処理:
#   1. AWS CLI実行環境とCaller Identityを確認する
#   2. 同名Trailと同名S3バケットが存在しないことを確認する
#   3. ログ保存先S3バケットを作成し、公開防止・所有権・暗号化を設定する
#   4. CloudTrailサービスだけがログを書き込めるBucket Policyを設定する
#   5. Multi-region TrailとManagement Event用Event Selectorを作成する
#   6. ログ記録を開始し、作成後の設定を証跡として保存する
#
# 安全上の注意:
#   - 想定AWSアカウント以外では処理を停止する
#   - 同名Trailまたは同名S3バケットが存在する場合は上書きせず停止する
#   - 作成直前に確認文字列の入力を求める
#   - 実案件の既存Trail作成・変更には使用しない
# -----------------------------------------------------------------------------

# 未定義変数、コマンド失敗、パイプ途中の失敗を検知して処理を停止する。
set -euo pipefail

# 環境変数が指定されていない場合に使用する学習環境の既定値。
readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly TRAIL_PREFIX="${TRAIL_PREFIX:-cloudtrail}"

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
  ./01_create_cloudtrail_trail.sh [trail-name] [trail-bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, TRAIL_PREFIX
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  ./01_create_cloudtrail_trail.sh
  SKIP_CONFIRM=true ./01_create_cloudtrail_trail.sh
USAGE
}

# 必須コマンドが存在しない状態で変更処理へ進まないようにする。
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

# 作成処理はAWSリソースを変更するため、実行者へ最終確認を求める。
# 自動実行時はSKIP_CONFIRM=trueで省略できるが、対象確認は別途必要となる。
confirm_change() {
  if [ "${SKIP_CONFIRM:-false}" = "true" ]; then
    return 0
  fi

  printf 'Type "create" to create the temporary CloudTrail Trail: '
  read -r ANSWER
  if [ "$ANSWER" != "create" ]; then
    echo "Canceled."
    exit 1
  fi
}

# ヘルプ表示だけの場合はAWSへ接続せず終了する。
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

# 想定外引数を受け取った場合は誤ったTrail名・バケット名で処理しない。
if [ "$#" -gt 2 ]; then
  usage >&2
  exit 2
fi

require_command aws

# 第1引数でTrail名を上書きできる。証跡は実行日時ごとに分離する。
readonly TRAIL_NAME_VALUE="${1:-$DEFAULT_TRAIL_NAME}"
readonly RUN_ID="$(date +%Y%m%d_%H%M%S)"
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_create_trail"

# beforeは変更前確認、changeは投入した設定、afterは変更後確認を保存する。
mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/change" "$EVIDENCE_DIR/after"

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

# 第2引数がない場合は、AWSアカウントIDを含む一意なラボ用バケット名を使用する。
# Trail ARNはBucket Policyのaws:SourceArn条件で使用する。
readonly TRAIL_BUCKET_VALUE="${2:-nobu-iac-lab-cloudtrail-${ACCOUNT_ID}}"
readonly TRAIL_ARN="arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME_VALUE}"

# 変更対象を画面へ表示し、実行者が確認できるようにする。
echo "================================================"
echo "Create temporary CloudTrail Trail"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Account : $ACCOUNT_ID"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $TRAIL_BUCKET_VALUE"
echo "Prefix  : $TRAIL_PREFIX"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

# 作業実行者と対象AWSアカウントを変更前証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

# 同名Trailが存在する場合は既存設定を壊す可能性があるため、作成せず停止する。
TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 0 ]; then
  echo "ERROR: Trail already exists: $TRAIL_NAME_VALUE" >&2
  echo "This script will not overwrite an existing Trail." >&2
  exit 1
fi

# 自アカウント内に同名バケットがある場合、既存Bucket Policyなどを上書きせず停止する。
# 他アカウントが同名バケットを所有する場合は、後続create-bucketが安全に失敗する。
OWN_BUCKET_COUNT=$(aws s3api list-buckets \
  --profile "$PROFILE" \
  --query "length(Buckets[?Name=='${TRAIL_BUCKET_VALUE}'])" \
  --output text)

if [ "$OWN_BUCKET_COUNT" -ne 0 ]; then
  echo "ERROR: S3 bucket already exists in this account: $TRAIL_BUCKET_VALUE" >&2
  echo "This script will not overwrite an existing bucket or bucket policy." >&2
  exit 1
fi

confirm_change

# CloudTrailログ専用S3バケットを作成する。
# 東京リージョンなどus-east-1以外ではLocationConstraintの指定が必要となる。
aws s3api create-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --create-bucket-configuration "LocationConstraint=$REGION" \
  --output json \
  > "$EVIDENCE_DIR/change/01_create_bucket.json"

# ACLやBucket Policyを通じた意図しないパブリックアクセスを4項目すべてで防止する。
aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --public-access-block-configuration \
    'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

# ACLを無効化し、バケット所有者が保存オブジェクトを一元管理する。
aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

# 保存されるCloudTrailログへSSE-S3によるデフォルト暗号化を設定する。
# 本番では要件に応じてSSE-KMSやKMS Key Policyも検討する。
aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --server-side-encryption-configuration \
    'Rules=[{ApplyServerSideEncryptionByDefault={SSEAlgorithm=AES256}}]'

# CloudTrailサービスへ必要最小限の権限を付与するBucket Policyを作成する。
# 1つ目のStatementはバケットACL確認、2つ目は指定プレフィックスへのログ書き込み用。
# aws:SourceArnで、このスクリプトが作成するTrailからのアクセスだけに制限する。
cat > "$EVIDENCE_DIR/change/02_cloudtrail_bucket_policy.json" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${TRAIL_BUCKET_VALUE}",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "${TRAIL_ARN}"
        }
      }
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${TRAIL_BUCKET_VALUE}/${TRAIL_PREFIX}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "aws:SourceArn": "${TRAIL_ARN}"
        }
      }
    }
  ]
}
POLICY

# 作成したBucket Policyをログ保存先S3バケットへ適用する。
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TRAIL_BUCKET_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_DIR/change/02_cloudtrail_bucket_policy.json"

# 全リージョンとグローバルサービスのManagement Eventを記録するTrailを作成する。
# ログファイル検証を有効化し、配信後ログの完全性確認を可能にする。
aws cloudtrail create-trail \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --s3-bucket-name "$TRAIL_BUCKET_VALUE" \
  --s3-key-prefix "$TRAIL_PREFIX" \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --output json \
  > "$EVIDENCE_DIR/change/03_create_trail.json"

# 初期Event SelectorはManagement EventのRead / Writeをすべて記録する。
# Data Eventは大量発生・追加料金の可能性があるため、この段階では設定しない。
cat > "$EVIDENCE_DIR/change/04_management_event_selector.json" <<'SELECTOR'
[
  {
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [],
    "ExcludeManagementEventSources": []
  }
]
SELECTOR

# 作成したEvent SelectorをTrailへ適用し、適用結果を証跡として保存する。
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --event-selectors "file://$EVIDENCE_DIR/change/04_management_event_selector.json" \
  --output json \
  > "$EVIDENCE_DIR/change/05_put_event_selectors.json"

# Trailの作成だけではログ記録が開始されないため、明示的に開始する。
aws cloudtrail start-logging \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE"

# CloudTrail側へ状態が反映されるまで短時間待機してから変更後確認を行う。
sleep 5

# 作成後のTrail設定、稼働状態、Event Selectorをafter証跡として保存する。
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/01_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/02_trail_status.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/03_event_selectors.json"

# 最終的にIsLogging=Trueであることを機械的に確認する。
# Falseの場合はTrailが作成済みの可能性があるため、自動削除せず調査を促す。
IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" != "True" ]; then
  echo "ERROR: Trail was created, but IsLogging is not True." >&2
  echo "Use 03_delete_cloudtrail_trail.sh after investigating the evidence." >&2
  exit 1
fi

# 実行者が確認しやすいよう、主要な稼働状態だけを表形式で表示する。
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query '{IsLogging:IsLogging,StartLoggingTime:StartLoggingTime,LatestDeliveryTime:LatestDeliveryTime,LatestDeliveryError:LatestDeliveryError}' \
  --output table

echo "Temporary Trail creation completed."
echo "Next: ./02_check_cloudtrail_trail.sh"
echo "Evidence: $EVIDENCE_DIR"
