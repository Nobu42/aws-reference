# 10 Lambda Security CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、AWS Lambdaのセキュリティ設定をAWS CLIで確認し、影響調査、設定変更、変更後確認、証跡取得、切り戻しを行うためのリファレンスである。

対象は、銀行系システムのように、既存AWS環境に対してセキュリティ改善やネットワーク最適化を行う現場を想定する。

このドキュメントでは、主に以下を扱う。

- Lambda Functionの基本設定確認
- IAM Execution Role確認
- Resource-based policy確認
- VPC接続設定確認
- Security Group / Subnet確認
- 環境変数確認
- KMS暗号化確認
- CloudWatch Logs確認
- Function URL確認
- Function URLの公開リスク確認
- CloudTrailによる変更履歴確認
- 変更前後の証跡取得
- 切り戻し手順
- Teams報告例

関連リファレンス:

```text
00_common_aws_cli_reference.md
03_cloudtrail_cli_reference.md
04_cloudwatch_cli_reference.md
07_vpc_network_cli_reference.md
08_ec2_security_cli_reference.md
```

## 2. Lambdaセキュリティ確認で見る順番

Lambdaのセキュリティ調査では、以下の順番で見ると整理しやすい。

```text
Lambda Function
  ↓
Execution Role
  IAM Role / Trust Policy / Attached Policy / Inline Policy
  ↓
Resource-based Policy
  add-permission / Principal / SourceArn / Function URL権限
  ↓
Network
  VPC設定 / Subnet / Security Group / VPC Endpoint / NAT Gateway
  ↓
Environment Variables
  環境変数キー / 秘密情報混入 / KMS Key
  ↓
Encryption
  KMSKeyArn / Customer managed key / IAM permission
  ↓
Logs
  CloudWatch Logs / Log Group / Retention / Error検索
  ↓
Function URL
  AuthType / CORS / Resource policy / Public access
  ↓
Audit Trail
  CloudTrail / 作業証跡 / Console screenshot
```

確認観点:

| 観点 | 確認内容 |
| :--- | :--- |
| Function | 対象Functionを識別できるか |
| IAM Role | 最小権限に近いか、信頼ポリシーがLambda用か |
| Resource Policy | 不要な外部アカウント、`Principal=*` がないか |
| VPC | Private Subnet接続、SG、外部通信経路が妥当か |
| Environment | 秘密情報が環境変数に平文で入っていないか |
| KMS | Customer managed keyが必要な環境で指定されているか |
| Logs | CloudWatch Logsへ出力され、保持期間が設定されているか |
| Function URL | `AuthType=AWS_IAM` か、`NONE` の公開が承認済みか |
| CloudTrail | 設定変更履歴を追跡できるか |

重要:

```text
Lambdaはサーバーレスでも「権限」と「公開経路」を必ず確認する。
特にFunction URLの AuthType=NONE と Resource-based policy の Principal=* は、
外部公開に直結するため、変更前後の証跡を残す。
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

FUNCTION_NAME="sample-function"

echo "Account : $ACCOUNT_ID"
echo "Region  : $REGION"
echo "Function: $FUNCTION_NAME"
```

### 3.2 証跡ディレクトリ

```bash
WORK_NAME="lambda_security_check"
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
| 1 | Function一覧 | 対象Functionを識別できる | `list-functions` |
| 2 | Function設定 | Runtime、Role、VPC、KMSを確認 | `get-function-configuration` |
| 3 | IAM Role | Lambda用Trust Policy | `iam get-role` |
| 4 | IAM Policy | 最小権限、不要なFullAccessなし | `list-attached-role-policies` |
| 5 | Resource Policy | `Principal=*` を確認 | `lambda get-policy` |
| 6 | VPC | Subnet / SG / VPC ID確認 | `get-function-configuration` |
| 7 | SG | 必要な宛先のみ許可 | `describe-security-group-rules` |
| 8 | 環境変数 | 秘密情報がない、値を証跡に残さない | `get-function-configuration` |
| 9 | KMS | `KMSKeyArn`確認 | `get-function-configuration` |
| 10 | Logs | Log Group、Retention確認 | `logs describe-log-groups` |
| 11 | Function URL | AuthType / CORS確認 | `get-function-url-config` |
| 12 | CloudTrail | 変更履歴確認 | `lookup-events` |

## 5. Lambda Function基本確認

### 5.1 Function一覧

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Functions[*].{Name:FunctionName,Runtime:Runtime,PackageType:PackageType,Role:Role,LastModified:LastModified,Timeout:Timeout,MemorySize:MemorySize,VpcId:VpcConfig.VpcId,KMSKeyArn:KMSKeyArn}' \
  --output table
```

