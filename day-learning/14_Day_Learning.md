# Day 14 Learning: DNS・VPC Endpoint・Flow Logs確認ドリル

## 1. 今日の目的

AWS環境の通信調査で重要となるDNS、VPC Endpoint、VPC Flow Logsを確認し、通信経路と調査可否を説明できる状態を目指す。

Day 14では、設定が存在するかだけではなく、次の関係を一連で確認する。

```text
通信先の名前
  -> DNSで解決されるIPアドレス
  -> Source SubnetのRoute Table
  -> NAT GatewayまたはVPC Endpoint
  -> Security Group / Network ACL
  -> Flow LogsのACCEPT / REJECT
  -> Applicationの応答
```

本ドリルでは設定変更を行わない。現在設定を確認し、未設定項目は即時変更せず、要件・影響範囲・費用・保存方針を確認する改善候補として整理する。

関連資料:

- [Day 10 VPC・Subnet・Route Table確認](./10_Day_Learning.md)
- [Day 11 Security Group・Network ACL確認](./11_Day_Learning.md)
- [Day 13 Security Group変更・確認・切り戻しドリル](./13_Day_Learning.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [Private DNS構築スクリプト](../scripts/14_private_dns_setup.sh)
- [Private DNS構築手順](../docs/setup_guides/14_private_dns_setup.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)

---

## 2. 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象VPCの内部DNS、VPC Endpoint、VPC Flow Logsの設定を確認してください。

Web EC2からRDSとS3へ接続する際の経路を整理し、
通信障害発生時にDNS、Route、SG、NACL、Endpoint、
Flow Logsのどこを確認するか説明してください。

設定変更は実施しないでください。
```

## 今日の確認順序

1. AWSアカウント、リージョン、対象VPCを確認する
2. VPC DNS属性を確認する
3. Private Hosted ZoneとVPC関連付けを確認する
4. Private DNSレコードと実リソースを照合する
5. VPC内EC2から名前解決を確認する
6. Route 53 Resolver EndpointとRuleを確認する
7. VPC Endpoint一覧を確認する
8. S3 Gateway Endpointの有無を確認する
9. Route TableからS3向け経路を確認する
10. S3 Bucket PolicyのVPC Endpoint条件を確認する
11. VPC Flow Logsの有無と保存先を確認する
12. Flow Logsがある場合のACCEPT / REJECT検索方法を確認する
13. CloudTrailでDNS・Endpoint・Flow Logsの変更履歴を確認する
14. 通信障害の調査順序、証跡、報告内容を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象VPC | `sample-vpc` |
| Private Hosted Zone | `home.` |
| 主な内部DNS | `bastion.home`、`web01.home`、`web02.home`、`db.home` |
| S3バケット | `nobu-terraform-iac-lab-upload` |
| 主な通信 | Web EC2からRDS、Web EC2からS3 |
| 設定変更 | なし |

## ラボ環境の期待値

| 項目 | 期待値 | 判定 |
|---|---|---|
| VPC DNS Support | `true` | 必須 |
| VPC DNS Hostnames | `true` | 有効を期待 |
| Private Hosted Zone | `home.`が`sample-vpc`へ関連付く | 良好 |
| `bastion.home` | Bastion EC2のPrivate IP | 良好 |
| `web01.home` | Web01 EC2のPrivate IP | 良好 |
| `web02.home` | Web02 EC2のPrivate IP | 良好 |
| `db.home` | RDS EndpointへのCNAME | 良好 |
| S3 VPC Endpoint | 未設定の想定 | NAT経由。設計判断が必要 |
| VPC Flow Logs | 未設定の想定 | 調査性の改善候補 |

## 今日実行しない操作

- VPC DNS属性の変更
- Private Hosted Zone、DNSレコード、VPC関連付けの作成・変更・削除
- Route 53 Resolver EndpointまたはRuleの作成・変更・削除
- VPC Endpointの作成・変更・削除
- Route Tableの変更
- S3 Bucket Policyの変更
- VPC Flow Logsの作成・変更・削除
- CloudWatch Logs Log Group、IAM Role、S3保存先の作成・変更・削除

---

## 3. DNS・Endpoint・Flow Logsの役割

## DNS

DNSは、アプリケーションが使用する名前をIPアドレスまたは別のDNS名へ解決する。

```text
db.home
  -> RDS Endpoint
  -> RDSのPrivate IP
```

名前解決に失敗すると、Route、SG、NACLが正しくても通信できない。

## VPC Endpoint

VPC Endpointは、VPC内リソースからAWSサービスへPrivate経路で接続するために使う。

| 種類 | 主なサービス | 経路の特徴 |
|---|---|---|
| Gateway Endpoint | S3、DynamoDB | Route TableへPrefix List経路が追加される |
| Interface Endpoint | KMS、Secrets Manager、CloudWatch Logsなど | Private IPを持つENIとSGを使用する |

S3 Gateway Endpointがない場合、Private Subnet上のEC2は通常、NAT Gateway経由でS3のPublic Endpointへ接続する。

## VPC Flow Logs

VPC Flow Logsは、VPC、Subnet、ENIを通過するIP通信のメタデータを記録する。

主な確認値:

- Source IP
- Destination IP
- Source Port
- Destination Port
- Protocol
- `ACCEPT` / `REJECT`
- ENI ID
- 開始時刻、終了時刻

重要:

```text
ACCEPTは、ネットワーク制御上で通信が許可されたことを示す。
Applicationが正常応答したことまでは保証しない。

REJECTは、SG、NACLなどのネットワーク制御で拒否された通信の
切り分けに利用できる。

Flow Logsはパケット本文を記録しない。
```

---

## 4. 通信障害の基本調査順序

通信障害では、思いついた設定を変更せず、次の順序で事実を確認する。

```text
1. Source / Destination / Protocol / Portを確定する
2. DNS名が正しいIPへ解決されるか確認する
3. Source SubnetのRoute Tableを確認する
4. NAT / Endpoint / TGW / VPNなどの経路を確認する
5. Source SG outboundを確認する
6. Source NACL outboundを確認する
7. Destination NACL inboundを確認する
8. Destination SG inboundを確認する
9. Flow LogsでACCEPT / REJECTを確認する
10. OS、Listener、Application、認証を確認する
```

調査開始時に確定する5点:

| 項目 | 例 |
|---|---|
| Source | `sample-ec2-web01` |
| Destination | `db.home`、S3 |
| Protocol | TCP |
| Port | 3306、443 |
| 発生時刻 | `2026-06-21 10:00 JST` |

---

## 5. 作業開始条件と報告条件

## 作業開始条件

- 読み取り専用の確認作業である
- 対象AWSアカウント、リージョン、VPCが明確である
- 対象通信のSource、Destination、Protocol、Portが明確である
- 設計書または期待構成を確認できる
- AWS WebコンソールとAWS CLIで確認できる
- 証跡保存先が準備できている

## 作業中止・確認条件

- 想定外のAWSアカウントまたはリージョンである
- `sample-vpc`が0件または複数件である
- Private Hosted Zoneが複数存在し、正しいZoneを判断できない
- DNSレコードが想定外リソースを向いている
- EndpointまたはFlow Logsの変更を求められたが承認がない
- 読み取り権限不足により現状を確認できない

## 即時共有する状態

- `enableDnsSupport=false`
- `home.`が対象VPCへ関連付いていない
- `db.home`が想定外RDSまたはPublic接続先を向いている
- Route Tableに想定外のEndpoint、TGW、Peering、`blackhole`がある
- VPC Endpoint Policyが過度に広い、または必要通信を拒否している
- S3 Bucket Policyの`aws:sourceVpce`が実Endpoint IDと一致しない
- Flow Logsで重要通信の`REJECT`を確認した

---

## 6. 作業用変数と証跡保存先

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

VPC_NAME="sample-vpc"
PRIVATE_ZONE_NAME="home."
DB_INSTANCE_ID="sample-db"
S3_BUCKET="nobu-terraform-iac-lab-upload"
WORK_NAME="dns_endpoint_flow_logs_check"
```

### 証跡保存用ディレクトリ

```bash
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/dns" \
  "$EVIDENCE_DIR/endpoint" \
  "$EVIDENCE_DIR/flow_logs" \
  "$EVIDENCE_DIR/cloudtrail" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 必須変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nPRIVATE_ZONE_NAME=%s\nDB_INSTANCE_ID=%s\nS3_BUCKET=%s\nEVIDENCE_DIR=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" \
  "$PRIVATE_ZONE_NAME" "$DB_INSTANCE_ID" "$S3_BUCKET" "$EVIDENCE_DIR"
```

---

## 7. AWSアカウントと対象VPCの確認

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. VPCコンソールで`sample-vpc`を開く
5. VPC ID、CIDR、状態を確認する

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

### 結果の読み方

- Accountが`445405559057`である
- VPC IDが空または`None`ではない
- VPC Stateが`available`である
- CIDRが設計書と一致する

---

## 8. VPC DNS属性の確認

### Webコンソール

1. VPCコンソールで`sample-vpc`を開く
2. VPCの詳細を確認する
3. DNS解決とDNSホスト名が有効であることを確認する
4. 「編集」は押さない

取得するスクリーンショット:

```text
03_VPC_DNS属性確認.png
```

### AWS CLI

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsSupport \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/dns/01_enable_dns_support.json"

aws ec2 describe-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --attribute enableDnsHostnames \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/dns/02_enable_dns_hostnames.json"
```

### 結果の読み方

| 属性 | 期待値 | 意味 |
|---|---|---|
| `EnableDnsSupport.Value` | `true` | AmazonProvidedDNSで名前解決できる |
| `EnableDnsHostnames.Value` | `true` | VPC内リソースのDNSホスト名を利用できる |

`enableDnsSupport=false`の場合、Private Hosted ZoneやAWS提供DNSによる名前解決へ影響するため、即時共有する。

---

## 9. Private Hosted ZoneとVPC関連付けの確認

### Webコンソール

1. Route 53コンソールを開く
2. 「ホストゾーン」を開く
3. `home.`を開く
4. 種類がPrivate Hosted Zoneであることを確認する
5. 関連付けられたVPCが`sample-vpc`であることを確認する
6. 「削除」「VPCを関連付ける」は押さない

取得するスクリーンショット:

```text
04_Private_Hosted_Zone確認.png
05_Private_Hosted_Zone_VPC関連付け確認.png
```

### AWS CLI

Route 53はグローバルサービスであり、次のコマンドに`--region`は指定しない。

```bash
aws route53 list-hosted-zones-by-vpc \
  --profile "$PROFILE" \
  --vpc-id "$VPC_ID" \
  --vpc-region "$REGION" \
  --query 'HostedZoneSummaries[*].{Name:Name,HostedZoneId:HostedZoneId,Owner:Owner}' \
  --output table \
  --no-cli-pager
```

Private Hosted Zone IDを取得する。

```bash
PRIVATE_ZONE_ID=$(aws route53 list-hosted-zones-by-vpc \
  --profile "$PROFILE" \
  --vpc-id "$VPC_ID" \
  --vpc-region "$REGION" \
  --query "HostedZoneSummaries[?Name==\`$PRIVATE_ZONE_NAME\`].HostedZoneId | [0]" \
  --output text \
  --no-cli-pager)

PRIVATE_ZONE_ID="${PRIVATE_ZONE_ID#/hostedzone/}"
echo "PRIVATE_ZONE_ID=$PRIVATE_ZONE_ID"
```

証跡保存:

```bash
aws route53 list-hosted-zones-by-vpc \
  --profile "$PROFILE" \
  --vpc-id "$VPC_ID" \
  --vpc-region "$REGION" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/dns/03_hosted_zones_by_vpc.json"
```

### 結果の読み方

- `home.`が一覧に存在する
- Hosted Zone IDを一意に特定できる
- 対象VPCに関連付いている
- 0件の場合、VPC内から`*.home`を解決できない可能性がある
- 複数件の場合、誤ったZoneを調査しないよう作業を止める

---

## 10. Private DNSレコードの確認

### Webコンソール

Route 53の`home.`を開き、次のレコードを確認する。

| レコード | 種別 | 期待値 |
|---|---|---|
| `bastion.home` | A | Bastion EC2のPrivate IP |
| `web01.home` | A | Web01 EC2のPrivate IP |
| `web02.home` | A | Web02 EC2のPrivate IP |
| `db.home` | CNAME | `sample-db`のRDS Endpoint |

取得するスクリーンショット:

```text
06_Private_DNSレコード一覧.png
```

### AWS CLI

```bash
aws route53 list-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$PRIVATE_ZONE_ID" \
  --query 'ResourceRecordSets[*].{Name:Name,Type:Type,TTL:TTL,Values:ResourceRecords[*].Value}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws route53 list-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$PRIVATE_ZONE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/dns/04_private_dns_records.json"
```

### 実リソースとの照合

EC2 Private IPを確認する。

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,PrivateIp:PrivateIpAddress}' \
  --output table \
  --no-cli-pager
```

RDS Endpointを確認する。

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{DB:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VpcId:DBSubnetGroup.VpcId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- A Recordの値が現在のEC2 Private IPと一致する
- `db.home`のCNAMEが現在のRDS Endpointと一致する
- RDSの`PubliclyAccessible`が`false`である
- 古いIPや古いRDS Endpointが残っていない

注意:

```text
home.は個人ラボ用の名前空間である。

実案件では、組織が管理するPrivate Domain、
オンプレミスDNSとの重複、Resolver転送設計を確認する。
```

---

## 11. VPC内からの名前解決確認

Private Hosted Zoneは、関連付けたVPC内またはResolver連携されたネットワークから確認する。

MacなどVPC外の端末から`db.home`が引けないことは、今回の構成では異常ではない。

### Bastionで確認

```bash
ssh awsref-bastion
```

```bash
getent hosts bastion.home
getent hosts web01.home
getent hosts web02.home
getent hosts db.home
```

`dig`が導入済みの場合:

```bash
dig bastion.home
dig web01.home
dig web02.home
dig db.home
```

### Web EC2で確認

```bash
ssh awsref-web01
```

```bash
getent hosts db.home
getent hosts s3.ap-northeast-1.amazonaws.com
```

### 結果の読み方

- `*.home`がVPC内から解決できる
- `db.home`の最終解決先がRDSのPrivate IPである
- S3のサービスDNS名も解決できる
- 名前解決成功だけでは、Port疎通やApplication正常性を保証しない

### 証跡の考え方

接続先EC2上で取得した結果は、次の情報と一緒に保存する。

```text
実行日時
実行ホスト
実行ユーザー
確認したDNS名
解決結果
期待値
判定
```

---

## 12. Route 53 Resolver EndpointとRuleの確認

オンプレミスDNSとAWS Private DNSを連携する場合、Route 53 ResolverのInbound Endpoint、Outbound Endpoint、Resolver Ruleを使用することがある。

今回の個人ラボでは未設定を想定する。

### Webコンソール

1. Route 53コンソールを開く
2. 「Resolver」のInbound Endpointを確認する
3. Outbound Endpointを確認する
4. RuleとVPC関連付けを確認する
5. 未設定の場合は、その事実を記録する

取得するスクリーンショット:

```text
07_Route53_Resolver_Endpoint確認.png
08_Route53_Resolver_Rule確認.png
```

### AWS CLI

```bash
aws route53resolver list-resolver-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'ResolverEndpoints[*].{Name:Name,Id:Id,Direction:Direction,Status:Status,HostVPCId:HostVPCId,SecurityGroupIds:SecurityGroupIds}' \
  --output table \
  --no-cli-pager
```

```bash
aws route53resolver list-resolver-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'ResolverRules[*].{Name:Name,Id:Id,DomainName:DomainName,RuleType:RuleType,Status:Status,OwnerId:OwnerId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- 未設定は、オンプレミスDNS連携を行わない個人ラボでは想定内である
- 閉域網やオンプレミス連携がある案件では、Endpoint、Rule、関連VPC、SG、転送先IPを確認する
- Resolver Endpointを変更すると複数システムの名前解決へ影響する可能性がある

---

## 13. VPC Endpoint一覧の確認

### Webコンソール

1. VPCコンソールを開く
2. 「エンドポイント」を開く
3. 対象VPCで絞り込む
4. Service、Type、State、Subnet、Route Table、SG、Private DNSを確認する
5. 未設定の場合は、その事実を記録する

取得するスクリーンショット:

```text
09_VPC_Endpoint一覧確認.png
```

### AWS CLI

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,Service:ServiceName,Type:VpcEndpointType,State:State,RouteTables:RouteTableIds,Subnets:SubnetIds,Groups:Groups[*].GroupId,PrivateDns:PrivateDnsEnabled}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/endpoint/01_vpc_endpoints.json"
```

### 結果の読み方

- 出力なしの場合、対象VPCにVPC Endpointはない
- `Gateway`ではRoute Table関連付けとEndpoint Policyを確認する
- `Interface`ではSubnet、ENI、SG、Private DNS、Endpoint Policyを確認する
- `State=available`であることを確認する

---

## 14. S3 VPC EndpointとRoute Tableの確認

### S3 Endpoint確認

```bash
aws ec2 describe-vpc-endpoints \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=service-name,Values="com.amazonaws.${REGION}.s3" \
  --query 'VpcEndpoints[*].{EndpointId:VpcEndpointId,Type:VpcEndpointType,State:State,RouteTables:RouteTableIds,PrivateDns:PrivateDnsEnabled,Policy:PolicyDocument}' \
  --output table \
  --no-cli-pager
```

### Route TableのS3 Prefix List経路確認

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,S3EndpointRoutes:Routes[?DestinationPrefixListId!=`null`].{PrefixList:DestinationPrefixListId,Endpoint:VpcEndpointId,State:State}}' \
  --output json \
  --no-cli-pager
```

### S3 Prefix List確認

```bash
aws ec2 describe-managed-prefix-lists \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=prefix-list-name,Values="com.amazonaws.${REGION}.s3" \
  --query 'PrefixLists[*].{Name:PrefixListName,PrefixListId:PrefixListId,State:State,OwnerId:OwnerId}' \
  --output table \
  --no-cli-pager
```

### ラボの想定通信経路

S3 Gateway Endpointがない場合:

```text
Web EC2
  -> Private Subnet Route Table
  -> 0.0.0.0/0
  -> NAT Gateway
  -> Internet Gateway
  -> S3 Public Endpoint
```

S3 Gateway Endpointがある場合:

```text
Web EC2
  -> Private Subnet Route Table
  -> S3 Prefix List
  -> Gateway VPC Endpoint
  -> S3
```

重要:

```text
S3のDNS名がPublic IPへ解決されても、
Gateway Endpoint経由になる場合がある。

最終的な経路判断は、対象SubnetのRoute Tableにある
S3 Prefix List向けRouteで行う。
```

### 結果の読み方

- S3 Endpointなし、S3 Prefix List RouteなしならNAT経由の想定
- Endpointなしは即時障害ではない
- NAT経由を許容する設計か、Endpoint化が必要かを確認する
- Gateway Endpoint追加は、通信経路、Endpoint Policy、Bucket Policy、試験へ影響する

---

## 15. S3 Bucket PolicyのVPC Endpoint条件確認

VPC Endpoint経由だけを許可するBucket Policyがある場合、Endpoint IDとRoute Tableの整合性が必要になる。

### Webコンソール

1. S3コンソールで対象バケットを開く
2. 「アクセス許可」を開く
3. Bucket Policyを確認する
4. `aws:sourceVpce`、`aws:sourceVpc`の有無を確認する
5. 「編集」は押さない

取得するスクリーンショット:

```text
10_S3_Bucket_Policy_Endpoint条件確認.png
```

### AWS CLI

```bash
aws s3api get-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$S3_BUCKET" \
  --expected-bucket-owner "$EXPECTED_ACCOUNT_ID" \
  --query Policy \
  --output text \
  --no-cli-pager
```

### 結果の読み方

- `aws:sourceVpce`がなければ、特定Endpointだけに限定するPolicyではない
- `aws:sourceVpce`がある場合、指定Endpoint IDが実在し、対象Route Tableへ関連付くか確認する
- Endpoint制限を追加すると、Webコンソール、別VPC、バッチ、外部連携からのアクセスを拒否する可能性がある

---

## 16. VPC Flow Logs設定の確認

### Webコンソール

1. VPCコンソールで`sample-vpc`を開く
2. 「フローログ」タブを開く
3. Flow Logsの有無を確認する
4. 存在する場合、Traffic Type、保存先、状態、IAM Roleを確認する
5. 「フローログを作成」は押さない

取得するスクリーンショット:

```text
11_VPC_Flow_Logs設定確認.png
```

### AWS CLI

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --query 'FlowLogs[*].{FlowLogId:FlowLogId,ResourceId:ResourceId,TrafficType:TrafficType,DestinationType:LogDestinationType,LogGroupName:LogGroupName,LogDestination:LogDestination,Status:DeliverLogsStatus,MaxAggregationInterval:MaxAggregationInterval}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=resource-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/flow_logs/01_describe_flow_logs.json"
```

### 結果の読み方

| 状態 | 判断 |
|---|---|
| 出力なし | VPC単位Flow Logsは未設定 |
| `DeliverLogsStatus=SUCCESS` | 配信正常 |
| `DeliverLogsStatus=FAILED` | IAM Role、保存先、権限などを調査 |
| `TrafficType=ALL` | ACCEPTとREJECTを記録 |
| `TrafficType=REJECT` | 拒否通信だけを記録 |

注意:

- VPC単位で未設定でも、Subnet単位またはENI単位で設定されている可能性がある
- 未設定は、通信障害そのものではない
- 未設定の場合、過去通信のACCEPT / REJECTを後から確認できない
- 有効化にはログ量、保存先、保持期間、費用、個人情報・監査要件の確認が必要になる

### VPC内の全Flow Logs確認

```bash
aws ec2 describe-flow-logs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'FlowLogs[*].{FlowLogId:FlowLogId,ResourceId:ResourceId,ResourceType:ResourceType,TrafficType:TrafficType,DestinationType:LogDestinationType,Status:DeliverLogsStatus}' \
  --output table \
  --no-cli-pager
```

---

## 17. Flow LogsのACCEPT / REJECT検索

この章は、Flow LogsがCloudWatch Logsへ配信されている場合に実施する。

現在のラボでFlow Logsが未設定の場合は、コマンドを無理に実行せず、検索不能であることを調査結果へ記録する。

### Log Group確認

```bash
aws logs describe-log-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name-prefix "/aws/vpc/" \
  --query 'logGroups[*].{LogGroupName:logGroupName,RetentionInDays:retentionInDays,StoredBytes:storedBytes,KmsKeyId:kmsKeyId}' \
  --output table \
  --no-cli-pager
```

### REJECT検索

```bash
LOG_GROUP_NAME="/aws/vpc/flowlogs"

aws logs filter-log-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --log-group-name "$LOG_GROUP_NAME" \
  --filter-pattern '"REJECT"' \
  --limit 20 \
  --output table \
  --no-cli-pager
```

### CloudWatch Logs Insights検索例

```text
fields @timestamp, interfaceId, srcAddr, srcPort, dstAddr, dstPort, protocol, action, bytes
| filter action = "REJECT"
| sort @timestamp desc
| limit 50
```

特定通信を絞り込む例:

```text
fields @timestamp, interfaceId, srcAddr, srcPort, dstAddr, dstPort, protocol, action, bytes
| filter srcAddr = "10.0.64.10"
| filter dstPort = 3306
| sort @timestamp desc
| limit 50
```

### 結果の読み方

| 結果 | 次の調査 |
|---|---|
| `REJECT` | SG、NACL、通信方向、Port、対象ENIを確認する |
| `ACCEPT` | OS、Listener、Application、認証、応答を確認する |
| 該当ログなし | 時刻、対象ENI、Flow Logs対象範囲、配信遅延を確認する |

Flow Logsの制約:

- パケット本文は確認できない
- ApplicationのHTTP StatusやDB認証結果は確認できない
- すべてのAWS内部通信が記録対象になるわけではない
- GuardDutyが内部で利用するFlow Logs分析と、人が閲覧するFlow Logs設定は別である

---

## 18. ENIとIPアドレスの対応確認

Flow LogsではEC2名ではなくENI IDやIPアドレスが記録されるため、対象リソースを特定する。

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkInterfaces[*].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Groups:Groups[*].GroupId,InstanceId:Attachment.InstanceId}' \
  --output table \
  --no-cli-pager
