# 案件理解: オンプレミス、S3、CloudTrail、GuardDutyのつながり

## 1. このドキュメントの目的

このドキュメントは、金融系案件で想定されるオンプレミス環境とAmazon S3の連携、およびCloudTrail、GuardDuty、CloudWatchなどの監査・検知サービスとの関係を整理するためのメモである。

案件では、S3バケットポリシーの設定変更が複数予定されており、CloudTrail、CloudWatch、GuardDuty周辺も重点キャッチアップ領域として挙げられている。

これらは別々のAWSサービスだが、以下の流れとしてつながる可能性がある。

```text
オンプレミスまたはAWS上の業務システム
  ↓
S3へ業務データを保存・取得
  ↓
CloudTrailで操作履歴を記録・調査
  ↓
GuardDutyで不審な操作を分析・検知
  ↓
EventBridge / CloudWatch / SNSなどで通知・監視
```

重要:

```text
この案件で実際にオンプレミスからS3へデータを送っているか、
どの接続方式やAWSサービスを利用しているかは、現時点では未確認である。

以下の構成は、金融系システムで考えられる仮説として整理する。
案件初日に構成資料や担当者への確認が必要である。
```

## 2. 各サービスの役割

| サービス | 主な役割 |
| :--- | :--- |
| Amazon S3 | 振込データ、帳票、電子保管ファイル、ログ、バックアップなどの保存 |
| AWS Direct Connect | オンプレミスとAWSを専用接続で接続 |
| Site-to-Site VPN | オンプレミスとAWS間をIPsecで暗号化して接続 |
| S3 Interface VPC Endpoint | オンプレミスやVPCからPrivate IP経由でS3へ接続 |
| S3 Gateway VPC Endpoint | VPC内リソースからS3へPrivate経路で接続 |
| AWS DataSync | オンプレミスのNFS、SMB、HDFS、Object StorageなどからS3へデータ転送 |
| S3 File Gateway | オンプレミスからNFS / SMBファイル共有としてS3を利用 |
| AWS Transfer Family | SFTP、FTPS、FTPなどで受け取ったファイルをS3へ保存 |
| CloudTrail | S3設定変更やオブジェクト操作を記録・調査 |
| GuardDuty | CloudTrailイベントなどを分析して不審な操作を検知 |
| CloudWatch | ログ検索、Metric Filter、Alarm、運用監視 |
| EventBridge | GuardDuty Findingなどのイベントを通知・自動処理へ連携 |

## 3. 想定される全体構成

### 3.1 オンプレミスからS3へ直接接続する構成

```text
銀行オンプレミス
  業務サーバー / ファイルサーバー
        ↓
Direct Connect
または
Site-to-Site VPN
        ↓
接続用VPC / Transit Gateway
        ↓
S3 Interface VPC Endpoint
        ↓
Amazon S3
```

この構成では、オンプレミスのシステムがS3 APIを使って、直接S3へファイルを保存・取得する可能性がある。

確認ポイント:

- Direct ConnectまたはVPNの経路
- Transit Gateway Route Table
- VPC Route Table
- S3 Interface Endpoint
- Interface EndpointのSecurity Group
- Private DNS / Route 53 Resolver
- IAM RoleまたはAccess Key
- S3 Bucket Policy
- KMS Key Policy

### 3.2 AWS上の中継サーバーを経由する構成

```text
銀行オンプレミス
        ↓
Direct Connect / VPN
        ↓
AWS上のEC2 / Transfer Family / Lambda
        ↓
S3 Gateway EndpointまたはS3 API
        ↓
Amazon S3
```

この構成では、オンプレミスから受信したファイルを、AWS上のサービスがS3へ保存する。

確認ポイント:

- オンプレミスから中継サービスまでの通信
- 中継サービスのIAM Role
- S3 Bucket Policy
- S3 VPC Endpoint Policy
- ファイル受信後の加工・検証処理
- エラー時の再送・重複制御

### 3.3 DataSyncを利用する構成

```text
オンプレミスNFS / SMB / HDFS / Object Storage
        ↓
DataSync Agent
        ↓ TLS
AWS DataSync
        ↓
Amazon S3
```

DataSyncは、オンプレミスのファイルやオブジェクトをS3へ定期・大量転送する場合に利用できる。

確認ポイント:

- DataSync Agentの配置場所
- DataSync Task
- Source Location / Destination Location
- DataSync用IAM Role
- S3 Bucket Policy
- CloudWatch Logs
- 転送スケジュール
- 転送失敗時の再実行

### 3.4 S3 File Gatewayを利用する構成

