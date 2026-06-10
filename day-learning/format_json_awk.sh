#!/bin/bash

set -u

readonly EXIT_SUCCESS=0
readonly EXIT_USAGE_ERROR=2
readonly EXIT_FILE_ERROR=3
readonly EXIT_FORMAT_ERROR=4

usage() {
  cat <<'USAGE'
Usage:
  format_json_awk.sh <input-json-file> [output-json-file]

Examples:
  ./scripts/format_json_awk.sh input.json
  ./scripts/format_json_awk.sh input.json formatted.json

Notes:
  - When output-json-file is omitted, the formatted JSON is written to stdout.
  - The input file is never overwritten.
  - This script formats JSON with awk, but does not perform full JSON validation.
USAGE
}

format_json() {
  awk '
    function print_indent(count, i) {
      for (i = 0; i < count; i++) {
        printf "  "
      }
    }

    BEGIN {
      indent = 0
      in_string = 0
      escape = 0
      format_error = 0
    }

    {
      for (i = 1; i <= length($0); i++) {
        char = substr($0, i, 1)

        if (in_string) {
          printf "%s", char

          if (escape) {
            escape = 0
          } else if (char == "\\") {
            escape = 1
          } else if (char == "\"") {
            in_string = 0
          }

          continue
        }

        if (char == "\"") {
          in_string = 1
          printf "%s", char
        } else if (char == "{" || char == "[") {
          printf "%s\n", char
          indent++
          print_indent(indent)
        } else if (char == "}" || char == "]") {
          printf "\n"
          indent--

          if (indent < 0) {
            format_error = 1
            indent = 0
          }

          print_indent(indent)
          printf "%s", char
        } else if (char == ",") {
          printf ",\n"
          print_indent(indent)
        } else if (char == ":") {
          printf ": "
        } else if (char !~ /[[:space:]]/) {
          printf "%s", char
        }
      }
    }

    END {
      printf "\n"

      if (in_string || indent != 0 || format_error) {
        print "ERROR: Unbalanced JSON quotes or brackets." > "/dev/stderr"
        exit 1
      }
    }
  ' "$1"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage >&2
  exit "$EXIT_USAGE_ERROR"
fi

readonly INPUT_FILE="$1"
readonly OUTPUT_FILE="${2:-}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: Input file not found: $INPUT_FILE" >&2
  exit "$EXIT_FILE_ERROR"
fi

if [ ! -r "$INPUT_FILE" ]; then
  echo "ERROR: Input file is not readable: $INPUT_FILE" >&2
  exit "$EXIT_FILE_ERROR"
fi

if [ -z "$OUTPUT_FILE" ]; then
  format_json "$INPUT_FILE" || exit "$EXIT_FORMAT_ERROR"
  exit "$EXIT_SUCCESS"
fi

if [ "$INPUT_FILE" = "$OUTPUT_FILE" ]; then
  echo "ERROR: Input and output files must be different." >&2
  exit "$EXIT_FILE_ERROR"
fi

readonly OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
readonly OUTPUT_NAME=$(basename "$OUTPUT_FILE")

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "ERROR: Output directory not found: $OUTPUT_DIR" >&2
  exit "$EXIT_FILE_ERROR"
fi

TEMP_FILE=$(mktemp "${OUTPUT_DIR}/.${OUTPUT_NAME}.tmp.XXXXXX") || {
  echo "ERROR: Could not create a temporary output file." >&2
  exit "$EXIT_FILE_ERROR"
}

trap 'rm -f "$TEMP_FILE"' EXIT

if ! format_json "$INPUT_FILE" > "$TEMP_FILE"; then
  echo "ERROR: JSON formatting failed: $INPUT_FILE" >&2
  exit "$EXIT_FORMAT_ERROR"
fi

mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "Formatted JSON written to: $OUTPUT_FILE"
exit "$EXIT_SUCCESS"
