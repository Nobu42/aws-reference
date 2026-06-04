# 09/12 ALB・Public DNSトラブルシュートメモ

## 概要

このメモは、`09_LoadBalancer_setup.sh` と `12_public_dns_setup.sh` の実行時に発生した問題と、その切り分け、対応、学びを記録したものである。

今回のポイントは、**同じ名前のTarget Group `sample-tg` が旧VPCに残っていたため、新しいVPC上のALB構築が止まった**ことである。

これは、AWS設定変更作業でよくある「残存リソース」「同名リソース」「依存関係」の問題であり、案件対策として非常に重要である。

## 関係するスクリプト

| スクリプト | 役割 |
| :--- | :--- |
| `09_LoadBalancer_setup.sh` | Public SubnetにALBを作成し、Web EC2をTarget Groupへ登録する |
| `12_public_dns_setup.sh` | Route 53 Public Hosted Zoneに `bastion` と `www` のDNSレコードを作成・更新する |

## 本来の構成

本来作成したい構成は以下である。

```text
Internet
  |
  | http://www.nobu-iac-lab.com
  v
Route 53 Public Hosted Zone
  |
  | A Alias
  v
Application Load Balancer sample-elb
  |
  | Target Group sample-tg / port 3000
  v
Web EC2
  - sample-ec2-web01
  - sample-ec2-web02
```

BastionはALBを経由しない。

```text
User PC
  |
  | ssh bastion.nobu-iac-lab.com
  v
Bastion EC2
```

## 今回の実行順

今回、以下の流れで作業した。

1. `12_public_dns_setup.sh` を実行した
2. ALB情報取得のところで進まなかった
3. ALB一覧を確認した
4. ALBが存在しないことが分かった
5. `09_LoadBalancer_setup.sh` を実行した
6. Target Group設定のところで問題が見つかった
7. Target Group一覧を確認した
8. 旧VPCに紐づいた `sample-tg` が残っていることが分かった
9. 古いTarget Groupを削除した
10. `09_LoadBalancer_setup.sh` を再実行した
11. `12_public_dns_setup.sh` を再実行した
12. ALB作成とRoute 53更新が成功した

## 発生した事象

`12_public_dns_setup.sh` を実行したところ、以下までは正常に進んだ。

```text
=== Caller Identity ===
Account: 445405559057
Arn: arn:aws:iam::445405559057:user/nobu

=== Get Public Hosted Zone ID ===
Hosted Zone ID: Z02886402CZFSQE5OSSQ

=== Get VPC ID ===
VPC: vpc-0127f31bb241c01b0

=== Get Bastion Public IP ===
Bastion Instance: i-09fb67d6c0de9c265
Bastion Public IP: 52.195.216.194

=== Get ALB DNS Name and Canonical Hosted Zone ID ===
```

この時点で、ALB情報が取得できていなかった。

`12_public_dns_setup.sh` は、`www.nobu-iac-lab.com` をALBへ向けるために、以下の情報を必要とする。

| 必要な値 | 用途 |
| :--- | :--- |
| ALB ARN | 対象ALBの一意な識別子 |
| ALB DNS Name | Route 53 Aliasの向き先 |
| ALB Canonical Hosted Zone ID | Route 53 Alias作成に必要 |

ALBが存在しない場合、これらを取得できない。

## ALB存在確認

ALBが存在するか確認するため、以下を実行した。

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,State:State.Code,VpcId:VpcId,DNS:DNSName}' \
  --output table
```

結果は何も表示されなかった。

これは、現在の `ap-northeast-1` にALBが存在しないことを意味する。

この時点の判断:

```text
12_public_dns_setup.sh が止まった直接原因は、sample-elb が存在しないため。
```

## 09番の再実行

ALBが存在しなかったため、先に `09_LoadBalancer_setup.sh` を実行した。

```bash
./09_LoadBalancer_setup.sh
```

出力は以下まで進んだ。

```text
=== Caller Identity ===
Account: 445405559057

=== Get Resource IDs ===
VPC: vpc-0127f31bb241c01b0
Public Subnet 01: subnet-0f5c48bdd26da2768 (ap-northeast-1a)
Public Subnet 02: subnet-0d48938a5cc94e862 (ap-northeast-1c)
Web Instances: i-027d8cf0673190a7a, i-08f91d1b14fa093e1
ELB Security Group: sg-003d65256fed91381

=== Configure Target Group ===
```

ここでTarget Group周辺に問題がありそうだと判断した。

## Target Group確認

Target Group一覧を確認した。

```bash
aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'TargetGroups[*].{Name:TargetGroupName,VpcId:VpcId,Port:Port,Protocol:Protocol,Arn:TargetGroupArn}' \
  --output table
