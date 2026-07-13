# AWS公式ドキュメント GuardDuty要約

作成日: 2026-07-14

この資料は、AWS公式ドキュメントをもとに、Amazon GuardDutyを現場作業で確認するための要点として整理したものである。

日本語版ドキュメントは機械翻訳の場合がある。設定値や仕様の厳密な確認が必要な場合は、英語版も併せて確認する。

## 1. GuardDutyとは

Amazon GuardDutyは、AWS環境内のデータソースとログを継続的に監視、分析、処理する脅威検出サービスである。

GuardDutyは、脅威インテリジェンス、機械学習、異常検知などを使って、AWS環境内の疑わしいアクティビティや悪意のある可能性があるアクティビティを検出する。

GuardDutyで検出される代表的な脅威:

- 漏洩したAWS認証情報の利用
- EC2やコンテナワークロードでの暗号資産マイニング
- EC2やコンテナワークロードでのマルウェアの可能性
- S3バケットに対するデータ引き出しや破壊の可能性
- RDSやAuroraに対する不審なログインアクティビティ
- EKS、ECS、Fargate、EC2のRuntime上の不審動作
- Lambda関数の不審なネットワークアクティビティ

現場では、GuardDutyを「AWS環境内の脅威検知サービス」として扱う。

## 2. Security Hubとの違い

GuardDutyとSecurity Hubは役割が異なる。

| 項目 | GuardDuty | Security Hub |
| :--- | :--- | :--- |
| 主な役割 | 脅威検知 | 検出結果集約、セキュリティ標準評価 |
| 主な出力 | Finding | Finding、Control、Security Score |
| 入力元 | CloudTrail、VPC Flow Logs相当、DNSログ、S3 Data Events、各保護プランのログなど | GuardDuty、Inspector、Macie、Security Hub Control、外部製品など |
| 現場での見方 | 不審な動作・侵害可能性の確認 | 複数サービスの検出結果と準拠状況の集約 |
| 通知連携 | EventBridge、Security Hub、S3エクスポートなど | EventBridge、自動化ルール、外部連携など |

GuardDutyはFindingを生成する側であり、Security HubはGuardDutyなどのFindingを集約する側である。

## 3. 基本データソース

GuardDutyを有効化すると、基本的な脅威検出のために、関連する基本データソースの取り込みと分析を開始する。

基本データソース:

| データソース | 概要 | 現場での注意 |
| :--- | :--- | :--- |
| CloudTrail Management Event | IAM、S3設定、EC2操作などの管理イベント | CloudTrail証跡調査とは別に、GuardDutyが分析対象として扱う |
| VPC Flow Logs相当 | EC2インスタンス由来のネットワーク通信メタデータ | 要件3.7のVPC Flow Logs有効化とは別観点 |
| DNS Logs | DNSクエリに関する情報 | Route 53 Resolver DNS Query Logsの運用設定とは別にGuardDutyが扱う場合がある |

重要:

- GuardDutyの基本的な脅威検出を使うために、利用者がCloudTrailやVPC Flow Logsを個別に有効化する必要がある、という意味ではない。
- 要件3.7の「VPC Flow Logsを有効化する」は、監査証跡・調査用ログを残すための別要件である。
- GuardDutyで脅威検知できることと、運用上の調査ログが保管されていることは同じではない。

## 4. Detector

Detectorは、GuardDutyが有効なリージョン内でGuardDuty機能を管理する単位である。

現場で確認する項目:

| 項目 | 意味 |
| :--- | :--- |
| Detector ID | GuardDuty Detectorを識別するID |
| Status | `ENABLED` または `DISABLED` |
| Finding publishing frequency | 既存Finding更新の通知頻度 |
| Service role | GuardDutyのサービスリンクロール |
| Created at | Detector作成日時 |
| Updated at | Detector更新日時 |
| Features | GuardDuty保護プランの有効/無効 |

注意:

- Detectorはリージョンごとに存在する。
- GuardDutyが有効なリージョンを確認する。
- 複数アカウント環境では管理者アカウント側で見るべき情報がある。

## 5. Protection Plan / Feature

GuardDutyには、基本的な脅威検出に加えて、用途別の保護プランがある。

