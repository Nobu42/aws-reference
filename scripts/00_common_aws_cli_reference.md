# 00 共通 AWS CLI・証跡保存リファレンス

## 1. このドキュメントの目的

このドキュメントは、AWSの設定調査、設定変更、テスト、切り戻し、手順書作成で共通して使うAWS CLIの基本操作を整理したリファレンスである。

個別サービスのコマンドを実行する前に、以下を安全かつ再現可能な形で行うことを目的とする。

1. 操作対象のAWSアカウント、IAM主体、リージョンを確認する
2. AWS CLIのProfile、設定、バージョンを確認する
3. 読み取り系コマンドで変更前状態を取得する
4. CLI結果を証跡ファイルとして保存する
5. 変更前後の差分を確認する
6. エラー出力と終了コードを記録する
7. 秘密情報や個人情報を証跡へ残さない
8. BashとPowerShellのどちらでも作業できるようにする

銀行系システムのように、変更内容だけでなく「誰が、いつ、どの環境で、何を確認し、何を変更し、どのような結果になったか」を説明できることが重要な環境を想定する。

## 2. 想定する利用場面

このリファレンスは、以下のような作業で利用する。

- S3バケットポリシーの変更前後確認
- CloudTrailとCloudWatch Logsの連携設定
- GuardDuty Findingの確認
- MFAなし管理コンソールログインの検知設定
- VPC、Route Table、Security Group、NACLの設定確認
- EC2、RDS、Lambdaのセキュリティ設定確認
- AWS設定変更手順書の作成
- 作業証跡、テスト結果、切り戻し結果の保存
- Teamsやレビュー会議での作業結果説明

## 3. このリファレンスの位置づけ

今後作成するサービス別リファレンスでは、AWS CLIの共通操作をこのドキュメントへ集約する。

```text
00_common_aws_cli_reference.md
  ├─ アカウント、Profile、Region確認
  ├─ --query、--output、--filters
  ├─ 証跡保存、差分確認、終了コード
  └─ 秘密情報、エラー、トラブル対応

01_s3_security_cli_reference.md
02_s3_bucket_policy_cli_reference.md
03_cloudtrail_cli_reference.md
04_cloudwatch_cli_reference.md
05_guardduty_cli_reference.md
...
```

## 4. 最初に覚える基本方針

AWS設定変更作業では、次の順番を基本とする。

```text
対象確認
  ↓
変更前確認
  ↓
変更前証跡保存
  ↓
変更内容と差分確認
  ↓
設定変更
  ↓
変更後確認
  ↓
変更後証跡保存
  ↓
動作テスト
  ↓
CloudTrailなどの監査証跡確認
  ↓
作業結果報告
```

重要な考え方:

- 変更系コマンドより先に、読み取り系コマンドを実行する
- 手順書には、コマンドだけでなく期待結果を書く
- 変更前後で同じ確認コマンドを使う
- CLIの標準出力とエラー出力を分けて保存する
- 証跡用JSONへエラーメッセージを混ぜない
- AWSコンソールの画面だけでなく、CLI結果も保存する
- CloudTrailで変更イベントを確認できるようにする
- 異常時に戻せる設定値を変更前に取得する

## 5. コマンドの危険度を意識する

AWS CLIコマンドは、操作名からおおよその危険度を判断できる。

| 分類 | よく使う操作名 | 主な用途 |
| :--- | :--- | :--- |
| 読み取り系 | `describe`、`get`、`list`、`lookup`、`head` | 現状確認、証跡取得 |
| 作成・変更系 | `create`、`put`、`update`、`modify`、`associate`、`attach`、`authorize`、`enable` | 設定変更 |
| 削除・無効化系 | `delete`、`remove`、`detach`、`disassociate`、`revoke`、`disable`、`terminate` | 切り戻し、削除 |

ただし、操作名だけで安全性を断定してはいけない。

例:

- `get-secret-value` は読み取り系だが、秘密情報を取得する
- `get-function-configuration` はLambda環境変数を含む場合がある
- `describe-instance-attribute --attribute userData` は機密情報を含む場合がある
- `head-bucket` は出力がなくても、終了コードでアクセス可否を判断する
- `put-*` は既存設定を上書きすることがある

実行前に、必ず `help` またはAWS CLI Command Referenceで動作を確認する。

## 6. AWS CLIコマンドの基本構造

AWS CLIの基本形は以下である。

```bash
aws <service> <operation> [options]
```

例:

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket example-bucket \
  --output json
```

| 要素 | 例 | 意味 |
| :--- | :--- | :--- |
| `aws` | `aws` | AWS CLI本体 |
| `<service>` | `s3api` | 操作対象サービス |
| `<operation>` | `get-bucket-policy` | 実行するAPI操作 |
| `[options]` | `--bucket example-bucket` | 対象リソース、出力形式、検索条件など |

## 7. 作業前の共通変数

### 7.1 Bash

Linux、macOS、Git Bashなどでは、以下のように変数を定義する。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
```

コマンドでは変数をダブルクォートで囲む。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

### 7.2 PowerShell

Windows PowerShellでは、以下のように変数を定義する。

```powershell
$Profile = "learning"
$Region = "ap-northeast-1"
$ExpectedAccountId = "445405559057"
```

```powershell
aws sts get-caller-identity `
  --profile $Profile `
  --output table
```

