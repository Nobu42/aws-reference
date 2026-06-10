# Day 11 Learning: Security Group・Network ACL確認ドリル

## 1. 今日の目的

AWS環境のSecurity GroupとNetwork ACLを確認し、通信要件に対して必要最小限の許可になっているか、通信障害や意図しない公開につながる設定がないかを説明できる状態を目指す。

Day 11で最も重要なポイントは、Security GroupとNetwork ACLの違いを暗記だけで終わらせず、実際の通信経路と戻り通信を含めて判断することである。

```text
Security Group:
リソース単位で適用するStatefulな許可制御。
許可した通信の戻り通信は自動的に許可される。

Network ACL:
Subnet単位で適用するStatelessな許可・拒否制御。
InboundとOutboundの両方向を明示的に許可する必要がある。
```

本ドリルでは設定変更を行わない。Security Group、Security Group Rule、Network ACL、関連Subnet、関連リソースを確認し、設計書との一致、危険な公開ルール、影響範囲、証跡、報告内容を整理する。

関連資料:

- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md)
- [RDS Security CLIリファレンス](../docs/references/09_rds_security_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)
- [Security Group構築スクリプト](../scripts/06_security_group_setup.sh)
- [Web EC2構築スクリプト](../scripts/08_Web_server_setup.sh)
- [RDS構築スクリプト](../scripts/10_Database_setup.sh)
- [ElastiCache構築スクリプト](../scripts/19_elasticache_setup.sh)
- [Day 10 VPC・Subnet・Route Table確認ドリル](./10_Day_Learning.md)

## 今日の調査シナリオ

次の依頼を受けた想定で確認する。

```text
対象VPC内のSecurity GroupとNetwork ACLを確認してください。

外部公開されている通信、Security Group間で許可している通信、
Network ACLのRule番号、Allow/Deny、戻り通信を整理してください。

危険な公開ルールや設計書との差異がある場合は、
設定変更せず、影響範囲と要確認事項を報告してください。
```

## 今日の確認順序

1. AWSアカウント、リージョン、対象VPCを確認する
2. 証跡保存先を準備する
3. Security Group一覧を確認する
4. Security Group RuleをRule単位で確認する
5. InboundとOutboundを分けて確認する
6. `0.0.0.0/0`、`::/0`、全Port許可などの危険候補を確認する
7. Security Group参照ルールを確認する
8. Security Groupが関連付くリソースと影響範囲を確認する
9. Network ACL一覧とSubnet関連付けを確認する
10. NACLのInbound、Outbound、Rule番号、Allow/Denyを確認する
11. 戻り通信とEphemeral Portを確認する
12. 代表的な通信経路ごとにSGとNACLを照合する
13. CloudTrailでSG・NACL変更履歴を確認する
14. 証跡、調査結果、要確認事項、Teams報告を整理する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象VPC名 | `sample-vpc` |
| 主な確認対象 | Security Group、Security Group Rule、Network ACL、ENI |
| 設定変更 | なし |

## ラボ環境の期待Security Group構成

| Security Group | Inbound | Source | 用途 |
|---|---|---|---|
| `sample-sg-bastion` | TCP 22 | 自分のGlobal IP `/32` | BastionへのSSH |
| `sample-sg-elb` | TCP 80 | `0.0.0.0/0` | ALBへのHTTP |
| `sample-sg-elb` | TCP 443 | `0.0.0.0/0` | ALBへのHTTPS |
| `sample-sg-web` | TCP 22 | `sample-sg-bastion` | BastionからWebへのSSH |
| `sample-sg-web` | TCP 3000 | `sample-sg-elb` | ALBからWebアプリへの通信 |
| `sample-sg-db` | TCP 3306 | `sample-sg-web` | WebからRDS MySQLへの通信 |
| `sample-sg-elasticache` | TCP 6379 | `sample-sg-web` | WebからRedisへの通信 |

## 今日実行しない操作

- Security Groupの作成・削除
- Inbound Rule、Outbound Ruleの追加・削除・変更
- Security Groupのリソース関連付け変更
- Network ACLの作成・削除
- Network ACL Entryの追加・置換・削除
- Network ACLとSubnetの関連付け変更
- 疎通試験目的の一時的な全開放
- SSH、RDP、DB、Redis Portの一時公開

---

## 2. Security GroupとNetwork ACLの違い

| 項目 | Security Group | Network ACL |
|---|---|---|
| 適用単位 | ENI・リソース | Subnet |
| 状態管理 | Stateful | Stateless |
| ルール | Allowのみ | AllowとDeny |
| 評価方法 | 一致するAllowがあれば許可 | Rule番号の小さい順に評価し、最初の一致を適用 |
| 戻り通信 | 自動許可 | 反対方向のRuleが必要 |
| 複数適用 | 複数SGのAllowを合算 | Subnetに1つのNACLを関連付け |
| 主な用途 | リソース単位の必要最小限許可 | Subnet境界の追加制御・明示的拒否 |

## Security GroupのStateful性

例として、外部利用者からALBのTCP 443へ接続する場合を考える。

```text
Client -> ALB TCP 443:
ALB Security Group InboundでTCP 443を許可する。

ALB -> Client 戻り通信:
Security GroupはStatefulなため、戻り通信用Inbound/Outbound Ruleを
個別に追加しなくても許可される。
```

ただし、Security GroupのOutboundは新しく開始する通信にも影響するため、設計に応じて確認する。

## Network ACLのStateless性

同じ通信をNACLで制御する場合、受信側だけでなく戻り通信も許可する必要がある。