証跡保存:

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/01_list_functions.json"
```

確認ポイント:

- 対象Function名
- Runtime
- PackageType
- Execution Role
- VPC接続有無
- KMS Key設定有無
- LastModified
- Timeout / MemorySize

### 5.2 対象Function設定

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,FunctionArn:FunctionArn,Runtime:Runtime,PackageType:PackageType,Role:Role,Handler:Handler,CodeSize:CodeSize,Description:Description,Timeout:Timeout,MemorySize:MemorySize,LastModified:LastModified,State:State,LastUpdateStatus:LastUpdateStatus,VpcConfig:VpcConfig,KMSKeyArn:KMSKeyArn,LoggingConfig:LoggingConfig,TracingConfig:TracingConfig,EnvironmentError:Environment.Error}' \
  --output json \
  > "$EVIDENCE_DIR/before/02_function_configuration.json"
```

画面確認用:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,Runtime:Runtime,Role:Role,State:State,LastUpdateStatus:LastUpdateStatus,VpcId:VpcConfig.VpcId,Subnets:VpcConfig.SubnetIds,SecurityGroups:VpcConfig.SecurityGroupIds,KMSKeyArn:KMSKeyArn,LogGroup:LoggingConfig.LogGroup}' \
  --output table
```

注意:

```text
Environment.Variables には秘密情報が含まれる可能性がある。
証跡として保存する場合は、値をマスクするか、値そのものを保存しない。
```

### 5.3 Function全体情報

```bash
aws lambda get-function \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{Configuration:Configuration,Code:Code,Concurrency:Concurrency,Tags:Tags}' \
  --output json \
  > "$EVIDENCE_DIR/before/03_get_function.json"
```

確認ポイント:

- Code location
- RepositoryType
- Concurrency設定
- Tags
- Runtime / Role / VPC / KMS

## 6. IAM Execution Role確認

### 6.1 Execution Role ARN取得

```bash
ROLE_ARN=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Role' \
  --output text)

ROLE_NAME="${ROLE_ARN##*/}"

echo "Role ARN : $ROLE_ARN"
echo "Role Name: $ROLE_NAME"
```

### 6.2 Trust Policy確認

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,CreateDate:CreateDate,AssumeRolePolicyDocument:AssumeRolePolicyDocument,MaxSessionDuration:MaxSessionDuration}' \
  --output json \
  > "$EVIDENCE_DIR/before/04_iam_role.json"
```

画面確認用:

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'Role.AssumeRolePolicyDocument.Statement[*].{Effect:Effect,Principal:Principal,Action:Action,Condition:Condition}' \
  --output table
```

期待値:

```text
Principal.Service に lambda.amazonaws.com が含まれる。
不要なAWSアカウントやサービスがAssumeRoleできない。
```

### 6.3 Managed Policy確認

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/05_attached_role_policies.json"
```

画面確認用:

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
  --output table
```

確認ポイント:

- `AdministratorAccess` が付いていないか
- 不要な `*FullAccess` が付いていないか
- CloudWatch Logsに必要な権限があるか
- VPC接続に必要なENI操作権限があるか
- KMS / Secrets Manager / S3 / DynamoDBなどの権限が過剰でないか

### 6.4 Inline Policy確認

```bash
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/06_inline_policy_names.json"
```

Inline Policy名を指定して取得する。

```bash
INLINE_POLICY_NAME="sample-inline-policy"

aws iam get-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --output json \
  > "$EVIDENCE_DIR/investigation/iam_inline_policy_${INLINE_POLICY_NAME}.json"
```

確認ポイント:

- `Action="*"` がないか
- `Resource="*"` が必要以上に使われていないか
- `iam:PassRole` が広すぎないか
- `kms:Decrypt` が必要なKMS Keyに限定されているか
- `secretsmanager:GetSecretValue` が必要なSecretに限定されているか

### 6.5 Managed Policyの中身確認

```bash
POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

POLICY_VERSION_ID=$(aws iam get-policy \
  --profile "$PROFILE" \
  --policy-arn "$POLICY_ARN" \
  --query 'Policy.DefaultVersionId' \
  --output text)

aws iam get-policy-version \
  --profile "$PROFILE" \
  --policy-arn "$POLICY_ARN" \
  --version-id "$POLICY_VERSION_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/managed_policy_${POLICY_VERSION_ID}.json"
