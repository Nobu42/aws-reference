# Day 15 Learning: EC2・RDS Security確認ドリル

## 学習開始前に実行するスクリプト

Day 15はEC2、EBS、IAM Role、RDS、Security Groupを実物確認するハンズオンである。`sample-vpc`が存在しない場合は最初に日次ラボ環境を構築する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

アプリケーション状態とCloudWatch Agentによるログを確認する場合は、Ansibleも実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

CloudTrail一時Trailは作成しない。S3 Data Eventは有効化しない。

起動後、EC2とRDSが見えることを確認する。

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,PrivateIp:PrivateIpAddress,Profile:IamInstanceProfile.Arn}' \
  --output table \
  --no-cli-pager

aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DBInstances[].{DBInstanceIdentifier:DBInstanceIdentifier,Engine:Engine,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId}' \
  --output table \
  --no-cli-pager
```

学習終了後、後続の横断確認を続けない場合は`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

## 1. 今日の目的

EC2とRDSの主要なセキュリティ設定を横断的に確認し、現在状態、良好な設定、改善候補、影響範囲を説明できる状態を目指す。

Day 15では、単一設定だけで安全性を判断しない。

```text
EC2:
Public IP
  + Subnet / Route Table
  + Security Group / Network ACL
  + IAM Role
  + IMDSv2
  + EBS暗号化

RDS:
PubliclyAccessible
  + DB Subnet Group
  + Security Group / Network ACL / Route
  + Storage暗号化
  + Parameter Group / Logs
  + Backup / Snapshot / Deletion Protection
```

本ドリルでは設定変更を行わない。Webコンソールと読み取り専用AWS CLIで確認し、結果を証跡化して報告する。

関連資料:

- [Day 10 VPC・Subnet・Route Table確認](./10_Day_Learning.md)
- [Day 11 Security Group・Network ACL確認](./11_Day_Learning.md)
- [Day 14 DNS・VPC Endpoint・Flow Logs確認](./14_Day_Learning.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [RDS Security CLIリファレンス](../docs/references/09_rds_security_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [Bastion EC2構築スクリプト](../scripts/07_bastion_server_setup.sh)
- [Web EC2構築スクリプト](../scripts/08_Web_server_setup.sh)
- [RDS構築スクリプト](../scripts/10_Database_setup.sh)
- [S3・Web IAM Role構築スクリプト](../scripts/11_s3_setup.sh)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)

---

## 2. 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象VPC内のEC2およびRDSについて、
セキュリティ設定と運用保護設定を確認してください。

EC2はPublic IP、Security Group、IAM Role、IMDSv2、EBS暗号化を確認してください。

RDSは外部公開されていないことを複数観点で確認し、
暗号化、ログ、バックアップ、削除保護の状態を整理してください。

設定変更は実施しないでください。
```

## 今日の確認順序

1. AWSアカウント、リージョン、対象VPCを確認する
2. EC2一覧と役割を確認する
3. EC2のPublic IP、Subnet、Route Tableを確認する
4. EC2のSecurity Groupを確認する
5. EC2のIAM Instance ProfileとRole Policyを確認する
6. EC2のIMDSv2設定を確認する
7. EC2のEBS暗号化を確認する
8. RDS基本設定とPubliclyAccessibleを確認する
9. RDSのDB Subnet GroupとRouteを確認する
10. RDSのSecurity Groupを確認する
11. RDSのStorage暗号化とKMS Keyを確認する
12. RDSのParameter GroupとOption Groupを確認する
13. RDSログとCloudWatch Logs連携を確認する
14. RDSのBackup、Snapshot、Deletion Protectionを確認する
15. CloudTrailでEC2・RDS変更履歴を確認する
16. 結果、改善候補、要確認事項、証跡を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象VPC | `sample-vpc` |
| EC2 | `sample-ec2-bastion`、`sample-ec2-web01`、`sample-ec2-web02` |
| RDS | `sample-db` |
| DB Engine / Port | MySQL / TCP 3306 |
| 設定変更 | なし |

## ラボ環境の期待値

### EC2

| 対象 | Public IP | Subnet | IMDSv2 | IAM Role |
|---|---|---|---|---|
| `sample-ec2-bastion` | あり | Public Subnet | `HttpTokens=required` | 原則なし |
| `sample-ec2-web01` | なし | Private Subnet 01 | `HttpTokens=required` | `sample-role-web` |
| `sample-ec2-web02` | なし | Private Subnet 02 | `HttpTokens=required` | `sample-role-web` |

### RDS

| 項目 | ラボ期待値 | 評価 |
|---|---|---|
| PubliclyAccessible | `false` | 良好 |
| DB Subnet Group | Private Subnet 2つ | 良好 |
| Security Group | Web SGからTCP 3306のみ | 良好 |
| StorageEncrypted | `true` | 良好 |
| BackupRetentionPeriod | `0` | ラボでは削除・費用優先。本番では要改善 |
| DeletionProtection | `false` | ラボでは削除優先。本番では要改善 |
| MultiAZ | `false` | ラボでは費用優先。本番では可用性要件確認 |
| CloudWatch Logs Export | 未設定の可能性あり | 監査・運用要件確認 |

重要:

```text
学習環境の期待値と、本番・金融環境の期待値は同じではない。

ラボでは日次削除と費用を優先するため、
Backup、Deletion Protection、Multi-AZを無効にしている。

本番環境では、RPO、RTO、可用性、監査、削除防止の要件を確認する。
```

## 今日実行しない操作

- EC2の起動、停止、再起動、終了
- Public IP、Subnet、Security Groupの変更
- IAM Role、Instance Profile、Policyの追加・変更・削除
- IMDS設定の変更
- EBS暗号化デフォルト、Volume、Snapshotの変更
- RDSの起動、停止、再起動、削除
- RDS Public設定、SG、Subnet Group、Parameter Groupの変更
- RDS Backup、Logs Export、Deletion Protectionの変更
- Snapshot作成、共有、削除

---

## 3. EC2・RDSの安全性を複数観点で確認する

## EC2の公開判定

Public IPの有無だけでは、EC2の公開範囲を完全には判断できない。

```text
Public IPあり
  + Public SubnetのIGW Route
  + SG / NACL許可
  + OS / Application Listener
  = Internetから接続可能になる候補
```

Public IPがあってもSGで拒否されていれば接続できない。一方、Public IPがなくてもALB、NLB、VPN、Direct Connect、踏み台、SSMなどから接続される場合がある。

## RDSの非公開判定

`PubliclyAccessible=false`だけでは、RDSの通信制御全体を判断できない。

確認する組み合わせ:

```text
PubliclyAccessible=false
  + Private Subnetで構成されたDB Subnet Group
  + Public向けRouteの確認
  + DB SGのSourceが必要なApplication SGだけ
  + NACL
  + DNS / Endpoint
```

外部公開されていないことを説明する場合は、少なくともPublic設定、Subnet、Route、SGをセットで示す。

---

## 4. 作業開始条件と報告条件

## 作業開始条件

- 読み取り専用の確認作業である
- 対象AWSアカウント、リージョン、VPCが明確である
- EC2とRDSの用途を確認できる
- 設計書または期待構成を確認できる
- AWS WebコンソールとAWS CLIで確認できる
- 証跡保存先が準備できている

## 作業中止・確認条件

- 想定外のAWSアカウントまたはリージョンである
- 対象VPC、EC2、RDSを一意に特定できない
- RDSが`available`以外で、既存作業との競合が疑われる
- 読み取り権限不足で主要設定を確認できない
- 設定変更を求められたが承認、試験、切り戻しがない

## 即時共有する状態

- Private Web EC2にPublic IPがある
- Bastion以外のEC2がInternetから直接SSH可能である
- EC2のIMDSv2が必須化されていない
- 未暗号化EBS Volumeがある
- EC2 IAM Roleが管理者相当または用途不明である
- RDSの`PubliclyAccessible=true`
- DB SGが`0.0.0.0/0`または広いCIDRからDB Portを許可する
- RDS Storageが未暗号化である
- RDS SnapshotがPublic共有されている

---

## 5. 作業用変数と証跡保存先

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

VPC_NAME="sample-vpc"
BASTION_NAME="sample-ec2-bastion"
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"
WEB_ROLE_NAME="sample-role-web"
DB_INSTANCE_ID="sample-db"
WORK_NAME="ec2_rds_security_check"
```

### 証跡保存用ディレクトリ

```bash
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/ec2" \
  "$EVIDENCE_DIR/iam" \
  "$EVIDENCE_DIR/ebs" \
  "$EVIDENCE_DIR/rds" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 必須変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nBASTION_NAME=%s\nWEB01_NAME=%s\nWEB02_NAME=%s\nWEB_ROLE_NAME=%s\nDB_INSTANCE_ID=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" \
  "$BASTION_NAME" "$WEB01_NAME" "$WEB02_NAME" "$WEB_ROLE_NAME" \
  "$DB_INSTANCE_ID" "$EVIDENCE_DIR"
```

---

## 6. AWSアカウントと対象VPCの確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. VPCコンソールで`sample-vpc`を確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_sample-vpc確認.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --no-cli-pager)

echo "VPC_ID=$VPC_ID"
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"

aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/02_vpc.json"
```

---

## 7. EC2一覧・配置・Public IPの確認

### Webコンソール

1. EC2コンソールを開く
2. インスタンス一覧を開く
3. `sample-ec2-*`で絞り込む
4. Name、Instance ID、State、Private IP、Public IPを確認する
5. BastionとWeb EC2のSubnetを確認する

取得するスクリーンショット:

```text
03_EC2一覧_Public_IP確認.png
04_EC2_Subnet配置確認.png
```

### AWS CLI

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,AZ:Placement.AvailabilityZone,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SGs:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn}' \
  --output table \
  --no-cli-pager
```

Public IPを持つEC2だけを抽出する。

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[?PublicIpAddress!=`null`].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,SGs:SecurityGroups[*].GroupId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/ec2/01_describe_instances.json"
```

### 結果の読み方

- BastionだけがPublic IPを持つ
- Web01、Web02のPublic IPが空または`None`
- BastionはPublic Subnet、Web EC2はPrivate Subnetにある
- Web EC2はALB経由でApplication通信を受ける
- Web EC2へのSSHはBastion経由に限定される

Public IPを持つEC2がBastion以外にもある場合、用途、Route、SG、接続元を確認する。

---

## 8. EC2 Security Groupの確認

### Webコンソール

1. 対象EC2を開く
2. 「セキュリティ」タブを開く
3. 関連Security Groupを確認する
4. Inbound RuleとOutbound Ruleを確認する
5. Source、Protocol、Port、Descriptionを確認する
6. 「インバウンドルールを編集」は押さない

取得するスクリーンショット:

```text
05_Bastion_SG確認.png
06_Web_EC2_SG確認.png
```

### AWS CLI

EC2とSGの関連付け:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,SecurityGroups:SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId}}' \
  --output table \
  --no-cli-pager
```

VPC内のSG Rule:

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Egress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

Public Inbound Ruleを抽出する。

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`].{GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- BastionのSSHは管理元IPなど必要範囲だけに限定される
- Web EC2のSSHはBastion SGからのみ許可される
- Web Application PortはALB SGからのみ許可される
- Web SGに`0.0.0.0/0`からのSSHやApplication Port許可がない
- Rule Descriptionから用途を説明できる

---

## 9. EC2 IAM Instance ProfileとRoleの確認

Web EC2は、S3へのApplicationデータ保存とCloudWatch Agentのために`sample-role-web`を使用する。

Bastionへ不要なRoleを付与しないことも確認する。

### Webコンソール

1. EC2コンソールで対象EC2を開く
2. IAM Roleを確認する
3. Web01、Web02が`sample-role-web`を使用することを確認する
4. BastionのIAM Role有無を確認する
5. IAMコンソールでRoleの信頼ポリシーと権限を確認する

取得するスクリーンショット:

```text
07_EC2_IAM_Role関連付け確認.png
08_Web_Role_Policy確認.png
```

### AWS CLI

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=state,Values=associated \
  --query 'IamInstanceProfileAssociations[*].{InstanceId:InstanceId,State:State,ProfileArn:IamInstanceProfile.Arn,AssociationId:AssociationId}' \
  --output table \
  --no-cli-pager
```

Instance Profile:

```bash
aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$WEB_ROLE_NAME" \
  --query 'InstanceProfile.{Name:InstanceProfileName,Arn:Arn,Roles:Roles[*].{RoleName:RoleName,Arn:Arn}}' \
  --output table \
  --no-cli-pager
```

管理ポリシー:

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$WEB_ROLE_NAME" \
  --output table \
  --no-cli-pager
```

インラインポリシー:

```bash
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$WEB_ROLE_NAME" \
  --output table \
  --no-cli-pager
```

信頼ポリシー:

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$WEB_ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,AssumeRolePolicyDocument:AssumeRolePolicyDocument,MaxSessionDuration:MaxSessionDuration}' \
  --output json \
  --no-cli-pager
```

### 結果の読み方

- Web01、Web02に同じ想定Instance Profileが関連付く
- Bastionに不要なRoleがない
- Roleの信頼先がEC2 Service Principalである
- S3権限が対象バケットへ限定される
- `AdministratorAccess`や`AmazonS3FullAccess`など過剰権限がない
- CloudWatch Agent用権限の用途を説明できる

注意:

```text
Roleが付いていることだけで良好とは判断しない。

誰がRoleを引き受けられるかを信頼ポリシーで確認し、
Roleを使って何ができるかを権限ポリシーで確認する。
```

---

## 10. EC2 IMDSv2の確認

IMDSはInstance Metadata Serviceである。IAM Roleの一時認証情報などを取得できるため、IMDSv2を必須化して保護する。

### Webコンソール

1. EC2コンソールで対象EC2を開く
2. メタデータオプションを確認する
3. IMDSv2が必須であることを確認する
4. 「インスタンスメタデータオプションを変更」は押さない

取得するスクリーンショット:

```text
09_EC2_IMDSv2確認.png
```

### AWS CLI

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,HttpEndpoint:MetadataOptions.HttpEndpoint,HttpTokens:MetadataOptions.HttpTokens,HopLimit:MetadataOptions.HttpPutResponseHopLimit,MetadataTags:MetadataOptions.InstanceMetadataTags,State:MetadataOptions.State}' \
  --output table \
  --no-cli-pager
