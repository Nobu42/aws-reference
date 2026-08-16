# 要件4.1～4.15 検証環境End-to-Endアラーム発報手順書

作成日: 2026-08-17

## 1. 目的

クラウドセキュリティ対応のうち、実際のアラート発報が求められている要件4.1～4.15について、検証環境で実AWSイベントを発生させ、次の経路をEnd-to-Endで確認する。

```text
AWS操作
  -> CloudTrail Management Event
  -> CloudWatch Logs
  -> Metric Filter
  -> Custom Metric
  -> CloudWatch Alarm
  -> SNS Topic
  -> メール / Teams / 監視基盤
```

既存A-gate対応済みとして正式承認された要件は、CloudWatch方式を重複作成せず、次の既存経路を確認する。

```text
AWS操作
  -> CloudTrail / EventBridge
  -> 別アカウントのEvent BusまたはA-gate管理経路
  -> 既存通知処理
  -> メール / Teams / 監視基盤
```

本手順はWebコンソール操作を前提とする。

## 2. 対象要件

実アラート発報の対象は、正式な評価シートのモニタリング要件4.1～4.15である。

| 要件 | 監視対象 | 代表実イベント |
| :--- | :--- | :--- |
| 4.1 | 不正なAPI呼び出し | テスト専用Bucketへの`PutBucketTagging`を明示的に拒否 |
| 4.2 | MFAなしコンソールログイン | MFA未登録の無権限テストIAMユーザーによる成功ログイン |
| 4.3 | rootアカウント使用 | 専用サンドボックスのrootユーザーによるMFAログイン |
| 4.4 | IAMポリシー変更 | 未アタッチのテスト用Customer managed policy作成 |
| 4.5 | CloudTrail設定変更 | 承認済み`UpdateTrail`またはテスト専用Trail作成 |
| 4.6 | コンソール認証失敗 | 無権限テストIAMユーザーでパスワードを1回だけ誤入力 |
| 4.7 | CMK無効化・削除予約 | 未使用テスト専用CMKの無効化と削除予約 |
| 4.8 | S3 Bucket Policy変更 | 空のテスト専用Bucketへ安全側のDeny Policyを設定 |
| 4.9 | AWS Config設定変更 | テスト専用Managed Config Rule作成 |
| 4.10 | Security Group変更 | 未関連付けSGへTCP 65535のテストルール追加 |
| 4.11 | NACL変更 | 未関連付けNACLへRule 200のテストEntry追加 |
| 4.12 | Network Gateway変更 | テスト専用Internet Gateway作成・テストVPCへAttach |
| 4.13 | Route Table変更 | 未関連付けRoute Tableへ`198.51.100.0/24`のRoute追加 |
| 4.14 | VPC変更 | 空のテスト専用VPC作成 |
| 4.15 | AWS Organizations変更 | 管理サンドボックスで空のテストOU作成 |

要件A3・A4は運用手順と日々のモニタリング運用、要件3.4～3.7はロギング設定の是正であり、本手順のアラーム発報対象には含めない。

## 3. 試験の成立条件

各要件について、最初に変更パラメータ一覧または正式な対応要否表から、`CloudWatch新規`または`A-gate既存`のどちらで確認するかを確定する。方式未確定の要件は試験しない。

共通成立条件:

1. 承認済みの実AWS操作を実施した。
2. CloudTrailで対象`eventName`、`eventTime`、`userIdentity`、対象リソースIDを確認した。
3. 確定した監視方式の経路で通知が到達した。
4. 必要な証跡を取得した。
5. テスト専用変更を戻し、またはテスト専用リソースを削除した。
6. 既存業務リソースへ変更がないことを確認した。

`CloudWatch新規`の追加成立条件:

1. 同じイベントがCloudTrail連携先CloudWatch Logs Log Groupへ到達した。
2. 対象Custom Metricに`Sum >= 1`のDatapointが生成された。
3. 対象Alarmが`OK -> ALARM`へ遷移した。
4. Alarm Historyに状態遷移と理由が記録された。
5. SNSからメール、Teamsまたは監視基盤へ通知が到達した。

`A-gate既存`の追加成立条件:

1. 対象EventBridge Ruleまたは連携元設定が実イベントと一致したことを確認した。
2. 別アカウントEvent Bus、Target、Dead-letter queue、再試行状態にエラーがないことを確認した。
3. A-gate側の処理記録または管理担当の確認結果から、対象イベントを受信したことを確認した。
4. A-gate経路からメール、Teamsまたは監視基盤へ通知が到達した。

手動の`SetAlarmState`は通知経路だけの確認であり、Metric Filterを含むEnd-to-End試験の代替にはしない。CloudWatch Logsへの擬似JSON投入も、CloudTrailが実操作を記録した証明にはしない。

## 4. 共通テスト値

`<...>`は作業前にパラメータシートまたは変更申請の値へ置き換える。

| 項目 | 値例 | 使用箇所 |
| :--- | :--- | :--- |
| システム略称 | `<SYSTEM>` | 全テストリソース名 |
| 変更申請番号 | `<CHANGE_ID>` | タグ、作業記録 |
| 対象アカウント | `<ACCOUNT_ID>` | 全要件 |
| 対象リージョン | `<REGION>` | 原則`ap-northeast-1`など設計値 |
| 作業日 | `<YYYYMMDD>` | リソース名、証跡名 |
| ネットワーク試験対象VPC | `<TEST_VPC_ID>` | 既存検証VPCまたは空のテストVPC |
| Purposeタグ | `alarm-test` | 全テストリソース |
| DeleteAfterタグ | `<YYYY-MM-DD>` | 削除漏れ防止 |
| テストVPC CIDR | `10.254.255.0/28` | 4.10～4.14 |
| SG/NACL送信元 | `192.0.2.0/24` | 4.10、4.11 |
| テストTCP Port | `65535` | 4.10、4.11 |
| NACL Rule number | `200` | 4.11 |
| テストRoute宛先 | `198.51.100.0/24` | 4.13 |
| KMS削除待機期間 | `7日` | 4.7 |

`192.0.2.0/24`と`198.51.100.0/24`は文書・試験用アドレスである。ただし、VPC CIDRを含め、現場のIPアドレス管理と重複確認を優先する。

## 5. 共通事前準備

### 5.1 承認と体制

1. 変更申請番号、承認者、実施者、確認者、切り戻し判断者を確認する。
2. 対象が検証アカウントであることを確認する。
3. 他チームの結合試験、性能試験、バッチ、運用試験と重ならない時間帯を確定する。
4. 通知確認者へ、テスト通知と削除・復旧操作による追加通知が発生することを連絡する。
5. A-gate、SCP、Permission Boundary、AWS Config、Security Hub、EventBridge、自動修復の有無を確認する。
6. テスト専用リソースの作成、変更、復旧、削除権限を確認する。

### 5.2 CloudTrail確認

1. AWS Management Consoleへログインする。
2. 画面右上のアカウントとリージョンを確認する。
3. CloudTrailコンソールの「証跡」を開く。
4. 対象TrailがLogging中であることを確認する。
5. Management Eventが記録対象であることを確認する。
6. 4.1でRead APIを使用する場合はRead Eventも記録対象であることを確認する。本手順の4.1はWrite APIの拒否を使用する。
7. IAM、root、Organizationsを確認する場合はGlobal service eventsが対象であることを確認する。
8. `CloudWatch新規`の場合、CloudWatch Logs Log Group ARNとCloudWatch Logs Role ARNを確認する。
9. `CloudWatch新規`の場合、Trail Statusに最新配信エラーがないことを確認する。

### 5.3 監視経路、Metric Filter、Alarm確認

1. 要件ごとの対応区分が`CloudWatch新規`または`A-gate既存`のどちらか確認する。
2. `CloudWatch新規`の場合、CloudWatch Logsで対象Log Groupを開く。
3. 対象要件のMetric Filterが存在することを確認する。
4. Filter Patternは[要件4番台 監視設定値一覧 設計パラメータ案](./requirements_4_x_monitoring_parameter_design_2026_07.md)と確定済みパラメータを突合する。
5. 代表的な最新CloudTrailイベントを開き、JSONがトップレベルに`eventName`、`eventSource`、`userIdentity`を持つことを確認する。
6. CloudWatch Alarmで対象Alarmを開く。
7. Namespace、Metric Name、Statistic、Period、Threshold、Evaluation periodsを確認する。
8. `Actions enabled`が有効であることを確認する。
9. Alarm Actionが承認済みSNS Topicであることを確認する。
10. 試験開始時のAlarm状態が`OK`であることを確認する。
11. SNS TopicのSubscriptionが`Confirmed`または有効であることを確認する。
12. `A-gate既存`の場合、対応要件番号、EventBridge Rule名、Event Pattern、Event Bus、Target ARN、送信先アカウント、通知先を正式資料と突合する。
13. EventBridge Ruleが`Enabled`であり、Target、Retry policy、Dead-letter queueに異常がないことを確認する。
14. 送信先が別アカウントの場合、受信確認担当者、確認方法、確認可能時刻を確定する。
15. `A-gate既存`の要件に同等のMetric FilterとAlarmを追加しない。

