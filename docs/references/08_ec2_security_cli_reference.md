# 08 EC2 Security CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、EC2のセキュリティ設定をAWS CLIで確認し、影響調査、設定変更、変更後確認、証跡取得、切り戻しを行うためのリファレンスである。

対象は、銀行系システムのように、既存AWS環境に対してセキュリティ改善やネットワーク最適化を行う現場を想定する。

このドキュメントでは、主に以下を扱う。

- EC2インスタンス一覧確認
- Public IP / Subnet / Security Group確認
- IAM Role / Instance Profile確認
- IMDSv2設定確認
- IMDSv2必須化
- EBS暗号化確認
- EBS暗号化デフォルト設定確認
- Security Group確認
- Security Group Rule単位の確認
- CloudTrailによる変更履歴確認
- 変更前後の証跡取得
- 切り戻し手順
- Teams報告例

関連リファレンス:

```text
00_common_aws_cli_reference.md
07_vpc_network_cli_reference.md
aws_security_investigation_cli_reference.md
```

## 2. EC2セキュリティ確認で見る順番

EC2のセキュリティ調査では、以下の順番で見ると整理しやすい。

```text
EC2 Instance
  ↓
配置場所
  VPC / Subnet / Public IP / Private IP
  ↓
通信制御
  Security Group / Network ACL / Route Table
  ↓
権限
  IAM Instance Profile / IAM Role / Attached Policy / Inline Policy
  ↓
メタデータ保護
  IMDSv2 / HttpTokens / HttpEndpoint / HopLimit
  ↓
ストレージ保護
  EBS Encryption / KMS Key / DeleteOnTermination
  ↓
証跡
  CloudTrail / Config / CloudWatch / SSM
```

確認観点:

| 観点 | 確認内容 |
| :--- | :--- |
| Public Exposure | Public IPが不要なEC2に付いていないか |
| Network | Subnet、Route Table、SG、NACLが設計どおりか |
| IAM Role | EC2に不要に強いRoleが付いていないか |
| IMDS | IMDSv2が必須化されているか |
| EBS | Volumeが暗号化されているか |
| Key Pair | 不要なSSH前提になっていないか |
| Logging | CloudTrailで変更履歴を追えるか |
| Operations | 変更前後の証跡と切り戻しがあるか |

重要:

```text
EC2のセキュリティ確認は、インスタンス単体では完結しない。
IAM Role、Security Group、EBS、IMDS、CloudTrailをセットで確認する。
```

## 3. 作業前の共通変数

### 3.1 Bash

```bash
PROFILE="learning"
REGION="ap-northeast-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

VPC_NAME="sample-vpc"

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "Account: $ACCOUNT_ID"
echo "Region : $REGION"
echo "VPC    : $VPC_ID"
```

### 3.2 証跡ディレクトリ

```bash
WORK_NAME="ec2_security_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"
```

### 3.3 Caller Identity保存

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

## 4. クイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | EC2一覧 | 対象インスタンスを識別できる | `describe-instances` |
| 2 | Public IP | Private EC2にPublic IPなし | `describe-instances` |
| 3 | Subnet | Public/Private配置が設計どおり | `describe-subnets` |
| 4 | Security Group | 必要最小限のInbound/Outbound | `describe-security-groups` |
| 5 | SG Rule | Rule単位で確認できる | `describe-security-group-rules` |
| 6 | IAM Role | 必要なRoleだけ付与 | `describe-iam-instance-profile-associations` |
| 7 | Role Policy | 最小権限 | `list-attached-role-policies`、`list-role-policies` |
| 8 | IMDSv2 | `HttpTokens=required` | `describe-instances` |
| 9 | EBS Volume | `Encrypted=true` | `describe-volumes` |
| 10 | EBS default encryption | `EbsEncryptionByDefault=true` | `get-ebs-encryption-by-default` |
| 11 | DeleteOnTermination | 不要Volumeが残らない | `describe-instances` |
| 12 | CloudTrail | 変更履歴を追える | `lookup-events` |

