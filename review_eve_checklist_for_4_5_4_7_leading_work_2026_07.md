# 要件4.5/4.7 先行作業 レビュー前日確認チェックリスト

作成日: 2026-07-19

本資料は、要件4.5「CloudTrail設定変更監視」および要件4.7「カスタマー管理KMSキーの無効化・削除予約監視」のレビュー前日に確認すべき事項を整理するものである。

目的は、レビュー当日に「前提未確認」「権限未確認」「通知先未確認」「切り戻し未確認」で止まらない状態を作ることである。  
本資料は、レビュー前日の自己点検、リーダー確認、PM確認、インフラ担当確認に使用する。

## 1. レビュー前日のゴール

レビュー前日のゴールは、手順書を完全確定させることではない。  
レビューで判断してもらうべき未確定事項と、作業当日に詰まり得る事項を明示することである。

| ゴール | 完了条件 |
| :--- | :--- |
| 作業対象が明確 | 先行作業対象が4.5/4.7であることを確認済み |
| 作業方式が明確 | Webコンソール作業を前提とすることを確認済み |
| 作業環境が明確 | 検証環境で実施することを確認済み |
| CloudTrail連携方針が明確 | CloudTrail -> CloudWatch Logs連携を追加する方針または確認待ちとして明示済み |
| 通知方式が明確 | 既存SNS Topicまたは既存通知基盤を使う方針を確認済み |
| 権限の見通しがある | 作業用アカウントに必要な権限を確認済み、または確認依頼済み |
| 切り戻し方針が明確 | 検証環境で残置するか切り戻すか確認済み、または確認事項として明示済み |
| 公式根拠が用意済み | CloudWatch / CloudTrail公式URLを提示できる |

## 2. 最優先で確認すること

レビュー前日は、以下を最優先で確認する。

| 優先 | 確認事項 | 理由 | 未確認時の扱い |
| :--- | :--- | :--- | :--- |
| 1 | 作業用アカウントが作業日前に払い出されるか | 権限確認と作業実施の前提 | 作業開始条件未充足として明示 |
| 2 | CloudTrail -> CloudWatch Logs連携を今回有効化してよいか | Metric Filter方式の前提 | レビュー確認事項にする |
| 3 | 連携先Log Group名がパラメータシートにあるか | デフォルト値を勝手に採用しないため | 空欄なら確認事項にする |
| 4 | CloudTrail配信用IAM Role名をどうするか | デフォルトRoleか現場命名規則Roleか決めるため | 確認事項にする |
| 5 | IAM Roleを誰が作るか | 作業者権限だけで完結しない可能性 | インフラ/IAM担当へ確認 |
| 6 | `iam:PassRole`が作業者に付くか | RoleがあってもTrailへ設定できない可能性 | 権限確認事項にする |
| 7 | 既存SNS Topicを使ってよいか | Alarm Action設定の前提 | 通知先確認事項にする |
| 8 | 通知テストの受信確認者は誰か | 通知到達確認の証跡が取れないため | レビュー確認事項にする |
| 9 | 設定変更テスト後に残置するか切り戻すか | 当日手順が変わるため | 判断欄を残す |
| 10 | A-gate / EventBridge対応済み要件と重複しないか | 二重通知防止 | PM確認待ちとして明示 |

## 3. 作業対象と対象外

### 3.1 作業対象

| 要件 | 内容 | 先行作業で行うこと |
| :--- | :--- | :--- |
| 4.5 | CloudTrail設定変更監視 | CloudTrail変更イベントをMetric Filter / Alarmで検知する |
| 4.7 | カスタマー管理KMSキーの無効化・削除予約監視 | KMS危険操作イベントをMetric Filter / Alarmで検知する |

### 3.2 先行作業で行わないこと

| 対象外 | 理由 |
| :--- | :--- |
| 本番環境変更 | 検証環境で手順と設定値を確認してから扱う |
| 本番Trailの停止・削除テスト | 監査ログ停止につながる |
| 本物のKMSキー無効化・削除予約テスト | 暗号化済みデータやサービス利用へ影響する |
| 既存EventBridge Rule削除 | 既存通知経路を壊す可能性がある |
| 既存SNS Topic削除 | 他用途通知を壊す可能性がある |
| 既存Log Group削除 | 既存ログや証跡を失う |

