# Day 13 Learning: Security Group変更・確認・切り戻しドリル

## 学習開始前に実行するスクリプト

Day 13はBastion、Webアプリケーション、RDS、Security Groupを使用して疎通変化と切り戻しを確認するため、`sample-vpc`が存在しない場合は最初に日次ラボ環境を構築する。

```bash
/Users/nobu/aws-reference/scripts/All_Setup.sh
```

`sample-vpc`が前日から残っている場合は、`All_Setup.sh`を再実行しない。続いてアプリケーションを構築・再適用する。
前日の環境を破棄して新規構築する場合は、先に`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

```bash
read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo
export DB_MASTER_PASSWORD

/Users/nobu/aws-reference/ansible/run_site_local.sh
```

Security Group変更はCloudTrail Event Historyで確認できるManagement Eventであるため、CloudTrail一時TrailとS3 Data Eventは不要である。切り戻し確認後、後続学習で環境を使用しない場合は`/Users/nobu/aws-reference/scripts/cleanup_network.sh`を実行する。

## 1. 今日の目的

Day 12で作成したSecurity Group変更手順をもとに、変更前確認、模擬変更、疎通確認、CloudTrail確認、切り戻し、切り戻し後確認、結果報告までを一人で実施する。

Day 13は、AWS設定変更を「変更コマンドが成功した」で終わらせず、次の一連の作業として完結させるドリルである。

```text
変更前確認
  -> 作業開始判断
  -> 設定変更
  -> 変更後設定確認
  -> 疎通・アプリ・監視確認
  -> CloudTrail確認
  -> 切り戻し
  -> 切り戻し後確認
  -> 証跡整理・結果報告
```

関連資料:

- [Day 11 Security Group・Network ACL確認ドリル](./11_Day_Learning.md)
- [Day 12 Security Group変更影響調査・手順書作成](./12_Day_Learning.md)
- [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md)
- [設計書](../docs/design/Design_Specification.md)
- [ネットワーク構成図](../docs/design/Network_Architecture.png)
- [RDS構築スクリプト](../scripts/10_Database_setup.sh)

---

## 2. 今日の模擬変更方式

ラボ環境では、Web SGからDB SGへのTCP 3306 Ruleがすでに存在し、Webアプリケーションが利用している。

既存Ruleを削除して再追加する方法は、WebアプリケーションのDB接続を遮断するため、今回の練習では使用しない。

Day 13では、既存アプリ通信へ影響しにくい次の一時Ruleを使用する。

```text
Destination Security Group:
sample-sg-db

Temporary Inbound Rule:
Protocol   : TCP
Port       : 3306
Source     : sample-sg-bastion
Description: TEMP Day13 SG change drill
```

模擬変更の流れ:

```text
変更前:
Bastion SGからDB SGへのTCP 3306 Ruleは存在しない。
Bastionからdb.home:3306への疎通は失敗する想定。

変更:
DB SGへTCP 3306 from Bastion SGを一時追加する。

変更後:
Bastionからdb.home:3306への疎通成功を確認する。
Webアプリケーションの既存通信が正常であることも確認する。

切り戻し:
今回追加した一時Rule IDだけを削除する。

切り戻し後:
一時Ruleが存在しないことを確認する。
Bastionからdb.home:3306への疎通が変更前状態へ戻ることを確認する。
Web SGからDB SGへの既存Ruleが残っていることを確認する。
```

## この方式を選ぶ理由

- Web SGからRDSへの既存業務通信を維持できる
- Rule追加、疎通変化、Rule削除を一連で確認できる
- Source SG参照Ruleを実際に扱える
- 追加Rule IDを使った安全な切り戻しを練習できる
- CloudTrailで追加と削除の両方を確認できる

## 重要な注意

この方式は個人ラボ専用の模擬変更である。

```text
本番・金融環境では、練習目的の一時アクセス許可を作成しない。

