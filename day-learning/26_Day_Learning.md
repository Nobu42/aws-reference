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

# Exercise 8: 構成図を見た後の作業初動依頼

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
Exercise 8: 構成図を見た後の作業初動依頼
```

必須候補:

```text
1. Exercise 1
2. Exercise 3
3. Exercise 8
```

余力があれば、Exercise 4またはExercise 5を追加する。

---

## 要確認事項

```text
実案件で使用する共通関数シェルの命名規則
実案件での証跡保存先
実案件での承認フロー
実案件での作業時間帯
実案件でのCloudTrail保存先とCloudWatch Logs連携有無
実案件でのS3 Data Event利用可否
実案件でのAthena、CloudTrail Lake、JP1、Hinemos等の利用有無
```
