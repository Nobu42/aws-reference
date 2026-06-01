# 18_ses_receiving_setup.sh 解説

## 概要

`18_ses_receiving_setup.sh` は、Amazon SESで独自ドメイン宛メールを受信し、受信メールをS3へ保存するためのスクリプトである。

SESは通常のメールボックスを持つサービスではない。

そのため、SESで受信したメールはReceipt Ruleに従って、S3、SNS、Lambdaなどへ配送する。

今回の構成では、以下のメールアドレス宛のメールをS3へ保存する。

```text
inquiry@nobu-iac-lab.com
```

作成または設定する主なリソースは以下である。

| 種別 | 名前 | 用途 |
| :--- | :--- | :--- |
| S3 Bucket | `nobu-iac-lab-mailbox` | SES受信メールの保存先 |
| S3 Prefix | `inbox/` | 受信メール保存先のキーPrefix |
| SES Receipt Rule Set | `sample-ruleset` | 受信ルールのまとまり |
| SES Receipt Rule | `sample-rule-inquiry` | `inquiry@nobu-iac-lab.com` 宛メールをS3へ保存 |
| Route 53 MX | `nobu-iac-lab.com` | ドメイン宛メールをSES受信エンドポイントへ配送 |

## 前提条件

このスクリプトを実行する前に、以下が準備されている必要がある。

| 項目 | 内容 |
| :--- | :--- |
| Public Hosted Zone | `nobu-iac-lab.com.` がRoute 53で管理されている |
| SES Domain Identity | `nobu-iac-lab.com` がSESで検証済み |
| SES Region | `ap-northeast-1` を使う |
| 受信対象 | `inquiry@nobu-iac-lab.com` |

東京リージョン `ap-northeast-1` はSES受信に対応しており、受信エンドポイントは以下である。

```text
inbound-smtp.ap-northeast-1.amazonaws.com
```

## スクリプト全体の流れ

このスクリプトは、次の順番で処理を行う。

1. Bashの安全設定を有効にする
2. AWS CLIプロファイル、リージョン、ドメイン名、受信先S3バケット名を定義する
3. LocalStack向けの設定が残っていないように無効化する
4. 実行対象のAWSアカウントとIAMユーザーを確認する
5. Route 53 Public Hosted Zoneを取得する
6. 受信メール保存用S3バケットを作成または再利用する
7. S3 Public Access Blockを有効化する
8. S3 ACLを無効化する
9. S3デフォルト暗号化を有効化する
10. SESがS3へPutObjectできるようにバケットポリシーを設定する
11. SES Receipt Rule Setを作成または再利用する
12. SES Receipt Ruleを作成または更新する
13. Receipt Rule SetをActiveにする
14. Route 53にMXレコードを作成または更新する
15. Receipt Rule Set、Active Rule Set、MXレコードを確認する

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

メール受信設定は、DNS、S3、SESの複数サービスにまたがる。

途中で失敗したまま進むと、メールが届かない、S3に保存されない、意図しないRule SetがActiveになるなどの問題につながるため、失敗時点で停止する。

## 共通変数

```bash
PROFILE="learning"
REGION="ap-northeast-1"

DOMAIN_NAME="nobu-iac-lab.com"
DOMAIN_NAME_DOT="${DOMAIN_NAME}."

MAIL_BUCKET_NAME="nobu-iac-lab-mailbox"
MAIL_OBJECT_PREFIX="inbox/"

RULE_SET_NAME="sample-ruleset"
RULE_NAME="sample-rule-inquiry"

RECIPIENT_EMAIL="inquiry@${DOMAIN_NAME}"

MX_RECORD_NAME="${DOMAIN_NAME}"
MX_RECORD_VALUE="10 inbound-smtp.${REGION}.amazonaws.com"
```

今回の受信先は `inquiry@nobu-iac-lab.com` のみである。

ドメイン全体ではなく、Receipt Ruleの `Recipients` で特定アドレスだけを対象にしている。

## 安全装置

このスクリプトには、MXレコードやActive Receipt Rule Setの上書きを避けるための安全装置を入れている。

```bash
ALLOW_REPLACE_MX="${ALLOW_REPLACE_MX:-false}"
ALLOW_REPLACE_ACTIVE_RULE_SET="${ALLOW_REPLACE_ACTIVE_RULE_SET:-false}"
```

既存MXレコードが想定値と違う場合、通常は停止する。

また、別のReceipt Rule SetがActiveな場合も停止する。

明示的に置き換えたい場合だけ、以下のように実行する。

```bash
ALLOW_REPLACE_MX=true ALLOW_REPLACE_ACTIVE_RULE_SET=true ./18_ses_receiving_setup.sh
```

