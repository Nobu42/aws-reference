# Day 8 Learning: GuardDuty基礎確認・Finding一次調査

## 学習開始前に実行するスクリプト

Day 8は既存GuardDuty DetectorとFindingを読み取り専用で確認するハンズオンである。AWSリソースは新規作成しないが、Detector、Finding、関連CloudTrailを実際にCLIとGUIで確認する。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

GuardDuty Detectorが存在しない場合は、勝手に有効化せず、Detector未設定として記録する。

実行場所と作業対象アカウントを確認する。

```bash
cd /Users/nobu/aws-reference/day-learning

aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

Detectorの有無を最初に確認する。

```bash
aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1 \
  --output table \
  --no-cli-pager
```

## 1. 今日の目的

Amazon GuardDutyのDetector、Finding、Severity、対象リソース、Actionを確認し、Findingを受け取った際の一次調査と報告を行える状態を目指す。

Day 8では、GuardDutyの設定変更やサンプルFinding作成は行わない。既存設定と既存Findingを読み取り、次の問いへ回答できるようにする。

```text
GuardDutyは対象リージョンで有効か。
未対応のFindingはあるか。
Findingの重要度と対象リソースは何か。
自分のリソースは攻撃対象か、不審動作を行う側か。
最初に何を確認し、誰へ何を報告するか。
```

関連資料:

- [GuardDuty CLIリファレンス](../docs/references/05_guardduty_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md)
- [オンプレミス、S3、CloudTrail、GuardDutyのつながり](../docs/case_studies/case_study_onpremises_s3_cloudtrail_guardduty.md)
- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)
- [Day 7 CloudTrail・CloudWatch総合調査ドリル](./07_Day_Learning.md)

## 今日の調査シナリオ

次の依頼を受けた想定で調査する。

```text
対象AWSアカウントのGuardDuty設定と未対応Findingを確認してください。

Findingが存在する場合は、重要度、Finding Type、対象リソース、
Resource Role、Action、初回・最終検知時刻を確認し、
一次調査結果と追加確認事項を報告してください。

GuardDuty設定変更、Finding Archive、リソース隔離は行わないでください。
```

## 今日の確認順序

1. AWSアカウントとリージョンを確認する
2. 証跡保存先を準備する
3. GuardDuty Detectorの存在を確認する
4. Detector状態とFinding発行頻度を確認する
5. Protection Plan・Featureの状態を確認する
6. 未Archive Finding件数を確認する
7. High以上のFindingを優先確認する
8. Severity別の件数を確認する
9. 調査対象Findingを1件選択する
10. Finding詳細を確認する
11. Resource RoleとAction Typeを確認する
12. 対象リソースと関連ログへ横展開する
13. EventBridge・通知連携の有無を確認する
14. 証跡、判断、追加確認事項を整理する
15. Teams報告文を作成する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 主な確認対象 | Detector、Feature、Finding、Severity、Resource、Action |
| Finding対象 | 未Archive Findingを優先 |
| 設定変更 | なし |

## 今日実行しない操作

次の操作は検知、課金、通知、インシデント対応、業務へ影響するため実行しない。

- GuardDuty Detectorの作成、更新、無効化、削除
- Protection Plan・Featureの有効化、無効化
- サンプルFindingの作成
- FindingのArchive、Unarchive
- Finding Feedbackの変更
- EventBridge Ruleや通知先の作成、更新、削除
- EC2停止、隔離、Security Group変更
- IAM Access Key無効化、削除
- S3 Bucket Policy変更
- RDS、Lambda、EKSなど対象リソースの設定変更
- Findingを再現するための不審通信や異常操作

---

## 2. GuardDutyの役割を理解する

GuardDutyは、AWS環境で発生した不審な動作を分析し、Findingとして提示する脅威検知サービスである。

GuardDuty Findingは、侵害を断定するものではない。

```text
GuardDuty Finding:
調査を開始するための検知結果

一次調査:
対象リソース、重要度、Action、時刻、関連ログを確認する

判断:
正常作業、既知の検証、誤検知、要調査、侵害疑いを整理する

対応:
承認と業務影響を確認したうえで、隔離、権限停止、設定変更などを実施する
```

## GuardDutyと他サービスの役割

| サービス | 主な役割 |
|---|---|
| GuardDuty | AWSログなどを分析して不審な活動をFindingとして検知する |
| CloudTrail | AWS API操作の実行者、時刻、送信元、結果を確認する |
| VPC Flow Logs | ENIを通過するネットワーク通信のメタデータを確認する |
| Route 53 Resolver DNS Query Logs | DNS問い合わせを確認する |
| CloudWatch Logs | 各種ログの保存・検索・監視を行う |
| EventBridge | GuardDuty Findingを通知や自動処理へ連携する |
| Security Hub | 複数サービスやアカウントのFindingを集約する |

重要:

```text
GuardDutyが分析に利用するデータソースと、
人が監査・調査のために保存するCloudTrail TrailやVPC Flow Logsは、
目的と管理経路が異なる。

