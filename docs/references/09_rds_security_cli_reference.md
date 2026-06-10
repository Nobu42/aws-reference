# 09 RDS Security CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、Amazon RDSのセキュリティ設定と運用保護設定をAWS CLIで確認し、影響調査、設定変更、変更後確認、証跡取得、切り戻しを行うためのリファレンスである。

対象は、銀行系システムのように、既存AWS環境に対してセキュリティ改善やネットワーク最適化を行う現場を想定する。

このドキュメントでは、主に以下を扱う。

- Public設定確認
- DB Subnet Group確認
- Security Group確認
- 暗号化確認
- KMS Key確認
- Parameter Group確認
- ログ設定確認
- CloudWatch Logs連携確認
- RDSログファイル確認
- バックアップ設定確認
- Snapshot確認
- Deletion Protection確認
- CloudTrailによる変更履歴確認
- 変更前後の証跡取得
- 切り戻し手順
- Teams報告例

関連リファレンス:

```text
00_common_aws_cli_reference.md
07_vpc_network_cli_reference.md
08_ec2_security_cli_reference.md
```

## 2. RDSセキュリティ確認で見る順番

RDSのセキュリティ調査では、以下の順番で見ると整理しやすい。

```text
RDS DB Instance
  ↓
Public Access
  PubliclyAccessible / DB Subnet Group / Route / DNS
  ↓
Network Control
  VPC Security Group / NACL / Route Table
  ↓
Encryption
  StorageEncrypted / KmsKeyId / Snapshot encryption
  ↓
Configuration
  DB Parameter Group / Option Group
  ↓
Logging
  EnabledCloudwatchLogsExports / DB log files / CloudWatch Logs
  ↓
Backup
  BackupRetentionPeriod / BackupWindow / Snapshots / DeletionProtection
  ↓
Audit Trail
  CloudTrail / 作業証跡 / Console screenshot
```

確認観点:

| 観点 | 確認内容 |
| :--- | :--- |
| Public | `PubliclyAccessible=false` か |
| Network | Private Subnetに配置されているか |
| SG | Web/アプリSGからDBポートのみ許可か |
| Encryption | `StorageEncrypted=true` か |
| KMS | 想定KMS Keyか |
| Parameter | セキュリティ・ログ関連パラメータが妥当か |
| Logs | DBログが取得できるか、CloudWatch Logsへ出しているか |
| Backup | 自動バックアップが有効か |
| Snapshot | Snapshotが暗号化されているか、Public共有されていないか |
| Deletion Protection | 削除保護が必要な環境で有効か |

重要:

```text
RDSの公開設定は PubliclyAccessible だけで判断しない。
DB Subnet Group、Security Group、Route Table、DNS、NACLも合わせて確認する。
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

DB_INSTANCE_IDENTIFIER="sample-db"

echo "Account: $ACCOUNT_ID"
echo "Region : $REGION"
echo "DB     : $DB_INSTANCE_IDENTIFIER"
```

### 3.2 証跡ディレクトリ

```bash
WORK_NAME="rds_security_check"
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
| 1 | DB Instance | 対象DBを識別できる | `describe-db-instances` |
| 2 | Public設定 | `PubliclyAccessible=false` | `describe-db-instances` |
| 3 | DB Subnet Group | Private Subnetのみ | `describe-db-subnet-groups` |
| 4 | Security Group | Web SGからDB Portのみ許可 | `describe-security-group-rules` |
| 5 | 暗号化 | `StorageEncrypted=true` | `describe-db-instances` |
| 6 | KMS Key | 想定KMS Key | `describe-db-instances`、`kms describe-key` |
| 7 | Parameter Group | `in-sync`、差分把握 | `describe-db-parameters` |
| 8 | Logs Export | 必要ログが有効 | `describe-db-instances` |
| 9 | DB Log Files | エラー/スローログ確認 | `describe-db-log-files` |
| 10 | Backup | Retention > 0 | `describe-db-instances` |
| 11 | Snapshot | 暗号化、Public共有なし | `describe-db-snapshots` |
| 12 | Deletion Protection | 本番相当では有効 | `describe-db-instances` |
| 13 | CloudTrail | 変更履歴確認 | `lookup-events` |

## 5. RDS DB Instance確認

### 5.1 DB Instance一覧

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,BackupRetention:BackupRetentionPeriod,DeletionProtection:DeletionProtection,MultiAZ:MultiAZ,Endpoint:Endpoint.Address,Port:Endpoint.Port}' \
  --output table
```

