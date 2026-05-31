# 10_Database_setup.sh 解説

## 概要

`10_Database_setup.sh` は、Private Subnet上にAmazon RDS for MySQLを作成するスクリプトである。

Web EC2からのみMySQL接続を許可し、インターネットからRDSへ直接接続できない構成にする。

この手順で作成または利用する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| Security Group | sample-sg-db | RDS用Security Group |
| Ingress Rule | Web SG -> DB SG:3306 | Web EC2からのMySQL接続のみ許可 |
| DB Parameter Group | sample-db-pg | MySQLのDBパラメータ管理 |
| DB Option Group | sample-db-og | MySQLのDBオプション管理 |
| DB Subnet Group | sample-db-subnet | RDSを配置できるPrivate Subnet群 |
| RDS DB Instance | sample-db | MySQL DB本体 |

RDSはPrivate Subnetに配置し、`--no-publicly-accessible` を指定する。

これにより、外部公開の入口はALB、運用入口はBastion、DB接続元はWeb EC2に限定する構成になる。

## 前提条件

このスクリプトを実行する前に、少なくとも以下のリソースが作成されている必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Private Subnet 01 / 02を作成する |
| `06_security_group_setup.sh` | Bastion用 / ELB用Security Groupを作成する |
| `08_Web_server_setup.sh` | Web用Security Group `sample-sg-web` を作成する |

RDS自体はALBを必要としないため、`09_LoadBalancer_setup.sh` は直接の前提ではない。

ただし、この学習環境全体では、WebアプリケーションをALB経由で公開するため、通常は01から09まで作成した後に10を実行する。

## 実行前のパスワード設定

DBマスターパスワードはスクリプトに直書きしない。

実行前に環境変数で設定する。

```bash
export DB_MASTER_PASSWORD='任意の強いパスワード'
./10_Database_setup.sh
```

スクリプトでは、RDS MySQLの制約に合わせて最低限以下を確認する。

| 項目 | 条件 |
| :--- | :--- |
| 文字数 | 8文字以上、41文字以下 |
| 使用不可文字 | `/`、`"`、`@` |

実運用では、平文の環境変数だけに頼らず、Secrets ManagerやSSM Parameter Storeで管理するのが望ましい。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、RDS関連名を定義する
3. `DB_MASTER_PASSWORD` の存在と基本制約を確認する
4. LocalStack向けの設定が残っていないように無効化する
5. 実行対象のAWSアカウントとIAMユーザーを確認する
6. `sample-vpc` が1つだけ存在することを確認し、VPC IDを取得する
7. VPC IDで絞り込み、Private Subnet 01 / 02を取得する
8. Private Subnet 2つが別AZであることを確認する
9. VPC IDで絞り込み、Web用Security Groupを取得する
10. DB用Security Groupを作成または再利用する
11. Web用Security GroupからDB用Security Groupへの3306番を許可する
12. DB Parameter Groupを作成または再利用する
13. DB Option Groupを作成または再利用する
14. DB Subnet Groupを作成または再利用する
15. RDS DB Instanceを作成または再利用する
16. RDSが `available` になるまで待機する
17. RDSとDB用Security Groupの状態を確認する

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

RDSは課金対象であり、VPC、Subnet、Security Groupとの関連も強い。

途中の失敗を見落とすと、削除不能な依存関係や意図しない公開設定につながるため、失敗時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
PRIVATE_SUBNET_01_NAME="sample-subnet-private01"
PRIVATE_SUBNET_02_NAME="sample-subnet-private02"

WEB_SG_NAME="sample-sg-web"
DB_SG_NAME="sample-sg-db"

DB_PARAMETER_GROUP_NAME="sample-db-pg"
DB_OPTION_GROUP_NAME="sample-db-og"
DB_SUBNET_GROUP_NAME="sample-db-subnet"
DB_INSTANCE_IDENTIFIER="sample-db"

DB_ENGINE="mysql"
DB_ENGINE_VERSION="8.0"
DB_PARAMETER_GROUP_FAMILY="mysql8.0"
DB_MAJOR_ENGINE_VERSION="8.0"
DB_PORT="3306"