```

結果:

```text
Name:     sample-tg
Port:     3000
Protocol: HTTP
VpcId:    vpc-09872a034f259a5f3
Arn:      arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/eb5fb0fa1c9c88b4
```

ここで重要なのは、Target GroupのVPC IDである。

| 項目 | VPC ID |
| :--- | :--- |
| 現在のVPC | vpc-0127f31bb241c01b0 |
| 残っていたTarget GroupのVPC | vpc-09872a034f259a5f3 |

`sample-tg` という名前は同じだが、紐づいているVPCが違っていた。

## 原因

原因は、古いTarget Group `sample-tg` が旧VPCに紐づいたまま残っていたことである。

```text
旧Target Group:
  sample-tg
  VPC: vpc-09872a034f259a5f3

現在の構築対象:
  sample-vpc
  VPC: vpc-0127f31bb241c01b0
```

ALBのTarget GroupはVPCに紐づくリソースである。

そのため、同じ名前のTarget Groupが存在していても、VPCが違えば現在のALB構成では再利用できない。

`09_LoadBalancer_setup.sh` は、既存Target Groupを見つけた場合にVPC IDを確認する。

VPC IDが期待値と違う場合は、誤ったTarget Groupを使わないように停止する。

これはスクリプトの安全装置として正しい動きである。

## なぜNameだけでは危険か

AWSでは、Nameタグやリソース名だけでは安全に対象を特定できないことがある。

今回のように、古いリソースが残っている場合、以下のような状態になる。

| リソース名 | VPC | 状態 |
| :--- | :--- | :--- |
| sample-tg | 旧VPC | 残存している |
| sample-vpc | 新VPC | 現在の構築対象 |

もしスクリプトがNameだけでTarget Groupを再利用していた場合、以下の問題が起きる可能性がある。

- 新しいALBが旧VPCのTarget Groupを参照しようとして失敗する
- Web EC2を誤ったTarget Groupへ登録しようとする
- 後続のDNSが存在しないALBや誤ったALBへ向く
- 原因調査が難しくなる

そのため、NameだけでなくVPC IDも確認することが重要である。

## 対応

古いTarget Groupを削除した。

```bash
aws elbv2 delete-target-group \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/eb5fb0fa1c9c88b4
```

その後、Target Groupが消えていることを確認した。

```bash
aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'TargetGroups[*].{Name:TargetGroupName,VpcId:VpcId,Port:Port,Protocol:Protocol,Arn:TargetGroupArn}' \
  --output table
```

古い `sample-tg` が表示されなければ、削除できている。

## 09番の再実行結果

古いTarget Groupを削除した後、`09_LoadBalancer_setup.sh` を再実行した。

```bash
./09_LoadBalancer_setup.sh
```

結果:

```text
=== Get Resource IDs ===
VPC: vpc-0127f31bb241c01b0
Public Subnet 01: subnet-0f5c48bdd26da2768 (ap-northeast-1a)
Public Subnet 02: subnet-0d48938a5cc94e862 (ap-northeast-1c)
Web Instances: i-027d8cf0673190a7a, i-08f91d1b14fa093e1
ELB Security Group: sg-003d65256fed91381

=== Configure Target Group ===
Creating Target Group: sample-tg
Target Group: arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/d1206ec02a6929f8

=== Register Web Servers to Target Group ===
Web01 and Web02 registered to Target Group.

=== Configure Application Load Balancer ===
Creating ALB: sample-elb
Load Balancer: arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/907bd450b752f10a

=== Wait for Load Balancer to become available ===
Load Balancer is available.

=== Configure Listener ===
Creating HTTP Listener: 80 -> sample-tg
Listener: arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:listener/app/sample-elb/907bd450b752f10a/18bec825a99a88f4
```

作成されたALB:

```text
Name:   sample-elb
DNS:    sample-elb-1152648241.ap-northeast-1.elb.amazonaws.com
Scheme: internet-facing
State:  active
Type:   application
VpcId:  vpc-0127f31bb241c01b0
```

作成されたTarget Group:

```text
Name: sample-tg
ARN:  arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/d1206ec02a6929f8
Port: 3000
```

Target Healthは初期状態だった。

```text
Target: i-027d8cf0673190a7a
Port:   3000
State:  initial
Reason: Elb.RegistrationInProgress

Target: i-08f91d1b14fa093e1
Port:   3000
State:  initial
Reason: Elb.RegistrationInProgress
```

`initial` は、Target登録直後の状態であり、少し待つと `healthy` または `unhealthy` に変わる。

Webアプリやnginx/Pumaが正しく応答していない場合は `unhealthy` になる。

## 12番の再実行結果

ALB作成後、`12_public_dns_setup.sh` を再実行した。

```bash
./12_public_dns_setup.sh
```

結果:

```text
=== Get Public Hosted Zone ID ===
Hosted Zone ID: Z02886402CZFSQE5OSSQ

