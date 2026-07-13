# AWS公式ドキュメント Security Hub要約

作成日: 2026-07-14

この資料は、AWS公式ドキュメントをもとに、AWS Security Hubを現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. Security Hubとは

AWS Security Hubは、AWS環境のセキュリティ状態をまとめて確認し、セキュリティ標準やベストプラクティスに照らして評価するためのサービスである。

公式ドキュメントでは、現在は `AWS Security Hub CSPM` という表記が使われている。CSPMはCloud Security Posture Managementの略であり、クラウド環境の設定状態、セキュリティ標準への準拠状況、検出結果を管理する考え方である。

Security Hubで扱う主な情報:

- セキュリティ標準
- セキュリティコントロール
- セキュリティチェック
- 検出結果
- セキュリティスコア
- GuardDuty、Inspector、Macieなど他サービスからの検出結果
- サードパーティー製品からの検出結果
- 自動化ルール
- EventBridge連携

現場では、Security Hubを「AWSアカウント全体のセキュリティ検出結果と準拠状況を集約して見る場所」として扱う。

## 2. GuardDutyとの違い

Security HubとGuardDutyは役割が異なる。

| 項目 | Security Hub | GuardDuty |
| :--- | :--- | :--- |
| 主な役割 | セキュリティ検出結果と準拠状況の集約・評価 | 脅威検知 |
| 主な出力 | Findings、Controls、Security score | Findings |
| 入力元 | Security Hub自身のコントロール、GuardDuty、Inspector、Macie、外部製品など | CloudTrail、VPC Flow Logs相当、DNSログ、S3 Data Eventsなど |
| 現場での見方 | 全体のセキュリティ状態、標準準拠、検出結果の集約 | 不審な操作や脅威の検知 |
| 通知連携 | EventBridge、自動化ルール、外部連携 | EventBridge、Security Hub連携 |

GuardDutyは脅威検知サービスであり、Security HubはGuardDutyなどの検出結果を集約して管理できるサービスである。

今回のA3/A4ではGuardDuty運用が中心だが、Security Hubが有効であれば、GuardDuty FindingがSecurity Hub側にも集約されている可能性がある。

## 3. 主要概念

| 用語 | 意味 | 現場での確認観点 |
| :--- | :--- | :--- |
| Finding | セキュリティチェックや脅威検知の結果 | 未対応、重要度、対象リソース |
| ASFF | AWS Security Finding Format | Findingの標準形式 |
| Security Standard | セキュリティ標準 | FSBP、CIS、PCI DSS、NISTなど |
| Control | 標準内の個別チェック項目 | 有効/無効、合格/不合格 |
| Security Check | リソースに対する評価実行 | PASSED / FAILEDなど |
| Security Score | 有効コントロールに対する合格割合 | 全体傾向の確認 |
| Insight | Findingの集約ビュー | 重要な問題の把握 |
| Workflow Status | Findingの調査状態 | NEW、NOTIFIED、SUPPRESSED、RESOLVED |
| Record State | Findingのレコード状態 | ACTIVE、ARCHIVED |
| Automation Rule | Findingを自動更新・抑制するルール | 誤検知抑制、重要度変更 |
| Custom Action | 選択したFindingをEventBridgeへ送る仕組み | 手動起点の対応連携 |

## 4. Security Standard

Security Standardは、規制フレームワーク、業界ベストプラクティス、社内ポリシーなどに基づく要件のまとまりである。

代表例:

- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark
- PCI DSS
- NIST系標準

現場での確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| 有効な標準 | どの基準で評価されているか |
| 無効な標準 | 監査対象外としてよいか |
| 標準ごとのSecurity Score | どの標準の不合格が多いか |
| 対象アカウント | 管理者アカウントとメンバーアカウントの範囲 |
| 対象リージョン | リージョンごとの有効化状況 |

注意:

- Security Hubは、有効化後に生成されたFindingのみを統合する。
- Security Hubを有効化する前に発生したFindingを遡って取り込むわけではない。
- リージョンごとに有効化状況を確認する必要がある。

## 5. Control

Controlは、Security Standard内の個別チェック項目である。

Controlを有効にすると、Security Hubはセキュリティチェックを実行し、結果としてFindingを生成する。Controlを無効にすると、そのControlに対するチェックは停止し、Findingは生成されなくなる。

Controlで確認する項目:

| 項目 | 確認内容 |
| :--- | :--- |
| Control ID | 例: `S3.8`, `CloudTrail.1`, `IAM.6`など |
| Title | Controlの概要 |
| Severity | Critical / High / Medium / Low / Informational |
| Status | 有効 / 無効 |
| Compliance Status | PASSED / FAILED / WARNING / NOT_AVAILABLE |
| Failed resources | 不合格リソース |
| Remediation | 推奨対応 |
| Disabled reason | 無効化理由 |

