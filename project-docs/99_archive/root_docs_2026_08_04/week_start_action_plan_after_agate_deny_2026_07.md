# 週初め対応メモ A-gate explicit deny後の進め方

作成日: 2026-07-26

対象: クラウドセキュリティ対応 全要件

## 1. 背景

先行作業でCloudTrailからCloudWatch Logsへの連携を有効化しようとした際、A-gateポリシーによる明示的拒否が発生した。

この事象により、従来の前提である「業務側がWebコンソールで直接設定変更する」方式は再確認が必要となった。

今後は、各要件を以下の実行経路に分類して進める。

| 区分 | 内容 | 主な担当 |
| :--- | :--- | :--- |
| A-gate対応済み | 既存A-gate / EventBridge / 既存監視基盤で要件を満たす | A-gate / 基盤 / 業務側確認 |
| A-gate側作業 | A-gate側または基盤側で設定変更する | A-gate / 基盤 |
| 申請後に業務側作業 | A-gate申請、権限付与、Deny解除後に業務側が設定変更する | 業務側 |
| 業務側で対応可能 | 統制対象外または参照・資料整理のみで完了する | 業務側 |
| 確認待ち | 実行経路、作業主体、権限、既存監視との重複が未確定 | PM / リーダー / A-gate / 基盤 |

## 2. 週初めに最初にやること

| 優先度 | 作業 | 目的 | 成果物 |
| :--- | :--- | :--- | :--- |
| 高 | A-gate explicit denyの証跡整理 | 事象を正確に共有する | エラー画面、エラー文言、発生日時、対象アカウント、対象リージョン、対象Trail、操作内容 |
| 高 | PM、リーダーへ状況再共有 | 作業前提の変更を合意する | 共有メモ、判断待ち一覧 |
| 高 | A-gate回答待ち事項の一覧化 | 回答待ちで作業が止まる範囲を明確化する | A-gate確認事項一覧 |
| 高 | WBSの見直し方針を提示 | スケジュールと作業主体を現実に合わせる | WBS修正方針 |
| 高 | 全要件の実行経路再分類 | 直接変更、A-gate対応、対応不要、確認待ちを分ける | 要件別対応方式一覧 |
| 中 | A-gate回答なしでも進められる作業に着手 | 待ち時間を減らす | 設定値案、手順書、確認手順、証跡テンプレート |
| 中 | 既存A-gate / EventBridge対応済み要件の根拠整理 | 追加対応不要の説明材料を作る | 対応不要根拠一覧 |
| 中 | A-gate側へ渡す変更パラメータ整理 | A-gate側作業になった場合に即依頼できる状態にする | A-gate依頼用パラメータ表 |

## 3. PM、リーダーへ伝えること

### 3.1 状況報告

```text
先行作業でCloudTrailからCloudWatch Logsへの連携を有効化しようとしたところ、
A-gateポリシーによる明示的拒否が発生。

単なるAllow不足ではなくexplicit denyのため、作業者側では回避不可。
現在、A-gate側へ以下を確認中。

1. A-gate側でCloudWatch Logs連携を設定できるか
2. 申請により業務側で設定変更できるようにするのか
3. 既存A-gate / EventBridge通知で対応済みとして扱うのか
```

### 3.2 作業方針

```text
A-gate回答待ちの間、全要件を
「A-gate対応済み」
「A-gate/基盤側作業」
「申請後に業務側作業」
「業務側で対応可能」
「確認待ち」
に再分類する。

WBSも、単純な設定作業ではなく、
実行経路確認、A-gate/基盤側依頼、変更後確認、通知確認、証跡整理を含む形へ修正する。
```

### 3.3 確認したいこと

```text
今回のクラウドセキュリティ対応について、
CloudTrail、CloudWatch Logs、IAM Role、KMS、S3 Server Access Logging、VPC Flow Logs、Metric Filter、Alarmの変更は、
業務側が直接実施してよい範囲なのか、
A-gate/基盤側で実施する範囲なのかを確認する。

また、既存A-gate / EventBridgeで検知・通知済みの要件は、
新規CloudWatch Logs / Metric Filter / Alarm作成なしで対応済みとしてよいか確認する。
```

## 4. WBS修正ポイント

現行WBSは2026-07-17時点の整理であり、4.5/4.7先行作業を業務側で開発環境設定テストする前提が含まれている。

今回のA-gate explicit denyを受け、以下を追加または修正する。