### 7.3 手順書ではProfileとRegionを明示する

AWS CLIはProfileや環境変数に設定されたデフォルト値を利用できる。

しかし、設定変更手順書では、操作対象を明確にするため、原則として以下をコマンドへ明示する。

```text
--profile <profile-name>
--region <region-name>
```

例:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

IAM、Route 53、CloudFrontなど、グローバルに扱われるサービスもある。

一方、CloudTrail、CloudWatch、GuardDuty、EC2、RDS、Lambdaなどはリージョンの取り違えに注意する。

## 8. 作業前に必ず行う確認

### 8.1 AWS CLIバージョン確認

```bash
aws --version
```

確認ポイント:

- AWS CLI v1かv2か
- 手順書作成時と実行時で大きくバージョンが異ならないか
- コマンドやオプションが利用可能なバージョンか

AWS CLI v1とv2では、出力ページャー、利用可能な出力形式、オプションなどが異なる場合がある。

証跡例:

```bash
aws --version > aws_cli_version.txt 2>&1
```

PowerShell:

```powershell
aws --version *> aws_cli_version.txt
```

### 8.2 設定済みProfile一覧確認

```bash
aws configure list-profiles
```

確認ポイント:

- 利用予定のProfileが存在すること
- 本番、開発、検証など、似た名前のProfileを取り違えていないこと

### 8.3 Profile設定確認

```bash
aws configure list \
  --profile "$PROFILE"
```

確認ポイント:

- `profile` が想定どおりであること
- `region` が想定どおりであること
- 認証情報の取得元が想定どおりであること

注意:

- 認証情報の取得元や設定ファイルの場所が表示される
- 画面キャプチャや証跡保存を行う場合は、現場の情報管理ルールを確認する
- Access Key、Secret Access Key、Session Tokenを意図的に表示・保存してはいけない

### 8.4 操作アカウントとIAM主体確認

最も重要な確認コマンドである。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

主な出力項目:

| 項目 | 意味 |
| :--- | :--- |
| `Account` | AWSアカウントID |
| `Arn` | 実行主体のIAMユーザー、IAMロール、Assumed RoleなどのARN |
| `UserId` | 実行主体の一意なID |

確認ポイント:

- `Account` が作業対象アカウントIDと一致すること
- `Arn` が作業用IAMユーザーまたは作業用ロールであること
- 本番、検証、開発アカウントを取り違えていないこと
- 想定外のAssumed Roleになっていないこと

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > 00_caller_identity.json
```

PowerShell:

```powershell
aws sts get-caller-identity `
  --profile $Profile `
  --output json `
  > 00_caller_identity.json
```

### 8.5 期待するAWSアカウントIDとの照合

#### Bash

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "Error: Unexpected AWS Account ID."
  echo "Expected: $EXPECTED_ACCOUNT_ID"
  echo "Actual  : $ACCOUNT_ID"
  exit 1
fi

echo "AWS Account ID is correct: $ACCOUNT_ID"
```

#### PowerShell

```powershell
$AccountId = aws sts get-caller-identity `
  --profile $Profile `
  --query "Account" `
  --output text

if ($AccountId -ne $ExpectedAccountId) {
  Write-Error "Unexpected AWS Account ID. Expected=$ExpectedAccountId Actual=$AccountId"
  exit 1
}

Write-Host "AWS Account ID is correct: $AccountId"
```

### 8.6 対象リージョン確認

Profileに設定されたリージョンを確認する。

```bash
aws configure get region \
  --profile "$PROFILE"
```

指定したリージョンが、アカウントで利用可能か確認する。

```bash
aws ec2 describe-regions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --region-names "$REGION" \
  --query 'Regions[*].{RegionName:RegionName,OptInStatus:OptInStatus}' \
  --output table
```

確認ポイント:

- 手順書の対象リージョンと一致すること
- 東京リージョンを想定している場合、`ap-northeast-1` であること
- Opt-inが必要なリージョンを誤って指定していないこと

## 9. 環境変数とエンドポイントの確認

### 9.1 設定値の優先順位

AWS CLIでは、一般に以下の順で設定値が優先される。

```text
コマンドラインオプション
  ↓
環境変数
  ↓
Profile設定
```

例:

- `--profile` は `AWS_PROFILE` より優先される
- `--region` は環境変数やProfileのRegion設定より優先される
- `--output` は `AWS_DEFAULT_OUTPUT` やProfileのOutput設定より優先される

### 9.2 よく確認する環境変数

| 環境変数 | 用途 | 注意点 |
| :--- | :--- | :--- |
| `AWS_PROFILE` | 使用Profile | 想定外Profileの原因になる |
| `AWS_REGION` | 使用Region | `AWS_DEFAULT_REGION` やProfileより優先される |
| `AWS_DEFAULT_REGION` | デフォルトRegion | リージョン取り違えに注意 |
| `AWS_DEFAULT_OUTPUT` | デフォルト出力形式 | 手順書の出力形式と異なる原因になる |
| `AWS_PAGER` | 出力ページャー | コマンドが止まったように見える原因になる |
| `AWS_ENDPOINT_URL` | カスタムエンドポイント | 実AWSではなく別環境へ接続する原因になる |
| `AWS_CA_BUNDLE` | CA証明書バンドル | 組織内プロキシ環境では意図的に設定される場合がある |

注意:

```text
env | grep AWS
```

