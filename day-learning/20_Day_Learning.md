# Day 20 Learning: 模擬作業1 S3 Bucket Policy変更

## 1. 今日の目的

S3 Bucket Policy変更を題材に、作業開始連絡から変更前確認、設定変更、変更後確認、CloudTrail確認、切り戻し、最終報告までを一人称で完遂する。

```text
作業依頼を確認する
  -> 対象と承認範囲を確認する
  -> 変更前設定と業務動作を保存する
  -> 承認済み差分だけを適用する
  -> 設定・Security・Application・Auditを確認する
  -> 切り戻す
  -> 最終状態と証跡を確認する
  -> 結果を報告する
```

Day 20では、個人ラボ環境に対して実際にBucket Policyを変更し、確認後に変更前Policyへ切り戻す。

変更を実施する前に、対象Account、Bucket、開始状態、変更後Policy、切り戻しPolicyを必ず確認する。開始状態が想定と異なる場合は変更を行わず、ドライランへ切り替える。

関連資料:

- [Day 2 S3 Bucket Policy変更ドリル](./02_Day_Learning.md)
- [Day 19 作業手順書・証跡整理](./19_Day_Learning.md)
- [S3 Bucket Policy変更手順書テンプレート](../docs/templates/s3_bucket_policy_change_procedure_template.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [S3 Bucket Policy CLIリファレンス](../docs/references/02_s3_bucket_policy_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [共通AWS CLI・証跡保存リファレンス](../docs/references/00_common_aws_cli_reference.md)
- [S3 Bucket Policy変更ケーススタディ](../docs/case_studies/case_study_s3_bucket_policy_change.md)

---

## 2. Day 2・Day 19・Day 20の違い

| Day | 目的 |
|---|---|
| Day 2 | Bucket Policy変更の各操作と意味を詳しく学ぶ |
| Day 19 | 現場へ提出できる手順書と証跡計画を作る |
| Day 20 | 手順書に沿って、開始から報告までを通しで実施する |

Day 20では、途中で分からなくなった場合も、まず現在の手順No.、期待結果、証跡、異常時対応を確認する。手順外の試行錯誤で設定を追加変更しない。

---

## 3. 模擬作業チケット

```text
作業ID:
  LAB-CHG-S3-001

対象:
  AWS Account: 445405559057
  Region: ap-northeast-1
  Bucket: nobu-terraform-iac-lab-upload

作業目的:
  TLS 1.2未満のS3アクセスを明示的に拒否する。

変更内容:
  現行のDenyInsecureTransportを維持し、
  DenyOutdatedTLS Statementを追加する。

変更後確認:
  Bucket Policy、Public判定、Public Access Block、
  Application動作、CloudTrail変更履歴を確認する。

切り戻し:
  変更前Bucket Policyを再適用する。

最終状態:
  変更前Bucket Policyへ切り戻した状態とする。
```

## 作業管理情報

| 項目 | 記録 |
|---|---|
| 作業日時 |  |
| 作業担当 |  |
| レビュー担当 | 学習環境では自己レビュー |
| 作業開始時刻 |  |
| 変更実施時刻 |  |
| 切り戻し時刻 |  |
| 作業終了時刻 |  |
| 最終結果 |  |
| 残課題 |  |

---

## 4. 成功条件

次をすべて満たした場合、模擬作業は成功とする。

- 対象Account、Region、Bucketが想定値と一致する
- 変更前Policyを保存できる
- 変更前PolicyがPublicではない
- 変更前Application動作が正常である
- 追加差分が`DenyOutdatedTLS`だけである
- Policy検証でError Findingがない
- Bucket Policy変更が成功する
- 変更後Policyに`DenyOutdatedTLS`が存在する
- 変更後も`IsPublic=False`である
- Public Access Blockの4項目が`True`である
- ApplicationのUpload・表示が正常である
- CloudTrailで`PutBucketPolicy`を確認できる
- 変更前Policyへ切り戻せる
- 切り戻し後Policyが変更前Policyと一致する
- 切り戻し後Application動作が正常である
- 必要な証跡と報告が揃う

---

## 5. 作業中止条件

次に該当する場合、変更を実施しない、または次の手順へ進まない。

- Caller Identityが想定Accountと一致しない
- 対象Bucket名が手順書と一致しない
- 変更前Policyを取得できない
- 変更前Policyが想定開始状態と異なる
- 変更前に`IsPublic=True`である
- 変更前Application Testが失敗する
- 変更後Policy案の差分が`DenyOutdatedTLS`追加以外を含む
- Access Analyzer Policy ValidationでError Findingがある
- 切り戻し用Policyを確認できない
- AWS CLIの変更操作でErrorが発生する
- 変更後に`IsPublic=True`になる
- Application動作へ影響が発生する
- 想定外のAlarm、Finding、影響が発生する

異常時は、現在状態と証跡を保存し、手順外の追加変更を行わない。

---

## 6. 今日の実施順序

| Phase | 手順 | 内容 |
|---|---|---|
| 開始 | S-01からS-03 | 作業開始、変数、証跡準備 |
| 変更前 | P-01からP-10 | 対象、設定、Application、CloudTrail確認 |
| 変更準備 | C-01からC-05 | Policy案、検証、差分、実施判断 |
| 変更 | C-06 | Bucket Policy適用 |
| 変更後 | V-01からV-09 | 設定、Application、CloudTrail、監視確認 |
| 切り戻し | R-01からR-08 | 変更前Policy再適用と確認 |
| 終了 | E-01からE-05 | 最終状態、証跡、報告 |

---

## 7. 作業用変数

作業Shellを途中で開き直した場合は、変数が残っていると思い込まず再設定する。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
BUCKET_NAME="nobu-terraform-iac-lab-upload"
WORK_ID="LAB-CHG-S3-001"

WORK_NAME="s3_bucket_policy_change"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"
```

確認:

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nBUCKET_NAME=%s\nWORK_ID=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$BUCKET_NAME" "$WORK_ID" "$EVIDENCE_DIR"
```

必須変数の空値確認:

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID BUCKET_NAME WORK_ID EVIDENCE_DIR; do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set." >&2
    return 1 2>/dev/null || exit 1
  fi
done

echo "OK: Required variables are set."
```

---

## 8. S-01 証跡ディレクトリの作成

```bash
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

確認:

```bash
find "$EVIDENCE_DIR" -maxdepth 1 -type d -print | sort
```

期待結果:

- 必要なDirectoryがすべて存在する
- 過去作業の証跡Directoryと混在していない

---

## 9. S-02 作業情報の保存

```bash
{
  printf 'WORK_ID=%s\n' "$WORK_ID"
  printf 'PROFILE=%s\n' "$PROFILE"
  printf 'REGION=%s\n' "$REGION"
  printf 'EXPECTED_ACCOUNT_ID=%s\n' "$EXPECTED_ACCOUNT_ID"
  printf 'BUCKET_NAME=%s\n' "$BUCKET_NAME"
  printf 'START_TIME=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
} > "$EVIDENCE_DIR/00_metadata/S-02_work_metadata.txt"
```

```bash
cat "$EVIDENCE_DIR/00_metadata/S-02_work_metadata.txt"
```

---

## 10. S-03 作業開始報告

学習環境では、次の内容を作業開始報告として記録する。

```text
LAB-CHG-S3-001を開始する。

対象Account:
  445405559057

対象Region:
  ap-northeast-1

対象Bucket:
  nobu-terraform-iac-lab-upload

変更内容:
  DenyOutdatedTLS Statement追加

確認内容:
  変更前設定、Policy差分、変更後設定、Application、
  CloudTrail、切り戻し、最終状態

異常時:
  次手順へ進まず、現在状態と証跡を保存して切り戻しを判断する。
```

---

## 11. P-01 Caller Identity確認

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/P-01_before_caller_identity.json"
```

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

Account ID一致確認:

```bash
ACTUAL_ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACTUAL_ACCOUNT_ID" >&2
  return 1 2>/dev/null || exit 1
fi

echo "OK: AWS account matches: $ACTUAL_ACCOUNT_ID"
```

期待結果:

```text
Account: 445405559057
```

NG時対応:

- 作業を中止する
- Profile、認証情報、AssumeRoleを確認する
- 想定Accountへ切り替えた後、P-01から再開する

---

## 12. P-02 対象Bucket存在確認

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-02_before_head_bucket.json"
```

```bash
cat "$EVIDENCE_DIR/before/P-02_before_head_bucket.json"
```

期待結果:

- CommandがExit Code `0`で終了する
- `BucketRegion`が`ap-northeast-1`
- Bucket ARNが対象Bucketと一致する

---

## 13. P-03 変更前Bucket Policy保存

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

```bash
cat "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json"
```

変更前Policy Hash:

```bash
shasum -a 256 \
  "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json" \
  > "$EVIDENCE_DIR/before/P-03_before_bucket_policy.sha256"
```

期待する開始状態:

- `DenyInsecureTransport`が存在する
- `DenyOutdatedTLS`が存在しない
- 対象Resourceが正しい

確認:

```bash
grep -o '"Sid":"[^"]*"' \
  "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json"
```

開始状態が異なる場合:

```text
DenyOutdatedTLSが既に存在する:
  変更を実施せず、Day 20をドライランへ切り替える。

想定外Statementが存在する:
  変更を実施せず、Policyの由来と利用要件を確認する。

Policyを取得できない:
  変更を実施せず、権限とPolicy有無を確認する。
```

---

## 14. P-04 Public判定確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-04_before_policy_status.json"
```

```bash
cat "$EVIDENCE_DIR/before/P-04_before_policy_status.json"
```

期待結果:

```text
IsPublic: False
```

`IsPublic=True`の場合、変更を実施せず即時共有する。

---

## 15. P-05 Public Access Block確認

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-05_before_public_access_block.json"
```

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

期待結果:

```text
BlockPublicAcls: True
IgnorePublicAcls: True
BlockPublicPolicy: True
RestrictPublicBuckets: True
```

---

## 16. P-06 Object Ownership・ACL確認

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-06_before_ownership_controls.json"
```

```bash
aws s3api get-bucket-acl \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-06_before_bucket_acl.json"
```

期待結果:

- `ObjectOwnership=BucketOwnerEnforced`
- ACLにPublic Grantがない

---

## 17. P-07 暗号化・Versioning確認

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-07_before_encryption.json"
```

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/P-07_before_versioning.json"
```

期待結果:

- Default Encryptionが設定されている
- Versioningの現在値を記録できる

Versioning未設定は、本変更の中止条件ではない。改善候補として記録する。

---

## 18. P-08 変更前Application確認

Web Application全体の疎通:

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/before/P-08_before_application_http_headers.txt"
```

期待結果:

```text
HTTP/2 200
```

Web画面で確認する。

1. `https://www.nobu-iac-lab.com`を開く
2. Loginする
3. 既存画像が表示されることを確認する
4. 必要に応じて承認済みのテスト画像をUploadする
5. Screenshotを保存する

Screenshot:

```text
screenshots/P-08_before_application.png
```

変更前からApplicationが異常な場合、変更を実施しない。

---

## 19. P-09 変更前CloudTrail確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --query 'Events[?EventName==`PutBucketPolicy`] | [0:5].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/P-09_before_cloudtrail_put_bucket_policy.json"
```

確認点:

- 直近の変更時刻
- 実行主体
- 想定外の変更がないか

---

## 20. P-10 GUI変更前証跡

Webコンソールで次を確認し、変更前Screenshotを保存する。

1. S3を開く
2. 対象Bucketを開く
3. 「アクセス許可」Tabを開く
4. Bucket Policyを確認する
5. Public Access Blockを確認する
6. 対象Bucket名とAccountを確認する
7. 「編集」「削除」は押さない

Screenshot:

```text
screenshots/P-10_before_s3_permissions.png
screenshots/P-10_before_bucket_policy.png
```

---

## 21. 変更前確認結果の判定

| 項目 | 期待値 | 結果 |
|---|---|---|
| Caller Identity | Account一致 |  |
| Bucket | 存在・アクセス可能 |  |
| 開始Policy | `DenyInsecureTransport`のみ |  |
| Policy Status | `IsPublic=False` |  |
| Public Access Block | 4項目`True` |  |
| Object Ownership | `BucketOwnerEnforced` |  |
| Encryption | 設定あり |  |
| Application | 正常 |  |
| CloudTrail | 直近履歴確認済み |  |
| 切り戻しPolicy | 保存済み |  |

すべて確認できた場合のみ変更準備へ進む。

---

## 22. C-01 変更後Policy案の作成

次のFileをEditorで作成する。

```text
<EVIDENCE_DIR>/change/C-01_change_bucket_policy_after.json
```

内容:

```json
{
  "Version": "2012-10-17",
  "Statement": [
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
    },
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
  ]
}
```

確認:

```bash
cat "$EVIDENCE_DIR/change/C-01_change_bucket_policy_after.json"
```

---

## 23. C-02 Policy構文・Security Validation

Access AnalyzerでResource Policyを検証する。

```bash
aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --policy-document "file://$EVIDENCE_DIR/change/C-01_change_bucket_policy_after.json" \
  --policy-type RESOURCE_POLICY \
  --validate-policy-resource-type AWS::S3::Bucket \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/C-02_change_policy_validation.json"
```

```bash
cat "$EVIDENCE_DIR/change/C-02_change_policy_validation.json"
```

期待結果:

- JSONとして読み込める
- `ERROR`のFindingがない
- Findingがある場合は内容を確認し、未解決のまま変更しない

---

## 24. C-03 変更差分確認

```bash
diff -u \
  "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json" \
  "$EVIDENCE_DIR/change/C-01_change_bucket_policy_after.json" \
  | tee "$EVIDENCE_DIR/change/C-03_change_policy_diff.txt"
```

`diff`は差分がある場合にExit Code `1`を返す。今回の差分確認では、差分が表示されること自体は想定どおりである。

期待する差分:

- `DenyOutdatedTLS` Statement追加のみ
- `DenyInsecureTransport`は維持
- Bucket ARNは変更なし
- Allow Statement追加なし

差分に想定外変更がある場合、Policy案を修正し、C-02から再確認する。

---

## 25. C-04 影響調査の最終確認

| 影響対象 | 確認内容 | 判定 |
|---|---|---|
| Rails Application | TLS 1.2以上でS3を利用する |  |
| Web EC2 IAM Role | 必要Actionは変更しない |  |
| 管理者CLI | 現行CLIで利用可能 |  |
| AWS Service Principal | Deny対象から除外する |  |
| 古いClient | TLS 1.2未満の利用なし |  |
| Public Access | 引き続きPublicにしない |  |
| Monitoring | CloudTrail確認方法あり |  |
| Rollback | 変更前Policy保存済み |  |

未確認項目がある場合は変更を実施しない。

---

## 26. C-05 実施直前確認

変更操作の直前に、声出し確認する想定で読み上げる。

```text
作業ID:
  LAB-CHG-S3-001

操作Account:
  445405559057

操作Region:
  ap-northeast-1

操作Bucket:
  nobu-terraform-iac-lab-upload

変更:
  DenyOutdatedTLS Statement追加

変更前Backup:
  取得済み

切り戻し:
  変更前Policy再適用

変更後確認:
  Policy、Public判定、PAB、Application、CloudTrail
```

Caller Identityを再確認する。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

---

## 27. C-06 Bucket Policy変更

ここから実際にAWS設定を変更する。

```bash
set +e

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_DIR/change/C-01_change_bucket_policy_after.json" \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/C-06_change_put_bucket_policy_stdout.txt" \
  2> "$EVIDENCE_DIR/change/C-06_change_put_bucket_policy_stderr.txt"

PUT_POLICY_RC=$?
set -e

printf 'PutBucketPolicy exit code: %s\n' "$PUT_POLICY_RC" \
  | tee "$EVIDENCE_DIR/change/C-06_change_put_bucket_policy_result.txt"
```

判定:

```bash
if [ "$PUT_POLICY_RC" -ne 0 ]; then
  echo "ERROR: PutBucketPolicy failed. Do not continue." >&2
  cat "$EVIDENCE_DIR/change/C-06_change_put_bucket_policy_stderr.txt" >&2
else
  echo "OK: PutBucketPolicy succeeded."
fi
```

`PUT_POLICY_RC`が`0`以外の場合、次手順へ進まず現在Policyを確認する。

---

## 28. V-01 変更後Policy取得

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-01_after_bucket_policy.json"
```

```bash
grep -o '"Sid":"[^"]*"' \
  "$EVIDENCE_DIR/after/V-01_after_bucket_policy.json"
```

期待結果:

```text
DenyInsecureTransport
DenyOutdatedTLS
```

---

## 29. V-02 変更案と適用後Policyの比較

```bash
diff -u \
  "$EVIDENCE_DIR/change/C-01_change_bucket_policy_after.json" \
  "$EVIDENCE_DIR/after/V-01_after_bucket_policy.json" \
  > "$EVIDENCE_DIR/after/V-02_after_policy_diff.txt" || true
```

AWSがPolicy JSONの空白、Property順序、値表現を正規化する場合がある。単純なText Diffだけで不一致と断定せず、Statement、Effect、Principal、Action、Resource、Conditionを確認する。

---

## 30. V-03 Public判定確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-03_after_policy_status.json"
```

```bash
cat "$EVIDENCE_DIR/after/V-03_after_policy_status.json"
```

期待結果:

```text
IsPublic: False
```

`IsPublic=True`の場合、即時切り戻しへ進む。

---

## 31. V-04 Public Access Block再確認

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-04_after_public_access_block.json"
```

期待結果:

- 4項目すべて`True`
- 変更前から意図しない変更がない

---

## 32. V-05 GUI変更後確認

Webコンソールで対象Bucketの「アクセス許可」Tabを開き、次を確認する。

1. `DenyInsecureTransport`が存在する
2. `DenyOutdatedTLS`が存在する
3. Public Access BlockがOn
4. Publicに関する警告がない
5. 対象Bucket名が正しい

Screenshot:

```text
screenshots/V-05_after_bucket_policy.png
screenshots/V-05_after_s3_permissions.png
```

---

## 33. V-06 AWS CLI正常系アクセステスト

現在の管理用AWS CLIがTLS 1.2以上で正常に利用できることを確認する。

```bash
aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-06_after_head_bucket.json"
```

```bash
aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --max-items 10 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-06_after_list_objects.json"
```

注意:

- `--max-items 10`は疎通確認用であり、全Objectの証跡ではない
- 通常のAWS CLIではTLS 1.2未満の通信を直接再現しにくい
- 正常系成功だけでは、TLS 1.2未満の拒否動作を直接証明しない

---

## 34. V-07 Application動作確認

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/after/V-07_after_application_http_headers.txt"
```

Web画面で確認する。

1. Loginできる
2. 既存画像が表示される
3. 承認済みテスト画像をUploadできる
4. Upload後の画像を表示できる
5. Error画面が表示されない

Screenshot:

```text
screenshots/V-07_after_application_upload.png
screenshots/V-07_after_application_display.png
```

Application Testが失敗した場合、切り戻し判断へ進む。

---

## 35. V-08 CloudTrail変更履歴確認

変更直後はEventが反映されていない場合がある。数分待って再確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --query 'Events[?EventName==`PutBucketPolicy`] | [0].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/V-08_after_cloudtrail_put_bucket_policy_summary.json"
```

```bash
cat "$EVIDENCE_DIR/cloudtrail/V-08_after_cloudtrail_put_bucket_policy_summary.json"
```

確認する値:

- `EventName=PutBucketPolicy`
- 作業実施時刻と整合する`EventTime`
- 想定したUserまたはRole
- `EventId`

---

## 36. V-09 変更後Monitoring確認

```bash
aws cloudwatch describe-alarms \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[?StateValue==`ALARM`].{AlarmName:AlarmName,StateValue:StateValue,StateReason:StateReason}' \
  --output table \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-09_after_cloudwatch_alarms.txt"
```

GuardDutyを利用している場合:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/V-09_after_guardduty_detectors.txt"
```

確認点:

- 作業に起因する想定外Alarmがない
- 想定外のSecurity Findingがない
- Application Logに異常がない

---

## 37. 変更後判定

| 項目 | 期待値 | 結果 |
|---|---|---|
| Policy適用 | Exit Code `0` |  |
| DenyInsecureTransport | 存在 |  |
| DenyOutdatedTLS | 存在 |  |
| Policy Status | `IsPublic=False` |  |
| Public Access Block | 4項目`True` |  |
| AWS CLI正常系 | 成功 |  |
| Application | Upload・表示正常 |  |
| CloudTrail | `PutBucketPolicy`確認 |  |
| Monitoring | 想定外異常なし |  |

すべて正常でも、Day 20では切り戻しを実施して最終状態を変更前へ戻す。

---

## 38. R-01 切り戻し判断

Day 20は切り戻し練習を含むため、変更後確認が正常でも切り戻す。

切り戻し前に確認する。

- 変更前Policy Fileが存在する
- 変更前Policy Hashが保存されている
- 現在Policyに`DenyOutdatedTLS`が存在する
- 対象Account、Region、Bucketが正しい
- 切り戻し後の確認方法が準備できている

---

## 39. R-02 切り戻し直前の現在Policy保存

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/R-02_rollback_policy_before_rollback.json"
```

---

## 40. R-03 変更前Policy再適用

```bash
set +e

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --policy "file://$EVIDENCE_DIR/before/P-03_before_bucket_policy.json" \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/R-03_rollback_put_bucket_policy_stdout.txt" \
  2> "$EVIDENCE_DIR/rollback/R-03_rollback_put_bucket_policy_stderr.txt"

ROLLBACK_RC=$?
set -e

printf 'Rollback PutBucketPolicy exit code: %s\n' "$ROLLBACK_RC" \
  | tee "$EVIDENCE_DIR/rollback/R-03_rollback_put_bucket_policy_result.txt"
```

`ROLLBACK_RC`が`0`以外の場合、現在PolicyとErrorを保存して共有する。

---

## 41. R-04 切り戻し後Policy確認

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/R-04_rollback_bucket_policy_after.json"
```

```bash
if cmp \
  "$EVIDENCE_DIR/before/P-03_before_bucket_policy.json" \
  "$EVIDENCE_DIR/rollback/R-04_rollback_bucket_policy_after.json"; then
  echo "cmp exit code: 0"
else
  CMP_RC=$?
  echo "cmp exit code: $CMP_RC"
fi
```

期待結果:

```text
cmp exit code: 0
```

Statement確認:

```bash
grep -o '"Sid":"[^"]*"' \
  "$EVIDENCE_DIR/rollback/R-04_rollback_bucket_policy_after.json"
```

期待結果:

- `DenyInsecureTransport`が存在する
- `DenyOutdatedTLS`が存在しない

---

## 42. R-05 切り戻し後Security確認

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/R-05_rollback_policy_status.json"
```

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/R-05_rollback_public_access_block.json"
```

期待結果:

- `IsPublic=False`
- Public Access Blockの4項目が`True`

---

## 43. R-06 切り戻し後Application確認

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/rollback/R-06_rollback_application_http_headers.txt"
```

Web画面でUpload・表示を確認し、Screenshotを保存する。

```text
screenshots/R-06_rollback_application.png
```

---

## 44. R-07 切り戻しCloudTrail確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --query 'Events[?EventName==`PutBucketPolicy`] | [0:2].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/cloudtrail/R-07_rollback_cloudtrail_put_bucket_policy.json"
```

変更時と切り戻し時の2件を、EventTimeとEventIdで識別する。

---

## 45. R-08 GUI切り戻し後確認

Webコンソールで次を確認する。

- `DenyInsecureTransport`が存在する
- `DenyOutdatedTLS`が存在しない
- Public Access BlockがOn
- Public警告がない
- 対象Bucketが正しい

Screenshot:

```text
screenshots/R-08_rollback_bucket_policy.png
screenshots/R-08_rollback_s3_permissions.png
```

---

## 46. E-01 最終状態確認

| 項目 | 最終期待値 | 結果 |
|---|---|---|
| Bucket Policy | 変更前Policyと一致 |  |
| DenyInsecureTransport | 存在 |  |
| DenyOutdatedTLS | 存在しない |  |
| Policy Status | `IsPublic=False` |  |
| Public Access Block | 4項目`True` |  |
| Application | 正常 |  |
| CloudTrail | 変更・切り戻しEvent確認 |  |
| Monitoring | 想定外異常なし |  |

---

## 47. E-02 証跡確認

全証跡:

```bash
find "$EVIDENCE_DIR" -type f -print | sort
```

空File:

```bash
find "$EVIDENCE_DIR" -type f -size 0 -print | sort
```

File数:

```bash
find "$EVIDENCE_DIR" -type f | wc -l
```

注意:

- `put-bucket-policy`成功時のstdoutは空になるため、空のstdout File自体は異常ではない
- 変更結果は専用のResult FileとExit Codeで判断する
- stderr Fileが存在する場合は内容を確認する
- Screenshotと手順No.が対応していることを確認する
- 秘密情報を含む証跡を共有・Git登録しない

---

## 48. E-03 模擬作業結果一覧

| 手順 | 確認・操作 | 期待結果 | 実施結果 | 証跡 |
|---|---|---|---|---|
| P-01 | Caller Identity | Account一致 |  | `00_metadata/P-01_before_caller_identity.json` |
| P-03 | 変更前Policy | 開始状態一致 |  | `before/P-03_before_bucket_policy.json` |
| P-04 | Public判定 | `False` |  | `before/P-04_before_policy_status.json` |
| C-02 | Policy Validation | Errorなし |  | `change/C-02_change_policy_validation.json` |
| C-03 | 差分確認 | Statement追加のみ |  | `change/C-03_change_policy_diff.txt` |
| C-06 | Policy変更 | Exit Code `0` |  | `change/C-06_change_put_bucket_policy_result.txt` |
| V-01 | 変更後Policy | Statement追加済み |  | `after/V-01_after_bucket_policy.json` |
| V-03 | Public判定 | `False` |  | `after/V-03_after_policy_status.json` |
| V-07 | Application | 正常 |  | `screenshots/V-07_after_application_upload.png` |
| V-08 | CloudTrail | Event確認 |  | `cloudtrail/V-08_after_cloudtrail_put_bucket_policy_summary.json` |
| R-03 | 切り戻し | Exit Code `0` |  | `rollback/R-03_rollback_put_bucket_policy_result.txt` |
| R-04 | Policy復元 | 変更前と一致 |  | `rollback/R-04_rollback_bucket_policy_after.json` |
| R-06 | Application | 正常 |  | `screenshots/R-06_rollback_application.png` |
| R-07 | CloudTrail | 2 Event確認 |  | `cloudtrail/R-07_rollback_cloudtrail_put_bucket_policy.json` |

---

## 49. E-04 作業完了報告

```text
LAB-CHG-S3-001 S3 Bucket Policy変更模擬作業が完了した。

対象:
  Account: 445405559057
  Region: ap-northeast-1
  Bucket: nobu-terraform-iac-lab-upload

実施内容:
  TLS 1.2未満を拒否するDenyOutdatedTLS Statementを追加した。

変更後確認:
  Bucket PolicyへDenyOutdatedTLSが追加されたことを確認した。
  PolicyStatus.IsPublic=Falseを確認した。
  Public Access Blockの4項目がTrueであることを確認した。
  AWS CLIおよびApplicationの正常動作を確認した。
  CloudTrailでPutBucketPolicy Eventを確認した。

切り戻し:
  変更前Bucket Policyを再適用した。
  切り戻し後Policyが変更前Policyと一致することを確認した。
  切り戻し後もApplicationが正常であることを確認した。

最終状態:
  変更前Bucket Policyへ復元済み。

証跡:
  所定の証跡Directoryへ保存済み。

残課題:
  TLS 1.2未満の拒否を直接再現する試験方法は別途要件確認が必要。
```

---

## 50. E-05 異常時報告

```text
LAB-CHG-S3-001の手順<手順No.>で異常を確認したため、後続作業を停止した。

発生時刻:
対象Account:
対象Region:
対象Bucket:
発生手順:
実施操作:
Error:
Exit Code:
現在Policy:
Public判定:
Application影響:
切り戻し実施有無:
取得証跡:
要確認事項:
```

---

## 51. ドライランへ切り替える場合

次の場合は、実際のPolicy変更を行わずドライランとする。

- 開始Policyに`DenyOutdatedTLS`が既に存在する
- Applicationが起動していない
- 変更前Policyを取得できない
- Access Analyzer ValidationのErrorを解消できない
- 影響調査の未確認事項が残る
- 切り戻しPolicyを確認できない

ドライランで実施すること:

1. 変更前確認
2. 変更後Policy案の作成
3. Policy Validation
4. 差分確認
5. 変更コマンドの机上確認
6. 変更後確認手順の読み合わせ
7. 切り戻し手順の読み合わせ
8. 証跡一覧と報告文の作成

報告では、変更未実施の理由を明確にする。

---

## 52. GUI作業へ置き換える場合

現場でCLI変更が許可されず、Webコンソールで変更する場合も、確認項目は同じである。

| CLI手順 | GUI対応 |
|---|---|
| Caller Identity | 右上のAccount情報を確認 |
| `get-bucket-policy` | S3のアクセス許可TabでPolicyを確認 |
| Policy File差分 | 承認済みPolicyと編集画面を比較 |
| `put-bucket-policy` | Bucket Policy編集画面で保存 |
| `get-bucket-policy-status` | Public警告とCLI証跡を確認 |
| CloudTrail lookup | Event Historyで`PutBucketPolicy`を確認 |

GUI作業でも、保存前の対象確認、保存後の再表示、CloudTrail確認、切り戻しを省略しない。

---

## 53. よくある失敗

| 失敗 | 原因 | 対応 |
|---|---|---|
| Wrong Accountで作業する | Caller Identity未確認 | 作業直前に再確認 |
| Wrong Bucketへ適用する | Copy & Paste、対象確認不足 | Expected OwnerとBucket名を明示 |
| 変更前Policyを失う | Backup未取得 | 変更前に必ず保存・確認 |
| Policy JSON Error | Quote、Comma、Bracket誤り | Access Analyzerで検証 |
| 想定外Statementを消す | Full Policy置換の理解不足 | Diffで全体を確認 |
| Publicになる | Allow、Principal、Condition誤り | Policy StatusとPABを確認 |
| Applicationが失敗する | 利用元・TLS影響調査不足 | 変更前後Application Test |
| CloudTrail Eventを見つけられない | 反映待ち、検索条件誤り | 数分待ち、Resource・EventName確認 |
| 切り戻し後も変更が残る | Wrong Policy Fileを適用 | `cmp`、Sid、Hashを確認 |
| 証跡が何を示すか不明 | 命名・手順No.不足 | 手順No.とTimingをFile名へ含める |

---

## 54. セキュリティ上の注意点

- Bucket Policy変更はPolicy全体の置換である
- 明示的DenyはIAM Allowより優先される
- `Principal=*`だけでPublic Allowと断定しない
- `aws:PrincipalIsAWSService=false`の目的を理解する
- TLS 1.2未満を利用するClientの有無を確認する
- Access Key、Secret、Tokenを証跡へ残さない
- CloudTrail証跡のUser、Source IPの共有範囲を確認する
- Application Screenshotへ個人情報を含めない
- 変更系Commandは対象確認後に1回だけ実行する
- Error時に手順外の追加変更をしない
- 最終状態を明示して作業を終了する

---

## 55. 案件で説明できるポイント

- 承認済みS3 Bucket Policy変更を一人称で進められる
- 変更前確認から最終報告までを手順No.で管理できる
- Bucket Policy全体置換のリスクを説明できる
- Policy ValidationとDiffで変更案を事前確認できる
- GUI、CLI、Application、CloudTrailを組み合わせて確認できる
- `IsPublic=False`とPublic Access Blockを変更後に確認できる
- Application Testで業務影響を確認できる
- 変更前Policyを使って切り戻せる
- 切り戻し後の最終状態を確認できる
- 異常時に後続作業を止め、事実と証跡を報告できる

---

## 56. 資格試験につながるポイント

- S3 Bucket PolicyとResource Policy
- IAM Policy評価と明示的Deny
- `aws:SecureTransport`
- `s3:TlsVersion`
- `aws:PrincipalIsAWSService`
- S3 Public Access Block
- Object OwnershipとACL
- CloudTrail Management Event
- IAM Access Analyzer Policy Validation
- 暗号化、Versioning、監査、切り戻し

---

## 57. 要確認事項

実案件へ参画後、次を確認する。

- Bucket Policy変更の承認フロー
- GUIまたはCLIのどちらで変更するか
- Policy Validationに使う承認済みTool
- Bucket Policy変更対象約20件の一覧と優先順位
- 利用Principal、別Account、AWS Service Principal
- 閉域網、Proxy、VPC Endpoint、TLS Version
- Application Testの担当と確認項目
- TLS 1.2未満拒否の直接試験要否
- CloudTrail証跡の必須項目
- Screenshotの取得・Maskルール
- 切り戻し判断者と連絡先
- 作業終了時の最終状態

---

## 58. Day 20完了チェックリスト

### 開始・変更前

- [ ] 作業チケットと承認範囲を確認した
- [ ] 変数と証跡Directoryを準備した
- [ ] 作業開始報告を記録した
- [ ] Caller Identityを確認した
- [ ] 対象Bucketを確認した
- [ ] 変更前Policyを保存した
- [ ] 変更前Policy Hashを保存した
- [ ] Public判定とPublic Access Blockを確認した
- [ ] Object Ownership、ACL、暗号化を確認した
- [ ] 変更前Application Testを実施した
- [ ] 変更前CloudTrailを確認した

### 変更準備・変更

- [ ] 変更後Policy案を作成した
- [ ] Access AnalyzerでPolicyを検証した
- [ ] 変更差分を確認した
- [ ] 影響調査の未確認事項がない
- [ ] 切り戻しPolicyを確認した
- [ ] 実施直前に対象を再確認した
- [ ] Bucket Policy変更結果を記録した

### 変更後

- [ ] 変更後Policyを取得した
- [ ] `DenyOutdatedTLS`追加を確認した
- [ ] `IsPublic=False`を確認した
- [ ] Public Access Blockの4項目を確認した
- [ ] GUI変更後証跡を取得した
- [ ] AWS CLI正常系を確認した
- [ ] ApplicationのUpload・表示を確認した
- [ ] CloudTrail変更Eventを確認した
- [ ] Monitoringに想定外異常がないことを確認した

### 切り戻し・終了

- [ ] 切り戻し前の現在Policyを保存した
- [ ] 変更前Policyを再適用した
- [ ] 切り戻し後Policyが変更前と一致した
- [ ] `DenyOutdatedTLS`が存在しないことを確認した
- [ ] 切り戻し後も`IsPublic=False`である
- [ ] 切り戻し後Applicationが正常である
- [ ] CloudTrailで変更・切り戻しEventを確認した
- [ ] 最終状態を記録した
- [ ] 証跡一覧を確認した
- [ ] 作業完了報告を作成した

## Day 20の完了条件

次を自分の言葉で説明できればDay 20は完了とする。

```text
S3 Bucket Policy変更では、作業前に対象Account、Region、Bucket、
変更前Policy、Application動作、切り戻し方法を確認する。

変更後Policy案はAccess AnalyzerとDiffで確認し、
承認済み差分だけを適用する。

変更後はPolicyだけでなく、Public判定、Public Access Block、
AWS CLI、Application、CloudTrail、Monitoringを確認する。

異常時は後続作業を止め、現在状態と証跡を保存して切り戻しを判断する。

切り戻し後は変更前Policyとの一致、Public判定、Application、
CloudTrailを確認し、最終状態と作業結果を報告する。
```
