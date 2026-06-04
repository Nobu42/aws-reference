# 12_public_dns_setup.sh 解説

## 概要

`12_public_dns_setup.sh` は、Route 53のPublic Hosted Zoneに公開DNSレコードを作成または更新するスクリプトである。

作成するレコードは以下の2つである。

| レコード | 種別 | 参照先 |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com | A Record | Bastion EC2のPublic IP |
| www.nobu-iac-lab.com | A Alias Record | Application Load Balancer |

この手順により、IPアドレスやALBのAWS管理DNS名を直接使わず、独自ドメイン名でアクセスできるようにする。

日次でEC2やALBを作り直す運用では、BastionのPublic IPやALB DNS名が変わるため、Route 53レコードも更新が必要になる。

このスクリプトでは `UPSERT` を使い、レコードがなければ作成し、既にあれば更新する。

## 前提条件

このスクリプトを実行する前に、以下のリソースが存在している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `07_bastion_server_setup.sh` | Bastion EC2を作成する |
| `09_LoadBalancer_setup.sh` | ALB `sample-elb` を作成する |
| Route 53 | `nobu-iac-lab.com` のPublic Hosted Zoneが作成済みであること |

Public Hosted Zoneは毎日削除する対象ではなく、ドメイン管理用の永続リソースとして残す。

このスクリプトで作成する `bastion` と `www` のDNSレコードは、日次ラボ環境に紐づく一時レコードである。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、ドメイン名、対象リソース名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. `nobu-iac-lab.com` のPublic Hosted Zoneが1件だけ存在することを確認する
6. `sample-vpc` のVPC IDを取得する
7. VPC IDで絞り込み、running状態のBastion EC2を1台だけ取得する
8. Bastion EC2のPublic IPを取得する
9. ALB `sample-elb` を取得する
10. ALBが `sample-vpc` に属していることを確認する
11. ALBが `application / internet-facing` であることを確認する
12. ALBのDNS名とCanonical Hosted Zone IDを取得する
13. Route 53へ `bastion` と `www` のレコードをUPSERTする
14. Route 53の変更が `INSYNC` になるまで待機する
15. 作成または更新したDNSレコードを確認する

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

DNSは公開先を決める設定である。

誤ったIPやALBへ向けると、接続不可や想定外環境への誘導につながるため、前提リソースの確認で失敗したら止める。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

DOMAIN_NAME="nobu-iac-lab.com"
DOMAIN_NAME_DOT="${DOMAIN_NAME}."

VPC_NAME="sample-vpc"
BASTION_INSTANCE_NAME="sample-ec2-bastion"
ALB_NAME="sample-elb"

BASTION_RECORD_NAME="bastion"
ALB_RECORD_NAME="www"

BASTION_TTL="300"
```

`DOMAIN_NAME_DOT` は、Route 53のHosted Zone名が末尾`.`付きで返るために使う。

```text
nobu-iac-lab.com.
```

DNSレコード名もRoute 53上では末尾`.`付きのFQDNとして扱われる。

## Public Hosted Zoneの取得

Public Hosted Zoneを取得する。

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`]"
```

ポイントは、`Config.PrivateZone==false` でPublic Hosted Zoneだけに絞り込むことである。

同じドメイン名でPrivate Hosted Zoneが存在する場合もあるため、Public / Privateを明確に分ける。

検索結果が0件または2件以上の場合は停止する。

| 件数 | 処理 |
| :--- | :--- |
| 0件 | Public Hosted Zoneがないため停止 |
| 1件 | そのHosted Zoneを使用 |
| 2件以上 | 誤作業防止のため停止 |

## VPC IDでの絞り込み

このスクリプトでは、Bastion EC2をNameタグだけで取得しない。

まず `sample-vpc` のVPC IDを取得し、そのVPC IDでBastionを絞り込む。

```bash
aws ec2 describe-instances \
  --filters \
    Name=vpc-id,Values="$VPC_ID" \
    Name=tag:Name,Values="$BASTION_INSTANCE_NAME" \
    Name=instance-state-name,Values=running
