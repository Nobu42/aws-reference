# CloudTrail -> CloudWatch Logs連携 確認事項・懸念点整理

作成日: 2026-07-18

本資料は、要件4.5「CloudTrail設定変更監視」および要件4.7「カスタマー管理KMSキーの無効化・削除予約監視」の先行作業において、CloudTrailからCloudWatch Logsへの連携設定で確認すべき事項、懸念点、作業時の注意点を整理するものである。

4番台のMetric Filter方式は、CloudTrailイベントがCloudWatch Logsへ届くことを前提とする。  
そのため、CloudTrail -> CloudWatch Logs連携の作り方が確定しない限り、Metric Filter、CloudWatch Alarm、通知設定の作業は成立しない。

## 1. 現時点の見立て

| 項目 | 状況 | 判断 |
| :--- | :--- | :--- |
| CloudWatch Logsロググループ | 存在する | 入れ物は存在する |
| CloudTrail側のCloudWatch Logs連携 | 未設定または未確認 | Trail詳細で確認が必要 |
| CloudTrail配信用IAM Role | 存在しない、または未確認 | 保存時に作成される想定か確認が必要 |
| パラメータシート | CloudWatch Logs連携値が空欄に見える | 正式設計値が未記載の可能性 |
| Metric Filter方式 | CloudTrail -> CloudWatch Logs連携が前提 | 連携未成立なら作成しても検知しない |

「ロググループがある」だけでは、CloudTrailからCloudWatch Logsへイベントが配信されているとは判断しない。  
Trail側に以下の2つが設定され、実際にログイベントが届いて初めて連携済みと判断する。

```text
CloudWatchLogsLogGroupArn
CloudWatchLogsRoleArn
```

## 2. はっきりさせるべきこと

| No. | 確認事項 | 理由 |
| :--- | :--- | :--- |
| 1 | 対象Trailはどれか | Metric Filterの元ログが決まらない |
| 2 | 対象TrailはManagement Eventを記録しているか | 4.5/4.7の監視対象イベントが届かない可能性がある |
| 3 | CloudWatch Logs連携を今回追加してよいか | Trail設定変更に該当するため作業承認が必要 |
| 4 | 既存ロググループを使うか、新規ロググループを作るか | パラメータシート、保持期間、KMS暗号化、命名規則と関係する |
| 5 | コンソールで自動表示されるロググループ名を採用してよいか | AWSの候補表示と正式設計値が一致するとは限らない |
| 6 | IAM Roleはデフォルト名でよいか、現場命名規則に合わせるか | 金融現場では命名規則・権限設計との整合が重要 |
| 7 | IAM Roleを作業者が作成してよいか | `iam:CreateRole`、`iam:PutRolePolicy`、`iam:PassRole`が必要になる |
| 8 | 保存後にデフォルトRoleが自動作成・設定される前提でよいか | Role欄が空欄表示の場合、作業時の判断点になる |
| 9 | ロググループの保持期間は何日か | 監査証跡・運用要件・費用に関係する |
| 10 | ロググループにKMS暗号化が必要か | 3.5/3.6のCMK対応と関係する可能性がある |
| 11 | 既存EventBridge / A-gateと二重通知にならないか | 同じイベントで複数通知が出る可能性がある |
| 12 | 設定変更テスト後に残置するか切り戻すか | 検証環境の正式設定にするか一時検証にするかで手順が変わる |

## 3. パラメータシートで見るべき値

### 3.1 CloudTrail -> CloudWatch Logs連携そのもの

| 見る値 | 意味 | 空欄の場合 |
| :--- | :--- | :--- |
| `CloudWatchLogsLogGroupArn` | CloudTrailイベントの配信先Log Group ARN | CloudWatch Logs連携未設定の可能性 |
| `CloudWatchLogsRoleArn` | CloudTrailがCloudWatch Logsへ書き込むために使用するIAM Role ARN | CloudWatch Logs連携未設定の可能性 |
| CloudWatch Logs Log Group Name | 連携先ロググループ名 | 新規作成または正式値確認が必要 |
| CloudWatch Logs Role Name | 配信用IAM Role名 | 新規作成または正式値確認が必要 |

### 3.2 `.*key`系の値

`.*key`、`kmsKeyId`、`KmsKeyId`、`kms_key_id`、`log_group_kms_key_id`のような値は、CloudTrail -> CloudWatch Logs連携そのものではなく、暗号化に使うKMSキーを指す可能性が高い。