```text
Public Subnet NACL Inbound:
Client -> ALB TCP 443を許可する。

Public Subnet NACL Outbound:
ALB -> Clientの戻り先Ephemeral Portを許可する。
```

NACLで戻り通信を許可していない場合、Security Groupが正しくても通信できない。

## Security GroupにはDenyがない

Security Groupは許可ルールのみを持つ。特定IPを明示的に拒否するRuleは作成できない。

明示的な拒否が必要な場合は、要件に応じて次を検討する。

- Network ACL
- AWS WAF
- AWS Network Firewall
- OS Firewall
- Application側制御
- 組織ポリシーや他のセキュリティサービス

---

## 3. Sourceに指定したSecurity Groupの意味

Inbound RuleのSourceに別のSecurity Groupを指定した場合、そのSecurity Group IDを持つENIからの通信を許可する。

```text
sample-sg-db:
TCP 3306 Source=sample-sg-web

意味:
sample-sg-webが関連付いたWebサーバーから、
sample-sg-dbが関連付いたRDSへのTCP 3306を許可する。
```

これは、Source Security Group内の全通信を無条件に許可する意味ではない。指定したProtocolとPortだけを許可する。

SG参照を使用する利点:

- IPアドレス変更に追従しやすい
- Auto Scalingなどで台数が変わってもRule変更が不要
- Web層、DB層など役割単位で通信要件を表現できる
- CIDR許可より影響範囲を限定しやすい

確認時は、参照先SGの名前だけでなく、SG IDと関連リソースも確認する。

---

## 4. Network ACLのRule評価

NACLはRule番号の小さい順に評価し、最初に一致したRuleを適用する。

```text
Rule 100 Allow TCP 443 from 0.0.0.0/0
Rule 110 Deny  TCP 443 from 203.0.113.10/32

結果:
203.0.113.10からのTCP 443はRule 100に先に一致するためAllowとなる。
Rule 110のDenyには到達しない。
```

特定IPを拒否したい場合は、Deny RuleをAllow Ruleより小さい番号にする必要がある。

```text
Rule 90  Deny  TCP 443 from 203.0.113.10/32
Rule 100 Allow TCP 443 from 0.0.0.0/0
```

## `*` Rule

NACLには最後に暗黙的なDeny Ruleが存在する。

```text
Rule Number: *
Action: deny
```

どのRuleにも一致しない通信は拒否される。

## Default Network ACL

Default NACLは通常、InboundとOutboundの両方で全通信を許可するRuleを持つ。

```text
Rule 100: Allow all traffic
Rule *  : Deny all traffic
```

Default NACLを使用している場合、細かな通信制御はSecurity Group側が中心になる。ただし、金融案件ではDefault NACL利用の妥当性や、カスタムNACL要件を確認する。

---

## 5. Ephemeral Portの考え方

Ephemeral Portは、Client側が一時的に使用する送信元Portである。

WebサーバーからRDSのTCP 3306へ接続する例:

```text
Web EC2 -> RDS:
送信元Port: Ephemeral Port
宛先Port  : 3306

RDS -> Web EC2 戻り通信:
送信元Port: 3306
宛先Port  : Web EC2が使用したEphemeral Port
```

NACLはStatelessなため、通信方向ごとに必要Portを許可する。

| 通信 | Source Subnet NACL | Destination Subnet NACL |
|---|---|---|
| WebからRDSへの要求 | OutboundでTCP 3306を許可 | InboundでTCP 3306を許可 |
| RDSからWebへの戻り | InboundでEphemeral Portを許可 | OutboundでEphemeral Portを許可 |

Ephemeral Port範囲はOS、Client、通信方式によって異なる。`1024-65535`を例として見ることは多いが、現場では利用OS、設計標準、実際の要件を確認する。

---

## 6. 作業開始条件と中止・報告条件

## 作業開始条件

- 対象AWSアカウントが確認できている
- 対象リージョンが確認できている
- 対象VPCが一意に特定できている
- 設計書または通信要件を確認できる
- 確認のみであり、設定変更を行わないことが明確である
- 証跡保存先が準備できている

## 中止・即時報告条件

- 想定AWSアカウントと一致しない
- 対象VPCが複数あり一意に特定できない
- SSH、RDP、DB、Redis、全Portなどの意図しない公開を確認した
- 想定外のSecurity Group参照を確認した
- NACLで想定外のDenyまたは全許可を確認した
- Ruleの目的や所有者が不明である
- 設計書と実環境に重大な差異がある
- 調査中に変更操作が必要になった

---

## 7. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
VPC_NAME="sample-vpc"
WORK_NAME="sg_nacl_check"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nWORK_NAME=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" "$WORK_NAME"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID VPC_NAME WORK_NAME; do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

---

## 8. 証跡保存用ディレクトリの作成

```bash
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/investigation" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

### 証跡ディレクトリ確認

```bash
find "$EVIDENCE_DIR" \
  -maxdepth 1 \
  -type d \
  -print
```

想定構成:

| ディレクトリ | 用途 |
|---|---|
| `00_metadata` | Caller Identity、対象VPCなど |
| `before` | SG、Rule、NACLの全体証跡 |
| `investigation` | 個別SG、関連リソース、CloudTrail調査 |
| `screenshots` | Webコンソールの画面証跡 |

---

## 9. AWSアカウントと対象VPCを確認する

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. リージョンを東京リージョンへ切り替える
4. VPCコンソールを開く
5. `sample-vpc`が存在することを確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_対象VPC確認.png
```

