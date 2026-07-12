# 要件別 必要情報・確認事項一覧

作成日: 2026-07-08

この資料は、監査指摘対応を進める前に、関係者へ確認するべき情報を要件番号別に整理したものである。

最初に共有された評価シート由来のテキスト情報を正とし、その内容をもとに確認事項を整理する。
公開リポジトリで扱うことを想定し、顧客名、案件名、会社名、具体的な環境名、AWSアカウントID、S3バケット名、VPC ID、個人名、内部資料の正式名称は記載しない。

## 1. 使い方

この資料は、以下の場面で使用する。

- 作業計画を決める前の関係者確認
- 現状調査時に必要な資料・権限の洗い出し
- 設計方針を決める前の確認漏れ防止
- 要件ごとの作業範囲、通知範囲、テスト方法の確認
- 手順書やレビュー資料へ転記するための下書き

## 2. 前提

| 項目 | 前提 |
|---|---|
| 正とする情報 | 最初に共有された評価シート由来のテキスト情報 |
| 対象要件 | A3、A4、3.4、3.5、3.6、3.7、4.1〜4.15 |
| 主な対応方針 | CloudTrail、CloudWatch Logs、Metric Filter、CloudWatch Alarm、通知先を中心に監視を整備する |
| EventBridgeの扱い | 元要件の必須方式ではなく、既存監視・代替通知経路の確認観点として扱う |
| 文書化方針 | 固有名を避け、匿名化した表現にする |

## 3. まず共通で確認すること

| No | 確認事項 | 確認理由 |
|---|---|---|
| 1 | 対象AWSアカウントはどれか | 調査・変更対象を誤らないため |
| 2 | 対象環境はどこまでか | 本番、運用、開発、検証の範囲を確定するため |
| 3 | 対象リージョンはどこか | CloudTrail、CloudWatch、SNS、VPC Flow Logsの確認先を決めるため |
| 4 | Organizations配下か | Organization TrailやOrganizations変更監視の扱いに影響するため |
| 5 | 既存資料の所在はどこか | 設計根拠と監査指摘の前提を確認するため |
| 6 | AWS CLIを利用してよいか | 設定値をJSONで保存し、変更前後の証跡を残すため |
| 7 | 参照系権限はどこまで付与されているか | 現状調査が可能か判断するため |
| 8 | 変更系権限は誰が持つか | 作業者、承認者、実施者を分ける必要があるため |
| 9 | 通知先は既存か新規か | Alarm ActionやSNS設計に影響するため |
| 10 | 通知後の一次対応者は誰か | A3/A4の運用手順に必要なため |
| 11 | 対応記録はどこに保存するか | A4の運用証跡に必要なため |
| 12 | テストはどの環境で実施できるか | 本番で実イベントを発生させられない場合があるため |
| 13 | スクリーンショット、CLI出力、通知メールなど、必要な証跡形式は何か | 提出物の粒度を合わせるため |

## 4. 参照エビデンスの匿名化表現

元テキストに記載されていた参照エビデンスは、公開用には以下のように置き換える。

| 元情報の種類 | この資料での表現 |
|---|---|
| セキュリティ設計に関する資料 | セキュリティ設計資料 |
| 運用設計に関する資料 | 運用設計資料 |
| 既存チャットや確認履歴 | 既存確認履歴 |
| 不正アクセス分析手順 | 不正アクセス分析手順 |
| Athena等の確認クエリ | ログ分析クエリ |
| 月次確認や集計資料 | 月次確認資料 |
| CloudTrail、CloudWatch、S3等の設定証跡 | クラウドログ設定エビデンス |
| 追加指摘対応に関する資料 | 追加指摘対応資料 |

## 5. 要件別サマリ

