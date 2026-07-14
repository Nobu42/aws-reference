# 要件4番台 監視設定値一覧 設計パラメータ案

作成日: 2026-07-12

この資料は、要件4.1〜4.15のCloudTrail系監視について、CloudWatch Logs、Metric Filter、CloudWatch Alarm、通知先に設定する値を整理するための設計パラメータ案である。

正式な評価シート由来の情報を正とする。ここに記載するFilter Patternや名称は設計案であり、現場の命名規則、既存監視方式、通知先、対象アカウント、対象リージョンの確認後に確定する。

## 1. 前提

正式資料上の4番台は、CloudTrailをCloudWatch Logsに連携し、Metric FilterおよびCloudWatch Alarmで発報する構成が推奨されている。

ただし、既存環境ではEventBridge、GuardDuty、別アカウント連携、メール通知、Teams通知が存在する可能性がある。新規作成前に既存通知との重複を確認する。

## 2. 共通設計値

| 項目 | 設定案 | 確認事項 |
| :--- | :--- | :--- |
| 対象Log Group | CloudTrail Management Event連携先Log Group | Prod / OPER / 管理アカウントで異なる可能性あり |
| Metric Namespace | `<system>/SecurityMonitoring` | 現場命名規則に合わせる |
| Metric Value | `1` | 一致イベント1件を1として加算 |
| Default Value | `0` | 設定可否と運用方針を確認 |
| Statistic | `Sum` | 期間内の検知件数を監視 |
| Period | `300`秒を基本案 | 即時性要件により60秒も候補 |
| Evaluation Periods | `1` | 1期間で検知 |
| Datapoints to Alarm | `1` | 1回検知でALARM |
| Threshold | `>= 1` | 1件以上で発報 |
| Treat missing data | `notBreaching` | ログがない状態を正常扱い |
| Alarm Action | 既存SNS Topicまたは新規SNS Topic | メール / Teams / 監視基盤を確認 |
| OK Action | 原則なし、または運用方針に従う | OK通知が必要か確認 |
| Insufficient Data Action | 原則なし | 不要通知を避ける |

## 3. 命名案

現場命名規則が未確定の場合の仮案である。

| 種別 | 命名案 |
| :--- | :--- |
| Metric Filter | `<system>-security-<requirement>-<event>` |
| Metric Name | `<Requirement><EventName>Count` |
| Alarm Name | `<system>-security-<requirement>-<event>-alarm` |
| SNS Topic | `<system>-security-alert-topic` |

例:

| 要件 | Metric Filter案 | Metric Name案 | Alarm Name案 |
| :--- | :--- | :--- | :--- |
| 4.8 | `<system>-security-4-8-s3-bucket-policy-change` | `Req48S3BucketPolicyChangeCount` | `<system>-security-4-8-s3-bucket-policy-change-alarm` |

## 4. 要件別設定値案

Filter PatternはCloudWatch LogsのMetric Filter用候補である。作成前に、対象Log GroupのサンプルCloudTrailイベントでテストする。

| 要件 | 監視対象 | Metric Name案 | Filter Pattern |
| :--- | :--- | :--- | :--- |
| 4.1 | 不正なAPI呼び出し | `Req41UnauthorizedApiCallCount` | 後続コードブロック参照 |
| 4.2 | MFAなし管理コンソールサインイン | `Req42ConsoleLoginWithoutMfaCount` | 後続コードブロック参照 |
| 4.3 | rootアカウント使用 | `Req43RootAccountUsageCount` | 後続コードブロック参照 |
| 4.4 | IAMポリシー変更 | `Req44IamPolicyChangeCount` | 後続コードブロック参照 |
| 4.5 | CloudTrail設定変更 | `Req45CloudTrailChangeCount` | 後続コードブロック参照 |
| 4.6 | AWS Management Console認証失敗 | `Req46ConsoleLoginFailureCount` | 後続コードブロック参照 |
| 4.7 | CMK無効化または削除予約 | `Req47KmsKeyDisableOrDeletionCount` | 後続コードブロック参照 |
| 4.8 | S3バケットポリシー変更 | `Req48S3BucketPolicyChangeCount` | 後続コードブロック参照 |
| 4.9 | AWS Config設定変更 | `Req49ConfigChangeCount` | 後続コードブロック参照 |
| 4.10 | Security Group変更 | `Req410SecurityGroupChangeCount` | 後続コードブロック参照 |
| 4.11 | NACL変更 | `Req411NetworkAclChangeCount` | 後続コードブロック参照 |
| 4.12 | Network Gateway変更 | `Req412NetworkGatewayChangeCount` | 後続コードブロック参照 |
| 4.13 | Route Table変更 | `Req413RouteTableChangeCount` | 後続コードブロック参照 |
| 4.14 | VPC変更 | `Req414VpcChangeCount` | 後続コードブロック参照 |
| 4.15 | AWS Organizations変更 | `Req415OrganizationsChangeCount` | 後続コードブロック参照 |