| 修正対象 | 修正内容 | 理由 |
| :--- | :--- | :--- |
| WBS-1 初動整理 | A-gate統制確認、explicit deny証跡整理、実行経路確認を追加 | 作業主体が未確定になったため |
| WBS-2 先行作業 | 4.5/4.7の開発環境設定テストを「A-gate回答待ち」「実行経路確定後」に変更 | CloudWatch Logs連携がA-gateで拒否されたため |
| WBS-2 先行作業 | 「A-gate側作業依頼パラメータ作成」を追加 | A-gate/基盤側作業になる可能性が高いため |
| WBS-2 先行作業 | 「設定後確認」「通知到達確認」「証跡整理」を業務側作業として明確化 | 直接変更できなくても確認作業は残るため |
| WBS-3 対応不要整理 | 既存A-gate / EventBridge対応済み要件の根拠整理を強化 | 新規作成不要の説明責任が残るため |
| WBS-4 横展開 | 4番台全体をA-gate対応済み、A-gate/基盤側作業、業務側作業に再分類 | CloudWatch Logs連携前提の横展開が成立しない可能性があるため |
| WBS-5 仕上げ | 3.4 Server Access Logging、3.5/3.6 KMS、3.7 VPC Flow LogsにもA-gate統制確認を追加 | これらも基盤統制対象の可能性があるため |
| WBS-6 8月作業 | 設定作業日ではなく「実行経路確定後の設定・確認・証跡取得」と表現を変更 | 作業主体が業務側とは限らないため |
| WBS-8 テストリハ | A-gate/基盤側作業後の確認リハ、通知確認リハを追加 | 業務側が実作業しない場合でも確認リハが必要なため |
| WBS-9 リリース準備 | A-gate/基盤側作業依頼、承認、作業主体、連絡経路を追加 | 本番直前に作業主体が未確定だと危険なため |

## 5. WBSに追加するステータス案

| ステータス | 意味 |
| :--- | :--- |
| A-gate回答待ち | A-gate側の回答がないと実行経路が決まらない |
| 実行経路確認中 | 業務側、A-gate側、基盤側のどこが作業するか確認中 |
| A-gate対応済み | 既存A-gate / EventBridge / 既存監視基盤で要件を満たす |
| A-gate/基盤側作業 | 業務側では直接変更せず、A-gateまたは基盤側で変更する |
| 申請後業務側作業 | A-gate申請後に業務側が設定変更する |
| 業務側確認のみ | 設定変更は行わず、変更後確認、通知確認、証跡整理を行う |
| 対応不要 | 追加設定不要。根拠を残す |

## 6. 全要件の再分類

現時点の仮分類である。A-gate回答、基盤側回答、PM判断により更新する。

| 要件 | 内容 | 現時点の見立て | A-gate回答なしで進められる作業 | A-gate回答が必要な作業 |
| :--- | :--- | :--- | :--- | :--- |
| A3 | セキュリティアラート監視運用 | 業務側で資料整理可能 | 既存手順、月次運用、検知後対応、エスカレーション、記録様式の整理 | A-gate通知を正式運用に含める場合の通知経路確認 |
| A4 | セキュリティアラート対応手順 | 業務側で資料整理可能 | GuardDuty等の検知後手順、一次確認、連絡先、証跡様式の整理 | A-gate側の検知・通知・対応運用を含める場合の確認 |
| 3.4 | CloudTrailログ保存先S3のServer Access Logging | A-gate/基盤統制対象の可能性あり | 現状確認、Source bucket、Target bucket、prefix、保存先権限、費用影響、手順書作成 | Server Access Logging有効化を誰が実施するか |
| 3.5 | CloudTrailログのCMK暗号化 | A-gate/基盤統制対象の可能性が高い | 対象Trail、対象S3 bucket、既存KMS、Key Policy、設定値案、手順書作成 | CMK作成、Key Policy変更、Trail暗号化設定を誰が実施するか |
| 3.6 | CMKローテーション有効化 | A-gate/基盤統制対象の可能性あり | 対象CMK、Rotation状態、現行Key Policy、設定値案、手順書作成 | Rotation有効化を誰が実施するか |
| 3.7 | VPC Flow Logs有効化 | A-gate/基盤統制対象の可能性あり | 対象VPC一覧、既存Flow Logs、保存先、IAM Role、費用影響、手順書作成 | Flow Logs作成を誰が実施するか |
| 4.1 | 不正なAPI呼び出し監視 | CloudWatch Logs連携に依存 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.2 | MFAなしConsoleLogin監視 | CloudWatch Logs連携に依存 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.3 | rootアカウント使用監視 | CloudWatch Logs連携に依存 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.4 | IAMポリシー変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.5 | CloudTrail設定変更監視 | 先行作業。A-gate回答待ち | Filter Pattern案、設定値、手順書、UpdateTrail確認観点、証跡整理 | CloudTrail -> CloudWatch Logs連携方法、実行主体 |
| 4.6 | Console認証失敗監視 | CloudWatch Logs連携に依存 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.7 | CMK無効化・削除予約監視 | 先行作業。A-gate回答待ち | Filter Pattern案、テストCMK案、手順書、証跡整理 | KMS操作可否、テストCMK作成可否、Metric Filter/Alarm作成可否 |
| 4.8 | S3バケットポリシー変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.9 | AWS Config変更監視 | CloudWatch Logs連携に依存 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.10 | Security Group変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.11 | NACL変更監視 | CloudWatch Logs連携に依存、既存監視確認要 | Filter Pattern案、Metric/Alarm名、通知先、サンプルログ、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否 |
| 4.12 | Network Gateway変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.13 | Route Table変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.14 | VPC変更監視 | 既存A-gate / EventBridge対応済み候補 | 対応不要根拠、既存Rule、通知経路、対象イベントの証跡整理 | 対応済みとしてよいかの正式判断 |
| 4.15 | AWS Organizations変更監視 | CloudWatch Logs連携に依存、管理アカウント確認要 | Filter Pattern案、対象アカウント、管理アカウント側確認観点、手順書作成 | CloudWatch Logs連携、Metric Filter/Alarm作成可否、管理アカウントでの実行要否 |

