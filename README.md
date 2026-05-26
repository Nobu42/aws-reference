## AWS Reference

本設計書は、AWS上にWebアプリケーション基盤を構築するためのネットワーク、サーバー、データベース、DNS、メール、キャッシュ関連リソースの構成を定義する。

本構成は、AWS CLIとシェルスクリプトによるインフラ構築手順を整理したリファレンス実装であり、VPC、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheなどを組み合わせたWebアプリケーション基盤の全体像を確認できることを目的とする。

また、後続でTerraform化することを想定し、各AWSリソースの役割、依存関係、セキュリティ設計、削除運用を明確にする。

![Network Architecture](./docs/Network_Architecture.png)