GuardDutyが有効でも、人が確認するためのTrailやFlow Logsが
必ず設定済みとは限らない。
```

---

## 3. GuardDutyの主な用語

| 用語 | 意味 |
|---|---|
| Detector | GuardDutyによる検知を管理するリージョン単位のリソース |
| Finding | GuardDutyが検知したセキュリティイベント |
| Finding Type | 検知内容を分類する名前 |
| Severity | Findingの重要度 |
| Resource | Findingに関係するAWSリソース |
| Resource Role | リソースが`TARGET`か`ACTOR`かを示す |
| Action | 検知された通信、API、DNS、ログイン試行など |
| Count | 同一Findingへ集約された検知回数 |
| Archived | FindingがArchive済みか |
| Protection Plan | S3、EKS、RDS、Lambda、Malware Protectionなどの追加保護 |
| Sample Finding | 調査・通知手順の検証用Finding |

## Resource Role

| Resource Role | 意味 | 例 |
|---|---|---|
| `TARGET` | 自分のAWSリソースが攻撃や不審活動の対象 | 外部からEC2へポートスキャン |
| `ACTOR` | 自分のAWSリソースが不審活動を行う側 | EC2から疑わしい外部IPへ通信 |

`ACTOR`の場合は、対象リソースが侵害されて外部へ不審通信を行っている可能性があるため、優先して確認する。

## Action Type

| Action Type | 内容 | 主な追加確認先 |
|---|---|---|
| `NETWORK_CONNECTION` | 不審なネットワーク通信 | VPC Flow Logs、EC2、SG、NACL |
| `PORT_PROBE` | ポートスキャン・探索 | SG、NACL、ALB、公開IP |
| `DNS_REQUEST` | 不審なDNS問い合わせ | DNS Query Logs、EC2、プロセス |
| `AWS_API_CALL` | 不審なAWS API操作 | CloudTrail、IAM、Access Key |
| `RDS_LOGIN_ATTEMPT` | 不審なDBログイン試行 | RDSログ、DBユーザー、SG |

---

## 4. Severityと一次対応優先度

GuardDuty Severityは、CLIとAPIでは1.0から10.0の数値で表される。

| 数値範囲 | Console表示 | 基本優先度 | 一次対応の目安 |
|---|---|---|---|
| 9.0 - 10.0 | Critical | 最優先 | 直ちに共有し、侵害可能性を確認する |
| 7.0 - 8.9 | High | 高 | 即時に一次調査を開始する |
| 4.0 - 6.9 | Medium | 中 | 早めに正当性と影響を確認する |
| 1.0 - 3.9 | Low | 低 | 記録し、継続発生や集中を確認する |

## Severityだけで判断しない

次の場合は、SeverityがMediumやLowでも優先度を上げる。

- 本番環境の重要リソースが対象
- IAM認証情報や管理者権限が関係する
- 顧客データや機密情報を保管するS3、RDSが対象
- `Count`が増加している
- 同じ送信元やリソースで継続発生している
- Resource Roleが`ACTOR`
- 作業時間外や変更申請のない時間帯に発生した

---

## 5. 作業開始条件と中止・報告条件

## 作業開始条件

- 対象AWSアカウントとリージョンが明確である
- 読み取り専用の調査である
- Findingを確認できる権限がある
- 証跡保存先が準備されている
- Findingに機密情報が含まれる可能性を理解している

## 中止・即時報告条件

- AWSアカウントまたはリージョンが想定と異なる
- CriticalまたはHigh Findingを確認した
- IAM Access Keyや管理者権限に関係するFindingを確認した
- 本番重要リソースが`ACTOR`として検知されている
- データ流出や外部への不審通信が疑われる
- GuardDuty Detectorが無効または存在しない
- 想定外のリージョンでFindingが発生している
- 調査のために設定変更やリソース隔離が必要になった

中止・報告条件へ該当した場合は、独断でArchive、隔離、停止、権限変更を行わず、Findingの事実と緊急度を早めに共有する。

---

## 6. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID
do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

---

## 7. 証跡保存用ディレクトリの作成

```bash
WORK_NAME="guardduty_basic_investigation"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/detector" \
  "$EVIDENCE_DIR/findings" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/integration" \
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

### 証跡分類

| ディレクトリ | 保存内容 |
|---|---|
| `00_metadata` | Caller Identity、作業対象 |
| `detector` | Detector、Feature、複数リージョン確認 |
| `findings` | Finding一覧、統計、高重要度Finding |
| `investigation` | 調査対象Finding詳細、関連リソース、ログ |
| `integration` | EventBridge、Security Hubなどの連携確認 |
| `report` | 調査結果、証跡一覧、Teams報告 |
| `screenshots` | Webコンソール証跡 |

---