証跡保存:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/01_describe_db_instances.json"
```

確認ポイント:

- 対象DB Instanceを識別できる
- `DBInstanceStatus=available`
- `PubliclyAccessible=false`
- `StorageEncrypted=true`
- `BackupRetentionPeriod` が0ではない
- `DeletionProtection` が環境方針どおり
- Engine / EngineVersionがサポート方針どおり

### 5.2 対象DB Instance詳細

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,Endpoint:Endpoint,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,BackupRetentionPeriod:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow,DeletionProtection:DeletionProtection,MultiAZ:MultiAZ,DBSubnetGroup:DBSubnetGroup,VpcSecurityGroups:VpcSecurityGroups,DBParameterGroups:DBParameterGroups,OptionGroupMemberships:OptionGroupMemberships,EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports,PendingModifiedValues:PendingModifiedValues}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_instance_${DB_INSTANCE_IDENTIFIER}.json"
```

### 5.3 RDS基本サマリ

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,BackupRetentionPeriod:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow,DeletionProtection:DeletionProtection,EnabledLogs:EnabledCloudwatchLogsExports}' \
  --output table
```

## 6. Public設定確認

### 6.1 PubliclyAccessible確認

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,PubliclyAccessible:PubliclyAccessible,Endpoint:Endpoint.Address,Port:Endpoint.Port,DBSubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcId:DBSubnetGroup.VpcId}' \
  --output table
```

期待値:

```text
PubliclyAccessible = False
```

注意:

- `PubliclyAccessible=true` の場合、DB EndpointがVPC外から名前解決されたときにPublic IPへ解決される可能性がある
- ただし、実際に接続できるかはSecurity GroupやNACLにも依存する
- 銀行系/社内系DBでは原則 `false` を期待する

### 6.2 PubliclyAccessible=true のRDS抽出

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[?PubliclyAccessible==`true`].{ID:DBInstanceIdentifier,Engine:Engine,Endpoint:Endpoint.Address,Port:Endpoint.Port,VpcId:DBSubnetGroup.VpcId,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table
```

結果が出た場合:

- 対象DBの業務用途を確認する
- Security Groupが全公開でないか確認する
- Public設定が要件どおりか確認する
- Private化する場合、接続元やDNS影響を確認する

### 6.3 PubliclyAccessibleを無効化する変更例

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --no-publicly-accessible \
  --apply-immediately
```

変更後確認:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,PendingModifiedValues:PendingModifiedValues}' \
  --output table
```

注意:

- 接続元がVPC外にある場合、接続できなくなる可能性がある
- DNS解決結果が変わる可能性がある
- 作業前にアプリ、運用端末、バッチ、監視の接続元を確認する
- `--apply-immediately` は即時反映のため、本番では作業時間帯と承認が必要

### 6.4 切り戻し候補

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --publicly-accessible \
  --apply-immediately
```

注意:

- Public化はセキュリティリスクが高いため、緊急切り戻しでも承認を取る
- 併せてSecurity Groupで接続元を限定する
- 恒久対応としてVPN、Direct Connect、踏み台、PrivateLinkなどを検討する

## 7. DB Subnet Group確認

### 7.1 DB Subnet Group名取得

```bash
DB_SUBNET_GROUP_NAME=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' \
  --output text)

echo "$DB_SUBNET_GROUP_NAME"
```

### 7.2 DB Subnet Group詳細

```bash
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus,Subnets:Subnets[*].{SubnetId:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name,Status:SubnetStatus}}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_subnet_group_${DB_SUBNET_GROUP_NAME}.json"
```

表形式:

```bash
aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[*].Subnets[*].{SubnetId:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name,Status:SubnetStatus}' \
  --output table
```

確認ポイント:

- Private Subnetのみ含まれているか
- 複数AZのSubnetが含まれているか
- VPC IDが対象VPCと一致するか
- SubnetGroupStatusがCompleteか

### 7.3 Subnet側の属性確認

