# 09_LoadBalancer_setup.sh 解説

## 概要

`09_LoadBalancer_setup.sh` は、Public SubnetにApplication Load Balancerを作成し、Private Subnet上のWeb EC2へHTTP通信を転送するスクリプトである。

この手順で作成または利用する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| ALB | sample-elb | インターネットからHTTPアクセスを受ける入口 |
| Target Group | sample-tg | Web EC2 2台への転送先グループ |
| Listener | HTTP:80 | ALBの80番で受け、Target Groupへforwardする |
| Security Group | sample-sg-elb | ALBへHTTP / HTTPSを許可する |
| Web EC2 | sample-ec2-web01 / sample-ec2-web02 | ALBから3000番で転送される対象 |

ALB自体はPublic Subnetに配置するが、アプリケーションを動かすWeb EC2はPrivate Subnetに配置する。

これにより、外部公開の入口はALBに限定し、Web EC2へは直接インターネットから到達できない構成にする。

## 前提条件

このスクリプトを実行する前に、以下のスクリプトが完了している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public Subnet / Private Subnetを作成する |
| `03_internetgateway_setup.sh` | Internet Gatewayを作成し、VPCへアタッチする |
| `05_route_table_setup.sh` | Public SubnetからInternet Gatewayへの経路を設定する |
| `06_security_group_setup.sh` | ELB用Security Groupを作成する |
| `08_Web_server_setup.sh` | Web EC2 2台とWeb用Security Groupを作成する |

確認コマンド:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-subnet-public01,sample-subnet-public02 \
  --query 'Subnets[*].{ID:SubnetId,VPC:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId,State:State.Name}' \
  --output table
```

AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではALB、Target Group、Listenerを操作するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`
- `ec2:DescribeInstances`
- `ec2:DescribeSecurityGroups`
- `elasticloadbalancing:DescribeTargetGroups`
- `elasticloadbalancing:CreateTargetGroup`
- `elasticloadbalancing:ModifyTargetGroup`
- `elasticloadbalancing:RegisterTargets`
- `elasticloadbalancing:DescribeLoadBalancers`
- `elasticloadbalancing:CreateLoadBalancer`
- `elasticloadbalancing:SetSubnets`
- `elasticloadbalancing:SetSecurityGroups`
- `elasticloadbalancing:DescribeListeners`
- `elasticloadbalancing:CreateListener`
- `elasticloadbalancing:ModifyListener`
- `elasticloadbalancing:AddTags`
- `elasticloadbalancing:DescribeTargetHealth`

削除運用まで含める場合は、以下も必要になる。

- `elasticloadbalancing:DeleteLoadBalancer`
- `elasticloadbalancing:DeleteTargetGroup`

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、参照するNameタグを定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 共通関数を定義する
5. 実行対象のAWSアカウントとIAMユーザーを確認する
6. `sample-vpc` が1つだけ存在することを確認し、VPC IDを取得する
7. VPC IDで絞り込み、Public Subnet 01 / 02を取得する
8. Public Subnet 2つが別AZであることを確認する
9. VPC IDで絞り込み、running状態のWeb EC2 2台を取得する
10. ELB用Security Groupを取得する
11. Target Groupを作成または再利用する
12. Web EC2 2台をTarget Groupへ登録する
13. ALBを作成または再利用する
14. ALBが `available` になるまで待機する
15. HTTP:80 Listenerを作成または更新する
16. ALBのDNS名を表示する
17. Target Health、ALB、Listenerの状態を確認する

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

ALBは外部公開入口であり、Target GroupやSecurity Groupと組み合わせて通信経路を作る。途中の失敗を見落とすと、公開不可や想定外公開につながるため、失敗時点で止める設定にしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
PUB01_NAME="sample-subnet-public01"
PUB02_NAME="sample-subnet-public02"
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"
ELB_SG_NAME="sample-sg-elb"

