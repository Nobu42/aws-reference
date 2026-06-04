# 15_acm_certificate_setup.sh 解説

## 概要

`15_acm_certificate_setup.sh` は、Application Load BalancerにHTTPS Listenerを追加するためのスクリプトである。

このスクリプトでは、ACM証明書を作成または再利用し、Route 53にDNS検証用CNAMEを作成し、ALBの443番Listenerへ証明書を設定する。

今回の対象ドメインは以下である。

| 項目 | 値 |
| :--- | :--- |
| ドメイン | `nobu-iac-lab.com` |
| 証明書対象 | `www.nobu-iac-lab.com` |
| Public Hosted Zone | `nobu-iac-lab.com.` |
| ALB | `sample-elb` |
| Target Group | `sample-tg` |
| Listener | HTTPS:443 |
| TLS Security Policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` |

この手順により、HTTPだけでなくHTTPSでも以下のURLへアクセスできるようになる。

```text
https://www.nobu-iac-lab.com
```

## 前提条件

このスクリプトを実行する前に、以下のリソースが作成済みである必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `06_security_group_setup.sh` | ELB用Security Groupで443番を許可する |
| `08_Web_server_setup.sh` | Web EC2を作成する |
| `09_LoadBalancer_setup.sh` | ALB `sample-elb` とTarget Group `sample-tg` を作成する |
| `12_public_dns_setup.sh` | `www.nobu-iac-lab.com` をALBへ向ける |

特に重要なのは、ALBとTarget Groupが現在の `sample-vpc` に属していることである。

古いVPCに紐づいたALBやTarget Groupが残っていると、HTTPS Listenerを誤った環境へ設定してしまう可能性がある。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、ドメイン名、ALB名、Target Group名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. Public Hosted Zone `nobu-iac-lab.com.` を取得する
6. `sample-vpc` のVPC IDを取得する
7. ACM証明書を検索する
8. 既存の `ISSUED` 証明書があれば再利用する
9. `ISSUED` がなければ `PENDING_VALIDATION` の証明書を再利用する
10. 証明書がなければDNS検証方式で新規リクエストする
11. ACMのDNS検証用CNAMEを取得する
12. DNS検証用CNAMEをRoute 53にUPSERTする
13. Route 53の変更が `INSYNC` になるまで待つ
14. ACM証明書が `ISSUED` になるまで待つ
15. ALB `sample-elb` を取得し、VPC / Type / Schemeを確認する
16. Target Group `sample-tg` を取得し、VPC / Protocol / Portを確認する
17. HTTPS:443 Listenerを作成または更新する
18. HTTPS ListenerとACM証明書の状態を確認する

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

証明書、DNS、ALB Listenerは公開経路に関わる設定である。

途中のエラーを無視して進むと、HTTPS接続不可、別Target Groupへの転送、古いALBへの設定といった問題につながるため、失敗時点で停止する。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

DOMAIN_NAME="nobu-iac-lab.com"
CERT_DOMAIN_NAME="www.${DOMAIN_NAME}"
PUBLIC_HOSTED_ZONE_NAME="${DOMAIN_NAME}."
VPC_NAME="sample-vpc"

ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"
TARGET_GROUP_PORT="3000"

HTTPS_PORT="443"
HTTPS_PROTOCOL="HTTPS"

SSL_POLICY="ELBSecurityPolicy-TLS13-1-2-2021-06"
```

今回のACM証明書は `www.nobu-iac-lab.com` 用である。

ALBのHTTPS Listenerは443番で受け、Default actionとしてTarget Group `sample-tg` へforwardする。

## TLS Security Policy

HTTPS Listenerでは、TLS Security Policyを明示している。

```bash
SSL_POLICY="ELBSecurityPolicy-TLS13-1-2-2021-06"
```

このポリシーはTLS 1.3とTLS 1.2を許可し、TLS 1.1とTLS 1.0を許可しない。

