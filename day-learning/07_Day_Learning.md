# Day 7 Learning: CloudTrail・CloudWatch総合調査ドリル

## 学習開始前に実行するスクリプト

Day 7はS3、CloudTrail、CloudWatchを横断確認する実環境ハンズオンである。Day 5で作成した一時TrailとCloudWatch Logs連携を使い、最後に切り戻す。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: Day 5の一時Trailを使用する
CloudTrail -> CloudWatch Logs連携: Day 5の一時連携を使用する
S3 Data Event: 有効化しない
```

Day 5の一時Trailが残っている前提で、状態確認を実行する。一時Trailがない場合は、Day 5の手順に戻って一時TrailとCloudWatch Logs連携を作成してから進める。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh

/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

Metric Filter、Alarmが未設定の場合も、調査結果として記録する。

実行場所と作業対象を確認する。

```bash
cd /Users/nobu/aws-reference/day-learning

aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager

aws s3api head-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --no-cli-pager
```

Day 7終了時に、一時CloudWatch Logs連携を切り戻す。`<timestamp>_enable_cloudwatch_logs`はDay 5で`01_enable_cloudtrail_cloudwatch_logs.sh`が表示したEvidenceディレクトリである。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
  /Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab/<timestamp>_enable_cloudwatch_logs
```

Evidenceディレクトリが分からない場合は、候補だけを確認し、実際にDay 5で成功したディレクトリを指定する。

```bash
ls -dt /Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab/*_enable_cloudwatch_logs
```

一時Trailを後続で使わない場合は削除する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

## 1. 今日の目的

S3 Bucket Policy変更を題材に、CloudTrailで変更履歴を特定し、現在のS3設定、CloudTrail Trail、CloudWatch Logs連携、Metric Filter、CloudWatch Alarmを横断的に確認する。

Day 7では、個別のAWSサービスを確認するだけではなく、次の問いへ一連の証跡を使って回答できる状態を目指す。

```text
誰が、いつ、どのAWSアカウントで、何を変更したか。
変更は成功したか。
現在の設定はどうなっているか。
監査ログと監視設定は機能しているか。
業務影響や追加確認事項はあるか。
```

本ドリルでは調査対象S3バケットの設定変更を実施しない。Day 5で作成した一時CloudTrail連携を使い、既存設定の確認、変更履歴調査、証跡取得、結果整理、Teams報告文作成を行う。

関連資料:

- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [S3 Bucket Policy CLIリファレンス](../docs/references/02_s3_bucket_policy_cli_reference.md)
- [Day 2 S3 Bucket Policy変更・テスト・切り戻し](./02_Day_Learning.md)
- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)
- [Day 4 CloudWatch Logs・Metric Filter・Alarm確認](./04_Day_Learning.md)
- [Day 6 CloudWatch・MFAなしログイン検知ハンズオン](./06_Day_Learning.md)

## 今日の調査シナリオ

次の問い合わせを受けた想定で調査する。

```text
対象S3バケットのBucket Policyが変更されている。

変更履歴、現在設定、Public判定、監査ログ、CloudWatch監視状態を確認し、
影響の有無と追加確認事項を報告してください。

設定変更は行わないでください。
```

## 今日の確認順序

1. AWSアカウント、リージョン、対象バケットを確認する
2. 証跡保存先を準備する
3. 対象バケットの存在と現在設定を確認する
4. CloudTrail Event HistoryからBucket Policy変更履歴を検索する
5. 最新の変更イベント詳細を確認する
6. 実行者、時刻、送信元IP、UserAgent、変更結果を整理する
7. Trail設定と配信状態を確認する
8. CloudTrailからCloudWatch Logsへの連携状況を確認する
9. CloudWatch Logs、Metric Filter、Alarmの既存設定を確認する
10. CloudTrailと現在設定の情報を関連付ける
11. 証跡一覧、調査結果、追加確認事項を整理する
12. Teams報告文を作成する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象バケット | `nobu-terraform-iac-lab-upload` |
| 主な変更イベント | `PutBucketPolicy`、`DeleteBucketPolicy` |
| 主な確認対象 | S3、CloudTrail、CloudWatch Logs、Metric Filter、Alarm |
| 設定変更 | 調査対象S3にはなし。Day 5の一時Trail連携はDay 7終了時に切り戻す |

## 今日実行しない操作

次の操作は設定、監視、通知、業務へ影響するため実行しない。

- Bucket Policyの追加、更新、削除
- Public Access Blockの変更
- 既存CloudTrail Trailの作成、更新、削除
- Event Selectorの変更
- 既存CloudWatch Logs連携の追加、変更、削除
- Log Group、Metric Filter、Alarmの作成、更新、削除
- Alarm Actionの有効化、無効化
- SNS通知テスト
- GuardDutyやSecurity Hub設定の変更
- 証跡取得を目的とした意図的な異常操作

例外として、Day 5で作成した一時CloudWatch Logs連携の確認と切り戻しは実施する。

---

## 2. CloudTrail・CloudWatch・現在設定の関係

