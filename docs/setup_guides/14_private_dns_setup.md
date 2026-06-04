# 14_private_dns_setup.sh 解説

## 概要

`14_private_dns_setup.sh` は、Route 53のPrivate Hosted Zoneを作成し、VPC内だけで使う内部DNS名を登録するスクリプトである。

作成するPrivate Hosted Zoneは `home.` である。

作成または更新するDNSレコードは以下である。

| レコード | 種別 | 参照先 |
| :--- | :--- | :--- |
| bastion.home | A Record | Bastion EC2のPrivate IP |
| web01.home | A Record | Web01 EC2のPrivate IP |
| web02.home | A Record | Web02 EC2のPrivate IP |
| db.home | CNAME Record | RDS Endpoint |

Public DNSの `bastion.nobu-iac-lab.com` や `www.nobu-iac-lab.com` はインターネット側から名前解決される。

一方、Private DNSの `web01.home` や `db.home` は、Private Hosted Zoneを関連付けたVPC内からだけ名前解決される。

この手順により、EC2やRDSのIPアドレス、RDS Endpointを直接覚えなくても、VPC内では固定の内部名でアクセスできるようになる。

## 前提条件

このスクリプトを実行する前に、以下のリソースが作成済みである必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public / Private Subnetを作成する |
| `07_bastion_server_setup.sh` | Bastion EC2を作成する |
| `08_Web_server_setup.sh` | Web01 / Web02 EC2を作成する |
| `10_Database_setup.sh` | RDS MySQL `sample-db` を作成する |

Private Hosted ZoneはVPCに関連付けて使うため、対象VPCのDNS属性も有効である必要がある。

| VPC DNS属性 | 必要な状態 |
| :--- | :--- |
| enableDnsSupport | True |
| enableDnsHostnames | True |

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、Private Hosted Zone名、対象リソース名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `sample-vpc` が1件だけ存在することを確認し、VPC IDを取得する
6. VPCのDNS属性 `enableDnsSupport` / `enableDnsHostnames` を確認する
7. `home.` のPrivate Hosted Zoneを作成または再利用する
8. 既存の `home.` がある場合、現在のVPCに関連付いているか確認する
9. Bastion / Web01 / Web02のPrivate IPを取得する
10. RDS `sample-db` が `available` で、同じVPC内かつ非公開であることを確認する
11. RDS Endpointを取得する
12. Route 53へPrivate DNSレコードをUPSERTする
13. Route 53の変更が `INSYNC` になるまで待機する
14. 作成または更新したPrivate DNSレコードを確認する

## Bashの安全設定

```bash
#!/bin/bash
set -euo pipefail
```

| 設定 | 意味 |
| :--- | :--- |
| `-e` | コマンドが失敗した時点でスクリプトを終了する |
| `-u` | 未定義の変数を使った場合にエラーにする |
| `-o pipefail` | パイプ処理の途中で失敗した場合もエラーとして扱う |

DNSは接続先を決める設定である。

誤ったIPやRDS Endpointを登録すると、通信不可、別環境への接続、調査時の混乱につながるため、前提確認で失敗したら止める。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"

PRIVATE_ZONE_NAME="home"
PRIVATE_ZONE_NAME_DOT="${PRIVATE_ZONE_NAME}."

BASTION_INSTANCE_NAME="sample-ec2-bastion"
WEB01_INSTANCE_NAME="sample-ec2-web01"
WEB02_INSTANCE_NAME="sample-ec2-web02"
DB_INSTANCE_IDENTIFIER="sample-db"

BASTION_RECORD_NAME="bastion"
WEB01_RECORD_NAME="web01"
WEB02_RECORD_NAME="web02"
DB_RECORD_NAME="db"

