# Day 17 Learning: 共通関数シェル・confハンズオン

## 学習開始前に実行するスクリプト

Day 17はローカルの運用シェル読解ハンズオンである。既定ではモック応答を使うため、AWS APIは呼び出さない。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

実AWSへ読み取り確認したい場合だけ、本文の最後にある`DAY17_RUN_MODE=real`を使用する。通常のDay 17学習では不要である。

最初に教材ディレクトリへ移動し、ファイル構成を確認する。

```bash
cd /Users/nobu/aws-reference/scripts/operations_shell_lab

find . -maxdepth 3 -type f | sort
```

## 1. 今日の目的

金融系の現場では、次のような構成のシェルに遭遇することがある。

```text
実行シェル
  -> confファイルをsource
  -> 共通関数シェルをsource
  -> AWS CLIを共通関数経由で実行
  -> stdout / stderr / 終了コード / 証跡ディレクトリへ結果を残す
```

Day 17では、実際に大きめの共通関数シェル、設定ファイル、実行シェル、モックAWS応答を用意し、それらを手で読んで実行する。

この教材はクリーンルーム方式で作成した学習用ファイルである。実在案件のシェル、設定値、設計を複製したものではない。

## 2. 今日使うファイル

```bash
cd /Users/nobu/aws-reference/scripts/operations_shell_lab

find . -maxdepth 3 -type f | sort
```

想定する構成:

```text
./README.md
./bin/s3_security_check.sh
./conf/accounts.conf
./conf/s3_security_check.conf
./fixtures/access_denied/get_bucket_policy_error.txt
./fixtures/ok/get_bucket_policy.json
./fixtures/ok/get_bucket_policy_status.json
./fixtures/ok/get_public_access_block.json
./fixtures/ok/sts_get_caller_identity.json
./fixtures/wrong_account/sts_get_caller_identity.json
./lib/aws_api_common_functions.sh
```

役割:

| ファイル | 役割 |
|---|---|
| `bin/s3_security_check.sh` | 作業者が実行する入口のシェル |
| `lib/aws_api_common_functions.sh` | 共通関数、終了コード、ログ、AWS CLIラッパー |
| `conf/s3_security_check.conf` | 対象Profile、Region、Bucket、実行モード |
| `conf/accounts.conf` | アカウントIDやラベルの定義 |
| `fixtures/ok/` | 正常系のAWS CLIモック応答 |
| `fixtures/wrong_account/` | アカウント相違のモック応答 |
| `fixtures/access_denied/` | AccessDeniedのモック応答 |

## 3. まず構文確認する

運用シェルを読む前に、構文エラーがないかを確認する。

```bash
bash -n lib/aws_api_common_functions.sh
bash -n bin/s3_security_check.sh
```

出力がなければ構文エラーなしである。

見るポイント:

```text
bash -nは実行しない
構文だけを見る
AWS APIも呼ばない
```

## 4. 入口のシェルを読む

最初から全部読まず、入口だけを探す。

```bash
grep -n '^source\|^check_.*()\|^main()\|op_run_aws\|^exit ' \
  bin/s3_security_check.sh
```

読み方:

| 見る場所 | 意味 |
|---|---|
| `source "$COMMON_FILE"` | 共通関数ファイルを読み込む |
| `source "$CONF_FILE"` | confファイルを読み込む |
| `source "$ACCOUNTS_CONF"` | アカウント定義を読み込む |
| `check_caller_identity()` | アカウント確認処理 |
| `check_public_access_block()` | S3 Public Access Block確認 |
| `check_policy_status()` | S3 Bucket PolicyのPublic判定確認 |
| `check_bucket_policy()` | Bucket Policy本文確認 |
| `main()` | 実際の処理順序 |
| `exit "$rc"` | 最終的な終了コード |

実案件で大きなシェルを渡されたら、まずここを探す。

## 5. confファイルを読む

```bash
sed -n '1,120p' conf/s3_security_check.conf
```

重要な設定:

| 設定 | 意味 |
|---|---|
| `RUN_MODE=mock` | 既定ではAWS APIを呼ばず、fixturesを読む |
| `MOCK_SCENARIO=ok` | 正常系モックを使う |
| `AWS_PROFILE=learning` | AWS CLI Profile |
| `AWS_REGION=ap-northeast-1` | 対象Region |
| `EXPECTED_ACCOUNT_ID=445405559057` | 想定アカウントID |
| `TARGET_BUCKET=nobu-terraform-iac-lab-upload` | 対象S3 Bucket |
| `EVIDENCE_ROOT=evidence/day17_operations_shell` | 証跡保存先 |

