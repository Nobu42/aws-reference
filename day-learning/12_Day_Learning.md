# Day 12 Learning: Security Group変更影響調査・手順書作成

## 学習開始前に実行するスクリプト

Day 12はSecurity Group、Web EC2、RDS、DNS、既存Ruleを確認するため、`sample-vpc`が存在しない場合は最初に日次ラボ環境を構築する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

手順書へ記載するアプリケーション確認とDB利用状態を実物で確認する場合は、Ansibleも実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

CloudTrail一時TrailとS3 Data Eventは不要である。Day 13を続けない場合は、学習終了後に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

## 1. 今日の目的

Web Security GroupからRDS Security GroupへTCP 3306を許可する変更を想定し、レビューに提出できる粒度の影響調査と作業手順書を作成する。

Day 12では実際のSecurity Group変更を行わない。変更前確認、影響範囲、変更手順、変更後確認、疎通試験、切り戻し、証跡、報告内容を事前に整理する。

```text
Day 11:
現在のSecurity GroupとNetwork ACLを確認する。

Day 12:
承認済みの変更を安全に実施できる手順書を作る。

Day 13:
手順書に沿って模擬変更、確認、切り戻しを実施する。
```

関連資料:

- [Day 11 Security Group・Network ACL確認ドリル](./11_Day_Learning.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [RDS Security CLIリファレンス](../docs/references/09_rds_security_cli_reference.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [Markdown版作業手順書テンプレート](../docs/templates/s3_bucket_policy_change_procedure_template.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)
- [RDS構築スクリプト](../scripts/10_Database_setup.sh)

## 今日の変更シナリオ

次の変更依頼を受けた想定で手順書を作成する。

```text
目的:
Private Subnet上のWeb EC2からRDS MySQLへ接続できるようにする。

変更対象:
Destination Security Group: sample-sg-db

追加Rule:
Direction : Inbound
Protocol  : TCP
Port      : 3306
Source    : sample-sg-web
Description: MySQL access from web servers

設定変更:
Day 12では実施しない。
```

## 重要な前提

ラボ環境では、`All_Setup.sh`または`10_Database_setup.sh`によって対象Ruleがすでに作成されている可能性が高い。

変更前確認で同一Ruleが存在する場合は、次のように判断する。

```text
同一Ruleが存在する:
変更不要。作業を中止し、既存設定が要件を満たしていることを報告する。

同一Ruleが存在しない:
影響調査、レビュー、承認後に変更候補とする。

似たRuleが存在する:
CIDR許可、異なるSource SG、広いPort範囲などを調査し、
承認なく追加・削除しない。
```

## 今日の確認順序

1. 変更要求と通信要件を明文化する
2. 対象AWSアカウント、リージョン、VPCを確認する
3. Source SGとDestination SGを一意に特定する
4. 対象Inbound Ruleの存在有無を確認する
5. Source SGとDestination SGの関連リソースを確認する
6. RDS設定、Subnet、Route、NACL、DNSを確認する
7. 変更前疎通とアプリ動作の確認方法を定義する
8. 影響範囲とリスクを整理する
9. 作業開始条件、中止条件、切り戻し条件を定義する
10. GUIとAWS CLIの変更手順を作成する
11. 変更後確認と疎通試験を定義する
12. 切り戻し手順と切り戻し後確認を定義する
13. CloudTrail、スクリーンショット、証跡一覧を整理する
14. レビュー依頼とTeams報告文を作成する

## 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| VPC | `sample-vpc` |
| Source SG | `sample-sg-web` |
| Destination SG | `sample-sg-db` |
| Protocol / Port | TCP / 3306 |
| 変更内容 | DB SG InboundへWeb SG参照Ruleを追加する想定 |
| Day 12の設定変更 | なし |

## 今日実行しない操作

- `authorize-security-group-ingress`
- `revoke-security-group-ingress`
- Security Group Ruleの追加・削除・変更
- RDS Security Group関連付け変更
- Network ACL、Route Table、DNS設定変更
- 疎通確認目的の一時的な全開放
- RDS認証情報のファイル保存

---

## 2. 変更要求を明文化する

変更手順書の最初に、Source、Destination、Protocol、Port、目的を明確にする。

| 項目 | 内容 |
|---|---|
| Source Resource | Web EC2 |
| Source Security Group | `sample-sg-web` |
| Destination Resource | RDS MySQL |
| Destination Security Group | `sample-sg-db` |
| Protocol | TCP |
| Destination Port | 3306 |
| 通信方向 | Web EC2からRDS |
| 変更対象 | DB SGのInbound Rule |
| 変更理由 | WebアプリケーションからRDSへ接続するため |
| 利用者影響 | 要調査 |
| サービス停止 | 原則なし。ただし設定誤り時はDB接続へ影響 |

## 変更前と変更後

```text
変更前:
sample-sg-dbにTCP 3306 from sample-sg-webが存在しない。

変更後:
sample-sg-dbにTCP 3306 from sample-sg-webが存在する。
```

## 完了条件

```text
1. 対象DB SGに期待Ruleが1件だけ存在する
2. SourceがCIDRではなくsample-sg-webである
3. RDS接続確認が成功する
4. Webアプリケーションが正常に動作する
5. Public公開Ruleが追加されていない
6. CloudTrailに変更履歴が記録される
7. 証跡と作業結果を報告できる
```

---

## 3. なぜCIDRではなくSecurity Group参照を使うか

Web EC2からRDSへの内部通信では、SourceにWeb SGを指定する。

```text
推奨候補:
TCP 3306 from sample-sg-web

避ける候補:
TCP 3306 from 0.0.0.0/0
TCP 3306 from VPC全体CIDR
TCP 3306 from Web EC2の現在のPrivate IPだけ
```

SG参照の利点:

- Web EC2のIPアドレス変更に追従できる
- Web EC2の増減時にDB SG変更が不要
- Web層からDB層への通信要件を明確に表現できる
- VPC全体CIDR許可よりアクセス元を限定できる
- Public IPや外部CIDRを許可せずに済む

注意:

- Source SGが関連付いたすべてのENIが許可対象候補になる
- Source SGを他用途のリソースが共有していないか確認する
- SG参照だけで認証や暗号化を代替できるわけではない

---

## 4. 作業手順書の構成

現場でExcel手順書へ転記する場合、次のシートまたは章構成にする。

| No. | シート・章 | 内容 |
|---|---|---|
| 01 | 作業概要 | 対象、目的、日時、担当、承認 |
| 02 | 変更前確認 | 現在設定、関連リソース、疎通 |
| 03 | 影響調査 | 利用者、アプリ、通信、監視 |
| 04 | 変更手順 | GUIまたはCLIの操作 |
| 05 | 変更後確認 | Rule、疎通、アプリ、監視 |
| 06 | 切り戻し | Rule削除、切り戻し後確認 |
| 07 | 証跡一覧 | CLI、スクリーンショット、ログ |
| 08 | チェックリスト | 作業漏れ防止 |
| 09 | レビュー承認 | 作成、レビュー、承認、結果 |

---

## 5. 作業概要テンプレート

| 項目 | 内容 | 備考 |
|---|---|---|
| 作業名 | RDS Security Group Inbound Rule追加 |  |
| 作業ID | `<change-id>` | 現場管理番号 |
| 対象システム | 某銀行 振込・電子保管システム | 案件情報に合わせる |
| 対象AWSアカウント | `<account-id>` | Caller Identityで確認 |
| 対象リージョン | `ap-northeast-1` |  |
| 対象VPC | `sample-vpc` / `<vpc-id>` |  |
| Source SG | `sample-sg-web` / `<sg-id>` |  |
| Destination SG | `sample-sg-db` / `<sg-id>` |  |
| 変更内容 | DB SG InboundにTCP 3306 from Web SGを追加 |  |
| 作業目的 | WebアプリからRDS MySQLへ接続するため |  |
| 作業方式 | AWS Webコンソール / AWS CLI | 現場ルールに合わせる |
| サービス停止 | 原則なし | 要確認 |
| 利用者影響 | 原則なし | 設定誤り時はDB接続影響 |
| 切り戻し可否 | 可 | 追加Ruleを削除する |
| 作業担当 | `<name>` |  |
| レビュー担当 | `<name>` |  |
| 承認者 | `<name>` |  |
| 実施予定日時 | `yyyy/mm/dd hh:mm - hh:mm` |  |
| 事前連絡 | Teams |  |
| 作業後報告 | Teams |  |

---

## 6. 作業開始条件・中止条件・切り戻し条件

## 作業開始条件

- 作業手順書がレビュー済みである
- 作業実施が承認済みである
- 対象アカウント、リージョン、VPC、SG IDが確認済みである
- Source SGとDestination SGの関連リソースが確認済みである
- 同一Ruleが存在しないことを確認済みである
- 変更前証跡を取得済みである
- 変更前疎通結果を記録済みである
- 変更後試験と切り戻し手順を準備済みである
- 関係者へ作業開始を連絡済みである

## 作業中止条件

- 想定アカウントまたはリージョンと一致しない
- 対象SGを一意に特定できない
- 同一Ruleがすでに存在する
- Source SGが想定外リソースで共有されている
- Destination SGが想定外RDS・リソースで共有されている
- 変更前状態が手順書と異なる
- 未承認の関連設定変更が必要になった
- 監視アラートまたは業務障害が発生している
- 関係者から中止指示がある

## 切り戻し条件

- 変更後Ruleが期待値と異なる
- Sourceが誤ってCIDRまたは別SGになった
- 意図しないPublic公開が発生した
- WebアプリケーションまたはRDS接続に異常が発生した
- 他システムへの想定外影響が発生した
- 変更後確認を時間内に完了できない
- 関係者から切り戻し指示がある

---

## 7. 作業用変数の設定

Day 12では確認コマンドに使用する。変更系コマンドは実行しない。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"
VPC_NAME="sample-vpc"
WEB_SG_NAME="sample-sg-web"
DB_SG_NAME="sample-sg-db"
DB_INSTANCE_ID="sample-db"
DB_PORT="3306"
RULE_DESCRIPTION="MySQL access from web servers"
WORK_NAME="sg_change_procedure"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nWEB_SG_NAME=%s\nDB_SG_NAME=%s\nDB_INSTANCE_ID=%s\nDB_PORT=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" \
  "$WEB_SG_NAME" "$DB_SG_NAME" "$DB_INSTANCE_ID" "$DB_PORT"
```

---

## 8. 証跡保存用ディレクトリの設計

Day 12では、次回の模擬変更で使用する証跡構成を準備する。

```bash
EVIDENCE_DIR="evidence/$(date +%Y%m%d_%H%M%S)_${WORK_NAME}"

mkdir -p \
  "$EVIDENCE_DIR/00_metadata" \
  "$EVIDENCE_DIR/before" \
  "$EVIDENCE_DIR/change" \
  "$EVIDENCE_DIR/after" \
  "$EVIDENCE_DIR/rollback" \
  "$EVIDENCE_DIR/screenshots"

echo "Evidence directory: $EVIDENCE_DIR"
```

| ディレクトリ | 用途 |
|---|---|
| `00_metadata` | Caller Identity、対象ID |
| `before` | 変更前設定、疎通、関連リソース |
| `change` | 変更コマンド結果、作業中証跡 |
| `after` | 変更後設定、疎通、アプリ確認 |
| `rollback` | 切り戻しコマンド、切り戻し後確認 |
| `screenshots` | Webコンソール証跡 |

---

## 9. 対象AWSアカウントとVPCを確認する

### Webコンソール

1. AWSマネジメントコンソールへログインする
2. 右上のアカウント情報を確認する
3. 東京リージョンを選択する
4. VPCコンソールで`sample-vpc`を確認する

取得するスクリーンショット:

```text
01_操作アカウント確認.png
02_対象VPC確認.png
```

### AWS CLI

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text \
  --no-cli-pager)

if [ "$ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]; then
  echo "ERROR: Unexpected AWS account: $ACCOUNT_ID"
  return 1 2>/dev/null || exit 1
fi
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

---

## 10. Source SGとDestination SGを一意に特定する

```bash
WEB_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$WEB_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text \
  --no-cli-pager)

DB_SG_COUNT=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$DB_SG_NAME" \
  --query 'length(SecurityGroups)' \
  --output text \
  --no-cli-pager)

printf 'WEB_SG_COUNT=%s\nDB_SG_COUNT=%s\n' "$WEB_SG_COUNT" "$DB_SG_COUNT"
```

両方が`1`でない場合は作業を中止する。

```bash
WEB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$WEB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

DB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$DB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

printf 'WEB_SG_ID=%s\nDB_SG_ID=%s\n' "$WEB_SG_ID" "$DB_SG_ID"
```

証跡保存:

```bash
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$WEB_SG_ID" "$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/01_target_security_groups.json"
```

---

## 11. 同一Ruleの存在有無を確認する

変更前に、TCP 3306 from Web SGがすでに存在しないか確認する。

```bash
MATCHING_RULE_COUNT=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$WEB_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Matching rule count: $MATCHING_RULE_COUNT"
```

判定:

```bash
if [ "$MATCHING_RULE_COUNT" -gt 0 ]; then
  echo "STOP: The required rule already exists. Do not add a duplicate rule."
else
  echo "The required rule does not exist. Continue impact investigation and review."
fi
```

### DB SGの現在Rule

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/02_db_sg_rules.json"
```

### Webコンソール

1. VPCコンソールの「セキュリティグループ」を開く
2. `sample-sg-db`を選択する
3. 「インバウンドルール」を開く
4. TCP 3306のSourceとDescriptionを確認する
5. 「インバウンドルールを編集」は押さない

取得するスクリーンショット:

```text
03_DB_SG_変更前Inbound確認.png
```

---

## 12. 類似Ruleと危険Ruleを確認する

同一Ruleがなくても、似たRuleや広すぎるRuleが存在する可能性がある。

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query 'SecurityGroupRules[?FromPort==`3306` || ToPort==`3306` || IpProtocol==`-1`].{RuleId:SecurityGroupRuleId,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

確認する危険候補:

- TCP 3306 from `0.0.0.0/0`
- TCP 3306 from `::/0`
- TCP 3306 from VPC全体CIDR
- 全Protocol from Web SG
- 広いPort範囲 from Web SG
- 用途不明の別SG参照
- Descriptionなし、または期限切れの一時Rule

類似Ruleを確認した場合、追加Ruleとの重複・競合・不要Rule整理を別途検討する。承認なく既存Ruleを削除しない。

---

## 13. Source SGの関連リソースを確認する

Web SGをSourceに指定すると、そのSGが関連付くすべてのENIが接続元候補になる。

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$WEB_SG_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,InstanceId:Attachment.InstanceId,Groups:Groups[].GroupId}' \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$WEB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/03_web_sg_network_interfaces.json"
```

確認ポイント:

- Web EC2だけが関連付いているか
- 別システムや管理用EC2が共有していないか
- 想定外のLambda、Endpoint、その他ENIがないか
- Source SGを許可することで接続元が広がりすぎないか

---

## 14. Destination SGの関連リソースを確認する

DB SGを変更すると、そのSGを使用するすべてのリソースへ影響する。

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,Groups:Groups[].GroupId}' \
  --output table \
  --no-cli-pager
```

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[].{DBInstance:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VpcId:DBSubnetGroup.VpcId,SecurityGroups:VpcSecurityGroups[].VpcSecurityGroupId}' \
  --output table \
  --no-cli-pager