| 要件番号 | 確認テーマ | 主な確認先 |
|---|---|---|
| A3 | セキュリティアラート監視手順書 | 運用設計資料、既存手順、GuardDuty運用 |
| A4 | 日々の監視運用証跡 | 月次確認資料、対応記録、保存先 |
| 3.4 | CloudTrailログ保存先S3のServer Access Logging | CloudTrail、S3、ログ保存先 |
| 3.5 | CloudTrailログのKMS CMK暗号化 | CloudTrail、S3、KMS |
| 3.6 | カスタマー管理KMSキーのローテーション | KMS、Key Policy、鍵運用 |
| 3.7 | VPC Flow Logs | VPC、Flow Logs、保存先、費用 |
| 4.1 | 不正API呼び出し監視 | CloudTrail、CloudWatch Logs、Metric Filter、Alarm |
| 4.2 | MFAなしConsoleLogin監視 | CloudTrail、IAM認証方針、Metric Filter、Alarm |
| 4.3 | rootアカウント使用監視 | CloudTrail、root運用ルール、Alarm |
| 4.4 | IAMポリシー変更監視 | CloudTrail、IAM運用、Alarm |
| 4.5 | CloudTrail設定変更監視 | CloudTrail、CloudWatch Logs、Alarm |
| 4.6 | Console認証失敗監視 | CloudTrail、認証失敗しきい値、Alarm |
| 4.7 | KMSキー無効化・削除予約監視 | CloudTrail、KMS、Alarm |
| 4.8 | S3バケットポリシー変更監視 | CloudTrail、S3、Metric Filter、Alarm |
| 4.9 | AWS Config設定変更監視 | CloudTrail、AWS Config、Alarm |
| 4.10 | Security Group変更監視 | CloudTrail、EC2/VPC、Alarm |
| 4.11 | NACL変更監視 | CloudTrail、VPC、Alarm |
| 4.12 | Network Gateway変更監視 | CloudTrail、VPC、Alarm |
| 4.13 | Route Table変更監視 | CloudTrail、VPC、Alarm |
| 4.14 | VPC変更監視 | CloudTrail、VPC、Alarm |
| 4.15 | AWS Organizations変更監視 | Organizations、管理アカウント、CloudTrail |

## 6. 要件別確認事項

### A3 セキュリティアラート監視の運用手順書

元テキスト上の指摘:

- セキュリティアラートのモニタリング手順が文書化されていない。

必要な情報:

- 既存の運用手順書の有無
- GuardDutyやその他セキュリティアラートの確認方法
- アラートの重要度分類
- 異常判定基準
- 一次対応者、二次対応者、エスカレーション先
- 対応記録の保存先

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 既存のセキュリティアラート確認手順書はあるか | 新規作成か既存改訂か |
| 2 | GuardDutyだけを対象にするか、CloudWatch Alarm等も含めるか | 手順書の対象範囲 |
| 3 | 日次確認、即時確認、月次確認のどれを標準運用にするか | 運用頻度と記録様式 |
| 4 | 重要度ごとの対応基準はあるか | 異常判定基準 |
| 5 | エスカレーション先と連絡手段は何か | 手順書の連絡フロー |

必要な資料・権限:

- 運用設計資料
- セキュリティ設計資料
- 既存確認履歴
- GuardDuty参照権限
- CloudWatch Alarm参照権限

### A4 セキュリティアラート監視が日々の運用で実施されていること

元テキスト上の指摘:

- セキュリティイベント調査に関するエビデンスが不足している。
- A3の手順書整備と合わせて対応する。

必要な情報:

- 現在の確認頻度
- 対応記録の有無
- 月次確認資料の保存先
- アラート発生時の記録項目
- 記録の承認者または確認者

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 日々の運用証跡として何を残す必要があるか | 記録テンプレート |
| 2 | 月次確認資料はA4の証跡として使えるか | 既存資料流用可否 |
| 3 | アラートがない日も確認記録が必要か | 日次チェック表の要否 |
| 4 | 対応記録の保存場所はどこか | 運用手順書の記載内容 |
| 5 | 誰が記録を確認・承認するか | レビュー運用 |

必要な資料・権限:

- 月次確認資料
- 既存対応記録
- 運用設計資料
- GuardDuty参照権限
- CloudWatch Alarm参照権限