TARGET_GROUP_NAME="sample-tg"
ALB_NAME="sample-elb"
APP_PORT="3000"
HEALTH_CHECK_PATH="/"
```

`APP_PORT` は、ALBからWeb EC2へ転送するアプリケーションポートである。

今回の構成では、ALBはHTTP 80番で受け、Target Group経由でWeb EC2の3000番へ転送する。

`HEALTH_CHECK_PATH` はTarget Groupのヘルスチェックパスである。Railsアプリやnginx/Pumaが未起動の場合、このパスに応答できずTarget Healthは `unhealthy` になる。

## VPC IDでの絞り込み

このスクリプトでは、Subnet、Web EC2、Security Groupの取得時にVPC IDで絞り込む。

例:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUB01_NAME" \
  --query 'length(Subnets)' \
  --output text
```

同じNameタグのSubnetやEC2が別VPCに存在する可能性があるため、Nameタグだけで検索しない。

また、検索結果が0件または2件以上の場合は停止する。

| 件数 | 処理 |
| :--- | :--- |
| 0件 | 前提リソースがないため停止 |
| 1件 | そのリソースを使用 |
| 2件以上 | 誤作業防止のため停止 |

## Public SubnetのAZ確認

ALBは複数AZにまたがる構成が基本である。

このスクリプトでは、`sample-subnet-public01` と `sample-subnet-public02` のAvailability Zoneを確認し、同じAZだった場合は停止する。

```bash
if [ "$PUB01_AZ" = "$PUB02_AZ" ]; then
  echo "Error: ALB requires subnets in at least two Availability Zones."
  exit 1
fi
```

今回の実行では以下の構成である。

| Subnet | Subnet ID | AZ |
| :--- | :--- | :--- |
| sample-subnet-public01 | subnet-0d93b924889bb2ede | ap-northeast-1a |
| sample-subnet-public02 | subnet-027e5f398c2a0e4bd | ap-northeast-1c |

## Target Groupの作成または再利用

```bash
TG_ARN=$(ensure_target_group)
```

`ensure_target_group` は、`sample-tg` が存在するか確認する。

既存Target Groupがある場合は、以下を確認する。

- VPC IDが `sample-vpc` と一致すること
- Protocolが `HTTP` であること
- Portが `3000` であること

存在しない場合は、以下の設定でTarget Groupを作成する。

| 項目 | 値 |
| :--- | :--- |
| Name | sample-tg |
| Protocol | HTTP |
| Port | 3000 |
| Target Type | instance |
| VPC | sample-vpc |
| Health Check Protocol | HTTP |
| Health Check Path | / |

既存Target Groupを再利用する場合も、タグとヘルスチェック設定を再適用する。

## Target登録

```bash
aws elbv2 register-targets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --target-group-arn "$TG_ARN" \
  --targets Id="$WEB01_ID",Port="$APP_PORT" Id="$WEB02_ID",Port="$APP_PORT"
```

Web EC2 2台をTarget Groupへ登録する。

`register-targets` は同じTargetを再登録しても安全に扱えるため、再実行時に重複登録で失敗しない。

今回登録したTargetは以下である。

| Name | Instance ID | Port |
| :--- | :--- | :--- |
| sample-ec2-web01 | i-0e65b7e57cf447008 | 3000 |
| sample-ec2-web02 | i-09ef15cd775216f4d | 3000 |

## ALBの作成または再利用

```bash
LB_ARN=$(ensure_load_balancer)
```

`ensure_load_balancer` は、`sample-elb` が存在するか確認する。

既存ALBがある場合は、以下を確認する。

- VPC IDが `sample-vpc` と一致すること
- Typeが `application` であること
- Schemeが `internet-facing` であること

既存ALBを再利用する場合も、SubnetとSecurity Groupを設計値へそろえる。

存在しない場合は、以下の設定でALBを作成する。

| 項目 | 値 |
| :--- | :--- |
| Name | sample-elb |
| Type | application |
| Scheme | internet-facing |
| IP Address Type | ipv4 |
| Subnets | sample-subnet-public01, sample-subnet-public02 |
| Security Group | sample-sg-elb |

