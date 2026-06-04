# 05 GuardDuty CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、Amazon GuardDutyをAWS CLIで確認、調査、検証するためのリファレンスである。

対象は、銀行系システムのように、AWS環境の脅威検知、セキュリティ対策状況確認、Finding調査、証跡取得、関係者報告が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- GuardDuty Detector確認
- GuardDuty有効化状態確認
- Finding一覧取得
- Finding詳細確認
- Finding重要度の読み方
- Finding件数集計
- サンプルFinding作成
- Finding調査の進め方
- EC2 / IAM Access Key / S3 / RDS / Lambda Findingの確認観点
- CloudTrail、VPC、EC2、S3、RDS、Lambdaへの横展開調査
- Archive / Feedbackの扱い
- 証跡取得
- Teams報告例

CloudTrailでの操作証跡確認は、以下を参照する。

```text
03_cloudtrail_cli_reference.md
```

CloudWatch Logs / Alarm連携は、以下を参照する。

```text
04_cloudwatch_cli_reference.md
```

## 2. GuardDutyで見るもの

GuardDutyは、AWS環境の脅威検知サービスである。

CloudTrail、VPC Flow Logs、DNS Logs、S3 Data Events、EKS、RDS、Lambdaなど、対象となるデータソースや保護機能をもとに、不審な動作をFindingとして出力する。

案件での使い方は、主に以下である。

| 用途 | 内容 |
| :--- | :--- |
| セキュリティ対策状況確認 | GuardDutyが有効か、Detectorがあるか確認する |
| Finding確認 | 未対応Findingや高重要度Findingを確認する |
| 影響調査 | Findingの対象リソース、通信先、実行者を確認する |
| 横展開調査 | CloudTrail、VPC Flow Logs、EC2、IAM、S3などを追加確認する |
| 報告 | Finding概要、影響、対応方針、証跡を整理する |
| 検証 | サンプルFindingで検知・通知・手順を確認する |

重要:

```text
GuardDuty Findingは「断定」ではなく「調査すべきセキュリティイベント」である。
Findingの重要度、対象リソース、Action、通信先、CloudTrail履歴を確認し、
正当な作業か、侵害可能性があるかを判断する。
```

## 3. GuardDutyの主な用語

| 用語 | 意味 |
| :--- | :--- |
| Detector | GuardDutyの検知を行うリージョン単位のリソース |
| Finding | GuardDutyが検知したセキュリティイベント |
| Finding Type | `UnauthorizedAccess:EC2/TorClient` などの検知タイプ |
| Severity | Findingの重要度。CLIでは数値、ConsoleではCritical/High/Medium/Low |
| Resource | Findingの対象になったAWSリソース |
| Resource Role | 対象リソースが `TARGET` か `ACTOR` かを示す |
| Action | 検知されたアクション。通信、API、DNS、RDSログインなど |
| Service | Detector ID、Action、Archived、Count、Evidenceなどを含む詳細情報 |
| Sample Finding | 検証用に生成できるサンプルFinding |

## 4. 作業前の共通変数

### 4.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

PROJECT_NAME="nobu-iac-lab"
```

Detector IDはリージョンごとに取得する。

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text)

echo "$DETECTOR_ID"
```

注意:

- GuardDutyはリージョン単位でDetectorを持つ
- `ap-northeast-1` でDetectorがあっても、他リージョンにDetectorがあるとは限らない
- Organizations環境では管理アカウント、委任管理者、メンバーアカウントの関係を確認する

### 4.2 証跡ディレクトリ

