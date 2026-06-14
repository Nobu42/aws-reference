# Day 23 Learning: 最終リハーサル・説明練習・公開前確認

## 学習開始前に実行するスクリプト

Day 23は最終確認日であり、新しいAWS環境を起動しない。

```text
All_Setup.sh: 実行しない
Ansible: 実行しない
CloudTrail一時Trail: 作成しない
S3 Data Event: 有効化しない
```

残存リソースが気になる場合は、AWS設定を作成する代わりに、既存のクリーンアップ結果とコストを確認する。

```bash
/Users/nobu/aws-reference/scripts/check_cleanup.sh

/Users/nobu/aws-reference/scripts/check_cost.sh
```

## 1. 今日の目的

案件初日に必要な資料、説明、質問、作業姿勢を最終確認し、新しい知識を増やさずに落ち着いて参画できる状態へ整える。

```text
必要資料へ辿る
  -> READMEから目的のリファレンスを短時間で開く

自分の言葉で説明する
  -> 主要AWSサービスと作業の流れを1分で説明する

依頼へ初動する
  -> 対象、目的、承認、影響、Test、切り戻しを確認する

公開状態を確認する
  -> Git差分、不要ファイル、秘密情報、リンクを確認する

参画前の状態を整える
  -> 初日用メモを確認し、十分に休む
```

Day 23ではAWSリソースの構築、変更、削除を行わない。

分からない項目や説明が詰まる項目があっても、新しい長文資料を追加して埋めようとしない。既存資料の場所を確認し、要確認事項として残す。

関連資料:

- [README](../README.md)
- [案件対策ロードマップ](../docs/roadmaps/2026-06-05_to_2026-06-30_project_preparation_roadmap.md)
- [AWS案件 面談メモ](../project.md)
- [Day 17 運用シェル基礎・読解演習](./17_Day_Learning.md)
- [Day 18 AWSセキュリティ横断チェック](./18_Day_Learning.md)
- [Day 19 作業手順書・証跡整理](./19_Day_Learning.md)
- [Day 20 模擬作業1 S3 Bucket Policy変更](./20_Day_Learning.md)
- [Day 21 模擬作業2 GuardDuty Finding・CloudTrail横断調査](./21_Day_Learning.md)
- [Day 22 案件初日準備・受入情報整理](./22_Day_Learning.md)
- [共通AWS CLI・証跡保存リファレンス](../docs/references/00_common_aws_cli_reference.md)
- [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md)
- [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md)

---

## 2. Day 23の位置づけ

| Day | 目的 |
|---|---|
| Day 20 | S3 Bucket Policy変更を開始から報告まで通しで行う |
| Day 21 | GuardDuty Findingを起点に横断調査する |
| Day 22 | 初日に情報を受け取り、安全に最初の作業へ着手する準備を行う |
| Day 23 | 資料、説明、初動、公開状態を最終確認し、余力を残して終了する |

Day 23で避けること:

- 新しいAWSサービスの深掘り
- 新しい大規模ハンズオン
- 未承認のAWS変更操作
- 長い新規リファレンス作成
- 不安を埋めるための無制限な詰め込み
- 睡眠時間を削る学習

最終日に必要なのは、すべてを暗記することではない。

```text
どこを見ればよいか分かる
何を先に確認すべきか分かる
分からないことを適切に質問できる
作業前に止まる条件を説明できる
確認済み事実を短く報告できる
```

---

## 3. 今日の成果物

| 成果物 | 内容 |
|---|---|
| 資料導線確認結果 | READMEから主要資料へ辿れることを確認する |
| 1分説明メモ | 主要サービス・作業を自分の言葉で説明する |
| 模擬初動結果 | 依頼受領から着手前確認までを練習する |
| Repository最終確認結果 | Git差分、不要ファイル、秘密情報、リンクを確認する |
| 初日用メモ | 初日の優先事項、質問、報告、停止条件を1ページ相当にまとめる |
| 残課題 | 初日以降に確認する項目を明確にする |

---

## 4. 今日の時間配分

2時間を目安にし、延長しすぎない。

| 時間 | 内容 |
|---|---|
| 00:00から00:10 | 今日のゴールと停止時刻を確認する |
| 00:10から00:30 | README資料導線リハーサル |
| 00:30から01:05 | 主要サービスの1分説明 |
| 01:05から01:25 | 模擬作業依頼への初動 |
| 01:25から01:45 | Repository公開前確認 |
| 01:45から01:55 | 初日用メモと残課題整理 |
| 01:55から02:00 | 終了確認 |

