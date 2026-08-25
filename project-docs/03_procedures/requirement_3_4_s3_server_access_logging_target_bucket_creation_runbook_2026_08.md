# 要件3.4 S3 Server Access Logging ターゲットバケット作成・設定手順書

作成日: 2026-08-25  
対象: 開発・検証環境  
操作方法: AWS Management Console  

> 取扱注意: 本書は環境固有のリソース名を含む。公開範囲を確認するまで、公開リポジトリへの push や社外共有を行わない。

## 1. 目的

要件3.4「CloudTrail S3バケットでサーバーアクセスログが有効になっていること」への対応として、CloudTrailログ保存先S3バケットのServer Access Loggingを有効化する。

本書では、Server Access Loggingの配信先となるS3ターゲットバケットを新規作成し、ソースバケットにログ配信設定を追加し、実際のログオブジェクト到着を確認するまでの操作を定める。

## 2. 対象リソース

| 項目 | 値 | 用途・注意点 |
|---|---|---|
| 要件番号 | `3.4` | CloudTrailログ保存先S3へのアクセス記録 |
| 証跡名 | `a-b2bp-dv-tn-rb2b-tauditlogs0000-trailename` | 対象Trailとの照合用。S3 Server Access Loggingの入力項目ではない。正式名称に誤記がないか作業前に実環境と照合する |
| ソースバケット | `a-b2bp-dv-tn-rb2b-tauditlogs0000` | Server Access Loggingを有効化するCloudTrailログ保存先バケット |
| ターゲットバケット | `rb2bs3bucketserver-access-log-test` | Server Access Loggingのログ保存先として新規作成するバケット |
| AWSアカウントID | `<作業前に記入>` | ソースとターゲットは同一AWSアカウントであること |
| AWSリージョン | `<作業前に記入>` | ソースとターゲットは同一リージョンであること |
| ターゲットプレフィックス | `a-b2bp-dv-tn-rb2b-tauditlogs0000/`（案） | 承認済みパラメータを優先する。末尾に `/` を付ける |
| オブジェクトキー形式 | 日付ベースのパーティション、日付ソースは `イベント時刻`（案） | Athena等で日付検索しやすい。既存設計またはパラメータシートの決定値を優先する |
| バージョニング | `<設計値を記入>` | 未決定のまま作業しない |
| ライフサイクル・保持期間 | `<設計値を記入>` | ログ保存期間、移行先ストレージクラス、削除日数を事前に確定する |
| タグ | `<現場命名規則に従って記入>` | システム、環境、用途、管理者、コスト管理等の必須タグを確認する |

### 2.1 本手順の前提

- 配信先はS3汎用バケットとする。
- ソースバケットとターゲットバケットは、同一AWSアカウントかつ同一AWSリージョンに配置する。
- ターゲットバケットではServer Access Loggingを有効化しない。ログの再帰生成を防止するためである。
- ターゲットバケットではS3 Object Lockを有効化しない。
- ターゲットバケットではRequester Paysを有効化しない。
- ターゲットバケットのデフォルト暗号化はSSE-S3とする。S3 Server Access LoggingのS3配信先にSSE-KMSを指定しない。
- オブジェクト所有者は`バケット所有者の強制`とし、ACLを無効化する。
- ログ配信権限にはACLではなくバケットポリシーを使用する。

## 3. 作業前の確認

### 3.1 アカウントとリージョンの確認

1. AWS Management Console右上のアカウント表示を開く。
2. AWSアカウントIDを確認し、作業記録へ記載する。
3. S3コンソールを開く。
4. `a-b2bp-dv-tn-rb2b-tauditlogs0000`を選択する。
5. `プロパティ`タブの`AWS リージョン`を確認し、作業記録へ記載する。
6. 対象アカウントまたは対象リージョンが作業指示と異なる場合は作業を中止する。

### 3.2 ソースバケットの変更前確認

