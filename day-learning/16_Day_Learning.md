# Day 16 Learning: Lambda Security確認ドリル

## 学習開始前に実行するスクリプト

現在の個人ラボではLambda Functionが0件であることを確認するDayのため、開始前スクリプトは不要である。

```text
All_Setup.sh: 不要
Ansible: 不要
CloudTrail一時Trail: 不要
S3 Data Event: 不要
```

Lambda Functionが0件の場合も、想定どおりの確認結果として扱う。

## 1. 今日の目的

AWS Lambdaの権限、公開経路、ネットワーク、秘密情報、暗号化、ログを横断的に確認し、Function URLの公開リスクを説明できる状態を目指す。

Lambdaはサーバーを管理しないサービスだが、セキュリティ確認が不要になるわけではない。

```text
誰がLambdaを呼び出せるか
  -> Resource-based Policy / Function URL / Trigger

Lambdaが何を操作できるか
  -> Execution Role / IAM Policy

Lambdaがどこへ通信できるか
  -> VPC / Subnet / SG / NAT / VPC Endpoint

秘密情報とログをどう保護するか
  -> Environment Variables / Secrets Manager / KMS / CloudWatch Logs
```

本ドリルでは設定変更やFunction実行を行わない。Webコンソールと読み取り専用AWS CLIで現在設定を確認し、証跡と報告内容を整理する。

現在の個人ラボにはLambda Functionの構築スクリプトがなく、Functionは0件を想定する。0件の場合も異常ではなく、「現在Lambdaは使用していない」と確認結果を報告する。

関連資料:

- [Day 3 CloudTrail基礎・変更履歴調査](./03_Day_Learning.md)
- [Day 4 CloudWatch Logs・Metric Filter・Alarm確認](./04_Day_Learning.md)
- [Day 14 DNS・VPC Endpoint・Flow Logs確認](./14_Day_Learning.md)
- [Day 15 EC2・RDS Security確認](./15_Day_Learning.md)
- [Lambda Security CLIリファレンス](../docs/references/10_lambda_security_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)

---

## 2. 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象AWSアカウントのLambda利用状況とセキュリティ設定を確認してください。

Functionがある場合は、Execution Role、Resource-based Policy、
VPC接続、環境変数、KMS、CloudWatch Logs、Function URLを確認してください。

Function URLが外部公開されていないか、
Lambdaが過剰な権限を持っていないかを重点的に確認してください。

設定変更およびFunction実行は行わないでください。
```

## 今日の確認順序

1. AWSアカウントとリージョンを確認する
2. Lambda Function一覧と件数を確認する
3. Functionが0件の場合の報告を整理する
4. Function基本設定と状態を確認する
5. Execution Roleの信頼ポリシーと権限を確認する
6. Resource-based PolicyとTriggerを確認する
7. VPC、Subnet、Security Group、外向き経路を確認する
8. 環境変数の扱いと秘密情報管理を確認する
9. KMS設定を確認する
10. CloudWatch Logsと保持期間を確認する
11. Function URLのAuthType、CORS、Resource Policyを確認する
12. Concurrency、Version、Alias、Code Signingなどを確認する
13. CloudTrailでLambda変更履歴を確認する
14. 結果、改善候補、証跡、報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象サービス | AWS Lambda |
| ラボの期待値 | Lambda Function 0件 |
| 設定変更 | なし |
| Function実行 | なし |

## 今日実行しない操作

- Lambda Functionの作成、更新、削除
- Lambda FunctionのInvoke
- Execution Role、IAM Policy、Resource-based Policyの変更
- Trigger、Event Source Mapping、Permissionの変更
- VPC、Subnet、Security Group、VPC Endpointの変更
- Environment Variables、KMS Key、LoggingConfigの変更
- Function URLの作成、更新、削除
- Function URLへの疎通試験
- Concurrency、Version、Alias、Code Signing設定の変更

---

## 3. Lambdaの2種類の権限を理解する

Lambdaの権限確認では、Execution RoleとResource-based Policyを混同しない。

## Execution Role

Lambda Functionが実行中にAWSサービスへアクセスするための権限である。

```text
Lambda Function
  -> Execution Role
  -> S3 / RDS / DynamoDB / KMS / Secrets Manager / CloudWatch Logs
```

確認すること:

- 信頼ポリシーで`lambda.amazonaws.com`がRoleを引き受けられるか
- Roleに何のActionが許可されているか
- Resourceが必要範囲へ限定されているか
- `AdministratorAccess`や不要なFullAccessがないか

## Resource-based Policy

誰がLambda Functionを呼び出せるかをFunction側で定義するPolicyである。

```text
S3 / EventBridge / API Gateway / 別アカウント / Function URL
  -> Resource-based Policy
  -> Lambda FunctionをInvoke