DB_INSTANCE_CLASS="db.t3.micro"
DB_ALLOCATED_STORAGE="20"
DB_MASTER_USERNAME="adminuser"
```

今回のRDSは学習用の小さい構成である。

| 項目 | 値 |
| :--- | :--- |
| Engine | MySQL |
| Engine Version | 8.0 |
| Instance Class | db.t3.micro |
| Storage | 20 GiB |
| Storage Type | gp2 |
| Public Access | 無効 |
| Multi-AZ | 無効 |
| Backup Retention | 0日 |
| Deletion Protection | 無効 |
| Storage Encryption | 有効 |

学習環境では削除しやすさを優先しているため、Backup Retention、Multi-AZ、Deletion Protectionは無効にしている。

銀行系の実運用では、Multi-AZ、バックアップ、削除保護、KMSキー、監査ログ、変更管理が重要になる。

## VPC IDでの絞り込み

このスクリプトでは、SubnetやSecurity Groupの取得時にVPC IDで絞り込む。

例:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'length(Subnets)' \
  --output text
```

Nameタグだけで検索すると、別VPCに同じ名前のSubnetやSecurity Groupが存在した場合に、誤ったリソースを参照する可能性がある。

そのため、まず `sample-vpc` を1件に特定し、そのVPC IDを使って後続リソースを検索する。

| 件数 | 処理 |
| :--- | :--- |
| 0件 | 前提リソースがないため停止 |
| 1件 | そのリソースを使用 |
| 2件以上 | 誤作業防止のため停止 |

## Private SubnetのAZ確認

DB Subnet Groupには、複数AZのSubnetを指定する。

このスクリプトでは、`sample-subnet-private01` と `sample-subnet-private02` のAvailability Zoneを確認し、同じAZだった場合は停止する。

```bash
if [ "$SUBNET_PRIV01_AZ" = "$SUBNET_PRIV02_AZ" ]; then
  echo "Error: DB Subnet Group should use subnets in at least two Availability Zones."
  exit 1
fi
```

RDSのDB Subnet Groupは、DBを配置できるSubnetの候補を定義するものである。

単一AZ構成でDB Instanceを作る場合でも、Subnet Groupには複数AZのSubnetを用意するのが基本である。

## DB Security Group

DB用Security Group `sample-sg-db` を作成または再利用する。

このSecurity Groupには、Web用Security Group `sample-sg-web` からの3306番だけを許可する。

```bash
UserIdGroupPairs=[
  {
    GroupId="$WEB_SG_ID",
    Description="MySQL access from web servers"
  }
]
```

ポイントは、送信元にCIDRではなくSecurity Groupを指定していることである。

| 設定 | 意味 |
| :--- | :--- |
| Source | `sample-sg-web` |
| Protocol | TCP |
| Port | 3306 |
| Destination | `sample-sg-db` |

これにより、Web EC2のPrivate IPが変わっても、Web用Security Groupに所属していればDB接続が許可される。

逆に、BastionやインターネットからRDSへ直接接続する経路は作らない。

## DB Parameter Group

DB Parameter Group `sample-db-pg` を作成または再利用する。

既存のParameter Groupがある場合は、familyが `mysql8.0` であることを確認する。

familyが異なる場合は、同名でも互換性がないため停止する。

```bash
DB_PARAMETER_GROUP_FAMILY="mysql8.0"
```

今回は個別パラメータの変更は行っていない。

案件対策としては、Parameter Groupの変更には以下の観点がある。

- 変更対象パラメータが動的反映か、再起動が必要か
- DB再起動が必要な場合、停止時間や影響範囲は何か
- 変更前後の値を記録しているか
- ロールバック手順があるか

## DB Option Group

DB Option Group `sample-db-og` を作成または再利用する。

既存のOption Groupがある場合は、engineとmajor versionが期待値と一致することを確認する。

```bash
DB_ENGINE="mysql"
DB_MAJOR_ENGINE_VERSION="8.0"
```

今回は追加オプションの設定は行っていない。

実運用では、監査、バックアップ、暗号化、外部連携などの機能追加時にOption Groupが関係することがある。

