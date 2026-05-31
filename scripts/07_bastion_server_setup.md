# 07_bastion_server_setup.sh 解説

## 概要

`07_bastion_server_setup.sh` は、Public Subnetに踏み台サーバー用EC2を作成または再利用するスクリプトである。

この手順で作成するBastionは、後続でPrivate Subnet上のWebサーバーへSSH接続するための管理入口になる。

作成または利用する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| EC2 | sample-ec2-bastion | 踏み台サーバー |
| Key Pair | nobu | EC2 SSH接続用 |
| 秘密鍵ファイル | nobu.pem | ローカルからSSHするための秘密鍵 |
| Security Group | sample-sg-bastion | BastionへのSSH許可 |
| Subnet | sample-subnet-public01 | Bastion配置先 |

BastionはPublic IPを持つため、外部からSSHできる入口になる。したがって、Security Group、Key Pair、秘密鍵ファイル、Public IPの扱いが重要である。

## 前提条件

このスクリプトを実行する前に、以下のスクリプトが完了している必要がある。

| 手順 | 内容 |
| :--- | :--- |
| `01_vpc_setup.sh` | `sample-vpc` を作成する |
| `02_subnet_setup.sh` | Public Subnetを作成する |
| `03_internetgateway_setup.sh` | Internet Gatewayを作成し、VPCへアタッチする |
| `05_route_table_setup.sh` | Public SubnetからInternet Gatewayへの経路を設定する |
| `06_security_group_setup.sh` | Bastion用Security Groupを作成する |

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
  --filters Name=tag:Name,Values=sample-subnet-public01 \
  --query 'Subnets[*].{ID:SubnetId,VPC:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-bastion \
  --query 'SecurityGroups[*].{ID:GroupId,VPC:VpcId,Name:GroupName,Ingress:IpPermissions}' \
  --output json
```

AWS CLIで `learning` プロファイルが設定されている必要がある。

```bash
aws configure list --profile learning
```

このスクリプトではEC2、Key Pair、SSM Parameter Storeを操作するため、IAMユーザーまたはIAMロールには少なくとも以下の権限が必要である。

- `sts:GetCallerIdentity`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeInstances`
- `ec2:DescribeKeyPairs`
- `ec2:CreateKeyPair`
- `ec2:RunInstances`
- `ec2:StartInstances`
- `ec2:CreateTags`
- `ssm:GetParameter`

削除運用まで含める場合は、以下も必要になる。

- `ec2:StopInstances`
- `ec2:TerminateInstances`
- `ec2:DeleteKeyPair`

ただし、このスクリプトと現在の `cleanup_network.sh` では、Key Pairは自動削除しない方針にしている。

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、参照するNameタグを定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 共通関数を定義する
5. 実行対象のAWSアカウントとIAMユーザーを確認する
6. `sample-vpc` が1つだけ存在することを確認し、VPC IDを取得する
7. VPC IDで絞り込み、Public SubnetとBastion用Security Groupを取得する
8. 同じNameタグのBastion EC2が既に存在するか確認する
9. 既存Bastionがあれば、Key Pair名とローカル秘密鍵を確認して再利用する
10. 既存Bastionが停止中なら起動する
11. 既存Bastionがなければ、Key Pairと秘密鍵ファイルの整合性を確認する
12. Key Pairが存在しない場合だけ新規作成し、`nobu.pem` を保存する
13. Amazon Linux 2023の最新AMI IDをSSM Parameter Storeから取得する
14. Public SubnetにBastion EC2を起動する
15. EC2が `running` になるまで待機する
16. Public IPとPrivate IPを取得する
17. SSH接続コマンドとEC2の状態を表示する

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

EC2作成は課金対象であり、Key PairやSecurity Groupの不整合はSSH不能につながる。途中の失敗を見落として後続処理が進まないようにしている。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
PUBLIC_SUBNET_NAME="sample-subnet-public01"
BASTION_SG_NAME="sample-sg-bastion"