```

確認すること:

- Principal
- Action
- SourceArn
- SourceAccount
- Condition
- Function URLのInvoke権限

重要:

```text
Execution Role:
Lambdaが何をできるか

Resource-based Policy:
誰がLambdaを呼び出せるか
```

---

## 4. Function URLの認証方式

Function URLは、Lambdaへ直接HTTPS Endpointを付与する機能である。

| AuthType | 意味 | 主なリスク |
|---|---|---|
| `AWS_IAM` | IAM認証とSigV4署名が必要 | 呼び出し権限の設計が必要 |
| `NONE` | Function URL側では認証しない | 外部から認証なしで呼び出せる可能性 |

危険性が高い組み合わせ:

```text
AuthType=NONE
  +
Resource-based PolicyのPrincipal=*
  +
機密処理、更新処理、秘密情報を返すFunction
```

`AuthType=NONE`が必ず不正とは限らない。公開Webhookなどの要件がある場合も、Application側認証、WAF相当の防御、入力検証、Rate制御、監視、承認を確認する。

---

## 5. 作業開始条件と報告条件

## 作業開始条件

- 読み取り専用の確認作業である
- 対象AWSアカウントとリージョンが明確である
- Lambda Functionの用途または未使用状態を確認できる
- AWS WebコンソールとAWS CLIで確認できる
- 証跡保存先が準備できている

## 作業中止・確認条件

- 想定外のAWSアカウントまたはリージョンである
- 対象Functionを一意に特定できない
- Environment Variablesや秘密情報の値を証跡保存しようとしている
- Function実行や設定変更を求められたが承認がない
- Resource-based PolicyまたはIAM Policyを確認する権限がない

## 即時共有する状態

- Function URLが`AuthType=NONE`で承認された公開要件を確認できない
- Resource-based Policyに無条件の`Principal=*`がある
- Execution Roleに`AdministratorAccess`など過剰権限がある
- 環境変数にAccess Key、Password、Token、Private Keyが平文保存される
- Function URLのCORSが不要に`AllowOrigins=*`
- VPC接続FunctionがPublic Subnet指定だけでInternetへ出られると誤認されている
- CloudWatch Logsがなく、実行エラーや監査情報を確認できない

---

## 6. 作業用変数と証跡保存先

Functionが存在する場合、`FUNCTION_NAME`を実在する対象名へ置き換える。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

FUNCTION_NAME="<target-function-name>"
WORK_NAME="lambda_security_check"
```

### 証跡保存用ディレクトリ

```bash
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/lambda" \
  "$EVIDENCE_DIR/iam" \
  "$EVIDENCE_DIR/network" \
  "$EVIDENCE_DIR/logs" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 秘密情報を証跡へ残さない

保存しないもの:

- Environment Variablesの値
- Password、Token、API Key、Access Key
- Secrets Manager Secret Value
- SSM SecureStringの値
- Lambda Code取得用の署名付きURL
- Functionの処理データや個人情報

---

## 7. AWSアカウントとLambda Function一覧の確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. Lambdaコンソールを開く
5. Function一覧と件数を確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_Lambda_Function一覧確認.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Functions[*].{Name:FunctionName,Runtime:Runtime,PackageType:PackageType,Role:Role,LastModified:LastModified,Timeout:Timeout,MemorySize:MemorySize,VpcId:VpcConfig.VpcId,KMSKeyArn:KMSKeyArn}' \
  --output table \
  --no-cli-pager
```

Function件数:

```bash
aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'length(Functions)' \
  --output text \
  --no-cli-pager
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_caller_identity.json"

aws lambda list-functions \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/lambda/01_list_functions.json"
```

### Functionが0件の場合

現在のラボでは0件を想定する。

```text
対象AWSアカウント、東京リージョンのLambda Function一覧を確認した。
確認時点でFunctionは存在しない。

そのため、Execution Role、Resource-based Policy、VPC Config、
Environment Variables、KMS、Logs、Function URLの個別確認対象はない。

設定変更は実施していない。
```

0件はLambdaサービスが無効という意味ではない。他リージョン、別アカウント、削除済みFunction、CloudTrail履歴も必要に応じて確認する。

---

## 8. Function基本設定の確認

この章以降は、確認対象Functionが存在する場合に実施する。

### Webコンソール

1. Lambdaコンソールで対象Functionを開く
2. Configurationを開く
3. Runtime、Architecture、Memory、Timeout、Execution Roleを確認する
4. StateとLast Update Statusを確認する
5. VPC、KMS、Logging、Tracingを確認する
6. 「編集」は押さない

取得するスクリーンショット:

```text
03_Lambda_Function基本設定確認.png
```

### AWS CLI

