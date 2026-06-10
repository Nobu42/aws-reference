# 07 VPC / Network CLIリファレンス

## 1. このドキュメントの目的

このドキュメントは、VPC、Subnet、Route Table、Security Group、Network ACL、VPC Endpoint、VPC Flow LogsをAWS CLIで確認し、ネットワーク影響調査やセキュリティ確認を行うためのリファレンスである。

対象は、銀行系システムのように、AWSネットワーク設定の変更、影響調査、疎通確認、セキュリティ対策状況確認、証跡取得、手順書作成が重要になる環境を想定する。

このドキュメントでは、主に以下を扱う。

- VPC確認
- Subnet確認
- Route Table確認
- Internet Gateway / NAT Gateway確認
- Security Group確認
- Security Group Rule確認
- Network ACL確認
- Network Interface確認
- VPC Endpoint確認
- VPC Flow Logs確認
- 通信経路の影響調査
- 変更前後の証跡取得
- よくあるトラブルと確認ポイント
- Teams報告例

既存のコマンド辞書的な説明は以下も参照する。

```text
aws_network_cli_reference.md
```

## 2. ネットワーク調査で見る順番

AWSネットワーク調査では、以下の順番で見ると整理しやすい。

```text
Source
  ↓
Security Group outbound
  ↓
Subnet NACL outbound
  ↓
Route Table
  ↓
Gateway / NAT Gateway / Transit Gateway / VPC Endpoint
  ↓
Destination subnet
  ↓
Subnet NACL inbound
  ↓
Security Group inbound
  ↓
Destination
```

基本の確認軸:

| 観点 | 内容 |
| :--- | :--- |
| Source | どこから通信するか |
| Destination | どこへ通信するか |
| Protocol | TCP / UDP / ICMP |
| Port | 443、3306、6379など |
| Route | どのRoute Tableでどこへ向くか |
| SG | Statefulな許可があるか |
| NACL | Statelessな許可が双方向にあるか |
| DNS | 名前解決先が想定どおりか |
| Endpoint | AWSサービス向け通信がEndpoint経由か |
| Logs | Flow LogsでACCEPT / REJECTが確認できるか |

重要:

```text
Security GroupはStateful。
Network ACLはStateless。
Route TableはSubnet単位で効く。
Subnetに明示関連付けがない場合、Main Route Tableが暗黙的に使われる。
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

PROJECT_NAME="nobu-iac-lab"
VPC_NAME="sample-vpc"

VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "$VPC_ID"
```

注意:

- 実案件ではVPC名だけでなく、VPC ID、Account ID、Regionを手順書に明記する
- VPC名が重複する可能性があるため、本番ではVPC IDで確認する
- Shared VPCやOrganizations環境では、所有アカウントと利用アカウントを確認する

### 3.2 証跡ディレクトリ

```bash
WORK_NAME="vpc_network_check"
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

## 4. ネットワーク確認のクイックチェックリスト

| No. | 確認項目 | 期待値の例 | 主なコマンド |
| :--- | :--- | :--- | :--- |
| 1 | VPC | 想定VPC、CIDR、DNS属性 | `describe-vpcs`、`describe-vpc-attribute` |
| 2 | Subnet | Public/Private、AZ、CIDR | `describe-subnets` |
| 3 | Route Table | IGW/NAT/TGW/Endpoint経路 | `describe-route-tables` |
| 4 | Internet Gateway | VPCにAttach済み | `describe-internet-gateways` |
| 5 | NAT Gateway | `available` | `describe-nat-gateways` |
| 6 | Security Group | 必要最小限のInbound/Outbound | `describe-security-groups` |
| 7 | SG Rule | Rule単位で確認 | `describe-security-group-rules` |
| 8 | NACL | Subnet関連付け、双方向許可 | `describe-network-acls` |
| 9 | ENI | EC2/RDS/Lambda/EndpointのNIC確認 | `describe-network-interfaces` |
| 10 | Endpoint | Gateway/Interface Endpoint確認 | `describe-vpc-endpoints` |
| 11 | Flow Logs | 有効化、送信先、対象 | `describe-flow-logs` |
| 12 | CloudTrail | 変更履歴 | `lookup-events` |
| 13 | Reachability Analyzer | 疎通経路解析 | `create-network-insights-path` |

## 5. VPC確認

### 5.1 VPC一覧

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Vpcs[*].{VpcId:VpcId,State:State,Cidr:CidrBlock,IsDefault:IsDefault,OwnerId:OwnerId,Tenancy:InstanceTenancy,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --output json \
  > "$EVIDENCE_DIR/before/01_describe_vpcs.json"
```