| プロトコル | 許可 |
| :--- | :--- |
| TLS 1.3 | Yes |
| TLS 1.2 | Yes |
| TLS 1.1 | No |
| TLS 1.0 | No |

金融系のセキュリティ改善作業では、TLSバージョンや暗号スイートの扱いが確認対象になりやすい。

そのため、AWS CLIやELBv2のデフォルト任せにせず、スクリプト内で明示している。

## Public Hosted Zoneの確認

DNS検証用CNAMEを登録するため、Public Hosted Zoneを取得する。

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name "$PUBLIC_HOSTED_ZONE_NAME" \
  --query "HostedZones[?Name==\`$PUBLIC_HOSTED_ZONE_NAME\` && Config.PrivateZone==\`false\`]"
```

ポイントは、`Config.PrivateZone==false` でPublic Hosted Zoneだけを対象にしていることである。

同じドメイン名でPrivate Hosted Zoneが存在する場合もあるため、Public / Privateを明確に区別する。

今回の実行結果では、以下のHosted Zoneを使用した。

```text
Hosted Zone ID: Z02886402CZFSQE5OSSQ
```

## VPC IDの確認

ALBとTarget Groupが現在の学習用VPCに属していることを確認するため、`sample-vpc` のVPC IDを取得する。

```text
VPC: vpc-0c78f8870606de8ce
```

このVPC IDは、後続のALB確認とTarget Group確認で使う。

NameだけでALBやTarget Groupを扱うと、古いVPCに残った同名リソースを誤って参照する可能性がある。

今回のような日次作成・削除のラボでは、VPC IDでの確認が重要である。

## ACM証明書の再利用

スクリプトは、まず `www.nobu-iac-lab.com` の既存ACM証明書を探す。

優先順位は以下である。

| 優先順位 | 状態 | 処理 |
| :--- | :--- | :--- |
| 1 | `ISSUED` | 発行済み証明書として再利用 |
| 2 | `PENDING_VALIDATION` | 検証待ち証明書として再利用 |
| 3 | なし | 新規リクエスト |

同じドメインの証明書が複数ある場合は、誤った証明書をALBに設定しないため停止する。

今回の実行では、既存の発行済み証明書を再利用した。

```text
Existing ACM Certificate found:
arn:aws:acm:ap-northeast-1:445405559057:certificate/331011aa-f281-4599-b3a1-c8545805208b
```

## DNS検証レコード

ACMのDNS検証では、Route 53にCNAMEレコードを作成する。

今回の検証レコードは以下である。

| 項目 | 値 |
| :--- | :--- |
| Record Name | `_c497f1fd492da2931acd977e27407b46.www.nobu-iac-lab.com.` |
| Record Value | `_d3ac093a285825893feeb535f873d85e.jkddzztszm.acm-validations.aws.` |
| Type | CNAME |
| TTL | 300 |

スクリプトでは、このCNAMEをRoute 53に `UPSERT` する。

```json
{
  "Action": "UPSERT",
  "ResourceRecordSet": {
    "Name": "ACM Validation Record Name",
    "Type": "CNAME",
    "TTL": 300,
    "ResourceRecords": [
      {
        "Value": "ACM Validation Record Value"
      }
    ]
  }
}
```

`UPSERT` は、レコードがなければ作成し、既に存在すれば更新する指定である。

ACMのDNS検証CNAMEは、証明書更新時にも使われるため、日次cleanupでは消さずに残す運用でよい。

## ACM証明書の発行待ち

Route 53の変更が `INSYNC` になった後、ACM証明書が `ISSUED` になるまで待つ。

```bash
aws acm wait certificate-validated \
  --certificate-arn "$CERT_ARN"
```

今回の実行では、既存証明書が既に `ISSUED` だったため、すぐに完了した。

```text
ACM Certificate is ISSUED.
```

## ALBの確認

HTTPS Listenerを追加するALB `sample-elb` を取得する。

今回の実行結果は以下である。

```text
ALB ARN:
arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/6541a59d3446f47f

