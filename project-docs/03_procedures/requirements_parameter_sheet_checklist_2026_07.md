# 要件別 パラメータシート確認チェックリスト

作成日: 2026-07-16

この資料は、クラウドセキュリティ対応の各要件について、作業手順書を確定する前にパラメータシートで確認すべき内容を整理したチェックリストである。

手順書は監査指摘と改善計画をもとに作成できるが、正式な作業手順として使う前に、実環境のパラメータシート、設計書、既存設定値と突合する必要がある。

## 1. 確認方針

| 観点 | 確認内容 |
| :--- | :--- |
| 対象範囲 | 対象アカウント、対象リージョン、対象環境、対象リソース |
| 既存設定 | 既に同等設定があるか、別方式で実装済みか |
| 命名規則 | Trail名、Log Group名、Alarm名、Metric名、SNS Topic名、EventBridge Rule名 |
| 通知経路 | SNS、メール、Teams、監視基盤、別アカウントEvent bus |
| 証跡 | 作業前後で取得する画面、ログ、通知結果、保存先 |
| 切り戻し | 変更対象、戻す値、削除してよいもの、削除してはいけないもの |
| 承認 | 作業承認、通知テスト承認、本番作業承認、レビュー先 |

## 2. 共通で確認するパラメータシート

| パラメータシート/資料 | 確認する内容 |
| :--- | :--- |
| アカウント一覧 | 対象アカウント、管理アカウント、メンバーアカウント、環境区分 |
| リージョン一覧 | 対象リージョン、除外リージョン、グローバルサービスの扱い |
| CloudTrail設定 | Trail名、Multi-Region、Management Event、Data Event、CloudWatch Logs連携、S3保存先、KMS |
| CloudWatch Logs設定 | Log Group名、保持期間、KMS、Metric Filter、Subscription Filter |
| CloudWatch Alarm設定 | Alarm名、Metric、Threshold、Period、Evaluation、通知Action |
| SNS設定 | Topic名、ARN、Subscription、通知先、用途、共用有無 |
| EventBridge設定 | Rule名、Event Pattern、Target、別アカウント送信、入力変換、状態 |
| Security Hub設定 | 有効化状況、GuardDuty統合、Automation Rule、通知連携 |
| GuardDuty設定 | Detector、Feature、Protection Plan、Finding通知、Archive/Suppression |
| S3設定 | 対象バケット、ログ保存先、Bucket Policy、暗号化、Public Access Block |
| KMS設定 | CMK、Key Policy、Alias、Rotation、CloudTrail/S3/Logsとの紐づき |
| VPC/ネットワーク設定 | VPC、Subnet、Route Table、NACL、Security Group、Gateway、Flow Logs |
| 運用設計 | 一次対応者、エスカレーション先、証跡保存先、レビュー先 |

## 3. 要件別確認チェックリスト