| 保護プラン / Feature | 主な内容 | 現場での確認観点 |
| :--- | :--- | :--- |
| S3 Protection | S3 CloudTrail Data Eventsを分析し、S3のデータ引き出しや破壊の可能性を検知 | 対象アカウント・リージョンで有効か |
| EKS Protection | Kubernetes監査ログを分析 | EKS利用有無 |
| Runtime Monitoring | EKS、EC2、ECS/FargateなどのRuntimeイベントを分析 | 対象ワークロードとAgent管理 |
| Malware Protection for EC2 | EC2に関連付くEBSボリュームをスキャン | スキャン対象、IAM、コスト |
| Malware Protection for S3 | 新規アップロードS3オブジェクトのマルウェア検出 | 対象バケット、スキャン範囲 |
| Malware Protection for AWS Backup | Backupリソースのマルウェア検出 | Backup運用との関係 |
| RDS Protection | Aurora / RDS PostgreSQL系のログインアクティビティを分析 | 対象DBエンジン、ログイン監視 |
| Lambda Protection | Lambdaネットワークアクティビティを分析 | Lambda利用有無 |

現場での注意:

- すべてのProtection Planを有効にすればよいわけではない。
- 対象サービスを利用していない場合、無効でも直ちに問題とは限らない。
- 有効化により料金、ログ量、運用、通知量に影響する。
- 無料トライアル終了後も自動で無効にはならない。

## 6. S3 Protection

S3 Protectionは、S3バケットに対するデータ引き出しや破壊などの潜在的なセキュリティリスクを識別する。

特徴:

- S3のCloudTrail Data EventsをGuardDutyが分析する。
- Object-level API操作をもとに、S3リソースへの疑わしいアクセスを検出する。
- S3 Protectionを有効にするために、CloudTrail側でS3 Data Eventを明示的に有効化する必要はない。

今回の案件での注意:

- 要件4.8のS3 Bucket Policy変更監視はCloudTrail Management Eventの監視である。
- S3 ProtectionはS3 Object操作やデータリスクの脅威検知である。
- 両者は目的が異なる。

## 7. RDS Protection

RDS Protectionは、対応するAuroraやRDS for PostgreSQL系のログインアクティビティを分析し、不審なログイン動作を検出する。

確認観点:

- 対象DBエンジンを利用しているか
- RDS Protectionが有効か
- 対象アカウント・リージョンで利用中か
- RDSログイン活動の検出結果が出ているか

公式ドキュメントでは、RDS Protectionは追加インフラストラクチャが不要で、データベースインスタンスのパフォーマンスに影響しないよう設計されていると説明されている。

## 8. Lambda Protection

Lambda Protectionは、Lambda関数のネットワークアクティビティを分析し、潜在的な脅威を検出する。

確認観点:

- Lambdaを利用しているか
- Lambda Protectionが有効か
- Lambda Network Activity Monitoringの対象か
- Lambda@Edgeは対象外である点に注意する
- コスト増加の可能性を確認する

Lambda Protectionは、Lambda関数の呼び出し時に生成されるネットワーク関連ログを分析する。

## 9. Finding

GuardDuty Findingは、AWSアカウント、ワークロード、データ内で検出された潜在的なセキュリティ問題を表す。

Findingで確認する項目:

| 項目 | 意味 |
| :--- | :--- |
| Finding ID | 検出結果の識別子 |
| Finding Type | 脅威の種類 |
| Title | 検出内容の概要 |
| Severity | 重要度 |
| Resource | 対象リソース |
| Account | 対象アカウント |
| Region | 対象リージョン |
| First seen | 初回検出時刻 |
| Last seen | 最終検出時刻 |
| Count | 同一Findingの発生回数 |
| Service archived | アーカイブ済みか |
| Description | 詳細説明 |
| Remediation | 推奨対応 |

Findingは、GuardDutyコンソール、AWS CLI、APIで確認できる。Security Hub連携が有効な場合はSecurity Hub側にも取り込まれる。

## 10. Finding Type

GuardDuty Finding Typeは、潜在的なセキュリティ問題を分類する文字列である。

基本形式:

```text
ThreatPurpose:ResourceTypeAffected/ThreatFamilyName.DetectionMechanism!Artifact
```

