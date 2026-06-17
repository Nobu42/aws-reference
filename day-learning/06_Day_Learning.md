# Day 6 Learning: CloudWatch・MFAなしログイン検知ハンズオン

## 学習開始前に実行するスクリプト

Day 6は専用の検証用Log Group、Metric Filter、Alarmを実際に作成・テスト・削除するハンズオンである。ラボ用VPCやアプリケーションは使用しない。

Day 5で一時TrailをCloudWatch Logsへ連携済みの場合は、最初に実CloudTrailイベントが届いていることを確認してから、Metric Filter/Alarmの検証へ進む。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
CloudTrail -> CloudWatch Logs連携: Day 5の一時連携を確認する
S3 Data Event: 有効化しない
```

本文の切り戻し手順で、Day 6中に作成した検証用リソースだけを削除して終了する。

実行場所を統一する。

```bash
cd /Users/nobu/aws-reference/day-learning
pwd
```

作業対象アカウントを確認してから作成系コマンドへ進む。

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

Day 5で作成したCloudTrail -> CloudWatch Logs連携が残っている場合は確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

この確認で見るもの:

```text
TrailにCloudWatchLogsLogGroupArnが設定されている
CloudWatch LogsにCloudTrail用Log Streamが作成されている
実際のManagement EventがCloudWatch Logsへ届いている
```

## 1. 今日の目的

専用の検証用CloudWatch Logs Log Groupを使用し、MFAなし管理コンソールログインを検知するMetric FilterとCloudWatch Alarmを実際に作成・テスト・削除する。

Day 5では検知設計を理解した。Day 6では、実作業として依頼された場合に、手順書を見ながら変更前確認、設定変更、テスト、変更後確認、証跡取得、切り戻しまで進められる状態を目指す。

本ハンズオンでは、Day 5で作成した一時Trail連携は確認対象として使う。Metric FilterとAlarmの作成・削除は、検証用Log GroupへサンプルCloudTrailイベントを投入する方式で行う。通知先SNSは変更しない。

関連資料:

- [MFAなし管理コンソールログイン検知手順](../docs/references/06_mfa_console_login_detection.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [Day 4 CloudWatch Logs・Metric Filter・Alarm確認](./04_Day_Learning.md)
- [Day 5 MFAなし管理コンソールログイン検知の設計理解](./05_Day_Learning.md)

## 今日の作業フロー

```text
作業対象確認
↓
変更前確認・証跡取得
↓
専用検証Log GroupとLog Stream作成
↓
Metric Filter作成
↓
通知なしCloudWatch Alarm作成
↓
MFAありイベント投入
↓
非検知確認
↓
MFAなしイベント投入
↓
Metric・Alarm・ログ確認
↓
CloudTrailで変更履歴確認
↓
切り戻し
↓
切り戻し後確認・報告
```

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 検証用Log Group | `/nobu-iac-lab/security/mfa-console-login-lab` |
| 検証用Log Stream | `manual-test-events` |
| Metric Namespace | `NobuIacLab/SecurityLab` |
| Metric Name | `ConsoleLoginWithoutMFA` |
| Metric Filter名 | `ConsoleLoginWithoutMFA-Lab` |
| Alarm名 | `nobu-iac-lab-security-console-login-without-mfa-lab` |
| Alarm Action | 無効 |
| 実CloudTrail連携変更 | なし |
| SNS通知 | なし |

## 作成する一時リソース

| リソース | 用途 | Day 6終了時 |
|---|---|---|
| 検証用Log Group | サンプルCloudTrailイベント保存 | 削除する |
| 検証用Log Stream | サンプルイベント投入先 | Log Groupとともに削除する |
| Metric Filter | MFAなしログイン検知 | 削除する |
| Custom Metric | 検知件数 | 新規データ送信を停止する |
| CloudWatch Alarm | Custom Metric監視 | 削除する |

## 今日変更しないもの

- 実運用中のCloudTrail Trail
- CloudTrail連携用IAM Role
- 既存CloudWatch Logs Log Group
- 既存Metric Filter
- 既存CloudWatch Alarm
- SNS Topic、Subscription、Teams通知
- IAMユーザーのMFA設定

---

## 2. 実作業とラボハンズオンの違い

実案件では、CloudTrailからCloudWatch Logsへの配信設定を確認し、実際の`ConsoleLogin`イベントをMetric Filterで検知する。

Day 6では、実CloudTrail連携を変更せず、検証用Log GroupにCloudTrail形式のサンプルイベントを投入する。

```text
実案件:
AWS Console Login
→ CloudTrail
→ CloudWatch Logs
→ Metric Filter
→ Custom Metric
→ Alarm
→ 通知

