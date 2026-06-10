# 2026-06-05 to 2026-07-01 案件対策ロードマップ

## 1. このロードマップの目的

このロードマップは、2026年7月2日（木）の案件初日に向けて、AWSセキュリティ・ネットワーク改善案件で実際に使いそうな作業を、参画前に手を動かして練習するための計画である。

対象案件は、某銀行の振込・電子保管システムにおけるAWSセキュリティ・ネットワーク最適化・改善案件を想定する。

想定される作業は、アプリ開発ではなく以下である。

- AWS設定の確認
- セキュリティ対策状況の確認
- 影響調査済み項目に対する設定変更
- 設定変更後のテスト
- 作業手順書の作成
- 証跡取得
- 必要に応じた報告対応

## 2. 期間と学習時間

| 項目 | 内容 |
| :--- | :--- |
| 開始日 | 2026年6月5日（金） |
| 終了日 | 2026年7月1日（水） |
| 案件初日 | 2026年7月2日（木） |
| 平日 | 2時間 |
| 土日 | 4時間 |
| 平日日数 | 19日 |
| 土日日数 | 8日 |
| 合計時間 | 70時間 |

時間配分の目安:

| 領域 | 時間 | 比率 | 内容 |
| :--- | :--- | :--- | :--- |
| AWSハンズオン・模擬変更 | 38時間 | 約56% | S3、CloudTrail、CloudWatch、GuardDuty、VPC/SG、RDS、Lambda |
| 運用シェル基礎・読解 | 6時間 | 約9% | Bash関数、引数、戻り値、終了コード、sed、awk |
| 手順書・証跡整理 | 16時間 | 約24% | 変更前確認、変更後確認、切り戻し、スクリーンショット想定 |
| 報告・説明練習 | 8時間 | 約11% | Teams報告、初日質問、作業説明、面談で話せる整理 |

## 2.1 6月9日時点の進捗と改訂理由

6月6日から6月9日にかけて、S3セキュリティ確認とBucket Policy変更ドリルを予定より深く実施した。

実施済み:

- S3 Public Access Block、Bucket Policy、ACL、暗号化、Versioning、Loggingなどの確認
- Bucket Policy変更前バックアップ
- TLS 1.2未満を拒否するPolicyの追加
- 変更後確認と正常系アクセステスト
- CloudTrailによる`PutBucketPolicy`変更履歴確認
- 変更前Policyへの切り戻し
- 切り戻し後の設定、疎通、CloudTrail確認

現在参画中の農中情報システムの現場で、NTTデータ系のAWS API関連シェルについて次の特徴を確認した。

- Bashで作成された大規模な共通関数ファイル
- `declare`による変数宣言
- 関数内での厳格な引数・異常系チェック
- 多数の`return`と最上位の終了コード管理
- confファイルからの設定読み込み
- マルチアカウント利用を意識した構造
- AWS CLIコマンドを変数へ格納して実行
- JSON解析に`sed`、`awk`などを使用
- JP1などのジョブ管理を意識したログと終了ステータス

これは7月案件で使用されるシェルの情報ではなく、別現場で確認した参考情報である。
7月案件で同じ構造が採用されている根拠はないため、案件前提にはしない。

ただし、厳格な引数チェック、戻り値、ログ、終了コードなどは金融系運用シェル全般で役立つため、補助学習として最小限取り入れる。

## 2.2 参画日確定後の追加方針

案件初日は2026年7月2日（木）に確定した。

参画直前の1週間は、新規知識を最大限まで詰め込む期間ではなく、総復習、模擬チケット、手順書、証跡、報告練習を中心にする。

NTTデータ関連の金融現場で観察した運用シェルの特徴を参考に、クリーンルーム方式の模擬共通関数シェルを作成し、1日から2日程度の読解・利用演習を行う。

模擬シェルに含める要素:

- `source`で読み込む共通関数ファイル
- confファイル
- `declare`による変数・定数
- 厳格な引数チェックと異常系チェック
- 戻り値、終了コード、ログ
- AWS CLI実行ラッパー
- マルチアカウント・Profile切替を意識した構造
- `sed`、`awk`を利用した結果確認

この方式が7月案件で使われることは未確認である。既存方式がある場合に読み解き、合わせて作業する能力を養う補助演習として扱う。

顧客名は公開ポートフォリオやリポジトリ内へ記載しない。

## 3. 方針