## 8. AWSアカウントとリージョンを確認する

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. AWSアカウント情報を確認する
3. 東京リージョンを選択する
4. GuardDutyコンソールを開く

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_GuardDutyトップ画面.png
```

### AWS CLI

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

### 結果の読み方

- `Account`が想定AWSアカウントIDと一致することを確認する
- `Arn`から操作主体を確認する
- GuardDutyはリージョン単位であるため、東京リージョンであることを確認する
- 想定外のアカウントまたはリージョンの場合は後続調査を中止する

---

## 9. Detectorの存在を確認する

GuardDuty Detectorは、リージョン単位でGuardDutyの検知を管理する。

## 9.1 Webコンソール

1. GuardDutyコンソールを開く
2. GuardDutyが有効であることを確認する
3. 「設定」を開く
4. Detector IDとリージョンを確認する

取得するスクリーンショット:

```text
03_GuardDuty_Detector確認.png
```

## 9.2 AWS CLI

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/detector/01_list_detectors.json"
```

### 結果の読み方

```text
Detector IDあり:
対象リージョンでGuardDuty Detectorが存在する。

Detector IDなし:
対象リージョンでGuardDutyが未有効化、または確認権限がない可能性がある。
```

Detectorが存在しない場合は、Day 8のFinding確認を続行できない。勝手に有効化せず、監視対象リージョンとGuardDuty管理方式を確認する。

---

## 10. Detector IDを取得する

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text \
  --no-cli-pager)

echo "DETECTOR_ID=$DETECTOR_ID"
```

### Detector ID必須チェック

```bash
if [ "$DETECTOR_ID" = "None" ] || [ -z "$DETECTOR_ID" ]; then
  echo "ERROR: GuardDuty Detector was not found in $REGION."
else
  echo "GuardDuty Detector found: $DETECTOR_ID"
fi
```

GuardDutyは通常、1アカウント・1リージョンにつき1つのDetectorを持つ。Organizations環境では、委任管理者やメンバーアカウントの関係も確認する。

---

## 11. Detector状態を確認する

### AWS CLI

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
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
  > "$EVIDENCE_DIR/detector/02_get_detector.json"
```

### 要点だけ表示する

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency,ServiceRole:ServiceRole,CreatedAt:CreatedAt,UpdatedAt:UpdatedAt}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

| 項目 | 確認内容 |
|---|---|
| `Status` | `ENABLED`であるか |
| `FindingPublishingFrequency` | Finding更新の発行頻度 |
| `ServiceRole` | GuardDutyサービスRole |
| `CreatedAt` | Detector作成日時 |
| `UpdatedAt` | Detector更新日時 |

期待値:

```text
Status: ENABLED
```

`Status=DISABLED`の場合は、検知が停止しているため早めに報告する。独断で有効化しない。

---

## 12. Protection Plan・Featureを確認する

GuardDutyでは、基本的な脅威検知に加えて、S3、EKS、RDS、Lambda、Malware ProtectionなどのProtection PlanやFeatureを利用できる。

### Webコンソール

1. GuardDutyの「設定」を開く
2. Protection PlanやFeatureの状態を確認する
3. 対象システムで必要な保護が有効か確認する
4. Organizations管理の場合は管理方式を確認する

取得するスクリーンショット:

```text
04_GuardDuty_Protection_Plan確認.png
```

### AWS CLI

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --query 'Features[].{Name:Name,Status:Status,UpdatedAt:UpdatedAt}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- `ENABLED`は対象Featureが有効であることを示す
- `DISABLED`でも、対象システムで利用していないサービスなら直ちに問題とは限らない
- Featureの有効化は料金、権限、対象リソース、運用へ影響する
- 対応要否はセキュリティ要件と対象サービスを確認して判断する

### 案件で特に確認する候補

| Protection Plan・Feature | 確認理由 |
|---|---|
| S3 Protection | S3 Objectアクセスに関する不審活動の検知 |
| RDS Protection | RDSログイン活動に関する不審検知 |
| Lambda Protection | Lambdaからの不審ネットワーク活動の検知 |
| Malware Protection | 対象ワークロードやS3オブジェクトのマルウェア対策 |
| EKS Runtime Monitoring | EKSを利用する場合のRuntime監視 |

---

## 13. 複数リージョンのDetectorを確認する

GuardDutyはリージョン単位である。対象システムが利用するリージョンにDetectorが存在するか確認する。

### 確認対象リージョン例

```text
ap-northeast-1
us-east-1
us-west-2
```

### AWS CLI

```bash
for TARGET_REGION in ap-northeast-1 us-east-1 us-west-2
do
  echo "=== $TARGET_REGION ==="

  aws guardduty list-detectors \
    --profile "$PROFILE" \
    --region "$TARGET_REGION" \
    --query 'DetectorIds' \
    --output text \
    --no-cli-pager
done
```

### 証跡保存

```bash
for TARGET_REGION in ap-northeast-1 us-east-1 us-west-2
do
  aws guardduty list-detectors \
    --profile "$PROFILE" \
    --region "$TARGET_REGION" \
    --output json \
    --no-cli-pager \
    > "$EVIDENCE_DIR/detector/detectors_${TARGET_REGION}.json"
done
```