## 4. パラメータシート確認

### 4.1 CloudTrail関連

| 確認項目 | 見る値 | 確認結果 |
| :--- | :--- | :--- |
| 対象Trail名 | Trail Name | `TBD` |
| 対象リージョン | Home Region / Region | `TBD` |
| Multi-Region Trailか | `IsMultiRegionTrail` | `TBD` |
| Management Event記録 | Include management events | `TBD` |
| Read/Write種別 | ReadWriteType | `TBD` |
| KMS除外有無 | ExcludeManagementEventSources | `TBD` |
| CloudWatch Logs連携 | 有効/無効 | `TBD` |
| CloudWatch Logs Log Group名 | Log Group Name | `TBD` |
| CloudWatch Logs Log Group ARN | `CloudWatchLogsLogGroupArn` | `TBD` |
| CloudTrail配信用IAM Role名 | Role Name | `TBD` |
| CloudTrail配信用IAM Role ARN | `CloudWatchLogsRoleArn` | `TBD` |

確認観点:

- Log Group名が空欄の場合、コンソール自動表示値を使ってよいか確認する。
- Role名が空欄の場合、デフォルトRoleを使うか、現場命名規則Roleを作るか確認する。
- `KmsKeyId`や`.*key`系の値はCloudWatch Logs連携値ではなく暗号化関連値の可能性が高い。

### 4.2 CloudWatch Logs関連

| 確認項目 | 見る値 | 確認結果 |
| :--- | :--- | :--- |
| Log Group名 | Name | `TBD` |
| Log Group ARN | ARN | `TBD` |
| Log Class | Standard / Infrequent Access | `TBD` |
| Retention | 保持期間 | `TBD` |
| KMS Key | KMS Key ID / ARN | `TBD` |
| 既存Log Stream | CloudTrail用Log Stream有無 | `TBD` |
| 既存ログイベント | CloudTrail JSON到達有無 | `TBD` |
| 既存Metric Filter | 同等Filter有無 | `TBD` |

確認観点:

- Metric FilterはStandard log classのLog Groupで使用する。
- Log Groupが存在しても、CloudTrailイベントが届いているとは判断しない。
- CloudTrail形式のJSONイベント本文があることを確認する。

### 4.3 Metric Filter / Alarm関連

| 確認項目 | 4.5 | 4.7 |
| :--- | :--- | :--- |
| Metric Filter名 | `TBD` | `TBD` |
| Metric Namespace | `TBD` | `TBD` |
| Metric Name | `TBD` | `TBD` |
| Metric Value | `1` | `1` |
| Default Value | `0` | `0` |
| Dimension | 原則なし | 原則なし |
| Alarm名 | `TBD` | `TBD` |
| Statistic | `Sum` | `Sum` |
| Period | `300秒` | `300秒` |
| Evaluation Periods | `1` | `1` |
| Datapoints to Alarm | `1` | `1` |
| Threshold | `>= 1` | `>= 1` |
| Treat missing data | `notBreaching` | `notBreaching` |
| Alarm Action | 既存SNS Topic | 既存SNS Topic |

## 5. Filter Pattern確認

### 5.1 4.5 CloudTrail設定変更

```text
{($.eventName=CreateTrail) || ($.eventName=UpdateTrail) || ($.eventName=DeleteTrail) || ($.eventName=StartLogging) || ($.eventName=StopLogging)}
```

確認事項:

| 確認 | 内容 |
| :--- | :--- |
| Security Hub / CIS相当の基本Patternか | 余計な条件を混ぜていないか |
| `eventSource`条件を追加しない方針か | 監査準拠確認とズレないか |
| `PutEventSelectors`等を入れるか | 入れる場合は別Filterにするか |
| 実イベントテスト方法 | 本番Trail停止系操作をしないこと |

### 5.2 4.7 KMSキー無効化・削除予約