CloudTrail、CloudWatch、S3の現在設定は、それぞれ回答できる内容が異なる。

| 確認先 | 回答できること |
|---|---|
| CloudTrail Event History | 誰が、いつ、どのAPIを実行したか |
| CloudTrail Trail | イベントを継続保存・配信する設定があるか |
| Trail Status | S3やCloudWatch Logsへの配信状態・配信エラー |
| CloudWatch Logs | 配信されたイベントを検索・保管できるか |
| Metric Filter | 特定イベントを数値化して検知できるか |
| CloudWatch Alarm | Metricを評価して通知や対応へつなげられるか |
| S3現在設定 | 調査時点でBucket PolicyやPublic判定がどうなっているか |

重要:

```text
CloudTrailの変更イベントは過去の操作を示す。
S3 APIの確認結果は現在の設定を示す。

過去にPutBucketPolicyが成功していても、
その後の変更や切り戻しによって現在のPolicyは異なる可能性がある。
```

## 調査の基本線

```text
変更履歴:
CloudTrail Event History
↓
イベント詳細:
実行者、時刻、API、対象、送信元IP、結果
↓
現在設定:
S3 Bucket Policy、Public判定、Public Access Block
↓
監査・監視:
Trail、Trail Status、CloudWatch Logs、Metric Filter、Alarm
↓
判断:
正常作業、要確認、影響あり、監視改善候補
```

---

## 3. 作業開始条件と中止条件

## 作業開始条件

- 調査対象のAWSアカウント、リージョン、バケット名が明確である
- 調査対象期間または変更日時の目安が分かる
- 読み取り操作のみを行う
- 証跡保存先が準備されている
- 証跡に機密情報が含まれる可能性を理解している

## 作業中止・確認条件

- AWSアカウントまたはリージョンが想定と異なる
- 対象バケット名が不明確である
- 調査対象期間が広すぎて変更イベントを特定できない
- CloudTrailイベントに想定外の実行者や送信元IPが記録されている
- Bucket PolicyがPublicアクセスを許可している可能性がある
- Trailが停止している、または配信エラーがある
- 既存監視設定の変更が必要になった
- 証跡へAccess Key ID、個人情報、機密情報が含まれている

中止・確認条件へ該当した場合は、独断で設定変更せず、調査結果と追加確認事項を報告する。

---

## 4. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET="nobu-terraform-iac-lab-upload"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nBUCKET=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$BUCKET"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID BUCKET
do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

---

## 5. 証跡保存用ディレクトリの作成

```bash
WORK_NAME="cloudtrail_cloudwatch_investigation"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/current" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/cloudwatch" \
  "$EVIDENCE_DIR/report" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 証跡ディレクトリ確認

```bash
find "$EVIDENCE_DIR" \
  -maxdepth 1 \
  -type d \
  -print \
  | sort
```

### 推奨する証跡分類

| ディレクトリ | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、作業対象、確認日時 |
| `current` | 調査時点のS3現在設定 |
| `cloudtrail` | イベント一覧、イベント詳細、Trail設定・状態 |
| `cloudwatch` | Log Group、Metric Filter、Alarm |
| `report` | 調査結果、証跡一覧、Teams報告文 |
| `screenshots` | Webコンソール画面 |

---

## 6. AWSアカウントと対象バケットの確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. AWSアカウント情報を確認する
3. 東京リージョンを選択する
4. Amazon S3を開く
5. 対象バケットが存在することを確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_S3対象バケット確認.png
```

### AWS CLI: Caller Identity

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

### AWS CLI: 想定アカウントとの一致確認

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
  echo "Expected account: $EXPECTED_ACCOUNT_ID"
else
  echo "Account check OK: $ACCOUNT_ID"
fi
```

### AWS CLI: バケット存在確認

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager
```

### 結果の読み方

- `Account`が想定AWSアカウントIDと一致することを確認する
- `Arn`から操作主体を確認する
- `head-bucket`が成功することを確認する
- `BucketRegion`が想定リージョンと一致することを確認する
- 想定外のアカウントの場合は後続調査を中止する

---

## 7. 対象バケットの現在設定確認

変更履歴を調べる前に、調査時点の現在設定を取得する。

## 7.1 Bucket Policy Status

### Webコンソール

1. 対象バケットを開く
2. 「アクセス許可」タブを開く
3. Block Public AccessとBucket Policyを確認する
4. Public表示や警告の有無を確認する

取得するスクリーンショット:

```text
03_S3現在設定_Public判定.png
```

### AWS CLI

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/current/01_bucket_policy_status.json"
```

期待値:

```text
IsPublic: False
```

## 7.2 Bucket-level Public Access Block

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/current/02_bucket_public_access_block.json"
```

期待値:

```text
BlockPublicAcls        True
IgnorePublicAcls       True
BlockPublicPolicy      True
RestrictPublicBuckets  True
```

## 7.3 現在のBucket Policy

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager
```

読みやすく確認する場合は、JSON整形スクリプトへ渡す。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  | ./format_json_awk.sh /dev/stdin
```