```

IMDSv2が必須ではないEC2を抽出する。

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=metadata-options.http-tokens,Values=optional \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,HttpTokens:MetadataOptions.HttpTokens,HttpEndpoint:MetadataOptions.HttpEndpoint,HopLimit:MetadataOptions.HttpPutResponseHopLimit}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

| 項目 | 期待値 | 意味 |
|---|---|---|
| HttpEndpoint | `enabled` | IMDS Endpointを利用可能 |
| HttpTokens | `required` | IMDSv2 Token必須 |
| HopLimit | 基本`1` | コンテナ等の要件がある場合は確認 |
| MetadataTags | 基本`disabled` | Instance TagのMetadata公開を抑制 |
| State | `applied` | 設定適用済み |

`HttpTokens=optional`の場合、IMDSv1も利用可能なため改善候補として共有する。

---

## 11. EC2 EBS暗号化の確認

### Webコンソール

1. EC2コンソールで対象EC2を開く
2. 「ストレージ」タブを開く
3. Volume IDを開く
4. 暗号化、KMS Key、Size、Typeを確認する
5. Delete on terminationを確認する

取得するスクリーンショット:

```text
10_EC2_EBS暗号化確認.png
11_EBSデフォルト暗号化確認.png
```

### リージョンのEBSデフォルト暗号化

```bash
aws ec2 get-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 get-ebs-default-kms-key-id \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table \
  --no-cli-pager