```bash
WORK_NAME="guardduty_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 4.3 Caller Identity保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

## 5. GuardDuty確認のクイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | Detector存在 | Detector IDが返る | `list-detectors` |
| 2 | Detector状態 | `ENABLED` | `get-detector` |
| 3 | Finding Publishing Frequency | 要件どおり | `get-detector` |
| 4 | 未Archive Finding | 件数を確認 | `list-findings` |
| 5 | 高重要度Finding | Critical/Highを優先確認 | `list-findings` |
| 6 | Finding詳細 | 対象Resource、Action、Evidence確認 | `get-findings` |
| 7 | Finding統計 | SeverityやType別件数 | `get-findings-statistics` |
| 8 | サンプルFinding | 検知手順検証に使用 | `create-sample-findings` |
| 9 | 横展開調査 | CloudTrail、VPC、EC2、S3など | 関連CLI |
| 10 | 対応記録 | Archive / Feedbackの扱い | `archive-findings`、`update-findings-feedback` |

## 6. Detector確認

### 6.1 list-detectors

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

証跡保存:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/01_list_detectors.json"
```

確認ポイント:

- Detector IDが返る
- 空の場合、そのリージョンではGuardDutyが有効化されていない可能性がある
- GuardDutyはリージョン単位なので、調査対象リージョンを必ず確認する

### 6.2 Detector ID取得

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text)

if [ "$DETECTOR_ID" = "None" ] || [ -z "$DETECTOR_ID" ]; then
  echo "GuardDuty Detector not found in $REGION"
  exit 1
fi

echo "Detector ID: $DETECTOR_ID"
```

### 6.3 get-detector

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

証跡保存:

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/02_get_detector.json"
```

確認ポイント:

- `Status` が `ENABLED`
- `FindingPublishingFrequency`
- `ServiceRole`
- `CreatedAt`
- `UpdatedAt`
- `DataSources` または `Features`

注意:

- 利用できるData SourceやFeatureはリージョンやアカウント状態で差がある
- Organizations環境では、委任管理者側での設定も確認する

## 7. GuardDuty有効化

ラボでGuardDutyを有効化する例である。

```bash
aws guardduty create-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --enable \
  --finding-publishing-frequency SIX_HOURS \
  --tags Project="$PROJECT_NAME",Environment=learning \
  --output json \
  > "$EVIDENCE_DIR/change/03_create_detector.json"
```

確認:

```bash
aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

注意:

- GuardDutyは課金対象である
- 本番では勝手に有効化せず、承認、対象アカウント、対象リージョン、通知設計を確認する
- Organizations環境では、個別アカウントで勝手に有効化するのではなく、管理方式を確認する
- 有効化直後はFindingがすぐ出るとは限らない

## 8. 複数リージョンのDetector確認

GuardDutyはリージョン単位なので、重要リージョンを横断確認する。

```bash
for target_region in ap-northeast-1 us-east-1 us-west-2; do
  echo "=== $target_region ==="
  aws guardduty list-detectors \
    --profile "$PROFILE" \
    --region "$target_region" \
    --query 'DetectorIds' \
    --output text
done
```

証跡保存例:

```bash
for target_region in ap-northeast-1 us-east-1 us-west-2; do
  aws guardduty list-detectors \
    --profile "$PROFILE" \
    --region "$target_region" \
    --output json \
    > "$EVIDENCE_DIR/before/guardduty_detectors_${target_region}.json"
done
```

確認ポイント:

- 対象システムが使うリージョンで有効か
- グローバルサービスイベントやIAM関連Findingをどのリージョンで扱うか
- 現場の監視対象リージョン一覧と一致しているか

## 9. Finding一覧確認

### 9.1 未Archive Finding一覧

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output table
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
  > "$EVIDENCE_DIR/before/04_list_active_findings.json"
```

注意:

- `list-findings` はFinding IDの一覧を返す
- 詳細を見るには `get-findings` を使う
- Findingは同じパターンの活動が同じIDに集約されることがある

### 9.2 Finding IDを取得

```bash
FINDING_IDS=$(aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --max-results 10 \
  --query 'FindingIds' \
  --output text)

echo "$FINDING_IDS"
```

### 9.3 高重要度Findingを先に見る