## 5. EC2インスタンス確認

### 5.1 VPC内EC2一覧

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,State:State.Name,Type:InstanceType,AZ:Placement.AvailabilityZone,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,IamProfile:IamInstanceProfile.Arn,KeyName:KeyName,LaunchTime:LaunchTime}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/01_describe_instances.json"
```

確認ポイント:

- 対象EC2のNameタグ、Instance IDが確認できる
- Running / Stopped / Terminatedの状態
- Public IPの有無
- Subnet配置
- IAM Instance Profileの有無
- Key Pairの有無
- 起動時刻

### 5.2 稼働中EC2だけ確認

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SubnetId:SubnetId,SGs:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn}' \
  --output table
```

### 5.3 Public IPを持つEC2確認

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[?PublicIpAddress!=`null`].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,PublicIp:PublicIpAddress,PrivateIp:PrivateIpAddress,SubnetId:SubnetId,SGs:SecurityGroups[*].GroupId}' \
  --output table
```

確認ポイント:

- Bastion以外のEC2にPublic IPが付いていないか
- Private Subnet配置のEC2にPublic IPが付いていないか
- WebサーバーはALB経由のみでよいか
- 直接SSH/RDPが必要な設計か

## 6. EC2詳細確認

### 6.1 対象インスタンス詳細

```bash
INSTANCE_ID="<instance-id>"

aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,Type:InstanceType,ImageId:ImageId,Platform:PlatformDetails,SubnetId:SubnetId,VpcId:VpcId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SGs:SecurityGroups,IamProfile:IamInstanceProfile,MetadataOptions:MetadataOptions,BlockDevices:BlockDeviceMappings}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/instance_${INSTANCE_ID}.json"
```

### 6.2 EC2に紐づくSecurity Group

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,SecurityGroups:SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName}}' \
  --output table
```

### 6.3 EC2に紐づくEBS Volume ID

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].BlockDeviceMappings[].{DeviceName:DeviceName,VolumeId:Ebs.VolumeId,DeleteOnTermination:Ebs.DeleteOnTermination,Status:Ebs.Status}' \
  --output table
```

## 7. IAM Role / Instance Profile確認

### 7.1 Instance Profile association確認

EC2にIAM Roleを付ける場合、EC2には直接RoleではなくInstance Profileが関連付く。

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=instance-id,Values="$INSTANCE_ID" \
  --query 'IamInstanceProfileAssociations[*].{AssociationId:AssociationId,InstanceId:InstanceId,State:State,ProfileArn:IamInstanceProfile.Arn}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=instance-id,Values="$INSTANCE_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/02_iam_instance_profile_association_${INSTANCE_ID}.json"
```

確認ポイント:

- Instance Profileが付いているか
- Stateが `associated` か
- 想定Roleに紐づくProfileか
- 不要に強いRoleが付いていないか

### 7.2 Instance Profile名を取得する

```bash
INSTANCE_PROFILE_ARN=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text)

INSTANCE_PROFILE_NAME="${INSTANCE_PROFILE_ARN##*/}"

echo "$INSTANCE_PROFILE_NAME"
```

### 7.3 Instance Profileに含まれるRole確認

```bash
aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --query 'InstanceProfile.{InstanceProfileName:InstanceProfileName,Arn:Arn,Roles:Roles[*].RoleName,CreateDate:CreateDate}' \
  --output table
```

証跡保存:

```bash
aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/instance_profile_${INSTANCE_PROFILE_NAME}.json"
```

### 7.4 Role名を取得する

```bash
ROLE_NAME=$(aws iam get-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --query 'InstanceProfile.Roles[0].RoleName' \
  --output text)

echo "$ROLE_NAME"
```