時間内に終わらない項目は、初日以降の確認事項へ移す。

---

## 5. 最終リハーサルの成功条件

- READMEから主要資料へ迷わず辿れる
- S3、CloudTrail、CloudWatch、GuardDuty、VPC、EC2、RDS、Lambdaを短く説明できる
- MFAなし管理コンソールログイン検知の流れを説明できる
- 設定変更作業の安全な流れを説明できる
- 作業依頼を受けたときの最初の確認事項を説明できる
- Gitの未Commit差分を把握できる
- `.DS_Store`、秘密鍵、Credentialなどの混入を確認できる
- 現場固有情報を公開Repositoryへ残さない姿勢を説明できる
- 初日に確認する質問を優先順位付きで把握できる
- 前日に余力を残して学習を終了できる

---

## 6. README資料導線リハーサル

READMEを入口として、次の依頼に対応する資料を30秒以内に特定する。

| 依頼・質問 | 最初に開く資料 |
|---|---|
| S3の公開設定を確認したい | [S3 Security CLIリファレンス](../docs/references/01_s3_security_cli_reference.md) |
| Bucket Policyを変更したい | [S3 Bucket Policy CLIリファレンス](../docs/references/02_s3_bucket_policy_cli_reference.md) |
| Bucket Policy変更手順書を作りたい | [S3 Bucket Policy変更手順書Template](../docs/templates/s3_bucket_policy_change_procedure_template.md) |
| 誰が設定変更したか調べたい | [CloudTrail CLIリファレンス](../docs/references/03_cloudtrail_cli_reference.md) |
| CloudWatch Alarmを確認したい | [CloudWatch CLIリファレンス](../docs/references/04_cloudwatch_cli_reference.md) |
| GuardDuty Findingを調査したい | [GuardDuty CLIリファレンス](../docs/references/05_guardduty_cli_reference.md) |
| MFAなしLogin検知を説明したい | [MFAなし管理コンソールログイン検知](../docs/references/06_mfa_console_login_detection.md) |
| VPC通信経路を確認したい | [VPC / Network CLIリファレンス](../docs/references/07_vpc_network_cli_reference.md) |
| EC2 Securityを確認したい | [EC2 Security CLIリファレンス](../docs/references/08_ec2_security_cli_reference.md) |
| RDS Securityを確認したい | [RDS Security CLIリファレンス](../docs/references/09_rds_security_cli_reference.md) |
| Lambda Securityを確認したい | [Lambda Security CLIリファレンス](../docs/references/10_lambda_security_cli_reference.md) |
| サービス横断で確認したい | [AWS Security Settings横断チェックリスト](../docs/references/90_aws_security_settings_checklist.md) |
| Networkを横断確認したい | [AWS Network Settings横断チェックリスト](../docs/references/91_aws_network_settings_checklist.md) |
| 変更前から報告まで通しで確認したい | [Day 20 模擬作業1](./20_Day_Learning.md) |
| Finding調査を通しで確認したい | [Day 21 模擬作業2](./21_Day_Learning.md) |
| 初日の質問を確認したい | [Day 22 案件初日準備](./22_Day_Learning.md) |

## リハーサル方法

1. READMEだけを開く
2. 上表の依頼をランダムに1つ選ぶ
3. 該当資料へ辿る
4. 最初に見る章を特定する
5. 資料が見つからなければ、READMEの導線を見直す

## 確認記録

| No. | 依頼 | 開いた資料 | 所要時間 | 結果 | 備考 |
|---:|---|---|---:|---|---|
| 1 | S3公開設定確認 |  |  |  |  |
| 2 | CloudTrail変更履歴 |  |  |  |  |
| 3 | GuardDuty Finding調査 |  |  |  |  |
| 4 | VPC通信影響調査 |  |  |  |  |
| 5 | 初日質問確認 |  |  |  |  |

資料を暗記するのではなく、入口から必要情報へ辿れることを確認する。

---

## 7. 1分説明の型

主要サービスは、次の順序で説明する。

```text
1. 何のためのサービスか
2. 今回の案件で何を確認・変更しそうか
3. 変更前後に何を確認するか
4. 注意すべき影響・証跡は何か
```

1分で説明しきれない場合は、細部を削る。

```text
最初に結論
  -> 主要な確認項目
  -> 変更時の注意
  -> 証跡・監査
```

避ける説明:

- 用語だけを並べる
- AWS公式説明を暗唱する
- 分からない部分を断定する
- 個人ラボの構成を案件環境と同じように話す
- 変更方法だけ説明し、影響・Test・切り戻しを省略する