```text
オンプレミス業務サーバー
        ↓ NFS / SMB
S3 File Gateway
        ↓
Amazon S3
```

S3 File Gatewayを使うと、オンプレミス側は通常のファイル共有として利用しながら、保存先をS3にできる。

確認ポイント:

- NFS / SMB共有
- Gateway VM / Appliance
- キャッシュ領域
- S3 Bucket
- IAM Role
- KMS暗号化
- FileとS3 Objectの対応関係

## 4. 閉域網とS3アクセス

### 4.1 S3 Gateway Endpoint

S3 Gateway Endpointは、VPC内のEC2やLambdaなどからS3へアクセスするための経路である。

```text
VPC内のEC2 / Lambda
  ↓
S3 Gateway Endpoint
  ↓
Amazon S3
```

特徴:

- VPC Route TableへS3 Prefix List向け経路を追加する
- Internet GatewayやNAT Gatewayを経由せずS3へ接続できる
- Gateway Endpoint自体の追加料金はない
- オンプレミスからVPN、Direct Connect、Transit Gateway経由で直接利用することはできない

### 4.2 S3 Interface Endpoint

S3 Interface EndpointはPrivate IPを持つENIとしてVPC内に作成される。

```text
オンプレミス
  ↓ Direct Connect / VPN
VPC内のS3 Interface Endpoint
  ↓
Amazon S3
```

特徴:

- オンプレミスからDirect ConnectまたはVPN経由で利用できる
- Interface EndpointのSecurity Group確認が必要
- Private DNSやEndpoint固有DNS名を確認する
- 利用時間とデータ処理量に応じた料金が発生する

### 4.3 Direct Connectと暗号化

Direct Connectは、オンプレミスとAWSを専用接続で結ぶサービスである。

ただし、Direct Connectの通信は標準で自動的に暗号化されるわけではない。

暗号化が必要な場合は、以下のような方式を確認する。

- HTTPS / TLSによるアプリケーションレベルの暗号化
- Direct Connect上でSite-to-Site VPNを利用する
- 対応接続でMACsecを利用する

案件での確認ポイント:

```text
閉域接続であることと、通信が暗号化されていることは別の確認項目である。
```

## 5. S3とCloudTrailのつながり

CloudTrailは、AWS上で行われたAPI操作を記録・調査するためのサービスである。

S3では、主にManagement eventsとData eventsを区別する。

### 5.1 Management events

Management eventsは、S3バケット自体の設定変更などを記録する。

代表例:

```text
CreateBucket
DeleteBucket
PutBucketPolicy
DeleteBucketPolicy
PutBucketPublicAccessBlock
DeletePublicAccessBlock
PutBucketEncryption
PutBucketLogging
PutBucketVersioning
```

今回想定されているS3バケットポリシー変更作業は、主に `PutBucketPolicy` として記録される。

確認できる情報:

- 誰が変更したか
- いつ変更したか
- どのAPIを実行したか
- どのIPアドレスから実行したか
- Webコンソール、CLI、SDKのどれを使ったか
- エラーが発生したか

### 5.2 Data events

Data eventsは、S3 Objectに対する操作を記録する。

代表例:

```text
PutObject
GetObject
DeleteObject
ListObjects
```

オンプレミスやAWS上の業務システムからS3へファイルを送信した場合、最終的なS3操作は `PutObject` などとして記録される可能性がある。

注意:

```text
通常のCloudTrail Event Historyでは、S3 Object-levelのData eventsは確認できない。
人が後からData eventsを調査・保存するには、TrailまたはEvent Data Storeで対象S3 Data eventsを設定する。
Data eventsは高頻度になる可能性があり、料金と保存量を確認する。
```

### 5.3 S3変更作業後のCloudTrail確認例

```text
1. 作業者がBucket Policyを変更する
2. CloudTrailでPutBucketPolicyを確認する
3. オンプレミスまたはアプリからテストファイルを送信する
4. S3でObjectが保存されたことを確認する
5. CloudTrail Data eventsを記録している場合、PutObjectを確認する
6. 証跡として作業者、時刻、対象Bucket、結果を保存する
```

## 6. S3とGuardDutyのつながり

GuardDutyは、CloudTrailイベント、VPC Flow Logs、Route 53 Resolver DNS Query Logsなどを分析し、不審な動作をFindingとして通知する。

### 6.1 GuardDutyの基本データソース

GuardDutyを有効にすると、以下の基本データソースを独立した経路で分析する。

- CloudTrail Management events
- VPC Flow Logs
- Route 53 Resolver DNS Query Logs