CLI/APIではSeverityは数値で扱う。

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/before/05_list_high_findings.json"
```

確認ポイント:

- `severity >= 9.0` はCritical相当
- `severity >= 7.0` はHigh以上
- 高重要度は先に詳細確認し、対象リソースの隔離や認証情報ローテーション要否を判断する

## 10. Finding詳細確認

### 10.1 get-findings

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids $FINDING_IDS \
  --output json \
  > "$EVIDENCE_DIR/investigation/06_get_findings.json"
```

一覧として見やすく表示する。

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids $FINDING_IDS \
  --query 'Findings[*].{Id:Id,Type:Type,Severity:Severity,Title:Title,AccountId:AccountId,Region:Region,CreatedAt:CreatedAt,UpdatedAt:UpdatedAt,ResourceType:Resource.ResourceType,ResourceRole:Service.ResourceRole,ActionType:Service.Action.ActionType,Archived:Service.Archived,Count:Service.Count}' \
  --output table
```

確認ポイント:

- `Id`
- `Type`
- `Severity`
- `Title`
- `Description`
- `AccountId`
- `Region`
- `CreatedAt`
- `UpdatedAt`
- `Resource`
- `Service.Action`
- `Service.Evidence`
- `Service.Count`
- `Service.Archived`

注意:

- GuardDuty Consoleではローカル時刻表示、CLI/JSONではUTC表示になることがある
- 手順書や報告ではJST/UTCを明記する

### 10.2 1件だけ詳細確認

```bash
FINDING_ID="<finding-id>"

aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/finding_${FINDING_ID}.json"
```

## 11. Finding重要度の読み方

GuardDutyのSeverityは1.0から10.0の数値で表される。

| 数値範囲 | Console表示 | 優先度 | 対応方針 |
| :--- | :--- | :--- | :--- |
| 9.0 - 10.0 | Critical | 最優先 | 攻撃進行中または直近発生の可能性。即時トリアージ |
| 7.0 - 8.9 | High | 高 | 侵害済みまたは不正利用中の可能性。即時対応 |
| 4.0 - 6.9 | Medium | 中 | 不審活動。早めに調査し、正当性を確認 |
| 1.0 - 3.9 | Low | 低 | 試行や偵察の可能性。記録し傾向を見る |

案件での優先順位:

1. Critical / High
2. Mediumで対象が本番重要リソース
3. Mediumで継続発生しているもの
4. Lowでも同一IPや同一リソースに集中しているもの

注意:

- Lowでも無視しない
- `Count` が増えているFindingは継続的な活動の可能性がある
- MediumでもIAM認証情報や本番DBが関係する場合は優先度を上げる

## 12. Finding統計

### 12.1 Severity別件数

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-statistic-types COUNT_BY_SEVERITY \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output json \
  > "$EVIDENCE_DIR/before/07_findings_statistics_by_severity.json"
```

### 12.2 Finding Type別件数

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --group-by FINDING_TYPE \
  --order-by DESC \
  --max-results 50 \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output table
```

### 12.3 対象リソース別件数

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --group-by RESOURCE \
  --order-by DESC \
  --max-results 50 \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --output table
```

確認ポイント:

- 高重要度Findingが何件あるか
- 同じFinding Typeが多発していないか
- 同じリソースに集中していないか
- Archive済みを除外しているか

## 13. Finding条件検索

### 13.1 Finding Typeで検索

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":["UnauthorizedAccess:EC2/TorClient"]}}}' \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/08_findings_by_type.json"
```

### 13.2 リソースIDで検索

```bash
INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"

aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"resource.instanceDetails.instanceId\":{\"Eq\":[\"$INSTANCE_ID\"]}}}" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/09_findings_by_instance.json"
```

### 13.3 S3バケット名で検索

```bash
BUCKET_NAME="nobu-terraform-iac-lab-upload"

aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria "{\"Criterion\":{\"resource.s3BucketDetails.name\":{\"Eq\":[\"$BUCKET_NAME\"]}}}" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/10_findings_by_s3_bucket.json"
```

### 13.4 未ArchiveかつMedium以上

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"severity":{"Gte":4},"service.archived":{"Eq":["false"]}}}' \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/11_medium_or_higher_active_findings.json"
```