例:

```text
UnauthorizedAccess:EC2/SSHBruteForce
Recon:EC2/PortProbeUnprotectedPort
CryptoCurrency:EC2/BitcoinTool.B!DNS
```

主なThreatPurpose:

| ThreatPurpose | 意味 |
| :--- | :--- |
| Backdoor | C&Cサーバー通信など、バックドアの可能性 |
| Behavior | 通常のベースラインから外れた動作 |
| CredentialAccess | 認証情報窃取の可能性 |
| Cryptocurrency | 暗号資産関連の不正利用 |
| DefenseEvasion | 検出回避の可能性 |
| Discovery | 偵察活動 |
| Execution | 悪意あるコード実行や探索 |
| Exfiltration | データ持ち出し |
| Impact | 破壊、妨害、操作 |
| InitialAccess | 初期アクセス |
| Pentest | ペネトレーションテスト類似活動 |
| Persistence | 永続化 |
| Policy | 推奨セキュリティ方針に反する動作 |
| PrivilegeEscalation | 権限昇格 |
| Recon | 偵察 |
| Stealth | 匿名化や隠蔽 |
| Trojan | トロイの木馬的活動 |
| UnauthorizedAccess | 不正アクセス |

## 11. Severity

GuardDuty Findingには、1.0〜10.0の重大度値が割り当てられる。

| 重大度 | 値の範囲 | 意味 |
| :--- | :--- | :--- |
| Critical | 9.0 - 10.0 | 攻撃シーケンスが進行中または最近発生した可能性。リソース侵害の可能性が高い |
| High | 7.0 - 8.9 | 対象リソースが侵害され、不正目的で活発に利用されている可能性 |
| Medium | 4.0 - 6.9 | 通常と異なる不審な活動。リソース侵害の可能性を調査する |
| Low | 1.0 - 3.9 | 低リスクだが確認対象になり得る活動 |

現場での対応優先度:

- Critical / Highは即時確認対象
- Mediumは業務予定、変更作業、既知活動と突合する
- Lowは定期確認、抑制ルール、運用上の扱いを確認する

## 12. Finding Aggregation

GuardDutyは、同一のセキュリティ問題に関連する新たなアクティビティを検出した場合、新しいFindingを毎回作るのではなく、元のFindingを更新することがある。

例:

- 同じEC2インスタンスへのSSHブルートフォース試行は、同一Finding IDに集約され、Countが増える場合がある。
- 別インスタンスを対象にした同種の活動は、新しいFinding IDになる場合がある。

現場での注意:

- Countが増えているFindingは、継続的に発生している可能性がある。
- Latest detailsは最新の発生内容に更新される。
- 個々の通信やAPI操作の詳細は、CloudTrailやVPC Flow Logsなどの元ログで確認する。

## 13. Suppression Rule

Suppression Ruleは、条件に一致する新しいFindingを自動的にアーカイブするルールである。

用途:

- 既知の正当な活動によるノイズ削減
- 誤検知として確認済みのFinding抑制
- 対応不要のFindingを通常一覧から除外

注意:

- 抑制されたFindingはSecurity Hub、S3エクスポート、Detective、EventBridgeへ送信されない。
- GuardDutyはFinding自体を生成するが、自動的にArchivedとして扱う。
- Archived FindingはGuardDutyで90日間表示できる。
- マルチアカウント環境ではGuardDuty管理者のみがSuppression Ruleを作成できる。
- 広すぎるSuppression Ruleは、Extended Threat Detectionの攻撃シーケンス検出に影響する可能性がある。

現場では、Suppression Ruleを作る前に、理由、対象条件、承認者、見直し期限を残す。

## 14. EventBridge連携

GuardDutyはFindingをEventBridgeへイベントとして送信する。

代表的な流れ:

```text
GuardDuty Finding
  -> EventBridge Rule
  -> SNS / Lambda / SQS / Step Functions / チケット管理 / SIEMなど
```

公式ドキュメントでは、新規Findingの通知はほぼリアルタイムで送信される。既存Findingの後続発生については、一定間隔で集約され、通知頻度を設定できる。

現場で確認する項目:

| 項目 | 確認理由 |
| :--- | :--- |
| EventBridge Rule | GuardDuty Finding通知があるか |
| Event Pattern | Severity、Finding Type、Resourceなどで絞っているか |
| Target | SNS、Lambda、別アカウントEvent Busなど |
| 通知頻度 | 後続発生通知の間隔 |
| マルチアカウント | 管理者アカウント側のRuleか |
| 自動対応 | LambdaやSSM Automationが実行されないか |

A3/A4では、GuardDutyのFindingをどう受け取り、誰が確認し、どう記録するかが重要である。

## 15. Security Hub連携

GuardDutyはSecurity Hubと統合できる。

Security Hub連携が有効な場合:

- GuardDuty FindingがSecurity Hub側に取り込まれる
- ASFF形式に正規化される
- Security HubのFinding一覧、Insight、EventBridge連携で扱える
- 他サービスのFindingと合わせて優先度付けできる

確認事項:

- Security Hubが有効か
- GuardDuty統合が有効か
- Security Hub側でFindingが見えているか
- Security HubのAutomation Ruleで抑制・更新されていないか
- Security Hub EventBridge RuleとGuardDuty EventBridge Ruleが重複していないか

## 16. S3エクスポート

GuardDutyは生成されたFindingを90日間保持する。

長期保管が必要な場合、FindingをS3バケットへエクスポートできる。

S3エクスポートで必要なもの:

- エクスポート先S3バケット
- 検出結果データを暗号化するKMS Key
- S3 Bucket Policy
- KMS Key Policy
- GuardDuty Detector ID
- リージョンごとのエクスポート設定

注意:

- エクスポート設定はリージョン単位である。
- GuardDuty管理者アカウントで設定すると、関連付けられたメンバーアカウントのFindingも同じ場所にエクスポートされる。
- Archived Findingはデフォルトではエクスポートされない。
- KMS KeyとS3 bucketのリージョン整合を確認する。
- S3エクスポートはA4の運用証跡保存と関係する可能性がある。

## 17. マルチアカウント管理

複数AWSアカウント環境では、GuardDuty管理者アカウントとメンバーアカウントの構成を確認する。

管理方式:

| 方式 | 概要 | 現場での確認観点 |
| :--- | :--- | :--- |
| AWS Organizations統合 | 組織の委任GuardDuty管理者で一元管理 | 金融系・複数アカウントでは自然 |
| 招待による管理 | 管理者アカウントがメンバーを招待 | Organizations未統合の場合 |

確認ポイント:

- GuardDuty管理者アカウント
- メンバーアカウント一覧
- 自動有効化設定
- Protection Planの有効化範囲
- Finding閲覧権限
- Suppression Rule作成権限
- EventBridge通知が管理者側かメンバー側か

## 18. 料金と無料トライアル

GuardDutyは、初回有効化時に30日間の無料トライアルが提供される。

注意点:

- 無料トライアル終了後もGuardDutyやProtection Planは自動で無効にならない。
- GuardDuty本体、S3 Protection、RDS Protection、Lambda Protectionなど、Protection Planごとに料金影響がある。
- 使用状況画面で推定コストや使用量を確認する。
- Protection Planを有効にする前に、対象サービスの利用有無と必要性を確認する。

## 19. 今回の案件での確認観点

A3/A4では、GuardDutyに関する運用手順と証跡が重要である。

確認するとよい項目:

| 項目 | 理由 |
| :--- | :--- |
| GuardDutyが有効か | 脅威検知の前提 |
| 対象リージョン | GuardDutyはリージョン単位で有効化されるため |
| Detector ID | Finding確認、S3エクスポート、API確認に必要 |
| 管理者アカウント | マルチアカウント環境での確認主体 |
| メンバーアカウント | Prod / OPER / 管理系アカウントが対象か確認 |
| Protection Plan | S3、RDS、Lambda、Runtimeなどの有効化状況 |
| Finding一覧 | 未対応、High以上、Archivedの有無 |
| Suppression Rule | 誤検知や既知Findingの扱い |
| EventBridge Rule | 通知、Teams、メール、チケット起票の有無 |
| Security Hub連携 | Finding集約や二重通知の確認 |
| S3エクスポート | 90日超の証跡保管が必要か |
| 運用手順 | 誰が、いつ、何を確認し、どう記録するか |