証跡保存:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/current/03_bucket_policy_current.json"
```

### 確認ポイント

- `Effect`が`Allow`か`Deny`か
- `Principal`が限定されているか
- `Action`が必要最小限か
- `Resource`が対象バケットとObjectを正しく指定しているか
- `Condition`が意図どおりか
- `aws:SecureTransport`によるHTTP拒否があるか
- クロスアカウント、VPC Endpoint、AWSサービスからのアクセス許可があるか

### 現在設定の判断

```text
IsPublic=False:
AWSによるPublic判定では非Publicである。

Public Access Blockが4項目True:
対象バケット単位の公開防止設定は有効である。

ただし、業務利用者、IAM Role、クロスアカウントアクセス、
VPC Endpoint、サービスプリンシパルへの許可が適切かは別途確認する。
```

---

## 8. CloudTrailでBucket Policy変更履歴を検索する

CloudTrail Event Historyから、対象バケットに対する変更イベントを検索する。

## 8.1 Webコンソール

1. CloudTrailコンソールを開く
2. 「イベント履歴」を開く
3. 検索属性で「リソース名」を選択する
4. 対象バケット名を入力する
5. 対象期間を絞る
6. `PutBucketPolicy`と`DeleteBucketPolicy`を確認する

取得するスクリーンショット:

```text
04_CloudTrail_BucketPolicy変更イベント一覧.png
```

## 8.2 AWS CLI: 変更イベント一覧

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/01_bucket_policy_change_events.json"
```

### 確認ポイント

| 項目 | 確認内容 |
|---|---|
| `EventTime` | 変更日時。JSTとUTCの違いに注意する |
| `EventName` | `PutBucketPolicy`または`DeleteBucketPolicy` |
| `Username` | 操作者の概要 |
| `EventId` | イベント詳細を一意に特定するID |

### 注意点

- `lookup-events`で確認できるEvent Historyは直近90日間である
- Management Eventを検索する機能であり、長期保存のTrailとは用途が異なる
- `PutBucketPolicy`は新規作成と更新の両方で記録される
- `PutBucketPolicy`だけでは、承認済み変更か不正変更かを判断できない

---

## 9. 最新の変更イベントを特定する

最新の`PutBucketPolicy`イベントを調査対象とする。

```bash
EVENT_ID=$(aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy`] | [0].EventId' \
  --output text \
  --no-cli-pager)

echo "EVENT_ID=$EVENT_ID"
```

### Event ID必須チェック

```bash
if [ "$EVENT_ID" = "None" ] || [ -z "$EVENT_ID" ]; then
  echo "ERROR: PutBucketPolicy event was not found."
else
  echo "PutBucketPolicy event found: $EVENT_ID"
fi
```

### 最新イベントの要約表示

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager
```

取得するスクリーンショット:

```text
05_CloudTrail_最新PutBucketPolicyイベント.png
```

---

## 10. CloudTrailイベント詳細を確認する

イベント詳細から、実行者、変更対象、送信元、結果を確認する。

## 10.1 生イベントを証跡として保存する

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/02_put_bucket_policy_event_raw.json"
```

生イベントは一行JSONになる場合がある。完全な証跡として保存し、目視確認には次の要約コマンドを使用する。

## 10.2 読みやすいイベント要約

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,EventSource:EventSource,Username:Username,ReadOnly:ReadOnly,EventId:EventId}' \
  --output json \
  --no-cli-pager
```

## 10.3 生イベントを整形して確認する

生イベントを整形し、入れ子構造を維持したまま確認する。

```bash
./format_json_awk.sh \
  "$EVIDENCE_DIR/cloudtrail/02_put_bucket_policy_event_raw.json" \
  "$EVIDENCE_DIR/cloudtrail/03_put_bucket_policy_event_formatted.json"

cat \
  "$EVIDENCE_DIR/cloudtrail/03_put_bucket_policy_event_formatted.json"
```

確認するJSONパス:

```text
eventTime
eventName
eventSource
awsRegion
userIdentity.arn
sourceIPAddress
userAgent
requestParameters.bucketName
requestParameters.bucketPolicy
tlsDetails.tlsVersion
errorCode
errorMessage
```

`errorCode`と`errorMessage`が存在しない場合、CloudTrailイベントにはAPIエラーが記録されていない可能性が高い。ただし、変更後設定と対象システムの動作確認を組み合わせて成功を判断する。

## 10.4 確認する主要フィールド

| フィールド | 意味 | 調査観点 |
|---|---|---|
| `eventTime` | API実行時刻 | 作業予定時間内か |
| `userIdentity.type` | 認証主体の種類 | IAMUser、AssumedRole、AWSServiceなど |
| `userIdentity.arn` | 実行者ARN | 承認済み操作者・Roleか |
| `eventName` | 実行API | `PutBucketPolicy`か |
| `sourceIPAddress` | 送信元IP | 想定ネットワーク・端末か |
| `userAgent` | 実行クライアント | Webコンソール、AWS CLI、SDKなど |
| `requestParameters.bucketName` | 対象バケット | 調査対象と一致するか |
| `requestParameters.bucketPolicy` | 設定したPolicy | 承認済み内容と一致するか |
| `errorCode` | APIエラーコード | 値がある場合は失敗原因を確認する |
| `errorMessage` | APIエラー詳細 | 権限・Policy・条件を確認する |
| `readOnly` | 読み取り操作か | 設定変更では通常`false` |