`sample-sg-elb` は、前工程でHTTP 80/tcpとHTTPS 443/tcpをインターネット向けに許可している。

ただし、このスクリプトで作成するListenerはHTTP 80のみである。HTTPS 443 Listenerは、後続のACM証明書設定後に作成する想定である。

## Listenerの作成または更新

```bash
LISTENER_ARN=$(ensure_http_listener)
```

`ensure_http_listener` は、ALBにHTTP:80 Listenerが存在するか確認する。

| 状態 | 処理 |
| :--- | :--- |
| HTTP:80 Listenerがない | 新規作成する |
| HTTP:80 Listenerが1つある | 転送先Target Groupを `sample-tg` に更新する |
| HTTP:80 Listenerが複数ある | 誤設定の可能性があるため停止する |

Listenerの設定は以下である。

| 項目 | 値 |
| :--- | :--- |
| Protocol | HTTP |
| Port | 80 |
| Default Action | forward to sample-tg |

## 実行結果

実行コマンド:

```bash
./09_LoadBalancer_setup.sh
```

実行時に確認された主なリソースID:

| 種別 | 値 |
| :--- | :--- |
| VPC | vpc-09872a034f259a5f3 |
| Public Subnet 01 | subnet-0d93b924889bb2ede / ap-northeast-1a |
| Public Subnet 02 | subnet-027e5f398c2a0e4bd / ap-northeast-1c |
| Web01 | i-0e65b7e57cf447008 |
| Web02 | i-09ef15cd775216f4d |
| ELB Security Group | sg-0b3b4f92ca2be5015 |
| Target Group | arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/eb5fb0fa1c9c88b4 |
| ALB | arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/5319a7191c654aa8 |
| Listener | arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:listener/app/sample-elb/5319a7191c654aa8/37097e668441454e |
| ALB DNS | sample-elb-594310010.ap-northeast-1.elb.amazonaws.com |

アクセスURL:

```text
http://sample-elb-594310010.ap-northeast-1.elb.amazonaws.com
```

実行直後のTarget Health:

| Target | Port | State | Reason | Description |
| :--- | :--- | :--- | :--- | :--- |
| i-0e65b7e57cf447008 | 3000 | initial | Elb.RegistrationInProgress | Target registration is in progress |
| i-09ef15cd775216f4d | 3000 | initial | Elb.RegistrationInProgress | Target registration is in progress |

`initial` はTarget登録直後の状態であり、この時点では異常ではない。

Rails/Puma/nginxがまだWeb EC2上で起動していない場合、その後 `unhealthy` になる可能性が高い。これはALB作成失敗ではなく、Target側が3000番でHTTP応答していないためである。

確認されたALB状態:

| 項目 | 値 |
| :--- | :--- |
| Name | sample-elb |
| DNSName | sample-elb-594310010.ap-northeast-1.elb.amazonaws.com |
| Scheme | internet-facing |
| State | active |
| Type | application |
| VPC | vpc-09872a034f259a5f3 |

確認されたListener:

| Protocol | Port | Default Action |
| :--- | :--- | :--- |
| HTTP | 80 | forward to sample-tg |

## 変更前確認

ALB作成前には、少なくとも以下を確認する。

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-elb \
  --output table

aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-tg \
  --output table
```

存在しない場合は、AWS CLIが `LoadBalancerNotFound` や `TargetGroupNotFound` を返す。

Web EC2確認:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId,State:State.Name}' \
  --output table
```

Security Group確認:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-elb,sample-sg-web \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,VPC:VpcId,Ingress:IpPermissions}' \
  --output json
```

確認ポイント:

- ALB名が既に使われていないか
- Target Group名が既に使われていないか
- Public Subnetが2つあり、別AZであること
- Web EC2 2台がrunningであること
- Web EC2にPublic IPがないこと
- ALB用Security GroupがHTTP 80/tcpを許可していること
- Web用Security GroupがELB SGから3000/tcpを許可していること

## 変更後確認

スクリプト実行後は、以下を確認する。

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-elb \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId}' \
  --output table
```