GitHub表示でCloudWatch LogsのJSON Filter Patternが数式扱いされることを避けるため、Filter Patternは表内ではなくコードブロックで記載する。

### 4.1 不正なAPI呼び出し

```text
{ ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }
```

### 4.2 MFAなし管理コンソールサインイン

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Success") && ($.additionalEventData.MFAUsed = "No") }
```

### 4.3 rootアカウント使用

```text
{ ($.userIdentity.type = "Root") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != "AwsServiceEvent") }
```

### 4.4 IAMポリシー変更

```text
{ ($.eventSource = "iam.amazonaws.com") && (($.eventName = "CreatePolicy") || ($.eventName = "DeletePolicy") || ($.eventName = "CreatePolicyVersion") || ($.eventName = "DeletePolicyVersion") || ($.eventName = "SetDefaultPolicyVersion") || ($.eventName = "PutUserPolicy") || ($.eventName = "PutGroupPolicy") || ($.eventName = "PutRolePolicy") || ($.eventName = "DeleteUserPolicy") || ($.eventName = "DeleteGroupPolicy") || ($.eventName = "DeleteRolePolicy") || ($.eventName = "AttachUserPolicy") || ($.eventName = "AttachGroupPolicy") || ($.eventName = "AttachRolePolicy") || ($.eventName = "DetachUserPolicy") || ($.eventName = "DetachGroupPolicy") || ($.eventName = "DetachRolePolicy")) }
```

### 4.5 CloudTrail設定変更

```text
{ ($.eventSource = "cloudtrail.amazonaws.com") && (($.eventName = "CreateTrail") || ($.eventName = "UpdateTrail") || ($.eventName = "DeleteTrail") || ($.eventName = "StartLogging") || ($.eventName = "StopLogging") || ($.eventName = "PutEventSelectors") || ($.eventName = "PutInsightSelectors")) }
```

### 4.6 AWS Management Console認証失敗

```text
{ ($.eventName = "ConsoleLogin") && ($.responseElements.ConsoleLogin = "Failure") }
```

### 4.7 CMK無効化または削除予約

```text
{ ($.eventSource = "kms.amazonaws.com") && (($.eventName = "DisableKey") || ($.eventName = "ScheduleKeyDeletion")) }
```

### 4.8 S3バケットポリシー変更

```text
{ ($.eventSource = "s3.amazonaws.com") && (($.eventName = "PutBucketPolicy") || ($.eventName = "DeleteBucketPolicy")) }
```

### 4.9 AWS Config設定変更

```text
{ ($.eventSource = "config.amazonaws.com") && (($.eventName = "StopConfigurationRecorder") || ($.eventName = "StartConfigurationRecorder") || ($.eventName = "PutConfigurationRecorder") || ($.eventName = "DeleteConfigurationRecorder") || ($.eventName = "PutDeliveryChannel") || ($.eventName = "DeleteDeliveryChannel") || ($.eventName = "PutConfigRule") || ($.eventName = "DeleteConfigRule")) }
```

### 4.10 Security Group変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "AuthorizeSecurityGroupIngress") || ($.eventName = "AuthorizeSecurityGroupEgress") || ($.eventName = "RevokeSecurityGroupIngress") || ($.eventName = "RevokeSecurityGroupEgress") || ($.eventName = "CreateSecurityGroup") || ($.eventName = "DeleteSecurityGroup") || ($.eventName = "ModifySecurityGroupRules")) }
```