のようなコマンドは、Access Key、Secret Access Key、Session Tokenを表示する可能性がある。

証跡取得や画面共有中には実行しない。

### 9.3 Bashで個別に確認する

```bash
printf 'AWS_PROFILE=%s\n' "${AWS_PROFILE:-<unset>}"
printf 'AWS_REGION=%s\n' "${AWS_REGION:-<unset>}"
printf 'AWS_DEFAULT_REGION=%s\n' "${AWS_DEFAULT_REGION:-<unset>}"
printf 'AWS_DEFAULT_OUTPUT=%s\n' "${AWS_DEFAULT_OUTPUT:-<unset>}"
printf 'AWS_PAGER=%s\n' "${AWS_PAGER:-<unset>}"
printf 'AWS_ENDPOINT_URL=%s\n' "${AWS_ENDPOINT_URL:-<unset>}"
```

### 9.4 PowerShellで個別に確認する

```powershell
Write-Host "AWS_PROFILE=$Env:AWS_PROFILE"
Write-Host "AWS_REGION=$Env:AWS_REGION"
Write-Host "AWS_DEFAULT_REGION=$Env:AWS_DEFAULT_REGION"
Write-Host "AWS_DEFAULT_OUTPUT=$Env:AWS_DEFAULT_OUTPUT"
Write-Host "AWS_PAGER=$Env:AWS_PAGER"
Write-Host "AWS_ENDPOINT_URL=$Env:AWS_ENDPOINT_URL"
```

### 9.5 LocalStackなどの設定が残っている場合

このリポジトリでは、LocalStack用のAliasや環境変数が残っている場合に、実AWSではなく別エンドポイントへ接続する可能性がある。

Bash:

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

注意:

- 実案件では、カスタムエンドポイントや社内プロキシ設定が意図的に使われている可能性がある
- 理由を確認せずに環境変数を解除しない
- `AWS_ENDPOINT_URL_<SERVICE>` のようなサービス別エンドポイント設定も存在する
- 接続先が不明な場合は、管理者や手順書作成者へ確認する

## 10. AWS CLIのヘルプを使う

### 10.1 AWS CLI全体のヘルプ

```bash
aws help
```

### 10.2 サービスのヘルプ

```bash
aws s3api help
```

### 10.3 操作のヘルプ

```bash
aws s3api get-bucket-policy help
```

確認できる内容:

- コマンドの説明
- 必須パラメータ
- 任意パラメータ
- 入力形式
- 出力形式
- 使用例

貸与PCや開発環境から外部インターネットへ接続できない場合でも、AWS CLIの組み込みヘルプが利用できる可能性がある。

## 11. よく使う共通オプション

| オプション | 用途 | 主な注意点 |
| :--- | :--- | :--- |
| `--profile` | 使用するProfileを指定 | アカウント取り違え防止のため明示する |
| `--region` | 使用するリージョンを指定 | リージョナルサービスでは明示する |
| `--query` | JMESPathで出力を絞り込む | クライアント側フィルタリング |
| `--output` | 出力形式を指定 | 証跡は原則JSON |
| `--filters` | API側で対象を絞り込む | サービスごとに構文が異なる |
| `--no-cli-pager` | 外部ページャーを無効化 | 証跡保存やスクリプトで有効 |
| `--no-paginate` | 自動ページネーションを無効化 | 最初のページしか取得しない可能性がある |
| `--page-size` | API呼び出しごとの取得件数を調整 | タイムアウト時の調整に使う |
| `--max-items` | CLI出力件数を制限 | 全件証跡には使わない |
| `--cli-connect-timeout` | 接続タイムアウトを指定 | ネットワーク障害調査で使用 |
| `--cli-read-timeout` | 読み取りタイムアウトを指定 | 大きな応答の調査で使用 |
| `--debug` | 詳細なデバッグログを表示 | 機密情報を含む可能性がある |

## 12. 出力形式の使い分け

AWS CLIでは、主に以下の出力形式を使う。

| 出力形式 | 用途 | 特徴 |
| :--- | :--- | :--- |
| `json` | 証跡保存、差分確認、後続処理 | 構造を保持し、再利用しやすい |
| `table` | 人が画面で確認 | 見やすいが、機械処理には向かない |
| `text` | IDやARNの取得、シェル変数への代入 | `--query` と組み合わせる |
| `yaml` | 人が読む設定確認 | 環境やAWS CLIバージョンに注意 |
| `off` | 標準出力を抑止し終了コードだけ確認 | エラーは標準エラーへ出力される |

### 12.1 人が画面で確認する場合

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

### 12.2 証跡として保存する場合

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > 00_caller_identity.json
```

### 12.3 IDやARNを変数へ代入する場合

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)
```

### 12.4 存在確認で終了コードだけ使う場合

```bash
if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --output off 2>/dev/null; then
  echo "Bucket exists and is accessible."
else
  echo "Bucket does not exist or is not accessible."
fi
```

### 12.5 `--output text` の注意点

`--output text` は、列の順番やページネーションの影響を受ける場合がある。

値を取得する場合は、原則として `--query` を併用する。

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[*].[VpcId,CidrBlock,IsDefault]' \
  --output text
```

証跡保存や複雑な差分確認には、`--output json` を使う。

## 13. `--query` とJMESPath

`--query` は、AWS CLIが受け取った応答をクライアント側で絞り込む機能である。

### 13.1 特定項目を取得する

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text
```