```bash
SUBNET_IDS=$(aws rds describe-db-subnet-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --query 'DBSubnetGroups[0].Subnets[*].SubnetIdentifier' \
  --output text)

aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids $SUBNET_IDS \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`]|[0].Value,SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,Cidr:CidrBlock,MapPublicIp:MapPublicIpOnLaunch,Type:Tags[?Key==`Type`]|[0].Value}' \
  --output table
```

確認ポイント:

- `MapPublicIpOnLaunch=false`
- Route TableがPrivate用か
- タグでPrivate Subnetと識別できるか

## 8. Security Group確認

### 8.1 RDSに関連付くSecurity Group ID取得

```bash
DB_SG_IDS=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
  --output text)

echo "$DB_SG_IDS"
```

### 8.2 Security Group詳細

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $DB_SG_IDS \
  --query 'SecurityGroups[*].{Name:GroupName,GroupId:GroupId,VpcId:VpcId,Description:Description,Inbound:IpPermissions,Outbound:IpPermissionsEgress,Tags:Tags}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_security_groups.json"
```

### 8.3 Security Group Rule単位で確認

```bash
for SG_ID in $DB_SG_IDS; do
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
for SG_ID in $DB_SG_IDS; do
  aws ec2 describe-security-group-rules \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=group-id,Values="$SG_ID" \
    --output json \
    > "$EVIDENCE_DIR/investigation/db_security_group_rules_${SG_ID}.json"
done
```

確認ポイント:

- InboundはWeb/Application SGからDB Portのみ許可か
- 0.0.0.0/0 や ::/0 からDB Portが許可されていないか
- MySQLなら3306、PostgreSQLなら5432など必要ポートのみか
- SourceがCIDRではなくSecurity Groupで指定されているか
- Rule Descriptionがあるか

### 8.4 危険なDBポート公開確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?((FromPort==`3306` || FromPort==`5432` || FromPort==`1433` || FromPort==`1521`) && (CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`))].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,Description:Description}' \
  --output table
```

結果が出た場合:

- 優先度高めで要確認
- 本当に外部公開が必要か確認
- 接続元CIDRを限定できるか確認
- 可能であればSecurity Group参照へ変更する

### 8.5 RDS SG変更時の影響

| 変更内容 | 主な影響 |
| :--- | :--- |
| Inbound削除 | アプリ、バッチ、運用端末からDB接続不可 |
| Inbound追加 | 不要な接続経路が増える |
| Source変更 | Web/Appサーバーから接続不可になる可能性 |
| Port変更 | アプリのDB接続設定と不一致になる |
| SG差し替え | 既存通信がまとめて影響を受ける |

変更前に確認すること:

- アプリケーションの接続元SG
- バッチ/Lambda/運用端末の接続元
- DB Port
- NACL、Route、Private DNS
- RDS Endpointが変わらないか
- 切り戻し用の旧SG Rule

## 9. 暗号化確認

### 9.1 RDS StorageEncrypted確認

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId,StorageType:StorageType,AllocatedStorage:AllocatedStorage}' \
  --output table
```

期待値:

```text
StorageEncrypted = True
KmsKeyId = 想定KMS Key
```

### 9.2 未暗号化RDS抽出

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[?StorageEncrypted==`false`].{ID:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,BackupRetention:BackupRetentionPeriod}' \
  --output table
```

結果が出た場合:

- 暗号化対応の対象候補
- 既存DBをその場で暗号化できるとは限らない
- Snapshotコピー、暗号化Snapshot、Restore、切替などの移行計画が必要
- 停止時間、DNS切替、アプリ接続情報、バックアップ方針を確認する

### 9.3 KMS Key確認

```bash
KMS_KEY_ID=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].KmsKeyId' \
  --output text)

echo "$KMS_KEY_ID"

aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/rds_kms_key.json"
```

確認ポイント:

- KeyがEnabledか
- AWS管理キーか、カスタマー管理キーか
- Key Policyで必要な管理者/利用者が許可されているか
- Snapshotコピーやクロスアカウント復旧で問題にならないか

### 9.4 Snapshot暗号化確認

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,Type:SnapshotType,Status:Status,Encrypted:Encrypted,KmsKeyId:KmsKeyId,SnapshotCreateTime:SnapshotCreateTime,Engine:Engine}' \
  --output table
```

