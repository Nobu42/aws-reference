# S3バケットポリシー変更 作業手順書テンプレート Markdown版

## 1. このテンプレートの目的

このMarkdownは、現場でExcelファイルをダウンロードできない、または既存テンプレートを持ち込めない場合に、一からExcel作業手順書を作り直すための設計図である。

対象作業は、S3バケットポリシー変更を想定する。

ただし、構成はAWS設定変更作業全般に流用できる。

主な利用場面:

- S3バケットポリシー変更
- S3 Public Access Block設定変更
- Security Group変更
- Route Table変更
- CloudTrail / CloudWatch設定変更
- GuardDuty検知設定確認
- VPC Endpoint Policy変更

## 2. Excelで作り直す場合のブック構成

Excelで作成する場合、以下のシート構成にする。

| シートNo. | シート名 | 目的 |
| :--- | :--- | :--- |
| 01 | 作業概要 | 作業の目的、対象、日時、担当、承認、前提条件を整理する |
| 02 | 変更前確認 | 変更前のAWS設定、取得証跡、期待値を整理する |
| 03 | 影響調査 | 変更対象がどのサービス、利用者、通信、権限に影響するか整理する |
| 04 | 変更手順 | 実際に実行する手順を1行ずつ記載する |
| 05 | 変更後確認 | 変更後の確認、テスト、証跡取得結果を整理する |
| 06 | 切り戻し手順 | 失敗時に元へ戻す手順を整理する |
| 07 | 証跡一覧 | 取得したCLI出力、画面キャプチャ、ログ、差分ファイルを一覧化する |
| 08 | チェックリスト | 作業前、作業中、作業後の確認漏れを防ぐ |
| 09 | レビュー承認 | 作成、レビュー、承認、実施結果確認の記録を残す |

Excel作成時の共通ルール:

| 項目 | 推奨設定 |
| :--- | :--- |
| フォント | Meiryo UI または MS Gothic |
| フォントサイズ | 10 または 11 |
| 1行目 | タイトル行 |
| 2行目以降 | 表形式 |
| ヘッダー色 | 薄い青または薄いグレー |
| 罫線 | 表全体に細線 |
| ウィンドウ枠固定 | ヘッダー行の下で固定 |
| フィルター | 各表のヘッダー行に設定 |
| 日付形式 | yyyy/mm/dd hh:mm |
| ステータス候補 | 未着手、対応中、完了、保留、対象外 |
| 判定候補 | OK、NG、対象外、要確認 |

## 3. シート01: 作業概要

### 3.1 シートの目的

作業の全体像を1枚で確認できるようにする。

誰が、いつ、どのAWSアカウントで、何を、なぜ変更するのかを明確にする。

### 3.2 Excel列定義

| 列 | 項目 | 入力例 | 備考 |
| :--- | :--- | :--- | :--- |
| A | 項目 | 作業名 | 固定項目 |
| B | 内容 | S3バケットポリシー変更 | 作業ごとに記載 |
| C | 備考 | 影響調査済み項目に対する設定変更 | 任意 |

### 3.3 Excel貼り付け用

| 項目 | 内容 | 備考 |
| :--- | :--- | :--- |
| 作業名 | S3バケットポリシー変更 |  |
| 作業ID | CHG-YYYYMMDD-001 | 現場の管理番号があれば記載 |
| 対象システム | 某銀行 振込・電子保管システム |  |
| 対象AWSアカウント | `<account-id>` | `aws sts get-caller-identity` で確認 |
| 対象リージョン | ap-northeast-1 | 東京リージョンなど |
| 対象サービス | Amazon S3 |  |
| 対象リソース | `<bucket-name>` | バケット名 |
| 作業目的 | バケットポリシーを見直し、必要なアクセスのみ許可する |  |
| 作業分類 | セキュリティ設定変更 |  |
| 実施予定日時 | yyyy/mm/dd hh:mm - hh:mm |  |
| 作業担当 | `<name>` |  |
| レビュー担当 | `<name>` |  |
| 承認者 | `<name>` |  |
| 作業方式 | AWS Management Console / AWS CLI | 現場ルールに合わせる |
| 変更前バックアップ | 取得する | Bucket Policy JSONなど |
| 切り戻し可否 | 可 | 旧Policyへ戻す |
| サービス停止 | なし / あり | 影響調査結果に合わせる |
| 利用者影響 | なし / あり / 要確認 |  |
| 関係者連絡 | Teamsで事前連絡 |  |
| 作業後報告 | Teamsで結果報告 |  |