### 13.2 一覧から必要な項目だけ表示する

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,IsDefault:IsDefault}' \
  --output table
```

### 13.3 Nameタグを表示する

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name}' \
  --output table
```

### 13.4 最初の要素を取得する

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[0].VpcId' \
  --output text)
```

注意:

- 対象が複数存在する場合、`[0]` で最初の要素だけを取得すると誤参照につながる
- 本番作業では、リソースが一意であることを別途確認する
- `None` や空文字を取得した場合は、後続処理を止める

### 13.5 `None` と空文字を検知する

```bash
get_required_value() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found."
    exit 1
  fi

  echo "$value"
}
```

使用例:

```bash
VPC_ID=$(get_required_value "VPC" "$VPC_ID")
```

## 14. `--filters` と `--query` の違い

| 項目 | `--filters` | `--query` |
| :--- | :--- | :--- |
| 処理場所 | AWSサービス側 | AWS CLIクライアント側 |
| 主な目的 | APIから返す対象を絞る | 返された応答を整形・抽出する |
| 利点 | 大量データの転送を減らせる | 表示形式を柔軟に変更できる |
| 注意点 | サービスごとに指定方法が異なる | 応答取得後に処理される |

両方を組み合わせる例:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters \
    Name=instance-state-name,Values=running \
    Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,PrivateIp:PrivateIpAddress}' \
  --output table
```

基本方針:

- 対象リソースを減らす場合は `--filters`
- 表示項目を整える場合は `--query`
- 大量データでは、先にサーバー側フィルタリングを行う

## 15. ページネーションとページャー

### 15.1 自動ページネーション

一覧系コマンドでは、AWS CLIが複数回APIを呼び出し、全件を取得する場合がある。

証跡として全件を保存したい場合、安易に `--no-paginate` や `--max-items` を指定しない。

```text
--no-paginate
```

を指定すると、最初のページしか取得しない可能性がある。

### 15.2 大量データでタイムアウトする場合

```bash
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --page-size 100 \
  --output json
```

`--page-size` は、API呼び出しごとの取得件数を小さくする。

最終的な全件取得を維持しながら、個々のAPI呼び出しのタイムアウトを避けたい場合に使う。

### 15.3 AWS CLI v2の出力ページャー

AWS CLI v2では、出力がページャーへ渡される場合がある。

証跡保存やスクリプト実行では、ページャーを無効化すると扱いやすい。

コマンド単位:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --no-cli-pager \
  --output table
```

Bashセッション単位:

```bash
export AWS_PAGER=""
```

PowerShellセッション単位:

```powershell
$Env:AWS_PAGER = ""
```

## 16. JSONや設定ファイルを安全に渡す

### 16.1 長いJSONをコマンドラインへ直接書かない

Bucket PolicyやIAM Policyのような長いJSONは、コマンドラインへ直接記述すると以下の問題が起きやすい。

- 引用符のエスケープミス
- BashとPowerShellで構文が変わる
- 履歴へ設定値が残る
- レビュー時に差分を確認しづらい
- 手順書からコピーした際に全角文字が混ざる

JSONファイルを作成し、`file://` で渡す方法を優先する。

```bash
aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --policy file://bucket-policy.json
```

### 16.2 `file://` と `fileb://`

| 指定 | 用途 |
| :--- | :--- |
| `file://` | テキスト、JSONなどをファイルから読み込む |
| `fileb://` | バイナリデータをファイルから読み込む |

通常のPolicy JSONでは `file://` を使う。

### 16.3 JSONの構文確認

利用可能なツールに応じて、JSON構文を確認する。

Pythonが利用可能な場合:

```bash
python3 -m json.tool bucket-policy.json > /dev/null
```

PowerShell:

```powershell
Get-Content .\bucket-policy.json -Raw | ConvertFrom-Json | Out-Null
```

エラーが出ないことを確認してから、変更系コマンドを実行する。

### 16.4 `--generate-cli-skeleton` の注意点

コマンド入力の雛形確認に使える場合がある。

```bash
aws s3api put-bucket-policy \
  --generate-cli-skeleton input
```

ただし、生成されるJSON SkeletonはAWS CLIバージョン間で安定性が保証されない。

レビュー済み手順書や長期保管する設定ファイルの正解として、そのまま依存しない。

## 17. BashとPowerShellの引用符

AWS CLIへJSON、JMESPath、空白を含む文字列を渡す場合、シェルごとの引用符ルールに注意する。

### 17.1 Bash

JMESPathはシングルクォートで囲むことが多い。

```bash
aws ec2 describe-vpcs \
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock}' \
  --output table
```

### 17.2 PowerShell

PowerShellでもJMESPathをシングルクォートで囲める。

```powershell
aws ec2 describe-vpcs `
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock}' `
  --output table
```

### 17.3 JSONはファイルで渡す

BashとPowerShellで引用符の挙動が異なるため、JSONパラメータは `file://` を優先する。

```text
手順書に巨大なJSON文字列を直接書く
```

よりも、

```text
レビュー済みJSONファイルを配置し、file://で読み込む
```

方が安全である。

## 18. 証跡保存ディレクトリ

### 18.1 推奨ディレクトリ構成

作業単位で証跡ディレクトリを分ける。