1. S3コンソールの`汎用バケット`から`a-b2bp-dv-tn-rb2b-tauditlogs0000`を開く。
2. `プロパティ`タブを開く。
3. `サーバーアクセスのログ記録`が`無効`であることを確認する。
4. 変更前画面を証跡として保存する。
5. CloudTrailコンソールで`a-b2bp-dv-tn-rb2b-tauditlogs0000-trailename`を検索し、S3バケット名が`a-b2bp-dv-tn-rb2b-tauditlogs0000`と一致することを確認する。

### 3.3 ターゲットバケット名の確認

1. S3コンソールのバケット一覧で`rb2bs3bucketserver-access-log-test`を検索する。
2. 該当バケットが存在しないことを確認する。
3. 同名バケットが既に存在する場合は作業を中止する。
4. 別名や連番を独断で使用せず、変更後の正式バケット名について承認を得る。

### 3.4 事前に確定する設計値

次のいずれかが未確定の場合、バケット作成前に設計担当者または承認者へ確認する。

- AWSアカウントID
- AWSリージョン
- ターゲットプレフィックス
- オブジェクトキー形式
- バージョニングの有効・無効
- ログ保持期間とライフサイクルルール
- 必須タグ
- 作業後にバケットを継続利用するか、テスト後に削除するか
- 本番・OPER環境で使用する正式なバケット名

## 4. 必要な権限

実際の権限制御はIAMポリシー、Permission Boundary、SCP、RCP、A-gate等を含めて確認する。Allowが付与されていても、上位統制に明示的なDenyがある場合は操作できない。

### 4.1 参照権限

- `s3:ListAllMyBuckets`
- `s3:GetBucketLocation`
- `s3:GetBucketLogging`
- `s3:GetBucketPolicy`
- `s3:GetBucketPublicAccessBlock`
- `s3:GetBucketOwnershipControls`
- `s3:GetEncryptionConfiguration`
- `s3:GetBucketVersioning`
- `s3:GetLifecycleConfiguration`
- `s3:GetBucketTagging`
- `s3:ListBucket`

### 4.2 設定変更権限

- `s3:CreateBucket`
- `s3:PutBucketLogging`
- `s3:PutBucketPolicy`
- `s3:PutBucketPublicAccessBlock`
- `s3:PutBucketOwnershipControls`
- `s3:PutEncryptionConfiguration`
- `s3:PutBucketVersioning`（バージョニングを有効化する場合）
- `s3:PutLifecycleConfiguration`（ライフサイクルを設定する場合）
- `s3:PutBucketTagging`（タグを設定する場合）

### 4.3 テスト後にバケットを削除する場合の追加権限

- `s3:DeleteObject`
- `s3:DeleteObjectVersion`（バージョニング有効時）
- `s3:DeleteBucketPolicy`
- `s3:DeleteBucket`

## 5. ターゲットバケットの新規作成

### 5.1 S3バケット作成画面を開く

1. AWS Management Consoleで`S3`を開く。
2. 左側メニューの`汎用バケット`を選択する。
3. `バケットを作成`を選択する。

### 5.2 基本設定を入力する

1. バケットタイプは`汎用`を選択する。
2. バケット名へ`rb2bs3bucketserver-access-log-test`を入力する。
3. AWSリージョンは、ソースバケット`a-b2bp-dv-tn-rb2b-tauditlogs0000`と同じリージョンを選択する。
4. `既存のバケットから設定をコピー`は使用しない。意図しない設定を引き継がないためである。
5. 名前空間の選択項目が表示される場合は、現場のS3標準設計に従う。判断できない場合は作業を中止する。

> バケット名とリージョンは作成後に変更できない。入力値を再確認してから次へ進む。

### 5.3 オブジェクト所有者を設定する

1. `オブジェクト所有者`で`ACL無効`を選択する。
2. `バケット所有者の強制`を選択する。
3. ACLを有効化しない。