実案件では、承認された変更要求、作業手順書、作業日時、
対象リソース、試験、切り戻し、関係者連絡に従う。
```

---

## 3. 今日の作業範囲

| 項目 | 内容 |
|---|---|
| AWSアカウントID | `445405559057` |
| リージョン | `ap-northeast-1` |
| AWS CLIプロファイル | `learning` |
| 対象VPC | `sample-vpc` |
| Source SG | `sample-sg-bastion` |
| Destination SG | `sample-sg-db` |
| Protocol / Port | TCP / 3306 |
| 変更内容 | DB SGへBastion SG参照の一時Inbound Ruleを追加 |
| 疎通元 | Bastion EC2 |
| 疎通先 | `db.home:3306` |
| 最終状態 | 一時Ruleを削除し、変更前状態へ戻す |

## 今日の作業順序

1. ラボ環境とWebアプリケーションが正常であることを確認する
2. 作業変数と対象AWSアカウントを確認する
3. VPC、Bastion SG、Web SG、DB SGを一意に特定する
4. Source SGとDestination SGの関連リソースを確認する
5. 既存のWeb SGからDB SGへのRuleを確認する
6. 一時Ruleが存在しないことを確認する
7. 変更前設定と疎通結果を証跡保存する
8. 作業開始条件を確認する
9. 一時Ruleを追加する
10. 変更後Ruleと疎通結果を確認する
11. Webアプリケーションの正常性を確認する
12. CloudTrailでRule追加履歴を確認する
13. 追加した一時Rule IDだけを削除する
14. 切り戻し後Ruleと疎通結果を確認する
15. CloudTrailでRule削除履歴を確認する
16. 証跡、結果、要確認事項を整理して報告する

## 今日変更しないもの

- Web SGからDB SGへの既存TCP 3306 Rule
- Bastion SG、Web SG、DB SG自体
- RDS Security Group関連付け
- Network ACL
- Route Table
- Private Hosted Zoneと`db.home`
- RDS設定
- Webアプリケーション設定
- DBユーザー、パスワード、権限

---

## 4. 作業開始条件・中止条件・緊急切り戻し条件

## 作業開始条件

- 個人ラボ環境である
- 当日のラボ利用者が自分だけである
- 作業後に一時Ruleを必ず削除できる
- 対象AWSアカウントとリージョンが確認できている
- VPC、Source SG、Destination SGを一意に特定できている
- Source SGはBastion EC2だけで使用されている
- Destination SGは対象RDSだけで使用されている
- 一時Ruleが変更前に存在しない
- Web SGからDB SGへの既存Ruleが存在する
- BastionからDBへの変更前疎通結果を取得できる
- Webアプリケーションが変更前に正常である
- 証跡保存先が準備できている
- 切り戻しコマンドを準備できている

## 作業中止条件

- 想定外のAWSアカウントまたはリージョンである
- 対象VPCまたはSGが複数存在する
- Source SGまたはDestination SGが想定外リソースで共有されている
- 一時Ruleがすでに存在する
- Web SGからDB SGへの既存Ruleが見つからない
- 変更前のWebアプリケーションが異常である
- 変更前疎通結果が想定と異なる
- RDSが`available`ではない
- CloudWatch Alarmなど既存障害を確認した
- 切り戻し方法を確定できない

## 緊急切り戻し条件

- 誤ったSGへRuleを追加した
- Source SG、Protocol、Portが想定と異なる
- Public CIDRまたは想定外Sourceを許可した
- Webアプリケーションに異常が発生した
- RDS、監視、他リソースに想定外影響が発生した
- 変更後確認を完了できない
- 一時Ruleを作業時間内に削除できない

---

## 5. 作業用変数の設定

```bash
PROFILE="learning"
REGION="ap-northeast-1"
EXPECTED_ACCOUNT_ID="445405559057"

VPC_NAME="sample-vpc"
BASTION_SG_NAME="sample-sg-bastion"
WEB_SG_NAME="sample-sg-web"
DB_SG_NAME="sample-sg-db"
DB_INSTANCE_ID="sample-db"

DB_PORT="3306"
TEMP_RULE_DESCRIPTION="TEMP Day13 SG change drill"
WORK_NAME="sg_change_drill"
```

### 変数確認

```bash
printf 'PROFILE=%s\nREGION=%s\nEXPECTED_ACCOUNT_ID=%s\nVPC_NAME=%s\nBASTION_SG_NAME=%s\nWEB_SG_NAME=%s\nDB_SG_NAME=%s\nDB_INSTANCE_ID=%s\nDB_PORT=%s\nTEMP_RULE_DESCRIPTION=%s\n' \
  "$PROFILE" "$REGION" "$EXPECTED_ACCOUNT_ID" "$VPC_NAME" \
  "$BASTION_SG_NAME" "$WEB_SG_NAME" "$DB_SG_NAME" \
  "$DB_INSTANCE_ID" "$DB_PORT" "$TEMP_RULE_DESCRIPTION"
```

### 必須変数チェック

```bash
for VARIABLE_NAME in PROFILE REGION EXPECTED_ACCOUNT_ID VPC_NAME BASTION_SG_NAME WEB_SG_NAME DB_SG_NAME DB_INSTANCE_ID DB_PORT TEMP_RULE_DESCRIPTION WORK_NAME; do
  if [ -z "${!VARIABLE_NAME:-}" ]; then
    echo "ERROR: $VARIABLE_NAME is not set."
    return 1 2>/dev/null || exit 1
  fi
done

echo "Required variable check OK."
```

---

## 6. 証跡保存用ディレクトリの作成

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

### 証跡ディレクトリ確認

```bash
find "$EVIDENCE_DIR" \
  -maxdepth 1 \
  -type d \
  -print
```

| ディレクトリ | 用途 |
|---|---|
| `00_metadata` | Caller Identity、対象ID、作業時刻 |
| `before` | 変更前Rule、関連リソース、疎通、アプリ |
| `change` | Rule追加結果 |
| `after` | 変更後Rule、疎通、アプリ、CloudTrail |
| `rollback` | Rule削除結果、切り戻し後確認、CloudTrail |
| `screenshots` | Webコンソール証跡 |

---

## 7. AWSアカウントを確認する

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table \
  --no-cli-pager
```

```bash
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/00_metadata/00_caller_identity.json"
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

echo "Account check OK: $ACCOUNT_ID"
```

取得するスクリーンショット:

```text
01_操作アカウント確認.png
```

---

## 8. 対象VPCとSGを一意に特定する

### VPC

