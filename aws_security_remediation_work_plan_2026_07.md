# AWSセキュリティ監査指摘対応 作業計画たたき台

作成日: 2026-07-07

この資料は、第三者検証評価シートの指摘事項に対して、作業計画を今週中に固めるためのたたき台である。
現時点では詳細設計や既存環境確認前のため、作業順序、作業群、確認観点、スケジュール目安を整理する。

## 1. 前提

対象作業は大きく以下の3系統に分ける。

| 分類 | 対象要件 | 概要 |
|---|---|---|
| 運用手順整備 | A3, A4 | GuardDuty等のセキュリティアラート対応手順、対応記録の整備 |
| ログ保全強化 | 3.4, 3.5, 3.6, 3.7 | CloudTrailログ保管先S3、SSE-KMS/CMK、CMKローテーション、VPC Flow Logs |
| 監視アラート設定 | 4.1〜4.15 | CloudTrailイベントをCloudWatch Logs / Metric Filter / Alarm等で検知・通知 |

評価シート上では、4.1〜4.15の多くが「CloudTrailをCloudWatchに連携させ、メトリクスおよびアラーム設定で発報する」方針で記載されている。
そのため、まずは既存のCloudTrail、CloudWatch Logs連携、Metric Filter、Alarm、SNS等の通知基盤を棚卸しし、既存構成に合わせて対応方針を決める。

## 2. マイルストーン

| 期間 | 目標 | 主な成果物 |
|---|---|---|
| 2026-07-07〜2026-07-10 | 作業計画目安の決定 | 対応方針、作業分解、概算スケジュール、確認事項一覧 |
| 2026-07-13〜2026-07-31 | 開発・設定作成 | 設定案、手順書、CloudWatch監視設定、KMS/ログ設定、開発環境反映 |
| 2026-08-03〜2026-08-14 | テスト | 単体テスト、結合テスト、通知テスト、証跡取得、修正 |
| 2026-08-17〜2026-09-11 | レビュー・リリース準備 | 銀行様説明資料、レビュー反映、本番手順確定、リリース判定 |
| 2026-09-12 | 最終リリース | 本番反映、リリース証跡、完了報告 |

## 3. 今週中に決めること

今週中に、少なくとも以下を決める。

| 項目 | 決める内容 |
|---|---|
| 対象環境 | Prod / OPER / 開発環境 / 検証環境の範囲 |
| 対象アカウント | AWSアカウント、リージョン、Organizations管理有無 |
| 実装方式 | CloudWatch Metric Filter中心か、EventBridge併用か |
| 通知先 | SNS、メール、Teams、監視製品、SIEM等 |
| 証跡方針 | CLI JSON、画面スクリーンショット、テスト結果、レビュー記録 |
| 開発環境での試験可否 | 本番前に同等設定を試せる環境の有無 |
| KMS方針 | CloudTrailログ用CMKの新規作成/既存利用、Key Policy、Rotation |
| VPC Flow Logs方針 | 対象VPC、保存先、保持期間、TrafficType、ログ量 |
| 本番変更方式 | GUI / CLI / IaC / 申請ツール / 作業者分担 |
| レビュー体制 | リーダー、銀行様、ITセキュリティ統括部、運用担当の確認ポイント |

## 4. 作業群

### 4.1 現状調査

目的は、既存設定で足りているもの、不足しているもの、新規設定が必要なものを切り分けることである。

確認対象:

- CloudTrail Trail
- CloudTrail Event Selectors
- CloudTrail保存先S3バケット
- CloudTrailからCloudWatch Logsへの連携
- CloudWatch Logs Log Group、保持期間、KMS
- 既存Metric Filter
- 既存CloudWatch Alarm
- 既存SNS Topic / Subscription
- 既存EventBridge Rule
- GuardDuty Detector / Finding運用
- VPC Flow Logs
- KMS Key / Key Policy / Rotation

成果物:

- 現状調査結果一覧
- 既存設定で対応済みの項目一覧
- 追加設定が必要な項目一覧
- 権限不足や追加確認が必要な項目一覧

### 4.2 運用手順整備

対象:

- A3: セキュリティアラートに関するモニタリング運用手順書
- A4: セキュリティアラートの日々の運用エビデンス

作成する内容:

- GuardDuty Finding確認手順
- アラート受信時の一次確認手順
- 異常判定基準
- セキュリティチームへのエスカレーション基準
- 対応記録の保存項目
- 月次確認から日次または即時対応へ移行する場合の運用整理

成果物:

- セキュリティアラート対応手順書
- 対応記録テンプレート
- 運用試験結果

### 4.3 CloudTrailログ保全強化

対象:

- 3.4: CloudTrail S3バケットのServer Access Logging有効化
- 3.5: CloudTrailログのSSE-KMS/CMK化
- 3.6: カスタマー管理キーのローテーション有効化

注意点:

- CloudTrailログ保存先S3バケットのServer Access Logging保存先をどこにするか決める
- ログ保存先バケットのライフサイクル、保持期間、暗号化を確認する
- CloudTrailがSSE-KMSでログを書き込めるようにKMS Key Policyを設計する
- 運用者がログを読むためのKMS権限を確認する
- CMK削除や無効化に対する監視も必要

成果物:

- CloudTrailログ保全設計
- KMS Key Policy案
- Server Access Logging設定手順
- SSE-KMS設定手順
- ローテーション確認結果
- テスト結果

### 4.4 VPC Flow Logs有効化

対象:

- 3.7: すべてのVPCでVPC Flow Logsが有効であること

確認内容:

- Prod / OPERそれぞれのVPC一覧
- 既存Flow Logsの有無
- 保存先: CloudWatch Logs / S3
- TrafficType: ACCEPT / REJECT / ALL
- Log Format
- 保持期間
- KMS暗号化
- ログ量と料金影響

成果物:

- VPC Flow Logs設定方針
- OPER環境の有効化手順
- テスト結果
- 証跡

### 4.5 CloudWatch監視アラート設定

対象:

- 4.1: 不正なAPI呼び出し
- 4.2: MFAなし管理コンソールサインイン
- 4.3: rootアカウント使用
- 4.4: IAMポリシー変更
- 4.5: CloudTrail設定変更
- 4.6: AWS Management Console認証失敗
- 4.7: CMK無効化または削除予約
- 4.8: S3バケットポリシー変更
- 4.9: AWS Config設定変更
- 4.10: Security Group変更
- 4.11: NACL変更
- 4.12: ネットワークゲートウェイ変更
- 4.13: Route Table変更
- 4.14: VPC変更
- 4.15: AWS Organizations変更

基本方針:

```text
CloudTrail
  ↓
CloudWatch Logs
  ↓
Metric Filter
  ↓
CloudWatch Alarm
  ↓
SNS等の通知先
```

検討事項:

- 4.1〜4.15を個別Metric Filterにするか、カテゴリ単位で統合するか
- Alarmを個別に作るか、重要度別にまとめるか
- 通知先を既存SNSにするか、新規SNSにするか
- 通知本文に必要な情報をどこまで含めるか
- テストイベントを本番で発生させてよいか

成果物:

- Metric Filter設計一覧
- Alarm設計一覧
- 通知先一覧
- テスト観点一覧
- 設定手順
- 変更後証跡

## 5. 週次スケジュール案

### 2026-07-07〜2026-07-10: 計画策定

| 日付 | 作業 |
|---|---|
| 7/7 | 評価シート読み込み、作業群分類、初期計画作成 |
| 7/8 | 既存資料確認、対象環境・対象アカウント確認、質問事項整理 |
| 7/9 | 実装方式の候補整理、工数・順序・リスク確認 |
| 7/10 | 作業計画合意、来週以降の作業順確定 |

成果物:

- 作業計画
- 21項目の分類表
- 現状調査チェックリスト
- 質問事項一覧

### 2026-07-13〜2026-07-17: 現状調査・設計

主な作業:

- Prod / OPERの現状調査
- CloudTrail / CloudWatch Logs連携確認
- 既存Metric Filter / Alarm / SNS確認
- KMS / CloudTrailログS3 / VPC Flow Logs確認
- 4.1〜4.15のMetric Filter候補作成
- GuardDuty手順書構成案作成