### 確認ポイント

- 対象システムが実際に利用するリージョンか
- 組織の監視対象リージョン一覧と一致するか
- 意図せず利用されているリージョンがないか
- Organizationsで自動有効化されているか

対象リージョン一覧が未確認の場合は、任意のリージョンを勝手に有効化せず、要確認事項へ残す。

---

## 14. 未Archive Findingを確認する

ArchiveされていないFindingを、現在対応対象となり得るFindingとして確認する。

## 14.1 Webコンソール

1. GuardDutyの「検出結果」を開く
2. Archive済みを除外する
3. Severityの高い順に並べる
4. Finding Type、対象リソース、更新日時を確認する

取得するスクリーンショット:

```text
05_GuardDuty_未Archive_Finding一覧.png
```

## 14.2 AWS CLI: Finding ID一覧

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/findings/01_active_finding_ids.json"
```

### 結果の読み方

```text
Finding IDあり:
未Archive Findingが存在する。詳細確認へ進む。

Finding IDなし:
現在の検索条件では未Archive Findingが存在しない。
GuardDutyが正常に有効であることや通知連携を別途確認する。
```

`list-findings`はFinding ID一覧を返す。Findingの内容は`get-findings`で確認する。

---

## 15. High以上のFindingを優先確認する

CriticalとHighを優先して確認する。

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/findings/02_high_or_critical_finding_ids.json"
```

High以上のFindingを確認した場合は、詳細調査を続けながら早めに関係者へ共有する。

---

## 16. Finding統計を確認する

## 16.1 Severity別件数

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-statistic-types COUNT_BY_SEVERITY \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-statistic-types COUNT_BY_SEVERITY \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/findings/03_findings_by_severity.json"
```

## 16.2 Finding Type別件数

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --group-by FINDING_TYPE \
  --order-by DESC \
  --max-results 50 \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- Critical、Highが何件あるか
- MediumやLowが継続して増加していないか
- 同じFinding Typeが多発していないか
- 同じリソースに集中していないか
- Archive済みFindingを除外しているか

---

## 17. 調査対象Findingを1件選択する

未Archive Findingから1件を選択し、詳細調査を行う。

### 最新Finding IDを取得する

```bash
FINDING_ID=$(aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --sort-criteria AttributeName=updatedAt,OrderBy=DESC \
  --max-results 1 \
  --query 'FindingIds[0]' \
  --output text \
  --no-cli-pager)

echo "FINDING_ID=$FINDING_ID"
```

### Finding ID必須チェック

```bash
if [ "$FINDING_ID" = "None" ] || [ -z "$FINDING_ID" ]; then
  echo "No active GuardDuty Finding was found."
else
  echo "Investigation target Finding: $FINDING_ID"
fi
```

未Archive Findingが存在しない場合は、無理にFindingを作成しない。Detector、Feature、通知連携の確認と、Findingが存在しない旨の報告を行う。

---

## 18. Finding詳細を確認する

## 18.1 Webコンソール

1. GuardDutyのFinding一覧から対象Findingを開く
2. Severity、Finding Type、Titleを確認する
3. 対象リソースとResource Roleを確認する
4. Action、通信先、API、ポートなどを確認する
5. CreatedAt、UpdatedAt、Countを確認する

取得するスクリーンショット:

```text
06_GuardDuty_Finding詳細_概要.png
07_GuardDuty_Finding詳細_Resource_Action.png
```

## 18.2 生JSONを証跡として保存する

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/01_finding_detail.json"
```

## 18.3 要約表示

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

## 18.4 確認する主要項目

| 項目 | 確認内容 |
|---|---|
| `Id` | Findingを一意に識別するID |
| `Type` | 検知内容の分類 |
| `Severity` | 一次対応の優先度 |
| `Title` | Finding概要 |
| `Description` | 詳細説明 |
| `AccountId` | 発生AWSアカウント |
| `Region` | 発生リージョン |
| `CreatedAt` | 初回検知時刻 |
| `UpdatedAt` | 最終更新時刻 |
| `Resource.ResourceType` | 対象リソース種別 |
| `Service.ResourceRole` | `TARGET`または`ACTOR` |
| `Service.Action.ActionType` | 検知されたAction種別 |
| `Service.Count` | 集約された検知回数 |
| `Service.Archived` | Archive状態 |
| `Service.Evidence` | 脅威情報などの根拠 |

### 時刻の注意

CLIとJSONではUTC、Webコンソールではローカル時刻で表示される場合がある。報告では次のようにタイムゾーンを明記する。

```text
2026-06-15 01:30 UTC
2026-06-15 10:30 JST
```

---

## 19. Finding Typeを分解して読む

Finding Typeは、検知内容を理解するための重要な情報である。

例:

```text
UnauthorizedAccess:EC2/TorClient
```