```text
{($.eventSource=kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}
```

確認事項:

| 確認 | 内容 |
| :--- | :--- |
| `eventSource=kms.amazonaws.com`が入っているか | KMS操作に限定するため |
| 対象イベントが`DisableKey`と`ScheduleKeyDeletion`か | 監査要件と一致するか |
| CloudTrailでKMSイベントが除外されていないか | 除外されていると検知できない |
| 実イベントテスト方法 | 本物のCMKを無効化・削除予約しないこと |

## 6. 権限確認

### 6.1 作業用アカウントで確認すること

作業用アカウントを受領済みの場合、レビュー前日に以下を確認する。

| 確認 | OK条件 |
| :--- | :--- |
| ログインできる | 対象AWSアカウントへ入れる |
| 対象Trailが見える | CloudTrail Trail詳細を表示できる |
| Trail編集画面へ入れる | 保存せずにCloudWatch Logs連携欄を確認できる |
| Log Groupが見える | CloudWatch Logsで対象Log Groupを確認できる |
| Log Streamが見える | CloudTrail用Log Streamを確認できる |
| Metric Filter作成画面へ入れる | 作成画面に到達できる |
| Alarm作成画面へ入れる | 作成画面に到達できる |
| SNS Topicが見える | 既存TopicとSubscriptionを確認できる |
| IAM Roleが見える | CloudTrail配信用Role候補を確認できる |

注意:

- 作業前確認では保存ボタンを押さない。
- 画面に入れることと保存できることは別である。
- IAM Role欄が空欄の場合、Role未作成またはIAM参照権限不足の可能性がある。

### 6.2 担当者へ確認依頼する権限

| 区分 | 必要Action | 用途 |
| :--- | :--- | :--- |
| CloudTrail参照 | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrail`, `cloudtrail:GetTrailStatus`, `cloudtrail:GetEventSelectors` | Trail確認 |
| CloudTrail変更 | `cloudtrail:UpdateTrail` | CloudWatch Logs連携設定 |
| CloudWatch Logs参照 | `logs:DescribeLogGroups`, `logs:DescribeLogStreams`, `logs:FilterLogEvents` | Log Group / Log Stream / ログ確認 |
| Metric Filter | `logs:DescribeMetricFilters`, `logs:PutMetricFilter`, `logs:TestMetricFilter` | Filter確認・作成・構文テスト |
| CloudWatch Alarm | `cloudwatch:DescribeAlarms`, `cloudwatch:PutMetricAlarm` | Alarm確認・作成 |
| IAM Role参照 | `iam:ListRoles`, `iam:GetRole`, `iam:ListRolePolicies`, `iam:GetRolePolicy`, `iam:ListAttachedRolePolicies` | Role確認 |
| IAM Role利用 | `iam:PassRole` | CloudTrailへ配信用Roleを指定 |
| SNS参照 | `sns:ListTopics`, `sns:GetTopicAttributes`, `sns:ListSubscriptionsByTopic` | 通知先確認 |

条件付き権限:

| 条件 | 必要Action |
| :--- | :--- |
| Log Groupを新規作成する | `logs:CreateLogGroup`, `logs:PutRetentionPolicy` |
| Log GroupにKMS Keyを関連付ける | `logs:AssociateKmsKey` |
| IAM Roleを新規作成する | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy` |
| 切り戻しでFilter/Alarmを削除する | `logs:DeleteMetricFilter`, `cloudwatch:DeleteAlarms` |

## 7. CloudTrail -> CloudWatch Logs連携確認

レビュー前日に以下を整理する。

| 確認 | 観点 |
| :--- | :--- |
| 既存Log Groupを使うか | パラメータシート記載値と一致するか |
| 新規Log Groupを作るか | 命名規則、Retention、KMS暗号化が決まっているか |
| IAM Role名 | デフォルトRoleか現場命名規則Roleか |
| IAM Role作成者 | 作業者かインフラ/IAM担当か |
| 保存後確認 | `CloudWatchLogsLogGroupArn`と`CloudWatchLogsRoleArn`を確認するか |
| 配信確認 | Log StreamだけでなくCloudTrail JSON本文まで確認するか |
| 配信待機 | 数分待つ想定を手順に入れているか |