この期間のメイン作業は、新しいリファレンスを増やすことではなく、作成済みリファレンスを使って「案件で実際に動ける状態」にすることである。

基本方針:

- 読むだけで終わらせない
- 1回の作業を必ず「変更前確認、実施、変更後確認、切り戻し、証跡」に分解する
- CLI結果だけでなく、Webコンソールのスクリーンショット証跡も想定する
- Teamsで報告できる文章まで作る
- 完璧な網羅より、案件で出そうな作業を深く練習する
- 6月25日から7月1日は新規作成より総復習、模擬作業、リハーサルを優先する
- 現場想定の主要手順ではPythonと`jq`を必須にしない
- AWS CLI、Webコンソール、`grep`、`sed`、`awk`、`diff`、`cmp`を中心にする
- 運用シェル学習は汎用的なBash読解力の補強として扱い、7月案件の実行方式とは決めつけない
- 7月案件では、参画後に実際の作業方式、ツール、共通シェルの有無を確認する

おすすめの進め方:

```text
1. リファレンスを読む
2. 実際にAWS CLIで確認する
3. 証跡を保存する
4. 作業手順書に落とす
5. 切り戻しを書く
6. Teams報告文を書く
7. 自分の言葉で説明する
```

## 4. 6月30日時点の到達目標

6月30日時点で、以下を満たしていれば案件初日にかなり落ち着いて入れる。

| No. | 到達目標 | 完了条件 |
| :--- | :--- | :--- |
| 1 | S3バケットポリシー変更を説明できる | 変更前確認、差分、変更、切り戻しを手順書化済み |
| 2 | S3 Public Access Block / ACL / 暗号化を確認できる | CLIとWebコンソールで見る場所を把握 |
| 3 | CloudTrailで変更履歴を追える | EventName、User、Time、Source IPを説明できる |
| 4 | CloudWatch Logs / Metric Filter / Alarmを説明できる | MFAなしログイン検知の流れを説明できる |
| 5 | GuardDuty Findingを調査できる | Finding詳細、重要度、対象リソース、初動を説明できる |
| 6 | SG変更の影響調査ができる | Source、Destination、Port、影響範囲を整理できる |
| 7 | VPC / Route / NACL / Endpointを横断確認できる | 通信経路の切り分け順を説明できる |
| 8 | RDS / Lambdaの主要セキュリティ設定を確認できる | Public設定、SG、暗号化、ログ、Function URLなど |
| 9 | 証跡を残せる | JSON、差分、スクリーンショット、テスト結果を整理できる |
| 10 | Teamsで報告できる | 変更前、変更後、要確認の報告文を出せる |
| 11 | 運用シェルの基本的な処理を追える | 引数、関数、戻り値、終了コード、ログの流れを追える |

## 5. 使う主要ファイル