### 7.5 Role信頼ポリシー確認

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,AssumeRolePolicyDocument:AssumeRolePolicyDocument,CreateDate:CreateDate}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/role_${ROLE_NAME}.json"
```

確認ポイント:

- Trust PolicyのPrincipalが `ec2.amazonaws.com` か
- 不要なPrincipalが信頼されていないか
- Role名と用途が一致しているか

### 7.6 AWS管理ポリシー確認

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
  --output table
```

証跡保存:

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/role_${ROLE_NAME}_attached_policies.json"
```

確認ポイント:

- `AdministratorAccess` など過剰な権限がないか
- `AmazonS3FullAccess` のような広い権限を使っていないか
- CloudWatch Agent用など用途に合った権限か
- 本番では対象リソースに絞ったカスタムポリシーが望ましい

### 7.7 Inline Policy確認

```bash
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'PolicyNames[]' \
  --output table
```

Inline Policyを取得する:

```bash
POLICY_NAME="<inline-policy-name>"

aws iam get-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/role_${ROLE_NAME}_inline_${POLICY_NAME}.json"
```

確認ポイント:

- `Action: "*"` がないか
- `Resource: "*"` が妥当か
- `s3:*`、`iam:*`、`kms:*` など広すぎるActionがないか
- Conditionで対象を絞れるか
- 不要な権限が残っていないか

### 7.8 IAM権限変更時の注意

EC2 Roleの権限を変更すると、アプリやAgentに影響する可能性がある。

影響例:

| 変更対象 | 影響例 |
| :--- | :--- |
| S3権限 | 画像アップロード、ログ保存、データ取得が失敗する |
| CloudWatch Logs権限 | CloudWatch Agentのログ送信が失敗する |
| SSM権限 | Session Manager接続やRun Commandが失敗する |
| KMS権限 | 暗号化S3/EBS/Secretsの利用に失敗する |
| Secrets Manager権限 | アプリ起動やDB接続情報取得に失敗する |

変更前に確認すること:

- 対象Roleを利用しているEC2一覧
- アプリが使うAWS API
- CloudTrail上の直近API利用履歴
- 切り戻し用の旧Policy
- 変更後テスト項目

## 8. IMDSv2確認

IMDSはInstance Metadata Serviceである。

IMDSv1が利用可能な状態では、SSRFなどの脆弱性と組み合わさった場合に、一時認証情報の取得リスクが高くなる。

基本方針:

```text
HttpEndpoint: enabled
HttpTokens: required
HttpPutResponseHopLimit: 1
InstanceMetadataTags: disabled
```

ただし、コンテナ、プロキシ、特殊Agentがある場合、HopLimitを2以上にする必要があることがある。

### 8.1 EC2ごとのIMDS設定確認

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,HttpEndpoint:MetadataOptions.HttpEndpoint,HttpTokens:MetadataOptions.HttpTokens,HopLimit:MetadataOptions.HttpPutResponseHopLimit,MetadataTags:MetadataOptions.InstanceMetadataTags,MetadataState:MetadataOptions.State}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,MetadataOptions:MetadataOptions}' \
  --output json \
  > "$EVIDENCE_DIR/before/03_imds_options.json"
```

### 8.2 IMDSv2が必須でないEC2を抽出

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=metadata-options.http-tokens,Values=optional \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,State:State.Name,HttpTokens:MetadataOptions.HttpTokens,HttpEndpoint:MetadataOptions.HttpEndpoint,HopLimit:MetadataOptions.HttpPutResponseHopLimit}' \
  --output table
```

結果が出た場合:

- IMDSv1も利用可能な状態
- IMDSv2必須化の候補
- アプリやAgentがIMDSv2に対応しているか確認する

### 8.3 IMDSv2必須化

```bash
INSTANCE_ID="<instance-id>"

aws ec2 modify-instance-metadata-options \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --http-endpoint enabled \
  --http-tokens required \
  --http-put-response-hop-limit 1 \
  --instance-metadata-tags disabled