### 5.4 共通中止条件

次のいずれかに該当した場合は実イベントを起こさず中止する。

- アカウント、リージョン、Trailを一意に特定できない。
- `CloudWatch新規`で、Log Group、Alarm、SNS Topicを一意に特定できない。
- `CloudWatch新規`で、CloudTrailからCloudWatch Logsへの配信が停止またはエラーとなっている。
- `CloudWatch新規`で、Alarmが試験開始前から`ALARM`または`INSUFFICIENT_DATA`である。
- `A-gate既存`で、対応要件とRule、Target、通知先の対応関係を証明できない。
- テスト専用リソースと業務リソースを識別できない。
- A-gateまたはSCPによる明示的拒否を回避する変更が必要となる。
- 戻し手順、削除順序、確認者が未確定である。
- 既存業務リソースの停止、削除、無効化、経路変更が必要となる。

## 6. 各イベント後の共通確認

### 6.1 全方式共通

1. 操作時刻をJSTとUTCで記録する。
2. CloudTrailの「イベント履歴」を開く。
3. デフォルトの`読み取り専用=false`フィルターで見つからない場合はフィルターを解除する。
4. 「イベント名」で対象`eventName`を検索する。
5. Event recordで対象リソースID、テストPrincipal、成功または想定したAccessDeniedを確認する。

### 6.2 `CloudWatch新規`の確認

1. CloudWatch Logsの対象Log Groupで同じ`eventName`とリソースIDを検索する。
2. CloudWatchの「すべてのメトリクス」から対象NamespaceとMetricを開く。
3. `Sum`のDatapointが1以上であることを確認する。
4. 対象Alarmで`OK -> ALARM`を確認する。
5. Alarm Historyを開き、Datapointによる状態遷移であることを確認する。
6. SNS、メール、Teamsまたは監視基盤で通知を確認する。
7. 通知到達後に証跡を保存する。

### 6.3 `A-gate既存`の確認

1. EventBridgeの対象Ruleで、Monitoring表示またはCloudWatch Metricの`MatchedEvents`、`Invocations`、`FailedInvocations`を対象時間帯で確認する。
2. `MatchedEvents >= 1`、`Invocations >= 1`、`FailedInvocations = 0`を確認する。
3. Dead-letter queueを使用している場合、失敗メッセージがないことを確認する。
4. 別アカウント送信の場合、A-gate担当へEvent time、Event ID、Event name、送信元Accountを連携する。
5. A-gate側の受信記録と通知受信を確認する。
6. Event Pattern、Target、送信先を変更せず、証跡だけを取得する。

### 6.4 後片付け

1. 確定した監視方式で通知到達を確認する。
2. テスト用変更を戻し、またはテスト用リソースを削除する。
3. 復旧・削除イベントで追加通知が発生した場合は正常な追加検知として記録する。

Metric Filter作成前に存在した過去ログは、新しいMetric Datapointを生成しない。Alarmがすでに`ALARM`の間に同じ要件の次イベントを発生させても、新しい状態遷移通知が出ない場合がある。同じAlarmで2種類目のイベントを確認するときは、評価期間経過後に`OK`へ戻ったことを確認してから実施する。

Periodが5分、Evaluation periodsが1の場合、実イベントから通知までの待機上限は作業計画上15～20分を確保する。同じ操作を連打しない。

## 7. 要件別実イベント手順

### 7.1 要件4.1 不正なAPI呼び出し

#### 目的

テスト専用Bucketへのタグ更新を明示的に拒否し、業務リソースを変更せず`AccessDenied`イベントを発生させる。

#### 事前準備

IAM担当が次のテスト専用Roleを事前作成する。

```text
Role名: <SYSTEM>-alarm-test-denied-role-<YYYYMMDD>
対象Bucket: <SYSTEM>-alarm-test-denied-<ACCOUNT_ID>-<YYYYMMDD>
```

Roleの許可・拒否Policy例:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadOnlyForTestBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyTagUpdateForAlarmTest",
      "Effect": "Deny",
      "Action": "s3:PutBucketTagging",
      "Resource": "arn:aws:s3:::<SYSTEM>-alarm-test-denied-<ACCOUNT_ID>-<YYYYMMDD>"
    }
  ]
}
```

対象Bucketは空、Block Public Accessはすべて有効、業務用途なしとする。

#### 操作手順

1. テスト専用RoleへSwitch Roleする。
2. S3コンソールでテスト専用Bucketを開く。
3. 「プロパティ」の「タグ」を開く。
4. 「編集」を選択する。
5. Keyに`AlarmTest`、Valueに`Denied`を入力する。
6. 「変更の保存」を1回だけ選択する。
7. `AccessDenied`が表示されることを確認する。
8. タグが追加されていないことを確認する。
9. 元の作業Roleへ戻る。
10. CloudTrailで`PutBucketTagging`を検索し、`errorCode`が`AccessDenied`系であることを確認する。
11. 「6. 各イベント後の共通確認」を実施する。

#### 注意点

- 既存権限を一時的に外してAccessDeniedを作らない。
- 業務Bucketを対象にしない。
- コンソールが複数回APIを呼び、Metric値が1を超える場合がある。
- テストRoleを作成・更新したイベントが4.4へ一致する可能性があるため、通知確認者へ事前連絡する。

### 7.2 要件4.2 MFAなしコンソールログイン

#### 目的

MFA未登録の無権限テストIAMユーザーで1回だけログインし、`ConsoleLogin Success`かつ`MFAUsed No`を発生させる。

#### 事前準備

```text
IAMユーザー名: <SYSTEM>-alarm-test-console-user-<YYYYMMDD>
アクセスキー: 作成しない
所属Group: なし
Permission Policy: なし
MFA: 登録しない
Console password: 一時ランダムパスワード
初回ログイン時のパスワード変更: 無効
```

認証担当とIAM担当の承認を得る。既存ユーザーからMFAを外す方法は採用しない。

WinAuth、SAML、IAM Identity Centerなどのフェデレーション経路は使用しない。フェデレーション側でMFA済みでも、CloudTrailの`MFAUsed`がIAMユーザーMFAと同じ意味にならないためである。

#### 操作手順

1. IAM担当が上記ユーザーへConsole accessだけを設定する。
2. パスワードを手順書、スクリーンショット、チャットへ記録しない。
3. 通常セッションと分離したプライベートブラウザを開く。
4. 対象アカウントのIAMユーザー用サインインURLを開く。
5. Account IDまたはAlias、テストユーザー名、正しい一時パスワードを入力する。
6. MFAを使用せず1回だけログインする。
7. Console Homeが表示されたら、AWSサービスを操作せず直ちにサインアウトする。
8. CloudTrailで`ConsoleLogin`を検索する。
9. `userIdentity.type=IAMUser`、テストユーザー名、`responseElements.ConsoleLogin=Success`、`additionalEventData.MFAUsed=No`を確認する。
10. 「6. 各イベント後の共通確認」を実施する。

#### リージョン確認

IAMユーザーの`ConsoleLogin`記録リージョンはサインインEndpointとブラウザCookieにより変わる。対象リージョンで見つからない場合は、`us-east-1`、`us-east-2`、`eu-north-1`、`ap-southeast-2`も確認する。対象TrailがMulti-RegionかつGlobal service eventsを含み、これらのイベントを対象Log Groupへ配信する設計であることが前提となる。

#### 注意点

- 対象アカウントでMFAなしIAMユーザーが統制上禁止されている場合は実施しない。
- A-gateや認証基盤を迂回する目的でユーザーを作成しない。
- 要件4.6を同じユーザーで実施する場合、4.6の失敗ログインを先に行う。
- 4.2と4.6の確認後、Console accessを削除し、テストIAMユーザーを削除する。

### 7.3 要件4.3 rootアカウント使用

#### 実施可能条件

実イベントは、root認証情報が有効な専用サンドボックスアカウントに限定する。業務アカウント、通常の検証アカウント、Organizations管理アカウントでは実施しない。

root認証情報が集中管理により削除・無効化されている場合、テスト目的で再有効化しない。

#### 例外試験手順

1. セキュリティ責任者の書面承認を確認する。
2. root認証情報管理者とMFA管理者の2名立会いとする。
3. 専用サンドボックスのrootサインインページを開く。
4. rootメールアドレス、パスワード、登録済みMFAでログインする。
5. Console Homeが表示されたらAWSサービスを操作せず、直ちにサインアウトする。
6. CloudTrailの`us-east-1`で`ConsoleLogin`を検索する。
7. `userIdentity.type=Root`、`responseElements.ConsoleLogin=Success`、`additionalEventData.MFAUsed=Yes`を確認する。
8. 「6. 各イベント後の共通確認」を実施する。
9. root認証情報の保管状態に変更がないことを確認する。

#### 中止条件

- root MFAがない。
- root認証情報を新規発行または共有する必要がある。
- 対象サンドボックスのCloudTrailイベントが試験対象Log Groupへ届かない。
- 統制上、rootサインインが禁止されている。

この条件を満たさない場合、実イベントによるEnd-to-End試験は成立しない。Pattern Testと手動Alarm通知確認を代替証跡とし、実イベント未実施理由の承認を取得する。

### 7.4 要件4.4 IAMポリシー変更

#### 目的

どのUser、Role、GroupにもアタッチしないCustomer managed policyを作成し、`CreatePolicy`を発生させる。

#### 操作手順

1. IAMコンソールの「ポリシー」を開く。
2. 「ポリシーを作成」を選択する。
3. JSONエディタへ次のPolicyを入力する。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NoEffectivePermissionForAlarmTest",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<SYSTEM>-nonexistent-alarm-test-<ACCOUNT_ID>-<YYYYMMDD>/*"
    }
  ]
}
```