注意:

- Finding Criteriaのフィールド名はFindingのJSON構造に合わせる
- 条件が効かない場合は、まず `get-findings` のJSONで実際のフィールド名を確認する

## 14. サンプルFinding

サンプルFindingは、検知手順、通知設定、調査手順、証跡取得を練習するために使う。

### 14.1 サンプルFinding作成

```bash
aws guardduty create-sample-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-types UnauthorizedAccess:EC2/TorClient UnauthorizedAccess:EC2/TorRelay
```

注意:

- `finding-types` を指定しない場合、対応する全サンプルFindingが生成される可能性がある
- 検証では対象Finding Typeを絞る
- サンプルFindingは実際の侵害ではないが、報告や証跡では「サンプル」と明記する

### 14.2 サンプルFinding確認

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":["UnauthorizedAccess:EC2/TorClient","UnauthorizedAccess:EC2/TorRelay"]}}}' \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/after/12_list_sample_findings.json"
```

詳細確認:

```bash
SAMPLE_FINDING_IDS=$(aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":["UnauthorizedAccess:EC2/TorClient","UnauthorizedAccess:EC2/TorRelay"]}}}' \
  --max-results 10 \
  --query 'FindingIds' \
  --output text)

aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids $SAMPLE_FINDING_IDS \
  --output json \
  > "$EVIDENCE_DIR/after/13_get_sample_findings.json"
```

### 14.3 サンプルFindingで確認すること

| 確認対象 | 確認内容 |
| :--- | :--- |
| GuardDuty Console | Findingが表示される |
| AWS CLI | `list-findings` / `get-findings` で取得できる |
| CloudWatch / EventBridge | 通知や連携がある場合、イベントが届く |
| 手順書 | 調査フローに沿って確認できる |
| 報告 | 「サンプルFinding」として説明できる |

## 15. Finding詳細の読み方

### 15.1 共通で見る項目

| JSON項目 | 見る内容 |
| :--- | :--- |
| `Id` | Finding ID |
| `Type` | Finding Type |
| `Severity` | 重要度 |
| `Title` | 概要 |
| `Description` | 詳細説明 |
| `AccountId` | 発生アカウント |
| `Region` | 発生リージョン |
| `CreatedAt` | 初回検知時刻 |
| `UpdatedAt` | 最終更新時刻 |
| `Resource.ResourceType` | 対象リソース種別 |
| `Service.ResourceRole` | `TARGET` または `ACTOR` |
| `Service.Action.ActionType` | 検知アクション種別 |
| `Service.Count` | 集約回数 |
| `Service.Archived` | Archive状態 |
| `Service.Evidence` | 脅威情報などの根拠 |

### 15.2 Resource Role

| Resource Role | 意味 |
| :--- | :--- |
| `TARGET` | 自分のAWSリソースが攻撃や不審動作の対象 |
| `ACTOR` | 自分のAWSリソースが不審動作を行っている側 |

例:

- `TARGET`: 外部からEC2へポートスキャンされた
- `ACTOR`: EC2から外部の疑わしいIPへ通信している

### 15.3 Action Type

| Action Type | 例 | 主な確認先 |
| :--- | :--- | :--- |
| `NETWORK_CONNECTION` | 不審IPへの通信 | VPC Flow Logs、Security Group、EC2 |
| `PORT_PROBE` | ポートスキャン | Security Group、NACL、ALB |
| `DNS_REQUEST` | 悪性ドメイン問い合わせ | DNS Logs、EC2、プロセス |
| `AWS_API_CALL` | 不審なAWS API操作 | CloudTrail、IAM、Access Key |
| `RDS_LOGIN_ATTEMPT` | 不審なDBログイン試行 | RDS、DBユーザー、Security Group |

## 16. Finding調査の基本フロー

1. Finding ID、Type、Severity、Titleを確認する
2. Severityで初動優先度を決める
3. 対象リソースを特定する
4. Resource Roleが `TARGET` か `ACTOR` か確認する
5. Action Typeを確認する
6. 通信先IP、ドメイン、ポート、API名、DBユーザーなどを確認する
7. CloudTrail、VPC Flow Logs、EC2、IAM、S3、RDSなどで横展開調査する
8. 正当な作業、既知の検証、誤検知、侵害可能性を切り分ける
9. 必要に応じて隔離、権限停止、キー無効化、SG閉塞、パスワード変更を提案する
10. 証跡と判断理由をまとめて報告する

重要:

```text
Findingを見てすぐにリソース削除や通信遮断をしない。
本番影響、承認、切り戻し、業務影響を確認した上で対応する。
ただしCritical/Highで侵害可能性が高い場合は、初動対応を急ぐ。
```

## 17. EC2 Finding調査

### 17.1 EC2情報を確認

FindingからInstance IDを取得できる場合:

```bash
INSTANCE_ID="<instance-id>"

aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SubnetId:SubnetId,VpcId:VpcId,SecurityGroups:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn,Tags:Tags}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/14_ec2_instance_${INSTANCE_ID}.json"
```

### 17.2 Security Group確認

```bash
SG_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].SecurityGroups[].GroupId' \
  --output text)

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SG_IDS \
  --output json \
  > "$EVIDENCE_DIR/investigation/15_security_groups_${INSTANCE_ID}.json"
