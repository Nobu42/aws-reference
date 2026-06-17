#!/bin/bash

# -----------------------------------------------------------------------------
# CloudTrailでS3 Object-level Data Eventを一時的に有効化する学習用スクリプト
#
# 目的:
#   Rails / Active StorageなどがS3へ画像をアップロードしたときのPutObjectを、
#   CloudTrailログから確認できるようにする。
#
# 重要な前提:
#   - PutBucketPolicyなどはManagement Eventなので通常のEvent Historyで確認できる。
#   - PutObject / DeleteObjectなどのオブジェクト操作はData Eventであり、
#     TrailのEvent Selectorへ明示的に追加しないと記録されない。
#   - Data Eventは操作数に応じて課金対象になるため、確認後は必ず復元する。
#
# 主な処理:
#   1. AWSアカウント、対象Trail、対象S3バケットを確認する
#   2. 変更前のEvent SelectorをEvidenceへ保存する
#   3. 既存Selectorが学習用の想定形か確認する
#   4. Management Eventを残したまま、対象バケットのWriteOnly Data Eventを追加する
#   5. 復元に必要な情報と次に実行するコマンドをEvidenceへ保存する
#
# 安全上の注意:
#   - Advanced Event SelectorがあるTrailは上書きしない
#   - カスタムSelector構成のTrailは上書きしない
#   - 実案件の既存Trailには、この学習用スクリプトをそのまま使わない
# -----------------------------------------------------------------------------

set -euo pipefail

readonly PROFILE="${PROFILE:-learning}"
readonly REGION="${REGION:-ap-northeast-1}"
readonly EXPECTED_ACCOUNT_ID="${EXPECTED_ACCOUNT_ID:-445405559057}"
readonly DEFAULT_TRAIL_NAME="${TRAIL_NAME:-nobu-iac-lab-trail}"
readonly DEFAULT_BUCKET_NAME="${BUCKET_NAME:-nobu-terraform-iac-lab-upload}"

# スクリプトの場所からリポジトリルートを求め、Evidence保存先を固定する。
# どのディレクトリから実行しても、復元用ファイルを同じ場所に残すためである。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly EVIDENCE_BASE_DIR="${EVIDENCE_BASE_DIR:-$REPOSITORY_ROOT/evidence/cloudtrail_s3_data_events}"

# AWS CLIのページャ停止、LocalStack等の環境変数解除。
# 学習用AWSアカウントへ確実に向けるための事故防止である。
export AWS_PAGER=""
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

usage() {
  cat <<'USAGE'
Usage:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
    [trail-name] [bucket-name]

Environment variables:
  PROFILE, REGION, EXPECTED_ACCOUNT_ID, TRAIL_NAME, BUCKET_NAME
  EVIDENCE_BASE_DIR, SKIP_CONFIRM

Example:
  /Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
    nobu-iac-lab-trail nobu-terraform-iac-lab-upload
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
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
readonly EVIDENCE_DIR="$EVIDENCE_BASE_DIR/${RUN_ID}_enable_s3_data_events"

require_command aws

# before: 変更前のTrail/Event Selector
# change: 適用予定のEvent Selector
# after : 適用後の確認結果
mkdir -p "$EVIDENCE_DIR/before" "$EVIDENCE_DIR/change" "$EVIDENCE_DIR/after"

echo "================================================"
echo "Enable CloudTrail S3 write-only data events"
echo "Profile : $PROFILE"
echo "Region  : $REGION"
echo "Trail   : $TRAIL_NAME_VALUE"
echo "Bucket  : $BUCKET_NAME_VALUE"
echo "Evidence: $EVIDENCE_DIR"
echo "================================================"

# 誤アカウントでData Eventを有効化しないため、最初にAccount IDを確認する。
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID" >&2
  echo "Expected account: $EXPECTED_ACCOUNT_ID" >&2
  exit 1
fi

# 操作主体と対象アカウントを変更前証跡として保存する。
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/before/00_caller_identity.json"

# 対象バケットが存在し、想定アカウントが所有していることを確認する。
# Data Eventの対象ARNはこのバケット名から作るため、ここで間違いを止める。
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME_VALUE" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  > "$EVIDENCE_DIR/before/01_head_bucket.json"

# 対象Trailが1件に特定できることを確認する。
# 0件なら作成漏れ、複数件なら名前指定の不整合として停止する。
TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'length(trailList)' \
  --output text)