### 5.2 対象VPC確認

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[*].{VpcId:VpcId,State:State,Cidr:CidrBlock,OwnerId:OwnerId,IsDefault:IsDefault,Tags:Tags}' \
  --output table
```

確認ポイント:

- VPC IDが想定どおり
- CIDRが設計書と一致
- `State=available`
- Default VPCではないか
- Tagsが付与されているか

### 5.3 VPC DNS属性

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output table

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output table
```

証跡保存:

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output json \
  > "$EVIDENCE_DIR/before/02_vpc_dns_support.json"

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output json \
  > "$EVIDENCE_DIR/before/03_vpc_dns_hostnames.json"
```

確認ポイント:

- Private Hosted Zoneを使う場合、`enableDnsSupport=true`
- EC2のDNS名やRoute 53 Private DNSを使う場合、`enableDnsHostnames=true`
- RDSやVPC Endpointの名前解決にも影響する

## 6. Subnet確認

### 6.1 VPC内Subnet一覧

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`]|[0].Value,SubnetId:SubnetId,Az:AvailabilityZone,Cidr:CidrBlock,AvailableIp:AvailableIpAddressCount,MapPublicIp:MapPublicIpOnLaunch,State:State,Type:Tags[?Key==`Type`]|[0].Value}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/04_describe_subnets.json"
```

確認ポイント:

- Public Subnet / Private Subnetが設計どおり
- AZ分散されている
- CIDRが重複していない
- `MapPublicIpOnLaunch` がPublic Subnetだけ有効か
- Available IPが枯渇していないか

### 6.2 Public IP自動割当の確認

```bash
SUBNET_ID="<subnet-id>"

aws ec2 describe-subnet-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$SUBNET_ID" \
  --attribute mapPublicIpOnLaunch \
  --output table
```

注意:

- Private Subnetで `MapPublicIpOnLaunch=true` だと意図せずPublic IPが付く可能性がある
- Public Subnetでも、ALB/NAT/Bastion以外にPublic IPを付ける必要があるか確認する

### 6.3 SubnetとAZの対応

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{SubnetId:SubnetId,Name:Tags[?Key==`Name`]|[0].Value,AZ:AvailabilityZone,AZId:AvailabilityZoneId,Cidr:CidrBlock}' \
  --output table
```

確認ポイント:

- ALBは2つ以上のAZに配置されているか
- RDS Subnet Groupは複数AZのSubnetを含むか
- ElastiCache Subnet Groupも複数AZを含むか

## 7. Route Table確認

### 7.1 Route Table一覧

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`]|[0].Value,RouteTableId:RouteTableId,Associations:Associations[*].SubnetId,Main:Associations[?Main==`true`]|[0].Main,Routes:Routes[*].{Destination:DestinationCidrBlock,Destination6:DestinationIpv6CidrBlock,PrefixList:DestinationPrefixListId,Gateway:GatewayId,Nat:NatGatewayId,Tgw:TransitGatewayId,VpcPeering:VpcPeeringConnectionId,State:State}}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/05_describe_route_tables.json"
```

確認ポイント:

- Public SubnetのRoute Tableに `0.0.0.0/0 -> igw-...`
- Private SubnetのRoute Tableに `0.0.0.0/0 -> nat-...`
- S3 Gateway Endpoint利用時はPrefix List経路がある
- `blackhole` routeがない
- Subnet関連付けが設計どおり
- 明示関連付けがないSubnetはMain Route Tableを使う