```

特定IPから確認する場合:

```bash
PRIVATE_IP="<flow-log-private-ip>"

aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=addresses.private-ip-address,Values="$PRIVATE_IP" \
  --query 'NetworkInterfaces[*].{ENI:NetworkInterfaceId,Description:Description,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Groups:Groups[*].GroupId,InstanceId:Attachment.InstanceId}' \
  --output table \
  --no-cli-pager
```

---

## 19. Web EC2からRDSへの障害調査例

対象通信:

```text
Source      : sample-ec2-web01
Destination : db.home
Protocol    : TCP
Port        : 3306
```

調査順序:

| No. | 確認 | 判断 |
|---|---|---|
| 1 | `db.home`の名前解決 | RDS Endpoint / Private IPへ解決するか |
| 2 | RDS Status | `available`か |
| 3 | VPC / Subnet | WebとRDSが想定VPC・Subnetにあるか |
| 4 | Route | VPC内`local` Routeがあるか |
| 5 | Web SG outbound | TCP 3306を送信できるか |
| 6 | DB SG inbound | Web SGからTCP 3306を許可するか |
| 7 | NACL | 往路と戻りのEphemeral Portを許可するか |
| 8 | Flow Logs | `ACCEPT` / `REJECT`を確認できるか |
| 9 | DB認証 | ユーザー、パスワード、権限が正しいか |

重要:

```text
Access denied for userは、ネットワーク到達後にDBが返す認証エラーである。

