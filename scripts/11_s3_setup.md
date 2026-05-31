# 11_s3_setup.sh 解説

## 概要

`11_s3_setup.sh` は、Webアプリケーション用のS3バケットを作成し、Web EC2からS3へアクセスするためのIAM Role / Instance Profileを設定するスクリプトである。

Rails Active Storageなどで投稿画像や添付ファイルをS3へ保存する想定である。

この手順で作成または利用する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| S3 Bucket | nobu-terraform-iac-lab-upload | Webアプリケーションのアップロードファイル保存先 |
| Bucket Public Access Block | 有効 | バケットやオブジェクトの意図しない公開を防ぐ |
| Object Ownership | BucketOwnerEnforced | ACLを無効化し、バケット所有者に所有権を統一する |
| Bucket Encryption | SSE-S3 / AES256 | S3オブジェクトをサーバー側で暗号化する |
| Bucket Policy | DenyInsecureTransport | HTTPアクセスを拒否し、HTTPS通信を強制する |
| IAM Role | sample-role-web | Web EC2が利用するIAM Role |
| Inline Policy | sample-policy-web-s3-upload | 対象S3バケットだけに限定したS3権限 |
| Managed Policy | CloudWatchAgentServerPolicy | CloudWatch Agentがログを送信するための権限 |
| Instance Profile | sample-role-web | IAM RoleをEC2へ関連付けるための入れ物 |

重要な点は、S3アクセスに `AmazonS3FullAccess` を使わず、対象バケットに限定したインラインポリシーを付与していることである。

これは、案件で出ていた「S3やバケットポリシーの変更」「影響調査」「設定変更」の練習としてかなり実務寄りの内容である。

## 前提条件

このスクリプトを実行する前に、少なくとも以下のリソースが作成されている必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public / Private Subnetを作成する |
| `04_nat_gateway_setup.sh` | Private Subnetからインターネットへ出るNAT Gatewayを作成する |
| `05_route_table_setup.sh` | Private SubnetからNAT Gatewayへの経路を設定する |
| `08_Web_server_setup.sh` | Web EC2 2台を作成する |

現時点の構成では、Private Subnet上のWeb EC2からS3へアクセスする場合、通信経路は以下になる。

```text
Web EC2
  -> Private Route Table
  -> NAT Gateway
  -> Internet Gateway
  -> S3 public endpoint
```

将来的には、S3 Gateway VPC Endpointを追加すると、以下のようにNAT Gatewayを経由せずS3へ到達できる。

```text
Web EC2
  -> Private Route Table
  -> S3 Gateway VPC Endpoint
  -> S3
```

これは「ネットワーク最適化」「コスト最適化」「セキュリティ改善」の題材になる。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、S3バケット名、IAM Role名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. S3バケットを作成または再利用する
6. S3バケットのリージョンが `ap-northeast-1` であることを確認する
7. Public Access Blockを有効化する
8. Object Ownershipを `BucketOwnerEnforced` にしてACLを無効化する
9. デフォルト暗号化としてSSE-S3を設定する
10. HTTPアクセスを拒否するBucket Policyを設定する
11. EC2用IAM Roleを作成または再利用する
12. S3バケット限定のインラインポリシーをIAM Roleへ付与する
13. 以前の `AmazonS3FullAccess` が付いていれば外す
14. CloudWatch Agent用管理ポリシーをIAM Roleへ付与する
15. Instance Profileを作成または再利用する
16. Instance ProfileにIAM Roleを追加する
17. `sample-vpc` のVPC IDを取得する
18. VPC IDで絞り込み、running状態のWeb EC2 2台を取得する
19. Web EC2 2台へInstance Profileを関連付ける
20. S3設定、IAM Role Policy、Instance Profile関連付けを確認する

## Bashの安全設定

```bash
#!/bin/bash
set -euo pipefail
```

`set -euo pipefail` は、シェルスクリプトを安全に実行するための設定である。

| 設定 | 意味 |
| :--- | :--- |
| `-e` | コマンドが失敗した時点でスクリプトを終了する |
| `-u` | 未定義の変数を使った場合にエラーにする |
| `-o pipefail` | パイプ処理の途中で失敗した場合もエラーとして扱う |

