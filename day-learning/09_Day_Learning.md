# Day 9 Learning: GuardDutyサンプルFinding調査・後片付けドリル

## 1. 今日の目的

GuardDutyのサンプルFindingを限定的に作成し、Finding確認、一次調査、関連サービスへの横展開、報告、Archive、CloudTrailによる操作履歴確認までを一連の作業として実施する。

Day 8では既存DetectorとFindingを読み取る基礎を確認した。Day 9では、検証用Findingを使い、次の実務フローを練習する。

```text
変更前確認
↓
サンプルFinding作成
↓
今回作成したFindingの特定
↓
Finding一次調査
↓
CloudTrail・Network・Security Groupへの横展開
↓
調査結果報告
↓
サンプルFindingのArchive
↓
後片付け確認
↓
CloudTrailで作業履歴確認
```

サンプルFindingは実際の侵害ではない。ただし、既存通知設定によってメール、Teams、監視システムなどへ通知される可能性があるため、実案件では必ず事前承認と関係者連絡を行う。

関連資料:

- [GuardDuty CLIリファレンス](../docs/references/05_guardduty_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [Day 8 GuardDuty基礎確認・Finding一次調査](./08_Day_Learning.md)
- [Day 7 CloudTrail・CloudWatch総合調査ドリル](./07_Day_Learning.md)

## 今日の検証シナリオ

```text
GuardDuty Findingの一次調査手順を確認するため、
承認済みの検証環境で指定したFinding TypeのサンプルFindingを作成する。

今回作成したサンプルFindingのみを特定し、
重要度、対象リソース、Resource Role、Actionを確認する。

関連サービスへの横展開調査、証跡取得、報告を行った後、
今回作成したサンプルFindingのみをArchiveする。
```

## 今日の確認順序

1. AWSアカウント、リージョン、Detectorを確認する
2. 作業開始条件と通知影響を確認する
3. 証跡保存先を準備する
4. 変更前の未Archive Finding ID一覧を保存する
5. EventBridge・通知連携を確認する
6. 作成するサンプルFinding Typeを限定する
7. サンプルFindingを作成する
8. 変更後のFinding ID一覧を保存する
9. 作成前後を比較し、今回作成したFinding IDだけを特定する
10. サンプルFinding詳細を確認する
11. Resource、Action、Severity、Countを確認する
12. CloudTrail、Network、Security Groupへの横展開方法を整理する
13. サンプルFindingであることを明記して報告する
14. 今回作成したFindingだけをArchiveする
15. Archive後の状態を確認する
16. CloudTrailで作成・Archive操作履歴を確認する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象Detector | 東京リージョンの既存Detector |
| サンプルFinding Type | `UnauthorizedAccess:EC2/TorClient` |
| 作成対象 | 指定した1種類のサンプルFinding |
| 後片付け | 今回作成したサンプルFindingのみArchive |
| Detector・Feature変更 | なし |
| 実リソース変更 | なし |

## 今日実行しない操作

- Finding Typeを指定しない全サンプルFinding作成
- 既存の実FindingのArchive
- Finding Feedbackの変更
- Detectorの作成、更新、無効化、削除
- Protection Planの変更
- EventBridge Rule、SNS、通知先の変更
- EC2停止、隔離、Security Group変更
- IAM Access Key無効化、削除
- 不審通信や攻撃操作による実Finding生成
- サンプルFinding内の架空リソースIDに対する変更操作

---

## 2. Day 8とDay 9の違い

| 項目 | Day 8 | Day 9 |
|---|---|---|
| 主目的 | 既存設定とFindingの読み取り | サンプルFindingを使った調査フロー検証 |
| GuardDuty変更 | なし | サンプルFinding作成とArchive |
| Finding対象 | 既存未Archive Finding | 今回作成したサンプルFindingのみ |
| 横展開 | 調査方法の確認 | サンプル情報から調査手順を実践 |
| 後片付け | なし | 今回作成したFindingのみArchive |
| CloudTrail確認 | 必要に応じて | 作成・Archive操作を確認 |

Day 9で重要なのは、サンプルFindingの調査そのものより、**既存Findingと今回作成したFindingを混同せず、安全に対象を限定すること**である。

---

## 3. サンプルFindingの注意点

## サンプルFindingとは

GuardDutyが提供する検証用Findingである。通知経路、調査手順、証跡、報告を確認するために利用できる。

サンプルFindingには、検証用の架空リソース、IPアドレス、通信情報などが含まれる場合がある。

```text
サンプルFinding:
実際の攻撃や侵害によって発生したFindingではない

ただし:
GuardDuty、EventBridge、SNS、メール、Teams、SIEMなどの
既存通知経路では通常のFindingとして扱われる可能性がある
```

## サンプルFinding作成前に確認すること

- 検証環境であること
- GuardDuty Detectorが有効であること
- 作成するFinding Typeが限定されていること
- 既存の実FindingをArchiveしないこと
- EventBridgeや通知先への影響
- 監視担当者への事前連絡
- 検証開始・終了時刻
- 後片付け方法
- 証跡保存先

## 本番環境での扱い

実案件では、承認なしにサンプルFindingを作成しない。

```text
理由:
- セキュリティ監視担当へ実アラートとして通知される可能性がある
- インシデント対応が開始される可能性がある
- 自動隔離や自動修復が実行される可能性がある
- 運用KPIや監査記録へ影響する可能性がある
```

---

## 4. 作業開始条件と中止条件

## 作業開始条件

- 対象AWSアカウントとリージョンが想定どおりである
- GuardDuty Detectorが`ENABLED`である
- サンプルFinding作成が許可された検証環境である
- 作成するFinding Typeを1種類に限定している
- 既存Finding ID一覧を保存済みである
- 通知先と自動対応の有無を確認済みである
- 検証後にArchiveまで実施する時間を確保している

## 作業中止条件

- AWSアカウントまたはリージョンが想定と異なる
- Detectorが存在しない、または`DISABLED`
- 実環境・本番環境で承認がない
- 通知先や自動対応の影響を判断できない
- 既存Finding ID一覧を保存できない
- Finding Typeが未指定または空である
- サンプル作成後、今回作成したFindingを特定できない
- Critical・Highの実Findingを確認した
- 想定外の通知や自動処理が発生した

今回作成したFindingを一意に特定できない場合は、Archiveを実行しない。

---

## 5. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

SAMPLE_FINDING_TYPE="UnauthorizedAccess:EC2/TorClient"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nSAMPLE_FINDING_TYPE=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$SAMPLE_FINDING_TYPE"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID SAMPLE_FINDING_TYPE
do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

`SAMPLE_FINDING_TYPE`が空の場合、全対応サンプルFindingを生成する操作につながる可能性がある。必ず値を確認する。

---

## 6. 証跡保存用ディレクトリの作成

```bash
WORK_NAME="guardduty_sample_finding_investigation"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/integration" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/report" \
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

| ディレクトリ | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、作業条件 |
| `before` | 作成前Detector・Finding一覧 |
| `change` | サンプルFinding作成操作 |
| `investigation` | Finding詳細、横展開調査 |
| `integration` | EventBridge・通知連携 |
| `after` | 作成後Finding一覧 |
| `rollback` | Archiveと後片付け確認 |
| `report` | 調査結果、Teams報告 |
| `screenshots` | Webコンソール証跡 |

---

## 7. AWSアカウント・Detectorを確認する

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. AWSアカウントと東京リージョンを確認する
3. GuardDutyコンソールを開く
4. Detectorが有効であることを確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_GuardDuty_Detector確認.png
```

### Caller Identity

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

### 想定アカウントとの一致確認

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
  echo "Expected account: $EXPECTED_ACCOUNT_ID"
else
  echo "Account check OK: $ACCOUNT_ID"
fi
```

### Detector ID取得

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text \
  --no-cli-pager)

echo "DETECTOR_ID=$DETECTOR_ID"
```

### Detector状態確認

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency,ServiceRole:ServiceRole}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/01_detector.json"
```

期待値:

```text
Status: ENABLED
```

---

## 8. 通知・自動対応の影響を確認する

サンプルFinding作成前に、EventBridge RuleとTargetを確認する。

### EventBridge Rule一覧

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Rules[].{Name:Name,State:State,EventBusName:EventBusName,Description:Description}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/integration/01_eventbridge_rules_before.json"
```