## 4. シート02: 変更前確認

### 4.1 シートの目的

変更前の状態を保存し、変更後に差分比較できるようにする。

### 4.2 Excel列定義

| 列 | 項目 | 入力例 | 備考 |
| :--- | :--- | :--- | :--- |
| A | No | 1 | 連番 |
| B | 確認対象 | Bucket Policy | 確認する設定 |
| C | 確認内容 | 現在のPolicyを取得する |  |
| D | 確認コマンド / 画面 | `aws s3api get-bucket-policy ...` | GUIの場合は画面名 |
| E | 期待値 | 現行設定が取得できること |  |
| F | 結果 | OK / NG / 要確認 | プルダウン推奨 |
| G | 証跡ファイル | `before/bucket_policy.json` | ファイル名 |
| H | 備考 |  |  |

### 4.3 Excel貼り付け用

| No | 確認対象 | 確認内容 | 確認コマンド / 画面 | 期待値 | 結果 | 証跡ファイル | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Caller Identity | 操作対象AWSアカウントを確認する | `aws sts get-caller-identity --profile <profile>` | 想定Account IDであること |  | `00_caller_identity.json` |  |
| 2 | Bucket存在確認 | 対象バケットにアクセスできることを確認する | `aws s3api head-bucket --bucket <bucket>` | エラーなく完了すること |  | `before/head_bucket.txt` |  |
| 3 | Bucket Policy | 現在のBucket Policyを取得する | `aws s3api get-bucket-policy --bucket <bucket>` | Policy JSONを取得できること |  | `before/bucket_policy.json` |  |
| 4 | Public Access Block | Public Access Block設定を確認する | `aws s3api get-public-access-block --bucket <bucket>` | 4項目が想定どおりであること |  | `before/public_access_block.json` |  |
| 5 | Object Ownership | ACL無効化状態を確認する | `aws s3api get-bucket-ownership-controls --bucket <bucket>` | BucketOwnerEnforcedなど想定値であること |  | `before/ownership_controls.json` |  |
| 6 | Bucket Encryption | 暗号化設定を確認する | `aws s3api get-bucket-encryption --bucket <bucket>` | SSE-S3 / SSE-KMSなど想定値であること |  | `before/encryption.json` |  |
| 7 | Versioning | Versioning状態を確認する | `aws s3api get-bucket-versioning --bucket <bucket>` | 有効/無効が設計どおりであること |  | `before/versioning.json` |  |
| 8 | Access Logging | サーバーアクセスログ設定を確認する | `aws s3api get-bucket-logging --bucket <bucket>` | 設定有無が設計どおりであること |  | `before/logging.json` |  |
| 9 | CloudTrail | 直近のBucket Policy変更履歴を確認する | `aws cloudtrail lookup-events ...` | 想定外の変更がないこと |  | `before/cloudtrail_put_bucket_policy.json` |  |
| 10 | 利用元確認 | IAM Role、VPC Endpoint、アプリからの利用有無を確認する | IAM / CloudTrail / 設計書 | 利用元が把握できていること |  | `before/usage_check.md` |  |

## 5. シート03: 影響調査

### 5.1 シートの目的

ポリシー変更によって影響を受ける利用者、システム、IAM Principal、通信経路を整理する。

### 5.2 Excel列定義

| 列 | 項目 | 入力例 | 備考 |
| :--- | :--- | :--- | :--- |
| A | No | 1 | 連番 |
| B | 影響対象 | Webアプリ | 利用者、サービス、処理 |
| C | 現行アクセス | `s3:PutObject` | 現在必要な権限 |
| D | 変更後アクセス | `s3:PutObject` | 変更後も必要な権限 |
| E | 影響有無 | なし / あり / 要確認 | プルダウン推奨 |
| F | 確認方法 | CloudTrail、IAM Policy確認 |  |
| G | 判断理由 | 対象Roleのみ許可を維持するため |  |
| H | 対応 | 追加確認、関係者確認など |  |
| I | 備考 |  |  |

### 5.3 Excel貼り付け用