S3とIAMは権限設定の影響範囲が広い。

途中の失敗を見落とすと、想定外公開、過剰権限、EC2からS3にアクセスできない状態につながるため、失敗時点で止める。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

BUCKET_NAME="nobu-terraform-iac-lab-upload"
VPC_NAME="sample-vpc"

ROLE_NAME="sample-role-web"
ROLE_DESCRIPTION="upload images"
INSTANCE_PROFILE_NAME="$ROLE_NAME"

S3_INLINE_POLICY_NAME="sample-policy-web-s3-upload"
S3_FULL_ACCESS_POLICY_ARN="arn:aws:iam::aws:policy/AmazonS3FullAccess"
CLOUDWATCH_AGENT_POLICY_ARN="arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"
```

バケット名はグローバルで一意である必要がある。

`nobu-terraform-iac-lab-upload` はRailsアプリケーションのアップロード用バケットとして利用する。

## S3バケット作成

```bash
aws s3api create-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" \
  --create-bucket-configuration LocationConstraint="$REGION"
```

`ap-northeast-1` のような `us-east-1` 以外のリージョンでは、`LocationConstraint` の指定が必要である。

既存バケットを再利用する場合も、バケットのリージョンが期待値と一致するか確認する。

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME"
```

同じバケット名が別リージョンに存在する場合は、想定外の構成になるため停止する。

## Public Access Block

```bash
aws s3api put-public-access-block \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

設定内容は以下である。

| 項目 | 値 | 意味 |
| :--- | :--- | :--- |
| BlockPublicAcls | true | 新規のPublic ACL設定をブロックする |
| IgnorePublicAcls | true | 既存のPublic ACLを無視する |
| BlockPublicPolicy | true | Public許可につながるBucket Policyをブロックする |
| RestrictPublicBuckets | true | Public Policyがある場合のアクセスを制限する |

このバケットはアプリケーション経由で利用するため、直接インターネット公開しない。

画像を公開したい場合でも、まずはCloudFrontや署名付きURLなどを検討する。

## ACL無効化

```bash
aws s3api put-bucket-ownership-controls \
  --ownership-controls '{
    "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
    ]
  }'
```

`BucketOwnerEnforced` にすると、ACLが無効化され、オブジェクト所有者はバケット所有者に統一される。

これは現在のS3運用では基本形である。

ACLとBucket Policyが混在すると、公開範囲の調査が複雑になる。

ACLを無効化することで、アクセス制御の中心をIAM PolicyとBucket Policyに寄せられる。

## デフォルト暗号化

```bash
aws s3api put-bucket-encryption \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

この設定により、S3オブジェクトはSSE-S3で暗号化される。

| 項目 | 値 |
| :--- | :--- |
| Server Side Encryption | SSE-S3 |
| Algorithm | AES256 |
| KMS Key | 使用しない |

現在のS3では新規オブジェクトは自動的に暗号化されるが、明示設定しておくと監査や影響調査で説明しやすい。

実運用では、要件に応じてSSE-KMSや顧客管理KMSキーを検討する。

## HTTPS通信の強制

HTTPでのS3アクセスを拒否するBucket Policyを設定する。

```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::nobu-terraform-iac-lab-upload",
    "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

このPolicyは「許可」ではなく「拒否」である。

そのため、`Principal: "*"` を使っていても、全員にアクセスを許可しているわけではない。

意味は「HTTPで来たアクセスは誰であっても拒否する」である。

Public Access Blockは公開許可を防ぐ設定であり、HTTPS強制のDeny Policyとは役割が異なる。

## IAM Role

Web EC2がS3へアクセスするため、EC2用IAM Role `sample-role-web` を作成する。

信頼ポリシーは以下である。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

`Principal` に `ec2.amazonaws.com` を指定することで、EC2がこのRoleを引き受けられる。

既存Roleを再利用する場合も、信頼ポリシーとタグを設計値へそろえる。

## S3バケット限定インラインポリシー

Web EC2用Roleには、対象バケット限定のインラインポリシー `sample-policy-web-s3-upload` を付与する。

バケットに対する権限:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetBucketLocation",
    "s3:ListBucket",
    "s3:ListBucketMultipartUploads"
  ],
  "Resource": "arn:aws:s3:::nobu-terraform-iac-lab-upload"
}
```

