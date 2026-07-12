## 作業の型

1. 変更対象の確認
   - 対象バケット名
   - 現在のBucket Policy
   - Public Access Block
   - ACL
   - 暗号化
   - CloudTrail / CloudWatch / S3 Access Logs の有無

2. 影響範囲の確認
   - どのIAM Role / User / Service がアクセスしているか
   - アプリ、Lambda、EC2、外部連携が使っていないか
   - Deny条件追加で既存処理が止まらないか

3. 変更作業
   - 変更前JSON取得
   - ポリシー差分確認
   - 適用
   - エラー時の切り戻し準備

4. 変更後テスト
   - 許可されるべきアクセスが通る
   - 拒否されるべきアクセスが拒否される
   - アプリや連携処理が正常
   - CloudTrail等でイベント確認

5. 証跡・手順書
   - 変更前
   - 変更後
   - 確認結果
   - 切り戻し方法
   - 残課題