### Webコンソール

1. EventBridgeのRule一覧を開く
2. GuardDutyを対象とするRuleを確認する
3. Event Patternを確認する
4. Targetを確認する
5. 自動隔離や自動変更がないことを確認する

取得するスクリーンショット:

```text
03_EventBridge_GuardDuty通知連携_変更前.png
```

### 確認ポイント

- SNS、メール、Teams、SIEMへの通知
- Lambda、Step Functions、Systems Manager Automation
- 自動隔離Security Group
- IAM認証情報の自動無効化
- インシデント管理システムへの自動起票

自動対応の影響を判断できない場合は、サンプルFindingを作成しない。

---

## 9. 変更前のFinding一覧を保存する

作成前のFinding ID一覧を保存し、作成後との差分確認に使用する。

## 未Archive Finding一覧

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/02_active_findings_before.json"
```

## 対象Finding TypeのID一覧

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"type\":{\"Eq\":[\"$SAMPLE_FINDING_TYPE\"]},\"service.archived\":{\"Eq\":[\"false\"]}}}" \
  --max-results 50 \
  --query 'FindingIds' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | sed '/^$/d' \
  | sort -u \
  > "$EVIDENCE_DIR/before/03_sample_type_finding_ids_before.txt"
```

### 変更前ID確認