オブジェクトに対する権限:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:AbortMultipartUpload",
    "s3:ListMultipartUploadParts"
  ],
  "Resource": "arn:aws:s3:::nobu-terraform-iac-lab-upload/*"
}
```

Rails Active Storageでは、アップロード、取得、削除、マルチパートアップロードでこれらの権限を利用する。

以前の学習構成では `AmazonS3FullAccess` を使っていたが、このスクリプトでは付与しない。

過去の実行で付いていた場合は、以下で外す。

```bash
aws iam detach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$S3_FULL_ACCESS_POLICY_ARN"
```

案件対策としては、この差が重要である。

| 比較 | 内容 |
| :--- | :--- |
| AmazonS3FullAccess | 全バケットへの広い権限になりやすい |
| バケット限定Policy | 対象バケットだけに操作範囲を限定できる |

S3バケットポリシー変更やIAM権限変更では、「誰が」「どのバケットに」「どの操作を」「どの条件で」できるかを説明できる必要がある。

## CloudWatch Agent用Policy

CloudWatch AgentがnginxやPumaログをCloudWatch Logsへ送信するため、以下のAWS管理ポリシーを付与する。

```text
arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

この権限がない場合、CloudWatch AgentをインストールしてもLog GroupやLog Streamの作成、PutLogEventsに失敗する。

S3権限はバケット限定にしているが、CloudWatch Agent権限はAWS管理ポリシーを利用している。

後続のCloudWatch編で、必要に応じてさらに権限を絞る余地がある。

## Instance Profile

EC2にIAM Roleを付けるには、IAM Roleを直接付与するのではなく、Instance Profileを使う。

```text
IAM Role
  -> Instance Profile
  -> EC2 Instance
```

このスクリプトでは、Role名と同じ `sample-role-web` というInstance Profileを作成する。

Instance Profileに既に別Roleが入っている場合は停止する。

これは、既存Roleを上書きしてEC2の権限を壊さないためである。

## Web EC2への関連付け

Web EC2を取得するときは、VPC IDとNameタグで絞り込む。

```bash
aws ec2 describe-instances \
  --filters \
    Name=vpc-id,Values="$VPC_ID" \
    Name=tag:Name,Values="$instance_name" \
    Name=instance-state-name,Values=running
```

Nameタグだけで検索すると、別VPCに同名EC2が存在した場合に誤ったEC2へRoleを付ける可能性がある。

検索結果が0件または2件以上の場合は停止する。

| 件数 | 処理 |
| :--- | :--- |
| 0件 | 前提リソースがないため停止 |
| 1件 | そのEC2を対象にする |
| 2件以上 | 誤作業防止のため停止 |

対象EC2は以下である。

| EC2 | 用途 |
| :--- | :--- |
| sample-ec2-web01 | Railsアプリケーション実行用Webサーバー |
| sample-ec2-web02 | Railsアプリケーション実行用Webサーバー |

既に同じInstance Profileが関連付いている場合は何もしない。

別のInstance Profileが関連付いている場合は、`replace-iam-instance-profile-association` で置き換える。

## 実行結果

今回の実行結果は以下である。

| 項目 | 値 |
| :--- | :--- |
| AWS Account | 445405559057 |
| VPC | vpc-0127f31bb241c01b0 |
| S3 Bucket | nobu-terraform-iac-lab-upload |
| Bucket ARN | arn:aws:s3:::nobu-terraform-iac-lab-upload |
| IAM Role | sample-role-web |
| IAM Role ARN | arn:aws:iam::445405559057:role/sample-role-web |
| Instance Profile | sample-role-web |
| Instance Profile ARN | arn:aws:iam::445405559057:instance-profile/sample-role-web |
| Web01 | i-027d8cf0673190a7a |
| Web02 | i-08f91d1b14fa093e1 |
| S3 Inline Policy | sample-policy-web-s3-upload |
| Attached Managed Policy | CloudWatchAgentServerPolicy |

