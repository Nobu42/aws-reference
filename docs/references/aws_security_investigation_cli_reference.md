# AWS Security Investigation CLI Reference

## このドキュメントの目的

このドキュメントは、AWSセキュリティ調査、ネットワーク影響調査、設定変更前後の確認、手順書作成で使うAWS CLIコマンドを整理したリファレンスである。

対象は、銀行系システムのように変更影響、アクセス経路、公開範囲、暗号化、監査証跡、検知結果の確認が重要になる環境を想定する。

基本方針は、まず読み取り系の `describe`、`get`、`list`、`lookup` 系コマンドで現状を確認し、変更作業の前後で同じ観点を再確認することである。

## 前提

以降の例では、AWS CLIプロファイルとリージョンを以下の前提で記載する。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
```

実行時は、必要に応じて実案件のプロファイル名、リージョン、アカウントに置き換える。

## 調査時の基本方針

### 先に確認する項目

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

確認ポイント:

- 操作対象のAWSアカウントID
- 実行主体のIAMユーザーまたはIAMロール
- 本番、検証、開発アカウントの取り違えがないこと

### 証跡として保存しやすい出力形式

人がその場で見る場合:

```bash
--output table
```

手順書や調査証跡として残す場合:

```bash
--output json
```

差分比較を行う場合は、変更前後で同じコマンドを実行し、JSONを保存して比較する。

例:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json > before_security_groups.json
```

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json > after_security_groups.json
```

## 目的別早見表

| 目的 | 主なコマンド |
| :--- | :--- |
| アカウント確認 | `aws sts get-caller-identity` |
| EC2構成確認 | `aws ec2 describe-instances` |
| EBS確認 | `aws ec2 describe-volumes` |
| AMI確認 | `aws ec2 describe-images` |
| SSH鍵確認 | `aws ec2 describe-key-pairs` |
| Security Group確認 | `aws ec2 describe-security-groups` |
| ルール単位確認 | `aws ec2 describe-security-group-rules` |
| S3バケット一覧 | `aws s3api list-buckets` |
| S3公開設定確認 | `aws s3api get-public-access-block` |
| S3ポリシー確認 | `aws s3api get-bucket-policy` |
| S3暗号化確認 | `aws s3api get-bucket-encryption` |
| RDS確認 | `aws rds describe-db-instances` |
| Aurora確認 | `aws rds describe-db-clusters` |
| Lambda確認 | `aws lambda list-functions` |
| Lambda詳細確認 | `aws lambda get-function-configuration` |
| GuardDuty検知確認 | `aws guardduty list-findings` |
| CloudTrail履歴確認 | `aws cloudtrail lookup-events` |
| IAMロール確認 | `aws iam get-role` |
| IAMポリシー確認 | `aws iam get-policy` |
| KMSキー確認 | `aws kms describe-key` |
| CloudWatch Logs確認 | `aws logs describe-log-groups` |
| AWS Config確認 | `aws configservice describe-configuration-recorders` |
| Security Hub確認 | `aws securityhub get-findings` |
| Access Analyzer確認 | `aws accessanalyzer list-findings` |

## Account / STS

### aws sts get-caller-identity

現在のAWS CLI認証情報が、どのAWSアカウント、IAMユーザー、IAMロールとして動作しているかを確認する。

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

確認ポイント:

- `Account` が想定したAWSアカウントIDか
- `Arn` が作業用IAMユーザーまたは作業用ロールか
- 作業対象外アカウントを見ていないか

## EC2

### aws ec2 describe-instances

EC2インスタンスの一覧、状態、IP、Subnet、Security Groupを確認する。

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,VpcId:VpcId,SubnetId:SubnetId,SGs:SecurityGroups[*].GroupId,IamProfile:IamInstanceProfile.Arn}' \
  --output table
```

確認ポイント:

- Public IPを持つべきでないEC2にPublic IPがないこと
- 付与Security Groupが設計どおりであること
- IAM Instance Profileが過剰権限になっていないこと
- 停止中や不要なEC2が残っていないこと

### aws ec2 describe-instance-attribute

EC2インスタンスの個別属性を確認する。

```bash
aws ec2 describe-instance-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-id <instance-id> \
  --attribute disableApiTermination \
  --output table
```