```bash
cat "$EVIDENCE_DIR/before/03_sample_type_finding_ids_before.txt"
```

何も表示されない場合は、変更前に対象Finding Typeの未Archive Findingが存在しない状態である。

---

## 10. 検証開始時刻を記録する

サンプルFindingを特定する補助情報として、検証開始時刻をUTCとJSTで記録する。

```bash
date -u '+UTC=%Y-%m-%dT%H:%M:%SZ' \
  | tee "$EVIDENCE_DIR/00_metadata/02_test_start_time_utc.txt"

date '+JST=%Y-%m-%dT%H:%M:%S%z' \
  | tee "$EVIDENCE_DIR/00_metadata/03_test_start_time_jst.txt"
```

Finding IDの差分を主な識別方法とし、時刻は補助情報として使用する。

---

## 11. サンプルFinding Typeを最終確認する

```bash
printf 'Create sample finding type: %s\n' "$SAMPLE_FINDING_TYPE"
```

確認内容:

```text
対象AWSアカウント: 445405559057
対象リージョン: ap-northeast-1
Detector ID: <detector-id>
Finding Type: UnauthorizedAccess:EC2/TorClient
作成数: 指定したFinding Typeのみ
通知影響: 確認済み
後片付け: 今回作成したFindingのみArchive
```

実案件では、ここで作業責任者の最終承認を確認する。

---

## 12. サンプルFindingを作成する

### AWS CLI

```bash
aws guardduty create-sample-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-types "$SAMPLE_FINDING_TYPE" \
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

### 注意

- `--finding-types`を削除しない
- 空の変数を渡さない
- 複数種類を一度に作成しない
- コマンド成功直後にFindingが表示されない場合がある
- 既存通知先へ検証アラートが送信される可能性がある

取得するスクリーンショット:

```text
04_GuardDuty_サンプルFinding作成後一覧.png
```

---

## 13. 作成後のFinding一覧を保存する

サンプルFindingが表示されるまで数分待つ場合がある。

### 対象Finding Typeの作成後ID一覧

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"type\":{\"Eq\":[\"$SAMPLE_FINDING_TYPE\"]},\"service.archived\":{\"Eq\":[\"false\"]}}}" \
  --max-results 50 \
  --query 'FindingIds' \
  --output text \
  --no-cli-pager \
  | tr '\t' '\n' \
  | sed '/^$/d' \
  | sort -u \
  > "$EVIDENCE_DIR/after/01_sample_type_finding_ids_after.txt"
```

確認:

```bash
cat "$EVIDENCE_DIR/after/01_sample_type_finding_ids_after.txt"
```

### 作成後の詳細一覧保存

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"type\":{\"Eq\":[\"$SAMPLE_FINDING_TYPE\"]},\"service.archived\":{\"Eq\":[\"false\"]}}}" \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/02_sample_type_findings_after.json"
```

---

## 14. 今回作成したFinding IDを特定する

作成前後のID一覧を比較し、今回増えたFinding IDだけを抽出する。

```bash
comm -13 \
  "$EVIDENCE_DIR/before/03_sample_type_finding_ids_before.txt" \
  "$EVIDENCE_DIR/after/01_sample_type_finding_ids_after.txt" \
  > "$EVIDENCE_DIR/after/03_new_sample_finding_ids.txt"
