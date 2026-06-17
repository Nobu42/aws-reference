# Day 21 Learning: 模擬作業2 GuardDuty Finding・CloudTrail横断調査

## 学習開始前に実行するスクリプト

Day 21はGuardDuty Findingを起点にした読み取り専用の横断調査ハンズオンである。既存FindingまたはDay 9で作成したサンプルFindingを対象にする。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

調査対象Findingがない場合は、Day 21単独でサンプルFindingを作成しない。必要な場合はDay 9の通知影響確認、作成、Archive手順を別作業として実施する。

実行場所とDetectorの状態を確認する。

```bash
cd /Users/nobu/aws-reference/day-learning

aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1 \
  --output table \
  --no-cli-pager
```

## 1. 今日の目的

GuardDuty Findingを起点に、対象リソース、重要度、検知内容、CloudTrail操作履歴、Network・IAM・S3設定を横断して確認し、一次調査結果を報告する。

```text
調査依頼を確認する
  -> 対象Account・Region・Findingを特定する
  -> Findingの重要度と対象リソースを確認する
  -> CloudTrailで関連操作を時系列化する
  -> EC2・IAM・S3・Networkの関連設定を確認する
  -> 事実・推測・未確認事項を分ける
  -> 暫定対応案を整理する
  -> 証跡と一次調査結果を報告する
```

Day 21では、調査作業を一人称で進める感覚を身につける。

調査中は、FindingのArchive、EC2停止、Access Key無効化、Security Group変更などの対応操作を実施しない。対応が必要と判断した場合は、根拠、影響、実施案、切り戻し案を整理して承認を求める。

関連資料:

- [Day 7 CloudTrail・CloudWatch総合調査](./07_Day_Learning.md)
- [Day 8 GuardDuty基礎確認・Finding一次調査](./08_Day_Learning.md)
- [Day 9 GuardDutyサンプルFinding調査・後片付け](./09_Day_Learning.md)
- [Day 18 AWSセキュリティ横断チェック](./18_Day_Learning.md)
- [Day 19 作業手順書・証跡整理](./19_Day_Learning.md)
- [GuardDuty CLIリファレンス](../docs/references/05_guardduty_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)

---

## 2. Day 8・Day 9・Day 21の違い

| Day | 目的 | GuardDutyへの変更 |
|---|---|---|
| Day 8 | Detector、Finding、重要度、基本項目を読み取る | なし |
| Day 9 | 承認済みサンプルFindingを作成し、調査とArchiveを練習する | サンプル作成・Archive |
| Day 21 | 1件のFindingを調査依頼として受け、横断調査と報告を通しで行う | なし |

Day 21では、CLIコマンドを実行すること自体より、次の判断を重視する。

- 何が事実として確認できたか
- 何が推測に留まるか
- 追加で誰に何を確認する必要があるか
- 緊急対応が必要か
- 設定変更する場合の影響は何か
- 調査結果を短く正確に報告できるか

---

## 3. 模擬調査チケット

```text
調査ID:
  LAB-INV-GD-001

依頼内容:
  東京リージョンのGuardDutyで確認されたFinding 1件について、
  一次調査を実施し、対象リソース、重要度、関連操作、
  Network・IAM設定、推奨対応を報告する。

対象:
  AWS Account: 445405559057
  Region: ap-northeast-1
  GuardDuty Detector: 東京リージョンの既存Detector
  Finding ID: 調査開始時に1件選定する

作業範囲:
  Read-onlyの設定確認、CloudTrail確認、証跡取得、一次報告

作業範囲外:
  Finding Archive、Feedback変更、リソース停止・隔離、
  IAM無効化、Security Group変更、通知設定変更
```

## 調査管理情報

| 項目 | 記録 |
|---|---|
| 調査日時 |  |
| 調査担当 |  |
| 調査ID | `LAB-INV-GD-001` |
| Finding ID |  |
| Finding Type |  |
| Severity |  |
| 対象リソース |  |
| 調査開始時刻 |  |
| 初回報告時刻 |  |
| 調査終了時刻 |  |
| 判定 |  |
| 推奨対応 |  |
| 未確認事項 |  |

---

## 4. Findingが存在しない場合の扱い

GuardDutyの未Archive Findingが存在しない場合は、無理に実Findingを発生させない。

次の優先順位で調査対象を選ぶ。

1. 未Archiveの実Finding
2. 過去に作成済みのサンプルFinding
3. Day 9で承認済みの手順により作成したサンプルFinding
4. Findingが存在しない場合は、想定シナリオによる机上調査

Day 21単独では`create-sample-findings`を実行しない。サンプルFindingを新規作成する場合は、Day 9の通知影響確認、対象限定、Archive手順を使用する。

机上調査へ切り替えた場合は、報告へ次のように明記する。

```text
GuardDuty Findingが存在しなかったため、実Findingに対する調査は未実施。
想定Findingを用いて、確認経路、CLI、証跡、報告方法の机上確認を実施した。
```

---

## 5. 成功条件

次をすべて満たした場合、模擬調査は成功とする。