```text
evidence/
└─ 20260603_090000_s3_bucket_policy_change/
   ├─ 00_metadata/
   ├─ before/
   ├─ change/
   ├─ after/
   ├─ rollback/
   └─ screenshots/
```

| ディレクトリ | 保存する内容 |
| :--- | :--- |
| `00_metadata` | Caller Identity、AWS CLIバージョン、作業情報 |
| `before` | 変更前設定、変更前状態 |
| `change` | 変更用JSON、実行ログ、差分 |
| `after` | 変更後設定、テスト結果、CloudTrailイベント |
| `rollback` | 切り戻し実施時の結果 |
| `screenshots` | AWSコンソール、アプリ画面などの画像証跡 |

### 18.2 Bashで作成する

```bash
WORK_NAME="s3_bucket_policy_change"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"

echo "$EVIDENCE_DIR"
```

### 18.3 PowerShellで作成する

```powershell
$WorkName = "s3_bucket_policy_change"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$EvidenceDir = "evidence\${Timestamp}_${WorkName}"

New-Item -ItemType Directory -Force -Path `
  "$EvidenceDir\00_metadata", `
  "$EvidenceDir\before", `
  "$EvidenceDir\change", `
  "$EvidenceDir\after", `
  "$EvidenceDir\rollback", `
  "$EvidenceDir\screenshots" | Out-Null

Write-Host $EvidenceDir
```

### 18.4 証跡ファイル名の例

```text
00_caller_identity.json
01_bucket_location.json
02_public_access_block_before.json
03_bucket_policy_before.json
04_bucket_policy_after.json
05_bucket_policy_diff.txt
06_application_test_result.txt
07_cloudtrail_put_bucket_policy.json
```

ファイル名は、手順書の作業No.と対応させると確認しやすい。

## 19. 作業メタデータを保存する

### 19.1 Bash

```bash
aws --version \
  > "$EVIDENCE_DIR/00_metadata/aws_cli_version.txt" 2>&1

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"

date '+%Y-%m-%dT%H:%M:%S%z' \
  > "$EVIDENCE_DIR/00_metadata/local_start_time.txt"

date -u '+%Y-%m-%dT%H:%M:%SZ' \
  > "$EVIDENCE_DIR/00_metadata/utc_start_time.txt"
```

### 19.2 PowerShell

```powershell
aws --version *> "$EvidenceDir\00_metadata\aws_cli_version.txt"

aws sts get-caller-identity `
  --profile $Profile `
  --output json `
  > "$EvidenceDir\00_metadata\00_caller_identity.json"

Get-Date -Format "o" `
  > "$EvidenceDir\00_metadata\local_start_time.txt"

(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
  > "$EvidenceDir\00_metadata\utc_start_time.txt"
```

CloudTrailなどのJSONではUTC時刻が表示される場合がある。

作業時刻を説明しやすくするため、ローカル時刻とUTC時刻の両方を意識する。

## 20. 標準出力と標準エラーを分けて保存する

### 20.1 なぜ分けるのか

AWS CLIの正常なJSON出力とエラーメッセージを同じファイルへ保存すると、JSONとして利用できなくなる。

```text
stdout: 正常なコマンド結果
stderr: エラーメッセージ
```

証跡用JSONへ `2>&1` でエラーを混ぜない。

### 20.2 Bash

```bash
if aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --output json \
  > "$EVIDENCE_DIR/before/02_public_access_block.json" \
  2> "$EVIDENCE_DIR/before/02_public_access_block_error.log"; then
  echo "Command succeeded."
else
  echo "Command failed."
  exit 1
fi
```

### 20.3 PowerShell

```powershell
aws s3api get-public-access-block `
  --profile $Profile `
  --region $Region `
  --bucket example-bucket `
  --output json `
  1> "$EvidenceDir\before\02_public_access_block.json" `
  2> "$EvidenceDir\before\02_public_access_block_error.log"

if ($LASTEXITCODE -ne 0) {
  Write-Error "Command failed."
  exit 1
}
```

## 21. 終了コードを確認する

AWS CLIは、コマンドの成否を終了コードで返す。

### 21.1 Bash

```bash
echo $?
```

### 21.2 PowerShell

```powershell
echo $LASTEXITCODE
```

### 21.3 主な終了コード

| 終了コード | 主な意味 |
| :--- | :--- |
| `0` | 正常終了 |
| `1` | S3転送処理の一部失敗 |
| `2` | コマンド解析失敗、またはS3転送対象の一部スキップ |
| `130` | `Ctrl+C` などによる中断 |
| `252` | 構文、パラメータ、値が不正 |
| `253` | 認証情報や設定など、実行環境が不正 |
| `254` | AWSサービスがエラーを返した |
| `255` | AWS CLIまたはAWSサービスによる失敗 |

注意:

- エラーメッセージだけでなく終了コードも確認する
- `head-bucket` のように出力がないコマンドでは、終了コードが重要になる
- `set -e` を使うシェルスクリプトでは、エラー時に即座に終了することを理解する

## 22. 変更前後の差分確認

### 22.1 基本方針

変更前後で同じコマンドを実行し、同じ出力形式で保存する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/before/03_bucket_policy_before.json"
```

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/after/03_bucket_policy_after.json"
```

### 22.2 Bashの `diff`

