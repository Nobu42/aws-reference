# 10-Day Condensed Learning: AWS案件対策濃縮版

## 使い方

この文書は、Day 1からDay 26までを全部なぞる時間がない場合の10日間濃縮版である。

説明は最小限にする。分からない用語や出力が出たら、その場でデュークへ質問する。

```text
目的:
  AWS環境まわりの設定確認、設定変更、証跡取得、影響確認、報告に慣れる

捨てるもの:
  重複説明
  低頻度サービスの深掘り
  EventBridgeなど補足サービスの作成実習
  使わないサービスの網羅

残すもの:
  S3
  Bucket Policy
  CloudTrail
  CloudWatch Logs / Metric Filter / Alarm
  GuardDuty Finding読解
  VPC / SG / NACL / Endpoint
  KMS / SSE-KMS
  共通シェル / conf読解
  証跡 / 手順書 / 報告
```

## 毎日の進め方

```text
1. 今日の対象Dayを開く
2. コマンドを実行する
3. 結果を証跡へ保存する
4. 「何を確認したか」を1行で言う
5. 分からない出力はその場で質問する
6. 後片付けを行う
```

質問するときは、次の形で投げる。

```text
この出力のどこを見ればよい？
この結果は正常？
現場なら次に何を確認する？
このコマンドは何を確認している？
この差分は問題ない？
```

## 毎日共通の作業場所

```bash
cd /Users/nobu/aws-reference/day-learning

export AWS_PAGER=""

PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET="nobu-terraform-iac-lab-upload"
TRAIL_NAME="nobu-iac-lab-trail"
FORMAT_JSON_AWK="/Users/nobu/aws-reference/day-learning/format_json_awk.sh"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager
```

## 起動と後片付け

日次ラボ環境が必要な日だけ実行する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh

read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

Ansible前にSSH設定を確認する。

```bash
grep -n "awsref" ~/.ssh/config
```

後片付けは、使ったものだけ実行する。

```bash
/Users/nobu/aws-reference/day-learning/restore_and_cleanup_all.sh

/Users/nobu/aws-reference/scripts/cleanup_network.sh

/Users/nobu/aws-reference/scripts/check_cleanup.sh

/Users/nobu/aws-reference/scripts/check_cost.sh
```

## 10日間の全体像

| Day | 重点 | 元Day |
|---|---|---|
| 1 | S3設定棚卸 | Day 1 |
| 2 | S3 Bucket Policy変更・切り戻し | Day 2 |
| 3 | CloudTrailで変更履歴を追う | Day 3、Day 7 |
| 4 | CloudWatch Logs / Metric Filter / Alarm | Day 4、Day 5、Day 6 |
| 5 | GuardDuty Findingを読む | Day 8、Day 9 |
| 6 | VPC / Route / Endpoint / Flow Logs | Day 10、Day 14 |
| 7 | Security Group / NACL / 通信要件 | Day 11、Day 12、Day 13 |
| 8 | KMS / SSE-KMS / EC2・RDS最低限 | Day 15、Day 18、Day 26 |
| 9 | 共通関数シェル / conf / 証跡 | Day 17、Day 19 |
| 10 | 現場指示型総合演習 | Day 20、Day 21、Day 24、Day 26 |

---

## Day 1: S3設定棚卸

元資料:

- [01_Day_Learning.md](./01_Day_Learning.md)
- [01_s3_security_cli_reference.md](../docs/references/01_s3_security_cli_reference.md)

やること:

```text
S3 Bucketが存在するか
Public Access Block
Bucket Policy Status
Ownership Controls
ACL
Encryption
Versioning
Logging
CORS
```

最低成果物:

```text
対象Bucketのセキュリティ設定を説明できる
Publicかどうかを判断できる
ACLとOwnershipの関係を説明できる
SSE-S3 / SSE-KMS / SSE-C禁止を読める
```

実行の中心:

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager

aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager

aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager
```

質問ポイント:

```text
PublicAccessBlockの4項目の違い
BucketOwnerEnforcedの意味
AES256とaws:kmsの違い
Versioningがnullの場合の意味
```

---

## Day 2: S3 Bucket Policy変更・切り戻し

元資料:

- [02_Day_Learning.md](./02_Day_Learning.md)
- [20_Day_Learning.md](./20_Day_Learning.md)
- [02_s3_bucket_policy_cli_reference.md](../docs/references/02_s3_bucket_policy_cli_reference.md)

やること:

```text
変更前Policy保存
変更後Policy作成
Access AnalyzerでPolicy検証
put-bucket-policy
反映後Policy取得
before / after / applied差分確認
rollback用Policy確認
```

最低成果物:

```text
DenyInsecureTransport
DenyOutdatedTLS
Principal
Action
Resource
Condition
Sid
を説明できる
```

実行の中心:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  | "$FORMAT_JSON_AWK"

aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --policy-document file://02_Day_Learning/after/bucket-policy-after.json \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --output json \
  --no-cli-pager
```