| No | 影響対象 | 現行アクセス | 変更後アクセス | 影響有無 | 確認方法 | 判断理由 | 対応 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Railsアプリ画像アップロード | `s3:PutObject` | `s3:PutObject` | なし | IAM Role、アプリ設定、CloudTrail | Web EC2のRoleからのPutObjectを維持するため | 変更後にアップロードテスト |  |
| 2 | Railsアプリ画像表示 | `s3:GetObject` | `s3:GetObject` | なし | アプリ動作確認 | 必要なGetObjectを維持するため | 変更後に画面表示確認 |  |
| 3 | 管理者による確認 | `s3:ListBucket` | 必要に応じて維持 | 要確認 | IAM User/Role確認 | 管理作業に必要な可能性あり | 管理者へ確認 |  |
| 4 | VPC Endpoint経由アクセス | `aws:sourceVpce` 条件なし/あり | 条件追加/維持 | 要確認 | VPC Endpoint ID確認 | Endpoint ID不一致時にアクセス不可 | Endpoint IDを証跡化 |  |
| 5 | 外部公開アクセス | なし | なし | なし | Public Access Block、Policy確認 | Public公開しない方針 | 変更後もPublic判定確認 |  |
| 6 | バッチ/Lambda | 不明 | 不明 | 要確認 | CloudTrail、設計書、関係者確認 | 利用元未確定 | 利用有無を確認 |  |

## 6. シート04: 変更手順

### 6.1 シートの目的

実作業時に迷わないよう、1操作1行で手順を記載する。

GUI作業でもCLI作業でも、実施内容、確認観点、証跡を明確にする。

### 6.2 Excel列定義

| 列 | 項目 | 入力例 | 備考 |
| :--- | :--- | :--- | :--- |
| A | 手順No | 1 | 連番 |
| B | 作業区分 | 事前確認 / 変更 / 確認 | プルダウン推奨 |
| C | 作業内容 | Bucket Policyを更新する |  |
| D | 操作場所 | AWS Console / AWS CLI |  |
| E | コマンド / 操作 | `aws s3api put-bucket-policy ...` | GUIの場合は画面操作 |
| F | 期待結果 | エラーなく完了 |  |
| G | 実施結果 | 未実施 / OK / NG | プルダウン推奨 |
| H | 証跡 | `change/put_bucket_policy.txt` |  |
| I | 備考 |  |  |

### 6.3 Excel貼り付け用

| 手順No | 作業区分 | 作業内容 | 操作場所 | コマンド / 操作 | 期待結果 | 実施結果 | 証跡 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 事前確認 | 作業対象アカウントを確認する | AWS CLI | `aws sts get-caller-identity --profile <profile>` | 想定Account IDであること |  | `00_caller_identity.json` |  |
| 2 | 事前確認 | 変更前Bucket Policyを保存する | AWS CLI | `aws s3api get-bucket-policy --bucket <bucket> > before/bucket_policy.json` | Policyを保存できること |  | `before/bucket_policy.json` |  |
| 3 | 事前確認 | 変更後Policy案を準備する | エディタ | `change/bucket_policy_after.json` を作成 | JSON構文が正しいこと |  | `change/bucket_policy_after.json` |  |
| 4 | 事前確認 | 変更前後の差分を確認する | diffツール | `diff -u before/bucket_policy.json change/bucket_policy_after.json` | 変更差分が想定どおりであること |  | `change/policy_diff.txt` |  |
| 5 | 変更 | Bucket Policyを更新する | AWS CLI / Console | `aws s3api put-bucket-policy --bucket <bucket> --policy file://change/bucket_policy_after.json` | エラーなく完了すること |  | `change/put_bucket_policy.txt` | GUIの場合は画面証跡 |
| 6 | 変更後確認 | 更新後Policyを取得する | AWS CLI | `aws s3api get-bucket-policy --bucket <bucket>` | 変更後Policyと一致すること |  | `after/bucket_policy.json` |  |
| 7 | 変更後確認 | Public判定を確認する | AWS CLI / Console | `aws s3api get-bucket-policy-status --bucket <bucket>` | Publicでないこと |  | `after/policy_status.json` |  |
| 8 | 変更後確認 | アプリからS3アップロードを確認する | Webアプリ | 画像アップロード操作 | 正常に保存されること |  | `screenshots/upload_result.png` |  |
| 9 | 変更後確認 | CloudTrailで変更イベントを確認する | AWS CLI / Console | `lookup-events` | `PutBucketPolicy` が記録されること |  | `after/cloudtrail_put_bucket_policy.json` |  |
| 10 | 報告 | 作業完了を報告する | Teams | 作業結果、証跡、残課題を報告 | 関係者へ共有済み |  | `after/teams_report.txt` |  |