```

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/04_target_rds.json"
```

確認ポイント:

- `sample-sg-db`が`sample-db`だけに関連付いているか
- RDSが`available`か
- Endpoint Portが3306か
- `PubliclyAccessible`が`false`か
- 想定外のDBが同じSGを共有していないか

---

## 15. Web EC2とRDSの配置を確認する

```bash
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=instance-state-name,Values=running Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],InstanceId:InstanceId,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[].GroupId}' \
  --output table \
  --no-cli-pager
```

```bash
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{DBInstance:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VpcId:DBSubnetGroup.VpcId,Subnets:DBSubnetGroup.Subnets[].SubnetIdentifier,SecurityGroups:VpcSecurityGroups[].VpcSecurityGroupId}' \
  --output table \
  --no-cli-pager
```

期待:

```text
Web EC2:
Private Subnetに配置され、sample-sg-webを使用する。

RDS:
Private Subnet Groupに配置され、sample-sg-dbを使用する。
PubliclyAccessibleはfalseである。
```

---

## 16. Route TableとNACLを確認する

同一VPC内の通信は通常`local` Routeを使用する。SG Ruleを追加しても、NACLや経路に問題があると通信できない。

### Route Table

```bash
aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`].Value|[0],RouteTableId:RouteTableId,Associations:Associations[].SubnetId,Routes:Routes}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/05_route_tables.json"
```

### NACL

```bash
aws ec2 describe-network-acls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'NetworkAcls[].{Name:Tags[?Key==`Name`].Value|[0],NetworkAclId:NetworkAclId,IsDefault:IsDefault,Subnets:Associations[].SubnetId,Entries:Entries}' \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/06_network_acls.json"
```

NACL確認項目:

- Web Subnet OutboundでTCP 3306を許可する
- DB Subnet InboundでTCP 3306を許可する
- DB Subnet Outboundで戻り通信のEphemeral Portを許可する
- Web Subnet Inboundで戻り通信のEphemeral Portを許可する
- Rule番号とAllow/Deny順序に問題がない

---

## 17. DNSとRDS Endpointを確認する

Applicationが`db.home`を使用する場合、名前解決先が対象RDS Endpointと一致するか確認する。

### RDS Endpoint取得

```bash
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --no-cli-pager)