現場での注意点:

- Controlのタイトルや説明は変更される可能性があるため、自動化やフィルタではControl IDを使う。
- 管理者アカウントでは、メンバーアカウント全体のControl状態が見える。
- クロスリージョン集約がある場合、ホームリージョンに複数リージョンのControl状態が反映される。

## 6. Finding

Findingは、セキュリティチェックまたはセキュリティ関連検知の観測可能なレコードである。

Findingの主な発生元:

- Security HubのControlチェック
- GuardDuty
- Inspector
- Macie
- サードパーティー製品
- カスタム統合

Security Hubは、複数ソースのFindingをASFFに正規化して扱う。

Findingで確認する項目:

| 項目 | 意味 |
| :--- | :--- |
| Title | 検出内容の概要 |
| Severity | 重要度 |
| Resource | 対象リソース |
| Account | 対象アカウント |
| Region | 対象リージョン |
| CreatedAt | 作成時刻 |
| UpdatedAt | 更新時刻 |
| Product | 生成元サービスまたは製品 |
| Workflow Status | 調査状態 |
| Record State | Active / Archived |
| Compliance Status | Control Findingの場合の準拠状態 |
| Remediation | 推奨対応 |

## 7. Workflow StatusとRecord State

Security HubのFindingでは、調査状態とレコード状態を分けて考える。

Workflow Status:

| 値 | 意味 |
| :--- | :--- |
| `NEW` | 新規Finding |
| `NOTIFIED` | リソース所有者などに通知済み |
| `SUPPRESSED` | 対応不要、抑制対象 |
| `RESOLVED` | 確認または修正済み |

Record State:

| 値 | 意味 |
| :--- | :--- |
| `ACTIVE` | 有効なFinding |
| `ARCHIVED` | アーカイブ済みFinding |

注意:

- `ARCHIVED` は削除ではない。
- コンソールのFinding一覧では、デフォルトでArchived Findingが除外される場合がある。
- Active Findingは、更新がない場合90日で削除される。
- Archived Findingは、更新がない場合30日で削除される。
- 長期保管が必要な場合は、EventBridgeなどでS3や外部基盤へエクスポートする設計を検討する。

## 8. AWS Configとの関係

Security Hubは、多くのControlチェックでAWS Configのサービスリンクルールを使用する。

そのため、Security HubのControl結果を正しく生成するには、AWS Configで対象リソースを記録していることが重要である。

現場での確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| AWS Config有効化 | Security Hub Control評価の前提になる場合がある |
| Configuration Recorder | 対象リソースを記録しているか |
| Recording Scope | 全リソースか、特定リソースか |
| 対象リージョン | Security Hub有効リージョンと整合するか |
| Delivery Channel | Configスナップショット保存先 |

Security Hubの画面だけで不合格理由が分からない場合、AWS Configの記録対象とリソース履歴も確認する。

## 9. 管理者アカウントとメンバーアカウント

複数アカウント環境では、Security Hub管理者アカウントとメンバーアカウントの構成を確認する。

管理方式:

| 方式 | 概要 | 現場での確認観点 |
| :--- | :--- | :--- |
| AWS Organizations統合 | 組織の委任管理者で一元管理 | 金融系・複数アカウントではこちらが自然 |
| 招待による手動管理 | 管理者がメンバーを招待 | 小規模またはOrganizations未統合の場合 |

Organizations統合では、委任管理者アカウントがSecurity Hub管理者となり、メンバーアカウントを管理する。

現場での確認ポイント:

- Security Hub管理者アカウント
- Organizations管理アカウント
- 委任管理者
- メンバーアカウント一覧
- 中央設定を使用しているか
- アカウントが一元管理型かセルフマネージド型か
- 各アカウント・各リージョンの有効化状況

## 10. 中央設定

中央設定は、Security Hub管理者が複数アカウント・複数リージョンのSecurity Hub設定をまとめて管理する仕組みである。

中央設定で管理できるもの:

- Security Hubを有効にするか
- どのセキュリティ標準を有効にするか
- どのControlを有効にするか
- アカウントやOUごとの設定ポリシー

現場での意味:

- アカウントごとの設定ずれを減らせる
- 監査対象アカウントの有効化漏れを防げる
- 変更する場合は、個別アカウントではなく管理者アカウント側での確認が必要になる

注意:

- 一元管理型アカウントは委任管理者側で設定する。
- セルフマネージド型アカウントは自身で設定する。
- 作業者がメンバーアカウントだけを見ている場合、設定変更できない可能性がある。

## 11. クロスリージョン集約

Security Hubでは、複数リージョンのFinding、Insight、Control compliance status、Security Scoreをホームリージョンへ集約できる。

