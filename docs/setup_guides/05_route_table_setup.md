# 05_route_table_setup.sh 解説

## 概要

`05_route_table_setup.sh` は、`sample-vpc` 内のPublic SubnetとPrivate SubnetにRoute Tableを設定するスクリプトである。

このスクリプトにより、設計書の以下の経路を作成する。

| Route Table | 対象 | ルート | 関連Subnet |
| :--- | :--- | :--- | :--- |
| sample-rt-public | Public | 0.0.0.0/0 -> sample-igw | sample-subnet-public01, sample-subnet-public02 |
| sample-rt-private01 | Private | 0.0.0.0/0 -> sample-ngw-01 | sample-subnet-private01 |
| sample-rt-private02 | Private | 0.0.0.0/0 -> sample-ngw-02 | sample-subnet-private02 |

`03_internetgateway_setup.sh` でInternet GatewayをVPCへアタッチし、`04_nat_gateway_setup.sh` でNAT Gatewayを作成していても、Route Tableに経路がなければSubnetから外部へ通信できない。

この手順で初めて、Public SubnetはInternet Gateway経由、Private SubnetはNAT Gateway経由で外向き通信できる構成になる。

## 前提条件

このスクリプトを実行する前に、以下のスクリプトが完了している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public Subnet / Private Subnetを作成する |
| `03_internetgateway_setup.sh` | Internet Gatewayを作成し、VPCへアタッチする |
| `04_nat_gateway_setup.sh` | NAT Gateway 01 / 02を作成し、`available` まで待機する |

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=attachment.vpc-id,Values=<VPC_ID> \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table

aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=vpc-id,Values=<VPC_ID> Name=state,Values=available \
  --query 'NatGateways[*].{ID:NatGatewayId,Name:Tags[?Key==`Name`].Value|[0],State:State,Subnet:SubnetId}' \
  --output table
```

また、AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではRoute Table、Route、Route Table Associationを操作するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`
- `ec2:DescribeInternetGateways`
- `ec2:DescribeNatGateways`
- `ec2:DescribeRouteTables`
- `ec2:CreateRouteTable`
- `ec2:CreateRoute`
- `ec2:ReplaceRoute`
- `ec2:AssociateRouteTable`
- `ec2:ReplaceRouteTableAssociation`
- `ec2:CreateTags`

削除運用まで含める場合は、以下も必要になる。

- `ec2:DisassociateRouteTable`
- `ec2:DeleteRoute`
- `ec2:DeleteRouteTable`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、参照するNameタグを定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 共通関数を定義する
5. 実行対象のAWSアカウントとIAMユーザーを確認する
6. `sample-vpc` が1つだけ存在することを確認し、VPC IDを取得する
7. VPC IDで絞り込み、Internet Gateway、NAT Gateway、SubnetのIDを取得する
8. Public Route Tableを作成または再利用する
9. Public Route Tableに `0.0.0.0/0 -> Internet Gateway` を設定する
10. Public Subnet 01 / 02をPublic Route Tableへ関連付ける
11. Private Route Table 01を作成または再利用する
12. Private Route Table 01に `0.0.0.0/0 -> NAT Gateway 01` を設定する
13. Private Subnet 01をPrivate Route Table 01へ関連付ける
14. Private Route Table 02を作成または再利用する
15. Private Route Table 02に `0.0.0.0/0 -> NAT Gateway 02` を設定する
16. Private Subnet 02をPrivate Route Table 02へ関連付ける
17. VPC内のRoute Tableを一覧表示して確認する

## Bashの安全設定

```bash
#!/bin/bash
set -euo pipefail
```

`set -euo pipefail` は、シェルスクリプトを安全に実行するための設定である。

| 設定 | 意味 |
| :--- | :--- |
| `-e` | コマンドが失敗した時点でスクリプトを終了する |
| `-u` | 未定義の変数を使った場合にエラーにする |
| `-o pipefail` | パイプ処理の途中で失敗した場合もエラーとして扱う |

Route Table変更は通信経路そのものを変更する作業である。途中の失敗を見落として後続処理が進むと、意図しない通信断や経路不整合につながる可能性があるため、失敗時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
IGW_NAME="sample-igw"
NGW01_NAME="sample-ngw-01"
NGW02_NAME="sample-ngw-02"
PUB01_NAME="sample-subnet-public01"
PUB02_NAME="sample-subnet-public02"
PRI01_NAME="sample-subnet-private01"
PRI02_NAME="sample-subnet-private02"

RT_PUB_NAME="sample-rt-public"
RT_PRI01_NAME="sample-rt-private01"
RT_PRI02_NAME="sample-rt-private02"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、Route Tableを設定するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`VPC_NAME`、`IGW_NAME`、`NGW01_NAME`、`NGW02_NAME`、Subnet名は、前工程で作成したリソースを検索するために使用する。