| 見る値 | 意味 |
| :--- | :--- |
| `KmsKeyId` | Trailのログファイル暗号化に使うKMSキー |
| `kmsKeyId` | サービスやIaC定義上のKMSキー指定 |
| `log_group_kms_key_id` | CloudWatch Logsロググループ暗号化に使うKMSキー |
| `cloudwatch_logs_kms_key_id` | CloudWatch Logs用KMSキー |

注意:

- `KmsKeyId`が空欄であることは、CloudTrail -> CloudWatch Logs連携が未設定である証拠ではない。
- `KmsKeyId`が空欄である場合、3.5「CloudTrailログのCMK暗号化」やCloudWatch Logs暗号化要件との関係を確認する。
- 連携有無は、`CloudWatchLogsLogGroupArn`と`CloudWatchLogsRoleArn`で判断する。

### 3.3 `identity`系の値

`userIdentity`、`identity`、`principal`のような値は、CloudTrailログ内の「誰が操作したか」を示す項目である可能性が高い。  
CloudTrail -> CloudWatch Logs連携の設定値ではなく、通知本文、調査項目、Metric Filter拡張条件で使う項目として扱う。

| 値 | 意味 |
| :--- | :--- |
| `userIdentity.type` | `IAMUser`、`AssumedRole`、`Root`などの操作主体種別 |
| `userIdentity.arn` | 操作主体のARN |
| `userIdentity.userName` | IAMユーザー名 |
| `principalId` | AWS内部の操作主体ID |

## 4. Webコンソールでの確認箇所

### 4.1 Trail側

```text
CloudTrail
  -> 証跡
  -> 対象Trailを選択
  -> CloudWatch Logs欄
  -> 編集
```

確認する項目:

| 項目 | 確認内容 |
| :--- | :--- |
| CloudWatch Logs | 有効か無効か |
| ロググループ | ロググループ名またはARNが表示されているか |
| IAMロール | Role名またはRole ARNが表示されているか |
| 保存後のTrail詳細 | `CloudWatchLogsLogGroupArn`相当の値が入っているか |
| 保存後のTrail詳細 | `CloudWatchLogsRoleArn`相当の値が入っているか |

### 4.2 CloudWatch Logs側

```text
CloudWatch
  -> ログ
  -> ロググループ
  -> 対象ロググループ
```

確認する項目:

| 項目 | 確認内容 |
| :--- | :--- |
| ロググループ名 | パラメータシートまたは作業手順書と一致するか |
| 保持期間 | 設計値と一致するか |
| KMSキー | 暗号化要件と一致するか |
| ログストリーム | CloudTrail用ログストリームが作成されているか |
| ログイベント | CloudTrailイベントが実際に届いているか |
| Metric Filter | 4.5/4.7用Filter作成先として正しいか |

### 4.3 IAM側

```text
IAM
  -> ロール
  -> CloudTrail_CloudWatchLogs_Role または承認済みRole名
```

確認する項目:

| 項目 | 確認内容 |
| :--- | :--- |
| Role名 | 命名規則に合っているか |
| 信頼関係 | `cloudtrail.amazonaws.com`がAssumeRoleできるか |
| 権限ポリシー | 対象Log Groupへ書き込み可能か |
| Resource | 対象Log GroupのARNに限定されているか |
| 作成日時 | 今回作業で作成されたものか、既存か |

## 5. IAM Role欄が空欄の場合の扱い

AWS公式ドキュメントでは、CloudTrailからCloudWatch Logsへ配信するIAM Roleとして、デフォルトで`CloudTrail_CloudWatchLogs_Role`が指定される旨が記載されている。

ただし、作業画面で「新規」を選んでも「既存」を選んでもIAM Role欄が空欄の場合、空欄のまま保存してよいと独自判断しない。

考えられる原因:

| 原因 | 内容 |
| :--- | :--- |
| 画面表示 | 候補Roleが読み込まれていない |
| 権限不足 | IAM Role一覧参照権限がない |
| 権限不足 | IAM Role作成権限がない |
| 権限不足 | CloudTrailにRoleを渡す`iam:PassRole`権限がない |
| 既存Roleなし | CloudTrail配信用Roleがまだ作成されていない |
| 保存時作成 | 保存時にデフォルトRoleが作成される画面仕様 |

作業時の扱い:

```text
IAM Role欄が空欄の場合は作業を一時停止し、
空欄のまま保存してよいか承認者へ確認する。

保存を実施した場合は、保存後にTrail詳細、IAM Role実体、CloudWatch Logs配信状況を確認する。
```

保存後の確認:

| 確認 | OK条件 |
| :--- | :--- |
| Trail詳細 | CloudWatch Logs Log Group ARNが設定されている |
| Trail詳細 | CloudWatch Logs Role ARNが設定されている |
| IAM Role | Roleが存在する |
| IAM Role信頼関係 | `cloudtrail.amazonaws.com`を信頼している |
| IAM Role権限 | `logs:CreateLogStream`、`logs:PutLogEvents`が許可されている |
| CloudWatch Logs | 数分後にCloudTrailイベントが届く |

## 6. 作業に必要な権限

作業用アカウントの権限が不足している場合、Webコンソール上で項目が表示されない、プルダウンが空になる、保存できない、テストできない、といった事象が発生する。

権限は大きく以下の2種類に分けて確認する。

| 区分 | 誰に必要か | 目的 |
| :--- | :--- | :--- |
| 作業者権限 | 作業用アカウント、作業用Role | Webコンソールで確認、作成、更新、テストを実施するため |
| 配信用IAM Role権限 | CloudTrailがAssumeRoleするIAM Role | CloudTrailがCloudWatch Logsへログを書き込むため |

この2つは別物である。  
作業者にCloudWatch LogsやCloudTrailを操作する権限があっても、CloudTrail配信用IAM Roleに書き込み権限がなければログ配信は失敗する。

### 6.1 参照確認に必要な権限

現状調査、レビュー前確認、作業前確認で必要になる権限である。

| 確認対象 | 必要になり得る権限 | 確認内容 |
| :--- | :--- | :--- |
| CloudTrail Trail | `cloudtrail:DescribeTrails`, `cloudtrail:GetTrail`, `cloudtrail:GetTrailStatus` | Trail名、Home Region、CloudWatch Logs連携、配信状態 |
| Event Selector | `cloudtrail:GetEventSelectors` | Management Event、Read/Write、KMS除外有無 |
| CloudWatch Logs Log Group | `logs:DescribeLogGroups`, `logs:DescribeLogStreams` | Log Group存在、Retention、Log Stream |
| CloudWatch Logsイベント | `logs:FilterLogEvents` | CloudTrailイベント到達確認 |
| Metric Filter | `logs:DescribeMetricFilters` | 既存Filter有無、重複確認 |
| CloudWatch Alarm | `cloudwatch:DescribeAlarms` | 既存Alarm有無、通知先確認 |
| SNS Topic | `sns:ListTopics`, `sns:GetTopicAttributes`, `sns:ListSubscriptionsByTopic` | 通知先Topic、Subscription、利用可否 |
| IAM Role | `iam:ListRoles`, `iam:GetRole`, `iam:ListRolePolicies`, `iam:GetRolePolicy`, `iam:ListAttachedRolePolicies` | CloudTrail配信用Roleの存在、信頼関係、権限 |
| IAM Policy | `iam:GetPolicy`, `iam:GetPolicyVersion` | 管理ポリシー利用時の権限内容 |
| KMS Key | `kms:ListAliases`, `kms:DescribeKey`, `kms:GetKeyPolicy` | Log Group暗号化やTrailログ暗号化に関係するCMK確認 |

注意:

- Webコンソールのプルダウン表示には、`List*`や`Describe*`系権限が必要になることがある。
- 既存IAM Roleを選ぶ画面が空欄の場合、Roleが存在しないだけでなく、IAM参照権限不足の可能性もある。

### 6.2 設定変更に必要な権限

CloudTrail -> CloudWatch Logs連携、Metric Filter、Alarm、通知設定を作る場合に必要になる権限である。