MXレコードはメール配送先そのものを決めるため、実運用では必ず変更前確認が必要である。

## Public Hosted Zoneの確認

MXレコードを作成するため、Route 53のPublic Hosted Zoneを取得する。

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`]"
```

Private Hosted Zoneと取り違えないように、`Config.PrivateZone==false` でPublic Hosted Zoneだけを対象にする。

今回のHosted Zone IDは以下である。

```text
Z02886402CZFSQE5OSSQ
```

## S3バケット

受信メール保存用に、以下のS3バケットを作成または再利用する。

```text
nobu-iac-lab-mailbox
```

受信メールは以下のPrefixへ保存する。

```text
s3://nobu-iac-lab-mailbox/inbox/
```

S3バケットには以下の設定を行う。

| 設定 | 内容 |
| :--- | :--- |
| Public Access Block | すべて有効 |
| Object Ownership | `BucketOwnerEnforced` |
| ACL | 無効 |
| Default Encryption | SSE-S3 |
| Bucket Policy | SESからのPutObjectのみ許可 |
| Secure Transport | TLS以外のS3アクセスを拒否 |

受信メールには本文、送信者、宛先、件名、添付ファイルなどが含まれる可能性があるため、S3側は強めに保護する。

## S3 Bucket Policy

SESがS3へ受信メールを書き込めるように、バケットポリシーを設定する。

許可するPrincipalはSESサービスである。

```json
"Principal": {
  "Service": "ses.amazonaws.com"
}
```

許可するActionは `s3:PutObject` である。

また、Conditionで以下を制限する。

| Condition | 目的 |
| :--- | :--- |
| `aws:SourceAccount` | 自分のAWSアカウントからのSES操作に限定する |
| `aws:SourceArn` | 指定したReceipt Ruleからの書き込みに限定する |
| `aws:SecureTransport` | TLSではないS3アクセスを拒否する |

今回のSourceArnは以下である。

```text
arn:aws:ses:ap-northeast-1:445405559057:receipt-rule-set/sample-ruleset:receipt-rule/sample-rule-inquiry
```

## Receipt Rule Set

Receipt Rule Setは、SESで受信したメールに対する処理ルールをまとめる単位である。

今回作成または再利用するRule Setは以下である。

```text
sample-ruleset
```

SESでメール受信処理を有効にするには、対象のRule SetをActiveにする必要がある。

今回の実行では、`sample-ruleset` がActiveになった。

```text
Active Receipt Rule Set: sample-ruleset
```

## Receipt Rule

Receipt Ruleは、どの宛先のメールをどのように処理するかを定義する。

今回のRuleは以下である。

| 項目 | 値 |
| :--- | :--- |
| Rule Name | `sample-rule-inquiry` |
| Enabled | `True` |
| Recipient | `inquiry@nobu-iac-lab.com` |
| TlsPolicy | `Optional` |
| ScanEnabled | `True` |
| Action | S3Action |
| S3 Bucket | `nobu-iac-lab-mailbox` |
| ObjectKeyPrefix | `inbox/` |

`ScanEnabled` を有効にすることで、SESのスパム・ウイルススキャンを有効にしている。

`TlsPolicy` は `Optional` としている。

これは、TLSを使わない送信元からも受信できるようにするためである。

厳格な運用では、要件に応じて `Require` を検討する。

## MXレコード

Route 53に以下のMXレコードを作成する。

| 項目 | 値 |
| :--- | :--- |
| Name | `nobu-iac-lab.com.` |
| Type | MX |
| TTL | 300 |
| Value | `10 inbound-smtp.ap-northeast-1.amazonaws.com` |

MXレコードは、ドメイン宛メールをどのメールサーバーへ配送するかを決める。

今回のMXレコードにより、`nobu-iac-lab.com` 宛のメールはSES東京リージョンの受信エンドポイントへ配送される。

確認コマンド:

```bash
dig MX nobu-iac-lab.com
```

今回の実行結果:

```text
nobu-iac-lab.com. 300 IN MX 10 inbound-smtp.ap-northeast-1.amazonaws.com.
```

## 実行結果

今回の実行結果の要点は以下である。

| 項目 | 値 |
| :--- | :--- |
| AWS Account | `445405559057` |
| Region | `ap-northeast-1` |
| Public Hosted Zone | `Z02886402CZFSQE5OSSQ` |
| Active Rule Set | `sample-ruleset` |
| Receipt Rule | `sample-rule-inquiry` |
| Recipient | `inquiry@nobu-iac-lab.com` |
| S3 Bucket | `nobu-iac-lab-mailbox` |
| S3 Prefix | `inbox/` |
| MX | `10 inbound-smtp.ap-northeast-1.amazonaws.com` |