echo "RDS_ENDPOINT=$RDS_ENDPOINT"
```

### Web EC2上で実施する確認候補

```bash
getent hosts db.home
```

```bash
getent hosts "$RDS_ENDPOINT"
```

確認結果は次回の実作業時にテキスト証跡として保存する。

---

## 18. 変更前疎通確認を定義する

Day 12では手順を作成する。実行は変更作業日またはDay 13に行う。

### TCP 3306疎通

Web EC2から実行する想定:

```bash
nc -vz db.home 3306
```

結果の読み方:

| 結果 | 判断 |
|---|---|
| `succeeded` | TCP接続可能 |
| `timed out` | SG、NACL、Route、Firewallなどを調査 |
| `refused` | 到達したがPortでListenしていない可能性 |
| 名前解決失敗 | DNSを調査 |

### MySQL接続確認

```bash
mysql -h db.home -P 3306 -u adminuser -p
```

パスワードは対話入力する。コマンドライン、手順書、証跡ファイルへ平文で記載しない。

### アプリ動作確認

```bash
curl -I https://www.nobu-iac-lab.com
```

確認候補:

- Web画面が表示できる
- ログインできる
- DB参照を伴う画面が表示できる
- DB更新を伴う操作が成功する
- Application LogにDB接続エラーがない

---

## 19. 影響調査

| No. | 影響対象 | 想定影響 | 影響有無 | 確認方法 | 対応 |
|---|---|---|---|---|---|
| 1 | Web EC2 | RDSへのTCP 3306接続が可能になる | あり | ENI、SG、疎通 | 変更後疎通 |
| 2 | RDS | Web SGからの接続元が追加される | あり | RDS SG、接続確認 | 監視確認 |
| 3 | Webアプリ | DB接続が可能になる | あり | 画面・ログ | 機能確認 |
| 4 | Source SG共有リソース | RDS接続可能になる可能性 | 要確認 | ENI一覧 | 共有有無確認 |
| 5 | Destination SG共有DB | Web SGから接続可能になる可能性 | 要確認 | RDS・ENI一覧 | 共有有無確認 |
| 6 | NACL | 変更しないが通信可否へ影響 | 要確認 | NACL Rule | 双方向確認 |
| 7 | Route Table | 変更しないが経路へ影響 | 要確認 | Route Table | local Route確認 |
| 8 | DNS | 変更しないが接続先特定へ影響 | 要確認 | `getent hosts` | Endpoint照合 |
| 9 | 監視 | DB接続数やエラーが変化する可能性 | 要確認 | CloudWatch | 作業中監視 |
| 10 | 他システム | SG共有時に影響する可能性 | 要確認 | 設計書・関係者 | 共有有無確認 |

## セキュリティ影響

追加Ruleによって、Web SGを持つリソースからRDSへTCP 3306で到達可能になる。

確認すること:

- Web SGの利用リソースが必要最小限か
- DB SGの利用リソースが対象RDSだけか
- 認証情報とDB権限が適切か
- TLS接続要件があるか
- RDS監査ログ・接続ログ要件があるか
- Publicアクセスを追加していないか

---

## 20. 変更前確認表

| No. | 確認対象 | 確認内容 | 期待値 | 結果 | 証跡 |
|---|---|---|---|---|---|
| 1 | Caller Identity | 対象アカウント確認 | 想定Account ID |  | `00_metadata/00_caller_identity.json` |
| 2 | VPC | 対象VPC確認 | `sample-vpc` |  | `00_metadata/01_vpc.json` |
| 3 | Web SG | SG IDとRule確認 | 対象を一意に特定 |  | `before/01_target_security_groups.json` |
| 4 | DB SG | SG IDとRule確認 | 対象を一意に特定 |  | `before/02_db_sg_rules.json` |
| 5 | 同一Rule | 重複確認 | 0件 |  | `before/03_duplicate_check.txt` |
| 6 | Source SG利用元 | 関連ENI確認 | Web EC2のみ |  | `before/04_web_sg_enis.json` |
| 7 | Destination SG利用先 | RDS確認 | 対象RDSのみ |  | `before/05_db_sg_resources.json` |
| 8 | RDS | Status、Public、Port | available、false、3306 |  | `before/06_rds.json` |
| 9 | Route | local Route確認 | 想定どおり |  | `before/07_route_tables.json` |
| 10 | NACL | 双方向通信確認 | 想定どおり |  | `before/08_network_acls.json` |
| 11 | DNS | db.home確認 | 対象RDSへ解決 |  | `before/09_dns.txt` |
| 12 | TCP疎通 | 変更前状態確認 | 想定結果 |  | `before/10_nc_3306.txt` |
| 13 | アプリ | 変更前動作確認 | 正常または既知状態 |  | `before/11_application_test.txt` |
| 14 | CloudTrail | 直近SG変更確認 | 想定外変更なし |  | `before/12_cloudtrail.json` |

---

## 21. GUI変更手順案

Day 12では実行しない。レビュー用手順として記載する。

1. AWSマネジメントコンソールへログインする
2. 操作対象アカウントとリージョンを確認する
3. VPCコンソールを開く
4. 「セキュリティグループ」を開く
5. Group IDで`sample-sg-db`を検索する
6. Group Name、VPC ID、Descriptionが対象と一致することを確認する
7. 「インバウンドルール」を開く
8. TCP 3306 from `sample-sg-web`が存在しないことを再確認する
9. 変更前画面のスクリーンショットを取得する
10. 「インバウンドルールを編集」を押す
11. 「ルールを追加」を押す
12. Typeに`MYSQL/Aurora`またはCustom TCPを指定する
13. ProtocolがTCP、Portが3306であることを確認する
14. Sourceに`sample-sg-web`のSG IDを指定する
15. Descriptionに`MySQL access from web servers`を指定する
16. 保存前に対象、Source、Port、Descriptionをダブルチェックする
17. 承認された手順と一致する場合のみ保存する
18. 保存完了メッセージを確認する
19. 変更後Rule画面のスクリーンショットを取得する

取得するスクリーンショット案:

```text
04_DB_SG_変更前Inbound確認.png
05_DB_SG_変更入力確認.png
06_DB_SG_変更後Inbound確認.png
```

---

## 22. AWS CLI変更手順案

**Day 12では次の変更コマンドを実行しない。**

変更前に変数を再表示する。

```bash
printf 'ACCOUNT=%s\nREGION=%s\nVPC_ID=%s\nWEB_SG_ID=%s\nDB_SG_ID=%s\nPORT=%s\n' \
  "$EXPECTED_ACCOUNT_ID" "$REGION" "$VPC_ID" "$WEB_SG_ID" "$DB_SG_ID" "$DB_PORT"