```

同じNameタグのEC2が別VPCに存在した場合、Nameタグだけでは誤ったPublic IPをDNSへ登録する可能性がある。

VPC IDで絞り込むことで、今回の学習用VPCに属するBastionだけを対象にする。

## Bastion Aレコード

Bastion用レコードは通常のAレコードである。

```json
{
  "Name": "bastion.nobu-iac-lab.com.",
  "Type": "A",
  "TTL": 300,
  "ResourceRecords": [
    {
      "Value": "Bastion Public IP"
    }
  ]
}
```

Bastion EC2にはPublic IPが付いているため、そのIPアドレスをAレコードに登録する。

TTLは300秒にしている。

理由は、EC2を作り直すとPublic IPが変わるためである。

| TTL | 特徴 |
| :--- | :--- |
| 短い | 変更反映が早いがDNS問い合わせが増える |
| 長い | DNS問い合わせは減るが、IP変更時に古い値が残りやすい |

学習環境では日次で作り直すため、300秒程度にしておくと扱いやすい。

## ALB Alias Aレコード

Web用レコード `www.nobu-iac-lab.com` は、ALBへのAlias Aレコードである。

```json
{
  "Name": "www.nobu-iac-lab.com.",
  "Type": "A",
  "AliasTarget": {
    "HostedZoneId": "ALB Canonical Hosted Zone ID",
    "DNSName": "ALB DNS Name",
    "EvaluateTargetHealth": false
  }
}
```

ALBは固定IPではなく、AWS管理のDNS名を持つ。

そのため、ALBへ向ける場合は、通常のAレコードにIPを入れるのではなく、Route 53のAliasレコードを使う。

Aliasレコード作成には以下が必要である。

| 値 | 用途 |
| :--- | :--- |
| ALB DNS Name | ALBの向き先DNS名 |
| Canonical Hosted Zone ID | ALBのHosted Zone ID |

取得コマンド:

```bash
aws elbv2 describe-load-balancers \
  --names sample-elb \
  --query 'LoadBalancers[0].{DNSName:DNSName,CanonicalHostedZoneId:CanonicalHostedZoneId}'
```

## ALBの確認

スクリプトでは、ALBが想定したVPCにあることを確認する。

```bash
if [ "$ALB_VPC_ID" != "$VPC_ID" ]; then
  echo "Error: ALB is in unexpected VPC."
  exit 1
fi
```

また、ALBの種類と公開方式も確認する。

| 項目 | 期待値 |
| :--- | :--- |
| Type | application |
| Scheme | internet-facing |

`www.nobu-iac-lab.com` はインターネットからアクセスする公開Web用レコードである。

そのため、ALBは `internet-facing` である必要がある。

## UPSERTの意味

Route 53の `UPSERT` は、レコードがなければ作成し、既にあれば更新するアクションである。

```text
UPSERT = CREATE + UPDATE
```

今回のように、毎日EC2やALBを作り直す環境では、値が変わる。

| 対象 | 変わる可能性 |
| :--- | :--- |
| Bastion Public IP | EC2再作成で変わる |
| ALB DNS Name | ALB再作成で変わる |
| ALB Canonical Hosted Zone ID | リージョンやLB種別に依存する |

`CREATE` だけだと、2回目の実行時に「レコードが既に存在する」というエラーになる。

`UPSERT` なら、同じスクリプトを再実行するだけで現在の値へ更新できる。

これが「DNSレコードはUPSERTなので再実行耐性がある」という意味である。

## Route 53変更の待機

Route 53の変更は即時に `INSYNC` になるとは限らない。

そのため、以下で変更反映を待つ。

```bash
aws route53 wait resource-record-sets-changed \
  --profile "$PROFILE" \
  --id "$CHANGE_ID"
```

`INSYNC` は、Route 53側で変更が反映された状態を示す。

ただし、クライアントやDNSキャッシュの都合で、手元からの名前解決結果がすぐ変わらない場合もある。

## 実行結果の確認

スクリプトの最後に、作成または更新したレコードを確認する。

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --query "ResourceRecordSets[?Name==\`bastion.nobu-iac-lab.com.\` || Name==\`www.nobu-iac-lab.com.\`]" \
  --output table
```

期待するレコード:

| Name | Type | Value |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com. | A | Bastion Public IP |
| www.nobu-iac-lab.com. | A Alias | sample-elb |

## 動作確認

Mac側から名前解決を確認する。

```bash
dig bastion.nobu-iac-lab.com
dig www.nobu-iac-lab.com
```

または短く確認する。

```bash
dig +short bastion.nobu-iac-lab.com
dig +short www.nobu-iac-lab.com
```

BastionへSSHする場合:

```bash
ssh -i /Users/nobu/aws-reference/scripts/nobu.pem ec2-user@bastion.nobu-iac-lab.com
```

`~/.ssh/config` を使う場合は、`HostName` をDNS名にしておくと、Bastion再作成でPublic IPが変わってもDNS更新だけで接続先を追従できる。

WebへHTTPアクセスする場合:

```bash
curl -I http://www.nobu-iac-lab.com
```

ブラウザで確認する場合:

```text
http://www.nobu-iac-lab.com
```

後続のACM / HTTPS Listener設定後は、以下でアクセスする。

```text
https://www.nobu-iac-lab.com
```

## 再実行耐性

このスクリプトは、同じDNSレコードに対して `UPSERT` を使う。

そのため、以下のような再実行に対応できる。

| 状況 | 動作 |
| :--- | :--- |
| 初回実行 | レコードを作成する |
| Bastion Public IPが変わった | Aレコードを新IPへ更新する |
| ALBを作り直した | Alias先を新ALBへ更新する |
| 既に同じ値だった | 同じ値で更新し、正常終了する |

ただし、以下の場合は停止する。

| 状況 | 停止理由 |
| :--- | :--- |
| Public Hosted Zoneがない | DNSレコードを作成できない |
| Public Hosted Zoneが複数ある | 誤ったHosted Zoneを更新する危険がある |
| 同名VPCが複数ある | 誤ったVPCを参照する危険がある |
| Bastionが0台または複数台running | 誤ったPublic IPを登録する危険がある |
| ALBが別VPCにある | 想定外のALBへ公開DNSを向ける危険がある |
| ALBがinternet-facingでない | Public DNSの向き先として不適切 |

## 削除時の注意

Public Hosted Zone自体はドメイン管理用の永続リソースとして残す。

一方で、以下のレコードは日次ラボ環境に紐づく一時レコードである。

- `bastion.nobu-iac-lab.com`
- `www.nobu-iac-lab.com`

ALBやBastionを削除した後にこれらのレコードが残ると、存在しないリソースや古いIPを指す状態になる。

現在の `check_cleanup.sh` では、これらを「Public DNS temporary records」として確認対象にしている。

日次削除運用に12番を正式に含める場合は、`cleanup_network.sh` または別のcleanupスクリプトで、`bastion` と `www` のレコード削除を追加する。

## 案件対策としての見どころ

DNS設定変更は、影響範囲が広い作業である。

案件対策として説明しやすいポイントは以下である。

| 観点 | 説明ポイント |
| :--- | :--- |
| 公開経路 | `www` はALBへ向け、Web EC2へ直接向けない |
| 運用入口 | `bastion` はBastion Public IPへ向ける |
| 再実行耐性 | UPSERTにより作成済みレコードも更新できる |
| 誤操作防止 | Hosted Zone、VPC、Bastion、ALBを事前確認する |
| 影響調査 | TTL、DNSキャッシュ、既存レコード、向き先変更を確認する |
| 切り戻し | 変更前のRecordSetを控えておき、元の値へUPSERTする |
| セキュリティ | Public DNSで公開する対象をALBとBastionに限定する |

DNS変更時は、以下を確認する習慣が重要である。

- どのHosted Zoneを更新するか
- Public Hosted ZoneかPrivate Hosted Zoneか
- レコード名の末尾`.`を含めたFQDNは正しいか
- AレコードかAliasレコードか
- TTLはいくつか
- 変更前の値は何か
- 変更後に名前解決と疎通確認をしたか

## 実運用との差分

この学習環境では、BastionへPublic DNS名を付けている。

実運用では、以下のような検討が必要になる。

| 項目 | 学習環境 | 実運用での検討 |
| :--- | :--- | :--- |
| Bastion公開 | Public IP + DNS | SSM Session Manager、VPN、踏み台制限 |
| Web公開 | HTTPのALB Alias | HTTPS Listener、WAF、CloudFront |
| TTL | 300秒 | 切替方式や運用要件に合わせる |
| DNS変更 | 手動スクリプト | 変更申請、レビュー、作業証跡 |
| 監査 | 最小限 | CloudTrail、Route 53 Resolver Query Logs等 |

銀行系では、DNS変更も「設定変更」の一部として扱われる。

作業前後のレコード値、影響範囲、切り戻し手順、疎通確認を明確にしておくことが重要である。