## 7. A-gate回答なしでも対応できそうな作業

| 作業 | 対象 | 具体内容 |
| :--- | :--- | :--- |
| 対応不要根拠整理 | 4.4、4.8、4.10、4.12、4.13、4.14 | 既存A-gate / EventBridgeのRule名、対象イベント、Target、通知経路、確認日、判断者を整理する |
| 設定値案の整備 | 4.1〜4.15 | Metric Filter名、Metric Namespace Custom、Metric Name、Alarm名、Filter Pattern、通知先Topicを整理する |
| 手順書の分岐化 | 全要件 | A-gate側作業、申請後業務側作業、対応不要、確認のみの4パターンに分ける |
| 証跡テンプレート作成 | 全要件 | 作業前、作業後、通知、対応不要根拠、A-gate回答、未実施理由の証跡名を整理する |
| A-gate依頼パラメータ作成 | 3.4〜3.7、4.5、4.7、4番台 | A-gate/基盤側へ渡す対象リソース、設定値、期待状態、確認方法を整理する |
| 通知確認観点整理 | 4番台、A3/A4 | メール、Teams、A-gate、SNS、EventBridge、監視基盤の到達確認方法を整理する |
| WBS修正案作成 | 全要件 | 実行経路確認、A-gate回答待ち、A-gate/基盤側作業、業務側確認のみのタスクを追加する |
| PM確認待ち一覧更新 | 全要件 | 要件番号、確認内容、判断理由、影響、期限、回答者を一覧化する |

## 8. A-gate回答がないと進めにくい作業

| 作業 | 理由 |
| :--- | :--- |
| CloudTrailからCloudWatch Logsへの連携有効化 | explicit denyで拒否済み。実行主体が未確定 |
| CloudTrail配信用IAM Role新規作成 | IAM Role作成、PassRole、Role PolicyがA-gate統制対象の可能性が高い |
| Metric Filter / Alarmの新規作成 | CloudWatch Logs連携が未確定。CloudWatch変更権限も要確認 |
| KMSテストCMK作成、DisableKey、ScheduleKeyDeletion | KMS操作は統制対象の可能性が高く、誤操作影響も大きい |
| S3 Server Access Logging有効化 | S3 bucket設定変更もA-gate統制対象の可能性がある |
| VPC Flow Logs有効化 | VPC、IAM Role、Log Group、S3保存先が絡むため基盤側作業の可能性がある |
| 本番作業手順確定 | 実行主体、承認経路、作業者、確認者が未確定 |

## 9. 週初めの作業順

1. A-gate explicit denyの証跡を整理する。
2. PM、リーダーへ状況、影響、WBS修正方針を共有する。
3. A-gate回答待ち事項を一覧化する。
4. WBSに「A-gate回答待ち」「実行経路確認」「A-gate/基盤側作業」「業務側確認のみ」を追加する。
5. 全要件を実行経路別に再分類する。
6. A-gate回答なしでも進められる資料整理、対応不要根拠整理、パラメータ整理を進める。
7. A-gate回答後、手順書をA-gate側作業版または申請後業務側作業版へ更新する。

## 10. 週初めの一言メモ

```text
先行作業でA-gateの明示的拒否が出たため、作業前提を見直す。
設定値や手順書の作成は継続するが、実際の設定変更は
「業務側で直接実施」
「A-gate/基盤側で実施」
「既存A-gate対応済みで追加作業なし」
のどれに該当するかを要件番号ごとに再分類する。

WBSも、直接設定作業ではなく、実行経路確認、A-gate/基盤側依頼、設定後確認、通知確認、証跡整理を含む形へ修正する。
```
