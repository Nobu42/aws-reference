# Day 17 Learning: 運用シェル基礎・読解演習

## 1. 今日の目的

金融系の運用現場で、大きな共通関数シェル、設定ファイル、呼び出し元シェルを渡された場合に、処理の流れと異常終了の原因を追える状態を目指す。

```text
設定値はどこから来るか
  -> confファイル / 環境変数 / 引数 / declare

どの処理が呼ばれるか
  -> source / main関数 / 共通関数 / AWS CLI

成功・失敗をどう伝えるか
  -> stdout / stderr / return / exit / 終了コード
```

本ドリルは、現在参画中の別案件で観察したNTTデータ関連の金融系運用シェルの特徴を参考にした、クリーンルーム方式の読解演習である。

7月から参画する案件で同じシェル構成や実行方式が使われるとは限らない。現場固有仕様を予想して暗記するのではなく、一般的なBash運用シェルを安全に読める力を身につける。

関連資料:

- [案件対策ロードマップ](../docs/roadmaps/2026-06-05_to_2026-06-30_project_preparation_roadmap.md)
- [Day 1 S3 Security確認](./01_Day_Learning.md)
- [Day 2 S3 Bucket Policy変更ドリル](./02_Day_Learning.md)
- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)
- [Day 7 CloudTrail・CloudWatch総合調査](./07_Day_Learning.md)
- [Day 12 Security Group変更影響調査](./12_Day_Learning.md)
- [Day 13 Security Group変更ドリル](./13_Day_Learning.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)

---

## 2. 今日の調査シナリオ

次の依頼を受けた想定で運用シェルを読解する。

```text
AWS設定確認用の運用シェルについて、処理内容を確認してください。

共通関数ファイルと設定ファイルを読み込み、
対象AWSアカウントとS3バケットを確認する構成です。

正常系と異常系の処理、戻り値、ログ出力を整理してください。
本日はAWS設定変更を行わないでください。
```

## 今日の確認順序

1. 運用シェルの構成と前提を確認する
2. 実行ファイルと`source`の違いを理解する
3. `declare`、変数、設定ファイルを確認する
4. 関数、引数、`return`、`exit`を確認する
5. stdout、stderr、終了コードを確認する
6. `set -euo pipefail`の動きを確認する
7. AWS CLIの正常系・異常系処理を確認する
8. `grep`、`sed`、`awk`の用途を確認する
9. 共通関数シェルの処理経路を追う
10. 正常系・異常系の試験観点を整理する
11. マルチアカウントとジョブ実行時の注意点を整理する
12. 読解結果、証跡、報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| 主題 | Bash運用シェルの基礎と読解 |
| AWS操作 | 読み取り専用コマンドのみ |
| 対象例 | AWSアカウント確認、S3バケット存在確認 |
| 設定変更 | なし |
| 主な確認要素 | `source`、`declare`、関数、引数、戻り値、終了コード、ログ |
| 補助コマンド | `grep`、`sed`、`awk`、`bash -n` |

## 今日実行しない操作

- AWSリソースの作成、更新、削除
- 実在案件のシェルや設定値の持ち出し
- 実在案件のソースコードを模倣したファイルの作成
- 本番アカウントでの試験実行
- 承認されていないProfileやRoleへの切り替え
- `eval`を使った動的コマンド実行
- 秘密情報を含む状態での`set -x`

---

## 3. 現場で観察した特徴と今日の扱い

別案件で観察した運用シェルには、次の特徴があった。

| 観察した特徴 | 今日学ぶ一般化した内容 |
|---|---|
| 大きな共通関数ファイル | 関数の入力、処理、戻り値、呼び出し元を追う |
| 共通関数を`source`で読み込む | 同一シェルへ変数と関数を読み込む仕組みを理解する |
| confファイルを読み込む | 設定値の出所と上書き順序を確認する |
| `declare`が多い | 変数属性、配列、読み取り専用値を確認する |
| 引数チェックが厳格 | 実行前条件と異常終了条件を整理する |
| `return`が多い | 関数単位で失敗を呼び出し元へ返す流れを追う |
| AWS CLIを変数経由で呼ぶ | 実際に実行されるコマンドと引数を復元する |
| `sed`、`awk`を多用 | テキスト加工の目的と壊れやすい条件を確認する |
| 終了コードを管理する | ジョブ管理製品や呼び出し元へ結果を伝える仕組みを理解する |
| マルチアカウントを意識する | 対象アカウント誤りを防ぐ確認を重視する |

重要:

```text
観察した別案件の方式
  !=
7月から参画する案件の確定仕様
```

Day 17では、どの現場でも応用できる読解力を優先する。

---

## 4. 運用シェルを読む順序

大きなシェルを上から一行ずつ読み始めると全体像を失いやすい。最初に入口と出口を特定する。

## 推奨する読解順序

