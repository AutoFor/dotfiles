# 新規セットアップガイド (Windows クライアント)

新しい Windows PC を「接続クライアント」として Azure devbox に繋ぐまでの手順。
開発環境の本体 (zsh / nvim / Claude Code / tmux) は devbox 側にあるので、
Windows に入れるのは接続と表示に必要な最小限だけ。

- devbox 自体を新規に構築する場合は `cloud/azure-devbox/README.md` を参照
- リポジトリの運用ルール (2 クローン戦略・同期) はリポジトリ直下の `CLAUDE.md` を参照
- 旧 WSL 前提の構成は #212 で廃止した。旧手順が必要なら Git 履歴を参照

## 1. 基本ツール (winget)

PowerShell で:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e
winget install --id Microsoft.PowerShell -e     # pwsh (devbox.ps1 / 通知スクリプトが使う)
winget install --id Microsoft.AzureCLI -e       # VM の起動/停止 (devbox.ps1)
winget install --id x-motemen.ghq -e
winget install --id tailscale.tailscale -e      # devbox への SSH 経路
```

## 2. フォント

WezTerm の設定が参照するフォントを入れる (ユーザーローカルインストールで可):

| フォント | 入手先 | 用途 |
|---------|--------|------|
| HackGen Console NF | https://github.com/yuru7/HackGen/releases | 本文 (日本語 + Nerd Fonts) |
| Symbols Nerd Font Mono | https://www.nerdfonts.com/font-downloads | 新しめのアイコンのフォールバック |

## 3. ログイン類

```powershell
gh auth login        # GitHub
az login             # Azure (devbox の起動権限があるアカウント)
tailscale up         # devbox と同じ tailnet に参加
```

参加後、`tailscale status` に devbox (100.126.96.27) が見えることを確認する。

## 4. dotfiles の取得とリンク

```powershell
ghq get AutoFor/dotfiles
Set-Location "$env:USERPROFILE\ghq\github.com\AutoFor\dotfiles"
.\install-windows.ps1
```

> シンボリックリンク作成のため、**管理者 PowerShell** で実行するか **開発者モード**を ON にしておく。

リンクされるもの: `~\.wezterm.lua` / `~\.gitconfig` / `~\.bashrc` / `~\.ssh\config` /
`~\.local\bin\devbox.ps1` / `%LOCALAPPDATA%\nvim`。

クローン直後に、このリポジトリの同期・push 設定を入れる (詳細は `CLAUDE.md` の「同期」):

```powershell
git config core.hooksPath .githooks                                   # コミット即 push フック
git config pull.rebase true
git config rebase.autostash true
git config credential.helper ""                                       # 空にリセット (下の 2 行を効かせる)
git config credential.https://github.com.username <GitHubユーザー名>
git config credential.https://github.com.helper '!gh auth git-credential'
```

> `windows/.gitconfig` (グローバルにリンクされる) が `credential.username = AutoFor` を
> 持っているため、この設定を入れないと `git push` がパスワード入力で止まる。

## 5. SSH 鍵

```powershell
ssh-keygen -t ed25519
```

公開鍵 (`~\.ssh\id_ed25519.pub`) を devbox の `~/.ssh/authorized_keys` に追記する。
既存クライアントがあるならそこから `ssh devbox` して追記するのが早い。

確認: PowerShell から `ssh devbox` で入れること (`windows/.ssh/config` が Host devbox を定義済み)。

## 6. 通知トースト (任意)

Claude Code の完了通知を「クリックで該当ペインへジャンプできるトースト」で受けるなら:

```powershell
Install-Module BurntToast -Scope CurrentUser
pwsh -File windows\bin\register-wezterm-jump.ps1    # wezterm-jump: URI スキーム登録 (HKCU、管理者不要)
```

## 7. 動作確認

WezTerm を起動する。`devbox.ps1 ensure` が VM の起動を担保してから、
ネイティブ SSH ドメイン `devbox-tmux` で devbox の tmux `main` セッションに attach する。

- 右下ステータスに `devbox` (緑) と出れば OK
- タブバーに tmux のウィンドウがタブ風に並ぶ
- 切断・スリープ後も WezTerm を開き直せば同じ画面に戻る (セッションの実体は devbox の tmux)

ショートカット一覧は `docs/qiita/terminal-shortcuts.md` を参照。

## トラブルシューティング

| 症状 | 原因/対処 |
|------|----------|
| 接続できない (タイムアウト) | `tailscale status` で devbox が見えるか確認。VM 停止中なら `devbox.ps1 up`。Tailscale 障害時は `ssh devbox-public` (先に NSG で現在 IP を許可) |
| シンボリックリンク作成に失敗 | 管理者 PowerShell で `install-windows.ps1` を実行するか、開発者モードを ON |
| 文字化け・アイコン欠け | HackGen Console NF / Symbols Nerd Font Mono が未インストール |
| `git push` が AutoFor のパスワードを求めて止まる | 手順 4 の credential 設定が未投入 |
| 通知トーストが出ない | BurntToast 未導入 or `register-wezterm-jump.ps1` 未実行。詳細は claude/ 側のドキュメント参照 |
| WezTerm 起動時に VM が起きない | `az login` が未実施 or 期限切れ (`devbox.ps1 status` で確認) |