コメントと空行を除いて確認する。

```bash
sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' \
  conf/s3_security_check.conf
```

`awk`でキーと値を分けて見る。

```bash
awk -F= '
  $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {
    printf "%-28s %s\n", $1, $2
  }
' conf/s3_security_check.conf
```

現場での読み方:

```text
シェル本体だけを見るのではなく、confで実行対象が決まる。
Profile、Region、Account、Bucketを最初に確認する。
```

## 6. 共通関数ファイルを読む

関数一覧だけを先に出す。

```bash
grep -n '^op_.*()' lib/aws_api_common_functions.sh
```

主な関数:

| 関数 | 役割 |
|---|---|
| `op_log()` | 標準出力とログファイルへ記録 |
| `op_log_error()` | エラーを記録 |
| `op_require_command()` | 必要なコマンドの存在確認 |
| `op_require_file()` | 必要なファイルの存在確認 |
| `op_require_vars()` | 必須変数の空チェック |
| `op_init_evidence()` | 証跡ディレクトリ作成 |
| `op_json_value()` | JSON風テキストから値を取り出す |
| `op_json_has_text()` | JSON風テキストに指定文字列があるか確認 |
| `op_run_mock_aws()` | モックAWS応答を返す |
| `op_run_real_aws()` | 実AWS CLIを実行する |
| `op_run_aws()` | mock/realを切り替えるAWS CLIラッパー |
| `op_assert_account()` | アカウントID確認 |
| `op_report_result()` | 結果サマリをTSVに追記 |

`declare`も確認する。

```bash
grep -n '^declare\|^OP_' lib/aws_api_common_functions.sh
```

この教材ではmacOS標準のBash 3.2でも動くように、定数は`declare -r`で定義している。Linux環境の新しいBashでは`declare -g`を見ることもあるが、古いBashでは使えない場合がある。

## 7. 正常系を実行する

```bash
./bin/s3_security_check.sh \
  --conf conf/s3_security_check.conf

echo $?
```

期待する終了コード:

```text
0
```

期待する主な表示:

```text
RUN_MODE=mock
MOCK_SCENARIO=ok
RESULT caller_identity: OK
RESULT public_access_block: OK
RESULT bucket_policy_status: OK
RESULT bucket_policy: OK
Script finished successfully.
```

この実行ではAWS APIは呼ばない。`fixtures/ok/`配下のJSONをAWS CLI結果として扱う。

## 8. 証跡ディレクトリを見る

最新の証跡ディレクトリを変数に入れる。

```bash
EVIDENCE_DIR=$(
  ls -dt /Users/nobu/aws-reference/evidence/day17_operations_shell/*_s3_security_check \
    | head -n 1
)

echo "$EVIDENCE_DIR"
```

中身を見る。

```bash
find "$EVIDENCE_DIR" -type f | sort
```

代表的なファイル:

| ファイル | 意味 |
|---|---|
| `run.log` | 実行ログ |
| `stdout/01_caller_identity.json` | Caller Identity確認結果 |
| `stdout/02_public_access_block.json` | Public Access Block確認結果 |
| `stdout/03_bucket_policy_status.json` | Bucket Policy Status確認結果 |
| `stdout/04_bucket_policy.json` | Bucket Policy本文 |
| `stderr/*.err` | 各AWS CLI相当処理のstderr |
| `result/check_summary.tsv` | 確認結果のサマリ |

ログを見る。

```bash
cat "$EVIDENCE_DIR/run.log"
```

サマリを見る。

```bash
cat "$EVIDENCE_DIR/result/check_summary.tsv"
```

期待する内容:

```text
check	status	detail
caller_identity	OK	expected_account=445405559057
public_access_block	OK	all_four_settings_true
bucket_policy_status	OK	IsPublic=false
bucket_policy	OK	required_deny_statements_found
```

## 9. 正常系の処理経路を追う

入口の`main()`を読む。

```bash
sed -n '/^main()/,/^}/p' bin/s3_security_check.sh
```