読み方:

| 部分 | 意味 |
|---|---|
| `UnauthorizedAccess` | 不正アクセスに関連する分類 |
| `EC2` | 主な対象リソースや領域 |
| `TorClient` | Torネットワークとの通信に関係する検知 |

Finding Typeだけで侵害を断定せず、Description、Resource、Action、通信先、時刻、Count、関連ログを確認する。

---

## 20. 対象リソースを確認する

Findingの`ResourceType`に応じて、関連リソースの現在状態を読み取り専用で確認する。

## 20.1 EC2が対象の場合

Finding詳細からInstance IDを確認し、次のコマンドを実行する。

```bash
INSTANCE_ID="<instance-id>"
```

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,VpcId:VpcId,SubnetId:SubnetId,SecurityGroups:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/02_ec2_instance.json"
```

確認ポイント:

- インスタンスが稼働中か
- Public IPを持つか
- 対象VPC、Subnet、Security Group
- IAM Instance Profile
- Finding発生時刻と運用作業時刻

## 20.2 S3が対象の場合

```bash
BUCKET="<bucket-name>"
```

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --output table \
  --no-cli-pager
```

確認ポイント:

- Public判定
- Public Access Block
- Bucket Policyとクロスアカウント許可
- FindingのActionと対象Object
- CloudTrail Data EventやS3アクセスログの有無

## 20.3 IAM Access Keyが対象の場合

IAM認証情報に関するFindingは優先して調査する。

確認ポイント:

- 対象IAMユーザーまたはRole
- Access Keyの所有者
- CloudTrail上のAPI操作
- 送信元IP、UserAgent、リージョン
- 通常利用と異なる操作か
- キー無効化やローテーションが必要か

Access Key IDや認証情報を証跡・チャットへ不用意に貼り付けない。キー無効化は業務影響と承認を確認して実施する。

## 20.4 RDS、Lambda、EKSなどが対象の場合

対象サービスの設定、ログ、ネットワーク、IAM Roleを確認する。

```text
RDS:
DB Instance、PubliclyAccessible、SG、DBログ、ログインユーザー

Lambda:
Function、Execution Role、VPC、環境変数、Function URL、CloudWatch Logs

EKS:
Cluster、Node、Pod、Runtime、IAM、Network Policy
```

---

## 21. Actionに応じて横展開調査する

## NETWORK_CONNECTION

確認すること:

- Local IP、Remote IP、Local Port、Remote Port
- InboundかOutboundか
- Resource Roleが`TARGET`か`ACTOR`か
- VPC Flow Logs
- Security Group、NACL、Route
- 対象EC2やLambdaのプロセス・ログ

## PORT_PROBE

確認すること:

- スキャン元IP
- 対象ポート
- Public IP、ALB、NLBの有無
- Security Groupの公開範囲
- NACL
- 通信が許可されたか拒否されたか

## DNS_REQUEST

確認すること:

- 問い合わせ先ドメイン
- 問い合わせ元リソース
- Route 53 Resolver DNS Query Logs
- 対象リソースのプロセス・アプリログ
- 同時刻のネットワーク通信

## AWS_API_CALL

確認すること:

- API名
- IAMユーザー、Role、Access Key
- 送信元IPとUserAgent
- API実行リージョン
- CloudTrailイベント
- 前後に実行された関連API

## RDS_LOGIN_ATTEMPT

確認すること:

- DBユーザー
- 送信元
- 成功・失敗
- RDSログ
- Security Group
- 正当なアプリケーション接続か

---

## 22. CloudTrailで関連APIを確認する

FindingのAction Typeが`AWS_API_CALL`の場合や、対象リソースに設定変更が疑われる場合はCloudTrailを確認する。

### 実行者名で検索する例

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=Username,AttributeValue="<username>" \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### リソース名で検索する例

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="<resource-name>" \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- Finding時刻前後のAPI
- 通常と異なるAPI
- 権限変更、認証情報作成、ログ停止
- S3 Policy、Security Group、Routeなどの設定変更
- 実行者、送信元IP、UserAgent
- `errorCode`と`errorMessage`

CloudTrail Event Historyは直近90日間のManagement Eventを検索する。長期調査やData Event確認には、TrailのS3ログやCloudTrail Lakeなどを確認する。

---

## 23. EventBridge・通知連携を確認する

GuardDuty FindingはEventBridgeを利用して通知や自動処理へ連携できる。

Day 8では連携設定の有無だけを確認し、変更しない。

### Webコンソール

1. EventBridgeコンソールを開く
2. 「ルール」を開く
3. GuardDuty Findingを対象とするRuleを確認する
4. TargetとRule状態を確認する

取得するスクリーンショット:

```text
08_EventBridge_GuardDuty連携確認.png
```

### AWS CLI: Rule一覧

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
  > "$EVIDENCE_DIR/integration/01_eventbridge_rules.json"