1. 実行されるシェルファイルを特定する
2. `main`関数または末尾の実行開始部分を探す
3. `source`されるファイルを一覧化する
4. 引数チェックを確認する
5. 設定値の取得元を確認する
6. `main`から呼ばれる関数を順番に追う
7. 各関数の`return`を確認する
8. 最後の`exit`を確認する
9. AWS CLIの実行箇所を確認する
10. ログと終了コードの対応を確認する

最初に検索する文字列:

```bash
grep -n '^source\|^\. ' target.sh
grep -n '^main()\|^function main' target.sh
grep -n '^declare\|^readonly\|^export' target.sh
grep -n '^ *return\|^ *exit' target.sh
grep -n 'aws ' target.sh
grep -n 'main "\$@"\|main \$@' target.sh
```

| 検索対象 | 確認目的 |
|---|---|
| `source`または`.` | 外部から読み込む関数・設定を特定する |
| `main` | 処理の開始地点を特定する |
| `declare`、`readonly`、`export` | Global設定と環境変数を特定する |
| `return`、`exit` | 正常・異常終了の経路を特定する |
| `aws` | AWS APIを呼び出す処理を特定する |

---

## 5. 実行とsourceの違い

子プロセスとして実行する。

```bash
bash ./child.sh
```

実行権限とshebangがある場合:

```bash
./child.sh
```

この場合、`child.sh`は別のシェルプロセスとして動く。子プロセス内で定義した変数や関数は、通常は呼び出し元へ残らない。

現在のシェルへ読み込む。

```bash
source ./common_functions.sh
```

`.`は`source`と同じ用途で使われる。

```bash
. ./common_functions.sh
```

| 観点 | `./script.sh` / `bash script.sh` | `source script.sh` |
|---|---|---|
| 実行場所 | 子プロセス | 現在のシェル |
| 関数定義 | 呼び出し元へ残らない | 呼び出し元で利用できる |
| 変数変更 | 原則として呼び出し元へ残らない | 呼び出し元へ影響する |
| `exit`の影響 | 子プロセスを終了する | 現在のシェルまで終了する可能性がある |
| 主な用途 | 実処理を実行する | 共通関数や設定を読み込む |

注意:

```text
sourceするファイルは、単なるデータではなく実行されるコードである。
信頼できないファイルをsourceしない。
共通関数ファイル内のexitは、呼び出し元まで終了させる可能性がある。
```

---

## 6. shebangと構文確認

先頭行のshebangは、直接実行時に使用するInterpreterを示す。

```bash
#!/bin/bash
```

実行前に確認する。

```bash
head -n 5 target.sh
file target.sh
bash --version
```

確認点:

- `/bin/bash`で動く前提か
- `/bin/sh`互換を求めているか
- Bash固有の`declare`、配列、`[[ ]]`を使っているか
- 改行コードがLFか
- 実行権限があるか

構文だけを確認する。

```bash
bash -n target.sh
```

`bash -n`は処理を実行せず、構文エラーを確認する。AWS APIは呼び出さない。

---

## 7. set -euo pipefail

このリポジトリの構築スクリプトでも、次の設定を多く使用している。

```bash
set -euo pipefail
```

| 設定 | 意味 | 注意点 |
|---|---|---|
| `set -e` | コマンドが失敗した場合にシェルを終了する | 条件式など例外的に終了しない場面がある |
| `set -u` | 未定義変数の参照をエラーにする | 任意変数は`${VAR:-}`などで扱う |
| `set -o pipefail` | Pipeline内の途中の失敗もPipeline全体の失敗にする | `grep`の未一致も失敗になる |

未定義変数を安全に確認する。

```bash
if [ -z "${PROFILE:-}" ]; then
  echo "ERROR: PROFILE is not set." >&2
  exit 2
fi
```

AWS CLIの失敗を自分で判定したい場合:

```bash
set +e
aws_output=$(aws sts get-caller-identity --profile "$PROFILE" --output text 2>&1)
aws_status=$?
set -e
```

終了コードは対象コマンドの直後で取得する。別のコマンドを実行すると`$?`は上書きされる。

---

## 8. 変数とdeclare

通常の変数:

```bash
PROFILE="learning"
REGION="ap-northeast-1"
```

関数内だけで使うLocal変数:

```bash
show_target() {
  local profile="$1"
  local region="$2"

  printf 'profile=%s region=%s\n' "$profile" "$region"
}
```

`local`を使うと、関数内の一時変数がGlobal変数を意図せず上書きする事故を減らせる。

| 記述 | 意味 |
|---|---|
| `declare NAME=value` | 変数を宣言する |
| `declare -r NAME=value` | 読み取り専用変数として宣言する |
| `declare -i COUNT=0` | 整数属性を付ける |
| `declare -a ITEMS=()` | Index配列を宣言する |
| `declare -A MAP=()` | 連想配列を宣言する |
| `declare -x NAME=value` | 環境変数としてExportする |
| `declare -p NAME` | 変数の宣言内容を表示する |
| `declare -F` | 定義済み関数名を一覧表示する |
| `declare -f function_name` | 指定関数の定義内容を表示する |

