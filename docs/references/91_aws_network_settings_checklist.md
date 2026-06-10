# 91 AWS Network Settings 横断チェックリスト

## 1. このドキュメントの目的

このドキュメントは、AWS環境のネットワーク設定をサービス横断で確認するための索引である。

個別の詳細コマンドは各リファレンスに分けているため、このドキュメントでは「どの通信経路を」「どの順番で」「どの設定を見て」「どのリファレンスへ進むか」を整理する。

想定する作業は、銀行系システムのAWSセキュリティ・ネットワーク改善案件で発生しそうな以下の内容である。

- VPC / Subnet / Route Table設定の確認
- Security Group / Network ACLの影響調査
- VPC Endpoint、NAT Gateway、Internet Gatewayの確認
- EC2 / RDS / Lambda / ElastiCache / ALBの通信経路確認
- DNS / Route 53 Private Hosted Zoneの確認
- VPC Flow LogsやReachability Analyzerによる調査
- 設定変更後の疎通確認
- 作業手順書、切り戻し手順、証跡の作成

このドキュメントで重視する観点:

- 通信元
- 通信先
- Protocol / Port
- Route Table
- Security Group
- Network ACL
- DNS
- VPC Endpoint
- Flow Logs
- 影響範囲
- 切り戻し
- 証跡

## 2. 使い方

まずこの横断チェックリストで通信経路の全体像を確認し、詳細は該当リファレンスへ進む。

```text
91_aws_network_settings_checklist.md
  ↓
通信要件を整理する
  ↓
Source / Destination / Portを決める
  ↓
VPC、Subnet、Route、SG、NACL、DNSを順番に確認する
  ↓
必要に応じて個別CLIリファレンスへ進む
  ↓
変更前確認、変更、変更後確認、切り戻しを実施
  ↓
Flow Logs、CloudTrail、スクリーンショットを証跡化する
```

関連リファレンス:

| No. | リファレンス | 主な用途 |
| :--- | :--- | :--- |
| 00 | [共通AWS CLI・証跡保存リファレンス](./00_common_aws_cli_reference.md) | Account / Profile / Region確認、証跡保存 |
| 03 | [CloudTrail CLIリファレンス](./03_cloudtrail_cli_reference.md) | ネットワーク設定変更履歴 |
| 04 | [CloudWatch CLIリファレンス](./04_cloudwatch_cli_reference.md) | Flow Logs、Alarm、ログ検索 |
| 07 | [VPC/Network CLIリファレンス](./07_vpc_network_cli_reference.md) | VPC、Subnet、Route、SG、NACL、Endpoint、Flow Logs |
| 08 | [EC2 Security CLIリファレンス](./08_ec2_security_cli_reference.md) | EC2、Public IP、SG、IAM Role、IMDSv2 |
| 09 | [RDS Security CLIリファレンス](./09_rds_security_cli_reference.md) | RDS Public設定、Subnet Group、SG |
| 10 | [Lambda Security CLIリファレンス](./10_lambda_security_cli_reference.md) | Lambda VPC、SG、Endpoint、Function URL |
| 90 | [AWS Security Settings 横断チェックリスト](./90_aws_security_settings_checklist.md) | サービス横断のセキュリティ確認 |
| 汎用 | [AWSネットワーク調査用CLIリファレンス](./aws_network_cli_reference.md) | ネットワーク調査コマンド辞書 |

## 3. ネットワーク調査の基本順序

AWSネットワークの疎通確認では、以下の順番で見る。

```text
Source
  ↓
Source Security Group outbound
  ↓
Source Subnet NACL outbound
  ↓
Source Subnet Route Table
  ↓
Gateway / NAT Gateway / Transit Gateway / VPC Endpoint / Peering
  ↓
Destination Subnet Route Table
  ↓
Destination Subnet NACL inbound
  ↓
Destination Security Group inbound
  ↓
Destination
  ↓
Application / Listener / Health Check
```

重要:

```text
Security GroupはStateful。
Network ACLはStateless。
Route TableはSubnet単位で効く。
Subnetに明示的なRoute Table関連付けがない場合は、Main Route Tableが使われる。
```

ネットワーク調査で最初に決める5点:

| No. | 項目 | 例 |
| :--- | :--- | :--- |
| 1 | 通信元 | Web EC2、Lambda、踏み台、ALB |
| 2 | 通信先 | RDS、ElastiCache、S3、外部API、オンプレ |
| 3 | Protocol | TCP、UDP、ICMP |
| 4 | Port | 443、80、22、3000、3306、6379 |
| 5 | 通信方向 | Inbound、Outbound、双方向、戻り通信 |

## 4. 重要度の目安

| 重要度 | 意味 | 例 |
| :--- | :--- | :--- |
| Critical | 外部公開、通信遮断、重要DB到達性など重大影響に直結 | RDS Public、SG 0.0.0.0/0:3306、誤ったDefault Route |
| High | 障害、監査不備、運用影響につながる | NAT経路不備、VPC Endpoint不足、Flow Logsなし |
| Medium | 調査困難、設計不明瞭、将来の障害につながる | SG説明なし、タグ不足、NACL複雑化 |
| Low | 標準化、可読性、運用改善 | 命名規則、証跡配置、図面更新 |

