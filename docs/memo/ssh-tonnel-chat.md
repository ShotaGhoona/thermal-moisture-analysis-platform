forward（京大ゲートウェイ）に入れた時点で、外部 → 京大内部 の“入口”までは完全にできました。
ここから先は：

🔥目的

大学（学内LAN内）の研究室PCを “自宅のMac から操作できる状態” にする

つまり、

あなたのMac
   ↓（SSHトンネル）
forward.kuins（踏み台）
   ↓（SSH）
研究室PC（Linux/Windows）


という 2段階接続 を作る。

これが “SSHポートフォワーディング” で、
京大が推奨している正式ルート。

🧩 学内PCへ接続する仕組み（超重要）

forward へ接続できたら、次に必要なのは：

研究室PCの学内IP（例：10.xxx.xxx.xxx）

研究PCのOS（Linux / Windows）

研究PCのユーザー名（labuser など）

これがわかれば、次のような “ローカル→研究PC” のトンネルが作れる。

🔥 ステップ構造（必ずこの順番）
Step 1：研究室PCの IP を教えてもらう

（例：10.158.23.41 みたいな 10.x.x.x 系）

※ forward に入った瞬間、プロンプトが

forward%


になってるよね？

→ forward 内で次を実行すれば研究室PCに ping できることが多い：

ping 10.xxx.xxx.xxx

Step 2：Mac 側で SSH トンネルを張る

例（あとで正式版をあなた用に作る）：

研究室PCが

IP：10.158.23.41

SSH ポート：22番

あなたの京大ID：a0207104

なら Mac でこうする：

ssh -i ~/.ssh/id_ed25519 \
    -o CertificateFile=~/.ssh/id_ed25519-cert.pub \
    -L 2222:10.158.23.41:22 \
    a0207104@forward.kuins.kyoto-u.ac.jp


この意味は：

Mac の “localhost:2222” を → forward → 研究室PC:22 へつなげる

つまり：

       ローカルMac（あなた）
SSH -L 2222────→ forward（京大）
                    │
                    └── SSH → 研究室PC

Step 3：トンネルを張ったまま “別ターミナルを開く”

Mac で別ターミナルを開いて：

ssh -p 2222 labuser@localhost


これで 研究室PCのシェルが開く（＝操作できる）。

Step 4：VSCode で開く（最強）

VSCode → Remote-SSH → New SSH Target：

ssh -p 2222 labuser@localhost


これで
大学の研究室PCのファイルを VSCode で編集し、GPU を使い、Python を走らせられる。

Step 5：Windows の研究PCの場合（RDP）

もし研究PCが Windows なら：

Mac → Microsoft Remote Desktop を開いて、

PC name: localhost:13389


になるようにトンネルを作る：

ssh -i ~/.ssh/id_ed25519 \
    -o CertificateFile=~/.ssh/id_ed25519-cert.pub \
    -L 13389:10.158.23.41:3389 \
    a0207104@forward.kuins.kyoto-u.ac.jp

🎯 ここから先に進むために必要な情報は 3つだけ
❗❗ あなたに聞きたいこと（超重要） ❗❗
① 研究室PCの学内IP

例：

10.158.xxx.xxx


（研究室や教授に聞く / forward 内で確認できる）

② 研究室PCの OS

Linux (Ubuntu / CentOS / Rocky / Fedora 等)

Windows

macOS の場合も稀にある

③ 研究室PCのユーザー名

例：

murayama
labuser
yamashita
syota


（ログインに使うユーザーID）

これを教えてくれたら、
あなた専用の接続コマンドを “完全・最適化・自動生成” して渡す。

そしてあなたは 自宅のMacから研究室PCを自由に操作できる状態になる。

👉 まずはこれを教えてください：

研究PCの IP

研究PCの OS

研究PCの ログインユーザー名

準備でき次第、次を完全に作るよ。

---

少し時間を空けるとterminal,の接続が切れている気がします
yamashitashota@Macintosh-40743 ~ % 
どうやったらまたトンネルに入れるの？

---

うん、それめっちゃ普通の動きだよ 👍
まず状況整理


前：
forward% って出てた → 京大 forward サーバの中にいた状態


今：
yamashitashota@Macintosh-40743 ~ %
→ 自分の Mac のターミナルに戻ってる状態（SSH セッションがタイムアウト or 自分で閉じた）


SSH は しばらく何もしないと勝手に切れる ので、
また入りたくなったら 同じコマンドをもう一回打ち直すだけ でOK。

🔁 forward に再接続するコマンド
またトンネル（というか京大の入り口）に入り直したいときは：
ssh -i ~/.ssh/id_ed25519 \
  -o CertificateFile=~/.ssh/id_ed25519-cert.pub \
  a0207104@forward.kuins.kyoto-u.ac.jp

これを叩いて、
Enter passphrase for key ... が出たら
→ 鍵のパスフレーズを入れる
→ forward% が出たらまた京大の中にいる状態に戻れてる。

「トンネル（ポートフォワード）」も同じで、コマンドをもう一回実行するだけ
将来的にこんな感じのポートフォワードコマンドを使うことになるんだけど：
ssh -i ~/.ssh/id_ed25519 \
  -o CertificateFile=~/.ssh/id_ed25519-cert.pub \
  -L 2222:10.xxx.xxx.xxx:22 \
  a0207104@forward.kuins.kyoto-u.ac.jp

このセッションが切れたら、
またこのコマンドを実行し直せばトンネルが張り直される、というだけの話。

次の一歩どうする？
今は


forward には入れるようになった ✅


まだ「研究室PCへのトンネル」は作ってない状態


なので、もし


研究PCの IP（10.x.x.x）


研究PCの OS（Linux / Windows）


研究PCのユーザー名


がわかれば、それをもとに
「このコマンドを打てば毎回トンネル再接続できるよ」っていう1本を作るね。
