# 19_elasticache_setup.sh 解説

## 概要

`19_elasticache_setup.sh` は、Railsアプリケーションから利用するRedis互換キャッシュ基盤として、Amazon ElastiCache for RedisのReplication Groupを作成するスクリプトである。

今回の構成では、クラスターモード有効のRedisを作成する。

| 項目 | 値 |
| :--- | :--- |
| Replication Group | `sample-elasticache` |
| Engine | `redis` |
| Node Type | `cache.t3.micro` |
| Cluster Mode | 有効 |
| Shards | `2` |
| Replicas per shard | `2` |
| Total Nodes | `6` |
| Port | `6379` |
| Subnet Group | `sample-elasticache-sg` |
| Security Group | `sample-sg-elasticache` |
| At-rest encryption | 有効 |
| Transit encryption | 有効 |

合計ノード数は以下の計算になる。

```text
2 shards * (1 primary + 2 replicas) = 6 nodes
```

この構成は、可用性やシャーディングの学習には向いている。

一方で、6ノード分の課金が発生するため、毎日の自動起動対象に常時入れるより、Redis / ElastiCacheを検証する日にだけ実行する運用が安全である。

## 前提条件

このスクリプトを実行する前に、以下のリソースが作成済みである必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public / Private Subnetを作成する |
| `06_security_group_setup.sh` | Bastion / ELB用Security Groupを作成する |
| `08_Web_server_setup.sh` | Web EC2とWeb用Security Groupを作成する |

ElastiCacheは外部公開せず、Private Subnetに配置する。

そのため、ローカルPCから直接Redisへ接続する構成ではない。

接続確認やRailsアプリからの利用は、VPC内のWeb EC2から行う。

## 作成するリソース

このスクリプトで作成または再利用する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| ElastiCache Replication Group | `sample-elasticache` | Redisクラスタ本体 |
| ElastiCache Subnet Group | `sample-elasticache-sg` | ElastiCacheを配置するPrivate Subnet群 |
| Security Group | `sample-sg-elasticache` | Redisへの接続制御 |
| Security Group Rule | `sample-sg-web` -> `sample-sg-elasticache:6379` | Web EC2からRedis接続を許可 |

`sample-elasticache-sg` の `sg` は、Security GroupではなくSubnet Group名として使っている。

実際のSecurity Group名は `sample-sg-elasticache` である。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、VPC名、Redis設定を定義する
3. LocalStack向け設定を無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `sample-vpc` を1件だけ取得できることを確認する
6. Private Subnetを取得する
7. Private Subnetが2つ以上、かつ2AZ以上に分散していることを確認する
8. Web用Security Group `sample-sg-web` を取得する
9. ElastiCache用Security Group `sample-sg-elasticache` を作成または再利用する
10. Web用Security GroupからRedis 6379/tcpへの接続を許可する
11. ElastiCache Subnet Groupを作成または再利用する
12. ElastiCache Replication Groupを作成または再利用する
13. Replication Groupが `available` になるまで待つ
14. Replication Group、Security Group、Subnet Groupを確認する

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

ElastiCacheは課金対象のリソースであり、作成にも削除にも時間がかかる。

途中の失敗を無視して進めると、Security Groupだけ残る、Subnet Groupだけ残る、古いVPCに紐づいたリソースを再利用してしまう、という問題につながる。

そのため、失敗時点で停止する。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"

REPLICATION_GROUP_ID="sample-elasticache"
REPLICATION_GROUP_DESCRIPTION="Sample Elasticache"
ENGINE="redis"
CACHE_NODE_TYPE="cache.t3.micro"

AT_REST_ENCRYPTION_ENABLED="true"
TRANSIT_ENCRYPTION_ENABLED="true"

NUM_NODE_GROUPS="2"
REPLICAS_PER_NODE_GROUP="2"

CACHE_SUBNET_GROUP_NAME="sample-elasticache-sg"
ELASTICACHE_SG_NAME="sample-sg-elasticache"
WEB_SG_NAME="sample-sg-web"

REDIS_PORT="6379"
```

今回の学習では、クラスターモード有効構成にしている。

`NUM_NODE_GROUPS` はシャード数である。

`REPLICAS_PER_NODE_GROUP` は、各シャードに作成するReplica数である。

## セキュリティ設定

このスクリプトでは、保存時暗号化と転送時暗号化を明示的に有効にしている。

```bash
--at-rest-encryption-enabled
--transit-encryption-enabled
```

| 設定 | 意味 |
| :--- | :--- |
| At-rest encryption | ElastiCache上のデータを保存時に暗号化する |
| Transit encryption | クライアントとRedis間の通信をTLSで暗号化する |

金融系の環境では、通信経路と保存データの暗号化は確認対象になりやすい。

そのため、デフォルト任せにせず、スクリプト内で明示している。

注意点として、転送時暗号化を有効にすると、クライアントはTLS対応で接続する必要がある。

通常の `redis://` ではなく、RailsやSidekiqでは `rediss://` を使う構成になる。