```bash
VPC_COUNT=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text \
  --no-cli-pager)

if [ "$VPC_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one VPC named $VPC_NAME."
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

### Security Group数確認

```bash
for SG_NAME in "$BASTION_SG_NAME" "$WEB_SG_NAME" "$DB_SG_NAME"; do
  SG_COUNT=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$SG_NAME" \
    --query 'length(SecurityGroups)' \
    --output text \
    --no-cli-pager)

  printf '%s count: %s\n' "$SG_NAME" "$SG_COUNT"

  if [ "$SG_COUNT" -ne 1 ]; then
    echo "ERROR: Expected exactly one Security Group named $SG_NAME."
    return 1 2>/dev/null || exit 1
  fi
done
```

### Security Group ID取得

```bash
BASTION_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --no-cli-pager)

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

printf 'BASTION_SG_ID=%s\nWEB_SG_ID=%s\nDB_SG_ID=%s\n' \
  "$BASTION_SG_ID" "$WEB_SG_ID" "$DB_SG_ID"
```

### 対象IDを証跡保存

```bash
printf 'ACCOUNT_ID=%s\nREGION=%s\nVPC_ID=%s\nBASTION_SG_ID=%s\nWEB_SG_ID=%s\nDB_SG_ID=%s\n' \
  "$ACCOUNT_ID" "$REGION" "$VPC_ID" "$BASTION_SG_ID" "$WEB_SG_ID" "$DB_SG_ID" \
  > "$EVIDENCE_DIR/00_metadata/01_target_ids.txt"
```

---

## 9. Source SGとDestination SGの関連リソースを確認する

### Bastion SG関連ENI

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$BASTION_SG_ID" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Description:Description,Type:InterfaceType,Status:Status,SubnetId:SubnetId,PrivateIp:PrivateIpAddress,PublicIp:Association.PublicIp,InstanceId:Attachment.InstanceId,Groups:Groups[].GroupId}' \
  --output table \
  --no-cli-pager
```

```bash
aws ec2 describe-network-interfaces \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$BASTION_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/01_bastion_sg_network_interfaces.json"
```

### DB SG関連ENI

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
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].{DBInstance:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VpcId:DBSubnetGroup.VpcId,SecurityGroups:VpcSecurityGroups[].VpcSecurityGroupId}' \
  --output table \
  --no-cli-pager
```

中止判断:

- Bastion SGがBastion EC2以外で使用されている
- DB SGが対象RDS以外で使用されている
- RDSが`available`ではない
- RDS Portが3306ではない
- RDSがPublicly Accessibleである

---

## 10. 変更前SG Ruleを保存する

### DB SG全Rule

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/02_db_sg_rules.json"
```

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr4:CidrIpv4,Cidr6:CidrIpv6,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

### 既存Web SG Rule確認

Webアプリケーションが使用する既存Ruleが1件存在することを確認する。

```bash
WEB_DB_RULE_COUNT=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$WEB_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Web-to-DB rule count: $WEB_DB_RULE_COUNT"
```

```bash
if [ "$WEB_DB_RULE_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one Web-to-DB rule. Do not continue."
  return 1 2>/dev/null || exit 1
fi
```

### 一時Rule不存在確認

```bash
TEMP_RULE_COUNT=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$BASTION_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Temporary rule count before change: $TEMP_RULE_COUNT"
```

```bash
if [ "$TEMP_RULE_COUNT" -ne 0 ]; then
  echo "ERROR: Temporary Bastion-to-DB rule already exists. Do not continue."
  return 1 2>/dev/null || exit 1
fi
```

取得するスクリーンショット:

```text
02_DB_SG_変更前Inbound確認.png
```

---

## 11. 変更前疎通とアプリ状態を確認する

## BastionからDBへの変更前疎通

まずBastionへ接続する。

```bash
ssh awsref-bastion
```

Bastion上で実行する。

```bash
getent hosts db.home
```

```bash
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' \
  && echo "TCP 3306 OPEN" \
  || echo "TCP 3306 BLOCKED"
```

作業端末から一行で実行し、証跡保存する場合:

```bash
ssh awsref-bastion \
  "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' && echo 'TCP 3306 OPEN' || echo 'TCP 3306 BLOCKED'" \
  | tee "$EVIDENCE_DIR/before/04_bastion_to_db_tcp_3306.txt"
```

期待結果:

```text
TCP 3306 BLOCKED
```

注意:

- 変更前から`OPEN`の場合は、一時Rule以外の経路・SG Rule・NACL・共有SGを調査する
- 想定外のため、原因が分かるまで変更を開始しない
- `timeout`やBashの`/dev/tcp`が利用できない場合は、`nc -vz db.home 3306`など現場で利用可能な方法を使用する

## Webアプリケーションの変更前確認

作業端末で実行する。

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/before/05_web_application_headers.txt"
```

期待結果:

```text
HTTP/2 200
```

ブラウザでも、DB参照を伴う画面とログインなどの基本動作を確認する。

取得するスクリーンショット:

```text
03_変更前Webアプリ確認.png
```

---

## 12. 変更前CloudTrail確認

直近のSecurity Group変更履歴を確認し、別作業と競合していないことを確認する。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$DB_SG_ID" \
  --query 'Events[?EventName==`AuthorizeSecurityGroupIngress` || EventName==`RevokeSecurityGroupIngress`].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId}' \
  --output table \
  --no-cli-pager
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/before/03_cloudtrail_db_sg_events.json"
```