- 対象Account、Region、Detectorが想定と一致する
- 調査対象Findingを1件に限定できる
- Finding ID、Type、Severity、Titleを確認できる
- Findingが実FindingかサンプルFindingかを区別できる
- 対象リソースとResource Roleを確認できる
- Action、通信元・通信先、発生時刻を確認できる
- CloudTrailで関連イベントを確認できる、または確認できない理由を説明できる
- 対象リソースの関連設定を確認できる
- 事実、推測、未確認事項を分けて整理できる
- 緊急度と推奨対応を説明できる
- 設定変更せずに調査を完了できる
- 証跡一覧と一次調査報告を作成できる

---

## 6. 調査中止・即時連絡条件

次に該当する場合は、通常調査を止め、管理者またはセキュリティ担当へ即時連絡する。

- Caller Identityが想定Accountと一致しない
- 調査対象が本番Accountであり、参照権限・調査承認が不明
- CriticalまたはHighの実Findingを確認した
- 現在進行中の不審操作が疑われる
- IAM Access Key悪用、Credential漏えい、Root利用が疑われる
- S3の公開、情報流出、破壊的操作が疑われる
- EC2が不審な外部通信を継続している
- 同一対象で複数Findingが急増している
- 調査中に想定外の設定変更を発見した
- 証跡に秘密情報・個人情報が含まれる

即時連絡時は、断定を避けて確認済み事実を伝える。

```text
GuardDutyでHigh SeverityのFindingを確認した。
現時点で確認済みの対象は<resource>、Finding Typeは<type>、
初回検知時刻は<time>である。
影響範囲と継続有無は調査中のため、対応判断を依頼する。
```

---

## 7. 今日の実施順序

| Phase | 手順 | 内容 |
|---|---|---|
| 開始 | S-01からS-04 | 依頼確認、変数、証跡、開始報告 |
| 対象特定 | T-01からT-05 | Account、Detector、Finding選定 |
| 一次判定 | A-01からA-06 | Severity、Resource、Action、時刻確認 |
| 横断調査 | I-01からI-08 | CloudTrail、EC2、IAM、S3、Network確認 |
| 判断 | J-01からJ-04 | 事実、推測、影響、推奨対応整理 |
| 終了 | E-01からE-05 | 証跡、報告、未確認事項、完了確認 |

---

## 8. S-01 作業用変数を設定する

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
WORK_ID="LAB-INV-GD-001"

WORK_NAME="guardduty_cloudtrail_investigation"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"
```

確認:

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nWORK_ID=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$WORK_ID" "$EVIDENCE_DIR"
```

必須変数確認:

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID WORK_ID EVIDENCE_DIR; do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set." >&2
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

## PowerShellを使う場合

```powershell
$ProfileName = "learning"
$Region = "ap-northeast-1"
$ExpectedAccountId = "445405559057"
$WorkId = "LAB-INV-GD-001"
$EvidenceDir = "evidence\$(Get-Date -Format yyyyMMdd_HHmmss)_guardduty_cloudtrail_investigation"
```

---

## 9. S-02 証跡保存先を作成する

```bash
mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/01_finding" \
  "$EVIDENCE_DIR/02_cloudtrail" \
  "$EVIDENCE_DIR/03_resource" \
  "$EVIDENCE_DIR/04_network" \
  "$EVIDENCE_DIR/05_report" \
  "$EVIDENCE_DIR/screenshots"
```

```bash
find "$EVIDENCE_DIR" -maxdepth 1 -type d -print | sort
```

証跡分類:

| Directory | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、Detector、調査時刻 |
| `01_finding` | Finding一覧、Finding詳細、要約 |
| `02_cloudtrail` | 関連CloudTrail Event |
| `03_resource` | EC2、IAM、S3などの設定 |
| `04_network` | SG、Route、NACL、Flow Logs設定 |
| `05_report` | 事実整理、時系列、報告文 |
| `screenshots` | Webコンソール証跡 |

---

## 10. S-03 調査開始時刻を記録する

```bash
date '+%Y-%m-%d %H:%M:%S %z' \
  | tee "$EVIDENCE_DIR/00_metadata/00_investigation_start_time.txt"
```

CloudTrail Event Historyは時刻条件を指定して検索できる。調査開始時刻だけでなく、Findingの`CreatedAt`、`UpdatedAt`、`Service.EventFirstSeen`、`Service.EventLastSeen`も後続で確認する。

---

## 11. S-04 調査開始報告

```text
LAB-INV-GD-001 GuardDuty Finding一次調査を開始する。

対象:
AWS Account 445405559057
Region ap-northeast-1

実施範囲:
Finding確認、CloudTrail確認、関連リソース・Network設定確認、一次報告

設定変更:
なし

調査対象Findingは、DetectorとFinding一覧確認後に1件選定する。
```

---

## 12. T-01 AWS操作アカウントを確認する

### Webコンソール

1. AWSマネジメントコンソール右上のAccount情報を確認する
2. Account IDが`445405559057`であることを確認する
3. Regionを東京リージョンへ切り替える
4. 調査対象環境であることを確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"
```

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

一致確認:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" = "$EXPECTED_ACCOUNT_ID" ]; then
  echo "OK: Account ID matched: $ACCOUNT_ID"
else
  echo "STOP: Unexpected Account ID: $ACCOUNT_ID" >&2
fi
```

---

## 13. T-02 GuardDuty Detectorを確認する

### Webコンソール

1. GuardDutyコンソールを開く
2. 東京リージョンであることを確認する
3. GuardDutyが有効であることを確認する
4. Findings画面を開く

