# クラウドセキュリティ対応 全要件テスト方法説明資料

作成日: 2026-08-17

用途: 関係者説明用

## 1. 目的

本資料は、クラウドセキュリティ対応の全要件について、採用するテスト方法、代替候補、実アラームまたは実通知の要否、その方法を選ぶ理由を説明するための資料である。

正式な改善計画に記載された次の21要件を対象とする。

- 共通運用要件: A3、A4
- ロギング要件: 3.4～3.7
- モニタリング要件: 4.1～4.15

本資料はテスト方針の説明資料であり、実際の操作、設定値、切り戻し、証跡ファイル名は承認済みの作業手順書とパラメータシートを正とする。

## 2. 結論

1. A3とA4はAWS設定そのものではなく、手順書と運用実績を確認する。
2. 3.4～3.7はアラーム要件ではないため、実アラームではなく実際のログ配信、暗号化状態、設定状態を確認する。
3. 4.1～4.15は、検証環境で要件ごとに少なくとも1件の代表イベントを発生させ、実通知まで確認することを原則とする。
4. Filter Patternに複数のイベント名が含まれる場合、全条件をPattern Testで確認し、実イベントは安全な代表操作に限定する。
5. root、Organizations、認証基盤、中央統制対象など、担当範囲だけでは安全に実イベントを発生できない要件は、代替テストの範囲と不足する証明を明記して承認を得る。
6. 本番環境では、検証環境と同じ設定値であること、ログ配送が正常であること、通知先が正しいことを確認する。危険な実イベントを本番環境で再実施するかは別途承認事項とする。

## 3. テスト方法の区分

| 区分 | 確認できる範囲 | 確認できない範囲 | 主な用途 |
| :--- | :--- | :--- | :--- |
| End-to-End実イベントテスト | AWS操作、CloudTrail、CloudWatch Logs、Metric、Alarm、通知受信まで | Filter Patternに含まれる未実施の別イベント | 4番台の最終確認 |
| Metric Filter Pattern Test | 一致サンプルが一致し、不一致サンプルが除外されること | 実ログ配送、Metric発行、Alarm、通知 | Filter Pattern全条件の単体確認 |
| Alarm単体テスト | AlarmからSNS等の通知先まで | CloudTrail、CloudWatch Logs、Metric Filter | 通知経路だけの切り分け |
| 設定確認 | 設定値、対象範囲、状態 | 実際のログ到着や通知到達 | 3.6、作業前後比較 |
| 運用試験 | 手順に従った確認、判断、記録、連絡 | AWS検知機能そのものの網羅性 | A3、A4 |

### 3.1 Pattern Testだけで完了にしない理由

Pattern TestはFilter Patternとサンプルログの一致を確認する機能であり、サンプルログを実際のLog Groupへ投入しない。そのため、Metricの増加、Alarmの状態遷移、通知受信は確認できない。

### 3.2 Alarm単体テストだけで完了にしない理由

`SetAlarmState`はAlarmを一時的に`ALARM`へ変更し、SNS等のAlarm Actionを確認する手段である。ただしCloudTrail、CloudWatch Logs、Metric Filterを通らないため、監視経路全体の証明にはならない。APIまたはCLIが禁止されている環境では、この方法自体を採用しない。

### 3.3 過去イベントだけでは実アラームを確認できない理由

Metric Filterは作成後に取り込まれたログイベントからMetricを発行する。作成前の過去ログを検索しても、新しいMetricやAlarmは発生しない。過去イベントは実際のログ形式確認とPattern Testの入力例として使用する。

## 4. 4番台の共通End-to-End確認

### 4.1 CloudWatch Alarm方式

```text
承認済みのテスト操作
  -> CloudTrailイベント生成
  -> CloudWatch Logsへ配送
  -> Metric Filter一致
  -> Metricが1以上
  -> CloudWatch AlarmがALARMへ遷移
  -> SNS等の通知先で受信
  -> テスト操作を切り戻し
  -> Alarmが通常状態へ復帰
```

### 4.2 既存EventBridge等の統制方式

既存統制方式が同等対策として承認されている要件は、CloudWatch Alarmを新設せず、次の経路を確認する。