### 7.2 Subnetに関連付くRoute Tableを確認

```bash
SUBNET_ID="<subnet-id>"

aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/route_table_for_${SUBNET_ID}.json"
```

上記で空の場合、SubnetはMain Route Tableに暗黙関連付けされている可能性がある。

Main Route Table確認:

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=association.main,Values=true \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes}' \
  --output table
```

### 7.3 Default Route確認

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=route.destination-cidr-block,Values=0.0.0.0/0 \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`]}' \
  --output table
```

確認ポイント:

- Public SubnetはIGW向きか
- Private SubnetはNAT Gateway向きか
- 閉域環境ではTGW/VGW/Firewall向きか
- 想定外にInternet向きになっていないか

## 8. Internet Gateway / NAT Gateway確認

### 8.1 Internet Gateway確認

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[*].{InternetGatewayId:InternetGatewayId,Attachments:Attachments,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/06_describe_internet_gateways.json"
```

確認ポイント:

- VPCにIGWがAttachされている
- Public SubnetのDefault RouteがIGW向き
- Private SubnetがIGW向きになっていない

### 8.2 NAT Gateway確認

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --query 'NatGateways[*].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId,PublicIp:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/07_describe_nat_gateways.json"
```

確認ポイント:

- `State=available`
- Public Subnetに配置されている
- Elastic IPが関連付いている
- Private SubnetのDefault RouteがNAT Gatewayへ向いている
- NAT Gatewayは課金対象のため不要時に削除対象

## 9. Security Group確認

### 9.1 Security Group一覧

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,GroupId:GroupId,Description:Description,VpcId:VpcId,Tags:Tags}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/08_describe_security_groups.json"
```

### 9.2 特定Security Group詳細

```bash
SG_ID="<security-group-id>"

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$SG_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/security_group_${SG_ID}.json"
```

確認ポイント:

- Inboundが必要最小限か
- 0.0.0.0/0 や ::/0 の許可がないか
- SSH/RDPを広く公開していないか
- DB/RedisなどがWeb SGからのみ許可されているか
- Outboundが全許可でよいか
- ルールDescriptionがあるか

### 9.3 Security Group Rule単位で確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$SG_ID" \
  --query 'SecurityGroupRules[*].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/09_describe_security_group_rules.json"
```

Rule単位で見る理由:

- 変更時にSecurity Group Rule IDを使って差分管理しやすい
- Descriptionを確認しやすい
- Ingress/Egressの切り分けがしやすい

### 9.4 公開されている危険ポート確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Cidr6:CidrIpv6,Description:Description}' \
  --output table
```

確認ポイント:

- 22 / 3389 が全公開されていないか
- 3306 / 5432 / 6379 が全公開されていないか
- 80 / 443 はALBだけに必要か
- 一時作業用ルールが残っていないか

## 10. Network ACL確認