---

## 8. S3を1分で説明する

```text
S3はObject Storage Serviceで、BucketとObjectを単位にデータを保存します。

Security確認では、Account・Bucket単位のPublic Access Block、
Bucket Policy、Object Ownership、ACL、暗号化、Versioning、
Loggingを確認します。

Bucket Policy変更ではPolicy全体を置換するため、変更前Policyを保存し、
Principal、Action、Resource、Conditionの差分と利用主体への影響を確認します。

変更後はPublic判定、Application動作、CloudTrail変更履歴を確認し、
異常時は変更前Policyへ切り戻します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| `Principal`とは | 誰に対する許可・拒否かを表す |
| `Action`とは | 何のAPI操作を対象とするかを表す |
| `Resource`とは | 対象Bucket・Object ARNを表す |
| `Condition`とは | 許可・拒否を適用する追加条件を表す |
| `IsPublic=False`なら十分か | Policy StatusだけでなくPAB、ACL、Access Pointなども確認する |
| S3はVPC内か | S3はRegional Serviceであり、VPC EndpointなどでPrivate接続できる |

---

## 9. CloudTrailを1分で説明する

```text
CloudTrailはAWS API操作を記録し、誰が、いつ、どのServiceで、
何を実行したかを調査するための監査サービスです。

Event Historyでは直近のManagement Eventを確認でき、
TrailではS3やCloudWatch Logsへ継続的に記録できます。

設定変更後は対象ResourceやEventNameで検索し、
userIdentity、eventTime、sourceIPAddress、requestParameters、
errorCodeなどを確認します。

S3 Object操作などはData Eventの設定が必要な場合があり、
CloudTrailにEventがないことだけで操作がなかったと断定しません。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Management Eventとは | AWSリソースの設定・管理操作 |
| Data Eventとは | S3 Object、Lambda Invokeなどのデータ操作 |
| Event Historyの注意点 | 記録範囲、Region、期間、Data Eventの有無を確認する |
| 変更証跡で見る項目 | EventName、User、Time、Source IP、Request、Error |

---

## 10. CloudWatchを1分で説明する

```text
CloudWatchはMetric、Log、Alarmを使ってAWSリソースやApplicationを
監視するサービスです。

CloudWatch LogsへLogを集約し、Metric Filterで特定パターンを
Custom Metricへ変換し、Alarmで閾値超過を検知できます。

設定確認ではLog Group、保持期間、暗号化、Metric Filter、
Alarm条件、Missing Data、通知先を確認します。

変更後は期待するEventでMetricとAlarmが変化するかを確認し、
通知試験を行う場合は事前承認と関係者連絡を行います。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Metric Filterとは | Log EventのPattern一致をMetricへ変換する設定 |
| Alarmとは | Metricを評価し、OK・ALARM・INSUFFICIENT_DATAを管理する |
| Missing Dataの注意 | `breaching`、`notBreaching`などの扱いで判定が変わる |
| 証跡 | Log、Filter、Alarm設定、State、通知結果 |

---

## 11. GuardDutyを1分で説明する

```text
GuardDutyはCloudTrail、VPC Flow Logs、DNS Logなどの情報を分析し、
不審な操作や通信をFindingとして通知する脅威検知サービスです。

Finding調査では、Type、Severity、対象Resource、Resource Role、
Action、FirstSeen、LastSeen、Countを確認します。

その後、CloudTrail、EC2、IAM、S3、Security Group、Route、
Flow Logsなどへ横断して、影響と継続有無を調査します。

実Findingはサンプルと断定せず、Critical・Highは早めに共有し、
Archive、隔離、Access Key無効化などは承認後に実施します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Resource Role `TARGET` | 対象リソースが不審操作を受けた側 |
| Resource Role `ACTOR` | 対象リソースが不審操作を行った側 |
| Archiveの意味 | 一覧から整理する操作であり、原因解決そのものではない |
| 初動 | 事実、重要度、対象、継続性を確認し、必要なら即時共有する |

---

## 12. MFAなし管理コンソールログイン検知を1分で説明する

```text
AWS Management ConsoleへのLoginは、CloudTrailのConsoleLogin Eventに
記録されます。

CloudTrailをCloudWatch Logsへ連携し、
ConsoleLoginがSuccessで、MFAUsedがNoのEventをMetric Filterで抽出し、
Custom MetricとCloudWatch Alarmで検知します。

設計時はRoot・IAM User・FederationなどのLogin方式、
正常な例外、通知先、誤検知、Test方法を確認します。

検知時はuserIdentity、sourceIPAddress、userAgent、Login結果、
MFA情報、関連操作をCloudTrailで調査します。
```