よく確認する属性:

| 属性 | 目的 |
| :--- | :--- |
| `disableApiTermination` | 誤削除防止設定 |
| `instanceType` | インスタンスタイプ |
| `userData` | UserData設定 |
| `sourceDestCheck` | NATインスタンスなどで使う送信元/宛先チェック |

`userData` には認証情報や内部情報が含まれる可能性があるため、証跡化時は取り扱いに注意する。

### aws ec2 describe-volumes

EBSボリュームの暗号化、サイズ、アタッチ先を確認する。

```bash
aws ec2 describe-volumes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size,Encrypted:Encrypted,KmsKeyId:KmsKeyId,VolumeType:VolumeType,InstanceId:Attachments[0].InstanceId,Device:Attachments[0].Device}' \
  --output table
```

確認ポイント:

- EBSが暗号化されているか
- KMSキーが設計どおりか
- 未アタッチの不要ボリュームがないか
- サイズやタイプが想定どおりか

### aws ec2 describe-snapshots

EBSスナップショットを確認する。

```bash
aws ec2 describe-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --owner-ids self \
  --query 'Snapshots[*].{SnapshotId:SnapshotId,VolumeId:VolumeId,StartTime:StartTime,State:State,Encrypted:Encrypted,KmsKeyId:KmsKeyId,Description:Description}' \
  --output table
```

確認ポイント:

- 不要なスナップショットが残っていないか
- 暗号化されているか
- 共有設定が意図どおりか

### aws ec2 describe-snapshot-attribute

スナップショットの共有属性を確認する。

```bash
aws ec2 describe-snapshot-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --snapshot-id <snapshot-id> \
  --attribute createVolumePermission \
  --output json
```

確認ポイント:

- `Group=all` でパブリック共有されていないこと
- 想定外アカウントに共有されていないこと

### aws ec2 describe-images

自アカウント所有AMIを確認する。

```bash
aws ec2 describe-images \
  --profile "$PROFILE" \
  --region "$REGION" \
  --owners self \
  --query 'Images[*].{ImageId:ImageId,Name:Name,State:State,CreationDate:CreationDate,Public:Public,RootDeviceName:RootDeviceName}' \
  --output table
```

確認ポイント:

- AMIがパブリック化されていないこと
- 古いAMIが不要に残っていないこと
- どのEC2構築に使われているか

### aws ec2 describe-key-pairs

EC2 Key Pairを確認する。

```bash
aws ec2 describe-key-pairs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'KeyPairs[*].{KeyName:KeyName,KeyPairId:KeyPairId,KeyType:KeyType,CreateTime:CreateTime}' \
  --output table
```

確認ポイント:

- 不要なKey Pairがないか
- 共有運用されているKey Pairがないか
- 鍵管理ルールに合っているか

### aws ec2 describe-tags

タグを横断的に確認する。

```bash
aws ec2 describe-tags \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters "Name=resource-type,Values=instance,volume,security-group,subnet,vpc" \
  --output table
```

確認ポイント:

- 管理対象タグが付与されているか
- システム名、環境名、所有者、コスト配賦タグが揃っているか

## ELB / ALB

### aws elbv2 describe-load-balancers

ALB/NLBの一覧、スキーム、VPC、Subnetを確認する。

```bash
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,Arn:LoadBalancerArn,Type:Type,Scheme:Scheme,VpcId:VpcId,DNSName:DNSName,State:State.Code,Subnets:AvailabilityZones[*].SubnetId}' \
  --output table
```

確認ポイント:

- internet-facingかinternalか
- 配置Subnetが設計どおりか
- 不要なLoad Balancerが残っていないか

### aws elbv2 describe-listeners

リスナーのプロトコル、ポート、証明書を確認する。

```bash
aws elbv2 describe-listeners \
  --profile "$PROFILE" \
  --region "$REGION" \
  --load-balancer-arn <load-balancer-arn> \
  --query 'Listeners[*].{ListenerArn:ListenerArn,Protocol:Protocol,Port:Port,SslPolicy:SslPolicy,Certificates:Certificates[*].CertificateArn,DefaultActions:DefaultActions[*].Type}' \
  --output table
```

確認ポイント:

- HTTPのみで公開されていないか
- HTTPSのSSL Policyが古くないか
- 証明書ARNが想定どおりか

### aws elbv2 describe-rules

ALB Listener Ruleを確認する。

```bash
aws elbv2 describe-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --listener-arn <listener-arn> \
  --output table
```

確認ポイント:

- Host HeaderやPath条件が設計どおりか
- 意図しない転送先Target Groupがないか
- 認証、リダイレクト、固定レスポンス設定が妥当か

### aws elbv2 describe-target-groups

Target Groupの設定を確認する。

```bash
aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'TargetGroups[*].{Name:TargetGroupName,Arn:TargetGroupArn,Protocol:Protocol,Port:Port,VpcId:VpcId,TargetType:TargetType,HealthCheckPath:HealthCheckPath}' \
  --output table
```

### aws elbv2 describe-target-health

Target Group配下のターゲット状態を確認する。

```bash
aws elbv2 describe-target-health \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn <target-group-arn> \
  --output table
```

確認ポイント:

- ターゲットが `healthy` か
- 片系だけ異常になっていないか
- AZ単位で偏りがないか

## S3

### aws s3api list-buckets

アカウント内のS3バケット一覧を確認する。

```bash
aws s3api list-buckets \
  --profile "$PROFILE" \
  --query 'Buckets[*].{Name:Name,CreationDate:CreationDate}' \
  --output table
```

### aws s3api get-bucket-location

バケットのリージョンを確認する。

```bash
aws s3api get-bucket-location \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

### aws s3api get-public-access-block

Public Access Blockを確認する。

```bash
aws s3api get-public-access-block \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

確認ポイント:

- `BlockPublicAcls` が `true` か
- `IgnorePublicAcls` が `true` か
- `BlockPublicPolicy` が `true` か
- `RestrictPublicBuckets` が `true` か

### aws s3api get-bucket-policy-status

バケットポリシーがパブリックと判定されているか確認する。

```bash
aws s3api get-bucket-policy-status \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

確認ポイント:

- `IsPublic` が `false` であること

### aws s3api get-bucket-policy

バケットポリシーを確認する。

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output json
```

確認ポイント:

- `Principal: "*"` が不用意に使われていないか
- `Action` が広すぎないか
- `Resource` がバケット全体に広がりすぎていないか
- VPC Endpoint条件、送信元IP条件、TLS条件が必要に応じて入っているか

### aws s3api get-bucket-acl

バケットACLを確認する。

```bash
aws s3api get-bucket-acl \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output json
```

確認ポイント:

- `AllUsers` や `AuthenticatedUsers` への許可がないこと
- ACL無効化方針の場合、運用と矛盾していないこと

### aws s3api get-bucket-ownership-controls

Object Ownership設定を確認する。

```bash
aws s3api get-bucket-ownership-controls \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

確認ポイント:

- `BucketOwnerEnforced` になっているか
- ACLを無効化する設計になっているか

### aws s3api get-bucket-encryption

S3バケットのデフォルト暗号化を確認する。

```bash
aws s3api get-bucket-encryption \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

確認ポイント:

- SSE-S3またはSSE-KMSが有効か
- KMSキーが設計どおりか

### aws s3api get-bucket-versioning

バージョニング設定を確認する。

```bash
aws s3api get-bucket-versioning \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

確認ポイント:

- 誤削除や改ざん対策として有効化が必要か
- ライフサイクル設定と整合しているか

### aws s3api get-bucket-logging

サーバーアクセスログ設定を確認する。

```bash
aws s3api get-bucket-logging \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

### aws s3api get-bucket-lifecycle-configuration

ライフサイクル設定を確認する。

```bash
aws s3api get-bucket-lifecycle-configuration \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

### aws s3api get-bucket-replication

レプリケーション設定を確認する。

```bash
aws s3api get-bucket-replication \
  --profile "$PROFILE" \
  --bucket <bucket-name> \
  --output table
```

## RDS

### aws rds describe-db-instances

RDS DBインスタンスの公開設定、暗号化、Subnet Group、Security Groupを確認する。

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[*].{DB:DBInstanceIdentifier,Engine:Engine,Class:DBInstanceClass,Endpoint:Endpoint.Address,Public:PubliclyAccessible,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,MultiAZ:MultiAZ,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcId:DBSubnetGroup.VpcId,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table
```