KEY_NAME="nobu"
KEY_FILE="${KEY_NAME}.pem"

INSTANCE_NAME="sample-ec2-bastion"
INSTANCE_TYPE="t3.micro"
```

`PROFILE` は、AWS CLIで使用する認証情報のプロファイル名である。

`REGION` は、EC2を作成するリージョンである。今回は東京リージョンの `ap-northeast-1` を使用する。

`KEY_NAME` はAWS側のKey Pair名で、`KEY_FILE` はローカルに保存する秘密鍵ファイル名である。

`INSTANCE_NAME` はBastion EC2のNameタグであり、再実行時の既存EC2検出にも使う。

## VPC IDでの絞り込み

このスクリプトでは、SubnetとSecurity Groupを取得するときにVPC IDで絞り込む。

例:

```bash
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=tag:Name,Values="$PUBLIC_SUBNET_NAME" \
  --query 'length(Subnets)' \
  --output text
```

Subnet名やSecurity Group名は、別VPCに同じ名前で存在する可能性がある。

Nameタグだけで検索して先頭を使うと、別VPCのSubnetやSecurity Groupを誤って使う危険がある。そのため、先に対象VPCを特定し、以降の検索はVPC IDで範囲を限定する。

また、検索結果が0件または2件以上の場合は停止する。

| 件数 | 処理 |
| :--- | :--- |
| 0件 | 前提リソースがないため停止 |
| 1件 | そのリソースを使用 |
| 2件以上 | 誤作業防止のため停止 |

## Key Pairの扱い

このスクリプトでは、Key Pairを無条件に削除して作り直さない。

理由は、EC2のKey Pairとローカルの秘密鍵ファイルが対応していないとSSHできなくなるためである。

AWSのKey Pair作成時に返される `KeyMaterial` は、作成時にしか取得できない。AWS側にKey Pairが存在していても、後から秘密鍵の中身を再ダウンロードすることはできない。

そのため、現在のスクリプトでは以下の判定にしている。

| AWS側Key Pair | ローカル `nobu.pem` | 処理 |
| :--- | :--- | :--- |
| あり | あり | 再利用し、`chmod 400` を適用する |
| あり | なし | 停止する |
| なし | あり | 停止する |
| なし | なし | 新規作成し、`nobu.pem` に保存する |

AWS側にKey Pairがあるのに `nobu.pem` がない場合、秘密鍵は復元できない。

ローカルに `nobu.pem` だけが残っている場合も、その秘密鍵がAWS側のKey Pairと対応している保証がない。

このような状態で勝手に削除や再作成を行うと、既存EC2へのSSH接続を壊す可能性があるため、スクリプトを停止させて人が確認する設計にしている。

## Key Pair作成

AWS側にもローカルにもKey Pairが存在しない場合だけ、以下のようにKey Pairを作成する。

```bash
aws ec2 create-key-pair \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$KEY_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'KeyMaterial' \
  --output text > "$KEY_FILE"

chmod 400 "$KEY_FILE"
```

`chmod 400` は、秘密鍵ファイルを所有者だけが読める権限にする設定である。

権限が広すぎる場合、SSHクライアントは秘密鍵の利用を拒否することがある。

## 既存Bastionの再利用

再実行時にBastion EC2を重複作成しないため、以下の条件で既存インスタンスを検索する。

```bash
Name=vpc-id,Values="$VPC_ID"
Name=tag:Name,Values="$INSTANCE_NAME"
Name=instance-state-name,Values=pending,running,stopping,stopped
```

判定は以下である。

| 既存Bastion数 | 処理 |
| :--- | :--- |
| 0台 | 新規作成する |
| 1台 | 既存Bastionを再利用する |
| 2台以上 | 重複の可能性があるため停止する |

既存Bastionを再利用する場合は、以下も確認する。

- EC2のKey Pair名が `nobu` であること
- ローカルに `nobu.pem` が存在すること
- `nobu.pem` の権限が `400` にできること

既存Bastionが `stopped` の場合は起動する。

既存Bastionが `stopping` の場合は、停止完了を待ってから起動する。

## AMI取得

新規Bastionを起動する場合、Amazon Linux 2023のAMI IDをSSM Parameter Storeから取得する。

```bash
aws ssm get-parameter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text
```

AMI IDはリージョンや時期によって変わるため、固定値ではなくAWS管理パラメータから取得している。

これにより、東京リージョンで利用できる最新のAmazon Linux 2023 AMIを使ってEC2を起動できる。

## Bastion EC2作成

新規作成時は、以下のようにEC2を起動する。

```bash
aws ec2 run-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_BASTION_ID" \
  --subnet-id "$PUB01_ID" \
  --associate-public-ip-address \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" "ResourceType=volume,Tags=[{Key=Name,Value=$INSTANCE_NAME-root},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Instances[0].InstanceId' \
  --output text