```

確認:

```bash
cat "$EVIDENCE_DIR/after/03_new_sample_finding_ids.txt"
```

### 件数確認

```bash
NEW_SAMPLE_FINDING_COUNT=$(wc -l < "$EVIDENCE_DIR/after/03_new_sample_finding_ids.txt" | tr -d ' ')

echo "NEW_SAMPLE_FINDING_COUNT=$NEW_SAMPLE_FINDING_COUNT"
```

### 中止条件

```text
0件:
Finding反映待ち、コマンド失敗、条件不一致を確認する。

1件:
今回作成したFindingとして詳細確認へ進む。

2件以上:
想定外。既存Findingや複数生成の可能性を確認し、Archiveを実行しない。
```

今回作成したFindingが1件であることを確認後、変数へ格納する。

```bash
SAMPLE_FINDING_ID=$(sed -n '1p' "$EVIDENCE_DIR/after/03_new_sample_finding_ids.txt")

echo "SAMPLE_FINDING_ID=$SAMPLE_FINDING_ID"
```

---

## 15. サンプルFinding詳細を確認する

### 生JSON保存

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/01_sample_finding_detail.json"
```

### 要約表示

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].{Id:Id,Type:Type,Severity:Severity,Title:Title,AccountId:AccountId,Region:Region,CreatedAt:CreatedAt,UpdatedAt:UpdatedAt,ResourceType:Resource.ResourceType,ResourceRole:Service.ResourceRole,ActionType:Service.Action.ActionType,Archived:Service.Archived,Count:Service.Count}' \
  --output table \
  --no-cli-pager
```

### Webコンソール

1. GuardDutyのFinding一覧を開く
2. 今回作成したFinding IDを検索する
3. サンプルFindingであることを確認する
4. Severity、Resource、Actionを確認する

取得するスクリーンショット:

```text
05_サンプルFinding詳細_概要.png
06_サンプルFinding詳細_Resource_Action.png
```

---

## 16. サンプルFindingで確認する項目

| 項目 | 確認内容 |
|---|---|
| Finding ID | 今回作成したIDと一致するか |
| Finding Type | 指定したTypeと一致するか |
| Severity | 重要度と対応優先度 |
| Title・Description | サンプルであることを確認できるか |
| AccountId・Region | 対象環境と一致するか |
| ResourceType | 対象リソース種別 |
| Resource Role | `TARGET`または`ACTOR` |
| Action Type | 通信、API、DNSなど |
| CreatedAt・UpdatedAt | 検証時間帯と一致するか |
| Count | 検知回数 |
| Archived | `false`であるか |

### サンプルと判断する根拠

- 承認済みの`create-sample-findings`実行直後に作成された
- 作成前後のFinding ID差分で特定した
- Finding Typeが指定値と一致する
- CreatedAtが検証時間帯と一致する
- Title、Description、AdditionalInfoなどにサンプルを示す情報がある
- Finding内の対象リソースが検証用・架空情報である

1つの根拠だけでなく、複数の根拠でサンプルFindingと判断する。

---

## 17. ResourceとActionを確認する

### Resource情報を保存する

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].Resource' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/02_sample_finding_resource.json"
```

### Action情報を保存する

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].Service.Action' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/03_sample_finding_action.json"
```

### 確認ポイント

- Resource Roleが`TARGET`か`ACTOR`か
- 通信方向
- Local IPとRemote IP
- Local PortとRemote Port
- Protocol
- Threat List Name
- 通信がBlockedか
- 対象リソースが実在するか

サンプルFinding内の架空Instance IDやIPアドレスに対して、設定変更や隔離操作を実施しない。

---

## 18. 横展開調査の考え方

サンプルFindingでは実リソースや実通信が存在しない場合がある。その場合も、実Findingで何を確認するかを手順として整理する。

## EC2 Network Findingの場合

```text
1. FindingのInstance ID、ENI、Private IP、Public IPを確認する
2. EC2の稼働状態、Subnet、SG、IAM Roleを確認する
3. Security Groupの公開範囲を確認する
4. NACLとRoute Tableを確認する
5. VPC Flow Logsで通信時刻、IP、Port、ACCEPT/REJECTを確認する
6. OS・アプリログやプロセスを確認する
7. 正常通信か、侵害されたリソースからの通信かを判断する
```

## IAM Access Key Findingの場合

```text
1. Access Keyの所有者を確認する
2. CloudTrailで同じAccess KeyのAPI操作を検索する
3. 送信元IP、UserAgent、リージョンを確認する
4. 権限変更、認証情報作成、S3アクセスなどを確認する
5. 業務影響を確認して、キー無効化・ローテーションを相談する
```

## S3 Findingの場合

```text
1. 対象バケットとObjectを確認する
2. Public Access Block、Policy、ACL、Object Ownershipを確認する
3. CloudTrail Data Eventやアクセスログを確認する
4. 実行者、送信元、GetObject・PutObject・DeleteObjectを確認する
5. データ影響と認証情報漏えい可能性を確認する
```

---

## 19. CloudTrailへの横展開

サンプルFindingの作成操作と、後続のArchive操作はCloudTrailのManagement Eventとして確認できる。

### GuardDuty関連イベント検索

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=guardduty.amazonaws.com \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=guardduty.amazonaws.com \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/04_cloudtrail_guardduty_events.json"
```

