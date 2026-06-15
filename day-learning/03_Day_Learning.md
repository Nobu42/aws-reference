# Day 3 Learning: CloudTrail基礎・変更履歴調査

## 学習開始前に実行するスクリプト

Day 3開始時に一時Trailが残っている場合は、状態確認だけを実行する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

一時Trailが存在しない場合は、作成後に状態を確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh

/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

Rails Active Storageから画像をアップロードして`PutObject`を確認する場合だけ、`sample-vpc`が存在しないときに`All_Setup.sh`を実行する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。続いてAnsibleを実行する。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

S3 Data Eventは学習開始時に有効化しない。Railsから画像をアップロードする直前に有効化し、確認直後に必ず切り戻す。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

Day 3終了時は、Data Eventの切り戻し後に一時Trailを削除する。詳しい切り戻しコマンドは後続手順を使用する。

## Day 3の実施方針

Day 3では、CloudTrailの次の2つを分けて確認する。

| 確認対象 | 内容 |
|---|---|
| Event History | Trailを作成していなくても、過去90日間のManagement Eventを検索できる |
| Trail | Management EventやData Eventを継続的に記録し、S3などへ配信する設定 |

現在の学習用AWSアカウントでは、Event Historyで`PutBucketPolicy`などを確認できる一方、初期状態ではTrailが存在しない。

Trailが存在しないままでは、Trail設定、ログ記録状態、ログ保存先S3、Event Selector、`PutObject` Data Eventを実物で確認できない。

そのため、Day 3では`All_Setup.sh`とは独立した一時検証用Trailを作成し、確認後に削除する。

実案件では、既存Trail、組織Trail、CloudTrail Lake、監査ログ集約構成が存在する可能性がある。承認なしでTrailを作成・変更・削除しない。

## Day 3の実施順序

```text
1. Event HistoryでManagement Eventを確認する
2. 一時検証用Trailとログ保存先S3バケットを作成する
3. Trail設定、稼働状態、Event Selectorを確認する
4. TrailログがS3へ配信されることを確認する
5. 必要に応じて、対象S3バケットのWrite-only Data eventsを有効化する
6. Rails Active Storageから画像をアップロードする
7. Trail保存先S3ログからPutObjectを確認する
8. Event Selectorを変更前設定へ切り戻す
9. 一時検証用Trailとログ保存先S3バケットを削除する
```

## 実行場所と終了処理

CloudTrail関連スクリプトは、**現在のディレクトリに関係なく、次の絶対パスで実行する**。

```text
Trail作成・確認・削除:
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/

S3 Data Event有効化・PutObject確認・切り戻し:
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/

ローカル証跡保存先:
/Users/nobu/aws-reference/evidence/
```

削除・切り戻しの判断:

| 対象 | 実施タイミング | 実行する処理 |
|---|---|---|
| S3 Data Event設定 | `PutObject`確認直後。Day 3を途中終了する場合も必ず実施する | `02_restore_s3_event_selectors.sh` |
| 一時TrailとCloudTrailログ用S3バケット | Day 3の全確認終了後 | `03_delete_cloudtrail_trail.sh` |
| ローカル証跡 | 内容確認・報告・復習が完了するまで削除しない | 必要になった時点で手動整理する |
| Rails画像保存先S3バケット | この手順では削除しない | 対象外 |

重要:

```text
Data Eventを切り戻してもTrailは残る。
Trailを削除してもローカル証跡は残る。
Trail削除スクリプトはRails画像保存先S3バケットを削除しない。
```

## 迷わないための実行コマンド一覧

### Day 3開始時

Trailが存在するか分からない場合は、最初に確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