## 20. Webコンソールでの確認観点

GuardDutyコンソールで見る場所:

- 概要
- 検出結果
- 保護プラン
- 使用状況
- 抑制ルール
- リスト
- 設定
- アカウント

確認順序:

```text
GuardDutyが有効か確認
  -> Detector IDとStatusを確認
  -> 管理者 / メンバーアカウントを確認
  -> Protection Planを確認
  -> Finding一覧を確認
  -> High以上と未対応Findingを確認
  -> Suppression Ruleを確認
  -> EventBridge通知経路を確認
  -> Security Hub連携を確認
  -> S3エクスポート要否を確認
```

## 21. 現場での確認チェックリスト

| No. | 確認項目 | 確認理由 |
| :--- | :--- | :--- |
| 1 | GuardDuty有効化状況 | 脅威検知の前提を確認する |
| 2 | Detector ID | Finding確認やエクスポート設定で必要 |
| 3 | Finding publishing frequency | 後続Finding通知の頻度を確認する |
| 4 | 管理者アカウント | 設定変更やSuppression Rule作成主体を確認する |
| 5 | メンバーアカウント | 対象環境が含まれているか確認する |
| 6 | Protection Plan | 対象サービスの検知範囲を確認する |
| 7 | Finding一覧 | 未対応アラートを確認する |
| 8 | Severity | 優先度を判断する |
| 9 | Archived Finding | 確認済みや抑制済みのFindingを確認する |
| 10 | Suppression Rule | 自動アーカイブの条件を確認する |
| 11 | EventBridge Rule | 通知や自動対応を確認する |
| 12 | Security Hub統合 | Finding集約と重複通知を確認する |
| 13 | S3エクスポート | 長期保管と証跡化を確認する |
| 14 | 使用状況 | 料金影響を確認する |

## 22. よくある誤解

| 誤解 | 正しい理解 |
| :--- | :--- |
| GuardDutyはCloudTrailの代わりになる | GuardDutyは脅威検知。CloudTrailは操作証跡 |
| GuardDutyが有効ならVPC Flow Logs要件は不要 | GuardDutyの分析と、調査用Flow Logs保管は別要件 |
| Findingがないなら安全 | GuardDutyが検知していないだけで、全リスクを否定するものではない |
| Sample Findingは実インシデント | Sample Findingは表示・運用確認用の架空Finding |
| Suppression Ruleは削除と同じ | 抑制条件に一致したFindingをArchived扱いにする |
| Archived Findingは重要ではない | 確認済みや抑制済みであり、理由と承認が重要 |
| Protection Planは全部有効が正解 | 対象サービス、料金、運用に応じて判断する |
| EventBridge通知があれば運用証跡は不要 | 通知後の確認、判断、対応、完了記録が必要 |

## 23. 公式ドキュメントURL

### 日本語

| 分類 | URL |
| :--- | :--- |
| GuardDutyとは | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/what-is-guardduty.html |
| 基本データソース | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_data-sources.html |
| 複数アカウント | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_accounts.html |
| Findingの理解と生成 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings.html |
| Findingの管理 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/findings_management.html |
| Finding形式 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_finding-format.html |
| Finding重大度 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings-severity.html |
| Finding集約 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/finding-aggregation.html |
| Suppression Rule | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/findings_suppression-rule.html |
| EventBridge連携 | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings_eventbridge.html |
| S3エクスポート | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_exportfindings.html |
| S3 Protection | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/s3-protection.html |
| RDS Protection | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/rds-protection.html |
| Lambda Protection | https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/lambda-protection.html |
| 料金 | https://aws.amazon.com/jp/guardduty/pricing/ |

### English

| 分類 | URL |
| :--- | :--- |
| What is GuardDuty | https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html |
| Foundational data sources | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_data-sources.html |
| Multiple accounts | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_accounts.html |
| Findings | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings.html |
| Finding format | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-format.html |
| Finding severity | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings-severity.html |
| Suppression rules | https://docs.aws.amazon.com/guardduty/latest/ug/findings_suppression-rule.html |
| EventBridge integration | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings_eventbridge.html |
| Export findings to S3 | https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_exportfindings.html |