### 確認するイベント例

| EventName | 意味 |
|---|---|
| `CreateSampleFindings` | サンプルFinding作成 |
| `ArchiveFindings` | Finding Archive |
| `UnarchiveFindings` | FindingのArchive解除 |
| `UpdateFindingsFeedback` | Finding Feedback変更 |
| `CreateDetector` | Detector作成 |
| `UpdateDetector` | Detector更新 |
| `DeleteDetector` | Detector削除 |

---

## 20. Network・Security Groupへの横展開

サンプルFinding内のリソースは架空の場合があるため、Day 9では確認手順を整理し、実在確認ができたリソースに対してのみ読み取りコマンドを実行する。

### EC2情報確認例

```bash
INSTANCE_ID="<real-instance-id>"

aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,VpcId:VpcId,SubnetId:SubnetId,SecurityGroups:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn}' \
  --output table \
  --no-cli-pager
```

### Security Group確認例

```bash
SG_ID="<security-group-id>"

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --output table \
  --no-cli-pager
```

### VPC Flow Logs設定確認

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'FlowLogs[].{FlowLogId:FlowLogId,ResourceId:ResourceId,TrafficType:TrafficType,DestinationType:LogDestinationType,Destination:LogDestination,Status:FlowLogStatus}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- 対象リソースが実在するか
- Public IPを持つか
- 不要なPortが公開されていないか
- 通信方向とSG Ruleが一致するか
- Flow Logsが利用できるか
- Finding時刻周辺の通信を確認できるか

---

## 21. EventBridge通知結果を確認する

既存EventBridge RuleがGuardDutyを対象としている場合、サンプルFindingが通知された可能性がある。

確認すること:

- EventBridge Ruleの状態
- Target
- SNS配信結果
- Lambda実行結果
- Teamsやメールへの通知
- 自動処理の実行有無

取得するスクリーンショット:

```text
07_GuardDuty_サンプルFinding通知結果.png
```

通知がない場合も、次を切り分ける。

- Ruleが存在しない
- Event Patternが一致しない
- Ruleが無効
- Target権限エラー
- 通知先設定不備
- 通知遅延

Day 9では通知設定を変更しない。

---

## 22. 調査結果を整理する

```text
Finding ID:
<sample-finding-id>

Finding Type:
UnauthorizedAccess:EC2/TorClient

サンプル判定:
承認済みcreate-sample-findings操作による検証用Finding

Severity:
<severity>

Resource:
<resource-type / resource-id>

Resource Role:
<TARGET / ACTOR>

Action Type:
<action-type>

CreatedAt:
<created-at>

UpdatedAt:
<updated-at>

Count:
<count>

通知結果:
<通知あり / 通知なし / 要確認>

横展開調査:
CloudTrail:
Network:
Security Group:

判断:
サンプルFinding。実際の侵害ではない。

後片付け:
今回作成したFindingのみArchiveする。
```

---

## 23. Archive前の最終確認

Archiveは、今回作成したサンプルFindingだけに限定する。

### 対象ID確認

```bash
printf 'Archive target Finding ID: %s\n' "$SAMPLE_FINDING_ID"
```

### Finding詳細再確認

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].{Id:Id,Type:Type,Title:Title,CreatedAt:CreatedAt,Archived:Service.Archived}' \
  --output table \
  --no-cli-pager