流れ:

```text
ConsoleLogin
  -> CloudTrail
  -> CloudWatch Logs
  -> Metric Filter
  -> Custom Metric
  -> CloudWatch Alarm
  -> 通知・一次調査
```

---

## 13. VPC・Networkを1分で説明する

```text
VPCはAWS上の論理Networkで、Subnet、Route Table、Security Group、
Network ACL、Internet Gateway、NAT Gateway、VPC Endpointなどを
組み合わせて通信経路と許可範囲を制御します。

通信調査では、Source、Destination、Protocol、Portを整理し、
DNS、Route、Security Group、Network ACL、Endpoint、
対象Serviceの順に確認します。

Subnet名だけでPublic・Privateを判断せず、関連Route Tableと
Public IP、GatewayへのRouteで判断します。

変更時は片方向だけでなく戻り通信、Application影響、
Flow Logs、CloudTrail、切り戻しを確認します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Security Group | StatefulなResource単位の許可制御 |
| Network ACL | StatelessなSubnet単位の許可・拒否制御 |
| Public Subnet | Internet GatewayへのRouteなどを持ち、Public通信可能なSubnet |
| NAT Gateway | Private Subnetから外向き通信を行うために利用する |
| VPC Endpoint | AWS ServiceへInternetを経由せず接続する |
| Flow Logs | Network Interfaceなどの通信メタデータを記録する |

---

## 14. EC2を1分で説明する

```text
EC2はAWS上の仮想Serverです。

Security確認では、Public IP、Subnet、Security Group、IAM Role、
IMDSv2、EBS暗号化、Patch、CloudWatch Agent、Logを確認します。

Web ServerはPrivate Subnetへ配置し、ALBや踏み台など必要な経路だけを
許可する構成が一般的です。

変更時はApplication、接続元、IAM権限、再起動有無、監視、
切り戻しを確認します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| IAM Role | Access KeyをServerへ固定保存せずAWS権限を付与できる |
| IMDSv2 | Token必須のMetadata ServiceでSSRFなどのリスクを軽減する |
| EBS暗号化 | Volume、Snapshotの保存データを保護する |

---

## 15. RDSを1分で説明する

```text
RDSはDatabaseの構築・運用を支援するManaged Serviceです。

Security確認では、Publicly Accessible、Subnet Group、
Security Group、暗号化、Parameter Group、Log Export、
Backup、Multi-AZを確認します。

Private Subnetへ配置し、ApplicationのSecurity Groupなど
必要な接続元からDatabase Portだけを許可する構成を確認します。

設定変更では再起動やFailoverの有無、Application接続、
Backup、監視、切り戻しを確認します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Publicly Accessible | RDSへPublic到達性を持たせる設定 |
| DB Subnet Group | RDSを配置するSubnetの組み合わせ |
| Parameter Group | Database Engineの設定値 |
| Backup確認 | 保持期間、Snapshot、復旧手順を確認する |

---

## 16. Lambdaを1分で説明する

```text
LambdaはServer管理をせずにCodeをEvent駆動で実行するServiceです。

Security確認では、Execution Role、Resource-based Policy、
VPC接続、Environment Variable、KMS暗号化、CloudWatch Logs、
Function URLを確認します。

Function URLやResource Policyで意図せず公開されていないか、
Roleが必要最小権限か、Environment Variableへ秘密情報を
平文保存していないかを確認します。

変更時はTrigger、呼び出し元、Timeout、Concurrency、Log、
Application影響、Version・Aliasによる切り戻しを確認します。
```

追加質問への短い回答:

| 質問 | 回答 |
|---|---|
| Execution Role | Lambda FunctionがAWS Serviceへアクセスする権限 |
| Resource-based Policy | 誰がFunctionを呼び出せるかを制御するPolicy |
| Function URL | LambdaへHTTPS Endpointを提供する機能 |
| VPC接続 | Private Resource接続やNetwork経路へ影響する |

---

## 17. AWS設定変更作業を1分で説明する

```text
AWS設定変更では、最初に対象Account、Region、Resource、
作業目的、承認範囲を確認します。

変更前設定とApplication動作を保存し、利用主体、Network、
権限、監視、業務影響を確認します。

承認済みの差分だけを適用し、変更後は設定、Application、
CloudTrail、監視を確認します。

異常時は後続作業を止め、現在状態と証跡を保存して、
承認された切り戻し手順を実施します。