取得するスクリーンショット:

```text
02_GuardDuty_Detector確認.png
```

### Detector一覧

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/02_detector_list.json"
```

### Detector ID取得

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text \
  --no-cli-pager)

printf 'DETECTOR_ID=%s\n' "$DETECTOR_ID"
```

中止条件:

```bash
if [ -z "$DETECTOR_ID" ] || [ "$DETECTOR_ID" = "None" ]; then
  echo "STOP: GuardDuty Detector was not found." >&2
else
  echo "OK: GuardDuty Detector was found."
fi
```

### Detector詳細

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/03_detector_detail.json"
```

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency,UpdatedAt:UpdatedAt}' \
  --output table \
  --no-cli-pager
```

期待値:

```text
Status: ENABLED
```

---

## 14. T-03 調査候補Findingを確認する

最初に未Archive Findingを一覧表示する。

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --sort-criteria AttributeName=updatedAt,OrderBy=DESC \
  --max-results 20 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_finding/01_unarchived_finding_ids.json"
```

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --sort-criteria AttributeName=updatedAt,OrderBy=DESC \
  --max-results 20 \
  --query 'FindingIds' \
  --output table \
  --no-cli-pager
```

High以上の候補を優先表示する。

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.archived":{"Eq":["false"]}}}' \
  --sort-criteria AttributeName=severity,OrderBy=DESC \
  --max-results 20 \
  --query 'FindingIds' \
  --output table \
  --no-cli-pager
```

### Severityの目安

| 数値 | Console表示 | 初動 |
|---|---|---|
| 9.0から10.0 | Critical | 即時連絡、緊急対応判断 |
| 7.0から8.9 | High | 速やかに共有、優先調査 |
| 4.0から6.9 | Medium | 一次調査、影響確認 |
| 1.0から3.9 | Low | 内容確認、傾向監視 |

---

## 15. T-04 調査対象Findingを1件選定する

GuardDutyコンソールまたは一覧結果から、調査対象Finding IDを1件選ぶ。

```bash
FINDING_ID="<finding-id>"
```

確認:

```bash
printf 'DETECTOR_ID=%s\nFINDING_ID=%s\n' \
  "$DETECTOR_ID" "$FINDING_ID"
```

空値確認:

```bash
if [ -z "$FINDING_ID" ] || [ "$FINDING_ID" = "<finding-id>" ]; then
  echo "STOP: FINDING_ID is not set." >&2
else
  echo "OK: Investigation target Finding ID is set."
fi
```

調査対象を1件に限定する理由:

- 別Findingの情報を混同しない
- 証跡と報告の対象を明確にする
- Archiveや対応判断を誤らない
- 調査時系列を追いやすくする

---

## 16. T-05 Finding詳細を保存する

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_finding/02_finding_detail.json"
```

要約表示:

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].{Id:Id,Type:Type,Severity:Severity,Title:Title,AccountId:AccountId,Region:Region,CreatedAt:CreatedAt,UpdatedAt:UpdatedAt,ResourceType:Resource.ResourceType,ResourceRole:Service.ResourceRole,ActionType:Service.Action.ActionType,Archived:Service.Archived,Count:Service.Count}' \
  --output table \
  --no-cli-pager
```

取得するスクリーンショット:

```text
03_GuardDuty_Finding概要.png
04_GuardDuty_Finding詳細.png
```

---

## 17. A-01 Findingの基本項目を確認する

| 項目 | 確認内容 |
|---|---|
| `Id` | 調査対象Finding ID |
| `Type` | 検知種類 |
| `Title` | 検知内容の要約 |
| `Description` | 詳細説明 |
| `Severity` | 対応優先度 |
| `AccountId` | 発生Account |
| `Region` | 発生Region |
| `CreatedAt` | Finding作成時刻 |
| `UpdatedAt` | 最終更新時刻 |
| `Service.Count` | 同種イベントの集約回数 |
| `Service.Archived` | Archive状態 |

基本情報を個別表示する。

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].{Type:Type,Title:Title,Description:Description,Severity:Severity,CreatedAt:CreatedAt,UpdatedAt:UpdatedAt,Count:Service.Count,Archived:Service.Archived}' \
  --output table \
  --no-cli-pager
```

確認結果記録:

```text
Finding ID:
Finding Type:
Title:
Severity:
CreatedAt:
UpdatedAt:
Count:
Archived:
```

---

## 18. A-02 実Finding・サンプルFindingを区別する

サンプルFindingであることは、TypeやTitleだけで断定しない。

確認する情報:

- サンプルFinding作成の作業記録
- `CreateSampleFindings`のCloudTrail Event
- 作成時刻とFinding作成時刻の一致
- 対象リソースIDが架空またはサンプルか
- 調査依頼者からの情報
- 通知・検証計画

GuardDuty操作履歴:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=guardduty.amazonaws.com \
  --query 'Events[?EventName==`CreateSampleFindings`].{EventTime:EventTime,Username:Username,EventName:EventName,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

判定例:

```text
判定: サンプルFinding
根拠:
- 承認済みCreateSampleFindingsの作業記録がある
- CloudTrailのCreateSampleFindings時刻とFinding CreatedAtが一致する
- Finding内の対象リソースが検証用情報である
```