### 10.1 NACL一覧

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[*].{NetworkAclId:NetworkAclId,IsDefault:IsDefault,Associations:Associations[*].SubnetId,Entries:Entries[*].{Rule:RuleNumber,Egress:Egress,Protocol:Protocol,Action:RuleAction,Cidr:CidrBlock,Cidr6:Ipv6CidrBlock,From:PortRange.From,To:PortRange.To},Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/10_describe_network_acls.json"
```

確認ポイント:

- Subnet関連付けが設計どおり
- Inbound / Outbound両方に必要な許可がある
- DenyルールのRule NumberがAllowより前にないか
- Ephemeral portが戻り通信で許可されているか
- Default NACLをそのまま使っているか、カスタムNACLか

重要:

```text
NACLはStateless。
Inboundを許可しても、戻り通信のOutboundが許可されていないと通信できない。
```

### 10.2 Subnetに関連付くNACL確認

```bash
SUBNET_ID="<subnet-id>"

aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/network_acl_for_${SUBNET_ID}.json"
```

## 11. Network Interface確認

### 11.1 VPC内ENI一覧

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,Description:Description,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:Association.PublicIp,Groups:Groups[*].GroupId,AttachmentInstance:Attachment.InstanceId,RequesterManaged:RequesterManaged,InterfaceType:InterfaceType}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/11_describe_network_interfaces.json"
```

確認ポイント:

- EC2、RDS、ALB、VPC Endpoint、LambdaなどのENIを識別する
- 対象IPアドレスがどのENIか確認する
- Security GroupがどのENIに付いているか確認する
- 不要なENIが残っていないか

### 11.2 IPアドレスからENIを探す

```bash
PRIVATE_IP="<private-ip>"

aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=addresses.private-ip-address,Values="$PRIVATE_IP" \
  --query 'NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,Description:Description,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Groups:Groups[*].GroupId,Attachment:Attachment.InstanceId,InterfaceType:InterfaceType}' \
  --output table
```

## 12. VPC Endpoint確認

### 12.1 Endpoint一覧

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[*].{Name:Tags[?Key==`Name`]|[0].Value,EndpointId:VpcEndpointId,Service:ServiceName,Type:VpcEndpointType,State:State,Subnets:SubnetIds,RouteTables:RouteTableIds,Groups:Groups[*].GroupId,PrivateDns:PrivateDnsEnabled,DnsEntries:DnsEntries[*].DnsName}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/12_describe_vpc_endpoints.json"
```

確認ポイント:

- S3 Gateway Endpointがあるか
- Interface EndpointのSubnetとSecurity Groupが正しいか
- `PrivateDnsEnabled=true` が必要なEndpointで有効か
- Endpoint Policyが最小権限か
- Route TableにGateway Endpoint用Prefix List経路が入っているか

### 12.2 S3 Endpoint確認

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=service-name,Values="com.amazonaws.${REGION}.s3" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,Type:VpcEndpointType,State:State,RouteTables:RouteTableIds,PolicyDocument:PolicyDocument}' \
  --output json \
  > "$EVIDENCE_DIR/investigation/13_s3_vpc_endpoint.json"
```

確認ポイント:

- Private SubnetからS3へNAT Gateway経由ではなくGateway Endpoint経由にできているか
- Endpoint Policyで対象BucketやActionが絞られているか
- S3 Bucket Policyで `aws:sourceVpce` 条件を使っている場合、Endpoint IDが一致しているか

### 12.3 Interface EndpointのSecurity Group確認

```bash
ENDPOINT_ID="<vpc-endpoint-id>"

ENDPOINT_SG_IDS=$(aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-endpoint-ids "$ENDPOINT_ID" \
  --query 'VpcEndpoints[0].Groups[*].GroupId' \
  --output text)

aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids $ENDPOINT_SG_IDS \
  --output json \
  > "$EVIDENCE_DIR/investigation/endpoint_security_groups_${ENDPOINT_ID}.json"
```

確認ポイント:

- Interface EndpointはENIとSecurity Groupを持つ
- 接続元Subnet/SGから443が許可されているか
- 全公開になっていないか

## 13. VPC Flow Logs確認

### 13.1 Flow Logs一覧

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --query 'FlowLogs[*].{FlowLogId:FlowLogId,ResourceId:ResourceId,ResourceType:ResourceType,TrafficType:TrafficType,LogDestinationType:LogDestinationType,LogGroupName:LogGroupName,LogDestination:LogDestination,DeliverLogsStatus:DeliverLogsStatus,MaxAggregationInterval:MaxAggregationInterval,LogFormat:LogFormat}' \
  --output table
```

証跡保存:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --output json \
  > "$EVIDENCE_DIR/before/14_describe_flow_logs.json"
```

確認ポイント:

- VPC / Subnet / ENIのどの単位で有効か
- `TrafficType` が `ALL`、`ACCEPT`、`REJECT` のどれか
- CloudWatch LogsまたはS3に配送されているか
- `DeliverLogsStatus=SUCCESS`
- Log Formatに必要なフィールドが含まれるか

### 13.2 Flow Logsがない場合の注意

Flow Logsがない場合:

- 通信のACCEPT/REJECT証跡が取りづらい
- SG/NACL/Routeの静的確認が中心になる
- 障害時に後追い調査しづらい
- 本番では有効化の要否を検討する

注意:

- Flow Logsは課金対象
- 保存先CloudWatch Logs/S3の保管期間を確認する
- ログにはIPアドレスなどの通信情報が含まれる

### 13.3 CloudWatch Logs上のFlow Logs検索

```bash
FLOW_LOG_GROUP_NAME="<flow-log-group-name>"
SRCADDR="<source-ip>"
DSTADDR="<destination-ip>"

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$FLOW_LOG_GROUP_NAME" \
  --filter-pattern "$SRCADDR $DSTADDR" \
  --max-items 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/flow_logs_${SRCADDR}_${DSTADDR}.json"
```

確認ポイント:

- `ACCEPT` か `REJECT` か
- Source / Destination IP
- Port
- Protocol
- 時刻
- ENI ID

## 14. 通信影響調査テンプレート

### 14.1 例: Web EC2からRDS MySQLへ接続できるか

前提:

```text
Source: Web EC2
Destination: RDS
Protocol: TCP
Port: 3306
```

確認順:

1. Web EC2のSubnetを確認
2. RDSのSubnet / Security Groupを確認
3. Web EC2のSecurity Group outboundを確認
4. RDS Security Group inboundでWeb SGから3306が許可されているか確認
5. NACLで3306と戻り通信が許可されているか確認
6. Route TableでVPC内local routeがあるか確認
7. DNSでRDS EndpointがPrivate IPに解決されるか確認
8. Flow LogsでACCEPT/REJECTを確認

Web EC2 SG確認:

```bash
WEB_SG_ID="<web-sg-id>"
DB_SG_ID="<db-sg-id>"

aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --query 'SecurityGroupRules[?IsEgress==`false`].{RuleId:SecurityGroupRuleId,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSg:ReferencedGroupInfo.GroupId,Cidr:CidrIpv4,Description:Description}' \
  --output table
```

期待値:

```text
DB SG inbound:
  TCP 3306 from Web SG
```

### 14.2 例: Private EC2からS3へ接続できるか

確認順:

1. EC2 SubnetのRoute Tableを確認
2. S3 Gateway Endpointがあるか確認
3. Endpointに該当Route Tableが関連付いているか確認
4. Endpoint Policyを確認
5. S3 Bucket Policyに `aws:sourceVpce` 条件がある場合、Endpoint IDを確認
6. NAT Gateway経由設計の場合、Default RouteがNAT Gateway向きか確認
7. Flow Logsで通信状況を確認

S3 Endpoint確認:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=service-name,Values="com.amazonaws.${REGION}.s3" \
  --output table
```

### 14.3 例: ALBからWeb EC2へ接続できるか

前提:

```text
Source: ALB Security Group
Destination: Web EC2 Security Group
Protocol: TCP
Port: 3000
```

確認順:

1. ALBがPublic Subnetに配置されているか
2. ALB Security Group inboundで80/443が許可されているか
3. ALB Security Group outboundでWeb Portが許可されているか
4. Web Security Group inboundでALB SGから3000が許可されているか
5. Web EC2がPrivate Subnetにあるか
6. NACLが双方向通信を許可しているか
7. Target Group Healthがhealthyか

Target Health確認:

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names sample-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn "$TG_ARN" \
  --output table
```

## 15. CloudTrailでネットワーク変更履歴を確認する

ネットワーク設定変更はCloudTrailで確認する。

### 15.1 Security Group変更

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_authorize_sg_ingress.json"
```

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| Inbound追加 | `AuthorizeSecurityGroupIngress` |
| Inbound削除 | `RevokeSecurityGroupIngress` |
| Outbound追加 | `AuthorizeSecurityGroupEgress` |
| Outbound削除 | `RevokeSecurityGroupEgress` |
| SG作成 | `CreateSecurityGroup` |
| SG削除 | `DeleteSecurityGroup` |
| Rule説明変更 | `UpdateSecurityGroupRuleDescriptionsIngress` |

### 15.2 Route Table変更

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| Route追加 | `CreateRoute` |
| Route置換 | `ReplaceRoute` |
| Route削除 | `DeleteRoute` |
| Route Table作成 | `CreateRouteTable` |
| Route Table削除 | `DeleteRouteTable` |
| Subnet関連付け | `AssociateRouteTable` |
| Subnet関連付け変更 | `ReplaceRouteTableAssociation` |

検索例:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ReplaceRoute \
  --max-results 50 \
  --output json \
  > "$EVIDENCE_DIR/investigation/cloudtrail_replace_route.json"
```

### 15.3 NACL変更

関連EventName:

| 操作 | EventName |
| :--- | :--- |
| Entry作成 | `CreateNetworkAclEntry` |
| Entry置換 | `ReplaceNetworkAclEntry` |
| Entry削除 | `DeleteNetworkAclEntry` |
| NACL関連付け変更 | `ReplaceNetworkAclAssociation` |

## 16. Reachability Analyzer

Reachability Analyzerは、VPC内の送信元から宛先へ到達可能かを解析するサービスである。

使いどころ:

- SG/NACL/Routeのどこで止まっているか確認したい
- 実通信を発生させずに経路を確認したい
- 手動確認の補助証跡として使いたい

注意:

- 利用可能なリソース種別やパス定義に制約がある
- 本番では解析対象、料金、証跡扱いを確認する

### 16.1 Network Insights Path作成

```bash
SOURCE_ARN="<source-resource-arn>"
DESTINATION_ARN="<destination-resource-arn>"

PATH_ID=$(aws ec2 create-network-insights-path \
  --profile "$PROFILE" \
  --region "$REGION" \
  --source "$SOURCE_ARN" \
  --destination "$DESTINATION_ARN" \
  --protocol tcp \
  --destination-port 443 \
  --tag-specifications "ResourceType=network-insights-path,Tags=[{Key=Name,Value=${PROJECT_NAME}-path},{Key=Project,Value=${PROJECT_NAME}}]" \
  --query 'NetworkInsightsPath.NetworkInsightsPathId' \
  --output text)

echo "$PATH_ID"
```

### 16.2 解析開始

```bash
ANALYSIS_ID=$(aws ec2 start-network-insights-analysis \
  --profile "$PROFILE" \
  --region "$REGION" \
  --network-insights-path-id "$PATH_ID" \
  --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' \
  --output text)

echo "$ANALYSIS_ID"
```

### 16.3 解析結果確認

```bash
aws ec2 describe-network-insights-analyses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --network-insights-analysis-ids "$ANALYSIS_ID" \
  --output json \
  > "$EVIDENCE_DIR/investigation/reachability_analysis_${ANALYSIS_ID}.json"
```

確認ポイント:

- `NetworkPathFound`
- `Status`
- 経路上のコンポーネント
- 到達できない場合の説明

## 17. 変更前後に保存する証跡

| タイミング | 証跡 | ファイル例 |
| :--- | :--- | :--- |
| 変更前 | Caller Identity | `00_caller_identity.json` |
| 変更前 | VPC | `01_describe_vpcs.json` |
| 変更前 | VPC DNS属性 | `02_vpc_dns_support.json`、`03_vpc_dns_hostnames.json` |
| 変更前 | Subnet | `04_describe_subnets.json` |
| 変更前 | Route Table | `05_describe_route_tables.json` |
| 変更前 | Internet Gateway | `06_describe_internet_gateways.json` |
| 変更前 | NAT Gateway | `07_describe_nat_gateways.json` |
| 変更前 | Security Group | `08_describe_security_groups.json` |
| 変更前 | SG Rules | `09_describe_security_group_rules.json` |
| 変更前 | NACL | `10_describe_network_acls.json` |
| 変更前 | ENI | `11_describe_network_interfaces.json` |
| 変更前 | VPC Endpoint | `12_describe_vpc_endpoints.json` |
| 変更前 | Flow Logs | `14_describe_flow_logs.json` |
| 調査 | CloudTrail変更履歴 | `cloudtrail_*.json` |
| 調査 | Flow Logs検索結果 | `flow_logs_*.json` |
| 変更後 | 変更対象の再取得 | `after/*.json` |
| 画面 | AWS Console | VPC、Subnet、Route Table、SG、NACL、Endpoint、Flow Logs |

## 18. 変更時の影響範囲

| 変更対象 | 主な影響 |
| :--- | :--- |
| VPC DNS属性 | Private DNS、RDS Endpoint、Private Hosted Zone、Endpoint名前解決 |
| Subnet属性 | EC2 Public IP自動割当、配置先 |
| Route Table | Internet/NAT/TGW/Endpoint経路、通信可否 |
| Security Group | リソース単位のInbound/Outbound許可 |
| NACL | Subnet単位の双方向通信許可/拒否 |
| VPC Endpoint | AWSサービスへの経路、Bucket Policy条件 |
| Flow Logs | 通信証跡、調査能力、コスト |

変更前に確認すること:

- 対象通信のSource / Destination / Port / Protocol
- 作業時間帯
- 影響するSubnet / ENI / Resource
- 切り戻しコマンド
- 変更前JSON証跡
- 関係者への連絡要否

## 19. よくあるトラブルと確認ポイント

### 19.1 EC2からInternetへ出られない

確認ポイント:

- SubnetのRoute TableにDefault Routeがあるか
- Public SubnetならIGW向きか
- Private SubnetならNAT Gateway向きか
- NAT Gatewayが `available` か
- Security Group outboundが許可されているか
- NACL outbound/inboundの戻り通信が許可されているか
- DNS解決できているか

### 19.2 ALBからTargetがunhealthy

確認ポイント:

- Target GroupのPort/Protocolが正しいか
- Web SG inboundでALB SGから許可されているか
- ALB SG outboundが許可されているか
- NACLが双方向許可しているか
- アプリケーションが待ち受けているか
- Health Check Pathが正しいか

### 19.3 RDSへ接続できない

確認ポイント:

- RDSがPrivate Subnetにあるか
- RDS SG inboundで接続元SGからDB Portを許可しているか
- 接続元SG outboundが許可されているか
- NACLが双方向許可しているか
- RDS Endpointが名前解決できるか
- DBユーザー/パスワード/DB名は正しいか

### 19.4 S3へ接続できない

確認ポイント:

- NAT Gateway経由設計か、S3 Gateway Endpoint経由設計か
- S3 Gateway EndpointがRoute Tableに関連付いているか
- Endpoint Policyが許可しているか
- Bucket Policyで `aws:sourceVpce` 条件があるか
- IAM RoleにS3権限があるか

### 19.5 Security Groupを変更したのに通信できない

確認ポイント:

- 宛先側SG inboundだけでなく、送信元側SG outboundも確認したか
- NACLが拒否していないか
- Route Tableが正しいか
- DNSが違うIPを返していないか
- 対象リソースに変更したSGが本当に関連付いているか
- アプリケーション側がListenしているか

## 20. 作業手順書に書く項目

| 項目 | 内容 |
| :--- | :--- |
| 作業目的 | SG変更、Route追加、Endpoint追加、Flow Logs有効化など |
| 対象 | Account、Region、VPC、Subnet、SG、Route Table |
| 通信要件 | Source、Destination、Protocol、Port |
| 変更前確認 | VPC、Subnet、Route、SG、NACL、Endpoint、Flow Logs |
| 変更内容 | 追加/削除/置換する設定 |
| 影響範囲 | 対象通信、関連リソース、業務影響 |
| テスト | 疎通確認、Target Health、Flow Logs、Reachability Analyzer |
| 切り戻し | 変更前設定へ戻すコマンド |
| 証跡 | CLI JSON、Consoleスクリーンショット |
| 報告 | 変更結果、確認結果、残課題 |

## 21. 案件で説明できるポイント

このネットワーク調査は、案件では次のように説明できる。

```text
VPC内の通信影響調査では、Source、Destination、Protocol、Portを明確にしたうえで、
Subnet、Route Table、Security Group、Network ACL、VPC Endpoint、Flow Logsを順番に確認します。
変更前には対象リソースの設定をJSONで保存し、変更後は同じコマンドで再取得して差分確認します。
疎通できない場合は、Route、SG、NACL、DNS、Endpoint、Flow Logsの順に切り分け、
必要に応じてReachability Analyzerも補助的に利用します。
```

## 22. 資格試験につながるポイント

| 領域 | 試験で問われやすいポイント |
| :--- | :--- |
| VPC | CIDR、DNS属性、Default VPC |
| Subnet | Public/Private、AZ、Public IP自動割当 |
| Route Table | IGW、NAT、TGW、Endpoint経路 |
| Security Group | Stateful、リソース単位 |
| Network ACL | Stateless、Subnet単位、Rule Number |
| VPC Endpoint | Gateway Endpoint、Interface Endpoint、Private DNS |
| Flow Logs | ACCEPT/REJECT、CloudWatch Logs/S3保存 |
| Reachability Analyzer | 到達性解析 |
| NAT Gateway | Private SubnetからInternet向け通信 |
| IGW | Public SubnetからInternet向け通信 |

## 23. 調査結果テンプレート

```text
対象AWSアカウント:
  <account-id>

確認日時:
  <yyyy-mm-dd hh:mm JST>

Region:
  <region>

VPC:
  <vpc-id> / <vpc-name>

通信要件:
  Source:
  Destination:
  Protocol:
  Port:

Source Subnet:
  <subnet-id>

Destination Subnet:
  <subnet-id>

Route Table:
  問題なし / 要確認

Security Group:
  問題なし / 要確認

Network ACL:
  問題なし / 要確認

VPC Endpoint:
  利用あり / 利用なし / 対象外

Flow Logs:
  有効 / 無効
  ACCEPT / REJECT / 未確認

CloudTrail変更履歴:
  あり / なし / 未確認

総合判断:
  問題なし / 要改善 / 要追加調査

備考:
  <調査メモ>
```

## 24. Teams報告例

### 24.1 変更前確認完了

```text
VPCネットワーク設定の変更前確認を実施しました。
対象は <vpc-id> の <通信要件> です。
Subnet、Route Table、Security Group、Network ACL、VPC Endpoint、Flow Logsの設定を確認し、
変更前証跡としてCLI出力を保存済みです。
```

### 24.2 疎通不可の一次調査

```text
対象通信 <source> -> <destination>:<port> の疎通不可について一次調査しました。
現時点では <Route/SG/NACL/DNS/Endpoint> に要確認点があります。
追加でFlow LogsおよびCloudTrail変更履歴を確認し、設定変更有無とREJECT有無を切り分けます。
```

### 24.3 変更後確認完了

```text
ネットワーク設定変更後の確認を実施しました。
変更対象 <resource> は想定どおり更新され、対象通信 <source> -> <destination>:<port> の確認も完了しています。
変更後のCLI出力と必要な画面証跡を保存済みです。
```

## 25. 公式ドキュメント

- [VPCネットワークアーキテクチャを確認する](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-network-inventory.html)
- [Subnet Route Table](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/subnet-route-tables.html)
- [Security Group](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLルール](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/nacl-rules.html)
- [AWS PrivateLinkとVPC Endpointの概念](https://docs.aws.amazon.com/ja_jp/vpc/latest/privatelink/concepts.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html)
- [AWS CLIでReachability Analyzerを開始する](https://docs.aws.amazon.com/ja_jp/vpc/latest/reachability/getting-started-cli.html)