```

変更直後は `MetadataOptions.State=pending` になることがある。

### 8.4 IMDSv2変更後確認

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,MetadataOptions:MetadataOptions}' \
  --output json \
  > "$EVIDENCE_DIR/after/imds_options_${INSTANCE_ID}.json"
```

期待値:

```text
HttpEndpoint = enabled
HttpTokens = required
HttpPutResponseHopLimit = 1
InstanceMetadataTags = disabled
State = applied
```

### 8.5 OS上からIMDSv2確認

EC2へログインできる場合、OS上で確認できる。

```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

IMDSv1が無効になっているか確認する:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  http://169.254.169.254/latest/meta-data/
```

期待値:

```text
IMDSv2 tokenあり: 取得できる
IMDSv1 tokenなし: 401になる
```

### 8.6 IMDSv2切り戻し

アプリやAgentがIMDSv2に対応しておらず影響が出た場合、切り戻し候補は以下。

```bash
aws ec2 modify-instance-metadata-options \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --http-endpoint enabled \
  --http-tokens optional
```

注意:

- `optional` に戻すとIMDSv1も利用可能になる
- 本番では恒久対応としてアプリ/Agent側をIMDSv2対応にする
- 切り戻し理由、影響内容、再対応方針を記録する

## 9. EBS暗号化確認

### 9.1 アカウント/リージョンのEBS暗号化デフォルト確認

```bash
aws ec2 get-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

証跡保存:

```bash
aws ec2 get-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/04_ebs_encryption_by_default.json"
```

期待値:

```text
EbsEncryptionByDefault = true
```

### 9.2 デフォルトKMS Key確認

```bash
aws ec2 get-ebs-default-kms-key-id \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

証跡保存:

```bash
aws ec2 get-ebs-default-kms-key-id \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/05_ebs_default_kms_key.json"
```

確認ポイント:

- AWS管理キーか、カスタマー管理KMS Keyか
- キーポリシーで必要なPrincipalが利用できるか
- バックアップやAMIコピー時にKMS権限不足が起きないか

### 9.3 EC2に紐づくEBS Volume暗号化確認

```bash
VOLUME_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' \
  --output text)

aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --volume-ids $VOLUME_IDS \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size,VolumeType:VolumeType,Encrypted:Encrypted,KmsKeyId:KmsKeyId,AZ:AvailabilityZone,Attachments:Attachments[*].{InstanceId:InstanceId,Device:Device,DeleteOnTermination:DeleteOnTermination}}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --volume-ids $VOLUME_IDS \
  --output json \
  > "$EVIDENCE_DIR/investigation/volumes_${INSTANCE_ID}.json"
```

確認ポイント:

- `Encrypted=true`
- `KmsKeyId` が想定どおり
- 不要に大きいVolumeがないか
- `DeleteOnTermination` が設計どおり

### 9.4 未暗号化EBS Volume抽出

```bash
aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=encrypted,Values=false \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size,VolumeType:VolumeType,AZ:AvailabilityZone,Attachments:Attachments[*].{InstanceId:InstanceId,Device:Device}}' \
  --output table
```

結果が出た場合:

- 暗号化対応の対象
- 既存Volumeはそのまま暗号化できないため、SnapshotコピーやVolume交換を検討する
- 停止や切替作業が必要になる可能性がある
- アプリ影響が大きいため、単純な設定変更として扱わない

### 9.5 EBS暗号化デフォルト有効化

リージョン単位で、新規作成されるEBS Volumeをデフォルト暗号化する。

```bash
aws ec2 enable-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION"
```

変更後確認:

```bash
aws ec2 get-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

注意:

- 既存Volumeには影響しない
- 新規Volume、AMIからの起動、Snapshotコピーなどに影響する
- KMS Key権限不足があると起動や作成に失敗する可能性がある

### 9.6 EBS暗号化デフォルト切り戻し

```bash
aws ec2 disable-ebs-encryption-by-default \
  --profile "$PROFILE" \
  --region "$REGION"