ALB VPC:
vpc-0c78f8870606de8ce

ALB Type/Scheme:
application / internet-facing
```

スクリプトでは、ALBが以下を満たすことを確認する。

| 項目 | 期待値 |
| :--- | :--- |
| VPC | `sample-vpc` のVPC ID |
| Type | `application` |
| Scheme | `internet-facing` |

ALBが別VPCにある場合や、想定と異なる種類の場合は停止する。

## Target Groupの確認

HTTPS ListenerのDefault actionでforwardするTarget Group `sample-tg` を取得する。

今回の実行結果は以下である。

```text
Target Group ARN:
arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/b96dec0044d356ec

Target Group VPC:
vpc-0c78f8870606de8ce

Target Group Protocol/Port:
HTTP:3000
```

スクリプトでは、Target Groupが以下を満たすことを確認する。

| 項目 | 期待値 |
| :--- | :--- |
| VPC | `sample-vpc` のVPC ID |
| Protocol | HTTP |
| Port | 3000 |

ALBでHTTPSを終端し、ALBからWeb EC2へのバックエンド通信はHTTP:3000で行う構成である。

```text
Client
  |
  | HTTPS:443
  v
ALB
  |
  | HTTP:3000
  v
Web EC2
```

## HTTPS Listenerの作成または更新

スクリプトは、ALBに443番Listenerが存在するか確認する。

| 状態 | 処理 |
| :--- | :--- |
| HTTPS:443 Listenerなし | 新規作成 |
| HTTPS:443 Listenerあり | 証明書、TLSポリシー、Default actionを更新 |

今回の実行では、HTTPS Listenerが存在しなかったため新規作成された。

```text
HTTPS Listener not found. Creating HTTPS Listener.
HTTPS Listener created:
arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:listener/app/sample-elb/6541a59d3446f47f/39a9bc5614a0fc48
```

作成されたListenerの内容は以下である。

| 項目 | 値 |
| :--- | :--- |
| Protocol | HTTPS |
| Port | 443 |
| Certificate | `arn:aws:acm:ap-northeast-1:445405559057:certificate/331011aa-f281-4599-b3a1-c8545805208b` |
| SslPolicy | `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| Default Action | forward |

## 実行結果

今回の実行結果の要点は以下である。

| 項目 | 値 |
| :--- | :--- |
| AWS Account | `445405559057` |
| IAM User | `arn:aws:iam::445405559057:user/nobu` |
| Public Hosted Zone ID | `Z02886402CZFSQE5OSSQ` |
| VPC ID | `vpc-0c78f8870606de8ce` |
| Certificate Domain | `www.nobu-iac-lab.com` |
| Certificate Status | `ISSUED` |
| Certificate ARN | `arn:aws:acm:ap-northeast-1:445405559057:certificate/331011aa-f281-4599-b3a1-c8545805208b` |
| ALB ARN | `arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/6541a59d3446f47f` |
| Target Group ARN | `arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/b96dec0044d356ec` |
| HTTPS Listener ARN | `arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:listener/app/sample-elb/6541a59d3446f47f/39a9bc5614a0fc48` |
| TLS Security Policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` |
| Certificate Expiration | `2026-11-17T08:59:59+09:00` |

## 動作確認

HTTPS Listener作成後、以下を確認する。

### Listener確認

```bash
aws elbv2 describe-listeners \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn <ALB_ARN> \
  --output table
```

443番Listenerがあり、Protocolが `HTTPS`、SslPolicyが `ELBSecurityPolicy-TLS13-1-2-2021-06` であればよい。

### 証明書確認

```bash
aws acm describe-certificate \
  --profile learning \
  --region ap-northeast-1 \
  --certificate-arn arn:aws:acm:ap-northeast-1:445405559057:certificate/331011aa-f281-4599-b3a1-c8545805208b \
  --query 'Certificate.{DomainName:DomainName,Status:Status,NotAfter:NotAfter}' \
  --output table