## DB Subnet Group

DB Subnet Group `sample-db-subnet` を作成または再利用する。

指定するSubnetは以下の2つである。

| Subnet | 用途 |
| :--- | :--- |
| sample-subnet-private01 | RDS配置候補のPrivate Subnet |
| sample-subnet-private02 | RDS配置候補のPrivate Subnet |

既存Subnet Groupを再利用する場合も、対象Subnetを現在のPrivate Subnet 2つにそろえる。

```bash
aws rds modify-db-subnet-group \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --subnet-ids "$SUBNET_PRIV01" "$SUBNET_PRIV02"
```

これにより、古いSubnet IDが残ったままになることを防ぐ。

## RDS DB Instance

RDS DB Instance `sample-db` を作成または再利用する。

新規作成時の主な設定は以下である。

```bash
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --engine "$DB_ENGINE" \
  --engine-version "$DB_ENGINE_VERSION" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --allocated-storage "$DB_ALLOCATED_STORAGE" \
  --storage-type gp2 \
  --storage-encrypted \
  --master-username "$DB_MASTER_USERNAME" \
  --master-user-password "$DB_MASTER_PASSWORD" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  --vpc-security-group-ids "$DB_SG_ID" \
  --no-publicly-accessible \
  --backup-retention-period 0 \
  --no-multi-az \
  --no-deletion-protection
```

重要な設定は以下である。

| 設定 | 意味 |
| :--- | :--- |
| `--db-subnet-group-name` | RDSをPrivate Subnet群へ配置する |
| `--vpc-security-group-ids` | DB用Security Groupを関連付ける |
| `--no-publicly-accessible` | Public IPを持たせない |
| `--storage-encrypted` | ストレージ暗号化を有効にする |
| `--backup-retention-period 0` | 学習用のため自動バックアップを無効化 |
| `--no-multi-az` | 学習用のためSingle-AZ構成 |
| `--no-deletion-protection` | 学習後に削除しやすくする |

銀行案件を意識する場合、特に見るべき点は以下である。

- DBがPubliclyAccessibleになっていないか
- DB用Security Groupの送信元が広すぎないか
- 暗号化が有効か
- バックアップや削除保護が必要な環境で無効になっていないか
- Parameter Group変更に再起動が必要か
- 設定変更時の影響範囲、手順、ロールバックが整理されているか

## 再実行耐性

このスクリプトは、同じリソースが既に存在する場合に再利用する。

| 対象 | 再実行時の動作 |
| :--- | :--- |
| DB Security Group | 既存を再利用し、タグを再設定する |
| DB Ingress Rule | 既存ルールがあればDuplicateを正常扱いにする |
| DB Parameter Group | 既存を再利用し、familyを確認する |
| DB Option Group | 既存を再利用し、engine / major versionを確認する |
| DB Subnet Group | 既存を再利用し、Subnetを現在の2つにそろえる |
| RDS DB Instance | 既存を再利用し、必要に応じてSG関連付けを更新する |
| stopped状態のRDS | 起動してavailableになるまで待つ |

ただし、以下の場合は自動修正せず停止する。

| 状況 | 停止理由 |
| :--- | :--- |
| 同名VPCが複数ある | 誤ったVPCを選ぶ危険がある |
| 同名Subnetが複数ある | 誤ったSubnetを選ぶ危険がある |
| 同名Web SGが複数ある | DB接続許可の送信元を誤る危険がある |
| 既存DBがPubliclyAccessible | セキュリティ上の問題がある |
| 既存DBのengineが異なる | 期待するMySQL構成ではない |
| 既存DBのSubnet Groupが異なる | 想定外の配置になっている |
| RDSがdeleting / failed等 | 状態確認が必要 |

## 実行結果の確認

スクリプトの最後に、RDSとDB Security Groupを確認する。

RDS確認:

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion,Class:DBInstanceClass,Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,StorageEncrypted:StorageEncrypted,MultiAZ:MultiAZ,DBSubnetGroup:DBSubnetGroup.DBSubnetGroupName,VpcSecurityGroups:VpcSecurityGroups[*].VpcSecurityGroupId}' \
  --output table