```text
承認済みのテスト操作
  -> CloudTrailイベント生成
  -> EventBridge Rule一致または共通監視基盤で検知
  -> Target呼び出し
  -> メール、Teams、監視基盤等で受信
```

この場合、CloudWatch Alarmが発報しないことは異常ではない。採用した監視経路の実通知まで到達することを確認する。

### 4.3 共通合格条件

次のすべてを確認した場合にEnd-to-Endテスト合格とする。

1. テスト操作のCloudTrailイベントを特定できる。
2. 監視対象Log Groupまたは承認済みの統制経路へイベントが到達する。
3. 対象要件のFilterまたはRuleが一致する。
4. MetricまたはRuleの検知実績を確認できる。
5. Alarm履歴または通知経路の実行履歴を確認できる。
6. 最終通知先で受信を確認できる。
7. テスト用変更を切り戻し、残存リソースがないことを確認できる。

## 5. 要件別テスト方法

### 5.1 A3、A4

| 要件 | 第一候補 | その他の候補 | 実通知 | 選定理由と判定 |
| :--- | :--- | :--- | :--- | :--- |
| A3 セキュリティアラート監視運用手順書 | GuardDutyのサンプルFindingまたは4番台のテスト通知を1件使用し、受信、一次確認、影響判断、エスカレーション、記録、クローズまで机上運用する | 過去の実Findingを匿名化して再確認する。通知を発生させずシナリオだけで机上訓練する | 1件実施を推奨 | 手順書を読めることではなく、担当者が手順どおりに判断して記録できることを確認する |
| A4 日々のモニタリング運用 | 合意した試行期間に日次または定期確認を実施し、異常なしの日も含めて確認記録を残す。期間中にサンプル通知を1件処理する | 既存の月次記録と過去対応記録を確認し、新様式で1回運用する | 初回に1件推奨 | 1日のテストだけでは継続運用を証明できない。初回運用試験と、その後に蓄積する確認記録を組み合わせる |

GuardDutyサンプルFindingは架空の値を持つサンプルであり、実際の侵害を発生させずにEventBridge RuleやFilterを確認できる。ただし実Findingそのものの再現ではないため、サンプルであることを証跡に明記する。

### 5.2 3.4～3.7

| 要件 | 第一候補 | その他の候補 | 実アラーム | 選定理由と判定 |
| :--- | :--- | :--- | :--- | :--- |
| 3.4 CloudTrail S3バケットのServer Access Logging | 設定後、承認済みの読み取り操作をSource bucketへ実施し、Target bucketの指定prefixへアクセスログが配送され、内容を参照できることを確認する | CloudTrailからSource bucketへ通常配送されるログオブジェクトのアクセス記録を待つ | 対象外 | 要件は通知ではなくS3アクセス履歴の保全である。設定画面だけでなく実ログオブジェクトまで確認する。配信は数時間遅れる場合がある |
| 3.5 CloudTrailログのCMK暗号化 | SSE-KMS設定後に安全な管理APIを1回実行し、新規CloudTrailログオブジェクトが対象CMKで暗号化されていること、Trailに配送エラーがないこと、承認済み参照者が復号して読めることを確認する | 通常運用で生成された設定後の新規ログオブジェクトを待って確認する | 対象外 | 既存ログではなく設定変更後に新規配送されたオブジェクトで確認する。暗号化だけでなくCloudTrailの書き込み権限と参照者の復号権限も検証する |
| 3.6 CMK自動ローテーション | 対象のカスタマーマネージド対称キーで自動ローテーションが有効であり、ローテーション期間が設計値であることを画面とパラメータシートで確認する | 明示的な承認がある場合だけオンデマンドローテーションを行う | 対象外 | 要件はローテーション設定の有効化であり、将来の自動ローテーション日まで待つ必要はない。不要なキーマテリアル変更を避ける |
| 3.7 全VPCのVPC Flow Logs | 対象VPCでFlow LogがActiveになった後、既存の承認済みテスト用ENIから制御した通信を1回発生させ、CloudWatch LogsまたはS3で該当Flow Log recordを確認する | 通常通信がある既存ENIのログ到着を待つ。通信元がない場合だけ短命なテストEC2等を承認後に用意する | 対象外 | 要件は全対象VPCの通信メタデータ記録である。Flow Logの設定状態だけでなく、少なくとも1件の実レコード到着を確認する。配送には遅延がある |