環境変数の値を含めない安全な表示:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,FunctionArn:FunctionArn,Runtime:Runtime,PackageType:PackageType,Architectures:Architectures,Role:Role,Handler:Handler,Description:Description,Timeout:Timeout,MemorySize:MemorySize,EphemeralStorage:EphemeralStorage.Size,LastModified:LastModified,State:State,LastUpdateStatus:LastUpdateStatus,VpcId:VpcConfig.VpcId,Subnets:VpcConfig.SubnetIds,SecurityGroups:VpcConfig.SecurityGroupIds,KMSKeyArn:KMSKeyArn,LoggingConfig:LoggingConfig,TracingConfig:TracingConfig,EnvironmentError:Environment.Error}' \
  --output json \
  --no-cli-pager
```

証跡保存:

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,FunctionArn:FunctionArn,Runtime:Runtime,PackageType:PackageType,Architectures:Architectures,Role:Role,Handler:Handler,Description:Description,Timeout:Timeout,MemorySize:MemorySize,EphemeralStorage:EphemeralStorage.Size,LastModified:LastModified,State:State,LastUpdateStatus:LastUpdateStatus,VpcConfig:VpcConfig,KMSKeyArn:KMSKeyArn,LoggingConfig:LoggingConfig,TracingConfig:TracingConfig,EnvironmentError:Environment.Error}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/lambda/02_function_configuration_without_environment_values.json"
```

### 結果の読み方

- `State=Active`
- `LastUpdateStatus=Successful`
- Runtimeがサポート期間内である
- Timeout、Memory、Ephemeral Storageが用途と一致する
- Execution Roleを一意に確認できる
- VPC、KMS、Logging、Tracingの設定を説明できる
- `Environment.Error`がない

---

## 9. Execution Roleの確認

### Webコンソール

1. 対象FunctionのPermissionsを開く
2. Execution Role名を確認する
3. IAMコンソールでRoleを開く
4. Trust Relationshipを確認する
5. Attached PolicyとInline Policyを確認する

取得するスクリーンショット:

```text
04_Lambda_Execution_Role確認.png
05_Lambda_Role_Trust_Policy確認.png
06_Lambda_Role_Permissions確認.png
```

### Role名を取得する

```bash
ROLE_ARN=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Role' \
  --output text \
  --no-cli-pager)

ROLE_NAME="${ROLE_ARN##*/}"

printf 'ROLE_ARN=%s\nROLE_NAME=%s\n' "$ROLE_ARN" "$ROLE_NAME"
```

### Trust Policy

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'Role.{RoleName:RoleName,Arn:Arn,AssumeRolePolicyDocument:AssumeRolePolicyDocument,PermissionsBoundary:PermissionsBoundary,MaxSessionDuration:MaxSessionDuration}' \
  --output json \
  --no-cli-pager
```

### Managed PolicyとInline Policy

```bash
aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --query 'AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}' \
  --output table \
  --no-cli-pager
```

```bash
aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws iam get-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/iam/01_execution_role.json"

aws iam list-attached-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/iam/02_attached_role_policies.json"

aws iam list-role-policies \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/iam/03_inline_policy_names.json"
```

### 結果の読み方

- Trust PolicyのService Principalに`lambda.amazonaws.com`がある
- 不要なAWSアカウントやServiceがRoleを引き受けられない
- `AdministratorAccess`や不要なFullAccessがない
- Resourceが必要なS3 Bucket、Secret、Table、Queueなどへ限定される
- VPC接続時にENI操作権限がある
- CloudWatch Logs出力に必要な権限がある
- Permission BoundaryやSCPの影響を必要に応じて確認する

---

## 10. Resource-based Policyの確認

### Webコンソール

1. 対象FunctionのPermissionsを開く
2. Resource-based Policy Statementsを確認する
3. Principal、Action、SourceArn、SourceAccountを確認する
4. Function URL権限を確認する

取得するスクリーンショット:

```text
07_Lambda_Resource_Policy確認.png
```

### AWS CLI

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  --no-cli-pager
```

Policy未設定の場合、`ResourceNotFoundException`が返る。これはFunction自体が存在する場合でも、Resource-based Policyがない状態として扱う。

### 確認ポイント

| 項目 | 確認内容 |
|---|---|
| Principal | 誰がInvokeできるか |
| Action | `lambda:InvokeFunction`または`lambda:InvokeFunctionUrl` |
| Resource | Function、Version、Aliasが適切か |
| SourceArn | S3 Bucket、EventBridge Rule、API Gatewayなどが限定されるか |
| SourceAccount | Confused Deputy対策として必要か |
| Condition | Function URL経由、Organization、Accountなどの条件 |

危険候補:

```text
Principal=*
Conditionなし
SourceArnなし
SourceAccountなし
用途不明の別アカウント許可
不要になったTriggerのStatement
```

---

## 11. TriggerとEvent Source Mappingの確認

Lambdaを呼び出す経路を確認する。Resource-based Policyだけでなく、Event Source Mapping、API Gateway、EventBridge、S3通知などの設定も確認する。

### Webコンソール

1. Function overviewでTriggerを確認する
2. Trigger種別と対象Resourceを確認する
3. 無効化されたTriggerや用途不明Triggerがないか確認する

取得するスクリーンショット:

```text
08_Lambda_Trigger確認.png
```

### Event Source Mapping

```bash
aws lambda list-event-source-mappings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'EventSourceMappings[*].{UUID:UUID,State:State,EventSourceArn:EventSourceArn,FunctionArn:FunctionArn,BatchSize:BatchSize,LastProcessingResult:LastProcessingResult,DestinationConfig:DestinationConfig}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- Triggerの用途と管理主体を説明できる
- Source Resourceが想定どおりである
- Event Source MappingのStateが`Enabled`または設計値である
- `LastProcessingResult`に継続エラーがない
- 不要なInvoke経路が残っていない

---

## 12. VPC接続設定の確認

LambdaがRDS、ElastiCache、Private APIへ接続する場合、VPC Configを使用することがある。

LambdaをVPCへ接続すると、自動的にInternetへ出られるわけではない。外部APIやAWSサービスへ接続する場合、NAT GatewayまたはVPC Endpointが必要になる場合がある。

重要:

```text
LambdaへPublic Subnetを指定しても、
Lambdaが使用するENIへPublic IPは付与されない。

Public Subnetを指定するだけではInternetへ接続できないため、
通常はPrivate SubnetからNAT Gatewayを経由するか、
必要なVPC Endpointを利用する。
```

### Webコンソール

1. 対象FunctionのConfigurationを開く
2. VPCを開く
3. VPC ID、Subnet、Security Groupを確認する
4. VPCコンソールでSubnet、Route、SG、Endpointを確認する

取得するスクリーンショット:

```text
09_Lambda_VPC_Config確認.png
10_Lambda_Subnet_Route確認.png
11_Lambda_Security_Group確認.png
```

### VPC Config

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,VpcId:VpcConfig.VpcId,SubnetIds:VpcConfig.SubnetIds,SecurityGroupIds:VpcConfig.SecurityGroupIds,Ipv6AllowedForDualStack:VpcConfig.Ipv6AllowedForDualStack}' \
  --output table \
  --no-cli-pager
```

### SubnetとSG

```bash
SUBNET_IDS=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.SubnetIds' \
  --output text \
  --no-cli-pager)

SG_IDS=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.SecurityGroupIds' \
  --output text \
  --no-cli-pager)
```

VPC接続されている場合に実行する。

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-ids $SUBNET_IDS \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,Cidr:CidrBlock,MapPublicIpOnLaunch:MapPublicIpOnLaunch}' \
  --output table \
  --no-cli-pager
```

```bash
SG_FILTER_VALUES=$(printf '%s' "$SG_IDS" | tr '\t ' ',')

aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$SG_FILTER_VALUES" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Egress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,DestinationSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### VPC Endpoint

```bash
VPC_ID=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'VpcConfig.VpcId' \
  --output text \
  --no-cli-pager)

aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,Service:ServiceName,Type:VpcEndpointType,State:State,Subnets:SubnetIds,RouteTables:RouteTableIds,Groups:Groups[*].GroupId,PrivateDns:PrivateDnsEnabled}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- VPC接続が業務要件上必要か
- Private Subnetを複数AZで使用するか
- SG Egressが必要な接続先とPortへ限定されるか
- RDS、ElastiCacheなど接続先SGがLambda SGから許可するか
- Internet向け通信はNAT経由か
- S3、KMS、Secrets Manager、CloudWatch LogsなどはEndpoint経由か
- DNS解決とRouteを説明できるか

---

## 13. 環境変数と秘密情報の確認

環境変数はApplication設定に便利だが、Password、Token、API Keyなどの秘密情報を安易に保存しない。

### Webコンソール

1. 対象FunctionのConfigurationを開く
2. Environment variablesを確認する
3. キー名から秘密情報候補を確認する
4. 値をスクリーンショットへ含めない
5. 値を手順書やTeamsへ貼り付けない

取得するスクリーンショット:

```text
12_Lambda_環境変数設定有無確認_値なし.png
```

確認するキー名の例:

```text
DB_PASSWORD
SECRET_KEY
API_KEY
TOKEN
ACCESS_KEY
SECRET_ACCESS_KEY
PRIVATE_KEY
CONNECTION_STRING
```

### AWS CLIで安全に確認する範囲

Environment Variablesの値を取得・保存せず、暗号化エラーの有無だけを確認する。

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,KMSKeyArn:KMSKeyArn,EnvironmentError:Environment.Error}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 秘密情報はSecrets ManagerまたはSSM Parameter Store利用を検討する
- FunctionのExecution RoleにSecret取得権限が必要になる
- VPC接続時はSecrets ManagerやKMSへのNAT / Endpoint経路を確認する
- 秘密情報を移行する場合、Application変更、試験、切り戻しが必要になる

---

## 14. KMS設定の確認

### Webコンソール

1. 対象FunctionのEnvironment variablesまたはEncryption設定を確認する
2. Customer managed keyの有無を確認する
3. KMS Keyの状態、Policy、管理主体を確認する

取得するスクリーンショット:

```text
13_Lambda_KMS設定確認.png
```

### AWS CLI

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,KMSKeyArn:KMSKeyArn,EnvironmentError:Environment.Error}' \
  --output table \
  --no-cli-pager
```