=== Get VPC ID ===
VPC: vpc-0127f31bb241c01b0

=== Get Bastion Public IP ===
Bastion Instance: i-09fb67d6c0de9c265
Bastion Public IP: 52.195.216.194

=== Get ALB DNS Name and Canonical Hosted Zone ID ===
ALB ARN: arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/907bd450b752f10a
ALB DNS Name: sample-elb-1152648241.ap-northeast-1.elb.amazonaws.com
ALB Canonical Hosted Zone ID: Z14GRHDCWA56QT

=== Create / Update Public DNS Records ===
Route 53 Change ID: /change/C010270118YBEPOU302MC

=== Wait for DNS Change to be INSYNC ===
DNS change is INSYNC.
```

Route 53に作成・更新されたレコード:

| Name | Type | Value |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com. | A | 52.195.216.194 |
| www.nobu-iac-lab.com. | A Alias | sample-elb-1152648241.ap-northeast-1.elb.amazonaws.com |

## 最終状態

最終的に、以下の状態になった。

### ALB

| 項目 | 値 |
| :--- | :--- |
| Name | sample-elb |
| ARN | arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/907bd450b752f10a |
| DNS | sample-elb-1152648241.ap-northeast-1.elb.amazonaws.com |
| Scheme | internet-facing |
| State | active |
| Type | application |
| VPC | vpc-0127f31bb241c01b0 |

### Target Group

| 項目 | 値 |
| :--- | :--- |
| Name | sample-tg |
| ARN | arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/d1206ec02a6929f8 |
| Protocol | HTTP |
| Port | 3000 |
| VPC | vpc-0127f31bb241c01b0 |

### Targets

| Target | Port | 初期状態 |
| :--- | :--- | :--- |
| i-027d8cf0673190a7a | 3000 | initial |
| i-08f91d1b14fa093e1 | 3000 | initial |

### Route 53

| レコード | 種別 | 向き先 |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com | A | 52.195.216.194 |
| www.nobu-iac-lab.com | A Alias | sample-elb-1152648241.ap-northeast-1.elb.amazonaws.com |

## 確認コマンド

### ALB確認

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,State:State.Code,VpcId:VpcId,DNS:DNSName}' \
  --output table
```

### Target Group確認

```bash
aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --query 'TargetGroups[*].{Name:TargetGroupName,VpcId:VpcId,Port:Port,Protocol:Protocol,Arn:TargetGroupArn}' \
  --output table
```

### Target Health確認

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/d1206ec02a6929f8 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

### Route 53レコード確認

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id Z02886402CZFSQE5OSSQ \
  --query "ResourceRecordSets[?Name==\`bastion.nobu-iac-lab.com.\` || Name==\`www.nobu-iac-lab.com.\`]" \
  --output table
```

### 名前解決確認

```bash
dig +short bastion.nobu-iac-lab.com
dig +short www.nobu-iac-lab.com
```

### HTTP確認

```bash
curl -I http://www.nobu-iac-lab.com
```

## 切り分けの考え方

今回のように、DNSやALB周りで止まった場合は、以下の順に確認するとよい。

### 1. DNSスクリプトが必要とするリソースを確認する

`12_public_dns_setup.sh` は、以下が必要である。

- Public Hosted Zone
- Bastion Public IP
- ALB DNS Name
- ALB Canonical Hosted Zone ID

このうちALBが存在しなければ、`www` のAliasレコードは作れない。

### 2. ALBが存在するか確認する

```bash
aws elbv2 describe-load-balancers ...
```

ALBがなければ、先に09番を実行する。

### 3. Target Groupが残っていないか確認する

```bash
aws elbv2 describe-target-groups ...
```

Target GroupはALB作成前でも残ることがある。

ALBは消えていてもTarget Groupだけ残っている場合があるため、ALB一覧だけで判断しない。

### 4. VPC IDを見る

リソース名が同じでも、VPC IDが違えば別環境の残存リソースである。

今回のように、`sample-tg` という名前だけで判断しない。

### 5. 不要な残存リソースを削除する

旧VPCに紐づくTarget Groupが不要であれば削除する。

ただし、本番環境では必ず影響調査と承認を行う。

## なぜVPC ID確認が重要か

AWSでは、リソースの名前は一意とは限らない。

今回のTarget Groupは、名前としては `sample-tg` だった。

しかし、紐づくVPCが違っていた。

```text
sample-tg
  旧VPC: vpc-09872a034f259a5f3

sample-vpc
  現在VPC: vpc-0127f31bb241c01b0