確認ポイント:

- `PubliclyAccessible` が意図どおりか
- Storage Encryptionが有効か
- Security GroupがDB接続元に限定されているか
- Multi-AZが要件に合っているか

### aws rds describe-db-clusters

AuroraなどのDB Clusterを確認する。

```bash
aws rds describe-db-clusters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBClusters[*].{Cluster:DBClusterIdentifier,Engine:Engine,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,MultiAZ:MultiAZ,VpcSGs:VpcSecurityGroups[*].VpcSecurityGroupId,DeletionProtection:DeletionProtection}' \
  --output table
```

### aws rds describe-db-subnet-groups

DB Subnet Groupを確認する。

```bash
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table
```

### aws rds describe-db-snapshots

DB Snapshotを確認する。

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --snapshot-type manual \
  --query 'DBSnapshots[*].{Snapshot:DBSnapshotIdentifier,DB:DBInstanceIdentifier,Status:Status,Encrypted:Encrypted,KmsKeyId:KmsKeyId,CreateTime:SnapshotCreateTime}' \
  --output table
```

### aws rds describe-db-parameter-groups

DB Parameter Groupを確認する。

```bash
aws rds describe-db-parameter-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws rds describe-db-parameters

DB Parameter Group内のパラメータを確認する。

```bash
aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name <parameter-group-name> \
  --output table
```

### aws rds describe-pending-maintenance-actions

保留中メンテナンスを確認する。

```bash
aws rds describe-pending-maintenance-actions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

## Lambda

### aws lambda list-functions

Lambda関数一覧を確認する。

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Functions[*].{FunctionName:FunctionName,Runtime:Runtime,Role:Role,Handler:Handler,LastModified:LastModified,VpcConfig:VpcConfig.VpcId}' \
  --output table
```

### aws lambda get-function-configuration

Lambda関数の詳細設定を確認する。

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name <function-name> \
  --query '{FunctionName:FunctionName,Runtime:Runtime,Role:Role,Timeout:Timeout,MemorySize:MemorySize,State:State,LastModified:LastModified,VpcConfig:VpcConfig,Environment:Environment}' \
  --output json
```

確認ポイント:

- VPC接続時のSubnetとSecurity Group
- 実行ロール
- 環境変数に秘密情報が含まれていないか
- TimeoutやMemoryが要件に合っているか

環境変数には秘密情報が含まれる可能性があるため、証跡ファイルの取り扱いに注意する。

### aws lambda get-policy

Lambdaのリソースベースポリシーを確認する。

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name <function-name> \
  --output json
```

確認ポイント:

- 想定外のPrincipalからInvoke許可がないか
- EventBridge、S3、API Gatewayなどの連携元が設計どおりか

### aws lambda list-event-source-mappings

イベントソースマッピングを確認する。

```bash
aws lambda list-event-source-mappings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name <function-name> \
  --output table
```

### aws lambda list-tags

Lambda関数のタグを確認する。

```bash
aws lambda list-tags \
  --profile "$PROFILE" \
  --region "$REGION" \
  --resource <function-arn> \
  --output table
```

## GuardDuty

### aws guardduty list-detectors

GuardDuty Detector IDを取得する。

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DetectorIds[0]' \
  --output text)
```

### aws guardduty get-detector

GuardDuty Detector設定を確認する。

```bash
aws guardduty get-detector \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

### aws guardduty list-findings

Finding IDを一覧表示する。

```bash
aws guardduty list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

### aws guardduty get-findings

Finding詳細を確認する。

```bash
aws guardduty get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-ids <finding-id> \
  --output json
```

確認ポイント:

- Finding Type
- Severity
- 対象リソース
- 通信先IP、ドメイン、ポート
- First Seen / Last Seen
- 対応済みか継続発生中か

### aws guardduty get-findings-statistics

Finding件数を重要度別に確認する。

```bash
aws guardduty get-findings-statistics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --finding-statistic-types COUNT_BY_SEVERITY \
  --output table
```

### aws guardduty list-members

Organizations連携や管理アカウント配下のメンバーを確認する。

```bash
aws guardduty list-members \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

### aws guardduty list-ip-sets / list-threat-intel-sets

