# 17 SES Send Mail Test

## 目的

Amazon SESのSMTPインターフェースを利用して、Pythonスクリプトからメールを送信する。

この手順では、SESで検証済みの送信元 `no-reply@nobu-iac-lab.com` から、検証済みの送信先 `nobu4071@icloud.com` へテストメールを送信する。

## 実行環境

この手順は以下の環境で検証している。

- 実行環境: Mac
- AWSリージョン: ap-northeast-1
- Python: Python 3
- 対象サービス: Amazon SES SMTP Interface
- 前提:
  - SES Domain Identity `nobu-iac-lab.com` が作成済みであること
  - DKIM / SPF / DMARC レコードがRoute 53に登録済みであること
  - Email Address Identity `nobu4071@icloud.com` が検証済みであること
  - SES SMTP credentials が作成済みであること
  - SES sandbox中の場合、送信先メールアドレスも検証済みであること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| SMTPサーバー | email-smtp.ap-northeast-1.amazonaws.com |
| SMTPポート | 587 |
| 暗号化 | STARTTLS |
| 認証方式 | SMTP Username / SMTP Password |
| 送信元 | no-reply@nobu-iac-lab.com |
| 送信先 | nobu4071@icloud.com |
| 件名 | SMTP経由での電子メールのテスト |
| 本文 | SMTPのテスト |

## スクリプト

- [17_sendmail_test.py](../../scripts/17_sendmail_test.py)

## 認証情報の扱い

SMTP認証情報は秘密情報のため、Pythonスクリプトには直接書かない。
実行前に環境変数として設定する。

```bash
export SES_SMTP_USER='SMTP username'
export SES_SMTP_PASSWORD='SMTP password'
```

この値はGitHub、README、Markdown、スクリーンショットに載せない。

## 実行コマンド

```bash
cd scripts
python3 17_sendmail_test.py
```

## Pythonスクリプトの概要

スクリプトでは以下を行う。

1. 環境変数からSMTP Username / SMTP Passwordを読み込む
2. SES SMTP endpointへ587番ポートで接続する
3. STARTTLSで通信を暗号化する
4. SMTP認証を行う
5. MIME形式のメール本文を作成する
6. `no-reply@nobu-iac-lab.com` から `nobu4071@icloud.com` へメールを送信する
7. SMTP接続を終了する

## 実行結果

PythonスクリプトからSES SMTP endpointへ接続し、メール送信に成功した。

実行ログの一部を以下に示す。
認証情報を含む可能性がある部分はマスクしている。

```text
send: 'ehlo ****************************************\r\n'
reply: b'250-email-smtp.amazonaws.com\r\n'
reply: b'250-8BITMIME\r\n'
reply: b'250-STARTTLS\r\n'
reply: b'250-AUTH PLAIN LOGIN\r\n'
reply: b'250 Ok\r\n'

send: 'STARTTLS\r\n'
reply: b'220 Ready to start TLS\r\n'

send: 'ehlo ****************************************\r\n'
reply: b'250-email-smtp.amazonaws.com\r\n'
reply: b'250-8BITMIME\r\n'
reply: b'250-AUTH PLAIN LOGIN\r\n'
reply: b'250 Ok\r\n'

send: 'AUTH PLAIN ********'
reply: b'235 Authentication successful.\r\n'

send: 'mail FROM:<no-reply@nobu-iac-lab.com>\r\n'
reply: b'250 Ok\r\n'

send: 'rcpt TO:<nobu4071@icloud.com>\r\n'
reply: b'250 Ok\r\n'

send: 'data\r\n'
reply: b'354 End data with <CR><LF>.<CR><LF>\r\n'

send: b'Content-Type: text/plain; charset="utf-8"\r\n...'
reply: b'250 Ok 0106019dec617b98-********-********-********-********-********-000000\r\n'

send: 'QUIT\r\n'
reply: b'221 Bye\r\n'

Mail sent successfully.
```

## 結果の読み取り

| ログ | 意味 |
| :--- | :--- |
| `250-STARTTLS` | SMTPサーバーがSTARTTLSに対応している |
| `220 Ready to start TLS` | TLS通信を開始できる |
| `235 Authentication successful.` | SMTP認証に成功した |
| `mail FROM:<no-reply@nobu-iac-lab.com>` | 送信元メールアドレスが受け付けられた |
| `rcpt TO:<nobu4071@icloud.com>` | 送信先メールアドレスが受け付けられた |
| `250 Ok ...` | SESがメール送信を受け付けた |
| `Mail sent successfully.` | Pythonスクリプト上でも送信処理が完了した |

## 受信確認

送信先であるiCloudメールで、SESから送信したテストメールを受信できることを確認した。

```text
From: no-reply@nobu-iac-lab.com
To: nobu4071@icloud.com
Subject: SMTP経由での電子メールのテスト
```

これにより、以下の経路でメール送信できることを確認した。

```text
Python Script
  ↓ SMTP / STARTTLS
Amazon SES
  ↓
no-reply@nobu-iac-lab.com
  ↓
nobu4071@icloud.com
```

## 学んだこと

- SES SMTP interfaceを利用してアプリケーションからメール送信できる
- SMTP 587番ポートではSTARTTLSを使って通信を暗号化する
- SES SMTP credentialsはAWS CLI用のAccess Keyとは別物である
- SMTP Username / SMTP Passwordは秘密情報として扱う必要がある
- SES sandbox中は、送信先メールアドレスも検証済みである必要がある
- Domain Identityを検証することで、`no-reply@nobu-iac-lab.com` を送信元として利用できる
- Pythonの `smtplib` を使うと、Railsなどのアプリケーションメール送信の仕組みを理解しやすい

## 注意事項

SMTP認証ログには、Base64エンコードされた認証情報が含まれることがある。
そのため、`set_debuglevel(1)` の出力をそのままGitHubに載せてはいけない。

公開用のログでは、以下を必ずマスクする。

```text
AUTH PLAIN ********
SMTP username
SMTP password
Message IDの一部
```

SMTP credentialsはGitHubにコミットしない。
環境変数、パスワードマネージャー、またはAWS Secrets Managerなどで管理する。

## 今後の拡張

RailsアプリケーションからSES経由でメール送信する場合は、以下のように環境変数でSMTP設定を渡す。

```text
SMTP_ADDRESS=email-smtp.ap-northeast-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=<SES SMTP username>
SMTP_PASSWORD=<SES SMTP password>
MAIL_FROM=no-reply@nobu-iac-lab.com
```

RailsではAction MailerのSMTP設定でこれらの値を利用する。