| 作業 | 必要になり得る権限 | 注意 |
| :--- | :--- | :--- |
| CloudTrailへCloudWatch Logs連携を設定 | `cloudtrail:UpdateTrail` | Trail設定変更に該当する |
| 既存IAM RoleをCloudTrailへ指定 | `iam:PassRole` | `cloudtrail.amazonaws.com`へ渡すRoleに限定する |
| Log Group作成 | `logs:CreateLogGroup` | 既存Log Groupを使う場合は不要 |
| Retention設定 | `logs:PutRetentionPolicy` | 保持期間の設計値確認が必要 |
| Log GroupへのKMSキー関連付け | `logs:AssociateKmsKey` | KMS暗号化要件がある場合のみ |
| Metric Filter作成 | `logs:PutMetricFilter` | 4.5/4.7の検知条件を設定する |
| Metric Filter削除 | `logs:DeleteMetricFilter` | 切り戻し時に必要 |
| Alarm作成・更新 | `cloudwatch:PutMetricAlarm` | Alarm ActionにSNS Topicを指定する |
| Alarm削除 | `cloudwatch:DeleteAlarms` | 切り戻し時に必要 |
| Alarm Action有効化・無効化 | `cloudwatch:EnableAlarmActions`, `cloudwatch:DisableAlarmActions` | 通知テストや切り戻しで使う可能性 |
| SNS TopicをAlarm Actionに指定 | `sns:Publish`ではなく、Alarm側のAction設定権限が中心 | 通常のAlarm通知ではCloudWatchがSNSへ通知する |

注意:

- SNS Topic自体を新規作成する場合は、`sns:CreateTopic`、`sns:Subscribe`、`sns:SetTopicAttributes`等が追加で必要になる。
- 既存Topicを使う前提なら、Topic新規作成権限は原則不要である。
- 切り戻しを手順に含める場合、作成権限だけでなく削除権限も確認する。

### 6.3 IAM Roleを新規作成する場合に必要な権限

CloudTrail配信用IAM Roleが存在しない場合、またはデフォルトRoleを作成する場合に必要になる。

| 作業 | 必要になり得る権限 | 内容 |
| :--- | :--- | :--- |
| IAM Role作成 | `iam:CreateRole` | CloudTrailがAssumeRoleするRoleを作成する |
| Inline Policy付与 | `iam:PutRolePolicy` | CloudWatch Logs書き込み権限をRoleへ付与する |
| 管理ポリシー付与 | `iam:AttachRolePolicy` | 管理ポリシー方式の場合 |
| Role確認 | `iam:GetRole`, `iam:GetRolePolicy` | 作成後の確認 |
| Role削除 | `iam:DeleteRole`, `iam:DeleteRolePolicy`, `iam:DetachRolePolicy` | 切り戻しでRole削除まで行う場合 |
| RoleをCloudTrailへ渡す | `iam:PassRole` | CloudTrailの設定保存時に必要 |

注意:

- IAM Role作成は権限管理上、作業者ではなくインフラ担当またはIAM管理担当が実施する場合がある。
- IAM Roleを作業者が作らない方針の場合、作業前にRole名、Role ARN、信頼ポリシー、権限ポリシーを提示して作成依頼する。
- `iam:PassRole`が不足すると、Role自体が存在していてもCloudTrailへ設定できない。

### 6.4 CloudTrail配信用IAM Roleに必要な権限

これは作業者権限ではなく、CloudTrailがAssumeRoleするIAM Roleに付与する権限である。

信頼関係の要点:

```text
Principal: cloudtrail.amazonaws.com
Action: sts:AssumeRole
```

権限ポリシーの要点:

```text
logs:CreateLogStream
logs:PutLogEvents
```

対象Resource:

```text
arn:aws:logs:<region>:<account-id>:log-group:<log-group-name>:log-stream:<account-id>_CloudTrail_<region>*
```

注意:

- Resourceは対象Log GroupのLog Streamに限定する。
- Organization Trailの場合、アカウントIDやLog Stream名の扱いが変わる可能性がある。
- Log GroupへKMS暗号化を設定する場合、CloudWatch LogsサービスがKMSキーを使えるKey Policyも確認する。

### 6.5 Metric Filter構文テストに必要な権限

CLIでFilter Patternをテストする場合、以下が必要になる。

```text
logs:TestMetricFilter
```

`logs:TestMetricFilter`は、実際のMetric Filterを作成せず、指定したログイベント文字列にFilter Patternが一致するか確認するAPIである。

権限不足時の典型例:

```text
Forbidden
AccessDeniedException
not authorized to perform: logs:TestMetricFilter
```

この権限がない場合の代替:

| 代替手段 | 内容 |
| :--- | :--- |
| WebコンソールのPattern Test | Metric Filter作成画面でサンプルJSONを使って確認する |
| 権限者による代行確認 | 権限を持つ担当者にFilter Patternテストを依頼する |
| 検証環境当日の確認 | 実作業アカウント払い出し後に再確認する |
| 机上確認 | Security Hub/CIS相当のFilter Patternと照合する |