### Caller Identity

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
```

### 対象VPCを一意に特定する

```bash
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text \
  --no-cli-pager)

echo "VPC count: $VPC_COUNT"
```

```bash
if [ "$VPC_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one VPC named $VPC_NAME."
  return 1 2>/dev/null || exit 1
fi
```

### VPC ID取得

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --no-cli-pager)

echo "Target VPC ID: $VPC_ID"
```

```bash
aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/01_target_vpc.json"
```

---

## 10. Security Group一覧を確認する

### Webコンソール

1. VPCコンソールを開く
2. 左側メニューの「セキュリティグループ」を開く
3. VPC IDで対象VPCへ絞り込む
4. Group Name、Group ID、説明、VPC ID、タグを確認する
5. 想定外または用途不明のSGがないか確認する

取得するスクリーンショット:

```text
03_Security_Group一覧.png
```

### AWS CLI

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[].{Name:GroupName,GroupId:GroupId,Description:Description,VpcId:VpcId,OwnerId:OwnerId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/01_security_groups.json"
```

### 確認ポイント

- 対象SGが想定VPC内に存在するか
- SG名、説明、タグから用途を判断できるか
- Default Security Groupが利用されていないか
- 用途不明、重複、未使用のSGがないか
- 想定SGが不足していないか

ラボ環境の主な期待SG:

```text
sample-sg-bastion
sample-sg-elb
sample-sg-web
sample-sg-db
sample-sg-elasticache
```

---

## 11. Security Group IDを取得する

SG名だけでなく、変更・調査対象を一意に示すSG IDを取得する。

```bash
BASTION_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=sample-sg-bastion \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

ELB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=sample-sg-elb \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

WEB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=sample-sg-web \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

DB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=sample-sg-db \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

ELASTICACHE_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=sample-sg-elasticache \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)
```

### 取得結果確認

```bash
printf 'BASTION_SG_ID=%s\nELB_SG_ID=%s\nWEB_SG_ID=%s\nDB_SG_ID=%s\nELASTICACHE_SG_ID=%s\n' \
  "$BASTION_SG_ID" "$ELB_SG_ID" "$WEB_SG_ID" "$DB_SG_ID" "$ELASTICACHE_SG_ID"
```

存在しないSGは`None`になる可能性がある。構築内容によってElastiCacheを作成していない場合などは、未確認事項として記録する。

---

## 12. Security Group RuleをRule単位で確認する

`describe-security-group-rules`を使用すると、Ingress/Egress、Rule ID、CIDR、参照SG、DescriptionをRule単位で確認できる。

### Webコンソール

1. 対象Security Groupを選択する
2. 「インバウンドルール」を確認する
3. 「アウトバウンドルール」を確認する
4. Protocol、Port、Source/Destination、Descriptionを確認する
5. 「ルールを編集」は押さない

取得するスクリーンショット:

```text
04_Security_Group_Inbound確認.png
05_Security_Group_Outbound確認.png
```

### 全Rule確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,PrefixList:PrefixListId,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/02_security_group_rules.json"
```

### Rule IDを確認する理由

- 変更対象を一意に示せる
- 追加・削除したRuleを追跡しやすい
- Descriptionを含めてレビューしやすい
- 切り戻し対象を特定しやすい
- 同じPortでもSourceが異なるRuleを区別できる

---

## 13. Inbound Ruleを確認する

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- 必要なProtocolとPortだけを許可しているか
- SourceがCIDRかSG参照か
- `0.0.0.0/0`や`::/0`が要件上必要か
- SSH/RDPが管理端末や踏み台に限定されているか
- DB/RedisがWeb SGからのみに限定されているか
- 一時作業用Ruleが残っていないか
- Descriptionから目的と期限が分かるか

---

## 14. Outbound Ruleを確認する

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=true \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,DestinationSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 結果の読み方

```text
Protocol=-1
Cidr4=0.0.0.0/0
```

上記はIPv4の全Protocol・全PortへのOutbound許可を表す。

Outbound全許可はAWSのDefault設定としてよく使われるが、金融案件では次を確認する。

- 設計標準として許容されているか
- 外部送信先を制限する要件があるか
- VPC Endpoint、Proxy、Firewall経由に限定する要件があるか
- Applicationが必要とする通信先を把握しているか
- 制限した場合のOS Update、監視、外部API、AWS APIへの影響

Security GroupはStatefulだが、Outbound Ruleが不要という意味ではない。リソースから新しく開始する通信にはOutbound Ruleが影響する。

---

## 15. 危険な公開ルール候補を確認する

### IPv4・IPv6の全体公開

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?CidrIpv4==`0.0.0.0/0` || CidrIpv6==`::/0`].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,Description:Description}' \
  --output table \
  --no-cli-pager
```

`0.0.0.0/0`または`::/0`があるだけで即問題とは限らない。Internet-facing ALBの80/443など、公開要件があるRuleは妥当な場合がある。

### 特に注意するPort

| Port | 用途例 | 公開時の主なリスク |
|---|---|---|
| 22 | SSH | 不正ログイン、脆弱性攻撃 |
| 3389 | RDP | 不正ログイン、脆弱性攻撃 |
| 3306 | MySQL | DBへの直接攻撃 |
| 5432 | PostgreSQL | DBへの直接攻撃 |
| 6379 | Redis | データ漏えい、改ざん |
| 9200 | Elasticsearch | データ漏えい |
| 0-65535 | 全Port | 広範な攻撃面 |

### 全Protocol公開候補

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?IpProtocol==`-1`].{RuleId:SecurityGroupRuleId,GroupId:GroupId,Cidr4:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 判定時の注意

- 公開範囲だけでなく、関連リソースも確認する
- SGが未使用なら直ちに通信へ影響しないが、将来誤使用されるリスクがある
- Public IPやInternet向けRouteがなくても、閉域網・Peering・Transit Gatewayなどから到達する可能性がある
- `0.0.0.0/0`を見つけても、承認なく削除しない

---

## 16. ラボの期待Ruleと照合する

### Bastion SG

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$BASTION_SG_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

期待:

```text
Inbound TCP 22:
自分のGlobal IP /32からのみ許可
```

Global IPが変わるとSSHできなくなるため、現在値と設計値の違いが意図したものか確認する。

### ALB SG

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$ELB_SG_ID" \
  --output table \
  --no-cli-pager
```