| 用途 | ファイル |
| :--- | :--- |
| 共通作法 | [00_common_aws_cli_reference.md](../references/00_common_aws_cli_reference.md) |
| S3セキュリティ | [01_s3_security_cli_reference.md](../references/01_s3_security_cli_reference.md) |
| S3バケットポリシー | [02_s3_bucket_policy_cli_reference.md](../references/02_s3_bucket_policy_cli_reference.md) |
| CloudTrail | [03_cloudtrail_cli_reference.md](../references/03_cloudtrail_cli_reference.md) |
| CloudWatch | [04_cloudwatch_cli_reference.md](../references/04_cloudwatch_cli_reference.md) |
| GuardDuty | [05_guardduty_cli_reference.md](../references/05_guardduty_cli_reference.md) |
| MFAなしログイン検知 | [06_mfa_console_login_detection.md](../references/06_mfa_console_login_detection.md) |
| VPC / Network | [07_vpc_network_cli_reference.md](../references/07_vpc_network_cli_reference.md) |
| EC2 Security | [08_ec2_security_cli_reference.md](../references/08_ec2_security_cli_reference.md) |
| RDS Security | [09_rds_security_cli_reference.md](../references/09_rds_security_cli_reference.md) |
| Lambda Security | [10_lambda_security_cli_reference.md](../references/10_lambda_security_cli_reference.md) |
| セキュリティ横断 | [90_aws_security_settings_checklist.md](../references/90_aws_security_settings_checklist.md) |
| ネットワーク横断 | [91_aws_network_settings_checklist.md](../references/91_aws_network_settings_checklist.md) |
| 手順書テンプレート | [s3_bucket_policy_change_procedure_template.md](../templates/s3_bucket_policy_change_procedure_template.md) |
| S3ケーススタディ | [case_study_s3_bucket_policy_change.md](../case_studies/case_study_s3_bucket_policy_change.md) |
| Day 1 S3確認ドリル | [01_Day_Learning.md](../../day-learning/01_Day_Learning.md) |
| Day 2 Bucket Policy変更ドリル | [02_Day_Learning.md](../../day-learning/02_Day_Learning.md) |
| Day 3 CloudTrail変更履歴調査ドリル | [03_Day_Learning.md](../../day-learning/03_Day_Learning.md) |
| Day 4 CloudWatch Logs・検知確認ドリル | [04_Day_Learning.md](../../day-learning/04_Day_Learning.md) |
| Day 5 MFAなし管理コンソールログイン検知ドリル | [05_Day_Learning.md](../../day-learning/05_Day_Learning.md) |
| Day 6 CloudWatch・MFAなしログイン検知ハンズオン | [06_Day_Learning.md](../../day-learning/06_Day_Learning.md) |
| Day 7 CloudTrail・CloudWatch総合調査ドリル | [07_Day_Learning.md](../../day-learning/07_Day_Learning.md) |
| Day 8 GuardDuty基礎確認・Finding一次調査 | [08_Day_Learning.md](../../day-learning/08_Day_Learning.md) |
| Day 9 GuardDutyサンプルFinding調査・後片付け | [09_Day_Learning.md](../../day-learning/09_Day_Learning.md) |
| Day 10 VPC・Subnet・Route Table確認 | [10_Day_Learning.md](../../day-learning/10_Day_Learning.md) |
| Day 11 Security Group・Network ACL確認 | [11_Day_Learning.md](../../day-learning/11_Day_Learning.md) |
| Day 12 Security Group変更影響調査・手順書作成 | [12_Day_Learning.md](../../day-learning/12_Day_Learning.md) |
| Day 13 Security Group変更・確認・切り戻しドリル | [13_Day_Learning.md](../../day-learning/13_Day_Learning.md) |
| Day 14 DNS・VPC Endpoint・Flow Logs確認 | [14_Day_Learning.md](../../day-learning/14_Day_Learning.md) |
| Day 15 EC2・RDS Security確認 | [15_Day_Learning.md](../../day-learning/15_Day_Learning.md) |
| Day 16 Lambda Security確認 | [16_Day_Learning.md](../../day-learning/16_Day_Learning.md) |
| Day 17 運用シェル基礎・読解演習 | [17_Day_Learning.md](../../day-learning/17_Day_Learning.md) |
| Day 18 AWSセキュリティ横断チェック | [18_Day_Learning.md](../../day-learning/18_Day_Learning.md) |
| Day 19 作業手順書・証跡整理 | [19_Day_Learning.md](../../day-learning/19_Day_Learning.md) |
| Day 20 模擬作業1 S3 Bucket Policy変更 | [20_Day_Learning.md](../../day-learning/20_Day_Learning.md) |
| Day 21 模擬作業2 GuardDuty Finding・CloudTrail横断調査 | [21_Day_Learning.md](../../day-learning/21_Day_Learning.md) |
| Day 22 案件初日準備・受入情報整理 | [22_Day_Learning.md](../../day-learning/22_Day_Learning.md) |
| Day 23 最終リハーサル・説明練習・公開前確認 | [23_Day_Learning.md](../../day-learning/23_Day_Learning.md) |

## 6. 日別ロードマップ

### 6月5日（金） 2時間

テーマ: 全体整理と開始準備

進捗: 完了

実施内容:

- ロードマップと主要リファレンスの確認
- 案件対策の優先順位整理
- Day Learning形式での学習開始準備

### 6月6日（土）から6月9日（火）

テーマ: S3セキュリティ確認・Bucket Policy変更総合ドリル

進捗: 完了

実施内容:

- Day 1としてS3セキュリティ設定をGUIとAWS CLIで確認
- Day 2としてBucket Policyの変更前確認、影響調査、バックアップを実施
- `DenyOutdatedTLS`を追加し、変更後設定と正常系アクセスを確認
- CloudTrailで変更イベントを確認
- 変更前Policyへの切り戻しを実施
- 切り戻し後Policy、Public判定、Public Access Block、オブジェクト一覧を確認
- CloudTrailで切り戻しイベントを確認

成果物:

- [01_Day_Learning.md](../../day-learning/01_Day_Learning.md)
- [02_Day_Learning.md](../../day-learning/02_Day_Learning.md)
- 変更前、変更後、切り戻しPolicy
- CloudTrailイベント証跡

完了条件:

- S3セキュリティ設定の確認順を説明できる
- Bucket Policy変更を「変更前確認、変更、変更後確認、切り戻し、CloudTrail確認」まで実行できる
- `Principal`、`Action`、`Resource`、`Condition`を説明できる

### 6月10日（水） 2時間

テーマ: CloudTrail基礎・変更履歴調査

やること:

- `03_cloudtrail_cli_reference.md`を読む
- Trail一覧、Trail Status、Event Historyの違いを確認する
- Management EventとData Eventの違いを整理する
- `lookup-events`でS3以外の変更イベントも検索する
- EventName、Username、EventTime、SourceIPAddress、UserAgent、エラー有無を確認する
- 生JSONと読みやすい要約を分けて保存する

成果物:

- Day 3 CloudTrailイベント検索メモ
- CloudTrail変更履歴確認テンプレート

完了条件:

- 任意の変更操作について「誰が、いつ、何をしたか」を説明できる
- Management EventとData Eventの違いを説明できる

### 6月11日（木） 2時間

テーマ: CloudWatch Logs / Metric Filter

やること:

- `04_cloudwatch_cli_reference.md`を読む
- Log Group、Retention、Metric Filter、Alarmを確認する
- CloudTrail連携ログがある前提で検知の流れを整理する
- Logs Insightsの基本クエリを確認する

成果物:

- CloudWatch確認メモ

完了条件:

- Log Group、Metric Filter、Alarmの役割を説明できる

### 6月12日（金） 2時間

テーマ: MFAなし管理コンソールログイン検知の設計理解

やること:

- `06_mfa_console_login_detection.md`を読む
- `ConsoleLogin`と`additionalEventData.MFAUsed`を確認する
- CloudTrailからCloudWatch Logs、Metric Filter、Alarmへつながる流れを整理する
- 作業手順、確認方法、切り戻しを確認する

成果物:

- MFAなしログイン検知の説明メモ

完了条件:

- 面談で出た「CloudTrailをCloudWatchに連携し、MFAなし管理コンソールログインを検知」を説明できる

### 6月13日（土） 4時間

テーマ: CloudWatch・MFAなしログイン検知ハンズオン

やること:

- `04_cloudwatch_cli_reference.md`と`06_mfa_console_login_detection.md`を読む
- Log Group、Retention、Metric Filter、Alarmの役割を確認する
- CloudTrailからCloudWatch Logs連携の設定を確認する
- `ConsoleLogin`と`additionalEventData.MFAUsed`を確認する
- Metric FilterとAlarmの作成手順を確認する
- テスト方法、変更後確認、切り戻しを整理する
- GUI、AWS CLI、証跡、報告の流れをまとめる

成果物:

- MFAなしログイン検知手順書
- CloudWatch確認メモ
- 証跡一覧
- Teams報告文

完了条件:

- 「CloudTrailをCloudWatchへ連携し、MFAなしログインを検知する」流れを説明できる
- 実作業として依頼されても、手順書を見ながら進められる

### 6月14日（日） 4時間

テーマ: CloudTrail / CloudWatch総合ドリル

やること:

- CloudTrail変更履歴確認
- CloudWatch Logs確認
- Metric Filter / Alarm確認
- 変更後確認と切り戻しの流れを1本にまとめる
- スクリーンショット証跡の撮影ポイントを整理する

成果物:

- [Day 7 CloudTrail・CloudWatch総合調査ドリル](../../day-learning/07_Day_Learning.md)
- CloudTrail / CloudWatch総合作業メモ

完了条件:

- 監査ログ、検知、証跡のつながりを説明できる

### 6月15日（月） 2時間

テーマ: GuardDuty基礎確認

やること:

- `05_guardduty_cli_reference.md` を読む
- Detector、Finding、Severityを確認する
- Finding一覧とFinding詳細の見方を整理する
- 重要度ごとの初動を整理する

成果物:

- [Day 8 GuardDuty基礎確認・Finding一次調査](../../day-learning/08_Day_Learning.md)
- GuardDuty Finding調査メモ

完了条件:

- Findingを見た時に、対象リソースと重要度を説明できる