許可IPリスト、脅威インテリジェンスリストを確認する。

```bash
aws guardduty list-ip-sets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

```bash
aws guardduty list-threat-intel-sets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --detector-id "$DETECTOR_ID" \
  --output table
```

## IAM

IAMはグローバルサービスであるため、通常は `--region` を指定しない。

### aws iam list-roles

IAM Role一覧を確認する。

```bash
aws iam list-roles \
  --profile "$PROFILE" \
  --query 'Roles[*].{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate,MaxSessionDuration:MaxSessionDuration}' \
  --output table
```

### aws iam get-role

IAM Roleの信頼ポリシーを確認する。

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name <role-name> \
  --output json
```

確認ポイント:

- `AssumeRolePolicyDocument` のPrincipal
- 外部アカウントからAssumeRoleできる設定がないか
- Service Principalが設計どおりか

### aws iam list-attached-role-policies

Roleにアタッチされた管理ポリシーを確認する。

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name <role-name> \
  --output table
```

### aws iam list-role-policies / get-role-policy

Roleのインラインポリシーを確認する。

```bash
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name <role-name> \
  --output table
```

```bash
aws iam get-role-policy \
  --profile "$PROFILE" \
  --role-name <role-name> \
  --policy-name <policy-name> \
  --output json
```

### aws iam get-policy / get-policy-version

管理ポリシーの内容を確認する。

```bash
aws iam get-policy \
  --profile "$PROFILE" \
  --policy-arn <policy-arn> \
  --output json
```

```bash
aws iam get-policy-version \
  --profile "$PROFILE" \
  --policy-arn <policy-arn> \
  --version-id <version-id> \
  --output json
```

確認ポイント:

- `Action: "*"` や `Resource: "*"` が過剰でないか
- 管理者権限相当が不要に付与されていないか
- 条件句で送信元、MFA、組織IDなどが制御されているか

### aws iam list-users / list-access-keys

IAM Userとアクセスキーを確認する。

```bash
aws iam list-users \
  --profile "$PROFILE" \
  --query 'Users[*].{UserName:UserName,Arn:Arn,CreateDate:CreateDate,PasswordLastUsed:PasswordLastUsed}' \
  --output table
```

```bash
aws iam list-access-keys \
  --profile "$PROFILE" \
  --user-name <user-name> \
  --output table
```

確認ポイント:

- 長期間使われていないユーザーがないか
- 不要なアクセスキーがないか
- アクセスキーのローテーション運用があるか

### aws iam generate-credential-report / get-credential-report

IAM認証情報レポートを取得する。

```bash
aws iam generate-credential-report \
  --profile "$PROFILE"
```

```bash
aws iam get-credential-report \
  --profile "$PROFILE" \
  --output text
```

出力にはユーザーの認証状態が含まれるため、証跡ファイルの管理に注意する。

## KMS

### aws kms list-keys

KMSキー一覧を確認する。

```bash
aws kms list-keys \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws kms describe-key

KMSキーの状態、用途、管理者を確認する。

```bash
aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id <key-id-or-arn> \
  --output table
```

確認ポイント:

- `Enabled` が意図どおりか
- `KeyManager` が `CUSTOMER` か `AWS` か
- `KeyUsage` が用途に合っているか
- 削除待ち状態ではないか

### aws kms get-key-policy

KMS Key Policyを確認する。

```bash
aws kms get-key-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id <key-id-or-arn> \
  --policy-name default \
  --output json
```

確認ポイント:

- キー管理者が適切か
- 利用主体が最小限か
- 外部アカウントに利用許可がないか

### aws kms list-grants

KMS Grantを確認する。

```bash
aws kms list-grants \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id <key-id-or-arn> \
  --output table
```

### aws kms get-key-rotation-status

キーローテーション設定を確認する。

```bash
aws kms get-key-rotation-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id <key-id-or-arn> \
  --output table
```

## CloudTrail

### aws cloudtrail describe-trails

CloudTrail Trailを確認する。

```bash
aws cloudtrail describe-trails \
  --profile "$PROFILE" \
  --region "$REGION" \
  --include-shadow-trails \
  --output table
```

### aws cloudtrail get-trail-status

Trailの記録状態を確認する。