```

### Archive実行条件

- IDが作成前後の差分で特定されている
- Finding Typeが指定したサンプルTypeと一致する
- CreatedAtが検証時間帯と一致する
- サンプルFindingである根拠がある
- 実Findingではない

1項目でも確認できない場合はArchiveを実行しない。

---

## 24. サンプルFindingをArchiveする

```bash
aws guardduty archive-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
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

重要:

```text
ArchiveはFindingを削除しない。
通常の未Archive一覧から除外する操作である。
原因や脅威を解消する操作ではない。
```

---

## 25. Archive後の状態を確認する

### Finding詳細

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].{Id:Id,Type:Type,Archived:Service.Archived,UpdatedAt:UpdatedAt}' \
  --output table \
  --no-cli-pager
```

期待値:

```text
Archived: True
```

証跡保存:

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/01_sample_finding_after_archive.json"
```

### 未Archive一覧から除外されたことを確認する

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"id\":{\"Eq\":[\"$SAMPLE_FINDING_ID\"]},\"service.archived\":{\"Eq\":[\"false\"]}}}" \
  --output table \
  --no-cli-pager
```

取得するスクリーンショット:

```text
08_サンプルFinding_Archive後確認.png
```

---

## 26. CloudTrailで作業履歴を確認する

サンプルFinding作成とArchiveの操作履歴を確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=guardduty.amazonaws.com \
  --query 'Events[?EventName==`CreateSampleFindings` || EventName==`ArchiveFindings`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=guardduty.amazonaws.com \
  --query 'Events[?EventName==`CreateSampleFindings` || EventName==`ArchiveFindings`].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/02_cloudtrail_sample_create_archive_events.json"
```

### 確認ポイント

- `CreateSampleFindings`が記録されている
- `ArchiveFindings`が記録されている
- 実行者が想定どおり
- 実行時刻が検証時間帯と一致する
- 想定外のGuardDuty変更操作がない

---

## 27. 後片付け完了確認

### Detector状態

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency}' \
  --output table \
  --no-cli-pager
```

### 今回作成したFindingの状態

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$SAMPLE_FINDING_ID" \
  --query 'Findings[0].{Id:Id,Type:Type,Archived:Service.Archived}' \
  --output table \
  --no-cli-pager
```

### 既存Findingへの影響確認

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/03_active_findings_after_cleanup.json"
```

確認内容:

- Detectorは`ENABLED`のまま
- 今回作成したFindingはArchive済み
- 既存FindingをArchiveしていない
- Detector、Feature、通知設定を変更していない
- 想定外の自動処理が発生していない

---

## 28. 推奨するスクリーンショット証跡

| No. | ファイル名 | 画面 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント |
| 02 | `02_GuardDuty_Detector確認.png` | Detector状態 |
| 03 | `03_EventBridge_GuardDuty通知連携_変更前.png` | Rule・Target |
| 04 | `04_GuardDuty_サンプルFinding作成後一覧.png` | Finding一覧 |
| 05 | `05_サンプルFinding詳細_概要.png` | Type、Severity、時刻 |
| 06 | `06_サンプルFinding詳細_Resource_Action.png` | Resource、Action |
| 07 | `07_GuardDuty_サンプルFinding通知結果.png` | 通知結果 |
| 08 | `08_サンプルFinding_Archive後確認.png` | Archive後状態 |

---

## 29. 証跡ファイルを確認する

### 全証跡

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -print \
  | sort
```

### 空ファイル

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -size 0 \
  -print \
  | sort
```

### ファイル数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

### 証跡確認ポイント

- Caller IdentityとDetector状態
- 作成前Finding ID一覧
- 作成後Finding ID一覧
- 作成前後の差分ID
- サンプルFinding詳細
- ResourceとAction
- CloudTrail操作履歴
- Archive後Finding詳細
- 既存Findingへの影響確認
- 通知結果

証跡を公開する場合は、アカウントID、ARN、Access Key ID、IPアドレス、通知先などを確認する。

---

## 30. 作業結果テンプレート

```text
作業名:
GuardDutyサンプルFinding調査ドリル

対象AWSアカウント:
<account-id>

対象リージョン:
<region>

Detector ID:
<detector-id>

検証開始日時:
<yyyy-mm-dd hh:mm JST>

作成したFinding Type:
UnauthorizedAccess:EC2/TorClient