例:

```bash
declare -r RC_OK=0
declare -r RC_USAGE=2
declare -r RC_AWS_ERROR=255
declare -a TARGET_BUCKETS=()
declare -A PROFILE_BY_ENV=()
```

確認コマンド:

```bash
declare -p RC_OK RC_USAGE RC_AWS_ERROR
declare -F
declare -f show_target
```

注意:

- `declare -r`で読み取り専用にした値は後から変更できない
- 関数内の`declare`はBashでは原則としてLocal変数になる
- 変数名だけで意味を判断せず、宣言箇所と利用箇所を両方確認する

---

## 9. confファイルの確認

運用シェルでは、環境ごとの差分をconfファイルへ分離する場合がある。

クリーンルーム方式の例:

```bash
declare -r APP_NAME="aws-security-check"
declare -r PROFILE="learning"
declare -r REGION="ap-northeast-1"
declare -r EXPECTED_ACCOUNT_ID="445405559057"
declare -r TARGET_BUCKET="nobu-terraform-iac-lab-upload"
```

呼び出し元:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/conf/lab.conf"
source "${SCRIPT_DIR}/lib/common_functions.sh"
```

確認点:

- confファイルがどの順番で読み込まれるか
- 環境ごとにファイルが分かれているか
- 誰がconfファイルを変更できるか
- Password、Access Key、Secretが平文で含まれていないか
- `source`前後で変数が上書きされないか
- 相対パスではなく、スクリプト自身を基準としたパスを使っているか

---

## 10. 引数の基本

| 記述 | 意味 |
|---|---|
| `$0` | 実行したスクリプト名 |
| `$1` | 第1引数 |
| `$2` | 第2引数 |
| `$#` | 引数の個数 |
| `"$@"` | 各引数を個別の値として展開する |
| `"$*"` | 全引数を1つの文字列として展開する |
| `shift` | `$1`を捨てて、後続引数を前へ移動する |

厳格な引数チェック:

```bash
validate_args() {
  if [ "$#" -ne 2 ]; then
    echo "ERROR: Usage: $0 <profile> <bucket>" >&2
    return 2
  fi

  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "ERROR: profile and bucket must not be empty." >&2
    return 2
  fi

  return 0
}
```

確認点:

- 必須引数の個数
- 許可される値
- 空文字や不正文字の扱い
- 引数エラー時の終了コード
- Usageの出力先がstderrか

---

## 11. returnとexitの違い

`return`は関数または`source`されたファイルから呼び出し元へ戻る。

```bash
check_value() {
  local value="$1"

  if [ -z "$value" ]; then
    echo "ERROR: value is empty." >&2
    return 2
  fi

  return 0
}
```

`exit`はShell Processを終了する。

```bash
if ! check_value "${1:-}"; then
  exit 2
fi
```

```text
共通関数:
  returnで結果を呼び出し元へ返す

main関数:
  returnでトップレベルへ結果を返す

トップレベル:
  exitでジョブや呼び出し元へ最終結果を返す
```

`set -e`が有効な場合も、関数の非0終了を呼び出し元で処理できる形:

```bash
main() {
  if validate_args "$@"; then
    return 0
  else
    return $?
  fi
}

if main "$@"; then
  exit 0
else
  main_status=$?
  exit "$main_status"
fi
```

次のように単独で`main`を呼ぶと、`set -e`有効時は後続の終了コード取得や終了ログ出力へ進む前にShellが終了する可能性がある。

```text
main "$@"
main_status=$?
exit "$main_status"
```

最終ログ出力や後処理が必要な運用シェルでは、`if`条件内で`main`を呼ぶか、終了コード捕捉部分の設計を確認する。

終了コードは`0`から`255`の範囲で扱われる。`exit 256`は環境によって`0`として見えるため使用しない。

---

## 12. 終了コードの読み方

| 終了コード | 一般的な意味 | 注意 |
|---:|---|---|
| `0` | 正常終了 | 成功 |
| `1` | 一般的な異常終了 | 詳細はスクリプト設計を確認する |
| `2` | Usage、引数、構文などの異常 | 現場独自定義の場合もある |
| `126` | コマンドを実行できない | 権限や形式を確認する |
| `127` | コマンドが見つからない | PATHや導入状況を確認する |
| `128+n` | Signalによる終了 | 例: `130`はSIGINT相当 |
| `255` | 独自の重大異常、SSHやAWS CLIの失敗で見かける | 必ず仕様書・関数定義を確認する |

