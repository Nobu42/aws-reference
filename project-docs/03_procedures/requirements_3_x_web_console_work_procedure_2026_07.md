# 要件3番台 Webコンソール作業実施手順書

作成日: 2026-07-12

この手順書は、要件3.4〜3.7のログ保全、CMK暗号化、VPC Flow Logs設定をAWS Management Consoleで実施するための作業手順である。

正式な評価シート由来の情報を正とする。作業前に対象環境、対象アカウント、対象リージョン、対象リソース、ログ保存先、暗号化方針を確定する。

## 1. 作業対象

| 要件 | 作業内容 | 正式資料上の改善方針 |
| :--- | :--- | :--- |
| 3.4 | CloudTrail S3バケットのServer Access Logging有効化 | CloudTrail S3バケットでサーバーアクセスログを有効にする |
| 3.5 | CloudTrailログのSSE-KMS / CMK暗号化 | CloudTrailログをKMS CMKで保存時暗号化する |
| 3.6 | カスタマー管理対称CMKのローテーション有効化 | 3.5で作成または使用するCMKで年次ローテーションを有効化する |
| 3.7 | VPC Flow Logs有効化 | 利用されているすべてのVPCでVPC Flow Logsを有効化する |

## 2. 共通作業前確認

1. AWS Management Consoleへログインする。
2. 対象アカウントであることを確認する。
3. 対象リージョンを確認する。
4. 作業対象環境がProdかOPERかを確認する。
5. 作業対象リソース一覧を確認する。
6. 変更承認、作業時間、切り戻し方針を確認する。

取得する証跡:

- 対象アカウント表示
- 対象リージョン表示
- 対象リソース一覧
- 変更前設定画面

## 3. 要件3.4 CloudTrail S3バケット Server Access Logging

### 3.1 事前確認

確認項目:

| 項目 | 確認内容 |
| :--- | :--- |
| Source bucket | CloudTrailログ保存先S3バケット |
| Target bucket | Server Access Logging保存先S3バケット |
| Target prefix | ログ保存先プレフィックス |
| 同一リージョン | SourceとTargetが同じリージョンか |
| 同一アカウント | SourceとTargetが同じアカウントか |
| Object Ownership | BucketOwnerEnforcedか |
| Target bucket暗号化 | SSE-S3か |
| Object Lock | Target bucketで既定保持が有効ではないか |
| Requester Pays | Target bucketで有効ではないか |

注意:

- ログ保存先をSource bucket自身にすると、ログのログが発生し、保管量増加と確認性低下につながる。
- Target bucketにSSE-KMS既定暗号化を設定している場合、S3 Server Access Loggingの保存先として適さない可能性がある。SSE-S3を基本とする。
- BucketOwnerEnforcedの場合、ACLではなくBucket PolicyでS3ログ配信を許可する。

### 3.2 Target bucket権限確認

Target bucketに、S3ログ配信サービスがログを書き込める権限が必要である。

確認する内容:

- Bucket Policy
- `logging.s3.amazonaws.com` への `s3:PutObject` 許可
- `aws:SourceArn` にSource bucket ARNを指定しているか
- `aws:SourceAccount` に対象アカウントを指定しているか

### 3.3 設定手順

1. S3を開く。
2. CloudTrailログ保存先Source bucketを開く。
3. `プロパティ` を開く。
4. `サーバーアクセスのログ記録` を開く。
5. `編集` を選択する。
6. Server Access Loggingを有効化する。
7. Target bucketを選択する。
8. Target prefixを入力する。
9. 保存する。

取得する証跡:

- 変更前Server Access Logging画面
- Target bucket設定
- 変更後Server Access Logging画面

### 3.4 動作確認

1. Source bucketに対するアクセスが発生するまで待つ。
2. Target bucketの指定prefixにログオブジェクトが作成されるか確認する。
3. ログ配信がすぐに確認できない場合、一定時間後に再確認する。

Server Access Loggingはベストエフォートであり、配信遅延があり得る。

## 4. 要件3.5 CloudTrailログのCMK暗号化

### 4.1 事前確認

確認項目:

| 項目 | 確認内容 |
| :--- | :--- |
| 対象Trail | CloudTrailログ保存対象 |
| S3保存先 | CloudTrailログ保存先バケット |
| KMS Key | 使用するカスタマー管理キー |
| Key Region | S3 bucket / Trail構成と整合しているか |
| Key Policy | CloudTrailが利用できるか |
| 参照者権限 | ログ参照者にKMS Decrypt権限があるか |
| 既存ログ | 既存ログは自動で再暗号化されない |

### 4.2 CMK作成または選定