## 7. シート05: 変更後確認

### 7.1 シートの目的

変更後に、設定値、セキュリティ状態、業務機能が想定どおりであることを確認する。

### 7.2 Excel貼り付け用

| No | 確認対象 | 確認内容 | 確認方法 | 期待値 | 結果 | 証跡 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Bucket Policy | 変更後Policyが反映されていること | `get-bucket-policy` | 変更後JSONと一致 |  | `after/bucket_policy.json` |  |
| 2 | Public判定 | バケットがPublicでないこと | `get-bucket-policy-status` | `IsPublic=false` |  | `after/policy_status.json` |  |
| 3 | Public Access Block | Public Access Blockが有効であること | `get-public-access-block` | 4項目がtrue |  | `after/public_access_block.json` |  |
| 4 | アプリ機能 | 画像アップロードが成功すること | Web画面操作 | 投稿/アップロード成功 |  | `screenshots/upload_result.png` |  |
| 5 | アプリ機能 | 画像表示が成功すること | Web画面操作 | 画像が表示される |  | `screenshots/image_display.png` |  |
| 6 | 許可アクセス | 想定Roleからアクセスできること | アプリ/CLI | AccessDeniedにならない |  | `after/allowed_access.txt` |  |
| 7 | 拒否アクセス | 想定外Principalからアクセスできないこと | CLI/Policy Simulator | AccessDeniedになる |  | `after/denied_access.txt` |  |
| 8 | CloudTrail | 変更イベントが記録されていること | `lookup-events` | `PutBucketPolicy` 確認 |  | `after/cloudtrail.json` |  |
| 9 | 監視 | CloudWatch / GuardDutyに想定外検知がないこと | Console / CLI | 異常なし |  | `after/security_check.png` |  |

## 8. シート06: 切り戻し手順

### 8.1 シートの目的

設定変更に失敗した場合、または変更後に影響が発生した場合に、旧設定へ戻す手順を明確にする。

### 8.2 Excel貼り付け用

| 手順No | 条件 | 作業内容 | 操作場所 | コマンド / 操作 | 期待結果 | 実施結果 | 証跡 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 切り戻し判断 | 影響内容を確認し、切り戻し実施可否を判断する | Teams / 監視 / アプリ | 関係者確認 | 切り戻し判断が明確であること |  | `rollback/rollback_decision.txt` |  |
| 2 | 切り戻し | 変更前Bucket Policyを再適用する | AWS CLI / Console | `aws s3api put-bucket-policy --bucket <bucket> --policy file://before/bucket_policy.json` | エラーなく完了すること |  | `rollback/put_old_policy.txt` |  |
| 3 | 確認 | 切り戻し後Policyを取得する | AWS CLI | `aws s3api get-bucket-policy --bucket <bucket>` | 変更前Policyと一致すること |  | `rollback/bucket_policy.json` |  |
| 4 | 確認 | アプリ機能を確認する | Web画面 | アップロード/表示が正常 |  | `rollback/app_check.png` |  |
| 5 | 確認 | CloudTrailに切り戻し操作が記録されていること | AWS CLI / Console | `PutBucketPolicy` が記録されること |  | `rollback/cloudtrail.json` |  |
| 6 | 報告 | 切り戻し結果を報告する | Teams | 影響、対応、現在状態を共有 |  | `rollback/teams_report.txt` |  |

## 9. シート07: 証跡一覧

### 9.1 シートの目的

作業で取得した証跡を一覧化し、レビューや監査時に追跡できるようにする。

### 9.2 Excel列定義

| 列 | 項目 | 入力例 | 備考 |
| :--- | :--- | :--- | :--- |
| A | No | 1 | 連番 |
| B | タイミング | 変更前 / 変更中 / 変更後 / 切り戻し |  |
| C | 証跡種別 | CLI JSON / Screenshot / Log / Diff |  |
| D | 証跡名 | Bucket Policy変更前 |  |
| E | ファイル名 | `before/bucket_policy.json` |  |
| F | 取得方法 | AWS CLI |  |
| G | 取得者 | `<name>` |  |
| H | 取得日時 | yyyy/mm/dd hh:mm |  |
| I | 秘密情報確認 | OK / 要マスク |  |
| J | 備考 |  |  |

### 9.3 Excel貼り付け用