最後に最終状態、証跡、影響、残課題を報告します。
```

作業の型:

```text
対象確認
  -> 変更前確認
  -> 影響調査
  -> 承認確認
  -> 設定変更
  -> 設定確認
  -> Application Test
  -> CloudTrail・監視確認
  -> 切り戻しまたは完了
  -> 証跡・報告
```

---

## 18. 手順書・証跡を1分で説明する

```text
作業手順書は、誰が実施しても対象を誤らず、
異常時に止まり、同じ結果を確認できるようにする文書です。

対象、目的、影響、変更前確認、1操作ごとの手順、
期待結果、異常時対応、変更後Test、切り戻し、証跡を記載します。

証跡はScreenshotだけでなく、CLI出力、Diff、CloudTrail、
Application Test、承認・報告記録を組み合わせます。

秘密情報や個人情報を含めず、手順No.と証跡名を対応させ、
何を確認した証跡か説明できる状態にします。
```

---

## 19. 運用Shellを1分で説明する

```text
既存の運用Shellを確認する場合は、最初にEntry point、main、
source先、conf、引数を確認します。

次に、mainから呼ばれる関数、AWS CLI実行箇所、戻り値、
stderr、Log、最終Exit codeを追います。

変更が必要な場合は、既存の命名、Error処理、Return code、
Multi-account切替、Job管理方式へ合わせます。

新しいToolへの置き換えから始めず、現在の処理と影響を
理解してから最小範囲で対応します。
```

---

## 20. 1分説明の自己評価

各説明を声に出し、1分以内で話す。

| 項目 | 1分以内 | 自分の言葉 | 影響・証跡を含む | 曖昧な点 |
|---|---|---|---|---|
| S3 |  |  |  |  |
| CloudTrail |  |  |  |  |
| CloudWatch |  |  |  |  |
| GuardDuty |  |  |  |  |
| MFAなしLogin検知 |  |  |  |  |
| VPC・Network |  |  |  |  |
| EC2 |  |  |  |  |
| RDS |  |  |  |  |
| Lambda |  |  |  |  |
| AWS設定変更 |  |  |  |  |
| 手順書・証跡 |  |  |  |  |
| 運用Shell |  |  |  |  |

説明できなかった項目は、該当リファレンスの入口だけ確認する。全文を読み直さない。

---

## 21. 模擬依頼への初動リハーサル

次の依頼を受けた想定で、設定変更前までの初動を10分で整理する。

```text
S3バケットのセキュリティ指摘について、
Bucket Policyを修正する手順書を作成してください。

影響調査は概ね完了しています。
対象は複数ありますが、まず1件目をお願いします。
```

## 最初に確認すること

```text
対象Account:
Environment:
Region:
対象Bucket:
指摘内容:
変更前Policy:
変更後Policy:
承認済み範囲:
影響調査資料:
利用Principal・Service:
Application Test:
切り戻し:
証跡Rule:
期限:
Reviewer:
```

## 初回返信例

```text
S3 Bucket Policy修正手順書の作成依頼を受領しました。

まず1件目について、対象Account・Region・Bucket、
指摘内容、変更前後Policy、影響調査結果、Test・切り戻し条件を確認します。

確認後、変更前確認、変更手順、変更後Test、切り戻し、
証跡一覧を含む手順書を作成し、レビューを依頼します。

現時点では設定変更を実施しません。
```

## 初動の成功条件

- 作業対象を推測していない
- 「影響調査済み」を無条件に信用せず資料を確認する
- 手順書作成と設定変更を区別している
- Test、切り戻し、証跡を最初から含めている
- Reviewerと期限を確認する
- 設定変更未実施を明記する

---

## 22. 模擬異常への初動リハーサル

次の状況を想定する。

```text
手順書に記載されたBucket Policyと、
Webコンソールで確認した現在Policyが一致しない。
```

## 対応

1. 設定変更へ進まない
2. 現在Policyを証跡として保存する
3. 手順書の前提と異なる差分を整理する
4. CloudTrailで直近変更を確認する
5. 現在状態、差分、影響、確認依頼を報告する
6. 回答・承認後に手順書を更新する

## 報告例

```text
S3 Bucket Policy変更の事前確認で、
手順書記載の変更前Policyと現在Policyが一致しないことを確認しました。

対象:
<account / region / bucket>

差分:
<difference>

現在状態:
設定変更は未実施です。