### 5.3 4.1～4.15

| 要件 | 第一候補となる実イベント | その他の候補または代替 | 実通知方針 | 選定理由と注意点 |
| :--- | :--- | :--- | :--- | :--- |
| 4.1 不正なAPI呼び出し | 明示的Denyを持つテストRoleで、空のテストBucketに対する`PutBucketTagging`を実行して`AccessDenied`を発生させる | 別の無害な参照・タグ操作を明示的Denyする。`UnauthorizedOperation`と`AccessDenied*`は両方Pattern Testする | 実施 | 失敗してもリソース内容が変わらないため安全性が高い。実ユーザーの権限不足を意図的に起こさない |
| 4.2 MFAなしコンソールサインイン | 専用サンドボックスで、権限を持たないテストIAMユーザーをMFA未登録のまま1回だけ成功ログインさせる | MFA未使用ログイン禁止の場合、既存イベント形式によるPattern TestとAlarm単体テストを組み合わせ、代替であることを承認する。MFA強制の統制証跡により対象外判断する候補もある | 条件付き | MFA統制を弱めてまで実施しない。外部IdPのMFAとCloudTrailの`MFAUsed`は同じ意味にならない場合があるため、認証方式を先に確認する |
| 4.3 rootアカウント使用 | 専用サンドボックスのrootユーザーでMFAログインし、ログイン後すぐにサインアウトする | root利用が禁止される場合、Pattern TestとAlarm単体テストに限定し、代替承認を得る | 原則サンドボックスのみ | rootは影響範囲が最大である。業務アカウントや本番で通知確認のためだけに使用しない。rootの`ConsoleLogin`は原則`us-east-1`側の記録も確認する |
| 4.4 IAMポリシー変更 | どのPrincipalにもアタッチしないテスト用Customer managed policyを作成し、確認後に削除する | テストRoleに権限を持たないInline Policyを作成・削除する。Attach/Detach等の全分岐はPattern Testする | 実施 | 未アタッチPolicyは実効権限を変えない。作成と削除の両方が監視対象の場合、複数Metricが発生し得る |
| 4.5 CloudTrail設定変更 | ログ記録を開始しないテスト専用Trailを作成して削除する、またはテスト専用Trailへ承認済みの`UpdateTrail`を実施する | 中央統制Trailしかない場合は管理チームが代表イベントを実施する。Pattern TestとAlarm単体テストは代替候補 | 条件付き | 稼働中Trailの停止、削除、Event Selector変更は行わない。SCP等で明示的Denyされる場合は担当境界を越えて回避しない |
| 4.6 Management Console認証失敗 | 権限を持たないテストIAMユーザーでパスワードを1回だけ誤入力する | IAMユーザー認証を使用しない環境では、認証基盤側の失敗監視を確認する。AWS側は既存`ConsoleLogin`形式によるPattern TestとAlarm単体テストを代替候補とする | 条件付き | 外部IdPやWinAuthでAWS到達前に拒否された失敗は、AWSアカウントのCloudTrailへ`ConsoleLogin`として残らない場合がある。実利用者で繰り返し失敗させない |
| 4.7 CMK無効化・削除予約 | 未使用のテスト専用CMKを作成し、`DisableKey`後に`EnableKey`、`ScheduleKeyDeletion`後に直ちに`CancelKeyDeletion`を行う | `DisableKey`と`ScheduleKeyDeletion`の一方だけを代表イベントにし、もう一方はPattern Testする | 実施 | 業務データを暗号化していないテスト専用CMKに限定する。削除予約は7～30日の待機期間内に必ず取り消す |
| 4.8 S3バケットポリシー変更 | 空のテスト専用Bucketへ安全側のDeny Policyを設定し、確認後にPolicyを削除する | 既存EventBridge等が対応済みなら、同じテストイベントで既存通知経路を確認する | 実施 | Public許可を作らずに`PutBucketPolicy`と`DeleteBucketPolicy`を発生できる。業務BucketのPolicyは変更しない |
| 4.9 AWS Config設定変更 | 対象をテストリソースへ限定したテスト用AWS Managed Config Ruleを作成し、確認後に削除する | Configが中央管理の場合は管理チームに代表イベントを依頼する。Recorder停止等はPattern Testだけとする | 条件付き | Configuration RecorderやDelivery Channelを停止すると記録断が起こるため使用しない。Rule評価と削除に伴う料金・設定項目生成を確認する |
| 4.10 Security Group変更 | 既存検証VPCまたは空VPCに未関連付けSGを作成し、TCP 65535、送信元`192.0.2.0/24`のRuleを追加・削除してSGを削除する | SGの作成・削除だけを代表イベントにする。その他のRule操作はPattern Testする | 実施 | SGをEC2、ENI、ALB、RDS、Lambda等へ関連付けなければ業務通信へ適用されない |
| 4.11 NACL変更 | 未関連付けのカスタムNACLを作成し、Rule 200、TCP 65535、送信元`192.0.2.0/24`のEntryを追加・削除してNACLを削除する | NACLの作成・削除だけを代表イベントにする。Replace系はPattern Testする | 実施 | Subnet associationを0件に保つことで既存SubnetへRuleが適用されない。Default NACLは変更しない |
| 4.12 Network Gateway変更 | テスト用Internet Gatewayを作成し、未アタッチのまま削除する | Attach/Detachまで必要な場合は空VPCへAttachして直ちにDetachする。Customer Gateway系はPattern Testする | 実施 | `CreateInternetGateway`だけならVPCは不要であり最も安全である。Attach/Detachは既存VPCのIGWを触らず空VPCに限定する |
| 4.13 Route Table変更 | 既存検証VPCまたは空VPCに未関連付けRoute Tableを作成して削除する | `CreateRoute`まで必要な場合は空VPCとテストIGWを使い、宛先`198.51.100.0/24`のRouteを追加・削除する | 実施 | Route TableをSubnetへ関連付けなければ業務経路は変わらない。Main Route Tableと既存Routeは変更しない |
| 4.14 VPC変更 | 他環境と重複しないCIDRで空のテストVPCを作成し、依存リソースがないことを確認して削除する | Peering系まで必要な場合は空VPCを2つ作成し、Peering作成・拒否または削除を行う。既存VPC属性変更は避ける | 実施 | `CreateVpc`を確認するにはVPC作成が必要である。空VPCなら業務Subnet、Route、ENIを持たず、切り戻しはテストVPC削除で完結する |
| 4.15 AWS Organizations変更 | 管理サンドボックスで空のテストOUを作成し、AccountやPolicyを所属させずに削除する | 管理アカウントでの操作が許可されない場合は管理チームに実施を依頼する。Pattern TestとAlarm単体テストは代替候補 | 原則管理サンドボックスのみ | Organizations変更は管理アカウントでのみ実施できる。業務OU、Account移動、SCP変更は行わない |