成果物:

- 現状調査結果
- 監視設定設計案
- KMS/ログ保全設計案
- 手順書構成案

### 2026-07-21〜2026-07-24: 開発1

7/20が祝日想定のため、作業日は短めに見る。

主な作業:

- 開発環境でCloudWatch Logs Metric Filter作成
- Alarm作成
- SNS通知設定確認
- GuardDuty手順書ドラフト作成
- CloudTrailログS3 Server Access Logging設定案作成
- KMS Key Policy案作成

成果物:

- 開発環境設定
- 通知テスト結果
- 手順書ドラフト
- KMS Key Policy案

### 2026-07-27〜2026-07-31: 開発2・開発環境確認

主な作業:

- 4.1〜4.15の監視設定を横展開
- VPC Flow Logs設定確認
- CloudTrailログSSE-KMS/CMK設定の開発環境テスト
- 設定手順・切り戻し手順作成
- 証跡取得

成果物:

- 開発環境設定完了
- 設定手順書
- 切り戻し手順書
- 開発環境テスト結果

### 2026-08-03〜2026-08-07: テスト1

主な作業:

- 単体テスト
- 通知テスト
- CloudTrailイベント発生確認
- Metric Filter一致確認
- Alarm発報確認
- SNS通知確認
- GuardDuty手順書の机上確認

成果物:

- 単体テスト結果
- 通知テスト証跡
- 不具合一覧

### 2026-08-10〜2026-08-14: テスト2・レビュー準備

8/11が祝日想定のため、作業日は短めに見る。

主な作業:

- 修正後再テスト
- 結合観点の確認
- 運用試験
- 銀行様説明資料の素案作成
- 本番反映手順の初版作成

成果物:

- テスト完了報告
- 運用試験結果
- 銀行様説明資料素案
- 本番反映手順初版

### 2026-08-17〜2026-08-28: レビュー・修正

主な作業:

- リーダーレビュー
- 銀行様レビュー
- ITセキュリティ統括部向け確認
- 指摘修正
- 本番手順確定
- リリース判定材料作成

成果物:

- レビュー反映版手順書
- レビュー反映版設定資料
- 本番作業手順書
- リリース判定資料

### 2026-08-31〜2026-09-11: リリース準備

主な作業:

- 本番反映リハーサル
- 作業者・確認者・承認者の確定
- 本番作業タイムライン確定
- 切り戻し判断基準確定
- 連絡体制確認
- 最終証跡テンプレート確認

成果物:

- 本番作業計画
- リハーサル結果
- 最終版手順書
- 切り戻し手順
- 連絡体制表

### 2026-09-12: 最終リリース

主な作業:

- 本番反映
- 変更後確認
- 通知確認
- 証跡取得
- リリース完了報告

成果物:

- 本番反映証跡
- 変更後確認結果
- 完了報告

## 6. 21項目の作業分類

| 要件 | 分類 | 作業種別 | 難易度 | 注意点 |
|---|---|---|---|---|
| A3 | 運用手順 | 手順書作成 | 中 | 異常判定基準、通知先、エスカレーション |
| A4 | 運用手順 | 記録運用整理 | 低 | A3に含めて対応可能 |
| 3.4 | ログ保全 | S3 Server Access Logging | 中 | 保存先、ログ量、ライフサイクル |
| 3.5 | ログ保全 | CloudTrail SSE-KMS/CMK | 高 | KMS Key Policy、CloudTrail書込権限 |
| 3.6 | ログ保全 | CMKローテーション | 中 | 3.5とセット、対象キー種別確認 |
| 3.7 | ログ保全 | VPC Flow Logs | 中 | OPER環境、保存先、ログ量 |
| 4.1 | 監視 | 不正API呼び出し | 中 | UnauthorizedOperation等の条件確認 |
| 4.2 | 監視 | MFAなしConsoleLogin | 中 | MFA強制済みなら要件確認 |
| 4.3 | 監視 | root使用 | 低 | CloudTrailイベント条件明確 |
| 4.4 | 監視 | IAM Policy変更 | 中 | 対象イベントが多い |
| 4.5 | 監視 | CloudTrail設定変更 | 中 | StopLogging/DeleteTrail等は重要 |
| 4.6 | 監視 | Console認証失敗 | 中 | しきい値・通知頻度確認 |
| 4.7 | 監視 | CMK無効化/削除予約 | 中 | DisableKey/ScheduleKeyDeletion |
| 4.8 | 監視 | S3 Bucket Policy変更 | 低〜中 | PutBucketPolicy/DeleteBucketPolicy |
| 4.9 | 監視 | AWS Config変更 | 中 | Config導入状況確認 |
| 4.10 | 監視 | Security Group変更 | 中 | 変更イベントが多い |
| 4.11 | 監視 | NACL変更 | 中 | 対象VPC確認 |
| 4.12 | 監視 | Network Gateway変更 | 中 | IGW/CGW/VGW/TGW対象範囲確認 |
| 4.13 | 監視 | Route Table変更 | 中 | 0.0.0.0/0やTGW/NAT/Endpoint経路 |
| 4.14 | 監視 | VPC変更 | 中 | Peering含めるか確認 |
| 4.15 | 監視 | Organizations変更 | 中 | 管理アカウント権限確認 |