Customer managed keyが設定されている場合:

```bash
KMS_KEY_ARN=$(aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'KMSKeyArn' \
  --output text \
  --no-cli-pager)

aws kms describe-key \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-id "$KMS_KEY_ARN" \
  --query 'KeyMetadata.{KeyId:KeyId,Arn:Arn,Description:Description,Enabled:Enabled,KeyState:KeyState,KeyManager:KeyManager,KeyUsage:KeyUsage,DeletionDate:DeletionDate}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- Customer managed keyが要件上必要か
- KMS Keyが`Enabled`
- 削除予定や無効化状態ではない
- Execution RoleとKey Policyの権限が整合する
- VPC接続FunctionがKMSへ到達できる

---

## 15. CloudWatch LogsとLoggingConfigの確認

### Webコンソール

1. LambdaのMonitorを開く
2. CloudWatch LogsのLog Groupを開く
3. Log Stream、最終ログ時刻、Errorを確認する
4. Retention、KMS、Stored Bytesを確認する
5. ログに秘密情報が出力されていないか確認する

取得するスクリーンショット:

```text
14_Lambda_LoggingConfig確認.png
15_Lambda_CloudWatch_Log_Group確認.png
```

### LoggingConfig

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,LoggingConfig:LoggingConfig,TracingConfig:TracingConfig}' \
  --output table \
  --no-cli-pager
```

### Log Group

```bash
LOG_GROUP_NAME="/aws/lambda/${FUNCTION_NAME}"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --query 'logGroups[*].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId,CreationTime:creationTime}' \
  --output table \
  --no-cli-pager
```

### Log Stream

```bash
aws logs describe-log-streams \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --order-by LastEventTime \
  --descending \
  --max-items 10 \
  --query 'logStreams[*].{LogStreamName:logStreamName,LastEventTimestamp:lastEventTimestamp}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- Log Groupが存在する
- Retentionが監査・運用要件に一致する
- KMS暗号化要件を満たす
- ErrorやTimeoutを調査できる
- Application Logへ秘密情報を出力しない
- LoggingConfig変更時はMetric Filter、Alarm、Logs Insights、運用ツールへの影響を確認する

---

## 16. Function URLの確認

### Webコンソール

1. 対象FunctionのConfigurationを開く
2. Function URLを確認する
3. URLの有無、Auth Type、CORS、Invoke Modeを確認する
4. PermissionsでFunction URL関連Statementを確認する
5. URLへアクセスしない

取得するスクリーンショット:

```text
16_Lambda_Function_URL確認.png
17_Lambda_Function_URL_Resource_Policy確認.png
```

### AWS CLI

```bash
aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'FunctionUrlConfigs[*].{FunctionUrl:FunctionUrl,AuthType:AuthType,CreationTime:CreationTime,LastModifiedTime:LastModifiedTime,InvokeMode:InvokeMode,Cors:Cors}' \
  --output table \
  --no-cli-pager
```

Function URLがある場合:

```bash
aws lambda get-function-url-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionUrl:FunctionUrl,AuthType:AuthType,Cors:Cors,InvokeMode:InvokeMode,CreationTime:CreationTime,LastModifiedTime:LastModifiedTime}' \
  --output json \
  --no-cli-pager
```

Resource-based Policyも再確認する。

```bash
aws lambda get-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  --no-cli-pager
```

### 結果の読み方

| 状態 | 判断 |
|---|---|
| Function URLなし | 直接HTTPS Endpointなし |
| `AuthType=AWS_IAM` | IAM権限とSigV4署名が必要 |
| `AuthType=NONE` | 認証なし呼び出しの可能性。公開要件と防御を確認 |
| `AllowOrigins=*` | 任意Originを許可。要件確認 |
| `Principal=*` | Conditionと公開要件を重点確認 |

重要:

```text
Function URLがAWS_IAMでも、Execution Roleが呼び出し権限になるわけではない。