要件4.15のFilter Patternは、承認された変更APIへ限定する。`eventSource = organizations.amazonaws.com`だけを条件にすると、`List*`や`Describe*`などの読み取り操作まで一致するため、テスト前に変更イベント一覧を確定する。

## 6. 複数イベントを含む要件の考え方

### 6.1 代表イベントだけを実施する理由

4番台のFilter Patternには、同じリスクを表す複数のAPI名がOR条件で含まれる。すべてのAPIを実環境で実行すると、停止、削除、関連付け変更などの危険操作まで必要になる。

そのため次の二段構成とする。

1. 一致サンプルと不一致サンプルを使用し、Filter Patternの全分岐をPattern Testする。
2. 要件ごとに安全な代表イベントを1件以上発生させ、CloudTrailから実通知まで確認する。

代表イベントで監視経路を確認し、Pattern Testで条件網羅を補うことで、安全性と網羅性を両立する。

### 6.2 すべてのイベントを実施する場合

関係者から「Filter Patternに含まれる全APIを実イベントで確認すること」が求められた場合、次を別途決定する。

- 各イベントを安全に実行できる専用リソース
- 実施順序と切り戻し順序
- 1イベントごとのAlarm復帰待ち
- 通知件数と通知先への事前連絡
- root、Organizations、CloudTrail停止等を実施しない例外承認

CloudWatch Alarmは状態が変わった場合にActionを実行する。同じ評価期間内でAlarmが`ALARM`のまま複数イベントが発生しても、イベント件数と同じ数の通知が届くとは限らない。APIごとに通知を確認する場合は、Alarmが`OK`へ戻った後に次のイベントを実施する。

