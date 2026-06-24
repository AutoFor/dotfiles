# dotfiles

Linux / WSL Ubuntu + Windows の設定ファイルを一元管理するリポジトリ。

別 PC への移植を `git clone` + インストールスクリプトで完了できるようにする。

## ディレクトリ構成

```
~/dotfiles/
├── README.md
├── install.sh                    # Linux / WSL 用セットアップスクリプト
├── install-windows.ps1           # Windows 用セットアップスクリプト
├── .gitignore
│
├── wsl/                          # WSL Ubuntu 設定
│   ├── .zshrc
│   ├── .bashrc
│   ├── .gitconfig
│   ├── .config/
│   │   ├── gh/config.yml
│   │   └── git/ignore
│   └── .local/bin/
│       ├── gf
│       └── backup-wsl-full
│
├── windows/                      # Windows 設定
│   ├── .wezterm.lua
│   ├── .gitconfig
│   ├── .bashrc
│   └── yamabuki-r/
│
├── claude/                       # Claude Code 設定
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── windows-notify.ps1
│   ├── github-app-config.env.example
│   ├── mcp/mcp-config.json.example
│   └── skills/（9ディレクトリ）
│
└── codex/                        # Codex 設定
    ├── config.toml
    └── skills/
```

## 方針

- リポジトリ内の設定ファイルを実体として、各 OS のホームディレクトリへシンボリックリンクする
- 既存ファイルは `*.backup.YYYYMMDD` に退避する
- ユーザー名やホームディレクトリは `$HOME` / `$USERPROFILE` から解決する
- WSL 固有の設定は WSL 上でだけ適用し、通常の Linux ではスキップする
- Windows 側の WezTerm は `WEZTERM_WSL_DISTRO` / `WEZTERM_WSL_USER` で環境差分を上書きできる

## クリーンな Windows PC からの初回セットアップ

想定する初期状態:

- Windows は入っている
- Git / gh / WSL / WezTerm はまだ入っていない
- Codex または Claude Code だけ先に入っている場合もある

PowerShell は **管理者として実行** する。

### 1. Windows 側の基本ツールを入れる

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id wez.wezterm -e
winget install --id OpenJS.NodeJS.LTS -e
```

`winget` が使えない場合は Microsoft Store の「アプリ インストーラー」を更新する。

インストール後、新しい PowerShell を開いて確認する。

```powershell
git --version
gh --version
node --version
npm --version
```

### 2. WSL Ubuntu を入れる

```powershell
wsl --install -d Ubuntu
```

再起動を求められたら Windows を再起動する。初回起動時に Linux ユーザー名とパスワードを作成する。

既に WSL はあるが distro 名を確認したい場合:

```powershell
wsl -l -v
```

この README の例は distro 名を `Ubuntu` としている。`Ubuntu-24.04` など別名なら、後の `\\wsl$\Ubuntu\...` と `WEZTERM_WSL_DISTRO` を実際の名前に置き換える。

### 3. GitHub にログインする

PowerShell で:

```powershell
gh auth login
```

WSL 側でも後で `gh auth login` を実行する。Windows と WSL は別環境なので、両方で認証しておく。

### 4. WSL 側の基本ツールを入れる

Ubuntu を開いて実行する。

```bash
sudo apt update
sudo apt install -y git gh zsh curl unzip build-essential openssh-server rclone
```

GitHub CLI にログインする。

```bash
gh auth login
```

zsh を既定シェルにする。

```bash
chsh -s "$(which zsh)"
```

`zoxide` を入れる。

```bash
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

Claude Code / Codex を WSL 側でも使う場合は、Node.js が必要。Windows に Node.js が入っていても WSL とは別なので、WSL 側にも入れる。

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts
npm install -g @anthropic-ai/claude-code
npm install -g yaml-language-server
```

既に Codex CLI を Windows 側だけに入れている場合でも、WSL のシェルから使うなら WSL 側にも入れる。

### 5. リポジトリをクローン

WSL 側で実行する。

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
```

任意の場所に clone してよい。以降の例では `~/dotfiles` とする。

### 6. Linux / WSL 設定をインストール

```bash
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

既存ファイルは `*.backup.YYYYMMDD` にバックアップされる。

通常の Linux では `/etc/wsl.conf` と WSL 用 SSH 自動起動は自動でスキップされる。
sudo が必要なシステム設定を明示的に避ける場合:

```bash
INSTALL_SYSTEM_CONFIG=0 ./install.sh
```

### 7. Windows 設定をインストール

PowerShell（管理者）で実行：

```powershell
\\wsl$\Ubuntu\home\<ユーザー名>\dotfiles\install-windows.ps1
```

WSL distro 名が `Ubuntu` ではない場合は、実際の distro 名に置き換える。

管理者 PowerShell を使わない場合は、Windows の「開発者モード」を有効にしてから実行する。シンボリックリンク作成に必要。

Windows 側に直接 clone した場合:

```powershell
git clone https://github.com/AutoFor/dotfiles.git $env:USERPROFILE\dotfiles
Set-Location $env:USERPROFILE\dotfiles
.\install-windows.ps1
```

WezTerm から使う WSL distro / user が既定値と違う場合は、Windows のユーザー環境変数に設定する。

```powershell
[Environment]::SetEnvironmentVariable("WEZTERM_WSL_DISTRO", "Ubuntu-24.04", "User")
[Environment]::SetEnvironmentVariable("WEZTERM_WSL_USER", "your-linux-user", "User")
```

未設定時は distro は `Ubuntu`、ユーザー名とホームディレクトリは WSL 内から自動取得される。

### 8. WezTerm を起動する

Windows のスタートメニューから WezTerm を起動する。設定が正しければ WSL が開く。

WSL SSH ドメインを使う場合、この dotfiles は WSL 側の sshd を 2222 番で使う前提がある。接続できない場合でも WezTerm は WSL native domain へフォールバックする。

### 9. 確認

```bash
# シンボリックリンクの確認
ls -la ~/.zshrc             # → ~/dotfiles/wsl/.zshrc
ls -la ~/.claude/CLAUDE.md  # → ~/dotfiles/claude/CLAUDE.md