```

DB Security Group確認:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-db \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceSecurityGroups:UserIdGroupPairs[*].GroupId,Description:UserIdGroupPairs[*].Description}}' \
  --output table
```

確認ポイント:

| 項目 | 期待値 |
| :--- | :--- |
| Status | available |
| PubliclyAccessible | False |
| StorageEncrypted | True |
| Port | 3306 |
| DBSubnetGroup | sample-db-subnet |
| DB SG Ingress | sample-sg-webから3306のみ |

## Railsアプリとの関係

このRDSは、後続のRailsアプリケーションから接続される想定である。

現時点のWeb EC2では、nginxがPuma socketへ転送しようとしているが、Rails/Pumaがまだ起動していない場合は502になる。

Railsアプリを動かすには、RDS作成後に以下が必要になる。

| 項目 | 内容 |
| :--- | :--- |
| DB接続先 | RDS EndpointまたはPrivate DNS名 |
| DBユーザー | `adminuser` またはアプリ用DBユーザー |
| DBパスワード | Secrets Manager / 環境変数 / credentials等で管理 |
| Security Group | Web SGからDB SGの3306番が許可されていること |
| Private DNS | Ansibleやアプリが `db.home` を期待する場合は名前解決が必要 |
| Puma | RailsアプリをPumaで起動し、nginxのupstreamと合わせる |

以前の構成で `db.home` を使っていた場合、次の段階ではPrivate Hosted Zoneまたはアプリ設定でRDS Endpointを参照できるようにする。

## 削除時の注意

RDSはSubnetやSecurity Groupに依存しているため、削除順が重要である。

削除時は、先にRDS DB Instanceを削除し、その後にDB Subnet Group、DB Parameter Group、DB Option Group、DB Security Groupを削除する。

このため、`cleanup_network.sh` は10番のRDS関連リソースにも対応している。

確認には以下を使う。

```bash
./check_cleanup.sh
```

削除後に期待する状態:

- `sample-db` が存在しない
- `sample-db-subnet` が存在しない
- `sample-db-pg` が存在しない
- `sample-db-og` が存在しない
- `sample-sg-db` が存在しない

## 案件対策としての見どころ

この手順は、銀行案件の「AWSセキュリティ・ネットワーク最適化・改善」「影響調査や設定変更、手順書作成」に直結する。

面談や実務で説明しやすいポイントは以下である。

| 観点 | 説明ポイント |
| :--- | :--- |
| ネットワーク分離 | DBはPrivate Subnetに配置し、Public IPを持たせない |
| 最小権限通信 | DB接続元はWeb Security Groupに限定する |
| 影響調査 | Parameter Group変更やSG変更の影響範囲を確認する |
| 設定変更 | 変更前後の値、対象リソース、反映タイミングを確認する |
| 手順書 | 作成、確認、ロールバック、削除の手順を分けて記録する |
| セキュリティ | 暗号化、公開設定、SG、バックアップ、監査ログを見る |
| 運用 | RDSの状態、Endpoint、依存関係、削除順を確認する |

特に、S3バケットポリシーやSecurity Group変更と同じく、RDSでも「誰から、どこへ、何番ポートで、どの権限で通信できるか」を説明できることが重要である。

## 実運用との差分

この学習環境では、毎日作成して学習後に削除する運用を優先している。

そのため、実運用とは一部設定が異なる。

| 項目 | 学習環境 | 実運用での検討 |
| :--- | :--- | :--- |
| Multi-AZ | 無効 | 可用性要件に応じて有効化 |
| Backup Retention | 0日 | 復旧要件に応じて保持期間を設定 |
| Deletion Protection | 無効 | 本番では有効化を検討 |
| KMS Key | AWS管理キー | 顧客管理KMSキーを検討 |
| Password管理 | 環境変数 | Secrets Manager等で管理 |
| Monitoring | 最小限 | CloudWatch、Enhanced Monitoring、Performance Insightsを検討 |
| Audit | 未設定 | CloudTrail、DBログ、GuardDuty RDS Protection等を検討 |

学習では削除しやすさを優先し、本番では保護・監査・復旧を優先する。