`RT_PUB_NAME`、`RT_PRI01_NAME`、`RT_PRI02_NAME` は、Route Tableの作成または再利用判定に使用する。

## LocalStack設定の無効化

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

LocalStack向けのaliasや環境変数が残っていると、実AWSではなくLocalStackへ接続する可能性がある。

このスクリプトは実AWSのRoute Tableを変更するため、LocalStack関連設定を無効化する。

## ID取得チェック関数

```bash
get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}
```

AWS CLIの検索結果が存在しない場合、`--output text` では `None` または空文字が返ることがある。

Route Table設定は、VPC、IGW、NAT Gateway、Subnetに依存する。前提リソースのIDが取れていない状態で処理を進めると、原因が分かりにくいエラーや誤った設定につながるため、この関数で明示的に停止する。

## Route Tableの作成または再利用

```bash
ensure_route_table() {
  local route_table_name="$1"
  ...
}
```

`ensure_route_table` は、同じVPC内に同じNameタグのRoute Tableが存在するか確認する。

既存Route Tableがある場合は、そのRoute Table IDを返す。存在しない場合は、新しくRoute Tableを作成する。

この設計により、スクリプトを再実行してもRoute Tableを重複作成しない。

また、同じNameタグのRoute Tableが複数存在する場合は、先頭を自動選択せずにエラーで停止する。

これは案件作業でも重要である。Route Table変更では、誤ったRoute Tableを変更すると想定外のSubnet通信に影響する可能性があるため、重複リソースがある場合は先に整理または確認する。

## デフォルトルートの作成または更新

```bash
ensure_default_route "$RT_PUB_ID" "igw" "$IGW_ID" "Public Route Table"
ensure_default_route "$RT_PRI01_ID" "nat" "$NGW01_ID" "Private Route Table 01"
ensure_default_route "$RT_PRI02_ID" "nat" "$NGW02_ID" "Private Route Table 02"
```

`ensure_default_route` は、`0.0.0.0/0` のルートを作成または更新する関数である。

処理内容は以下である。

| 状態 | 処理 |
| :--- | :--- |
| 期待通りの向き先で既に存在する | 何もしない |
| `0.0.0.0/0` が存在しない | `create-route` で作成する |
| `0.0.0.0/0` はあるが向き先が違う | `replace-route` で置き換える |

Public Route Tableでは、`0.0.0.0/0` をInternet Gatewayへ向ける。

Private Route Tableでは、`0.0.0.0/0` をNAT Gatewayへ向ける。

`0.0.0.0/0` は、VPC内ローカルCIDRに一致しない通信のデフォルト経路である。VPC内通信は通常、Route Tableに自動作成される `local` ルートで処理される。

## Route Table Associationの作成または更新

```bash
ensure_route_table_association "$PUB01_ID" "$RT_PUB_ID" "Public Subnet 01"
ensure_route_table_association "$PUB02_ID" "$RT_PUB_ID" "Public Subnet 02"
ensure_route_table_association "$PRI01_ID" "$RT_PRI01_ID" "Private Subnet 01"
ensure_route_table_association "$PRI02_ID" "$RT_PRI02_ID" "Private Subnet 02"
```

`ensure_route_table_association` は、SubnetとRoute Tableの関連付けを作成または更新する関数である。

処理内容は以下である。

| 状態 | 処理 |
| :--- | :--- |
| 期待通りのRoute Tableに関連付いている | 何もしない |
| 別のRoute Tableに明示的に関連付いている | `replace-route-table-association` で差し替える |
| 明示的な関連付けがない | `associate-route-table` で関連付ける |

Subnetは、明示的にRoute Tableへ関連付けられていない場合、VPCのmain route tableを使用する。

本構成では、Public SubnetとPrivate Subnetの経路を明確に分けるため、各Subnetを明示的にカスタムRoute Tableへ関連付ける。

## VPC IDでの絞り込み

このスクリプトでは、前提リソースの取得時にVPC IDで絞り込む。

例:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text
```

Nameタグだけで検索すると、別VPCに同名Subnetや同名NAT Gatewayが存在した場合に誤取得する可能性がある。

特に案件作業では、開発、検証、本番など複数環境に似たNameタグのリソースが存在することがある。Route Table変更では誤取得が通信影響に直結するため、VPC IDで検索範囲を限定する。

## 実行結果

実行コマンド:

```bash
./05_route_table_setup.sh
```

実行時に確認された主なリソースID:

| 種別 | 値 |
| :--- | :--- |
| VPC | vpc-09872a034f259a5f3 |
| Internet Gateway | igw-0ddad1b7e6600a21d |
| NAT Gateway 01 | nat-0a9a3139d04df4a44 |
| NAT Gateway 02 | nat-0af657b124c9512de |
| Public Subnet 01 | subnet-0d93b924889bb2ede |
| Public Subnet 02 | subnet-027e5f398c2a0e4bd |
| Private Subnet 01 | subnet-0142374c89d7e9608 |
| Private Subnet 02 | subnet-0bf266742a8f500dc |

作成されたRoute Table:

| Route Table | ID | 関連Subnet | デフォルトルート |
| :--- | :--- | :--- | :--- |
| sample-rt-public | rtb-05ecdb3932180b324 | public01, public02 | 0.0.0.0/0 -> igw-0ddad1b7e6600a21d |
| sample-rt-private01 | rtb-0ac5e6e7302a0d073 | private01 | 0.0.0.0/0 -> nat-0a9a3139d04df4a44 |
| sample-rt-private02 | rtb-0d0f89e4447edf45a | private02 | 0.0.0.0/0 -> nat-0af657b124c9512de |

確認結果として、Public SubnetはInternet Gatewayへ、Private Subnetは各AZのNAT Gatewayへ向く構成になった。

また、`Name: None` のRoute Tableが表示された。これはVPC作成時に自動作成されるmain route tableである。今回の構成では各Subnetを明示的にカスタムRoute Tableへ関連付けているため、main route tableが残っていても問題ない。

## 変更前確認

Route Table変更前には、少なくとも以下を確認する。

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<VPC_ID> \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,Associations:Associations[*].SubnetId,Routes:Routes[*]}' \
  --output json
```

確認ポイント:

- 対象VPCが正しいこと
- 変更対象Subnetが正しいこと
- 既存のRoute Table Associationがどうなっているか
- 既存の `0.0.0.0/0` ルートがあるか
- 既存のmain route tableを誤って変更しようとしていないか
- NAT Gatewayが `available` であること
- Internet Gatewayが対象VPCへアタッチされていること

案件作業では、変更前の状態をJSONまたはスクリーンショットで残すと、変更後比較と切り戻し判断に使いやすい。

## 変更後確認

スクリプト実行後は、以下を確認する。

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<VPC_ID> \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,AssociatedSubnets:Associations[?SubnetId!=`null`].SubnetId,IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0],NGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]}' \
  --output table
```

確認ポイント:

- `sample-rt-public` がPublic Subnet 01 / 02に関連付いていること
- `sample-rt-public` の `0.0.0.0/0` がInternet Gatewayを向いていること
- `sample-rt-private01` がPrivate Subnet 01に関連付いていること
- `sample-rt-private01` の `0.0.0.0/0` がNAT Gateway 01を向いていること
- `sample-rt-private02` がPrivate Subnet 02に関連付いていること
- `sample-rt-private02` の `0.0.0.0/0` がNAT Gateway 02を向いていること

将来的にEC2作成後は、以下の疎通確認も行う。

- Public Subnet上のBastionへSSHできること
- Private Subnet上のWeb EC2から外部へHTTP/HTTPS通信できること
- Private Subnet上のWeb EC2が直接インターネットから到達できないこと
- ALBからWeb EC2へ到達できること

## 切り戻し方法

Route Table変更の切り戻しでは、変更前に控えたRoute Table Association IDとRoute Table IDを使う。

別Route Tableへ戻す場合:

```bash
aws ec2 replace-route-table-association \
  --profile learning \
  --region ap-northeast-1 \
  --association-id <ASSOCIATION_ID> \
  --route-table-id <ROLLBACK_ROUTE_TABLE_ID>
```

デフォルトルートを削除する場合:

```bash
aws ec2 delete-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <ROUTE_TABLE_ID> \
  --destination-cidr-block 0.0.0.0/0
```

デフォルトルートの向き先を戻す場合:

```bash
aws ec2 replace-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <ROUTE_TABLE_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id <IGW_ID>
```

またはNAT Gatewayへ戻す場合:

```bash
aws ec2 replace-route \
  --profile learning \
  --region ap-northeast-1 \
  --route-table-id <ROUTE_TABLE_ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id <NAT_GATEWAY_ID>