CloudTrail Event HistoryでSG IDによる検索結果が得られない場合は、Event Nameで検索し、CloudTrail Event内の対象SG IDを確認する。

---

## 13. 作業直前チェック

変更コマンドを実行する直前に、対象と条件を再確認する。

```bash
printf 'ACCOUNT_ID=%s\nREGION=%s\nVPC_ID=%s\nSOURCE_SG=%s (%s)\nDESTINATION_SG=%s (%s)\nPROTOCOL=tcp\nPORT=%s\nDESCRIPTION=%s\n' \
  "$ACCOUNT_ID" "$REGION" "$VPC_ID" \
  "$BASTION_SG_NAME" "$BASTION_SG_ID" \
  "$DB_SG_NAME" "$DB_SG_ID" \
  "$DB_PORT" "$TEMP_RULE_DESCRIPTION"
```

実行前チェックリスト:

- [ ] 個人ラボ環境である
- [ ] Account IDが`445405559057`である
- [ ] Regionが`ap-northeast-1`である
- [ ] Destinationが`sample-sg-db`である
- [ ] Sourceが`sample-sg-bastion`である
- [ ] ProtocolがTCPである
- [ ] Portが3306である
- [ ] Descriptionが一時Ruleと識別できる
- [ ] 一時Ruleが変更前に0件である
- [ ] 既存Web-to-DB Ruleが1件存在する
- [ ] 変更前証跡を取得済みである
- [ ] 切り戻しコマンドを準備済みである

1項目でも満たさない場合は、変更を開始しない。

---

## 14. 一時Inbound Ruleを追加する

**この章からAWS設定変更が発生する。**

```bash
if aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$DB_PORT,ToPort=$DB_PORT,UserIdGroupPairs=[{GroupId=$BASTION_SG_ID,Description='$TEMP_RULE_DESCRIPTION'}]" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/change/01_authorize_temp_rule.json" \
  2> "$EVIDENCE_DIR/change/01_authorize_temp_rule_error.txt"; then
  CHANGE_RC=0
else
  CHANGE_RC=$?
fi

printf 'authorize-security-group-ingress exit code: %s\n' "$CHANGE_RC" \
  > "$EVIDENCE_DIR/change/01_authorize_temp_rule_exit_code.txt"
```

### コマンド結果確認

```bash
cat "$EVIDENCE_DIR/change/01_authorize_temp_rule.json"
cat "$EVIDENCE_DIR/change/01_authorize_temp_rule_error.txt"
cat "$EVIDENCE_DIR/change/01_authorize_temp_rule_exit_code.txt"
```

```bash
if [ "$CHANGE_RC" -ne 0 ]; then
  echo "ERROR: Temporary rule authorization failed. Do not continue testing."
  return 1 2>/dev/null || exit 1
fi
```

注意:

- `$?`は直前コマンドの終了コードを表すため、変更コマンド直後に`CHANGE_RC`へ保存する
- 終了コードが`0`以外の場合は、現在設定を確認してから中止または切り戻しを判断する
- `InvalidPermission.Duplicate`の場合は追加済みRuleを調査し、作業を中止する
- 想定外エラーの場合は再実行せず、現在設定を確認する

---

## 15. 追加した一時Ruleを一意に特定する

### 一時Rule件数

```bash
TEMP_RULE_COUNT=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$BASTION_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Temporary rule count after change: $TEMP_RULE_COUNT"
```

```bash
if [ "$TEMP_RULE_COUNT" -ne 1 ]; then
  echo "ERROR: Expected exactly one temporary rule. Stop testing and perform emergency rollback investigation."
fi
```

### 一時Rule ID取得

```bash
TEMP_RULE_ID=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$BASTION_SG_ID'].SecurityGroupRuleId | [0]" \
  --output text \
  --no-cli-pager)

echo "TEMP_RULE_ID=$TEMP_RULE_ID"
```

```bash
if [ -z "$TEMP_RULE_ID" ] || [ "$TEMP_RULE_ID" = "None" ]; then
  echo "ERROR: Temporary rule ID was not found."
  return 1 2>/dev/null || exit 1
fi
```

### Rule ID保存

```bash
printf 'TEMP_RULE_ID=%s\nDB_SG_ID=%s\nBASTION_SG_ID=%s\n' \
  "$TEMP_RULE_ID" "$DB_SG_ID" "$BASTION_SG_ID" \
  > "$EVIDENCE_DIR/change/02_temp_rule_id.txt"
```

---

## 16. 変更後Security Groupを確認する

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/after/01_db_sg_rules.json"
```

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --security-group-rule-ids "$TEMP_RULE_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

変更後確認:

- Rule IDが取得できる
- Group IDがDB SGである
- Inbound Ruleである
- ProtocolがTCPである
- From/To Portが3306である
- Source SGがBastion SGである
- Descriptionが`TEMP Day13 SG change drill`である
- 既存Web-to-DB Ruleが残っている
- Public CIDR Ruleが追加されていない

取得するスクリーンショット:

```text
04_DB_SG_一時Rule追加後.png
```

---

## 17. 変更後疎通を確認する

Bastionへ接続する。

```bash
ssh awsref-bastion
```

Bastion上で実行する。

```bash
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' \
  && echo "TCP 3306 OPEN" \
  || echo "TCP 3306 BLOCKED"