Day 6メイン検証:
サンプルConsoleLoginイベント
→ 検証用CloudWatch Logs
→ Metric Filter
→ Custom Metric
→ 通知なしAlarm

Day 5から残した実環境確認:
実AWS API操作
→ 一時CloudTrail Trail
→ CloudWatch Logs
→ 実ログとして検索
```

Day 6で確認できること:

- Filter Patternが期待どおり一致すること
- Metric FilterがCustom Metricを出力すること
- AlarmがCustom Metricを監視すること
- 設定変更と切り戻しをAWS CLIで実施できること
- 変更前後の証跡を整理できること

Day 6だけでは確認できないこと:

- 実際の`ConsoleLogin`イベント形式との差異
- SNS、メール、Teamsへの通知
- 本番運用上のエスカレーション

---

## 3. 作業開始条件と中止条件

## 作業開始条件

- AWSアカウントとリージョンが想定どおりである
- 同名のLog Group、Metric Filter、Alarmが存在しない
- 検証用リソースを作成してよい環境である
- 検証後に削除する時間を確保している
- SNS通知を設定しない
- 実CloudTrail Trailを変更しない

## 作業中止条件

- AWSアカウントまたはリージョンが想定と異なる
- 同名リソースが既に存在する
- 既存リソースとの用途を判断できない
- Alarm Actionが意図せず有効になっている
- 想定外の通知が発生した
- 検証用以外のLog GroupやAlarmを変更してしまった
- AWS CLIエラーの原因を判断できない

---

## 4. 作業用変数の設定

最初に作業対象を変数として定義する。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

LAB_LOG_GROUP_NAME="/nobu-iac-lab/security/mfa-console-login-lab"
LAB_LOG_STREAM_NAME="manual-test-events"

METRIC_NAMESPACE="NobuIacLab/SecurityLab"
METRIC_NAME="ConsoleLoginWithoutMFA"
FILTER_NAME="ConsoleLoginWithoutMFA-Lab"
ALARM_NAME="nobu-iac-lab-security-console-login-without-mfa-lab"

FILTER_PATTERN='{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }'
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID"

printf 'LAB_LOG_GROUP_NAME=%s\nLAB_LOG_STREAM_NAME=%s\n' \
  "$LAB_LOG_GROUP_NAME" "$LAB_LOG_STREAM_NAME"

printf 'METRIC_NAMESPACE=%s\nMETRIC_NAME=%s\nFILTER_NAME=%s\nALARM_NAME=%s\n' \
  "$METRIC_NAMESPACE" "$METRIC_NAME" "$FILTER_NAME" "$ALARM_NAME"
```

### 変数の必須チェック

```bash
for VARIABLE_NAME in \
  PROFILE \
  REGION \
  EXPECTED_ACCOUNT_ID \
  LAB_LOG_GROUP_NAME \
  LAB_LOG_STREAM_NAME \
  METRIC_NAMESPACE \
  METRIC_NAME \
  FILTER_NAME \
  ALARM_NAME \
  FILTER_PATTERN
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
WORK_NAME="mfa_console_login_detection_lab"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/test" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
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

---

## 6. AWSアカウント確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. AWSアカウント情報を確認する
3. 東京リージョンを選択する
4. CloudWatchコンソールを開く

取得するスクリーンショット:

```text
01_操作アカウント確認.png
```

### AWS CLI

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
  echo "Expected account: $EXPECTED_ACCOUNT_ID"
  return 1 2>/dev/null || exit 1
fi

echo "Account check OK: $ACCOUNT_ID"
```

### Caller Identityを証跡保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

---

## 7. 変更前確認

同名の検証用リソースが存在しないことを確認する。

存在する場合は、新規作成せず用途と所有者を確認する。

## Log Group変更前確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/01_log_group_before.json"
```

読みやすい確認:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes}' \
  --output table \
  --no-cli-pager
```

## Alarm変更前確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/02_alarm_before.json"
```

読みやすい確認:

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

## 変更前の期待値

```text
検証用Log Group:
存在しない