```text
255 = 常にAWS CLI異常
ではない。

運用シェルがAWS CLI異常を255へ変換する設計はあり得るが、
その意味は共通関数や終了コード一覧で確認する。
```

---

## 13. stdoutとstderr

| 出力先 | File Descriptor | 主な用途 |
|---|---:|---|
| 標準入力 | `0` | コマンドへの入力 |
| 標準出力 | `1` | 正常結果 |
| 標準エラー出力 | `2` | エラー、警告、診断情報 |

```bash
echo "INFO: check started."
echo "ERROR: check failed." >&2
```

Redirect:

```bash
command > stdout.log
command 2> stderr.log
command > stdout.log 2> stderr.log
command > combined.log 2>&1
command >> append.log 2>&1
```

確認点:

- 正常結果とエラーが別ファイルか
- ログへ秘密情報が出ないか
- 上書き`>`と追記`>>`を使い分けているか
- `2>&1`の位置が適切か

---

## 14. AWS CLI呼び出しを読む

直接呼び出す例:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager
```

文字列変数へ格納する例:

```bash
l_aws_cmd="aws sts get-caller-identity --profile ${PROFILE}"
```

文字列変数方式はQuote、空白、特殊文字の扱いが崩れやすい。`eval "$l_aws_cmd"`は、意図しない文字列までコマンドとして実行する危険がある。

Bash配列で保持する例:

```bash
declare -a AWS_BASE_CMD=(
  aws
  --profile "$PROFILE"
  --region "$REGION"
  --no-cli-pager
)

"${AWS_BASE_CMD[@]}" sts get-caller-identity --output table
```

現場では既存規約を優先する。文字列変数方式を見つけた場合は、実際の展開結果、Quote、`eval`利用の有無を慎重に確認する。

---

## 15. AWS CLIの正常系・異常系を捕捉する

```bash
run_aws_readonly() {
  local stdout_file="$1"
  local stderr_file="$2"
  shift 2

  local status

  set +e
  aws "$@" > "$stdout_file" 2> "$stderr_file"
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    echo "ERROR: AWS CLI failed. status=$status" >&2
    return 255
  fi

  return 0
}
```

呼び出し例:

```bash
if run_aws_readonly \
  "/tmp/caller_identity.out" \
  "/tmp/caller_identity.err" \
  sts get-caller-identity \
  --profile "$PROFILE" \
  --output text \
  --no-cli-pager; then
  status=0
else
  status=$?
fi

printf 'wrapper_status=%s\n' "$status"
```

この例では、AWS CLIが返した非0の終了コードを共通関数側で`255`へ変換している。

確認点:

- AWS CLI本来の終了コードを保持するか
- 共通関数の独自終了コードへ変換するか
- stdoutとstderrをどこへ保存するか
- `AccessDenied`とリソース未存在を区別するか
- Retry対象と即時異常終了を区別するか

---

## 16. 対象AWSアカウントの誤りを防ぐ

マルチアカウント環境では、AWS CLIが成功しても対象アカウントが誤っていれば作業事故になる。

```bash
check_account() {
  local profile="$1"
  local expected_account_id="$2"
  local actual_account_id

  actual_account_id=$(aws sts get-caller-identity \
    --profile "$profile" \
    --query Account \
    --output text \
    --no-cli-pager) || return 255

  if [ "$actual_account_id" != "$expected_account_id" ]; then
    echo "ERROR: Unexpected AWS account: $actual_account_id" >&2
    return 10
  fi

  echo "INFO: Account check OK: $actual_account_id"
  return 0
}
```

確認する値:

- AWSアカウントID
- IAM UserまたはAssumed RoleのARN
- AWS CLI Profile
- Region
- 対象リソース名
- 作業環境名

---

## 17. grep・sed・awkの基本

## grep

`grep`は行から条件に一致する文字列を検索する。

```bash
grep -n 'ERROR' operation.log
grep -q 'AccessDenied' operation.log
grep -E 'ERROR|WARNING' operation.log
grep -v '^#' app.conf
```

| 戻り値 | 意味 |
|---:|---|
| `0` | 一致あり |
| `1` | 一致なし |
| `2`以上 | 実行エラー |

`set -euo pipefail`環境では、単なる一致なしが処理全体の失敗になる場合がある。条件式内で利用する。

```bash
if grep -q 'NoSuchBucket' aws_error.log; then
  echo "INFO: Bucket does not exist."
else
  echo "INFO: NoSuchBucket was not found."
fi
```

## sed

`sed`は行単位の置換、削除、抽出に使われる。

```bash
printf '%s\n' 'arn:aws:s3:::example-bucket' \
  | sed 's#arn:aws:s3:::#bucket=#'