```

ポイントは以下である。

| 設定 | 内容 |
| :--- | :--- |
| `--subnet-id` | Public Subnet 01に配置する |
| `--associate-public-ip-address` | Public IPを付与してSSH接続できるようにする |
| `--security-group-ids` | Bastion用Security Groupを関連付ける |
| `--key-name` | SSH接続用Key Pairを指定する |
| `--metadata-options HttpTokens=required` | IMDSv2を必須にする |
| `ResourceType=volume` | ルートボリュームにもタグを付与する |

## IMDSv2必須化

```bash
--metadata-options "HttpTokens=required,HttpEndpoint=enabled"
```

この設定により、EC2 Instance Metadata ServiceはIMDSv2のトークン必須になる。

IMDSは、インスタンス自身のメタデータやIAM Roleの一時認証情報を取得できる仕組みである。実運用では、SSRFなどのリスク低減のため、IMDSv2必須化が推奨される。

今回のBastionにはまだIAM Roleを付与していないが、早い段階からIMDSv2を必須にすることで、後続拡張時も安全側の構成にできる。

## 実行結果

実行コマンド:

```bash
./07_bastion_server_setup.sh
```

実行時に確認された主なリソースID:

| 種別 | 値 |
| :--- | :--- |
| VPC | vpc-09872a034f259a5f3 |
| Public Subnet | subnet-0d93b924889bb2ede |
| Bastion Security Group | sg-04d7173674c03abb7 |
| Key Pair | nobu |
| 秘密鍵ファイル | nobu.pem |
| AMI | ami-0b53194d9d4d5cfea |
| Instance ID | i-08eb38b7ecffa99d8 |
| Instance Type | t3.micro |
| Public IP | 3.112.3.37 |
| Private IP | 10.0.0.110 |
| State | running |
| Subnet | subnet-0d93b924889bb2ede |

表示されたSSH接続コマンド:

```bash
ssh -i nobu.pem ec2-user@3.112.3.37
```

SSH接続確認では、初回接続時にホスト鍵確認が表示され、`yes` を入力後にAmazon Linux 2023のログインバナーが表示された。

これにより、以下を確認できた。

- Bastion EC2が起動していること
- Public IPが付与されていること
- Bastion用Security GroupのSSH許可が有効であること
- `nobu.pem` がEC2のKey Pairと対応していること
- Amazon Linux 2023へ `ec2-user` でSSH接続できること

## SSH configについて

現時点の接続コマンドは以下である。

```bash
ssh -i /Users/nobu/aws-reference/scripts/nobu.pem ec2-user@3.112.3.37
```

`~/.ssh/config` に登録する場合は、既存の旧環境設定と混ざらないよう、別名のHostにするのが安全である。

例:

```sshconfig
Host awsref-bastion
  HostName 3.112.3.37
  User ec2-user
  IdentityFile /Users/nobu/aws-reference/scripts/nobu.pem
  IdentitiesOnly yes
