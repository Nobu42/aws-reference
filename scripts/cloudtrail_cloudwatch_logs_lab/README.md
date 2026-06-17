# CloudTrail CloudWatch Logs Lab

Day 5〜7で使用する、CloudTrail Management EventをCloudWatch Logsへ一時連携するための学習用スクリプト群である。

このラボは、CloudTrail Event Historyだけでは見えにくい次の流れを実環境で確認する。

```text
AWS API操作
  -> CloudTrail Trail
  -> CloudWatch Logs Log Group
  -> Metric Filter / Alarmの入力
```

## 構成

```text
cloudtrail_cloudwatch_logs_lab/
├── 01_enable_cloudtrail_cloudwatch_logs.sh
├── 02_check_cloudtrail_cloudwatch_logs.sh
├── 03_restore_cloudtrail_cloudwatch_logs.sh
└── README.md
```

## 前提

先に一時Trailを作成しておく。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
```

## 連携有効化

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/01_enable_cloudtrail_cloudwatch_logs.sh
```

## 配信確認

CloudTrailからCloudWatch Logsへの配信は数分遅れる場合がある。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/02_check_cloudtrail_cloudwatch_logs.sh
```

## 切り戻し

`01_enable_cloudtrail_cloudwatch_logs.sh`が表示したEvidenceディレクトリを指定する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_cloudwatch_logs_lab/03_restore_cloudtrail_cloudwatch_logs.sh \
  /Users/nobu/aws-reference/evidence/cloudtrail_cloudwatch_logs_lab/<timestamp>_enable_cloudwatch_logs
```

実案件の既存Trailには使用しない。