```

作業端末から一行で実行し、証跡保存する場合:

```bash
ssh awsref-bastion \
  "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' && echo 'TCP 3306 OPEN' || echo 'TCP 3306 BLOCKED'" \
  | tee "$EVIDENCE_DIR/after/03_bastion_to_db_tcp_3306.txt"
```

期待結果:

```text
TCP 3306 OPEN
```

この確認はTCP Portへの到達性を確認する。DB認証やSQL実行の成功までは確認していない。

変更後も`BLOCKED`の場合は次を確認する。

- 一時RuleのSource SGとPort
- Bastion EC2にBastion SGが関連付いているか
- DB SGがRDSへ関連付いているか
- `db.home`の名前解決
- RDS StatusとEndpoint
- Route Tableのlocal Route
- NACLのInbound、Outbound、Ephemeral Port
- RDSがPort 3306で待ち受けているか

---

## 18. Webアプリケーションの継続正常性を確認する

今回の一時Rule追加によって既存Web-to-DB Ruleは変更していないが、想定外影響がないことを確認する。

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/after/04_web_application_headers.txt"
```

ブラウザで次を確認する。

- Web画面が表示できる
- ログインできる
- DB参照を伴う画面が表示できる
- DB更新を伴う操作が成功する
- Application LogにDB接続エラーがない

取得するスクリーンショット:

```text
05_変更後Webアプリ確認.png
```

---

## 19. 変更後CloudTrailを確認する

Rule追加後、CloudTrailへの反映に数分かかる場合がある。

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --query 'Events[].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId,Resource:Resources[0].ResourceName}' \
  --output table \
  --no-cli-pager
```

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
- 操作者が自分である
- 対象Group IDがDB SGである
- Source Group IDがBastion SGである
- ProtocolとPortがTCP 3306である
- Error Codeがない

---

## 20. 切り戻し直前チェック

切り戻し対象をRule IDで一意に確認する。

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --security-group-rule-ids "$TEMP_RULE_ID" \
  --query 'SecurityGroupRules[].{RuleId:SecurityGroupRuleId,GroupId:GroupId,IsEgress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}' \
  --output table \
  --no-cli-pager
```

切り戻し前チェックリスト:

- [ ] Rule IDが今回追加した一時Ruleである
- [ ] Group IDがDB SGである
- [ ] Source SGがBastion SGである
- [ ] ProtocolがTCPである
- [ ] Portが3306である
- [ ] Descriptionが一時Ruleを示している
- [ ] Web-to-DB既存Ruleとは別Rule IDである
- [ ] Rule IDが1件だけである

一致しない場合は、削除を実行しない。

---

## 21. 一時Ruleを削除して切り戻す

```bash
if aws ec2 revoke-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$DB_SG_ID" \
  --security-group-rule-ids "$TEMP_RULE_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/01_revoke_temp_rule.json" \
  2> "$EVIDENCE_DIR/rollback/01_revoke_temp_rule_error.txt"; then
  ROLLBACK_RC=0
else
  ROLLBACK_RC=$?
fi

printf 'revoke-security-group-ingress exit code: %s\n' "$ROLLBACK_RC" \
  > "$EVIDENCE_DIR/rollback/01_revoke_temp_rule_exit_code.txt"
```

### コマンド結果確認

```bash
cat "$EVIDENCE_DIR/rollback/01_revoke_temp_rule.json"
cat "$EVIDENCE_DIR/rollback/01_revoke_temp_rule_error.txt"
cat "$EVIDENCE_DIR/rollback/01_revoke_temp_rule_exit_code.txt"
```

```bash
if [ "$ROLLBACK_RC" -ne 0 ]; then
  echo "ERROR: Temporary rule rollback failed. Investigate immediately."
fi
```

削除対象は今回追加した一時Rule IDだけに限定する。

---

## 22. 切り戻し後Ruleを確認する

### 一時Rule不存在確認

```bash
TEMP_RULE_COUNT_AFTER_ROLLBACK=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$BASTION_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Temporary rule count after rollback: $TEMP_RULE_COUNT_AFTER_ROLLBACK"
```

期待結果:

```text
0
```

### 既存Web-to-DB Rule確認

```bash
WEB_DB_RULE_COUNT_AFTER_ROLLBACK=$(aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" Name=is-egress,Values=false \
  --query "length(SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='$WEB_SG_ID'])" \
  --output text \
  --no-cli-pager)

echo "Web-to-DB rule count after rollback: $WEB_DB_RULE_COUNT_AFTER_ROLLBACK"
```

期待結果:

```text
1
```

### DB SG全Rule保存

```bash
aws ec2 describe-security-group-rules \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=group-id,Values="$DB_SG_ID" \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/02_db_sg_rules_after_rollback.json"
```

取得するスクリーンショット:

```text
06_DB_SG_切り戻し後Inbound確認.png
```

---

## 23. 切り戻し後疎通を確認する

Bastion上で実行する。

```bash
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' \
  && echo "TCP 3306 OPEN" \
  || echo "TCP 3306 BLOCKED"
```

作業端末から一行で実行し、証跡保存する場合:

```bash
ssh awsref-bastion \
  "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/db.home/3306' && echo 'TCP 3306 OPEN' || echo 'TCP 3306 BLOCKED'" \
  | tee "$EVIDENCE_DIR/rollback/05_bastion_to_db_tcp_3306.txt"
```