1. KMSを開く。
2. `カスタマー管理型キー` を開く。
3. 既存CMKを利用するか、新規作成するか確認する。
4. 新規作成する場合は、対称キーを作成する。
5. Alias、説明、タグを現場命名規則に合わせる。
6. Key AdministratorとKey Userを設定する。
7. CloudTrailサービスが利用できるKey Policyを確認する。

注意:

- CloudTrail用CMKは削除しない。
- 切り戻し時も、既に暗号化されたログを読むためにCMKを有効なまま保持する。

### 4.3 CloudTrail側設定

1. CloudTrailを開く。
2. 対象Trailを開く。
3. `編集` を選択する。
4. SSE-KMS暗号化を有効化する。
5. 対象CMKを指定する。
6. 保存する。

取得する証跡:

- 変更前Trail暗号化設定
- KMS Key詳細
- Key Policy
- 変更後Trail暗号化設定

### 4.4 動作確認

1. CloudTrailのTrail statusを確認する。
2. `Latest delivery error` 相当のエラーがないことを確認する。
3. S3に新規CloudTrailログが配信されることを確認する。
4. 新規ログオブジェクトの暗号化方式を確認する。
5. ログ参照者がKMS Decrypt権限を持つことを確認する。

## 5. 要件3.6 CMKローテーション

### 5.1 設定手順

1. KMSを開く。
2. 要件3.5で使用するカスタマー管理キーを開く。
3. `キーローテーション` を開く。
4. 自動キーローテーションを有効化する。
5. 保存する。

取得する証跡:

- 変更前ローテーション設定
- 変更後ローテーション設定

注意:

- AWS管理キーではなく、カスタマー管理キーが対象である。
- 対称CMKが対象である。
- ローテーション有効化後もKey IDは変わらず、暗号化処理で使われるキーマテリアルがローテーションされる。

## 6. 要件3.7 VPC Flow Logs

### 6.1 対象VPC確認

確認項目:

| 項目 | 確認内容 |
| :--- | :--- |
| 対象VPC | 利用されているすべてのVPC |
| 対象環境 | Prod、OPER |
| 既存Flow Logs | 有効化済みか |
| Log destination | CloudWatch LogsまたはS3 |
| Traffic type | ALL / ACCEPT / REJECT |
| Log format | 標準形式またはカスタム形式 |
| Retention | 保存期間 |
| KMS | 暗号化要件 |

正式資料では、Prod業務系サーバでは有効、OPER運用サーバでは無効とされている。現場のVPC一覧と照合する。

### 6.2 設定手順 CloudWatch Logs宛て

1. VPCを開く。
2. 対象VPCを選択する。
3. `フローログ` タブを開く。
4. `フローログを作成` を選択する。
5. Filterを選択する。原則は要件に応じて`ALL`を確認する。
6. DestinationをCloudWatch Logsにする。
7. Log Groupを選択または作成する。
8. IAM Roleを選択する。
9. Log formatを選択する。
10. 作成する。

### 6.3 設定手順 S3宛て

1. VPCを開く。
2. 対象VPCを選択する。
3. `フローログ` タブを開く。
4. `フローログを作成` を選択する。
5. DestinationをS3にする。
6. S3 bucket ARNとprefixを指定する。
7. Log formatを選択する。
8. 作成する。

### 6.4 動作確認

1. 対象VPCのFlow Logs一覧で状態を確認する。
2. CloudWatch LogsまたはS3にログが配信されることを確認する。
3. Delivery errorがないことを確認する。
4. 保持期間、暗号化、アクセス権を確認する。

取得する証跡:

- 変更前Flow Logs一覧
- Flow Log作成画面
- 作成後Flow Logs詳細
- ログ配信先
- ログ到着確認

## 7. 切り戻し方針

| 要件 | 切り戻し |
| :--- | :--- |
| 3.4 | Server Access Loggingを無効化する。ただしログ保存先に作成済みのログは保持方針に従う |
| 3.5 | TrailのKMS設定を作業前状態へ戻す。既にCMKで暗号化されたログ参照のためCMKは無効化しない |
| 3.6 | ローテーション設定を戻すかは承認判断とする。CMK削除・無効化は行わない |
| 3.7 | 作成したFlow Logを削除する。配信済みログは保持方針に従う |

## 8. 完了条件

| 要件 | 完了条件 |
| :--- | :--- |
| 3.4 | CloudTrail S3 bucketのServer Access Loggingが有効であり、Target bucketが確認済み |
| 3.5 | CloudTrailログがCMKで暗号化され、新規ログ配信にエラーがない |
| 3.6 | 対象CMKの自動ローテーションが有効 |
| 3.7 | 利用中VPCのFlow Logsが有効であり、ログ配信が確認済み |

