#!/bin/bash

# 未定義の変数を使ったらエラーにする。
# 例: $INPUT_FILE のつもりが $INPUTFILE と書いた場合に早く気づける。
set -u

# 終了コードを名前で管理する。
# 現場スクリプトでは「何の理由で失敗したか」を分けておくと追いやすい。
readonly EXIT_SUCCESS=0
readonly EXIT_USAGE_ERROR=2
readonly EXIT_FILE_ERROR=3
readonly EXIT_FORMAT_ERROR=4

# 使い方を表示する関数。
# 標準入力から読む場合は引数なし、または "-" を指定する。
usage() {
  cat <<'USAGE'
Usage:
  format_json_awk.sh [input-json-file|-] [output-json-file]

Examples:
  ./format_json_awk.sh input.json
  ./format_json_awk.sh input.json formatted.json
  cat input.json | ./format_json_awk.sh
  cat input.json | ./format_json_awk.sh - formatted.json

Notes:
  - When input-json-file is omitted or "-", JSON is read from stdin.
  - When output-json-file is omitted, the formatted JSON is written to stdout.
  - The input file is never overwritten.
  - This script formats JSON with awk, but does not perform full JSON validation.
USAGE
}

# JSONを整形する本体。
# awkで1文字ずつ読み、JSON文字列の外にある { [ ] } , : を見つけて改行とインデントを入れる。
# jqやpythonが使えない現場を想定した簡易フォーマッタであり、厳密なJSON検証は行わない。
format_json() {
  awk '
    # 指定された段数だけインデントを出力する。
    # count=2 の場合は、2スペース x 2 = 4スペースを出力する。
    function print_indent(count, i) {
      for (i = 0; i < count; i++) {
        printf "  "
      }
    }

    # BEGINは入力を読み始める前に1回だけ実行される。
    BEGIN {
      # 現在のインデント段数。
      # { または [ を見つけたら増やし、} または ] を見つけたら減らす。
      indent = 0

      # JSON文字列の内側にいるかどうか。
      # 例: "abc,{,}" の中にあるカンマや波括弧は構文ではなく文字なので、改行してはいけない。
      in_string = 0

      # バックスラッシュでエスケープされた直後かどうか。
      # 例: "message": "He said \"OK\"" の \" は文字列終了ではない。
      escape = 0

      # 括弧の数が合わないなど、簡易的に検知した整形エラー。
      format_error = 0
    }

    # awkでは、入力の各行に対してこのブロックが実行される。
    # ただしJSONは1行で来ることが多いので、行の中をさらに1文字ずつ処理する。
    {
      for (i = 1; i <= length($0); i++) {
        # substr($0, i, 1) は、現在行 $0 の i文字目を1文字だけ取り出す。
        char = substr($0, i, 1)

        # 文字列の内側にいる場合。
        # この場合、{ } [ ] , : が出てもJSON構文として扱わず、そのまま出力する。
        if (in_string) {
          printf "%s", char

          if (escape) {
            # 直前がバックスラッシュだった場合、今の文字はエスケープ対象。
            # 今の文字を処理したので escape 状態を解除する。
            escape = 0
          } else if (char == "\\") {
            # バックスラッシュを見つけたら、次の1文字は特別扱いする。
            # 例: \" は文字列の終わりではなく、ダブルクォート文字。
            escape = 1
          } else if (char == "\"") {
            # エスケープされていない " を見つけたので、文字列の外へ出る。
            in_string = 0
          }

          # 文字列内の1文字は処理済みなので、以降の構文判定へ進まない。
          continue
        }

        # ここから下は、文字列の外側にいる場合の処理。
        # JSON構文として { [ ] } , : を見て、改行やインデントを入れる。

        if (char == "\"") {
          # 文字列の開始。
          in_string = 1
          printf "%s", char
        } else if (char == "{" || char == "[") {
          # オブジェクトまたは配列の開始。
          # 例: { の直後で改行し、次の行は1段深くする。
          printf "%s\n", char
          indent++
          print_indent(indent)
        } else if (char == "}" || char == "]") {
          # オブジェクトまたは配列の終了。
          # 閉じ括弧は1段浅い位置に置くため、先に改行してからindentを減らす。
          printf "\n"
          indent--

          if (indent < 0) {
            # 閉じ括弧が多すぎる場合。
            # 例: {"a":1}} のような入力。
            format_error = 1
            indent = 0
          }

          print_indent(indent)
          printf "%s", char
        } else if (char == ",") {
          # カンマの後で改行する。
          # 例: "a": 1, "b": 2 を2行に分ける。
          printf ",\n"
          print_indent(indent)
        } else if (char == ":") {
          # コロンの後に半角スペースを1つ入れる。
          # 例: "key":"value" -> "key": "value"
          printf ": "
        } else if (char !~ /[[:space:]]/) {
          # JSON文字列の外にある余分な空白は捨てる。
          # ただし数字、true、false、nullなどはそのまま出す。
          printf "%s", char
        }
      }
    }

    # ENDは入力をすべて読み終わった後に1回だけ実行される。
    END {
      # 最後に改行を1つ出す。
      printf "\n"

      if (in_string || indent != 0 || format_error) {
        # 文字列が閉じていない、括弧の数が合わないなどを簡易検知する。
        # 完全なJSON検証ではないが、明らかな崩れには気づける。
        print "ERROR: Unbalanced JSON quotes or brackets." > "/dev/stderr"
        exit 1
      }
    }
  ' "$1"
}