```

変更コマンド案:

```bash
aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$DB_PORT,ToPort=$DB_PORT,UserIdGroupPairs=[{GroupId=$WEB_SG_ID,Description='$RULE_DESCRIPTION'}]" \
  --output json \
  --no-cli-pager
```

実作業時は標準出力を証跡へ保存し、戻り値を確認する。

```bash
aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$DB_PORT,ToPort=$DB_PORT,UserIdGroupPairs=[{GroupId=$WEB_SG_ID,Description='$RULE_DESCRIPTION'}]" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/01_authorize_security_group_ingress.json"
```

注意:

- 同一Ruleが存在する場合は`InvalidPermission.Duplicate`となる
- Duplicateを無視して続行せず、変更不要として報告する
- 対象SG ID、Source SG ID、Portを保存前に再確認する
- GUIとCLIのどちらを使用するか現場ルールに合わせる

---

## 23. 変更後Rule確認

### 期待Ruleだけを確認する

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$WEB_SG_ID'].{RuleId:SecurityGroupRuleId,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}" \
  --output table \
  --no-cli-pager
```

### DB SG全体を保存する

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/01_db_sg_rules.json"
```

確認項目:

- Ruleが1件だけ追加されている
- Destination SGが`sample-sg-db`
- Inbound Ruleである
- ProtocolがTCP
- From/To Portが3306
- Sourceが`sample-sg-web`
- Descriptionが期待どおり
- Public CIDR Ruleが追加されていない
- 既存Ruleが消えていない

---

## 24. 変更後疎通・アプリ確認

Web EC2から実行する想定:

```bash
nc -vz db.home 3306
```

```bash
mysql -h db.home -P 3306 -u adminuser -p
```

外部または作業端末から実行する想定:

```bash
curl -I https://www.nobu-iac-lab.com
```

確認項目:

- TCP 3306接続が成功する
- MySQL認証後に接続できる
- DB参照を伴う画面が正常に表示できる
- DB更新を伴う操作が正常に完了する
- Application LogにDB接続エラーがない
- CloudWatch Alarmや監視に異常がない
- 想定外の接続元を許可していない

---

## 25. CloudTrail変更履歴確認

変更後、`AuthorizeSecurityGroupIngress`を確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --query 'Events[].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId,Resource:Resources[0].ResourceName}' \
  --output table \
  --no-cli-pager
```