```text
判定: 実Findingの可能性あり
根拠:
- サンプル作成記録を確認できない
- 対象リソースが実在する
- FindingのEventLastSeenが更新されている

未確認:
- 利用者による正当な操作か
- 対象通信の業務要件
```

---

## 19. A-03 Severityと緊急度を判断する

Severityだけで緊急度を決めない。次を組み合わせて判断する。

- Severity
- 対象リソースの重要度
- Finding Type
- Resource Role
- EventFirstSeen、EventLastSeen
- Count増加
- 現在も継続しているか
- 情報流出・権限悪用の可能性
- 対象環境が本番か検証か

時刻・Count確認:

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].{Severity:Severity,Count:Service.Count,FirstSeen:Service.EventFirstSeen,LastSeen:Service.EventLastSeen,ResourceRole:Service.ResourceRole}' \
  --output table \
  --no-cli-pager
```

判断記録:

```text
Severity:
対象環境:
継続有無:
対象リソース重要度:
暫定緊急度:
即時連絡要否:
判断根拠:
```

---

## 20. A-04 対象リソースを確認する

Resource全体を証跡として保存する。

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].Resource' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_finding/03_finding_resource.json"
```

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].{ResourceType:Resource.ResourceType,ResourceRole:Service.ResourceRole}' \
  --output table \
  --no-cli-pager
```

主なResource Type:

| Resource Type | 横断先 |
|---|---|
| `Instance` | EC2、IAM Role、SG、VPC、Flow Logs |
| `AccessKey` | IAM、CloudTrail、利用サービス |
| `S3Bucket` | S3 Policy、Public設定、CloudTrail |
| `Lambda` | Function設定、IAM Role、VPC、CloudWatch Logs |
| `RDSDBInstance` | RDS設定、SG、ログ、接続元 |
| `Container` / `EKSCluster` | EKS、IAM、Network、Audit Log |

---

## 21. A-05 Resource Roleを確認する

| Resource Role | 意味 |
|---|---|
| `TARGET` | 対象リソースが攻撃・不審操作を受けた側 |
| `ACTOR` | 対象リソースが不審操作を行った側 |

```text
TARGETの例:
外部からEC2へPort Scanが行われた

ACTORの例:
EC2から不審な外部IPへ通信した
```

`ACTOR`の場合は、対象リソースが侵害されている可能性を考慮し、優先度を上げて確認する。

---

## 22. A-06 Action・通信情報を確認する

Action全体を保存する。

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].Service.Action' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/01_finding/04_finding_action.json"
```

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].Service.Action' \
  --output table \
  --no-cli-pager
```

確認する情報:

- Action Type
- Direction
- Protocol
- Local IP・Port
- Remote IP・Port
- Domain
- API名
- User Agent
- Blockedの有無

Actionの形はFinding Typeによって異なる。値が表示されない場合は、Finding全体JSONを確認する。

---

## 23. I-01 CloudTrail調査の方針を決める

CloudTrail Event Historyは管理イベントの調査に有効である。一方、次の情報が必ず見つかるとは限らない。

- EC2内部のOS操作
- VPC Flow Logs相当のNetwork通信
- Trailで有効化されていないData Event
- 90日より古いEvent History
- 別Regionの操作

最初に確認するCloudTrail検索軸:

| 調査対象 | 検索軸 |
|---|---|
| EC2 | Instance ID、関連EventName、IAM Role |
| IAM Access Key | Username、Access Key情報、EventSource |
| S3 | Bucket名、S3設定変更EventName |
| Lambda | Function名、Update系EventName |
| GuardDuty操作 | EventSource=`guardduty.amazonaws.com` |

---

## 24. I-02 CloudTrailで対象リソースの操作履歴を確認する

Findingから確認した実際のリソース名を設定する。

```bash
RESOURCE_NAME="<resource-name>"
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$RESOURCE_NAME" \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

JSON証跡:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$RESOURCE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_cloudtrail/01_resource_events.json"
```

注意:

- `lookup-events`で一度に指定できるLookup Attributeは1つである
- Finding発生時刻の前後を中心に確認する
- Event Historyにないことは、操作がなかったことの完全な証明ではない
- Data Eventが必要な場合はTrail設定またはCloudTrail Lakeを確認する

---

## 25. I-03 CloudTrail Event詳細を確認する

一覧から確認対象Event IDを設定する。

```bash
EVENT_ID="<event-id>"
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,ReadOnly:ReadOnly,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

詳細JSON:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/02_cloudtrail/02_selected_event.json"
```

CloudTrailで確認する項目:

```text
eventTime
eventSource
eventName
userIdentity
sourceIPAddress
userAgent
requestParameters
responseElements
errorCode
errorMessage
resources
readOnly
```

取得するスクリーンショット:

```text
05_CloudTrail_関連イベント一覧.png
06_CloudTrail_関連イベント詳細.png
```

---

## 26. I-04 EC2 Findingの場合の横断調査

Finding対象がEC2の場合、Finding詳細から実際のInstance IDを設定する。

```bash
INSTANCE_ID="<instance-id>"
```

### EC2基本情報

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,VpcId:VpcId,SubnetId:SubnetId,IamProfile:IamInstanceProfile.Arn,SecurityGroups:SecurityGroups}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_resource/01_ec2_instance.json"
```

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,VpcId:VpcId,SubnetId:SubnetId,IamProfile:IamInstanceProfile.Arn}' \
  --output table \
  --no-cli-pager