読み方:

```text
check_usage_vars
  -> 必須変数の確認

op_require_command
  -> sed / awk / awsなどの存在確認

op_init_evidence
  -> 証跡ディレクトリ作成

check_caller_identity
  -> アカウント確認

check_public_access_block
  -> S3 Public Access Block確認

check_policy_status
  -> Bucket PolicyがPublic扱いか確認

check_bucket_policy
  -> Bucket Policy本文確認
```

AWS CLI相当処理は直接`aws`を呼ばず、`op_run_aws()`を通る。

```bash
sed -n '/^op_run_aws()/,/^}/p' lib/aws_api_common_functions.sh
```

見るポイント:

```text
RUN_MODE=mockならfixturesを読む
RUN_MODE=realなら実AWS CLIを実行する
stdoutとstderrを別ファイルへ保存する
失敗時はOP_RC_AWS=20を返す
```

## 10. 異常系1: アカウント相違

環境変数でモックシナリオを上書きする。

```bash
DAY17_MOCK_SCENARIO=wrong_account \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf

echo $?
```

期待する終了コード:

```text
30
```

期待する主な表示:

```text
MOCK_SCENARIO=wrong_account
Unexpected AWS account: actual=000000000000 expected=445405559057
Script failed due to account mismatch.
```

意味:

```text
想定アカウントIDと実際のCaller Identityが違う。
この状態でS3確認や変更作業を続けてはいけない。
```

現場での報告例:

```text
実行前アカウント確認で想定外アカウントを検出したため、後続処理を停止した。
想定: 445405559057
実際: 000000000000
終了コード: 30
```

## 11. 異常系2: AccessDenied

```bash
DAY17_MOCK_SCENARIO=access_denied \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf

echo $?
```

期待する終了コード:

```text
20
```

期待する主な表示:

```text
MOCK_SCENARIO=access_denied
AWS command failed: operation=get_bucket_policy rc=255
Script failed due to AWS CLI error.
```

最新の証跡ディレクトリを確認する。

```bash
EVIDENCE_DIR=$(
  ls -dt /Users/nobu/aws-reference/evidence/day17_operations_shell/*_s3_security_check \
    | head -n 1
)

cat "$EVIDENCE_DIR/stderr/04_bucket_policy.err"
```

期待する内容:

```text
An error occurred (AccessDenied) when calling the GetBucketPolicy operation: Access Denied
```

意味:

```text
AWS CLI自体の失敗、または権限不足を共通関数が検出した。
元のAWS CLI終了コード255を、そのまま運用ジョブへ返さず、OP_RC_AWS=20へ分類している。
```

## 12. returnとexitを読む

`return`を探す。

```bash
grep -n 'return "\$?\"\|return "\$OP_RC\|return 0\|return [0-9]' \
  bin/s3_security_check.sh \
  lib/aws_api_common_functions.sh
```

`exit`を探す。

```bash
grep -n 'exit ' \
  bin/s3_security_check.sh \
  lib/aws_api_common_functions.sh
```

読み方:

| キーワード | 意味 |
|---|---|
| `return` | 関数から呼び出し元へ戻る |
| `exit` | シェルプロセス全体を終了する |
| `return "$?"` | 直前のコマンドや関数の終了コードを返す |
| `exit "$rc"` | 最終結果をジョブや呼び出し元へ返す |

実案件で重要な点:

```text
共通関数内のreturnは、どの終了コードを上位へ返すかを見る。
実行シェル末尾のexitは、JP1などのジョブ管理が受け取る最終ステータスになり得る。
sourceされる共通関数ファイルにexitがある場合、呼び出し元まで終了する可能性がある。
```

## 13. set -euo pipefailを見る

入口シェルの先頭を確認する。

```bash
sed -n '1,40p' bin/s3_security_check.sh
```

意味:

| 設定 | 意味 |
|---|---|
| `set -e` | コマンド失敗時に原則として終了する |
| `set -u` | 未定義変数をエラーにする |
| `set -o pipefail` | パイプ途中の失敗もパイプ全体の失敗にする |

この教材では、最後に`main`の戻り値を整理するため一時的に`set +e`している。

```bash
grep -n 'set +e\|main\|rc=\$?\|set -e' \
  bin/s3_security_check.sh
```

読み方:

```text
mainを実行する
戻り値をrcへ保存する
rcの値によってエラーメッセージを分ける
最後にexit "$rc"で終了する
```

## 14. AWS CLIを変数に入れる理由を読む

入口シェルでは、表示用に`l_aws_cmd`という変数を作っている。

```bash
grep -n 'l_aws_cmd=' bin/s3_security_check.sh
```

例:

```text
l_aws_cmd="${AWS_CMD} s3api get-bucket-policy --profile ${AWS_PROFILE} --region ${AWS_REGION} --bucket ${TARGET_BUCKET} --query Policy --output text"
```

意味:

```text
実際に何を実行しようとしたかをログへ残すための文字列である。
この教材では、実行そのものは配列風に引数を分けてop_run_awsへ渡している。
```

注意:

```text
文字列のAWSコマンドをevalで実行する方式は危険になりやすい。
引数に空白や特殊文字があると壊れやすく、入力値次第で意図しない実行につながる。
```

## 15. mockとrealの切り替え

既定はmockである。

```bash
grep -n 'RUN_MODE\|MOCK_SCENARIO' \
  conf/s3_security_check.conf \
  bin/s3_security_check.sh \
  lib/aws_api_common_functions.sh
```

mock時:

```text
AWS APIを呼ばない
fixtures配下のJSONやエラーファイルを読む
成功系と異常系を安全に練習できる
```

real時:

```text
実AWS CLIを読み取り専用で呼ぶ
Profile、Region、Bucket、Accountが正しいことを必ず確認する
本番や案件環境では勝手に使わない
```

実AWS読み取り確認を行う場合だけ実行する。

```bash
DAY17_RUN_MODE=real \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf
```

このコマンドは読み取り系のAWS CLIだけを実行する。ただし、実案件や本番アカウントでは、この学習用シェルを使用しない。

## 16. 今日の確認観点

作業後、次の観点で整理する。

| 観点 | 確認内容 |
|---|---|
| 入口 | どのシェルを実行するか |
| 共通関数 | どのファイルをsourceするか |
| conf | Profile、Region、Account、Bucketはどこで決まるか |
| 実行順序 | `main()`から何が呼ばれるか |
| AWS CLI | どの関数がAWS CLIを包んでいるか |
| 証跡 | stdout、stderr、run.log、summaryはどこに出るか |
| 正常終了 | 終了コード0の条件は何か |
| 異常終了 | 終了コード20、30の意味は何か |
| 安全性 | 想定外アカウントなら止まるか |
| 現場適用 | 本番環境で勝手に実行しない前提が明確か |

## 17. 作業メモテンプレート

```text
対象:
  scripts/operations_shell_lab/bin/s3_security_check.sh

読み込むファイル:
  scripts/operations_shell_lab/lib/aws_api_common_functions.sh
  scripts/operations_shell_lab/conf/s3_security_check.conf
  scripts/operations_shell_lab/conf/accounts.conf

実行モード:
  mock

対象AWS情報:
  Profile:
  Region:
  Account:
  Bucket:

正常系:
  実行結果:
  終了コード:
  証跡ディレクトリ:

異常系1:
  シナリオ:
  実行結果:
  終了コード:
  判断:

異常系2:
  シナリオ:
  実行結果:
  終了コード:
  判断:

気づき:
  sourceされたファイルも実行されるコードである。
  confの値を見ないと処理対象は分からない。
  AWS CLI失敗時はstderrと終了コードをセットで見る。
```

## 18. Day 17終了条件

次を満たせばDay 17は完了である。

```text
構文確認ができた
実行シェルのsource先を説明できる
confの主要変数を説明できる
共通関数の役割を大まかに説明できる
正常系を実行できた
アカウント相違の異常系を実行できた
AccessDeniedの異常系を実行できた
証跡ディレクトリ内のrun.logとcheck_summary.tsvを確認できた
終了コード0、20、30の意味を説明できる
```

## 要確認事項

- 7月からの案件で、この教材と同じ構成の共通関数シェルが使われるとは限らない。
- 実案件では、現場提供の手順書、conf、実行ユーザー、承認フロー、ジョブ管理方式を優先する。
- `sed`や`awk`でJSONを扱う場合は、簡易確認に留める。厳密なJSON処理が必要な場合は、現場で許可されたパーサを確認する。