# 引数は最大2つまで。
# 1つ目: 入力ファイル、または "-"
# 2つ目: 出力ファイル
if [ "$#" -gt 2 ]; then
  usage >&2
  exit "$EXIT_USAGE_ERROR"
fi

# 引数なしで、かつパイプ入力もない場合は使い方を表示して終了する。
# [ -t 0 ] は「標準入力が端末につながっているか」を見る。
# つまり cat file | ./format_json_awk.sh のようなパイプ入力がない状態を検知する。
if [ "$#" -eq 0 ] && [ -t 0 ]; then
  usage >&2
  exit "$EXIT_USAGE_ERROR"
fi

# 1つ目の引数がなければ "-" とみなす。
# "-" は「標準入力から読む」という慣例的な指定。
INPUT_FILE="${1:--}"

# /dev/stdin を渡された場合も "-" と同じ扱いに統一する。
# macOSや環境によって /dev/stdin を通常ファイルとして判定しにくい場合があるため。
if [ "$INPUT_FILE" = "/dev/stdin" ]; then
  INPUT_FILE="-"
fi

readonly INPUT_FILE
readonly OUTPUT_FILE="${2:-}"

# 入力が "-" ではない場合は、通常ファイルとして存在確認と読み取り確認を行う。
# "-" の場合は標準入力なので、ファイル存在チェックはしない。
if [ "$INPUT_FILE" != "-" ]; then
  if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE" >&2
    exit "$EXIT_FILE_ERROR"
  fi

  if [ ! -r "$INPUT_FILE" ]; then
    echo "ERROR: Input file is not readable: $INPUT_FILE" >&2
    exit "$EXIT_FILE_ERROR"
  fi
fi

# 出力ファイルが指定されていない場合は、整形結果を標準出力へ出す。
# 例: ./format_json_awk.sh input.json
# 例: cat input.json | ./format_json_awk.sh
if [ -z "$OUTPUT_FILE" ]; then
  format_json "$INPUT_FILE" || exit "$EXIT_FORMAT_ERROR"
  exit "$EXIT_SUCCESS"
fi

# 入力ファイルを直接上書きしないための安全策。
# 整形に失敗したときに元ファイルを壊さないようにする。
if [ "$INPUT_FILE" != "-" ] && [ "$INPUT_FILE" = "$OUTPUT_FILE" ]; then
  echo "ERROR: Input and output files must be different." >&2
  exit "$EXIT_FILE_ERROR"
fi

# 出力先のディレクトリ名とファイル名を分ける。
readonly OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
readonly OUTPUT_NAME=$(basename "$OUTPUT_FILE")

# リダイレクトと同じで、ファイルは作れても途中のディレクトリは自動作成されない。
# そのため、出力先ディレクトリが存在するか事前確認する。
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "ERROR: Output directory not found: $OUTPUT_DIR" >&2
  exit "$EXIT_FILE_ERROR"
fi

# いきなり出力ファイルへ書かず、一時ファイルへ書く。
# 整形途中で失敗した場合に、壊れたファイルを成果物として残さないため。
TEMP_FILE=$(mktemp "${OUTPUT_DIR}/.${OUTPUT_NAME}.tmp.XXXXXX") || {
  echo "ERROR: Could not create a temporary output file." >&2
  exit "$EXIT_FILE_ERROR"
}

# スクリプトが途中終了した場合、一時ファイルを削除する。
trap 'rm -f "$TEMP_FILE"' EXIT

# 整形結果を一時ファイルへ書く。
# format_json が失敗した場合は、一時ファイルを本来の出力ファイルへ置き換えない。
if ! format_json "$INPUT_FILE" > "$TEMP_FILE"; then
  echo "ERROR: JSON formatting failed: $INPUT_FILE" >&2
  exit "$EXIT_FORMAT_ERROR"
fi

# 整形に成功した場合だけ、一時ファイルを正式な出力ファイルへ置き換える。
mv "$TEMP_FILE" "$OUTPUT_FILE"

# mv後は一時ファイルが存在しないため、trapを解除する。
trap - EXIT

echo "Formatted JSON written to: $OUTPUT_FILE"
exit "$EXIT_SUCCESS"