レビューで確認する文:

```text
CloudTrailからCloudWatch Logsへの連携について、既存ロググループを使用する方針でよいか。
IAM Roleはデフォルト名ではなく、現場命名規則に沿ったCloudTrail配信用Roleを使用する認識でよいか。
保存後はTrail詳細のCloudWatchLogsLogGroupArn、CloudWatchLogsRoleArn、CloudWatch Logsへのイベント到達を確認する。
```

## 8. 通知設定確認

| 確認事項 | 確認内容 |
| :--- | :--- |
| 既存SNS Topic名 | パラメータシートと一致するか |
| SNS Topic ARN | Alarm Actionに指定する値 |
| Subscription | メール、Teams、既存通知基盤など |
| 受信確認者 | 誰が通知到達を確認するか |
| 通知テスト時刻 | 業務影響や誤報扱いを避ける時間帯 |
| 通知本文 | Alarm名、状態、時刻、メトリクス名が確認できるか |
| 二重通知 | A-gate / EventBridgeと重複しないか |

注意:

- 既存SNS Topicを使う場合、他用途の通知先である可能性がある。
- 通知テスト前に、受信者へ事前周知する。
- Alarm Actionは状態遷移時に実行されるため、既にALARM状態のままでは再通知されない可能性がある。

## 9. A-gate / EventBridge確認

4.5/4.7がA-gate / EventBridge側で既存対応済みか、または新規CloudWatch Alarmで対応するかを確認する。

| 確認 | 内容 |
| :--- | :--- |
| 対応済み要件番号 | A-gate対応可否列と突合済みか |
| EventBridge Rule | 対象イベントのRuleがあるか |
| Event Pattern | 4.5/4.7のイベントを拾っているか |
| Target | A-gateや別アカウントへ送信しているか |
| 通知実績 | 実際に通知されている証跡があるか |
| 設計書反映 | 設計書、パラメータシート、実環境の差異があるか |
| PM判断 | 新規設定対象か、対応不要か |

PM回答がない場合の扱い:

```text
A-gate / EventBridge側の既存対応有無は確認中である。
4.5/4.7の先行作業はCloudWatch Alarm方式の共通パターン確認として進めるが、既存通知との二重通知が判明した場合は設定対象から除外する。
```

## 10. 切り戻し・残置方針

レビュー前日に必ず確認する。

| 判断 | 手順上の扱い |
| :--- | :--- |
| 検証環境の正式設定として残置 | 設定値、証跡、通知テスト結果を残す |
| 一時検証として切り戻し | Metric Filter、Alarm、必要に応じてCloudTrail連携を戻す |
| 判断未定 | レビュー確認事項として明示する |

切り戻し対象:

| 対象 | 切り戻し内容 |
| :--- | :--- |
| Metric Filter | 作成した4.5/4.7用Filterを削除 |
| CloudWatch Alarm | 作成した4.5/4.7用Alarmを削除 |
| Alarm Action | 必要に応じて無効化 |
| CloudTrail -> CloudWatch Logs連携 | 作業前が無効だった場合、戻すか確認 |
| IAM Role | 今回新規作成した場合、残置/削除を確認 |
| Log Group | 新規作成した場合、残置/削除を確認 |

## 11. 証跡取得項目

レビューで「何を証跡として取るか」を確認する。

| タイミング | 証跡 |
| :--- | :--- |
| 作業前 | Trail詳細、CloudWatch Logs連携状態、Log Group、IAM Role、既存Metric Filter、既存Alarm、SNS Topic |
| 設定後 | Trail詳細、CloudWatch Logs連携、Role ARN、Metric Filter、Alarm、Alarm Action |
| 配信確認 | CloudWatch LogsのLog Stream、CloudTrail JSONイベント |
| 通知確認 | Alarm状態、通知メール/Teams、通知時刻、受信確認者 |
| 切り戻し後 | 作成物削除後の状態、Trail連携状態、Alarm/Filter不存在 |
| 権限不足時 | エラー画面、CloudTrail AccessDeniedイベント、依頼内容 |