### 6月16日（火） 2時間

テーマ: GuardDuty調査手順

やること:

- サンプルFindingを使った調査フローを整理する
- CloudTrail、VPC Flow Logs、Security Group確認へつなげる
- Teams報告文を作る

成果物:

- [Day 9 GuardDutyサンプルFinding調査・後片付け](../../day-learning/09_Day_Learning.md)
- GuardDuty調査手順テンプレート

完了条件:

- 「Findingが出ています」と言われた時の初動を説明できる

### 6月17日（水） 2時間

テーマ: VPC / Route Table確認

やること:

- `07_vpc_network_cli_reference.md` を読む
- VPC、Subnet、Route Tableを確認する
- Public / Private SubnetをRoute Tableで判定する
- Main Route Tableと明示関連付けを確認する

成果物:

- [Day 10 VPC・Subnet・Route Table確認](../../day-learning/10_Day_Learning.md)
- VPC / Route確認メモ

完了条件:

- Public / PrivateをSubnet名ではなくRoute Tableで説明できる

### 6月18日（木） 2時間

テーマ: Security Group / NACL確認

やること:

- SGとNACLの違いを整理する
- SG Rule単位でInbound / Outboundを確認する
- NACLのRule番号、Allow/Deny、Ephemeral Portを確認する
- 危険な公開ルールを整理する

成果物:

- [Day 11 Security Group・Network ACL確認](../../day-learning/11_Day_Learning.md)
- SG / NACL確認メモ

完了条件:

- SGはStateful、NACLはStatelessを実務目線で説明できる

### 6月19日（金） 2時間

テーマ: SG変更の影響調査手順化

やること:

- Web SGからRDS SGへ3306を許可する想定で手順書を作る
- 変更前確認を書く
- 影響範囲を書く
- 変更後確認を書く
- 切り戻しを書く

成果物:

- [Day 12 Security Group変更影響調査・手順書作成](../../day-learning/12_Day_Learning.md)
- SG変更手順書

完了条件:

- SG変更作業をレビューに出せる粒度で書ける

### 6月20日（土） 4時間

テーマ: ネットワーク変更ドリル

やること:

- SG変更の模擬作業を実施する
- 変更前SG Ruleを保存する
- ルール追加または削除を行う
- 疎通確認を行う
- 切り戻しを行う
- CloudTrailで変更履歴を確認する

成果物:

- [Day 13 Security Group変更・確認・切り戻しドリル](../../day-learning/13_Day_Learning.md)
- SG変更の実施証跡
- 疎通確認結果
- 切り戻し証跡

完了条件:

- SG変更を「作業、確認、戻し」まで一人で回せる

### 6月21日（日） 4時間

テーマ: DNS / Endpoint / Flow Logs確認

やること:

- Private Hosted ZoneとVPC DNS属性を確認する
- VPC Endpoint一覧を確認する
- S3通信がNATかEndpointかを整理する
- Flow LogsでACCEPT / REJECTを見る練習をする
- `91_aws_network_settings_checklist.md` を使って横断確認する

成果物:

- DNS / Endpoint / Flow Logs確認メモ
- [Day 14 DNS・VPC Endpoint・Flow Logs確認ドリル](../../day-learning/14_Day_Learning.md)

完了条件:

- 通信できない時にDNS、Route、SG、NACL、Endpoint、Flow Logsの順で切り分けられる

### 6月22日（月） 2時間

テーマ: EC2 / RDS Security確認

やること:

- `08_ec2_security_cli_reference.md` を読む
- Public IP、Security Group、IAM Role、IMDSv2を確認する
- EBS暗号化を確認する
- `09_rds_security_cli_reference.md` を読む
- PubliclyAccessible、DB Subnet Group、SGを確認する
- RDS暗号化、Backup、Deletion Protection、Logsを確認する

成果物:

- EC2 / RDS Security確認メモ
- [Day 15 EC2・RDS Security確認ドリル](../../day-learning/15_Day_Learning.md)

完了条件:

- EC2とRDSの主要なセキュリティ確認ポイントを短く説明できる
- RDSを外部公開していないことを複数観点で確認できる

### 6月23日（火） 2時間

テーマ: Lambda Security確認

やること:

- `10_lambda_security_cli_reference.md` を読む
- Execution Role、Resource-based policyを確認する
- VPC Config、環境変数、KMS、Logsを確認する
- Function URLの`AWS_IAM`と`NONE`の違いを整理する