```

## 7. Resource-based Policy確認

Lambdaには、IAM Roleとは別にFunction側へ付与するResource-based policyがある。

代表例:

- S3からLambdaをInvokeする
- EventBridgeからLambdaをInvokeする
- API GatewayからLambdaをInvokeする
- Function URLからLambdaをInvokeする
- 別AWSアカウントからLambdaをInvokeする

### 7.1 Function Policy取得

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/07_lambda_resource_policy.json"
```

Policyがない場合:

```text
ResourceNotFoundException が出る場合は、FunctionにResource-based policyが未設定。
```

### 7.2 Resource Policyの危険な見方

確認する文字列:

```text
"Principal":"*"
"Principal":{"AWS":"*"}
"Action":"lambda:InvokeFunction"
"Action":"lambda:InvokeFunctionUrl"
"Condition" がない
"SourceArn" がない
"SourceAccount" がない
```

見るべき観点:

| 観点 | 確認内容 |
| :--- | :--- |
| Principal | 誰がInvokeできるか |
| Action | `InvokeFunction` / `InvokeFunctionUrl` の範囲 |
| Resource | 対象FunctionまたはAliasが限定されているか |
| Condition | `SourceArn`、`SourceAccount`、`InvokedViaFunctionUrl` があるか |
| Sid | 変更対象Statementを識別できるか |

### 7.3 Policyを見やすく確認する

`jq` が使える環境の場合:

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Policy' \
  --output text \
  | jq .
```

`jq` が使えない環境では、JSON出力を証跡として保存してWebコンソールでも確認する。

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json
```

## 8. VPC接続設定確認

### 8.1 VPC Config確認

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,VpcId:VpcConfig.VpcId,SubnetIds:VpcConfig.SubnetIds,SecurityGroupIds:VpcConfig.SecurityGroupIds,Ipv6AllowedForDualStack:VpcConfig.Ipv6AllowedForDualStack}' \
  --output json \
  > "$EVIDENCE_DIR/before/08_lambda_vpc_config.json"
```

画面確認用:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{VpcId:VpcConfig.VpcId,Subnets:VpcConfig.SubnetIds,SecurityGroups:VpcConfig.SecurityGroupIds,Ipv6:VpcConfig.Ipv6AllowedForDualStack}' \
  --output table
```

確認ポイント:

- VPC接続が必要なFunctionか
- 接続先はPrivate Subnetか
- 複数AZのSubnetが指定されているか
- Security Groupが想定どおりか
- 外部AWSサービスへ通信する場合、NAT GatewayまたはVPC Endpointがあるか

### 8.2 Subnet詳細確認

```bash
SUBNET_IDS=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.SubnetIds' \
  --output text)

aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids $SUBNET_IDS \
  --query 'Subnets[*].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,CidrBlock:CidrBlock,MapPublicIpOnLaunch:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids $SUBNET_IDS \
  --output json \
  > "$EVIDENCE_DIR/investigation/lambda_subnets.json"
```

### 8.3 Security Group詳細確認

```bash
SG_IDS=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.SecurityGroupIds' \
  --output text)

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $SG_IDS \
  --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId,Description:Description,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/lambda_security_groups.json"
```

画面確認用:

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values=$SG_IDS \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:CidrIpv4,ReferencedGroup:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table
```

確認ポイント:

- LambdaからRDSやElastiCacheへ必要なPortだけ出ているか
- `0.0.0.0/0` へのEgressが許容される設計か
- Ingressルールが不要に開いていないか
- 変更対象SGが他のリソースにも使われていないか

重要:

```text
LambdaをVPC内に配置しても、自動的にインターネットへ出られるわけではない。
外部APIやAWS APIへアクセスする場合、NAT GatewayまたはVPC Endpointの有無を確認する。
```

### 8.4 VPC Endpoint確認

```bash
VPC_ID=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.VpcId' \
  --output text)

aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,ServiceName:ServiceName,Type:VpcEndpointType,State:State,Subnets:SubnetIds,Groups:Groups[*].GroupId,PrivateDnsEnabled:PrivateDnsEnabled}' \
  --output table
```

LambdaがVPC内から呼び出す可能性がある代表的なEndpoint:

| 用途 | Endpoint例 |
| :--- | :--- |
| S3 | Gateway Endpoint `com.amazonaws.ap-northeast-1.s3` |
| Secrets Manager | Interface Endpoint `com.amazonaws.ap-northeast-1.secretsmanager` |
| KMS | Interface Endpoint `com.amazonaws.ap-northeast-1.kms` |
| DynamoDB | Gateway Endpoint `com.amazonaws.ap-northeast-1.dynamodb` |
| SQS | Interface Endpoint `com.amazonaws.ap-northeast-1.sqs` |
| SNS | Interface Endpoint `com.amazonaws.ap-northeast-1.sns` |

## 9. VPC設定変更

### 9.1 VPC接続を追加・変更する

```bash
NEW_SUBNET_IDS="subnet-xxxxxxxx subnet-yyyyyyyy"
NEW_SG_IDS="sg-xxxxxxxx"

aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --vpc-config SubnetIds=${NEW_SUBNET_IDS// /,},SecurityGroupIds=${NEW_SG_IDS// /,}
```

更新完了待ち:

```bash
aws lambda wait function-updated \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"
```

変更後確認:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{LastUpdateStatus:LastUpdateStatus,VpcConfig:VpcConfig}' \
  --output table
```

### 9.2 VPC接続を外す

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --vpc-config SubnetIds=[],SecurityGroupIds=[]
```

注意:

```text
VPC接続を外すと、Private Subnet内のRDS、ElastiCache、Private API、VPC Endpointへ接続できなくなる。
切り戻し用に変更前のSubnetIdsとSecurityGroupIdsを必ず保存する。
```

## 10. 環境変数確認

### 10.1 環境変数の設定有無確認

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,Environment:Environment}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/environment_raw_need_masking.json"
```

重要:

```text
このファイルには環境変数の値が含まれる可能性がある。
パスワード、トークン、APIキー、接続文字列が入っている場合は、
共有前に必ずマスクする。
```

### 10.2 環境変数キーだけ確認する

`jq` が使える環境の場合:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Environment.Variables' \
  --output json \
  | jq 'keys'
```

`jq` が使えない環境では、Webコンソール画面で値を表示しないように注意して、キー名だけを証跡化する。

確認ポイント:

- `DB_PASSWORD`
- `SECRET_KEY`
- `API_KEY`
- `TOKEN`
- `ACCESS_KEY`
- `SECRET_ACCESS_KEY`
- `PRIVATE_KEY`
- 個人情報
- 接続文字列

案件での判断:

```text
秘密情報は、可能であれば環境変数ではなくSecrets ManagerやSSM Parameter Storeへ移す。
ただし既存アプリ影響があるため、変更時はアプリ側の読み取り方式、IAM Role権限、VPC Endpointを確認する。
```

### 10.3 環境変数を変更する

変更前保存:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Environment' \
  --output json \
  > "$EVIDENCE_DIR/before/environment_before_need_masking.json"
```

変更:

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --environment "Variables={APP_ENV=production,LOG_LEVEL=INFO}"
```

注意:

```text
--environment Variables=... は既存の環境変数セットを置き換える。
1項目だけ追加するつもりでも、他の既存キーを含めずに実行すると消える。
必ず変更前の全キーを確認してから実施する。
```

更新完了待ち:

```bash
aws lambda wait function-updated \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"
```

切り戻し:

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --environment "Variables={APP_ENV=production,LOG_LEVEL=INFO}"
```

切り戻し時は、変更前証跡に保存した値を使う。

## 11. 暗号化・KMS確認

### 11.1 KMSKeyArn確認

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,KMSKeyArn:KMSKeyArn}' \
  --output table
```

証跡保存:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,KMSKeyArn:KMSKeyArn,EnvironmentError:Environment.Error}' \
  --output json \
  > "$EVIDENCE_DIR/before/09_lambda_kms.json"
```

確認ポイント:

- Customer managed keyを使う要件があるか
- `KMSKeyArn` が未指定の場合の扱いが設計と合っているか
- 実行ロールに必要なKMS権限があるか
- Key policyにLambda利用が許可されているか
- KMS Keyの無効化・削除予定がないか

### 11.2 KMS Key詳細確認

```bash
KMS_KEY_ARN=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'KMSKeyArn' \
  --output text)

aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ARN" \
  --query 'KeyMetadata.{KeyId:KeyId,Arn:Arn,Description:Description,KeyState:KeyState,KeyManager:KeyManager,CustomerMasterKeySpec:CustomerMasterKeySpec,KeyUsage:KeyUsage,CreationDate:CreationDate,DeletionDate:DeletionDate}' \
  --output table
```

Key policy確認:

```bash
aws kms get-key-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ARN" \
  --policy-name default \
  --output json \
  > "$EVIDENCE_DIR/investigation/kms_key_policy.json"
```

### 11.3 Customer managed keyを指定する

```bash
NEW_KMS_KEY_ARN="arn:aws:kms:ap-northeast-1:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --kms-key-arn "$NEW_KMS_KEY_ARN"
```

変更後確認:

```bash
aws lambda wait function-updated \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,KMSKeyArn:KMSKeyArn,LastUpdateStatus:LastUpdateStatus}' \
  --output table
```

切り戻し:

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --kms-key-arn "$OLD_KMS_KEY_ARN"
```

KMS Key指定を外す場合:

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --kms-key-arn ""
```

注意:

```text
KMS Keyを変更すると、環境変数や一部のLambda内部データの復号に影響する可能性がある。
実行ロール、Key policy、KMS Endpoint、アプリ起動確認までセットで確認する。
```

## 12. CloudWatch Logs確認

### 12.1 Log Group確認

デフォルトのLog Group名:

```bash
LOG_GROUP_NAME="/aws/lambda/${FUNCTION_NAME}"
```

確認:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[*].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,CreationTime:creationTime}' \
  --output table
```

証跡保存:

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/10_lambda_log_group.json"
```

確認ポイント:

- Log Groupが存在するか
- Retentionが無期限になっていないか
- KMS暗号化が必要な環境で設定されているか
- ログ量が異常に増えていないか

### 12.2 Log Retention設定

```bash
aws logs put-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --retention-in-days 90
```

切り戻し例:

```bash
aws logs delete-retention-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME"
```

注意:

```text
delete-retention-policy を実行するとログ保持期間が無期限になる。
本番相当では、保持期間の設計値を確認してから切り戻す。
```

### 12.3 Log Stream確認

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[*].{LogStreamName:logStreamName,LastEventTimestamp:lastEventTimestamp,StoredBytes:storedBytes}' \
  --output table
```

### 12.4 Errorログ検索

```bash
aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '?ERROR ?Exception ?AccessDenied ?"Task timed out"' \
  --start-time "$(date -v-1H +%s)000" \
  --output json \
  > "$EVIDENCE_DIR/investigation/lambda_error_logs_last_1h.json"
```

Linuxの場合:

```bash
START_TIME=$(date -d '1 hour ago' +%s)000

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '?ERROR ?Exception ?AccessDenied ?"Task timed out"' \
  --start-time "$START_TIME" \
  --output json
```

### 12.5 CloudWatch Logs Insights検索

```bash
QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --start-time "$(date -v-1H +%s)" \
  --end-time "$(date +%s)" \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR|Exception|AccessDenied|Task timed out/ | sort @timestamp desc | limit 50' \
  --query 'queryId' \
  --output text)

sleep 5

aws logs get-query-results \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query-id "$QUERY_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/lambda_logs_insights_errors.json"
```

## 13. LoggingConfig確認・変更

Lambdaでは、Function設定としてLoggingConfigを持つ場合がある。

### 13.1 LoggingConfig確認

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,LoggingConfig:LoggingConfig}' \
  --output table
```

### 13.2 Log Groupを明示する

```bash
CUSTOM_LOG_GROUP="/aws/lambda/${FUNCTION_NAME}"

aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --logging-config LogFormat=Text,LogGroup="$CUSTOM_LOG_GROUP"
```

JSONログにする例:

```bash
aws lambda update-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --logging-config LogFormat=JSON,ApplicationLogLevel=INFO,SystemLogLevel=WARN,LogGroup="$CUSTOM_LOG_GROUP"
```

注意:

```text
ログ形式やログレベルを変更すると、既存のMetric Filter、CloudWatch Logs Insights、
監視ツール、運用手順に影響する可能性がある。
変更前にログを利用しているチームへ確認する。
```

## 14. Function URL確認

Function URLは、Lambdaに直接HTTPSエンドポイントを付与する機能である。

確認観点:

| 項目 | 見る内容 |
| :--- | :--- |
| FunctionUrl | URLが存在するか |
| AuthType | `AWS_IAM` か `NONE` か |
| CORS | `AllowOrigins=*` になっていないか |
| InvokeMode | 通常は `BUFFERED` |
| Resource Policy | Invoke権限が誰にあるか |

### 14.1 Function URL一覧

```bash
aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'FunctionUrlConfigs[*].{FunctionUrl:FunctionUrl,AuthType:AuthType,CreationTime:CreationTime,LastModifiedTime:LastModifiedTime,InvokeMode:InvokeMode,Cors:Cors}' \
  --output table
```

証跡保存:

```bash
aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/11_function_url_configs.json"
```

### 14.2 Function URL詳細

```bash
aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/12_function_url_config.json"
```

Function URLがない場合:

```text
ResourceNotFoundException が出る場合は、Function URL未作成。
```

### 14.3 Function URLの危険な状態