| No | タイミング | 証跡種別 | 証跡名 | ファイル名 | 取得方法 | 取得者 | 取得日時 | 秘密情報確認 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 変更前 | CLI JSON | Caller Identity | `00_caller_identity.json` | AWS CLI |  |  | OK |  |
| 2 | 変更前 | CLI JSON | Bucket Policy変更前 | `before/bucket_policy.json` | AWS CLI |  |  | 要確認 | PrincipalやResourceを確認 |
| 3 | 変更前 | CLI JSON | Public Access Block変更前 | `before/public_access_block.json` | AWS CLI |  |  | OK |  |
| 4 | 変更中 | Diff | Bucket Policy差分 | `change/policy_diff.txt` | diffツール |  |  | 要確認 |  |
| 5 | 変更中 | Screenshot | Console変更画面 | `screenshots/put_bucket_policy.png` | AWS Console |  |  | 要確認 |  |
| 6 | 変更後 | CLI JSON | Bucket Policy変更後 | `after/bucket_policy.json` | AWS CLI |  |  | 要確認 |  |
| 7 | 変更後 | CLI JSON | Public判定 | `after/policy_status.json` | AWS CLI |  |  | OK |  |
| 8 | 変更後 | Screenshot | アップロード確認 | `screenshots/upload_result.png` | Web画面 |  |  | 要確認 | 個人情報が写らないよう注意 |
| 9 | 変更後 | CLI JSON | CloudTrail変更イベント | `after/cloudtrail.json` | AWS CLI |  |  | 要確認 | User情報を確認 |
| 10 | 切り戻し | CLI JSON | 切り戻し後Policy | `rollback/bucket_policy.json` | AWS CLI |  |  | 要確認 | 切り戻し実施時のみ |

## 10. シート08: チェックリスト

### 10.1 シートの目的

作業漏れを防ぐため、作業前、作業中、作業後の確認項目をチェックする。

### 10.2 Excel貼り付け用

| No | タイミング | チェック項目 | 確認内容 | 判定 | 確認者 | 確認日時 | 備考 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 作業前 | アカウント確認 | 操作対象Account IDが正しいこと |  |  |  |  |
| 2 | 作業前 | リージョン確認 | 対象Regionが正しいこと |  |  |  |  |
| 3 | 作業前 | 対象リソース確認 | バケット名が正しいこと |  |  |  |  |
| 4 | 作業前 | 変更前バックアップ | 変更前Policyを保存したこと |  |  |  |  |
| 5 | 作業前 | 差分確認 | 変更前後のPolicy差分を確認したこと |  |  |  |  |
| 6 | 作業前 | 影響調査 | 利用元、Principal、通信経路を確認したこと |  |  |  |  |
| 7 | 作業前 | 切り戻し手順 | 切り戻しコマンドと旧Policyが準備済みであること |  |  |  |  |
| 8 | 作業中 | 作業記録 | 実施時刻、操作内容、結果を記録したこと |  |  |  |  |
| 9 | 作業後 | 設定確認 | 変更後Policyが想定どおりであること |  |  |  |  |
| 10 | 作業後 | セキュリティ確認 | Publicになっていないこと |  |  |  |  |
| 11 | 作業後 | 機能確認 | アプリからS3利用できること |  |  |  |  |
| 12 | 作業後 | CloudTrail確認 | 変更イベントが記録されていること |  |  |  |  |
| 13 | 作業後 | 証跡確認 | 必要な証跡が揃っていること |  |  |  |  |
| 14 | 作業後 | 報告 | 関係者へ作業結果を報告したこと |  |  |  |  |

## 11. シート09: レビュー承認

### 11.1 シートの目的

手順書作成、レビュー、承認、作業実施、作業結果確認の記録を残す。

### 11.2 Excel貼り付け用

| No | 区分 | 氏名 | 役割 | 確認内容 | 判定 | 確認日時 | コメント |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 作成 |  | 作業担当 | 手順書を作成した |  |  |  |
| 2 | レビュー |  | レビュー担当 | 対象、影響範囲、手順、切り戻しを確認した |  |  |  |
| 3 | 承認 |  | 承認者 | 作業実施を承認した |  |  |  |
| 4 | 作業実施 |  | 作業担当 | 手順どおり作業を実施した |  |  |  |
| 5 | 結果確認 |  | レビュー担当 / 管理者 | 作業結果と証跡を確認した |  |  |  |

## 12. Excelで作るときの入力規則

Excelで作り直す場合、以下の列にプルダウンを設定すると扱いやすい。