期待:

```text
Inbound TCP 80  from 0.0.0.0/0
Inbound TCP 443 from 0.0.0.0/0
```

Internet-facing ALBの公開要件として妥当か、HTTPSへ統一する予定があるかを確認する。

### Web SG

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$WEB_SG_ID" \
  --output table \
  --no-cli-pager
```

期待:

```text
Inbound TCP 22   from sample-sg-bastion
Inbound TCP 3000 from sample-sg-elb
```

Web EC2はPrivate Subnetにあり、Internetから直接SSH・Application Portへ接続させない。

### DB SG

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output table \
  --no-cli-pager
```

期待:

```text
Inbound TCP 3306 from sample-sg-web
```

### ElastiCache SG

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$ELASTICACHE_SG_ID" \
  --output table \
  --no-cli-pager
```

期待:

```text
Inbound TCP 6379 from sample-sg-web
```

---

## 17. Default Security Groupを確認する

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=default \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/03_default_security_group.json"
```

```bash
DEFAULT_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=default \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

echo "Default Security Group: $DEFAULT_SG_ID"
```

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DEFAULT_SG_ID" \
  --output table \
  --no-cli-pager
```

Default SGは通常、自分自身をSourceとするInbound Ruleを持つ。Default SGをリソースに使用していないか、意図しない相互通信が発生しないか確認する。

---

## 18. Security Groupが関連付くENIを確認する

Security Group変更の影響範囲は、SG名だけでは判断できない。SGが関連付くENIとリソースを確認する。

### VPC内ENI一覧

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:Association.PublicIp,Groups:Groups[].GroupId,InstanceId:Attachment.InstanceId,RequesterManaged:RequesterManaged}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/04_network_interfaces.json"
```

### 特定SGが関連付くENI

```bash
SG_ID="$WEB_SG_ID"

aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$SG_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,InstanceId:Attachment.InstanceId,Groups:Groups[].GroupId}' \
  --output table \
  --no-cli-pager
```

### 確認ポイント

- 同じSGを複数リソースが利用していないか
- EC2、ALB、RDS、ElastiCache、Lambda、VPC Endpointなどを識別できるか
- SG変更が複数環境・複数システムへ影響しないか
- 未使用SGか、ENIを持たないサービスへ使用されているか
- Descriptionからリソースを識別できるか

---

## 19. サービスごとのSecurity Group関連付けを確認する

### EC2

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[].GroupId}' \
  --output table \
  --no-cli-pager
```

### ALB

```bash
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'LoadBalancers[].{Name:LoadBalancerName,Scheme:Scheme,VpcId:VpcId,SecurityGroups:SecurityGroups,Subnets:AvailabilityZones[].SubnetId,State:State.Code}' \
  --output table \
  --no-cli-pager
```

### RDS

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[].{DBInstance:DBInstanceIdentifier,Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,VpcId:DBSubnetGroup.VpcId,SecurityGroups:VpcSecurityGroups[].VpcSecurityGroupId,Endpoint:Endpoint.Address,Port:Endpoint.Port}' \
  --output table \
  --no-cli-pager
```

### ElastiCache

```bash
aws elasticache describe-cache-clusters \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'CacheClusters[].{CacheClusterId:CacheClusterId,ReplicationGroupId:ReplicationGroupId,Status:CacheClusterStatus,SecurityGroups:SecurityGroups[].SecurityGroupId,SubnetGroup:CacheSubnetGroupName}' \
  --output table \
  --no-cli-pager
```

サービスごとの確認結果とENIの確認結果を照合し、SG変更の影響リソースを整理する。

---

## 20. Network ACL一覧とSubnet関連付けを確認する

### Webコンソール

1. VPCコンソールを開く
2. 左側メニューの「ネットワークACL」を開く
3. VPC IDで対象VPCへ絞り込む
4. NACL ID、Default有無、関連Subnetを確認する
5. 「インバウンドルール」と「アウトバウンドルール」を確認する
6. 「ネットワークACLを編集」は押さない

取得するスクリーンショット:

```text
06_Network_ACL一覧.png
07_Network_ACL_Subnet関連付け.png
```

### AWS CLI

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,IsDefault:IsDefault,AssociatedSubnets:Associations[].SubnetId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/05_network_acls.json"
```

### 確認ポイント

- 各SubnetがどのNACLに関連付いているか
- Default NACLかカスタムNACLか
- 1つのNACLが複数Subnetへ影響していないか
- PublicとPrivateでNACLを分けているか
- 関連付けが設計書と一致するか

---

## 21. Network ACL Entryを確認する

### Inbound Rule

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,IsDefault:IsDefault,Inbound:Entries[?Egress==`false`].{Rule:RuleNumber,Action:RuleAction,Protocol:Protocol,Cidr4:CidrBlock,Cidr6:Ipv6CidrBlock,From:PortRange.From,To:PortRange.To}}' \
  --output json \
  --no-cli-pager
```