```

この設定を入れると、以下で接続できる。

```bash
ssh awsref-bastion
```

Web EC2を作成した後は、`ProxyJump awsref-bastion` を使ってPrivate Subnet上のWebサーバーへSSHする構成にする。

## 変更前確認

Bastion作成前には、少なくとも以下を確認する。

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-bastion Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,KeyName:KeyName,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId,VPC:VpcId}' \
  --output table

aws ec2 describe-key-pairs \
  --profile learning \
  --region ap-northeast-1 \
  --key-names nobu \
  --output table
```

確認ポイント:

- 同じNameタグのBastion EC2が既に存在するか
- Bastionが存在する場合、Key Pair名が `nobu` か
- `nobu.pem` がローカルに存在するか
- `nobu.pem` の権限が広すぎないか
- Bastion用Security GroupのSSH許可CIDRが現在の作業元IPと一致しているか
- 対象VPCとPublic Subnetが正しいか

案件作業では、変更前のEC2、Security Group、Key Pair状態を証跡として残すと、変更後比較と切り戻し判断に使いやすい。

## 変更後確認

スクリプト実行後は、以下を確認する。

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8 \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,KeyName:KeyName,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
```

確認ポイント:

- Stateが `running` であること
- Instance Typeが `t3.micro` であること
- KeyNameが `nobu` であること
- Public IPが付与されていること
- Private IPがVPC CIDR内であること
- Subnetが `sample-subnet-public01` であること
- Bastion用Security Groupが関連付いていること
- SSH接続できること

IMDSv2の確認例:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8 \
  --query 'Reservations[0].Instances[0].MetadataOptions' \
  --output table
```

`HttpTokens` が `required` であれば、IMDSv2必須である。

## 切り戻し方法

Bastionを停止する場合:

```bash
aws ec2 stop-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8
```

Bastionを起動する場合:

```bash
aws ec2 start-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8
```

Bastionを削除する場合:

```bash
aws ec2 terminate-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8
```

削除後の確認:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids i-08eb38b7ecffa99d8 \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text
```

`terminated` になれば削除完了である。

Key Pairを削除する場合:

```bash
aws ec2 delete-key-pair \
  --profile learning \
  --region ap-northeast-1 \
  --key-name nobu
