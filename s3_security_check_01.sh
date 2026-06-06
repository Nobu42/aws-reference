#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. 対象アカウントと証跡ディレクトリを準備する。
source "$SCRIPT_DIR/tgi_pre_evidence.sh"

# 2. 機械判読用のJSON証跡を保存する。
source "$SCRIPT_DIR/evidence.sh"

# 3. 人が読みやすい形式で結果と証跡ファイルを表示する。
source "$SCRIPT_DIR/peaple_read.sh"

echo "S3 initial security evidence collection completed."