| シート | 列名 | 候補値 |
| :--- | :--- | :--- |
| 変更前確認 | 結果 | 未確認、OK、NG、要確認、対象外 |
| 影響調査 | 影響有無 | なし、あり、要確認、対象外 |
| 変更手順 | 作業区分 | 事前確認、変更、変更後確認、切り戻し、報告 |
| 変更手順 | 実施結果 | 未実施、OK、NG、保留、対象外 |
| 変更後確認 | 結果 | 未確認、OK、NG、要確認、対象外 |
| 切り戻し手順 | 実施結果 | 未実施、OK、NG、保留、対象外 |
| 証跡一覧 | タイミング | 変更前、変更中、変更後、切り戻し |
| 証跡一覧 | 証跡種別 | CLI JSON、Screenshot、Log、Diff、Console、Other |
| 証跡一覧 | 秘密情報確認 | OK、要マスク、要確認 |
| チェックリスト | 判定 | 未確認、OK、NG、対象外 |
| レビュー承認 | 判定 | 未確認、承認、差戻し、対象外 |

## 13. 証跡ディレクトリ例

作業証跡は、以下のように分けると後から確認しやすい。

```text
evidence/
  20260702_s3_bucket_policy_change/
    00_metadata/
      00_caller_identity.json
    before/
      bucket_policy.json
      public_access_block.json
      ownership_controls.json
      encryption.json
      versioning.json
    change/
      bucket_policy_after.json
      policy_diff.txt
      put_bucket_policy.txt
    after/
      bucket_policy.json
      policy_status.json
      cloudtrail_put_bucket_policy.json
    rollback/
      put_old_policy.txt
      bucket_policy.json
    screenshots/
      console_before_policy.png
      console_after_policy.png
      upload_result.png
```

## 14. Teams報告文テンプレート

### 14.1 作業前連絡

```text
本日 <hh:mm> より、<bucket-name> のS3バケットポリシー変更作業を実施します。
対象AWSアカウント、対象バケット、変更前設定、切り戻し手順は確認済みです。
作業中に想定外の影響が確認された場合は、旧Policyへ切り戻します。
```

### 14.2 作業完了報告

```text
<bucket-name> のS3バケットポリシー変更作業が完了しました。

結果:
- Bucket Policy変更: 完了
- Public判定: Publicではないことを確認
- アプリ動作確認: 正常
- CloudTrail変更履歴: 記録あり
- 切り戻し: 未実施

証跡は所定フォルダへ格納済みです。
```

### 14.3 切り戻し報告

```text
<bucket-name> のS3バケットポリシー変更後に <影響内容> を確認したため、
切り戻し手順に従い変更前Policyへ戻しました。

現在状態:
- Bucket Policy: 変更前設定へ復旧
- アプリ動作確認: <結果>
- CloudTrail変更履歴: 記録あり

詳細は証跡と作業記録に追記します。
```

## 15. 現場でExcel作成するときのコツ

- 最初にシート名だけ作る
- 各シートのヘッダー行を先に作る
- ヘッダー行にフィルターを付ける
- `No` 列は手入力の連番でよい
- 長文列は折り返し表示を有効にする
- コマンド列は等幅フォントにすると読みやすい
- 証跡ファイル名は相対パスで書く
- スクリーンショットはExcelに貼り付けず、証跡一覧にファイル名を書く運用もあり
- 秘密情報が含まれる証跡は、マスク要否を必ず確認する

## 16. 案件で説明できるポイント

このテンプレートは、案件では次のように説明できる。

```text
AWS設定変更では、作業概要、変更前確認、影響調査、変更手順、変更後確認、
切り戻し、証跡一覧、チェックリスト、レビュー承認を分けて管理します。

特にS3バケットポリシー変更では、変更前Policyの保存、変更差分の確認、
Public判定、アプリ動作確認、CloudTrailによる変更履歴確認を必ず行います。
Excelテンプレートが使えない環境でも、同じ構成をMarkdownから再作成できます。
```

## 17. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| S3 Bucket Policy | Principal、Action、Resource、Condition |
| Public Access Block | 4つのブロック設定 |
| Object Ownership | ACL無効化、BucketOwnerEnforced |
| Encryption | SSE-S3、SSE-KMS |
| CloudTrail | 管理イベント、S3データイベント、変更履歴 |
| IAM | Identity PolicyとResource Policyの違い |
| VPC Endpoint | `aws:sourceVpce` 条件 |
| 変更管理 | 変更前確認、切り戻し、証跡取得 |