### 4.11 NACL変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateNetworkAcl") || ($.eventName = "DeleteNetworkAcl") || ($.eventName = "CreateNetworkAclEntry") || ($.eventName = "DeleteNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclEntry") || ($.eventName = "ReplaceNetworkAclAssociation")) }
```

### 4.12 Network Gateway変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateInternetGateway") || ($.eventName = "DeleteInternetGateway") || ($.eventName = "AttachInternetGateway") || ($.eventName = "DetachInternetGateway") || ($.eventName = "CreateCustomerGateway") || ($.eventName = "DeleteCustomerGateway")) }
```

### 4.13 Route Table変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateRoute") || ($.eventName = "DeleteRoute") || ($.eventName = "ReplaceRoute") || ($.eventName = "CreateRouteTable") || ($.eventName = "DeleteRouteTable") || ($.eventName = "AssociateRouteTable") || ($.eventName = "DisassociateRouteTable") || ($.eventName = "ReplaceRouteTableAssociation")) }
```

### 4.14 VPC変更

```text
{ ($.eventSource = "ec2.amazonaws.com") && (($.eventName = "CreateVpc") || ($.eventName = "DeleteVpc") || ($.eventName = "ModifyVpcAttribute") || ($.eventName = "AcceptVpcPeeringConnection") || ($.eventName = "CreateVpcPeeringConnection") || ($.eventName = "DeleteVpcPeeringConnection") || ($.eventName = "RejectVpcPeeringConnection")) }
```

### 4.15 AWS Organizations変更

```text
{ ($.eventSource = "organizations.amazonaws.com") }
```

## 5. 要件別補足

| 要件 | 補足確認 |
| :--- | :--- |
| 4.1 | `AccessDenied`系は通常運用でも発生し得る。通知閾値を1件にするか、短時間の複数件にするか確認する |
| 4.2 | MFA強制済みの場合、元資料上は不要判断の可能性あり。不要とする場合も根拠を残す |
| 4.3 | root利用は高リスクのため、1件で発報が妥当 |
| 4.4 | IAM Policy以外のIAM変更まで含めるか確認する |
| 4.5 | `StartLogging`を含めると復旧操作でも通知される。運用上許容する |
| 4.6 | 失敗ログインは誤入力でも発生する。通知閾値を要確認 |
| 4.7 | CMK無効化・削除予約は重要度が高く、1件発報が妥当 |
| 4.8 | 既存EventBridge別アカウント送信との重複を確認する |
| 4.9 | AWS Configが未導入または一部環境のみの場合、対象範囲を確認する |
| 4.10 | 通常変更でも通知されるため、変更管理番号との突合が必要 |
| 4.11 | NACL変更は影響が大きい。変更管理と突合する |
| 4.12 | 正式資料はInternet Gateway / Customer Gateway中心。NAT Gateway、Transit Gateway、VPN Gatewayを含めるか要確認 |
| 4.13 | ルート追加・変更は通信経路に直結する。通知後の確認観点を手順化する |
| 4.14 | VPC Peeringを含める。VPC EndpointやSubnet変更まで含めるかは要確認 |
| 4.15 | Organizationsは管理アカウント側での確認が必要な場合がある |

## 6. 設定確定前チェック

| No. | 確認項目 | 状態 |
| :--- | :--- | :--- |
| 1 | 対象アカウントが確定している | 未確認 |
| 2 | 対象リージョンが確定している | 未確認 |
| 3 | CloudTrail連携先Log Groupが確定している | 未確認 |
| 4 | Metric Namespaceが現場命名規則と合っている | 未確認 |
| 5 | Alarm名が現場命名規則と合っている | 未確認 |
| 6 | 通知先SNS Topicが確定している | 未確認 |
| 7 | メール通知先が確定している | 未確認 |
| 8 | Teams通知経路が確定している | 未確認 |
| 9 | 既存EventBridge通知との重複を確認済み | 未確認 |
| 10 | 通知テストの実施可否が承認済み | 未確認 |