スクリーンショットの注意:

- アカウントID、メールアドレス、IPアドレス、顧客名が写る場合は公開資料に含めない。
- 現場提出用と公開用を分ける。
- 画面全体ではなく、対象設定が分かる範囲を取得する。

## 12. 公式根拠URL

レビューで聞かれた時に提示する。

| 論点 | 公式URL |
| :--- | :--- |
| CloudTrail -> CloudWatch Logs連携 | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html |
| CloudTrail配信用IAM Role Policy | https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html |
| Metric Filter | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html |
| Filter Pattern | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html |
| CloudWatch Alarm | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html |
| Alarm Action | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarm-actions.html |
| 欠落データ処理 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html |
| CloudWatch Logs KMS暗号化 | https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html |

## 13. レビューで確認する質問一覧

そのままレビューに持ち込む確認事項である。

```text
4.5/4.7の先行作業は、検証環境でCloudWatch Alarm方式の共通パターンを確認する位置付けでよいか。
```

```text
CloudTrail -> CloudWatch Logs連携が未設定の場合、今回の先行作業で有効化してよいか。
```

```text
CloudWatch Logs連携先Log Groupは、パラメータシート記載値を使用する方針でよいか。
空欄の場合は、コンソール自動表示値または現場命名規則に沿った値を採用する必要があるか。
```

```text
CloudTrail配信用IAM Roleは、デフォルト名CloudTrail_CloudWatchLogs_Roleではなく、現場命名規則に沿ったRole名で作成する認識でよいか。
```

```text
IAM Role作成は作業者が行うのか、インフラ/IAM担当に事前作成を依頼するのか。
```

```text
作業用アカウントには、cloudtrail:UpdateTrail、logs:PutMetricFilter、cloudwatch:PutMetricAlarm、iam:PassRoleが付与される認識でよいか。
```

```text
通知先は既存SNS Topicを使用する認識でよいか。
通知テスト時の受信確認者と事前周知先は誰か。
```

```text
設定変更テスト後、検証環境の設定は残置するか、切り戻すか。
```

```text
A-gate / EventBridgeで既存対応済みの要件と、今回新規設定する要件の切り分けはどの判断を正とするか。
```

```text
作業証跡として取得すべきスクリーンショット、通知メール、設定画面、エラー画面の範囲はこれでよいか。
```

## 14. レビューでの冒頭説明

```text
本資料は、4.5/4.7先行作業のレビュー前日確認事項である。
今回の作業は、CloudTrailのManagement EventをCloudWatch Logsへ連携し、Metric Filter、CloudWatch Alarm、既存SNS Topic通知で検知する共通パターンの確認を目的とする。

特にCloudTrail -> CloudWatch Logs連携、CloudTrail配信用IAM Role、作業用アカウント権限、通知先、設定後の残置/切り戻し方針は作業前提となる。
未確定事項は作業前確認事項として明示している。
```

## 15. 前日最終チェック

| チェック | 状態 |
| :--- | :--- |
| 4.5/4.7が先行作業対象である | `未/済` |
| 検証環境で実施する | `未/済` |
| 作業用アカウントの払い出し予定を確認した | `未/済` |
| 作業用アカウントの権限確認依頼を出した | `未/済` |
| CloudTrail -> CloudWatch Logs連携方針を確認した | `未/済` |
| Log Group名をパラメータシートで確認した | `未/済` |
| IAM Role名と作成者を確認した | `未/済` |
| `iam:PassRole`の要否を確認した | `未/済` |
| Metric Filter Patternを確認した | `未/済` |
| Alarm設定値を確認した | `未/済` |
| SNS Topicと受信確認者を確認した | `未/済` |
| A-gate / EventBridge重複有無を確認した | `未/済` |
| 残置/切り戻し方針を確認した | `未/済` |
| 証跡取得項目を確認した | `未/済` |
| 公式根拠URLを手元に用意した | `未/済` |