作成したFinding ID:
<finding-id>

サンプル判定根拠:
- 作成前後のID差分
- 検証時間帯
- Finding Type
- Title・Description

Finding詳細:
Severity:
Resource Type:
Resource Role:
Action Type:
Count:

横展開調査:
CloudTrail:
Network:
Security Group:

通知結果:
<通知あり / 通知なし / 要確認>

後片付け:
今回作成したFindingのみArchive済み

既存Findingへの影響:
なし

証跡保存先:
<evidence-path>
```

---

## 31. Teams報告例

### 作業開始前

```text
GuardDutyのサンプルFindingを使用した調査手順検証を開始する。

対象:
AWSアカウント <account-id>
リージョン <region>
Finding Type UnauthorizedAccess:EC2/TorClient

実施内容:
- 作成前Finding一覧保存
- 指定した1種類のサンプルFinding作成
- Finding一次調査と通知確認
- 今回作成したFindingのみArchive
- CloudTrailで作業履歴確認

実Finding、Detector、Protection Plan、通知設定、実リソースは変更しない。
```

### サンプルFinding調査完了

```text
GuardDutyサンプルFindingの一次調査を実施した。

Finding:
- ID: <finding-id>
- Type: UnauthorizedAccess:EC2/TorClient
- Severity: <severity>
- Resource Role: <TARGET / ACTOR>
- Action Type: <action-type>

作成前後のFinding ID差分および検証時刻から、
今回作成したサンプルFindingであることを確認した。

CloudTrail、Network、Security Groupへの横展開方法と
既存通知経路の動作を確認した。
実際の侵害ではない。
```

### 後片付け完了

```text
GuardDutyサンプルFinding検証の後片付けを完了した。

今回作成したFinding ID <finding-id> のみArchiveした。
DetectorはENABLEDのままであり、既存Finding、Protection Plan、
EventBridge Rule、通知先、実リソースへの変更はない。

CloudTrailでCreateSampleFindingsおよびArchiveFindingsの
操作履歴を確認した。
証跡は <evidence-path> に保存した。
```

---

## 32. よくある問題と切り分け

## サンプルFindingが表示されない

- Detectorが`ENABLED`か
- リージョンとDetector IDが正しいか
- Finding Typeが対応しているか
- Finding一覧のFilter条件が狭すぎないか
- Archive済み表示を除外していないか
- 反映まで少し待ったか

## 作成前後の差分が0件

- Finding反映待ちの可能性
- 同じFinding Typeが既存Findingへ集約された可能性
- コマンド失敗
- Finding TypeやFilter条件の誤り

差分が0件の場合は、対象を特定できないためArchiveを実行しない。

## 差分が複数件

- 複数Findingが作成された可能性
- 同時刻に別の実Findingが発生した可能性
- 作成前一覧が不完全だった可能性

各FindingのType、CreatedAt、Title、Resourceを確認し、判断できない場合はArchiveを実行しない。

## 通知が届かない

- EventBridge Ruleがない
- Ruleが無効
- Event Patternが一致しない
- Target権限エラー
- SNS Subscription未確認
- 通知先側の遅延や障害

## Archive対象を間違えた可能性がある

- 直ちに作業を停止する
- CloudTrailで`ArchiveFindings`を確認する
- 対象Finding IDと実施者を報告する
- 現場ルールに従い`unarchive-findings`の実施要否を相談する

独断でArchive解除を実施しない。

---

## 33. セキュリティ上の注意点

- サンプルFinding作成前に通知・自動対応を確認する
- Finding Typeを必ず限定する
- 作成前後のID差分で今回のFindingを特定する
- 実FindingをArchiveしない
- サンプルFindingを実インシデントとして報告しない
- Finding内の架空リソースへ変更操作を実行しない
- Archiveは脅威の解消ではない
- 証跡にAccess Key ID、IPアドレス、ARNが含まれる可能性がある
- 実案件では承認、事前連絡、後片付け報告を行う
- Critical・Highの実Findingを見つけた場合は検証を中止して共有する

---

## 34. 案件で説明できるポイント

### 対象限定

```text
サンプルFinding作成前後のFinding ID一覧を保存し、
差分を取ることで今回作成したFindingだけを特定した。