この設定では、S3ログ配信サービス`logging.s3.amazonaws.com`への書き込み許可をバケットポリシーで付与する。

### 5.4 パブリックアクセスをブロックする

1. `このバケットのパブリックアクセスをすべてブロック`を有効にする。
2. 次の4項目がすべて有効であることを確認する。
   - 新しいACLを介して付与されたパブリックアクセスをブロックする
   - 任意のACLを介して付与されたパブリックアクセスをブロックする
   - 新しいパブリックバケットポリシーまたはアクセスポイントポリシーを介して付与されたパブリックアクセスをブロックする
   - 任意のパブリックバケットポリシーまたはアクセスポイントポリシーを介したパブリックアクセスとクロスアカウントアクセスをブロックする

ログ配信サービスプリンシパルへの限定的な許可はパブリックアクセスではないため、Block Public Accessを無効にする必要はない。

### 5.5 バージョニングとタグを設定する

1. `バケットのバージョニング`はパラメータシートまたは承認済み設計値を選択する。
2. `タグ`へ現場の命名規則で定められたキーと値を入力する。
3. 値が未確定の場合は作成を続けない。

### 5.6 暗号化とObject Lockを設定する

1. `デフォルトの暗号化`で`Amazon S3 マネージドキーを用いたサーバー側の暗号化（SSE-S3）`を選択する。
2. SSE-KMSまたはDSSE-KMSを選択しない。
3. `オブジェクトロック`を有効化しない。

### 5.7 作成内容を確認する

1. バケット名が`rb2bs3bucketserver-access-log-test`であることを確認する。
2. リージョンがソースバケットと一致することを確認する。
3. ACLが無効であることを確認する。
4. Block Public Accessがすべて有効であることを確認する。
5. 暗号化がSSE-S3であることを確認する。
6. Object Lockが無効であることを確認する。
7. `バケットを作成`を選択する。
8. 作成完了メッセージを確認する。

## 6. ターゲットバケットの作成後確認

1. バケット一覧から`rb2bs3bucketserver-access-log-test`を開く。
2. `プロパティ`で次を確認する。
   - AWSリージョンがソースバケットと一致する
   - バケットのバージョニングが設計値と一致する
   - デフォルト暗号化がSSE-S3である
   - Object Lockが無効である
   - Server Access Loggingが無効である
   - Requester Paysが無効である
3. `アクセス許可`で次を確認する。
   - Block Public Accessの4項目がすべて有効である
   - オブジェクト所有者が`バケット所有者の強制`である
   - ACLが無効である
4. `管理`でライフサイクルルールが設計値どおりであることを確認する。作成時に設定していない場合は、承認済みの保持期間に従って追加する。
5. 各画面を証跡として保存する。

## 7. ソースバケットのServer Access Logging有効化

### 7.1 設定画面を開く

1. S3コンソールの`汎用バケット`へ戻る。
2. `a-b2bp-dv-tn-rb2b-tauditlogs0000`を開く。
3. `プロパティ`タブを開く。
4. `サーバーアクセスのログ記録`まで移動する。
5. `編集`を選択する。

### 7.2 配信先を設定する

1. `サーバーアクセスのログ記録`で`有効`を選択する。
2. `送信先バケット`で`rb2bs3bucketserver-access-log-test`を指定する。
3. `送信先プレフィックス`へ承認済み値を入力する。
4. 本書の案を採用する場合は`a-b2bp-dv-tn-rb2b-tauditlogs0000/`を入力する。
5. `ログオブジェクトキーの形式`で承認済み値を選択する。
6. 本書の案を採用する場合は日付ベースのパーティション形式を選択し、日付ソースに`イベント時刻`を選択する。
7. 画面上のソースバケット、送信先バケット、プレフィックス、キー形式を再確認する。
8. `変更の保存`を選択する。

Amazon S3コンソールから有効化した場合、コンソールはターゲットバケットのバケットポリシーを更新し、ログ配信サービスプリンシパル`logging.s3.amazonaws.com`へ`s3:PutObject`を許可する。保存後は必ずポリシーを確認する。