S3バケット設定:

| 項目 | 結果 |
| :--- | :--- |
| BlockPublicAcls | True |
| IgnorePublicAcls | True |
| BlockPublicPolicy | True |
| RestrictPublicBuckets | True |
| ObjectOwnership | BucketOwnerEnforced |
| Default Encryption | SSE-S3 / AES256 |
| Bucket Policy | DenyInsecureTransport |

IAM Role Policy:

| 種別 | 名前 |
| :--- | :--- |
| Inline Policy | sample-policy-web-s3-upload |
| Managed Policy | CloudWatchAgentServerPolicy |

`AmazonS3FullAccess` は付与されていない。

## 確認コマンド

S3バケットのPublic Access Block確認:

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table
```

Object Ownership確認:

```bash
aws s3api get-bucket-ownership-controls \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table
```

暗号化確認:

```bash
aws s3api get-bucket-encryption \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table
```

Bucket Policy確認:

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --query Policy \
  --output text
```

IAM Roleのインラインポリシー確認:

```bash
aws iam list-role-policies \
  --profile learning \
  --role-name sample-role-web \
  --output table
```

IAM Roleの管理ポリシー確認:

```bash
aws iam list-attached-role-policies \
  --profile learning \
  --role-name sample-role-web \
  --output table
```

EC2へのInstance Profile関連付け確認:

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-id,Values=i-027d8cf0673190a7a,i-08f91d1b14fa093e1 \
  --query 'IamInstanceProfileAssociations[*].{InstanceId:InstanceId,State:State,ProfileArn:IamInstanceProfile.Arn}' \
  --output table