```

### VPC内EC2に関連するVolume

```bash
INSTANCE_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --no-cli-pager)

VOLUME_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids $INSTANCE_IDS \
  --query 'Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' \
  --output text \
  --no-cli-pager)

aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --volume-ids $VOLUME_IDS \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size,Type:VolumeType,Encrypted:Encrypted,KmsKeyId:KmsKeyId,AZ:AvailabilityZone,Attachments:Attachments[*].{InstanceId:InstanceId,Device:Device,DeleteOnTermination:DeleteOnTermination}}' \
  --output table \
  --no-cli-pager
```

未暗号化Volumeを抽出する。

```bash
aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=encrypted,Values=false \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size,Type:VolumeType,AZ:AvailabilityZone,Attachments:Attachments[*].{InstanceId:InstanceId,Device:Device}}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 対象Volumeの`Encrypted=true`
- KMS Keyが想定どおりである
- Root VolumeのDeleteOnTerminationが運用方針どおりである
- 未暗号化Volumeがない
- デフォルト暗号化は新規Volumeへの方針であり、既存Volumeの暗号化状態とは別に確認する

既存の未暗号化Volumeは、単純な設定変更でその場暗号化できるものとして扱わない。Snapshotコピー、暗号化Volume作成、停止、付け替え、試験、切り戻しが必要になる可能性がある。

---

## 12. EC2証跡保存

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/ec2/02_instances_full.json"

aws ec2 describe-iam-instance-profile-associations \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/iam/01_instance_profile_associations.json"

aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$WEB_ROLE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/iam/02_web_role.json"

aws ec2 get-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/ebs/01_ebs_encryption_by_default.json"
```

---

## 13. RDS基本設定とPubliclyAccessibleの確認

### Webコンソール

1. RDSコンソールを開く
2. `sample-db`を開く
3. Connectivity、Security、Configurationを確認する
4. Status、Endpoint、Port、Public Access、VPC、SGを確認する
5. 「変更」は押さない

取得するスクリーンショット:

```text
12_RDS基本設定_Public_Access確認.png
```

### AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,MultiAZ:MultiAZ,DBSubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcId:DBSubnetGroup.VpcId,VpcSecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table \
  --no-cli-pager
```