```

確認ポイント:

- Public IPがあるか
- 0.0.0.0/0で不要なポートが開いていないか
- SSH/RDPが直接公開されていないか
- Instance Profileが強すぎないか
- ALB経由のみの想定なのに直接公開されていないか

### 17.3 VPC Flow Logs確認

VPC Flow LogsがCloudWatch Logsへ出ている場合:

```bash
FLOW_LOG_GROUP_NAME="<vpc-flow-logs-log-group>"

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$FLOW_LOG_GROUP_NAME" \
  --filter-pattern "$INSTANCE_ID" \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/16_vpc_flow_logs_${INSTANCE_ID}.json"
```

注意:

- Flow LogsにはInstance IDではなくENI IDやIPアドレスで出ることが多い
- Findingの通信先IP、通信元IP、ポート、時間帯を使って検索する

## 18. IAM Access Key Finding調査

Access KeyやIAM Credentialに関するFindingは、認証情報漏えいの可能性があるため優先度が高い。

### 18.1 FindingからAccess Key情報を確認

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[*].Resource.AccessKeyDetails' \
  --output json \
  > "$EVIDENCE_DIR/investigation/17_access_key_details_${FINDING_ID}.json"
```

### 18.2 CloudTrailで該当Access Keyの操作を確認

```bash
ACCESS_KEY_ID="<access-key-id>"

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="$ACCESS_KEY_ID" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/18_cloudtrail_access_key_${ACCESS_KEY_ID}.json"
```

確認ポイント:

- Access Keyの所有者
- 直近のAPI操作
- 操作元IPアドレス
- 普段と異なるリージョンやサービス利用
- 権限昇格、認証情報取得、S3操作、Security Group変更

初動候補:

- 対象Access Keyの無効化
- IAMユーザー/Roleの権限確認
- パスワードやMFA状態確認
- CloudTrailで横展開調査

注意:

- Access Key無効化は業務アプリに影響する可能性がある
- 本番では承認と影響確認を行う

## 19. S3 Finding調査

### 19.1 S3 Bucket情報確認

```bash
BUCKET_NAME="<bucket-name>"

aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/19_s3_public_access_block_${BUCKET_NAME}.json"

aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/20_s3_policy_status_${BUCKET_NAME}.json"
```

### 19.2 Bucket Policy確認

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --query 'Policy' \
  --output text \
  > "$EVIDENCE_DIR/investigation/21_s3_bucket_policy_${BUCKET_NAME}.json"
```

### 19.3 CloudTrailでS3設定変更を確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/22_cloudtrail_s3_${BUCKET_NAME}.json"
```

確認ポイント:

- Public Access Block
- Bucket Policy
- ACL / Object Ownership
- 暗号化
- Versioning
- 不審な `PutBucketPolicy` や `DeleteBucketPolicy`
- 外部アカウント、`Principal: "*"`、広すぎるAction

## 20. RDS Finding調査

RDS ProtectionのFindingでは、DBログイン試行やDBユーザーが関係することがある。

### 20.1 RDS情報確認

```bash
DB_INSTANCE_ID="<db-instance-id>"

aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,PubliclyAccessible:PubliclyAccessible,VpcSecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId,Endpoint:Endpoint.Address,DBSubnetGroup:DBSubnetGroup.DBSubnetGroupName}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/23_rds_${DB_INSTANCE_ID}.json"
```

確認ポイント:

- PubliclyAccessibleが想定どおりか
- Security Groupで接続元が限定されているか
- 不審なDBユーザーや接続元がないか
- アプリケーションの通常接続か
- CloudTrailでRDS設定変更がないか

## 21. Lambda Finding調査

### 21.1 Lambda情報確認

```bash
FUNCTION_NAME="<function-name>"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/24_lambda_config_${FUNCTION_NAME}.json"
```

確認ポイント:

- 実行Role
- VPC設定
- Environment Variablesに秘密情報がないか
- 不審な更新履歴
- CloudTrailの `UpdateFunctionCode`、`UpdateFunctionConfiguration`

CloudTrail確認:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$FUNCTION_NAME" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/25_cloudtrail_lambda_${FUNCTION_NAME}.json"
```

## 22. Network Finding調査

GuardDutyのNetwork系Findingでは、通信先IP、通信元IP、Port、Protocol、Directionを見る。

### 22.1 Findingから通信情報を取り出す

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --query 'Findings[*].Service.Action' \
  --output json \
  > "$EVIDENCE_DIR/investigation/26_finding_action_${FINDING_ID}.json"
```

確認ポイント:

- `ActionType`
- `ConnectionDirection`
- `LocalIpDetails`
- `RemoteIpDetails`
- `RemotePortDetails`
- `Protocol`
- `Blocked`
- `DnsRequestAction.Domain`

### 22.2 Security Group / NACL / Route確認

通信方向に応じて、以下を確認する。

| 確認対象 | 見ること |
| :--- | :--- |
| Security Group | 該当Portが許可されているか |
| NACL | Subnet単位で許可/拒否されているか |
| Route Table | Internet/NAT/VPN/Direct Connect経路 |
| VPC Flow Logs | 実通信のACCEPT/REJECT |
| ALB/NLB | 外部公開経路 |
| DNS | 不審ドメイン問い合わせ |

## 23. FindingのArchiveとFeedback

### 23.1 Archive

調査済みで対応不要、またはサンプルFindingを片付ける場合にArchiveする。

```bash
aws guardduty archive-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID"
```

注意:

- ArchiveはFindingを消すわけではない
- 本番ではArchive理由を残す
- 未調査Findingを安易にArchiveしない

### 23.2 Feedback

Findingに対して有用/不要のFeedbackを設定する。

```bash
aws guardduty update-findings-feedback \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids "$FINDING_ID" \
  --feedback USEFUL \
  --comments "Confirmed and investigated. Activity was expected."
```

Feedback例:

| Feedback | 意味 |
| :--- | :--- |
| `USEFUL` | 有用なFindingだった |
| `NOT_USEFUL` | 誤検知や期待しないFindingだった |

注意:

- Feedbackは調査判断に関わるため、現場ルールに従う
- コメントには秘密情報や個人情報を書かない

## 24. EventBridge / CloudWatch連携の確認

GuardDuty FindingsはEventBridge経由で通知や自動対応につなげられる。

### 24.1 EventBridge Rule確認

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name-prefix "$PROJECT_NAME" \
  --output table
```

GuardDutyイベント用Ruleを検索する例:

```bash
aws events list-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Rules[?contains(EventPattern, `GuardDuty`) || contains(Name, `guardduty`)].{Name:Name,State:State,Arn:Arn,EventPattern:EventPattern}' \
  --output table