```

### EC2 Security Group ID取得

```bash
SECURITY_GROUP_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' \
  --output text \
  --no-cli-pager)

printf 'SECURITY_GROUP_IDS=%s\n' "$SECURITY_GROUP_IDS"
```

### Security Group詳細

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SECURITY_GROUP_IDS \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_network/01_ec2_security_groups.json"
```

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SECURITY_GROUP_IDS \
  --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output table \
  --no-cli-pager
```

確認ポイント:

- Public IPの有無
- Internetから到達可能なIngressの有無
- `0.0.0.0/0`または`::/0`へのEgress
- FindingのPort・ProtocolとSG Ruleの関係
- IAM Instance Profileの権限
- 対象がPublic SubnetかPrivate Subnetか
- 業務上必要な通信か

変更は実施せず、隔離が必要な場合は影響と手順案を報告する。

---

## 27. I-05 IAM Access Key Findingの場合の横断調査

Finding対象がAccess Keyの場合、対象IAM UserまたはRole、Access Key ID、関連API操作を確認する。

Access Key詳細:

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[0].Resource.AccessKeyDetails' \
  --output table \
  --no-cli-pager
```

IAM Userが特定できる場合:

```bash
IAM_USER_NAME="<iam-user-name>"
```

```bash
aws iam get-user \
  --profile "$PROFILE" \
  --user-name "$IAM_USER_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_resource/02_iam_user.json"
```

```bash
aws iam list-access-keys \
  --profile "$PROFILE" \
  --user-name "$IAM_USER_NAME" \
  --output table \
  --no-cli-pager
```

CloudTrailでUser操作を確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=Username,AttributeValue="$IAM_USER_NAME" \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,EventSource:EventSource,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

確認ポイント:

- Access Key Status
- Access Key作成日時
- 通常利用するRegion・Service
- Finding発生時刻前後のAPI操作
- `sourceIPAddress`と`userAgent`
- 失敗イベントと成功イベント
- 権限変更、Key作成、Policy変更の有無

Access Key無効化は影響が大きい。調査担当の独断で実施せず、緊急度、利用箇所、代替手段を整理して判断を依頼する。

---

## 28. I-06 S3 Findingの場合の横断調査

Finding対象がS3の場合、対象Bucket名を設定する。

```bash
BUCKET_NAME="<bucket-name>"
```

### Public判定

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

### Public Access Block

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

### Bucket Policy

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager \
  > "$EVIDENCE_DIR/03_resource/03_s3_bucket_policy.json"
```

### CloudTrail

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

確認ポイント:

- `IsPublic`
- Public Access Blockの4項目
- Bucket PolicyのPrincipal、Action、Resource、Condition
- ACL、Object Ownership
- 暗号化、Versioning、Logging
- Bucket Policy・ACL・Public設定の変更履歴
- S3 Data Eventが必要か

---

## 29. I-07 Network設定を横断確認する

EC2、RDS、LambdaなどVPC内リソースが対象の場合、VPC、Subnet、Route Table、NACL、Flow Logs設定を確認する。

対象値を設定する。

```bash
VPC_ID="<vpc-id>"
SUBNET_ID="<subnet-id>"
```

### Route Table

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_network/02_route_tables.json"
```

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Routes:Routes}' \
  --output table \
  --no-cli-pager
```

### Network ACL

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_network/03_network_acls.json"
```

### VPC Flow Logs設定

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/04_network/04_vpc_flow_logs.json"
```

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --query 'FlowLogs[*].{FlowLogId:FlowLogId,Status:FlowLogStatus,TrafficType:TrafficType,DestinationType:LogDestinationType,Destination:LogDestination}' \
  --output table \
  --no-cli-pager
```

確認ポイント:

- Internet Gateway、NAT Gateway、Transit Gateway、VPC EndpointへのRoute
- Public Subnet・Private Subnetの区別
- NACLの許可・拒否
- SGとの組み合わせ
- Flow Logsの有無、保存先、Traffic Type
- Findingの通信方向・IP・Portとの整合性

Flow Logsが未設定の場合、過去通信の確認ができない可能性がある。未設定を事実として報告し、必要に応じて有効化の影響調査を提案する。

---

## 30. I-08 同一対象・同一TypeのFindingを確認する

同一対象で複数Findingが発生している場合、単発事象より優先度が高い可能性がある。

Finding Typeを設定する。

```bash
FINDING_TYPE="<finding-type>"
```

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"type\":{\"Eq\":[\"$FINDING_TYPE\"]},\"service.archived\":{\"Eq\":[\"false\"]}}}" \
  --sort-criteria AttributeName=updatedAt,OrderBy=DESC \
  --max-results 50 \
  --query 'FindingIds' \
  --output table \
  --no-cli-pager