if [ "$TRAIL_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Trail, found: $TRAIL_COUNT" >&2
  echo "Check the Trail name and Home Region." >&2
  exit 1
fi

# Event Selector変更はTrailのHome Regionで行う必要がある。
# Shadow Trailや別リージョン指定による失敗を避ける。
HOME_REGION=$(aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --query 'trailList[0].HomeRegion' \
  --output text)

if [ "$HOME_REGION" != "$REGION" ]; then
  echo "ERROR: Trail Home Region is $HOME_REGION, expected $REGION." >&2
  echo "Run this script with REGION=$HOME_REGION." >&2
  exit 1
fi

# Trail設定と稼働状態を変更前証跡として保存する。
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name-list "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/02_trail.json"

aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/03_trail_status.json"

# Trailが停止していると、Data Eventを有効化してもログ配信されない。
IS_LOGGING=$(aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME_VALUE" \
  --query IsLogging \
  --output text)

if [ "$IS_LOGGING" != "True" ]; then
  echo "ERROR: Trail is not logging: $TRAIL_NAME_VALUE" >&2
  exit 1
fi

# 復元用に、変更前のEvent Selectorをフル・基本・Advancedに分けて保存する。
# restoreスクリプトはこれらを使って変更前状態へ戻す。
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/before/04_event_selectors_full.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query EventSelectors \
  --output json \
  > "$EVIDENCE_DIR/before/05_event_selectors_only.json"

aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query AdvancedEventSelectors \
  --output json \
  > "$EVIDENCE_DIR/before/06_advanced_event_selectors_only.json"

BASIC_SELECTOR_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors || `[]`)' \
  --output text)

ADVANCED_SELECTOR_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(AdvancedEventSelectors || `[]`)' \
  --output text)

# Advanced Event Selectorは表現力が高く、上書きすると影響範囲が読みにくい。
# 学習スクリプトでは安全のため変更しない。
if [ "$ADVANCED_SELECTOR_COUNT" -ne 0 ]; then
  echo "ERROR: Advanced Event Selectors are configured." >&2
  echo "This learning script will not overwrite them." >&2
  exit 1
fi

# 想定は「Management Event用の基本Selectorが1つだけ」の状態である。
# それ以外は既に独自設定がある可能性があるため変更しない。
if [ "$BASIC_SELECTOR_COUNT" -ne 1 ]; then
  echo "ERROR: Expected one basic Event Selector, found: $BASIC_SELECTOR_COUNT" >&2
  echo "This learning script will not overwrite a custom selector configuration." >&2
  exit 1
fi

# 既存Selectorの中身が、学習用Trailの初期状態と一致するか確認する。
# Management Eventを残したままData Eventだけを追加する前提を守るためである。
READ_WRITE_TYPE=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[0].ReadWriteType' \
  --output text)

INCLUDE_MANAGEMENT_EVENTS=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'EventSelectors[0].IncludeManagementEvents' \
  --output text)

DATA_RESOURCE_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors[0].DataResources || `[]`)' \
  --output text)

EXCLUDED_SOURCE_COUNT=$(aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --query 'length(EventSelectors[0].ExcludeManagementEventSources || `[]`)' \
  --output text)

if [ "$READ_WRITE_TYPE" != "All" ] \
  || [ "$INCLUDE_MANAGEMENT_EVENTS" != "True" ] \
  || [ "$DATA_RESOURCE_COUNT" -ne 0 ] \
  || [ "$EXCLUDED_SOURCE_COUNT" -ne 0 ]; then
  echo "ERROR: Existing Event Selector is not the expected default management-event configuration." >&2
  echo "This learning script will not overwrite it." >&2
  exit 1
fi