```

注意:

- EventBridge RuleのEventPatternに `aws.guardduty` が含まれるか確認する
- 通知先SNS、Lambda、Step FunctionsなどのTargetを確認する

### 24.2 Targets確認

```bash
RULE_NAME="<eventbridge-rule-name>"

aws events list-targets-by-rule \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule "$RULE_NAME" \
  --output table
```

確認ポイント:

- SNS Topic
- Lambda
- Step Functions
- Chatbot連携先
- Targetの権限

## 25. GuardDuty調査時に保存する証跡

| タイミング | 証跡 | コマンド例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `sts get-caller-identity` |
| 変更前 | Detector一覧 | `guardduty list-detectors` |
| 変更前 | Detector詳細 | `guardduty get-detector` |
| 調査 | Finding ID一覧 | `guardduty list-findings` |
| 調査 | Finding詳細 | `guardduty get-findings` |
| 調査 | Severity統計 | `guardduty get-findings-statistics` |
| 調査 | 対象EC2 | `ec2 describe-instances` |
| 調査 | 対象SG | `ec2 describe-security-groups` |
| 調査 | 対象S3 | `s3api get-bucket-policy-status` |
| 調査 | 対象RDS | `rds describe-db-instances` |
| 調査 | CloudTrail履歴 | `cloudtrail lookup-events` |
| 調査 | CloudWatch Logs | `logs filter-log-events` |
| 変更後 | Archive/Feedback結果 | `get-findings` |
| 画面証跡 | Console画面 | Finding詳細、対象リソース、関連ログ |

## 26. 作業手順書に書く項目

GuardDuty関連作業の手順書には、以下を含める。

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | Detector確認、Finding調査、サンプルFinding検証など |
| 対象 | Account、Region、Detector ID、Finding ID |
| 変更前状態 | Detector状態、Finding件数、重要度 |
| 実施内容 | Finding詳細確認、横展開調査、Archive/Feedback |
| 影響範囲 | 監視、通知、運用、対象リソース |
| 調査観点 | Severity、Resource、Action、通信先、CloudTrail |
| 変更後確認 | Finding状態、Archive状態、通知状態 |
| 切り戻し | Archive解除は別操作検討、Detector無効化は原則しない |
| 証跡 | CLI JSON、Consoleスクリーンショット |
| 報告 | Finding概要、判断、対応案、残課題 |

## 27. よくあるエラーと確認ポイント

### 27.1 Detectorが見つからない

確認ポイント:

- Regionが正しいか
- GuardDutyが有効化されているか
- Organizations管理アカウント側で管理されていないか
- IAM権限が足りているか

### 27.2 Findingが出ない

確認ポイント:

- Detectorが `ENABLED` か
- 対象リージョンで発生したイベントか
- FindingがArchive済みではないか
- 検知まで時間がかかっていないか
- サンプルFindingで検証しているか

### 27.3 list-findingsは出るが詳細が分からない

確認ポイント:

- `list-findings` はID一覧だけ返す
- `get-findings` で詳細を取得する
- `finding-ids` に正しいFinding IDを渡しているか

### 27.4 高重要度Findingの判断に迷う

確認ポイント:

- Severity
- Resource Role
- Action Type
- Count
- UpdatedAt
- 対象リソースの重要度
- CloudTrailで正当作業か確認
- 業務影響が大きい場合は関係者へ早めに共有

### 27.5 サンプルFindingと実Findingが混ざる

確認ポイント:

- TitleやDescriptionにSampleの記載がないか
- `additionalInfo` にSampleを示す情報がないか
- 作成時刻が検証時間と一致するか
- 報告ではサンプルFindingであることを明記する

## 28. 案件で説明できるポイント

このGuardDuty作業は、案件では次のように説明できる。

```text
GuardDutyのDetectorが有効であることを確認し、
未ArchiveのFinding一覧と重要度別件数をCLIで取得しました。
Finding詳細では、対象リソース、Severity、Action Type、通信先、
Resource Role、Count、CreatedAt/UpdatedAtを確認し、
CloudTrailやEC2/S3/RDSなど関連サービスへ横展開して調査する流れを整理しました。
サンプルFindingを使って、検知確認、証跡取得、報告手順も検証できます。
```

## 29. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| GuardDuty | 脅威検知サービス |
| Detector | リージョン単位のGuardDutyリソース |
| Finding | 検知結果 |
| Severity | Critical/High/Medium/Low |
| CloudTrail連携 | AWS API操作の調査 |
| VPC Flow Logs | ネットワーク通信の調査 |
| DNS Logs | 不審ドメイン問い合わせ |
| EventBridge | Finding通知や自動対応 |
| Security Hub | Finding集約 |
| IAM | Access Key関連Findingの調査 |

## 30. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

Region:
  <region>

Detector ID:
  <detector-id>

Detector Status:
  ENABLED / DISABLED / 未作成

Finding ID:
  <finding-id>

Finding Type:
  <type>

Severity:
  <numeric> / Critical / High / Medium / Low

Title:
  <title>

対象リソース:
  <resource-type> / <resource-id>

Resource Role:
  TARGET / ACTOR

Action Type:
  NETWORK_CONNECTION / PORT_PROBE / DNS_REQUEST / AWS_API_CALL / RDS_LOGIN_ATTEMPT

通信先 / 操作内容:
  <ip/domain/port/api/db-user>

初回検知:
  <created-at>

最終更新:
  <updated-at>

Count:
  <count>

CloudTrail確認:
  実施済み / 未実施 / 対象外

VPC Flow Logs確認:
  実施済み / 未実施 / 対象外

判断:
  正常作業 / サンプル / 要調査 / 侵害疑い

対応方針:
  <対応案>

証跡:
  <evidence path>

備考:
  <調査メモ>
```