## Security Group

ElastiCache用Security Groupは以下である。

```text
sample-sg-elasticache
```

Redisへの接続は、Web EC2用Security Group `sample-sg-web` からの6379/tcpだけを許可する。

```text
source: sample-sg-web
port  : 6379/tcp
target: sample-sg-elasticache
```

CIDRではなくSecurity Groupを送信元にしている点が重要である。

Web EC2のPrivate IPが作り直しで変わっても、同じSecurity Groupに属していればRedisへ接続できる。

今回の実行結果では、以下のルールが確認できた。

| 項目 | 値 |
| :--- | :--- |
| ElastiCache SG | `sg-0d84f387b787994dc` |
| Source SG | `sg-04b27e29fa108e010` |
| Protocol | `tcp` |
| Port | `6379` |
| Description | `Redis access from web servers` |

## Private Subnet / Subnet Group

ElastiCacheはPrivate Subnetに配置する。

今回の実行では、以下のPrivate Subnetを使った。

| Subnet | 用途 |
| :--- | :--- |
| `subnet-0e089367bc9f0b65c` | ElastiCache配置先 |
| `subnet-065ffee9f544939be` | ElastiCache配置先 |

スクリプトでは、Private Subnetが2つ以上あることに加えて、2つ以上のAvailability Zoneに分散していることも確認する。

```text
Private Subnet Count: 2
Private Subnet AZ Count: 2
```

ElastiCache Subnet Groupは以下である。

```text
sample-elasticache-sg
```

このSubnet Groupによって、ElastiCacheがどのSubnetに配置できるかを指定する。

## Replication Group

Replication Groupは、RedisのPrimary / Replica構成を管理する単位である。

今回のReplication Groupは以下である。

```text
sample-elasticache
```

クラスターモード有効構成のため、Configuration Endpointが発行される。

今回の実行結果では、以下のEndpointが確認できた。

```text
clustercfg.sample-elasticache.0wkp6l.apne1.cache.amazonaws.com
```

PortはRedis標準の6379である。

```text
6379
```

## 実行結果

今回の実行では、Replication Groupは既に作成済みで、状態は `available` だった。

```text
ElastiCache Replication Group already exists: sample-elasticache
Current status: available
```

待機処理では、1回目の確認で `available` になっていることを確認できた。

```text
Wait attempt 1/80: status=available, nodes=6, endpoint=clustercfg.sample-elasticache.0wkp6l.apne1.cache.amazonaws.com
ElastiCache Replication Group is available.
```

Replication Groupの確認結果は以下である。

| 項目 | 値 |
| :--- | :--- |
| ID | `sample-elasticache` |
| Status | `available` |
| ClusterEnabled | `True` |
| AtRestEncryptionEnabled | `True` |
| TransitEncryptionEnabled | `True` |
| ConfigurationEndpoint | `clustercfg.sample-elasticache.0wkp6l.apne1.cache.amazonaws.com` |
| ConfigurationPort | `6379` |

作成されたMember Clusterは以下の6つである。

```text
sample-elasticache-0001-001
sample-elasticache-0001-002
sample-elasticache-0001-003
sample-elasticache-0002-001
sample-elasticache-0002-002
sample-elasticache-0002-003
```

これは、2シャードそれぞれに3ノードが存在することを示している。

```text
0001: primary + replicas
0002: primary + replicas
```

## 再実行耐性

このスクリプトは、再実行しても同じリソースを重複作成しないようにしている。

| 対象 | 再実行時の挙動 |
| :--- | :--- |
| VPC | `sample-vpc` が1件だけであることを確認 |
| Web Security Group | `sample-sg-web` が1件だけであることを確認 |
| ElastiCache Security Group | 既存なら再利用 |
| Redis ingress rule | 既存なら正常扱い |
| ElastiCache Subnet Group | 既存ならVPCを確認して再利用 |
| Subnet Groupの更新 | 変更なしなら正常扱い |
| Replication Group | 既存なら作り直さず状態確認 |

今回の再実行では、以下が確認できた。

```text
ElastiCache Security Group already exists: sg-0d84f387b787994dc
Redis ingress rule already exists.
ElastiCache Subnet Group already exists: sample-elasticache-sg
ElastiCache Subnet Group already has current private subnets.
ElastiCache Replication Group already exists: sample-elasticache
Current status: available
```

## Waiterの注意点

初回作成時、AWS CLI標準のwaiterで以下のエラーが出た。

```text
Waiter ReplicationGroupAvailable failed: Max attempts exceeded
```

これは、必ずしもElastiCacheの作成失敗を意味しない。

6ノード構成では作成に時間がかかり、AWS CLI標準waiterの待機上限を超えることがある。

そのため、スクリプトでは独自の待機処理に変更している。

```bash
ELASTICACHE_WAIT_MAX_ATTEMPTS="80"
ELASTICACHE_WAIT_INTERVAL_SECONDS="30"
```

最大で以下の時間待つ。

```text
80 attempts * 30 seconds = 2400 seconds = 40 minutes
```