```

注意:

- セキュリティ方針上、切り戻しは基本的に推奨しない
- 本番では承認なしに無効化しない
- 切り戻し理由を記録する

## 10. Security Group確認

### 10.1 EC2に紐づくSecurity Group ID取得

```bash
SG_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].SecurityGroups[].GroupId' \
  --output text)

echo "$SG_IDS"
```

### 10.2 Security Group詳細確認

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SG_IDS \
  --query 'SecurityGroups[*].{Name:GroupName,GroupId:GroupId,VpcId:VpcId,Description:Description,Inbound:IpPermissions,Outbound:IpPermissionsEgress,Tags:Tags}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/security_groups_${INSTANCE_ID}.json"
```

表形式:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SG_IDS \
  --query 'SecurityGroups[*].{Name:GroupName,GroupId:GroupId,VpcId:VpcId,Description:Description}' \
  --output table
```

### 10.3 Security Group Rule単位で確認

```bash
for SG_ID in $SG_IDS; do
  aws ec2 describe-security-group-rules \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=group-id,Values="$SG_ID" \
    --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
    --output table
done
```

証跡保存:

```bash
for SG_ID in $SG_IDS; do
  aws ec2 describe-security-group-rules \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=group-id,Values="$SG_ID" \
    --output json \
    > "$EVIDENCE_DIR/investigation/security_group_rules_${SG_ID}.json"
done
```

確認ポイント:

- Inboundが必要最小限か
- 0.0.0.0/0 や ::/0 の許可がないか
- SSH/RDPが全公開されていないか
- DB/Redisなどのポートが全公開されていないか
- SourceにCIDRではなくSecurity Groupを使えるか
- Outbound全許可が必要か
- Rule Descriptionがあるか

### 10.4 危険なInbound公開確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,Description:Description}' \
  --output table
```

特に注意するポート:

| ポート | 用途 | 注意 |
| :--- | :--- | :--- |
| 22 | SSH | Bastion以外は原則公開しない |
| 3389 | RDP | 全公開は避ける |
| 3306 | MySQL | Web SGなど接続元を限定 |
| 5432 | PostgreSQL | 接続元を限定 |
| 6379 | Redis | 接続元を限定 |
| 9200 | Elasticsearch/OpenSearch | 公開しない |
| 80/443 | Web | 原則ALBだけ公開 |

### 10.5 EC2 SG変更時の影響

| 変更内容 | 影響 |
| :--- | :--- |
| Inbound削除 | アプリ、運用接続、監視、ヘルスチェックが失敗する可能性 |
| Inbound追加 | 意図しないアクセス経路が増える可能性 |
| Outbound削除 | 外部API、S3、CloudWatch Logs、SSM、yum/dnfが失敗する可能性 |
| Source CIDR変更 | 利用者や管理端末から接続できなくなる可能性 |
| Source SG変更 | ALB、Web、DB間通信に影響する可能性 |

変更前に確認すること:

- Source / Destination / Port / Protocol
- 現在の利用元
- ALB Target Health
- アプリの待受Port
- CloudWatch AgentやSSM Agentの通信
- Flow LogsのACCEPT/REJECT

## 11. Security Group変更例

### 11.1 Inbound追加

例: ALB SGからWeb EC2 SGへ3000番を許可する。

```bash
WEB_SG_ID="<web-security-group-id>"
ALB_SG_ID="<alb-security-group-id>"

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=3000,ToPort=3000,UserIdGroupPairs=[{GroupId=$ALB_SG_ID,Description='HTTP access from ALB'}]"
```

変更後確認:

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$WEB_SG_ID" \
  --query 'SecurityGroupRules[?IsEgress==`false`].{RuleId:SecurityGroupRuleId,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table
```

### 11.2 Rule IDでInbound削除

```bash
RULE_ID="<security-group-rule-id>"