成果物:

- Lambda Security確認メモ
- [Day 16 Lambda Security確認ドリル](../../day-learning/16_Day_Learning.md)

完了条件:

- Function URLの公開リスクを説明できる
- Lambdaの権限とネットワーク設定を確認できる

### 6月24日（水） 2時間

テーマ: 運用シェル基礎・読解演習

やること:

- Bashの`source`、`declare`、関数、引数、`return`、`exit`を確認する
- 関数ごとに入力、処理、戻り値を整理する
- 引数チェックとAWS CLI異常時の処理を確認する
- `grep`、`sed`、`awk`の基本的な利用方法を確認する
- 正常系と異常系の終了コード、標準出力、標準エラーを確認する
- 7月案件で同じ方式を使うとは限らないことを前提に、汎用的な読解練習として行う

成果物:

- 運用シェル読解メモ
- 異常系テスト結果
- 終了コード一覧
- [Day 17 運用シェル基礎・読解演習](../../day-learning/17_Day_Learning.md)

完了条件:

- 関数の入力、処理、戻り値を追跡できる
- ログと終了コードから失敗箇所を追跡できる

### 6月25日（木） 2時間

テーマ: セキュリティ横断チェック

やること:

- `90_aws_security_settings_checklist.md` を使って、ラボ環境または想定環境を1周確認する
- Critical / Highの確認項目を洗い出す
- 足りない証跡を整理する

成果物:

- セキュリティ横断チェック結果
- [Day 18 AWSセキュリティ横断チェック](../../day-learning/18_Day_Learning.md)

完了条件:

- 複数サービスを横断して確認する流れを掴む

### 6月26日（金） 2時間

テーマ: 手順書・証跡整理日

やること:

- ここまで作った手順書メモを整理する
- Markdown手順書テンプレートに合わせて整形する
- 証跡一覧の粒度を整える
- GUIスクリーンショットで撮る画面をリスト化する

成果物:

- 作業手順書テンプレートの実例
- 証跡一覧テンプレート
- [Day 19 作業手順書・証跡整理](../../day-learning/19_Day_Learning.md)

完了条件:

- Excel手順書に転記できる形になっている

### 6月27日（土） 4時間

テーマ: 模擬作業 1 S3バケットポリシー変更

やること:

- 作業チケットを想定する
- 変更前確認を行う
- S3 Bucket Policyの変更案を作る
- 影響範囲を整理する
- 変更またはドライランを行う
- 変更後確認を行う
- 切り戻しを行う
- Teams報告文を書く

成果物:

- 模擬作業一式
- 手順書
- 証跡
- 報告文
- [Day 20 模擬作業1 S3 Bucket Policy変更](../../day-learning/20_Day_Learning.md)

完了条件:

- 案件で一番出そうなS3作業を一通りリハーサルできている

### 6月28日（日） 4時間

テーマ: 模擬作業 2 GuardDuty Finding・CloudTrail横断調査

やること:

- Findingまたは想定Findingを起点にする
- 対象リソースを特定する
- Severity、Resource Role、Action、発生時刻を確認する
- CloudTrailで変更履歴を確認する
- SG / VPC / IAMの関連設定を確認する
- 事実、推測、未確認事項を分ける
- 推奨対応と一次調査報告を作る

Security Group変更はDay 12・Day 13で扱っているため、Day 21では面談で重点領域として挙がったGuardDuty・CloudTrailの横断調査を優先する。

成果物:

- 模擬作業一式
- 調査報告メモ
- [Day 21 模擬作業2 GuardDuty Finding・CloudTrail横断調査](../../day-learning/21_Day_Learning.md)

完了条件:

- Finding調査を「一人称で進める」感覚を掴む
- 事実、推測、未確認事項を分けて報告できる

### 6月29日（月） 2時間

テーマ: 案件初日の準備

やること:

- 初日に確認する質問リストを作る
- 現場ルール確認リストを作る
- 手順書レビュー観点を整理する
- Teamsでの報告テンプレートを整理する
- 自己紹介で話すAWS経験を短くまとめる

初日に確認したい質問例:

```text
- 変更作業はGUI中心かCLI中心か
- 手順書フォーマットはExcelかWordか
- 証跡はスクリーンショット必須か
- CloudTrail / Security Hub / GuardDuty / AWS Configは有効か
- 作業承認フローはどこで管理しているか
- 切り戻し判断者は誰か
- S3バケットポリシー変更対象一覧はどこにあるか
- 開発環境へのテキスト持ち込みルールはどうなっているか
- AWS設定変更はGUI、AWS CLI、既存シェルのどれで実施するか
- 共通関数シェルやconfファイルなどの既存作業基盤はあるか
- ジョブ管理製品や終了コードを利用する作業があるか
```

成果物:

- 初日質問リスト
- 自己紹介メモ
- Teamsテンプレート
- [Day 22 案件初日準備・受入情報整理](../../day-learning/22_Day_Learning.md)

完了条件:

- 初日に慌てず確認すべきことを聞ける
- 現場固有情報を公開リポジトリへ残さず整理できる
- 最初の作業依頼を安全に着手できる形へ分解できる

### 6月30日（火） 2時間

テーマ: 最終リハーサルと整え

やること:

- READMEから必要資料へ辿れるか確認する
- S3、CloudTrail、CloudWatch、GuardDuty、VPC、RDS、Lambdaの説明を1分ずつ練習する
- GitHubの状態を確認する
- `.DS_Store` など不要ファイルをコミットしないよう確認する
- 翌日に使うメモをまとめる

成果物:

- 初日用メモ
- 最終チェック結果
- [Day 23 最終リハーサル・説明練習・公開前確認](../../day-learning/23_Day_Learning.md)

完了条件:

- 案件初日に必要な資料と説明が手元にある
- 前日は詰め込みすぎず、余力を残す
- Repositoryの現在状態と公開可否を説明できる

## 7. 週ごとの重点テーマ

| 週 | 期間 | 重点テーマ | ゴール |
| :--- | :--- | :--- | :--- |
| Week 1 | 6/5 - 6/7 | S3基礎とBucket Policy | S3作業の入口を掴む |
| Week 2 | 6/8 - 6/14 | S3総合ドリル、CloudTrail、CloudWatch、MFA検知 | 設定変更、監査、検知を説明できる |
| Week 3 | 6/15 - 6/21 | GuardDuty、VPC、SG、NACL、DNS、Flow Logs | 調査とネットワーク影響確認ができる |
| Week 4 | 6/22 - 6/28 | EC2、RDS、Lambda、運用シェル基礎、横断チェック、模擬作業 | 実務ドリルで一人称の感覚を作る |
| Final | 6/29 - 6/30 | 初日準備、説明練習、整理 | 初日に落ち着いて入る |

## 8. 優先順位

時間が足りない場合は、以下を優先する。

| 優先度 | 項目 | 理由 |
| :--- | :--- | :--- |
| 1 | S3バケットポリシー変更ドリル | 案件で具体的に出ている |
| 2 | CloudTrail / CloudWatch / MFAなし検知 | 面談で重点キャッチアップに挙がった |
| 3 | SG / VPCネットワーク影響調査 | S3以外にもVPC/MFAなど横断対応がある |
| 4 | GuardDuty Finding調査 | 面談で話題になり、評価材料にもなった |
| 5 | 手順書・証跡・Teams報告 | NTTデータ系現場で重要になりやすい |
| 6 | RDS / Lambda / EC2確認 | 横断的に見られることの補強 |
| 7 | 運用シェル基礎・読解 | 7月案件での利用は未確認だが、金融系運用全般の補助知識になる |

## 9. 1日の作業テンプレート

平日2時間:

```text
00:00 - 00:10  今日やること確認
00:10 - 01:10  リファレンス確認・CLI確認・模擬作業
01:10 - 01:40  証跡整理・手順書反映
01:40 - 02:00  今日の学び、未完了、明日の入口を書く
```

土日4時間:

```text
00:00 - 00:15  今日のゴール確認
00:15 - 01:45  ハンズオン
01:45 - 02:00  休憩
02:00 - 03:00  変更後確認・切り戻し・証跡整理
03:00 - 03:40  手順書化・報告文作成
03:40 - 04:00  振り返り・次回準備
```

運用シェル基礎学習日:

```text
00:00 - 00:15  対象関数、引数、終了コードを確認
00:15 - 00:45  呼び出し元から処理とAWS CLI実行箇所を追跡
00:45 - 01:20  小さな確認用シェルを実行
01:20 - 01:40  正常系・異常系のログと戻り値を確認
01:40 - 02:00  関数仕様と調査結果を記録
```

## 10. 毎回残すメモ

各日の最後に、以下を短く残す。