証跡保存:

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_snapshots_${DB_INSTANCE_IDENTIFIER}.json"
```

確認ポイント:

- Snapshotが暗号化されているか
- Manual SnapshotがPublic共有されていないか
- 古いSnapshotが残りすぎていないか
- 復旧要件に必要なSnapshotがあるか

## 10. Parameter Group確認

### 10.1 関連Parameter Group取得

```bash
DB_PARAMETER_GROUP_NAME=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' \
  --output text)

echo "$DB_PARAMETER_GROUP_NAME"
```

### 10.2 Parameter Group適用状態

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBParameterGroups[*].{Name:DBParameterGroupName,Status:ParameterApplyStatus}' \
  --output table
```

確認ポイント:

- `in-sync`
- `pending-reboot` の場合、再起動が必要
- `failed-to-apply` がないか

### 10.3 Parameter Group詳細

```bash
aws rds describe-db-parameter-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_parameter_group_${DB_PARAMETER_GROUP_NAME}.json"
```

### 10.4 変更済みパラメータ確認

```bash
aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --source user \
  --query 'Parameters[*].{Name:ParameterName,Value:ParameterValue,ApplyType:ApplyType,ApplyMethod:ApplyMethod,IsModifiable:IsModifiable,Source:Source}' \
  --output table
```

証跡保存:

```bash
aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --source user \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_parameters_user_${DB_PARAMETER_GROUP_NAME}.json"
```

確認ポイント:

- デフォルトから変更されたパラメータを把握する
- セキュリティ/ログ/監査に関係する値を確認する
- Static parameterは再起動が必要になる
- ApplyMethodが `pending-reboot` か `immediate` か確認する

### 10.5 MySQL系で確認しやすいログ関連パラメータ例

```bash
aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --query 'Parameters[?contains(`general_log slow_query_log long_query_time log_output log_error_verbosity`, ParameterName)].{Name:ParameterName,Value:ParameterValue,Source:Source,ApplyType:ApplyType,ApplyMethod:ApplyMethod}' \
  --output table
```

確認例:

| Parameter | 見るポイント |
| :--- | :--- |
| `slow_query_log` | スロークエリログ取得方針 |
| `long_query_time` | スロークエリ判定秒数 |
| `general_log` | 通常は常時有効にしないことが多い |
| `log_output` | FILE / TABLE |

### 10.6 PostgreSQL系で確認しやすいログ関連パラメータ例

```bash
aws rds describe-db-parameters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --query 'Parameters[?contains(`log_statement log_min_duration_statement log_connections log_disconnections rds.force_ssl`, ParameterName)].{Name:ParameterName,Value:ParameterValue,Source:Source,ApplyType:ApplyType,ApplyMethod:ApplyMethod}' \
  --output table
```

確認例:

| Parameter | 見るポイント |
| :--- | :--- |
| `log_statement` | SQLログ出力範囲 |
| `log_min_duration_statement` | 遅いSQLの記録しきい値 |
| `log_connections` | 接続ログ |
| `log_disconnections` | 切断ログ |
| `rds.force_ssl` | SSL接続強制 |

### 10.7 Parameter変更例

例: MySQLのスロークエリログを有効化する。

```bash
aws rds modify-db-parameter-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --parameters "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
               "ParameterName=long_query_time,ParameterValue=1,ApplyMethod=immediate"
```

注意:

- EngineやVersionによりParameter名や値が異なる
- Static parameterは再起動が必要
- ログ量が増えるとストレージやCloudWatch Logsコストに影響する
- 本番では変更前後の負荷影響を確認する

### 10.8 Parameter変更の切り戻し

変更前の値に戻す。

```bash
aws rds modify-db-parameter-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --parameters "ParameterName=slow_query_log,ParameterValue=0,ApplyMethod=immediate"
```

またはデフォルトへリセットする。

```bash
aws rds reset-db-parameter-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" \
  --parameters "ParameterName=slow_query_log,ApplyMethod=immediate"
```

## 11. ログ確認

### 11.1 CloudWatch Logs Export設定確認

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports,PendingCloudwatchLogsExports:PendingCloudwatchLogsExports}' \
  --output table
```

証跡保存:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports,PendingCloudwatchLogsExports:PendingCloudwatchLogsExports}' \
  --output json \
  > "$EVIDENCE_DIR/before/02_cloudwatch_logs_exports.json"
```

確認ポイント:

- MySQLなら `error`、`general`、`slowquery` など
- PostgreSQLなら `postgresql`、`upgrade` など
- 必要なログがCloudWatch Logsへ出ているか
- ログ量とコストを考慮しているか

### 11.2 CloudWatch Logs Export有効化例

例: MySQLのerror/slowqueryログをCloudWatch Logsへ出す。

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --cloudwatch-logs-export-configuration '{"EnableLogTypes":["error","slowquery"]}' \
  --apply-immediately
```

変更後確認:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{EnabledCloudwatchLogsExports:EnabledCloudwatchLogsExports,PendingCloudwatchLogsExports:PendingCloudwatchLogsExports}' \
  --output table
```

注意:

- Engineごとに指定可能なLogTypeが異なる
- Parameter側でログ出力を有効化しないと、CloudWatch Logs Exportだけでは期待ログが出ない場合がある
- ログ量増加によりCloudWatch Logsコストが増える

### 11.3 CloudWatch Logs Export無効化例

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --cloudwatch-logs-export-configuration '{"DisableLogTypes":["slowquery"]}' \
  --apply-immediately
```

注意:

- 無効化すると調査能力が下がる
- 監査要件に反しないか確認する
- 代替ログ保存先があるか確認する

### 11.4 RDSログファイル一覧

```bash
aws rds describe-db-log-files \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DescribeDBLogFiles[*].{LogFileName:LogFileName,LastWritten:LastWritten,Size:Size}' \
  --output table
```

証跡保存:

```bash
aws rds describe-db-log-files \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --output json \
  > "$EVIDENCE_DIR/investigation/db_log_files_${DB_INSTANCE_IDENTIFIER}.json"
```

### 11.5 RDSログファイル取得

```bash
LOG_FILE_NAME="<log-file-name>"

aws rds download-db-log-file-portion \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --log-file-name "$LOG_FILE_NAME" \
  --output text \
  > "$EVIDENCE_DIR/investigation/rds_log_${DB_INSTANCE_IDENTIFIER}.txt"
```

注意:

- DBログにはSQL、ユーザー名、接続元、エラー内容などが含まれる可能性がある
- 個人情報や機密情報が含まれる場合、証跡提出前にマスク要否を確認する
- 大きいログは分割取得やCloudWatch Logs Insightsを検討する

### 11.6 CloudWatch Logs側の確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/rds/instance/${DB_INSTANCE_IDENTIFIER}" \
  --query 'logGroups[*].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes}' \
  --output table
```

確認ポイント:

- Log Groupが作成されているか
- Retentionが無期限になっていないか
- StoredBytesが急増していないか

## 12. バックアップ確認

### 12.1 BackupRetentionPeriod確認

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,BackupRetentionPeriod:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow,LatestRestorableTime:LatestRestorableTime,CopyTagsToSnapshot:CopyTagsToSnapshot,DeletionProtection:DeletionProtection}' \
  --output table
```

期待値例:

```text
BackupRetentionPeriod > 0
PreferredBackupWindow = 運用時間外
CopyTagsToSnapshot = True
DeletionProtection = True
```

### 12.2 自動バックアップ無効のRDS抽出

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[?BackupRetentionPeriod==`0`].{ID:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,DeletionProtection:DeletionProtection}' \
  --output table
```

結果が出た場合:

- 本番/準本番であれば要確認
- 復旧要件、RPO、RTOを確認する
- AWS Backupで別管理しているか確認する

### 12.3 自動バックアップ有効化例

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --backup-retention-period 7 \
  --preferred-backup-window "18:00-18:30" \
  --copy-tags-to-snapshot \
  --apply-immediately
```

注意:

- バックアップウィンドウはUTC指定
- 例の `18:00-18:30` UTC はJSTでは翌03:00-03:30
- 初回バックアップや設定変更時に負荷やI/O影響が出る場合がある
- 本番では業務時間外、監視強化、関係者連絡を行う

### 12.4 自動バックアップ切り戻し例

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --backup-retention-period 0 \
  --apply-immediately
```

注意:

- 自動バックアップ無効化は復旧能力を下げるため、原則推奨しない
- 本番では承認なしに実施しない
- AWS Backupなど代替保護があるか確認する

### 12.5 Manual Snapshot作成

設定変更前に手動Snapshotを作成する例。