期待結果:

```text
TCP 3306 BLOCKED
```

切り戻し後も`OPEN`の場合は、別のSG Rule、共有SG、NACL、経路、接続元判定を調査する。

Webアプリケーションは引き続き正常であることを確認する。

```bash
curl -I https://www.nobu-iac-lab.com \
  | tee "$EVIDENCE_DIR/rollback/06_web_application_headers.txt"
```

---

## 24. 切り戻し後CloudTrailを確認する

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RevokeSecurityGroupIngress \
  --query 'Events[].{Time:EventTime,EventName:EventName,Username:Username,EventId:EventId,Resource:Resources[0].ResourceName}' \
  --output table \
  --no-cli-pager
```

```bash
aws cloudtrail lookup-events \
  --profile "$PROFILE" \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RevokeSecurityGroupIngress \
  --output json \
  --no-cli-pager \
  > "$EVIDENCE_DIR/rollback/03_cloudtrail_revoke_sg_ingress.json"
```

確認項目:

- Event Nameが`RevokeSecurityGroupIngress`
- Event Timeが切り戻し時刻と一致する
- 操作者が自分である
- 対象Group IDがDB SGである
- 削除対象が一時Rule IDである
- Error Codeがない

---

## 25. 変更前と切り戻し後を比較する

Security Group Ruleの出力順序は変わる可能性がある。単純な`diff`結果だけで判断せず、期待Rule件数とRule内容も確認する。

```bash
diff -u \
  "$EVIDENCE_DIR/before/02_db_sg_rules.json" \
  "$EVIDENCE_DIR/rollback/02_db_sg_rules_after_rollback.json" \
  > "$EVIDENCE_DIR/rollback/04_before_after_rollback_diff.txt" \
  || true
```

```bash
cat "$EVIDENCE_DIR/rollback/04_before_after_rollback_diff.txt"
```

判定:

- 一時Ruleが存在しない
- Web-to-DB既存Ruleが1件存在する
- 他の既存Ruleが削除されていない
- Public CIDR Ruleが追加されていない
- 差分が出た場合は出力順序か実設定差分かを確認する

---

## 26. 証跡ファイルを確認する

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

### 証跡数

```bash
find "$EVIDENCE_DIR" \
  -type f \
  | wc -l
```

空ファイルがある場合は、コマンドが出力なしで正常終了したのか、失敗して空になったのかを確認する。

---

## 27. 実施結果記録表

| No. | 区分 | 確認・操作 | 期待結果 | 実施結果 | 証跡 |
|---|---|---|---|---|---|
| 1 | 変更前 | Caller Identity | 想定Account |  | `00_metadata/00_caller_identity.json` |
| 2 | 変更前 | 対象VPC・SG ID | 一意に特定 |  | `00_metadata/01_target_ids.txt` |
| 3 | 変更前 | Source/Destination SG関連リソース | 想定リソースのみ |  | `before/01_bastion_sg_network_interfaces.json` |
| 4 | 変更前 | DB SG Rule保存 | 取得成功 |  | `before/02_db_sg_rules.json` |
| 5 | 変更前 | Web-to-DB既存Rule | 1件 |  |  |
| 6 | 変更前 | Bastion-to-DB一時Rule | 0件 |  |  |
| 7 | 変更前 | BastionからDB疎通 | BLOCKED |  |  |
| 8 | 変更前 | Webアプリ | 正常 |  |  |
| 9 | 変更 | 一時Rule追加 | 成功 |  | `change/01_authorize_temp_rule.json` |
| 10 | 変更後 | 一時Rule | 1件 |  | `after/01_db_sg_rules.json` |
| 11 | 変更後 | BastionからDB疎通 | OPEN |  |  |
| 12 | 変更後 | Webアプリ | 正常 |  |  |
| 13 | 変更後 | CloudTrail追加履歴 | 記録あり |  | `after/02_cloudtrail_authorize_sg_ingress.json` |
| 14 | 切り戻し | 一時Rule削除 | 成功 |  | `rollback/01_revoke_temp_rule.json` |
| 15 | 切り戻し後 | 一時Rule | 0件 |  | `rollback/02_db_sg_rules_after_rollback.json` |
| 16 | 切り戻し後 | Web-to-DB既存Rule | 1件 |  |  |
| 17 | 切り戻し後 | BastionからDB疎通 | BLOCKED |  |  |
| 18 | 切り戻し後 | Webアプリ | 正常 |  |  |
| 19 | 切り戻し後 | CloudTrail削除履歴 | 記録あり |  | `rollback/03_cloudtrail_revoke_sg_ingress.json` |

---

## 28. 推奨スクリーンショット証跡

| No. | ファイル名 | 内容 |
|---|---|---|
| 01 | `01_操作アカウント確認.png` | AWSアカウントとリージョン |
| 02 | `02_DB_SG_変更前Inbound確認.png` | 一時Rule追加前 |
| 03 | `03_変更前Webアプリ確認.png` | 変更前アプリ正常性 |
| 04 | `04_DB_SG_一時Rule追加後.png` | 一時Rule追加後 |
| 05 | `05_変更後Webアプリ確認.png` | 変更後アプリ正常性 |
| 06 | `06_DB_SG_切り戻し後Inbound確認.png` | 一時Rule削除後 |
| 07 | `07_CloudTrail_Rule追加履歴.png` | Authorize履歴 |
| 08 | `08_CloudTrail_Rule削除履歴.png` | Revoke履歴 |

---

## 29. Teams報告例

### 作業開始報告

```text
Security Group変更ドリルを開始します。