| 要件 | テーマ | パラメータシートで確認すること | 手順書へ反映する内容 |
| :--- | :--- | :--- | :--- |
| A3 | セキュリティアラート監視運用手順 | GuardDuty対象アカウント、対象リージョン、通知先、一次対応者、エスカレーション先、Security Hub連携、既存月次確認資料、運用時間帯 | 受付、確認、判断、エスカレーション、証跡保存、完了判断の手順 |
| A4 | セキュリティアラート運用証跡 | GuardDuty確認記録、Finding調査記録、通知履歴、月次確認記録、証跡保存先、保存期間、レビュー先 | 日次/随時確認記録、個別アラート対応記録、月次確認記録の様式 |
| 3.4 | CloudTrailログ保存先S3のServer Access Logging | CloudTrailログ保存先バケット、Server Access Logging有無、ログ保存先バケット、Prefix、ライフサイクル、暗号化、アクセス権限 | Logging有効化手順、保存先、Prefix、切り戻し、ログ増加影響 |
| 3.5 | CloudTrailログのCMK暗号化 | 対象Trail、現在の暗号化方式、使用予定CMK、Key Policy、CloudTrailサービス許可、Log File Validation、S3保存先 | Trail更新手順、CMK指定、Key Policy確認、切り戻し値 |
| 3.6 | カスタマー管理CMKのローテーション | 対象CMK、Rotation有効/無効、Alias、用途、Key Policy、管理者、削除予定有無 | Rotation有効化確認、3.5に含めるか、単独確認とするか |
| 3.7 | VPC Flow Logs | 対象VPC、対象環境、Flow Logs有無、送信先CloudWatch Logs/S3、Traffic Type、IAM Role、保持期間、KMS | Flow Logs有効化手順、送信先、対象VPC一覧、切り戻し、料金/ログ量影響 |
| 4.1 | 不正なAPI呼び出し監視 | CloudTrail Log Group、Metric Filter名、Metric Name、Namespace、Filter Pattern、Alarm名、Threshold、通知先 | Unauthorized/API失敗検知のMetric FilterとAlarm設定 |
| 4.2 | MFAなしコンソールログイン監視 | ConsoleLoginイベントの記録先、MFA強制有無、Metric Filter名、Alarm名、通知先、不要判定根拠 | MFAUsed=No検知の設定手順、不要判断時の根拠 |
| 4.3 | rootアカウント使用監視 | root利用監視の既存有無、対象アカウント、Metric Filter名、Alarm名、通知先、Severity扱い | root利用1件発報の設定、通知先、対応手順 |
| 4.4 | IAMポリシー変更監視 | 監視対象IAMイベント、既存EventBridge有無、Metric Filter名、Alarm名、通知先、変更管理との突合先 | IAM Policy変更検知、通常変更との切り分け |
| 4.5 | CloudTrail設定変更監視 | CloudTrail変更監視の既存有無、対象Trail、EventBridge/Alarm有無、通知先、StartLogging/StopLogging扱い | CloudTrail変更検知、復旧操作時の通知扱い |
| 4.6 | コンソール認証失敗監視 | ConsoleLogin Failureの監視有無、閾値、短時間複数回判定、通知先、運用対応先 | 認証失敗検知、しきい値、通知後確認手順 |
| 4.7 | CMK無効化/削除予約監視 | KMSイベント監視有無、対象CMK、DisableKey/ScheduleKeyDeletion検知、通知先、鍵管理担当 | CMK無効化・削除予約の1件発報、確認先 |
| 4.8 | S3バケットポリシー変更監視 | 対象バケット範囲、既存EventBridge Rule、別アカウント送信、SNS Topic、Metric Filter/Alarm有無 | EventBridge利用案またはCloudWatch Alarm案、対象バケット限定有無 |
| 4.9 | AWS Config変更監視 | AWS Config有効化状況、Recorder、Delivery Channel、Config Rule、既存通知、対象アカウント | Config設定変更検知、Config未導入時の扱い |
| 4.10 | Security Group変更監視 | 対象VPC/SG、既存通知、監視対象イベント、変更管理先、通知先、閾値 | SG変更検知、変更管理との突合、通知後確認 |
| 4.11 | NACL変更監視 | 対象VPC/NACL、既存通知、監視対象イベント、通信影響確認先、通知先 | NACL変更検知、通信影響確認先 |
| 4.12 | Network Gateway変更監視 | 対象Gateway種別、Internet Gateway、Customer Gateway、NAT Gateway、Transit Gateway、VPN Gatewayの扱い、既存通知 | 正式対象イベント、追加Gatewayを含めるかの判断 |
| 4.13 | Route Table変更監視 | 対象Route Table、既存通知、監視対象イベント、通信経路確認先、変更管理先 | Route Table変更検知、通知後の確認先 |
| 4.14 | VPC変更監視 | VPC、VPC Peering、VPC Endpoint、Subnetを含めるか、既存通知、対象アカウント | VPC変更検知、対象範囲の明確化 |
| 4.15 | AWS Organizations変更監視 | Organizations管理アカウント、CloudTrail記録先、既存通知、対象イベント、通知先 | Organizations変更検知、管理アカウント側確認 |

## 4. 4番台で共通確認する設定値

4番台は同じ構成を横展開するため、以下を先に確定する。