証跡保存案:

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/02_cloudtrail_authorize_sg_ingress.json"
```

確認項目:

- Event Nameが`AuthorizeSecurityGroupIngress`
- Event Timeが作業時刻と一致する
- UsernameまたはRoleが作業者と一致する
- 対象SG IDが一致する
- TCP 3306とSource SGが一致する
- Error Codeがない

---

## 26. 切り戻し手順案

切り戻しでは、今回追加したRuleだけを削除する。既存Ruleを削除しないよう、Rule IDまたは完全一致するRule内容を確認する。

### 追加Rule IDを取得する

```bash
ADDED_RULE_ID=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$WEB_SG_ID'].SecurityGroupRuleId | [0]" \
  --output text \
  --no-cli-pager)

echo "ADDED_RULE_ID=$ADDED_RULE_ID"
```

Ruleが複数ある、`None`になる、今回追加したRuleと特定できない場合は切り戻し操作を中止する。

### Rule IDによる切り戻しコマンド案

**Day 12では実行しない。**

```bash
aws ec2 revoke-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --security-group-rule-ids "$ADDED_RULE_ID" \
  --output json \
  --no-cli-pager
```

### Rule内容による切り戻しコマンド案

```bash
aws ec2 revoke-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$DB_PORT,ToPort=$DB_PORT,UserIdGroupPairs=[{GroupId=$WEB_SG_ID}]" \
  --output json \
  --no-cli-pager