### 6.6 権限不足時の見え方

| 事象 | 考えられる不足権限 |
| :--- | :--- |
| Trail詳細が見えない | `cloudtrail:GetTrail`, `cloudtrail:DescribeTrails` |
| CloudWatch Logs連携を保存できない | `cloudtrail:UpdateTrail` |
| IAM Role欄が空欄 | `iam:ListRoles`, `iam:GetRole`不足、またはRole未作成 |
| 既存Roleを選べるが保存できない | `iam:PassRole`不足 |
| Log Group一覧が見えない | `logs:DescribeLogGroups` |
| Log Streamが見えない | `logs:DescribeLogStreams` |
| ログイベントを検索できない | `logs:FilterLogEvents` |
| Metric Filterを作成できない | `logs:PutMetricFilter` |
| Pattern TestがForbidden | `logs:TestMetricFilter` |
| Alarmを作成できない | `cloudwatch:PutMetricAlarm` |
| 既存SNS Topicが選べない | `sns:ListTopics`, `sns:GetTopicAttributes` |

### 6.7 作業日前に自分で権限を確認できる場合

作業用アカウントでIAM権限を参照できる場合、以下の順で確認する。

#### 6.7.1 自分がどの主体でログインしているか確認する

AWSコンソール右上のアカウント表示、またはIAM画面で、現在の操作主体を確認する。

| ログイン形態 | 確認する対象 |
| :--- | :--- |
| IAMユーザー | IAM User名、所属Group、直接付与Policy |
| AssumeRole | IAM Role名、Roleに付与されたPolicy |
| IAM Identity Center / SSO | Permission Set、割り当て先AWSアカウント、割り当てRole |
| スイッチロール | スイッチ後のRole名、Roleに付与されたPolicy |

CLIを使える場合は、以下で操作主体を確認できる。

```bash
aws sts get-caller-identity
```

確認する値:

| 値 | 見方 |
| :--- | :--- |
| `Arn` | IAM UserかAssumedRoleかを見る |
| `Account` | 対象AWSアカウントが正しいかを見る |
| `UserId` | 操作主体の内部ID |

#### 6.7.2 IAM画面で付与Policyを確認する

```text
IAM
  -> ユーザー または ロール
  -> 対象User/Role
  -> 許可
```

確認する項目:

| 確認項目 | 内容 |
| :--- | :--- |
| 直接付与Policy | User/Roleに直接付与されたPolicy |
| Group経由Policy | IAM Userが所属するGroup経由のPolicy |
| Permission Boundary | 境界ポリシーで許可範囲が制限されていないか |
| 明示的Deny | `Deny`がないか |
| Resource制限 | 対象Trail、Log Group、Role、SNS Topicに限定されすぎていないか |
| Condition制限 | MFA、SourceIp、PrincipalArn等の条件で作業時に拒否されないか |

注意:

- `Allow`があっても、Permission Boundary、SCP、明示的Denyで拒否される場合がある。
- IAM画面でPolicyが見えても、OrganizationsのSCPまでは見えない場合がある。
- IAM Identity Center利用時は、Permission Set側で許可されているか確認する。

#### 6.7.3 IAM Policy Simulatorで確認する

IAM Policy Simulatorを利用できる場合、作業用User/Roleを選択し、以下のActionをSimulationする。

| サービス | SimulationするAction |
| :--- | :--- |
| CloudTrail | `DescribeTrails`, `GetTrail`, `GetTrailStatus`, `GetEventSelectors`, `UpdateTrail` |
| CloudWatch Logs | `DescribeLogGroups`, `DescribeLogStreams`, `FilterLogEvents`, `PutMetricFilter`, `DeleteMetricFilter`, `TestMetricFilter` |
| CloudWatch | `DescribeAlarms`, `PutMetricAlarm`, `DeleteAlarms`, `EnableAlarmActions`, `DisableAlarmActions` |
| IAM | `ListRoles`, `GetRole`, `GetRolePolicy`, `ListRolePolicies`, `PassRole` |
| SNS | `ListTopics`, `GetTopicAttributes`, `ListSubscriptionsByTopic` |
| KMS | `ListAliases`, `DescribeKey`, `GetKeyPolicy` |