Public設定のRDSを抽出する。

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[?PubliclyAccessible==`true`].{ID:DBInstanceIdentifier,Engine:Engine,Endpoint:Endpoint.Address,Port:Endpoint.Port,VpcId:DBSubnetGroup.VpcId,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- `DBInstanceStatus=available`
- `PubliclyAccessible=false`
- VPC IDが`sample-vpc`と一致する
- PortがTCP 3306である
- Endpointは`db.home`のCNAME参照先と一致する

`PubliclyAccessible=false`は重要だが、次のSubnet Group、Route、SG確認を継続する。

---

## 14. RDS DB Subnet GroupとRouteの確認

### Webコンソール

1. RDSのConnectivityを開く
2. DB Subnet Group名を確認する
3. SubnetとAvailability Zoneを確認する
4. VPCコンソールで各SubnetのRoute Tableを確認する

取得するスクリーンショット:

```text
13_RDS_DB_Subnet_Group確認.png
14_RDS_Subnet_Route確認.png
```

### AWS CLI

```bash
DB_SUBNET_GROUP_NAME=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' \
  --output text \
  --no-cli-pager)

echo "DB_SUBNET_GROUP_NAME=$DB_SUBNET_GROUP_NAME"
```

```bash
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[0].{Name:DBSubnetGroupName,Status:SubnetGroupStatus,VpcId:VpcId,Subnets:Subnets[*].{SubnetId:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name,Status:SubnetStatus}}' \
  --output json \
  --no-cli-pager
```

対象SubnetのRoute Table:

```bash
DB_SUBNET_IDS=$(aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[0].Subnets[*].SubnetIdentifier' \
  --output text \
  --no-cli-pager)

DB_SUBNET_FILTER_VALUES=$(printf '%s' "$DB_SUBNET_IDS" | tr '\t ' ',')

aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$DB_SUBNET_FILTER_VALUES" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Subnets:Associations[*].SubnetId,Routes:Routes[*].{Destination:DestinationCidrBlock,Gateway:GatewayId,NAT:NatGatewayId,Endpoint:VpcEndpointId,State:State}}' \
  --output json \
  --no-cli-pager
```

### 結果の読み方

- DB Subnet Groupが対象VPCにある
- 2つ以上のAZのPrivate Subnetで構成される
- SubnetにInternet Gatewayへの直接Default Routeがない
- Public Subnetが混在していない
- Routeに`blackhole`がない

注意:

```text
DB Subnet GroupへPrivate Subnetを指定していても、
SubnetのRoute TableがPublic向けに変更されれば設計が崩れる。

Subnet名だけでPrivateと判断せず、Route Tableを確認する。
```

---

## 15. RDS Security Groupの確認

### Webコンソール

1. RDSのConnectivityでVPC Security Groupを開く
2. Inbound Ruleを確認する
3. TCP 3306のSourceがWeb SGであることを確認する
4. `0.0.0.0/0`や広いCIDRがないことを確認する
5. 「インバウンドルールを編集」は押さない

取得するスクリーンショット:

```text
15_RDS_Security_Group確認.png
```

### AWS CLI

```bash
DB_SG_ID=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text \
  --no-cli-pager)

echo "DB_SG_ID=$DB_SG_ID"
```

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,Egress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- Inbound TCP 3306のSourceがWeb SGである
- DB PortをInternetへ公開していない
- Bastionや管理端末からの直接DB接続が必要な場合、承認済み要件がある
- DB SGがRDS以外のリソースで共有されていない

RDS外部非公開の説明例:

```text
PubliclyAccessibleはfalseである。
DB Subnet Groupは2つのPrivate Subnetで構成されている。
DB SGのInbound TCP 3306はWeb SGからのみ許可されている。
Public CIDRからDB Portへの許可は存在しない。
```

---

## 16. RDS Storage暗号化とKMS Keyの確認

### Webコンソール

1. RDSのConfigurationを確認する
2. Storage encryptionが有効であることを確認する
3. KMS Keyを確認する
4. Snapshotの暗号化状態を確認する

取得するスクリーンショット:

```text
16_RDS_Storage暗号化確認.png
```

### AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,StorageType:StorageType,AllocatedStorage:AllocatedStorage}' \
  --output table \
  --no-cli-pager
```

未暗号化RDSを抽出する。

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[?StorageEncrypted==`false`].{ID:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible}' \
  --output table \
  --no-cli-pager
```

KMS Key:

```bash
RDS_KMS_KEY_ID=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].KmsKeyId' \
  --output text \
  --no-cli-pager)

aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$RDS_KMS_KEY_ID" \
  --query 'KeyMetadata.{KeyId:KeyId,Arn:Arn,Enabled:Enabled,KeyState:KeyState,KeyManager:KeyManager,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- `StorageEncrypted=true`
- KMS Keyが有効である
- AWS管理キーかカスタマー管理キーか説明できる
- Snapshot、Replica、Restore、Copy時のKMS権限を考慮する

未暗号化RDSは、その場で単純に暗号化できるものとして扱わない。暗号化Snapshot、Restore、Endpoint切替、停止時間、接続試験、切り戻しを含む移行作業として検討する。

---

## 17. RDS Parameter Group・Option Groupの確認

### Webコンソール

1. RDSのConfigurationを開く
2. DB Parameter Groupを確認する
3. Apply Statusを確認する
4. Option Groupを確認する
5. Pending Modificationの有無を確認する

取得するスクリーンショット:

```text
17_RDS_Parameter_Option_Group確認.png
```

### AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{ParameterGroups:DBParameterGroups[*].{Name:DBParameterGroupName,Status:ParameterApplyStatus},OptionGroups:OptionGroupMemberships[*].{Name:OptionGroupName,Status:Status},PendingModifiedValues:PendingModifiedValues}' \
  --output json \
  --no-cli-pager
```

ユーザー変更済みParameter:

```bash
DB_PARAMETER_GROUP_NAME=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' \
  --output text \
  --no-cli-pager)

aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --source user \
  --query 'Parameters[*].{Name:ParameterName,Value:ParameterValue,ApplyType:ApplyType,ApplyMethod:ApplyMethod,Source:Source}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- Parameter Apply Statusが`in-sync`
- `pending-reboot`や`failed-to-apply`がない
- ユーザー変更値の目的と影響を説明できる
- Option GroupがEngineと要件に一致する
- Pending Modificationがある場合、反映時期と影響を確認する

---

## 18. RDSログとCloudWatch Logs連携の確認

### Webコンソール

1. RDSのLogs & eventsを開く
2. 利用できるDB Logを確認する
3. CloudWatch Logs Export設定を確認する
4. CloudWatch Logs側のLog Groupと保持期間を確認する

取得するスクリーンショット:

```text
18_RDS_Logs_Export確認.png
19_RDS_CloudWatch_Log_Group確認.png
```

### AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports,PendingCloudwatchLogsExports:PendingCloudwatchLogsExports}' \
  --output table \
  --no-cli-pager
```

RDS Log File一覧:

```bash
aws rds describe-db-log-files \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DescribeDBLogFiles[*].{LogFileName:LogFileName,LastWritten:LastWritten,Size:Size}' \
  --output table \
  --no-cli-pager
```

CloudWatch Log Group:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/rds/instance/${DB_INSTANCE_ID}" \
  --query 'logGroups[*].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 必要なDB Logが取得可能である
- CloudWatch Logs Exportが監査・運用要件どおりである
- Log Groupの保持期間と暗号化を確認できる
- Export未設定は即時障害ではないが、調査性・監査性の改善候補になる
- Log出力有効化はDB負荷、Storage、CloudWatch Logs費用へ影響する

---

## 19. RDS Backup・Snapshot・Deletion Protectionの確認

### Webコンソール

1. RDSのMaintenance & backupsを確認する
2. Automated BackupのRetentionを確認する
3. Backup Windowを確認する
4. Deletion Protectionを確認する
5. Snapshot一覧を確認する
6. 「変更」「スナップショット作成」は押さない

取得するスクリーンショット:

```text
20_RDS_Backup_Deletion_Protection確認.png
21_RDS_Snapshot一覧確認.png
```

### AWS CLI

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,BackupRetentionPeriod:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow,LatestRestorableTime:LatestRestorableTime,CopyTagsToSnapshot:CopyTagsToSnapshot,DeletionProtection:DeletionProtection,DeleteAutomatedBackups:DeleteAutomatedBackups,MultiAZ:MultiAZ}' \
  --output table \
  --no-cli-pager