# 新しいターミナルを開いて動作確認
```

## 既に Linux / WSL がある場合の短縮手順

必要なツールが入っていれば、WSL 側では以下だけでよい。

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## 日常の使い方（設定を変更したいとき）

### シンボリックリンクの仕組み

`install.sh` を実行すると、各設定ファイルに「ショートカット」（シンボリックリンク）が作られる。

```
~/.zshrc  →  ~/dotfiles/wsl/.zshrc
（ショートカット）   （本体ファイル）
```

どちらを開いても同じファイルが表示されるが、**Git で管理されているのは `~/dotfiles/` の中**。

### 編集するファイル

設定を変えたいときは `~/dotfiles/` 内のファイルを編集する。

```bash
# 例: zshrc を編集
vim ~/dotfiles/wsl/.zshrc

# 例: WezTerm の設定を変更
vim ~/dotfiles/windows/.wezterm.lua

# 例: Claude Code の設定を変更
vim ~/dotfiles/claude/CLAUDE.md
```

| 編集するファイル | 実際に効く場所 |
|---|---|
| `~/dotfiles/wsl/.zshrc` | `~/.zshrc` |
| `~/dotfiles/wsl/.gitconfig` | `~/.gitconfig` |
| `~/dotfiles/wsl/.bashrc` | `~/.bashrc` |
| `~/dotfiles/windows/.wezterm.lua` | Windows の `~/.wezterm.lua` |
| `~/dotfiles/windows/.gitconfig` | Windows の `~/.gitconfig` |
| `~/dotfiles/windows/yamabuki-r/layout` | `C:\Prog\YamabukiR\layout` |
| `~/dotfiles/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `~/dotfiles/claude/settings.json` | `~/.claude/settings.json` |
| `~/dotfiles/codex/config.toml` | `~/.codex/config.toml` |

### コマンド短縮

WSL の zsh / bash では、`codex -y` を以下の短縮として使える。

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

### 変更を GitHub に保存する

```bash
cd ~/dotfiles
git status                          # 変更を確認
git add -A                          # 変更をステージング
git commit -m "zshrc にエイリアスを追加"  # コミット
git push                            # GitHub にプッシュ
```

### 別のPCに移すとき

Linux / WSL:

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Windows:

```powershell
git clone https://github.com/AutoFor/dotfiles.git $env:USERPROFILE\dotfiles
Set-Location $env:USERPROFILE\dotfiles
.\install-windows.ps1
```

この手順で各 OS のホームディレクトリにリンクが作られる。

## WSL 丸ごとバックアップ

`backup-wsl-full` は `wsl.exe --export` を使って WSL ディストリを `.tar` に書き出し、`rclone` で Google Drive へアップロードし、30 日より古いバックアップを削除する。

```bash
backup-wsl-full --distro Ubuntu
```

既定値:

- 一時置き場: `C:\Users\<WindowsUser>\AppData\Local\WSLBackups\tmp`
- 保存先: `gdrive:WSL-FullBackups/<distro>/`
- 保持期間: 30 日

よく使うオプション:

```bash
backup-wsl-full --dry-run
backup-wsl-full --distro Ubuntu --keep-local
backup-wsl-full --distro Ubuntu --remote gdrive:WSL-FullBackups --retention-days 30
```

注意:

- `rclone config` で `gdrive:` remote を事前に設定しておく必要がある
- 実行中の現在のディストリ自身は WSL 内から `terminate` できないため、その場合は停止せずに export する
- アップロード失敗時は再送のため一時 `.tar` を残す

## 注意事項

- Windows のシンボリックリンク作成には管理者権限または Developer Mode が必要
- Windows + WSL で WezTerm を使う場合、distro 名が `Ubuntu` 以外なら `WEZTERM_WSL_DISTRO` を設定する
- WSL SSH ドメインを使う場合は、WSL 側で `ssh` をインストールし、2222 番で接続できる状態にする
- Git のユーザー名とメールは `wsl/.gitconfig` / `windows/.gitconfig` の `[user]` を各自の値に変える
- Codex の trusted project はマシンごとのローカル情報なので、共有設定には固定パスを入れない
- `.profile` にシークレットが含まれている場合はリポジトリに含めないこと
- `install.sh` は冪等: 何度実行しても安全