```

Statusが `ISSUED` であればよい。

### HTTPS疎通確認

```bash
curl -I https://www.nobu-iac-lab.com
```

Rails / Puma / nginxが未設定または未起動の場合、HTTPS接続自体は成立しても、アプリケーション応答は `502` や `503` になることがある。

その場合、HTTPS ListenerやACM証明書ではなく、Target Group Health、nginx、Puma、Railsアプリ側を確認する。

## 注意事項

### HTTPS ListenerはALB削除時に消える

`cleanup_network.sh` でALBを削除すると、Listenerも一緒に削除される。

そのため、日次ラボではALBを作り直した後に、このスクリプトでHTTPS Listenerを再作成する。

### ACM証明書とDNS検証CNAMEは残す

ACM証明書とDNS検証CNAMEは、日次ラボの削除対象にしない。

理由は、証明書はALBと違って毎日作り直す必要がなく、DNS検証CNAMEを残しておくことで証明書の再検証や更新が安定するためである。

### Targetがhealthyとは限らない

HTTPS Listenerが作成されても、Target GroupのTargetがhealthyでなければアプリケーションは正常応答しない。

今回の構成では、Target GroupはHTTP:3000へ転送する。

Web EC2上でnginx / Puma / Railsが正しく動いていない場合、ALBは `502` や `503` を返す。

## 案件対策としてのポイント

この手順は、銀行案件の「AWSセキュリティ・ネットワーク最適化・改善」「影響調査や設定変更、手順書作成」と関係が深い。

特に重要な観点は以下である。

| 観点 | 内容 |
| :--- | :--- |
| 影響調査 | HTTPS Listener追加で外部公開経路が変わる |
| 設定変更 | ALB Listener、ACM証明書、Route 53 CNAMEを変更する |
| セキュリティ | TLSポリシーでTLS 1.0 / 1.1を無効化する |
| 誤作業防止 | ALBとTarget Groupが同じVPCにあることを確認する |
| 証明書管理 | 証明書のStatus、DomainName、有効期限を確認する |
| 手順書化 | 変更前後のListener、証明書ARN、DNS検証レコードを記録する |
| 切り戻し | 443 Listener削除またはHTTP運用へ戻す手順を用意する |

実務では、HTTPS化そのものよりも、以下を説明できることが重要である。

- どのドメインの証明書を使ったか
- 証明書は `ISSUED` か
- どのHosted ZoneへDNS検証CNAMEを入れたか
- Listenerは何番ポートか
- TLSポリシーは何か
- ALBからTarget Groupへの転送先はどこか
- 変更後にどのコマンドで確認したか

## 試験対策としてのポイント

AWS Advanced NetworkingやSolutions Architectの観点では、以下を押さえる。

- ACM証明書はALBのHTTPS Listenerに設定できる
- DNS検証ではRoute 53にCNAMEを作成する
- ALBはクライアントとのHTTPSを終端できる
- ALBからTarget Groupへの通信はHTTPにすることもできる
- HTTPS ListenerにはTLS Security Policyを指定できる
- Public Hosted ZoneとPrivate Hosted Zoneを取り違えない
- Route 53 AliasはALB向け、ACM DNS検証はCNAMEである
- 証明書のリージョンはALBと同じリージョンにする必要がある

## 次に確認すること

次は以下を確認する。

```bash
curl -I https://www.nobu-iac-lab.com

aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/b96dec0044d356ec \
  --output table
```

Target Healthがunhealthyの場合は、Web EC2にSSHしてnginx / Puma / Railsの状態を確認する。

```bash
ssh awsref-web01
sudo systemctl status nginx --no-pager
sudo ss -lntp | grep ':3000'
curl http://127.0.0.1:3000/
```

HTTPSの入口ができたので、次の焦点は「ALBからWeb EC2へ正常に転送できるか」である。