```

AWSで設定変更や影響調査を行う場合、以下のような識別子を確認する必要がある。

| リソース | 確認すべき識別子 |
| :--- | :--- |
| VPC | VpcId |
| Subnet | SubnetId / VpcId / AZ |
| Security Group | GroupId / VpcId |
| Target Group | TargetGroupArn / VpcId |
| ALB | LoadBalancerArn / VpcId |
| EC2 | InstanceId / VpcId / SubnetId |
| Route 53 | HostedZoneId / Record Name |

Nameタグは人間にとって分かりやすいが、作業対象を一意に保証するものではない。

## UPSERTとの関係

`12_public_dns_setup.sh` はRoute 53レコード作成に `UPSERT` を使っている。

`UPSERT` は、以下の動きをする。

```text
レコードがなければ作成する
レコードがあれば更新する
```

そのため、DNSレコードが既にあること自体は問題ではない。

今回の問題は、DNSレコードの重複ではなく、DNSの向き先にするALBが存在しなかったことと、ALB作成前段のTarget Groupに旧VPC残存リソースがあったことである。

つまり、再実行耐性の観点では以下の整理になる。

| 対象 | 再実行耐性 |
| :--- | :--- |
| Route 53 DNSレコード | UPSERTにより作成済みでも更新できる |
| Target Group | 既存が同じVPCなら再利用できる |
| Target Group | 既存が別VPCなら安全のため停止する |
| ALB | 既存が同じVPCなら再利用できる |
| ALB | 存在しなければ作成する |

## 今回の対応が案件対策になる理由

今回の対応は、案件内容の以下に直結する。

```text
AWSセキュリティ・ネットワーク最適化・改善
影響調査や設定変更、手順書作成
```

特に以下の観点が実務的である。

| 観点 | 今回の対応 |
| :--- | :--- |
| 影響調査 | ALB、Target Group、VPC ID、DNSレコードを確認した |
| 設定変更 | 古いTarget Groupを削除し、新しいALB/TG/DNSを作成した |
| 誤操作防止 | VPC ID不一致を検知して停止した |
| 手順書作成 | 確認コマンド、原因、対応、結果を記録した |
| ネットワーク理解 | ALB、Target Group、Route 53の依存関係を確認した |
| 運用理解 | 残存リソースが後続作業へ影響することを確認した |

このような切り分けは、本番作業前の事前確認や、設定変更時のトラブル対応で必要になる。

## 実務での注意点

本番や銀行系環境では、今回のようにすぐ削除する前に、必ず以下を確認する。

1. そのTarget Groupが本当に不要か
2. どのALBやListenerから参照されているか
3. 登録Targetが残っていないか
4. CloudTrailや変更履歴で作成経緯を確認できるか
5. 削除による影響範囲はないか
6. 削除前のARN、VPC ID、設定値を記録したか
7. ロールバック方法があるか

確認コマンド例:

```bash
aws elbv2 describe-listeners \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn <ALB_ARN>
```

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn <TARGET_GROUP_ARN>
```

```bash
aws elbv2 describe-rules \
  --profile learning \
  --region ap-northeast-1 \
  --listener-arn <LISTENER_ARN>
```

本番では、名前が古そうだから削除する、という判断はしない。

必ず参照関係と影響範囲を確認してから対応する。

## 再発防止

今回のような残存リソース問題を減らすため、以下を行う。

### cleanup対象を広げる

`cleanup_network.sh` に、日次ラボで作成したTarget Group、ALB、DNS一時レコードの削除を含める。

既にALBとTarget Groupは削除対象になっているが、今回のように途中で残った場合にも検知しやすいよう、`check_cleanup.sh` を必ず実行する。

### check_cleanup.shを実行する

日次削除後に以下を実行する。

```bash
./check_cleanup.sh
```

確認すべき項目:

- 古いVPCが残っていないこと
- 古いALBが残っていないこと
- 古いTarget Groupが残っていないこと
- 古いEC2が残っていないこと
- 古いSecurity Groupが残っていないこと
- `bastion` / `www` の一時DNSレコードが残っていないこと

### スクリプト側でVPC IDを照合する

`09_LoadBalancer_setup.sh` や `12_public_dns_setup.sh` のように、既存リソースを再利用する場合はVPC IDを必ず確認する。

今回、スクリプトがVPC ID不一致で停止したことにより、誤ったTarget Groupの利用を防げた。

これは良い安全装置である。

## まとめ

今回の問題は、DNSそのものの問題ではなく、ALB作成前段のTarget Group残存が原因だった。

最終的には、旧VPCに紐づくTarget Groupを削除し、09番と12番を再実行することで解決した。

重要な学びは以下である。

- AWSではNameだけでなく、VPC IDやARNで対象を確認する
- ALBがなくてもTarget Groupだけ残ることがある
- 残存リソースは後続スクリプトの失敗原因になる
- Route 53のUPSERTはDNS再実行には強いが、向き先リソースが存在しなければ意味がない
- 設定変更では、変更対象だけでなく依存リソースも確認する
- こうした確認・判断・記録が、案件で求められる影響調査と手順書作成に直結する