Listener確認:

```bash
aws elbv2 describe-listeners \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:loadbalancer/app/sample-elb/5319a7191c654aa8 \
  --query 'Listeners[*].{Port:Port,Protocol:Protocol,DefaultActions:DefaultActions[*].{Type:Type,TargetGroupArn:TargetGroupArn}}' \
  --output table
```

Target Health確認:

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:445405559057:targetgroup/sample-tg/eb5fb0fa1c9c88b4 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

確認ポイント:

- ALBのStateが `active` であること
- Schemeが `internet-facing` であること
- ListenerがHTTP 80で存在すること
- ListenerのDefault Actionが `sample-tg` へforwardであること
- Target GroupにWeb EC2 2台が登録されていること
- Target Healthが `initial`、`healthy`、または想定どおりの `unhealthy` であること

Rails/Puma/nginxを構成した後は、Target Healthが `healthy` になることを確認する。

## Target Healthの見方

Target Healthは、ALBとWeb EC2間の疎通状態を判断する重要な確認ポイントである。

代表的な状態は以下である。

| State | よくある意味 |
| :--- | :--- |
| initial | Target登録直後、またはヘルスチェック開始直後 |
| healthy | ヘルスチェックに成功している |
| unhealthy | ヘルスチェックに失敗している |
| unused | Targetが利用されていない、またはListener/Ruleから参照されていない |
| draining | Deregister中 |

`unhealthy` の場合に見るポイント:

- Web EC2でRails/Puma/nginxが起動しているか
- Web EC2が3000番で待ち受けているか
- Target GroupのHealth Check Pathがアプリの応答パスと一致しているか
- Web Security GroupがELB Security Groupから3000/tcpを許可しているか
- NACLで戻り通信が拒否されていないか
- Private SubnetのRoute TableやNATは、アプリの外向き通信要件に影響していないか
- Web EC2のOSファイアウォールやnginx/Puma設定で拒否していないか

確認例:

```bash
ssh awsref-web01
sudo ss -lntp | grep 3000
curl -I http://127.0.0.1:3000/
```

## 切り戻し方法

HTTP Listenerを削除する場合:

```bash
aws elbv2 delete-listener \
  --profile learning \
  --region ap-northeast-1 \
  --listener-arn <LISTENER_ARN>
```

ALBを削除する場合:

```bash
aws elbv2 delete-load-balancer \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn <LOAD_BALANCER_ARN>
```

ALB削除後、削除完了を待つ。

```bash
aws elbv2 wait load-balancers-deleted \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arns <LOAD_BALANCER_ARN>
```

Target Groupを削除する場合:

```bash
aws elbv2 delete-target-group \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn <TARGET_GROUP_ARN>
```

Target GroupはListenerやRuleから参照されている間は削除できない。先にListenerまたはALBを削除する。

## cleanup_network.shとの関係

`cleanup_network.sh` は、09で作成したALBとTarget Groupも削除対象にしている。

削除順序は以下である。

1. ALBを削除する
2. ALB削除完了を待つ
3. Target Groupを削除する
4. EC2を終了する
5. NAT Gatewayを削除する
6. Elastic IPを解放する
7. Route Tableを削除する
8. Security Groupを削除する
9. Internet Gatewayを削除する
10. Subnetを削除する
11. VPCを削除する

ALBが残っていると、関連付いたSecurity GroupやSubnetを削除できない。そのため、ネットワーク削除前にALBを先に削除する。

## 影響範囲

ALB作成により影響を受ける主な範囲は以下である。

| 対象 | 影響 |
| :--- | :--- |
| Public Subnet | ALBノードが配置される |
| ELB Security Group | ALBへのHTTP/HTTPS入口になる |
| Web Security Group | ELB SGから3000/tcpを受ける |
| Target Group | Web EC2 2台のヘルスチェックと転送先になる |
| Web EC2 | ALBからのHTTP 3000番を受ける対象になる |
| コスト | ALB稼働時間とLCUに課金される |