aws ec2 revoke-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --security-group-rule-ids "$RULE_ID"
```

注意:

- Rule IDを使うと、削除対象を特定しやすい
- 変更前にRule IDを証跡として保存する
- 削除後に通信テストを行う

### 11.3 既存Ruleの説明変更

```bash
aws ec2 update-security-group-rule-descriptions-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=3000,ToPort=3000,UserIdGroupPairs=[{GroupId=$ALB_SG_ID,Description='HTTP access from ALB'}]"
```

説明変更もCloudTrailに記録される。

## 12. CloudTrailでEC2変更履歴を確認する

### 12.1 EC2設定変更

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifyInstanceMetadataOptions \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_modify_instance_metadata_options.json"
```

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| EC2起動 | `RunInstances` |
| EC2停止 | `StopInstances` |
| EC2開始 | `StartInstances` |
| EC2終了 | `TerminateInstances` |
| Instance Type変更 | `ModifyInstanceAttribute` |
| IMDS設定変更 | `ModifyInstanceMetadataOptions` |
| SG関連付け変更 | `ModifyInstanceAttribute` |

### 12.2 IAM Instance Profile変更

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ReplaceIamInstanceProfileAssociation \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_replace_instance_profile.json"
```

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| Instance Profile関連付け | `AssociateIamInstanceProfile` |
| Instance Profile置換 | `ReplaceIamInstanceProfileAssociation` |
| Instance Profile解除 | `DisassociateIamInstanceProfile` |
| RoleへPolicy付与 | `AttachRolePolicy` |
| RoleからPolicy解除 | `DetachRolePolicy` |
| Inline Policy追加/更新 | `PutRolePolicy` |
| Inline Policy削除 | `DeleteRolePolicy` |

注意:

- IAMはグローバルサービスのため、CloudTrailの記録リージョンやTrail設定を確認する
- 組織Trailや監査アカウントに保存される場合がある

### 12.3 Security Group変更

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| Inbound追加 | `AuthorizeSecurityGroupIngress` |
| Inbound削除 | `RevokeSecurityGroupIngress` |
| Outbound追加 | `AuthorizeSecurityGroupEgress` |
| Outbound削除 | `RevokeSecurityGroupEgress` |
| Rule変更 | `ModifySecurityGroupRules` |
| Rule説明変更 | `UpdateSecurityGroupRuleDescriptionsIngress` |

検索例:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_authorize_sg_ingress.json"
```

### 12.4 EBS暗号化関連

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| EBS暗号化デフォルト有効化 | `EnableEbsEncryptionByDefault` |
| EBS暗号化デフォルト無効化 | `DisableEbsEncryptionByDefault` |
| デフォルトKMS Key変更 | `ModifyEbsDefaultKmsKeyId` |
| Volume作成 | `CreateVolume` |
| Volume接続 | `AttachVolume` |
| Volume切断 | `DetachVolume` |
| Snapshot作成 | `CreateSnapshot` |
| Snapshotコピー | `CopySnapshot` |

## 13. 変更前後に保存する証跡

| タイミング | 証跡 | ファイル例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `00_caller_identity.json` |
| 変更前 | EC2一覧 | `01_describe_instances.json` |
| 変更前 | IAM Instance Profile | `02_iam_instance_profile_association_<instance-id>.json` |
| 変更前 | IMDS設定 | `03_imds_options.json` |
| 変更前 | EBS暗号化デフォルト | `04_ebs_encryption_by_default.json` |
| 変更前 | EBSデフォルトKMS Key | `05_ebs_default_kms_key.json` |
| 調査 | Instance詳細 | `instance_<instance-id>.json` |
| 調査 | Role詳細 | `role_<role-name>.json` |
| 調査 | Role Policy | `role_<role-name>_attached_policies.json` |
| 調査 | EBS Volume | `volumes_<instance-id>.json` |
| 調査 | Security Group | `security_groups_<instance-id>.json` |
| 調査 | Security Group Rule | `security_group_rules_<sg-id>.json` |
| 調査 | CloudTrail | `cloudtrail_*.json` |
| 変更後 | IMDS変更後 | `imds_options_<instance-id>.json` |
| 変更後 | SG変更後 | `security_group_rules_after_<sg-id>.json` |
| 画面 | AWS Console | EC2詳細、IAM Role、SG、EBS、CloudTrail |