Finding Typeを1種類に限定し、既存Findingへの影響を避けた。
```

### 一次調査

```text
Finding Type、Severity、Resource、Resource Role、Action、
CreatedAt、UpdatedAt、Countを確認した。

実Findingの場合は、CloudTrail、VPC Flow Logs、
Security Group、対象サービス設定へ横展開する手順を整理した。
```

### 後片付け

```text
Archive前にFinding ID、Type、CreatedAt、サンプル判定根拠を再確認し、
今回作成したFindingだけをArchiveした。

Archive後はFinding状態、Detector、既存Findingへの影響を確認し、
CloudTrailで作成・Archive操作履歴を確認した。
```

### 安全な検証

```text
サンプルFindingでも既存通知や自動対応が動作する可能性があるため、
作成前にEventBridge RuleとTargetを確認する。

実案件では事前承認と監視担当への連絡を行う。
```

---

## 35. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| Sample Finding | GuardDutyの検知・通知・調査手順を検証できる |
| Finding Type | 検知内容を分類する名前 |
| Resource Role | `TARGET`または`ACTOR` |
| Action | Network、DNS、APIなどの検知内容 |
| EventBridge | GuardDuty Findingの通知・自動対応連携 |
| Archive | Findingを通常一覧から除外する。脅威解消ではない |
| Feedback | Findingの有用性をGuardDutyへ伝える |
| CloudTrail | GuardDuty設定・操作履歴の監査 |
| VPC Flow Logs | Network Findingの横展開調査 |
| Security Group | 通信許可範囲の確認 |

---

## 36. 要確認事項

実案件でサンプルFinding検証を行う場合は、次を確認する。

- サンプルFinding作成が許可された環境
- 作業申請番号と承認者
- 作成可能なFinding Type
- 監視担当者への事前連絡
- EventBridge、SNS、Teams、SIEMへの通知影響
- 自動隔離・自動修復の有無
- サンプルFindingの識別方法
- Finding Archiveの承認と運用ルール
- Archive解除手順
- 証跡保存先と保持期間
- 検証結果の報告先
- CloudTrailで確認すべき操作イベント

不明な項目は合理的に推測して作業を進めず、未確認事項として手順書と報告へ残す。

---

## 37. Day 9完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] Detector IDとStatusを確認した
- [ ] 通知・自動対応の影響を確認した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] 作成前の未Archive Finding一覧を保存した
- [ ] 作成前の対象Finding Type ID一覧を保存した
- [ ] 検証開始時刻を記録した
- [ ] サンプルFinding Typeが1種類に限定されていることを確認した
- [ ] サンプルFindingを作成した
- [ ] 作成後の対象Finding Type ID一覧を保存した
- [ ] 作成前後のID差分を確認した
- [ ] 今回作成したFinding IDを特定した
- [ ] Finding詳細の生JSONを保存した
- [ ] Type、Severity、Resource、Resource Role、Actionを確認した
- [ ] サンプルFindingである根拠を整理した
- [ ] CloudTrailへの横展開方法を確認した
- [ ] Network・Security Groupへの横展開方法を確認した
- [ ] 通知結果を確認した
- [ ] Archive対象IDを最終確認した
- [ ] 今回作成したFindingのみArchiveした
- [ ] Archive後の状態を確認した
- [ ] DetectorがENABLEDのままであることを確認した
- [ ] 既存Findingへの影響がないことを確認した
- [ ] CloudTrailで作成・Archive操作履歴を確認した
- [ ] 証跡ファイルと空ファイルを確認した
- [ ] Teams報告文を作成した

## Day 9の完了条件

次を自分の言葉で説明できればDay 9は完了とする。

```text
サンプルFinding作成前に、対象AWSアカウント、リージョン、
Detector、通知・自動対応、既存Finding一覧を確認する。

Finding Typeを1種類に限定してサンプルFindingを作成し、
作成前後のFinding ID一覧の差分から今回作成したFindingだけを特定する。

Finding Type、Severity、Resource、Resource Role、Actionを確認し、
実Findingの場合にCloudTrail、VPC Flow Logs、Security Groupへ
横展開する調査手順を整理する。

Archive前にサンプル判定根拠と対象IDを再確認し、
今回作成したFindingだけをArchiveする。

後片付け後はDetector、Finding状態、既存Findingへの影響を確認し、
CloudTrailでCreateSampleFindingsとArchiveFindingsの操作履歴を確認する。
```