### Outbound Rule

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,IsDefault:IsDefault,Outbound:Entries[?Egress==`true`].{Rule:RuleNumber,Action:RuleAction,Protocol:Protocol,Cidr4:CidrBlock,Cidr6:Ipv6CidrBlock,From:PortRange.From,To:PortRange.To}}' \
  --output json \
  --no-cli-pager
```

取得するスクリーンショット:

```text
08_Network_ACL_Inbound確認.png
09_Network_ACL_Outbound確認.png
```

### Protocolの読み方

| Protocol値 | 意味 |
|---|---|
| `-1` | 全Protocol |
| `6` | TCP |
| `17` | UDP |
| `1` | ICMP |

### 確認ポイント

- Rule番号の小さい順で意図どおり評価されるか
- AllowとDenyの順序が適切か
- InboundとOutboundが対になっているか
- 戻り通信のEphemeral Portが許可されているか
- 全通信Allowが設計上妥当か
- `*` Denyだけになっていないか
- IPv6利用時にIPv6 Ruleも確認しているか

---

## 22. 各Subnetに関連付くNACLを確認する

Day 10で取得したSubnet IDを使用する。

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],SubnetId:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock}' \
  --output table \
  --no-cli-pager
```

特定SubnetのNACL確認:

```bash
SUBNET_ID="<subnet-id>"

aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=association.subnet-id,Values="$SUBNET_ID" \
  --query 'NetworkAcls[].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,IsDefault:IsDefault,Associations:Associations,Entries:Entries}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/network_acl_for_${SUBNET_ID}.json"
```

明示的なNACL関連付けがあるかを確認し、Public/Private Subnetごとの影響範囲を整理する。

---

## 23. 代表通信1: InternetからALB、Web EC2

```text
Internet Client
  -> Public Subnet NACL Inbound
  -> ALB Security Group Inbound TCP 80/443
  -> ALB Listener
  -> ALB Security Group Outbound TCP 3000
  -> Private Subnet NACL Inbound TCP 3000
  -> Web Security Group Inbound TCP 3000 from ALB SG
  -> Web EC2
```

戻り通信:

```text
Web EC2
  -> Web Security GroupはStatefulのため戻り通信を許可
  -> Private Subnet NACL Outbound
  -> ALB
  -> ALB Security GroupはStatefulのため戻り通信を許可
  -> Public Subnet NACL Outbound
  -> Internet Client
```

確認項目:

- ALB SGの80/443公開が要件どおりか
- Web SGの3000がALB SGからのみに限定されているか
- Public/Private NACLが双方向通信を許可しているか
- ALB Target Healthが正常か
- Web EC2へInternetから直接到達する経路がないか

---

## 24. 代表通信2: BastionからWeb EC2へSSH

```text
管理端末
  -> Bastion SG Inbound TCP 22 from 管理端末Global IP /32
  -> Bastion EC2
  -> Web SG Inbound TCP 22 from Bastion SG
  -> Web EC2
```

確認項目:

- Bastion SGのTCP 22が`0.0.0.0/0`ではないか
- 許可CIDRが現在の管理端末Global IPと一致するか
- Web SGがBastion SG参照になっているか
- Web SGで管理端末CIDRや`0.0.0.0/0`を直接許可していないか
- Public/Private SubnetのNACLがSSHと戻り通信を許可しているか

---

## 25. 代表通信3: Web EC2からRDS

```text
Web EC2 / sample-sg-web
  -> Web SG Outbound
  -> Web Subnet NACL Outbound TCP 3306
  -> DB Subnet NACL Inbound TCP 3306
  -> RDS / sample-sg-db Inbound TCP 3306 from sample-sg-web
```

戻り通信では、NACLの反対方向でEphemeral Portを許可する必要がある。

確認項目:

- DB SGがWeb SGからのTCP 3306だけを許可しているか
- DB SGで`0.0.0.0/0`やVPC全体CIDRを許可していないか
- Web SG Outboundが必要通信を許可しているか
- Web SubnetとDB SubnetのNACLが双方向通信を許可しているか
- RDSがPublicly Accessibleではないか

---

## 26. 代表通信4: Web EC2からElastiCache

```text
Web EC2 / sample-sg-web
  -> Web SG Outbound
  -> Web Subnet NACL Outbound TCP 6379
  -> ElastiCache Subnet NACL Inbound TCP 6379
  -> ElastiCache / sample-sg-elasticache Inbound TCP 6379 from sample-sg-web
```

確認項目:

- ElastiCache SGがWeb SGからのTCP 6379だけを許可しているか
- Redis Portを外部公開していないか
- NACLで要求と戻り通信を許可しているか
- Transit EncryptionやAt-rest Encryption要件を確認しているか

---

## 27. 設計書と実環境を照合する

| 確認対象 | 設計値 | 実環境 | 判定 | 要確認事項 |
|---|---|---|---|---|
| Bastion SG | TCP 22 from 管理端末 `/32` |  |  |  |
| ALB SG | TCP 80/443 from Internet |  |  |  |
| Web SG SSH | TCP 22 from Bastion SG |  |  |  |
| Web SG App | TCP 3000 from ALB SG |  |  |  |
| DB SG | TCP 3306 from Web SG |  |  |  |
| ElastiCache SG | TCP 6379 from Web SG |  |  |  |
| SG Outbound | 設計方針を確認 |  |  |  |
| NACL Association | 対象Subnetと一致 |  |  |  |
| NACL Inbound | 必要通信を許可 |  |  |  |
| NACL Outbound | 戻り通信を許可 |  |  |  |