| 項目 | 確認内容 |
| :--- | :--- |
| 対象Log Group | CloudTrail Management Event連携先Log Group |
| Metric Namespace | 現場命名規則に合うNamespace |
| Metric Filter名 | 要件番号と監視対象が分かる名称 |
| Metric Name | 要件番号とイベント種別が分かる名称 |
| Alarm名 | 要件番号、監視対象、環境が分かる名称 |
| Period | 60秒、300秒などの監視周期 |
| Evaluation Periods | 1回検知で発報するか、複数回検知で発報するか |
| Threshold | 1件以上、複数件以上など |
| Treat missing data | 原則notBreaching相当でよいか |
| Alarm Action | 既存SNS Topic、Teams、メール、監視基盤 |
| OK Action | OK通知が必要か |
| Insufficient Data Action | 不足データ通知が必要か |
| EventBridge重複 | 既存EventBridge通知がある場合、新規Alarmを作るか |
| 通知テスト | 実イベントを起こすか、机上/Pattern Testにするか |

## 5. 3番台で共通確認する設定値

| 項目 | 確認内容 |
| :--- | :--- |
| 対象環境 | Prod、OPER、開発、検証など |
| 対象リソース | CloudTrailログ保存先S3、対象CMK、対象VPC |
| 保存先 | S3、CloudWatch Logs、別バケット、Prefix |
| 暗号化 | SSE-S3、SSE-KMS、対象CMK |
| 権限 | Bucket Policy、Key Policy、IAM Role |
| 保持期間 | S3ライフサイクル、CloudWatch Logs Retention |
| 料金影響 | Server Access Logging、Flow Logs、KMSリクエスト |
| 切り戻し値 | 元のLogging、KMS、Flow Logs設定 |

## 6. A3/A4で共通確認する設定値

| 項目 | 確認内容 |
| :--- | :--- |
| GuardDuty管理方式 | 単一アカウント、Organizations、委任管理者 |
| Detector | 対象リージョンごとのDetector有無 |
| Feature/Protection Plan | S3、RDS、Lambda、EKS、Runtime、Malware Protectionなど |
| Finding通知 | EventBridge、SNS、Teams、メール、監視基盤 |
| Security Hub連携 | GuardDuty FindingがSecurity Hubへ集約されるか |
| Archive/Suppression | Archive基準、Suppression Rule、有無 |
| 記録頻度 | 日次、随時、月次 |
| 証跡保存先 | 共有フォルダ、チケット、台帳、監査証跡フォルダ |
| 判断者 | 一次対応者、セキュリティ判断者、業務影響確認者 |
| レビュー先 | リーダー、運用、セキュリティ担当部署、PM |

## 7. パラメータシート確認後に手順書へ反映するもの

| 反映先 | 反映する内容 |
| :--- | :--- |
| 現状調査手順書 | 対象アカウント、対象リージョン、対象リソース、既存設定 |
| 作業実施手順書 | 実際の設定値、画面上で選択する既存リソース名、通知先 |
| 当日作業手順書 | 作業対象、作業順序、証跡取得箇所、切り戻し対象 |
| 切り戻し手順 | 元の設定値、戻す対象、削除してよいリソース |
| 通知テスト手順 | 通知先、テスト方法、受信確認者、証跡保存先 |
| A3/A4手順書 | 一次対応者、判断基準、エスカレーション、記録様式 |

## 8. 未確認のまま作業した場合のリスク

| 未確認項目 | リスク |
| :--- | :--- |
| 対象アカウント/リージョン | 対象外環境に設定し、監査対象を是正できない |
| 既存通知 | 二重通知、通知過多、運用混乱が発生する |
| SNS Topic | 誤った宛先に通知される、または通知されない |
| EventBridge Rule | 既存の別アカウント連携と衝突する |
| KMS Key Policy | CloudTrailやS3が書き込めなくなる |
| S3ログ保存先 | ログが保存できない、ログ量が想定外に増える |
| VPC Flow Logs送信先 | ログが出ない、保持期間や暗号化要件を満たさない |
| 切り戻し値 | 作業前状態へ戻せない |
| 証跡保存先 | 監査説明時に証跡を提示できない |

## 9. 確認依頼文面案

```text
手順書を正式化する前に、パラメータシート上の既存設定値と突合したい。

確認したい主な内容は以下。

・対象アカウント、対象リージョン、対象環境
・CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、EventBridge、SNSの既存設定
・3番台のS3ログ、CMK、VPC Flow Logsの対象リソースと設定値
・A3/A4のGuardDuty、Security Hub、通知経路、運用証跡保存先
・作業時に使用する既存Topic、既存Rule、既存Log Group、既存CMK
・切り戻し時に戻すべき設定値

パラメータシート確認後、手順書内の仮値を実環境の値に置き換える。
```