```

Snapshot:

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,Type:SnapshotType,Status:Status,Encrypted:Encrypted,KmsKeyId:KmsKeyId,CreateTime:SnapshotCreateTime}' \
  --output table \
  --no-cli-pager
```

Manual Snapshot一覧:

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --snapshot-type manual \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,DBInstance:DBInstanceIdentifier,Engine:Engine,Encrypted:Encrypted,CreateTime:SnapshotCreateTime}' \
  --output table \
  --no-cli-pager
```

Manual Snapshotがある場合、共有属性を確認する。

```bash
MANUAL_SNAPSHOT_ID="<manual-db-snapshot-id>"

aws rds describe-db-snapshot-attributes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-snapshot-identifier "$MANUAL_SNAPSHOT_ID" \
  --query 'DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]' \
  --output table \
  --no-cli-pager
```

`restore`属性に`all`が含まれる場合、Public共有状態である。不要なAWSアカウントIDが含まれていないことも確認する。

### ラボ環境の評価

```text
BackupRetentionPeriod=0:
日次削除する個人ラボでは意図した設定。
本番・金融環境では、RPO、RTO、AWS Backup利用有無を確認する。

DeletionProtection=false:
cleanup_network.shで削除するラボでは意図した設定。
本番・重要DBでは、誤削除防止のため有効化を検討する。

MultiAZ=false:
学習コストを抑えるための設定。
本番では可用性、復旧、停止許容時間を確認する。
```

### 結果の読み方

- Backup Retentionが環境方針と一致する
- 本番相当ではPoint-in-Time Recovery要件を満たす
- Deletion Protectionが環境方針と一致する
- Snapshotが暗号化される
- SnapshotがPublic共有されていない
- Backup Windowが業務影響を考慮している

---

## 20. RDS証跡保存

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rds/01_db_instance.json"

aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rds/02_db_subnet_group.json"

aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rds/03_db_security_group_rules.json"

aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rds/04_db_snapshots.json"
```

---

## 21. CloudTrailでEC2・RDS変更履歴を確認する

### 主なEC2イベント

| 領域 | 主なイベント |
|---|---|
| EC2起動・終了 | `RunInstances`、`TerminateInstances` |
| SG変更 | `AuthorizeSecurityGroupIngress`、`RevokeSecurityGroupIngress` |
| IAM Profile | `AssociateIamInstanceProfile`、`ReplaceIamInstanceProfileAssociation` |
| IMDS | `ModifyInstanceMetadataOptions` |
| EBS | `CreateVolume`、`AttachVolume`、`ModifyVolume` |

### 主なRDSイベント

| 領域 | 主なイベント |
|---|---|
| DB作成・変更 | `CreateDBInstance`、`ModifyDBInstance` |
| DB削除 | `DeleteDBInstance` |
| Snapshot | `CreateDBSnapshot`、`ModifyDBSnapshotAttribute` |
| Parameter | `ModifyDBParameterGroup`、`ResetDBParameterGroup` |

### EC2変更履歴

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifyInstanceMetadataOptions \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### RDS変更履歴

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifyDBInstance \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 誰が、いつ、どのAPIを実行したか確認する
- Event IDから詳細イベントを取得できる
- Event Historyは直近履歴確認用であり、長期保存要件はTrailまたはEvent Data Storeで確認する
- 設定値の現状確認と変更履歴確認を組み合わせる

---

## 22. Webコンソール証跡一覧

