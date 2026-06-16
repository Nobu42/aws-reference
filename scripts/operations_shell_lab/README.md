# Operations Shell Lab

Day 17で使用する、金融系運用シェル読解用の模擬教材である。

この教材はクリーンルーム方式で作成した学習用ファイルであり、実在案件のシェル、設定値、設計を複製したものではない。

## 構成

```text
operations_shell_lab/
├── bin/
│   └── s3_security_check.sh
├── conf/
│   ├── accounts.conf
│   └── s3_security_check.conf
├── fixtures/
│   ├── access_denied/
│   ├── ok/
│   └── wrong_account/
└── lib/
    └── aws_api_common_functions.sh
```

## 既定動作

既定では`RUN_MODE=mock`で動作し、AWS APIは呼び出さない。

```bash
cd /Users/nobu/aws-reference/scripts/operations_shell_lab

./bin/s3_security_check.sh \
  --conf conf/s3_security_check.conf
```

## 異常系

想定外アカウント:

```bash
DAY17_MOCK_SCENARIO=wrong_account \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf
```

Bucket Policy取得AccessDenied:

```bash
DAY17_MOCK_SCENARIO=access_denied \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf
```

## 実AWS読み取り確認

実AWSへ読み取り専用で確認する場合だけ、明示的に指定する。

```bash
DAY17_RUN_MODE=real \
  ./bin/s3_security_check.sh \
    --conf conf/s3_security_check.conf
```

実案件や本番アカウントでは、この学習用シェルを使用しない。