```

```bash
sed '/^$/d' target.txt
sed '/^#/d' target.conf
sed -n '1,20p' target.sh
```

macOSのBSD `sed`とLinuxのGNU `sed`ではOption差がある。JSONを正規表現だけで解析すると、改行、空白、配列、Escapeで壊れやすい。

## awk

`awk`は区切られた列の抽出、条件判定、簡単な集計に使われる。

```bash
awk -F= '$1 == "PROFILE" {print $2}' sample.conf
awk '$1 == "ERROR" {print NR, $0}' operation.log
```

AWS CLIの`--output table`を`awk`で解析しない。自動処理では、可能ならAWS CLIの`--query`と`--output text`で必要値を絞る。

---

## 18. JSON解析と現場制約

JSONは階層構造を持つため、`sed`や`awk`だけで安全に解析することは難しい。

```text
推奨順位の考え方:

1. AWS CLI --queryで必要な値へ絞る
2. --output textで単純な値として取得する
3. 現場承認済みのJSON Parserを使う
4. 固定形式が保証される場合だけsed・awkを限定利用する
```

`jq`が使えない環境では無理に導入しない。現場の標準ツール、持ち込み制約、審査済み手順へ従う。

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$TARGET_BUCKET" \
  --query 'PolicyStatus.IsPublic' \
  --output text \
  --no-cli-pager
```

---

## 19. Pipelineとpipefail

```bash
printf '%s\n' "$value" \
  | tr '[:space:]' '\n' \
  | sed '/^$/d' \
  | sort -u
```

通常、Pipeline全体の終了コードは最後のコマンドの終了コードになる。`set -o pipefail`を有効にすると、途中のコマンドの失敗もPipeline全体の失敗になる。

```bash
set -o pipefail
printf '%s\n' "sample" | grep 'not-found' | sort
status=$?
printf 'pipeline_status=%s\n' "$status"
```

`grep`の未一致は`1`であるため、`pipefail`環境ではPipeline全体が失敗になる。

---

## 20. 現在のリポジトリから読むポイント

現在の`aws-reference`には、共通関数ファイルを`source`する巨大シェル構成はない。一方、運用シェル読解に役立つ要素は既存スクリプトにも含まれる。

| ファイル | 読むポイント |
|---|---|
| `scripts/08_Web_server_setup.sh` | `local`、必須値確認、AWS CLIの終了コード捕捉、Duplicate判定 |
| `scripts/19_elasticache_setup.sh` | Wait、Retry、Timeout、`return 0`、`exit 1` |
| `scripts/cleanup_network.sh` | 多数の関数、`sed`・`tr`・`sort`、削除済み判定、Retry |
| `scripts/All_Setup.sh` | 複数シェルの順次実行、前工程の結果確認 |

読み取りコマンド:

```bash
grep -n '^set -euo pipefail\|^.*() {\|return\|exit' \
  ../scripts/08_Web_server_setup.sh
```

```bash
grep -n 'set +e\|InvalidPermission.Duplicate\|rule_status' \
  ../scripts/08_Web_server_setup.sh
```

```bash
grep -n 'return 0\|exit 1\|sed \|awk \|tr ' \
  ../scripts/cleanup_network.sh
```

---

## 21. クリーンルーム方式の構成例

次の構成は運用シェルの読解練習用モデルであり、実在案件のファイル構成ではない。

```text
operations-shell/
├── conf/
│   └── lab.conf
├── lib/
│   └── common_functions.sh
├── bin/
│   └── check_s3_bucket.sh
└── log/
```

```text
check_s3_bucket.sh
  |
  +-- source lab.conf
  +-- source common_functions.sh
  |
  +-- main "$@"
       +-- validate_args
       +-- check_account
       +-- check_s3_bucket
       +-- write_result
  |
  +-- exit <mainの戻り値>
```

---

## 22. 共通関数の読解例

次の例は読み取り専用AWS CLIだけを使用する。

```bash
log_info() {
  printf '%s INFO %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  return 0
}

log_error() {
  printf '%s ERROR %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  return 0
}

check_s3_bucket() {
  local profile="$1"
  local region="$2"
  local account_id="$3"
  local bucket="$4"
  local status

  set +e
  aws s3api head-bucket \
    --profile "$profile" \
    --region "$region" \
    --bucket "$bucket" \
    --expected-bucket-owner "$account_id" \
    --no-cli-pager > /tmp/head_bucket.out 2> /tmp/head_bucket.err
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    log_error "S3 bucket check failed. status=$status bucket=$bucket"
    return 255
  fi

  log_info "S3 bucket check succeeded. bucket=$bucket"
  return 0
}
```

| 項目 | `check_s3_bucket`の内容 |
|---|---|
| 目的 | 対象バケットの存在、アクセス、所有者を確認する |
| 入力 | Profile、Region、Account ID、Bucket名 |
| 参照する外部値 | AWS CLI認証情報 |
| 実行コマンド | `aws s3api head-bucket` |
| stdout | `/tmp/head_bucket.out` |
| stderr | `/tmp/head_bucket.err` |
| 正常時 | INFOログを出力し`return 0` |
| 異常時 | ERRORログを出力し`return 255` |
| AWS設定変更 | なし |