対応:
現在PolicyとCloudTrail変更履歴を確認しています。
変更前提と実施可否について確認をお願いします。
```

---

## 23. Repository最終確認の方針

Repository確認の目的は、差分をすべてなくすことではない。

目的:

- 自分が何を変更したか把握する
- 不要ファイルをCommitしない
- 秘密情報・案件固有情報を公開しない
- READMEから主要資料へ辿れる
- Markdownの明らかな崩れを確認する

行わないこと:

- 内容を確認せず`git add .`する
- 既存の未Commit変更を消す
- 秘密情報らしき値をそのまま共有する
- 前日に大規模な整理・移動を行う
- 動作確認なしでScriptを修正する

---

## 24. Git状態を確認する

```bash
git status --short
```

確認すること:

- `M`: 変更済みTracked File
- `??`: 未Tracked File
- `D`: 削除されたFile
- 想定外の変更がないか
- 自分が内容を説明できるか

差分の要約:

```bash
git diff --stat
```

差分の形式確認:

```bash
git diff --check
```

Staging済み差分がある場合:

```bash
git diff --cached --stat
```

注意:

```text
git statusがDirty
  !=
問題

内容を把握できない変更をCommit・Pushする
  =
問題
```

---

## 25. 不要ファイル・秘密情報候補を確認する

## Ignore設定

```bash
git check-ignore -v .DS_Store day-learning/.DS_Store scripts/example.pem 2>/dev/null
```

## Tracked不要ファイル候補

```bash
git ls-files \
  | grep -E '(^|/)\.DS_Store$|\.pem$|\.key$|\.p12$|\.pfx$|(^|/)\.env$' \
  || true
```

## Working Treeの不要ファイル候補

```bash
find . -type f \
  \( -name '.DS_Store' \
     -o -name '*.pem' \
     -o -name '*.key' \
     -o -name '*.p12' \
     -o -name '*.pfx' \
     -o -name '.env' \) \
  -print
```

## 秘密情報らしい文字列の確認

次の検索は候補を見つけるためのものであり、検出結果が必ず秘密情報とは限らない。

```bash
git grep -n -I -E \
  'AKIA[0-9A-Z]{16}|aws_secret_access_key|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|password[[:space:]]*=' \
  -- ':!day-learning/23_Day_Learning.md' \
  || true
```

確認時の注意:

- 検出結果をChatや外部AIへ貼らない
- 本物のCredentialを見つけた場合は、先に無効化・Rotation・報告を検討する
- File削除だけでGit履歴から秘密情報が消えたと判断しない
- Exampleや説明文の検出と実Credentialを区別する
- AWS Account ID、ARN、IP、個人情報も公開範囲を確認する

---

## 26. Git管理対象を確認する

Tracked File一覧:

```bash
git ls-files \
  | sort
```

Day Learning一覧:

```bash
git ls-files 'day-learning/*_Day_Learning.md' \
  | sort
```

主要リファレンス一覧:

```bash
git ls-files 'docs/references/*.md' \
  | sort
```

空のDay Learning File確認:

```bash
find day-learning -maxdepth 1 \
  -name '*_Day_Learning.md' \
  -type f \
  -size 0 \
  -print \
  | sort
```

空Fileが存在しても、将来用Placeholderなら直ちに異常とは限らない。READMEから未完成Fileへ案内していないかを確認する。

---

## 27. Markdownとリンクを確認する

末尾空白などの差分問題:

```bash
git diff --check
```

Markdown File一覧:

```bash
find . -type f -name '*.md' -print \
  | sort
```

READMEのDay Learningリンク確認:

```bash
grep -n 'Day 2[0-3]' README.md
```

目視確認:

- Heading階層が不自然ではないか
- Code Fenceが閉じているか
- Tableが崩れていないか
- Link先が存在するか
- READMEから主要資料へ辿れるか
- 現場固有情報を含んでいないか

最終日に大規模なMarkdown整形は行わない。明らかな誤りだけを直す。

---

## 28. 公開前の内容確認

## 公開してよい内容

- 個人ラボの一般化した構成
- AWS CLI・Webコンソールの一般的な確認手順
- 自分で作成したScript・設計・学習資料
- Example値を使ったPolicy・Command
- 一般化した手順書・証跡・報告の考え方

## 公開しない内容

- 現在・過去案件の実資料
- 顧客・銀行・上位会社の内部情報
- 現場固有のShell、conf、Policy、設計値
- Account、Role、User、Resourceの実識別子
- Credential、Password、Token、Private Key
- 実際のFinding、障害、脆弱性
- 個人情報、連絡先、集合案内

## 公開判断

```text
自分で作ったか
  -> Noなら公開しない

一般化されているか
  -> Noなら公開しない

案件・個人・Credentialを特定できないか
  -> 特定できるなら公開しない