```

### GuardDuty関連Ruleを名前で絞る例

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name-prefix "guardduty" \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- GuardDuty Findingを受信するRuleがあるか
- Ruleが`ENABLED`か
- Event PatternがGuardDutyを対象としているか
- TargetがSNS、Lambda、Security Hubなどのどれか
- 通知先と一次対応者が決まっているか
- 自動対応がある場合、業務影響と切り戻し方法

Rule名だけではGuardDuty連携と判断できない場合がある。Event PatternとTargetの詳細を確認する。

---

## 24. GuardDuty Findingの一次調査フロー

Findingを確認した際は、次の順序で進める。

```text
1. Finding ID、Type、Severity、Titleを確認する
2. Critical / Highなら早めに共有する
3. 対象AWSアカウントとリージョンを確認する
4. 対象リソースを特定する
5. Resource RoleがTARGETかACTORか確認する
6. Action Typeと通信先・API・ポートなどを確認する
7. CreatedAt、UpdatedAt、Countを確認する
8. CloudTrail、Flow Logs、対象サービス設定へ横展開する
9. 正常作業、既知の検証、要調査、侵害疑いを整理する
10. 証跡、判断、追加確認事項を報告する
11. 対応が必要な場合は承認後に別手順で実施する
```

## 最初にしてはいけないこと

- Findingだけを見て侵害と断定する
- FindingをArchiveして一覧から消す
- EC2を停止・削除する
- Security Groupを独断で変更する
- IAM Access Keyを業務影響確認なしで削除する
- 証跡取得前に設定を変更する
- サンプルFindingと実Findingを混同する

---

## 25. Finding判断マトリクス

| 判断 | 状態 | 次の行動 |
|---|---|---|
| 正常作業 | 承認済み作業と一致 | 証跡と判断理由を記録する |
| 既知の検証 | サンプルや承認済みテスト | 検証であることを明記する |
| 誤検知候補 | 正常動作の可能性が高い | 根拠を追加確認し、Feedback要否を相談する |
| 要調査 | 情報不足で判断できない | CloudTrail、Flow Logs、対象サービスを追加調査する |
| 侵害疑い | 不正操作や不審通信の可能性 | 即時共有し、封じ込め方針を相談する |

## 判断理由に含めるもの

- Finding TypeとSeverity
- 対象リソースとResource Role
- Action、通信先、API、ポート
- CreatedAt、UpdatedAt、Count
- CloudTrailやFlow Logsの確認結果
- 作業申請・変更履歴との一致
- 対象リソースの業務重要度

---

## 26. 推奨するスクリーンショット証跡

| No. | ファイル名 | 画面 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント確認 |
| 02 | `02_GuardDutyトップ画面.png` | GuardDuty有効状態 |
| 03 | `03_GuardDuty_Detector確認.png` | Detector設定 |
| 04 | `04_GuardDuty_Protection_Plan確認.png` | Feature・Protection Plan |
| 05 | `05_GuardDuty_未Archive_Finding一覧.png` | Finding一覧 |
| 06 | `06_GuardDuty_Finding詳細_概要.png` | Severity、Type、時刻 |
| 07 | `07_GuardDuty_Finding詳細_Resource_Action.png` | Resource、Action |
| 08 | `08_EventBridge_GuardDuty連携確認.png` | 通知連携 |

スクリーンショットには、対象AWSアカウント、リージョン、Finding ID、確認日時を可能な範囲で含める。

---

## 27. 証跡ファイルを確認する

### 証跡一覧

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -print \
  | sort
```

### 空ファイル確認

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -size 0 \
  -print \
  | sort
```

### 証跡ファイル数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

### 証跡確認ポイント

- Caller Identityが保存されている
- DetectorとFeatureの状態が保存されている
- 未ArchiveとHigh以上のFinding ID一覧が保存されている
- Finding詳細の生JSONが保存されている
- 関連リソースとログの確認結果が保存されている
- EventBridgeなど通知連携の確認結果が保存されている
- 空ファイルがある場合は理由を確認している
- Access Key ID、IPアドレス、ARNなどの機密性を確認している

---

## 28. 調査結果テンプレート

```text
作業名:
GuardDuty設定確認・Finding一次調査

対象AWSアカウント:
<account-id>

対象リージョン:
<region>

確認日時:
<yyyy-mm-dd hh:mm JST>

設定変更:
なし

Detector:
Detector ID:
Status:
Finding Publishing Frequency:

Protection Plan・Feature:
<確認結果>

未Archive Finding:
<件数>

High以上のFinding:
<件数>

調査対象Finding:
Finding ID:
Finding Type:
Severity:
Title:
対象リソース:
Resource Role:
Action Type:
CreatedAt:
UpdatedAt:
Count:

横展開調査:
CloudTrail:
VPC Flow Logs:
対象サービス設定:

通知連携:
EventBridge:
通知先:

判断:
正常作業 / 既知の検証 / 誤検知候補 / 要調査 / 侵害疑い

追加確認事項:
<確認事項>