---

## 23. main関数の読解例

```bash
main() {
  local status

  if validate_args "$@"; then
    :
  else
    status=$?
    return "$status"
  fi

  if check_account "$1" "$3"; then
    :
  else
    status=$?
    return "$status"
  fi

  if check_s3_bucket "$1" "$2" "$3" "$4"; then
    :
  else
    status=$?
    return "$status"
  fi

  return 0
}
```

トップレベル:

```bash
if main "$@"; then
  exit 0
else
  main_status=$?
  exit "$main_status"
fi
```

```text
validate_args失敗
  -> mainが同じstatusをreturn
  -> トップレベルが同じstatusでexit
  -> ジョブ管理側が異常終了を検知
```

---

## 24. 関数読解ワークシート

大きな共通関数ファイルを読む場合は、次の表を関数ごとに作る。

| 項目 | 記録内容 |
|---|---|
| 関数名 | 何という関数か |
| 目的 | 何を確認・変更するか |
| 引数 | `$1`から何を受け取るか |
| Global変数 | confや共通ファイルの何を参照するか |
| 実行コマンド | AWS CLI、OSコマンド、外部シェル |
| stdout | 正常結果をどこへ出すか |
| stderr | エラーをどこへ出すか |
| 戻り値 | `0`、`1`、`255`などの意味 |
| Side Effect | AWS設定、ファイル、ログへの変更 |
| 呼び出し元 | どの関数から呼ばれるか |
| 呼び出し先 | どの関数を呼ぶか |

記載例:

```text
関数名:
  check_s3_bucket

目的:
  対象S3バケットの存在、アクセス権、所有アカウントを確認する。

入力:
  profile、region、expected account ID、bucket name

正常時:
  INFOログを出力し、0を返す。

異常時:
  AWS CLIのstderrを保存し、ERRORログを出力して255を返す。

副作用:
  AWS設定変更なし。ローカルログファイルを作成する。
```

---

## 25. 正常系・異常系試験

## 正常系

| No. | 試験 | 期待結果 |
|---:|---|---|
| 1 | 正しい引数を指定する | 引数チェック成功 |
| 2 | 想定Profileを指定する | Caller Identity取得成功 |
| 3 | 想定Account IDを指定する | アカウント一致 |
| 4 | 存在するS3バケットを指定する | `head-bucket`成功 |
| 5 | 正常ログを確認する | 対象、時刻、結果が記録される |
| 6 | 最終終了コードを確認する | `0` |

## 異常系

| No. | 異常条件 | 確認すること | 終了コード例 |
|---:|---|---|---:|
| 1 | 引数なし | Usageと引数エラーがstderrへ出る | `2` |
| 2 | 引数数が多い | 厳格に拒否される | `2` |
| 3 | 想定外Profile | AWS認証またはAccount Checkで停止する | `10`または`255` |
| 4 | 想定外Account ID | AWS操作前に停止する | `10` |
| 5 | 存在しないBucket | stderrを保存し異常終了する | `255`など |
| 6 | AccessDenied | リソース未存在と区別して報告する | `255`など |
| 7 | AWS CLIなし | Command Not Foundを検知する | `127` |
| 8 | confファイルなし | `source`前に検知する | `1`または独自値 |
| 9 | ログ保存先へ書けない | AWS操作前またはログ出力時に停止する | 独自値 |
| 10 | Timeout | Retry回数と最終異常を記録する | 独自値 |

終了コード例はクリーンルーム方式の例である。実際の終了コードは現場の設計書と共通関数を確認する。

---

## 26. bash -xを使う場合の注意

`bash -x`は実行したコマンドと展開後の引数を表示するため、処理経路の調査に役立つ。

```bash
bash -x target.sh arg1 arg2
```

ただし、Password、Token、Access Key、Secret、Session情報、個人情報がログへ出る可能性がある。本番環境で無断使用しない。

構文確認だけであれば、まず`bash -n`を使う。

---

## 27. ログとジョブ管理

運用シェルのログへ含めたい情報:

- 実行開始・終了時刻
- 処理名
- 対象環境
- 対象AWSアカウントID
- 対象リージョン
- 対象リソース
- 正常・異常
- 終了コード
- エラー概要

ログへ含めない情報:

- Password
- Secret Access Key
- Session Token
- 秘密鍵
- 認証Cookie
- 不要な個人情報

```text
2026-06-24 09:00:00 INFO START check_s3_bucket account=445405559057 region=ap-northeast-1
2026-06-24 09:00:01 INFO SUCCESS check_s3_bucket bucket=nobu-terraform-iac-lab-upload
2026-06-24 09:00:01 INFO END status=0
```