## 7. 実アラームを出さない場合の扱い

### 7.1 代替テストを認める候補

次の要件は統制、権限、認証方式によって実イベントが実施できない可能性が高い。

- 4.2 MFAなしサインイン
- 4.3 rootアカウント使用
- 4.5 中央管理CloudTrail変更
- 4.6 外部認証基盤での認証失敗
- 4.9 中央管理AWS Config変更
- 4.15 AWS Organizations変更

### 7.2 代替テストの証跡

代替テストとする場合は、次を一組で残す。

1. 実イベントを行わない理由と承認記録
2. 一致・不一致サンプルによるPattern Test結果
3. Alarm単体テストまたは既存通知経路の受信結果
4. CloudTrailからCloudWatch Logsへの通常イベント配送結果
5. 実施していないため未確認となる範囲

この組み合わせはEnd-to-End実イベントテストと同一ではない。監査上の受入可否は関係者の明示的な判断を必要とする。

## 8. 想定質問と回答

### Q1. なぜ全APIを実際に操作しないのか

停止、削除、関連付け変更を含むためである。安全な代表イベントで実通知経路を確認し、残りの条件をPattern Testで確認する。全APIの実行が必要な場合は、専用リソース、個別承認、Alarm復帰待ちを追加する。

### Q2. 実アラームは出さないのか

4.1～4.15は、実施可能な要件について検証環境で実通知を1件以上出す。3.4～3.7はアラーム要件ではないため、実ログ配送と設定状態を確認する。A3とA4ではサンプル通知を使用して運用手順を確認する。

### Q3. Pattern Testだけで十分ではないか

十分ではない。Pattern TestはFilter Patternの一致だけを確認し、CloudTrail配送、Metric発行、Alarm状態遷移、通知受信を確認しない。

### Q4. Alarmを手動で`ALARM`にすれば十分ではないか

通知先の確認には有効だが、CloudTrailからMetric Filterまでを通らない。通知経路の単体テストとして扱い、End-to-Endテストの代替とする場合は不足範囲を明記する。

### Q5. 過去に存在するCloudTrailイベントを使えないか

ログ形式とPatternの確認には使用できる。ただしMetric Filterは作成前のイベントへ遡及適用されないため、過去イベントだけでは新しい実アラームを発生できない。

### Q6. テスト専用リソースを作る理由は何か

業務リソースから変更を隔離し、対象IDを証跡で特定し、切り戻しをテストリソースの削除だけで完結させるためである。既存検証リソースを使う場合は、未関連付け、未使用、担当部署の承認を条件とする。

### Q7. 検証環境で確認すれば本番では実イベントを出さなくてよいか

自動的には決まらない。検証環境では機能と通知経路を確認し、本番では設定値、対象範囲、配送状態、通知先を確認する。危険な本番実イベントを省略する場合は、検証環境と本番の同一性および省略判断を承認記録に残す。

### Q8. 既存EventBridge等で通知済みならCloudWatch Alarmは不要か

同等対策として承認され、対象イベント、対象アカウント、対象リージョン、通知先、運用手順まで要件を満たす場合は候補になる。その場合はCloudWatch Alarmではなく、既存Ruleから最終通知先まで実通知を確認する。方式の採否は設計判断として記録する。

### Q9. ConsoleLoginイベントが見つからない場合はどうするか

サインイン方式、サインインEndpoint、イベント記録リージョン、中央Trail、CloudWatch Logs連携先を確認する。外部IdPでAWS到達前に失敗した認証は、AWS側CloudTrailへ残らない可能性がある。その場合、認証基盤側の監視とAWS側の監視範囲を分けて説明する。

### Q10. 通知が1回しか届かないのは異常か

必ずしも異常ではない。CloudWatch Alarmは状態変化時にActionを実行するため、Alarmが`ALARM`のまま複数イベントが発生すると通知が追加されない場合がある。Metricの増分、Alarm履歴、状態遷移時刻を併せて確認する。

## 9. 関係者に事前合意を求める事項