### 3.4 CloudTrailログ保存先S3のServer Access Logging

元テキスト上の指摘:

- CloudTrailログ保存先S3バケットのサーバーアクセスログが無効である。

必要な情報:

- CloudTrailログ保存先S3バケット
- Server Access Loggingの現在値
- アクセスログの保存先バケット
- ログ保存先の暗号化、ライフサイクル、アクセス権限
- ログ量と費用影響

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | CloudTrailログ保存先S3バケットはどれか | 対象バケット |
| 2 | Server Access Loggingの保存先は既存か新規か | 保存先設計 |
| 3 | 保存先バケットは同一アカウントか別アカウントか | Bucket Policy設計 |
| 4 | ログの保持期間とライフサイクルはどうするか | コストと保管設計 |
| 5 | 有効化後の確認証跡は何を提出するか | テスト・証跡 |

必要な資料・権限:

- クラウドログ設定エビデンス
- CloudTrail参照権限
- S3 Logging参照・変更権限
- S3 Bucket Policy参照権限

### 3.5 CloudTrailログのKMS CMK暗号化

元テキスト上の指摘:

- CloudTrailログがSSE-KMSではなく、カスタマー管理KMSキーで暗号化されていない。

必要な情報:

- TrailのKmsKeyId
- CloudTrailログ保存先S3のデフォルト暗号化
- 既存KMSキーの有無
- 新規KMSキー作成可否
- Key Policy
- CloudTrailがKMSキーを使用できる権限
- 運用者がログを参照できる権限

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 既存のカスタマー管理KMSキーを使うか、新規作成するか | KMS設計 |
| 2 | Trail側のKmsKeyId設定まで変更対象か | CloudTrail変更手順 |
| 3 | S3バケットのデフォルト暗号化も変更対象か | S3暗号化設計 |
| 4 | Key Policyのレビュー担当は誰か | 承認ルート |
| 5 | ログ参照者にKMS復号権限が必要か | 運用者権限 |

必要な資料・権限:

- クラウドログ設定エビデンス
- KMS設計資料
- CloudTrail参照・変更権限
- KMS参照・変更権限
- S3暗号化設定参照権限

### 3.6 カスタマー管理KMSキーのローテーション

元テキスト上の指摘:

- 3.5でカスタマー管理KMSキーが使われていないため、評価対象となるキーがない。
- 3.5対応時にローテーションを有効化する。

必要な情報:

- 対象KMSキー
- 対称キーかどうか
- 自動ローテーションの現在値
- ローテーション対象外キーの有無
- 鍵運用ルール

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 3.5で使うKMSキーは対称カスタマー管理キーか | ローテーション可否 |
| 2 | 自動ローテーションを有効化してよいか | KMS変更手順 |
| 3 | 既存キーを使う場合、ローテーション方針は決まっているか | 既存運用との整合 |
| 4 | ローテーション有効化の証跡は何を提出するか | 証跡取得 |

必要な資料・権限:

- KMS設計資料
- KMS参照権限
- KMS Rotation変更権限

### 3.7 すべてのVPCでVPC Flow Logsが有効であること

元テキスト上の指摘:

- 一部環境ではVPC Flow Logsが有効だが、一部環境では無効である。

必要な情報:

- 対象VPC一覧
- VPC Flow Logsの有効化状況
- 保存先
- ログ形式
- 保持期間
- 費用影響
- 無効になっている理由

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 対象はすべてのVPCか、一部VPCか | 有効化範囲 |
| 2 | 既に有効なVPCと無効なVPCの一覧はあるか | 現状調査範囲 |
| 3 | 保存先はCloudWatch LogsかS3か | 設計と権限 |
| 4 | ログ対象はALL、ACCEPT、REJECTのどれか | ログ量と分析観点 |
| 5 | 無効な理由が業務上の制約か単なる未設定か | 対応可否 |

必要な資料・権限:

- VPC構成資料
- クラウドログ設定エビデンス
- EC2/VPC参照権限
- Flow Logs参照・変更権限
- CloudWatch LogsまたはS3参照権限