```

Rule IDによる削除の方が、削除対象を一意に特定しやすい。現場標準とAWS CLIバージョンを確認して使用する。

---

## 27. 切り戻し後確認

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/01_db_sg_rules_after_rollback.json"
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RevokeSecurityGroupIngress \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/02_cloudtrail_revoke_sg_ingress.json"
```

切り戻し後確認項目:

- 今回追加したRuleが削除されている
- 変更前のRule構成と一致する
- 他の既存Ruleが残っている
- Public公開Ruleがない
- CloudTrailに`RevokeSecurityGroupIngress`が記録される
- アプリ・疎通状態が変更前状態へ戻っている
- 関係者へ切り戻し結果を報告した

---

## 28. 変更後確認表

| No. | 確認対象 | 確認内容 | 期待値 | 結果 | 証跡 |
|---|---|---|---|---|---|
| 1 | DB SG Rule | 期待Rule確認 | TCP 3306 from Web SGが1件 |  | `after/01_db_sg_rules.json` |
| 2 | Public公開 | 危険Rule確認 | 新規公開なし |  | `after/02_public_rule_check.json` |
| 3 | TCP疎通 | WebからDB | 成功 |  | `after/03_nc_3306.txt` |
| 4 | MySQL接続 | DB認証・接続 | 成功 |  | `after/04_mysql_test.txt` |
| 5 | Webアプリ | DB利用機能 | 正常 |  | `after/05_application_test.txt` |
| 6 | Application Log | DB接続エラー | なし |  | `after/06_application_log.txt` |
| 7 | CloudWatch | Alarm・異常 | なし |  | `after/07_cloudwatch_check.txt` |
| 8 | CloudTrail | 変更履歴 | 記録あり |  | `after/08_cloudtrail.json` |
| 9 | スクリーンショット | 変更後画面 | 期待Rule表示 |  | `screenshots/06_DB_SG_変更後Inbound確認.png` |

---

## 29. 作業手順表

Excelへ転記できる形式で整理する。

| No. | 区分 | 作業内容 | 操作場所 | 期待結果 | 異常時対応 | 証跡 |
|---|---|---|---|---|---|---|
| 1 | 事前確認 | 作業承認を確認する | Teams・申請 | 承認済み | 中止 | `before/approval.txt` |
| 2 | 事前確認 | Caller Identity確認 | CLI・Console | 想定Account | 中止 | `00_metadata/caller_identity.json` |
| 3 | 事前確認 | 対象VPC、Web SG、DB SG確認 | CLI・Console | 対象一致 | 中止 | `before/target_resources.json` |
| 4 | 事前確認 | 同一Rule重複確認 | CLI・Console | 0件 | 既存なら中止 | `before/duplicate_check.txt` |
| 5 | 事前確認 | Source/Destination SG関連リソース確認 | CLI | 想定リソースのみ | 中止・確認 | `before/related_resources.json` |
| 6 | 事前確認 | RDS、Route、NACL、DNS確認 | CLI・Console | 設計どおり | 中止・確認 | `before/network_check.json` |
| 7 | 事前確認 | 変更前疎通・アプリ確認 | Web EC2・Browser | 既知状態 | 中止・確認 | `before/connectivity.txt` |
| 8 | 変更 | DB SG Inbound Rule追加 | ConsoleまたはCLI | エラーなく完了 | 切り戻し判断 | `change/authorize.json` |
| 9 | 変更後確認 | 追加Rule確認 | CLI・Console | TCP 3306 from Web SG | 切り戻し | `after/db_sg_rules.json` |
| 10 | 変更後確認 | Public公開Rule確認 | CLI | 新規公開なし | 即時切り戻し | `after/public_rule_check.json` |
| 11 | 試験 | TCP 3306疎通 | Web EC2 | 成功 | 調査・切り戻し | `after/nc_3306.txt` |
| 12 | 試験 | MySQL・アプリ動作確認 | Web EC2・Browser | 正常 | 調査・切り戻し | `after/application_test.txt` |
| 13 | 確認 | CloudWatch・CloudTrail確認 | Console・CLI | 異常なし・履歴あり | 調査 | `after/cloudtrail.json` |
| 14 | 報告 | 作業完了報告 | Teams | 報告済み | 連絡 | `after/teams_report.txt` |

---

## 30. 証跡一覧