## 10.5 UserAgentの読み方

| UserAgent例 | 想定される操作方法 |
|---|---|
| `aws-cli/...` | AWS CLIによる操作 |
| ブラウザ情報、`console.amazonaws.com`関連 | AWS Webコンソール操作の可能性 |
| `Boto3/...`、SDK名 | プログラムや自動処理 |
| `cloudformation.amazonaws.com` | CloudFormationによる操作 |
| AWSサービス名 | AWSサービスによる操作 |

UserAgentだけで正当性を断定しない。作業申請、操作者、時刻、変更内容、送信元IPと合わせて判断する。

---

## 11. CloudTrail Trail設定を確認する

Event Historyで変更イベントを検索できても、Trailによる長期保存やCloudWatch Logs連携が設定済みとは限らない。

## 11.1 Webコンソール

1. CloudTrailコンソールを開く
2. 「証跡」を開く
3. Trailの有無と状態を確認する
4. Multi-Region設定を確認する
5. 保存先S3バケットを確認する
6. CloudWatch Logs連携を確認する

取得するスクリーンショット:

```text
06_CloudTrail_Trail設定.png
```

## 11.2 AWS CLI: Trail一覧

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,MultiRegion:IsMultiRegionTrail,LoggingS3Bucket:S3BucketName,LogFileValidation:LogFileValidationEnabled,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/03_describe_trails.json"
```

### 確認ポイント

- Trailが存在するか
- `HomeRegion`がどこか
- `IsMultiRegionTrail`が要件どおりか
- `S3BucketName`が設定されているか
- `LogFileValidationEnabled`が要件どおりか
- `CloudWatchLogsLogGroupArn`が設定されているか
- `CloudWatchLogsRoleArn`が設定されているか

## 11.3 Trail Status

Trail名を確認後、対象Trailの状態を確認する。

```bash
TRAIL_NAME="<trail-name>"
```

`describe-trails`で確認した`HomeRegion`が`REGION`と異なる場合は、以降のTrail確認コマンドでHome Regionを指定する。Shadow TrailやOrganization Trailが表示された場合は、管理アカウントと操作権限も確認する。

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/04_trail_status.json"
```

### 確認ポイント

| 項目 | 確認内容 |
|---|---|
| `IsLogging` | Trailがログ記録中か |
| `LatestDeliveryTime` | S3への最新配信時刻 |
| `LatestDeliveryError` | S3への最新配信エラー |
| `LatestCloudWatchLogsDeliveryTime` | CloudWatch Logsへの最新配信時刻 |
| `LatestCloudWatchLogsDeliveryError` | CloudWatch Logsへの最新配信エラー |

値が空の場合は、該当連携が未設定である可能性と、直近配信がない可能性を切り分ける。

---

## 12. Event Selectorを確認する

Trailが記録するイベント種別を確認する。

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/05_event_selectors.json"
```

### 確認ポイント

- Management Eventを記録しているか
- Read Event、Write Eventの対象範囲
- S3 Object-level Data Eventを記録しているか
- 対象バケットがData Eventの記録対象か
- Advanced Event Selectorを使用しているか

重要:

```text
PutBucketPolicyはManagement Eventである。
GetObject、PutObject、DeleteObjectなどはS3 Data Eventである。

Bucket Policy変更履歴を確認できても、
Objectアクセス履歴を記録しているとは限らない。
```

---

## 13. CloudTrailからCloudWatch Logsへの連携確認

CloudTrailイベントをCloudWatch Logsで検索・検知するには、TrailからCloudWatch Logsへの配信設定が必要である。

### AWS CLI: 連携情報だけを確認する

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --query 'trailList[].{Name:Name,HomeRegion:HomeRegion,CloudWatchLogsLogGroupArn:CloudWatchLogsLogGroupArn,CloudWatchLogsRoleArn:CloudWatchLogsRoleArn}' \
  --output json \
  --no-cli-pager
```

### 結果の読み方

```text
CloudWatchLogsLogGroupArnあり:
CloudTrailからCloudWatch Logsへの連携設定がある。

CloudWatchLogsRoleArnあり:
CloudTrailがCloudWatch Logsへ配信するIAM Roleが設定されている。

値がNoneまたは空:
CloudWatch Logs連携は未設定である可能性が高い。
Event HistoryやS3 Trail保存が利用できないという意味ではない。
```

### 影響調査が必要な変更

CloudWatch Logs連携を追加・変更する場合は、次を確認する。

- 既存Trailの利用者と管理責任者
- 配信先Log Groupの命名規則
- CloudTrail配信用IAM Role
- Log Group Retention
- KMS暗号化要件
- CloudWatch Logs取り込み・保存料金
- 既存SIEMや監視製品との重複
- Metric FilterとAlarmへの影響
- 切り戻し方法