## 7. 主なリスク

| リスク | 内容 | 対応 |
|---|---|---|
| 権限不足 | CloudTrail、CloudWatch、KMS、Organizationsが見えない | 不足API名、影響タスク、必要理由を整理して相談 |
| 既存通知との重複 | 同じイベントで二重通知になる | 既存Metric Filter、Alarm、EventBridge、SNSを先に棚卸し |
| 通知過多 | Console失敗やAPIエラーが大量通知になる | しきい値、評価期間、重要度別通知を検討 |
| KMS設定不備 | CloudTrailがログを書けない、ログを読めない | 開発環境でKey Policyと書込/読取テスト |
| ログ量増加 | VPC Flow LogsやS3 Access Loggingでコスト増 | 保存先、保持期間、ライフサイクルを設計 |
| 本番テスト制約 | 実イベントを本番で発生させにくい | 開発環境、テストイベント、机上確認を組み合わせる |
| レビュー遅延 | 銀行様、統括部、運用担当レビューに時間がかかる | 8月後半にレビュー期間を確保 |

## 8. 今週の質問事項

| No | 確認したいこと |
|---|---|
| 1 | CloudTrailはProd/OPERそれぞれで既にCloudWatch Logsへ連携済みか |
| 2 | Metric Filter / Alarmの既存設定はあるか |
| 3 | 通知先はSNS、メール、Teams、監視製品、SIEMのどれか |
| 4 | 4.1〜4.15はCloudWatch Metric Filter方式で統一する認識でよいか |
| 5 | EventBridge方式は許容されるか、またはCloudWatch Alarm指定か |
| 6 | 開発環境で本番相当のテストが可能か |
| 7 | KMS CMKは新規作成か、既存キー利用か |
| 8 | KMS Key Policyのレビュー担当は誰か |
| 9 | VPC Flow Logsの保存先はCloudWatch LogsかS3か |
| 10 | ログ保持期間、ライフサイクル、暗号化要件はあるか |
| 11 | Organizations変更監視は管理アカウント側で設定する必要があるか |
| 12 | 本番作業はGUI、CLI、IaC、申請ツールのどれで行うか |

## 9. 直近の進め方

今週は設定作業に入るより、以下を優先する。

1. 21項目を正式な作業一覧に整える
2. 既存環境の確認観点をまとめる
3. CloudWatch監視設定の共通テンプレート方針を決める
4. KMS/CloudTrailログ/VPC Flow Logsの個別リスクを整理する
5. 来週から開発に入れるように、確認事項と不足権限を洗い出す

現場向けの説明例:

```text
今週は、21項目を運用手順、ログ保全、監視アラートの3系統に分け、
既存設定の棚卸しと実装方式の確認を行います。
来週以降は、CloudTrail/CloudWatch Logs/Metric Filter/Alarmを中心に開発環境で設定・テストし、
8月前半に通知テストと運用試験、9月12日のリリースに向けてレビューと本番手順確定を進めます。
```