この場合、DNS、Route、SG、NACLだけを直そうとせず、
DBユーザー、パスワード、接続元Host権限を確認する。
```

---

## 20. Web EC2からS3への障害調査例

対象通信:

```text
Source      : sample-ec2-web01
Destination : S3 bucket / S3 API
Protocol    : TCP
Port        : 443
```

調査順序:

| No. | 確認 | 判断 |
|---|---|---|
| 1 | S3 DNS | サービスDNS名を解決できるか |
| 2 | Route Table | S3 Prefix List RouteかNAT Routeか |
| 3 | Endpoint | S3 Gateway / Interface Endpointがあるか |
| 4 | Endpoint Policy | 対象BucketとActionを許可するか |
| 5 | Bucket Policy | `aws:sourceVpce`、TLS条件、Denyを確認する |
| 6 | IAM Role | EC2 Roleが必要なS3 Actionを許可するか |
| 7 | Flow Logs | NAT／Interface Endpointまでの通信を確認できるか |
| 8 | CloudTrail | S3 APIのAccessDeniedや実行主体を確認する |

判断例:

```text
S3 Endpointは未設定である。
Private Web EC2はPrivate Route TableのDefault Routeから
NAT Gatewayを経由してS3へ接続する構成である。

現在のアプリ疎通が正常なら即時障害ではない。
Endpoint化する場合は、Route Table、Endpoint Policy、
Bucket Policy、アプリ試験、切り戻しを事前確認する。
```

---

## 21. CloudTrailで変更履歴を確認する

CloudTrailでは、DNS、Endpoint、Flow Logsに関する設定変更の実行者、時刻、対象を確認する。

### 主なイベント名

| 領域 | 主なイベント |
|---|---|
| Route 53 | `ChangeResourceRecordSets`、`AssociateVPCWithHostedZone`、`DisassociateVPCFromHostedZone` |
| VPC Endpoint | `CreateVpcEndpoint`、`ModifyVpcEndpoint`、`DeleteVpcEndpoints` |
| Flow Logs | `CreateFlowLogs`、`DeleteFlowLogs` |
| VPC DNS属性 | `ModifyVpcAttribute` |

### 最近のイベント確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateVpcEndpoint \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateFlowLogs \
  --query 'Events[*].{EventTime:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

- イベントがない場合、直近90日間のEvent Historyに該当変更がない可能性がある
- CloudTrail Event Historyだけで長期履歴を保証しない
- TrailまたはEvent Data Storeの保存要件も確認する
- Route 53はグローバルサービスのため、記録リージョンや検索条件を確認する

---

## 22. Webコンソール証跡一覧

| No. | ファイル名 | 内容 |
|---|---|---|
| 1 | `01_操作アカウント確認.png` | Accountと操作主体 |
| 2 | `02_sample-vpc確認.png` | VPC ID、CIDR、状態 |
| 3 | `03_VPC_DNS属性確認.png` | DNS Support、DNS Hostnames |
| 4 | `04_Private_Hosted_Zone確認.png` | `home.`の種類 |
| 5 | `05_Private_Hosted_Zone_VPC関連付け確認.png` | 関連VPC |
| 6 | `06_Private_DNSレコード一覧.png` | 内部DNSレコード |
| 7 | `07_Route53_Resolver_Endpoint確認.png` | Resolver Endpoint |
| 8 | `08_Route53_Resolver_Rule確認.png` | Resolver Rule |
| 9 | `09_VPC_Endpoint一覧確認.png` | Endpointの有無 |
| 10 | `10_S3_Bucket_Policy_Endpoint条件確認.png` | `aws:sourceVpce`条件 |
| 11 | `11_VPC_Flow_Logs設定確認.png` | Flow Logsの有無と状態 |

スクリーンショット取得時の注意:

- 操作対象を識別できる情報を含める
- 秘密情報、Access Key、個人情報を含めない
- 画面全体ではなく、確認項目と対象名が読める範囲を取得する
- 変更を行わないため、「編集」「作成」「削除」は押さない

---

## 23. 調査結果の記載例

```text
対象VPC sample-vpc のDNS、VPC Endpoint、VPC Flow Logs設定を確認した。