---

## 14. CloudWatch Logsの既存設定を確認する

## 14.1 Webコンソール

1. CloudWatchコンソールを開く
2. 「ロググループ」を開く
3. CloudTrail連携先Log Groupの有無を確認する
4. Retention、KMS、Metric Filterを確認する

取得するスクリーンショット:

```text
07_CloudWatch_Log_Group一覧.png
08_CloudTrail連携先Log_Group設定.png
```

## 14.2 Log Group一覧

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'logGroups[].{LogGroupName:logGroupName,RetentionDays:retentionInDays,KmsKeyId:kmsKeyId,StoredBytes:storedBytes}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/01_log_groups.json"
```

### 確認ポイント

- CloudTrail連携先Log Groupが存在するか
- Retentionが設定されているか
- KMSカスタマー管理キーが必要か
- 想定外に保存容量が増えていないか
- 命名規則とタグが要件どおりか

`KmsKeyId`が空でも、CloudWatch Logsの標準暗号化は適用される。カスタマー管理KMSキーが関連付けられていない状態を示す。

---

## 15. Metric Filterを確認する

Metric Filterは、CloudWatch Logs内の特定イベントをCustom Metricへ変換する。

### Webコンソール

1. CloudTrail連携先Log Groupを開く
2. Metric Filter一覧を開く
3. S3 Policy変更やセキュリティ変更を検知するFilterの有無を確認する
4. Filter Pattern、Metric Namespace、Metric Nameを確認する

取得するスクリーンショット:

```text
09_CloudWatch_Metric_Filter一覧.png
```

### AWS CLI: 全Log GroupのMetric Filter一覧

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'metricFilters[].{FilterName:filterName,LogGroupName:logGroupName,FilterPattern:filterPattern}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/02_metric_filters.json"
```

### 確認ポイント

- `PutBucketPolicy`を検知するFilterがあるか
- `DeleteBucketPolicy`を検知するFilterがあるか
- CloudTrail停止や削除操作を検知するFilterがあるか
- Filter Patternが広すぎず、狭すぎないか
- Metric NamespaceとMetric Nameが命名規則どおりか
- Filterが存在してもAlarmへ接続されているとは限らない

### 検知設計例

次は設計例であり、Day 7では作成しない。

```text
CloudTrail Event:
eventSource = s3.amazonaws.com
eventName   = PutBucketPolicy または DeleteBucketPolicy

Metric Filter:
上記イベントをCustom Metricへ変換

CloudWatch Alarm:
一定期間内に1件以上発生した場合にALARM

通知:
SNS、メール、Teams、運用監視など
```

---

## 16. CloudWatch Alarmを確認する

### Webコンソール

1. CloudWatchの「アラーム」を開く
2. Alarm一覧を確認する
3. S3、CloudTrail、セキュリティ変更に関連するAlarmを確認する
4. 状態、しきい値、Actionを確認する

取得するスクリーンショット:

```text
10_CloudWatch_Alarm一覧.png
```

### AWS CLI

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,ActionsEnabled:ActionsEnabled,Namespace:Namespace,MetricName:MetricName}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudwatch/03_alarms.json"
```

### 確認ポイント

- 対象Metricを監視するAlarmが存在するか
- `StateValue`が`OK`、`ALARM`、`INSUFFICIENT_DATA`のどれか
- `ActionsEnabled`が要件どおりか
- Alarm Actionの通知先が正しいか
- しきい値、評価期間、Missing Dataの扱いが適切か
- 同目的の重複Alarmがないか

### 状態の読み方

| 状態 | 意味 |
|---|---|
| `OK` | Alarm条件を満たしていない |
| `ALARM` | Alarm条件を満たしている |
| `INSUFFICIENT_DATA` | 評価に必要なデータが不足している |

`OK`は監視対象に問題がないことを保証しない。Metric Filter、ログ配信、通知Actionが正しく機能していることも確認する。

---

## 17. CloudWatch Logsで対象イベントを検索する

CloudTrail連携先Log Groupがある場合のみ実施する。

### Webコンソール

1. CloudWatch Logs Insightsを開く
2. CloudTrail連携先Log Groupを選択する
3. 対象期間を変更時刻周辺へ絞る
4. `PutBucketPolicy`を検索する
5. Event ID、実行者、送信元IPをCloudTrail Event Historyと照合する

取得するスクリーンショット:

```text
11_CloudWatch_Logs_Insights_PutBucketPolicy検索.png
```

### Logs Insightsクエリ例

```text
fields @timestamp, eventName, userIdentity.arn, sourceIPAddress,
       requestParameters.bucketName, errorCode, errorMessage