JP1などのジョブ管理製品は、一般にShellの終了コードとログを使って正常・異常を判断する。

```text
ジョブ管理製品
  -> シェルを起動
  -> シェルが処理を実行
  -> exit statusを返す
  -> ジョブ管理製品が後続実行、停止、通知を判断
```

確認点:

- 正常終了コードの範囲
- 警告終了と異常終了の区別
- 後続ジョブを停止する終了コード
- Retry、Timeout、同時実行防止
- ログ保存期間と通知先

`JP1らしい書き方に見える`ことと、`JP1で実行されることが確定している`ことは別である。

---

## 28. マルチアカウント対応

複数AWSアカウントへ同じシェルを使う場合、環境名からProfile、Role ARN、Account IDを切り替える構成があり得る。

```bash
select_account() {
  local environment="$1"

  case "$environment" in
    dev)
      PROFILE="learning"
      EXPECTED_ACCOUNT_ID="445405559057"
      ;;
    *)
      echo "ERROR: Unsupported environment: $environment" >&2
      return 2
      ;;
  esac

  return 0
}
```

確認点:

- 環境名とAWSアカウントIDの対応
- AssumeRoleの有無
- Default Profileへ意図せずFallbackしないか
- Caller Identity確認があるか
- Regionを固定するか引数で受け取るか
- 本番環境だけ追加承認が必要か

---

## 29. セキュリティ上の注意点

- 変数は原則としてQuoteする
- `eval`を避ける
- 一時ファイルへ秘密情報を保存しない
- `source`対象のOwnerとPermissionを確認する
- AWS CLIの`--profile`、`--region`、対象IDを明示する
- `get`、`list`、`describe`、`head`か確認する
- `put`、`create`、`update`、`delete`、`modify`は承認後に実行する
- Caller Identityを先に確認する
- `bash -x`利用前に秘密情報の出力リスクを確認する

Quoteする例:

```bash
aws s3api head-bucket --bucket "$TARGET_BUCKET"
```

---

## 30. よくある読解ミス

| 読解ミス | 正しい確認 |
|---|---|
| `return 255`を見てAWS CLIが255を返したと断定する | 関数内で終了コードを変換していないか確認する |
| `source`を設定値の読込みだけと考える | 任意のShell Codeが実行されると認識する |
| `set -e`なら全エラーで必ず止まると考える | 条件式、Pipeline、Subshellなどの例外を確認する |
| stdoutだけを確認する | stderrと終了コードも確認する |
| `grep`未一致をコマンド異常と断定する | `grep`の戻り値`1`は未一致と理解する |
| `--output table`を自動解析する | `--query`と`--output text`を検討する |
| `255`の意味を共通仕様と考える | 現場の終了コード設計を確認する |
| 大きな関数ファイルを最初から逐次読む | `main`、呼び出し順、戻り値から追う |

---

## 31. トラブルシューティング

`command not found`:

```bash
command -v aws
command -v grep
command -v sed
command -v awk
```

`source: No such file or directory`:

```bash
pwd
ls -l target.sh
```

`unbound variable`:

```bash
printf 'PROFILE=%s\n' "${PROFILE:-<unset>}"
```

AWS CLIが失敗した場合の確認順序:

1. stderr
2. 終了コード
3. Caller Identity
4. Profile
5. Region
6. 対象リソース名
7. IAM権限
8. CloudTrail

Pipelineが予想外に失敗する場合:

```bash
set -o | grep pipefail
```

---

## 32. 証跡として残すもの

| 証跡 | 内容 |
|---|---|
| シェル構成図 | conf、共通関数、呼び出し元の関係 |
| 関数読解表 | 入力、処理、戻り値、Side Effect |
| 終了コード一覧 | 正常、Usage、対象誤り、AWS CLI異常 |
| 正常系結果 | 実行条件、ログ、終了コード |
| 異常系結果 | 異常条件、エラーログ、終了コード |
| 構文確認結果 | `bash -n`の結果 |
| 未確認事項 | 実行方式、ジョブ管理、現場固有規約 |

証跡名の例:

```text
01_shell_structure.png
02_function_reading_sheet.txt
03_return_code_list.txt
04_normal_test_result.txt
05_abnormal_test_result.txt
06_bash_syntax_check.txt
```

---

## 33. 作業結果の報告例

```text
AWS設定確認用運用シェルの読解を実施した。

呼び出し元シェルは、confファイルおよび共通関数ファイルをsourceし、
main関数から引数確認、AWSアカウント確認、S3バケット確認を順番に実行する構成である。

各関数は正常時に0、引数不備時に2、対象アカウント不一致時に10、
AWS CLI異常時に255を呼び出し元へ返す設計であることを確認した。

AWS CLI異常時はstderrを保存し、最終的にトップレベルのexit statusとして
呼び出し元へ返す流れである。

本日は読解と構文確認のみを実施し、AWS設定変更は実施していない。
```