VPCのenableDnsSupportおよびenableDnsHostnamesは有効である。
Private Hosted Zone home. は対象VPCへ関連付けられており、
bastion.home、web01.home、web02.home、db.homeは
現在のEC2 Private IPおよびRDS Endpointと一致した。

対象VPCにS3 VPC Endpointは存在せず、
Private Web EC2からS3への通信はNAT Gateway経由となる構成である。
現時点でアプリケーション疎通への異常は確認していない。

VPC Flow Logsは未設定であり、
過去通信のACCEPT / REJECTを確認できない状態である。
有効化する場合は、対象範囲、Traffic Type、保存先、保持期間、
費用、IAM Role、監査要件を確認する必要がある。

設定変更は実施していない。
```

## Teams報告例

```text
対象VPCのDNS・Endpoint・Flow Logs確認を完了しました。

・Private DNS: home. は対象VPCへ関連付け済み
・DNSレコード: EC2 Private IP、RDS Endpointと一致
・S3 Endpoint: 未設定。現在はNAT Gateway経由
・VPC Flow Logs: 未設定
・設定変更: なし

Endpoint化およびFlow Logs有効化は改善候補ですが、
通信経路、Policy、保存先、費用、既存アプリ影響の確認が必要です。
```

---

## 24. 未設定項目を見つけたときの判断

未設定を見つけても、直ちに不備や障害と判断しない。

| 未設定項目 | 確認すること |
|---|---|
| S3 Gateway Endpoint | NAT経由を許容する設計か、費用・セキュリティ要件は何か |
| Interface Endpoint | 対象AWS APIへNAT経由で到達できるか、Private化要件はあるか |
| Flow Logs | 監査・障害調査要件、保存先、保持期間、費用は何か |
| Resolver Endpoint | オンプレミスDNS連携要件があるか |
| Resolver Rule | 転送対象Domainと接続先DNSがあるか |

改善候補の報告では、次をセットで示す。

```text
現在状態
期待状態または要件
未設定による影響
変更した場合の影響範囲
必要な事前確認
試験方法
切り戻し方法
```

---

## 25. 変更時の影響調査観点

## Private DNS変更

- どのVPC、オンプレミス、接続先から名前解決されるか
- 同名のPublic Hosted Zoneや別Private Hosted Zoneがないか
- TTLとキャッシュによる反映遅延
- A、CNAME、Aliasの参照先が正しいか
- 切り戻し時に元のRecord Valueへ戻せるか

## VPC Endpoint追加・変更

- Gateway / Interfaceのどちらか
- 対象SubnetまたはRoute Table
- Endpoint Policy
- Interface EndpointのSG
- Private DNSの有効化による名前解決変化
- Bucket PolicyやIAM Policyの`aws:sourceVpce`条件
- NAT Gateway通信量と費用の変化
- 既存アプリ、バッチ、別VPC、オンプレミスへの影響

## Flow Logs有効化・変更

- VPC、Subnet、ENIのどの単位で取得するか
- Traffic Typeを`ALL`、`ACCEPT`、`REJECT`のどれにするか
- CloudWatch Logs、S3、Firehoseのどこへ保存するか
- IAM RoleとResource Policy
- 保持期間、暗号化、アクセス権限
- ログ量と費用
- 機密情報・監査要件

---

## 26. 案件で説明できるポイント

- DNS解決とネットワーク到達性は別の確認である
- Private Hosted Zoneは関連付けたVPC内で利用する
- VPC DNS属性が無効ならPrivate DNSへ影響する
- S3 Gateway EndpointはRoute TableのPrefix List経路で判断する
- S3 EndpointがなくてもNAT Gateway経由で通信できる構成がある
- Endpoint追加時はEndpoint PolicyとBucket Policyを合わせて確認する
- Interface EndpointはENI、SG、Private DNSを使用する
- Flow Logsの`ACCEPT`はApplication正常性を保証しない
- Flow Logs未設定は障害ではないが、調査性・監査性の改善候補になる
- CloudTrailで設定変更者と変更時刻を確認できる

## 資格試験につながるポイント

- Gateway Endpointの対象サービスは主にS3とDynamoDB
- Interface EndpointはAWS PrivateLinkを使用する
- Security GroupはStateful、NACLはStateless
- Route TableはLongest Prefix MatchでRouteを選択する
- Private Hosted ZoneはVPCと関連付けて使用する
- Route 53 ResolverはオンプレミスとVPCのDNS連携に使用する
- VPC Flow Logsは通信メタデータを記録し、パケット本文は記録しない
- GuardDutyによる分析と、人が保存・検索するFlow Logs設定は別である

---

## 27. 要確認事項

実案件では、次を担当者または設計書で確認する。

- Private DNSの管理主体と命名規則
- オンプレミスDNS、閉域網、Route 53 Resolverの構成
- Public / Private Hosted Zoneの同名運用有無
- S3、KMS、Secrets Manager、CloudWatch LogsなどのEndpoint利用方針
- Endpoint PolicyとResource Policyの管理主体
- NAT Gateway経由を許容するAWSサービス
- Flow Logsの取得対象、Traffic Type、保存先、保持期間
- Flow Logs、DNS Query Logs、CloudTrailの監査要件
- 障害調査時に利用できるCloudWatch Logs Insights権限
- 証跡の保存先と持ち出しルール

---

## 28. Day 14完了チェックリスト

- [ ] AWSアカウント、リージョン、対象VPCを確認した
- [ ] VPC DNS SupportとDNS Hostnamesを確認した
- [ ] Private Hosted ZoneとVPC関連付けを確認した
- [ ] Private DNSレコードとEC2・RDSを照合した
- [ ] VPC内EC2から名前解決を確認した
- [ ] Route 53 Resolver EndpointとRuleの有無を確認した
- [ ] VPC Endpoint一覧を確認した
- [ ] S3 Gateway Endpointの有無を確認した
- [ ] Route TableのS3 Prefix List経路を確認した
- [ ] S3 Bucket PolicyのEndpoint条件を確認した
- [ ] VPC Flow Logsの有無と保存先を確認した
- [ ] ACCEPT / REJECTの意味と限界を説明できる
- [ ] Web EC2からRDSへの障害調査順序を説明できる
- [ ] Web EC2からS3への障害調査順序を説明できる
- [ ] CloudTrailで設定変更履歴を確認する方法を確認した
- [ ] 未設定項目を即時変更せず、改善候補として整理した
- [ ] スクリーンショット、CLI結果、報告内容を整理した

## Day 14の完了条件

次を自分の言葉で説明できればDay 14は完了とする。

```text
1. Private Hosted Zoneがどこから名前解決できるか
2. VPC DNS属性がPrivate DNSへ与える影響
3. S3通信がNAT Gateway経由かGateway Endpoint経由かを判断する方法
4. Gateway EndpointとInterface Endpointの違い
5. Endpoint PolicyとBucket Policyを両方確認する理由
6. Flow LogsのACCEPT / REJECTで分かることと分からないこと
7. DNS、Route、SG、NACL、Endpoint、Flow Logsの調査順序
8. 未設定項目を即時変更せず影響調査する理由
```