TTL="300"
```

`PRIVATE_ZONE_NAME_DOT` は、Route 53のHosted Zone名が末尾`.`付きで返るために使う。

```text
home.
```

Route 53上のDNSレコードも、内部的には末尾`.`付きのFQDNとして扱われる。

## Private Hosted Zoneとは

Private Hosted Zoneは、指定したVPC内だけで有効なRoute 53のDNSゾーンである。

今回の `home.` はインターネット上に公開されない。

| 種別 | 名前解決できる場所 | 用途 |
| :--- | :--- | :--- |
| Public Hosted Zone | インターネット側 | `www.nobu-iac-lab.com`、`bastion.nobu-iac-lab.com` |
| Private Hosted Zone | 関連付けたVPC内だけ | `web01.home`、`db.home` |

Private Hosted Zoneは、内部通信の向き先を分かりやすくするために使う。

例えば、RailsアプリのDB接続先をRDS Endpointの長い名前ではなく、`db.home` にできる。

```text
sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
  ↓
db.home
```

RDSを作り直してEndpointが変わっても、`db.home` のCNAMEを更新すれば、アプリ側の設定を固定しやすくなる。

## VPC IDでの絞り込み

このスクリプトでは、EC2をNameタグだけで取得しない。

まず `sample-vpc` が1件だけ存在することを確認し、そのVPC IDを使って後続のEC2を絞り込む。

```bash
aws ec2 describe-instances   --filters     Name=vpc-id,Values="$VPC_ID"     Name=tag:Name,Values="$instance_name"     Name=instance-state-name,Values=running
```

同じNameタグのEC2が古いVPCに残っている場合、Nameタグだけでは誤ったPrivate IPをPrivate DNSへ登録する可能性がある。

今回のラボでは日次で作成・削除を行うため、残存リソース対策としてVPC IDでの絞り込みが重要になる。

## VPC DNS属性の確認

Private Hosted Zoneを使うには、VPC側のDNS属性が有効である必要がある。

スクリプトでは以下を確認する。

```bash
aws ec2 describe-vpc-attribute   --vpc-id "$VPC_ID"   --attribute enableDnsSupport

aws ec2 describe-vpc-attribute   --vpc-id "$VPC_ID"   --attribute enableDnsHostnames
```

今回の実行結果では、どちらも有効だった。

```text
enableDnsSupport: True
enableDnsHostnames: True
```

| 属性 | 意味 |
| :--- | :--- |
| enableDnsSupport | VPC内でAmazonProvidedDNSによる名前解決を使えるようにする |
| enableDnsHostnames | VPC内リソースにDNSホスト名を割り当てられるようにする |

Private Hosted Zoneの名前解決で特に重要なのは `enableDnsSupport` である。

`enableDnsHostnames` も、EC2やRDSのDNS名を扱う構成では有効にしておくのが基本である。

## Private Hosted Zoneの作成または再利用

スクリプトはまず、現在のVPCに `home.` のPrivate Hosted Zoneが関連付いているか確認する。

```bash
aws route53 list-hosted-zones-by-vpc   --vpc-id "$VPC_ID"   --vpc-region "$REGION"
```

処理の考え方は以下である。

| 状態 | 処理 |
| :--- | :--- |
| 現在のVPCに `home.` が1件関連付いている | そのPrivate Hosted Zoneを再利用する |
| 現在のVPCに `home.` がないが、アカウント内に1件だけ存在する | 現在のVPCへ関連付ける |
| `home.` が存在しない | 新規作成して現在のVPCへ関連付ける |
| `home.` が複数存在する | 誤作業防止のため停止する |

今回の実行では、`home.` は存在していなかったため新規作成された。

```text
Private Hosted Zone not found. Creating: home
Private Hosted Zone created: /hostedzone/Z06392831NMJBUOJ86QIO
Private Hosted Zone ID: Z06392831NMJBUOJ86QIO
```

## EC2 Private IPの取得

Private DNSに登録するため、以下3台のPrivate IPを取得する。

| EC2 | DNS名 | 登録値 |
| :--- | :--- | :--- |
| sample-ec2-bastion | bastion.home | BastionのPrivate IP |
| sample-ec2-web01 | web01.home | Web01のPrivate IP |
| sample-ec2-web02 | web02.home | Web02のPrivate IP |

今回の実行結果は以下である。

```text
Bastion Private IP: 10.0.15.188
Web01 Private IP: 10.0.65.29
Web02 Private IP: 10.0.83.211
```

Public DNSではBastionのPublic IPを登録したが、Private DNSではBastionのPrivate IPを登録している。

VPC内のEC2からBastionへ内部通信したい場合は `bastion.home` を使える。

ただし、MacなどVPC外の端末から `bastion.home` は名前解決できない。

## RDS Endpointの取得

`db.home` はRDS EndpointへのCNAMEとして作成する。

スクリプトでは、Endpointを取得する前に以下を確認する。

| 確認項目 | 期待値 |
| :--- | :--- |
| DB Status | available |
| RDS VPC ID | `sample-vpc` のVPC IDと一致 |
| PubliclyAccessible | False |

今回の実行結果は以下である。

```text
RDS Status: available
RDS VPC ID: vpc-0127f31bb241c01b0
RDS PubliclyAccessible: False
RDS Endpoint: sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