| filter eventSource = "s3.amazonaws.com"
| filter eventName in ["PutBucketPolicy", "DeleteBucketPolicy"]
| filter requestParameters.bucketName = "nobu-terraform-iac-lab-upload"
| sort @timestamp desc
| limit 50
```

### AWS CLIでクエリを開始する例

`<cloudtrail-log-group-name>`、`<start-epoch-seconds>`、`<end-epoch-seconds>`を実環境に合わせて指定する。

```bash
aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "<cloudtrail-log-group-name>" \
  --start-time <start-epoch-seconds> \
  --end-time <end-epoch-seconds> \
  --query-string 'fields @timestamp, eventName, userIdentity.arn, sourceIPAddress, requestParameters.bucketName, errorCode | filter eventName in ["PutBucketPolicy", "DeleteBucketPolicy"] | sort @timestamp desc | limit 50' \
  --output json \
  --no-cli-pager
```

Day 7では、CloudTrail連携先Log Groupがない場合や、対象期間を正確に指定できない場合は無理に実行しない。

### 確認ポイント

- CloudTrail Event Historyと同じイベントが検索できるか
- Event ID、時刻、実行者が一致するか
- ログ配信の遅延がないか
- エラーイベントがないか
- Metric Filterの対象条件と一致するか

---

## 18. CloudTrail変更履歴と現在設定を関連付ける

調査結果は、過去の変更履歴と現在設定を分けて整理する。

### 整理例

| 観点 | 確認結果 |
|---|---|
| 最新変更API | `PutBucketPolicy` |
| 変更日時 | `<event-time>` |
| 実行者 | `<user-or-role-arn>` |
| 送信元IP | `<source-ip>` |
| 実行方法 | AWS CLI / Webコンソール / SDK |
| APIエラー | なし / あり |
| 現在のBucket Policy | `<summary>` |
| 現在のPublic判定 | `IsPublic=False` |
| Public Access Block | 4項目True |
| Trail | 記録中 / 未設定 / 要確認 |
| CloudWatch Logs連携 | あり / なし / 要確認 |
| Metric Filter | あり / なし / 要確認 |
| Alarm | あり / なし / 要確認 |

### 判断時の注意

- CloudTrailにエラーがないことだけでアプリケーション影響なしとは判断しない
- `IsPublic=False`だけで最小権限とは判断しない
- Public Access Blockが有効でも、意図した業務アクセスが許可されているか確認する
- CloudWatch Logs連携が未設定でも、TrailのS3保存が有効な場合がある
- Metric FilterやAlarmがないことが直ちに不備とは限らない
- 監視要件、SIEM、Security Hub、GuardDutyとの役割分担を確認する

---

## 19. 証跡を確認する

### 証跡ファイル一覧

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -print \
  | sort
```

### 空ファイル確認

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -size 0 \
  -print \
  | sort
```

### 証跡ファイル数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

### 証跡確認ポイント

- Caller Identityが保存されている
- 現在のS3設定が保存されている
- CloudTrailイベント一覧と生イベントが保存されている
- Trail設定とTrail Statusが保存されている
- CloudWatch Logs、Metric Filter、Alarm一覧が保存されている
- スクリーンショット名が手順書と一致している
- 空ファイルがある場合は理由を確認している
- 公開前にアカウントID、ARN、IPアドレス、Access Key IDを確認している

---

## 20. 推奨するスクリーンショット証跡

| No. | ファイル名 | 画面 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント確認 |
| 02 | `02_S3対象バケット確認.png` | 対象バケット |
| 03 | `03_S3現在設定_Public判定.png` | Permissions、Public Access Block、Policy |
| 04 | `04_CloudTrail_BucketPolicy変更イベント一覧.png` | Event History |
| 05 | `05_CloudTrail_最新PutBucketPolicyイベント.png` | イベント詳細 |
| 06 | `06_CloudTrail_Trail設定.png` | Trail設定 |
| 07 | `07_CloudWatch_Log_Group一覧.png` | Log Group一覧 |
| 08 | `08_CloudTrail連携先Log_Group設定.png` | Retention、KMS、Metric Filter |
| 09 | `09_CloudWatch_Metric_Filter一覧.png` | Metric Filter |
| 10 | `10_CloudWatch_Alarm一覧.png` | Alarm一覧 |
| 11 | `11_CloudWatch_Logs_Insights_PutBucketPolicy検索.png` | Logs Insights検索結果 |

スクリーンショットには、対象アカウント、リージョン、リソース名、設定値、確認日時を可能な範囲で含める。

---

## 21. 調査結果テンプレート

```text
作業名:
S3 Bucket Policy変更履歴・監視状態調査

対象AWSアカウント:
<account-id>

対象リージョン:
<region>

対象バケット:
<bucket-name>

調査日時:
<yyyy-mm-dd hh:mm JST>

設定変更:
なし

最新変更イベント:
EventName:
EventTime:
EventId:
実行者ARN:
送信元IP:
UserAgent:
APIエラー:

現在設定:
Bucket Policy:
IsPublic:
Public Access Block:

CloudTrail:
Trail:
IsLogging:
S3保存先:
CloudWatch Logs連携:
配信エラー:

CloudWatch:
Log Group:
Metric Filter:
Alarm:
Alarm Action:

判断:
正常作業 / 要確認 / 影響あり / 判断保留

追加確認事項:
<作業申請、アプリ影響、監視要件など>