| No. | ファイル名 | 内容 |
|---|---|---|
| 1 | `01_操作アカウント確認.png` | 操作アカウント |
| 2 | `02_sample-vpc確認.png` | 対象VPC |
| 3 | `03_EC2一覧_Public_IP確認.png` | EC2一覧、Public IP |
| 4 | `04_EC2_Subnet配置確認.png` | Public / Private配置 |
| 5 | `05_Bastion_SG確認.png` | Bastion SG |
| 6 | `06_Web_EC2_SG確認.png` | Web SG |
| 7 | `07_EC2_IAM_Role関連付け確認.png` | Instance Profile |
| 8 | `08_Web_Role_Policy確認.png` | Role権限 |
| 9 | `09_EC2_IMDSv2確認.png` | Metadata Options |
| 10 | `10_EC2_EBS暗号化確認.png` | Volume暗号化 |
| 11 | `11_EBSデフォルト暗号化確認.png` | Region設定 |
| 12 | `12_RDS基本設定_Public_Access確認.png` | RDS基本設定 |
| 13 | `13_RDS_DB_Subnet_Group確認.png` | DB Subnet Group |
| 14 | `14_RDS_Subnet_Route確認.png` | Route Table |
| 15 | `15_RDS_Security_Group確認.png` | DB SG |
| 16 | `16_RDS_Storage暗号化確認.png` | RDS暗号化 |
| 17 | `17_RDS_Parameter_Option_Group確認.png` | Parameter / Option |
| 18 | `18_RDS_Logs_Export確認.png` | RDS Logs |
| 19 | `19_RDS_CloudWatch_Log_Group確認.png` | Log Group |
| 20 | `20_RDS_Backup_Deletion_Protection確認.png` | Backup / Delete Protection |
| 21 | `21_RDS_Snapshot一覧確認.png` | Snapshot |

スクリーンショット取得時の注意:

- 対象名、設定値、アカウントを識別できる情報を含める
- DB Password、Access Key、Secret、個人情報を含めない
- IAM PolicyやKMS Policyに機密情報が含まれないか確認する
- 変更ボタンを押さない

---

## 23. 調査結果の記載例

```text
対象VPC内のEC2およびRDSについて、セキュリティ設定を確認した。

EC2:
・BastionのみPublic IPを保持している
・Web01、Web02はPrivate Subnetに配置され、Public IPはない
・Web SGはBastion SGからのSSHとALB SGからのApplication通信に限定されている
・Web EC2には用途限定のIAM Roleが関連付いている
・IMDSv2は必須化されている
・EBS暗号化状態を確認した

RDS:
・PubliclyAccessibleはfalseである
・DB Subnet Groupは2つのPrivate Subnetで構成されている
・DB SGはWeb SGからTCP 3306のみ許可している
・StorageEncryptedはtrueである
・BackupRetentionPeriod、DeletionProtection、MultiAZはラボ方針により無効である

本番・金融環境では、Backup、Deletion Protection、Multi-AZ、
CloudWatch Logs Exportの要件確認が必要である。

設定変更は実施していない。
```

## Teams報告例

```text
EC2・RDS Security確認を完了しました。

EC2:
・BastionのみPublic IPあり
・Web EC2はPrivate Subnet、Public IPなし
・IMDSv2必須
・Web IAM Role、SG、EBS暗号化を確認

RDS:
・PubliclyAccessible=false
・Private DB Subnet Group
・DB SGはWeb SGからTCP 3306のみ
・StorageEncrypted=true

ラボではBackup Retention、Deletion Protection、Multi-AZが無効です。
本番適用時は復旧・可用性・監査要件の確認が必要です。
設定変更は実施していません。
```

---

## 24. 良好な設定と改善候補の整理

| 領域 | ラボの状態 | 判定 |
|---|---|---|
| Web EC2 Public IP | なし | 良好 |
| Bastion Public IP | あり | 用途と接続元制限を確認 |
| Web SG | Bastion / ALB SG参照 | 良好 |
| IMDSv2 | required | 良好 |
| Web IAM Role | S3限定Policy、CloudWatch Agent Policy | 権限詳細を確認 |
| EBS暗号化 | 実値確認 | 未暗号化なら改善候補 |
| RDS Public設定 | false | 良好 |
| DB Subnet Group | Private Subnet 2つ | 良好 |
| DB SG | Web SGから3306 | 良好 |
| RDS Storage暗号化 | true | 良好 |
| Backup Retention | 0 | ラボ想定。本番では改善候補 |
| Deletion Protection | false | ラボ想定。本番では改善候補 |
| Multi-AZ | false | ラボ想定。本番では可用性要件確認 |
| RDS Logs Export | 未設定の可能性 | 監査・運用要件確認 |

---

## 25. 変更時の影響調査観点

## EC2 Public IP・Subnet変更

- 接続元、接続先、運用経路
- Route Table、IGW、NAT、SG、NACL
- DNS Record、監視、許可リスト
- SSH、Ansible、バッチ、外部連携
- 停止・再起動・IP変更の可能性

## IAM Role・Policy変更

- Roleを使用する全EC2
- Applicationが実行するAWS API
- S3、CloudWatch Logs、KMSなどのResource
- Deny、Permission Boundary、SCP
- 変更後のApplication動作試験

## IMDSv2必須化

- Application、Agent、Script、Containerの対応
- Hop Limit要件
- IMDSv1利用状況
- 変更後のIAM Role認証とAgent状態