GuardDutyはこれらのデータを分析するために、ユーザーが作成したTrailやFlow Logs設定を直接利用するわけではない。

重要:

```text
GuardDutyが分析できることと、人がCloudTrailやFlow Logsを後から閲覧・保存できることは別である。

人による調査や監査証跡が必要な場合は、
CloudTrail Trail、Data events、VPC Flow Logsなどを別途設定する。
```

### 6.2 GuardDuty S3 Protection

GuardDuty S3 Protectionを有効にすると、S3のCloudTrail Data eventsを分析し、S3 Objectへの不審な操作を検知する。

分析対象となる代表操作:

```text
GetObject
PutObject
ListObjects
DeleteObject
```

想定される検知:

- 盗まれたIAM認証情報を使ったS3アクセス
- 普段と異なる操作パターン
- 不審なデータ取得
- データ破壊につながる不審な削除
- S3データを含む複数段階の攻撃

GuardDuty S3 Protectionのために、ユーザー側でCloudTrail TrailへS3 Data eventsを明示設定する必要はない。

ただし、人が詳細調査や証跡保存を行うためには、CloudTrail Data eventsの記録も検討する。

### 6.3 S3バケットポリシー変更とGuardDuty

S3 Bucket Policy変更はCloudTrail Management eventとして記録され、GuardDutyの基本脅威検知でも分析対象になり得る。

ただし、正常な承認済み作業を行っただけで、必ずGuardDuty Findingが発生するわけではない。

GuardDutyで見るべきこと:

- 作業後に新しいFindingが発生していないか
- S3BucketまたはAccessKeyに関連するFindingがないか
- 作業者とは異なるIAM Principalによる操作がないか
- 想定外RegionやSource IPからアクセスされていないか

## 7. CloudWatch / EventBridgeとのつながり

CloudWatchとEventBridgeは、ログの検索やFindingの通知に利用できる。

### 7.1 CloudWatch

CloudWatchの用途:

- CloudTrailをCloudWatch Logsへ送信する
- Metric Filterで特定イベントを検知する
- Alarmを作成する
- DataSync、Lambda、EC2などのログを確認する
- VPC Flow Logsを検索する

S3関連で考えられる検知例:

```text
DeleteBucketPolicy
DeletePublicAccessBlock
PutBucketAcl
PutBucketPolicy
PutBucketEncryption
```

すべての変更をAlarmにすると通知過多になるため、現場の監視要件に合わせて検知対象を決める。

### 7.2 EventBridge

EventBridgeの用途:

- GuardDuty Findingを受信する
- Findingの重要度に応じてSNSやLambdaへ連携する
- 自動通知や自動対応処理を起動する

例:

```text
GuardDuty Finding
  ↓
EventBridge Rule
  ↓
SNS / Email / Chat通知
  ↓
担当者が調査
```

## 8. 一連の作業として見た場合

S3、CloudTrail、GuardDutyは、以下の作業フローとしてつながる。

```text
変更前確認
  - S3 Bucket Policy
  - Public Access Block
  - IAM Role
  - VPC Endpoint / Endpoint Policy
  - オンプレミスからの接続経路
  ↓
S3 Bucket Policy変更
  ↓
CloudTrailでPutBucketPolicyを確認
  ↓
オンプレミスまたはAWSシステムからテストファイル送信
  ↓
S3 Object保存確認
  ↓
CloudTrail Data eventsでPutObject確認
  ↓
GuardDuty Finding確認
  ↓
CloudWatch Logs / EventBridge / 通知確認
  ↓
証跡整理・Teams報告
```

## 9. バケットポリシー変更時の影響調査

S3 Bucket Policyを変更する前に、誰がどの経路でS3を利用しているか確認する。

### 9.1 利用主体

- オンプレミス業務サーバー
- AWS上のEC2
- Lambda
- DataSync
- Transfer Family
- S3 File Gateway
- 他AWSアカウント
- 運用担当者
- バックアップシステム
- 監査システム

### 9.2 認証主体

- IAM Role
- IAM User / Access Key
- STS AssumeRole
- AWSサービスプリンシパル
- Cross-account Role

### 9.3 通信経路

- S3 Public Endpoint
- S3 Gateway Endpoint
- S3 Interface Endpoint
- NAT Gateway
- Direct Connect
- Site-to-Site VPN
- Transit Gateway
- AWSサービスからの直接アクセス

### 9.4 Policy条件

- `aws:SecureTransport`
- `aws:sourceVpce`
- `aws:sourceVpc`
- `aws:PrincipalArn`
- `aws:SourceArn`
- `aws:SourceAccount`
- `s3:prefix`
- KMS Key Policy