```bash
aws cloudtrail get-trail-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name <trail-name-or-arn> \
  --output table
```

確認ポイント:

- `IsLogging` が `true` か
- 最新Delivery Errorがないか
- S3保存先が設計どおりか

### aws cloudtrail get-event-selectors

Trailのイベントセレクターを確認する。

```bash
aws cloudtrail get-event-selectors \
  --profile "$PROFILE" \
  --region "$REGION" \
  --trail-name <trail-name-or-arn> \
  --output json
```

確認ポイント:

- 管理イベントが記録されているか
- S3やLambdaなどのデータイベントが必要に応じて記録されているか

### aws cloudtrail lookup-events

CloudTrailイベント履歴を検索する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<resource-id> \
  --output table
```

イベント名で検索する例:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --output table
```

確認ポイント:

- 誰が変更したか
- いつ変更したか
- どのAPIが実行されたか
- どのリソースが対象か

## CloudWatch Logs

### aws logs describe-log-groups

ロググループ一覧を確認する。

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'logGroups[*].{LogGroup:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId}' \
  --output table
```

確認ポイント:

- Retentionが無期限になっていないか
- KMS暗号化が必要なログで有効か
- 不要なロググループが残っていないか

### aws logs describe-log-streams

ログストリームを確認する。

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name <log-group-name> \
  --order-by LastEventTime \
  --descending \
  --output table
```

### aws logs filter-log-events

ログイベントを検索する。

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name <log-group-name> \
  --filter-pattern "ERROR" \
  --output json
```

調査対象に個人情報や機密情報が含まれる可能性があるため、ログ出力の共有範囲に注意する。

## AWS Config

### aws configservice describe-configuration-recorders

AWS Config Recorderを確認する。

```bash
aws configservice describe-configuration-recorders \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws configservice describe-configuration-recorder-status

Config Recorderの動作状態を確認する。

```bash
aws configservice describe-configuration-recorder-status \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws configservice describe-delivery-channels

Configの配信先を確認する。

```bash
aws configservice describe-delivery-channels \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws configservice describe-config-rules

Config Ruleを確認する。

```bash
aws configservice describe-config-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws configservice describe-compliance-by-config-rule

Config Ruleの準拠状況を確認する。

```bash
aws configservice describe-compliance-by-config-rule \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

## Security Hub

### aws securityhub describe-hub

Security Hubの有効化状態を確認する。

```bash
aws securityhub describe-hub \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws securityhub get-enabled-standards

有効化されている標準を確認する。

```bash
aws securityhub get-enabled-standards \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws securityhub get-findings

Security Hub Findingsを確認する。

```bash
aws securityhub get-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters '{"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}]}' \
  --output json
```

確認ポイント:

- Severity
- Workflow Status
- Compliance Status
- 対象リソース
- 検知元サービス

## IAM Access Analyzer

### aws accessanalyzer list-analyzers

Analyzer一覧を確認する。

```bash
aws accessanalyzer list-analyzers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws accessanalyzer list-findings

外部公開や外部共有に関するFindingを確認する。

```bash
aws accessanalyzer list-findings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --analyzer-arn <analyzer-arn> \
  --output table
```

### aws accessanalyzer get-finding

Finding詳細を確認する。

```bash
aws accessanalyzer get-finding \
  --profile "$PROFILE" \
  --region "$REGION" \
  --analyzer-arn <analyzer-arn> \
  --id <finding-id> \
  --output json
```

### aws accessanalyzer validate-policy

IAMポリシーの静的検証を行う。

```bash
aws accessanalyzer validate-policy \
  --profile "$PROFILE" \
  --policy-document file://policy.json \
  --policy-type IDENTITY_POLICY \
  --output json
```

確認ポイント:

- 過剰権限の警告
- 構文エラー
- セキュリティ上の注意点

## Secrets Manager / SSM Parameter Store

### aws secretsmanager list-secrets

Secrets Managerのシークレット一覧を確認する。

```bash
aws secretsmanager list-secrets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'SecretList[*].{Name:Name,Arn:ARN,KmsKeyId:KmsKeyId,LastChangedDate:LastChangedDate,LastAccessedDate:LastAccessedDate,RotationEnabled:RotationEnabled}' \
  --output table
