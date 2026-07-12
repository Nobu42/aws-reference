# 先行テスト作業候補

作成日: 2026-07-07

この資料は、AWSセキュリティ監査指摘対応を本格的に進める前に、影響が小さく、作業の流れを確認しやすい項目を先行テストとして実施するための整理である。

## 1. 目的

いきなり全要件を横展開するのではなく、まず1〜2件をパイロット作業として実施し、以下を確認する。

- 既存CloudTrail / CloudWatch Logs連携の状態
- Metric Filter / Alarm / SNS通知の作成手順
- テストイベントの発生方法
- 通知確認方法
- 証跡取得方法
- 作業手順書と切り戻し手順の粒度
- 権限不足やレビュー観点
- 4.1〜4.15へ横展開できる共通テンプレート

## 2. 結論

最初のパイロット作業としては、以下の順で検討する。

| 優先 | 要件番号 | 要件 | 推奨度 | 理由 |
|---|---|---|---|---|
| 1 | 4.8 | S3バケットポリシーの変更が監視されていること | 高 | イベント名が明確で、業務影響が小さく、テストしやすい |
| 2 | 4.5 | CloudTrailの設定変更が監視されていること | 高 | ログ保全の観点で重要。監査上の説明もしやすい |
| 3 | 4.7 | 顧客が作成したCMKの無効化またはスケジュールされた削除が監視されていること | 中 | 重要だがKMS絡みのため、Key Policyや権限確認後が安全 |

最初の1件としては、**4.8 S3バケットポリシー変更監視** が最も扱いやすい。

## 3. 最初に4.8を推奨する理由

### 3.1 業務影響が比較的小さい

4.8は、S3バケットポリシーの変更イベントを検知して通知する監視設定である。
基本的には、CloudTrailログをもとにCloudWatch LogsのMetric FilterやAlarmを追加する作業であり、既存アプリケーションの通信経路やデータ処理を直接変更しない。

注意点はあるが、SSE-KMS化やVPC Flow Logs有効化と比べると、業務影響は小さめである。

### 3.2 CloudTrailイベント名が明確

S3バケットポリシー変更で見る主なCloudTrail EventNameは以下。

| 操作 | CloudTrail EventName |
|---|---|
| バケットポリシー作成・更新 | `PutBucketPolicy` |
| バケットポリシー削除 | `DeleteBucketPolicy` |

イベント条件が明確なため、Metric FilterやEventBridge Patternの設計がしやすい。

### 3.3 テストしやすい

開発環境や検証用バケットで、バケットポリシーを一時的に変更し、CloudTrailに `PutBucketPolicy` を記録させることでテストできる。

本番で直接テストする場合は承認が必要だが、検証環境があれば比較的安全にテストできる。

### 3.4 横展開しやすい

4.8で以下の流れを確認できれば、4.1〜4.15の多くに横展開できる。

```text
CloudTrailイベント発生
  ↓
CloudWatch Logsへ配送
  ↓
Metric Filterで検知
  ↓
CloudWatch Alarm発報
  ↓
SNS等へ通知
  ↓
証跡取得
```

## 4. パイロット作業候補1: 4.8 S3バケットポリシー変更監視

### 4.1 作業概要

S3バケットポリシーの変更イベントをCloudTrailで記録し、CloudWatch Logs Metric FilterとCloudWatch Alarmで検知・通知する。

対象イベント:

```text
PutBucketPolicy
DeleteBucketPolicy
```

### 4.2 実施する作業

| No | 作業 | 内容 |
|---|---|---|
| 1 | 現状確認 | CloudTrail、CloudWatch Logs連携、既存Metric Filter、既存Alarm、SNS通知先を確認 |
| 2 | 対象決定 | 対象S3バケット、対象環境、通知先を確認 |
| 3 | Metric Filter設計 | `PutBucketPolicy` / `DeleteBucketPolicy` を拾うFilter Patternを作成 |
| 4 | Alarm設計 | 1回以上検知したら発報するAlarmを作成 |
| 5 | 通知設定 | 既存SNS Topicまたは指定通知先へ紐づけ |
| 6 | テスト | 検証用バケットでポリシー変更イベントを発生させ、通知を確認 |
| 7 | 証跡取得 | 変更前、設定内容、テスト結果、通知結果、CloudTrailイベントを保存 |
| 8 | 切り戻し確認 | Metric Filter / Alarmの削除または無効化手順を確認 |

### 4.3 想定するMetric Filter条件

CloudWatch Logs Metric Filterのイメージ。

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

注意:

- 実際のCloudTrailログの形に合わせて調整する
- 特定バケットに絞る場合は `requestParameters.bucketName` 等を確認する
- まずは広めに検知し、通知量を見てから絞る方が安全な場合がある

### 4.4 テスト方法

検証環境がある場合:

```text
1. 検証用S3バケットを選定
2. 現在のBucket Policyを保存
3. 軽微なPolicy変更または同等内容の再適用を実施
4. CloudTrailにPutBucketPolicyが記録されることを確認
5. CloudWatch Logs Metric Filterが一致することを確認
6. CloudWatch Alarmが発報することを確認
7. SNS等へ通知されることを確認
8. Bucket Policyを元に戻す
```

本番環境で実施する場合:

- 事前承認を取る
- 対象バケットと変更内容を明確にする
- 変更前Policyを必ず保存する
- 切り戻し手順を用意する
- 業務時間外または影響が少ない時間帯を検討する

### 4.5 成果物

- 現状確認結果
- Metric Filter設定内容
- Alarm設定内容
- 通知先設定
- テスト結果
- CloudTrailイベント証跡
- 通知受信証跡
- 切り戻し手順
- 横展開用テンプレート