検証用Alarm:
存在しない
```

出力がある場合は作業を中止し、既存リソースを削除・更新しない。

---

## 8. Filter Patternの事前テスト

設定変更前に、Filter Patternの一致・不一致を確認する。

```bash
aws logs test-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter-pattern "$FILTER_PATTERN" \
  --log-event-messages '["{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"No\"}}","{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Success\"},\"additionalEventData\":{\"MFAUsed\":\"Yes\"}}","{\"eventName\":\"ConsoleLogin\",\"responseElements\":{\"ConsoleLogin\":\"Failure\"},\"additionalEventData\":{\"MFAUsed\":\"No\"}}"]' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/03_test_metric_filter_before.json"
```

### 結果確認

```bash
cat "$EVIDENCE_DIR/before/03_test_metric_filter_before.json"
```

### 期待値

```text
SuccessかつMFAUsed=No:
一致する

SuccessかつMFAUsed=Yes:
一致しない

FailureかつMFAUsed=No:
一致しない
```

期待どおりでない場合は、Metric Filterを作成しない。

---

## 9. 検証用Log Groupの作成

### Webコンソール

実作業では、CloudWatch Logsの「ロググループ」画面で作成後のLog Groupを確認する。

AWS CLIで作成するため、Webコンソールでは「作成」操作を行わない。

### AWS CLI

```bash
aws logs create-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --no-cli-pager
```

終了コード確認:

```bash
echo $?
```

期待値:

```text
0
```

### Retentionを7日に設定

```bash
aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --retention-in-days 7 \
  --no-cli-pager
```

### 作成後確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,Class:logGroupClass}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/04_log_group_created.json"
```

### 確認ポイント

- Log Group名が想定どおり
- Retentionが7日
- 既存Log Groupを変更していない
- KMS要件がある場合は別途確認が必要

取得するスクリーンショット:

```text
02_検証用Log_Group作成後.png
```

---

## 10. 検証用Log Streamの作成

```bash
aws logs create-log-stream \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --no-cli-pager
```

### 作成後確認

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name-prefix "$LAB_LOG_STREAM_NAME" \
  --query 'logStreams[].{LogStream:logStreamName,LastEventTimestamp:lastEventTimestamp,LastIngestionTime:lastIngestionTime}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/05_log_stream_created.json"
```

---

## 11. Metric Filterの作成

Metric Filterは、検証用Log Groupへ投入されたログから成功したMFAなしログインを検知し、Custom Metricへ`1`を出力する。

### AWS CLI

```bash
aws logs put-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --metric-transformations \
    metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1,defaultValue=0,unit=Count \
  --no-cli-pager
```

### 作成後確認

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --query 'metricFilters[].{FilterName:filterName,FilterPattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/06_metric_filter_created.json"
```

### 確認ポイント

- `filterName`が想定どおり
- `filterPattern`が承認内容と一致する
- `metricNamespace`が想定どおり
- `metricName`が想定どおり
- `metricValue`が`1`
- 既存Metric Filterを更新していない

取得するスクリーンショット:

```text
03_Metric_Filter作成後.png
```

---

## 12. 通知なしCloudWatch Alarmの作成

初回検証では、Alarm Actionを無効にして不要な通知を防止する。

### AWS CLI

```bash
aws cloudwatch put-metric-alarm \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab detection for successful AWS Management Console login without MFA" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --no-actions-enabled \
  --no-cli-pager
```

### 作成後確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,Namespace:Namespace,MetricName:MetricName,Statistic:Statistic,Period:Period,EvaluationPeriods:EvaluationPeriods,Threshold:Threshold,TreatMissingData:TreatMissingData,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/07_alarm_created.json"
```

### 確認ポイント

- NamespaceとMetric NameがMetric Filterと一致する
- `Period`が60秒
- `Threshold`が1
- `TreatMissingData`が`notBreaching`
- `ActionsEnabled`が`False`
- 作成直後は`INSUFFICIENT_DATA`の場合がある

取得するスクリーンショット:

```text
04_通知なしAlarm作成後.png
```

---

## 13. MFAありログインイベントの投入

最初に、検知対象外であるMFAありログインイベントを投入する。

Metric Filterが誤検知しないことを確認する。

### テストイベントファイル作成

```bash
TIMESTAMP_MS="$(($(date +%s) * 1000))"

