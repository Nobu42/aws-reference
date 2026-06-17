# Day 19 Learning: 作業手順書・証跡整理

## 学習開始前に実行するスクリプト

Day 19は既存資料と過去の証跡を使用して、実際に作業手順書と証跡一覧を組み立てるローカルハンズオンである。AWS環境の構築は不要である。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

過去のローカル証跡を削除せず、必要なファイルを参照して手順書と証跡計画を整理する。

実行場所を統一し、参照できる証跡とテンプレートを確認する。

```bash
cd /Users/nobu/aws-reference

find day-learning/02_Day_Learning -maxdepth 2 -type f | sort

ls -l docs/templates/
```

Day 20で模擬変更する場合は、Day 19で作成した手順書を見ながら作業する。

## 1. 今日の目的

これまでの学習で確認したAWS設定、影響調査、変更、テスト、切り戻し、CloudTrail確認を、現場でレビュー・実施・報告に使える作業手順書へ整理する。

```text
調査で分かったこと
  -> 影響調査へ整理する

承認された変更内容
  -> 1操作1行の変更手順へ整理する

期待する設定と動作
  -> 変更前・変更後確認へ整理する

失敗時の復旧方法
  -> 切り戻し手順へ整理する

画面・CLI・CloudTrail・テスト結果
  -> 証跡一覧へ整理する
```

本ドリルでは、S3 Bucket Policy変更を題材に、Markdownで作業手順書の実例を組み立てる。Markdownは、現場で既存Excelテンプレートを利用できない場合でも、Excelへ一から転記できる構造にする。

設定変更は行わない。Day 20の模擬作業で使用できる手順書と証跡計画を完成させる。

関連資料:

- [Markdown版S3 Bucket Policy変更手順書テンプレート](../docs/templates/s3_bucket_policy_change_procedure_template.md)
- [Excel版S3 Bucket Policy変更手順書テンプレート](../docs/templates/s3_bucket_policy_change_procedure_template.xlsx)
- [共通AWS CLI・証跡保存リファレンス](../docs/references/00_common_aws_cli_reference.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [S3 Bucket Policy CLIリファレンス](../docs/references/02_s3_bucket_policy_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [Day 2 S3 Bucket Policy変更ドリル](./02_Day_Learning.md)
- [Day 12 Security Group変更影響調査・手順書作成](./12_Day_Learning.md)
- [Day 13 Security Group変更・確認・切り戻しドリル](./13_Day_Learning.md)
- [Day 18 AWSセキュリティ横断チェック](./18_Day_Learning.md)
- [S3 Bucket Policy変更ケーススタディ](../docs/case_studies/case_study_s3_bucket_policy_change.md)

---

## 2. 今日の作業シナリオ

次の依頼を受けた想定で手順書を作成する。

```text
対象S3バケットへ、TLS 1.2未満のアクセスを拒否するBucket Policy Statementを追加する。

影響調査は概ね完了している。
変更前確認、変更手順、変更後テスト、切り戻し、証跡一覧を含む
作業手順書を作成する。

作成した手順書はレビュー後に別日程で実施する。
本日は設定変更を行わない。
```

## 今日の確認順序

1. 作業依頼と承認範囲を整理する
2. 手順書の利用者と作業方式を決める
3. Excelへ転記できる章・シート構成を作る
4. 作業概要と対象情報を記載する
5. 変更前確認と証跡を整理する
6. 影響調査結果と未確認事項を整理する
7. 変更内容と差分を記載する
8. 変更手順を1操作1行で記載する
9. 変更後確認と業務テストを記載する
10. 切り戻し条件と切り戻し手順を記載する
11. GUI、CLI、CloudTrail、テスト証跡を一覧化する
12. レビュー観点と承認記録を整理する
13. 手順書を机上確認する
14. Day 20の模擬作業へ引き継ぐ

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| 作業名 | S3 Bucket PolicyへのTLS 1.2未満拒否Statement追加 |
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象バケット | `nobu-terraform-iac-lab-upload` |
| 変更内容 | `DenyOutdatedTLS` Statement追加 |
| 本日の作業 | 手順書、証跡一覧、レビュー観点の作成 |
| 設定変更 | なし |

## 今日実行しない操作

- `put-bucket-policy`によるBucket Policy変更
- `delete-bucket-policy`によるPolicy削除
- Public Access Block、ACL、Object Ownershipの変更
- アプリケーションへの変更
- 承認されていない疎通試験
- 証跡取得を目的とした不要な設定変更
- Day 20の模擬作業を前倒しして実施すること

---

## 3. 手順書の役割

作業手順書は、コマンド集ではない。誰が実施しても、対象を誤らず、異常時に止まり、同じ結果を確認できるようにする文書である。

## 手順書が答える質問

| 質問 | 手順書へ記載する場所 |
|---|---|
| なぜ作業するか | 作業概要、目的 |
| 何を変更するか | 変更内容、差分 |
| どの環境で行うか | Account、Region、対象リソース |
| 誰が実施・確認・承認するか | 体制、レビュー承認 |
| いつ実施するか | 作業日時、作業時間帯 |
| 何に影響するか | 影響調査 |
| 変更前はどうなっているか | 変更前確認 |
| 具体的に何を操作するか | 変更手順 |
| 成功をどう判断するか | 期待結果、変更後確認 |
| 失敗時にどうするか | 異常時対応、切り戻し |
| 何を証拠として残すか | 証跡一覧 |
| 誰へ何を報告するか | 作業後報告 |

## 良い手順書の条件

- 対象Account、Region、Resourceを誤認しにくい
- 1操作1行で追跡できる
- 各手順に期待結果がある
- NGの場合の停止条件と対応先がある
- 変更前設定を保存する
- 変更後設定と業務機能を確認する
- 切り戻し条件と手順が具体的である
- 証跡名が手順No.と対応する
- 不明点を推測で埋めず、要確認として残す
- 作業者とレビュー担当が同じ理解を持てる

---

## 4. 手順書・設計書・証跡・報告の違い

| 文書・記録 | 主な目的 | 主な内容 |
|---|---|---|
| 設計書 | あるべき構成を示す | Architecture、設定値、通信、権限 |
| 影響調査 | 変更による影響を判断する | 利用主体、通信、機能、監視、復旧 |
| 作業手順書 | 安全に作業を実施する | 操作、期待結果、異常時対応、証跡 |
| 試験項目書 | 変更後の正しさを確認する | 正常系、異常系、期待値、結果 |
| 証跡 | 実施事実と結果を示す | GUI、CLI、CloudTrail、ログ、差分 |
| 作業報告 | 結果を関係者へ共有する | 実施内容、結果、影響、残課題 |

同じ内容を複数文書へ書く場合でも、目的に応じて粒度を変える。

---

## 5. Excelへ転記するブック構成

現場でExcel手順書を一から作成する場合、次の9シート構成を基本とする。

| No. | シート名 | 目的 |
|---:|---|---|
| 01 | 作業概要 | 作業目的、対象、日時、担当、承認、前提 |
| 02 | 変更前確認 | 現在設定、期待値、証跡 |
| 03 | 影響調査 | 利用主体、通信、権限、業務影響 |
| 04 | 変更手順 | 1操作1行の作業手順 |
| 05 | 変更後確認 | 設定、機能、監査、監視の確認 |
| 06 | 切り戻し手順 | 判断条件、復元、復旧確認 |
| 07 | 証跡一覧 | GUI、CLI、ログ、差分、CloudTrail |
| 08 | チェックリスト | 作業漏れ防止 |
| 09 | レビュー承認 | 作成、レビュー、承認、結果確認 |

## MarkdownとExcelの対応

| Markdown | Excel |
|---|---|
| `##`見出し | Sheet |
| 表の1行 | Excelの1行 |
| `No.` | 手順番号 |
| Code Block | コマンド列または別紙 |
| Checkbox | 判定・実施結果列 |
| Link | 関連文書・証跡パス |

---

## 6. Excelで作成する場合の基本設定

| 項目 | 推奨 |
|---|---|
| Font | Meiryo UIまたはMS Gothic |
| Font Size | 10または11 |
| Header | 薄い青または薄いグレー |
| Border | 表全体へ細線 |
| Freeze Pane | Header下で固定 |
| Filter | 一覧表へ設定 |
| 日付 | `yyyy/mm/dd hh:mm` |
| Status | 未着手、対応中、完了、保留、対象外 |
| 判定 | 未確認、OK、NG、要確認、対象外 |
| Wrap Text | 手順、期待結果、備考で有効 |

重要:

```text
見栄えを整えることより、
対象、操作、期待結果、異常時対応、証跡を明確にすることを優先する。
```

---

## 7. 作業概要の記載例

| 項目 | 内容 | 備考 |
|---|---|---|
| 作業名 | S3 Bucket Policy TLS 1.2未満拒否追加 |  |
| 作業ID | `<change-id>` | 現場管理番号 |
| 対象システム | 某銀行 振込・電子保管システム想定 | 学習用 |
| 対象AWSアカウント | `445405559057` | 実施直前に再確認 |
| 対象リージョン | `ap-northeast-1` | 東京 |
| 対象サービス | Amazon S3 |  |
| 対象リソース | `nobu-terraform-iac-lab-upload` | Bucket名 |
| 作業目的 | TLS 1.2未満の通信を明示的に拒否する |  |
| 作業方式 | AWS CLIおよびWebコンソール確認 | 現場ルールを優先 |
| 作業担当 | `<name>` |  |
| レビュー担当 | `<name>` |  |
| 承認者 | `<name>` |  |
| 作業予定日時 | `<yyyy/mm/dd hh:mm-hh:mm>` |  |
| サービス停止 | なし想定 | 要確認 |
| 利用者影響 | TLS 1.2未満のClientは接続不可 | 影響調査対象 |
| 変更前Backup | Bucket Policy JSONを保存する |  |
| 切り戻し | 変更前Policyを再適用する |  |
| 事前連絡 | Teams Group Chat |  |
| 作業後報告 | Teams Group Chat |  |

## 要確認事項を明示する

```text
要確認:
- TLS 1.2未満を利用するClientが存在しないこと
- AWS Service Principalへの影響がないこと
- 作業時間帯と承認者
- CLI作業が許可されるか、GUI作業が必須か
- スクリーンショットとCLI証跡の提出粒度
```

---

## 8. 作業体制と役割

| 役割 | 主な責任 |
|---|---|
| 作業担当 | 手順に沿った操作、結果・証跡記録、異常時停止 |
| レビュー担当 | 対象、影響、手順、切り戻し、証跡を確認 |
| 承認者 | 変更実施を承認 |
| アプリ担当 | 業務機能と利用経路を確認 |
| AWS管理担当 | AWS設定、権限、監査を確認 |
| 運用担当 | 監視、通知、作業後運用を確認 |

1人称で進める場合も、独断で変更する意味ではない。実作業を主体的に進め、必要なレビュー・承認・相談を自分から依頼する。

---

## 9. 手順番号と証跡番号の規則

## 手順番号

| Prefix | 区分 | 例 |
|---|---|---|
| `P` | 事前確認 | `P-01` |
| `C` | 変更 | `C-01` |
| `V` | 変更後確認 | `V-01` |
| `R` | 切り戻し | `R-01` |
| `E` | 証跡・報告 | `E-01` |

## 証跡ファイル名

```text
<手順No>_<タイミング>_<対象>_<確認内容>.<拡張子>
```

例:

```text
P-01_before_caller_identity.json
P-03_before_bucket_policy.json
C-01_change_policy_diff.txt
V-02_after_bucket_policy_status.json
V-05_after_cloudtrail_put_bucket_policy.json
R-03_rollback_bucket_policy.json
```

GUI Screenshot:

```text
P-04_before_s3_permissions.png
C-02_change_s3_policy_confirmation.png
V-03_after_s3_permissions.png
V-04_after_application_upload.png
```

ファイル名へAccount ID、個人名、機密情報を過剰に含めない。

---

## 10. 証跡ディレクトリ設計

```text
<change-id>_s3_bucket_policy_change/
├── 00_metadata/
├── before/
├── impact/
├── change/
├── after/
├── rollback/
├── screenshots/
├── cloudtrail/
└── report/
```

作成例:

```bash
WORK_NAME="s3_bucket_policy_change"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/impact" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/report"
```

| Directory | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、作業情報、対象一覧 |
| `before` | 変更前設定 |
| `impact` | 影響調査結果、利用元情報 |
| `change` | 変更案、差分、変更操作結果 |
| `after` | 変更後設定、テスト結果 |
| `rollback` | 切り戻し設定、結果 |
| `screenshots` | GUI、アプリ画面 |
| `cloudtrail` | 変更イベント |
| `report` | 作業報告、証跡一覧 |

---

## 11. 証跡の種類と役割

| 証跡種別 | 得意なこと | 注意点 |
|---|---|---|
| GUI Screenshot | 人が見て設定状態を理解しやすい | 画面外の値、時刻、全項目を確認しにくい |
| CLI JSON | 設定値を正確に保存・比較しやすい | 人が読みづらい場合がある |
| CLI Table | 手順実施中に確認しやすい | 構造・全情報を保持しない |
| Diff | 変更前後の差分を示す | 差分対象の正しさを別途確認する |
| CloudTrail | 誰が、いつ、何を変更したか示す | 現在設定や業務動作は示さない |
| Application Test | 業務影響がないことを示す | AWS設定値そのものは示さない |
| Teams報告 | 関係者へ結果を共有する | 詳細証跡の代わりにはならない |

推奨する組み合わせ:

```text
GUI Screenshot
  + CLI JSON
  + CloudTrail
  + Application Test
  = 設定状態、正確な値、変更履歴、業務影響を説明できる
```

---

## 12. Screenshot証跡の取得ルール

## Screenshotへ含める情報

- AWS Service名
- 対象Resource名
- 確認対象の設定値
- Before / Afterを識別できる情報
- 必要に応じてAccount、Region
- 手順No.または証跡No.と対応するファイル名

## Screenshotへ含めない情報

- Password
- Secret Access Key
- Session Token
- Private Key
- 個人情報
- 不要な別Resource情報
- Browserの個人Bookmark、通知、私用Tab

## Screenshot取得前の確認

1. 対象AccountとRegionを確認する
2. 対象Resource名を確認する
3. 必要な設定が画面内に表示されていることを確認する
4. 秘密情報や不要情報が写っていないことを確認する
5. 操作前か操作後かを確認する
6. 規定のファイル名で保存する
7. 証跡一覧へ記載する

重要:

```text
変更画面を開いただけのScreenshot
  !=
設定が反映された証跡

保存後に再度設定画面を開き、変更後の現在値を取得する。
```

---

## 13. CLI証跡の取得ルール

設定値を保存する場合は原則JSON、作業者が画面で確認する場合はTableまたはTextを使う。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET_NAME="nobu-terraform-iac-lab-upload"
```

Caller Identity証跡:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/P-01_before_caller_identity.json"
```

Bucket Policy証跡:

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json"
```

Public判定証跡:

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-04_before_bucket_policy_status.json"
```

注意:

- stdout用JSONへstderrを`2>&1`で混ぜない
- エラーは別ファイルへ保存する
- `--profile`、`--region`、対象Resourceを明示する
- 全件必要な証跡で`--max-items`を使わない
- Secret値を取得するコマンドを掲載・実行しない

---

## 14. CloudTrail証跡の計画

CloudTrail証跡は、変更後に`PutBucketPolicy`が記録されたことを確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --query 'Events[?EventName==`PutBucketPolicy`] | [0].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/V-05_after_cloudtrail_put_bucket_policy.json"
```

確認する値:

- `EventName`
- `EventTime`
- `Username`または実行Role
- `EventId`
- 対象Bucket
- Source IP
- Error Codeの有無

注意:

- CloudTrail Event反映まで時間がかかる場合がある
- CloudTrailは変更操作を示すが、変更後設定の正しさは別途確認する
- Access Key ID、Source IP、User情報の取扱いは現場ルールへ従う

---

## 15. 変更前確認の作成

変更前確認では、変更対象だけでなく、変更後の安全性と機能確認に必要な関連設定も取得する。

| 手順No | 確認対象 | 確認内容 | 期待結果 | NG時対応 | 証跡 |
|---|---|---|---|---|---|
| P-01 | Caller Identity | 操作Accountと実行主体を確認 | 想定Account ID | 作業中止・連絡 | `00_metadata/P-01_before_caller_identity.json` |
| P-02 | Bucket存在 | 対象Bucketへアクセス可能か確認 | Errorなし | 作業中止・権限確認 | `before/P-02_before_head_bucket.txt` |
| P-03 | Bucket Policy | 変更前Policyを保存 | JSON取得成功 | 作業中止・Policy有無確認 | `before/P-03_before_bucket_policy.json` |
| P-04 | Policy Status | Public判定を確認 | `IsPublic=False` | 作業中止・即時共有 | `before/P-04_before_bucket_policy_status.json` |
| P-05 | Public Access Block | 4項目を確認 | 4項目`True` | 影響と対応方針確認 | `before/P-05_before_public_access_block.json` |
| P-06 | Object Ownership | ACL利用状態を確認 | `BucketOwnerEnforced` | 影響確認 | `before/P-06_before_ownership_controls.json` |
| P-07 | Encryption | Default Encryptionを確認 | 設計どおり | 影響確認 | `before/P-07_before_encryption.json` |
| P-08 | Application | Upload・表示が正常か確認 | 正常 | 作業中止・既存障害確認 | `before/P-08_before_application_test.txt` |
| P-09 | CloudTrail | 直近変更履歴を確認 | 想定外変更なし | 変更内容確認 | `cloudtrail/P-09_before_cloudtrail.json` |

## NG時対応を書く

悪い例:

```text
期待結果:
正常であること
```

良い例:

```text
期待結果:
PolicyStatus.IsPublicがFalseであること。

NG時対応:
IsPublic=Trueの場合は作業を開始せず、現在Policy、Public Access Block、
利用要件を確認して管理者へ共有する。
```

---

## 16. 影響調査の記載

| No. | 影響対象 | 現在の利用 | 変更後影響 | 確認方法 | 判定 | 対応 |
|---:|---|---|---|---|---|---|
| 1 | Rails Application | S3へ画像Upload・Get | TLS 1.2以上なら影響なし | Application Test、CloudTrail | 要確認 | 変更後Upload・表示確認 |
| 2 | Web EC2 IAM Role | `PutObject`、`GetObject` | 権限Actionは変更なし | IAM Policy、Application | 影響なし想定 | RoleとPolicyを証跡化 |
| 3 | 管理者CLI | AWS CLIから管理 | 現行AWS CLIはTLS 1.2以上想定 | CLI Version、接続試験 | 影響なし想定 | 変更後Read確認 |
| 4 | AWS Service Principal | Service連携の可能性 | `aws:PrincipalIsAWSService=false`で除外 | Policy、設計書 | 要確認 | 利用Serviceを確認 |
| 5 | 古いClient | TLS 1.2未満の可能性 | AccessDeniedになる | 利用者・Client調査 | 要確認 | 存在しないことを確認 |
| 6 | Public Access | 許可なし | Publicにはしない | Policy Status、PAB | 影響なし | 変更後再確認 |
| 7 | Monitoring | CloudTrail、CloudWatch | 変更Eventが増える | CloudTrail | 影響なし | Event確認 |

## 影響調査で確認する分類

- 利用者
- Application
- Batch、Lambda、ETL
- IAM User、Role、別Account
- AWS Service Principal
- VPC Endpoint
- Internet、閉域網、Proxy
- TLS Version
- Monitoring、CloudTrail、Alarm
- Backup、復旧、切り戻し

---

## 17. 変更差分の記載

## 変更前

```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::nobu-terraform-iac-lab-upload",
    "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

## 追加するStatement

```json
{
  "Sid": "DenyOutdatedTLS",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::nobu-terraform-iac-lab-upload",
    "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
  ],
  "Condition": {
    "NumericLessThan": {
      "s3:TlsVersion": "1.2"
    },
    "Bool": {
      "aws:PrincipalIsAWSService": "false"
    }
  }
}
```

## 変更意図

| Policy要素 | 意味 |
|---|---|
| `Effect=Deny` | 条件に一致する通信を明示的に拒否する |
| `Principal=*` | すべてのPrincipalを条件判定対象にする |
| `Action=s3:*` | S3の全操作を対象にする |
| `s3:TlsVersion < 1.2` | TLS 1.2未満を拒否する |
| `aws:PrincipalIsAWSService=false` | AWS Service PrincipalをDeny対象から除外する |

重要:

```text
Principal=*を含むDeny Statement
  !=
Public Allow
```

Policy全体、Effect、Action、Resource、Conditionを組み合わせて判断する。

---

## 18. 変更手順の書き方

## 1操作1行

悪い例:

```text
S3を開いて対象バケットを選び、Policyを変更して保存し、
変更後に画面とアプリを確認する。
```

良い例:

| 手順No | 作業内容 |
|---|---|
| C-01 | S3 Consoleで対象Bucketのアクセス許可Tabを開く |
| C-02 | Bucket Policyの編集を開く |
| C-03 | 承認済みPolicy JSONを貼り付ける |
| C-04 | Bucket名と追加Statementを再確認する |
| C-05 | 変更を保存する |
| V-01 | Bucket Policyを再表示して変更後値を確認する |
| V-02 | Policy Statusが`IsPublic=False`であることを確認する |
| V-03 | ApplicationのUpload・表示を確認する |
| V-04 | CloudTrailの`PutBucketPolicy`を確認する |

## 各手順に必要な列

| 列 | 内容 |
|---|---|
| 手順No | 一意な番号 |
| 区分 | 事前確認、変更、変更後確認、切り戻し |
| 作業内容 | 何をするか |
| 操作場所 | GUI、CLI、Application、Teams |
| 操作・コマンド | 具体的操作 |
| 期待結果 | 成功判定 |
| NG時対応 | 停止、連絡、切り戻し |
| 実施結果 | 未実施、OK、NG、保留 |
| 証跡 | 対応ファイル名 |

---

## 19. 変更手順の実例

変更操作はDay 20で承認済み模擬作業として実施する。本日は手順だけを作成する。

| 手順No | 区分 | 作業内容 | 操作場所 | 期待結果 | NG時対応 | 証跡 |
|---|---|---|---|---|---|---|
| C-01 | 変更準備 | 変更後Policy JSONを確認する | Editor / Diff | 承認済み差分のみ | 作業中止・再レビュー | `change/C-01_change_policy_diff.txt` |
| C-02 | 変更準備 | Caller Identityを再確認する | AWS CLI | 想定Account ID | 作業中止 | `00_metadata/C-02_change_caller_identity.json` |
| C-03 | 変更準備 | 対象Bucket名を再確認する | AWS Console / CLI | 対象一致 | 作業中止 | `screenshots/C-03_change_target_bucket.png` |
| C-04 | 変更 | 承認済みPolicyを適用する | AWS CLIまたはConsole | Errorなし | 変更を止めてError共有 | `change/C-04_change_put_bucket_policy.txt` |
| C-05 | 変更 | 保存完了を確認する | AWS Console | 保存成功 | Error共有・切り戻し判断 | `screenshots/C-05_change_policy_saved.png` |

変更コマンドはレビュー対象として手順書へ記載するが、本日は実行しない。

```text
aws s3api put-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --policy file://change/bucket-policy-after.json \
  --no-cli-pager
```

---

## 20. 変更後確認の実例

| 手順No | 確認対象 | 確認内容 | 期待結果 | NG時対応 | 証跡 |
|---|---|---|---|---|---|
| V-01 | Bucket Policy | 変更後Policyを再取得する | 承認済みPolicyと一致 | 切り戻し判断 | `after/V-01_after_bucket_policy.json` |
| V-02 | Policy Status | Public判定を確認する | `IsPublic=False` | 即時切り戻し・共有 | `after/V-02_after_policy_status.json` |
| V-03 | Public Access Block | 4項目を再確認する | 4項目`True` | 作業中止・共有 | `after/V-03_after_public_access_block.json` |
| V-04 | Application | 画像Uploadを確認する | 正常に保存できる | 切り戻し判断 | `screenshots/V-04_after_upload.png` |
| V-05 | Application | 画像表示を確認する | 正常に表示できる | 切り戻し判断 | `screenshots/V-05_after_display.png` |
| V-06 | AWS CLI | 想定管理操作が可能か確認 | AccessDeniedなし | 影響確認・切り戻し判断 | `after/V-06_after_allowed_access.txt` |
| V-07 | CloudTrail | `PutBucketPolicy`を確認する | Event確認 | 反映待ち・再確認 | `cloudtrail/V-07_after_cloudtrail.json` |
| V-08 | Monitoring | 想定外Alarm・Findingがないか確認 | 異常なし | 影響調査・共有 | `after/V-08_after_monitoring.txt` |

変更後確認は、設定確認、Security確認、Application確認、Audit確認を分ける。

---

## 21. 切り戻し条件

切り戻し手順だけでなく、どの状態で切り戻すかを記載する。

| No. | 切り戻し条件 | 判断 |
|---:|---|---|
| 1 | Bucket Policyが承認済み内容と一致しない | 原則切り戻し |
| 2 | `IsPublic=True`になる | 即時切り戻し・共有 |
| 3 | ApplicationのUploadまたは表示が失敗する | 影響確認後、原則切り戻し |
| 4 | 想定RoleからS3へアクセスできない | 原則切り戻し |
| 5 | 想定外のClient・Batchへ影響する | 関係者判断、原則切り戻し |
| 6 | AWS CLI変更操作がErrorになる | 現在状態確認後、切り戻し要否判断 |
| 7 | 監視でCriticalな異常を検知する | 即時共有・切り戻し判断 |

切り戻し判断者と連絡先は、実案件の手順書で明記する。

---

## 22. 切り戻し手順の実例

| 手順No | 区分 | 作業内容 | 期待結果 | NG時対応 | 証跡 |
|---|---|---|---|---|---|
| R-01 | 判断 | 切り戻し条件と現在影響を確認する | 判断者が切り戻し承認 | 操作せず継続連絡 | `rollback/R-01_rollback_decision.txt` |
| R-02 | 事前確認 | 変更前Policy JSONを確認する | 変更前証跡と一致 | 操作中止 | `before/P-03_before_bucket_policy.json` |
| R-03 | 切り戻し | 変更前Policyを再適用する | Errorなし | Error共有・追加対応判断 | `rollback/R-03_rollback_put_policy.txt` |
| R-04 | 確認 | 切り戻し後Policyを取得する | 変更前Policyと一致 | 追加対応判断 | `rollback/R-04_rollback_bucket_policy.json` |
| R-05 | 確認 | Public判定を確認する | `IsPublic=False` | 即時共有 | `rollback/R-05_rollback_policy_status.json` |
| R-06 | 機能確認 | Application動作を確認する | 正常 | 影響継続として共有 | `screenshots/R-06_rollback_application.png` |
| R-07 | Audit確認 | CloudTrailを確認する | 切り戻しEvent確認 | 反映待ち・再確認 | `cloudtrail/R-07_rollback_cloudtrail.json` |
| R-08 | 報告 | 影響、切り戻し、現在状態を報告する | 関係者へ共有済み | 再送・口頭連絡 | `report/R-08_rollback_report.txt` |

切り戻しコマンドは本日は実行しない。

```text
aws s3api put-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --expected-bucket-owner 445405559057 \
  --policy file://before/P-03_before_bucket_policy.json \
  --no-cli-pager
```

---

## 23. 証跡一覧テンプレート

| No. | 手順No | Timing | 種別 | 証跡名 | File | 取得方法 | 秘密情報確認 | Result | 備考 |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | P-01 | Before | CLI JSON | Caller Identity | `00_metadata/P-01_before_caller_identity.json` | AWS CLI | 要確認 |  |  |
| 2 | P-03 | Before | CLI JSON | Bucket Policy | `before/P-03_before_bucket_policy.json` | AWS CLI | 要確認 |  |  |
| 3 | P-04 | Before | CLI JSON | Policy Status | `before/P-04_before_bucket_policy_status.json` | AWS CLI | OK |  |  |
| 4 | P-05 | Before | Screenshot | S3 Permission | `screenshots/P-05_before_s3_permissions.png` | Console | 要確認 |  |  |
| 5 | C-01 | Change | Diff | Policy差分 | `change/C-01_change_policy_diff.txt` | Diff Tool | 要確認 |  |  |
| 6 | C-05 | Change | Screenshot | 保存完了 | `screenshots/C-05_change_policy_saved.png` | Console | 要確認 |  |  |
| 7 | V-01 | After | CLI JSON | Bucket Policy | `after/V-01_after_bucket_policy.json` | AWS CLI | 要確認 |  |  |
| 8 | V-02 | After | CLI JSON | Policy Status | `after/V-02_after_policy_status.json` | AWS CLI | OK |  |  |
| 9 | V-04 | After | Screenshot | Upload Test | `screenshots/V-04_after_upload.png` | Application | 要確認 |  |  |
| 10 | V-07 | After | CLI JSON | CloudTrail Event | `cloudtrail/V-07_after_cloudtrail.json` | AWS CLI | 要確認 |  |  |
| 11 | R-04 | Rollback | CLI JSON | Policy切り戻し後 | `rollback/R-04_rollback_bucket_policy.json` | AWS CLI | 要確認 |  | 実施時のみ |
| 12 | E-01 | Report | Text | 作業結果報告 | `report/E-01_work_report.txt` | Teams / Text | 要確認 |  |  |

---

## 24. 証跡の機密情報確認

証跡を保存・共有する前に、次の情報が含まれていないか確認する。

| 情報 | 取扱い |
|---|---|
| Secret Access Key | 保存・共有禁止 |
| Session Token | 保存・共有禁止 |
| Password | 保存・共有禁止 |
| Private Key | 保存・共有禁止 |
| Access Key ID | 必要性と共有範囲を確認 |
| IAM User / Role ARN | 共有範囲を確認 |
| Account ID | 共有範囲を確認 |
| Source IP | 共有範囲を確認 |
| Bucket名・Resource ARN | 機密区分を確認 |
| 個人情報・業務データ | 原則マスクまたは除外 |

証跡一覧の`秘密情報確認`列へ、`OK`、`要マスク`、`要確認`を記載する。

---

## 25. 期待結果の書き方

期待結果は、作業者が目視で判定できる具体的な値にする。

| 悪い例 | 良い例 |
|---|---|
| 正常であること | `PolicyStatus.IsPublic`が`False`であること |
| 設定されていること | `DenyOutdatedTLS` Statementが1件存在すること |
| 問題ないこと | Bucket-level Public Access Blockの4項目が`True`であること |
| アプリが動くこと | 画像Uploadが成功し、投稿画面へ画像が表示されること |
| CloudTrailを確認する | 最新の`PutBucketPolicy`でEventTime、Username、EventIdを確認できること |

---

## 26. 異常時対応の書き方

異常時対応では、作業者が独断で進めないよう、停止条件と連絡を明記する。

```text
NG時対応:
期待値と一致しない場合は次の手順へ進まない。
取得した証跡とError内容を保存し、レビュー担当および管理者へ共有する。
現在設定と業務影響を確認し、切り戻し要否の判断を依頼する。
```

異常時に記録する内容:

- 発生時刻
- 手順No.
- 対象Account、Region、Resource
- 実施操作
- Error Message
- 終了コード
- 現在設定
- Application影響
- 取得証跡
- 切り戻し実施有無
- 連絡先と回答

---

## 27. レビュー観点

## 作業概要

- [ ] 作業目的が明確である
- [ ] Account、Region、Resourceが一意である
- [ ] 作業日時、担当、承認者が明確である
- [ ] 停止・利用者影響が記載されている

## 影響調査

- [ ] 利用者、Application、Batch、別Accountを確認した
- [ ] IAM PrincipalとResource Policyを確認した
- [ ] 通信経路とTLS Versionを確認した
- [ ] Monitoring、CloudTrail、運用影響を確認した
- [ ] 未確認事項が明示されている

## 作業手順

- [ ] 1操作1行である
- [ ] 期待結果が具体的である
- [ ] NG時対応がある
- [ ] 変更前Backupがある
- [ ] 作業直前の対象再確認がある
- [ ] 承認済み変更だけを実施する

## 変更後・切り戻し

- [ ] 設定確認、Security確認、Application確認がある
- [ ] CloudTrail確認がある
- [ ] 切り戻し条件が具体的である
- [ ] 切り戻し後の確認がある

## 証跡

- [ ] 手順No.と証跡名が対応する
- [ ] Before / Afterを識別できる
- [ ] GUIとCLIの役割が分かれている
- [ ] 秘密情報確認がある
- [ ] 不足証跡が明示されている

---

## 28. 机上確認の進め方

手順書完成後、実作業を実施せずに最初から最後まで読み合わせる。

## 机上確認で行うこと

1. 作業依頼と対象が一致するか確認する
2. すべての手順No.を順番に読む
3. 各手順の操作場所を確認する
4. Command、File、画面名が存在するか確認する
5. 期待結果を判定できるか確認する
6. NG時に止まれるか確認する
7. 証跡名が重複していないか確認する
8. 切り戻しを最後まで実行できるか確認する
9. 作業時間内に収まるか確認する
10. 要確認事項を残したまま実施しないことを確認する

## Command構文確認

読み取り系コマンドは、必要に応じて検証環境で実行する。変更系コマンドは本日の机上確認では実行しない。

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

---

## 29. 作業時間の見積り

| 区分 | 目安 | 内容 |
|---|---:|---|
| 事前連絡・開始確認 | 5分 | 承認、体制、対象確認 |
| 変更前確認 | 15分 | Account、Policy、PAB、Application |
| 変更操作 | 5分 | Policy適用 |
| 変更後設定確認 | 10分 | Policy、Public、PAB |
| Application Test | 10分 | Upload、表示 |
| CloudTrail・Monitoring確認 | 10分 | Event、Alarm、Finding |
| 証跡整理・報告 | 15分 | 一覧、報告 |
| 切り戻し予備 | 20分 | 復元、確認、報告 |

見積りには、CloudTrail反映待ち、関係者回答待ち、切り戻し時間を含める。

---

## 30. 作業前報告例

```text
S3 Bucket Policy変更作業を開始する。

作業ID:
対象Account:
対象Region:
対象Bucket:
変更内容:
作業時間:
作業担当:

変更前確認、変更、変更後確認、Application Test、CloudTrail確認を実施する。
異常時は次手順へ進まず、影響を確認して切り戻し判断を依頼する。
```

---

## 31. 作業完了報告例

```text
S3 Bucket Policy変更作業が完了した。

実施内容:
- TLS 1.2未満を拒否するDenyOutdatedTLS Statementを追加

結果:
- 変更後Policyは承認済み内容と一致
- PolicyStatus.IsPublic=False
- Bucket-level Public Access Blockの4項目はTrue
- Applicationの画像Upload・表示は正常
- CloudTrailでPutBucketPolicyを確認
- 想定外のAlarm・Findingなし

切り戻し:
- 未実施

証跡:
- 所定の証跡フォルダへ格納済み

残課題:
- なし
```

---

## 32. 異常・切り戻し報告例

```text
S3 Bucket Policy変更後のApplication Testで影響を確認したため、切り戻しを実施した。

発生手順:
発生時刻:
対象:
事象:
想定影響:

対応:
- 変更前Bucket Policyを再適用
- 切り戻し後Policyが変更前と一致することを確認
- PolicyStatus.IsPublic=Falseを確認
- Application動作が復旧したことを確認
- CloudTrailで切り戻し操作を確認

現在状態:
切り戻し完了、Application正常

証跡:
所定フォルダへ格納済み

追加調査:
TLS利用状況と影響したClientを確認する。
```

---

## 33. 証跡一覧と手順書の整合性確認

次を機械的に確認する。

```bash
find "$EVIDENCE_DIR" -type f -print | sort
```

```bash
find "$EVIDENCE_DIR" -type f -size 0 -print | sort
```

```bash
find "$EVIDENCE_DIR" -type f | wc -l
```

確認点:

- 手順書記載の証跡が存在するか
- 空ファイルがないか
- File名が手順No.と対応するか
- Before / After / Rollbackが混在していないか
- Error Fileが結果として放置されていないか
- 秘密情報確認が完了しているか
- Screenshotが対象画面を示しているか

---

## 34. Excelへ転記する際の注意

- Markdown表の1行をExcelの1行へ対応させる
- Cell結合を増やしすぎない
- Commandは改行と折り返しを維持する
- 長いJSONは別Fileとし、手順書にはPathを書く
- Screenshotを大量に貼り付けず、証跡一覧で管理する方式も検討する
- 判定列は入力規則を使う
- 手順No.と証跡No.をFilter・Sortできるようにする
- 未確認事項を空欄にせず`要確認`と記載する
- Review Commentを消さず、対応履歴を残す
- 印刷範囲、Page Break、Headerを確認する

---

## 35. よくある手順書の不備

| 不備 | 問題 | 改善 |
|---|---|---|
| 対象Bucket名が曖昧 | 別Resourceを変更する危険 | Account、Region、Bucket名を明記 |
| Commandだけが並ぶ | 成功・失敗を判断できない | 期待結果とNG時対応を追加 |
| 変更前Backupがない | 切り戻せない | Before設定を保存 |
| 1行に複数操作 | どこで失敗したか不明 | 1操作1行へ分割 |
| Screenshot名が連番だけ | 何の証跡か分からない | 手順No.・Timing・対象を含める |
| GUI証跡だけ | 正確な全設定値を比較しにくい | CLI JSONを組み合わせる |
| CLI証跡だけ | Review時に理解しづらい | 必要画面のScreenshotを追加 |
| CloudTrail確認がない | 誰が変更したか追跡しにくい | 変更Eventを取得 |
| 切り戻し条件がない | 判断が遅れる | 条件と判断者を明記 |
| 要確認事項を推測で埋める | 誤った前提で作業する | 要確認として残し、実施前に解消 |

---

## 36. セキュリティ上の注意点

- 手順書へPassword、Secret、Tokenを書かない
- Screenshotへ秘密情報や個人情報を含めない
- Bucket PolicyのPrincipal、Resource ARNの機密区分を確認する
- CloudTrail証跡のUser、Source IP、Access Key IDの取扱いを確認する
- 変更系CommandはReview・承認後に実行する
- 作業直前にCaller Identityを再確認する
- Copy & Paste後に全角記号、Quote、改行を確認する
- GUI変更時も対象Resource名を保存直前に再確認する
- Error発生時に試行錯誤で追加変更しない
- 証跡の保存先、閲覧権限、保持期間を確認する

---

## 37. 案件で説明できるポイント

- AWS設定変更をExcel手順書へ転記できる粒度で整理できる
- 作業概要、影響調査、変更、変更後確認、切り戻しを分けて記載できる
- 1操作1行、期待結果、NG時対応を記載できる
- GUI Screenshot、CLI JSON、CloudTrail、Application Testの役割を説明できる
- 手順No.と証跡名を紐づけられる
- 切り戻し条件と判断者を明確にできる
- 不明点を推測せず、要確認事項として管理できる
- Review・承認・実施・結果確認の記録を残せる
- 証跡から秘密情報を除外できる
- 作業結果と残課題を簡潔に報告できる

---

## 38. 資格試験につながるポイント

- CloudTrailによる変更履歴確認
- S3 Bucket Policy、Public Access Block、TLS条件
- IAM Principal、Resource、Action、Condition
- 明示的Denyの評価
- AWS CLI Profile、Region、Expected Bucket Owner
- セキュリティ監査と証跡
- Versioning、Backup、切り戻し
- 最小権限と変更管理

---

## 39. 要確認事項

7月案件へ参画後、次を確認する。

- 使用する作業手順書のExcel Template
- 必須Sheetと必須Column
- 手順書の作成、Review、承認フロー
- 手順No.と証跡No.の命名規則
- GUI操作とAWS CLI操作の利用ルール
- Screenshotの取得範囲とMaskルール
- CLI JSON、Table出力の提出要否
- CloudTrail証跡の必須項目
- 証跡保存先、閲覧権限、保持期間
- 作業開始・完了・異常時の連絡先
- 切り戻し判断者
- 作業後の結果確認者
- ExcelへScreenshotを貼るか、別Fileで管理するか

---

## 40. Day 19完了チェックリスト

### 作業概要

- [ ] 作業目的を明記した
- [ ] Account、Region、Resourceを明記した
- [ ] 作業日時、担当、Review、承認を明記した
- [ ] 停止と利用者影響を記載した
- [ ] 要確認事項を記載した

### 変更前・影響調査

- [ ] 変更前確認項目を作成した
- [ ] 変更前Backupを計画した
- [ ] 利用者、Application、Batch、Roleを確認対象にした
- [ ] TLS、通信経路、AWS Service Principalを確認対象にした
- [ ] CloudTrailとMonitoringを確認対象にした

### 変更・変更後確認

- [ ] 変更差分を明確にした
- [ ] 変更手順を1操作1行にした
- [ ] 各手順へ期待結果を記載した
- [ ] 各手順へNG時対応を記載した
- [ ] 設定、Security、Application、Audit確認を分けた

### 切り戻し

- [ ] 切り戻し条件を記載した
- [ ] 切り戻し判断者を要確認事項へ含めた
- [ ] 変更前設定を再適用する手順を記載した
- [ ] 切り戻し後確認を記載した
- [ ] 切り戻し報告を記載した

### 証跡

- [ ] 証跡Directory構成を決めた
- [ ] 手順No.と証跡名を対応させた
- [ ] GUI、CLI、CloudTrail、Application証跡を計画した
- [ ] Before / After / Rollbackを識別できる
- [ ] 秘密情報確認列を用意した
- [ ] Screenshot一覧を作成した

### Review・引継ぎ

- [ ] Review観点を確認した
- [ ] 机上確認を実施した
- [ ] Excelへ転記できる構造になっている
- [ ] Day 20で使用する手順と証跡計画が揃っている
- [ ] 本日は設定変更を実施していない

## Day 19の完了条件

次を自分の言葉で説明できればDay 19は完了とする。

```text
作業手順書はコマンド集ではなく、対象を誤らず、
期待結果を確認し、異常時に止まり、切り戻しと証跡取得まで
同じ手順で実施するための文書である。

変更前確認、影響調査、変更手順、変更後確認、切り戻し、
証跡一覧、Review承認を分けて整理する。

手順は1操作1行とし、各行へ期待結果、NG時対応、証跡を記載する。

証跡はGUI Screenshot、CLI JSON、CloudTrail、Application Testを
目的に応じて組み合わせ、手順No.と対応させる。

不明点は推測で埋めず要確認事項として残し、
Reviewと承認を完了してから設定変更を実施する。
```