```bash
SNAPSHOT_ID="${DB_INSTANCE_IDENTIFIER}-before-change-$(date +%Y%m%d%H%M%S)"

aws rds create-db-snapshot \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --db-snapshot-identifier "$SNAPSHOT_ID"
```

Snapshot作成完了待ち:

```bash
aws rds wait db-snapshot-completed \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-snapshot-identifier "$SNAPSHOT_ID"
```

確認:

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,Status:Status,Encrypted:Encrypted,KmsKeyId:KmsKeyId,SnapshotCreateTime:SnapshotCreateTime}' \
  --output table
```

注意:

- Snapshot作成は時間がかかる
- ストレージコストが発生する
- 個人情報や機密情報を含むDBのSnapshot管理は厳格に行う

### 12.6 Public Snapshot確認

```bash
aws rds describe-db-snapshots \
  --profile "$PROFILE" \
  --region "$REGION" \
  --snapshot-type public \
  --include-public \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,DBInstance:DBInstanceIdentifier,Engine:Engine,Encrypted:Encrypted,SnapshotCreateTime:SnapshotCreateTime}' \
  --output table
```

Manual Snapshotの共有属性を確認する:

```bash
SNAPSHOT_ID="<manual-db-snapshot-id>"

aws rds describe-db-snapshot-attributes \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==`restore`].AttributeValues[]' \
  --output table
```

期待値:

```text
all が含まれないこと
不要なAWSアカウントIDが含まれないこと
```

Public共有を解除する例:

```bash
aws rds modify-db-snapshot-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --attribute-name restore \
  --values-to-remove all
```

注意:

- 自アカウントが公開しているSnapshotの確認にはSnapshot属性確認も組み合わせる
- Public共有は重大な情報漏えいリスクになる
- 本番データを含むSnapshotはPublicにしない

## 13. Deletion Protection確認

### 13.1 削除保護確認

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].{ID:DBInstanceIdentifier,DeletionProtection:DeletionProtection,DeleteAutomatedBackups:DeleteAutomatedBackups}' \
  --output table
```

期待値:

```text
本番相当: DeletionProtection = True
検証環境: 運用方針に従う
```

### 13.2 削除保護有効化

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --deletion-protection \
  --apply-immediately
```

### 13.3 削除保護無効化

```bash
aws rds modify-db-instance \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --no-deletion-protection \
  --apply-immediately
```

注意:

- 本番では削除保護無効化は削除作業前だけに限定する
- 承認、作業記録、CloudTrail証跡を残す

## 14. CloudTrailでRDS変更履歴を確認する

### 14.1 RDS設定変更

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifyDBInstance \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_modify_db_instance.json"
```

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| DB作成 | `CreateDBInstance` |
| DB変更 | `ModifyDBInstance` |
| DB再起動 | `RebootDBInstance` |
| DB削除 | `DeleteDBInstance` |
| Snapshot作成 | `CreateDBSnapshot` |
| Snapshotコピー | `CopyDBSnapshot` |
| Snapshot復元 | `RestoreDBInstanceFromDBSnapshot` |
| Parameter Group変更 | `ModifyDBParameterGroup` |
| Parameter Groupリセット | `ResetDBParameterGroup` |
| SG変更 | `AuthorizeSecurityGroupIngress` / `RevokeSecurityGroupIngress` |

### 14.2 Parameter Group変更履歴

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ModifyDBParameterGroup \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_modify_db_parameter_group.json"
```

### 14.3 Snapshot関連履歴

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateDBSnapshot \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_create_db_snapshot.json"
```

確認ポイント:

- 誰が変更したか
- いつ変更したか
- 変更元IPやUserAgent
- 変更対象DB
- 承認済み作業か

## 15. 変更前後に保存する証跡