| No. | タイミング | 証跡 | ファイル例 |
|---|---|---|---|
| 1 | 変更前 | Caller Identity | `00_metadata/00_caller_identity.json` |
| 2 | 変更前 | 対象VPC・SG ID | `00_metadata/01_target_ids.txt` |
| 3 | 変更前 | Web SG・DB SG | `before/01_target_security_groups.json` |
| 4 | 変更前 | DB SG Rule | `before/02_db_sg_rules.json` |
| 5 | 変更前 | 重複Rule確認 | `before/03_duplicate_check.txt` |
| 6 | 変更前 | 関連ENI・リソース | `before/04_related_resources.json` |
| 7 | 変更前 | RDS設定 | `before/05_rds.json` |
| 8 | 変更前 | Route・NACL | `before/06_network.json` |
| 9 | 変更前 | DNS・疎通・アプリ | `before/07_connectivity.txt` |
| 10 | 変更時 | Rule追加結果 | `change/01_authorize.json` |
| 11 | 変更後 | DB SG Rule | `after/01_db_sg_rules.json` |
| 12 | 変更後 | 疎通・アプリ確認 | `after/02_connectivity.txt` |
| 13 | 変更後 | CloudTrail | `after/03_cloudtrail.json` |
| 14 | 切り戻し | Rule削除結果 | `rollback/01_revoke.json` |
| 15 | 切り戻し | 切り戻し後Rule | `rollback/02_db_sg_rules.json` |
| 16 | 全体 | スクリーンショット | `screenshots/*.png` |

---

## 31. レビューチェックリスト

- [ ] 作業目的が明確である
- [ ] Source、Destination、Protocol、Portが明確である
- [ ] 対象Account、Region、VPC、SG IDが明確である
- [ ] Source SGの関連リソースを確認している
- [ ] Destination SGの関連リソースを確認している
- [ ] 同一Ruleの重複確認がある
- [ ] 類似Rule・危険Ruleの確認がある
- [ ] RDS、Route、NACL、DNSの確認がある
- [ ] 変更前疎通確認がある
- [ ] GUIまたはCLIの変更操作が1操作ずつ記載されている
- [ ] 保存前のダブルチェックがある
- [ ] 変更後Rule確認がある
- [ ] Public公開Rule確認がある
- [ ] 疎通・アプリ・監視確認がある
- [ ] CloudTrail確認がある
- [ ] 中止条件と切り戻し条件がある
- [ ] 切り戻し対象Ruleを一意に特定できる
- [ ] 切り戻し後確認がある
- [ ] 証跡ファイル名が明確である
- [ ] 関係者への開始・完了・異常報告がある
- [ ] Day 12では変更操作を実行していない

---

## 32. Teams報告例

### 手順書レビュー依頼

```text
RDS Security Group Inbound Rule追加の作業手順書を作成しました。

変更内容:
- Source: sample-sg-web
- Destination: sample-sg-db
- Protocol / Port: TCP / 3306
- Description: MySQL access from web servers

確認済み項目:
- 対象Account、Region、VPC、SG ID
- Source/Destination SGの関連リソース
- 既存Ruleと重複有無
- RDS、Route、NACL、DNS
- 変更前・変更後確認
- 疎通試験
- 切り戻し
- CloudTrail・証跡

手順、影響範囲、試験内容、切り戻し内容のレビューをお願いします。
Day 12では設定変更を実施していません。
```

### 同一Ruleが存在した場合

```text
RDS Security Group変更前確認を実施した結果、
TCP 3306 from sample-sg-webのRuleがすでに存在することを確認しました。

対象:
- Destination SG: sample-sg-db / <sg-id>
- Source SG: sample-sg-web / <sg-id>
- Protocol / Port: TCP / 3306
- Existing Rule ID: <rule-id>

要件を既存Ruleが満たしているため、重複Ruleの追加は実施しません。
既存Ruleの目的と継続利用可否をご確認ください。
```

### 作業開始前報告

```text
RDS Security Group Inbound Rule追加作業の変更前確認が完了しました。

対象、影響範囲、変更前設定、疎通状態、切り戻し手順を確認済みです。
承認済み手順に従い作業を開始します。

想定外の設定差異、疎通異常、監視異常を確認した場合は作業を中止し、
必要に応じて追加Ruleを削除して切り戻します。
```

### 作業完了報告

```text
RDS Security Group Inbound Rule追加作業が完了しました。

実施内容:
- sample-sg-dbへTCP 3306 from sample-sg-webを追加

変更後確認:
- 追加Rule: 想定どおり
- Public公開Rule: 追加なし
- Web EC2からRDSへの疎通: 正常
- Webアプリ動作: 正常
- CloudWatch: 異常なし
- CloudTrail: AuthorizeSecurityGroupIngress記録あり

切り戻し:
- 未実施

証跡:
- <保存先>
```

---

## 33. よくあるレビュー指摘

## SG名だけで対象を指定している

SG名は誤認しやすいため、Account ID、Region、VPC ID、SG IDを記載する。

## 「影響なし」とだけ記載している

影響なしと判断した根拠を書く。

```text
Source SGは対象Web EC2だけに関連付いている。
Destination SGは対象RDSだけに関連付いている。
追加はAllow Ruleであり既存通信を遮断しない。
変更後にDB疎通とアプリ動作を確認する。
```

## 変更後確認がRule確認だけで終わっている

設定値だけでなく、実際のTCP疎通、DB接続、アプリ機能、監視、CloudTrailを確認する。

## 切り戻しコマンドが曖昧

今回追加したRule ID、対象DB SG ID、Source Web SG IDを明記し、別Ruleを削除しない手順にする。

## 既存Ruleの重複確認がない

同一Ruleが存在する場合は変更不要である。重複追加を試みず、既存設定を報告する。

## パスワードをコマンドへ記載している

DBパスワードは対話入力または承認された秘密情報管理方式を使用し、手順書や証跡へ平文保存しない。