## 8. ターゲットバケットポリシーの確認

1. `rb2bs3bucketserver-access-log-test`を開く。
2. `アクセス許可`タブを開く。
3. `バケットポリシー`を確認する。
4. `logging.s3.amazonaws.com`に対する`s3:PutObject`許可が追加されていることを確認する。
5. `Resource`がターゲットバケットと承認済みプレフィックスだけを対象としていることを確認する。
6. `aws:SourceArn`がソースバケット`a-b2bp-dv-tn-rb2b-tauditlogs0000`を指していることを確認する。
7. `aws:SourceAccount`が作業対象AWSアカウントIDと一致することを確認する。
8. 既存のDeny、SCP、RCP等がログ配信を拒否していないことを確認する。

### 8.1 期待するポリシー構造

次はターゲットプレフィックスに`a-b2bp-dv-tn-rb2b-tauditlogs0000/`を採用した場合の期待例である。`<AWS_ACCOUNT_ID>`を実値へ置換するまで設定に使用しない。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ServerAccessLogsPolicy",
      "Effect": "Allow",
      "Principal": {
        "Service": "logging.s3.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::rb2bs3bucketserver-access-log-test/a-b2bp-dv-tn-rb2b-tauditlogs0000/*",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3:::a-b2bp-dv-tn-rb2b-tauditlogs0000"
        },
        "StringEquals": {
          "aws:SourceAccount": "<AWS_ACCOUNT_ID>"
        }
      }
    }
  ]
}
```

### 8.2 コンソールによる自動更新が失敗した場合

1. エラー画面を閉じる前に、エラーコード、明示的Denyの有無、リクエストIDを証跡として保存する。
2. ソース側のServer Access Loggingが有効になっていないことを確認する。
3. A-gate、SCP、RCP、IAM権限、Permission Boundaryによる`s3:PutBucketPolicy`または`s3:PutBucketLogging`の拒否を確認する。
4. 承認を得ずにACL方式へ切り替えない。
5. 承認済みの管理者が上記ポリシー相当のStatementを既存ポリシーへ追加する。
6. 既存ポリシーがある場合、既存Statementを消さずに追加する。ポリシー全体を上書きしない。
7. ポリシー反映後、ソースバケットのServer Access Logging設定を再実行する。

## 9. 設定後確認とログ配信テスト

### 9.1 設定値の確認

1. ソースバケット`a-b2bp-dv-tn-rb2b-tauditlogs0000`を開く。
2. `プロパティ`の`サーバーアクセスのログ記録`が`有効`であることを確認する。
3. 送信先が`rb2bs3bucketserver-access-log-test`であることを確認する。
4. プレフィックスとオブジェクトキー形式が承認済み値と一致することを確認する。
5. 変更後画面を証跡として保存する。

### 9.2 安全なアクセスイベントの発生

1. 設定保存時刻を作業記録へ記載する。
2. ソースバケットの`オブジェクト`タブを開く。
3. 一覧を更新し、読取専用のバケット一覧取得リクエストを発生させる。
4. CloudTrailログオブジェクトのアップロード、削除、名前変更、ダウンロードは行わない。
5. テスト実施時刻と実施者を記録する。

### 9.3 ログオブジェクトの到着確認

1. ターゲットバケット`rb2bs3bucketserver-access-log-test`を開く。
2. 承認済みプレフィックス配下を開く。
3. ログオブジェクトが作成されていることを確認する。
4. オブジェクトの最終更新日時が設定後のテスト時間帯に対応することを確認する。
5. 承認された場合のみログオブジェクトを参照し、対象バケット、リクエスト時刻、操作、HTTPステータス等を確認する。
6. ログ到着画面を証跡として保存する。

S3 Server Access Loggingはベストエフォート配信であり、設定反映とログ到着に数時間かかる場合がある。設定直後にログが見つからないことだけで失敗と判定しない。確認期限を定め、期限内に未到着の場合は`保留`としてトラブルシューティングへ進む。

## 10. 完了条件

次をすべて満たした時点で要件3.4の開発・検証環境設定を完了とする。

- 対象アカウントとリージョンが正しい。
- ターゲットバケット`rb2bs3bucketserver-access-log-test`が作成されている。
- ターゲットバケットが非公開である。
- オブジェクト所有者が`バケット所有者の強制`である。
- デフォルト暗号化がSSE-S3である。
- Object LockとRequester Paysが無効である。
- ターゲットバケット自身のServer Access Loggingが無効である。
- ソースバケットのServer Access Loggingが有効である。
- ターゲットバケット、プレフィックス、キー形式が設計値と一致する。
- ログ配信サービスプリンシパルへの許可が、対象ソースバケットと対象アカウントに限定されている。
- 実際のアクセスログオブジェクトがターゲットへ到着している。
- 変更前、変更後、実配信の証跡が保存されている。
- パラメータシートと設計書へ確定値が反映されている。

## 11. 切り戻し手順

切り戻しは承認者の指示に基づいて実施する。ログ到着確認後も継続利用する設計の場合、切り戻しを行わない。

### 11.1 ソースバケットのログ設定を無効化する

1. `a-b2bp-dv-tn-rb2b-tauditlogs0000`を開く。
2. `プロパティ`を開く。
3. `サーバーアクセスのログ記録`の`編集`を選択する。
4. `無効`を選択する。
5. `変更の保存`を選択する。
6. `無効`になった画面を証跡として保存する。

### 11.2 ターゲットバケットを削除する場合

1. 配信中のログが遅れて到着する可能性を考慮し、承認された待機時間を置く。
2. 必要なログと証跡を承認済み保存先へ退避済みであることを確認する。
3. バージョニング有効時は、現行オブジェクトだけでなく全バージョンと削除マーカーを確認する。
4. ターゲットバケット内のオブジェクトを削除する。
5. ターゲットバケットポリシーからログ配信用Statementを削除する。
6. `rb2bs3bucketserver-access-log-test`を削除する。
7. バケット一覧から消えたことを確認し、証跡を保存する。

ターゲットバケットの削除が承認されていない場合、ソース側のログ設定だけを無効化し、未使用バケットとして管理台帳へ記録する。独断で削除しない。

## 12. トラブルシューティング

| 事象 | 主な確認点 | 対応 |
|---|---|---|
| バケット名を使用できない | 同名バケットの存在、命名規則、名前空間 | 別名を独断で使用せず、正式名の再承認を得る |
| `Cross S3 location logging not allowed` | ソースとターゲットのリージョン | 同一リージョンで作り直す。リージョンは後から変更できない |
| バケット所有者不一致 | ソースとターゲットのAWSアカウント | 同一アカウントにターゲットを作成する |
| ターゲットバケットが存在しない | バケット名、作成結果、入力ミス | 正式名と実在を確認する |
| AccessDeniedまたは明示的Deny | IAM、Permission Boundary、SCP、RCP、A-gate | エラー証跡を添えて権限・統制担当へ確認する。回避設定を行わない |
| ポリシー保存失敗 | `s3:PutBucketPolicy`権限、既存Deny、JSON構文 | 既存ポリシーを保存し、差分を確認してから承認済みStatementを追加する |
| ログが配信されない | `logging.s3.amazonaws.com`、Resourceプレフィックス、SourceArn、SourceAccount | ポリシーの完全一致を確認する |
| ログが配信されない | Object Lock、Requester Pays、SSE-KMS | Object LockとRequester Paysを無効、暗号化をSSE-S3にする |
| 設定直後にログが見つからない | 設定反映と配信遅延 | 数時間待って再確認する。直ちに再設定を繰り返さない |
| 重複または一部欠落がある | S3 Server Access Loggingのベストエフォート特性 | 監査の完全性要件はCloudTrail等の別統制と併せて評価する |

## 13. 影響と注意点

- Server Access Loggingの有効化自体に追加料金は発生しないが、ターゲットバケットのS3ストレージ、ログ参照、ライフサイクル遷移等には通常料金が発生する。
- ログオブジェクト数と保存容量が増加する。保持期間を未設定のまま運用すると継続的に容量が増える。
- ログ配信はベストエフォートであり、完全性と即時性は保証されない。
- 設定反映後しばらくは、すべてのリクエストが記録されない場合がある。
- 本変更はCloudTrailログの出力先そのものを変更しないが、CloudTrailログ保存先バケットのプロパティとターゲットバケットポリシーを変更する。
- ターゲットバケットのServer Access Loggingを有効化するとログの再帰生成が発生するため、無効のままとする。
- 公開アクセス、ACL有効化、SSE-KMS、Object Lock、Requester Paysへの変更は行わない。

## 14. 中止条件

次のいずれかに該当した場合は作業を中止し、PM、リーダー、インフラ・統制担当へ連携する。

- 対象AWSアカウントまたはリージョンが不明、もしくは作業指示と不一致
- ソースバケット名または対象Trailとの対応関係が不明
- ターゲットバケット名が既に使用されている
- ターゲットプレフィックス、保持期間、タグ等の設計値が未確定
- A-gate、SCP、RCP等による明示的Denyが表示された
- 作業中に既存ポリシーや既存設定の想定外差分を発見した
- 同一アカウント・同一リージョン要件を満たせない
- SSE-S3を使用できない設計条件がある

## 15. 証跡ファイル名

```text
01_3.4_共通_アカウントリージョン_202608XX.png
02_3.4_Source_変更前ServerAccessLogging_202608XX.png
03_3.4_Source_CloudTrail保存先照合_202608XX.png
04_3.4_Target_作成設定値_202608XX.png
05_3.4_Target_作成完了_202608XX.png
06_3.4_Target_プロパティ_202608XX.png
07_3.4_Target_PublicAccessBlock_ObjectOwnership_202608XX.png
08_3.4_Target_暗号化_ObjectLock_RequesterPays_202608XX.png
09_3.4_Source_ServerAccessLogging入力値_202608XX.png
10_3.4_Source_変更後ServerAccessLogging_202608XX.png
11_3.4_Target_BucketPolicy_202608XX.png
12_3.4_Target_ログオブジェクト到着_202608XX.png
13_3.4_Target_ログ内容確認_202608XX.png
14_3.4_切り戻し_Source設定_202608XX.png
15_3.4_切り戻し_Target削除結果_202608XX.png
```

`14`と`15`は切り戻しを実施した場合のみ取得する。画面内に不要な個人情報、認証情報、オブジェクト本文を含めない。

## 16. パラメータシート反映項目

作業完了後、少なくとも次の値をパラメータシートへ反映する。

- ソースバケット名
- Server Access Logging有効・無効
- ターゲットバケット名
- ターゲットプレフィックス
- ログオブジェクトキー形式
- ターゲットバケットのAWSアカウントID
- ターゲットバケットのAWSリージョン
- オブジェクト所有者設定
- Block Public Access設定
- デフォルト暗号化方式
- バージョニング設定
- Object Lock設定
- Requester Pays設定
- バケットポリシーのSid、Principal、Action、Resource、Condition
- ライフサイクルルールと保持期間
- タグ

## 17. 公式ドキュメント

- [Amazon S3 サーバーアクセスログを有効にする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [サーバーアクセスログによるリクエストのログ記録](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/ServerLogs.html)
- [サーバーアクセスログ記録のトラブルシューティング](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/troubleshooting-server-access-logging.html)
- [S3 汎用バケットの作成](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/create-bucket-overview.html)
- [Amazon S3 ストレージへのパブリックアクセスのブロック](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/access-control-block-public-access.html)

