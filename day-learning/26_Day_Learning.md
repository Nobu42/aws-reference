# Day 26 Learning: 現場指示型・総合演習

## 学習開始前に実行するスクリプト

Day 26は、これまでのDayで学習した内容を使って、現場で指示されそうな作業を自力で組み立てる総合演習である。

最初からすべての環境を起動しない。お題ごとに必要なものだけ起動する。

```text
All_Setup.sh:
  S3、Rails、PutObject、CloudTrail Data Eventを確認するお題で必要

Ansible:
  RailsアプリケーションやCloudWatch Logs連携を確認するお題で必要

CloudTrail一時Trail:
  CloudTrail保存先S3、CloudWatch Logs連携、S3 Data Eventを確認するお題で必要

S3 Data Event:
  PutObject、DeleteObjectなどS3オブジェクト操作の証跡を見るお題でのみ一時的に有効化する
```

実行場所を統一する。

```bash
cd /Users/nobu/aws-reference/day-learning
```

事前に残存リソースと費用を確認する。

```bash
/Users/nobu/aws-reference/scripts/check_cleanup.sh

/Users/nobu/aws-reference/scripts/check_cost.sh
```

AWS環境を使うお題では、作業前に必ず次を確認する。

```bash
aws sts get-caller-identity \
  --profile learning \
  --output json \
  --no-cli-pager
```

---

## 目的

これまでのDay Learningは、手順をなぞってAWS CLIや設定変更の流れを身につけることが中心だった。

Day 26では、あえて詳細手順を少なくし、現場でありそうな依頼文から次を自分で組み立てる。

```text
何を確認するか
どのAWS CLIを使うか
どの証跡を残すか
どこで止まるべきか
どう報告するか
どう切り戻すか
```

この日のゴールは、すべてを暗記することではない。指示を受けたときに、落ち着いて作業を分解できることを目指す。

---

## 今日のルール

```text
1. いきなり変更しない
2. 最初に対象、目的、影響範囲、承認有無を整理する
3. before証跡を必ず残す
4. 変更案はdiffで確認する
5. validateできるものはvalidateする
6. 変更後はafter証跡を残す
7. CloudTrailまたはCloudWatch Logsで変更履歴を確認する
8. 切り戻し手順と切り戻し後確認を残す
9. 分からないことは要確認事項として書く
10. 最後に3行報告を作る
```

Day 26では、過去Dayの手順を見てもよい。ただし、コマンドをそのままコピーする前に、何を確認するためのコマンドかを1行で書く。

---

## 成果物

各お題ごとに、次のような証跡ディレクトリを作る。

```text
26_Day_Learning/evidence/<timestamp>_<exercise_name>/
```

例:

```text
26_Day_Learning/evidence/20260630_060000_ex01_s3_policy_change/
```

各お題で最低限残すもの:

| 種類 | 内容 |
|---|---|
| 作業メモ | 依頼内容、前提、対象、要確認事項 |
| before証跡 | 変更前設定 |
| change証跡 | 変更案、diff、validate結果 |
| after証跡 | 変更後設定、テスト結果 |
| audit証跡 | CloudTrail、CloudWatch Logs、Alarm履歴など |
| rollback証跡 | 切り戻し手順、切り戻し後確認 |
| 報告文 | 作業完了報告、または未完了報告 |

---

## 使ってよい主な資料