```text
AuthType=NONE
かつ
Resource-based policy で Principal=* に InvokeFunctionUrl / InvokeFunction が許可されている
```

この場合、URLを知っている外部ユーザーが認証なしで呼び出せる可能性がある。

確認コマンド:

```bash
aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionUrl:FunctionUrl,AuthType:AuthType,Cors:Cors,InvokeMode:InvokeMode}' \
  --output table

aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json
```

## 15. Function URL作成・変更

### 15.1 IAM認証付きFunction URLを作成する

```bash
aws lambda create-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --auth-type AWS_IAM \
  --cors AllowOrigins=https://www.example.com,AllowMethods=GET,POST
```

確認:

```bash
aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionUrl:FunctionUrl,AuthType:AuthType,Cors:Cors}' \
  --output table
```

### 15.2 Function URLをIAM認証へ変更する

```bash
aws lambda update-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --auth-type AWS_IAM
```

変更後確認:

```bash
aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionUrl:FunctionUrl,AuthType:AuthType,LastModifiedTime:LastModifiedTime}' \
  --output table
```

### 15.3 IAM認証Function URLのInvoke許可

同一アカウント内の特定IAM Roleに許可する例:

```bash
INVOKER_PRINCIPAL_ARN="arn:aws:iam::123456789012:role/sample-invoker-role"

aws lambda add-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id AllowInvokeFunctionUrlFromRole \
  --action lambda:InvokeFunctionUrl \
  --principal "$INVOKER_PRINCIPAL_ARN" \
  --function-url-auth-type AWS_IAM

aws lambda add-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id AllowInvokeFunctionViaUrlFromRole \
  --action lambda:InvokeFunction \
  --principal "$INVOKER_PRINCIPAL_ARN" \
  --invoked-via-function-url
```

重要:

```text
Function URLでは lambda:InvokeFunctionUrl と lambda:InvokeFunction の両方を意識する。
lambda:InvokedViaFunctionUrl 条件を使うと、Function URL経由の呼び出しに限定しやすい。
```

### 15.4 Public Function URLを作成する場合

Public公開は原則として慎重に扱う。

```bash
aws lambda create-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --auth-type NONE
```

CLIで `AuthType=NONE` を使う場合、Resource-based policyも必要になる。

```bash
aws lambda add-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id FunctionURLAllowPublicAccess \
  --action lambda:InvokeFunctionUrl \
  --principal '*' \
  --function-url-auth-type NONE

aws lambda add-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id FunctionURLInvokeAllowPublicAccess \
  --action lambda:InvokeFunction \
  --principal '*' \
  --invoked-via-function-url
```

本番相当での注意:

```text
AuthType=NONE はインターネット公開に近い扱い。
銀行系・金融系では、明確な承認、WAF/API Gateway/認証方式、監視、ログ確認、
Rate limit、利用目的の整理がない限り安易に使わない。
```

### 15.5 Function URL削除

```bash
aws lambda delete-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"
```

重要:

```text
Function URLを削除しても、AuthType=NONE用に追加したResource-based policyが残る場合がある。
不要な add-permission のStatementは remove-permission で削除する。
```

不要Statement削除:

```bash
aws lambda remove-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id FunctionURLAllowPublicAccess

aws lambda remove-permission \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --statement-id FunctionURLInvokeAllowPublicAccess
```

## 16. Function URL動作確認

### 16.1 URL取得

```bash
FUNCTION_URL=$(aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'FunctionUrl' \
  --output text)

echo "$FUNCTION_URL"
```

### 16.2 AuthType=NONEの疎通確認

```bash
curl -i "$FUNCTION_URL"
```

期待値:

```text
HTTP/2 200
またはアプリケーションが返す想定ステータス
```

### 16.3 AuthType=AWS_IAMの未署名アクセス確認

```bash
curl -i "$FUNCTION_URL"
```

期待値:

```text
HTTP 403
認証なしでは呼び出せない
```

### 16.4 IAM認証付きInvoke確認

SigV4署名が必要なため、通常の `curl` だけでは呼び出せない。

確認方法の例:

- AWS SDKから呼び出す
- PostmanでAWS SigV4を設定する
- `awscurl` など署名可能なツールを使う
- 一時的な検証用コードを用意する

案件での説明ポイント:

```text
AuthType=AWS_IAM のFunction URLは、URLを知っているだけでは呼び出せない。
IAM権限とSigV4署名が必要になる。
```

## 17. CloudTrailで変更履歴確認

### 17.1 Lambda設定変更イベント

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=lambda.amazonaws.com \
  --start-time "$(date -v-7d '+%Y-%m-%dT%H:%M:%S%z')" \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_lambda_events_7d.json"