公開範囲に必要な内容か
  -> 不要なら公開しない
```

---

## 29. Commit・Push前の確認

Day 23では、必ずCommit・Pushすることを完了条件にしない。内容を把握し、ユーザー自身が実施時期を判断する。

確認Command:

```bash
git status --short
```

```bash
git diff --stat
```

```bash
git diff --check
```

Staging後に確認する場合:

```bash
git diff --cached --stat
```

```bash
git diff --cached --check
```

確認事項:

- Commit対象を説明できる
- 不要Fileを含まない
- 秘密情報・案件情報を含まない
- Markdown Linkと主要内容を確認済み
- 関係ない変更を混ぜていない
- Commit Messageが変更内容を表している
- Push先Branch・Remoteを確認する

---

## 30. 初日に持つ短い作業姿勢

```text
1. Account、Region、Role、対象を確認する
2. 現場の既存手順とRuleを確認する
3. 変更前状態と影響範囲を確認する
4. 不明点は作業への影響を添えて質問する
5. 承認済み差分だけを変更する
6. 設定、Application、CloudTrail、監視を確認する
7. 異常時は止めて、現在状態と証跡を共有する
8. 最終状態、証跡、残課題を報告する
```

---

## 31. 初日用メモ

公開Repositoryには現場固有値を記載しない。実際の確認結果は現場指定の保存先へ記録する。

```text
初日の優先事項:
1. セキュリティ・情報管理Rule
2. 端末・Account・Tool・資料
3. 体制、Reviewer、承認、報告先
4. 最初の作業依頼

作業前確認:
Account / Environment / Region / Role / Resource
目的 / 承認 / 変更前 / 影響 / Test / 切り戻し / 証跡

停止条件:
対象、承認、期待結果、Test、切り戻し、証跡が不明
現在状態が手順書と異なる
想定外Error・影響が発生

報告:
結論 / 対象 / 確認済み事実 / 現在状態 / 要確認 / 次の行動

初日に確認:
GUI・CLI・既存Shellの利用方式
手順書・証跡Template
S3対象一覧と優先順位
CloudTrail・CloudWatch・GuardDutyの利用状況
```

---

## 32. 分からない質問を受けたときの答え方

分からないことを無理に答えない。

```text
現時点では正確に回答できないため、対象環境の設定と資料を確認します。

確認観点としては、<viewpoint>を想定しています。
確認後、事実と影響を整理して共有します。
```

部分的に分かる場合:

```text
一般的には<general-answer>です。