| タイミング | 証跡 | ファイル例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `00_caller_identity.json` |
| 変更前 | DB Instance一覧 | `01_describe_db_instances.json` |
| 変更前 | CloudWatch Logs Export | `02_cloudwatch_logs_exports.json` |
| 調査 | DB Instance詳細 | `db_instance_<db-id>.json` |
| 調査 | DB Subnet Group | `db_subnet_group_<name>.json` |
| 調査 | Security Group | `db_security_groups.json` |
| 調査 | Security Group Rule | `db_security_group_rules_<sg-id>.json` |
| 調査 | KMS Key | `rds_kms_key.json` |
| 調査 | DB Parameter Group | `db_parameter_group_<name>.json` |
| 調査 | User変更Parameter | `db_parameters_user_<name>.json` |
| 調査 | RDS Log Files | `db_log_files_<db-id>.json` |
| 調査 | RDS Log | `rds_log_<db-id>.txt` |
| 調査 | Snapshots | `db_snapshots_<db-id>.json` |
| 調査 | CloudTrail | `cloudtrail_*.json` |
| 変更後 | DB Instance再確認 | `after/db_instance_<db-id>.json` |
| 画面 | AWS Console | RDS詳細、Connectivity、Security、Logs、Backups、Parameter Group |

## 16. 変更時の影響範囲

| 変更対象 | 主な影響 |
| :--- | :--- |
| PubliclyAccessible | VPC外からの接続、DNS解決、運用接続 |
| Security Group | アプリ、バッチ、運用端末からDB接続 |
| DB Subnet Group | DB配置、AZ、ネットワーク到達性 |
| Parameter Group | DB動作、ログ量、接続、性能、再起動要否 |
| CloudWatch Logs Export | ログ保存、調査能力、CloudWatch Logsコスト |
| Backup Retention | 復旧可能期間、ストレージコスト |
| Deletion Protection | 削除運用 |
| KMS Key | 起動、Snapshot、復元、クロスアカウント共有 |
| Snapshot | 復旧能力、情報漏えいリスク、コスト |

変更前に確認すること:

- 対象DBの業務重要度
- 接続元アプリ/バッチ/運用端末
- DB Port
- 作業時間帯
- 再起動要否
- バックアップ取得要否
- 切り戻し方法
- 変更前JSON証跡

## 17. よくあるトラブルと確認ポイント

### 17.1 PubliclyAccessibleをfalseにしたら接続できない

確認ポイント:

- 接続元がVPC内か
- VPN / Direct Connect / Bastion / SSM経由か
- DNS解決先が変わっていないか
- Security Groupが接続元を許可しているか
- Route/NACLが双方向通信を許可しているか

### 17.2 SG変更後にアプリからDB接続できない

確認ポイント:

- RDS SG inboundでWeb/App SGからDB Portを許可しているか
- Web/App SG outboundが許可されているか
- 接続元がEC2以外の場合、正しいSG/CIDRか
- RDS Endpoint/Portが変わっていないか
- アプリ側のDB接続情報が正しいか

### 17.3 Parameter変更後に反映されない

確認ポイント:

- ParameterApplyStatusが `pending-reboot` ではないか
- Static parameterではないか
- DB再起動が必要か
- 変更対象のParameter GroupがDBに関連付いているか
- Auroraの場合、Cluster Parameter GroupとDB Parameter Groupのどちらか

### 17.4 ログがCloudWatch Logsへ出ない

確認ポイント:

- `EnabledCloudwatchLogsExports` に対象ログが含まれるか
- Parameter Groupでログ出力が有効か
- Engineが対象ログタイプをサポートしているか
- Log Groupが作成されているか
- ログ出力量が少なく、まだイベントが出ていないだけではないか

### 17.5 バックアップが取得されない

確認ポイント:

- `BackupRetentionPeriod` が0ではないか
- AWS Backupで別管理していないか
- DB Instanceの状態がavailableか
- PreferredBackupWindowが設定されているか
- 最新復元可能時刻 `LatestRestorableTime` が更新されているか

### 17.6 暗号化対応で悩む

確認ポイント:

- 既存DBをその場で暗号化できる変更か
- Snapshotコピー/復元が必要か
- 停止時間が必要か
- KMS Key Policy/IAM権限が足りているか
- アプリ接続先の切替方法
- DNS名、CNAME、Route 53 Private DNSの利用有無

## 18. 作業手順書に書く項目

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | Public無効化、SG変更、ログ有効化、Backup有効化など |
| 対象 | Account、Region、DB Instance、VPC、SG、Parameter Group |
| 変更前確認 | DB設定、Public、SG、暗号化、Parameter、Logs、Backup |
| 影響範囲 | アプリ、バッチ、運用端末、監視、復旧要件 |
| 変更内容 | CLIまたはConsole操作 |
| 変更後確認 | 設定値、接続確認、ログ、Backup、CloudTrail |
| 切り戻し | 旧設定へ戻すコマンド |
| 証跡 | CLI JSON、Console screenshot、ログ、CloudTrail |
| 報告 | 作業結果、確認結果、残課題 |