## 31. Teams報告例

### 31.1 Detector確認完了

```text
GuardDutyのDetector設定を確認しました。
対象アカウント <account-id> / Region <region> ではDetectorが存在し、
Statusは <ENABLED> です。
未Archive Findingの件数と重要度別件数を取得し、証跡として保存しました。
```

### 31.2 Finding一次調査

```text
GuardDuty Finding <finding-id> の一次調査を実施しました。
Finding Typeは <type>、Severityは <severity>、対象リソースは <resource> です。
Action Typeは <action-type> で、通信先/操作内容は <summary> です。
CloudTrailおよび対象リソース設定を確認し、現時点の判断は <判断> です。
```

### 31.3 高重要度Finding共有

```text
GuardDutyでHigh以上のFindingを確認しました。
対象リソースは <resource>、Finding Typeは <type> です。
侵害可能性を否定できないため、対象リソースの状態、権限、通信ログ、
CloudTrail履歴を優先して確認します。
必要に応じて、通信遮断や認証情報ローテーションの要否を相談します。
```

### 31.4 サンプルFinding検証

```text
GuardDutyのサンプルFindingを作成し、CLIおよびConsoleで検知確認を行いました。
今回確認したFindingは検証用サンプルであり、実際の侵害ではありません。
検知後の確認手順、証跡取得、報告フォーマットを確認済みです。
```

## 32. 公式ドキュメント

- [list-detectors - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/list-detectors.html)
- [get-detector - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/get-detector.html)
- [create-detector - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/create-detector.html)
- [list-findings - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/list-findings.html)
- [get-findings - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/get-findings.html)
- [get-findings-statistics - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/get-findings-statistics.html)
- [create-sample-findings - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/create-sample-findings.html)
- [archive-findings - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/archive-findings.html)
- [update-findings-feedback - AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/guardduty/update-findings-feedback.html)
- [Severity levels of GuardDuty findings](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings-severity.html)
- [Finding details - Amazon GuardDuty](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings-summary.html)
- [Filtering findings in GuardDuty](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_filter-findings.html)
- [GuardDuty finding types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-active.html)