## 14. 変更時の影響範囲

| 変更対象 | 主な影響 |
| :--- | :--- |
| IMDSv2必須化 | 古いSDK、古いAgent、独自スクリプトが認証情報取得に失敗する可能性 |
| IAM Role Policy変更 | S3、CloudWatch Logs、SSM、KMS、Secrets利用に影響 |
| Instance Profile変更 | EC2上のアプリやAgentが利用するAWS権限が変わる |
| EBS暗号化デフォルト | 新規Volume作成、AMI起動、Snapshotコピーに影響 |
| EBS Volume交換 | EC2停止、データ移行、アプリ停止が必要になる可能性 |
| Security Group Inbound変更 | アプリ接続、運用接続、ALB Health Checkに影響 |
| Security Group Outbound変更 | 外部API、AWS API、ログ送信、パッケージ取得に影響 |

変更前に必ず確認すること:

- 対象EC2の役割
- 影響するアプリ/Agent
- 利用しているAWS API
- 通信要件
- 変更前JSON証跡
- 切り戻し手順
- 作業後テスト項目

## 15. よくあるトラブルと確認ポイント

### 15.1 IMDSv2必須化後にアプリが動かない

確認ポイント:

- SDKがIMDSv2対応か
- CloudWatch Agent / SSM Agentが古くないか
- 独自スクリプトがIMDSv1前提でないか
- HopLimitが1で問題ないか
- コンテナ経由でメタデータを取得していないか

一次対応:

- アプリ/AgentのIMDSv2対応を確認
- 必要に応じてHopLimitを調整
- 緊急時は `HttpTokens=optional` へ切り戻し

### 15.2 EC2からS3へアクセスできない

確認ポイント:

- EC2 RoleにS3権限があるか
- Bucket PolicyでPrincipalが許可されているか
- Bucket Policyに `aws:sourceVpce` 条件があるか
- VPC Endpoint IDが一致しているか
- Security Group outboundが許可されているか
- Route TableがS3 EndpointまたはNAT Gateway向きか

### 15.3 CloudWatch Agentがログ送信できない

確認ポイント:

- EC2 RoleにCloudWatch Logs権限があるか
- `CloudWatchAgentServerPolicy` 相当の権限があるか
- Outbound 443が許可されているか
- Interface Endpointを使う場合、logs endpointへ到達できるか
- Agent設定が正しいか

### 15.4 ALB Targetがunhealthy

確認ポイント:

- Web EC2 SG inboundがALB SGからHealth Check Portを許可しているか
- アプリが対象PortでListenしているか
- NACLが双方向通信を許可しているか
- Target GroupのHealth Check Pathが正しいか
- EC2上のnginx/Pumaが起動しているか

### 15.5 EBS暗号化対応で起動できない

確認ポイント:

- KMS Key PolicyでEC2/Auto Scaling/利用Roleが許可されているか
- IAM RoleにKMS権限があるか
- Snapshotコピー時にKMS Keyを指定したか
- AMIのBlock Device Mappingが正しいか
- 別アカウント共有時にKMS Key共有が必要か

## 16. 作業手順書に書く項目

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | IMDSv2必須化、SG変更、Role Policy見直し、EBS暗号化確認など |
| 対象 | Account、Region、VPC、Instance ID、Role、SG、Volume |
| 変更前確認 | EC2、IAM Role、IMDS、EBS、SG、CloudTrail |
| 影響範囲 | アプリ、Agent、通信、AWS API、運用接続 |
| 変更内容 | 具体的なCLIまたはConsole操作 |
| 変更後確認 | 設定値、アプリ動作、Agent動作、CloudTrail |
| 切り戻し | 旧設定へ戻すコマンド |
| 証跡 | CLI JSON、Consoleスクリーンショット、ログ |
| 報告 | 作業結果、確認結果、残課題 |