対象:
- Account: 445405559057
- Region: ap-northeast-1
- Destination SG: sample-sg-db / <db-sg-id>
- Source SG: sample-sg-bastion / <bastion-sg-id>
- Protocol / Port: TCP / 3306

実施内容:
- ラボ専用の一時Inbound Ruleを追加
- BastionからRDSへの疎通を確認
- CloudTrail変更履歴を確認
- 一時Ruleを削除して変更前状態へ切り戻し

既存のWeb SGからDB SGへのRuleは変更しません。
異常時は今回追加したRule IDだけを削除します。
```

### 変更完了・切り戻し開始報告

```text
一時Security Group Ruleの追加と変更後確認が完了しました。

確認結果:
- 一時Rule: 想定どおり追加
- BastionからRDS TCP 3306: 接続成功
- Webアプリケーション: 正常
- CloudTrail AuthorizeSecurityGroupIngress: 記録あり

続けて、今回追加した一時Rule IDだけを削除し、
変更前状態へ切り戻します。
```

### 作業完了報告

```text
Security Group変更ドリルが完了しました。

実施結果:
- 一時Rule追加: 成功
- 変更後疎通: 成功
- Webアプリケーション: 正常
- 一時Rule削除: 成功
- 切り戻し後一時Rule件数: 0件
- 既存Web-to-DB Rule件数: 1件
- 切り戻し後Webアプリケーション: 正常
- CloudTrail Authorize / Revoke履歴: 確認済み

最終状態:
一時Ruleを削除し、変更前状態へ戻しています。

証跡:
<evidence-directory>
```

### 異常時報告

```text
Security Group変更ドリル中に想定外事象を確認したため、
作業を中止して切り戻しました。

事象:
<発生事象>

対象:
- Destination SG:
- Source SG:
- Temporary Rule ID:

対応:
- 一時Rule削除:
- 切り戻し後Rule確認:
- Webアプリケーション確認:
- CloudTrail確認:

現在状態:
<正常 / 要確認 / 調査中>

証跡:
<evidence-directory>
```

---

## 30. よくある問題と対処

## `InvalidPermission.Duplicate`

同一Protocol、Port、Source SGのRuleがすでに存在する。

- 追加を再実行しない
- 既存Rule ID、Description、作成履歴を確認する
- 一時Ruleが残存している場合は、所有者と利用状況を確認する

## 一時Rule追加後も疎通できない

- Source SGがBastion EC2へ関連付いているか
- Destination SGがRDSへ関連付いているか
- RuleのSource SG ID、Protocol、Portが正しいか
- `db.home`が対象RDSへ解決するか
- RDSが`available`か
- Route Tableにlocal Routeがあるか
- NACLが双方向通信を許可するか
- RDS Portが3306か

## 一時Rule削除後も疎通できる

- 別のSG Ruleが許可していないか
- Bastion EC2が複数SGを持っていないか
- DB SG以外のSGがRDSへ関連付いていないか
- CIDR Ruleや全Protocol Ruleがないか
- 接続確認結果が既存接続やキャッシュの影響を受けていないか

## CloudTrailに変更が表示されない

- 数分待って再確認する
- Regionが正しいか確認する
- Event Nameで検索する
- Event Sourceが`ec2.amazonaws.com`か確認する
- CloudTrail Event Historyの対象期間内か確認する

## 切り戻し対象Rule IDが分からない

- 削除を実行しない
- 変更時の出力JSONを確認する
- Protocol、Port、Source SG、Descriptionで一時Ruleを特定する
- 複数一致する場合は関係者確認まで停止する

---

## 31. セキュリティ上の注意点

- 本番環境で練習目的のRuleを追加しない
- 一時Ruleでもアクセス権限が拡大することを認識する
- Public CIDRをSourceにしない
- Bastion SGが他リソースで共有されていないことを確認する
- Descriptionで一時Ruleと目的を識別できるようにする
- Rule追加直後にRule IDを保存する
- Rule削除前にRule IDと内容を再確認する
- 既存Web-to-DB Ruleを削除しない
- DBパスワードを証跡やShell Historyへ残さない
- 一時Ruleを作業終了後に残さない
- CloudTrailで追加と削除の両方を確認する
- 最終状態が変更前と一致することを確認する

---

## 32. 案件で説明できるポイント

### 作業前確認

```text
Security Group変更前に、対象Account、Region、VPC、SG ID、
既存Rule、関連ENI、関連リソース、変更前疎通、
切り戻し方法を確認します。
```

### 安全な変更

```text
変更コマンド実行直前にSource、Destination、Protocol、Portを再確認し、
変更後は追加Rule IDを保存します。