# 適用予定のEvent Selectorをファイル化する。
# 1つ目は既存のManagement Event、2つ目が対象S3バケットのWriteOnly Data Eventである。
# Valuesの末尾の "/" は「このバケット配下のオブジェクト」を表すCloudTrail Data Eventの指定である。
cat > "$EVIDENCE_DIR/change/01_desired_event_selectors.json" <<EOF
[
  {
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [],
    "ExcludeManagementEventSources": []
  },
  {
    "ReadWriteType": "WriteOnly",
    "IncludeManagementEvents": false,
    "DataResources": [
      {
        "Type": "AWS::S3::Object",
        "Values": [
          "arn:aws:s3:::$BUCKET_NAME_VALUE/"
        ]
      }
    ],
    "ExcludeManagementEventSources": []
  }
]
EOF

# 復元時に必要な最小情報をテキストで保存する。
# 後から「どのTrail/バケット/リージョンに対する有効化だったか」を迷わないようにする。
printf '%s\n' "$TRAIL_NAME_VALUE" > "$EVIDENCE_DIR/trail_name.txt"
printf '%s\n' "$BUCKET_NAME_VALUE" > "$EVIDENCE_DIR/bucket_name.txt"
printf '%s\n' "$ACCOUNT_ID" > "$EVIDENCE_DIR/account_id.txt"
printf '%s\n' "$REGION" > "$EVIDENCE_DIR/region.txt"

echo "=== Desired Event Selectors ==="
cat "$EVIDENCE_DIR/change/01_desired_event_selectors.json"

echo
echo "This change keeps all management events and adds write-only S3 object data events."
echo "Write-only data events include PutObject, DeleteObject, and multipart-upload writes."
echo "CloudTrail data event charges will apply."

if [ "${SKIP_CONFIRM:-false}" != "true" ]; then
  read -r -p "Type 'enable' to apply this Event Selector change: " CONFIRM

  if [ "$CONFIRM" != "enable" ]; then
    echo "Canceled. Before-change evidence remains at: $EVIDENCE_DIR"
    exit 0
  fi
fi

# Event Selectorを置き換える。
# CloudTrailのput-event-selectorsは「追加」ではなく、指定したSelectorセットへ更新する操作である。
# そのため、既存Management Eventも含めた完全な配列を渡している。
aws cloudtrail put-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --event-selectors "file://$EVIDENCE_DIR/change/01_desired_event_selectors.json" \
  --output json \
  > "$EVIDENCE_DIR/after/01_put_event_selectors_response.json"

# 適用後のEvent Selectorを保存し、後続チェックと証跡に使う。
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME_VALUE" \
  --output json \
  > "$EVIDENCE_DIR/after/02_event_selectors_full.json"

# 対象バケットARNが反映されていることを最低限確認する。
# 見つからない場合は、Data Eventが記録されないため即時復元を促す。
if ! grep -Fq "arn:aws:s3:::$BUCKET_NAME_VALUE/" "$EVIDENCE_DIR/after/02_event_selectors_full.json"; then
  echo "ERROR: Target bucket ARN was not found after the change." >&2
  echo "Restore immediately using:" >&2
  echo "  $SCRIPT_DIR/02_restore_s3_event_selectors.sh '$EVIDENCE_DIR'" >&2
  exit 1
fi

# 復元時に「有効化処理を最後まで完了した証跡」だけを判別できるようにする。
printf '%s\n' "S3 Data Event enable completed." > "$EVIDENCE_DIR/ENABLE_COMPLETED"

cat > "$EVIDENCE_DIR/NEXT_STEPS.txt" <<EOF
1. Event Selectorの反映を待つため、5分程度待機する。
2. Railsアプリケーションから新しい画像をアップロードする。
3. CloudTrailログ配信を待つため、5分から15分程度待機する。
4. PutObjectを確認する:
   $SCRIPT_DIR/03_check_s3_putobject_events.sh "$TRAIL_NAME_VALUE" "$BUCKET_NAME_VALUE"
5. 確認後、変更前のEvent Selectorへ切り戻す:
   $SCRIPT_DIR/02_restore_s3_event_selectors.sh "$EVIDENCE_DIR"
6. Day 3の確認完了後、一時Trailを削除する:
   $REPOSITORY_ROOT/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
EOF

echo "================================================"
echo "S3データイベントを有効化した。"
echo "証跡ディレクトリ: $EVIDENCE_DIR"
echo "切り戻し時は、上記の証跡ディレクトリをそのまま指定する。"
echo
cat "$EVIDENCE_DIR/NEXT_STEPS.txt"
echo "================================================"