案件での優先順位:

```text
1. 意図しない外部公開がないか
2. 重要通信が遮断されないか
3. Route Tableの向きが正しいか
4. SG / NACLが必要最小限か
5. DNSが想定どおり解決されるか
6. AWSサービス向け通信がNATかEndpointか整理されているか
7. Flow LogsやCloudTrailで説明できるか
8. 切り戻せるか
```

## 5. 作業前の共通確認

### 5.1 操作先アカウント確認

```bash
PROFILE="learning"
REGION="ap-northeast-1"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table
```

証跡保存:

```bash
WORK_NAME="aws_network_settings_check"
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

### 5.2 変更前に確認すること

| 確認項目 | 内容 |
| :--- | :--- |
| Account | 操作先AWSアカウントが正しいか |
| Region | 対象リージョンが正しいか |
| VPC | 対象VPC IDが明確か |
| 通信要件 | Source、Destination、Port、Protocolが明確か |
| 対象Subnet | Public / Private / AZ / CIDRが明確か |
| 対象Route Table | 変更対象と関連Subnetが明確か |
| 対象SG | 変更対象SGと関連リソースが明確か |
| 対象NACL | Subnet関連付けとRule番号が明確か |
| DNS | Private Hosted Zone、Resolver、VPC DNS属性を確認したか |
| 承認 | 作業申請・変更承認があるか |
| 切り戻し | 変更前設定を保存したか |
| 証跡 | CLI結果、スクリーンショット、差分を残せるか |

## 6. サービス横断ネットワークチェック一覧

### 6.1 全体チェック

| No. | 領域 | 確認項目 | 重要度 | 詳細 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | VPC | CIDR、DNS属性、Default VPC有無 | High | 07 |
| 2 | Subnet | Public / Private、AZ、CIDR、Route関連付け | High | 07 |
| 3 | Route Table | `0.0.0.0/0`、TGW、NAT、IGW、Endpoint経路 | Critical | 07 |
| 4 | IGW | VPC Attach、Public Subnet経路 | High | 07 |
| 5 | NAT Gateway | Private Subnet outbound、AZ冗長、Cost | High | 07 |
| 6 | Security Group | Inbound / Outbound、Source、Port | Critical | 07 |
| 7 | NACL | Stateless、Ephemeral port、Rule順序 | High | 07 |
| 8 | ENI | EC2 / RDS / Lambda / EndpointのNIC | High | 07 |
| 9 | VPC Endpoint | S3、DynamoDB、KMS、Secrets Managerなど | High | 07 |
| 10 | DNS | VPC DNS属性、Private Hosted Zone、Resolver | High | 07 |
| 11 | ALB/NLB | Scheme、Listener、Target Health、SG | High | 07 |
| 12 | RDS | Public設定、DB Subnet Group、SG | Critical | 09 |
| 13 | Lambda | VPC Config、Subnet、SG、Endpoint/NAT | High | 10 |
| 14 | Flow Logs | ACCEPT / REJECT調査、保存先 | High | 07、04 |
| 15 | CloudTrail | ネットワーク設定変更履歴 | High | 03 |

### 6.2 変更作業で必ず見る横断チェック

| フェーズ | 確認項目 | 証跡 |
| :--- | :--- | :--- |
| 変更前 | 対象VPC / Subnet / Route / SG / NACL | `before/*.json` |
| 変更前 | 対象リソースの関連ENI | `describe-network-interfaces` |
| 変更前 | DNS解決結果 | `dig`、`nslookup` |
| 変更前 | 疎通結果 | `curl`、`nc`、`mysql`、`redis-cli` |
| 変更前 | Flow Logs / CloudTrail | `investigation/*.json` |
| 変更 | 実行コマンドまたはGUI操作 | 作業ログ、スクリーンショット |
| 変更後 | 設定値が期待どおりか | `after/*.json` |
| 変更後 | 疎通確認 | 成功・失敗を保存 |
| 変更後 | アプリ・監視への影響 | Target Health、CloudWatch Logs |
| 切り戻し | 変更前設定へ戻せるか | rollbackコマンド |

## 7. VPC確認

VPCでは、CIDR、DNS属性、Default VPC、DHCP Option Set、タグを確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| VPC ID | 対象が明確 | High | Nameタグだけで判断しない |
| CIDR | 設計書と一致 | High | オンプレや他VPCと重複しない |
| enableDnsSupport | `true` | High | Route 53 Resolver利用に必要 |
| enableDnsHostnames | `true` | Medium | Private Hosted Zoneで重要 |
| IsDefault | 本番相当では意図を確認 | Medium | Default VPC利用方針 |
| DHCP Option Set | 想定DNS / Domain | Medium | 独自DNS利用時に重要 |

代表コマンド:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[*].{VpcId:VpcId,Cidr:CidrBlock,State:State,IsDefault:IsDefault,OwnerId:OwnerId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

VPC_ID="vpc-xxxxxxxx"

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames
```

証跡:

- VPC一覧
- VPC属性
- DHCP Option Set
- タグ
- 設計書との照合結果

## 8. Subnet確認

Subnetでは、Public / Privateの役割、AZ、Route Table関連付け、NACL関連付け、Public IP自動割当を確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Subnet ID | 対象が明確 | High | VPC IDとセットで確認 |
| AZ | 冗長化要件どおり | High | Multi-AZ構成 |
| CIDR | 設計書と一致 | High | IP枯渇も確認 |
| MapPublicIpOnLaunch | Private Subnetでは原則 `false` | High | Public化リスク |
| Route Table | 役割と一致 | Critical | Public/Private判定の中心 |
| NACL | 想定NACLに関連付け | High | Stateless影響 |
| AvailableIpAddressCount | 余裕あり | Medium | LambdaやEndpoint ENIで消費 |

代表コマンド:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{SubnetId:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock,AvailableIPs:AvailableIpAddressCount,MapPublicIp:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

Public / Private判定:

```text
Public Subnet:
  Route Tableに 0.0.0.0/0 -> Internet Gateway がある

Private Subnet:
  Route Tableに 0.0.0.0/0 -> NAT Gateway / Transit Gateway などがある
  または外部向けDefault Routeがない
```

証跡:

- Subnet一覧
- Public IP自動割当
- Route Table関連付け
- NACL関連付け
- IP空き状況

## 9. Route Table確認

Route Tableは通信経路の中心である。特にDefault Route、Main Route Table、明示関連付けの有無を見る。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Main Route Table | 暗黙関連付けSubnetを把握 | High | 予期せぬ経路に注意 |
| Subnet Association | 対象Subnetが想定RTBに関連 | Critical | 明示関連付けを確認 |
| Local route | VPC CIDR向けlocal | High | VPC内通信 |
| `0.0.0.0/0 -> igw-*` | Public Subnetのみ | Critical | 外部公開 |
| `0.0.0.0/0 -> nat-*` | Private outbound | High | AZ障害影響 |
| `0.0.0.0/0 -> tgw-*` | 集約経路 | High | 送信先制御 |
| `pl-* -> vpce-*` | S3/DynamoDB Gateway Endpoint | High | NAT迂回 |
| Blackhole | なし、または意図明確 | High | 通信断原因 |

代表コマンド:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],Associations:Associations[*].{SubnetId:SubnetId,Main:Main},Routes:Routes[*].{Destination:DestinationCidrBlock,PrefixList:DestinationPrefixListId,Gateway:GatewayId,Nat:NatGatewayId,Tgw:TransitGatewayId,Vpce:VpcEndpointId,State:State}}' \
  --output json \
  > "$EVIDENCE_DIR/before/route_tables.json"
```

画面確認用:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].Routes[*].{Destination:DestinationCidrBlock,PrefixList:DestinationPrefixListId,Gateway:GatewayId,Nat:NatGatewayId,Tgw:TransitGatewayId,Vpce:VpcEndpointId,State:State}' \
  --output table
```

切り戻し:

```text
Route追加前に既存Route Tableを保存する。
誤ったRouteを追加した場合は delete-route で削除し、必要に応じて create-route で元のTargetへ戻す。
Subnet関連付けを変えた場合は、元のRouteTableAssociationIdを保存して戻す。
```

## 10. Internet Gateway / NAT Gateway確認

### 10.1 Internet Gateway

Internet GatewayはVPCをインターネットへ接続するためのGatewayである。存在だけでPublicになるわけではなく、Subnet Route Tableの経路とPublic IPも合わせて見る。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| IGW Attach | 対象VPCにAttach | High |
| Public Subnet Route | `0.0.0.0/0 -> igw-*` | Critical |
| 対象リソースPublic IP | Public通信対象だけ | Critical |
| SG Inbound | 公開Portのみ | Critical |

代表コマンド:

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --output table
```

### 10.2 NAT Gateway

NAT GatewayはPrivate Subnetのリソースが外部へ出るために使う。外部からPrivate Subnetへ開始されるInbound通信を許可するものではない。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| State | `available` | High |
| Subnet | Public NATはPublic Subnet | High |
| EIP | Public NATでは関連付け | Medium |
| Private Route | Private Subnetから `0.0.0.0/0 -> nat-*` | High |
| AZ | 可能なら同一AZ NATへ向く | Medium |
| Cost | 不要なNATを残さない | Medium |

代表コマンド:

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --query 'NatGateways[*].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId,ConnectivityType:ConnectivityType,PublicIp:NatGatewayAddresses[0].PublicIp,PrivateIp:NatGatewayAddresses[0].PrivateIp}' \
  --output table
```

よくある誤解:

```text
Private Subnetからインターネットへ出るにはNAT Gatewayが必要なことが多い。
ただしS3やDynamoDBなどはGateway EndpointでNATを通さず通信できる。
Secrets Manager、KMS、SQSなどはInterface Endpointを使う選択肢がある。
```

## 11. Security Group確認

Security GroupはStatefulな仮想Firewallである。Inboundを許可すると戻り通信は自動で許可される。Outboundも設計に応じて確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Inbound CIDR | 必要最小限 | Critical | `0.0.0.0/0` に注意 |
| Inbound SG参照 | アプリSGなどに限定 | Critical | DB/Redisで重要 |
| Outbound | 必要な宛先のみ、または設計で許可 | High | 厳格環境では絞る |
| Port | 必要Portのみ | Critical | 22、3389、3306、6379 |
| Description | 変更理由が分かる | Medium | レビューで重要 |
| 関連リソース | 影響範囲を把握 | High | 同じSGを複数リソースが利用 |

代表コマンド:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/security_groups.json"

aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="sg-xxxxxxxx" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,IsEgress:IsEgress,Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:CidrIpv4,ReferencedGroup:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table
```

危険な例:

| ルール | リスク |
| :--- | :--- |
| `0.0.0.0/0:22` | SSH公開 |
| `0.0.0.0/0:3389` | RDP公開 |
| `0.0.0.0/0:3306` | MySQL公開 |
| `0.0.0.0/0:5432` | PostgreSQL公開 |
| `0.0.0.0/0:6379` | Redis公開 |
| `0.0.0.0/0:0-65535` | 全開放 |

切り戻し:

```text
変更前のSecurityGroupRuleIdを保存する。
追加したルールは revoke-security-group-ingress / revoke-security-group-egress で削除する。
削除したルールは authorize-security-group-ingress / authorize-security-group-egress で戻す。
```

## 12. Network ACL確認

Network ACLはSubnet単位で効くStatelessな制御である。InboundとOutboundの両方を明示的に許可する必要がある。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| Subnet Association | 対象Subnetに関連付け | High | 影響範囲 |
| Rule Number | 小さい番号から評価 | High | 順序が重要 |
| Allow / Deny | 意図が明確 | High | Denyが先にあると遮断 |
| Inbound | 必要Portを許可 | High | Destination側 |
| Outbound | 戻り通信も許可 | High | Stateless |
| Ephemeral Port | 1024-65535などを考慮 | High | 戻り通信 |

代表コマンド:

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[*].{NetworkAclId:NetworkAclId,IsDefault:IsDefault,Associations:Associations[*].SubnetId,Entries:Entries[*].{RuleNumber:RuleNumber,Egress:Egress,Protocol:Protocol,RuleAction:RuleAction,Cidr:CidrBlock,FromPort:PortRange.From,ToPort:PortRange.To}}' \
  --output json \
  > "$EVIDENCE_DIR/before/network_acls.json"
```

よくある原因:

```text
Security Groupは許可しているのに通信できない。
→ NACLのOutboundまたは戻り通信のEphemeral Portが閉じている。
```

## 13. ENI確認

ENIはネットワーク調査で非常に重要である。EC2、RDS、Lambda、VPC Endpoint、NAT Gateway、ALBなど、多くのサービスがENIを持つ。

| 確認項目 | 内容 |
| :--- | :--- |
| NetworkInterfaceId | ENI ID |
| Description | どのサービスのENIか |
| PrivateIpAddress | 通信元/通信先IP |
| Groups | 関連Security Group |
| SubnetId | 配置Subnet |
| Attachment | 関連リソース |
| Status | in-use / available |

代表コマンド:

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkInterfaces[*].{ENI:NetworkInterfaceId,Description:Description,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Groups:Groups[*].GroupId,Attachment:Attachment.InstanceId}' \
  --output table
```

調査で使う場面:

- Flow LogsのInterface IDから対象リソースを特定する
- LambdaのVPC接続先を確認する
- Interface EndpointのSGを確認する
- RDSのPrivate IPとSubnetを確認する
- ALBやNATのENIを確認する

## 14. VPC Endpoint確認

VPC Endpointは、VPC内からAWSサービスへPrivate経路でアクセスするために使う。NAT Gatewayを通さずに通信できる場合があるため、セキュリティとコストの両面で重要である。

| Endpoint種類 | 代表サービス | 確認ポイント |
| :--- | :--- | :--- |
| Gateway Endpoint | S3、DynamoDB | Route TableにPrefix List経路が入る |
| Interface Endpoint | KMS、Secrets Manager、SQS、SNS、CloudWatch Logsなど | ENI、SG、Private DNS |
| Gateway Load Balancer Endpoint | Firewall / Appliance | 検査経路 |

代表コマンド:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,ServiceName:ServiceName,Type:VpcEndpointType,State:State,RouteTableIds:RouteTableIds,SubnetIds:SubnetIds,Groups:Groups[*].GroupId,PrivateDnsEnabled:PrivateDnsEnabled}' \
  --output table
```

確認ポイント:

- 対象サービスのEndpointが存在するか
- Gateway EndpointのRoute Table関連付けが対象Subnetに効くか
- Interface EndpointのSGが通信元から443を許可しているか
- Private DNSが有効か
- Endpoint policyでアクセス先が制限されているか

S3 Endpoint利用時の注意:

```text
S3 Gateway Endpointを作ると、対象Route TableにS3 Prefix List向け経路が追加される。
Bucket Policyで aws:sourceVpce や aws:sourceVpc を使っている場合、
既存アプリや別経路のアクセスに影響する可能性がある。
```

## 15. DNS / Route 53確認

AWSネットワークではDNSが原因の障害も多い。Private Hosted Zone、VPC DNS属性、Resolver、Public / Privateの名前空間重複を確認する。

| 確認項目 | 期待値 | 重要度 | 補足 |
| :--- | :--- | :--- | :--- |
| enableDnsSupport | `true` | High | VPC Resolver利用 |
| enableDnsHostnames | `true` | High | Private Hosted Zoneで重要 |
| Private Hosted Zone | 対象VPCに関連付け | High | 内部DNS |
| Public Hosted Zone | 外部公開レコード | High | ALB、Bastionなど |
| Split-view DNS | 意図が明確 | Medium | 同名Public/Private Zone |
| Resolver Rule | オンプレ連携時に確認 | High | Forwarding |

代表コマンド:

```bash
aws route53 list-hosted-zones-by-vpc \
  --profile "$PROFILE" \
  --vpc-id "$VPC_ID" \
  --vpc-region "$REGION" \
  --output table

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames
```

疎通確認:

```bash
dig example.internal
dig www.example.com
nslookup example.internal
```

確認ポイント:

- EC2 / Lambda / RDSから同じ名前を引いた時に同じ結果になるか
- Private Hosted Zoneが対象VPCに関連付いているか
- PublicとPrivateで同じ名前空間を使っていないか
- 独自DNSやオンプレDNSを使う場合、Resolver Ruleがあるか

## 16. ALB / NLB確認

Load Balancerは通信入口になるため、Scheme、Subnet、Security Group、Listener、Target Group、Health Checkを確認する。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| Scheme | internet-facing / internalが要件どおり | Critical |
| Subnet | Public ALBはPublic Subnet | High |
| Security Group | 公開Portのみ許可 | Critical |
| Listener | 80 / 443 / TLS Policy | High |
| Target Group | Port / Protocolがアプリと一致 | High |
| Target Health | Healthy | High |
| Access Logs | 要件に応じて有効 | Medium |

代表コマンド:

```bash
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,Scheme:Scheme,Type:Type,VpcId:VpcId,DNSName:DNSName,State:State.Code,Subnets:AvailabilityZones[*].SubnetId,SecurityGroups:SecurityGroups}' \
  --output table

aws elbv2 describe-target-health \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --output table
```

よくある原因:

```text
ALBはactiveだがアクセスできない:
- ALB SG inboundが閉じている
- Target SGがALB SGからのPortを許可していない
- Target Group PortがアプリPortと違う
- Health Check pathが違う
- Private Subnet側のNACLが戻り通信を落としている
```

## 17. EC2ネットワーク確認

EC2ではPublic IP、Subnet、SG、Route、NACL、OS側Firewall、アプリListen Portを確認する。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| Public IP | Private用途ではなし | High | 08 |
| Subnet | Public / Privateの役割どおり | High | 07 |
| Security Group | 管理Portを限定 | Critical | 08 |
| Route | 用途に合ったDefault Route | High | 07 |
| NACL | 双方向許可 | High | 07 |
| OS Firewall | firewalld / iptables確認 | Medium | OS |
| Listen Port | アプリが待受中 | High | EC2内確認 |

代表コマンド:

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[*].GroupId}' \
  --output table
```

EC2内確認例:

```bash
ss -lntp
ip route
curl -I http://localhost:3000
```

## 18. RDSネットワーク確認

RDSではPublic設定、DB Subnet Group、SG、DNS Endpoint、接続元を確認する。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| PubliclyAccessible | `false` | Critical | 09 |
| DB Subnet Group | Private Subnet | Critical | 09 |
| VPC SG | アプリSGからDB Portのみ | Critical | 09 |
| Endpoint DNS | 想定Endpoint | High | 09 |
| Port | 3306、5432など | High | 09 |
| NACL | 双方向許可 | High | 07 |

代表コマンド:

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Public:PubliclyAccessible,Endpoint:Endpoint.Address,Port:Endpoint.Port,VpcId:DBSubnetGroup.VpcId,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,SG:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table
```

疎通確認:

```bash
mysql -h "$RDS_ENDPOINT" -P 3306 -u adminuser -p
```

## 19. Lambdaネットワーク確認

LambdaはVPCに入れると、指定Subnet / SGに基づいて通信する。外部APIやAWS APIへ出る場合、NAT GatewayまたはVPC Endpointの有無が重要になる。

| 確認項目 | 期待値 | 重要度 | リファレンス |
| :--- | :--- | :--- | :--- |
| VPC Config | 必要なFunctionのみ設定 | High | 10 |
| Subnet | Private Subnet、複数AZ | High | 10 |
| Security Group | 接続先に必要なOutbound | High | 10 |
| NAT / Endpoint | 外部API / AWS API通信経路 | High | 10 |
| DNS | VPC DNS属性 | High | 15章 |
| Logs | 接続失敗ログ確認 | High | 04、10 |

代表コマンド:

```bash
FUNCTION_NAME="sample-function"

aws lambda get-function-configuration \
  --profile "$PROFILE" \
  --region "$REGION" \
  --function-name "$FUNCTION_NAME" \
  --query '{FunctionName:FunctionName,VpcConfig:VpcConfig,LastUpdateStatus:LastUpdateStatus}' \
  --output table
```

よくある原因:

```text
LambdaをVPCに入れた後に外部APIへ接続できない:
- Private SubnetにNAT Gateway経路がない
- 必要なInterface Endpointがない
- Endpoint SGがLambda SGから443を許可していない
- DNS解決ができない
```

## 20. S3 / AWSサービス向け通信確認

S3やAWS APIへの通信は、NAT Gateway経由かVPC Endpoint経由かを整理する。

| 通信先 | 経路候補 | 確認ポイント |
| :--- | :--- | :--- |
| S3 | Gateway Endpoint、Interface Endpoint、NAT | Bucket Policyの `aws:sourceVpce` |
| DynamoDB | Gateway Endpoint、NAT | Route TableのPrefix List |
| KMS | Interface Endpoint、NAT | Endpoint SG、Private DNS |
| Secrets Manager | Interface Endpoint、NAT | Lambda/EC2からの443 |
| CloudWatch Logs | Interface Endpoint、NAT | Agent / Lambdaログ |
| SQS / SNS | Interface Endpoint、NAT | Policy、SG、DNS |

代表コマンド:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output table

aws ec2 describe-prefix-lists \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'PrefixLists[*].{PrefixListId:PrefixListId,PrefixListName:PrefixListName,Cidrs:Cidrs}' \
  --output table
```

影響調査:

```text
S3 Bucket PolicyでVPC Endpoint制限を追加する場合:
- EC2 / Lambda / Railsアプリがどの経路でS3へアクセスしているか確認
- 対象SubnetのRoute TableにGateway Endpoint経路があるか確認
- 別アカウント、管理端末、CI/CD、バックアップ処理が影響を受けないか確認
```

## 21. ElastiCacheネットワーク確認

ElastiCacheはPrivate Subnet配置が基本で、アプリSGからRedis Portのみ許可する。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| Subnet Group | Private Subnet | High |
| Security Group | Web/App SGから6379のみ | Critical |
| Transit Encryption | 要件に応じて有効 | High |
| Endpoint DNS | アプリ設定と一致 | High |
| NACL | 双方向許可 | High |

代表コマンド:

```bash
aws elasticache describe-replication-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,ClusterEnabled:ClusterEnabled,Endpoint:ConfigurationEndpoint.Address,Port:ConfigurationEndpoint.Port,TransitEncryption:TransitEncryptionEnabled,AtRestEncryption:AtRestEncryptionEnabled}' \
  --output table
```

疎通確認:

```bash
redis-cli -h "$REDIS_ENDPOINT" -p 6379 ping
```

## 22. Hybrid / Cross-account / Transit Gateway確認

金融系案件では、オンプレ、別VPC、別アカウント、データセンター接続が絡むことがある。Transit Gateway、VPN、Direct Connect、VPC Peering、Resolver Ruleを確認する。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| Transit Gateway Attachment | 対象VPC/VPN/DXがAttach | High |
| TGW Route Table | Association / Propagationが意図どおり | Critical |
| VPC Route Table | TGW向け経路あり | Critical |
| VPN / DX | Status、BGP経路 | High |
| VPC Peering | Route双方設定 | High |
| Resolver Rule | オンプレDNS向けForwarding | High |
| CIDR重複 | なし | Critical |

代表コマンド:

```bash
aws ec2 describe-transit-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws ec2 describe-transit-gateway-attachments \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table

aws ec2 describe-transit-gateway-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output table
```

注意:

```text
Transit GatewayはVPC側Route TableとTGW側Route Tableの両方を見る。
片方だけ正しくても通信できない。
```

## 23. Flow Logs確認

VPC Flow Logsは、IP通信のACCEPT / REJECTを確認するための重要な証跡である。

| 確認項目 | 期待値 | 重要度 |
| :--- | :--- | :--- |
| Flow Logs有効化 | VPC / Subnet / ENIのいずれか | High |
| TrafficType | ALL、ACCEPT、REJECTの方針 | High |
| 保存先 | CloudWatch LogsまたはS3 | High |
| IAM Role | Logs出力権限 | Medium |
| Log Format | 調査に必要な項目 | Medium |

代表コマンド:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --output table
```

CloudWatch Logs検索例:

```bash
LOG_GROUP_NAME="/aws/vpc/flowlogs"

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '"REJECT"' \
  --output json \
  > "$EVIDENCE_DIR/investigation/flow_logs_reject.json"
```

確認ポイント:

- Source IP
- Destination IP
- Source Port
- Destination Port
- Protocol
- Action `ACCEPT` / `REJECT`
- Interface ID
- 時刻

## 24. Reachability Analyzer確認

Reachability Analyzerは、AWS上のネットワーク設定を静的に解析し、指定したSourceからDestinationへ到達可能か確認するために使う。

使う場面:

- SG / NACL / Route Tableの組み合わせ確認
- EC2からRDSへ到達できるか
- ALBからTargetへ到達できるか
- VPC Peering / TGW経由の経路確認
- 手作業確認だけでは説明が難しい場合の補助証跡

代表コマンドの流れ:

```bash
SOURCE_ID="eni-xxxxxxxx"
DESTINATION_ID="eni-yyyyyyyy"

PATH_ID=$(aws ec2 create-network-insights-path \
  --profile "$PROFILE" \
  --region "$REGION" \
  --source "$SOURCE_ID" \
  --destination "$DESTINATION_ID" \
  --protocol tcp \
  --destination-port 3306 \
  --query 'NetworkInsightsPath.NetworkInsightsPathId' \
  --output text)

ANALYSIS_ID=$(aws ec2 start-network-insights-analysis \
  --profile "$PROFILE" \
  --region "$REGION" \
  --network-insights-path-id "$PATH_ID" \
  --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' \
  --output text)

aws ec2 describe-network-insights-analyses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --network-insights-analysis-ids "$ANALYSIS_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/reachability_analysis.json"
```

注意:

```text
Reachability Analyzerは静的な設定解析であり、アプリプロセスがListenしているかまでは確認しない。
最終的にはcurl、mysql、redis-cliなど実通信の確認も行う。
```

## 25. CloudTrailで見るネットワーク変更イベント

ネットワーク変更後はCloudTrailで誰が何を変更したか確認する。

代表イベント:

```text
CreateVpc
ModifyVpcAttribute
CreateSubnet
ModifySubnetAttribute
CreateRoute
ReplaceRoute
DeleteRoute
AssociateRouteTable
DisassociateRouteTable
AuthorizeSecurityGroupIngress
RevokeSecurityGroupIngress
AuthorizeSecurityGroupEgress
RevokeSecurityGroupEgress
CreateNetworkAclEntry
ReplaceNetworkAclEntry
DeleteNetworkAclEntry
CreateVpcEndpoint
ModifyVpcEndpoint
DeleteVpcEndpoints
CreateFlowLogs
DeleteFlowLogs
CreateNatGateway
DeleteNatGateway
AttachInternetGateway
DetachInternetGateway
```

代表コマンド:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_ec2_network_events.json"
```

見るポイント:

- EventName
- EventTime
- Username / Role
- SourceIPAddress
- UserAgent
- ErrorCode
- RequestParameters
- ResponseElements

## 26. 疎通確認コマンド集

### 26.1 HTTP / HTTPS

```bash
curl -I http://example.com
curl -I https://example.com
curl -v https://example.com
```

### 26.2 TCP Port

```bash
nc -vz example.com 443
nc -vz db.example.internal 3306
```

### 26.3 DNS

```bash
dig example.com
dig db.home
nslookup example.com
```

### 26.4 MySQL / MariaDB

```bash
mysql -h "$RDS_ENDPOINT" -P 3306 -u adminuser -p
```

### 26.5 Redis

```bash
redis-cli -h "$REDIS_ENDPOINT" -p 6379 ping
```

### 26.6 EC2内

```bash
ip addr
ip route
ss -lntp
curl -I http://localhost:3000
```

## 27. 変更手順書へ落とす時の観点

| 項目 | 書く内容 |
| :--- | :--- |
| 作業名 | 例: Security Group Inbound Rule変更 |
| 対象 | Account、Region、VPC ID、Resource ID |
| 通信要件 | Source、Destination、Protocol、Port |
| 変更前設定 | 現在のRoute / SG / NACL / Endpoint |
| 変更後設定 | 期待する設定 |
| 影響範囲 | アプリ、運用、監視、他システム、オンプレ |
| 作業手順 | CLIまたはGUIの手順 |
| 確認手順 | 疎通、DNS、Flow Logs、CloudTrail |
| 切り戻し | 具体的な戻し方 |
| 証跡 | 保存ファイル、スクリーンショット |
| 連絡先 | Teams、担当者、承認者 |

## 28. 証跡一覧テンプレート

| No. | 証跡 | ファイル例 | 用途 |
| :--- | :--- | :--- | :--- |
| 1 | Caller Identity | `00_caller_identity.json` | 操作先確認 |
| 2 | VPC | `before/vpc.json` | 対象VPC確認 |
| 3 | Subnet | `before/subnets.json` | 配置確認 |
| 4 | Route Table | `before/route_tables.json` | 経路確認 |
| 5 | Security Group | `before/security_groups.json` | 許可ルール |
| 6 | NACL | `before/network_acls.json` | Subnet単位制御 |
| 7 | ENI | `investigation/network_interfaces.json` | リソース特定 |
| 8 | DNS | `investigation/dns_result.txt` | 名前解決 |
| 9 | 疎通 | `after/connectivity_test.txt` | 動作確認 |
| 10 | Flow Logs | `investigation/flow_logs.json` | ACCEPT / REJECT |
| 11 | CloudTrail | `investigation/cloudtrail_events.json` | 変更履歴 |
| 12 | スクリーンショット | `screenshots/*.png` | GUI証跡 |
| 13 | 差分 | `after/diff.txt` | レビュー |
| 14 | 切り戻し | `rollback/rollback_commands.txt` | 障害時対応 |

## 29. Teams報告例

### 29.1 変更前確認

```text
AWSネットワーク設定変更の変更前確認が完了しました。

対象:
- Account: 123456789012
- Region: ap-northeast-1
- VPC: vpc-xxxxxxxx
- 対象: Security Group sg-xxxxxxxx

通信要件:
- Source: Web EC2 Security Group
- Destination: RDS Security Group
- Protocol/Port: TCP/3306

確認内容:
- VPC / Subnet / Route Table
- Security Group
- Network ACL
- RDS Subnet Group
- DNS
- 変更前疎通
- CloudTrail直近変更履歴

現時点の懸念:
- なし

次に、承認済み手順に沿って設定変更を実施します。
```

### 29.2 変更完了

```text
AWSネットワーク設定変更が完了しました。

実施内容:
- Security Group Inbound Ruleを追加
- Source SGからTCP/3306を許可

変更後確認:
- SG Rule: 想定どおり
- RDS接続: 成功
- Flow Logs: ACCEPT確認
- CloudTrail: AuthorizeSecurityGroupIngress記録あり

証跡:
- 変更前JSON
- 変更後JSON
- 疎通結果
- CloudTrail
- スクリーンショット
```

### 29.3 要確認

```text
AWSネットワーク確認中に、追加確認が必要な項目がありました。

対象:
- Route Table: rtb-xxxxxxxx

内容:
- Private SubnetのDefault Routeが別AZのNAT Gatewayを向いています。

確認したい点:
- コスト・冗長化観点でこの設計が承認済みか
- AZ障害時の影響を許容しているか
- 同一AZ NAT Gatewayへの経路変更要否

設定変更前に方針確認をお願いします。
```

## 30. 案件で説明できるポイント

- 通信調査ではSource、Destination、Protocol、Portを最初に固定する
- Route Table、SG、NACL、DNS、Endpointを順番に見る
- SGはStateful、NACLはStatelessであり、切り分け観点が違う
- Public / Private Subnetは名前ではなくRoute Tableで判断する
- RDSやElastiCacheはPrivate Subnet配置とSG参照許可を確認する
- LambdaをVPCに入れた場合、NAT GatewayまたはVPC Endpointの有無が重要になる
- S3 Bucket PolicyでVPC Endpoint制限を入れる場合、通信経路の影響調査が必須
- Flow Logs、Reachability Analyzer、CloudTrailを組み合わせると説明しやすい
- GUI証跡とCLI JSON証跡を両方残すとレビューに耐えやすい

## 31. 資格試験につながるポイント

| 分野 | 試験観点 |
| :--- | :--- |
| VPC | CIDR、DNS属性、Subnet |
| Route Table | Main route table、Subnet association、Default route |
| IGW / NAT | Public / Private Subnet、Outbound通信 |
| Security Group | Stateful、Inbound / Outbound |
| NACL | Stateless、Rule番号、Ephemeral Port |
| VPC Endpoint | Gateway / Interface、Private DNS、Endpoint Policy |
| DNS | Route 53 Private Hosted Zone、Resolver |
| ALB | Scheme、Listener、Target Group、Health Check |
| RDS | PubliclyAccessible、DB Subnet Group |
| Lambda | VPC Config、NAT、Endpoint |
| Flow Logs | ACCEPT / REJECT、ENI、CloudWatch Logs |
| TGW | Attachment、Association、Propagation |

## 32. 公式ドキュメント

- [Amazon VPC Route Table](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Route_Tables.html)
- [Subnet Route Table](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/subnet-route-tables.html)
- [Security Group](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLルール](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/nacl-rules.html)
- [NAT Gateway](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-nat-gateway.html)
- [Gateway VPC Endpoint](https://docs.aws.amazon.com/ja_jp/vpc/latest/privatelink/gateway-endpoints.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html)
- [Reachability Analyzerとは](https://docs.aws.amazon.com/ja_jp/vpc/latest/reachability/what-is-reachability-analyzer.html)
- [Route 53 Private Hosted Zoneを作成する](https://docs.aws.amazon.com/ja_jp/Route53/latest/DeveloperGuide/hosted-zone-private-creating.html)
- [ALB Target GroupのHealth Statusを確認する](https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/application/check-target-health.html)