切り戻しではRule内容だけでなく、
今回追加したSecurity Group Rule IDを指定して削除します。
```

### 変更後確認

```text
設定値だけでなく、疎通、アプリケーション、監視、
CloudTrailを確認して変更完了を判断します。
```

### 最終状態確認

```text
切り戻し後は一時Ruleが0件であること、
既存業務Ruleが残っていること、疎通とアプリが変更前状態であること、
CloudTrailに削除履歴があることを確認します。
```

---

## 33. 資格試験につながるポイント

- Security GroupはStateful
- Security Group RuleのSourceに別SGを指定できる
- SG参照ではSource SGが関連付くENIが接続元候補になる
- Inbound Rule追加は`AuthorizeSecurityGroupIngress`
- Inbound Rule削除は`RevokeSecurityGroupIngress`
- Security Group Rule IDでRuleを一意に識別できる
- SG変更はCloudTrailのManagement Eventへ記録される
- SG変更後もRoute、NACL、DNS、Applicationを確認する必要がある
- NACLはStatelessで戻り通信を個別に許可する
- RDSをPrivate Subnetに置き、DB SGで接続元を限定する

---

## 34. 要確認事項

案件参画後、次を確認する。

- SG変更はWebコンソール、AWS CLI、既存Shellのどれで実施するか
- 変更コマンドを直接実行せず、共通関数Shellを使用するか
- Rule IDを手順書・証跡へ記載するか
- 一時Ruleや検証Ruleの利用可否
- Descriptionの命名規則と作業ID記載方法
- 作業前後の疎通確認方法
- 変更作業時の監視担当
- CloudTrail確認方法と反映待ち時間
- 作業開始、中止、切り戻しの判断者
- スクリーンショットとCLI証跡の保存方法
- 最終状態確認のレビュー担当

不明点は推測で変更せず、要確認事項として手順書と報告へ残す。

---

## 35. 中断時・再開時の残存一時Rule確認

作業中断、Terminal切断、変数消失などが発生した場合は、最初に一時Ruleが残っていないか確認する。

```bash
aws ec2 describe-security-group-rules \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-id,Values="<db-sg-id>" Name=is-egress,Values=false \
  --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`3306\` && ToPort==\`3306\` && ReferencedGroupInfo.GroupId=='<bastion-sg-id>'].{RuleId:SecurityGroupRuleId,GroupId:GroupId,SourceSg:ReferencedGroupInfo.GroupId,Description:Description}" \
  --output table \
  --no-cli-pager
```

残存Ruleを確認した場合:

1. DB SG ID、Bastion SG ID、TCP 3306、DescriptionがDay 13一時Ruleと一致することを確認する
2. Rule IDを記録する
3. 他作業が利用していないことを確認する
4. 今回の一時Ruleと特定できた場合だけ、Rule IDを指定して削除する
5. 削除後に一時Ruleが0件であることを確認する
6. CloudTrailと証跡を保存する

```bash
aws ec2 revoke-security-group-ingress \
  --profile learning \
  --region ap-northeast-1 \
  --group-id "<db-sg-id>" \
  --security-group-rule-ids "<temporary-rule-id>" \
  --output json \
  --no-cli-pager
```

一時Ruleと断定できない場合は削除せず、要確認事項として報告する。

---

## 36. Day 13完了チェックリスト

- [ ] Day 12の手順書を確認した
- [ ] 模擬変更方式と最終状態を説明できる
- [ ] 作業開始条件、中止条件、切り戻し条件を確認した
- [ ] 作業用変数を設定した
- [ ] 証跡保存用ディレクトリを作成した
- [ ] Caller Identityを確認した
- [ ] VPC、Bastion SG、Web SG、DB SGを一意に特定した
- [ ] Source SGとDestination SGの関連リソースを確認した
- [ ] 変更前DB SG Ruleを保存した
- [ ] 既存Web-to-DB Ruleが1件あることを確認した
- [ ] 一時Bastion-to-DB Ruleが0件であることを確認した
- [ ] 変更前Bastion-to-DB疎通を確認した
- [ ] 変更前Webアプリケーションを確認した
- [ ] 変更前CloudTrailを確認した
- [ ] 変更直前チェックを実施した
- [ ] 一時Ruleを追加した
- [ ] 一時Rule IDを保存した
- [ ] 変更後Rule内容を確認した
- [ ] 変更後Bastion-to-DB疎通を確認した
- [ ] 変更後Webアプリケーションを確認した
- [ ] CloudTrailのRule追加履歴を確認した
- [ ] 切り戻し対象Rule IDを再確認した
- [ ] 一時Ruleを削除した
- [ ] 切り戻し後一時Ruleが0件であることを確認した
- [ ] 既存Web-to-DB Ruleが残っていることを確認した
- [ ] 切り戻し後疎通とWebアプリケーションを確認した
- [ ] CloudTrailのRule削除履歴を確認した
- [ ] 証跡と作業結果を整理した
- [ ] 一時Ruleが残っていないことを最終確認した

## Day 13の完了条件

次を自分の言葉で説明できればDay 13は完了とする。

```text
Security Group変更では、変更前設定と影響範囲を確認し、
変更直前に対象、Source、Protocol、Portを再確認する。

変更後はRule IDとRule内容を保存し、
設定値、疎通、アプリケーション、監視、CloudTrailを確認する。

切り戻しでは今回追加したRule IDだけを削除し、
一時Ruleが存在しないこと、既存業務Ruleが残っていること、
疎通とアプリが変更前状態へ戻ったことを確認する。

作業は、変更、確認、切り戻し、最終状態確認、証跡、報告までを
一つのまとまりとして完了させる。
```