Teams向け短文報告例:

```text
運用シェルの処理経路と異常系を確認した。
conf・共通関数をsourceし、mainから各確認関数を実行する構成である。
引数、戻り値、AWS CLI異常時のstderrと最終終了コードを整理済み。
AWS設定変更は実施していない。
```

---

## 34. 案件で説明できるポイント

- 大きな共通関数シェルでも`main`から呼び出し順を追える
- `source`と子プロセス実行の違いを説明できる
- `declare`、Global変数、Local変数の役割を説明できる
- 引数チェックとUsage Errorを確認できる
- `return`と`exit`の違いを説明できる
- stdout、stderr、終了コードを分けて確認できる
- AWS CLI異常を呼び出し元へ返す流れを追える
- `grep`、`sed`、`awk`の用途と限界を説明できる
- JSON解析ではAWS CLIの`--query`を優先する理由を説明できる
- マルチアカウント作業でCaller Identity確認が重要な理由を説明できる
- ジョブ管理製品が終了コードを使う理由を説明できる

---

## 35. 資格試験につながるポイント

- AWS CLI Profileと認証情報の関係
- STS `GetCallerIdentity`による実行主体の確認
- IAM User、Assumed Role、AWSアカウントIDの識別
- 最小権限と読み取り専用確認
- CloudTrailによるAWS API実行履歴の確認
- マルチアカウント運用とRole切り替え
- S3 `HeadBucket`による存在、アクセス、所有者確認

資格試験ではBash構文そのものよりも、IAM、CloudTrail、マルチアカウント、監査の考え方へつながる。

---

## 36. 要確認事項

7月案件へ参画後、次を確認する。

- AWS設定変更はWebコンソール、AWS CLI、既存シェルのどれで実施するか
- 共通関数シェルやconfファイルが存在するか
- 利用可能なShell、AWS CLI、`grep`、`sed`、`awk`のVersion
- `jq`、Python、PowerShellなどの利用可否
- 終了コード一覧とログ規約があるか
- JP1などのジョブ管理製品から実行するか
- マルチアカウントの切り替え方式
- 本番、検証、開発のProfileまたはRoleの対応
- シェルの変更手順、Review、試験、Release方法
- `bash -x`やDebug Logの利用可否

不明な点は推測で処理せず、設計書、手順書、共通関数、担当者確認で確定する。

---

## 37. Day 17完了チェックリスト

### 構造確認

- [ ] 実行ファイル、conf、共通関数の関係を説明できる
- [ ] `source`されるファイルを特定できる
- [ ] `main`から関数の呼び出し順を追える
- [ ] 設定値の出所を特定できる

### Bash基礎

- [ ] `declare`、`local`、`readonly`、`export`の違いを説明できる
- [ ] `$0`、`$1`、`$#`、`"$@"`を説明できる
- [ ] `return`と`exit`の違いを説明できる
- [ ] stdoutとstderrを区別できる
- [ ] 終了コードを直後に取得する理由を説明できる
- [ ] `set -euo pipefail`の目的と注意点を説明できる

### AWS CLI異常系

- [ ] Caller Identityによる対象アカウント確認を説明できる
- [ ] AWS CLIのstdout、stderr、終了コードを分けて確認できる
- [ ] AWS CLI本来の終了コードと共通関数の戻り値を区別できる
- [ ] `255`の意味を現場仕様確認なしに断定しない
- [ ] AWS設定変更コマンドを承認なしで実行しない

### テキスト処理

- [ ] `grep`の一致、未一致、実行エラーを区別できる
- [ ] `sed`の置換と行削除の用途を説明できる
- [ ] `awk`の列抽出の用途を説明できる
- [ ] JSONを`sed`や`awk`だけで解析するリスクを説明できる
- [ ] AWS CLIの`--query`と`--output text`を利用できる

### 報告

- [ ] 関数読解ワークシートを作成できる
- [ ] 正常系と異常系の結果を整理できる
- [ ] 終了コード一覧を作成できる
- [ ] 未確認事項を推測と分けて報告できる

## Day 17の完了条件

次を自分の言葉で説明できればDay 17は完了とする。

```text
運用シェルは、入口となるmain、sourceされる設定と共通関数、
各関数の入力・処理・戻り値、最後のexitを順番に追って読解する。

関数内ではreturnで結果を呼び出し元へ返し、
トップレベルではexitでジョブや親プロセスへ最終結果を返す。

AWS CLI異常時はstdoutだけでなく、stderrと終了コードを確認する。
終了コード255の意味は固定ではなく、共通関数や設計書で確認する。

マルチアカウント作業では、実行前にCaller Identityを確認する。

別案件で観察した運用シェルの特徴は参考情報であり、
7月案件の実行方式として断定しない。
```