## EBS暗号化

- 既存Volumeを直接変更できるか
- Snapshot、Copy、Volume交換
- KMS Key Policyと利用権限
- 停止時間、Device Mapping、Mount
- 性能、バックアップ、切り戻し

## RDS設定変更

- Application、バッチ、監視、運用接続
- Endpoint、DNS、SG、Subnet、Route
- 再起動、停止、Pending Modification
- RPO、RTO、Backup Window
- Parameter、Logs、Storage、費用
- Snapshot、Restore、切り戻し方法

---

## 26. 案件で説明できるポイント

- EC2の公開範囲はPublic IP、Route、SG、NACLを組み合わせて判断する
- Web EC2をPrivate Subnetへ配置し、ALBやBastion経由に限定する構成を説明できる
- EC2には直接RoleではなくInstance Profileが関連付く
- IAM Roleは信頼ポリシーと権限ポリシーを分けて確認する
- IMDSv2必須化は一時認証情報の保護に重要である
- EBSデフォルト暗号化と既存Volume暗号化は別に確認する
- RDSの非公開性はPubliclyAccessibleだけで判断しない
- DB Subnet Group、Route、DB SGを合わせて確認する
- RDS暗号化はKMS Key、Snapshot、Restoreまで考慮する
- Backup、Deletion Protection、Multi-AZは環境要件によって評価が変わる
- CloudTrailでEC2・RDS設定変更の実行者と時刻を確認できる

## 資格試験につながるポイント

- Security GroupはStateful、Network ACLはStateless
- IAM Roleは長期Access Keyではなく一時認証情報を提供する
- IMDSv2はSession-orientedでTokenを使用する
- EBS暗号化はKMSを使用する
- RDSのStorage暗号化はSnapshotやReplicaにも関係する
- RDS DB Subnet Groupは複数AZのSubnetで構成する
- Multi-AZは可用性、Read Replicaは読み取り拡張が主目的である
- Backup Retentionが0の場合、自動バックアップは無効になる
- Deletion Protectionは誤削除防止に利用する

---

## 27. 要確認事項

実案件では次を担当者、設計書、運用手順書で確認する。

- EC2の役割、Public IP付与基準、接続経路
- Bastionを使用するか、SSM Session Managerを使用するか
- IAM Role、Permission Boundary、SCPの管理主体
- IMDSv2必須化とContainer / Agentの要件
- EBS KMS KeyとKey Policy
- EBS Snapshot、AMI、Backupの保持方針
- RDS Public設定、接続元、閉域網の構成
- DB Subnet Group、Route、NACLの設計
- DB SGの管理主体と変更手順
- RDS KMS KeyとSnapshot共有方針
- Parameter Group、Option Groupの変更管理
- DB Log、CloudWatch Logs、監査ログの要件
- RPO、RTO、Backup Retention、AWS Backupの利用有無
- Multi-AZ、Failover試験、Maintenance Window
- Deletion Protectionと削除承認手順
- 証跡の保存先、保管期間、マスクルール

---

## 28. Day 15完了チェックリスト

- [ ] AWSアカウント、リージョン、対象VPCを確認した
- [ ] EC2一覧、役割、Public IPを確認した
- [ ] BastionとWeb EC2のSubnet配置を確認した
- [ ] EC2のSecurity Group関連付けとRuleを確認した
- [ ] Public Inbound Ruleを確認した
- [ ] EC2のIAM Instance Profileを確認した
- [ ] Web IAM Roleの信頼ポリシーと権限を確認した
- [ ] EC2のIMDSv2設定を確認した
- [ ] EBSデフォルト暗号化を確認した
- [ ] EC2関連EBS Volumeの暗号化を確認した
- [ ] RDSのPubliclyAccessibleを確認した
- [ ] RDS DB Subnet GroupとRouteを確認した
- [ ] RDS Security Groupを確認した
- [ ] RDS Storage暗号化とKMS Keyを確認した
- [ ] RDS Parameter GroupとOption Groupを確認した
- [ ] RDS LogsとCloudWatch Logs Exportを確認した
- [ ] RDS Backup、Snapshot、Deletion Protectionを確認した
- [ ] CloudTrailでEC2・RDS変更履歴を確認する方法を確認した
- [ ] ラボと本番で評価が異なる設定を整理した
- [ ] 証跡、結果、改善候補、要確認事項を整理した

## Day 15の完了条件

次を自分の言葉で説明できればDay 15は完了とする。

```text
1. EC2のPublic IPだけで公開状態を判断できない理由
2. EC2 IAM Role、Instance Profile、Policyの関係
3. IMDSv2を必須化する理由
4. EBSデフォルト暗号化と既存Volume暗号化の違い
5. RDSを外部公開していないことを複数観点で確認する方法
6. DB Subnet GroupとDB Security Groupの役割
7. RDS Storage暗号化変更が単純な設定変更ではない理由
8. Backup Retention、Deletion Protection、Multi-AZの評価が環境で変わる理由
9. EC2・RDS設定変更時に必要な影響調査、試験、切り戻し
```