RDSはIPアドレスではなくEndpointで接続する。

そのため、Private DNSではAレコードではなくCNAMEレコードを使う。

```text
db.home CNAME sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

## UPSERTによる再実行耐性

Private DNSレコード作成では `UPSERT` を使う。

```json
{
  "Action": "UPSERT",
  "ResourceRecordSet": {
    "Name": "web01.home.",
    "Type": "A",
    "TTL": 300,
    "ResourceRecords": [
      {
        "Value": "10.0.65.29"
      }
    ]
  }
}
```

`UPSERT` は、レコードが存在しなければ作成し、既に存在すれば更新する指定である。

| 状態 | UPSERTの動き |
| :--- | :--- |
| レコードがない | 新規作成する |
| レコードがあるが値が同じ | 実質的に変更なし |
| レコードがあり値が違う | 新しい値に更新する |

日次でEC2やRDSを作り直すと、Private IPやRDS Endpointが変わることがある。

その場合でも、このスクリプトを再実行すれば `web01.home` や `db.home` の向き先を現在の環境に更新できる。

## 作成されたPrivate DNSレコード

今回作成されたレコードは以下である。

| レコード | 種別 | 値 |
| :--- | :--- | :--- |
| bastion.home | A | 10.0.15.188 |
| web01.home | A | 10.0.65.29 |
| web02.home | A | 10.0.83.211 |
| db.home | CNAME | sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com |

Route 53上では末尾`.`付きで表示される。

```text
bastion.home.
web01.home.
web02.home.
db.home.
```

## 動作確認

Private DNSはVPC内だけで名前解決できる。

そのため、確認はWeb EC2やBastion EC2にSSHして実行する。

```bash
dig web01.home
dig web02.home
dig db.home
```

`dig` が入っていない場合は、`getent hosts` でも確認できる。

```bash
getent hosts web01.home
getent hosts db.home
```

RDS接続確認は、Web EC2から以下のように実行できる。

```bash
mariadb -h db.home -P 3306 -u adminuser -p
```

接続後、MySQL側で確認する。

```sql
select version();
show databases;
```

`db.home` で接続できれば、Private Hosted ZoneのCNAMEがRDS Endpointへ解決され、Web EC2からRDSへSecurity Group経由で到達できていることを確認できる。

## Public DNSとの違い

今回のDNSは、Public DNSとPrivate DNSを明確に分けている。

| 用途 | DNS名 | 名前解決できる場所 | 向き先 |
| :--- | :--- | :--- | :--- |
| SSH入口 | bastion.nobu-iac-lab.com | インターネット側 | Bastion Public IP |
| Web公開 | www.nobu-iac-lab.com | インターネット側 | ALB |
| 内部Web01 | web01.home | VPC内 | Web01 Private IP |
| 内部Web02 | web02.home | VPC内 | Web02 Private IP |
| 内部DB | db.home | VPC内 | RDS Endpoint |

BastionへのSSHはPublic DNSを使う。

```bash
ssh -i /Users/nobu/aws-reference/scripts/nobu.pem ec2-user@bastion.nobu-iac-lab.com
```

Web EC2やRDSへの内部通信はPrivate DNSを使う。

```bash
ssh awsref-web01
mariadb -h db.home -P 3306 -u adminuser -p
```

## クリーンアップ時の注意

Private Hosted ZoneはVPCに関連付くリソースである。

そのため、日次削除では以下を整理する必要がある。

1. `home.` 内の一時レコードを削除する
2. Private Hosted Zoneが複数VPCに関連付いている場合は、対象VPCとの関連付けを解除する
3. 日次ラボ専用のPrivate Hosted ZoneであればHosted Zone自体を削除する

今回、cleanup側では `home.` のレコード削除、VPC関連付け確認、Hosted Zone削除まで扱うようにした。

Private Hosted Zoneに残るデフォルトの `NS` / `SOA` レコードは削除しない。

Route 53のHosted Zone削除時には、カスタムレコードが残っていると `HostedZoneNotEmpty` で失敗する。

## 案件対策としてのポイント

この手順は、銀行案件の「AWSセキュリティ・ネットワーク最適化・改善」「影響調査や設定変更、手順書作成」とかなり相性が良い。

特に重要な観点は以下である。

| 観点 | 内容 |
| :--- | :--- |
| 影響調査 | Private Hosted ZoneがどのVPCに関連付いているか確認する |
| 誤作業防止 | NameだけでなくVPC IDで対象リソースを絞り込む |
| セキュリティ | RDSが `PubliclyAccessible=False` であることを確認する |
| 接続性 | `db.home` がRDS Endpointへ解決されるか確認する |
| 変更管理 | UPSERT後にRoute 53 Change IDとINSYNCを確認する |
| 残存リソース対策 | 古いPrivate Hosted Zoneや別VPC関連付けを確認する |
| 手順書化 | 実行前提、変更内容、確認コマンド、戻し方を残す |

実務では、DNS変更は小さく見えて影響範囲が広い。

例えば `db.home` の向き先を誤ると、アプリケーションがDBへ接続できなくなったり、別環境のDBへ接続する事故につながる。

そのため、以下の順で確認するのが安全である。

1. 変更対象のHosted Zoneを確認する
2. Public / Privateを確認する
3. 関連付けVPCを確認する
4. 変更前のレコード値を記録する
5. 変更後のレコード値を確認する
6. VPC内のEC2から名前解決と接続確認を行う
7. ロールバック方法を用意する

## 試験対策としてのポイント

AWS Advanced NetworkingやSolutions Architectの観点では、以下を押さえる。

- Private Hosted Zoneは、関連付けたVPC内でのみ有効である
- 同じドメイン名でもPublic Hosted ZoneとPrivate Hosted Zoneは別物である
- VPCのDNS属性が無効だと、VPC内の名前解決に影響する
- RDSはIP固定ではなくEndpointで接続する
- ALBはPublic DNSではAlias A、RDS EndpointはPrivate DNSではCNAMEが自然である
- Route 53の変更はChange IDを持ち、`INSYNC` まで待つことができる
- 名前解決できても、Security GroupやRoute Tableが通っていないと通信は成功しない

## 実行結果

今回の実行結果の要点は以下である。

| 項目 | 値 |
| :--- | :--- |
| AWS Account | 445405559057 |
| IAM User | arn:aws:iam::445405559057:user/nobu |
| VPC ID | vpc-0127f31bb241c01b0 |
| enableDnsSupport | True |
| enableDnsHostnames | True |
| Private Hosted Zone | home. |
| Private Hosted Zone ID | Z06392831NMJBUOJ86QIO |
| Bastion Private IP | 10.0.15.188 |
| Web01 Private IP | 10.0.65.29 |
| Web02 Private IP | 10.0.83.211 |
| RDS Status | available |
| RDS PubliclyAccessible | False |
| RDS Endpoint | sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com |

作成されたPrivate DNSレコードは以下である。

```text
bastion.home. A     10.0.15.188
web01.home.   A     10.0.65.29
web02.home.   A     10.0.83.211
db.home.      CNAME sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

## 次に確認すること

次は、VPC内のEC2からPrivate DNSが引けることを確認する。

```bash
ssh awsref-web01
getent hosts web01.home
getent hosts web02.home
getent hosts db.home
mariadb -h db.home -P 3306 -u adminuser -p
```

その後、Railsアプリ側のDB接続先を `db.home` にしておくと、RDS Endpointが変わってもPrivate DNS側の更新で吸収しやすくなる。
