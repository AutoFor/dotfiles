# dotfiles

「Windows クライアント + Azure 開発サーバー (devbox)」構成の設定ファイルを一元管理するリポジトリ。

- **Windows** … 接続クライアント。WezTerm から Tailscale 経由の SSH で devbox の tmux に attach する
- **Azure devbox** … 開発の本体。zsh / Neovim / Claude Code / tmux セッションはすべてここで動く

別 PC への移植を `git clone` + インストールスクリプトで完了できるようにする
（手順は [docs/wiki/Setup-Guide.md](docs/wiki/Setup-Guide.md)）。

## 全体像

```
Windows (クライアント)                    Azure devbox (開発サーバー)
┌────────────────────────┐              ┌──────────────────────────┐
│ WezTerm                │ SSH          │ tmux (main セッション)     │
│  └─ devbox-tmux ドメイン┼──────────────┼→ zsh / nvim / claude      │
│ devbox.ps1 (az CLI)    │ Tailscale経由 │   セッションはここに永続    │
└────────────────────────┘              └──────────────────────────┘
```

接続は WezTerm の **ネイティブ SSH ドメイン `devbox-tmux`** で、devbox の tmux `main`
セッションに attach する (#214)。セッションの実体は devbox の tmux にあるため、
PC の休止・スリープ・切断でローカルの SSH が切れても、WezTerm を開き直すだけで
ウィンドウ/ペイン構成・実行中プロセスごと復帰する。タブ/ペイン管理のキーは
WezTerm から tmux にブリッジされ、tmux のウィンドウ一覧が WezTerm のタブバーに表示される。
iPad/iPhone (Termius) など他のクライアントからも `ssh devbox` → 同じセッションに入れる。

SSH の経路は **Tailscale**（IP はノード固有で不変。PR #218）。旧 wezterm mux ドメイン
（`azure`）は切り分け用フォールバックとして残している。

VM の自動起動は `windows/bin/devbox.ps1` が担い、WezTerm 起動時に自動実行される
（Tailscale 経由なので NSG の操作は通常不要）。

## ディレクトリ構成

```
~/dotfiles/
├── README.md
├── install.sh                    # Linux (Azure devbox 等) 用セットアップスクリプト
├── install-windows.ps1           # Windows 用セットアップスクリプト
│
├── nvim/                         # Neovim 設定（Linux / Windows 共有・OS分岐）
│
├── linux/                        # Linux (Azure devbox 等) 設定
│   ├── .zshenv / .zshrc / .bashrc
│   ├── .gitconfig
│   ├── .config/
│   │   ├── gh/config.yml
│   │   └── git/ignore
│   └── .local/bin/
│       ├── gf
│       └── codex
│
├── windows/                      # Windows (クライアント) 設定
│   ├── .wezterm.lua
│   ├── .gitconfig
│   ├── .bashrc
│   ├── bin/devbox.ps1            # devbox の起動/接続 CLI (ensure/connect/up/down/status)
│   └── yamabuki-r/
│
├── cloud/azure-devbox/           # Azure devbox の構築 (create-vm.sh / bootstrap.sh)
│
├── claude/                       # Claude Code 設定（devbox 側にリンクされる）
└── codex/                        # Codex 設定
```

## 方針

- リポジトリ内の設定ファイルを実体として、各 OS のホームディレクトリへシンボリックリンクする
- 既存ファイルは `*.backup.YYYYMMDD` に退避する
- ユーザー名やホームディレクトリは `$HOME` / `$USERPROFILE` から解決する
- 環境の違いはディレクトリ（`linux/` / `windows/`）と実行時判定で吸収する（ブランチでは分けない）
- 開発環境は Azure devbox に集約する。ローカル（Windows）は接続と最小限のツールのみ

## セットアップ

### 1. Windows クライアント

PowerShell で基本ツールを入れる。

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e
winget install --id Microsoft.PowerShell -e     # pwsh (devbox.ps1 / 通知スクリプトが使う)
winget install --id Microsoft.AzureCLI -e
winget install --id x-motemen.ghq -e
winget install --id tailscale.tailscale -e      # devbox への SSH 経路
```

フォントを入れる（WezTerm 設定が参照。ユーザーローカルで可）:
[HackGen Console NF](https://github.com/yuru7/HackGen/releases) と
[Symbols Nerd Font Mono](https://www.nerdfonts.com/font-downloads)。

ログインする。

```powershell
gh auth login
az login
tailscale up     # devbox と同じ tailnet に参加。tailscale status に devbox が見えること
```

ghq でリポジトリを取得し、リンクを張る（シンボリックリンク作成に管理者権限または開発者モードが必要）。

```powershell
ghq get AutoFor/dotfiles
Set-Location "$env:USERPROFILE\ghq\github.com\AutoFor\dotfiles"
.\install-windows.ps1
```

WezTerm は `devbox.ps1` を「環境変数 `DOTFILES_DIR` → ghq 既定パス → `~/dotfiles`」の順で探すので、
標準配置なら追加設定は不要。別の場所に置いた場合だけ `DOTFILES_DIR` を設定する。

クローン直後に、このリポジトリの同期設定を入れる（詳細は [CLAUDE.md](CLAUDE.md) の「同期」）:

```powershell
git config core.hooksPath .githooks                                   # コミット即 push フック
git config pull.rebase true
git config rebase.autostash true
git config credential.helper ""                                      # 空にリセット (下の 2 行を効かせる)
git config credential.https://github.com.username <GitHubユーザー名>
git config credential.https://github.com.helper '!gh auth git-credential'
```

> `windows/.gitconfig`（グローバルにリンクされる）が `credential.username = AutoFor` を
> 持っているため、この設定を入れないと `git push` がパスワード入力で止まる。

SSH 鍵が無ければ作成する。公開鍵は devbox の `~/.ssh/authorized_keys` に登録する
（`create-vm.sh` で VM を作った場合は作成時に登録済み。既存クライアントがあるなら
そこから `ssh devbox` して追記するのが早い）。

```powershell
ssh-keygen -t ed25519
```

通知トースト（Claude Code の完了通知。任意）を使うなら:

```powershell
Install-Module BurntToast -Scope CurrentUser
pwsh -File windows\bin\register-wezterm-jump.ps1   # クリックでペインへジャンプする URI スキーム登録 (HKCU)
```

### 2. Azure devbox（開発サーバー）

VM の作成から開発環境の流し込みまでは [cloud/azure-devbox/README.md](cloud/azure-devbox/README.md) を参照。
要点は次の 2 コマンド。

```bash
bash cloud/azure-devbox/create-vm.sh
ssh azureuser@<IP> 'bash -s' < cloud/azure-devbox/bootstrap.sh
```

`bootstrap.sh` が dotfiles の clone と `install.sh` の実行、wezterm-mux-server の導入
（Windows クライアントと同一バージョン固定）まで面倒を見る。

初回だけ VM 内で各サービスにログインする。

```bash
gh auth login
claude    # 初回起動で認証
```

### 3. 動作確認

WezTerm を起動すると `devbox.ps1 ensure`（VM 起動の担保）を経てネイティブ SSH ドメイン
`devbox-tmux` で接続され、devbox の tmux `main` セッションが開く。
右下ステータスに `devbox`（緑）、タブバーに tmux ウィンドウが並んでいれば OK。

## 日常の使い方

### 接続まわり（LEADER は `Ctrl+q`）

| 操作 | 動作 |
|---|---|
| WezTerm 起動 | VM 起動を担保して devbox の tmux `main` に attach |
| `Ctrl+t` | 新規 tmux ウィンドウ（タブバーにタブとして並ぶ） |
| `LEADER a` | VM 起動を担保してから devbox の tmux タブを開く（休止明けなど） |
| `LEADER Shift+A` | 旧 mux ドメイン（azure）に attach（切り分け用フォールバック） |
| `LEADER Shift+D` | 旧 mux ドメインから detach |
| `LEADER l` | ランチャー（tmux / mux フォールバック / 素の SSH / PowerShell） |
| `LEADER Shift+P` | ローカル PowerShell を新規タブで開く |

**休止・スリープ明け**: ローカルの接続は切れるが、セッションの実体は devbox の tmux に
生きている。WezTerm を開き直せば元の画面がそのまま戻る。

キーバインド・コピー操作・URL オープンなどの全ショートカットは
[docs/qiita/terminal-shortcuts.md](docs/qiita/terminal-shortcuts.md) を参照。

### VM の起動・停止（課金対策）

```powershell
# install-windows.ps1 が ~/.local/bin/devbox.ps1 にリンクしている
pwsh -File $env:USERPROFILE\.local\bin\devbox.ps1 status
pwsh -File $env:USERPROFILE\.local\bin\devbox.ps1 up
pwsh -File $env:USERPROFILE\.local\bin\devbox.ps1 down   # deallocate（課金はディスク代のみ）
```

毎日 22:00 の自動シャットダウンも設定済み（create-vm.sh）。

### 設定を変更したいとき

設定を変えたいときは `~/dotfiles/` 内のファイルを編集する（リンク先に実体がある）。

| 編集するファイル | 実際に効く場所 |
|---|---|
| `linux/.zshrc` ほか linux/ 配下 | devbox の `~/.zshrc` など |
| `windows/.wezterm.lua` | Windows の `~/.wezterm.lua` |
| `windows/.gitconfig` | Windows の `~/.gitconfig` |
| `windows/.ssh/config` | Windows の `~/.ssh/config`（`ssh devbox` の定義） |
| `windows/bin/devbox.ps1` | WezTerm 起動時 / `~/.local/bin/devbox.ps1` |
| `nvim/`（init.lua, lua/） | devbox: `~/.config/nvim` / Windows: `%LOCALAPPDATA%\nvim` |
| `claude/CLAUDE.md` / `claude/settings.json` | devbox の `~/.claude/` |
| `codex/config.toml` | devbox の `~/.codex/config.toml` |

変更の保存は devbox 上（または Windows 上）の clone から通常どおり commit / push する。

## Neovim の機能プロファイル

nvim 設定は Linux / Windows で共有し、OS 差分は `nvim/lua/os_util.lua` が、読み込む機能の範囲は `nvim/lua/features.lua` が制御する。

「どこまで読み込むか」は環境変数 `NVIM_PROFILE` で切り替える。

| 値 | 挙動 |
|---|---|
| `auto`（既定） | 外部コマンド（rg / cc・zig / node / gh / claude / codex / glow）の有無を検出し、使えるものだけ有効化 |
| `core` | 外部依存のないコア機能（ツリー・配色・fold・csv・outline・scratch・キーマップ）だけ |
| `full` | すべて有効化（未インストールでも読み込みを試みる） |

```powershell
# 例: 最小構成で起動（Windows）
$env:NVIM_PROFILE = "core"; nvim
```

個別に上書きしたいときは、`nvim/lua/features_local.lua`（Git 管理外）を作る。

```lua
-- nvim/lua/features_local.lua の例
return {
  treesitter = false,  -- このマシンでは treesitter を切る
  telescope = true,
}
```

## 注意事項

- Windows のシンボリックリンク作成には管理者権限または Developer Mode が必要
- `devbox.ps1` は 22 番に到達できる場合 az CLI を呼ばない。az が要るのは VM 起動のときだけ。
  SSH は Tailscale 経由なので NSG の操作は通常不要（公開 IP フォールバック `ssh devbox-public`
  を使うときだけ、先に NSG で現在 IP を許可する）
- 旧 mux ドメイン（フォールバック）を使う場合のみ、Windows / devbox の wezterm バージョンが
  一致している必要がある（bootstrap.sh の `WEZTERM_VERSION` を Windows 側に合わせる）。
  通常運用のネイティブ SSH + tmux はバージョン差があっても動く
- Git のユーザー名とメールは `linux/.gitconfig` / `windows/.gitconfig` の `[user]` を各自の値に変える
- Codex の trusted project はマシンごとのローカル情報なので、共有設定には固定パスを入れない
- `install.sh` / `install-windows.ps1` は冪等: 何度実行しても安全
- 旧構成（WSL 前提）の記述・スクリプトは #212 で廃止した。WSL 時代のファイルが必要になったら Git 履歴を参照