差異を確認した場合は、次の順序で整理する。

1. 差異の内容
2. 影響するSG、NACL、Subnet、リソース
3. 現在の通信影響
4. 意図した設定か
5. 変更要否
6. 変更する場合の試験と切り戻し

---

## 28. CloudTrailでSecurity Group変更履歴を確認する

### 代表イベント一覧

| 操作 | CloudTrail Event Name |
|---|---|
| SG作成 | `CreateSecurityGroup` |
| SG削除 | `DeleteSecurityGroup` |
| Inbound追加 | `AuthorizeSecurityGroupIngress` |
| Inbound削除 | `RevokeSecurityGroupIngress` |
| Inbound更新 | `ModifySecurityGroupRules` |
| Outbound追加 | `AuthorizeSecurityGroupEgress` |
| Outbound削除 | `RevokeSecurityGroupEgress` |

### 変更履歴確認

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[?EventName==`CreateSecurityGroup` || EventName==`DeleteSecurityGroup` || EventName==`AuthorizeSecurityGroupIngress` || EventName==`RevokeSecurityGroupIngress` || EventName==`AuthorizeSecurityGroupEgress` || EventName==`RevokeSecurityGroupEgress` || EventName==`ModifySecurityGroupRules`].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

証跡保存:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[?EventName==`CreateSecurityGroup` || EventName==`DeleteSecurityGroup` || EventName==`AuthorizeSecurityGroupIngress` || EventName==`RevokeSecurityGroupIngress` || EventName==`AuthorizeSecurityGroupEgress` || EventName==`RevokeSecurityGroupEgress` || EventName==`ModifySecurityGroupRules`]' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/investigation/06_cloudtrail_security_group_events.json"
```

確認ポイント:

- いつ変更されたか
- 誰が変更したか
- どのAPI操作か
- 対象SGは何か
- Source、Port、Protocolは何か
- Error Codeがないか
- 承認された作業と一致するか

---

## 29. CloudTrailでNetwork ACL変更履歴を確認する

### 代表イベント一覧

| 操作 | CloudTrail Event Name |
|---|---|
| NACL作成 | `CreateNetworkAcl` |
| NACL削除 | `DeleteNetworkAcl` |
| Entry追加 | `CreateNetworkAclEntry` |
| Entry置換 | `ReplaceNetworkAclEntry` |
| Entry削除 | `DeleteNetworkAclEntry` |
| Subnet関連付け置換 | `ReplaceNetworkAclAssociation` |

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --query 'Events[?EventName==`CreateNetworkAcl` || EventName==`DeleteNetworkAcl` || EventName==`CreateNetworkAclEntry` || EventName==`ReplaceNetworkAclEntry` || EventName==`DeleteNetworkAclEntry` || EventName==`ReplaceNetworkAclAssociation`].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

CloudTrail Event Historyは直近90日間のManagement Event確認に使用できる。長期保管や詳細な検索要件がある場合はTrailやCloudTrail Lakeの設計を確認する。

---

## 30. SG・NACL変更時の影響調査

Day 11では変更しない。今後の変更作業に備えて確認項目を整理する。

## Security Group変更前確認

- 対象アカウント、リージョン、VPC、SG ID
- 変更対象Rule ID
- IngressまたはEgress
- Protocol、Port、Source/Destination
- SourceがCIDRかSG参照か
- SGを使用する全リソース
- 許可する通信と拒否を維持する通信
- Applicationの依存通信
- 変更後試験
- 切り戻しRule

## Network ACL変更前確認

- 対象NACL ID
- 関連Subnetすべて
- 影響するリソースすべて
- InboundまたはOutbound
- Rule番号と評価順序
- AllowまたはDeny
- Protocol、Port、CIDR
- 戻り通信とEphemeral Port
- 既存Ruleとの競合
- 変更後試験と切り戻しEntry

## 主な影響

| 変更 | 主な影響 |
|---|---|
| SG Inbound追加 | 新しい通信元から接続可能になる |
| SG Inbound削除 | 利用中通信が接続できなくなる |
| SG Outbound制限 | 外部API、AWS API、監視、Updateなどが失敗する |
| SG参照変更 | 複数リソースの通信可否が変わる |
| NACL Allow追加 | Subnet全体へ新しい通信を許可する |
| NACL Deny追加 | Rule順序によって広範囲の通信を遮断する |
| NACL関連付け変更 | Subnet内の全リソースへ即時影響する |

---

## 31. 推奨するスクリーンショット証跡

| No. | ファイル名 | 画面 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウント情報 |
| 02 | `02_対象VPC確認.png` | 対象VPC |
| 03 | `03_Security_Group一覧.png` | 対象VPC内SG一覧 |
| 04 | `04_Security_Group_Inbound確認.png` | 対象SG Inbound |
| 05 | `05_Security_Group_Outbound確認.png` | 対象SG Outbound |
| 06 | `06_Network_ACL一覧.png` | 対象VPC内NACL一覧 |
| 07 | `07_Network_ACL_Subnet関連付け.png` | NACL関連Subnet |
| 08 | `08_Network_ACL_Inbound確認.png` | NACL Inbound |
| 09 | `09_Network_ACL_Outbound確認.png` | NACL Outbound |
| 10 | `10_CloudTrail変更履歴確認.png` | SG・NACL変更履歴 |

スクリーンショットには可能な範囲で次を含める。

- AWSアカウントを識別できる情報
- リージョン
- 対象VPC ID
- SG IDまたはNACL ID
- Rule内容
- 取得日時

秘密情報、個人情報、不要なアカウント情報が含まれる場合は、現場ルールに従ってマスキングする。

---

## 32. 証跡ファイルを確認する

### 全証跡

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -print \
  | sort
```