- [Day 2 S3 Bucket Policy変更](./02_Day_Learning.md)
- [Day 3 CloudTrail Trail・S3 Data Event](./03_Day_Learning.md)
- [Day 4 CloudWatch Logs確認](./04_Day_Learning.md)
- [Day 5 CloudTrail to CloudWatch Logs](./05_Day_Learning.md)
- [Day 6 MFAなしConsoleLogin検知](./06_Day_Learning.md)
- [Day 17 運用シェル・共通関数](./17_Day_Learning.md)
- [Day 18 AWSセキュリティ横断チェック](./18_Day_Learning.md)
- [Day 19 作業手順書・証跡整理](./19_Day_Learning.md)
- [Day 20 模擬作業 S3 Bucket Policy変更](./20_Day_Learning.md)
- [Day 21 模擬作業 GuardDuty・CloudTrail横断調査](./21_Day_Learning.md)
- [Day 24 構成図読解・影響範囲整理](./24_Day_Learning.md)
- [S3セキュリティCLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [S3 Bucket Policy CLIリファレンス](../docs/references/02_s3_bucket_policy_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [S3 Bucket Policy変更手順テンプレート](../docs/templates/s3_bucket_policy_change_procedure_template.md)

---

## お題の進め方

各お題は、次の順番で進める。

```text
1. 依頼文を読む
2. 作業対象を整理する
3. 影響範囲を仮説として書く
4. 変更前確認コマンドを自分で選ぶ
5. 証跡を保存する
6. 変更案を作る
7. 変更前後の差分を確認する
8. validateまたはdry-run相当の確認をする
9. 変更する
10. 変更後確認をする
11. 監査ログを確認する
12. 切り戻しできることを確認する
13. 報告文を書く
```

---

# Exercise 1: S3 Bucket Policy変更依頼

## 現場からの依頼文

```text
対象S3バケットに対して、TLS 1.2未満のアクセスを拒否するBucket Policyを追加してください。

影響調査は完了済みです。
対象バケットは nobu-terraform-iac-lab-upload です。
既存のDenyInsecureTransportは残してください。
変更後、Policyが意図通り反映されたこと、BucketがPublicではないこと、CloudTrailで変更履歴が確認できることを証跡として残してください。
切り戻しできる状態で作業してください。
```

## 自分で判断すること

```text
変更前に何を保存するか
どのPolicyを追加するか
validate-policyを使うか
diffでどこを見るか
反映後の差分が順序差分だけだった場合にどう判断するか
CloudTrailでどのEventNameを見るか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 変更前Policy | `before/bucket-policy-before.json` |
| 変更後Policy案 | `change/bucket-policy-after.json` |
| Policy検証 | `change/validate-policy.json` |
| 差分 | `change/policy-diff.txt` |
| 反映後Policy | `after/bucket-policy-applied.json` |
| Public確認 | `after/public-access-check.json` |
| CloudTrail | `audit/put-bucket-policy-event.json` |
| 切り戻しPolicy | `rollback/bucket-policy-rollback.json` |

## 完了条件

```text
DenyInsecureTransportが残っている
DenyOutdatedTLS相当のStatementが追加されている
s3:TlsVersionの条件がある
aws:PrincipalIsAWSServiceの除外条件がある
Access Analyzerのvalidate-policyで重大なエラーがない
get-bucket-policyで反映後Policyを取得できる
get-bucket-policy-statusでIsPublic=Falseを確認できる
CloudTrailでPutBucketPolicyを確認できる
切り戻し用Policyが保存されている
```

## 停止条件

```text
対象バケット名、アカウントID、リージョンが依頼と一致しない
既存Policyに外部アカウント許可や重要なConditionがあり、意味が判断できない
validate-policyでERROR相当のFindingが出る
変更後にPublic化する可能性がある
切り戻し用Policyを保存できていない
```

## 報告文テンプレート

```text
対象バケット nobu-terraform-iac-lab-upload に対して、TLS 1.2未満を拒否するBucket Policyを追加しました。
変更前後のPolicy、Access Analyzer検証、Public状態、CloudTrailのPutBucketPolicyイベントを証跡として保存済みです。
切り戻し用の変更前Policyも保存済みです。
```

---

# Exercise 2: S3暗号化・Ownership・ACL確認依頼

## 現場からの依頼文

```text
対象S3バケットのセキュリティ設定を確認してください。

確認対象は、Public Access Block、Bucket Policy、ACL、Object Ownership、Default Encryption、Versioning、Server Access Loggingです。
今回は変更不要です。
設定値とリスク有無を一覧化してください。
```

## 自分で判断すること

```text
どの設定は問題なしと言えるか
どの設定は要確認にすべきか
ACLが無効化されている状態をどう読むか
SSE-S3、SSE-KMS、SSE-C拒否をどう説明するか
Versioningがnullの場合にどう書くか
Server Access Logging未設定をどう扱うか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| Public Access Block | `before/public-access-block.json` |
| Policy Status | `before/policy-status.json` |
| Bucket Policy | `before/bucket-policy.json` |
| ACL | `before/bucket-acl.json` |
| Ownership | `before/ownership-controls.json` |
| Encryption | `before/encryption.json` |
| Versioning | `before/versioning.json` |
| Logging | `before/logging.json` |
| 確認結果一覧 | `summary/s3-security-check-summary.md` |

## 完了条件

```text
各設定の取得コマンドを自分で選べている
結果をそのまま貼るだけでなく、読み方を1行ずつ書いている
問題なし、要確認、変更候補を分けている
変更しない理由を書いている
```

## 報告文テンプレート

```text
対象S3バケットのセキュリティ設定を確認しました。
Public Access Block、Policy Status、ACL、Object Ownership、暗号化、Versioning、Loggingの証跡を保存済みです。
現時点で即時変更が必要な項目はありませんが、要確認事項として〇〇を整理しました。
```

---

# Exercise 3: CloudTrailで変更者・変更内容を追跡する依頼

## 現場からの依頼文

```text
対象S3バケットのBucket Policyがいつ誰により変更されたか確認してください。

PutBucketPolicyイベントを調べ、実行者、実行時刻、Source IP、UserAgent、対象バケット、変更されたPolicy内容を証跡として残してください。
lookup-eventsでRate exceededが出る場合は、条件を狭めるか時間を置いて再実行してください。
```

## 自分で判断すること

```text
EventNameで探すか、ResourceNameで探すか
EventIdを取得して詳細を見るか
CloudTrailEventをどう整形するか
table出力ではなくjsonやformat_json_awk.shを使うか
Rate exceededが出た場合にどう回避するか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| PutBucketPolicy一覧 | `audit/put-bucket-policy-events.json` |
| 対象Event詳細 | `audit/put-bucket-policy-event-detail.json` |
| 要約 | `summary/put-bucket-policy-summary.md` |

## 完了条件

```text
EventTimeをUTCとJSTのどちらで見ているか説明できる
UsernameまたはAssumedRoleを読める
sourceIPAddressを確認できる
userAgentからCLI、SDK、Consoleの区別ができる
requestParameters内のbucketPolicyを確認できる
Rate exceeded時に連打しない
```

## 報告文テンプレート

```text
対象バケットのPutBucketPolicyイベントを確認しました。
実行者は〇〇、実行時刻は〇〇、Source IPは〇〇、UserAgentは〇〇です。
イベント詳細と変更Policy内容を証跡として保存済みです。
```

---

# Exercise 4: RailsアプリからのS3 PutObject確認依頼

## 現場からの依頼文

```text
アプリケーションからS3へ画像アップロードした際の証跡を確認してください。

CloudTrailのS3 Data Eventを一時的に有効化し、Railsアプリから画像をアップロードしてください。
PutObjectイベントが記録されること、実行主体がEC2のIAM Roleであること、userAgentがaws-sdk-rubyであることを確認してください。
確認後、S3 Data Eventの設定は元に戻してください。
```

## 自分で判断すること

```text
All_Setup.shとAnsibleが必要か
一時Trailが存在するか
S3 Data Eventを有効化するタイミング
どのEvidence Directoryを使ってrestoreするか
PutObjectが出るまで何分待つか
AssumedRoleをどう読むか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| Trail確認 | `before/trail-check.json` |
| Data Event有効化証跡 | `change/enable-s3-data-events/` |
| PutObject確認 | `audit/putobject-events.json` |
| Event詳細 | `audit/putobject-event-detail.json` |
| Restore証跡 | `rollback/restore-s3-data-events/` |
| Restore後確認 | `rollback/event-selectors-after-restore.json` |

## 完了条件

```text
PutObjectイベントを1件以上確認できる
eventName=PutObjectを確認できる
bucketNameが対象S3バケットである
keyがアップロードされたオブジェクトである
userIdentity.arnがAssumedRoleである
sessionIssuer.arnがEC2用IAM Roleである
userAgentにaws-sdk-rubyが含まれる
S3 Data Eventを元に戻している
```

## 停止条件

```text
Trailが存在しない
Event Selectorの元設定を保存できていない
Data Eventを有効化したまま作業終了しそうになった
Railsアプリからアップロードできない
PutObjectが出ない理由を切り分けできない
```

## 報告文テンプレート

```text
RailsアプリからS3への画像アップロードを実施し、CloudTrail S3 Data EventでPutObjectを確認しました。
実行主体はEC2のIAM RoleからAssumeされた一時認証情報で、userAgentはaws-sdk-rubyでした。
確認後、S3 Data Event設定は元のEvent Selectorへ戻しています。
```

---

# Exercise 5: MFAなしConsoleLogin検知設定の確認依頼

## 現場からの依頼文

```text
CloudTrailの管理イベントをCloudWatch Logsへ連携し、MFAなしのConsoleLoginを検知できる設定になっているか確認してください。

検証用Log GroupでMetric FilterとCloudWatch Alarmを作成し、MFAUsed=Yesでは検知されず、MFAUsed=Noでは検知されることを確認してください。
通知Actionは無効のままにしてください。
検証後は作成したAlarm、Metric Filter、Log Groupを削除してください。
```

## 自分で判断すること

```text
本物のConsoleLoginを使うか、検証用ログを使うか
FILTER_PATTERNをどう書くか
test-metric-filterで何を確認するか
Metricが出るまで何分待つか
AlarmがOKに戻った場合に履歴を見るか
ActionsEnabled=falseをどう確認するか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| CloudTrail連携確認 | `before/cloudtrail-cloudwatch-logs-check.json` |
| Metric Filter作成後 | `change/metric-filter-created.json` |
| Alarm作成後 | `change/alarm-created.json` |
| MFAUsed=Yesテスト | `test/mfa-used-yes-result.json` |
| MFAUsed=Noテスト | `test/mfa-used-no-result.json` |
| Metric確認 | `test/metric-statistics.json` |
| Alarm状態 | `test/alarm-after-test.json` |
| Alarm履歴 | `test/alarm-history-after-test.json` |
| 削除後確認 | `rollback/after-delete.json` |

## 完了条件

```text
MFAUsed=Yesが検知対象外である
MFAUsed=Noが検知対象である
Custom MetricにDatapointが出る
Alarm状態またはAlarm履歴で評価されたことを確認できる
Alarm Actionが無効である
作成した検証用リソースを削除している
```

## 報告文テンプレート

```text
検証用Log Groupにて、MFAなしConsoleLogin検知用のMetric FilterとCloudWatch Alarmを確認しました。
MFAUsed=Yesは検知対象外、MFAUsed=Noは検知対象となり、Custom MetricとAlarm履歴で評価を確認済みです。
通知Actionは無効で、検証後に作成リソースは削除済みです。
```

---

# Exercise 6: 共通関数シェル経由のAWS CLI作業依頼

## 現場からの依頼文

```text
現場標準の共通関数シェルを読み込み、設定ファイルでアカウント、リージョン、対象バケットを切り替えて、S3設定確認を実施してください。

直接awsコマンドを手打ちするのではなく、共通関数のラッパーを使って実行してください。
実行ログ、設定ファイル、使用した関数名、実行結果を証跡として残してください。
```

## 自分で判断すること

```text
設定ファイルのどの値が環境差分か
共通関数が内部でどのawsコマンドを呼んでいるか
profile、region、account、bucketをどこで切り替えるか
ログ出力先はどこか
エラー時に関数内部とAWS CLIのどちらを見るか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 使用設定ファイル | `before/env.conf` |
| 使用関数一覧 | `summary/functions-used.md` |
| 実行ログ | `logs/run.log` |
| S3確認結果 | `after/s3-security-check.json` |
| エラー時メモ | `summary/error-handling.md` |

## 完了条件

```text
共通関数ファイルをsourceしている
設定ファイルからprofile、region、bucketを読んでいる
直接値を埋め込まず、変数経由で実行している
関数内部で実行されるAWS CLIの意味を説明できる
実行ログから成功、失敗、対象を追える
```

## 報告文テンプレート

```text
現場標準の共通関数シェルを利用し、設定ファイルで対象環境を指定してS3設定確認を実施しました。
使用した関数、設定ファイル、実行ログ、確認結果を証跡として保存済みです。
```

---

# Exercise 7: SSE-KMS化前の影響確認依頼

## 現場からの依頼文

```text
対象S3バケットのデフォルト暗号化をSSE-KMSへ変更する案があります。

今回は変更しません。
変更した場合に影響しそうなIAM Role、Bucket Policy、KMS Key Policy、アプリケーション、バッチ、HULFT連携を洗い出してください。
```

## 自分で判断すること

```text
現在の暗号化方式は何か
KMS Keyを使う場合に誰へkms:Encrypt、kms:Decryptが必要か
S3へのPutObjectだけでなくGetObjectにも影響するか
CloudTrailでKMS関連イベントを見る必要があるか
バッチ、HULFT、EC2 Role、外部アカウントの確認が必要か
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 現在の暗号化設定 | `before/bucket-encryption.json` |
| Bucket Policy | `before/bucket-policy.json` |
| IAM Role候補 | `summary/iam-role-candidates.md` |
| KMS影響整理 | `summary/kms-impact-analysis.md` |
| 要確認事項 | `summary/questions.md` |

## 完了条件

```text
SSE-S3とSSE-KMSの違いを説明できる
KMS Key PolicyとIAM Policyの両方を見る必要性を説明できる
書き込み主体と読み取り主体を分けて整理できる
変更しない理由を明記している
現場へ確認する質問が具体的である
```

## 報告文テンプレート

```text
対象S3バケットのSSE-KMS化に伴う影響範囲を整理しました。
現在の暗号化設定、Bucket Policy、利用主体候補を確認し、KMS Key PolicyおよびIAM権限で追加確認が必要な項目を洗い出しています。
今回は設定変更は実施していません。
```

---

# Exercise 8: SSE-KMS S3オブジェクト暗号化ハンズオン

## 現場からの依頼文

```text
対象S3バケットで、SSE-KMSを使用したオブジェクトアップロードと読み取り確認を実施してください。

今回はバケット全体のデフォルト暗号化は変更しません。
テストオブジェクト単位でSSE-KMSを指定し、PutObject、HeadObject、GetObject、CloudTrailの証跡を確認してください。

KMS Key PolicyやIAM Policyが不足すると、PutObjectやGetObjectが失敗する可能性があることを説明できるようにしてください。
```

## 推奨する進め方

```text
基本演習:
  AWS管理KMSキーを使ってSSE-KMSオブジェクトを作成する
  カスタマー管理KMSキーは作成しない

追加演習:
  時間と費用を許容できる場合のみ、カスタマー管理KMSキーの作成、Alias、Key Policy、削除予定を確認する
```

KMSのカスタマー管理キーは、作成すると少額でも料金が発生し得る。案件前の学習では、まず基本演習だけでよい。

## 自分で判断すること

```text
対象バケットの現在のDefault Encryptionは何か
テストオブジェクトだけSSE-KMSにするか
どのKMS Key IDまたはAliasを使うか
PutObject時に必要な権限は何か
GetObject時に必要な権限は何か
HeadObjectでどの項目を見ればSSE-KMSと分かるか
CloudTrailでKMS関連イベントを見る必要があるか
テストオブジェクトを削除するか、証跡として残すか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 作業メモ | `summary/sse-kms-hands-on-note.md` |
| 変更前暗号化設定 | `before/bucket-encryption.json` |
| KMS Alias確認 | `before/kms-aliases.json` |
| PutObject結果 | `change/put-sse-kms-object-result.json` |
| HeadObject結果 | `after/head-sse-kms-object.json` |
| GetObject結果 | `after/get-sse-kms-object-result.txt` |
| CloudTrail PutObject確認 | `audit/putobject-sse-kms-event.json` |
| 削除確認 | `rollback/delete-test-object-result.json` |
| KMS影響整理 | `summary/kms-permission-summary.md` |

## 確認観点

```text
S3側:
  ServerSideEncryption が aws:kms になっているか
  SSEKMSKeyId が記録されているか
  BucketKeyEnabled の有無

IAM側:
  PutObjectにはs3:PutObjectが必要
  SSE-KMS利用時はkms:Encryptやkms:GenerateDataKeyが関係する
  GetObjectにはs3:GetObjectが必要
  SSE-KMS復号時はkms:Decryptが関係する

KMS側:
  KMS KeyがEnabledか
  AWS管理キーかカスタマー管理キーか
  カスタマー管理キーの場合はKey Policyも見る

CloudTrail側:
  PutObjectのuserIdentity
  userAgent
  requestParameters.bucketName
  requestParameters.key
  requestParameters.x-amz-server-side-encryption
```

## 完了条件

```text
SSE-KMSを指定したPutObjectを実施している
HeadObjectでServerSideEncryption=aws:kmsを確認している
GetObjectで復号された内容を取得できることを確認している
KmsKeyIdまたはSSEKMSKeyIdの意味を説明できる
S3権限だけでなくKMS権限が必要になる理由を説明できる
テストオブジェクトの扱いを明記している
バケット全体のDefault Encryptionは変更していない
```

## 停止条件

```text
対象バケット名、アカウントID、リージョンが不明
KMS Key IDの意味が分からないまま既存設定を変更しようとしている
カスタマー管理KMSキーを作成した後の削除予定を理解していない
本番相当のBucket Default Encryptionを変更しようとしている
KMS権限不足エラーをS3 Bucket Policyだけの問題と判断している
```

## 報告文テンプレート

```text
対象S3バケットに対して、テストオブジェクト単位でSSE-KMSを指定したPutObject、HeadObject、GetObjectを確認しました。
HeadObjectによりServerSideEncryption=aws:kmsを確認し、KMS利用時はS3権限に加えてkms:Encrypt、kms:GenerateDataKey、kms:Decrypt等の権限確認が必要であることを整理しています。
今回はバケット全体のデフォルト暗号化設定は変更していません。
```

---

# Exercise 9: 構成図を見た後の作業初動依頼

## 現場からの依頼文

```text
構成図上で、対象S3バケットに対してアプリ、HULFT、Linux認証サーバ、バッチサーバが関連していることが分かりました。

Bucket Policy変更作業に入る前に、影響範囲と確認観点を整理してください。
技術的に分かる範囲と、現場へ確認すべき範囲を分けてください。
```

## 自分で判断すること

```text
どのシステムがS3へ書き込むか
どのシステムがS3から読み込むか
どのIAM Principalが使われているか
どの通信経路を通るか
どの時間帯にテストすべきか
誰に確認すべきか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 構成図読解メモ | `summary/architecture-reading.md` |
| 影響範囲一覧 | `summary/impact-scope.md` |
| 変更前確認観点 | `summary/before-checks.md` |
| 変更後確認観点 | `summary/after-checks.md` |
| 質問一覧 | `summary/questions-to-site.md` |

## 完了条件

```text
S3を中心に、利用者、認証主体、通信経路、ログを整理できている
HULFTが直接S3を触るのか、後段Linuxサーバが触るのかを要確認にしている
Linux認証サーバがIAM認証とは別物である可能性を切り分けている
作業時間帯と業務影響を確認項目に入れている
不明点を曖昧な不安ではなく質問文に変換している
```

## 報告文テンプレート

```text
構成図をもとに、対象S3バケットのBucket Policy変更に伴う影響範囲を整理しました。
アプリ、HULFT、Linuxサーバ、バッチの利用有無、IAM Principal、通信経路、ログ確認先を観点化しています。
不明点は要確認事項として質問一覧にまとめました。
```

---

# Exercise 10: EC2バッチからS3 PutObject確認依頼

## 現場からの依頼文

```text
バッチサーバから対象S3バケットへファイルをアップロードする処理があります。

Bucket Policy変更後も、バッチからS3へのPutObjectが問題なく実行できることを確認してください。
今回はJP1やHULFTの実機は使わず、EC2上の手動実行シェルでバッチ相当の動きを再現してください。

実行サーバ、実行ユーザー、IAM Role、S3オブジェクトキー、終了コード、CloudTrail S3 Data EventのPutObject証跡を残してください。
確認後、作成したテストファイルや一時設定は片付けてください。
```

## 想定する構成

```text
ローカル端末
  ↓ Ansible / SSH相当
EC2 awsref-web01 または awsref-web02
  ↓ バッチ用シェルを手動実行
IAM Role sample-role-web
  ↓ AssumeRoleされた一時認証情報
S3 nobu-terraform-iac-lab-upload
  ↓
CloudTrail S3 Data EventでPutObject確認
```

## 自分で判断すること

```text
All_Setup.shとAnsibleを起動する必要があるか
どのEC2をバッチサーバ相当として使うか
バッチ用シェルをどこに置くか
実行ユーザーは誰か
aws s3 cp と aws s3api put-object のどちらを使うか
バッチログをどこへ残すか
S3 Data Eventをいつ有効化し、いつ元へ戻すか
CloudTrailでPutObjectが出るまで何分待つか
テストオブジェクトを削除するか、証跡として残すか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 作業メモ | `summary/batch-putobject-work-note.md` |
| 実行サーバ確認 | `before/ec2-target-check.md` |
| IAM Role確認 | `before/ec2-iam-role.json` |
| S3 Data Event有効化証跡 | `change/enable-s3-data-events/` |
| バッチシェル | `change/s3_putobject_batch.sh` |
| バッチ実行ログ | `logs/s3_putobject_batch.log` |
| S3アップロード確認 | `after/s3-object-check.json` |
| CloudTrail PutObject確認 | `audit/putobject-event.json` |
| Event Selector復元証跡 | `rollback/restore-s3-data-events/` |
| テストファイル削除確認 | `rollback/s3-object-delete-check.json` |

## バッチシェルに入れる観点

```text
開始時刻を出す
実行ホスト名を出す
実行ユーザーを出す
aws sts get-caller-identityを出す
アップロード対象ファイル名を出す
aws s3 cp または aws s3api put-objectを実行する
終了コードを出す
成功、失敗を明確に出す
```

## 通信要件として読む観点

```text
送信元:
  EC2バッチサーバ

宛先:
  S3バケット

ポート:
  HTTPS 443

認証主体:
  EC2に付与されたIAM Role
  CloudTrail上ではAssumedRoleとして見える

操作:
  PutObject

確認ログ:
  バッチログ
  S3オブジェクト存在確認
  CloudTrail S3 Data Event
```

## 完了条件

```text
EC2上でバッチ相当のシェルを手動実行できる
バッチログに開始、終了、終了コードが残っている
S3へテストオブジェクトが作成されている
CloudTrail S3 Data EventでPutObjectを確認できる
userIdentity.arnがAssumedRoleである
sessionIssuer.arnまたは関連情報からEC2用IAM Roleを確認できる
userAgentからaws-cli実行であることを確認できる
S3 Data Eventを元へ戻している
テストオブジェクトの扱いを明記している
```

## 停止条件

```text
対象EC2が起動していない
対象EC2にIAM Roleが付与されていない
S3 Data Eventの元設定を保存できていない
対象バケット名、アカウントID、リージョンが不明
Bucket PolicyやKMS設定により失敗しているが、影響範囲を判断できない
Data Eventを有効化したまま終了しそうになった
```

## 報告文テンプレート

```text
EC2バッチサーバ相当の手動実行シェルから、対象S3バケットへのPutObjectを確認しました。
実行サーバ、実行ユーザー、IAM Role、S3オブジェクトキー、終了コード、CloudTrail S3 Data EventのPutObject証跡を保存済みです。
確認後、S3 Data Eventは元のEvent Selectorへ戻し、テストオブジェクトの扱いも記録しています。
```

---

# Exercise 11: バックアップ・復旧影響確認依頼

## 現場からの依頼文

```text
対象AWS環境のセキュリティ設定変更に伴い、バックアップや復旧に影響がないか確認してください。

今回は設定変更は行いません。
S3、EC2/EBS、RDS、KMS、AWS Backupまたは既存バッチバックアップの観点で、現在の設定、取得先、保持期間、暗号化、復旧時に必要な権限を整理してください。

特に、S3 Bucket PolicyやKMS Key Policy変更により、バックアップ取得、バックアップ保存、復旧時の読み取りが失敗しないかを確認観点としてまとめてください。
```

## 自分で判断すること

```text
バックアップ対象はS3、EBS、RDS、アプリケーションファイルのどれか
AWS Backupを使っているか、独自バッチやJP1/HULFT連携で取得しているか
バックアップ保存先が同一アカウントか、クロスアカウントか
バックアップ保存先S3にBucket PolicyやKMS Key Policyがあるか
復旧時にGetObject、kms:Decrypt、rds:RestoreDBInstanceFromDBSnapshotなどが必要か
保持期間と削除ルールが設定されているか
バックアップ成功だけでなく復旧テストの有無を確認すべきか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 作業メモ | `summary/backup-impact-work-note.md` |
| S3確認 | `before/s3-backup-related-settings.json` |
| RDSバックアップ確認 | `before/rds-backup-settings.json` |
| EBS Snapshot確認 | `before/ebs-snapshot-settings.json` |
| AWS Backup確認 | `before/aws-backup-settings.json` |
| KMS影響整理 | `summary/kms-backup-impact.md` |
| 復旧観点整理 | `summary/restore-checkpoints.md` |
| 要確認事項 | `summary/questions-to-site.md` |

## 確認観点

```text
S3:
  Versioning
  Lifecycle
  Object Lock利用有無
  バックアップ保存先Bucket Policy
  SSE-S3 / SSE-KMS
  クロスアカウント許可

EC2/EBS:
  EBS暗号化
  Snapshot取得有無
  Snapshotの保持期間
  AMI作成有無

RDS:
  BackupRetentionPeriod
  Automated Backup有効/無効
  Manual Snapshot
  DeletionProtection
  StorageEncrypted
  KmsKeyId

AWS Backup:
  Backup Vault
  Backup Plan
  Backup Rule
  Backup Selection
  Backup Job履歴
  Vault Lock利用有無

KMS:
  バックアップ取得主体にkms:Encrypt権限があるか
  復旧主体にkms:Decrypt権限があるか
  クロスアカウント復旧時にKey Policyが足りるか
```

## 完了条件

```text
どのバックアップ方式を使っているか、または不明かを明記している
S3、EBS、RDS、AWS Backupのうち、確認できた範囲を証跡化している
Bucket Policy変更がバックアップ処理へ影響し得る条件を整理している
KMS利用時に暗号化と復号の両方の権限を見る必要性を説明できる
バックアップ取得だけでなく復旧時の読み取り権限も確認観点に入れている
設定変更は実施していない
現場へ確認する質問が具体的である
```

## 停止条件

```text
バックアップ方式が不明なまま設定変更へ進もうとしている
KMS Key Policyの影響を判断できない
クロスアカウントバックアップの有無が不明
復旧時に誰の権限で読み取るか不明
本番バックアップ設定を変更しようとしている
```

## 報告文テンプレート

```text
対象AWS環境のバックアップ・復旧影響観点を確認しました。
S3、EBS、RDS、AWS Backup、KMSの確認可能な設定を証跡化し、Bucket PolicyやKMS Key Policy変更がバックアップ取得および復旧時の読み取りへ影響し得る点を整理しています。
今回は設定変更は実施していません。未確認項目は要確認事項としてまとめています。
```

---

# Exercise 12: 認証基盤・認証サーバ影響確認依頼

## 現場からの依頼文

```text
構成図上にLinux認証サーバ、AD/LDAP相当の認証基盤、運用端末、AWSアカウントが記載されています。

S3 Bucket PolicyやIAM/KMS関連の設定変更に入る前に、認証基盤とAWS権限の関係を整理してください。

今回は設定変更は行いません。
Linuxログイン認証、アプリケーション認証、AWS IAM認証、AssumeRole、SSO/Federationのどれが関係しているかを分けて、確認済み事項と要確認事項をまとめてください。
```

## 自分で判断すること

```text
Linux認証サーバはOSログイン用か、アプリ認証用か
AWS IAM RoleやIAM Userとは別の認証なのか
運用端末からAWSへ入る経路はConsoleかCLIか踏み台経由か
SSO、SAML、IAM Identity Center、AD連携があるか
EC2がS3へアクセスするときはOSユーザーではなくIAM Roleで認可されることを説明できるか
Bucket PolicyのPrincipalとLinuxユーザーの関係を混同していないか
CloudTrail上でIAMUser、AssumedRole、FederatedUserをどう読むか
```

## 最低限の成果物

| 種類 | ファイル例 |
|---|---|
| 作業メモ | `summary/auth-impact-work-note.md` |
| 認証方式整理 | `summary/authentication-map.md` |
| AWS権限整理 | `summary/aws-authorization-map.md` |
| CloudTrail主体確認 | `audit/cloudtrail-principal-samples.json` |
| 影響範囲整理 | `summary/auth-impact-scope.md` |
| 要確認事項 | `summary/questions-to-site.md` |

## 整理する観点

```text
Linuxログイン認証:
  EC2やオンプレLinuxへ誰がログインできるか
  AD/LDAP/ローカルユーザー/sudo権限など

アプリケーション認証:
  業務アプリのログインユーザー
  アプリ内部の権限
  AWS IAMとは別管理の可能性が高い

AWS管理操作の認証:
  IAM User
  IAM Role
  AssumedRole
  SSO/Federation
  MFA

AWSリソース操作の認可:
  IAM Policy
  Bucket Policy
  KMS Key Policy
  VPC Endpoint Policy

CloudTrail上の見え方:
  userIdentity.type
  userIdentity.arn
  userIdentity.sessionContext.sessionIssuer.arn
  sourceIPAddress
  userAgent
```

## 混同しやすいポイント

```text
Linuxユーザー:
  OSへログインするためのユーザー。
  それだけではS3アクセス権限を持つとは限らない。

IAM Role:
  AWS APIを実行するための権限主体。
  EC2に付与されている場合、アプリやバッチはAssumedRoleとしてS3へアクセスする。

Bucket PolicyのPrincipal:
  S3に対して誰を許可または拒否するかを表すAWS上の主体。
  Linuxユーザー名ではなく、IAM User、IAM Role、AWSアカウント、AWSサービスなどを見る。

認証と認可:
  認証は「誰かを確認すること」。
  認可は「何をしてよいかを許可すること」。
```

## 完了条件

```text
Linux認証、アプリ認証、AWS IAM認証を分けて整理している
Bucket PolicyのPrincipalがAWS上の主体であることを説明できる
EC2上のバッチがS3へアクセスする場合、OSユーザーではなくIAM Roleが重要であることを説明できる
CloudTrailのuserIdentityから実行主体を読める
認証サーバ停止や認証変更がAWS作業へ与える影響を仮説化している
設定変更は実施していない
現場へ確認する質問が具体的である
```

## 停止条件

```text
LinuxユーザーとIAM Roleを混同している
PrincipalにLinuxユーザー名を入れるものと誤解している
SSO/Federationの有無が分からないまま本番権限変更へ進もうとしている
認証サーバの役割が不明なまま影響なしと判断している
本番認証基盤の設定を変更しようとしている
```

## 報告文テンプレート

```text
構成図上の認証基盤について、Linuxログイン認証、アプリケーション認証、AWS IAM認証、AWSリソース認可を分けて整理しました。
S3 Bucket PolicyやKMS Key Policyで見るPrincipalはAWS上のIAM User/Role/Account等であり、Linuxユーザーとは別に確認が必要です。
今回は設定変更は実施していません。SSO/Federation、認証サーバの用途、運用端末からAWSへの接続経路は要確認事項としてまとめています。
```

---

## 自己採点表

各お題の最後に、次を5段階で自己採点する。

| 観点 | 1 | 3 | 5 |
|---|---|---|---|
| 対象確認 | 対象が曖昧 | 対象は分かる | アカウント、リージョン、リソースを証跡で確認した |
| 影響範囲 | ほぼ未整理 | 主な影響は書いた | 利用者、権限、経路、ログ、切り戻しまで整理した |
| コマンド選択 | コピペ中心 | 目的に合うコマンドを選べる | 出力の読み方まで説明できる |
| 証跡 | 一部のみ | before/afterはある | before/change/after/audit/rollbackが揃っている |
| 報告 | 結果だけ | 結果と証跡を報告 | 結果、影響、残課題、次アクションを短く報告できる |

目標は、全項目5ではない。参画前の目安は次でよい。

```text
対象確認: 5
影響範囲: 3以上
コマンド選択: 3以上
証跡: 4以上
報告: 4以上
```

---

## 現場で質問されたときの答え方

## どのくらいできますか

```text
S3 Bucket PolicyなどのAWSセキュリティ設定変更について、変更前確認、Policy差分確認、validate-policy、反映、反映後確認、CloudTrailでの変更履歴確認、切り戻し用証跡の整理まで一通り対応できます。
```

## 具体的には何を見ますか

```text
対象アカウント、リージョン、バケット名、現行Policy、Public Access Block、ACL/Object Ownership、暗号化、Versioning、CloudTrailイベント、必要に応じてCloudWatch LogsやS3 Data Eventを確認します。
```

## 分からない設定が出たらどうしますか

```text
まず公式ドキュメントと既存手順を確認し、影響範囲、変更可否、切り戻し可否を整理します。
判断できないものは、対象、理由、確認したい点を明確にして質問します。
```

---

## Day 26の終了条件

次のうち、最低3つのお題を実施する。

```text
Exercise 1: S3 Bucket Policy変更依頼
Exercise 2: S3暗号化・Ownership・ACL確認依頼
Exercise 3: CloudTrailで変更者・変更内容を追跡する依頼
Exercise 4: RailsアプリからのS3 PutObject確認依頼
Exercise 5: MFAなしConsoleLogin検知設定の確認依頼
Exercise 6: 共通関数シェル経由のAWS CLI作業依頼
Exercise 7: SSE-KMS化前の影響確認依頼
Exercise 8: SSE-KMS S3オブジェクト暗号化ハンズオン
Exercise 9: 構成図を見た後の作業初動依頼
Exercise 10: EC2バッチからS3 PutObject確認依頼
Exercise 11: バックアップ・復旧影響確認依頼
Exercise 12: 認証基盤・認証サーバ影響確認依頼
```

必須候補:

```text
1. Exercise 1
2. Exercise 3
3. Exercise 9
```

余力があれば、Exercise 4、Exercise 5、Exercise 8、Exercise 10、Exercise 11、Exercise 12のいずれかを追加する。

---

## 要確認事項

```text
実案件で使用する共通関数シェルの命名規則
実案件での証跡保存先
実案件での承認フロー
実案件での作業時間帯
実案件でのCloudTrail保存先とCloudWatch Logs連携有無
実案件でのS3 Data Event利用可否
実案件でのSSE-KMS利用有無、KMS Key Policy確認範囲
実案件でのバックアップ方式、保持期間、復旧テスト有無
実案件での認証基盤、SSO/Federation、運用端末からAWSへの接続経路
実案件でのAthena、CloudTrail Lake、JP1、Hinemos等の利用有無
```