## 17. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

Region:
  <region>

対象EC2:
  <instance-id> / <name>

配置:
  VPC:
  Subnet:
  Private IP:
  Public IP:

IAM:
  Instance Profile:
  Role:
  Attached Policy:
  Inline Policy:
  評価:

IMDS:
  HttpEndpoint:
  HttpTokens:
  HopLimit:
  InstanceMetadataTags:
  評価:

EBS:
  Volume ID:
  Encrypted:
  KMS Key:
  DeleteOnTermination:
  評価:

Security Group:
  Group ID:
  Inbound:
  Outbound:
  評価:

CloudTrail:
  変更履歴あり / なし / 未確認

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 18. Teams報告例

### 18.1 EC2セキュリティ確認完了

```text
EC2セキュリティ設定の確認を実施しました。
対象は <instance-id> / <name> です。

確認項目:
- IAM Instance Profile / Role
- IMDSv2設定
- EBS暗号化
- Security Group
- CloudTrail変更履歴

現時点の判定は <問題なし / 要確認 / 要改善> です。
証跡は所定フォルダへ格納済みです。
```

### 18.2 IMDSv2必須化前の連絡

```text
<instance-id> のIMDSv2必須化を実施予定です。
変更内容は HttpTokens=required、HttpEndpoint=enabled です。

変更前にEC2設定、IAM Role、アプリ/Agent影響、切り戻し手順を確認済みです。
変更後はアプリ動作、CloudWatch Agent、SSM Agent、CloudTrailを確認します。
```

### 18.3 Security Group変更後の報告

```text
Security Group変更が完了しました。

対象:
- EC2: <instance-id>
- SG: <sg-id>
- 変更内容: <source> から <port> の許可追加/削除

変更後確認:
- SG Rule: 想定どおり
- アプリ疎通: 正常
- ALB Target Health: healthy
- CloudTrail: 変更イベント確認済み

証跡は保存済みです。
```

## 19. 案件で説明できるポイント

このEC2セキュリティ確認は、案件では次のように説明できる。

```text
EC2の設定確認では、インスタンスの配置、Public IP、Security Groupだけでなく、
IAM Role、IMDSv2、EBS暗号化、CloudTrail変更履歴までまとめて確認します。

変更前には describe-instances、describe-security-group-rules、describe-volumes、
describe-iam-instance-profile-associations などで証跡を取得し、
変更後に同じ観点で再確認します。

IMDSv2必須化やIAM Role変更はアプリやAgentへ影響する可能性があるため、
変更前に影響範囲と切り戻し手順を明確にします。
```

## 20. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| EC2 | Instance ID、AMI、Subnet、Security Group、Key Pair |
| IAM Role | EC2にRoleを渡すにはInstance Profileが必要 |
| IMDSv2 | Token必須化、IMDSv1無効化 |
| Security Group | Stateful、Inbound/Outbound、Source SG |
| EBS暗号化 | KMS Key、Default Encryption、Snapshot/AMIとの関係 |
| CloudTrail | EC2/IAM/SG変更イベントの追跡 |
| Least Privilege | IAM Role Policyの最小権限 |
| Network | Public IP、Private Subnet、ALB経由アクセス |

## 21. 公式ドキュメント

- [EC2でInstance Profileを使用する](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html)
- [EC2 Instance Metadata Serviceの設定](https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html)
- [Amazon EBS暗号化](https://docs.aws.amazon.com/ja_jp/ebs/latest/userguide/ebs-encryption.html)
- [EBS暗号化をデフォルトで有効にする](https://docs.aws.amazon.com/ja_jp/ebs/latest/userguide/encryption-by-default.html)
- [Security Groupルール](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/security-group-rules.html)
- [IAMのセキュリティのベストプラクティス](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/best-practices.html)