質問ポイント:

```text
diffの読み方
JSONの順序差分が問題かどうか
Policy検証結果が空の意味
NumericLessThanやBool条件の意味
```

---

## Day 3: CloudTrailで変更履歴を追う

元資料:

- [03_Day_Learning.md](./03_Day_Learning.md)
- [07_Day_Learning.md](./07_Day_Learning.md)
- [03_cloudtrail_cli_reference.md](../docs/references/03_cloudtrail_cli_reference.md)

やること:

```text
Trailがあるか確認
TrailのS3保存先を確認
Event HistoryでPutBucketPolicyを探す
EventIdからCloudTrailEventを読む
CloudTrailのJSONをformat_json_awk.shで整形する
```

必要な場合だけTrail作成:

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh

/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

実行の中心:

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output json \
  --no-cli-pager

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET" \
  --query 'Events[?EventName==`PutBucketPolicy` || EventName==`DeleteBucketPolicy`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
誰が
いつ
どのAPIを
どのリソースに
どの送信元IPから
実行したか
を説明できる
```

質問ポイント:

```text
TrailとCloudTrailの違い
Event HistoryとTrail保存ログの違い
Management EventとData Eventの違い
ThrottlingExceptionが出たときの待ち方
```

---

## Day 4: CloudWatch Logs / Metric Filter / Alarm

元資料:

- [04_Day_Learning.md](./04_Day_Learning.md)
- [05_Day_Learning.md](./05_Day_Learning.md)
- [06_Day_Learning.md](./06_Day_Learning.md)
- [04_cloudwatch_cli_reference.md](../docs/references/04_cloudwatch_cli_reference.md)

やること:

```text
CloudWatch LogsのLog Group確認
RetentionDays確認
CloudTrail -> CloudWatch Logs連携確認
Metric Filterの意味を確認
Alarmの状態と履歴確認
MFAなしConsoleLogin検知の流れを理解
```

必要な場合だけCloudTrail連携:

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh

/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

実行の中心:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix /nobu-iac-lab \
  --output json \
  --no-cli-pager

aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
Log Group
Log Stream
RetentionDays
Metric Filter
Alarm
Alarm History
を説明できる
```

質問ポイント:

```text
filter-patternの読み方
CloudTrailEventのmessageが読みにくい場合
AlarmがOKのままの理由
Logs Insightsの時刻指定
```

---

## Day 5: GuardDuty Findingを読む

元資料:

- [08_Day_Learning.md](./08_Day_Learning.md)
- [09_Day_Learning.md](./09_Day_Learning.md)
- [05_guardduty_cli_reference.md](../docs/references/05_guardduty_cli_reference.md)

やること:

```text
Detector確認
Feature / Protection Plan確認
使用状況確認
Finding一覧確認
Sample Findingを1件読む
Severity、Resource、Action、Countを読む
```

やらないこと:

```text
EventBridge作成
通知連携作成
抑制ルール作成
Archive実行
実リソース隔離
```

実行の中心:

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text \
  --no-cli-pager)

echo "DETECTOR_ID=$DETECTOR_ID"

aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency,ServiceRole:ServiceRole,Features:Features}' \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
Detector
Feature
Finding
Finding Type
Severity
Resource Role
Action
Count
Archive
を説明できる
```

質問ポイント:

```text
Webコンソールの検出結果がFindingか
Sample Findingの架空リソースをどう扱うか
Countが増える意味
未Archiveを見る意味
```

---

## Day 6: VPC / Route / Endpoint / Flow Logs

元資料:

- [10_Day_Learning.md](./10_Day_Learning.md)
- [14_Day_Learning.md](./14_Day_Learning.md)
- [07_vpc_network_cli_reference.md](../docs/references/07_vpc_network_cli_reference.md)

やること:

```text
VPC
Subnet
Route Table
Internet Gateway
NAT Gateway
VPC Endpoint
Flow Logs
を読む
```

実行の中心:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager

aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager

aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
外から入る通信
内から出る通信
ALBとNAT Gatewayの役割
Public SubnetとPrivate Subnet
VPC Endpointの用途
Flow Logsのメタデータ
を説明できる
```

質問ポイント:

```text
このRoute Tableならどこへ通信するか
ALBとNAT Gatewayの違い
VPC Endpointがあると何が変わるか
Flow Logsで見えるもの、見えないもの
```

---

## Day 7: Security Group / NACL / 通信要件

元資料:

- [11_Day_Learning.md](./11_Day_Learning.md)
- [12_Day_Learning.md](./12_Day_Learning.md)
- [13_Day_Learning.md](./13_Day_Learning.md)

やること:

```text
Security Group確認
Network ACL確認
変更前証跡
変更案
影響範囲
テスト
切り戻し
```

実行の中心:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager

aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
通信要件を見て、
送信元
宛先
ポート
プロトコル
方向
対象SG
影響する経路
を整理できる
```

質問ポイント:

```text
この通信要件ならどのSGを変えるか
NACLを見る必要があるか
Stateful / Statelessの違い
戻し手順に何を書くか
```

---

## Day 8: KMS / SSE-KMS / EC2・RDS最低限

元資料:

- [15_Day_Learning.md](./15_Day_Learning.md)
- [18_Day_Learning.md](./18_Day_Learning.md)
- [26_Day_Learning.md](./26_Day_Learning.md)
- [09_rds_security_cli_reference.md](../docs/references/09_rds_security_cli_reference.md)

やること:

```text
S3暗号化
KMS Key確認
KMS Key Policyの読み方
EC2 IAM Role / IMDSv2 / EBS暗号化
RDS Public / 暗号化 / Backup / SG
```

実行の中心:

```bash
aws kms list-keys \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager

aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager

aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager
```

最低成果物:

```text
SSE-S3
SSE-KMS
Customer managed key
KMS Key Policy
IAM Role
IMDSv2
EBS暗号化
RDSバックアップ
を説明できる
```

質問ポイント:

```text
KmsKeyIdがNoneの場合の意味
SSE-KMSにすると何が影響するか
KMS Key PolicyとIAM Policyの関係
RDSバックアップ設定の読み方
```

---

## Day 9: 共通関数シェル / conf / 証跡

元資料:

- [17_Day_Learning.md](./17_Day_Learning.md)
- [19_Day_Learning.md](./19_Day_Learning.md)
- [26_Day_Learning.md](./26_Day_Learning.md)

やること:

```text
巨大な共通関数シェルを読む
confからprofile、account、region、bucketを読む
関数が最終的に呼ぶAWS CLIを特定する
証跡ディレクトリを作る
before / after / rollbackを分ける
作業結果を短く報告する
```

最低成果物:

```text
このシェルは何をしているか
どのconfを読んでいるか
どのAWS CLIを実行しているか
どのファイルを証跡として残すか
を説明できる
```

使う補助:

```bash
./format_json_awk.sh

rg "aws " .
rg "profile|region|bucket|account|role" .
```

質問ポイント:

```text
この関数の入口はどこか
この変数はどこで設定されているか
このAWS CLIは何を変えるか
この証跡で十分か
```

---

## Day 10: 現場指示型総合演習

元資料:

- [20_Day_Learning.md](./20_Day_Learning.md)
- [21_Day_Learning.md](./21_Day_Learning.md)
- [24_Day_Learning.md](./24_Day_Learning.md)
- [26_Day_Learning.md](./26_Day_Learning.md)

やること:

```text
Exercise 1:
  S3 Bucket Policy変更依頼を受けた想定で、変更前確認、変更、確認、CloudTrail確認、報告まで行う

Exercise 2:
  GuardDuty Findingが出た想定で、Finding詳細、対象リソース、CloudTrail、報告まで行う

Exercise 3:
  構成図を見た想定で、S3、HULFT、認証サーバ、EC2、RDS、通信経路、証跡取得ポイントを整理する

Exercise 4:
  共通シェル経由でAWS CLIを実行する想定で、conf、関数、実行コマンド、証跡を整理する
```

最低成果物:

```text
作業開始前に確認すること
作業中に保存する証跡
作業後に確認すること
切り戻し条件
報告文
を作れる
```

報告文テンプレート:

```text
対象:
実施内容:
変更前確認:
変更内容:
変更後確認:
CloudTrail確認:
影響:
切り戻し:
未確認事項:
次アクション:
```

質問ポイント:

```text
この回答で現場報告として足りるか
この手順は危険ではないか
この証跡は何を証明しているか
この作業はどこで止めるべきか
```

---

## 余裕がない場合の最低ライン

10日すら厳しい場合は、次だけやる。

```text
1. Day 1: S3設定棚卸
2. Day 2: Bucket Policy変更
3. Day 3: CloudTrail変更履歴
4. Day 4: CloudWatch Logs / Alarm
5. Day 7: Security Group / 通信要件
6. Day 9: 共通シェル / 証跡
7. Day 10: 総合演習
```

GuardDuty、KMS、RDS、Lambdaは、時間がなければ「読めるところまで」でよい。

## 最終チェック

参画前に次を口頭で言える状態にする。

```text
S3のセキュリティ設定は、Public Access Block、Bucket Policy、Ownership、ACL、暗号化、Versioning、Loggingを確認します。

設定変更時は、変更前証跡、変更案、検証、反映後確認、CloudTrail確認、切り戻し手順を揃えます。

CloudTrailでは、誰が、いつ、どのAPIを、どのリソースに対して実行したかを確認します。

CloudWatch Logsでは、ログの保存先、保持期間、Metric Filter、Alarm、Alarm Historyを確認します。

ネットワーク変更では、送信元、宛先、ポート、プロトコル、SG、NACL、Route、Endpointを確認します。

共通シェルでは、conf、変数、関数、最終的に実行されるAWS CLI、証跡出力先を追います。
```