```

## Web EC2からの動作確認

EC2に付与したIAM Roleを使う場合、EC2内では `--profile learning` を使わない。

Mac側のAWS CLIプロファイルはEC2内には存在しないためである。

Web EC2へSSHする。

```bash
ssh awsref-web01
```

EC2上で認証情報を確認する。

```bash
aws sts get-caller-identity
```

期待するArnの例:

```text
arn:aws:sts::445405559057:assumed-role/sample-role-web/i-xxxxxxxxxxxxxxxxx
```

S3一覧確認:

```bash
aws s3 ls s3://nobu-terraform-iac-lab-upload/
```

アップロード確認:

```bash
echo "s3 test from web01" > /tmp/s3-test.txt
aws s3 cp /tmp/s3-test.txt s3://nobu-terraform-iac-lab-upload/test/s3-test-web01.txt
```

ダウンロード確認:

```bash
aws s3 cp s3://nobu-terraform-iac-lab-upload/test/s3-test-web01.txt /tmp/s3-test-download.txt
cat /tmp/s3-test-download.txt
```

削除確認:

```bash
aws s3 rm s3://nobu-terraform-iac-lab-upload/test/s3-test-web01.txt
```

これが成功すれば、EC2のInstance Profile経由でS3へアクセスできている。

## 再実行耐性

このスクリプトは、同じリソースが既に存在する場合に再利用する。

| 対象 | 再実行時の動作 |
| :--- | :--- |
| S3 Bucket | 既存バケットを再利用し、リージョンを確認する |
| Public Access Block | 毎回同じ設定を適用する |
| Object Ownership | 毎回 `BucketOwnerEnforced` を適用する |
| Bucket Encryption | 毎回SSE-S3設定を適用する |
| Bucket Policy | 毎回 `DenyInsecureTransport` を適用する |
| IAM Role | 既存Roleを再利用し、信頼ポリシーとタグをそろえる |
| S3 Inline Policy | 毎回上書き適用する |
| AmazonS3FullAccess | 付いていた場合は外す |
| Instance Profile | 既存を再利用する |
| EC2関連付け | 同じProfileならスキップ、別Profileなら置き換える |

ただし、以下の場合は自動修正せず停止する。

| 状況 | 停止理由 |
| :--- | :--- |
| バケットが別リージョンにある | 想定外のS3配置になる |
| 同名VPCが複数ある | 誤ったVPCを選ぶ危険がある |
| 同名Web EC2が複数running | 誤ったEC2にRoleを付ける危険がある |
| Instance Profileに別Roleが入っている | 既存権限を壊す危険がある |

## 案件対策としての見どころ

この手順は、面談で出ていた「S3やバケットポリシーの変更が20個程度ある」という話に直結する。

説明しやすいポイントは以下である。

| 観点 | 説明ポイント |
| :--- | :--- |
| 公開制御 | Public Access Blockを4項目すべて有効化 |
| ACL廃止 | BucketOwnerEnforcedでACLを無効化 |
| 暗号化 | SSE-S3を明示設定 |
| 通信保護 | Bucket PolicyでHTTPアクセスをDeny |
| 最小権限 | AmazonS3FullAccessではなく対象バケット限定Policy |
| EC2権限 | Access KeyではなくInstance Profileを利用 |
| 影響調査 | Bucket PolicyやIAM Policy変更時に、許可範囲と拒否条件を確認 |
| 運用 | 設定確認コマンドを手順書として残す |

S3の設定変更では、以下を確認する習慣が重要である。

- Bucket PolicyがAllowなのかDenyなのか
- Principalが誰か
- Resourceがバケット本体かオブジェクトか
- Conditionがあるか
- IAM PolicyとBucket Policyの両方を見ているか
- Public Access Blockと矛盾していないか
- アプリケーションの必要操作を過不足なく許可しているか

## ネットワーク観点

現時点では、Web EC2はPrivate Subnetにあり、S3へはNAT Gateway経由でアクセスする。

これは動作確認としては問題ない。

ただし、運用・コスト・セキュリティ改善の観点では、S3 Gateway VPC Endpointを追加する余地がある。

| 構成 | 特徴 |
| :--- | :--- |
| NAT Gateway経由 | 既存の外向き通信経路を利用できるが、NAT Gateway料金とデータ処理料金がかかる |
| S3 Gateway Endpoint | Private SubnetからS3へAWS内部経路で到達でき、NAT Gateway依存を減らせる |

将来S3 Gateway Endpointを作成した場合、Bucket Policyに `aws:sourceVpce` 条件を追加して、特定VPC Endpointからのアクセスだけを許可する設計も検討できる。

ただし、`aws:sourceVpce` を追加する場合、NAT Gateway経由アクセスや管理端末からのアクセスを意図せず拒否する可能性があるため、影響調査が必要である。

## 実運用との差分

この学習環境では、RailsアプリケーションのS3アップロード検証とAWS設定理解を優先している。

実運用では、以下の追加検討が必要になる。

| 項目 | 学習環境 | 実運用での検討 |
| :--- | :--- | :--- |
| 暗号化 | SSE-S3 | SSE-KMS、顧客管理KMSキー |
| IAM Policy | アプリ用操作に限定 | さらにprefix単位、環境単位で分離 |
| Bucket Policy | HTTPS強制 | VPC Endpoint制限、Principal制限 |
| バージョニング | 未設定 | 誤削除・復旧要件に応じて有効化 |
| ライフサイクル | 未設定 | 保存期間、コスト最適化 |
| ログ | 未設定 | S3 Server Access Logs、CloudTrail Data Events |
| マルウェア対策 | 未設定 | GuardDuty Malware Protection for S3等 |
| データ分類 | 未設定 | Macie等による機密情報検出 |

銀行系案件では、S3の公開設定、暗号化、アクセス元、ログ、データ保護が重要になる。

## 削除時の注意

S3バケットは、中にオブジェクトが残っていると削除できない。

削除時は、先にオブジェクトを削除してからバケットを削除する。

```bash
aws s3 rm s3://nobu-terraform-iac-lab-upload --recursive --profile learning

aws s3api delete-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

IAM Role削除時は、以下の順番に注意する。

1. EC2からInstance Profileの関連付けを外す
2. Instance ProfileからRoleを外す
3. Instance Profileを削除する
4. Roleからインラインポリシーを削除する
5. Roleから管理ポリシーをdetachする
6. Roleを削除する

IAMとInstance Profileは反映に時間がかかることがある。

削除直後に再作成や再関連付けを行う場合は、少し待ってから確認する。