`iam:PassRole`を確認する場合、対象ResourceはCloudTrail配信用IAM Roleに限定し、`iam:PassedToService`が`cloudtrail.amazonaws.com`となる条件も確認する。

#### 6.7.4 Webコンソールで作業画面まで進める

事前に保存や作成を実行しない範囲で、作業画面へ到達できるか確認する。

| 確認画面 | 確認内容 |
| :--- | :--- |
| CloudTrail Trail詳細 | 対象Trailが見える |
| CloudTrail編集画面 | CloudWatch Logs連携項目が見える |
| CloudTrail編集画面 | Log Group候補が表示される |
| CloudTrail編集画面 | IAM Role候補が表示される、または新規作成項目が表示される |
| CloudWatch Logs | 対象Log Groupが見える |
| CloudWatch Logs | Metric Filter作成画面に入れる |
| CloudWatch Alarm | Alarm作成画面に入れる |
| SNS | 既存TopicとSubscriptionが見える |
| IAM | CloudTrail配信用Roleを確認できる |

注意:

- 「画面に入れる」ことと「保存できる」ことは別である。
- 保存可否は`UpdateTrail`、`PutMetricFilter`、`PutMetricAlarm`、`iam:PassRole`等に依存する。
- 事前確認では、承認前に保存ボタンを押さない。

#### 6.7.5 権限不足をCloudTrailで確認する

操作に失敗した場合、CloudTrail Event Historyで失敗イベントを確認する。

見る項目:

| 項目 | 内容 |
| :--- | :--- |
| `eventName` | 失敗したAPI名 |
| `errorCode` | `AccessDenied`、`AccessDeniedException`等 |
| `errorMessage` | 不足しているActionの手掛かり |
| `userIdentity.arn` | どのUser/Roleで失敗したか |
| `eventTime` | 失敗時刻 |

証跡として残す内容:

```text
対象画面
実施操作
エラー表示
CloudTrailの失敗イベント
不足している可能性があるAction
```

### 6.8 自分で権限を見られない場合の依頼用一覧表

作業者がIAM権限やPermission Setを確認できない場合、IAM管理担当、インフラ担当、または権限管理担当へ以下を確認依頼する。

依頼文例:

```text
要件4.5/4.7の先行作業として、CloudTrail -> CloudWatch Logs連携、Metric Filter、CloudWatch Alarm、既存SNS Topic指定を検証環境で実施する。
作業日前に、作業用アカウントまたは作業用Roleに以下の権限が付与されているか確認したい。
IAM Roleを作業者が作成しない方針の場合は、CloudTrail配信用IAM Roleの事前作成と、作業者へのiam:PassRole付与可否を確認したい。
```

#### 6.8.1 必須権限

既存Log Group、既存SNS Topicを使用し、Metric FilterとAlarmを作成する場合の基本権限である。

| 区分 | 必要Action | 用途 | 備考 |
| :--- | :--- | :--- | :--- |
| CloudTrail参照 | `cloudtrail:DescribeTrails` | Trail一覧・設定確認 | 参照 |
| CloudTrail参照 | `cloudtrail:GetTrail` | Trail詳細確認 | 参照 |
| CloudTrail参照 | `cloudtrail:GetTrailStatus` | Trail配信状態確認 | 参照 |
| CloudTrail参照 | `cloudtrail:GetEventSelectors` | Management Event記録有無確認 | 参照 |
| CloudTrail変更 | `cloudtrail:UpdateTrail` | CloudWatch Logs連携設定 | 設定変更 |
| CloudWatch Logs参照 | `logs:DescribeLogGroups` | Log Group確認 | 参照 |
| CloudWatch Logs参照 | `logs:DescribeLogStreams` | Log Stream確認 | 参照 |
| CloudWatch Logs参照 | `logs:FilterLogEvents` | CloudTrailイベント到達確認 | 参照 |
| Metric Filter | `logs:DescribeMetricFilters` | 既存Filter確認 | 参照 |
| Metric Filter | `logs:PutMetricFilter` | 4.5/4.7用Filter作成 | 設定変更 |
| Metric Filter | `logs:TestMetricFilter` | Filter Pattern構文・一致確認 | テスト |
| CloudWatch Alarm | `cloudwatch:DescribeAlarms` | 既存Alarm確認 | 参照 |
| CloudWatch Alarm | `cloudwatch:PutMetricAlarm` | Alarm作成・更新 | 設定変更 |
| IAM Role参照 | `iam:ListRoles` | 既存Role候補確認 | 参照 |
| IAM Role参照 | `iam:GetRole` | Role詳細・信頼関係確認 | 参照 |
| IAM Role参照 | `iam:ListRolePolicies` | Inline Policy一覧確認 | 参照 |
| IAM Role参照 | `iam:GetRolePolicy` | Inline Policy内容確認 | 参照 |
| IAM Role参照 | `iam:ListAttachedRolePolicies` | 管理ポリシー確認 | 参照 |
| IAM Role利用 | `iam:PassRole` | CloudTrailへ配信用Roleを指定 | 対象Roleに限定 |
| SNS参照 | `sns:ListTopics` | 既存Topic確認 | 参照 |
| SNS参照 | `sns:GetTopicAttributes` | Topic属性確認 | 参照 |
| SNS参照 | `sns:ListSubscriptionsByTopic` | 通知先確認 | 参照 |