EVENT_MESSAGE='{"eventSource":"signin.amazonaws.com","eventName":"ConsoleLogin","responseElements":{"ConsoleLogin":"Success"},"additionalEventData":{"MFAUsed":"Yes"},"sourceIPAddress":"203.0.113.20","userIdentity":{"type":"IAMUser","arn":"arn:aws:iam::123456789012:user/mfa-user"}}'

ESCAPED_EVENT_MESSAGE=$(printf '%s' "$EVENT_MESSAGE" \
  | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '[{"timestamp":%s,"message":"%s"}]\n' \
  "$TIMESTAMP_MS" "$ESCAPED_EVENT_MESSAGE" \
  > "$EVIDENCE_DIR/test/08_mfa_used_yes_event.json"
```

### イベント内容確認

```bash
cat "$EVIDENCE_DIR/test/08_mfa_used_yes_event.json"
```

### CloudWatch Logsへ投入

```bash
aws logs put-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --log-events "file://$EVIDENCE_DIR/test/08_mfa_used_yes_event.json" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/test/09_put_mfa_used_yes_result.json"
```

### ログ確認

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-pattern '{ $.eventName = "ConsoleLogin" }' \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### Alarm確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,StateReason:StateReason,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

### 期待値

```text
MFAUsed=Yesイベント:
Log Groupに保存される

Metric Filter:
検知対象外

Alarm:
ALARMへ遷移しない
```

Alarm評価には時間がかかる場合がある。直後の状態だけで判断しない。

---

## 14. MFAなしログインイベントの投入

次に、検知対象である成功したMFAなしログインイベントを投入する。

### テストイベントファイル作成

```bash
TIMESTAMP_MS="$(($(date +%s) * 1000))"

EVENT_MESSAGE='{"eventSource":"signin.amazonaws.com","eventName":"ConsoleLogin","responseElements":{"ConsoleLogin":"Success"},"additionalEventData":{"MFAUsed":"No"},"sourceIPAddress":"203.0.113.10","userIdentity":{"type":"IAMUser","arn":"arn:aws:iam::123456789012:user/test-user"}}'

ESCAPED_EVENT_MESSAGE=$(printf '%s' "$EVENT_MESSAGE" \
  | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '[{"timestamp":%s,"message":"%s"}]\n' \
  "$TIMESTAMP_MS" "$ESCAPED_EVENT_MESSAGE" \
  > "$EVIDENCE_DIR/test/10_mfa_used_no_event.json"
```

### イベント内容確認

```bash
cat "$EVIDENCE_DIR/test/10_mfa_used_no_event.json"
```

### CloudWatch Logsへ投入

```bash
aws logs put-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --log-stream-name "$LAB_LOG_STREAM_NAME" \
  --log-events "file://$EVIDENCE_DIR/test/10_mfa_used_no_event.json" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/test/11_put_mfa_used_no_result.json"
```

### Filter Pattern一致ログ確認

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --limit 20 \
  --query 'events[].{Timestamp:timestamp,LogStream:logStreamName,Message:message}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-pattern "$FILTER_PATTERN" \
  --limit 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/test/12_filter_mfa_without_login_result.json"
```

取得するスクリーンショット:

```text
05_MFAなしログイン検知ログ.png
```

---

## 15. Custom Metricの確認

Metric Filterが一致イベントを処理すると、Custom Metricへ値が出力される。

反映まで数分かかる場合がある。

### Metric存在確認

```bash
aws cloudwatch list-metrics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --query 'Metrics[].{Namespace:Namespace,MetricName:MetricName,Dimensions:Dimensions}' \
  --output table \
  --no-cli-pager
```

### 直近15分のMetric確認

macOSの`date`を使用する例:

```bash
START_TIME="$(date -u -v-15M '+%Y-%m-%dT%H:%M:%SZ')"
END_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

printf 'START_TIME=%s\nEND_TIME=%s\n' \
  "$START_TIME" "$END_TIME"
```

```bash
aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws cloudwatch get-metric-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/test/13_metric_statistics.json"
```

### 期待値

```text
MFAUsed=Yesイベント:
検知件数に加算されない

MFAUsed=Noイベント:
Sumに1以上が表示される
```

---

## 16. Alarm状態の確認

Metricが反映された後、Alarm状態を確認する。

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,StateReason:StateReason,StateUpdatedTimestamp:StateUpdatedTimestamp,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

### 証跡保存

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/test/14_alarm_after_test.json"
```

### 期待値

```text
State:
ALARM

ActionsEnabled:
False
```

検知後、次の評価期間でデータがなくなると、`treat-missing-data=notBreaching`により`OK`へ戻る場合がある。

取得するスクリーンショット:

```text
06_Alarm検知結果.png
```

---

## 17. 変更後設定の確認

テストが終わったら、作成した設定値をまとめて確認する。

## Log Group

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --query 'logGroups[].{LogGroup:logGroupName,RetentionDays:retentionInDays,StoredBytes:storedBytes}' \
  --output table \
  --no-cli-pager
```

## Metric Filter

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --query 'metricFilters[].{FilterName:filterName,FilterPattern:filterPattern,MetricTransformations:metricTransformations}' \
  --output table \
  --no-cli-pager
```

## Alarm

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,Namespace:Namespace,MetricName:MetricName,Threshold:Threshold,TreatMissingData:TreatMissingData,ActionsEnabled:ActionsEnabled}' \
  --output table \
  --no-cli-pager
```

## 変更後証跡保存

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/15_log_group_after.json"

aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/16_metric_filter_after.json"

aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/17_alarm_after.json"
```

---

## 18. CloudTrailで変更履歴を確認する

Day 6で実施したCloudWatch LogsとCloudWatch Alarmの設定変更は、CloudTrailのManagement Eventとして確認できる。

## 確認対象イベント

| 操作 | EventName例 |
|---|---|
| Log Group作成 | `CreateLogGroup` |
| Retention設定 | `PutRetentionPolicy` |
| Log Stream作成 | `CreateLogStream` |
| Metric Filter作成 | `PutMetricFilter` |
| Alarm作成 | `PutMetricAlarm` |
| Alarm削除 | `DeleteAlarms` |
| Metric Filter削除 | `DeleteMetricFilter` |
| Log Group削除 | `DeleteLogGroup` |

### CloudWatch Logs変更イベント確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=logs.amazonaws.com \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### CloudWatch変更イベント確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=monitoring.amazonaws.com \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- 実行者が想定どおり
- 実行時刻が作業時間内
- 作成・変更したAPIが想定どおり
- エラーイベントがない
- 対象リソース名が想定どおり

---

## 19. 切り戻し

検証終了後、一時リソースを削除する。

削除は依存関係を考慮し、Alarm、Metric Filter、Log Groupの順に実施する。

## 19.1 Alarm Action確認

Alarm Actionが無効であることを確認する。

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{AlarmName:AlarmName,ActionsEnabled:ActionsEnabled,AlarmActions:AlarmActions}' \
  --output table \
  --no-cli-pager
```

期待値:

```text
ActionsEnabled:
False

AlarmActions:
空
```

## 19.2 Alarm削除

```bash
aws cloudwatch delete-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-names "$ALARM_NAME" \
  --no-cli-pager
```

## 19.3 Metric Filter削除

```bash
aws logs delete-metric-filter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name "$FILTER_NAME" \
  --no-cli-pager
```

削除後確認:

```bash
aws logs describe-metric-filters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --filter-name-prefix "$FILTER_NAME" \
  --output table \
  --no-cli-pager
```

## 19.4 Log Group削除

Log Groupを削除すると、Log Streamと保存されたテストイベントも削除される。

```bash
aws logs delete-log-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LAB_LOG_GROUP_NAME" \
  --no-cli-pager
```

## 19.5 切り戻し後確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output table \
  --no-cli-pager
```

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --output table \
  --no-cli-pager
```

### 切り戻し後の期待値

```text
検証用Alarm:
表示されない

検証用Metric Filter:
Log Group削除により存在しない

検証用Log Group:
表示されない
```

### 切り戻し証跡保存

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --alarm-name-prefix "$ALARM_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/18_alarm_after_rollback.json"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LAB_LOG_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/19_log_group_after_rollback.json"
```

取得するスクリーンショット:

```text
07_切り戻し後_Log_Group一覧.png
08_切り戻し後_Alarm一覧.png
```

---

## 20. 切り戻し後のCloudTrail確認

削除操作もCloudTrailで確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=Username,AttributeValue=nobu \
  --query 'Events[?EventName==`DeleteAlarms` || EventName==`DeleteMetricFilter` || EventName==`DeleteLogGroup`].{EventTime:EventTime,EventName:EventName,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- `DeleteAlarms`
- `DeleteMetricFilter`
- `DeleteLogGroup`
- 実行者
- 実行時刻
- エラーの有無

---

## 21. 実CloudTrail連携を設定する場合の確認事項

Day 6では実CloudTrail連携を変更しない。

実案件でCloudTrailからCloudWatch Logsへの連携を追加・変更する場合は、次を確認する。

### 変更前確認

- 対象Trail名とHome Region
- Multi-Region Trailか
- Management Eventが記録対象か
- 既存CloudWatch Logs連携の有無
- 配信先Log Group
- CloudTrail連携用IAM Role
- IAM RoleのTrust PolicyとPermissions Policy
- Log Group Retention
- KMS暗号化要件
- 既存SIEM・監視製品との連携
- 料金とログ保存期間

### 影響範囲

- Trail設定変更
- CloudWatch Logs取り込み・保存料金
- IAM Role作成・変更
- 既存Metric FilterとAlarm
- 監視運用と通知先
- 複数AWSアカウント・複数リージョンへの影響

### 実作業時の原則

```text
承認済み手順書に従う
↓
変更前証跡を取得する
↓
既存設定をバックアップする
↓
CloudTrail連携を設定する
↓
配信状態とエラーを確認する
↓
Metric FilterとAlarmを設定する
↓
テストする
↓
変更後証跡とCloudTrail変更履歴を確認する
```

---

## 22. 証跡一覧

| No. | タイミング | 証跡 | ファイル例 |
|---|---|---|---|
| 00 | 変更前 | Caller Identity | `00_caller_identity.json` |
| 01 | 変更前 | Log Group確認 | `01_log_group_before.json` |
| 02 | 変更前 | Alarm確認 | `02_alarm_before.json` |
| 03 | 変更前 | Filter Patternテスト | `03_test_metric_filter_before.json` |
| 04 | 変更時 | Log Group作成後 | `04_log_group_created.json` |
| 05 | 変更時 | Log Stream作成後 | `05_log_stream_created.json` |
| 06 | 変更時 | Metric Filter作成後 | `06_metric_filter_created.json` |
| 07 | 変更時 | Alarm作成後 | `07_alarm_created.json` |
| 08 | テスト | MFAありイベント | `08_mfa_used_yes_event.json` |
| 09 | テスト | MFAありイベント投入結果 | `09_put_mfa_used_yes_result.json` |
| 10 | テスト | MFAなしイベント | `10_mfa_used_no_event.json` |
| 11 | テスト | MFAなしイベント投入結果 | `11_put_mfa_used_no_result.json` |
| 12 | テスト | Filter一致ログ | `12_filter_mfa_without_login_result.json` |
| 13 | テスト | Custom Metric | `13_metric_statistics.json` |
| 14 | テスト | Alarm状態 | `14_alarm_after_test.json` |
| 15 | 変更後 | Log Group | `15_log_group_after.json` |
| 16 | 変更後 | Metric Filter | `16_metric_filter_after.json` |
| 17 | 変更後 | Alarm | `17_alarm_after.json` |
| 18 | 切り戻し | Alarm削除後 | `18_alarm_after_rollback.json` |
| 19 | 切り戻し | Log Group削除後 | `19_log_group_after_rollback.json` |

---

## 23. スクリーンショット一覧

| No. | ファイル名 | 撮影内容 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント、リージョン |
| 02 | `02_検証用Log_Group作成後.png` | Log Group、Retention |
| 03 | `03_Metric_Filter作成後.png` | Filter Pattern、Metric変換 |
| 04 | `04_通知なしAlarm作成後.png` | Alarm設定、Actions無効 |
| 05 | `05_MFAなしログイン検知ログ.png` | 一致したテストログ |
| 06 | `06_Alarm検知結果.png` | Alarm状態 |
| 07 | `07_切り戻し後_Log_Group一覧.png` | Log Groupが存在しないこと |
| 08 | `08_切り戻し後_Alarm一覧.png` | Alarmが存在しないこと |

### 撮影時の注意

- AWSアカウントとリージョンを識別できるようにする
- 対象リソース名と設定値を同じ画面に含める
- テスト用リソースであることを明確にする
- 不要な個人情報や認証情報を含めない
- 実イベントとサンプルイベントを混同しない

---

## 24. よくあるエラーと確認ポイント

## ResourceAlreadyExistsException

原因:

```text
同名のLog GroupまたはLog Streamが既に存在する。
```

対応:

- 既存リソースを削除・更新しない
- 用途と所有者を確認する
- 前回の切り戻し漏れか確認する
- 必要に応じて別名で作業申請する

## ResourceNotFoundException

原因:

```text
指定したLog Group、Log Stream、Metric Filter、Alarmが存在しない。
```

対応:

- AWSアカウントとリージョンを確認する
- 変数の値を確認する
- 作成手順が正常終了したか確認する
- 切り戻し済みではないか確認する

## InvalidParameterException

原因例:

- Filter Patternの構文誤り
- Metric Transformationの指定誤り
- AlarmのPeriodやThreshold指定誤り
- Log EventのJSON形式誤り

対応:

- `test-metric-filter`でFilter Patternを確認する
- 作成したテストイベントファイルを確認する
- AWS CLIコマンドと引用符を確認する

## put-log-eventsでイベントが拒否される

確認項目:

- Timestampが現在時刻から大きく外れていないか
- Timestampがミリ秒単位か
- テストイベントファイルがJSON配列か
- Log GroupとLog Streamが存在するか
- IAM権限があるか

## Custom Metricが表示されない

確認項目:

- Metric Filter作成後に一致イベントを投入したか
- NamespaceとMetric Nameが正しいか
- 数分待って再確認したか
- Filter Patternがイベントへ一致しているか
- リージョンが正しいか

## AlarmがALARMにならない

確認項目:

- Custom MetricにDatapointがあるか
- AlarmのNamespaceとMetric Nameが一致するか
- Period、Evaluation Periods、Thresholdが正しいか
- Alarm評価まで数分待ったか
- `treat-missing-data`が想定どおりか

## 切り戻しできない

確認項目:

- Alarm、Metric Filter、Log Groupの順で削除しているか
- 変数が現在のシェルに残っているか
- AWSアカウントとリージョンが正しいか
- 既に削除済みではないか
- IAM権限があるか

---

## 25. 影響範囲

| 変更対象 | 影響 |
|---|---|
| 検証用Log Group | CloudWatch Logs保存料金が発生し得る |
| Retention | 検証用Log Groupの保持期間を7日に設定する |
| Metric Filter | Custom Metricを出力する |
| Custom Metric | CloudWatch Custom Metric料金が発生し得る |
| CloudWatch Alarm | Alarm料金が発生し得る |
| サンプルイベント | 検証用Log Groupへ保存される |

CloudWatch Custom Metricには明示的な削除APIがない。Metric Filter削除後は新しいDatapointが送信されなくなるが、過去のMetricとDatapointは一定期間表示される場合がある。

影響しないもの:

- 実運用中のCloudTrail Trail
- 既存アプリケーションログ
- IAMユーザーのログイン可否
- MFA設定
- SNS通知先
- 既存CloudWatch Alarm
- アプリケーション通信

---

## 26. セキュリティ上の注意点

- 実CloudTrailイベントではなくサンプルイベントを使用する
- サンプルARN、IPアドレス、ユーザー名は架空の値を使用する
- 実際のAccess Key IDや認証情報をテストイベントへ含めない
- Alarm Actionを無効にした状態で作成する
- 既存Log Group、Metric Filter、Alarmを更新しない
- 同名リソースが存在する場合は作業を中止する
- 検証終了後に一時リソースを削除する
- CloudTrail変更履歴で実行した操作を確認する
- 証跡を公開する前にAWSアカウントIDやARNを確認する

---

## 27. Teams報告例

### 作業開始前

```text
MFAなし管理コンソールログイン検知の検証を開始する。

対象:
AWSアカウント 445405559057
リージョン ap-northeast-1

実施内容:
- 検証用CloudWatch Logs Log Group作成
- Metric Filter作成
- 通知なしCloudWatch Alarm作成
- サンプルイベントによる検知テスト
- 検証後の一時リソース削除

実CloudTrail設定、既存監視、SNS通知先は変更しない。
```

### 検知テスト完了

```text
MFAなし管理コンソールログイン検知テストを実施した。

結果:
- MFAあり成功ログインイベントは検知対象外であることを確認した
- MFAなし成功ログインイベントはMetric Filterへ一致した
- Custom Metricへ検知値が出力された
- 通知なしCloudWatch Alarmの状態を確認した
- Alarm Actionが無効であることを確認した

通知:
なし
```

### 切り戻し完了

```text
MFAなし管理コンソールログイン検知の検証用リソースを削除した。

削除対象:
- 検証用CloudWatch Alarm
- 検証用Metric Filter
- 検証用CloudWatch Logs Log Group

切り戻し後確認:
- 同名Alarmが存在しないことを確認した
- 同名Log Groupが存在しないことを確認した
- CloudTrailで削除操作を確認した

既存CloudTrail設定、既存監視、SNS通知先への変更はない。
```

---

## 28. 案件で説明できるポイント

### 実施前確認

```text
作業前に対象AWSアカウント、リージョン、既存Log Group、
Metric Filter、Alarm、通知先を確認する。

同名または同目的の監視がある場合は、重複作成せず影響を確認する。
```

### 安全なテスト

```text
Filter Patternはtest-metric-filterで先に確認する。

初回Alarmは通知Actionを無効にして作成し、
Metric Filter、Custom Metric、Alarm状態を順番に確認する。

実際のMFAなしログインは安易に発生させず、
サンプルイベントまたは承認済みテスト方法を使用する。
```

### 切り戻し

```text
追加したAlarm、Metric Filter、Log Groupを依存関係に沿って削除する。

切り戻し後は同名リソースが存在しないことを確認し、
CloudTrailで削除操作の実行者、時刻、対象を確認する。
```

---

## 29. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| CloudWatch Logs | Log Group、Log Stream、Retention |
| Metric Filter | ログパターンをCustom Metricへ変換する |
| Custom Metric | 独自の監視値をCloudWatch Metricsへ保存する |
| CloudWatch Alarm | Metricをしきい値で評価する |
| Alarm Action | SNS通知や自動アクションへ接続する |
| Treat Missing Data | データ欠損時のAlarm評価方法 |
| CloudTrail | CloudWatch設定変更をManagement Eventとして記録する |
| ConsoleLogin | AWS Management Consoleログインイベント |
| MFA | 認証情報漏えい時の不正ログインリスクを軽減する |

---

## 30. 要確認事項

実案件で同様の作業を行う場合は、次を確認する。

- 対象AWSアカウントとリージョン
- Organization Trail、Multi-Region Trail、単一Trailのどれを使用しているか
- CloudTrailからCloudWatch Logsへの連携先
- CloudTrail連携用IAM Role
- 既存SIEM・監視製品との役割分担
- Log Group RetentionとKMS暗号化要件
- Metric Namespace、Metric Name、Filter名、Alarm名の命名規則
- Alarmしきい値と評価期間
- Alarm Actionと通知先
- テスト方法とテスト通知の事前連絡
- 検知後の一次対応者とエスカレーション先
- 切り戻し条件と承認者

不明な項目は合理的に推測して変更せず、未確認事項・影響調査項目として手順書と報告へ残す。

---

## 31. Day 6完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] 作業用変数と証跡ディレクトリを準備した
- [ ] 同名Log GroupとAlarmが存在しないことを確認した
- [ ] `test-metric-filter`で一致・不一致を確認した
- [ ] 検証用Log GroupとLog Streamを作成した
- [ ] Retentionを7日に設定した
- [ ] Metric Filterを作成した
- [ ] 通知なしCloudWatch Alarmを作成した
- [ ] Alarm Actionが無効であることを確認した
- [ ] MFAありログインイベントが検知対象外であることを確認した
- [ ] MFAなしログインイベントがFilter Patternへ一致することを確認した
- [ ] Custom Metricを確認した
- [ ] Alarm状態を確認した
- [ ] CloudTrailで設定変更履歴を確認した
- [ ] 変更後設定と証跡を確認した
- [ ] Alarm、Metric Filter、Log Groupを削除した
- [ ] 切り戻し後に同名リソースが存在しないことを確認した
- [ ] CloudTrailで削除履歴を確認した
- [ ] Teams報告文を作成した

## Day 6の完了条件

次を手順書を見ながら実施・説明できればDay 6は完了とする。

```text
変更前に既存Log Group、Metric Filter、Alarmを確認する。

Filter Patternをtest-metric-filterで確認した後、
検証用Log GroupへMetric Filterと通知なしAlarmを作成する。

MFAあり・MFAなしのサンプルイベントを投入し、
Metric Filter、Custom Metric、Alarmの動作を確認する。

検証後は作成したAlarm、Metric Filter、Log Groupを削除し、
CloudTrailで作成・削除操作の履歴を確認する。
```