公式ドキュメントでは、以前の「集約リージョン」という用語が「ホームリージョン」と呼ばれるようになったと説明されている。ただし、一部APIでは古い用語が残る。

現場での確認ポイント:

| 項目 | 確認内容 |
| :--- | :--- |
| ホームリージョン | 集約データを確認するリージョン |
| リンクされたリージョン | 集約対象リージョン |
| 集約対象 | Findings、Insights、Control status、Security Score |
| 管理者アカウント | メンバーアカウントの集約可否 |
| リージョン有効化 | Security Hubが各リージョンで有効か |

注意:

- Security Hubは、有効化されていないリージョンからデータを集約しない。
- クロスリージョン集約設定だけで、リンク先リージョンのSecurity Hubが自動的に有効になるわけではない。
- ホームリージョンで見る結果は、リンクされたリージョンのFindingを含む可能性がある。

## 12. 統合

Security Hubは、AWSサービスやサードパーティー製品からFindingを取り込める。

代表的なAWS統合:

- GuardDuty
- Inspector
- Macie
- IAM Access Analyzer
- Firewall Manager

現場での確認ポイント:

| 項目 | 確認理由 |
| :--- | :--- |
| 有効な統合 | どのサービスのFindingが入っているか |
| 無効な統合 | 監査対象として不足していないか |
| GuardDuty統合 | A3/A4の運用証跡と関係する |
| Inspector統合 | 脆弱性管理と関係する |
| Macie統合 | S3機密情報検知と関係する |
| サードパーティー統合 | 既存SOC、SIEM、監視基盤と関係する |

Security Hubは、有効化後に生成されたFindingのみを受信・統合する。過去に生成されたFindingを遡って取り込むわけではない。

## 13. 自動化ルールとEventBridge

Security Hubには、Findingの自動更新や外部連携の機能がある。

主な自動化:

| 種類 | 概要 | 現場での注意 |
| :--- | :--- | :--- |
| Automation Rule | 条件に一致したFindingの重要度、Workflow Status、メモなどを更新する | 誤ってFindingを抑制していないか確認 |
| EventBridge Rule | Finding発生やCustom Actionを契機に外部処理を実行する | 通知、自動修復、チケット起票の有無を確認 |
| Custom Action | 選択したFindingをEventBridgeへ送る | 手動対応フローと関係 |

公式ドキュメントでは、Automation RuleはEventBridge Ruleより前に適用される。つまり、FindingがEventBridgeに渡る前に、Automation Ruleで更新された状態になる。

現場での確認ポイント:

- Automation Ruleがあるか
- `SUPPRESSED`に自動更新している条件があるか
- Severityを自動変更しているか
- EventBridge Ruleで通知やチケット起票をしているか
- LambdaやSSM Automationで自動修復していないか
- 自動化の対象Control IDやFinding Typeが妥当か

## 14. EventBridgeとの関係

Security HubはEventBridgeと連携し、Findingを外部通知や自動対応へつなげられる。

代表的な流れ:

```text
Security Hub Finding
  -> EventBridge Rule
  -> SNS / Lambda / SQS / Step Functions / チケット管理 / SIEMなど
```

確認するEventBridge Event Patternの観点:

- `source = aws.securityhub`
- FindingのSeverity
- FindingのWorkflow Status
- FindingのRecord State
- Product名
- Control ID
- Resource Type
- Account
- Region

通知や自動修復がすでに存在する場合、CloudWatch AlarmやGuardDuty通知と重複する可能性がある。

## 15. CloudTrailとの関係

Security Hub APIの操作はCloudTrailに記録される。

確認対象になりやすい操作:

- Security Hub有効化・無効化
- Standard有効化・無効化
- Control有効化・無効化
- Finding更新
- Automation Rule作成・変更・削除
- 管理者アカウントやメンバーアカウント関連操作

監査観点では、Security Hub自体の設定変更がCloudTrailで追跡できるかも確認対象になる。

## 16. 料金と無料トライアル

Security Hubを初めて有効化すると、30日間の無料トライアルに自動登録される。

注意点:

- 無料トライアル中でも、Security Hubが連携する他サービスの料金は発生し得る。
- AWS Config関連の利用が関係する。
- 使用状況はSecurity Hubの設定画面または使用状況画面で確認できる。
- クロスリージョン集約のデータ複製自体では追加料金は発生しないと公式ドキュメントで説明されている。

現場では、有効化前に対象アカウント、対象リージョン、標準、Control範囲を確認する。

## 17. 今回の案件での確認観点

今回のクラウドセキュリティ対応では、Security Hubは正式資料の主役ではないが、A3/A4、GuardDuty、EventBridge、通知設定、証跡運用と関係する可能性がある。