ただし、今回の環境では<environment-specific-item>によって変わるため、
現在設定と運用要件を確認してから判断します。
```

避ける回答:

- 推測を事実として断定する
- 知らないことを隠す
- 一般論だけで現場設定を変更する
- 調べる期限や次の行動を示さない

---

## 33. 初日の質問を最終確認する

## 最優先

1. 情報管理・Screenshot・File持ち込みルール
2. 最初の作業と期限
3. 作業依頼・手順書・証跡の保存先
4. 技術確認先、Reviewer、承認者、切り戻し判断者
5. AWS Account、Environment、Region、Roleの確認方法

## 作業開始前

1. GUI、AWS CLI、既存Shellのどれを使うか
2. 変更前後の期待値
3. 影響調査済み資料と未確認事項
4. Application Test担当と項目
5. 証跡、CloudTrail、完了報告の必須項目

## 必要時

1. 共通関数Shell、conf、JP1の有無
2. Multi-account切替方式
3. GuardDuty、Security Hub、AWS Configの運用
4. GitHub、外部Web、AIの利用範囲
5. Bridge Serverの利用方法

初日に全質問を一度に行わない。説明済み内容を確認し、作業に必要な順で質問する。

---

## 34. 最終自己評価

| No. | 評価項目 | OK / 要確認 | 次の行動 |
|---:|---|---|---|
| 1 | S3 Bucket Policy変更の流れを説明できる |  |  |
| 2 | S3 Security確認項目を説明できる |  |  |
| 3 | CloudTrailで変更履歴を追う流れを説明できる |  |  |
| 4 | CloudWatch Logs・Metric Filter・Alarmを説明できる |  |  |
| 5 | MFAなしLogin検知を説明できる |  |  |
| 6 | GuardDuty Finding初動を説明できる |  |  |
| 7 | VPC・Route・SG・NACLの確認順を説明できる |  |  |
| 8 | EC2・RDS・LambdaのSecurity確認項目を説明できる |  |  |
| 9 | 手順書、Test、切り戻し、証跡を説明できる |  |  |
| 10 | Teamsで質問・進捗・異常を報告できる |  |  |
| 11 | 既存運用Shellの読み始め方を説明できる |  |  |
| 12 | READMEから必要資料へ辿れる |  |  |
| 13 | 公開してはいけない情報を説明できる |  |  |
| 14 | 分からない場合の確認方法を説明できる |  |  |

`要確認`が残っていても問題ない。案件初日に質問・確認できる形へ整理されていればよい。

---

## 35. 要確認事項

案件参画後、次を確認する。

- 自分の担当範囲と最初の作業
- S3変更対象一覧、優先順位、共通差分
- 作業依頼、手順書、証跡、報告の正式な保存先
- GUI、AWS CLI、既存Shellの利用方式
- Account、Environment、Region、Roleの確認方法
- Reviewer、承認者、切り戻し判断者
- Application Test担当とTest項目
- CloudTrail、CloudWatch、GuardDuty、Security Hub、AWS Configの利用状況
- 共通関数Shell、conf、JP1、Multi-account方式の有無
- GitHub、外部Web、AI、Bridge Serverの利用ルール
- Screenshot・Mask・証跡命名ルール
- 日次・週次・顧客向け報告の形式

---

## 36. 前日の終了条件

次を満たしたら学習を終了する。

- READMEから主要資料へ辿れる
- 主要サービスの説明を一度声に出した
- 初日の優先質問を確認した
- 初日用メモを確認した
- Repositoryの現在状態を把握した
- 不要ファイル・秘密情報候補を確認した
- 翌日の予定・持ち物・連絡方法を確認した
- 新しい作業へ着手していない
- 残課題を要確認事項へ移した
- 十分に休める時間を確保した

```text
もう少し勉強できる
```

ではなく、

```text
明日、落ち着いて確認・相談・報告できる
```

状態で終了する。

---

## 37. Day 23完了チェックリスト

### 資料導線

- [ ] READMEからS3資料へ辿った
- [ ] READMEからCloudTrail資料へ辿った
- [ ] READMEからCloudWatch資料へ辿った
- [ ] READMEからGuardDuty資料へ辿った
- [ ] READMEからVPC資料へ辿った
- [ ] READMEから初日準備資料へ辿った

### 説明練習

- [ ] S3を1分で説明した
- [ ] CloudTrailを1分で説明した
- [ ] CloudWatchを1分で説明した
- [ ] GuardDutyを1分で説明した
- [ ] MFAなしLogin検知を1分で説明した
- [ ] VPC・Networkを1分で説明した
- [ ] EC2を1分で説明した
- [ ] RDSを1分で説明した
- [ ] Lambdaを1分で説明した
- [ ] AWS設定変更を1分で説明した
- [ ] 手順書・証跡を1分で説明した
- [ ] 運用Shellを1分で説明した

### 初動・報告

- [ ] 模擬S3依頼への初動を整理した
- [ ] 手順書と現在設定が異なる場合の停止・報告を説明した
- [ ] 分からない質問への答え方を確認した
- [ ] 初日の質問を優先順位付きで確認した
- [ ] 初日用メモを確認した

### Repository確認

- [ ] `git status --short`で現在状態を確認した
- [ ] `git diff --stat`で差分概要を確認した
- [ ] `git diff --check`を確認した
- [ ] `.DS_Store`など不要Fileを確認した
- [ ] Private Key・Credential候補を確認した
- [ ] 公開してはいけない現場情報を含まないことを確認した
- [ ] READMEから主要資料へ辿れることを確認した

### 終了

- [ ] 残課題を要確認事項へ移した
- [ ] 新しい大規模作業へ着手していない
- [ ] 翌日の予定・持ち物・連絡方法を確認した
- [ ] 学習を終了し、休む準備ができた

## Day 23の完了条件

次を自分の言葉で説明できればDay 23は完了とする。

```text
案件初日に必要なのは、すべてのAWS設定を暗記していることではなく、
対象、目的、承認、影響、Test、切り戻し、証跡を確認し、
分からない点を適切に質問できることである。

AWS設定変更では、変更前状態を保存し、承認済み差分だけを適用し、
設定、Application、CloudTrail、監視を確認する。
異常時は後続作業を止め、現在状態と証跡を共有して判断を求める。

必要な技術情報はREADMEとリファレンスから辿る。
現場固有情報は現場指定の保存先で扱い、個人Repositoryや個人AIへ
持ち出さない。

前日は新しい知識を詰め込まず、初日に落ち着いて確認、相談、
報告できる余力を残して終了する。
```