#### 6.8.2 条件付きで必要になる権限

作業方針によって必要になる権限である。

| 条件 | 必要Action | 用途 | 備考 |
| :--- | :--- | :--- | :--- |
| Log Groupを新規作成する | `logs:CreateLogGroup` | CloudTrail連携先Log Group作成 | 既存利用なら不要 |
| Retentionを設定する | `logs:PutRetentionPolicy` | 保持期間設定 | 設計値確認が必要 |
| Log GroupへKMS暗号化を設定する | `logs:AssociateKmsKey` | CMK関連付け | KMS要件がある場合 |
| Log GroupのKMS暗号化を外す | `logs:DisassociateKmsKey` | 切り戻し | 通常は不要 |
| IAM Roleを新規作成する | `iam:CreateRole` | CloudTrail配信用Role作成 | 作業者が作成する場合 |
| IAM RoleへInline Policyを付与する | `iam:PutRolePolicy` | Logs書き込み権限付与 | 作業者が作成する場合 |
| IAM Roleへ管理ポリシーを付与する | `iam:AttachRolePolicy` | 管理ポリシー方式 | 作業者が作成する場合 |
| KMS Keyを確認する | `kms:ListAliases`, `kms:DescribeKey`, `kms:GetKeyPolicy` | CMK要件確認 | 3.5/3.6と関係 |
| SNS Topicを新規作成する | `sns:CreateTopic`, `sns:Subscribe`, `sns:SetTopicAttributes` | 新規通知先作成 | 既存Topic利用なら原則不要 |

#### 6.8.3 切り戻しに必要な権限

作成後に切り戻す場合、削除や無効化の権限も必要になる。

| 切り戻し対象 | 必要Action | 備考 |
| :--- | :--- | :--- |
| Metric Filter | `logs:DeleteMetricFilter` | 作成したFilterのみ削除 |
| CloudWatch Alarm | `cloudwatch:DeleteAlarms` | 作成したAlarmのみ削除 |
| Alarm Action | `cloudwatch:DisableAlarmActions`, `cloudwatch:EnableAlarmActions` | 通知停止・復旧で使用 |
| CloudTrail連携 | `cloudtrail:UpdateTrail` | CloudWatch Logs連携を元に戻す場合 |
| IAM Role Inline Policy | `iam:DeleteRolePolicy` | 作成したInline Policyを削除する場合 |
| IAM Role | `iam:DeleteRole` | 作成したRoleを削除する場合 |

#### 6.8.4 CloudTrail配信用IAM Roleに付与する権限

CloudTrail配信用IAM Roleを事前作成してもらう場合、以下を依頼する。

信頼ポリシー:

```text
Principal: cloudtrail.amazonaws.com
Action: sts:AssumeRole
```

権限ポリシー:

```text
logs:CreateLogStream
logs:PutLogEvents
```

Resourceの考え方:

```text
対象Log Group配下のCloudTrail用Log Streamに限定する。
```

依頼時の確認項目:

| 確認項目 | 内容 |
| :--- | :--- |
| Role名 | 現場命名規則に合っているか |
| Role ARN | CloudTrail設定時に指定する値 |
| 信頼ポリシー | `cloudtrail.amazonaws.com`を信頼しているか |
| 権限ポリシー | 対象Log Groupへ書き込み可能か |
| `iam:PassRole`許可 | 作業者が当該RoleをCloudTrailへ渡せるか |