```

### aws secretsmanager describe-secret

シークレットのメタデータを確認する。

```bash
aws secretsmanager describe-secret \
  --profile "$PROFILE" \
  --region "$REGION" \
  --secret-id <secret-id> \
  --output table
```

### aws secretsmanager get-resource-policy

シークレットのリソースポリシーを確認する。

```bash
aws secretsmanager get-resource-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --secret-id <secret-id> \
  --output json
```

`get-secret-value` は秘密値そのものを取得するため、通常の調査証跡取得では使用しない。実行が必要な場合は、承認、目的、保存先、マスキング方針を明確にする。

### aws ssm describe-parameters

Parameter Storeのパラメータ一覧を確認する。

```bash
aws ssm describe-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Parameters[*].{Name:Name,Type:Type,KeyId:KeyId,LastModifiedDate:LastModifiedDate,Tier:Tier}' \
  --output table
```

`ssm get-parameter --with-decryption` は秘密値を取得する可能性があるため、通常の調査証跡取得では使用しない。

## ACM

### aws acm list-certificates

ACM証明書一覧を確認する。

```bash
aws acm list-certificates \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

### aws acm describe-certificate

証明書詳細を確認する。

```bash
aws acm describe-certificate \
  --profile "$PROFILE" \
  --region "$REGION" \
  --certificate-arn <certificate-arn> \
  --output json
```

確認ポイント:

- 有効期限
- 検証状態
- 関連ドメイン
- 使われているELB/CloudFrontなど

## WAF

### aws wafv2 list-web-acls

WAF Web ACL一覧を確認する。

```bash
aws wafv2 list-web-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --scope REGIONAL \
  --output table
```

CloudFront向けWAFの場合は、`--scope CLOUDFRONT` と `--region us-east-1` を使う。

### aws wafv2 get-web-acl

Web ACL詳細を確認する。

```bash
aws wafv2 get-web-acl \
  --profile "$PROFILE" \
  --region "$REGION" \
  --scope REGIONAL \
  --name <web-acl-name> \
  --id <web-acl-id> \
  --output json
```

確認ポイント:

- Managed Ruleが有効か
- IP制限やRate Based Ruleが設計どおりか
- Default Actionが意図どおりか

## 変更作業前後の基本確認セット

### 作業前

```bash
aws sts get-caller-identity --profile "$PROFILE" --output table
```

```bash
aws ec2 describe-security-groups --profile "$PROFILE" --region "$REGION" --output json > before_security_groups.json
```

```bash
aws ec2 describe-route-tables --profile "$PROFILE" --region "$REGION" --output json > before_route_tables.json
```

```bash
aws cloudtrail lookup-events --profile "$PROFILE" --region "$REGION" --max-results 50 --output json > before_cloudtrail_recent.json
```

### 作業後

```bash
aws ec2 describe-security-groups --profile "$PROFILE" --region "$REGION" --output json > after_security_groups.json
```

```bash
aws ec2 describe-route-tables --profile "$PROFILE" --region "$REGION" --output json > after_route_tables.json
```

```bash
aws cloudtrail lookup-events --profile "$PROFILE" --region "$REGION" --max-results 50 --output json > after_cloudtrail_recent.json
```

確認ポイント:

- 変更対象のみ差分が出ていること
- 変更対象外のリソースに差分がないこと
- CloudTrailに作業APIが記録されていること
- GuardDutyやSecurity Hubに新規の重大Findingが出ていないこと
- アプリケーションログやCloudWatch Alarmに異常がないこと

## 取り扱い注意コマンド

以下は秘密情報や機微情報を取得する可能性があるため、通常の証跡取得には含めない。

| コマンド | 注意点 |
| :--- | :--- |
| `aws secretsmanager get-secret-value` | シークレット値を取得する |
| `aws ssm get-parameter --with-decryption` | SecureStringの復号値を取得する |
| `aws lambda get-function-configuration` | 環境変数に秘密情報が含まれる可能性がある |
| `aws ec2 describe-instance-attribute --attribute userData` | UserDataに秘密情報が含まれる可能性がある |
| `aws logs filter-log-events` | ログに個人情報や業務データが含まれる可能性がある |

実行する場合は、取得目的、承認、保存先、マスキング方針、削除方針を明確にする。