1. 4番台は「全Patternを単体テストし、代表イベント1件で実通知を確認する」方針でよいか。
2. 検証環境では実通知を行い、本番では危険な実イベントを省略する方針でよいか。
3. 4.2、4.3、4.5、4.6、4.9、4.15の実イベント可否と代替テスト受入条件は何か。
4. 既存EventBridge等の統制方式を同等対策として扱う要件はどれか。
5. 通知先、通知確認者、テスト時間帯、テスト件名の識別方法は何か。
6. テスト用IAMユーザー、Role、CMK、S3 Bucket、VPC、OUの作成可否はどうか。
7. A4の継続運用を示す試行期間と証跡提出期間はどの程度か。
8. テスト後に即時削除するリソースと、設定として残すリソースはどれか。

## 10. 共通証跡

### 10.1 4番台

- 作業対象アカウント、リージョン、環境
- Metric FilterのPatternとPattern Test結果
- テスト操作の対象リソースと実施時刻
- CloudTrailイベント詳細
- CloudWatch Logsの該当ログイベント
- MetricのDatapoint
- Alarm状態とAlarm履歴
- SNS等の通知先設定
- 最終通知先の受信結果
- 切り戻し後の設定と残存リソース確認

### 10.2 3番台

- 変更前後の設定
- 配信先、暗号化キー、対象VPC等の対象範囲
- 実際に配信されたログオブジェクトまたはログレコード
- Delivery errorがないこと
- 必要に応じてログ参照結果

### 10.3 A3、A4

- 承認済み運用手順書
- 運用試験記録
- 日次または定期確認記録
- サンプル通知または実通知の対応記録
- エスカレーション判断とクローズ記録
- レビュー・承認記録

## 11. 参考となるAWS公式ドキュメント

### CloudTrail、CloudWatch Logs、Alarm

- [Amazon CloudWatch LogsによるCloudTrailログファイルのモニタリング](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/monitor-cloudtrail-log-files-with-cloudwatch-logs.html)
- [CloudTrailイベントのCloudWatchアラームの作成: 例](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudwatch-alarms-for-cloudtrail.html)
- [フィルターを使用したログイベントからのメトリクスの作成](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
- [メトリクスフィルターのフィルターパターン構文](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/FilterAndPatternSyntaxForMetricFilters.html)
- [Amazon CloudWatchでのアラームの使用](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)
- [AWS Management Consoleサインインイベント](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/cloudtrail-event-reference-aws-console-sign-in-events.html)

### A3、A4

- [GuardDutyのサンプルの検出結果生成](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/sample_findings.html)
- [GuardDutyの検出結果の理解と生成](https://docs.aws.amazon.com/ja_jp/guardduty/latest/ug/guardduty_findings.html)

### 3番台

- [Amazon S3サーバーアクセスログを有効にする](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/enable-server-access-logging.html)
- [AWS KMSキーを使用したCloudTrailログファイルの暗号化](https://docs.aws.amazon.com/ja_jp/awscloudtrail/latest/userguide/encrypting-cloudtrail-log-files-with-aws-kms.html)
- [AWS KMSキーローテーション](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/rotate-keys.html)
- [VPCフローログを使用したIPトラフィックのログ記録](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-logs.html)
- [フローログレコードと配信時間](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/flow-log-records.html)

### 4番台のテストリソース

- [AWS KMSキーの削除](https://docs.aws.amazon.com/ja_jp/kms/latest/developerguide/deleting-keys.html)
- [AWS Configマネージドルール](https://docs.aws.amazon.com/ja_jp/config/latest/developerguide/evaluate-config_use-managed-rules.html)
- [VPC Security Group](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLの作成](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/create-network-acl.html)
- [Internet Gateway](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [Subnet Route Table](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/subnet-route-tables.html)
- [VPCの作成](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/create-vpc.html)
- [VPCの削除](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/delete-vpc.html)
- [AWS OrganizationsでOUを作成する](https://docs.aws.amazon.com/ja_jp/organizations/latest/userguide/create_ou.html)

## 12. 最終判断

推奨方針は、検証環境で安全な代表イベントによる実通知を確認し、Pattern TestでFilter Patternの全条件を補完する方法である。

実イベントを実施できない要件は、代替テストで確認できる範囲と確認できない範囲を明記する。代替テストをEnd-to-Endテストと同一扱いにせず、関係者の承認をもって受入可否を確定する。