4. Policy名を`<SYSTEM>-alarm-test-policy-<YYYYMMDD>`とする。
5. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
6. Policyを作成する。
7. 「アタッチされたエンティティ」が0であることを確認する。
8. CloudTrailで`CreatePolicy`とPolicy ARNを確認する。
9. 「6. 各イベント後の共通確認」を実施する。
10. 通知と証跡取得後、テストPolicyを削除する。
11. `DeletePolicy`も監視対象となるため追加通知として記録する。

既存Policy、Permissions Boundary、A-gate管理Policyは変更しない。

### 7.5 要件4.5 CloudTrail設定変更

#### 推奨方法

承認済みの恒久是正作業で発生する`UpdateTrail`を代表実イベントとして利用する。CloudWatch Logs連携、KMS CMK、ログファイル検証など、実際に承認された変更以外を追加しない。

1. 対象TrailのS3 Bucket、Prefix、KMS Key、Log file validation、CloudWatch Logs、Role、Event Selectorを変更前証跡として保存する。
2. 承認済み作業手順書に従って対象項目だけを変更する。
3. 保存前に今回変更しない項目が変更前と一致することを確認する。
4. 保存する。
5. CloudTrailで`UpdateTrail`を検索する。
6. `requestParameters`が承認済み変更と一致することを確認する。
7. 「6. 各イベント後の共通確認」を実施する。
8. 恒久設定は試験完了を理由に元へ戻さない。

#### 承認済み変更がない場合の代替

1. S3で`<SYSTEM>-alarm-test-cloudtrail-<ACCOUNT_ID>-<YYYYMMDD>`を作成する。
2. Block Public Accessをすべて有効とする。
3. CloudTrailの「証跡」から「証跡の作成」を選択する。
4. Trail名を`<SYSTEM>-alarm-test-trail-<YYYYMMDD>`とする。
5. Organization Trailは無効、Insightsは無効、Data Eventは設定しない。
6. Management EventはReadとWriteを対象とする。
7. テスト専用S3 Bucketを指定し、Trailを作成する。
8. `CreateTrail`または`StartLogging`をCloudTrailで確認する。
9. 「6. 各イベント後の共通確認」を実施する。
10. 通知と証跡取得後、テストTrailを削除する。
11. テストBucket内のログを確認・保管後、空にしてBucketを削除する。

テストTrail作成はS3 Bucket Policy変更を伴い、4.8も発報する可能性がある。A-gate、中央ログ集約、Trail数上限、二重記録、料金への影響がある場合は実施しない。

### 7.6 要件4.6 AWS Management Console認証失敗

#### 目的

4.2用の無権限テストIAMユーザーでパスワードを1回だけ誤入力し、`ConsoleLogin Failure`を発生させる。

#### 操作手順

1. 4.2のテストIAMユーザーと一時パスワードが準備済みであることを確認する。
2. プライベートブラウザで対象アカウントのIAMユーザー用サインインURLを開く。
3. Account IDまたはAliasと、正しいテストユーザー名を入力する。
4. 正しい一時パスワードとは異なる値を1回だけ入力する。
5. 認証失敗画面を確認し、追加試行しない。
6. CloudTrailで`ConsoleLogin`を検索する。
7. `userIdentity.type=IAMUser`、テストユーザー名、`responseElements.ConsoleLogin=Failure`、`errorMessage=Failed authentication`を確認する。
8. 「6. 各イベント後の共通確認」を実施する。
9. 4.6の確認完了後、4.2の正しいパスワードによるMFAなし成功ログインへ進む。

WinAuth、SAML、IAM Identity Centerで認証に失敗しただけでは、失敗がAWS Sign-In Endpointへ到達せず`ConsoleLogin`が生成されない場合がある。本試験では直接IAMユーザーサインインを使用する。

実際のイベントに`responseElements.ConsoleLogin=Failure`が存在しない場合は、Metric Filterを無理に通そうとせずRaw Eventと正式設計を再確認する。AWS公式例には`responseElements.ConsoleLogin=Failure`と`errorMessage=Failed authentication`の両方が存在する。

### 7.7 要件4.7 CMK無効化または削除予約

#### テスト専用CMK作成

1. KMSコンソールの「カスタマー管理型のキー」を開く。
2. 「キーの作成」を選択する。
3. Key typeは「対称」、Key usageは「暗号化および復号化」を選択する。
4. Single-Region Keyを選択する。
5. Aliasを`alias/<SYSTEM>-alarm-test-kms-<YYYYMMDD>`とする。
6. Descriptionを`Alarm test only. No production data.`とする。
7. 承認済みのテスト管理RoleだけをKey administratorとする。
8. Key userは設定しない。
9. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
10. Keyを作成する。
11. CloudTrail、S3、EBS、RDS、Secrets Manager、CloudWatch Logsなどから参照されていないことを確認する。

#### DisableKeyテスト

1. 対象AliasとKey IDを再確認する。
2. Keyの「キーアクション」から「無効化」を選択する。
3. テスト専用Keyであることを再確認して無効化する。
4. CloudTrailで`DisableKey`とKey ARNを確認する。
5. 「6. 各イベント後の共通確認」を実施する。
6. 通知と証跡取得後、Keyを「有効化」する。
7. Key stateが`Enabled`へ戻ったことを確認する。

#### ScheduleKeyDeletionテスト

1. 4.7 Alarmが`OK`へ戻ったことを確認する。
2. 対象テストKeyを選択する。
3. 「キーアクション」から「キーの削除をスケジュール」を選択する。
4. Waiting periodに`7`日を入力する。
5. Key ARNとAliasを再確認して削除予約する。
6. CloudTrailで`ScheduleKeyDeletion`を確認する。
7. 「6. 各イベント後の共通確認」を実施する。
8. 通知と証跡取得後、「キーの削除をキャンセル」を実行する。
9. Cancel後はKeyが`Disabled`となるため、継続確認が必要な場合は「有効化」する。

#### 後片付け

テストKeyを廃止する場合は、承認済み廃止手順で再度削除予約する。再度の`ScheduleKeyDeletion`でも4.7が発報するため、正常な後片付け通知として記録する。業務Key、CloudTrail暗号化Key、データ暗号化Keyでは本試験を行わない。

### 7.8 要件4.8 S3 Bucket Policy変更

#### テストBucket作成

```text
Bucket名: <SYSTEM>-alarm-test-s3-policy-<ACCOUNT_ID>-<YYYYMMDD>
Object Ownership: Bucket owner enforced
Block Public Access: 4項目すべて有効
Versioning: 無効
Default encryption: SSE-S3
Object: なし
```

#### 操作手順

1. S3コンソールでテストBucketを開く。
2. Bucketが空で、CloudTrail、Config、ログ保存先、アプリケーションから未使用であることを確認する。
3. 「アクセス許可」の「バケットポリシー」で「編集」を選択する。
4. 次のPolicyのBucket名2か所を置き換えて入力する。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransportForAlarmTest",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::<SYSTEM>-alarm-test-s3-policy-<ACCOUNT_ID>-<YYYYMMDD>",
        "arn:aws:s3:::<SYSTEM>-alarm-test-s3-policy-<ACCOUNT_ID>-<YYYYMMDD>/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

5. Public Allowがないことを再確認する。
6. Policyを保存する。
7. CloudTrailで`PutBucketPolicy`とBucket名を確認する。
8. 「6. 各イベント後の共通確認」を実施する。
9. 通知と証跡取得後、Bucket Policyを削除する。
10. `DeleteBucketPolicy`による追加通知を記録する。
11. 要件4.9で同じBucketを使用する場合は、Bucketを空のまま保持する。
12. 要件4.9を実施しない場合、または4.9完了後に、Bucket Policyが「なし」、Bucketが空であることを確認し、テストBucketを削除する。