証跡保存先:
<evidence-path>
```

---

## 29. Teams報告例

### GuardDuty基礎確認完了

```text
対象AWSアカウントのGuardDuty設定を確認した。

対象:
AWSアカウント <account-id>
リージョン <region>

確認結果:
- Detector: <存在 / 未作成>
- Status: <ENABLED / DISABLED>
- 未Archive Finding: <件数>
- High以上のFinding: <件数>
- EventBridge通知連携: <あり / なし / 要確認>

設定変更は実施していない。
証跡は <evidence-path> に保存した。
```

### Findingが存在しない場合

```text
GuardDutyの未Archive Findingを確認した結果、
現在の検索条件では対象Findingは確認されなかった。

Detector StatusはENABLEDであり、Protection Planと通知連携を確認した。
Findingが存在しないことは、セキュリティ上の問題が存在しないことを
保証するものではないため、既存監視と運用状況を継続確認する。

設定変更は実施していない。
```

### Medium以下のFinding一次調査

```text
GuardDuty Findingの一次調査を実施した。

Finding:
- Finding ID: <finding-id>
- Type: <finding-type>
- Severity: <severity>
- 対象リソース: <resource>
- Resource Role: <TARGET / ACTOR>
- Action Type: <action-type>
- 初回検知: <created-at>
- 最終更新: <updated-at>
- Count: <count>

現在の判断は <正常作業 / 既知の検証 / 要調査> である。
追加確認事項は <内容> である。
設定変更、Archive、リソース隔離は実施していない。
```

### High以上のFinding共有

```text
GuardDutyでHigh以上のFindingを確認したため共有する。

Finding Type: <finding-type>
Severity: <severity>
対象リソース: <resource>
Resource Role: <TARGET / ACTOR>
Action Type: <action-type>
最終更新: <updated-at>

侵害可能性を否定できないため、CloudTrail、通信ログ、
対象リソース設定を優先して確認する。
独断でリソース隔離や設定変更は実施せず、初動方針を相談したい。
```

---

## 30. よくある問題と切り分け

## Detectorが見つからない

確認すること:

- リージョンが正しいか
- GuardDutyが有効化されているか
- IAM権限が足りているか
- Organizationsの委任管理者側で管理されていないか
- 対象アカウントがMember Accountか

## Findingが表示されない

確認すること:

- Detectorが`ENABLED`か
- リージョンが正しいか
- FindingがArchive済みではないか
- Finding Criteriaが狭すぎないか
- GuardDuty有効化直後ではないか
- 対象Protection Planが有効か

## list-findingsでは内容が分からない

`list-findings`はFinding ID一覧を返す。Findingの詳細は`get-findings`で確認する。

## Severityの判断に迷う

確認すること:

- Severity数値
- 対象リソースの重要度
- Resource Role
- Action Type
- Countと継続性
- IAM、S3、RDSなどデータ・認証情報への影響

## サンプルFindingか判断できない

確認すること:

- Title、Description、AdditionalInfo
- Finding作成時刻
- 検証作業の申請・連絡
- 対象リソースが実在するか
- Finding Typeがサンプル作成対象と一致するか

判断できない場合は、実Findingとして慎重に扱い、サンプルと断定しない。

---

## 31. 影響調査が必要な改善候補

Day 8は確認専用であり、次の項目を見つけても即時変更しない。

| 改善候補 | 主な影響範囲 |
|---|---|
| Detector有効化 | 対象リージョン、料金、運用責任 |
| Finding発行頻度変更 | 通知頻度、検知運用 |
| S3 Protection有効化 | S3監視、料金、運用 |
| RDS Protection有効化 | DB監視、料金、対象DB |
| Lambda Protection有効化 | Lambda監視、料金 |
| Malware Protection有効化 | 対象リソース、Service Role、料金 |
| EventBridge Rule追加 | 通知先、自動処理、誤作動 |
| Security Hub連携 | Finding集約、通知、管理責任 |
| 自動隔離処理 | 業務停止、切り戻し、承認 |
| Finding Archive | 対応状況、再表示、監査証跡 |

改善候補を見つけた場合は、対象アカウント、リージョン、影響範囲、料金、通知先、運用責任者、テスト方法、切り戻し方法を整理する。

---

## 32. セキュリティ上の注意点

- FindingにはIPアドレス、ARN、Access Key ID、リソース情報が含まれる場合がある
- Finding JSONやスクリーンショットを公開リポジトリへ保存しない
- Access Key IDをチャットや手順書へ不用意に記載しない
- FindingをArchiveしても原因が解消されるわけではない
- Findingだけで侵害や誤検知を断定しない
- Critical、High、IAM関連、ACTORのFindingは早めに共有する
- リソース隔離や権限停止は業務影響と承認を確認する
- 証跡取得前に対象リソースや設定を変更しない
- サンプルFindingを実Findingとして報告しない
- 実Findingをサンプルと決めつけない

---

## 33. 案件で説明できるポイント

### DetectorとFindingの確認

```text
対象AWSアカウントとリージョンを確認したうえで、
GuardDuty Detectorの存在、Status、Finding発行頻度、
Protection Planの状態を確認した。