### 4.1 不正なAPI呼び出し監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- CloudTrailが対象APIを記録しているか
- CloudTrailとCloudWatch Logsの連携有無
- 既存Metric FilterとAlarm
- 不正API呼び出しの判定条件
- 通知先

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 監視対象はAccessDenied系でよいか | Filter Pattern |
| 2 | UnauthorizedOperationやAccessDeniedExceptionなど、対象エラー名はどこまで含めるか | 検知範囲 |
| 3 | 1回で通知するか、一定回数以上で通知するか | Alarmしきい値 |
| 4 | 既存監視製品で同等通知があるか | 重複作成の有無 |

必要な資料・権限:

- セキュリティ設計資料
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Metric Filter/Alarm参照・変更権限
- 通知先参照権限

### 4.2 MFAなし管理コンソールサインイン監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。
- MFA強制済みなら不要の補足がある。

必要な情報:

- IAMユーザー、SSO、フェデレーション等のログイン方式
- MFA強制方針
- ConsoleLoginイベントの記録状況
- 既存Metric FilterとAlarm

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | MFAは全利用者に強制されているか | 監視の必要性 |
| 2 | MFAなし成功ログインを監視対象にする認識でよいか | Filter Pattern |
| 3 | root、IAMユーザー、フェデレーションをすべて対象にするか | 対象範囲 |
| 4 | 検知時のエスカレーション先はどこか | 運用手順 |

必要な資料・権限:

- IAM認証設計資料
- セキュリティ設計資料
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.3 rootアカウント使用監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- rootアカウント運用ルール
- root使用が許可される作業
- CloudTrail上のrootイベント
- 通知先とエスカレーション先

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | root使用は原則禁止か、承認時のみ許可か | 異常判定基準 |
| 2 | rootのConsoleLoginのみか、API操作も対象にするか | Filter Pattern |
| 3 | 検知時は即時連絡が必要か | Alarm通知方式 |
| 4 | root使用が予定作業だった場合の記録方法は何か | 運用手順 |

必要な資料・権限:

- IAM運用資料
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.4 IAMポリシー変更監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- IAM変更運用ルール
- 管理ポリシー、インラインポリシー、Role/User/Groupの変更対象
- 既存変更申請フロー
- 既存Metric FilterとAlarm

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 監視対象はIAM Policy変更全般でよいか | 対象イベント |
| 2 | Role/User/GroupへのPolicy Attach/Detachも含めるか | 検知範囲 |
| 3 | 予定変更もすべて通知するか | 通知量 |
| 4 | IAM変更の正当性確認は誰が行うか | 運用手順 |

必要な資料・権限:

- IAM運用資料
- CloudTrail参照権限
- IAM参照権限
- CloudWatch Logs参照権限
- Metric Filter/Alarm参照・変更権限

### 4.5 CloudTrail設定変更監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- 対象Trail一覧
- Organization Trailか個別Trailか
- CloudTrail設定変更イベント
- StopLoggingやDeleteTrailの扱い

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 対象Trailは全Trailか、重要Trail限定か | Filter対象 |
| 2 | StopLogging/DeleteTrailは高重要度通知にするか | 重要度設計 |
| 3 | Event Selector変更も含めるか | 検知範囲 |
| 4 | Organizations配下の場合、管理アカウント側で監視するか | 作業場所 |

必要な資料・権限:

- CloudTrail設計資料
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Metric Filter/Alarm参照・変更権限

### 4.6 AWS Management Console認証失敗監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- ConsoleLogin Failureの発生頻度
- しきい値
- 対象ユーザー範囲
- 通知先

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 1回の失敗で通知するか、複数回で通知するか | Alarmしきい値 |
| 2 | rootログイン失敗は別扱いにするか | 重要度設計 |
| 3 | 失敗元IPを確認する運用はあるか | 一次調査手順 |
| 4 | 誤検知やノイズの許容度はどの程度か | 通知頻度 |

必要な資料・権限:

- セキュリティ設計資料
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.7 カスタマー管理KMSキーの無効化・削除予約監視

元テキスト上の指摘:

- カスタマー管理KMSキーの無効化または削除予約が監視されていない。

必要な情報:

- 対象KMSキー一覧
- キーの用途
- 無効化や削除予約の承認フロー
- CloudTrail上のKMSイベント

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 監視対象は全カスタマー管理KMSキーか | 対象範囲 |
| 2 | DisableKeyとScheduleKeyDeletionを対象にする認識でよいか | Filter Pattern |
| 3 | CancelKeyDeletionも監視するか | 補助監視 |
| 4 | 検知時の緊急連絡先はどこか | 運用手順 |

必要な資料・権限:

- KMS設計資料
- KMS参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.8 S3バケットポリシー変更監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- 対象S3バケット範囲
- PutBucketPolicy/DeleteBucketPolicyの監視で要件を満たすか
- Public Access Block、ACL、Ownership Controls、CORS変更を含めるか
- 通知先
- テスト用バケットの有無

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 対象は全S3バケットか、監査対象バケット限定か | Filter設計 |
| 2 | PutBucketPolicy/DeleteBucketPolicyの2イベントでよいか | 監視範囲 |
| 3 | Public Access BlockやACL変更も含めるか | 要件拡張 |
| 4 | 検証用S3バケットでテストしてよいか | テスト手順 |
| 5 | 通知本文に対象バケット名や操作者情報を含める必要があるか | 通知設計 |

必要な資料・権限:

- S3設計資料
- CloudTrail参照権限
- S3参照権限
- CloudWatch Logs参照権限
- Metric Filter/Alarm参照・変更権限

### 4.9 AWS Config設定変更監視

元テキスト上の指摘:

- AWS Configの設定変更が監視されていない。

必要な情報:

- AWS Configの導入状況
- Configuration Recorderの設定
- Delivery Channelの設定
- Config関連変更イベント
- 管理アカウントや対象リージョン

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | AWS Configは対象環境で有効か | 現状調査範囲 |
| 2 | Config自体の変更監視が今回の対象でよいか | 監視対象 |
| 3 | Recorder停止やDelivery Channel削除を高重要度にするか | 重要度設計 |
| 4 | Config Rulesの変更も含めるか | 検知範囲 |

必要な資料・権限:

- AWS Config設計資料
- Config参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.10 Security Group変更監視

元テキスト上の指摘:

- 月次確認はあるが、通知設定がない。

必要な情報:

- 対象VPC
- Security Group変更運用
- 許可申請フロー
- 変更イベントの範囲

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 全Security Group変更を通知するか | 通知量 |
| 2 | Ingress/Egressルール変更を対象にするか | Filter Pattern |
| 3 | Security Group作成・削除も対象にするか | 検知範囲 |
| 4 | 0.0.0.0/0許可など危険変更だけ高重要度にするか | 重要度設計 |

必要な資料・権限:

- VPC構成資料
- EC2/VPC参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.11 NACL変更監視

元テキスト上の指摘:

- NACLの変更が監視されていない。

必要な情報:

- 対象VPC
- NACL変更運用
- 重要サブネット
- 変更イベントの範囲

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 全NACL変更を通知するか | 通知量 |
| 2 | Entry作成・置換・削除を対象にするか | Filter Pattern |
| 3 | NACL関連付け変更も含めるか | 検知範囲 |
| 4 | 重要サブネットに紐づくNACLだけ別扱いにするか | 重要度設計 |

必要な資料・権限:

- VPC構成資料
- EC2/VPC参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.12 Network Gateway変更監視

元テキスト上の指摘:

- Network Gatewayの変更が監視されていない。

必要な情報:

- 対象Gateway種別
- Internet Gateway、Customer Gateway、Virtual Private Gateway、Transit Gateway等の対象範囲
- 作成、削除、Attach、Detachの扱い

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 監視対象のGateway種別はどこまでか | 対象イベント |
| 2 | Attach/Detachを高重要度にするか | 重要度設計 |
| 3 | Transit Gateway関連を含めるか | 権限と対象範囲 |
| 4 | Gateway削除時の連絡先はどこか | 運用手順 |