Policy StatusがPublic、既存Bucketと同名、A-gateまたはConfig違反となる場合は中止する。

### 7.9 要件4.9 AWS Config設定変更

#### 前提

- 対象リージョンでConfiguration RecorderとDelivery Channelが稼働中である。
- Config Rule追加がOrganizations、Conformance Pack、A-gateの中央管理と競合しない。
- 4.8のテスト専用Bucketが存在するか、同条件の空Bucketを用意する。

#### 操作手順

1. AWS Configコンソールを対象リージョンで開く。
2. 「設定」でRecorderとDelivery Channelが稼働中であることを確認する。
3. RecorderとDelivery Channelは変更しない。
4. 「ルール」を開き、「ルールを追加」を選択する。
5. AWS Managed Ruleから`required-tags`を選択する。
6. Rule名を`<SYSTEM>-alarm-test-config-rule-<YYYYMMDD>`とする。
7. Scopeは「特定のリソース」を選択する。
8. Resource typeは`AWS::S3::Bucket`とする。
9. Resource IDは4.8のテスト専用Bucket名とする。
10. Parameter `tag1Key`に`Purpose`を入力する。
11. Parameter `tag1Value`に`alarm-test`を入力する。
12. Ruleを追加する。
13. CloudTrailで`PutConfigRule`とRule名を確認する。
14. 「6. 各イベント後の共通確認」を実施する。
15. 通知と証跡取得後、テストRuleだけを削除する。
16. `DeleteConfigRule`による追加通知を記録する。
17. Recorder、Delivery Channel、既存Ruleに変更がないことを確認する。

AWS Configが未導入、停止中、Organization Config Rule管理、またはテストBucketへScopeを限定できない場合は実施しない。

### 7.10 要件4.10 Security Group変更

#### 共通ネットワークテストVPC

本手順の標準案では、要件4.10～4.14で次の空のテスト専用VPCを共用する。ただし、テストVPCの新規作成は4.10～4.13の共通必須条件ではない。既存検証VPC内に未関連付けのテスト専用リソースを作成できる場合は、既存検証VPCを使用できる。

```text
Name tag: <SYSTEM>-alarm-test-vpc-<YYYYMMDD>
IPv4 CIDR: 10.254.255.0/28
IPv6 CIDR: なし
Tenancy: default
DNS resolution: default
DNS hostnames: default
```

作成前にIPアドレス管理表、IPAM、既存VPC、接続先ネットワークとの重複がないことを確認する。重複する場合は、ネットワーク担当が承認した未使用CIDRへ置き換える。

このVPCには、EC2、ENI、Subnet、ALB、NAT Gateway、VPC Endpoint、VPN、Transit Gateway Attachment、VPC Peeringを作成・接続しない。

#### テストVPCの要否判断

| 要件 | 新規VPCなしで実施できる条件 | 空のテストVPCが必要または推奨となる場合 |
| :--- | :--- | :--- |
| 4.10 Security Group | 既存検証VPCに未関連付けSGを作成し、そのSGだけへRuleを追加・削除できる | 既存検証VPCへのテストSG作成が統制上禁止されている場合 |
| 4.11 NACL | 既存検証VPCに未関連付けNACLを作成し、Subnet associationを0件のまま試験できる | 未関連付け状態を保証できない場合、またはFirewall ManagerなどがNACLを自動管理する場合 |
| 4.12 Network Gateway | `CreateInternetGateway`と`DeleteInternetGateway`だけを代表イベントにする | `AttachInternetGateway`と`DetachInternetGateway`まで実イベントで確認する場合 |
| 4.13 Route Table | 既存検証VPCに未関連付けカスタムRoute Tableを作成できる。`CreateRouteTable`だけを代表イベントにする場合、Targetも不要 | `CreateRoute`まで確認し、既存IGWなどをTargetに使用する承認がない場合 |
| 4.14 VPC | 該当なし。`CreateVpc`を実イベントにする場合はVPC作成が必要 | 空VPCを作成し、`CreateVpc`確認後に削除する方法を標準とする |

次のフローで判断する。

```text
4.14のCreateVpcを実イベントで確認する
  -> Yes: 空のテストVPCを作成する
  -> No:
       4.12でAttach/Detachまたは4.13でCreateRouteまで確認する
         -> Yes: 空のテストVPCを推奨する
         -> No: 既存検証VPC内の未関連付けテストリソースで実施できる
```

#### 空のテストVPCを作成する理由

1. **要件4.14の代表イベントを安全に作るため**

   4.14で`CreateVpc`を実イベントとして確認するには、VPCを実際に作成する必要がある。既存VPCのDNS属性などを一時変更して`ModifyVpcAttribute`を発生させる方法もあるが、使用中VPCの設定を短時間でも変更するため、空VPCの作成・削除より影響範囲が大きい。

2. **既存VPCの通信経路から試験を分離するため**

   Security Groupは関連付けられたリソースの通信を制御する。[AWS公式のSecurity Group説明](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-security-groups.html)に示されるとおり、未関連付けSGは業務リソースへ適用されない。

   カスタムNACLは作成直後にすべてのInbound/Outboundを拒否し、デフォルトではSubnetへ関連付けられていない。[AWS公式のNACL作成手順](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/create-network-acl.html)に従い、Subnet associationを0件のままにすれば既存Subnetへ適用されない。反対に、使用中Subnetへ関連付けるとルールが即時に適用されるため、通信断の可能性がある。

   カスタムRoute Tableは、関連付けられたSubnetの経路を制御する。[AWS公式のSubnet Route Table説明](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/subnet-route-tables.html)では、Subnetは明示的な関連付けがない場合にMain Route Tableを使用するとされている。未関連付けの新規カスタムRoute TableへテストRouteを追加しても、既存Subnetの経路は変わらない。

3. **IGWのAttach/Detachを既存VPCから切り離すため**

   [AWS公式のVPCクォータ](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/amazon-vpc-limits.html)では、一度にVPCへアタッチできるInternet Gatewayは1つとされている。既存検証VPCにIGWがアタッチ済みの場合、別のテストIGWをそのVPCへ追加できない。既存IGWをデタッチして差し替える方法は、インターネット経路を失わせる可能性があるため採用しない。

   [AWS公式のInternet Gateway説明](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Internet_Gateway.html)では、インターネット通信にはIGWのVPCへのAttachだけでなく、Subnet Route TableのRouteとリソースのPublic IPも必要とされている。Subnet、Route Association、EC2、Public IPを持たない空VPCへIGWをAttachするだけなら、業務通信経路は成立しない。

4. **切り戻し対象をテストリソースだけに限定するため**

   既存リソースの設定値を一時変更する方式では、変更前値の記録漏れ、同時変更との競合、切り戻し値の誤りが発生し得る。空VPC方式では、試験用SG、NACL、Route Table、Route、IGWを依存関係の逆順で削除し、最後にVPCを削除するため、既存業務設定へ値を書き戻す必要がない。