```

Linuxの場合:

```bash
START_TIME=$(date -d '7 days ago' '+%Y-%m-%dT%H:%M:%S%z')

aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=lambda.amazonaws.com \
  --start-time "$START_TIME" \
  --max-results 50 \
  --output json
```

### 17.2 重要イベント

```text
CreateFunction
UpdateFunctionConfiguration
UpdateFunctionCode
DeleteFunction
AddPermission
RemovePermission
CreateFunctionUrlConfig
UpdateFunctionUrlConfig
DeleteFunctionUrlConfig
PutFunctionConcurrency
DeleteFunctionConcurrency
TagResource
UntagResource
```

### 17.3 特定Function名で見る

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$FUNCTION_NAME" \
  --max-results 50 \
  --output table
```

見るポイント:

- 誰が変更したか
- いつ変更したか
- どのAPIを呼んだか
- UserAgentがConsoleかCLIか
- ErrorCodeがないか
- 変更申請の時間帯と一致しているか

## 18. 変更前確認テンプレート

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/lambda_function_configuration_before.json"

aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/lambda_resource_policy_before.json" \
  2> "$EVIDENCE_DIR/before/lambda_resource_policy_before_error.txt" || true

aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/before/lambda_function_url_before.json"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/lambda/${FUNCTION_NAME}" \
  --output json \
  > "$EVIDENCE_DIR/before/lambda_logs_before.json"
```

注意:

```text
環境変数の値が含まれる証跡は、共有前にマスクする。
```

## 19. 変更後確認テンプレート

```bash
aws lambda wait function-updated \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/lambda_function_configuration_after.json"

aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/lambda_resource_policy_after.json" \
  2> "$EVIDENCE_DIR/after/lambda_resource_policy_after_error.txt" || true

aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  > "$EVIDENCE_DIR/after/lambda_function_url_after.json"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/lambda/${FUNCTION_NAME}" \
  --output json \
  > "$EVIDENCE_DIR/after/lambda_logs_after.json"
```

差分確認:

```bash
diff -u \
  "$EVIDENCE_DIR/before/lambda_function_configuration_before.json" \
  "$EVIDENCE_DIR/after/lambda_function_configuration_after.json" \
  > "$EVIDENCE_DIR/after/lambda_function_configuration_diff.txt" || true
```

## 20. 影響範囲確認

### 20.1 IAM Role変更の影響

確認対象:

- Lambdaが呼び出すAWSサービス
- CloudWatch Logs出力
- VPC ENI作成
- KMS復号
- Secrets Manager取得
- S3読み書き
- RDS接続
- EventBridge / SQS / SNS連携

リスク:

```text
Execution Roleの権限を絞りすぎると、FunctionがAccessDeniedで失敗する。
逆に広すぎる権限は、侵害時の影響範囲を広げる。
```

### 20.2 VPC変更の影響

確認対象:

- RDS / ElastiCache / Private APIへの疎通
- NAT Gateway経由の外部API通信
- VPC Endpoint経由のAWS API通信
- Security GroupのEgress
- NACL
- DNS解決

リスク:

```text
SubnetやSGを変えると、Function自体は更新成功しても、
実行時にDB接続失敗や外部API接続失敗が発生することがある。
```

### 20.3 環境変数変更の影響

確認対象:

- アプリ起動
- DB接続
- 外部API認証
- Feature flag
- ログレベル
- Secret値

リスク:

```text
Lambdaの環境変数更新はセット置き換え。
既存キーを漏らすとアプリ障害につながる。
```

### 20.4 Function URL変更の影響

確認対象:

- 呼び出し元
- 認証方式
- CORS
- Resource-based policy
- WAF/API Gatewayなど前段有無
- 監視・ログ

リスク:

```text
AuthTypeをNONEにすると未認証公開になる。
AuthTypeをAWS_IAMに変えると、未署名の既存クライアントは403になる。
```

## 21. 切り戻し観点

| 変更対象 | 切り戻し方法 |
| :--- | :--- |
| IAM Role | `update-function-configuration --role "$OLD_ROLE_ARN"` |
| IAM Policy | 変更前Policyを再適用 |
| Resource Policy | `remove-permission` または `add-permission` |
| VPC | 変更前SubnetIds / SGIdsへ戻す |
| 環境変数 | 変更前の全Variablesへ戻す |
| KMS | 変更前KMSKeyArnへ戻す |
| Log Retention | 変更前Retentionへ戻す |
| Function URL | 変更前AuthType / CORSへ戻す、または削除 |

切り戻し前に確認すること:

```text
1. 障害内容
2. 切り戻し対象
3. 変更前証跡
4. 切り戻しコマンド
5. 切り戻し後確認コマンド
6. 関係者連絡
```

## 22. Webコンソール証跡で撮る画面

現場ではGUI証跡を求められることが多い。

撮る画面:

- Lambda Function一覧
- 対象FunctionのConfiguration
- Permissions
- Execution Roleリンク先のIAM Role
- Resource-based policy
- VPC設定
- Environment variables
- Encryption設定
- Monitor / Logs
- Function URL設定
- CloudWatch Logs Log Group
- CloudTrail Event history

注意:

```text
Environment variables画面は値が見える場合がある。
秘密情報が写る場合は、証跡取得前に表示状態やマスク方針を確認する。
```

## 23. Teams報告例

### 23.1 変更前確認完了

```text
Lambda設定変更の変更前確認が完了しました。