Trailが存在しないエラーになった場合だけ作成する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
```

### Rails画像アップロードのPutObjectを確認する場合

画像アップロード直前にData Eventを有効化する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

Event Selectorの反映を待つため、有効化後に5分程度待ってから新しい画像をアップロードする。
画像アップロード後は、CloudTrailログ配信を5分から15分程度待ってから確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

### PutObject確認直後または途中終了時

有効化時の証跡ディレクトリを確認する。

```bash
ls -dt \
  /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/*_enable_s3_data_events
```

今回の有効化時刻と一致する絶対パスを指定し、Data Eventを切り戻す。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  /Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/REPLACE_WITH_SUCCESSFUL_ENABLE_EVIDENCE
```

切り戻し後の期待値:

```text
ManagementEvents=True
ReadWriteType=All
DataResourceCount=0
```

### Day 3終了時

必要な確認、Data Event切り戻し、証跡確認が完了した後、一時TrailとCloudTrailログ用S3バケットを削除する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

## 使用する検証スクリプト

- [CloudTrail一時Trail検証スクリプト](../scripts/cloudtrail_trail_lab/README.md)
- [CloudTrail S3 Data Events検証スクリプト](../scripts/cloudtrail_s3_data_events/README.md)

一時Trailを作成する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
```

Trail作成後、設定とログ配信状態を確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

Day 3の確認とData Event検証が完了した後、一時Trailを削除する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

作成・削除スクリプトは実行前に確認文字列の入力を求める。Caller Identity、対象Trail名、ログ保存先S3バケット名を確認してから実行する。

## 1. CloudTrailの役割を理解する

CloudTrailは、AWSアカウント内で実行されたAPI操作を記録・調査するためのサービスである。

AWSマネジメントコンソール、AWS CLI、AWS SDK、AWSサービスなどから実行された操作をイベントとして記録する。

## CloudTrailで確認できる主な情報

| 項目 | 内容 |
|---|---|
| EventName | 実行されたAWS API操作 |
| EventSource | 操作対象のAWSサービス |
| EventTime | 操作が実行された時刻 |
| UserIdentity | 操作を実行したIAMユーザー、IAMロール、AWSサービス |
| SourceIPAddress | 操作元のIPアドレス |
| UserAgent | Webコンソール、AWS CLI、SDKなどの操作方法 |
| RequestParameters | APIへ渡された対象リソースや設定値 |
| Resources | 操作対象のAWSリソース |
| ErrorCode | API操作失敗時のエラーコード |
| ErrorMessage | API操作失敗時のエラー内容 |

## CloudTrailによる調査例

S3 Bucket Policyが変更された場合、`PutBucketPolicy`イベントを確認する。

```text
誰が:
IAMユーザー、IAMロール、AWSサービス

いつ:
EventTime

何をした:
EventName = PutBucketPolicy

どのリソースへ:
対象S3バケット

どこから:
SourceIPAddress、UserAgent

成功したか:
ErrorCode、ErrorMessageの有無
```

## CloudTrailと関連サービスの違い

| サービス | 主な役割 |
|---|---|
| CloudTrail | AWS API操作の記録と監査 |
| CloudWatch Logs | ログの保存、検索、監視 |
| CloudWatch Alarm | メトリクスが条件を満たした場合の検知 |
| GuardDuty | AWSログなどを分析した不審な操作の検知 |
| AWS Config | AWSリソース設定の変更履歴と準拠状態の確認 |

## CloudTrail確認の基本的な流れ

```text
調査対象のAWSリソースまたは操作を確認する
↓
CloudTrail Event Historyでイベントを検索する
↓
EventName、EventTime、UserIdentityを確認する
↓
SourceIPAddress、UserAgent、RequestParametersを確認する
↓
ErrorCode、ErrorMessageの有無を確認する
↓
変更後のAWS設定やアプリケーション動作と照合する
↓
確認結果を証跡・報告として記録する
```

## 注意事項

- CloudTrailイベントが存在しても、変更後設定が正しいことまでは証明できない
- CloudTrail確認と、変更後設定・動作確認を組み合わせて判断する
- Event Historyで確認できるイベントには期間と種類の制限がある
- CloudTrailイベントにはIAM情報、IPアドレスなどが含まれるため、証跡の取り扱いに注意する
- GitHubなどへ公開する場合は、アカウントID、ARN、アクセスキーID、IPアドレスなどをマスクする

## 説明例

```text
CloudTrailは、AWS上で実行されたAPI操作を記録する監査サービスである。

設定変更後はCloudTrailで対象イベントを検索し、
実行者、実行時刻、対象リソース、操作内容、エラーの有無を確認する。

CloudTrailの確認結果だけでは変更後設定の正しさまでは判断できないため、
実際の設定値やアプリケーション動作確認と組み合わせて作業結果を判断する。
```

## 2. Management EventとData Eventの違いを理解する

CloudTrailが記録するイベントには、Management EventとData Eventがある。

調査対象の操作がどちらに分類されるかを理解しないと、CloudTrailで検索しても対象イベントを確認できない場合がある。

## Management Event

Management Eventは、AWSリソースの作成、変更、削除など、AWS環境の設定を管理する操作を記録する。

Control Plane操作とも呼ばれる。

代表例:

| AWSサービス | EventName | 操作内容 |
|---|---|---|
| S3 | `PutBucketPolicy` | Bucket Policy変更 |
| S3 | `PutPublicAccessBlock` | Public Access Block変更 |
| EC2 | `AuthorizeSecurityGroupIngress` | Security Groupの受信ルール追加 |
| EC2 | `RunInstances` | EC2インスタンス作成 |
| IAM | `CreateUser` | IAMユーザー作成 |
| IAM | `AttachRolePolicy` | IAMロールへのPolicy追加 |
| RDS | `ModifyDBInstance` | RDSインスタンス設定変更 |
| Lambda | `UpdateFunctionConfiguration` | Lambda設定変更 |
| CloudTrail | `StopLogging` | Trailのログ記録停止 |

Management Eventは通常、CloudTrail Event Historyで確認できる。

Day 2で確認した`PutBucketPolicy`もManagement Eventである。

## Data Event

Data Eventは、AWSリソース内部のデータに対する操作を記録する。

Data Plane操作とも呼ばれる。

代表例:

| AWSサービス | EventName | 操作内容 |
|---|---|---|
| S3 | `GetObject` | S3オブジェクト取得 |
| S3 | `PutObject` | S3オブジェクト保存 |
| S3 | `DeleteObject` | S3オブジェクト削除 |
| Lambda | `Invoke` | Lambda関数実行 |
| DynamoDB | `GetItem` | DynamoDB項目取得 |
| DynamoDB | `PutItem` | DynamoDB項目保存 |

Data Eventは大量に発生する可能性があるため、通常のEvent Historyには表示されない。

Data Eventを人が検索・保存するには、CloudTrail TrailまたはCloudTrail Lake Event Data Storeで記録対象を設定する必要がある。

## S3操作の分類例

```text
Bucket Policyを変更する
→ PutBucketPolicy
→ Management Event
→ Event Historyで確認可能

S3バケットへ画像を保存する
→ PutObject
→ Data Event
→ Event Historyでは通常確認不可
```

RailsアプリケーションからS3へ画像をアップロードした場合、`PutObject`はData Eventとなる。

S3コンソールでオブジェクト一覧を表示した場合に発生するオブジェクト操作も、Data Eventとして扱われる場合がある。

## Read EventとWrite Event

Management EventとData Eventは、さらに読み取り操作と書き込み操作に分類できる。

| 分類 | 内容 | 例 |
|---|---|---|
| Read Event | 設定やデータを参照する操作 | `DescribeInstances`、`GetObject` |
| Write Event | 設定やデータを変更する操作 | `PutBucketPolicy`、`RunInstances`、`PutObject` |

設定変更調査では、最初にWrite Eventを確認すると対象操作を絞り込みやすい。

## Event Historyで確認できる範囲

CloudTrail Event Historyでは、主に次の範囲を確認できる。

```text
対象:
Management Event

期間:
過去90日間

検索単位:
リージョン単位

料金:
追加料金なし
```

Event Historyは、長期保存や複雑な横断検索のための仕組みではない。

長期保存、Data Event記録、複雑な検索、複数アカウント集約が必要な場合は、TrailまたはCloudTrail Lakeを使用する。

## 調査時の判断手順

```text
確認したい操作を整理する
↓
設定変更か、データ操作かを判断する
↓
Management Eventの場合はEvent Historyを検索する
↓
Data Eventの場合はTrailまたはEvent Data Storeの設定を確認する
↓
記録設定がなければ、対象イベントを遡って確認できない可能性を報告する
```

## 確認結果記載例

```text
調査対象のPutBucketPolicyは、S3 Bucket Policyを変更するManagement Eventである。

CloudTrail Event Historyで過去90日間のイベントを検索できるため、
EventName、実行者、実行時刻、対象バケットを確認する。

一方、S3オブジェクト保存時のPutObjectはData Eventであるため、
Event Historyでは通常確認できない。

PutObjectの監査が必要な場合は、TrailまたはEvent Data Storeで
S3 Data Eventが記録対象になっていることを確認する必要がある。
```

## 3. AWS操作アカウントとリージョンを確認する

CloudTrail調査を開始する前に、操作対象のAWSアカウントとリージョンを確認する。

CloudTrail Event Historyはリージョン単位で検索するため、対象リージョンを誤ると目的のイベントを確認できない可能性がある。

この手順ではAWS設定を変更しない。

## 作業対象

```text
AWS CLIプロファイル: learning
想定AWSアカウントID: 445405559057
対象リージョン: ap-northeast-1
対象操作: CloudTrailイベント確認
設定変更: なし
```

## Webコンソールによる確認

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を開く
3. AWSアカウントIDが想定値と一致することを確認する
4. 操作中のIAMユーザーまたはスイッチロールを確認する
5. リージョンを東京リージョンへ切り替える
6. CloudTrailコンソールを開く
7. 画面上のリージョンが東京であることを再確認する

取得するスクリーンショット:

```text
01_CloudTrail操作アカウント確認.png
02_CloudTrail対象リージョン確認.png
```

## AWS CLIによる操作アカウント確認

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table \
  --no-cli-pager
```

期待値:

```text
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu
```

確認項目:

- `Account`が想定AWSアカウントIDと一致すること
- `Arn`が想定したIAMユーザーまたはIAMロールであること
- 想定外のAWSアカウントや認証情報を使用していないこと

## AWS CLIプロファイルのリージョン確認

```bash
aws configure get region \
  --profile learning
```

期待値:

```text
ap-northeast-1
```

プロファイルへリージョンが設定されていない場合、何も表示されないことがある。

各AWS CLIコマンドで`--region ap-northeast-1`を明示していれば、対象リージョンを固定できる。

## CloudTrail Event Historyの検索リージョン確認

東京リージョンの直近イベントを最大5件表示する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --max-results 5 \
  --query 'Events[].{EventTime:EventTime,EventName:EventName,Username:Username}' \
  --output table \
  --no-cli-pager
```

イベントが表示された場合、東京リージョンのEvent Historyへアクセスできている。

イベントが表示されない場合は、次を確認する。

- 対象リージョンが正しいか
- 指定プロファイルが正しいか
- `cloudtrail:LookupEvents`権限があるか
- 指定期間内にManagement Eventが存在するか
- AWS CLIのエラーメッセージが表示されていないか

## 結果の読み方

```text
GetCallerIdentity成功:
現在の認証情報を使用してAWSへ接続できている

Accountが想定値と一致:
正しいAWSアカウントを操作している

Arnが想定値と一致:
正しいIAMユーザーまたはIAMロールを使用している

lookup-events成功:
対象リージョンのCloudTrail Event Historyを検索できる
```

## 異常時の対応

次の場合は調査を中断し、対象環境を再確認する。

- AWSアカウントIDが想定値と一致しない
- IAMユーザーまたはIAMロールが想定と異なる
- 対象リージョンが不明
- `AccessDeniedException`が発生する
- 調査対象イベントが別リージョンで実行された可能性がある

複数リージョンを調査する必要がある場合は、対象リージョンごとに`lookup-events`を実行する。

## 確認結果記載例

```text
CloudTrail調査前に、操作対象のAWSアカウントおよびリージョンを確認した。

AWSアカウントIDは445405559057、
操作主体はIAMユーザーnobuであることを確認した。

東京リージョンのCloudTrail Event HistoryをAWS CLIで検索できることを確認した。

設定変更は実施していない。
```

## 4. WebコンソールでCloudTrail Event Historyを確認する

AWSマネジメントコンソールからCloudTrail Event Historyを開き、AWS API操作を検索する方法を確認する。

この手順では、Day 2で実行したS3 Bucket Policy変更イベントを検索対象とする。

設定変更は行わない。

## Event Historyを開く

1. AWSマネジメントコンソールへログインする
2. リージョンを東京リージョンへ切り替える
3. CloudTrailコンソールを開く
4. 左側メニューから「イベント履歴」を選択する
5. イベント一覧が表示されることを確認する

確認項目:

```text
対象AWSアカウント:
445405559057

対象リージョン:
アジアパシフィック（東京）ap-northeast-1

表示対象:
過去90日間のManagement Event
```

取得するスクリーンショット:

```text
03_CloudTrail_Event_History一覧確認.png
```

## EventNameによる検索

1. 検索属性から「イベント名」を選択する
2. 検索値へ`PutBucketPolicy`を入力する
3. 検索結果を確認する
4. Day 2で実行した変更時と切り戻し時のイベントを確認する

確認項目:

```text
イベント名:
PutBucketPolicy

イベントソース:
s3.amazonaws.com

ユーザー名:
nobu

対象リソース:
nobu-terraform-iac-lab-upload

イベント時刻:
Day 2の変更時刻および切り戻し時刻
```

取得するスクリーンショット:

```text
04_CloudTrail_PutBucketPolicy検索結果.png
```

## Resource Nameによる検索

1. 検索属性から「リソース名」を選択する
2. 検索値へ対象バケット名を入力する
3. 対象バケットに関連するイベントを確認する

検索値:

```text
nobu-terraform-iac-lab-upload
```

この検索では、`PutBucketPolicy`以外の対象バケットに関連するManagement Eventも表示される可能性がある。

取得するスクリーンショット:

```text
05_CloudTrail_S3リソース名検索結果.png
```

## Usernameによる検索

1. 検索属性から「ユーザー名」を選択する
2. 検索値へ`nobu`を入力する
3. IAMユーザー`nobu`が実行したイベントを確認する

ユーザー名検索では、複数AWSサービスのイベントが表示される可能性がある。

操作時刻やEventNameを使用し、目的のイベントを特定する。

## イベント詳細の確認

対象となる`PutBucketPolicy`イベントを選択し、イベント詳細を開く。

確認項目:

| 項目 | 確認内容 |
|---|---|
| イベント名 | `PutBucketPolicy` |
| イベント時刻 | 作業実施時刻と一致すること |
| ユーザー名 | `nobu` |
| イベントソース | `s3.amazonaws.com` |
| AWSリージョン | `ap-northeast-1` |
| ソースIPアドレス | 想定した接続元であること |
| ユーザーエージェント | AWS CLIまたは想定した操作方法であること |
| リソース名 | 対象S3バケットであること |
| 読み取り専用 | `false` |
| エラーコード | 記録がないこと |
| エラーメッセージ | 記録がないこと |

取得するスクリーンショット:

```text
06_CloudTrail_PutBucketPolicy詳細確認.png
```

## イベントレコードの確認

イベント詳細画面でイベントレコードを表示し、次の内容を確認する。

```text
eventName
eventSource
eventTime
userIdentity
sourceIPAddress
userAgent
requestParameters
resources
readOnly
errorCode
errorMessage
```

`requestParameters`には、APIへ渡された対象バケット名やBucket Policyなどが記録される。

機密情報や個人情報を含む可能性があるため、スクリーンショットや外部公開時の取り扱いに注意する。

## 結果の読み方

```text
イベントが検索できた:
CloudTrail Event HistoryへManagement Eventが記録されている

EventNameがPutBucketPolicy:
Bucket Policy変更APIが実行された

Usernameがnobu:
IAMユーザーnobuの認証情報で操作された

ReadOnlyがfalse:
設定変更を伴う書き込み操作である

errorCodeとerrorMessageがない:
API操作が正常終了した可能性が高い
```

CloudTrailでエラーが記録されていなくても、反映されたBucket Policyが正しいとは限らない。

対象S3バケットの実際の設定値と、アプリケーション動作確認結果を合わせて判断する。

## Event Historyで見つからない場合

次を確認する。

- 検索対象リージョンが正しいか
- イベント発生から数分待ったか
- 検索属性と検索値が正しいか
- イベントが過去90日以内か
- 対象操作がManagement Eventか
- 別のIAMユーザーまたはIAMロールで実行されていないか

## 確認結果記載例

```text
CloudTrail Event HistoryでPutBucketPolicyイベントを検索した。

変更時および切り戻し時のイベントを確認し、
実行者、実行時刻、対象S3バケット、イベントソースが想定どおりであることを確認した。

イベントレコードにerrorCodeおよびerrorMessageは記録されていなかった。

設定変更は実施していない。
```

## 5. AWS CLIでTrail一覧と設定内容を確認する

CloudTrailのTrailは、AWS API操作ログをS3バケットやCloudWatch Logsへ継続的に配信するための設定である。

Event Historyは過去90日間のManagement Eventを確認する機能であり、Trailを作成していない場合でも利用できる。

この手順では、作成済みTrailの有無と設定内容を確認する。Section 5内では設定変更を行わない。

学習用AWSアカウントでは、先に一時Trail作成スクリプトを実行し、実物のTrailを確認する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/01_create_cloudtrail_trail.sh
```

実案件では、Trailが存在しない場合でも独断で作成しない。組織Trail、CloudTrail Lake、別監査基盤の有無を確認し、承認された手順に従う。

## Webコンソールによる確認

1. CloudTrailコンソールを開く
2. 対象リージョンが東京リージョンであることを確認する
3. 左側メニューから「証跡」を選択する
4. Trail一覧を確認する
5. Trailが存在する場合は名前を選択して設定詳細を開く
6. 「編集」は押さない

確認項目:

```text
Trail名
ホームリージョン
マルチリージョン証跡
組織の証跡
ログファイルの検証
ログ保存先S3バケット
S3プレフィックス
SNS通知
CloudWatch Logs連携
KMS暗号化
```

取得するスクリーンショット:

```text
07_CloudTrail_Trail一覧確認.png
08_CloudTrail_Trail設定確認.png
```

## AWS CLIによるTrail一覧確認

現在のAWSアカウントで参照できるTrail一覧を表示する。

```bash
aws cloudtrail describe-trails \
  --profile learning \
  --region ap-northeast-1 \
  --include-shadow-trails \
  --query 'trailList[].{
    Name:Name,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    CloudWatchLogs:CloudWatchLogsLogGroupArn
  }' \
  --output table \
  --no-cli-pager
```

## 結果の読み方

| 項目 | 内容 |
|---|---|
| `Name` | Trail名 |
| `HomeRegion` | Trailを作成・管理するリージョン |
| `MultiRegion` | 全リージョンのイベントを記録するTrailか |
| `Organization` | AWS Organizations全体を対象とするTrailか |
| `LogValidation` | ログファイル検証が有効か |
| `S3Bucket` | CloudTrailログ保存先S3バケット |
| `CloudWatchLogs` | 連携先CloudWatch Logs Log Group ARN |

何も表示されない場合、現在のAWSアカウントにはTrailが作成されていない可能性がある。

Trailが存在しなくても、Event Historyでは過去90日間のManagement Eventを確認できる。

## Trail名のみを確認する

```bash
aws cloudtrail describe-trails \
  --profile learning \
  --region ap-northeast-1 \
  --include-shadow-trails \
  --query 'trailList[].Name' \
  --output text \
  --no-cli-pager
```

出力例:

```text
sample-trail
```

Trail名を変数へ設定する。

```bash
TRAIL_NAME="<確認したTrail名>"
```

Trailが存在しない場合は、後続のTrail詳細確認、稼働状態確認、S3ログ配信確認、Data Event検証を実施できない。

学習環境では、[CloudTrail一時Trail検証スクリプト](../scripts/cloudtrail_trail_lab/README.md)を使用して一時Trailを作成する。

実案件では、未設定であることを確認結果として記録し、既存の監査構成と変更承認を確認する。

## 特定Trailの設定詳細確認

```bash
aws cloudtrail get-trail \
  --profile learning \
  --region ap-northeast-1 \
  --name "$TRAIL_NAME" \
  --query 'Trail.{
    Name:Name,
    TrailARN:TrailARN,
    HomeRegion:HomeRegion,
    MultiRegion:IsMultiRegionTrail,
    GlobalServiceEvents:IncludeGlobalServiceEvents,
    Organization:IsOrganizationTrail,
    LogValidation:LogFileValidationEnabled,
    S3Bucket:S3BucketName,
    S3Prefix:S3KeyPrefix,
    KmsKeyId:KmsKeyId,
    CloudWatchLogs:CloudWatchLogsLogGroupArn,
    CloudWatchLogsRole:CloudWatchLogsRoleArn,
    SnsTopic:SnsTopicARN
  }' \
  --output table \
  --no-cli-pager
```

## 重要な確認観点

### Multi-region Trail

```text
IsMultiRegionTrail=True
```

全リージョンで発生したManagement Eventを記録するTrailである。

金融系システムでは、想定外リージョンでの操作も監査対象になるため、Multi-region Trailが重要となる。

### Global Service Events

```text
IncludeGlobalServiceEvents=True
```

IAMやAWS STSなど、グローバルサービスのイベントを記録する。

### Log File Validation

```text
LogFileValidationEnabled=True
```

CloudTrailログファイルが配信後に変更・削除されていないか検証できる。

有効化後に配信されたログへ検証用ダイジェストファイルが作成される。

### S3ログ保存先

```text
S3BucketName=nobu-iac-lab-cloudtrail-445405559057
```

`S3BucketName`には、CloudTrailイベントログの保存先S3バケット名が表示される。

次の確認が必要となる。

- CloudTrailがログを書き込めるBucket Policyか
- Public Access Blockが有効か
- 暗号化されているか
- VersioningやObject Lockが必要か
- ライフサイクル設定が要件に合っているか
- CloudTrail自身のログを適切に保護できているか

### CloudWatch Logs連携

```text
CloudWatchLogsLogGroupArn=None
```

`None`の場合、CloudWatch Logsへの配信は設定されていない。Log Group ARNが表示される場合、CloudTrailイベントをCloudWatch Logsへ配信する構成である。

Metric FilterやAlarmを使用して、MFAなしログインやCloudTrail停止などを検知できる。

値が空の場合、CloudWatch Logs連携は未設定である。

## Trail未設定時の判断

Trailが未設定でも、直ちにセキュリティ上の問題とは断定しない。

次の可能性を確認する。

- 組織Trailを別の管理アカウントで設定している
- CloudTrail Lake Event Data Storeを使用している
- 別の監査基盤へログを集約している
- 学習環境のためTrailを作成していない
- 要件上Trailが必要だが未設定になっている

学習環境と実案件では、次のように対応を分ける。

| 環境 | 対応 |
|---|---|
| 学習環境 | 専用スクリプトで一時Trailを作成し、確認後に削除する |
| 実案件 | 独断で作成せず、組織Trailや監査基盤を確認して変更承認を得る |

## 確認結果記載例: Trailあり

```text
CloudTrail Trail一覧を確認し、対象Trailの設定内容を確認した。

対象TrailはMulti-region Trailとして設定されており、
グローバルサービスイベントおよびログファイル検証が有効であった。

CloudTrailログは指定S3バケットへ保存されている。
CloudWatch Logs連携の有無についても確認した。

設定変更は実施していない。
```

## 確認結果記載例: Trailなし

```text
CloudTrail Trail一覧を確認した結果、
現在のAWSアカウントでは参照可能なTrailを確認できなかった。

Event HistoryではManagement Eventを確認できるが、
長期保存、Data Event記録、CloudWatch Logs連携の状況は確認できない。

組織Trail、CloudTrail Lake、別監査基盤の利用有無について
関係者へ確認する必要がある。

設定変更は実施していない。
```

## 6. Trailのログ記録状態を確認する

作成済みTrailが実際にログを記録しているか、S3およびCloudWatch Logsへの配信でエラーが発生していないか確認する。

Trailの設定が存在していても、ログ記録が停止している場合や、保存先への配信に失敗している場合がある。

この手順では設定変更を行わない。

## 前提確認

前手順で確認したTrail名を変数へ設定する。

```bash
TRAIL_NAME="<確認したTrail名>"
```

変数の内容を確認する。

```bash
printf 'TRAIL_NAME=%s\n' "$TRAIL_NAME"
```

Trailが存在しない場合、この手順は実施できない。

学習環境では、次の確認スクリプトを実行すると、Trail設定、稼働状態、Event Selector、ログ保存先S3の設定、配信済みログオブジェクトをまとめて確認できる。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

## Webコンソールによる確認

1. CloudTrailコンソールを開く
2. 左側メニューから「証跡」を選択する
3. 対象Trailを開く
4. Trailのログ記録状態を確認する
5. S3およびCloudWatch Logsへの配信設定を確認する
6. 「ログ記録を停止」は押さない

確認項目:

```text
Trailのログ記録状態
ログ保存先S3バケット
CloudWatch Logs連携
最新ログ配信状況
配信エラーの有無
```

取得するスクリーンショット:

```text
09_CloudTrail_Trailログ記録状態確認.png
```

## AWS CLIによるTrail稼働状態確認

必要な項目だけを読みやすい表形式で表示する。

```bash
aws cloudtrail get-trail-status \
  --profile learning \
  --region ap-northeast-1 \
  --name "$TRAIL_NAME" \
  --query '{
    IsLogging:IsLogging,
    StartLoggingTime:StartLoggingTime,
    StopLoggingTime:StopLoggingTime,
    LatestDeliveryTime:LatestDeliveryTime,
    LatestDeliveryError:LatestDeliveryError,
    LatestCloudWatchLogsDeliveryTime:LatestCloudWatchLogsDeliveryTime,
    LatestCloudWatchLogsDeliveryError:LatestCloudWatchLogsDeliveryError
  }' \
  --output table \
  --no-cli-pager
```

## 結果の読み方

### IsLogging

```text
True:
Trailはログを記録中

False:
Trailのログ記録は停止中
```

`IsLogging=False`の場合は、停止理由、作業履歴、CloudTrailイベントを確認する。

確認だけの作業では、勝手にログ記録を開始しない。

### StartLoggingTime

```text
Trailでログ記録を開始した時刻
```

ログ記録が開始された時刻を確認する。

### StopLoggingTime

```text
Trailでログ記録を停止した時刻
```

値が表示される場合、過去にログ記録が停止された可能性がある。

現在の状態は`IsLogging`と合わせて判断する。

### LatestDeliveryTime

```text
S3バケットへ最後にCloudTrailログを配信した時刻
```

時刻が古い場合は、次を確認する。

- Trailがログ記録中か
- 対象AWSアカウントでイベントが発生しているか
- S3保存先へ配信できているか
- `LatestDeliveryError`が記録されていないか

### LatestDeliveryError

```text
S3バケットへの最新配信エラー
```

値が空の場合、最新のS3ログ配信エラーは記録されていない。

値が表示された場合は、次を確認する。

- 保存先S3バケットが存在するか
- Bucket PolicyがCloudTrailの書き込みを許可しているか
- KMS Key Policyが適切か
- Trail設定の保存先バケット名が正しいか

### LatestCloudWatchLogsDeliveryTime

```text
CloudWatch Logsへ最後にイベントを配信した時刻
```

CloudWatch Logs連携が設定されていない場合は、値が表示されないことがある。

### LatestCloudWatchLogsDeliveryError

```text
CloudWatch Logsへの最新配信エラー
```

値が表示された場合は、次を確認する。

- CloudWatch Logs Log Groupが存在するか
- CloudTrail用IAM Roleが存在するか
- IAM Roleにログ配信権限があるか
- Log Group ARNとIAM Role ARNが正しいか

## Trailの全ステータス確認

調査時に全項目が必要な場合だけ実行する。

```bash
aws cloudtrail get-trail-status \
  --profile learning \
  --region ap-northeast-1 \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager
```

全項目のJSONは証跡として保存し、通常の画面確認には要約表示を使用する。

```bash
mkdir -p 03_Day_Learning/evidence
```

```bash
aws cloudtrail get-trail-status \
  --profile learning \
  --region ap-northeast-1 \
  --name "$TRAIL_NAME" \
  --output json \
  --no-cli-pager \
  > 03_Day_Learning/evidence/cloudtrail-trail-status.json
```

ファイルが作成され、空でないことを確認する。

```bash
ls -l \
  03_Day_Learning/evidence/cloudtrail-trail-status.json

wc -c \
  03_Day_Learning/evidence/cloudtrail-trail-status.json
```

## 正常と判断できる状態

```text
IsLogging:
True

LatestDeliveryError:
値なし

LatestCloudWatchLogsDeliveryError:
CloudWatch Logs連携済みの場合は値なし

LatestDeliveryTime:
継続的に更新されている
```

## 異常時の対応

次の場合は設定変更を行わず、状況を整理して報告する。

- `IsLogging=False`
- `LatestDeliveryError`が表示される
- `LatestCloudWatchLogsDeliveryError`が表示される
- 最新配信時刻が想定より古い
- Trailの保存先S3バケットが存在しない
- CloudTrail用IAM Roleが存在しない

追加調査では、CloudTrailの設定変更イベントを確認する。

代表的なイベント:

```text
StartLogging
StopLogging
UpdateTrail
DeleteTrail
PutEventSelectors
PutInsightSelectors
```

## 確認結果記載例: 正常

```text
対象Trailのログ記録状態を確認した。

IsLoggingはTrueであり、Trailがログ記録中であることを確認した。
S3への最新ログ配信時刻を確認し、LatestDeliveryErrorは記録されていなかった。

CloudWatch Logs連携についても、設定状況および最新配信エラーの有無を確認した。

設定変更は実施していない。
```

## 確認結果記載例: 異常あり

```text
対象Trailの稼働状態を確認した結果、
LatestDeliveryErrorにエラーが記録されていることを確認した。

Trail設定、保存先S3バケット、Bucket PolicyおよびKMS Key Policyの
確認が必要である。

影響調査および承認が必要なため、設定変更は実施していない。
```

## 6.1. Trail保存先S3とPutObject Data Eventを確認する

Trailを作成すると、CloudTrailが記録したイベントをログファイルとしてS3へ継続的に配信できる。

Trail作成直後は、最初のログファイルが配信されるまで数分かかる場合がある。

### Trailログ保存先S3を確認する

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/02_check_cloudtrail_trail.sh
```

確認項目:

```text
IsLogging=True
LatestDeliveryErrorに値がない
Trailログ保存先S3バケットが設定されている
S3へCloudTrailログオブジェクトが配信されている
Management Eventを記録するEvent Selectorが設定されている
```

Trailログ保存先S3にログがまだ表示されない場合は、数分待ってから確認スクリプトを再実行する。

### PutObjectを確認する理由

`PutBucketPolicy`はBucket Policyという設定を変更するManagement Eventである。

Rails Active Storageが画像をS3へ保存するときの`PutObject`は、S3オブジェクトを操作するData Eventである。

```text
PutBucketPolicy:
S3バケット設定の変更
Management Event
Event Historyとlookup-eventsで確認できる

PutObject:
S3オブジェクトの保存
Data Event
通常のEvent Historyとlookup-eventsでは確認できない
```

### 対象バケットのWrite-only Data eventsを有効化する

Data eventsは有料であり、多数発生する可能性がある。検証では対象バケットとWrite Eventに限定する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/01_enable_s3_data_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

スクリプトは変更前Event Selectorを証跡として保存する。既存設定が想定した単純なManagement Event設定と異なる場合は、上書きせず停止する。

### Rails Active Storageから画像をアップロードする

Event Selectorの変更が反映される前にアップロードすると、Data eventが記録されない可能性がある。
有効化スクリプトの完了後、5分程度待ってから新しい画像をアップロードする。

WebブラウザからRailsアプリケーションへログインし、新しい画像をアップロードする。

記録する項目:

- 操作時刻
- アプリケーション上の操作結果
- 投稿または画像の識別情報
- S3へ新しいオブジェクトが保存されたこと

### Trail保存先S3ログからPutObjectを確認する

ログ配信まで5分から15分程度待ってから実行する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/03_check_s3_putobject_events.sh \
  nobu-iac-lab-trail \
  nobu-terraform-iac-lab-upload
```

確認項目:

```text
eventName=PutObject
requestParameters.bucketName=対象バケット
userIdentity.arn=Web EC2のIAM Role Session
userAgentにAWS SDK for Rubyを示す情報が含まれる
errorCodeとerrorMessageが記録されていない
```

### Event Selectorを切り戻す

Data eventsの確認後は、有効化に成功した際、`01_enable_s3_data_events.sh`が表示した`Evidence`ディレクトリを指定して変更前設定へ切り戻す。

```bash
ENABLE_EVIDENCE_DIR="/Users/nobu/aws-reference/evidence/cloudtrail_s3_data_events/REPLACE_WITH_SUCCESSFUL_ENABLE_EVIDENCE"

/Users/nobu/aws-reference/scripts/cloudtrail_s3_data_events/02_restore_s3_event_selectors.sh \
  "$ENABLE_EVIDENCE_DIR"
```

`ls -dt ... | head -n 1`による最新ディレクトリの自動選択は行わない。失敗した有効化処理が、復元に使用できない未完了ディレクトリを残す場合がある。

切り戻し後、対象バケットのData events設定が削除され、変更前Event Selectorと一致することを確認する。

### 一時TrailはDay 3終了時まで残す

後続のEvent History検索はTrailがなくても実施できるが、学習途中での混乱を防ぐため、一時Trailとログ保存先S3バケットはDay 3の全確認終了時まで残す。

## 7. AWS CLIでEvent Historyを検索する

`lookup-events`を使用し、CloudTrail Event Historyから目的のManagement Eventを検索する。

検索結果全体を表示すると読みづらくなるため、`--query`を使用して必要な項目だけを表形式で表示する。

この手順では設定変更を行わない。

## 直近イベントの確認

東京リージョンで発生した直近のManagement Eventを最大10件表示する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --max-results 10 \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName
  }' \
  --output table \
  --no-cli-pager
```

確認項目:

```text
EventTime:
イベント発生時刻

EventName:
実行されたAWS API操作

Username:
操作したIAMユーザーまたはIAMロールのセッション名

ResourceName:
操作対象リソース
```

## EventNameによる検索

`PutBucketPolicy`イベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

この検索では、東京リージョンで発生したすべての`PutBucketPolicy`イベントが表示される可能性がある。

対象バケット名、作業時刻、Event IDを使用して目的のイベントを特定する。

## ResourceNameによる検索

対象S3バケットに関連するイベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=nobu-terraform-iac-lab-upload \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

対象バケットに関連する複数種類のManagement Eventが表示される可能性がある。

## ResourceName検索後にEventNameを絞り込む

`lookup-events`で指定できる検索属性は、一度の実行につき原則1種類となる。

対象バケットで検索した結果から、`PutBucketPolicy`だけを`--query`で絞り込む。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=nobu-terraform-iac-lab-upload \
  --query 'Events[?EventName==`PutBucketPolicy`].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

Day 2で実行した変更時と切り戻し時のイベントが表示されることを確認する。

## Usernameによる検索

IAMユーザー`nobu`が実行したイベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=Username,AttributeValue=nobu \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

ユーザー名による検索では、多数のAWSサービスに対する操作が表示される可能性がある。

対象時刻、EventName、ResourceNameを使用して目的の操作を特定する。

## Event IDによる検索

Event IDは、CloudTrailイベントを一意に識別する値である。

対象Event IDを変数へ設定する。

```bash
EVENT_ID="<確認対象のEventId>"
```

必要な項目だけを表示する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    ResourceType:Resources[0].ResourceType,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

Event ID検索は、一覧から特定したイベントを再確認するときに使用する。

## 時間範囲を指定した検索

調査対象の時間が分かっている場合は、開始時刻と終了時刻を指定して検索範囲を狭める。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --start-time "2026-06-09T06:00:00+09:00" \
  --end-time "2026-06-09T07:00:00+09:00" \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

時間範囲を指定する場合は、JSTとUTCの違いに注意する。

```text
2026-06-09T06:34:00+09:00
=
2026-06-08T21:34:00Z
```

## 書き込みイベントだけを表示する

Event Historyの検索結果から、`ReadOnly`が文字列`"false"`である変更操作だけを表示する。

`lookup-events`の`ReadOnly`は真偽値ではなく文字列として返されるため、JMESPathでも文字列として比較する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --max-results 50 \
  --query "Events[?ReadOnly=='false'].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }" \
  --output table \
  --no-cli-pager
```

設定変更調査では、書き込みイベントを優先して確認すると対象を絞り込みやすい。

ただし、イベントによっては`ReadOnly`の値だけで完全に分類できない場合があるため、EventNameと詳細レコードも確認する。

## 代表的な検索属性

| AttributeKey | 検索対象 |
|---|---|
| `EventName` | AWS API操作名 |
| `EventId` | イベント固有ID |
| `Username` | IAMユーザーやロールセッション名 |
| `ResourceName` | 対象リソース名 |
| `ResourceType` | 対象リソース種別 |
| `EventSource` | AWSサービスのイベントソース |
| `AccessKeyId` | 操作に使用されたアクセスキーID |
| `ReadOnly` | 読み取り・書き込み分類 |

## 検索時の注意事項

- Event Historyはリージョン単位で検索する
- 一度の`lookup-events`で指定する検索属性は1種類とする
- 複数条件が必要な場合は、検索属性と`--query`を組み合わせる
- `--max-results`で取得する件数を制限する
- 検索結果が多い場合は時間範囲を指定する
- 変更直後のイベントは、反映まで数分かかる場合がある
- Event Historyで検索できる期間は過去90日間となる
- S3の`PutObject`などのData Eventは通常のEvent Historyでは確認できない

## 検索結果が表示されない場合

次を確認する。

```text
・対象リージョンは正しいか
・検索属性と検索値は正しいか
・対象操作はManagement Eventか
・対象イベントは過去90日以内か
・イベント発生後、数分待ったか
・別のIAMユーザーやIAMロールで実行されていないか
・cloudtrail:LookupEvents権限があるか
```

## 確認結果記載例

```text
CloudTrail Event HistoryをAWS CLIで検索した。

ResourceNameに対象S3バケットを指定し、
検索結果からPutBucketPolicyイベントを抽出した。

対象イベントのEventTime、Username、ResourceNameおよびEvent IDを確認し、
Day 2で実施したBucket Policy変更操作であることを確認した。

設定変更は実施していない。
```

## 8. S3 Bucket Policy変更イベントを確認する

Day 2で実施したBucket Policy変更と切り戻しについて、CloudTrailの`PutBucketPolicy`イベントを確認する。

変更時と切り戻し時には、どちらも`PutBucketPolicy`が記録される。

そのため、EventTime、Event ID、`requestParameters.bucketPolicy`の内容を使用して、それぞれの操作を識別する。

この手順では設定変更を行わない。

## Webコンソールによる確認

1. CloudTrailコンソールを開く
2. 東京リージョンを選択する
3. 「イベント履歴」を開く
4. 検索属性で「リソース名」を選択する
5. 対象バケット名を入力する
6. `PutBucketPolicy`イベントを確認する
7. 変更時と切り戻し時のイベント詳細を開く
8. Event IDとBucket Policyの内容を確認する

検索対象:

```text
nobu-terraform-iac-lab-upload
```

確認対象イベント:

```text
変更時:
DenyOutdatedTLSが追加されたPutBucketPolicy

切り戻し時:
DenyOutdatedTLSが存在しない元のPolicyを適用したPutBucketPolicy
```

取得するスクリーンショット:

```text
10_CloudTrail_BucketPolicy変更イベント確認.png
11_CloudTrail_BucketPolicy切り戻しイベント確認.png
```

## 対象バケットのPutBucketPolicyイベント一覧確認

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=nobu-terraform-iac-lab-upload \
  --query 'Events[?EventName==`PutBucketPolicy`].{
    EventTime:EventTime,
    Username:Username,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

Day 2の作業時刻を基に、変更時と切り戻し時のEvent IDを特定する。

## Event IDの設定

```bash
CHANGE_EVENT_ID="<Bucket Policy変更時のEventId>"
ROLLBACK_EVENT_ID="<Bucket Policy切り戻し時のEventId>"
```

設定内容を確認する。

```bash
printf 'CHANGE_EVENT_ID=%s\nROLLBACK_EVENT_ID=%s\n' \
  "$CHANGE_EVENT_ID" \
  "$ROLLBACK_EVENT_ID"
```

## 変更時イベントの要約確認

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$CHANGE_EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

期待結果:

```text
EventName:
PutBucketPolicy

Username:
nobu

ReadOnly:
false

ResourceName:
nobu-terraform-iac-lab-upload
```

## 切り戻し時イベントの要約確認

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$ROLLBACK_EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

変更時と切り戻し時の両方で、EventNameは`PutBucketPolicy`となる。

操作内容の違いは、イベント詳細に含まれるBucket Policyを確認して判断する。

## イベント詳細の保存

```bash
mkdir -p 03_Day_Learning/evidence
```

変更時イベントを保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$CHANGE_EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > 03_Day_Learning/evidence/put-bucket-policy-change-event.json
```

切り戻し時イベントを保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$ROLLBACK_EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > 03_Day_Learning/evidence/put-bucket-policy-rollback-event.json
```

保存したファイルを確認する。

```bash
ls -l \
  03_Day_Learning/evidence/put-bucket-policy-change-event.json \
  03_Day_Learning/evidence/put-bucket-policy-rollback-event.json
```

## 変更時Policyの確認

変更時イベントを整形し、適用したBucket Policyの構造を確認する。

```bash
./format_json_awk.sh \
  03_Day_Learning/evidence/put-bucket-policy-change-event.json \
  03_Day_Learning/evidence/put-bucket-policy-change-event-formatted.json

cat \
  03_Day_Learning/evidence/put-bucket-policy-change-event-formatted.json
```

`requestParameters.bucketPolicy.Statement`で次を確認する。

```text
Sid: DenyInsecureTransport
Sid: DenyOutdatedTLS
Condition.NumericLessThan.s3:TlsVersion: 1.2
```

## 切り戻し時Policyの確認

切り戻し時イベントも整形し、変更前Policyへ戻ったことを確認する。

```bash
./format_json_awk.sh \
  03_Day_Learning/evidence/put-bucket-policy-rollback-event.json \
  03_Day_Learning/evidence/put-bucket-policy-rollback-event-formatted.json

cat \
  03_Day_Learning/evidence/put-bucket-policy-rollback-event-formatted.json
```

`requestParameters.bucketPolicy.Statement`で次を確認する。

```text
DenyInsecureTransportが存在する
DenyOutdatedTLSが存在しない
s3:TlsVersionが存在しない
```

## 実行者・接続元・操作方法の確認

整形した変更時イベントで、次のJSONパスを確認する。

```text
eventTime: 変更実施時刻
userIdentity.userName: 操作を実行したIAMユーザー
sourceIPAddress: 操作元IPアドレス
userAgent: AWS CLIまたはWebコンソールなどの操作方法
tlsDetails.tlsVersion: API操作時に使用されたTLSバージョン
```

## エラー有無の確認

整形した変更時イベントと切り戻し時イベントで、`errorCode`と`errorMessage`の有無を目視確認する。
両項目が存在しない場合、対象CloudTrailイベントにはAPIエラーが記録されていない。

ただし、エラー記録がないことだけでは、反映されたPolicyの内容が正しいことまでは証明できない。

## 調査結果

```text
Bucket Policy変更時:
PutBucketPolicyイベントを確認した。
DenyInsecureTransportおよびDenyOutdatedTLSが含まれていた。

Bucket Policy切り戻し時:
PutBucketPolicyイベントを確認した。
DenyInsecureTransportのみが含まれ、DenyOutdatedTLSは存在しなかった。

両イベント:
実行者、対象バケット、実行時刻が想定どおりであった。
errorCodeおよびerrorMessageは記録されていなかった。
```

## 確認結果記載例

```text
CloudTrail Event Historyで、対象S3バケットに対する
Bucket Policy変更時および切り戻し時のPutBucketPolicyイベントを確認した。

変更時イベントにはDenyOutdatedTLSが含まれており、
切り戻し時イベントにはDenyOutdatedTLSが含まれていないことを確認した。

実行者、実行時刻、対象バケットおよび操作方法は想定どおりであった。
両イベントにerrorCodeおよびerrorMessageは記録されていなかった。

CloudTrailのイベント内容と、実際の変更後・切り戻し後Policyを照合した結果、
一連のBucket Policy変更作業が想定どおり実施されたことを確認した。
```

## 注意事項

- 変更時と切り戻し時は、どちらも`PutBucketPolicy`として記録される
- EventNameだけでは操作内容を識別できない
- EventTime、Event ID、`requestParameters.bucketPolicy`を使用して識別する
- CloudTrailイベントにはアクセスキーIDやIPアドレスが含まれる場合がある
- 外部公開する証跡では、機密情報をマスクする

## 9. CloudTrailイベント詳細を確認する

CloudTrailイベントの詳細レコードから、実行者、実行時刻、対象リソース、操作方法、変更内容、エラーの有無を確認する。

`lookup-events`の検索結果には、イベントの要約情報と`CloudTrailEvent`が含まれる。

`CloudTrailEvent`は1行のJSON文字列として返されるため、生JSONは証跡として保存し、通常確認では必要な項目だけを抽出する。

この手順では設定変更を行わない。

## Event IDの設定

確認対象のEvent IDを設定する。

```bash
EVENT_ID="<確認対象のEventId>"
```

```bash
printf 'EVENT_ID=%s\n' "$EVENT_ID"
```

## イベント要約の確認

画面確認用として、主要項目だけを表形式で表示する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    ResourceType:Resources[0].ResourceType,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

確認項目:

```text
EventTime:
操作が実行された時刻

EventName:
実行されたAWS API操作

Username:
操作を実行したユーザーまたはロールセッション名

ReadOnly:
読み取り操作か変更操作か

ResourceName:
操作対象リソース

ResourceType:
操作対象リソースの種類

EventId:
イベントを一意に識別するID
```

## 読みやすい要約の保存

```bash
mkdir -p 03_Day_Learning/evidence
```

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    ResourceType:Resources[0].ResourceType,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager \
  | tee 03_Day_Learning/evidence/cloudtrail-event-summary.txt
```

## 生JSONイベントの保存

詳細調査用として、`CloudTrailEvent`を生JSONのまま保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > 03_Day_Learning/evidence/cloudtrail-event.json
```

ファイルが作成され、空でないことを確認する。

```bash
ls -l \
  03_Day_Learning/evidence/cloudtrail-event.json

wc -c \
  03_Day_Learning/evidence/cloudtrail-event.json
```

生JSONは1行で保存されるため、通常確認ではファイル全体を`cat`しない。

## 基本情報の確認

生JSONを整形し、入れ子構造を維持したまま確認する。

```bash
./format_json_awk.sh \
  03_Day_Learning/evidence/cloudtrail-event.json \
  03_Day_Learning/evidence/cloudtrail-event-formatted.json

cat \
  03_Day_Learning/evidence/cloudtrail-event-formatted.json
```

期待される確認内容:

```text
eventSource:
s3.amazonaws.com

eventName:
PutBucketPolicy

awsRegion:
ap-northeast-1

eventType:
AwsApiCall

eventCategory:
Management

readOnly:
false
```

## 実行者の確認

整形結果の`userIdentity`配下を確認する。

| 項目 | 内容 |
|---|---|
| `type` | IAMUser、AssumedRole、AWSServiceなどの実行主体種別 |
| `userName` | IAMユーザー名 |
| `arn` | 実行者のIAM ARN |
| `accountId` | 実行者が所属するAWSアカウント |

`AssumedRole`の場合、IAMユーザー名ではなくロールARNやロールセッション名が記録される。

## 接続元と操作方法の確認

整形結果で次のJSONパスを確認する。

```text
sourceIPAddress:
操作元IPアドレス

userAgent:
AWS CLI、Webコンソール、AWS SDKなどの操作方法

tlsVersion:
API操作時に使用されたTLSバージョン

cipherSuite:
通信暗号化で使用された暗号スイート
```

AWS CLIから実行した場合、`userAgent`に次のような情報が含まれる。

```text
aws-cli
OS
CPUアーキテクチャ
実行したAWS CLIコマンド
```

## 対象リソースの確認

`PutBucketPolicy`の場合、`requestParameters.bucketName`と`resources`から対象S3バケットを確認する。

## APIへ渡された変更内容の確認

Bucket Policy変更イベントでは、`requestParameters.bucketPolicy`に適用したPolicyが記録される。

整形結果の`requestParameters.bucketPolicy.Statement`を開き、次を確認する。

```text
変更対象のSid
EffectがAllowかDenyか
追加・削除したCondition
対象バケットARN
```

CloudTrailの変更イベントと、実際に反映された設定値を照合して判断する。

## エラー有無の確認

結果の読み方:

```text
errorCodeとerrorMessageが存在しない:
errorCodeとerrorMessageは記録されていない

errorCodeまたはerrorMessageが存在する:
API操作が失敗した可能性があるため、エラー内容を確認する
```

`responseElements:null`が記録されていても、必ずしもエラーではない。

`PutBucketPolicy`など、正常終了時にレスポンス本文を返さないAPIでは`responseElements:null`となる場合がある。

## UTCとJSTの違い

生JSON内の`eventTime`はUTCで記録される。

```text
生JSON:
2026-06-08T21:34:00Z

日本時間:
2026-06-09T06:34:00+09:00
```

報告書には、使用したタイムゾーンを明記する。

## 実行主体種別の代表例

| `userIdentity.type` | 意味 |
|---|---|
| `IAMUser` | IAMユーザーによる操作 |
| `AssumedRole` | IAMロールを引き受けたセッションによる操作 |
| `AWSService` | AWSサービスによる操作 |
| `Root` | ルートユーザーによる操作 |
| `FederatedUser` | フェデレーションユーザーによる操作 |

想定外の実行主体が確認された場合は、操作の正当性を確認する。

## 調査時の確認順序

```text
1. Event IDを特定する
2. EventTimeとEventNameを確認する
3. 実行者とAWSアカウントを確認する
4. 対象リソースを確認する
5. Source IPとUser Agentを確認する
6. RequestParametersで変更内容を確認する
7. ErrorCodeとErrorMessageを確認する
8. 実際の設定値と照合する
9. 調査結果を報告する
```

## 確認結果記載例

```text
CloudTrailイベント詳細を確認した。

対象イベントはPutBucketPolicyであり、
IAMユーザーnobuによってAWS CLIから実行されていた。

対象リソースはnobu-terraform-iac-lab-uploadであり、
requestParametersに記録されたBucket Policyの内容を確認した。

イベントにerrorCodeおよびerrorMessageは記録されていなかった。
CloudTrailイベントと、実際に反映されたBucket Policyを照合した結果、
操作内容は想定どおりであることを確認した。

設定変更は実施していない。
```

## 証跡取り扱い上の注意

CloudTrailイベントには次の情報が含まれる可能性がある。

```text
AWSアカウントID
IAMユーザー名
IAM ARN
アクセスキーID
接続元IPアドレス
リクエストID
対象リソース名
変更したPolicy
```

社外共有やGitHub公開時は、必要に応じて機密情報をマスクする。

## 10. 代表的なAWS変更イベント名を整理する

CloudTrail調査では、設定変更に対応するAWS API名を`EventName`として検索する。

Webコンソールで実施した変更も、内部的にはAWS APIが呼び出されるため、対応するEventNameがCloudTrailへ記録される。

この手順では設定変更を行わない。

## EventName検索の基本コマンド

検索対象のEventNameを変数へ設定する。

```bash
EVENT_NAME="PutBucketPolicy"
```

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue="$EVENT_NAME" \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager
```

## S3の代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `CreateBucket` | S3バケット作成 |
| `DeleteBucket` | S3バケット削除 |
| `PutBucketPolicy` | Bucket Policy設定・変更 |
| `DeleteBucketPolicy` | Bucket Policy削除 |
| `PutBucketPublicAccessBlock` | Bucket-level Public Access Block変更 |
| `DeleteBucketPublicAccessBlock` | Bucket-level Public Access Block削除 |
| `PutBucketEncryption` | デフォルト暗号化設定変更 |
| `DeleteBucketEncryption` | デフォルト暗号化設定削除 |
| `PutBucketVersioning` | Versioning設定変更 |
| `PutBucketLogging` | Server Access Logging設定変更 |
| `PutBucketAcl` | バケットACL変更 |
| `PutBucketOwnershipControls` | Object Ownership設定変更 |
| `PutBucketTagging` | バケットタグ変更 |
| `PutBucketLifecycleConfiguration` | Lifecycle設定変更 |

S3オブジェクト操作はData Eventとなる。

```text
PutObject
GetObject
DeleteObject
```

これらは通常のEvent Historyでは確認できないため、Data Event記録設定を確認する。

## IAMの代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `CreateUser` | IAMユーザー作成 |
| `DeleteUser` | IAMユーザー削除 |
| `CreateRole` | IAMロール作成 |
| `DeleteRole` | IAMロール削除 |
| `AttachUserPolicy` | IAMユーザーへ管理Policyを追加 |
| `DetachUserPolicy` | IAMユーザーから管理Policyを削除 |
| `AttachRolePolicy` | IAMロールへ管理Policyを追加 |
| `DetachRolePolicy` | IAMロールから管理Policyを削除 |
| `PutUserPolicy` | IAMユーザーへインラインPolicyを設定 |
| `PutRolePolicy` | IAMロールへインラインPolicyを設定 |
| `CreateAccessKey` | アクセスキー作成 |
| `DeleteAccessKey` | アクセスキー削除 |
| `UpdateAccessKey` | アクセスキー状態変更 |
| `EnableMFADevice` | MFAデバイス有効化 |
| `DeactivateMFADevice` | MFAデバイス無効化 |
| `UpdateAssumeRolePolicy` | IAMロールの信頼Policy変更 |

IAMはグローバルサービスであるため、東京リージョンでイベントを確認できない場合は、米国東部（バージニア北部）の`us-east-1`も確認する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region us-east-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateUser \
  --output table \
  --no-cli-pager
```

## EC2・VPC・Security Groupの代表的な変更イベント

VPC、Subnet、Route Table、Security Groupなどの操作は、主に`ec2.amazonaws.com`のイベントとして記録される。

| EventName | 操作内容 |
|---|---|
| `RunInstances` | EC2インスタンス作成 |
| `TerminateInstances` | EC2インスタンス終了 |
| `StartInstances` | EC2インスタンス起動 |
| `StopInstances` | EC2インスタンス停止 |
| `ModifyInstanceAttribute` | EC2属性変更 |
| `AssociateIamInstanceProfile` | EC2へIAM Roleを関連付け |
| `CreateVpc` | VPC作成 |
| `DeleteVpc` | VPC削除 |
| `CreateSubnet` | Subnet作成 |
| `DeleteSubnet` | Subnet削除 |
| `CreateRoute` | Route追加 |
| `ReplaceRoute` | Route変更 |
| `DeleteRoute` | Route削除 |
| `AuthorizeSecurityGroupIngress` | Security Group受信ルール追加 |
| `RevokeSecurityGroupIngress` | Security Group受信ルール削除 |
| `AuthorizeSecurityGroupEgress` | Security Group送信ルール追加 |
| `RevokeSecurityGroupEgress` | Security Group送信ルール削除 |
| `CreateNetworkAclEntry` | NACLルール追加 |
| `ReplaceNetworkAclEntry` | NACLルール変更 |
| `DeleteNetworkAclEntry` | NACLルール削除 |
| `CreateVpcEndpoint` | VPC Endpoint作成 |
| `ModifyVpcEndpoint` | VPC Endpoint変更 |
| `DeleteVpcEndpoints` | VPC Endpoint削除 |
| `CreateFlowLogs` | VPC Flow Logs作成 |
| `DeleteFlowLogs` | VPC Flow Logs削除 |

## RDSの代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `CreateDBInstance` | DBインスタンス作成 |
| `ModifyDBInstance` | DBインスタンス設定変更 |
| `DeleteDBInstance` | DBインスタンス削除 |
| `StartDBInstance` | DBインスタンス起動 |
| `StopDBInstance` | DBインスタンス停止 |
| `CreateDBSnapshot` | DB Snapshot作成 |
| `DeleteDBSnapshot` | DB Snapshot削除 |
| `ModifyDBSnapshotAttribute` | DB Snapshot共有設定変更 |
| `CreateDBSubnetGroup` | DB Subnet Group作成 |
| `ModifyDBSubnetGroup` | DB Subnet Group変更 |
| `DeleteDBSubnetGroup` | DB Subnet Group削除 |
| `ModifyDBParameterGroup` | DB Parameter Group変更 |
| `AddTagsToResource` | RDSリソースへタグ追加 |
| `RemoveTagsFromResource` | RDSリソースからタグ削除 |

`ModifyDBInstance`では複数の設定を変更できるため、イベント詳細の`requestParameters`を確認する。

確認対象例:

```text
PubliclyAccessible
DeletionProtection
BackupRetentionPeriod
VpcSecurityGroupIds
EnableCloudwatchLogsExports
```

## Lambdaの代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `CreateFunction20150331` | Lambda関数作成 |
| `DeleteFunction20150331` | Lambda関数削除 |
| `UpdateFunctionCode20150331v2` | Lambda関数コード更新 |
| `UpdateFunctionConfiguration20150331v2` | Lambda関数設定変更 |
| `AddPermission20150331v2` | Resource-based Policyへ許可追加 |
| `RemovePermission20150331v2` | Resource-based Policyから許可削除 |
| `CreateFunctionUrlConfig` | Function URL作成 |
| `UpdateFunctionUrlConfig` | Function URL変更 |
| `DeleteFunctionUrlConfig` | Function URL削除 |
| `PutFunctionConcurrency` | 同時実行数設定 |
| `TagResource20170331v2` | Lambda関数へタグ追加 |
| `UntagResource20170331v2` | Lambda関数からタグ削除 |

LambdaのEventNameには、CloudTrail上でAPIバージョンを含む名前が記録される場合がある。

実際の環境でEventNameを確認し、検索値として使用する。

## CloudTrailの代表的な変更イベント

CloudTrail自体の停止・削除・変更は、監査機能へ影響する重要なイベントである。

| EventName | 操作内容 |
|---|---|
| `CreateTrail` | Trail作成 |
| `UpdateTrail` | Trail設定変更 |
| `DeleteTrail` | Trail削除 |
| `StartLogging` | Trailのログ記録開始 |
| `StopLogging` | Trailのログ記録停止 |
| `PutEventSelectors` | Event Selector変更 |
| `PutInsightSelectors` | Insights Selector変更 |
| `CreateEventDataStore` | Event Data Store作成 |
| `UpdateEventDataStore` | Event Data Store変更 |
| `DeleteEventDataStore` | Event Data Store削除 |

特に次のイベントは、発生時に早急な確認が必要となる。

```text
StopLogging
DeleteTrail
UpdateTrail
PutEventSelectors
DeleteEventDataStore
```

## CloudWatchの代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `PutMetricAlarm` | CloudWatch Alarm作成・変更 |
| `DeleteAlarms` | CloudWatch Alarm削除 |
| `DisableAlarmActions` | Alarmアクション無効化 |
| `EnableAlarmActions` | Alarmアクション有効化 |
| `PutRetentionPolicy` | Log Group保持期間変更 |
| `DeleteRetentionPolicy` | Log Group保持期間削除 |
| `PutMetricFilter` | Metric Filter作成・変更 |
| `DeleteMetricFilter` | Metric Filter削除 |
| `DeleteLogGroup` | Log Group削除 |

## GuardDutyの代表的な変更イベント

| EventName | 操作内容 |
|---|---|
| `CreateDetector` | GuardDuty Detector作成 |
| `UpdateDetector` | GuardDuty Detector設定変更 |
| `DeleteDetector` | GuardDuty Detector削除 |
| `CreateFilter` | Finding Filter作成 |
| `UpdateFilter` | Finding Filter変更 |
| `ArchiveFindings` | FindingをArchive化 |
| `CreateSampleFindings` | サンプルFinding作成 |

GuardDuty Detectorの無効化・削除や、FindingのArchive操作は、操作理由を確認する。

## EventSourceによる検索

S3イベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=s3.amazonaws.com \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName
  }' \
  --output table \
  --no-cli-pager
```

EC2・VPC・Security Groupイベントを検索する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ResourceName:Resources[0].ResourceName
  }' \
  --output table \
  --no-cli-pager
```

## EventName整理表

調査で確認したEventNameを記録する。

| サービス | EventName | 操作内容 | 重要度 | 確認結果 |
|---|---|---|---|---|
| S3 | `PutBucketPolicy` | Bucket Policy変更 | High |  |
| S3 | `PutBucketPublicAccessBlock` | Public Access Block変更 | Critical |  |
| IAM | `CreateAccessKey` | アクセスキー作成 | High |  |
| IAM | `AttachRolePolicy` | IAM Role権限追加 | High |  |
| EC2 | `AuthorizeSecurityGroupIngress` | SG受信ルール追加 | High |  |
| RDS | `ModifyDBInstance` | RDS設定変更 | High |  |
| Lambda | `AddPermission20150331v2` | Lambda呼び出し許可追加 | High |  |
| CloudTrail | `StopLogging` | Trailログ記録停止 | Critical |  |
| CloudWatch | `DisableAlarmActions` | Alarm通知無効化 | High |  |
| GuardDuty | `DeleteDetector` | Detector削除 | Critical |  |

## 確認時の注意事項

- EventNameはAWS API操作名となる
- Webコンソール操作でも、内部的に呼び出されたAPI名が記録される
- 同じ目的の操作でも、サービスや実行方法によって複数イベントが記録される場合がある
- ResourceNameが記録されないイベントもある
- 詳細な変更内容は`requestParameters`を確認する
- IAMなどのグローバルサービスは`us-east-1`で確認が必要な場合がある
- 一覧を暗記するのではなく、目的の設定に対応するAPI名を調べて検索する

## 確認結果記載例

```text
AWSサービスごとの代表的な設定変更イベントを整理した。

S3 Bucket Policy変更はPutBucketPolicy、
Security Group受信ルール追加はAuthorizeSecurityGroupIngress、
RDS設定変更はModifyDBInstanceとして記録される。

CloudTrailのStopLoggingやDeleteTrailなど、
監査機能へ影響するイベントは特に重要な確認対象となる。

実際の調査ではEventNameだけで判断せず、
実行者、対象リソース、requestParameters、エラーの有無を確認する。
```

## 11. CloudTrail調査証跡を整理する

CloudTrail調査で確認したイベントについて、第三者が調査内容と判断結果を確認できるように証跡を整理する。

証跡は、確認用の要約、生JSON、主要項目の抽出結果、Webコンソールのスクリーンショットに分けて保存する。

この手順では設定変更を行わない。

## 証跡ディレクトリの作成

```bash
mkdir -p \
  03_Day_Learning/evidence/summary \
  03_Day_Learning/evidence/raw \
  03_Day_Learning/evidence/extracted \
  03_Day_Learning/screenshots
```

想定するディレクトリ構成:

```text
03_Day_Learning/
├── evidence/
│   ├── summary/
│   ├── raw/
│   └── extracted/
└── screenshots/
```

## Event IDの設定

確認対象のEvent IDを設定する。

```bash
EVENT_ID="<確認対象のEventId>"
```

```bash
printf 'EVENT_ID=%s\n' "$EVENT_ID"
```

## 読みやすいイベント要約の保存

確認・報告用として、主要項目だけを表形式で保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].{
    EventTime:EventTime,
    EventName:EventName,
    Username:Username,
    ReadOnly:ReadOnly,
    ResourceName:Resources[0].ResourceName,
    ResourceType:Resources[0].ResourceType,
    EventId:EventId
  }' \
  --output table \
  --no-cli-pager \
  | tee 03_Day_Learning/evidence/summary/cloudtrail-event-summary.txt
```

要約ファイルでは次の情報を確認する。

```text
イベント発生時刻
イベント名
実行者
読み取り・書き込み区分
対象リソース名
対象リソース種別
Event ID
```

## 生JSONイベントの保存

詳細調査や正式証跡として、イベントの全内容を保存する。

```bash
aws cloudtrail lookup-events \
  --profile learning \
  --region ap-northeast-1 \
  --lookup-attributes AttributeKey=EventId,AttributeValue="$EVENT_ID" \
  --query 'Events[0].CloudTrailEvent' \
  --output text \
  --no-cli-pager \
  > 03_Day_Learning/evidence/raw/cloudtrail-event.json
```

生JSONは1行で保存されるため、通常確認ではファイル全体を`cat`しない。

## 読みやすい証跡を保存する

生JSONを整形したファイルを保存する。

```bash
./format_json_awk.sh \
  03_Day_Learning/evidence/raw/cloudtrail-event.json \
  03_Day_Learning/evidence/extracted/cloudtrail-event-formatted.json
```

整形済み証跡を表示し、基本情報、実行者、接続元、変更内容、エラー有無をJSONパスに沿って確認する。

```bash
cat \
  03_Day_Learning/evidence/extracted/cloudtrail-event-formatted.json
```

## 保存した証跡の確認

証跡ファイル一覧を確認する。

```bash
find 03_Day_Learning \
  -type f \
  -print \
  | sort
```

空ファイルを確認する。

```bash
find 03_Day_Learning \
  -type f \
  -size 0 \
  -print \
  | sort
```

`05_error_information.txt`は、エラーが記録されていない場合に空ファイルとなる。

それ以外の証跡ファイルが空の場合は、コマンド結果やEvent IDを再確認する。

## スクリーンショット証跡

Webコンソールで次の画面を取得する。

```text
01_CloudTrail操作アカウント確認.png
02_CloudTrail対象リージョン確認.png
03_CloudTrail_Event_History一覧確認.png
04_CloudTrail_EventName検索結果.png
05_CloudTrail_対象リソース検索結果.png
06_CloudTrail_イベント詳細確認.png
07_CloudTrail_イベントレコード確認.png
08_CloudTrail_Trail一覧確認.png
09_CloudTrail_Trailログ記録状態確認.png
```

スクリーンショットには、可能な範囲で次の情報を含める。

```text
対象AWSアカウント
対象リージョン
検索条件
イベント名
イベント発生時刻
実行者
対象リソース
Event ID
```

## 証跡の役割

| 証跡 | 用途 |
|---|---|
| 要約ファイル | 作業結果確認、報告、レビュー |
| 生JSON | 詳細調査、正式なイベント内容確認 |
| 抽出結果 | 必要項目の迅速な確認 |
| スクリーンショット | Webコンソール上での確認証跡 |
| Event ID | 対象イベントの一意な識別 |

## 証跡取り扱い上の注意

CloudTrailイベントには次の情報が含まれる可能性がある。

```text
AWSアカウントID
IAMユーザー名・ロール名
IAM ARN
アクセスキーID
接続元IPアドレス
対象リソース名
Bucket Policy
リクエストID
```

証跡をGitHubや社外へ公開する場合は、機密情報をマスクする。

証跡の編集が禁止されている場合は、原本を変更せず、公開用の複製ファイルを作成してマスクする。

## 証跡一覧記載例

| No. | 証跡 | 確認内容 | 結果 |
|---|---|---|---|
| 1 | CloudTrail Event History一覧 | 対象イベントの存在 | OK |
| 2 | Event ID検索結果 | 実行者・時刻・対象リソース | OK |
| 3 | 生JSONイベント | API操作の詳細 | OK |
| 4 | Request Parameters抽出結果 | Bucket Policy変更内容 | OK |
| 5 | エラー情報抽出結果 | エラー記録なし | OK |
| 6 | Trail稼働状態 | ログ記録・配信状態 | OK / 未設定 |

## 確認結果記載例

```text
CloudTrail調査証跡を、要約、生JSON、主要項目抽出結果、
Webコンソールのスクリーンショットに分類して保存した。

対象イベントのEvent ID、実行者、実行時刻、対象リソース、
リクエスト内容およびエラーの有無を確認できる状態とした。

生JSONは調査用原本として保持し、
通常確認には読みやすい要約および抽出結果を使用する。

設定変更は実施していない。
```

## 12. CloudTrail調査結果を報告形式でまとめる

CloudTrail調査結果を、作業担当者以外でも判断できる形式で整理する。

報告では、確認した事実、判断結果、未確認事項、追加対応の要否を分けて記載する。

この手順では設定変更を行わない。

## 報告に必要な項目

```text
調査対象
調査目的
対象AWSアカウント
対象リージョン
調査対象期間
検索条件
対象Event ID
実行者
実行時刻
操作内容
対象リソース
接続元
操作方法
エラーの有無
実際の設定との照合結果
追加調査・対応の要否
証跡保存先
```

## 調査結果一覧

| 確認項目 | 確認結果 |
|---|---|
| 対象AWSアカウント | `445405559057` |
| 対象リージョン | `ap-northeast-1` |
| EventName | `PutBucketPolicy` |
| EventSource | `s3.amazonaws.com` |
| 実行者 | IAMユーザー`nobu` |
| 対象リソース | `nobu-terraform-iac-lab-upload` |
| 操作種別 | Management Event / Write Event |
| 操作方法 | AWS CLI |
| ErrorCode | 記録なし |
| ErrorMessage | 記録なし |
| 設定照合 | Bucket PolicyとCloudTrailイベントを照合 |
| 判定 | 正常 |
| 設定変更 | なし |

## 事実と判断を分ける

報告では、確認できた事実と担当者の判断を分けて記載する。

### 確認できた事実

```text
・CloudTrailにPutBucketPolicyイベントが記録されている
・実行者はIAMユーザーnobuである
・対象リソースはnobu-terraform-iac-lab-uploadである
・操作はAWS CLIから実行されている
・イベントにerrorCodeおよびerrorMessageは記録されていない
・requestParametersにBucket Policy変更内容が記録されている
```

### 判断結果

```text
・作業時刻、実行者、対象リソースは想定どおりである
・CloudTrail上ではAPI操作が正常終了したと判断する
・実際のBucket Policyとイベント内容が一致している
・追加対応は不要と判断する
```

## 詳細な調査報告例

```text
件名:
S3 Bucket Policy変更履歴のCloudTrail確認結果

調査目的:
対象S3バケットに対するBucket Policy変更および切り戻しが、
想定した実行者と内容で実施されたことを確認する。

対象AWSアカウント:
445405559057

対象リージョン:
ap-northeast-1

対象リソース:
nobu-terraform-iac-lab-upload

確認結果:
CloudTrail Event Historyで、対象バケットに対する
PutBucketPolicyイベントを確認した。

Bucket Policy変更時のイベントにはDenyOutdatedTLSが含まれており、
切り戻し時のイベントにはDenyOutdatedTLSが含まれていないことを確認した。

両イベントの実行者、実行時刻、対象リソースは想定どおりであった。
errorCodeおよびerrorMessageは記録されていなかった。

CloudTrailイベントのrequestParametersと、
実際の変更後および切り戻し後Bucket Policyを照合した結果、
一連の操作は想定どおり実施されたと判断した。

追加対応:
なし

証跡保存先:
03_Day_Learning/evidence/
03_Day_Learning/screenshots/
```

## Teams報告例

```text
CloudTrailによるS3 Bucket Policy変更履歴の確認が完了した。

対象:
nobu-terraform-iac-lab-upload

確認結果:
・変更時と切り戻し時のPutBucketPolicyイベントを確認
・実行者、時刻、対象バケットは想定どおり
・変更時イベントにDenyOutdatedTLSが記録されていることを確認
・切り戻し時イベントにDenyOutdatedTLSが存在しないことを確認
・errorCodeおよびerrorMessageの記録なし
・現在のBucket Policyは変更前の状態へ切り戻し済み

判定:
正常

追加対応:
なし
```

## 異常が確認された場合の報告例

```text
CloudTrail調査の結果、想定外のPutBucketPolicyイベントを確認した。

対象:
<対象バケット>

確認内容:
・実行者: <想定外のIAMユーザーまたはIAMロール>
・実行時刻: <時刻>
・Event ID: <Event ID>
・接続元IPアドレス: <Source IP>
・変更内容: <確認した変更内容>

影響:
現在のBucket Policyと想定Policyに差異がある。

現在の対応:
追加の設定変更は行わず、関係者へ報告した。
対象イベント、現在のPolicy、関連するCloudTrailイベントを調査中。

確認依頼:
当該操作が承認済み作業であるか確認をお願いしたい。
```

## イベントが見つからない場合の報告例

```text
CloudTrail Event Historyで対象イベントを検索したが、
確認時点では該当イベントを確認できなかった。

確認済み項目:
・対象AWSアカウント
・対象リージョン
・EventName
・ResourceName
・対象時刻
・Management Eventであること

考えられる要因:
・CloudTrail Event Historyへの反映遅延
・対象リージョンの相違
・別のIAMユーザーまたはIAMロールによる操作
・検索条件の相違
・対象イベントが確認可能期間外

対応:
時間を置いて再検索し、必要に応じて別リージョンおよび
Trail、Event Data Store、関連ログを確認する。
```

## Trail未設定時の報告例

```text
CloudTrail Trail一覧を確認した結果、
現在のAWSアカウントでは参照可能なTrailを確認できなかった。

Event Historyによる過去90日間のManagement Event確認は可能である。

一方で、長期保存、Data Event記録、CloudWatch Logs連携の状況は
確認できないため、組織Trail、CloudTrail Lake、
別監査基盤の利用有無を確認する必要がある。

設定変更は実施していない。
```

## 報告時の注意事項

- 確認できた事実と判断を分ける
- 「エラー記録なし」と「設定が正しい」を同じ意味にしない
- UTCとJSTのどちらで記載したか明示する
- Event IDを記録する
- 未確認事項を隠さず記載する
- 設定変更を実施していない場合は明記する
- 機密情報をTeamsやチケットへ貼り付ける場合は現場ルールを確認する
- 緊急度が高い場合は、報告書完成を待たず先に連絡する

## Day 3で習得した内容

```text
・CloudTrailの役割
・Management EventとData Eventの違い
・AWSアカウントとリージョンの確認
・WebコンソールによるEvent History検索
・一時検証用Trailの作成と削除
・Trail設定とログ記録状態の確認
・Trailログ保存先S3へのログ配信確認
・Event Selectorの確認と切り戻し
・Rails Active StorageのPutObject Data Event確認
・lookup-eventsによるイベント検索
・Event IDによる詳細確認
・実行者、対象リソース、変更内容、エラーの確認
・代表的なAWS変更イベント名
・CloudTrail証跡の整理
・調査結果の報告
```

## Day 3完了条件

```text
・Management EventとData Eventの違いを説明できる
・Event HistoryとTrailの違いを説明できる
・一時検証用Trailを作成し、設定と稼働状態を確認できる
・Trailログ保存先S3へのログ配信を確認できる
・対象S3バケットに限定してData eventsを有効化し、変更前設定へ切り戻せる
・Rails Active StorageによるPutObjectをTrail保存先S3ログから確認できる
・学習終了後に一時Trailとログ保存先S3バケットを削除できる
・lookup-eventsで目的のイベントを検索できる
・Event IDを使用してイベントを特定できる
・実行者、実行時刻、対象リソース、変更内容を説明できる
・CloudTrailイベントと実際のAWS設定を照合できる
・読みやすい要約と生JSON証跡を分けて保存できる
・調査結果をTeamsや作業報告へ記載できる
```

## Day 3終了処理

Day 3の全確認、S3 Data Eventの切り戻し、必要な証跡確認が完了した後、一時Trailとログ保存先S3バケットを削除する。

```bash
/Users/nobu/aws-reference/scripts/cloudtrail_trail_lab/03_delete_cloudtrail_trail.sh
```

削除後もEvent Historyによる過去90日間のManagement Event検索は可能である。
一方、Trail保存先S3を使用するログ確認やS3 Data Eventの追加検証を再度行う場合は、一時Trailを再作成する必要がある。

実案件では、既存Trail、Event Selector、監査ログ保存先を独断で変更・削除しない。