5. **試験証跡を業務変更と明確に分離するため**

   `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を持つ専用リソースに限定すると、CloudTrail Eventの対象リソースID、Alarm発報、削除完了を一つの試験単位として突合できる。既存リソースの通常変更と混在しにくい。

#### 既存検証VPCを使用してよい条件

次のすべてを満たす場合、4.10、4.11、4.13は空VPCを新規作成せず、既存検証VPC内で実施できる。

1. 対象が本番VPC、運用VPC、共有サービスVPCではなく、変更承認済みの検証VPCである。
2. 作成するSG、NACL、Route Tableが新規テスト専用である。
3. SGをEC2、ENI、ALB、RDS、Lambdaなどへ関連付けない。
4. NACLをSubnetへ関連付けない。
5. Route TableをSubnetまたはGateway Route Tableとして関連付けない。IGWをRouteのTargetに使用する場合は、承認済みの未関連付けRoute Tableだけを使用する。
6. Main Route Table、Default SG、Default NACLを変更しない。
7. `CreateRoute`を実施する場合、未関連付けRoute Tableと承認済みTargetだけを使用する。
8. 変更前、実イベント、Alarm、通知、削除後の証跡を取得する。
9. 削除失敗時の確認担当と作業終了期限が決まっている。

一つでも満たせない場合は、空のテストVPCを使用するか、実イベント試験を中止して承認者へ判断を戻す。

#### 空のテストVPCの切り戻し手順

空VPC方式の切り戻しは、既存値への復元ではなく、テスト専用リソースの完全削除である。

1. Security GroupのテストRuleを削除する。
2. テストSecurity Groupを削除する。
3. NACLのテストEntryを削除する。
4. テストNACLを削除する。
5. テストRouteを削除する。
6. テストRoute Tableを削除する。
7. テストIGWをVPCからDetachする。
8. テストIGWを削除する。
9. EC2、ENI、Subnet、NAT Gateway、Endpoint、Peering、VPN、Transit Gateway Attachmentが0件であることを確認する。
10. テストVPCを削除する。
11. VPC、SG、NACL、Route Table、IGWの一覧からテスト用IDが消えたことを確認する。
12. CloudTrailで削除イベント、監視経路で追加Alarm、通知先で追加通知を確認する。

[AWS公式のVPC削除手順](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/delete-vpc.html)では、VPC削除前にEC2、Load Balancer、NAT Gateway、Transit Gateway Attachment、Interface Endpointなどの依存リソースを削除する必要がある。削除画面に想定外の依存リソースが表示された場合は、VPC削除を実行せず中止する。

#### 操作手順

1. VPCコンソールの「セキュリティグループ」を開く。
2. 「セキュリティグループを作成」を選択する。
3. Security Group nameに`<SYSTEM>-alarm-test-sg-<YYYYMMDD>`を入力する。
4. Descriptionに`Alarm test only. No resource attachment.`を入力する。
5. VPCに、要否判断で決定した`<TEST_VPC_ID>`を指定する。
6. Inbound rulesは追加せず作成する。
7. Outbound rulesは既定値のまま作成する。既定値を変更する必要がある場合は中止する。
8. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
9. `CreateSecurityGroup`が4.10のFilter Patternに含まれるため、CloudTrailへ記録されることを確認する。
10. `AuthorizeSecurityGroupIngress`を代表イベントとして確認する場合、4.10 Alarmが`OK`へ戻るまで待つ。
11. 作成したテストSGを選択し、「インバウンドルールを編集」を選択する。
12. 「ルールを追加」を選択する。
13. Typeに「カスタムTCP」を指定する。
14. Port rangeに`65535`を入力する。
15. Source typeに「カスタム」を指定する。
16. Sourceに`192.0.2.0/24`を入力する。
17. Descriptionに`alarm-test`を入力する。
18. SG ID、VPC ID、Source、Portを再確認し、「ルールを保存」を選択する。
19. CloudTrailで`AuthorizeSecurityGroupIngress`を検索する。
20. Event recordで次を確認する。

```text
groupId: テストSGのID
ipProtocol: tcp
fromPort: 65535
toPort: 65535
cidrIp: 192.0.2.0/24
```

21. 「6. 各イベント後の共通確認」を実施する。
22. 通知と証跡取得後、追加したInbound ruleだけを削除する。
23. CloudTrailの`RevokeSecurityGroupIngress`と追加通知を確認する。
24. テストSGに関連付けられたENIが0であることを確認し、テストSGを削除する。
25. Default Security Groupおよび既存SGに変更がないことを確認する。

`0.0.0.0/0`、`::/0`、業務CIDR、社内CIDR、実在する外部IPは入力しない。テストSGをEC2、ENI、ALB、RDS、Lambdaなどへ関連付けない。

### 7.11 要件4.11 NACL変更

#### 操作手順

1. VPCコンソールの「ネットワークACL」を開く。
2. 「ネットワークACLを作成」を選択する。
3. Name tagに`<SYSTEM>-alarm-test-nacl-<YYYYMMDD>`を入力する。
4. VPCに、要否判断で決定した`<TEST_VPC_ID>`を指定する。
5. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
6. Network ACLを作成する。
7. 「Subnet associations」が0件であることを確認する。
8. `CreateNetworkAcl`が4.11のFilter Patternに含まれるため、CloudTrailへ記録されることを確認する。
9. `CreateNetworkAclEntry`を代表イベントとして確認する場合、4.11 Alarmが`OK`へ戻るまで待つ。
10. 作成したテストNACLを選択する。
11. 「Inbound rules」から「Edit inbound rules」を選択する。
12. 「Add new rule」を選択する。
13. Rule numberに`200`を入力する。
14. Typeに「カスタムTCP」を指定する。
15. Protocolが`TCP (6)`であることを確認する。
16. Port rangeに`65535`を入力する。
17. Sourceに`192.0.2.0/24`を入力する。
18. Allow/Denyに`ALLOW`を指定する。
19. NACL ID、VPC ID、Rule number、Source、Portを再確認して保存する。
20. CloudTrailで`CreateNetworkAclEntry`を検索する。
21. Event recordで次を確認する。

```text
networkAclId: テストNACLのID
ruleNumber: 200
protocol: 6
ruleAction: allow
egress: false
cidrBlock: 192.0.2.0/24
portRange.from: 65535
portRange.to: 65535
```

22. 「6. 各イベント後の共通確認」を実施する。
23. 通知と証跡取得後、Rule number `200`だけを削除する。
24. CloudTrailの`DeleteNetworkAclEntry`と追加通知を確認する。
25. Subnet associationが0件であることを再確認し、テストNACLを削除する。
26. Default NACLおよび既存NACLに変更がないことを確認する。

Default NACLは使用しない。既存SubnetをテストNACLへ関連付けない。Rule numberが重複する場合は、未関連付けのテストNACLであることを再確認した上で、ネットワーク担当が承認した別番号を使用する。

### 7.12 要件4.12 Network Gateway変更

正式評価シートが対象とするNetwork Gatewayは、Internet GatewayとCustomer Gatewayである。本手順では、外部回線やVPNを作らずに済むInternet Gatewayを代表イベントにする。

`CreateInternetGateway`によるEnd-to-End発報確認だけで試験成立とする場合、VPCは不要である。`AttachInternetGateway`と`DetachInternetGateway`も実イベントで確認する場合だけ、空のテストVPCを使用する。

#### 操作手順

1. VPCコンソールの「インターネットゲートウェイ」を開く。
2. 「インターネットゲートウェイを作成」を選択する。
3. Name tagに`<SYSTEM>-alarm-test-igw-<YYYYMMDD>`を入力する。
4. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
5. Internet Gatewayを作成する。
6. CloudTrailで`CreateInternetGateway`とIGW IDを確認する。
7. 「6. 各イベント後の共通確認」を実施する。
8. `CreateInternetGateway`だけを代表イベントにする場合は、証跡取得後にテストIGWを削除し、`DeleteInternetGateway`と追加通知を確認して終了する。
9. `AttachInternetGateway`も個別に確認する場合、CloudWatch方式ではAlarmが`OK`へ戻り、A-gate方式では最初のイベント処理が完了するまで待つ。
10. テストIGWの「アクション」から「VPCにアタッチ」を選択する。
11. VPCに空のテストVPCを指定する。既存検証VPCの既存IGWをデタッチしない。
12. VPC IDとIGW IDを再確認してアタッチする。
13. CloudTrailで`AttachInternetGateway`を検索する。
14. Event recordでテストVPC IDとテストIGW IDを確認する。
15. 「6. 各イベント後の共通確認」を実施する。
16. 要件4.13のRouteテストを続ける場合は、IGWをアタッチしたまま保持する。
17. 要件4.13完了後、テストRouteが削除済みであることを確認する。
18. テストIGWをテストVPCからデタッチする。
19. CloudTrailの`DetachInternetGateway`と追加通知を確認する。
20. テストIGWを削除し、`DeleteInternetGateway`と追加通知を確認する。

Customer Gateway、Virtual Private Gateway、NAT Gateway、Transit Gateway、VPN Connectionは作成しない。テストVPCにSubnetやPublic IPを持つリソースがないため、IGWをAttachしただけではインターネット通信経路は成立しない。

### 7.13 要件4.13 Route Table変更

次のいずれかを作業前に選択する。

- **方式A: `CreateRouteTable`だけを代表イベントにする**
  既存検証VPCまたは空のテストVPCに未関連付けRoute Tableを作成する。IGWとRoute追加は不要である。
- **方式B: `CreateRoute`まで実イベントで確認する**
  空のテストVPCへテストIGWをAttachし、未関連付けRoute Tableに文書用CIDRのRouteを追加する。既存検証VPCで実施する場合は、未関連付けRoute Tableと既存IGWを使用することについて事前承認を取得する。

#### 操作手順

1. 方式Bの場合だけ、要件4.12のテストIGWが空のテストVPCへAttach済みであることを確認する。
2. VPCコンソールの「ルートテーブル」を開く。
3. 「ルートテーブルを作成」を選択する。
4. Nameに`<SYSTEM>-alarm-test-rtb-<YYYYMMDD>`を入力する。
5. VPCに、要否判断で決定した`<TEST_VPC_ID>`を指定する。
6. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
7. Route Tableを作成する。
8. 「Subnet associations」が0件であることを確認する。
9. `CreateRouteTable`が4.13のFilter Patternに含まれるため、CloudTrailへ記録されることを確認する。
10. 方式Aの場合は「6. 各イベント後の共通確認」を実施し、通知と証跡取得後、未関連付けのテストRoute Tableを削除して終了する。
11. 方式Bの場合、CloudWatch方式では`CreateRouteTable`による発報後に4.13 Alarmが`OK`へ戻り、A-gate方式では最初のイベント処理が完了するまで待つ。
12. 作成したテストRoute Tableの「Routes」タブを開く。
13. 「Edit routes」を選択する。
14. 「Add route」を選択する。
15. Destinationに`198.51.100.0/24`を入力する。
16. Target typeに「Internet Gateway」を指定する。
17. Targetに承認済みテストIGWのIDを指定する。
18. Route Table ID、Destination、Targetを再確認して保存する。
19. CloudTrailで`CreateRoute`を検索する。
20. Event recordで次を確認する。

```text
routeTableId: テストRoute TableのID
destinationCidrBlock: 198.51.100.0/24
gatewayId: テストIGWのID
```

21. 「6. 各イベント後の共通確認」を実施する。
22. 通知と証跡取得後、`198.51.100.0/24`のRouteだけを削除する。
23. CloudTrailの`DeleteRoute`と追加通知を確認する。
24. Subnet associationが0件であることを再確認し、テストRoute Tableを削除する。
25. Main Route Tableおよび既存Route Tableに変更がないことを確認する。

`0.0.0.0/0`、`::/0`、業務CIDR、社内CIDR、実在する外部CIDRはDestinationにしない。Main Route Tableを変更しない。Subnet association、Edge association、Route propagationを設定しない。Direct Connect、Transit Gateway、NAT Gateway、VPC Endpoint、VPNをTargetにしない。

### 7.14 要件4.14 VPC変更

要件4.10～4.14で共用する空VPCの作成イベントを、4.14の代表実イベントとする。

#### 操作手順

1. VPCコンソールの「VPC」を開く。
2. 「VPCを作成」を選択する。
3. 「作成するリソース」は「VPCのみ」を選択する。
4. Name tagに`<SYSTEM>-alarm-test-vpc-<YYYYMMDD>`を入力する。
5. IPv4 CIDR manual inputに、承認済みの`10.254.255.0/28`を入力する。
6. IPv6 CIDR blockは「IPv6 CIDRブロックなし」を選択する。
7. Tenancyは「Default」を選択する。
8. `Purpose=alarm-test`、`ChangeId=<CHANGE_ID>`、`DeleteAfter=<YYYY-MM-DD>`を設定する。
9. VPCを作成する。
10. CloudTrailで`CreateVpc`を検索する。
11. Event recordでVPC IDとCIDR `10.254.255.0/28`を確認する。
12. 「6. 各イベント後の共通確認」を実施する。
13. VPCを削除せず、要件4.12、4.13、4.10、4.11の順に使用する。
14. すべてのネットワーク試験と後片付け完了後、次が0件であることを確認する。

```text
EC2 / ENI / Subnet / Security Group（default以外）
NACL（default以外） / Route Table（main以外） / Internet Gateway
NAT Gateway / VPC Endpoint / Peering / VPN / Transit Gateway Attachment
```

15. テストVPCを削除する。
16. CloudTrailの`DeleteVpc`と追加通知を確認する。
17. VPC一覧からテストVPCが消え、既存VPC数に変化がないことを確認する。

VPC作成前にCIDR重複確認を完了していない場合は実施しない。「VPCなど」を選択してSubnet、Route Table、Internet Gateway、NAT Gatewayを一括作成しない。

### 7.15 要件4.15 AWS Organizations変更

#### 実施可能条件

- Organizationsの管理アカウントに属する専用管理サンドボックスである。
- 空OUの作成・削除がSCP、A-gate、アカウント管理運用へ影響しない。
- Organizations担当とセキュリティ責任者が書面承認している。
- テストOUへAccount、子OU、SCP、Resource Control Policy、Tag Policy、Backup Policyを関連付けない。

#### Filter Patternの事前確認

現在の4.15候補が次のように`eventSource`だけを条件としている場合、Organizationsコンソールの参照操作も一致し得る。

```text
{ $.eventSource = "organizations.amazonaws.com" }
```

このPatternは「Organizationsに対するすべての記録イベント」を検知する設計であり、「変更イベントだけ」に限定していない。正式要件が変更監視であるため、Read-onlyイベントを含める設計でよいか、テスト前に設計者と監査対応責任者へ確認する。コンソールを開いただけでMetricが増える場合、空OU作成による変更監視の証跡と混同しない。

#### 操作手順

1. Organizations管理アカウントへ、承認済み管理Roleでログインする。
2. AWS Organizationsコンソールを開く。
3. 「AWSアカウント」を開く。
4. 作成先として承認されたRootまたは親OUを選択する。
5. 「アクション」から「新規作成」を選択し、「組織単位」を選択する。
6. OU名に`<SYSTEM>-alarm-test-ou-<YYYYMMDD>`を入力する。
7. OUを作成する。
8. 作成したOUが空であり、Account、子OU、Policyが関連付いていないことを確認する。
9. CloudTrailで`CreateOrganizationalUnit`を検索する。
10. Event recordでOU ID、OU名、Parent IDを確認する。
11. 「6. 各イベント後の共通確認」を実施する。
12. 通知と証跡取得後、OUが空であることを再確認する。
13. 作成したテストOUを選択し、「削除」を実行する。
14. CloudTrailで`DeleteOrganizationalUnit`を確認する。
15. 削除操作による追加通知を確認する。
16. Rootおよび既存OUの構成、Account所属先、Policy関連付けに変更がないことを確認する。

Account移動、Account招待、Account作成、SCP作成・変更・関連付け、Organizations削除は行わない。管理アカウントへアクセスできない場合やA-gateが中央管理している場合、実イベント試験は当該管理者側の作業とする。メンバーアカウントだけで4.15を成立させない。

## 8. 推奨実施順序

Alarmの状態復帰待ち、テストリソースの共用、後片付け順序を考慮し、次の順で実施する。

| 順番 | 要件 | 実施内容 | 補足 |
| :--- | :--- | :--- | :--- |
| 1 | 共通 | Account、Region、Trail、Log Group、Metric Filter、Alarm、SNS確認 | すべての試験の前提 |
| 2 | 4.6 | テストIAMユーザーで認証失敗 | 4.2より先に実施 |
| 3 | 4.2 | 同じテストIAMユーザーでMFAなし成功ログイン | 完了後にユーザー削除 |
| 4 | 4.1 | 明示的に拒否されたS3タグ更新 | テストRoleとBucketを使用 |
| 5 | 4.4 | 未アタッチIAM Policy作成 | 作成後に削除 |
| 6 | 4.5 | 承認済みTrail変更またはテストTrail作成 | 中央管理との競合確認が必須 |
| 7 | 4.7 | テストCMKのDisable、Schedule、Cancel | 業務Keyは使用しない |
| 8 | 4.8 | テストBucket Policy設定 | 4.9でBucketを共用可能 |
| 9 | 4.9 | テストConfig Rule作成 | 完了後にRuleとBucketを削除 |
| 10 | 4.14 | 空VPC作成 | 4.10～4.13の共通基盤 |
| 11 | 4.12 | IGW作成・Attach | 4.13完了まで保持 |
| 12 | 4.13 | 未関連付けRoute TableとRoute作成 | Route、Tableの順に削除 |
| 13 | 4.10 | 未関連付けSGとIngress rule作成 | Rule、SGの順に削除 |
| 14 | 4.11 | 未関連付けNACLとEntry作成 | Entry、NACLの順に削除 |
| 15 | 4.14 | 空VPC削除 | 依存リソース0件を確認 |
| 16 | 4.3 | rootサインイン | 別作業枠・専用Sandboxのみ |
| 17 | 4.15 | 空OU作成 | 別作業枠・管理Sandboxのみ |

4.3と4.15は通常のアプリケーション検証アカウントで実施せず、統制管理者が立ち会う別作業として切り離す。

## 9. 要件別期待イベントと確認値

| 要件 | 代表`eventName` | 主な確認値 | 復旧・削除イベント |
| :--- | :--- | :--- | :--- |
| 4.1 | `PutBucketTagging` | `errorCode=AccessDenied`系、テストBucket名、テストRole ARN | リソース削除は管理者Roleで実施 |
| 4.2 | `ConsoleLogin` | `Success`、`MFAUsed=No`、テストIAMユーザー | Login profile/User削除 |
| 4.3 | `ConsoleLogin` | `userIdentity.type=Root`、`Success`、`MFAUsed=Yes` | なし |
| 4.4 | `CreatePolicy` | テストPolicy ARN、未アタッチ | `DeletePolicy` |
| 4.5 | `UpdateTrail` | Trail ARN、承認済み変更値 | 恒久変更は戻さない |
| 4.6 | `ConsoleLogin` | `Failure`、`Failed authentication`、テストIAMユーザー | なし |
| 4.7 | `DisableKey` | テストKey ARN | `EnableKey` |
| 4.7 | `ScheduleKeyDeletion` | テストKey ARN、`pendingWindowInDays=7` | `CancelKeyDeletion`、必要時`EnableKey` |
| 4.8 | `PutBucketPolicy` | テストBucket名、Deny Policy | `DeleteBucketPolicy` |
| 4.9 | `PutConfigRule` | テストRule名、`required-tags` | `DeleteConfigRule` |
| 4.10 | `AuthorizeSecurityGroupIngress` | TCP、65535、`192.0.2.0/24`、テストSG ID | `RevokeSecurityGroupIngress`、`DeleteSecurityGroup` |
| 4.11 | `CreateNetworkAclEntry` | Rule 200、TCP 65535、`192.0.2.0/24`、ALLOW | `DeleteNetworkAclEntry`、`DeleteNetworkAcl` |
| 4.12 | `CreateInternetGateway`または`AttachInternetGateway` | テストIGW ID、テストVPC ID | `DetachInternetGateway`、`DeleteInternetGateway` |
| 4.13 | `CreateRoute` | `198.51.100.0/24`、テストIGW ID、テストRoute Table ID | `DeleteRoute`、`DeleteRouteTable` |
| 4.14 | `CreateVpc` | `10.254.255.0/28`、テストVPC ID | `DeleteVpc` |
| 4.15 | `CreateOrganizationalUnit` | テストOU名、OU ID、Parent ID | `DeleteOrganizationalUnit` |

Metric Filterが複数の`eventName`や複数の`errorCode`をOR条件で持つ場合でも、End-to-End試験は要件ごとに承認済み代表イベント1件を発生させる。残りの分岐はMetric Filter Pattern Testで一致・不一致を確認する。全分岐の実AWS操作まで要求される場合は、操作ごとに影響、権限、復旧、追加通知を再評価し、別途承認を取得する。

## 10. 証跡取得

### 10.1 共通証跡

同じ情報を重複撮影せず、作業開始時に一度だけ取得する。

```text
01_共通_アカウント・リージョン確認_202608XX.png
02_共通_CloudTrail・CloudWatchLogs連携確認_202608XX.png
03_共通_MetricFilter一覧確認_202608XX.png
04_共通_CloudWatchAlarm一覧確認_202608XX.png
05_共通_SNSTopic・Subscription確認_202608XX.png
06_共通_A-gate対応要件・EventBridgeRule対応表確認_202608XX.png
```

`06`はA-gate対応要件がある場合だけ取得する。送信先Account ID、Target ARN、機密性のあるEvent Patternは現場の証跡管理ルールに従ってマスキングする。

### 10.2 要件別証跡

各要件は次の8種類を基本とし、画面内で複数項目を確認できる場合は統合する。

```text
<NN>_<要件番号>_テストリソース変更前_202608XX.png
<NN>_<要件番号>_実イベント操作結果_202608XX.png
<NN>_<要件番号>_CloudTrailイベント詳細_202608XX.png
<NN>_<要件番号>_CloudWatchLogsイベント確認_202608XX.png
<NN>_<要件番号>_CustomMetricデータポイント確認_202608XX.png
<NN>_<要件番号>_Alarm状態・履歴確認_202608XX.png
<NN>_<要件番号>_通知受信確認_202608XX.png
<NN>_<要件番号>_復旧・削除後確認_202608XX.png
```

`A-gate既存`の場合、CloudWatch Logs、Custom Metric、Alarm Historyの3枚を次へ置き換える。

```text
<NN>_<要件番号>_EventBridgeRule・EventPattern確認_202608XX.png
<NN>_<要件番号>_MatchedEvents・Invocations確認_202608XX.png
<NN>_<要件番号>_A-gate受信結果確認_202608XX.png
```

要件4.10の具体例:

```text
41_4.10_未関連付けSecurityGroup作成後_202608XX.png
42_4.10_TCP65535ルール追加結果_202608XX.png
43_4.10_CloudTrail_AuthorizeSecurityGroupIngress_202608XX.png
44_4.10_CloudWatchLogsイベント確認_202608XX.png
45_4.10_CustomMetricデータポイント確認_202608XX.png
46_4.10_Alarm状態・履歴確認_202608XX.png
47_4.10_通知受信確認_202608XX.png
48_4.10_SGルール・SG削除後確認_202608XX.png
```

CloudTrail Event recordでは、`eventTime`、`eventName`、`awsRegion`、`userIdentity.arn`、対象リソースID、変更値、`errorCode`を一画面またはJSONで確認可能な証跡を優先する。アクセスキーID、rootメールアドレス、一時パスワード、MFAコード、個人情報は証跡へ残さないか、承認済み方法でマスキングする。

## 11. 必要権限

### 11.1 共通参照権限

少なくとも次の参照操作を実施できるRoleを使用する。

```text
sts:GetCallerIdentity
cloudtrail:DescribeTrails
cloudtrail:GetTrail
cloudtrail:GetTrailStatus
cloudtrail:GetEventSelectors
cloudtrail:LookupEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:FilterLogEvents
logs:DescribeMetricFilters
cloudwatch:ListMetrics
cloudwatch:GetMetricData
cloudwatch:GetMetricStatistics
cloudwatch:DescribeAlarms
cloudwatch:DescribeAlarmHistory
sns:GetTopicAttributes
sns:ListSubscriptionsByTopic
events:ListRules
events:DescribeRule
events:ListTargetsByRule
```

Webコンソールは一覧・タグ・詳細表示のため、上記以外の`List*`、`Get*`、`Describe*`を呼ぶ場合がある。実際のRoleは現場の最小権限設計とコンソール利用要件に従う。

### 11.2 要件別変更権限

| 要件 | 主な変更権限 | 備考 |
| :--- | :--- | :--- |
| 4.1 | `sts:AssumeRole`、管理者側のテストBucket作成・削除権限 | テストRoleの`PutBucketTagging`は明示的Deny |
| 4.2、4.6 | `iam:CreateUser`、`iam:CreateLoginProfile`、`iam:DeleteLoginProfile`、`iam:DeleteUser`、`iam:TagUser` | IAM担当による事前作成でも可 |
| 4.3 | root認証情報と登録済みMFA | IAM権限では代替不可 |
| 4.4 | `iam:CreatePolicy`、`iam:TagPolicy`、`iam:DeletePolicy`、`iam:GetPolicy`、`iam:ListEntitiesForPolicy` | Policyをアタッチしない |
| 4.5 | `cloudtrail:UpdateTrail`、代替時は`CreateTrail`、`StartLogging`、`DeleteTrail`とS3関連権限 | 中央管理TrailではA-gate側作業となる場合あり |
| 4.7 | `kms:CreateKey`、`CreateAlias`、`TagResource`、`DescribeKey`、`DisableKey`、`EnableKey`、`ScheduleKeyDeletion`、`CancelKeyDeletion`、`DeleteAlias` | Key Policyでも許可が必要 |
| 4.8 | `s3:CreateBucket`、`PutBucketPolicy`、`DeleteBucketPolicy`、`GetBucketPolicy`、`DeleteBucket`、タグ関連権限 | Public化Policyは使用しない |
| 4.9 | `config:PutConfigRule`、`DeleteConfigRule`、`DescribeConfigRules`、Recorder/Channel参照権限 | Organization管理との競合確認が必須 |
| 4.10 | `ec2:CreateSecurityGroup`、`AuthorizeSecurityGroupIngress`、`RevokeSecurityGroupIngress`、`DeleteSecurityGroup`、`CreateTags` | 未関連付けSGのみ |
| 4.11 | `ec2:CreateNetworkAcl`、`CreateNetworkAclEntry`、`DeleteNetworkAclEntry`、`DeleteNetworkAcl`、`CreateTags` | Subnet関連付けは禁止 |
| 4.12 | `ec2:CreateInternetGateway`、`AttachInternetGateway`、`DetachInternetGateway`、`DeleteInternetGateway`、`CreateTags` | テストVPCのみ |
| 4.13 | `ec2:CreateRouteTable`、`CreateRoute`、`DeleteRoute`、`DeleteRouteTable`、`CreateTags` | Main/業務Tableは禁止 |
| 4.14 | `ec2:CreateVpc`、`DeleteVpc`、`CreateTags`と関連Describe権限 | CIDR重複確認が必須 |
| 4.15 | `organizations:CreateOrganizationalUnit`、`DeleteOrganizationalUnit`、`List*`、`Describe*` | 管理アカウントだけで実施 |

Identity-based policyでAllowされていても、SCP、Permission Boundary、Session Policy、Resource-based policy、KMS Key Policy、A-gateによる明示的Denyがある場合は実行できない。明示的Denyを検出した場合、迂回や別操作を試さず、拒否されたAction、対象Resource ARN、作業Role ARN、発生時刻、Request IDを管理者へ連携する。

## 12. トラブルシューティング

### 12.1 CloudTrailイベントが見つからない

1. 操作がAWS APIまで到達し、画面上で成功または想定したAccessDeniedとなったか確認する。
2. CloudTrail Event historyの時間範囲、Region、Read-onlyフィルターを確認する。
3. Event nameは完全一致で検索する。
4. Management EventのRead/Write対象を確認する。
5. IAM、root、OrganizationsなどGlobal service eventの記録Regionを確認する。
6. `ConsoleLogin`はサインインEndpointにより記録Regionが変わるため、4.2、4.3、4.6の記載Regionを確認する。
7. WinAuth、SAML、IAM Identity Centerの認証失敗がAWS Sign-In Endpointへ到達していない場合、`ConsoleLogin`は生成されない。
8. A-gateや別アカウントのOrganization Trailにだけ記録される設計か確認する。
9. 同じ操作を連打せず、5～15分待って再検索する。

### 12.2 CloudTrailにはあるがCloudWatch Logsにない

1. Event recordの`eventTime`と`awsRegion`を記録する。
2. 対象TrailのCloudWatch Logs Log Group ARNとRole ARNを確認する。
3. Log Group名だけでなく、Account、Region、ARN末尾を確認する。
4. CloudTrail Statusの最新配信エラーを確認する。
5. 配信用RoleのTrust policyが`cloudtrail.amazonaws.com`を許可していることを確認する。
6. Role policyが対象Log GroupのLog Stream作成とLog Event書き込みを許可していることを確認する。
7. KMS暗号化Log Groupの場合、CloudTrail配信経路に必要なKMS権限を確認する。
8. 15～20分待っても届かない場合、実イベント再実行ではなく配信障害として切り分ける。

### 12.3 CloudWatch LogsにはあるがMetricが増えない

1. Metric Filterを作成した時刻より後のイベントか確認する。過去ログは遡及評価されない。
2. Raw JSONのフィールド名、大文字・小文字、値をFilter Patternと比較する。
3. Pattern Testへ同じRaw Eventを入力し、一致数を確認する。
4. Filter Patternに余分な引用符、改行、全角文字がないか確認する。
5. Metric Namespace、Metric Name、Metric ValueがAlarm設計と一致するか確認する。
6. 4.1は`errorCode`、4.2、4.3、4.6は`ConsoleLogin`固有フィールド、4.15はRead-onlyイベント混入を重点確認する。
7. Patternの誤りをその場で変更せず、設計変更として承認を取得する。

### 12.4 Metricは増えたがAlarmが`ALARM`にならない

1. Alarmが同じAccount、Region、Namespace、Metric Nameを参照しているか確認する。
2. Statisticが`Sum`、Period、Threshold、Evaluation periods、Datapoints to alarmが設計値どおりか確認する。
3. Missing dataが`notBreaching`など確定済み設計と一致するか確認する。
4. Alarm作成後のDatapointであることを確認する。
5. Alarmが試験前から`ALARM`でなかったかAlarm Historyを確認する。
6. Period境界と評価遅延を考慮し、15～20分待つ。
7. `SetAlarmState`で見かけ上の結果を作らず、MetricとAlarmの関係を切り分ける。

### 12.5 Alarmは`ALARM`だが通知が届かない

1. Alarm Historyで「通知アクションを実行した」記録を確認する。
2. `Actions enabled`が有効であることを確認する。
3. ALARM actionのSNS Topic ARNが設計値と一致するか確認する。
4. SNS Subscriptionが`Confirmed`または有効であることを確認する。
5. SNS Topic Policy、KMS Key Policy、送信元Alarmの許可を確認する。
6. メール迷惑フォルダ、Teams連携、監視基盤側のフィルターと遅延を確認する。
7. Alarm通知は基本的に状態遷移時に行われるため、すでに`ALARM`中の追加イベントでは再通知されない可能性を確認する。
8. SNS配信ログまたは通知中継先のログを、権限を持つ担当へ確認依頼する。

### 12.6 テストリソースを削除できない

1. Resource ARN、Name、Tagがテスト専用であることを再確認する。
2. Dependency一覧を確認する。
3. 4.8はBucket Policy、Object、Versioned Objectを確認する。
4. 4.10はENI関連付け、4.11はSubnet associationを確認する。
5. 4.12はRouteとVPC Attach、4.13はRouteとAssociationを確認する。
6. 4.14はVPC内の全依存リソースを確認する。
7. 4.15はAccount、子OU、Policy関連付けが0であることを確認する。
8. 自動修復またはA-gateがリソースを再作成・保護している場合、繰り返し削除せず管理者へ連携する。

### 12.7 A-gate経路で通知を確認できない

1. 対象要件番号とEventBridge Ruleの対応関係を正式資料で再確認する。
2. Event Patternへ実イベントの`source`、`detail-type`、`detail.eventSource`、`detail.eventName`を当てはめる。
3. Ruleが`Enabled`であることを確認する。
4. `MatchedEvents`が0の場合、Event Pattern不一致、Region相違、Event Bus相違を確認する。
5. `MatchedEvents`が1以上で`Invocations`が0の場合、RuleとTargetの関連付けを確認する。
6. `FailedInvocations`が1以上の場合、Target policy、送信先Event Bus policy、IAM Role、Retry policy、Dead-letter queueを確認する。
7. 送信先が別アカウントの場合、送信元だけで受信成立と判断せず、A-gate担当の受信記録を取得する。
8. 受信済みで通知がない場合、A-gate側の通知条件、抑制、重複排除、通知先障害を確認する。
9. 権限不足でTarget ARNやMetricを確認できない場合、推測で合格にせず、管理担当の確認結果を証跡にする。
10. 既存Ruleをその場で変更せず、調査結果と再試験条件を管理担当へ連携する。

削除・切り戻し操作自体が監視対象イベントとなり、追加Alarmが発生する。これは試験失敗ではなく、設計どおりの追加検知として時刻と通知を記録する。

## 13. 合否判定

| 判定 | 条件 |
| :--- | :--- |
| 合格 | 実操作、CloudTrail、CloudWatch Logs、Metric、Alarm状態遷移、通知受信、復旧・削除を一連の証跡で追跡できる |
| 条件付き合格 | 実イベント以外は成立し、root・Organizationsなど統制上禁止された実操作だけが承認済み代替試験となっている |
| 不合格 | CloudTrailイベントがない、Logsへ届かない、Filter不一致、Alarm不遷移、通知未達、または後片付け未完了のいずれかがある |
| 中止 | 業務リソース変更、明示的Deny、対象誤り、戻し不能、権限・承認不足、想定外自動処理を検出した |

不合格または中止の場合、「設定を再実施した回数」ではなく、停止した層、確認結果、影響、暫定措置、再試験条件を記録する。

## 14. 公式ドキュメント

- [CloudTrailイベント履歴の表示](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/view-cloudtrail-events-console.html)
- [AWS Management Consoleサインインイベント](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-event-reference-aws-console-sign-in-events.html)
- [CloudTrailイベントレコードの内容](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-event-reference-record-contents.html)
- [CloudTrailイベント用CloudWatch Alarmの作成](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html)
- [AWSアカウントrootユーザーのベストプラクティス](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/root-user-best-practices.html)
- [IAM Policyの作成](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/access_policies_create-console.html)
- [IAM Policyの削除](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/access_policies_manage-delete-console.html)
- [CloudTrail Trailの作成・更新](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-create-and-update-a-trail-by-using-the-console.html)
- [CloudTrail Trailの更新](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-update-a-trail-console.html)
- [KMS Keyの削除](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys.html)
- [KMS Keyの削除予約](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html)
- [KMS Keyの削除予約キャンセル](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys-cancelling-key-deletion.html)
- [KMS Keyの有効化](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/enabling-keys.html)
- [S3 Bucket Policyの追加](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/add-bucket-policy.html)
- [S3 Bucketの削除](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/delete-bucket.html)
- [AWS Config Ruleの追加](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/evaluate-config_add-rules.html)
- [AWS Config Managed Rule required-tags](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/required-tags.html)
- [VPC Security Group](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-security-groups.html)
- [Security Group Rule](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/security-group-rules.html)
- [Network ACLの作成](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/create-network-acl.html)
- [Network ACL Rule](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/nacl-rules.html)
- [Internet Gateway](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [Internet Gatewayの作成・Attach・Detach](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/working-with-igw.html)
- [Amazon VPCクォータ](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/amazon-vpc-limits.html)
- [VPC Route Table](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Route_Tables.html)
- [Subnet Route Tableと関連付け](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/subnet-route-tables.html)
- [VPCの作成](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/create-vpc.html)
- [VPCの削除](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/delete-vpc.html)
- [AWS Organizationsのチュートリアル](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/orgs_tutorials_basic.html)
- [Organizational Unitの削除](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/delete-ou.html)
- [EventBridgeのアカウント間イベント送受信](https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-cross-account.html)
- [EventBridgeイベント配信モニタリングのベストプラクティス](https://docs.aws.amazon.com/ja_jp/eventbridge/latest/userguide/eb-monitoring-events-best-practices.html)
- [RFC 5737 IPv4 Address Blocks Reserved for Documentation](https://datatracker.ietf.org/doc/html/rfc5737)