対象:
- Function: sample-function
- Region: ap-northeast-1

確認内容:
- Function基本設定
- Execution Role
- Resource-based policy
- VPC設定
- 環境変数設定有無
- KMS設定
- CloudWatch Logs
- Function URL

現時点で確認した注意点:
- Function URL: AuthType=AWS_IAM
- Resource-based policy: Public許可なし
- 環境変数: 値は証跡共有対象外としてマスク予定

次に、承認済み手順に沿って設定変更を実施します。
```

### 23.2 変更完了

```text
Lambda設定変更が完了しました。

対象:
- Function: sample-function

実施内容:
- Function URL AuthTypeをAWS_IAMへ変更
- Resource-based policyを確認
- CloudWatch Logsでエラーが出ていないことを確認

変更後確認:
- LastUpdateStatus: Successful
- Function URL AuthType: AWS_IAM
- 未署名アクセス: 403
- CloudWatch Logs: 新規エラーなし

証跡:
- 変更前設定JSON
- 変更後設定JSON
- 差分
- CloudTrailイベント
- Webコンソールスクリーンショット
```

### 23.3 要確認事項

```text
Lambda環境変数に秘密情報と思われるキーが含まれていました。

確認対象:
- DB_PASSWORD
- API_TOKEN

現時点では値の共有・転記は行っていません。
Secrets ManagerまたはSSM Parameter Storeへの移行要否について、
アプリ影響と合わせて確認をお願いします。
```

## 24. 案件で説明できるポイント

- LambdaはサーバーレスでもIAM Roleの最小権限確認が重要
- Resource-based policyで外部からのInvoke許可を確認する
- Function URLは `AuthType=NONE` の場合に公開リスクが高い
- Function URLでは `InvokeFunctionUrl` と `InvokeFunction` の両方の権限を見る
- VPC接続時はSubnet、SG、NAT、VPC Endpoint、DNSを確認する
- 環境変数は証跡化時に秘密情報が漏れやすい
- LambdaログはCloudWatch Logsに出るため、Log GroupとRetentionも確認する
- CloudTrailで `UpdateFunctionConfiguration` や `AddPermission` の変更履歴を追える

## 25. 資格試験につながるポイント

| 領域 | 試験観点 |
| :--- | :--- |
| IAM | Execution Role、Resource-based policy、最小権限 |
| Lambda | Runtime、Timeout、Memory、VPC、Environment |
| VPC | Private Subnet、SG、NAT、VPC Endpoint |
| KMS | Customer managed key、Key policy、Decrypt権限 |
| CloudWatch | Logs、Log Group、Retention、Logs Insights |
| CloudTrail | Lambda設定変更APIの監査 |
| Function URL | AuthType、CORS、Invoke権限、公開リスク |
| Secrets | Secrets Manager / SSM Parameter Store利用 |

## 26. 公式ドキュメント

- AWS CLI `get-function-configuration`
  - https://docs.aws.amazon.com/cli/latest/reference/lambda/get-function-configuration.html
- AWS CLI `update-function-configuration`
  - https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-configuration.html
- AWS CLI `create-function-url-config`
  - https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function-url-config.html
- AWS CLI `list-function-url-configs`
  - https://docs.aws.amazon.com/cli/latest/reference/lambda/list-function-url-configs.html
- AWS Lambda Function URL作成
  - https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html
- AWS Lambda Function URLアクセス制御
  - https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html
- AWS Lambda VPC接続
  - https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html
- AWS Lambda環境変数
  - https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html
- AWS Lambda CloudWatch Logs
  - https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html
- AWS Lambda Log Group設定
  - https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-loggroups.html