証跡保存先:
<evidence-path>
```

---

## 22. Teams報告例

### 調査開始報告

```text
対象S3バケットのBucket Policy変更履歴および監視状態の確認を開始する。

対象:
AWSアカウント <account-id>
リージョン <region>
バケット <bucket-name>

確認内容:
- CloudTrail変更履歴
- 現在のBucket PolicyとPublic判定
- TrailとCloudWatch Logs連携
- Metric FilterとAlarm

設定変更は実施しない。
```

### 問題が確認されなかった場合

```text
対象S3バケットのBucket Policy変更履歴および監視状態を確認した。

最新のPutBucketPolicyイベント:
- 実行日時: <event-time>
- 実行者: <user-or-role>
- 送信元IP: <source-ip>
- APIエラー: なし

現在設定:
- IsPublic: False
- Bucket-level Public Access Block: 4項目すべて有効
- Bucket Policy: <summary>

CloudTrailおよびCloudWatchの設定状況を確認し、
現時点で緊急対応が必要な問題は確認されなかった。

設定変更は実施していない。
証跡は <evidence-path> に保存した。
```

### 追加確認が必要な場合

```text
対象S3バケットのBucket Policy変更履歴を確認した。

現在のPublic判定はFalseであり、Bucket-level Public Access Blockは有効である。
一方、次の項目は要件確認が必要である。

- <CloudWatch Logs連携が未設定>
- <Metric FilterまたはAlarmが未設定>
- <変更イベントの実行者・送信元IPの確認>
- <Bucket Policyの業務アクセス影響確認>

設定変更は実施していない。
対応要否と監視要件を確認後、必要に応じて変更手順を作成する。
```

### 想定外の変更を確認した場合

```text
対象S3バケットに対する想定外のBucket Policy変更イベントを確認した。

イベント:
- EventName: <event-name>
- EventTime: <event-time>
- 実行者: <user-or-role>
- 送信元IP: <source-ip>

現在設定とPublic判定を確認中である。
独断で切り戻しは実施せず、作業申請・操作者・影響範囲を確認する。
必要に応じて、セキュリティ担当およびシステム担当へエスカレーションする。
```

---

## 23. よくある問題と切り分け

## CloudTrailイベントが見つからない

確認すること:

- リージョンが正しいか
- ResourceNameが正しいか
- Event Historyの90日間を超えていないか
- `PutBucketPolicy`以外のイベント名ではないか
- TrailのS3ログやCloudTrail Lakeへ長期保存されていないか
- 別アカウントや委任管理アカウントで操作されていないか

## TrailはあるがCloudWatch Logs連携がない

確認すること:

- CloudWatch Logs連携が要件上必要か
- S3 Trail保存やSIEMで監視していないか
- 既存監視との重複がないか
- 連携追加時のIAM Role、Log Group、料金、Retention

## CloudWatch Logsにイベントが見つからない

確認すること:

- TrailからCloudWatch Logsへ連携されているか
- Log Group名が正しいか
- 対象期間が正しいか
- ログ配信に遅延やエラーがないか
- Trail Statusの`LatestCloudWatchLogsDeliveryError`

## AlarmがOKだがログがない

確認すること:

- Metric Filterが正しいLog Groupに設定されているか
- Filter Patternがイベントへ一致するか
- Custom MetricにDatapointがあるか
- Missing Dataの扱いが適切か
- Alarm Actionが有効か

## Bucket Policyが読めない

確認すること:

- Policyが未設定ではないか
- IAM権限が不足していないか
- 対象バケットと所有アカウントが正しいか
- `--expected-bucket-owner`が正しいか

---

## 24. 影響調査が必要な改善候補

Day 7は確認専用であり、次の項目を見つけても即時変更しない。

| 改善候補 | 主な影響範囲 |
|---|---|
| CloudTrail Trail追加・変更 | 全AWS API監査、ログ保存、料金 |
| Multi-Region Trail有効化 | 全リージョン、ログ量、重複Trail |
| S3 Data Event有効化 | Objectアクセス監査、料金、ログ量 |
| CloudWatch Logs連携追加 | IAM Role、Log Group、料金、既存SIEM |
| Log Group Retention変更 | 保持期間、監査要件、料金 |
| KMSカスタマー管理キー関連付け | KMS Policy、復号権限、配信障害 |
| Metric Filter追加 | Custom Metric、検知ノイズ、料金 |
| Alarm追加・変更 | 通知先、当番運用、誤検知 |
| Bucket Policy変更 | アプリ、バッチ、クロスアカウント、VPC Endpoint |

改善候補を見つけた場合は、要件、影響範囲、テスト方法、切り戻し方法、承認者を整理してから変更手順を作成する。

---

## 25. セキュリティ上の注意点

- CloudTrailイベントにはAccess Key ID、IPアドレス、ユーザー名、ARNが含まれる場合がある
- `requestParameters`にはPolicyや設定内容が含まれる
- 証跡ファイルを公開リポジトリへ保存しない
- 証跡を共有する場合は、機密情報と個人情報を確認する
- 想定外の変更を確認しても、独断で切り戻さない
- Public設定やTrail停止を確認した場合は早めに報告する
- CloudTrailログ削除、Trail停止、Alarm無効化などの操作履歴を優先的に確認する
- 正常な承認済み作業と不正操作を、CloudTrailイベントだけで断定しない

---

## 26. 案件で説明できるポイント

### 変更履歴と現在設定を分けて確認する

```text
CloudTrailでPutBucketPolicyの実行者、時刻、送信元IP、
UserAgent、エラー有無を確認した。