```

実務では、切り戻し前にも現在のRoute Table状態を再取得し、想定外の変更が入っていないか確認してから実行する。

## 削除時の注意

`05_route_table_setup.sh` を実行すると、カスタムRoute Tableが作成される。

VPC削除時は、Subnet、Internet Gateway、NAT Gatewayなどの依存関係に加えて、カスタムRoute Tableも削除対象になる。

現在の `cleanup_network.sh` がRoute Table削除に対応していない場合、VPC削除時に `DependencyViolation` になる可能性がある。

削除スクリプトでは、以下の順序を考慮する。

1. NAT Gatewayを削除する
2. NAT Gatewayが `deleted` になるまで待つ
3. Elastic IPを解放する
4. Internet Gatewayをdetachして削除する
5. Subnetを削除する
6. カスタムRoute Tableを削除する
7. VPCを削除する

main route tableはVPCに紐づく標準リソースであり、単体削除しない。VPC削除時に一緒に削除される。

## 影響範囲

Route Table変更は、対象Subnet内の全リソースの通信経路に影響する。

本構成で影響を受ける想定リソースは以下である。

| 対象 | 影響 |
| :--- | :--- |
| Public Subnet 01 / 02 | ALB、Bastion、NAT Gatewayのインターネット到達性 |
| Private Subnet 01 | WebServer 01の外向き通信 |
| Private Subnet 02 | WebServer 02の外向き通信 |
| RDS / ElastiCache | 同じPrivate Subnetに配置する場合、外向き通信や管理経路の影響を受ける可能性 |

Route Tableを誤ると、以下のような事象が起きる。

- Public SubnetのBastionへSSHできない
- ALBがインターネットから到達できない
- NAT Gatewayが外部へ出られず、Private Subnetの外向き通信が失敗する
- Private Subnetが誤ってInternet Gatewayへ向き、意図しない公開経路になる
- 片方のAZだけ外向き通信できない

## 気をつける点

- Public Subnetは、Internet GatewayへのルートがあるSubnetである
- Private Subnetは、Internet Gatewayへ直接出るルートを持たないSubnetである
- NAT GatewayはPublic Subnetに配置する
- Private Subnetから外部へ出るには、Private Route Tableの `0.0.0.0/0` をNAT Gatewayへ向ける
- NAT Gatewayは外向き通信のための仕組みであり、外部からPrivate EC2へ入るための入口ではない
- Route Tableの変更はSubnet単位で影響する
- Nameタグだけでリソースを検索せず、VPC IDでも絞り込む
- 再実行時にRoute Tableを重複作成しない
- 変更前のRoute Table状態を必ず控える
- 変更後はRoute Tableだけでなく、実際の疎通確認を行う

## 案件実務ポイント

今回の銀行案件では、影響調査済みのAWS設定変更、テスト、手順書作成が中心になる見込みである。

Route Table変更作業では、以下の観点が重要になる。

- 作業対象のVPC、Subnet、Route Tableが正しいことを事前確認する
- 変更前のRoute Table状態を証跡として保存する
- 変更内容を差分として説明できるようにする
- 変更後に通信できるべき経路と、通信できてはいけない経路を確認する
- 異常時に元のRoute Table AssociationやRouteへ戻す手順を用意する
- 本番環境では承認された作業時間帯、作業手順、確認観点に従う

説明例:

```text
Public SubnetにはInternet Gateway向けのデフォルトルートを設定し、
Private Subnetには各AZのNAT Gateway向けのデフォルトルートを設定しました。
これにより、Private Subnet上のサーバーはPublic IPを持たずに外向き通信できます。
変更前後でRoute Table Associationと0.0.0.0/0の向き先を確認し、
想定外のSubnetに影響がないことを確認します。
```

## 試験対策ポイント

AWS Advanced NetworkingやSolutions Architect系の試験では、Route Table、IGW、NAT Gatewayの関係は頻出である。

押さえるポイント:

- Public SubnetとPrivate Subnetの違いはRoute Tableで決まる
- Internet GatewayはVPCにアタッチするだけでは通信経路にならない
- Subnetに関連付いたRoute Tableに `0.0.0.0/0 -> IGW` があると、Public Subnetとして動作する
- Private Subnetからインターネットへ出るには `0.0.0.0/0 -> NAT Gateway` が必要
- NAT GatewayはAZ内に配置されるため、AZごとにNAT GatewayとPrivate Route Tableを分ける構成が可用性と設計説明に有利
- Route TableにはVPC CIDR向けの `local` ルートが自動作成される
- Security GroupやNACLが許可していても、Route Tableに経路がなければ通信できない
- Route Tableが正しくても、Security GroupやNACLで拒否されれば通信できない

## 今後の確認

このスクリプトは再実行耐性を入れているため、再度実行した場合は以下のような挙動になる想定である。

- 既存Route Tableを再利用する
- 既存の正しいデフォルトルートはスキップする
- 既存の正しいSubnet関連付けはスキップする
- 重複Route Tableがある場合は停止する

再実行確認コマンド:

```bash
./05_route_table_setup.sh
```

確認後は、`cleanup_network.sh` にRoute Table削除処理を追加し、`01` から `05` までの作成リソースを安全に削除できるようにする。