---

## 34. セキュリティ上の注意点

- DB Portを`0.0.0.0/0`または`::/0`へ公開しない
- VPC全体CIDR許可よりSG参照を優先できるか検討する
- Source SGとDestination SGの共有範囲を確認する
- SG名だけでなくSG IDとVPC IDを確認する
- 同一Ruleを重複追加しない
- 一時Ruleを恒久Ruleとして残さない
- DB認証情報を手順書・証跡・コマンド履歴へ残さない
- RDSの`PubliclyAccessible`を確認する
- Network ACLと戻り通信を確認する
- 変更後にPublic公開Ruleが増えていないことを確認する
- CloudTrailで操作者と変更内容を確認する
- 承認前に変更コマンドを実行しない

---

## 35. 案件で説明できるポイント

### 影響調査

```text
Security Group Rule追加前に、Source SGとDestination SGの関連ENI、
関連リソース、RDS設定、Route、NACL、DNS、既存疎通を確認します。

SG参照Ruleでは、Source SGを共有する全リソースが接続元候補になるため、
関連ENIの確認を重要視します。
```

### 重複Ruleの扱い

```text
同一Ruleが存在する場合は、重複追加を行いません。
既存Rule ID、Source、Port、Descriptionを証跡化し、
既存設定が要件を満たしていることを報告します。
```

### 変更後確認

```text
変更後はRuleの設定値だけでなく、
Web EC2からRDSへのTCP疎通、DB接続、アプリ動作、
監視、CloudTrailを確認します。
```

### 切り戻し

```text
今回追加したSecurity Group Rule IDを特定し、
そのRuleだけを削除して切り戻します。

切り戻し後は変更前Rule構成との一致、
疎通状態、CloudTrail、関係者報告まで確認します。
```

---

## 36. 資格試験につながるポイント

- Security GroupはStateful
- Security GroupはAllow Ruleのみ
- Sourceに別Security Groupを指定できる
- SG参照はIPアドレスではなくSG関連ENIを基準にする
- RDSへはApplication SGからDB Portだけを許可する構成が一般的
- RDSをPrivate Subnetへ配置し、Publicly Accessibleを無効にする
- NACLはStatelessで戻り通信の許可が必要
- 同一VPC内通信は通常local Routeを使用する
- Security Group変更はCloudTrailのManagement Eventへ記録される
- 追加したIngress Ruleは`RevokeSecurityGroupIngress`で削除できる
- 接続障害はSGだけでなくRoute、NACL、DNS、OS、Applicationも確認する

---

## 37. 要確認事項

案件参画後、次を確認する。

- SG変更はWebコンソール、AWS CLI、既存シェルのどれで実施するか
- AWS CLIを直接実行できるか
- 作業手順書のExcel様式
- SG Rule IDを手順書へ記載するか
- Rule Descriptionの命名規則
- 作業IDや申請番号をDescriptionへ記載するか
- Source SG参照を標準とするか
- 変更前・変更後疎通の標準コマンド
- DB接続試験で使用するユーザーと権限
- パスワードの受け渡し・入力方法
- アプリケーション確認担当
- CloudWatch監視担当
- CloudTrail証跡の取得方法
- スクリーンショットの取得・マスキングルール
- 作業開始、中止、切り戻しの承認者
- 緊急時の連絡先と報告経路

不明点は推測で変更せず、要確認事項として手順書とレビュー依頼へ残す。

---

## 38. Day 12完了チェックリスト

- [ ] 変更要求をSource、Destination、Protocol、Portで説明できる
- [ ] 変更前と変更後を説明できる
- [ ] CIDRではなくSG参照を使用する理由を説明できる
- [ ] 作業概要を作成した
- [ ] 作業開始条件を作成した
- [ ] 中止条件と切り戻し条件を作成した
- [ ] 対象Account、Region、VPC、SG IDの確認手順を作成した
- [ ] 同一Ruleの重複確認手順を作成した
- [ ] 類似Ruleと危険Ruleの確認手順を作成した
- [ ] Source SGの関連リソース確認手順を作成した
- [ ] Destination SGの関連リソース確認手順を作成した
- [ ] RDS、Route、NACL、DNSの確認手順を作成した
- [ ] 変更前疎通・アプリ確認手順を作成した
- [ ] 影響調査表を作成した
- [ ] GUI変更手順案を作成した
- [ ] AWS CLI変更手順案を作成した
- [ ] 変更後Rule確認手順を作成した
- [ ] 変更後疎通・アプリ・監視確認手順を作成した
- [ ] CloudTrail確認手順を作成した
- [ ] 切り戻し手順と切り戻し後確認を作成した
- [ ] 証跡一覧を作成した
- [ ] レビューチェックリストを作成した
- [ ] Teams報告文を作成した
- [ ] Day 12では設定変更を実施していない

## Day 12の完了条件

次を自分の言葉で説明できればDay 12は完了とする。

```text
Web SGからRDS SGへTCP 3306を許可する変更では、
対象SG IDと既存Ruleだけでなく、Source SGとDestination SGを共有する
全リソース、RDS、Route、NACL、DNS、既存疎通を確認する。

同一Ruleが存在する場合は重複追加せず、変更不要として報告する。

変更後はRule確認、TCP疎通、DB接続、アプリ動作、
監視、CloudTrailを確認する。

異常時は今回追加したRule IDを特定して削除し、
変更前状態への復旧と切り戻し後確認を行う。

Day 12では変更を実行せず、レビューと承認を受けられる
作業手順書を完成させる。
```