```

Finding ID一覧だけでは詳細を判断できない。必要なIDだけを`get-findings`で確認する。

確認ポイント:

- Countが増えているか
- EventLastSeenが更新されているか
- 同じ対象で別TypeのFindingがあるか
- 複数Regionで発生していないか
- 過去に同様のFindingがArchiveされていないか

---

## 31. J-01 時系列を整理する

Finding、CloudTrail、関係者情報を時刻順に並べる。

```text
時刻                      情報源       確認内容
YYYY-MM-DD HH:MM:SS JST   GuardDuty    EventFirstSeen
YYYY-MM-DD HH:MM:SS JST   CloudTrail   関連設定変更またはAPI操作
YYYY-MM-DD HH:MM:SS JST   GuardDuty    EventLastSeen
YYYY-MM-DD HH:MM:SS JST   GuardDuty    Finding UpdatedAt
YYYY-MM-DD HH:MM:SS JST   作業記録     調査開始
YYYY-MM-DD HH:MM:SS JST   Teams        初回報告
```

UTCとJSTを混同しない。CloudTrail JSONの`eventTime`はUTC表記になる場合がある。

時系列へ含める情報:

- Findingの初回・最終検知時刻
- Count
- 関連するCloudTrail Event
- 設定変更時刻
- 調査開始・報告時刻
- 対応判断時刻

---

## 32. J-02 事実・推測・未確認事項を分ける

### 事実

AWS画面、CLI、ログ、承認済み資料で確認できた内容を書く。

```text
- GuardDutyでFinding ID <id>を確認した
- Severityは<severity>である
- 対象リソースは<resource>である
- EventLastSeenは<time>である
- 対象Security Groupに<rule>が存在する
- CloudTrail Event Historyでは関連する設定変更を確認できなかった
```

### 推測

事実から考えられる可能性を、断定せずに書く。

```text
- 対象通信は業務通信ではない可能性がある
- Access Keyが想定外の端末から利用された可能性がある
- EC2が外部から到達可能な構成であることが影響した可能性がある
```

### 未確認事項

追加調査または関係者確認が必要な項目を書く。

```text
- 対象通信の業務要件
- 対象リソースの管理担当
- Flow Logs保存期間
- Access Keyの利用元システム
- 同一時間帯のアプリケーションログ
```

---

## 33. J-03 影響範囲を整理する

| 観点 | 確認内容 |
|---|---|
| Confidentiality | 情報閲覧・流出の可能性 |
| Integrity | 設定・データ改ざんの可能性 |
| Availability | 停止・削除・負荷影響の可能性 |
| 対象範囲 | 単一リソース、VPC、Account、複数Account |
| 継続性 | 単発、継続、再発 |
| 業務影響 | 対象システム、利用者、時間帯 |

記載例:

```text
現時点で確認できた影響:
- 対象EC2 1台に関するFindingを確認した
- EventLastSeen以降の継続検知は確認していない
- CloudTrail Event Historyでは関連する設定変更を確認していない

未確認:
- EC2内部のプロセス・ログ
- 対象通信による情報流出有無
- 同一VPC内の他リソースへの影響
```

---

## 34. J-04 推奨対応を整理する

Day 21では対応操作を実施せず、推奨案として整理する。

| 優先度 | 推奨対応例 | 事前確認 |
|---|---|---|
| 緊急 | EC2隔離、Access Key無効化 | 業務影響、承認者、代替経路 |
| 高 | SG Rule制限、認証情報ローテーション | 利用元、接続要件、切り戻し |
| 中 | Flow Logs・CloudTrail Data Event追加調査 | 料金、保存先、保持期間 |
| 低 | Tag・Owner情報整備、監視閾値見直し | 運用ルール |

推奨対応記載例:

```text
推奨対応:
1. 対象リソース管理担当へ通信要件を確認する
2. 業務通信ではない場合、EC2隔離またはSG制限を検討する
3. 隔離前にApplication影響、代替経路、切り戻し方法を確認する
4. OS・Application Logを追加調査する
5. 必要に応じてFlow Logs保存・監視設定を見直す

実施状況:
本調査では設定変更を実施していない
```

---

## 35. Webコンソールで取得する証跡

| No. | スクリーンショット | 目的 |
|---:|---|---|
| 1 | `01_操作アカウント確認.png` | Account・Region確認 |
| 2 | `02_GuardDuty_Detector確認.png` | Detector有効確認 |
| 3 | `03_GuardDuty_Finding概要.png` | Type、Severity、対象確認 |
| 4 | `04_GuardDuty_Finding詳細.png` | Resource、Action、時刻確認 |
| 5 | `05_CloudTrail_関連イベント一覧.png` | 関連Event一覧 |
| 6 | `06_CloudTrail_関連イベント詳細.png` | User、Source IP、Request確認 |
| 7 | `07_対象リソース設定確認.png` | EC2、IAM、S3などの設定 |
| 8 | `08_Network設定確認.png` | SG、Route、NACL、Flow Logs |

スクリーンショット取得時の注意:

- AccountとRegionを識別できるようにする
- Finding ID、Type、Severityを識別できるようにする
- Access Key、Token、個人情報を含めない
- 必要範囲だけを取得する
- ファイル名と手順No.を対応させる
- 画面だけで判定できない項目はCLI証跡を併用する

---

## 36. E-01 証跡ファイルを確認する

```bash
echo "=== Evidence files ==="
find "$EVIDENCE_DIR" -type f -print | sort

echo "=== Empty evidence files ==="
find "$EVIDENCE_DIR" -type f -size 0 -print | sort