確認するとよい項目:

| 項目 | 理由 |
| :--- | :--- |
| Security Hubが有効か | GuardDuty Findingや統合結果を集約している可能性がある |
| 対象リージョン | Security Hubはリージョンごとに有効化されるため |
| 管理者アカウント | Organizations配下では委任管理者で管理される可能性がある |
| メンバーアカウント | Prod / OPER / 管理系アカウントが対象か確認するため |
| クロスリージョン集約 | ホームリージョンだけ見ればよいか判断するため |
| GuardDuty統合 | A3/A4の運用証跡と関係するため |
| Automation Rule | Findingが自動抑制・更新されていないか確認するため |
| EventBridge Rule | 通知・自動対応・チケット起票があるか確認するため |
| Security Standards | 監査対象の標準が有効か確認するため |
| Failed Controls | 改善対象が他にもないか確認するため |

## 18. Webコンソールでの確認観点

Security Hubコンソールで見る場所:

- 概要
- 検出結果
- セキュリティ標準
- コントロール
- インサイト
- 自動化
- 統合
- 設定
- 使用状況

確認順序:

```text
Security Hubが有効か確認
  -> 管理者アカウント / メンバーアカウントを確認
  -> ホームリージョン / リンクリージョンを確認
  -> 有効な標準を確認
  -> 失敗しているControlを確認
  -> GuardDutyなど統合を確認
  -> Automation Ruleを確認
  -> EventBridge連携を確認
  -> FindingsのWorkflow StatusとRecord Stateを確認
```

## 19. 現場での確認チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | Security Hub有効化状況 | 対象アカウント・リージョンで利用中か確認する |
| 2 | 管理者アカウント | 誰が設定変更できるか確認する |
| 3 | メンバーアカウント | 対象環境が含まれているか確認する |
| 4 | 中央設定 | 個別アカウントで変更してよいか判断する |
| 5 | クロスリージョン集約 | どのリージョンで確認すべきか判断する |
| 6 | 有効なSecurity Standard | 評価対象の標準を確認する |
| 7 | Failed Control | 追加の是正対象がないか確認する |
| 8 | GuardDuty統合 | A3/A4の検知・証跡運用と関係する |
| 9 | Automation Rule | 自動抑制や重要度変更の有無を確認する |
| 10 | EventBridge Rule | 通知・自動対応・チケット連携を確認する |
| 11 | Archived Finding | 確認済みとして除外されているFindingを把握する |
| 12 | Usage | 有効化範囲と料金影響を確認する |

## 20. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| Security HubはGuardDutyと同じ | GuardDutyは脅威検知、Security HubはFinding集約と標準評価 |
| Security Hubを有効にすれば過去Findingも見える | 有効化前のFindingは遡って統合されない |
| Security Hubだけ見ればすべての証跡が分かる | CloudTrail、CloudWatch Logs、GuardDuty、Configなどの確認も必要 |
| Failed Controlはすべて即修正が必要 | 業務要件、例外承認、対象外理由を確認する |
| Archivedは削除済み | Archivedは確認済み・非表示扱いであり削除ではない |
| Security Scoreが高ければ安全 | Scoreは有効Controlに対する評価であり、全リスクを表すものではない |
| Automation Ruleは通知だけ | Findingを抑制・更新するため、見え方に影響する |

## 21. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| Security Hub CSPMとは | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/what-is-securityhub.html |
| 概念と用語 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-concepts.html |
| 有効化 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-settingup.html |
| 管理者アカウントとメンバーアカウント | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-accounts.html |
| クロスリージョン集約 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/finding-aggregation.html |
| セキュリティ標準 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/standards-view-manage.html |
| セキュリティコントロール | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/controls-view-manage.html |
| 検出結果 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-findings.html |
| 統合 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-findings-providers.html |
| 自動化 | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/automations.html |
| CloudTrailによるAPIログ | https://docs.aws.amazon.com/ja_jp/securityhub/latest/userguide/securityhub-ct.html |
| 料金 | https://aws.amazon.com/jp/security-hub/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| What is Security Hub CSPM | https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html |
| Concepts and terms | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-concepts.html |
| Enable Security Hub CSPM | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-settingup.html |
| Administrator and member accounts | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-accounts.html |
| Cross-Region aggregation | https://docs.aws.amazon.com/securityhub/latest/userguide/finding-aggregation.html |
| Security standards | https://docs.aws.amazon.com/securityhub/latest/userguide/standards-view-manage.html |
| Security controls | https://docs.aws.amazon.com/securityhub/latest/userguide/controls-view-manage.html |
| Findings | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings.html |
| Integrations | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings-providers.html |
| Automations | https://docs.aws.amazon.com/securityhub/latest/userguide/automations.html |