```

ただし、Key Pair削除は慎重に行う。削除しても既存EC2上の公開鍵が即座に消えるわけではないが、同じKey Pair名で新規EC2を作成できなくなる。また、ローカル秘密鍵との対応関係を誤るとSSH不能になる。

## cleanup_network.shとの関係

`cleanup_network.sh` は、Bastion EC2をNAT Gateway、Security Group、Subnetより先に削除する。

理由は、EC2がSecurity GroupやSubnetに依存しているためである。

削除順序の考え方:

1. Bastion EC2を終了する
2. Route Tableの関連付けを戻す
3. NAT Gatewayを削除する
4. Elastic IPを解放する
5. Security Groupを削除する
6. Subnetを削除する
7. Internet Gatewayをデタッチして削除する
8. VPCを削除する

現在の削除スクリプトでは、Key Pairとローカル `nobu.pem` は自動削除しない。

Key Pairは秘密鍵との対応が重要であり、自動削除すると次回作業時に混乱しやすいためである。

## 影響範囲

Bastion作成により影響を受ける主な範囲は以下である。

| 対象 | 影響 |
| :--- | :--- |
| Public Subnet | EC2が1台配置される |
| Security Group | Bastion用Security GroupがEC2に関連付く |
| Route Table | Public SubnetのInternet Gateway経路がSSH到達性に影響する |
| Key Pair | EC2 SSH接続に利用される |
| ローカル端末 | `nobu.pem` と `known_hosts` に影響する |
| コスト | EC2稼働時間とEBSボリュームに課金される |

Public IPを持つEC2は外部から到達可能な入口である。Security GroupでSSH接続元を `/32` に絞っていても、鍵管理やパッチ適用、不要時停止などを意識する。

## 気をつける点

- AWS Key Pairの秘密鍵は作成時にしか取得できない
- AWS側Key Pairとローカル `nobu.pem` は対応している必要がある
- Key Pairを無条件削除して作り直すと、既存EC2との対応が壊れる可能性がある
- `nobu.pem` はリポジトリにコミットしない
- `nobu.pem` の権限は `400` にする
- Public IPは停止と起動で変わる可能性がある
- Public IPを固定したい場合はElastic IPを検討する
- `~/.ssh/config` のHostNameはPublic IP変更時に更新が必要になる
- 初回SSH時に `known_hosts` へホスト鍵が保存される
- 同じIPに別インスタンスが割り当てられると、ホスト鍵不一致警告が出ることがある
- BastionのSSH許可CIDRは現在の作業元グローバルIPに依存する
- 作業場所や回線が変わった場合、Security GroupのSSH許可CIDR更新が必要になる
- IMDSv2必須化はセキュリティ上有効だが、古いツールやスクリプトがIMDSv1前提の場合は影響確認が必要になる

## 案件実務ポイント

今回の銀行案件では、影響調査済みのAWS設定変更、テスト、手順書作成が中心になる見込みである。

BastionやEC2の作業では、以下の観点が重要になる。

- 対象アカウント、リージョン、VPCを作業前に確認する
- 変更前のEC2、Security Group、Key Pair状態を証跡として残す
- 既存リソースがある場合は、削除や再作成ではなく影響を確認する
- Key Pairと秘密鍵ファイルの対応関係を崩さない
- SSH許可元CIDRが妥当か確認する
- Public IPを持つEC2が本当に必要か確認する
- 起動後にSSH疎通確認を行う
- 変更後に不要な公開や余計なIngressがないか確認する
- 切り戻しとして停止、終了、Security Groupルール戻しの手順を用意する

説明例:

```text
Bastion EC2はPublic Subnetに配置し、Security Groupで自分のグローバルIP /32 からのSSHのみ許可しています。
Key Pairは無条件削除せず、AWS側Key Pairとローカル秘密鍵の整合性を確認してから利用します。
既存Bastionがある場合は重複作成せず再利用し、停止中であれば起動する再実行耐性を入れています。
```

## 試験対策ポイント

AWS試験では、Bastion、Public Subnet、Private Subnet、Security Group、Key Pair、IMDSv2の関係を整理しておくとよい。

押さえるポイント:

- Public SubnetはInternet Gatewayへのルートを持つSubnetである
- Public IPを持つEC2でも、Security Groupで許可しなければSSHできない
- Private SubnetのEC2にはPublic IPを付けず、BastionやSSM Session Manager経由で管理する
- Security Groupはステートフルである
- Key PairはEC2 SSHログインに使う
- 秘密鍵はAWSから後で再取得できない
- Amazon Linux 2023の標準ユーザーは `ec2-user`
- IMDSv2ではメタデータ取得にトークンが必要になる
- Public IPは停止と起動で変わる可能性がある
- 本番ではBastionの代替としてSSM Session Managerを使う設計もある

## 今後の確認

このスクリプトは再実行耐性を入れているため、再度実行した場合は以下のような挙動になる想定である。

- 既存Bastionが `running` の場合は再利用する
- 既存Bastionが `stopped` の場合は起動する
- 既存Bastionがない場合だけ新規作成する
- 同じNameタグのBastionが複数ある場合は停止する
- AWS側Key Pairとローカル秘密鍵の整合性が取れない場合は停止する

再実行確認コマンド:

```bash
./07_bastion_server_setup.sh
```

今後の拡張として、次の手順でWeb EC2を作成する。

- Private Subnet 01に `sample-ec2-web01` を作成する
- Private Subnet 02に `sample-ec2-web02` を作成する
- Web用Security GroupはBastion用Security GroupからのSSHだけを許可する
- `~/.ssh/config` に `ProxyJump awsref-bastion` を使った接続設定を追加する
- Web EC2がPublic IPを持たないことを確認する