```bash
diff -u \
  "$EVIDENCE_DIR/before/03_bucket_policy_before.json" \
  "$EVIDENCE_DIR/after/03_bucket_policy_after.json" \
  > "$EVIDENCE_DIR/change/03_bucket_policy_diff.txt"
```

`diff` は差分がある場合に終了コード `1` を返す。

設定変更後に差分があること自体は正常なため、シェルスクリプト内では終了コードの扱いに注意する。

```bash
diff -u before.json after.json > difference.txt || true
```

### 22.3 PowerShellの `Compare-Object`

```powershell
Compare-Object `
  (Get-Content "$EvidenceDir\before\03_bucket_policy_before.json") `
  (Get-Content "$EvidenceDir\after\03_bucket_policy_after.json") `
  > "$EvidenceDir\change\03_bucket_policy_diff.txt"
```

### 22.4 GUIの差分ツール

貸与PCやVDIでは、WinMergeなどの承認済み差分ツールが利用できる場合がある。

差分ツールを使う場合も、以下を確認する。

- 左側が変更前、右側が変更後であること
- 文字コードや改行コードの違いだけではないこと
- 想定したStatement、設定値、ルールだけが変更されていること
- 差分画面のスクリーンショットを証跡として保存すること
- 設定値に秘密情報や個人情報が含まれていないこと

### 22.5 JSON差分の注意点

JSONでは、意味が同じでも以下の違いで差分が大きく見える場合がある。

- インデント
- 改行
- キーの順番
- 配列要素の順番

可能であれば、比較前にJSONを整形する。

Python:

```bash
python3 -m json.tool before.json > before_formatted.json
python3 -m json.tool after.json > after_formatted.json
diff -u before_formatted.json after_formatted.json
```

`jq` が承認済みで利用可能な場合:

```bash
jq -S . before.json > before_sorted.json
jq -S . after.json > after_sorted.json
diff -u before_sorted.json after_sorted.json
```

`jq` は便利だが、貸与PCや開発環境に導入されている前提にしない。

## 23. 証跡ファイルのハッシュ値

証跡ファイルが後から変更されていないことを確認したい場合、SHA-256ハッシュ値を保存する。

### 23.1 macOS

```bash
shasum -a 256 "$EVIDENCE_DIR/after/03_bucket_policy_after.json"
```

### 23.2 Linux

```bash
sha256sum "$EVIDENCE_DIR/after/03_bucket_policy_after.json"
```

### 23.3 PowerShell

```powershell
Get-FileHash `
  "$EvidenceDir\after\03_bucket_policy_after.json" `
  -Algorithm SHA256
```

実案件でハッシュ値が必要かは、証跡管理ルールや手順書テンプレートに従う。

## 24. 証跡の種類と役割

| 証跡 | 得意なこと | 注意点 |
| :--- | :--- | :--- |
| AWSコンソールのスクリーンショット | 人が見て状態を理解しやすい | 画面外の設定値を確認できない場合がある |
| AWS CLIのJSON出力 | 設定値を正確に保存しやすい | 機密情報を含む可能性がある |
| 差分ファイル | 変更箇所を説明しやすい | 整形差分に注意する |
| CloudTrailイベント | 誰が、いつ、何を変更したか確認できる | 反映まで時間がかかる場合がある |
| アプリケーションテスト結果 | 実際の利用影響を確認できる | 操作条件と期待結果を明記する |

案件では、次の組み合わせが説明しやすい。

```text
スクリーンショット: 人が見やすい状態証跡
CLI JSON          : 設定値を正確に残す証跡
CloudTrail        : 変更操作の監査証跡
テスト結果        : 業務・アプリケーション影響の確認証跡
```

## 25. スクリーンショット証跡の注意点

AWSコンソールのスクリーンショットを取得する場合、以下を確認する。

- 対象AWSアカウントやリージョンが分かること
- 対象リソース名が分かること
- 変更前か変更後か分かるファイル名にすること
- 必要な設定値が画面内に表示されていること
- unrelatedな個人情報や別案件情報が映っていないこと
- Access Key、Secret、Session Token、パスワードを映さないこと
- 画像編集やマスキングのルールを確認すること

ファイル名例:

```text
Evidence_001_BucketPolicy_Before.png
Evidence_002_BucketPolicy_After.png
Evidence_003_Application_Upload_Success.png
Evidence_004_CloudTrail_PutBucketPolicy.png
```

## 26. 証跡へ保存してはいけない情報

以下は、原則として証跡、Git、Teams、手順書へ保存しない。

- AWS Access Key ID
- AWS Secret Access Key
- AWS Session Token
- DBパスワード
- SMTPパスワード
- Secrets ManagerのSecret値
- SSM Parameter StoreのSecureString値
- KMSで復号した平文
- 顧客データ、個人情報、機微情報
- S3オブジェクト本文
- メール本文
- 認証Cookie、CSRF Token、API Token
- 秘密情報を含む可能性があるLambda環境変数
- 秘密情報を含む可能性があるEC2 UserData

また、以下にも注意する。

- `--debug` の出力
- シェルの `history`
- `env` や `set` による環境変数一覧
- 画面共有中のターミナル
- スクリーンショットの背景
- Gitへ追加する前の証跡ファイル

## 27. `--debug` の利用注意

`--debug` は、AWS CLIの詳細な処理を確認するために利用できる。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket example-bucket \
  --debug
```

利用場面:

- 認証情報の解決元を確認したい
- 接続先エンドポイントを確認したい
- リクエストがどの段階で失敗しているか確認したい

注意:

- 詳細ログには、内部情報や機密情報が含まれる可能性がある
- そのままTeams、メール、Gitへ貼り付けない
- 保存する場合は、現場ルールに従って内容を確認・マスキングする
- 通常の作業証跡として常用しない

## 28. `--no-verify-ssl` を安易に使わない

SSL証明書検証エラーが発生しても、以下を安易に使用しない。

```text
--no-verify-ssl
```

このオプションは、AWS CLIのSSL証明書検証を無効化する。

社内プロキシ、CA証明書、VDI環境の設定に問題がある可能性があるため、管理者へ確認する。

必要に応じて、承認済みのCA証明書バンドルや `AWS_CA_BUNDLE` の設定を確認する。

## 29. `--dry-run` の注意点

一部のEC2系コマンドなどでは、`--dry-run` を利用できる。

```bash
aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id sg-xxxxxxxxxxxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.0.0/8 \
  --dry-run
```

注意:

- すべてのAWS CLIコマンドで利用できるわけではない
- 権限がある場合でも `DryRunOperation` というエラー応答になることがある
- `--dry-run` が変更内容の妥当性や業務影響を保証するわけではない
- 実行可否は、各コマンドのヘルプで確認する

## 30. よくあるエラーと確認ポイント

### 30.1 Profileが見つからない

```text
The config profile (...) could not be found
```

確認:

```bash
aws configure list-profiles
```

確認ポイント:

- Profile名のスペル
- 貸与PCと開発環境で設定ファイルが異ならないか
- 実行ユーザーのホームディレクトリが正しいか

### 30.2 認証情報が見つからない

```text
Unable to locate credentials
```

確認ポイント:

- Profileの認証情報設定
- IAM Identity Centerのログイン状態
- EC2 IAM Roleの関連付け
- 一時認証情報の有効期限

### 30.3 一時認証情報が期限切れ

```text
ExpiredToken
```

確認ポイント:

- IAM Identity CenterやAssumeRoleのセッション有効期限
- AWS Session Tokenの有効期限
- 再ログインや再認証が必要か

### 30.4 権限不足

```text
AccessDenied
UnauthorizedOperation
```

確認ポイント:

- 実行主体のARN
- IAM Policy
- Permission Boundary
- Service Control Policy
- Resource-based Policy
- KMS Key Policy
- VPC Endpoint Policy

権限不足を解消するために、過剰な権限を安易に追加しない。

### 30.5 リソースが見つからない

```text
ResourceNotFound
NoSuchBucket
DBInstanceNotFound
```

確認ポイント:

- AWSアカウント
- リージョン
- リソース名、ID、ARN
- リソースが削除済みではないか
- 大文字、小文字、末尾のピリオドなど

### 30.6 エンドポイントへ接続できない

```text
Could not connect to the endpoint URL
```

確認ポイント:

- リージョン
- インターネット接続
- プロキシ
- DNS
- Firewall
- `AWS_ENDPOINT_URL`
- サービス別カスタムエンドポイント

### 30.7 コマンドが止まったように見える

確認ポイント:

- AWS CLI v2のページャーが開いていないか
- `q` でページャーを終了できるか
- `--no-cli-pager` を指定したか
- API応答が大きくないか
- タイムアウトしていないか

### 30.8 JSONや引用符のエラー

確認ポイント:

- BashとPowerShellの引用符の違い
- JSONのカンマ、ダブルクォート、波括弧
- 全角スペース、全角引用符が混ざっていないか
- `file://` でJSONファイルを渡せないか

## 31. 変更作業の共通チェックリスト

### 31.1 作業前

- [ ] 作業対象AWSアカウントIDを確認した
- [ ] 実行主体のIAMユーザーまたはIAMロールを確認した
- [ ] 対象リージョンを確認した
- [ ] 対象リソース名、ID、ARNを確認した
- [ ] 変更前設定をJSONで保存した
- [ ] 変更前のAWSコンソール画面を必要に応じて保存した
- [ ] 変更内容の差分を確認した
- [ ] 切り戻しに必要な変更前設定を保存した
- [ ] 変更用JSONの構文を確認した
- [ ] 作業承認と作業時間を確認した

### 31.2 作業中

- [ ] コマンドのProfileとRegionを再確認した
- [ ] 変更対象リソースが手順書と一致している
- [ ] コマンドの終了コードを確認した
- [ ] エラー出力を確認した
- [ ] 想定外の設定を上書きしていない
- [ ] 追加作業が必要になった場合、独断で手順外作業を行っていない

### 31.3 作業後

- [ ] 変更後設定をJSONで保存した
- [ ] 変更前後の差分が想定どおりである
- [ ] セキュリティ設定が弱くなっていない
- [ ] アプリケーションや業務の動作確認を行った
- [ ] CloudTrailなどで変更イベントを確認した
- [ ] 必要なスクリーンショットを保存した
- [ ] 切り戻し不要であることを確認した
- [ ] 作業結果を関係者へ共有した

## 32. 手順書へ記載するコマンドのテンプレート

サービス別リファレンスや作業手順書では、以下の形式で整理すると確認しやすい。

````markdown
### 手順No. 1: 対象設定を確認する

目的:

- 変更前の設定値を確認する
- 切り戻しに利用できる証跡を保存する