呼び出し元PrincipalのIAM権限と、
Function側Resource-based Policyの両方を確認する。
```

---

## 17. Concurrency・Version・Alias・Code Signing確認

Lambdaの変更影響や安定運用を確認するため、追加設定も確認する。

### Concurrency

```bash
aws lambda get-function-concurrency \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output table \
  --no-cli-pager
```

Reserved Concurrencyが未設定の場合、設定値が返らない、または`ResourceNotFoundException`となる場合がある。未設定は即時不備ではなく、Account全体のConcurrencyとFunctionの重要度を踏まえて判断する。

### VersionとAlias

```bash
aws lambda list-versions-by-function \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Versions[*].{Version:Version,LastModified:LastModified,Description:Description,Runtime:Runtime,CodeSize:CodeSize}' \
  --output table \
  --no-cli-pager
```

```bash
aws lambda list-aliases \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query 'Aliases[*].{Name:Name,FunctionVersion:FunctionVersion,Description:Description,RoutingConfig:RoutingConfig,RevisionId:RevisionId}' \
  --output table \
  --no-cli-pager
```

### Code Signing Config

```bash
aws lambda get-function-code-signing-config \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output table \
  --no-cli-pager
```

Code Signing Configが未設定の場合、`ResourceNotFoundException`となる場合がある。組織のデプロイ統制でCode Signingを必須としているか確認する。

### 結果の読み方

- Reserved Concurrencyが業務影響を考慮している
- Aliasが想定Versionを向く
- Weighted Alias利用時は切替率と監視を確認する
- `$LATEST`直接運用の是非を確認する
- Code Signingが必要な統制環境で設定されている

未設定が即時不備とは限らない。Functionの重要度、デプロイ方式、組織統制を確認する。

---

## 18. CloudTrailでLambda変更履歴を確認する

### 主なイベント

| 領域 | 主なイベント |
|---|---|
| Function | `CreateFunction`、`UpdateFunctionConfiguration`、`UpdateFunctionCode`、`DeleteFunction` |
| Permission | `AddPermission`、`RemovePermission` |
| Function URL | `CreateFunctionUrlConfig`、`UpdateFunctionUrlConfig`、`DeleteFunctionUrlConfig` |
| Concurrency | `PutFunctionConcurrency`、`DeleteFunctionConcurrency` |
| Alias | `CreateAlias`、`UpdateAlias`、`DeleteAlias` |

### Lambdaイベント確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=lambda.amazonaws.com \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,ResourceName:Resources[0].ResourceName,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 特定Functionの変更履歴

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$FUNCTION_NAME" \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventSource:EventSource,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 誰が、いつ、どのAPIを実行したか確認する
- Function URL、Permission、Role変更を重点確認する
- Event Historyは直近履歴用であり、長期保存要件はTrailまたはEvent Data Storeで確認する
- Functionが0件でも、削除済みFunctionの履歴が残る可能性がある

---

## 19. 証跡保存

Functionが存在する場合、秘密情報を含まない項目だけを保存する。

```bash
aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,FunctionArn:FunctionArn,Runtime:Runtime,PackageType:PackageType,Architectures:Architectures,Role:Role,Handler:Handler,Description:Description,Timeout:Timeout,MemorySize:MemorySize,EphemeralStorage:EphemeralStorage.Size,LastModified:LastModified,State:State,LastUpdateStatus:LastUpdateStatus,VpcConfig:VpcConfig,KMSKeyArn:KMSKeyArn,LoggingConfig:LoggingConfig,TracingConfig:TracingConfig,EnvironmentError:Environment.Error}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/lambda/03_function_security_summary.json"

aws lambda list-event-source-mappings \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/lambda/04_event_source_mappings.json"

aws lambda list-function-url-configs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/lambda/05_function_url_configs.json"

aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/lambda/${FUNCTION_NAME}" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/logs/01_lambda_log_groups.json"
```

Resource-based Policy取得時は、Policyの内容にAccount IDや外部連携情報が含まれる。提出先とマスク要否を確認する。

---

## 20. Webコンソール証跡一覧

| No. | ファイル名 | 内容 |
|---|---|---|
| 1 | `01_操作アカウント確認.png` | 操作アカウント |
| 2 | `02_Lambda_Function一覧確認.png` | Function一覧・0件確認 |
| 3 | `03_Lambda_Function基本設定確認.png` | Runtime、Role、状態 |
| 4 | `04_Lambda_Execution_Role確認.png` | Execution Role |
| 5 | `05_Lambda_Role_Trust_Policy確認.png` | 信頼ポリシー |
| 6 | `06_Lambda_Role_Permissions確認.png` | Role権限 |
| 7 | `07_Lambda_Resource_Policy確認.png` | 呼び出し許可 |
| 8 | `08_Lambda_Trigger確認.png` | Trigger |
| 9 | `09_Lambda_VPC_Config確認.png` | VPC Config |
| 10 | `10_Lambda_Subnet_Route確認.png` | Subnet / Route |
| 11 | `11_Lambda_Security_Group確認.png` | SG |
| 12 | `12_Lambda_環境変数設定有無確認_値なし.png` | 値を含めない環境変数確認 |
| 13 | `13_Lambda_KMS設定確認.png` | KMS |
| 14 | `14_Lambda_LoggingConfig確認.png` | Logging |
| 15 | `15_Lambda_CloudWatch_Log_Group確認.png` | Log Group |
| 16 | `16_Lambda_Function_URL確認.png` | URL、AuthType、CORS |
| 17 | `17_Lambda_Function_URL_Resource_Policy確認.png` | URL呼び出し権限 |

スクリーンショット取得時の注意:

- Environment Variablesの値を含めない
- Secret、Token、Password、個人情報を含めない
- Function CodeやApplication Logの機密情報を含めない
- Function URLを外部共有しない
- 対象名と設定値が識別できる範囲を取得する

---

## 21. 調査結果の記載例

### Function 0件の場合

```text
対象AWSアカウントの東京リージョンについて、Lambda利用状況を確認した。

確認時点でLambda Functionは存在しない。
そのため、Execution Role、Resource-based Policy、VPC Config、
Environment Variables、KMS、CloudWatch Logs、Function URLの
個別確認対象はない。

CloudTrail Event HistoryでLambda関連変更履歴も確認した。
設定変更およびFunction実行は実施していない。
```

### Functionが存在する場合

```text
対象Lambda Functionのセキュリティ設定を確認した。

・Execution Role: Lambda用Trust Policyおよび権限範囲を確認
・Resource-based Policy: Principal、Action、SourceArn、Conditionを確認
・VPC Config: Subnet、SG、NAT / Endpoint経路を確認
・Environment Variables: 秘密情報候補の有無を確認。値は証跡未保存
・KMS: Customer managed key利用状況を確認
・CloudWatch Logs: Log Group、Retention、KMSを確認
・Function URL: AuthType、CORS、Resource Policyを確認

設定変更およびFunction実行は実施していない。
```

## Teams報告例

```text
Lambda Security確認を完了しました。

対象:
・Account: 445405559057
・Region: ap-northeast-1

結果:
・Lambda Function: 0件
・個別設定確認対象: なし
・CloudTrail変更履歴: 確認済み
・設定変更 / Function実行: なし