### 6.9 レビュー時の権限確認文

レビューでは以下を確認する。

```text
4.5/4.7の先行作業では、CloudTrail -> CloudWatch Logs連携、Metric Filter、CloudWatch Alarm、既存SNS Topic指定を実施する。
作業用アカウントには、参照権限に加え、cloudtrail:UpdateTrail、logs:PutMetricFilter、cloudwatch:PutMetricAlarm、iam:PassRoleが必要になる可能性がある。
IAM Roleを新規作成する場合は、iam:CreateRole、iam:PutRolePolicyも必要になる。
作業者がIAM Roleを作成しない方針の場合は、事前にCloudTrail配信用Roleの作成を依頼する。
```

## 7. 作業時の注意点

### 7.1 Log Group

- コンソールで自動表示されるロググループを正式値として採用する前に、パラメータシートと照合する。
- 既存ロググループを使う場合、保持期間、KMS暗号化、Log Classを確認する。
- 新規ロググループを作る場合、命名規則と保持期間を事前に確定する。
- CloudTrail連携用ロググループは、CloudTrailと同じアカウント内に存在する必要がある。

### 7.2 IAM Role

- デフォルトRole名を使うか、現場命名規則に合わせるかを作業前に確認する。
- 空欄のまま保存する場合は、保存後にRole ARNが設定されたことを必ず確認する。
- Roleの信頼ポリシーと権限ポリシーを証跡化する。
- Organization Trailの場合、Role Policyの手動修正が必要になる可能性がある。

### 7.3 配信確認

- CloudTrailイベントはCloudWatch Logsへ即時に届かない場合がある。
- 数分待ってからログストリーム、ログイベントを確認する。
- ログイベントが届かない場合、Metric FilterやAlarm作成に進まない。
- 配信確認は、CloudTrail Event HistoryだけでなくCloudWatch Logs側で行う。

### 7.4 テスト後の扱い

- 検証環境の正式設定として残置するか、一時検証として切り戻すかを作業前に決める。
- 残置する場合、設定値、証跡、通知テスト結果を残す。
- 切り戻す場合、CloudWatch Logs連携、Metric Filter、Alarm、通知設定のどこまで戻すかを明確にする。

## 8. レビューで確認する質問

レビュー時は以下を確認する。

```text
CloudTrailからCloudWatch Logsへの連携について、
既存ロググループを使用する方針でよいか。
```

```text
CloudTrailのCloudWatch Logs連携を有効化する際、
コンソールで自動表示されるロググループ名をそのまま使用してよいか。
```

```text
CloudTrail配信用IAM Roleは、
AWSコンソールのデフォルトRoleであるCloudTrail_CloudWatchLogs_Roleを使用してよいか。
それとも現場命名規則に沿ったRole名を指定する必要があるか。
```

```text
IAM Role欄が空欄表示となる場合、
空欄のまま保存し、保存後にデフォルトRoleが設定されたことを確認する進め方でよいか。
```

```text
CloudWatch Logs連携後、検証環境の設定は残置するか。
または動作確認後に切り戻すか。
```

```text
CloudWatch Logs連携、Metric Filter、Alarm、SNS通知の設定値は、
パラメータシートへ追記する対象か。
```

## 9. レビューでの説明文

レビューでは以下の説明を使用する。

```text
4.5/4.7のMetric Filter方式では、CloudTrailイベントがCloudWatch Logsへ配信されていることが前提となる。
現状はロググループは存在するが、Trail側のCloudWatch Logs連携設定および配信用IAM Roleが未設定または未確認に見える。
そのため、先行作業ではまずCloudTrail -> CloudWatch Logs連携の設定方法、使用するロググループ、IAM Role、保存後の確認方法を確定する。
```

```text
IAM Role欄が空欄表示となる場合、デフォルトRoleが保存時に作成・設定される可能性はある。
ただし、推測で完了扱いにせず、保存後にTrail詳細のCloudWatchLogsRoleArn、IAM Role実体、CloudWatch Logsへのイベント到達を確認する。
```

## 10. 参照URL

- [AWS CloudTrail: CloudWatch Logs へのイベントの送信](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/send-cloudtrail-events-to-cloudwatch-logs.html)
- [AWS CloudTrail: CloudTrail がモニタリングに CloudWatch Logs を使用するためのロールポリシードキュメント](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-required-policy-for-cloudwatch-logs.html)