echo "=== Evidence file count ==="
find "$EVIDENCE_DIR" -type f | wc -l
```

空ファイルがある場合は、次を確認する。

- コマンドが成功したか
- 出力なしが正常結果か
- Errorが標準エラーへ出ていないか
- 証跡として説明可能か

証跡のHashを保存する。

```bash
find "$EVIDENCE_DIR" -type f \
  ! -path "$EVIDENCE_DIR/05_report/evidence_sha256.txt" \
  -exec shasum -a 256 {} \; \
  | sort \
  > "$EVIDENCE_DIR/05_report/evidence_sha256.txt"
```

---

## 37. E-02 一次調査結果を作成する

```text
調査ID:
LAB-INV-GD-001

調査対象:
AWS Account:
Region:
Finding ID:
Finding Type:
Severity:
対象リソース:
Resource Role:

検知概要:

確認済み事実:
- <fact-1>
- <fact-2>
- <fact-3>

CloudTrail確認結果:
- <cloudtrail-result>

関連設定確認結果:
- <related-setting-result>

影響範囲:
- <impact>

暫定判定:

推奨対応:
1.
2.
3.

未確認事項:
- <open-item>

設定変更:
なし

証跡保存先:
<evidence-directory>
```

---

## 38. E-03 Teams初回報告例

### Medium以下で継続検知がない場合

```text
GuardDuty Findingの一次調査を開始した。

Finding Typeは<type>、Severityは<severity>、
対象リソースは<resource>である。

現時点で<EventLastSeen>以降の継続検知は確認していない。
CloudTrailと関連設定を確認し、影響範囲と推奨対応を整理する。
設定変更は実施していない。
```

### High以上または継続中の場合

```text
GuardDutyでHigh以上のFindingを確認したため共有する。

Finding Type: <type>
Severity: <severity>
対象リソース: <resource>
FirstSeen: <time>
LastSeen: <time>
Count: <count>

現在進行中の可能性を含めて調査中である。
隔離・認証情報無効化などの対応要否について判断を依頼する。
独断での設定変更は実施していない。
```

---

## 39. E-04 Teams完了報告例

```text
LAB-INV-GD-001 GuardDuty Finding一次調査が完了した。

対象:
Finding ID <id>
Finding Type <type>
Severity <severity>
Resource <resource>

確認結果:
- <fact-1>
- <fact-2>
- <fact-3>

CloudTrail:
<related-event-result>

暫定判定:
<assessment>

推奨対応:
1. <recommendation-1>
2. <recommendation-2>

未確認事項:
- <open-item>

設定変更:
なし