重要:

```text
特定VPC Endpoint以外をDenyするBucket Policyを追加すると、
AWS管理コンソール、別VPC、他アカウント、AWSサービス連携、
障害対応用経路などが利用できなくなる可能性がある。
```

## 10. 案件初日に確認したい質問

### 10.1 S3利用目的

```text
対象S3バケットには、どのような業務データを保存していますか。
振込データ、帳票、電子保管ファイル、ログ、バックアップなど、
バケットごとの用途一覧はありますか。
```

### 10.2 アクセス元

```text
各S3バケットは、どのシステムから利用されていますか。
オンプレミス、AWS内サービス、他AWSアカウント、運用端末など、
アクセス元一覧はありますか。
```

### 10.3 通信経路

```text
オンプレミスからS3へアクセスする場合、
Direct Connect、Site-to-Site VPN、S3 Interface Endpoint、
DataSync、Transfer Family、中継EC2など、どの経路を利用していますか。
```

### 10.4 認証・認可

```text
S3アクセスに利用するIAM Role、IAM User、AWSサービスプリンシパル、
Cross-account Roleの一覧はありますか。
```

### 10.5 監査・検知

```text
CloudTrailで対象S3バケットのData eventsを記録していますか。
GuardDuty S3 Protection、Security Hub、AWS Configなどは有効ですか。
```

### 10.6 変更後テスト

```text
Bucket Policy変更後は、どのシステムからどの操作をテストすればよいですか。
PutObject、GetObject、ListBucket、DeleteObjectなどのテスト項目は定義されていますか。
```

## 11. 案件で説明できるポイント

- S3はVPC内に配置されるサービスではない
- オンプレミスからS3へPrivateに接続する場合、S3 Interface Endpointなどを利用できる
- S3 Gateway EndpointはVPC内リソース向けであり、オンプレミスから直接利用できない
- Direct Connectは専用接続だが、通信暗号化は別途確認が必要
- CloudTrail Management eventsはBucket Policyなどの設定変更を記録する
- CloudTrail Data eventsはPutObjectやGetObjectなどのObject操作を記録する
- GuardDutyはCloudTrail Management events、VPC Flow Logs、DNS Query Logsなどを分析する
- GuardDuty S3 ProtectionはS3 Data eventsを分析して不審なObject操作を検知する
- GuardDutyの分析と、人が確認するためのCloudTrail / Flow Logs保存設定は別に考える
- Bucket Policy変更では、利用主体、認証主体、通信経路、Policy条件を横断して影響調査する

## 12. 学習時に見る関連資料

| 目的 | リファレンス |
| :--- | :--- |
| S3設定確認 | [S3セキュリティ設定CLIリファレンス](../references/01_s3_security_cli_reference.md) |
| Bucket Policy変更 | [S3 Bucket Policy CLIリファレンス](../references/02_s3_bucket_policy_cli_reference.md) |
| CloudTrail確認 | [CloudTrail CLIリファレンス](../references/03_cloudtrail_cli_reference.md) |
| CloudWatch確認 | [CloudWatch CLIリファレンス](../references/04_cloudwatch_cli_reference.md) |
| GuardDuty確認 | [GuardDuty CLIリファレンス](../references/05_guardduty_cli_reference.md) |
| ネットワーク確認 | [VPC/Network CLIリファレンス](../references/07_vpc_network_cli_reference.md) |
| セキュリティ横断確認 | [AWS Security Settings 横断チェックリスト](../references/90_aws_security_settings_checklist.md) |
| ネットワーク横断確認 | [AWS Network Settings 横断チェックリスト](../references/91_aws_network_settings_checklist.md) |

## 13. 公式ドキュメント

- AWS PrivateLink for Amazon S3
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/privatelink-interface-endpoints.html
- Gateway endpoints for Amazon S3
  - https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html
- AWS DataSync: Transferring to or from on-premises storage
  - https://docs.aws.amazon.com/datasync/latest/userguide/transferring-on-premises-storage.html
- Amazon S3 File Gateway
  - https://docs.aws.amazon.com/filegateway/latest/files3/what-is-file-s3.html
- Logging Amazon S3 API calls using CloudTrail
  - https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudtrail-logging.html
- CloudTrail Data events
  - https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html
- GuardDuty foundational data sources
  - https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_data-sources.html
- GuardDuty S3 Protection
  - https://docs.aws.amazon.com/guardduty/latest/ug/s3-protection.html
- Encryption in AWS Direct Connect
  - https://docs.aws.amazon.com/directconnect/latest/UserGuide/encryption-in-transit.html