Active Receipt Rule Setの確認結果:

```text
Name: sample-ruleset
Rule: sample-rule-inquiry
Enabled: True
ScanEnabled: True
TlsPolicy: Optional
Action: S3Action
Bucket: nobu-iac-lab-mailbox
ObjectKeyPrefix: inbox/
Recipient: inquiry@nobu-iac-lab.com
```

S3には以下のオブジェクトが作成された。

```text
2026-06-02 05:22:33        645 AMAZON_SES_SETUP_NOTIFICATION
2026-06-02 05:24:08      10864 8ef0knkbpibsl3mjri281hcj1blkigiisbak8ug1
```

`AMAZON_SES_SETUP_NOTIFICATION` は、SESがS3受信設定を確認するために配置する通知ファイルである。

`8ef0knkbpibsl3mjri281hcj1blkigiisbak8ug1` が、実際に受信したメール本文である。

## 動作確認

### MX確認

```bash
dig MX nobu-iac-lab.com
```

期待値:

```text
10 inbound-smtp.ap-northeast-1.amazonaws.com.
```

### Active Receipt Rule Set確認

```bash
aws ses describe-active-receipt-rule-set \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

`sample-ruleset` がActiveで、`sample-rule-inquiry` がEnabledになっていることを確認する。

### S3保存確認

```bash
aws s3 ls s3://nobu-iac-lab-mailbox/inbox/ \
  --profile learning
```

受信メールが届いていれば、`inbox/` 配下にオブジェクトが増える。

### メール本文確認

本文の先頭だけ確認する場合は以下を使う。

```bash
aws s3 cp s3://nobu-iac-lab-mailbox/inbox/<OBJECT_KEY> - \
  --profile learning | head -n 40
```

メール本文には個人情報が含まれる可能性があるため、確認結果をチャットやGitHubへ貼り付けない。

## クリーンアップ時の注意

SES受信設定を使わない日は、以下を削除または無効化する。

| 対象 | 理由 |
| :--- | :--- |
| MXレコード | ドメイン宛メールがSESへ配送され続けるため |
| Active Receipt Rule Set | SES受信処理が有効なままになるため |
| S3受信メールバケット | 受信メール本文が残るため |

このスクリプトは受信テストを行う日だけ実行する。

毎日の通常構築では実行しない。

## 案件対策としてのポイント

この手順は、銀行案件の「AWSセキュリティ・ネットワーク最適化・改善」「影響調査や設定変更、手順書作成」と非常に相性が良い。

特に重要な観点は以下である。

| 観点 | 内容 |
| :--- | :--- |
| 影響調査 | MX変更によりドメイン宛メールの配送先が変わる |
| 設定変更 | Route 53、SES Receipt Rule、S3 Bucket Policyを変更する |
| セキュリティ | 受信メールを保存するS3を非公開・暗号化・TLS必須にする |
| 誤作業防止 | Public Hosted Zoneを1件に特定する |
| 監査 | 受信メールの保存先、Rule Set、Rule、MX値を記録する |
| 個人情報保護 | メール本文や添付ファイルがS3に保存される点を意識する |
| 切り戻し | MX削除、Rule Set無効化、S3オブジェクト削除の手順を用意する |

MX変更は、見た目はDNSレコード1つの変更だが、業務影響は大きい。

誤って本番ドメインのMXを変更すると、利用者やシステムからのメールが想定外の配送先へ流れる。

そのため、実務では以下を必ず確認する。

1. 変更対象ドメイン
2. 変更前MX
3. 変更後MX
4. TTL
5. 受信先システム
6. 切り戻し手順
7. 受信テスト結果

## 試験対策としてのポイント

AWS Advanced NetworkingやSolutions Architectの観点では、以下を押さえる。

- SESは送信だけでなく受信もできる
- SES受信ではMXレコードをSES受信エンドポイントへ向ける
- SES受信メールはS3、SNS、Lambdaなどへ配送できる
- Receipt Rule SetをActiveにしないと受信処理は動かない
- 受信関連リソースは基本的にSES受信エンドポイントと同じリージョンに置く
- S3バケットポリシーでSESからのPutObjectを許可する必要がある
- 受信メールは機密情報を含む可能性があるため、S3の公開制御と暗号化が重要である

## 次に確認すること

受信確認後は、以下を確認する。

```bash
aws s3 ls s3://nobu-iac-lab-mailbox/inbox/ \
  --profile learning
```

不要になったら、MXレコードと受信メール保存S3バケットを削除する。

次に進む場合は、受信したメールをLambdaで処理する構成や、S3イベント通知、CloudWatch Logs連携を試すと、案件対策としてさらに実務寄りになる。