### 空ファイル

```bash
find "$EVIDENCE_DIR" \
  -type f \
  -size 0 \
  -print \
  | sort
```

### ファイル数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

### 証跡確認ポイント

- Caller Identityがあるか
- 対象VPCの証跡があるか
- SG一覧とRule一覧があるか
- NACL一覧とEntryがあるか
- ENIと関連リソースを確認できるか
- CloudTrail変更履歴があるか
- 空ファイルの理由を説明できるか
- ファイル名から内容を識別できるか

---

## 33. 調査結果テンプレート

```text
作業名:
Security Group・Network ACL設定確認

作業日時:
YYYY-MM-DD HH:MM - HH:MM

作業者:
<氏名>

対象:
AWS Account: <account-id>
Region: <region>
VPC: <vpc-name> / <vpc-id>

設定変更:
なし

Security Group確認結果:
- SG数:
- Default SG利用:
- 危険な公開Rule:
- SSH/RDP公開:
- DB/Redis公開:
- SG参照Rule:
- Outbound全許可:
- 用途不明SG:

期待Ruleとの照合:
- Bastion SG:
- ALB SG:
- Web SG:
- DB SG:
- ElastiCache SG:

関連リソース:
- EC2:
- ALB:
- RDS:
- ElastiCache:
- その他ENI:

Network ACL確認結果:
- NACL数:
- Default NACL利用:
- 関連Subnet:
- Inbound:
- Outbound:
- Allow/Deny順序:
- Ephemeral Port:
- 要確認Rule:

設計書との差異:
- <なし、または差異内容>

影響範囲:
- <関連リソース、関連Subnet、利用通信>

CloudTrail確認:
- 対象イベント:
- 変更日時:
- 操作者:
- Event ID:

判定:
- 良好:
- 改善候補:
- 要確認:
- 即時報告:

証跡保存先:
<evidence-directory>

備考:
- 設定変更は実施していない
```

---

## 34. Teams報告例

### 問題がない場合

```text
対象VPCのSecurity GroupおよびNetwork ACL設定を確認しました。

Security Groupは、Bastion、ALB、Web、RDS、ElastiCacheの役割ごとに分離され、
WebからRDSへの3306、WebからElastiCacheへの6379など、
Security Group参照による必要最小限の許可であることを確認しました。

Network ACLは対象Subnetとの関連付け、Inbound、Outbound、
Rule番号、Allow/Deny、戻り通信を確認しました。

現時点で即時対応が必要な意図しない公開Ruleは確認されていません。
設定変更は実施していません。
証跡は <保存先> に保存しました。
```

### 要確認事項がある場合

```text
対象VPCのSecurity GroupおよびNetwork ACL設定を確認しました。

<SG ID / NACL ID> に次の要確認事項があります。
- 設定内容:
- 関連リソース:
- 関連Subnet:
- 想定影響:
- 設計書との差異:

設定の目的と利用状況を確認する必要があるため、
現時点では変更を実施していません。
証跡は <保存先> に保存しました。
```

### 危険な公開Ruleを確認した場合

```text
対象VPCのSecurity Group確認で、外部公開範囲が広いRuleを確認しました。

対象SG:
Rule ID:
Protocol / Port:
Source:
関連リソース:
想定リスク:

業務通信への影響が不明なため、Rule削除・変更は実施していません。
公開要件、利用状況、変更後試験、切り戻し方法の確認をお願いします。
```

---

## 35. よくある問題と切り分け

## Security Groupは許可しているが通信できない

- Route Tableに経路があるか
- NACLがInboundとOutboundを許可しているか
- 戻り通信のEphemeral Portを許可しているか
- 宛先PortでApplicationがListenしているか
- OS Firewallが許可しているか
- DNS名前解決が正しいか
- 接続先IP・Portが正しいか

## ALBからWeb EC2へ接続できない

- ALB SG OutboundがWeb Portを許可しているか
- Web SG InboundがALB SGをSourceにしているか
- Target Group PortとWeb Listen Portが一致するか
- Private Subnet NACLが双方向通信を許可しているか
- Target Health CheckのPathとPortが正しいか

## Web EC2からRDSへ接続できない

- DB SG InboundがWeb SGからTCP 3306を許可しているか
- Web EC2に期待するWeb SGが関連付いているか
- RDSに期待するDB SGが関連付いているか
- NACLがTCP 3306と戻り通信を許可しているか
- RDS Endpoint、Port、認証情報が正しいか
- DBがAvailableか

## SSH接続できない

- Bastion SGの許可Global IPが現在値と一致するか
- BastionにPublic IPがあるか
- Public Subnet RouteがIGWへ向くか
- Web SGがBastion SGからのTCP 22を許可しているか
- NACLがSSHと戻り通信を許可しているか
- Key Pair、OSユーザー、sshdを確認する

## NACL変更後に複数システムで通信障害が発生した

- 変更NACLに関連付くSubnetをすべて確認する
- Rule番号と最初に一致するRuleを確認する
- InboundとOutboundを確認する
- Allow/Denyの順序を確認する
- Ephemeral Portを確認する
- 変更前Entryへ切り戻せるか確認する

---

## 36. セキュリティ上の注意点