必要な資料・権限:

- ネットワーク構成資料
- EC2/VPC参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.13 Route Table変更監視

元テキスト上の指摘:

- Route Tableの変更が監視されていない。

必要な情報:

- 対象Route Table
- 重要サブネット
- インターネット向け経路
- NAT Gateway、Transit Gateway、VPC Endpoint等の経路

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | 全Route Table変更を通知するか | 通知量 |
| 2 | CreateRoute/DeleteRoute/ReplaceRouteを対象にするか | Filter Pattern |
| 3 | Association変更も含めるか | 検知範囲 |
| 4 | 0.0.0.0/0やGateway向き経路を高重要度にするか | 重要度設計 |

必要な資料・権限:

- ネットワーク構成資料
- EC2/VPC参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.14 VPC変更監視

元テキスト上の指摘:

- VPCの変更が監視されていない。

必要な情報:

- 対象VPC一覧
- VPC Peeringの有無
- CIDR変更や属性変更の扱い
- VPC作成・削除の扱い

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | VPC作成・削除・属性変更をすべて対象にするか | 検知範囲 |
| 2 | VPC Peering変更も含めるか | 対象イベント |
| 3 | DHCP Options変更を含めるか | 監視範囲 |
| 4 | VPC変更時の確認担当は誰か | 運用手順 |

必要な資料・権限:

- VPC構成資料
- EC2/VPC参照権限
- CloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

### 4.15 AWS Organizations変更監視

元テキスト上の指摘:

- AWS Organizationsの変更が監視されていない。

必要な情報:

- Organizations利用有無
- 管理アカウント
- 対象OU
- SCP運用
- CloudTrailの記録場所

確認事項:

| No | 確認事項 | 回答によって変わること |
|---|---|---|
| 1 | Organizationsは今回の対象環境で利用されているか | 調査対象 |
| 2 | 管理アカウント側で作業・確認が必要か | 権限依頼先 |
| 3 | SCP変更、OU変更、アカウント移動を対象にするか | Filter Pattern |
| 4 | Organizations変更の通知先は通常のAWS通知先と同じでよいか | 通知設計 |

必要な資料・権限:

- Organizations設計資料
- Organizations参照権限
- 管理アカウント側のCloudTrail参照権限
- CloudWatch Logs参照権限
- Alarm参照・変更権限

## 7. 確認後に決めること

| No | 決めること | 関係する要件 |
|---|---|---|
| 1 | 対象アカウント・対象環境・対象リージョン | 全要件 |
| 2 | 既存資料の正本 | 全要件 |
| 3 | 監視方式をCloudWatch Metric Filter/Alarm中心で統一するか | 4.1〜4.15 |
| 4 | EventBridgeや既存監視製品を補足確認するか | 4.1〜4.15 |
| 5 | 通知先を既存にするか新規にするか | A3、A4、4.1〜4.15 |
| 6 | 設定変更を先行する要件 | 3.4〜3.7、4.8 |
| 7 | 本番で実イベントテストを行うか | 4.1〜4.15 |
| 8 | 証跡の保存形式 | 全要件 |
| 9 | 運用手順書のレビュー担当 | A3、A4 |
| 10 | リリース前の承認者 | 全要件 |

## 8. 関係者へ最初に投げる短い確認文

以下のように確認すると、話を始めやすい。

```text
監査指摘対応について、要件番号ごとに必要な情報と確認事項を整理しました。

まず、対象アカウント・対象環境・対象リージョン、既存資料の所在、
CloudTrail/CloudWatch/SNS等の既存監視構成、通知先、作業権限を確認したいです。

4.1〜4.15は、評価シート上ではCloudTrailをCloudWatchへ連携し、
Metric FilterとAlarmで発報する方針に見えます。

EventBridgeや既存監視製品は、必須方式ではなく、
同等監視の有無や二重通知防止の確認観点として見ます。
```