証跡:
<evidence-directory>
```

---

## 40. E-05 調査完了判断

調査完了は、問題がないと断定することではない。

一次調査の完了条件:

- Findingの基本情報を確認した
- 緊急度を判断した
- 対象リソースとActionを確認した
- CloudTrailと関連設定を確認した
- 事実、推測、未確認事項を分けた
- 推奨対応と判断依頼事項を整理した
- 証跡を保存した
- 結果を報告した

追加調査が必要な場合は、担当、対象、期限を明確にして引き継ぐ。

---

## 41. GUI中心で調査する場合

| 調査内容 | Webコンソール |
|---|---|
| Account・Region | 画面右上 |
| Detector・Finding | GuardDuty Findings |
| Finding Resource・Action | Finding詳細 |
| CloudTrail Event | CloudTrail Event history |
| EC2・SG | EC2 Instances、Security Groups |
| IAM User・Key | IAM Users |
| S3設定 | S3 Permissions、Properties |
| Route・NACL・Flow Logs | VPC Console |

GUI中心でも、次を省略しない。

- 対象Account・Region確認
- Finding IDによる対象限定
- 発生時刻・重要度・対象リソース確認
- 証跡ファイル名と手順No.の対応
- 事実と推測の分離
- 設定変更前の承認確認

---

## 42. AWS CLIが制限される場合

AWS CLIが利用できない場合は、Webコンソールと手順書へ次を記録する。

```text
確認画面:
確認日時:
対象Account:
対象Region:
Finding ID:
Finding Type:
Severity:
対象リソース:
EventFirstSeen:
EventLastSeen:
CloudTrail Event:
関連設定:
確認結果:
未確認事項:
```

CLIを使用できないこと自体を未確認事項として明記する。

```text
AWS CLI利用制限により、Finding JSONの保存およびCLIによる再確認は未実施。
WebコンソールのFinding詳細とCloudTrail Event historyで一次調査を実施した。
```

---

## 43. よくある失敗

| 失敗 | 原因 | 対応 |
|---|---|---|
| 別Accountを調査する | Caller Identity未確認 | 調査開始時にAccount・Region確認 |
| Findingを混同する | IDを固定していない | 1件のFinding IDを変数化 |
| Severityだけで安全と判断する | 対象・継続性未確認 | Resource、Role、Count、時刻確認 |
| サンプルを実Findingと誤認する | 作成記録未確認 | CloudTrailと作業記録確認 |
| 実Findingをサンプルと断定する | Typeだけで判断 | 根拠がなければ実Finding扱い |
| CloudTrailにないので問題なしとする | 記録範囲の理解不足 | Management/Data Event、Region確認 |
| Findingと設定を直接結びつける | 因果関係未確認 | 事実と推測を分ける |
| 独断で隔離・無効化する | 緊急対応手順未確認 | 影響と承認者を確認 |
| Archiveして証跡を失う | 調査対象操作の誤り | Day 21ではArchiveしない |
| 報告が長く結論不明 | 情報整理不足 | 結論、事実、影響、依頼の順に報告 |

---

## 44. セキュリティ上の注意点

- 実Findingはサンプルと断定できない限り実事象として扱う
- Critical・Highは早期共有する
- Access Key、Secret、Session Tokenを証跡へ残さない
- Source IP、User名、リソース名の共有範囲を確認する
- FindingのArchiveは解決を意味しない
- Archive前に証跡、調査結果、対応状況を確認する
- EC2停止やSG変更は業務影響を伴う
- Access Key無効化は利用システム停止につながる
- CloudTrail Event Historyだけで完全な操作履歴と断定しない
- Flow Logs未設定の場合、過去通信を後から確認できない
- 調査中に設定変更を行わない
- 推測を事実として報告しない

---

## 45. 案件で説明できるポイント

- GuardDuty Findingを1件に限定して調査できる
- Severity、Resource、Resource Role、Action、時刻を説明できる
- 実FindingとサンプルFindingを根拠により区別できる
- CloudTrail Event Historyの対象範囲と限界を説明できる
- FindingからEC2、IAM、S3、Networkへ横断調査できる
- Flow Logs、SG、Route、NACLの確認観点を説明できる
- 事実、推測、未確認事項を分けて報告できる
- 緊急対応が必要な場合に、独断変更せず判断を依頼できる
- GUIとCLIの両方で証跡を取得できる
- 一次調査結果をTeamsで簡潔に報告できる

---

## 46. 資格試験につながるポイント

- GuardDuty DetectorとFinding
- Severity
- Resource Role
- Finding TypeとAction
- GuardDutyとCloudTrailの役割差
- CloudTrail Management EventとData Event
- VPC Flow Logs
- Security GroupとNetwork ACL
- IAM Access Keyの管理
- S3 Public Access BlockとBucket Policy
- EventBridgeによるFinding通知
- インシデント対応のContainment、Investigation、Recovery

---

## 47. 要確認事項

実案件へ参画後、次を確認する。

- GuardDuty Findingの受付・担当割当方法
- Severityごとの連絡期限
- Critical・Highの即時連絡先
- NTTデータ側と参画チーム側の責任分界
- Finding調査手順書と報告テンプレート
- サンプルFinding作成可否
- Finding Archive・Feedback変更の権限と承認
- 自動隔離・自動修復の有無
- CloudTrail、CloudTrail Lake、SIEMの利用範囲
- VPC Flow Logsの保存先と保持期間
- OS・Application Logの確認担当
- 複数Account・複数Regionの調査方法
- 証跡の保存先、命名規則、Maskルール
- 顧客・銀行への報告経路

---

## 48. Day 21完了チェックリスト

### 開始・対象特定

- [ ] 模擬調査チケットを確認した
- [ ] 作業範囲がRead-onlyであることを確認した
- [ ] 変数と証跡Directoryを準備した
- [ ] 調査開始時刻を記録した
- [ ] Caller Identityを確認した
- [ ] Regionを確認した
- [ ] Detectorを確認した
- [ ] 調査対象Findingを1件に限定した
- [ ] Finding詳細JSONを保存した

### 一次判定

- [ ] Finding ID、Type、Titleを確認した
- [ ] Severityを確認した
- [ ] 実Finding・サンプルFindingを区別した
- [ ] CreatedAt、UpdatedAt、FirstSeen、LastSeenを確認した
- [ ] Countを確認した
- [ ] Resource TypeとResource Roleを確認した
- [ ] Actionと通信情報を確認した
- [ ] 即時連絡要否を判断した

### 横断調査

- [ ] CloudTrailで対象リソースの操作履歴を確認した
- [ ] 必要なCloudTrail Event詳細を保存した
- [ ] 対象リソース設定を確認した
- [ ] IAM設定を必要に応じて確認した
- [ ] S3設定を必要に応じて確認した
- [ ] Security Groupを確認した
- [ ] Route Table・NACLを確認した
- [ ] VPC Flow Logs設定を確認した
- [ ] 同一対象・同一TypeのFindingを確認した

### 判断・報告

- [ ] 時系列を整理した
- [ ] 事実を整理した
- [ ] 推測を事実と分けた
- [ ] 未確認事項を整理した
- [ ] 影響範囲を整理した
- [ ] 推奨対応を整理した
- [ ] 設定変更を実施していない
- [ ] GUIとCLI証跡を確認した
- [ ] 一次調査結果を作成した
- [ ] Teams報告文を作成した

## Day 21の完了条件

次を自分の言葉で説明できればDay 21は完了とする。

```text
GuardDuty Findingの調査では、最初に対象Account、Region、Detector、
Finding IDを確認し、調査対象を1件に限定する。

FindingのSeverityだけで判断せず、Type、Resource、Resource Role、
Action、FirstSeen、LastSeen、Countを確認する。

CloudTrailでは関連する管理操作を確認し、EC2、IAM、S3、Security Group、
Route、NACL、Flow Logsなどへ横断して影響範囲を調査する。

CloudTrailやFlow Logsに記録がない場合は、問題がないと断定せず、
記録範囲と未確認事項を報告する。

調査結果は事実、推測、未確認事項を分け、緊急度、影響範囲、
推奨対応を報告する。対応操作は承認を得てから実施する。
```
