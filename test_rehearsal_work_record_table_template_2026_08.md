# 全要件 テストリハ作業記録表テンプレート

作成日: 2026-07-31

対象: 3.4、3.5、3.6、3.7、4.1〜4.15

対象外: A3、A4

## 1. 使い方

この資料は、テストリハ当日の作業実績を記録するためのテンプレートである。

作業手順書と同じく、Excelへ貼り付けやすいTSV形式とする。

列構成は `要件番号`、`作業内容`、`作業時間`、`作業記録`、`備考` の5列とする。

`作業記録` には、開始時刻、終了時刻、結果、証跡ファイル名、未実施理由、判断者、切り戻し有無を記録する。

## 2. 記入ルール

```text
結果:
OK        作業完了、確認完了
NG        作業失敗、想定外エラー
保留      判断待ち、確認待ち、配信待ち
未実施    対象外、A-gate対応済み、承認未取得、権限不足など

切り戻し:
なし      切り戻し不要
あり      切り戻し実施済み
不要      変更なし、確認のみ、未実施など

証跡:
証跡ファイル名を記載する。
複数ある場合はカンマ区切りで記載する。
メールアドレス、アカウントID、IPアドレスなどは必要に応じてマスクする。
```

## 3. 作業記録表

```tsv
要件番号	作業内容	作業時間	作業記録	備考
共通	作業開始前確認	予定10分 / 実績: 開始= / 終了=	結果= / 作業申請= / 作業開始承認= / 対象環境= / 対象アカウント= / 対象リージョン= / 作業者= / 確認者= / 連絡先= / 通知テスト承認= / 切り戻し判断者= / 証跡= / 切り戻し=不要	開始承認、通知テスト承認、判断者が未確定の場合は開始しない。
共通	AWSログイン、アカウント、リージョン確認	予定5分 / 実績: 開始= / 終了=	結果= / 確認アカウント= / 確認リージョン= / 証跡=01_共通_アカウントリージョン確認_202608XX.png / 切り戻し=不要	対象外アカウントまたは対象外リージョンの場合は作業中断。
共通	変更パラメータ一覧確認	予定10分 / 実績: 開始= / 終了=	結果= / 参照資料名= / 参照版数= / 確認した項目=対応区分,対象リソース,Trail名,Log Group名,IAM Role名,Metric Namespace,Metric Name,Alarm名,SNS Topic ARN,KMS Key,S3 bucket,VPC ID / 差異= / 証跡= / 切り戻し=不要	変更パラメータ一覧の値を正として記録する。
共通	A-gate / EventBridge対応区分確認	予定10分 / 実績: 開始= / 終了=	結果= / 対応なし要件= / 新規対応要件= / A-gate回答= / EventBridge確認結果= / 証跡=08_共通_EventBridgeルール一覧_202608XX.png,09_共通_EventBridge対象ルール詳細_202608XX.png / 切り戻し=不要	対応なし要件は根拠を記録する。
共通	CloudTrail現状確認	予定10分 / 実績: 開始= / 終了=	結果= / Trail名= / ログ記録状態= / Multi-region= / Event selectors= / CloudWatch Logs連携= / 証跡=02_共通_CloudTrail証跡詳細_202608XX.png,03_共通_CloudTrailイベントセレクタ_202608XX.png / 切り戻し=不要	対象Trailが違う場合は作業中断。
共通	CloudTrailからCloudWatch Logsへの連携設定	予定25分 / 実績: 開始= / 終了=	結果= / Log Group= / IAM Role= / 変更前= / 変更後= / エラー= / 証跡=04_共通_CloudWatchLogs連携状態_202608XX.png / 切り戻し=	設定保存時にA-gate explicit denyまたはAccessDeniedが出た場合はエラー画面を保存し作業停止。
共通	IAM Role確認	予定10分 / 実績: 開始= / 終了=	結果= / Role名= / Trust policy確認= / Permission確認= / 権限不足= / 証跡= / 切り戻し=不要	権限不足で確認できない場合は権限保持者へ確認依頼。
共通	CloudWatch Logs到達確認	予定20分 / 実績: 開始= / 終了=	結果= / Log Group= / Log Stream= / 最新イベント時刻= / ログ未到達理由= / 証跡=05_共通_CloudWatchLogsログ到達確認_202608XX.png,42_共通_ログ未到達確認_202608XX.png / 切り戻し=不要	ログ未到達の場合はMetric Filter作成へ進まない。
共通	SNS Topic確認	予定10分 / 実績: 開始= / 終了=	結果= / Topic名= / Topic ARN= / Subscription状態= / 通知先= / 証跡=06_共通_SNSTopic詳細_202608XX.png,07_共通_SNSTopicSubscription確認_202608XX.png / 切り戻し=不要	通知先情報は必要に応じてマスクする。
共通	Metric Filter一括設定	予定60分 / 実績: 開始= / 終了=	結果= / 作成要件= / スキップ要件= / Log Group= / Namespace=Custom / 差異= / 証跡=10_共通_MetricFilter一覧_202608XX.png,28_4番台_MetricFilter一覧_202608XX.png,29_4.X_MetricFilter詳細_202608XX.png,30_4.X_MetricFilterパターンテスト結果_202608XX.png / 切り戻し=	詳細はメトリックフィルター詳細手順書を参照する。
共通	CloudWatch Alarm作成	予定45分 / 実績: 開始= / 終了=	結果= / 作成Alarm= / スキップAlarm= / Namespace=Custom / 通知先SNS Topic= / 差異= / 証跡=11_共通_CloudWatchAlarm一覧_202608XX.png,31_4番台_CloudWatchAlarm一覧_202608XX.png,32_4.X_CloudWatchAlarm詳細_202608XX.png,33_4.X_Alarm通知アクション確認_202608XX.png / 切り戻し=	詳細は変更パラメータ一覧を正とする。
共通	Alarmテスト	予定60分 / 実績: 開始= / 終了=	結果= / テスト対象Alarm= / テスト方式=実イベントまたは代替確認 / 通知結果= / 通知確認者= / Alarm履歴= / 証跡=12_共通_通知受信確認_202608XX.png,34_4.X_Alarmテスト結果_202608XX.png / 切り戻し=	詳細はアラームテスト詳細手順書を参照する。影響が大きい実イベントは無理に発生させない。
3.4	CloudTrailログ保存先S3バケットのServer Access Logging設定	予定40分 / 実績: 開始= / 終了=	結果= / Source bucket= / Target bucket= / Target prefix= / 変更前= / 変更後= / 証跡=15_3.4_ServerAccessLogging変更前_202608XX.png,16_3.4_ServerAccessLogging変更後_202608XX.png / 切り戻し=	Target bucketをSource bucket自身にしない。
3.4	Server Access Logging配信確認	予定20分 / 実績: 開始= / 終了=	結果= / Target bucket= / Target prefix= / ログ配信有無= / 配信待ち判断= / 証跡=17_3.4_ServerAccessLogging配信確認_202608XX.png / 切り戻し=不要	Server Access Loggingは即時配信ではない。
3.5	CloudTrailログ暗号化用CMK確認	予定25分 / 実績: 開始= / 終了=	結果= / CMK Alias= / Key ID= / Key state= / Key policy確認= / 証跡=18_3.5_CMK詳細_202608XX.png,19_3.5_CMKKeyPolicy確認_202608XX.png / 切り戻し=不要	CMK権限不備はCloudTrailログ配信やログ参照に影響する。
3.5	CloudTrailログのCMK暗号化設定	予定35分 / 実績: 開始= / 終了=	結果= / Trail名= / KMS Key変更前= / KMS Key変更後= / エラー= / 証跡=20_3.5_CloudTrailKMS設定変更前_202608XX.png,21_3.5_CloudTrailKMS設定変更後_202608XX.png / 切り戻し=	既存ログは自動で再暗号化されない。
3.5	CloudTrailログのCMK暗号化確認	予定25分 / 実績: 開始= / 終了=	結果= / Trail status= / S3ログオブジェクト= / 暗号化方式= / KMS Key= / 証跡=22_3.5_CloudTrailログSSEKMS確認_202608XX.png / 切り戻し=不要	新規ログオブジェクトで確認する。
3.6	カスタマー管理対称CMKのローテーション有効化	予定15分 / 実績: 開始= / 終了=	結果= / CMK Alias= / 変更前Rotation= / 変更後Rotation= / 証跡=23_3.6_CMKローテーション変更前_202608XX.png,24_3.6_CMKローテーション変更後_202608XX.png / 切り戻し=	AWS管理キーは対象外。
3.7	VPC Flow Logs有効化	予定40分 / 実績: 開始= / 終了=	結果= / VPC ID= / Filter= / Destination= / Log GroupまたはS3 bucket= / IAM Role= / 変更前= / 変更後= / 証跡=25_3.7_VPCFlowLogs変更前_202608XX.png,26_3.7_VPCFlowLogs変更後_202608XX.png / 切り戻し=	削除予定VPCや不要VPCは対象外。
3.7	VPC Flow Logs配信確認	予定20分 / 実績: 開始= / 終了=	結果= / Flow Log ID= / Status= / 配信先= / ログ配信有無= / 証跡=27_3.7_VPCFlowLogs配信確認_202608XX.png / 切り戻し=不要	保存先権限、IAM Role、KMS暗号化の設定不備で配信されない場合がある。
4-G	4番台全体の設定値確認	予定20分 / 実績: 開始= / 終了=	結果= / 確認要件=4.1〜4.15 / Filter Pattern差異= / Metric差異= / Alarm差異= / 通知先差異= / 未実施理由= / 証跡=28_4番台_MetricFilter一覧_202608XX.png,31_4番台_CloudWatchAlarm一覧_202608XX.png / 切り戻し=不要	詳細はメトリックフィルター詳細手順書とアラームテスト詳細手順書を正とする。
4-G	4番台全体の通知受信確認	予定20分 / 実績: 開始= / 終了=	結果= / 通知確認者= / 通知先= / 通知到達= / 通知本文確認= / 証跡=12_共通_通知受信確認_202608XX.png / 切り戻し=不要	通知が届かない場合はSNS Subscription、Alarm Action、Metric Filter一致条件を確認する。
4-G	4番台全体の作業後証跡取得	予定30分 / 実績: 開始= / 終了=	結果= / 取得済み証跡= / 不足証跡= / 追加取得要否= / 証跡= / 切り戻し=不要	作業前後比較、設定値、通知到達を証跡として残す。
共通	変更後設定値突合	予定20分 / 実績: 開始= / 終了=	結果= / 変更パラメータ一覧との差異= / 差異内容= / 判断者= / 対応方針= / 証跡= / 切り戻し=	差異がある場合は判断者と対応方針を残す。
共通	CloudTrail作業証跡確認	予定15分 / 実績: 開始= / 終了=	結果= / 確認イベント=UpdateTrail,PutMetricFilter,PutMetricAlarm,KMS操作,S3 Logging変更,Flow Logs作成 / Event history表示有無= / 証跡=13_共通_CloudTrail作業イベント履歴_202608XX.png / 切り戻し=不要	Event historyの反映には遅延がある。
共通	切り戻し判断	予定10分 / 実績: 開始= / 終了=	結果= / 切り戻し要否= / 判断者= / 判断理由= / 対象設定= / 証跡= / 切り戻し=	既存設定は削除しない。
共通	切り戻し作業	予定40分 / 実績: 開始= / 終了=	結果= / 実施内容= / Alarm= / Metric Filter= / Server Access Logging= / CloudTrail KMS= / Flow Logs= / CMK CancelKeyDeletion= / 証跡=14_共通_切り戻し後確認_202608XX.png / 切り戻し=あり	今回作成または変更した設定のみを対象にする。
共通	証跡ファイル確認	予定20分 / 実績: 開始= / 終了=	結果= / 証跡保存先= / 不足証跡= / マスク要否= / 追加取得= / 証跡= / 切り戻し=不要	証跡不足はレビュー指摘になりやすい。
共通	未実施項目整理	予定15分 / 実績: 開始= / 終了=	結果= / 未実施要件= / 理由=A-gate対応済み,権限不足,承認未取得,配信遅延,実イベント未実施,対象外環境 / 判断者= / 証跡=35_4.X_A-gateまたはEventBridge対応済み根拠_202608XX.png / 切り戻し=不要	未実施は失敗ではなく判断理由を残す。
共通	作業完了報告	予定10分 / 実績: 開始= / 終了=	結果= / 実施要件= / 対応なし要件= / 通知結果= / 切り戻し有無= / 残課題= / 証跡保存先= / 報告先= / 切り戻し=不要	完了判断者の確認を受ける。
```

## 4. 当日メモ欄

```text
作業日:
対象環境:
対象アカウント:
対象リージョン:
作業者:
確認者:
通知確認者:
切り戻し判断者:
証跡保存先:

全体結果:
残課題:
PM/リーダー確認事項:
A-gate確認事項:
次回対応:
```