```text
日付:
作業時間:
今日やったこと:
作成・更新したファイル:
理解できたこと:
まだ曖昧なこと:
案件で使えそうな言い方:
次回やること:
```

## 11. 案件初日に持っていく説明

自己紹介・作業姿勢として言えること:

```text
個人環境では、AWS CLIとシェルスクリプトでVPC、Subnet、ALB、EC2、RDS、S3、Route 53、ACM、SES、ElastiCacheまで構築し、
AnsibleでRailsアプリケーションのデプロイも検証しています。

セキュリティ・ネットワーク改善案件を意識して、S3バケットポリシー変更、CloudTrail、CloudWatch、GuardDuty、
MFAなし管理コンソールログイン検知、VPC / SG / NACL / Endpoint、RDS、Lambdaの確認手順をMarkdownで整理しています。

作業時は、変更前確認、影響範囲、変更後確認、切り戻し、証跡取得をセットで進める想定で準備しています。

参画前学習では、金融系運用にも応用できるよう、引数チェック、関数、戻り値、
終了コード、ログを使ったBashシェルの基礎読解も練習しています。
```

## 12. 追加提案

より良い進め方として、以下を提案する。

### 12.1 リファレンス追加より模擬チケット対応を優先する

リファレンスはかなり揃っているため、今後は新規ドキュメントを増やすより、実際の作業チケットを想定して1本ずつ完了させる方が効果が高い。

模擬チケット例:

```text
Ticket 1:
S3バケット policy-prod-archive のBucket Policyを変更し、
特定IAM RoleからのみPutObjectを許可する。

Ticket 2:
CloudTrailからMFAなしConsoleLoginを検知し、
CloudWatch Alarmで通知できるようにする。

Ticket 3:
Web EC2からRDSへの3306通信のみ許可されているか確認し、
不要なSecurity Group Ruleを削除する。

Ticket 4:
GuardDuty Findingを確認し、対象リソース、重要度、推奨対応を報告する。
```

### 12.2 GitHubを見せる前提の整備を最後に行う

6月末に以下だけ確認する。

- READMEから目的の資料へすぐ辿れるか
- 秘密情報が入っていないか
- `.DS_Store` が混ざっていないか
- 主要Markdownが案件説明に耐えるか
- 構成図と設計書が最新か

### 12.3 最終週は詰め込みすぎない

6月29日と6月30日は、新しいことを増やさず、初日に聞く質問と説明練習に寄せる。

```text
案件初日は、知識量よりも
「確認すべきことを落ち着いて確認できること」
「手順書と証跡の考え方が分かっていること」
「分からない点を適切に質問できること」
が重要。
```

### 12.4 既存シェルがある場合は、既存方式へ合わせる

7月案件で共通関数シェル、conf、JP1、マルチアカウント切替などが使われるかは未確認である。

既存シェルが存在する場合は、参画直後に新しい技術へ置き換えたり、共通部分を大きく変更したりしない。

基本姿勢:

```text
1. 呼び出し元と対象関数を特定する
2. 引数、設定値、戻り値、ログを確認する
3. 既存の命名規則とエラー処理へ合わせる
4. 修正範囲を最小限にする
5. 正常系と異常系をテストする
6. 共通関数変更時は影響範囲と利用箇所を確認する
```

## 13. 完了判定

6月30日に以下を確認する。

| No. | 確認 | OK |
| :--- | :--- | :--- |
| 1 | S3バケットポリシー変更手順を説明できる |  |
| 2 | CloudTrailで変更履歴を追える |  |
| 3 | CloudWatchでMetric Filter / Alarmを説明できる |  |
| 4 | MFAなしログイン検知の流れを説明できる |  |
| 5 | GuardDuty Finding調査の初動を説明できる |  |
| 6 | SG変更の影響調査と切り戻しを書ける |  |
| 7 | VPC / Route / NACL / Endpointの確認順を説明できる |  |
| 8 | RDS / Lambdaの主要セキュリティ設定を確認できる |  |
| 9 | 手順書テンプレートを使って作業手順を書ける |  |
| 10 | Teams報告文を短く書ける |  |
| 11 | 初日に聞く質問リストがある |  |
| 12 | GitHub / README / リファレンスを見せられる状態 |  |
| 13 | Bash関数の入力、処理、戻り値、ログを追える |  |
| 14 | 7月案件で使用する作業方式とツールを初日に確認できる |  |