ALBは外部公開の入口である。Security Group、Listener、Target Groupの設定を誤ると、公開不可や想定外公開につながる。

## 気をつける点

- ALBは少なくとも2つのAZにまたがるSubnet指定が基本である
- ALB用Security Groupはインターネットからの入口を制御する
- Web用Security Groupでは、ALB用Security Groupからのアプリケーションポートだけを許可する
- Target GroupのPortとWebアプリの待ち受けPortを一致させる
- Health Check Pathはアプリが200を返すパスにする
- Target Healthが `initial` の時点では、まだ異常とは限らない
- Rails/Puma/nginxが未起動ならTarget Healthは `unhealthy` になる
- HTTPS Listenerはこのスクリプトでは未作成であり、ACM証明書設定後に作成する
- ALB削除前にTarget Groupを削除しようとすると失敗することがある
- ALBが残るとSecurity GroupやSubnet削除で詰まる

## 案件実務ポイント

今回の銀行案件では、影響調査済みのAWS設定変更、テスト、手順書作成が中心になる見込みである。

ALBやTarget Groupの変更では、以下の観点が重要になる。

- 変更対象のALB、Listener、Rule、Target Groupを正確に特定する
- 変更前のListener設定とTarget Group設定を証跡として保存する
- Target GroupのHealth Check設定を確認する
- 変更前後でTarget Healthを比較する
- Security Groupの送信元と許可Portを確認する
- ALBアクセスログやCloudWatchメトリクスで影響を確認する
- 切り戻しとしてListenerのDefault ActionやTarget Group登録状態を戻せるようにする
- アプリ未起動による `unhealthy` とネットワーク不備による `unhealthy` を切り分ける

説明例:

```text
ALBはPublic Subnet 2つに配置し、HTTP 80番のListenerで受けた通信をTarget Groupへforwardしています。
Target GroupはPrivate Subnet上のWeb EC2 2台を3000番で登録しています。
Web Security Groupでは、ALB用Security Groupからの3000番のみを許可しているため、Web EC2はインターネットから直接到達できません。
```

## 試験対策ポイント

AWS試験では、ALB、Listener、Target Group、Health Check、Security Groupの関係がよく問われる。

押さえるポイント:

- ALBはレイヤー7のロードバランサーである
- ALBはListenerで受け、Ruleに従ってTarget Groupへ転送する
- Target GroupにはInstance、IP、Lambdaなどのターゲットタイプがある
- 今回はTarget Type `instance` を使っている
- ALBはPublic Subnet、Web EC2はPrivate Subnetに置く構成がよく使われる
- Web EC2のSecurity Groupでは、ALB SGからのアプリケーションポートだけを許可する
- Target Healthがhealthyでないと、ALBは正常な転送先として扱えない
- HTTPS化にはACM証明書とHTTPS Listenerが必要である
- ALBはSecurity Groupを持つが、NLBはSecurity Groupの扱いが構成により異なる
- ALBのDNS名は作成時に払い出され、Route 53 Aliasレコードで独自ドメインに紐づけることが多い

## 今後の確認

このスクリプトは再実行耐性を入れているため、再度実行した場合は以下のような挙動になる想定である。

- 既存Target Groupを再利用する
- 既存ALBを再利用する
- 既存HTTP:80 Listenerを更新する
- Web EC2 2台をTarget Groupへ再登録する
- VPC、Protocol、Port、Schemeなどが設計と違う場合は停止する

再実行確認コマンド:

```bash
./09_LoadBalancer_setup.sh
```

次の工程では、Web EC2側にRails/Puma/nginxを構成し、Target Healthが `healthy` になることを確認する。

その後、Route 53、ACM、HTTPS Listenerを追加し、`https://www.nobu-iac-lab.com` でアクセスできる構成へ拡張する。