- SG名だけでなくSG IDとVPC IDを確認する
- SG変更前に関連リソースをすべて確認する
- `0.0.0.0/0`と`::/0`の両方を確認する
- SSH、RDP、DB、Redis、管理Portを広く公開しない
- CIDRよりSG参照が適切な内部通信ではSG参照を検討する
- Default SGを安易に利用しない
- Outbound全許可の妥当性を確認する
- NACLはSubnet全体へ影響することを認識する
- NACLのRule番号と評価順序を確認する
- NACL変更時は戻り通信を必ず確認する
- 一時Ruleには目的、期限、削除予定を記録する
- 設計書との差異を承認なく修正しない
- 調査用に全開放しない

---

## 37. 案件で説明できるポイント

### SGとNACLの違い

```text
Security GroupはENI・リソース単位のStatefulな許可制御で、
許可した通信の戻り通信は自動的に許可されます。

Network ACLはSubnet単位のStatelessな許可・拒否制御で、
InboundとOutboundの両方向、Rule番号、戻り通信を確認します。
```

### 危険な公開Ruleの確認

```text
0.0.0.0/0や::/0のRuleを抽出し、
Protocol、Port、関連リソース、公開要件を確認します。

公開Ruleが存在しても直ちに削除せず、
業務要件、影響範囲、試験、切り戻しを確認してから変更します。
```

### SG参照Rule

```text
DBやRedisへの接続はVPC全体CIDRではなく、
Web Security GroupをSourceにすることで、
Web層のリソースから必要Portだけを許可できます。
```

### 影響調査

```text
Security Group変更前には関連ENIと利用サービスを確認します。
Network ACL変更前には関連SubnetとSubnet内の全リソースを確認します。

特にNACLはStatelessでSubnet全体へ影響するため、
戻り通信とEphemeral Portを含めて確認します。
```

---

## 38. 資格試験につながるポイント

- Security GroupはStateful
- Network ACLはStateless
- Security GroupはAllow Ruleのみ
- Network ACLはAllowとDenyを持つ
- Security Groupは複数関連付けでき、許可Ruleを合算する
- Subnetには1つのNACLが関連付く
- NACLはRule番号の小さい順に評価する
- NACLは最初に一致したRuleを適用する
- NACLには最後に`*` Deny Ruleがある
- Default NACLは通常、Inbound/Outboundを全許可する
- Custom NACLは作成直後、通常すべての通信を拒否する
- Security GroupのSourceに別SGを指定できる
- SG参照は指定Portの通信を許可する
- NACLでは戻り通信とEphemeral Portの考慮が必要
- SGだけでなくRoute、NACL、OS Firewall、Application Portも通信可否に影響する

---

## 39. 要確認事項

案件参画後、次を確認する。

- SG・NACLの命名規則
- SG Rule Descriptionの記載標準
- SG Rule IDを手順書へ記載するか
- Inbound/Outboundの標準設定
- Outbound全許可の許容方針
- Default SG利用方針
- Default NACL・Custom NACL利用方針
- Ephemeral Portの標準範囲
- IPv6利用有無
- 踏み台、SSM Session Manager、管理接続の標準方式
- 閉域網、Firewall、Proxy、Transit Gatewayとの関係
- SG/NACL変更の承認フロー
- 変更前・変更後の試験方法
- CloudTrail証跡の保存先
- スクリーンショットの取得・マスキングルール
- 設定差異を確認した場合の報告先

不明な項目は合理的に推測して設定変更せず、未確認事項として手順書と報告へ残す。

---

## 40. Day 11完了チェックリスト

- [ ] AWSアカウントとリージョンを確認した
- [ ] 対象VPCを一意に特定した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] 対象VPC内のSecurity Group一覧を確認した
- [ ] Security Group RuleをRule単位で確認した
- [ ] InboundとOutboundを分けて確認した
- [ ] `0.0.0.0/0`と`::/0`の公開Ruleを確認した
- [ ] SSH、RDP、DB、Redis、全Port公開を確認した
- [ ] Security Group参照Ruleを確認した
- [ ] Default Security Groupを確認した
- [ ] SGが関連付くENIとリソースを確認した
- [ ] EC2、ALB、RDS、ElastiCacheのSG関連付けを確認した
- [ ] Network ACL一覧を確認した
- [ ] NACLとSubnetの関連付けを確認した
- [ ] NACL InboundとOutboundを確認した
- [ ] Rule番号とAllow/Denyの評価順序を確認した
- [ ] 戻り通信とEphemeral Portを確認した
- [ ] 代表的な通信経路ごとにSGとNACLを照合した
- [ ] 設計書と実環境を照合した
- [ ] CloudTrailでSG・NACL変更履歴を確認した
- [ ] 影響範囲と要確認事項を整理した
- [ ] 証跡ファイルと空ファイルを確認した
- [ ] Teams報告文を作成した
- [ ] 設定変更を実施していないことを確認した

## Day 11の完了条件

次を自分の言葉で説明できればDay 11は完了とする。

```text
Security Groupはリソース単位のStatefulな許可制御であり、
許可した通信の戻り通信は自動的に許可される。

Network ACLはSubnet単位のStatelessな許可・拒否制御であり、
InboundとOutboundの両方向、Rule番号、Allow/Deny、
戻り通信のEphemeral Portを確認する必要がある。

Security GroupやNetwork ACLを変更する前には、
対象ID、関連ENI、関連Subnet、関連リソース、通信要件、
変更後試験、切り戻しを整理する。

危険な公開Ruleや設計書との差異を確認しても、
業務影響が不明な状態では変更せず、証跡と影響範囲を報告する。
```
