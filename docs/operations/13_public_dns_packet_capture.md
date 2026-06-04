# 13_public_dns_packet_capture.md

## パケットキャプチャによるDNS確認

Route 53で作成したPublic DNSレコードが、実際に名前解決されていることを `tcpdump` で確認した。

この確認はMac上で実施した。

> 注意:
> このファイル内のIPアドレスは、キャプチャ実施時点の例である。
> Bastion EC2やALBを作り直すと、Bastion Public IPやALBが返すIPアドレスは変わる。
> 2026-06-01時点の確認では、`bastion.nobu-iac-lab.com` は `52.195.216.194` に名前解決されている。

### 実行コマンド

まず、MacのWi-Fiインターフェースを対象にDNS通信をキャプチャする。

```bash
sudo tcpdump -i en0 -n port 53
```

DNS通信だけに絞りつつ、パケット内容を少し詳しく見る場合は以下でもよい。

```bash
sudo tcpdump -i en0 -nn -vvv port 53
```

別ターミナルで、DNS名前解決を実行する。

```bash
dig bastion.nobu-iac-lab.com
dig www.nobu-iac-lab.com
```

DNSサーバーを明示して確認したい場合は、以下のように指定する。

```bash
dig @192.168.40.208 bastion.nobu-iac-lab.com
dig @192.168.40.208 www.nobu-iac-lab.com
```

Google Public DNSで確認する場合は以下。

```bash
dig @8.8.8.8 bastion.nobu-iac-lab.com
dig @8.8.8.8 www.nobu-iac-lab.com
```

### 実行結果

`bastion.nobu-iac-lab.com` の名前解決では、以下のようなDNS問い合わせと応答を確認できた。

```text
192.168.40.101.51034 > 192.168.40.208.53: A? bastion.nobu-iac-lab.com.
192.168.40.208.53 > 192.168.40.101.51034: A 43.206.215.171
```

これは、MacからDNSサーバーへ `bastion.nobu-iac-lab.com` のAレコードを問い合わせ、キャプチャ時点のBastion Public IPである `43.206.215.171` が返ってきたことを示している。

現在のBastionを再作成している場合、返ってくるIPアドレスはこの値と一致しないことがある。

今回のRoute 53確認では、以下のように現在のBastion Public IP `52.195.216.194` が返っている。

```text
bastion.nobu-iac-lab.com. 300 IN A 52.195.216.194
```

`www.nobu-iac-lab.com` の名前解決では、以下のようにALBのIPアドレスが複数返ってきた。

```text
192.168.40.101.63679 > 192.168.40.208.53: A? www.nobu-iac-lab.com.
192.168.40.208.53 > 192.168.40.101.63679: A 3.115.185.66, A 13.192.190.8
```
> `192.168.40.208:53` は、自宅のラズパイ上に構築しているDNSサーバーを示している。

ALBは複数のIPアドレスを返すため、Aレコードの応答に複数IPが含まれることがある。

Route 53上では `www.nobu-iac-lab.com` はALBへのAlias Aレコードである。

クライアントから見ると、最終的にはALBが持つ複数のIPアドレスへ名前解決される。

そのため、`dig` や `tcpdump` で見えるIPアドレスは、ALBの状態やDNS応答のタイミングにより変わることがある。

### 読み取り方

| 表示 | 意味 |
| :--- | :--- |
| `192.168.40.101` | DNS問い合わせを行ったMac |
| `192.168.40.208.53` | DNSサーバーの53番ポート |
| `A? bastion.nobu-iac-lab.com.` | Bastion用DNS名のIPv4アドレスを問い合わせ |
| `A 43.206.215.171` | キャプチャ時点のBastion Public IPが返ってきた |
| `A? www.nobu-iac-lab.com.` | ALB用DNS名のIPv4アドレスを問い合わせ |
| `A 3.115.185.66, A 13.192.190.8` | ALBのIPアドレスが返ってきた |

### 学んだこと

- Route 53で作成したPublic DNSレコードが、実際にDNS問い合わせとして流れていることを確認できた
- `bastion.nobu-iac-lab.com` はBastionサーバーのPublic IPへ名前解決された
- `www.nobu-iac-lab.com` はALBへ名前解決された
- ALBは複数のIPアドレスを返すことがある
- Bastion EC2を再作成すると、同じDNS名でも返るPublic IPは変わる
- DNSレコードを `UPSERT` しても、端末側や中継DNSサーバー側にTTL分のキャッシュが残ることがある
- `tcpdump` を使うと、DNS問い合わせと応答をパケットレベルで確認できる

### 注意事項

`tcpdump` は管理者権限が必要なため、Macでは `sudo` を付けて実行する。

Wi-Fiインターフェースが `en0` ではない環境では、以下のコマンドでインターフェース名を確認する。

```bash
networksetup -listallhardwareports
```

ブラウザや他のアプリケーションが裏でDNS問い合わせを行うため、キャプチャ結果には今回の検証とは関係ない名前解決が混ざることがある。

また、DNSサーバーは環境により異なる。

たとえば、以下のように問い合わせ先が変わる。

| 問い合わせ方法 | DNSサーバー |
| :--- | :--- |
| Macの通常名前解決 | 自宅DNS、ルーター、ISP DNSなど環境依存 |
| `dig @192.168.40.208` | 自宅ラズパイDNS |
| `dig @8.8.8.8` | Google Public DNS |

DNSの検証では、どのDNSサーバーへ問い合わせた結果なのかも合わせて記録する。

### 案件対策としての見どころ

この確認は、Route 53の設定値をAWS CLI上で見るだけでなく、実際にクライアントからDNS問い合わせが発生し、応答が返っていることを確認する作業である。

障害調査や設定変更後の確認では、以下を切り分ける必要がある。

| 観点 | 確認内容 |
| :--- | :--- |
| Route 53設定 | レコードが正しく作成・更新されているか |
| DNS伝播 | 変更が `INSYNC` になっているか |
| DNSキャッシュ | 端末やDNSサーバーに古い値が残っていないか |
| 名前解決 | 実際に期待したAレコードが返るか |
| 通信確認 | 名前解決後、SSHやHTTPで接続できるか |

今回のように `tcpdump` でDNS問い合わせと応答を確認できると、DNS設定だけでなく、端末から見た実際の名前解決経路も説明できる。