待機中は、現在のStatus、ノード数、Configuration Endpointを表示する。

```text
Wait attempt 1/80: status=available, nodes=6, endpoint=...
```

これにより、`creating` のままなのか、ノード数が増えているのか、Endpointが発行されたのかを確認しながら待てる。

## 接続確認

ElastiCacheはPrivate Subnetに配置され、Security GroupもWeb EC2からの接続だけを許可している。

そのため、接続確認はMacからではなくWeb EC2上で行う。

転送時暗号化を有効化しているため、`redis-cli` を使う場合はTLSを指定する。

```bash
redis-cli -c --tls \
  -h clustercfg.sample-elasticache.0wkp6l.apne1.cache.amazonaws.com \
  -p 6379 \
  ping
```

期待値は以下である。

```text
PONG
```

`redis-cli` が入っていない場合は、クライアント導入後に確認する。

TLS接続が前提なので、通常の平文Redis接続では失敗する可能性がある。

## Railsアプリから利用する場合

Railsアプリから利用する場合、接続先はConfiguration Endpointを使う。

転送時暗号化が有効なので、URLスキームは `rediss://` を使う。

例:

```text
rediss://clustercfg.sample-elasticache.0wkp6l.apne1.cache.amazonaws.com:6379/0
```

ただし、今回のElastiCacheはクラスターモード有効である。

Rails Cache Store、Sidekiq、Action Cableなどで利用する場合は、使用しているRedisクライアントやGemがクラスターモードに対応しているか確認する必要がある。

単純な単一Redis前提の設定では、クラスターモード有効Redisと相性が悪い場合がある。

学習目的でRailsとRedisの接続だけを試すなら、以下のような小さい構成も候補になる。

```text
1 shard
1 replica
```

または、クラスターモード無効のReplication Groupを別途用意する方法もある。

今回の `19_elasticache_setup.sh` は、クラスターモード、Multi-AZ、Replica、暗号化、Security Group制御をまとめて学ぶための構成である。

## cleanupとの関係

ElastiCacheは削除漏れが課金につながりやすい。

そのため、`cleanup_network.sh` には以下の削除処理を含めている。

| 対象 | 名前 |
| :--- | :--- |
| ElastiCache Replication Group | `sample-elasticache` |
| ElastiCache Subnet Group | `sample-elasticache-sg` |
| ElastiCache Security Group | `sample-sg-elasticache` |

学習後は以下を実行する。

```bash
./cleanup_network.sh
./check_cleanup.sh
```

削除確認では、以下が残っていないことを見る。

```text
No daily lab ElastiCache Replication Group / Subnet Group
```

ElastiCache Replication Groupの削除にも時間がかかるため、cleanup中に待機が発生する。

## 案件で見るポイント

金融系のAWS環境でElastiCacheを見る場合、以下の観点が重要になる。

| 観点 | 確認内容 |
| :--- | :--- |
| 配置 | Private Subnetに配置されているか |
| 通信制御 | Web/App層のSecurity Groupからのみ6379を許可しているか |
| 暗号化 | 保存時暗号化と転送時暗号化が有効か |
| 可用性 | Multi-AZ / Replica / Automatic Failoverが有効か |
| スケール | Shard数、Replica数、Node Typeが妥当か |
| 接続方式 | アプリ側がTLS接続やクラスターモードに対応しているか |
| 運用 | 削除、再作成、障害時切替、接続先変更の手順があるか |
| コスト | ノード数と利用時間が過剰でないか |

今回のスクリプトでは、暗号化、Private Subnet配置、SG参照による接続制限、Multi-AZ構成を意識している。

## 試験対策としてのポイント

ElastiCacheの試験対策では、以下を押さえる。

| 項目 | ポイント |
| :--- | :--- |
| Subnet Group | ElastiCacheを配置するSubnet群を指定する |
| Security Group | Redisへの入口を制御する |
| Replication Group | Primary / Replica構成を管理する |
| Cluster Mode | データを複数Shardに分散する |
| Configuration Endpoint | クラスターモード有効時に使う接続先 |
| Automatic Failover | ReplicaをPrimaryへ昇格させる仕組み |
| Multi-AZ | 複数AZにノードを配置して可用性を高める |
| Transit encryption | Redis接続にTLSが必要になる |
| At-rest encryption | 保存データを暗号化する |

特に、クラスターモード有効時はPrimary EndpointではなくConfiguration Endpointを使う点が重要である。

## 今回の学び

- ElastiCacheはPrivate Subnetに配置する
- Redisへの接続元はCIDRではなくWeb用Security Groupで制御する
- クラスターモード有効ではConfiguration Endpointが発行される
- 2シャード、各2レプリカでは合計6ノードになる
- 保存時暗号化と転送時暗号化を有効化できる
- 転送時暗号化を有効化すると、クライアント側はTLS接続が必要になる
- AWS CLI標準waiterは、大きめの構成では待機上限に達することがある
- ElastiCacheは課金対象なので、学習後のcleanup確認が重要である