その後、S3 APIで現在のBucket Policy、Public判定、
Public Access Blockを確認し、過去の変更履歴と現在設定を分けて整理した。
```

### Event HistoryとTrailの違い

```text
CloudTrail Event Historyで直近のManagement Eventを検索できることと、
TrailでS3やCloudWatch Logsへ継続配信していることは別である。

Trail設定、Trail Status、Event Selector、CloudWatch Logs連携を個別に確認した。
```

### 検知設定の確認

```text
CloudWatch Logsへイベントが配信されているか確認したうえで、
Metric FilterとCloudWatch Alarmの既存設定を確認した。

AlarmがOKであることだけではなく、ログ配信、Filter Pattern、
Custom Metric、Alarm Actionが機能する構成か確認する必要がある。
```

### 報告と変更判断

```text
調査結果を、確認済み事項、判断、追加確認事項、証跡保存先に分けて報告した。

監視改善候補があっても、影響範囲と既存運用を確認せず即時変更しない。
```

---

## 27. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| CloudTrail Event History | 直近90日間のManagement Event検索 |
| CloudTrail Trail | イベントをS3やCloudWatch Logsへ継続配信 |
| Management Event | Bucket Policy変更などリソース設定操作 |
| Data Event | S3 Objectアクセスなど高頻度イベント |
| Event Selector | Trailが記録するイベント種別を制御 |
| Trail Status | ログ記録状態と配信エラー確認 |
| CloudWatch Logs | ログ保存、検索、Metric Filterの入力 |
| Metric Filter | ログイベントをCustom Metricへ変換 |
| CloudWatch Alarm | Metricを評価して状態変更・通知 |
| S3 Public Access Block | Publicアクセスを制限する保護設定 |
| Bucket Policy Status | AWSによるPublic判定 |

---

## 28. 要確認事項

実案件で同様の調査を行う場合は、次を確認する。

- 正式な対象AWSアカウント、リージョン、バケット名
- 調査対象期間と変更申請番号
- 承認済みの変更内容と実施者
- Webコンソール、AWS CLI、共通シェルなど実際の操作方式
- Organization Trail、Multi-Region Trail、Account Trailの管理方式
- CloudTrailログの保存先と保持期間
- CloudTrail Lake、SIEM、Security Hubとの役割分担
- CloudWatch Logs連携先と配信用IAM Role
- Metric Filter、Alarm、通知先の命名・運用規則
- 証跡の保存先、命名規則、マスキング規則
- 想定外の変更を確認した場合のエスカレーション先

不明な項目は合理的に推測して設定変更せず、未確認事項として手順書と報告へ残す。

---

## 29. Day 7完了チェックリスト

- [ ] AWSアカウント、リージョン、対象バケットを確認した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] 対象バケットの存在を確認した
- [ ] 現在のBucket Policy Statusを確認した
- [ ] Bucket-level Public Access Blockを確認した
- [ ] 現在のBucket Policyを確認した
- [ ] CloudTrailでBucket Policy変更イベント一覧を確認した
- [ ] 最新の`PutBucketPolicy` Event IDを特定した
- [ ] CloudTrail生イベントを証跡として保存した
- [ ] 実行者、時刻、送信元IP、UserAgent、エラー有無を確認した
- [ ] Trail設定を確認した
- [ ] Trail Statusと配信エラーを確認した
- [ ] Event Selectorを確認した
- [ ] CloudWatch Logs連携状況を確認した
- [ ] Log Group一覧を確認した
- [ ] Metric Filter一覧を確認した
- [ ] CloudWatch Alarm一覧を確認した
- [ ] 変更履歴と現在設定を分けて整理した
- [ ] 改善候補の影響範囲を整理した
- [ ] 証跡ファイルと空ファイルを確認した
- [ ] Teams報告文を作成した
- [ ] 設定変更を実施していないことを確認した

## Day 7の完了条件

次を自分の言葉で説明できればDay 7は完了とする。

```text
CloudTrail Event Historyを使用して、対象S3バケットに対する
Bucket Policy変更履歴を検索し、最新イベントの実行者、時刻、
送信元IP、UserAgent、エラー有無を確認する。

CloudTrailの過去イベントだけで判断せず、
S3 APIで現在のBucket Policy、Public判定、Public Access Blockを確認する。

Trail設定、Trail Status、Event Selector、CloudWatch Logs連携、
Metric Filter、Alarmを確認し、監査と検知の状態を整理する。

調査結果は、確認済み事項、判断、追加確認事項、証跡保存先に分けて報告する。
設定変更が必要な場合は、影響調査と承認後に別手順として実施する。
```