操作分類:

- 読み取り系

対象:

- AWS Account: `<account-id>`
- Region: `<region>`
- Resource: `<resource-name-or-arn>`

実行コマンド:

```bash
aws <service> <operation> \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/<file-name>.json"
```

期待結果:

- `<expected-value>` であること

証跡:

- `<file-name>.json`

異常時:

- 作業を中断し、対象アカウント、リージョン、権限、リソース名を確認する
````

## 33. 作業開始時の共通コマンド例

### 33.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
WORK_NAME="aws_setting_change"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

export AWS_PAGER=""

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"

aws --version \
  > "$EVIDENCE_DIR/00_metadata/aws_cli_version.txt" 2>&1

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "Error: Unexpected AWS Account ID."
  exit 1
fi

echo "Ready: $EVIDENCE_DIR"
```

### 33.2 PowerShell

```powershell
$Profile = "learning"
$Region = "ap-northeast-1"
$ExpectedAccountId = "445405559057"
$WorkName = "aws_setting_change"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$EvidenceDir = "evidence\${Timestamp}_${WorkName}"

$Env:AWS_PAGER = ""

New-Item -ItemType Directory -Force -Path `
  "$EvidenceDir\00_metadata", `
  "$EvidenceDir\before", `
  "$EvidenceDir\change", `
  "$EvidenceDir\after", `
  "$EvidenceDir\rollback", `
  "$EvidenceDir\screenshots" | Out-Null

aws --version *> "$EvidenceDir\00_metadata\aws_cli_version.txt"

aws sts get-caller-identity `
  --profile $Profile `
  --output json `
  > "$EvidenceDir\00_metadata\00_caller_identity.json"

$AccountId = aws sts get-caller-identity `
  --profile $Profile `
  --query "Account" `
  --output text

if ($AccountId -ne $ExpectedAccountId) {
  Write-Error "Unexpected AWS Account ID."
  exit 1
}

Write-Host "Ready: $EvidenceDir"
```

## 34. 貸与PC・VDI・開発環境での注意点

金融系案件では、貸与PC、VDI、開発環境、橋渡し環境が分かれている場合がある。

最初に以下を確認する。

- AWS CLIが利用可能か
- AWS CLIのバージョン
- Bash、PowerShell、Command Promptのどれを使うか
- 利用可能なテキストエディタ
- WinMergeなどの差分ツールが利用可能か
- JSON整形ツールが利用可能か
- ファイル持ち込み、持ち出し方法
- クリップボードの利用可否
- スクリーンショット取得方法
- 証跡ファイルの保存先
- GitHubや外部サイトへの接続可否
- AWSコンソールとAWS CLIのどちらで変更するか

手順書は、特定のエディタや追加ツールがなくても実行できる形を基本とする。

```text
必須:
  AWS CLI
  BashまたはPowerShell
  承認済みテキストエディタ

任意:
  WinMerge
  jq
  Vim
  VS Code
```

## 35. 実務での説明例

### 35.1 作業開始時

```text
作業対象アカウント、リージョン、実行主体を確認しました。
変更前設定をCLIのJSON出力とAWSコンソール画面で取得し、
切り戻しに必要な設定値を保存してから変更作業を開始します。
```

### 35.2 変更完了時

```text
設定変更は正常終了しました。
変更前後の差分は想定した設定項目のみであることを確認しています。
変更後の設定値、アプリケーション動作、CloudTrailイベントを確認し、
証跡ファイルを保存しました。
```

### 35.3 異常時

```text
変更後確認で想定外の結果を確認したため、追加作業は行わず中断しました。
変更前に取得した設定値を用いて切り戻し可能な状態です。
対象設定、エラー内容、影響範囲を整理して関係者へ共有します。
```

## 36. 今後のサービス別リファレンスで扱う内容

この共通リファレンスを前提として、以下をサービス別に整理する。

| リファレンス | 主な内容 |
| :--- | :--- |
| S3セキュリティ | Public Access Block、ACL、暗号化、ログ、バージョニング |
| S3バケットポリシー | Policy取得、Public判定、変更、差分、切り戻し |
| CloudTrail | Trail、Event Data Store、イベント検索、ログ配送 |
| CloudWatch | Log Group、Metric Filter、Alarm、ログ検索 |
| MFAなしログイン検知 | CloudTrail、CloudWatch Logs、Metric Filter、Alarm |
| GuardDuty | Detector、Finding、Severity、サンプルFinding |
| VPCネットワーク | VPC、Subnet、Route Table、Security Group、NACL |
| EC2セキュリティ | IAM Role、IMDSv2、EBS暗号化、Security Group |
| RDSセキュリティ | Public設定、暗号化、ログ、バックアップ |
| Lambdaセキュリティ | IAM Role、VPC、環境変数、ログ、Function URL |

## 37. 公式ドキュメント

- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Configuring settings for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
- [Configuration and credential file settings in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [Configuring environment variables for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
- [Controlling command output in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output.html)
- [Setting the output format in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-output-format.html)
- [Filtering output in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html)
- [Using the pagination options in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-pagination.html)
- [Using quotation marks and literals with strings in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-parameters-quoting-strings.html)
- [Accessing help and resources for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-help.html)
- [Command line return codes in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-returncodes.html)
- [list-profiles - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/configure/list-profiles.html)
- [get-caller-identity - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html)