未Archive FindingとHigh以上のFindingを優先して確認した。
```

### Finding詳細の読み方

```text
Finding TypeとSeverityだけで判断せず、
対象リソース、Resource Role、Action Type、CreatedAt、
UpdatedAt、Countを確認した。

Resource RoleがACTORの場合は、対象リソースが不審動作を
行っている可能性を考慮して優先度を上げた。
```

### 横展開調査

```text
FindingのActionと対象リソースに応じて、
CloudTrail、VPC Flow Logs、Security Group、
S3、EC2、RDSなどへ横展開して確認する。

Findingは調査開始点であり、関連ログと現在設定を組み合わせて判断する。
```

### 安全な初動

```text
Findingを確認しても、独断でArchive、リソース停止、
Security Group変更、Access Key削除を行わない。

事実、緊急度、影響、追加確認事項を先に共有し、
対応が必要な場合は承認後に別手順で実施する。
```

---

## 34. 資格試験につながるポイント

| 項目 | 覚える内容 |
|---|---|
| GuardDuty | AWS環境の脅威検知サービス |
| Detector | リージョン単位のGuardDutyリソース |
| Finding | GuardDutyの検知結果 |
| Severity | Critical、High、Medium、Low |
| Resource Role | `TARGET`または`ACTOR` |
| Action Type | Network、DNS、API、RDS Loginなど |
| S3 Protection | S3に関する不審活動の検知 |
| RDS Protection | RDSログイン活動の分析 |
| Lambda Protection | Lambdaネットワーク活動の分析 |
| Malware Protection | マルウェア検出 |
| EventBridge | Finding通知や自動処理への連携 |
| Security Hub | 複数のFindingを集約 |
| CloudTrail | AWS API操作の追加調査 |
| VPC Flow Logs | ネットワーク通信の追加調査 |

---

## 35. 要確認事項

実案件で同様の作業を行う場合は、次を確認する。

- GuardDutyの管理アカウント、委任管理者、Member Account構成
- 監視対象AWSアカウントとリージョン
- 有効にすべきProtection Plan
- Critical、High、Medium、Lowごとの対応時間
- Finding一次対応者とエスカレーション先
- Findingを確認する時間帯と当番体制
- EventBridge、SNS、Teams、SIEM、Security Hubとの連携
- サンプルFindingを作成できる検証環境
- Finding ArchiveとFeedbackの運用ルール
- 自動隔離・自動修復の有無
- 証跡保存先、保持期間、マスキング規則
- CloudTrail、Flow Logs、DNS Query Logsの保存・検索方法

不明な項目は合理的に推測して設定変更せず、未確認事項として手順書と報告へ残す。

---

## 36. Day 8完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] GuardDuty Detectorの存在を確認した
- [ ] Detector IDを取得した
- [ ] Detector Statusを確認した
- [ ] Finding Publishing Frequencyを確認した
- [ ] Protection Plan・Featureを確認した
- [ ] 複数リージョンのDetectorを確認した
- [ ] 未Archive Finding ID一覧を確認した
- [ ] High以上のFinding ID一覧を確認した
- [ ] Severity別件数を確認した
- [ ] Finding Type別件数を確認した
- [ ] 調査対象Findingを1件選択した
- [ ] Finding詳細の生JSONを保存した
- [ ] Finding Type、Severity、Titleを確認した
- [ ] 対象リソースとResource Roleを確認した
- [ ] Action Type、CreatedAt、UpdatedAt、Countを確認した
- [ ] 対象リソースの現在状態を確認した
- [ ] 必要に応じてCloudTrailなどへ横展開した
- [ ] EventBridge・通知連携の有無を確認した
- [ ] 証跡ファイルと空ファイルを確認した
- [ ] 一次調査結果と追加確認事項を整理した
- [ ] Teams報告文を作成した
- [ ] 設定変更、Archive、隔離を実施していないことを確認した

## Day 8の完了条件

次を自分の言葉で説明できればDay 8は完了とする。

```text
GuardDutyはリージョン単位のDetectorで検知を管理するため、
最初に対象AWSアカウント、リージョン、Detector Statusを確認する。

未Archive FindingとHigh以上のFindingを優先して確認し、
Finding Type、Severity、対象リソース、Resource Role、
Action Type、CreatedAt、UpdatedAt、Countを読み取る。

Findingは侵害を断定するものではないため、
CloudTrail、VPC Flow Logs、対象サービスの現在設定へ横展開し、
正常作業、既知の検証、要調査、侵害疑いを整理する。

CriticalやHighのFindingは早めに共有する。
ただし、独断でArchive、リソース停止、隔離、権限変更を行わず、
事実、影響、追加確認事項、証跡を報告して初動方針を相談する。
```