## 19. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

Region:
  <region>

対象RDS:
  <db-instance-identifier>

基本情報:
  Engine:
  EngineVersion:
  Status:
  Endpoint:
  Port:

Public設定:
  PubliclyAccessible:
  DB Subnet Group:
  VPC:
  評価:

Security Group:
  Group ID:
  Inbound:
  Source:
  評価:

暗号化:
  StorageEncrypted:
  KmsKeyId:
  SnapshotEncrypted:
  評価:

Parameter Group:
  Name:
  ApplyStatus:
  User Modified Parameters:
  評価:

ログ:
  EnabledCloudwatchLogsExports:
  DB Log Files:
  CloudWatch Logs:
  評価:

バックアップ:
  BackupRetentionPeriod:
  PreferredBackupWindow:
  LatestRestorableTime:
  DeletionProtection:
  評価:

CloudTrail:
  変更履歴あり / なし / 未確認

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 20. Teams報告例

### 20.1 RDSセキュリティ確認完了

```text
RDSセキュリティ設定の確認を実施しました。
対象は <db-instance-identifier> です。

確認項目:
- PubliclyAccessible
- DB Subnet Group
- Security Group
- Storage Encryption / KMS
- Parameter Group
- Logs / CloudWatch Logs Export
- Backup / Snapshot / Deletion Protection
- CloudTrail変更履歴

現時点の判定は <問題なし / 要確認 / 要改善> です。
証跡は所定フォルダへ格納済みです。
```

### 20.2 Security Group変更前連絡

```text
<db-instance-identifier> のRDS Security Group変更を実施予定です。
変更内容は <source> から <db-port> への許可 <追加/削除/変更> です。

変更前に接続元、既存SG Rule、アプリ影響、切り戻し手順を確認済みです。
変更後はアプリDB接続確認、SG Rule確認、CloudTrail確認を実施します。
```

### 20.3 ログ有効化後報告

```text
RDSログ設定変更が完了しました。

対象:
- DB: <db-instance-identifier>
- 有効化ログ: <error/slowquery/postgresql など>

変更後確認:
- EnabledCloudwatchLogsExports: 想定どおり
- DB Log Files: 確認済み
- CloudWatch Logs: Log Group確認済み
- CloudTrail: ModifyDBInstance確認済み

ログ量とコストは継続確認します。
```

## 21. 案件で説明できるポイント

このRDSセキュリティ確認は、案件では次のように説明できる。

```text
RDSでは、PubliclyAccessibleだけでなく、DB Subnet Group、Security Group、
暗号化、Parameter Group、ログ、バックアップ、Deletion Protectionをまとめて確認します。

変更前には describe-db-instances、describe-security-group-rules、
describe-db-parameters、describe-db-log-files、describe-db-snapshots などで証跡を取得し、
変更後に同じ観点で再確認します。

Parameter Groupやログ設定は再起動要否やログ量増加の影響があるため、
変更前に影響範囲、作業時間帯、切り戻し手順を明確にします。
```

## 22. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| PubliclyAccessible | Public/Private配置、DNS、SGとの関係 |
| DB Subnet Group | 複数AZ、Private Subnet |
| Security Group | Web/App SGからDB Portのみ許可 |
| Encryption | StorageEncrypted、KMS Key |
| Snapshot | Manual/Automated、暗号化、Public共有 |
| Parameter Group | Dynamic/Static、pending-reboot |
| Logs | CloudWatch Logs Export、Engine別ログ |
| Backup | Retention、Backup Window、PITR |
| Deletion Protection | 誤削除防止 |
| CloudTrail | RDS変更イベント追跡 |

## 23. 公式ドキュメント

- [VPC内のDB Instanceを操作する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Amazon RDSリソースを暗号化する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/Overview.Encryption.html)
- [DB Parameter Groupを操作する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html)
- [Amazon RDSログファイルを監視する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_LogAccess.html)
- [自動バックアップを操作する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html)
- [DB Snapshotを作成する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_CreateSnapshot.html)
- [DB Instanceを削除する](https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/USER_DeleteInstance.html)