別アカウント・別リージョンも対象に含む場合は、追加確認が必要です。
```

---

## 22. 良好な設定と改善候補

| 領域 | 良好な状態 | 改善候補 |
|---|---|---|
| Execution Role | 用途別・最小権限 | 管理者権限、FullAccess、Resource `*` |
| Trust Policy | `lambda.amazonaws.com`に限定 | 不要なAccount / Service |
| Resource Policy | PrincipalとSourceを限定 | 無条件`Principal=*` |
| Trigger | 用途と管理主体が明確 | 不要・用途不明Trigger |
| VPC | 必要なFunctionだけ接続 | 経路不明、SG共有、NAT / Endpoint不足 |
| Environment | 秘密情報を外部Secret Storeで管理 | Password、Tokenの平文保存 |
| KMS | 要件どおりのKeyと権限 | Key無効、削除予定、権限不足 |
| Logs | Retention、暗号化、監視あり | Logなし、無期限、秘密情報出力 |
| Function URL | `AWS_IAM`または承認済み公開 | 未承認`NONE`、広いCORS |
| Version / Alias | リリース先が明確 | `$LATEST`だけで変更管理不明 |

---

## 23. 変更時の影響調査観点

## Execution Role変更

- Functionが呼び出すAWS API
- 対象Resource、KMS Key、Secret
- CloudWatch Logs出力権限
- VPC接続時のENI操作権限
- 他FunctionでRoleを共有していないか
- 変更後の正常系・異常系試験

## Resource-based Policy変更

- S3、EventBridge、API Gateway、別アカウントなど全呼び出し元
- Principal、SourceArn、SourceAccount
- Version、Alias、Qualifier
- 削除するStatement ID
- 既存Trigger停止リスク

## VPC Config変更

- 接続先RDS、ElastiCache、Private API
- Subnet、AZ、SG、NACL、Route、DNS
- NAT Gateway、VPC Endpoint
- Lambda ENI作成権限
- 外部API、AWS API、CloudWatch Logsへの到達性

## Environment Variables・KMS変更

- 全既存キーを維持できるか
- Applicationの読取方式
- Secrets Manager / SSMへの移行
- KMS Key PolicyとExecution Role
- 暗号化・復号エラー
- 秘密情報を証跡やログへ残さない方法

## Function URL変更

- 呼び出し元、認証方式、SigV4対応
- Resource-based Policy
- CORS
- 公開範囲、Application認証、監視
- URL変更や削除による利用者影響

---

## 24. 案件で説明できるポイント

- LambdaのExecution RoleとResource-based Policyの違い
- Lambda Functionが0件でも確認結果として成立する
- Function URLの`AWS_IAM`と`NONE`の違い
- `AuthType=NONE`と`Principal=*`の公開リスク
- LambdaをVPCへ接続しても自動的にInternetへ出られない
- VPC接続FunctionではSubnet、SG、NAT、Endpoint、DNSを確認する
- Environment Variablesの値を証跡へ残さない
- 秘密情報はSecrets ManagerやSSM Parameter Store利用を検討する
- KMS変更時はRole権限とKey Policyを確認する
- CloudWatch Logsへ秘密情報を出力しない
- CloudTrailでFunction URL、Permission、設定変更履歴を確認できる

## 資格試験につながるポイント

- Execution RoleはLambdaがAWSサービスを操作する権限である
- Resource-based PolicyはLambdaを呼び出すPrincipalを許可する
- LambdaのVPC接続にはSubnetとSecurity Groupを指定する
- VPC接続LambdaのInternet通信にはNAT Gatewayなどが必要になる
- Interface EndpointはAWS PrivateLinkを使用する
- Function URLの`AWS_IAM`はIAM権限とSigV4署名を必要とする
- Reserved ConcurrencyはFunctionの最大同時実行数を制御する
- Versionは不変、AliasはVersionを参照する
- CloudTrailはLambda設定変更APIを記録する

---

## 25. 要確認事項

実案件では次を担当者、設計書、運用手順書で確認する。

- Lambdaを利用するAWSアカウントとリージョン
- Functionの業務用途、管理主体、重要度
- Execution RoleとIAM Policyの管理主体
- Permission Boundary、SCP、Organization制御
- Trigger、Resource-based Policy、別アカウント連携
- Function URLの利用有無、公開要件、認証方式
- API Gateway、WAF、Application認証との役割分担
- VPC接続、Subnet、SG、NAT、Endpointの設計
- Environment Variablesと秘密情報管理方針
- Secrets Manager、SSM Parameter Store、KMSの利用方針
- CloudWatch Logsの保持期間、暗号化、監視、マスク方針
- Concurrency、Version、Alias、Deployment方式
- Code Signingの統制要件
- CloudTrail、Config、GuardDuty Lambda Protectionの利用状況
- 証跡の保存先、保管期間、持ち出しルール

---

## 26. Day 16完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] Lambda Function一覧と件数を確認した
- [ ] Function 0件の場合の報告方法を整理した
- [ ] Function基本設定を秘密情報なしで確認する方法を確認した
- [ ] Execution Roleの信頼ポリシーを確認する方法を確認した
- [ ] Execution Roleの権限を確認する方法を確認した
- [ ] Resource-based Policyを確認する方法を確認した
- [ ] TriggerとEvent Source Mappingを確認する方法を確認した
- [ ] VPC Config、Subnet、SG、NAT、Endpointの確認方法を確認した
- [ ] Environment Variablesの値を証跡へ残さない理由を説明できる
- [ ] KMS設定と権限の確認方法を確認した
- [ ] CloudWatch LogsとRetentionの確認方法を確認した
- [ ] Function URLのAuthTypeとCORSを確認する方法を確認した
- [ ] `AWS_IAM`と`NONE`の違いを説明できる
- [ ] Concurrency、Version、Alias、Code Signingを確認する方法を確認した
- [ ] CloudTrailでLambda変更履歴を確認する方法を確認した
- [ ] 証跡、結果、改善候補、要確認事項を整理した

## Day 16の完了条件

次を自分の言葉で説明できればDay 16は完了とする。

```text
1. Execution RoleとResource-based Policyの違い
2. Function URLのAWS_IAMとNONEの違い
3. AuthType=NONEとPrincipal=*を重点確認する理由
4. LambdaをVPCへ接続した場合の通信経路
5. Environment Variablesの値を証跡へ保存しない理由
6. Secrets Manager、SSM Parameter Store、KMSの役割
7. CloudWatch Logsで確認する項目
8. Functionが0件の場合の調査結果と報告方法
9. Lambda設定変更時に必要な影響調査、試験、切り戻し
```