## 5. パイロット作業候補2: 4.5 CloudTrail設定変更監視

### 5.1 作業概要

CloudTrailの設定変更、停止、削除などを検知して通知する。

対象イベント例:

| 操作 | CloudTrail EventName |
|---|---|
| Trail作成 | `CreateTrail` |
| Trail更新 | `UpdateTrail` |
| Trail削除 | `DeleteTrail` |
| ログ記録開始 | `StartLogging` |
| ログ記録停止 | `StopLogging` |
| Event Selector変更 | `PutEventSelectors` |

### 5.2 推奨理由

CloudTrailは監査証跡の中心であり、設定変更や停止を検知することは監査上の重要度が高い。
また、CloudTrail関連イベントはCloudTrail自身に記録されるため、監査指摘の説明がしやすい。

### 5.3 注意点

実際に `StopLogging` や `DeleteTrail` を本番で発生させるテストは避けるべきである。
テスト方法は検証環境での実施、またはMetric Filterのパターンテスト、過去イベントの利用を検討する。

### 5.4 実施する作業

| No | 作業 | 内容 |
|---|---|---|
| 1 | 現状確認 | 既存Trail、CloudWatch Logs連携、既存監視を確認 |
| 2 | Metric Filter設計 | CloudTrail設定変更イベントを検知するFilter Patternを作成 |
| 3 | Alarm設計 | 検知時にAlarm発報 |
| 4 | 通知設定 | SNS等へ通知 |
| 5 | テスト | 検証環境または過去ログ/テストパターンで確認 |
| 6 | 証跡取得 | 設定、テスト、通知結果を保存 |

## 6. パイロット作業候補3: 4.7 CMK無効化/削除予約監視

### 6.1 作業概要

顧客が作成したCMK、現在の表現ではカスタマー管理キーが無効化された場合、または削除予約された場合に検知して通知する。

対象イベント:

| 操作 | CloudTrail EventName |
|---|---|
| KMSキー無効化 | `DisableKey` |
| KMSキー削除予約 | `ScheduleKeyDeletion` |

### 6.2 推奨理由

CMKが無効化または削除されると、暗号化データを復号できなくなる可能性がある。
CloudTrailログSSE-KMS化とも関係するため、監査上の重要度が高い。

### 6.3 最初の1件としては少し慎重にしたい理由

KMSはKey Policyや利用権限の確認が必要で、誤設定時の影響が大きい。
また、本番で `DisableKey` や `ScheduleKeyDeletion` を発生させるテストは避けるべきである。

そのため、最初のパイロットとしては4.8または4.5を先に実施し、監視設定の流れを確認した後に4.7へ進む方が安全である。

## 7. 4.1〜4.9をまとめて実施するか

### 7.1 設計はまとめて実施する

4.1〜4.9は、CloudTrailイベントをCloudWatch Logs Metric Filterで検知し、Alarmで通知するという共通構成を使える可能性が高い。
そのため、設計、命名規則、通知先、証跡取得方式はまとめて検討するのがよい。

まとめて検討するもの:

- Metric Filter命名規則
- Metric Namespace
- Metric Name
- Alarm命名規則
- SNS Topic
- 通知先
- しきい値
- 評価期間
- 証跡保存形式
- テスト方法

### 7.2 実装・テストはいきなり全部まとめない

いきなり4.1〜4.9をまとめて実装すると、以下のリスクがある。

- 通知が多すぎる
- Filter Patternの誤りに気づきにくい
- 既存通知との重複が分かりにくい
- テスト証跡が整理しづらい
- 切り戻し範囲が広くなる

そのため、まず1件をパイロットとして実施し、テンプレートを固めてから横展開する。

## 8. 推奨する進め方

```text
1. 4.8 S3バケットポリシー変更監視をパイロット候補にする
2. 既存CloudTrail / CloudWatch Logs / Metric Filter / Alarm / SNSを確認
3. 開発環境または検証用バケットでテストする
4. 設定手順、証跡取得、通知確認、切り戻し手順を固める
5. 4.1〜4.9の設計を共通化する
6. 4.5、4.7など重要度の高い項目へ横展開する
7. 4.10以降のネットワーク系監視へ展開する
```

## 9. リーダー・PM向け説明文

```text
最初の作業としては、業務影響が比較的小さく、CloudTrailイベント名が明確な
4.8「S3バケットポリシー変更監視」をパイロットにするのがよいと考えています。

この作業で、CloudTrail、CloudWatch Logs、Metric Filter、Alarm、SNS通知、証跡取得、切り戻しの一連の流れを確認できます。
その結果をテンプレート化し、4.1〜4.9のCloudTrail系監視へ横展開する進め方が安全だと思います。

4.1〜4.9は設計と命名規則はまとめて検討し、実装・テストはまず1件パイロット、その後に横展開する方針にしたいです。
```

## 10. 確認事項

パイロット作業前に確認する。

| 確認事項 | 理由 |
|---|---|
| 4.8をパイロットにしてよいか | 最初に試す要件番号の合意 |
| 検証環境または検証用S3バケットがあるか | 安全にテストするため |
| CloudTrailはCloudWatch Logsへ連携済みか | Metric Filter方式の前提 |
| 既存Metric Filter / Alarm / SNSがあるか | 重複回避 |
| 通知先はどこか | Alarm Action設定に必要 |
| 本番でテストイベントを発生させてよいか | テスト方式に影響 |
| 証跡保存先はどこか | 作業後のエビデンス整理 |
| 切り戻し手順のレビュー担当は誰か | 安全に進めるため |

