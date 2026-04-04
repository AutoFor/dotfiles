# 新規セットアップガイド

新しい PC や別の環境にこの dotfiles を導入するための手順です。

## 事前に手動でインストールするもの

### WSL 側（必須）

以下のツールを **先に** インストールしてください。

| ツール | インストールコマンド | 用途 |
|--------|-------------------|------|
| **zsh** | `sudo apt install zsh && chsh -s $(which zsh)` | メインシェル |
| **zoxide** | `curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \| sh` | スマート cd（`z` コマンド） |
| **fzf** | `sudo apt install fzf` | ファジーファインダー（`cfd()` で使用） |
| **gh (GitHub CLI)** | `sudo apt install gh && gh auth login` | GitHub 操作 |
| **Git** | `sudo apt install git` | バージョン管理（通常はプリインストール済み） |
| **rclone** | `sudo apt install rclone && rclone config` | WSL フルバックアップのクラウド転送 |

### WSL 側（Claude Code を使う場合）

| ツール | インストールコマンド | 用途 |
|--------|-------------------|------|
| **Node.js** | `sudo apt install nodejs npm` | Claude Code の実行環境 |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | AI アシスタント |

### Windows 側（必須）

| ツール | インストール方法 | 用途 |
|--------|-----------------|------|
| **WSL** | `wsl --install` (PowerShell 管理者) | Linux 環境 |
| **WezTerm** | [公式サイト](https://wezfurlong.org/wezterm/)からダウンロード | ターミナルエミュレータ |
| **Developer Mode** | 設定 → システム → 開発者向け → 開発者モード ON | シンボリックリンク作成に必要 |

### Windows 側（任意）

| ツール | インストール方法 | 用途 |
|--------|-----------------|------|
| **Git for Windows** | [公式サイト](https://git-scm.com/)からダウンロード | Windows 側の Git 操作・credential manager |

## セットアップ手順

### ステップ 1: リポジトリをクローン（WSL 内で実行）

```bash
git clone --recurse-submodules https://github.com/AutoFor/dotfiles.git ~/dotfiles
```

> `--recurse-submodules` を忘れると `claude/` ディレクトリが空になります。
> 忘れた場合は `cd ~/dotfiles && git submodule update --init --recursive` で取得できます。

### ステップ 2: WSL 設定をインストール

```bash
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

**実行結果:**
- 各設定ファイルのシンボリックリンクが作成される
- 既存ファイルがある場合は `*.backup.YYYYMMDD` にバックアップされる
- `~/.local/bin/backup-wsl-full` などの補助スクリプトがリンクされる
- 何度実行しても安全（冪等）

### ステップ 3: Windows 設定をインストール

PowerShell を **管理者権限** で開いて実行:

```powershell
\\wsl$\Ubuntu\home\<ユーザー名>\dotfiles\install-windows.ps1
```

> `<ユーザー名>` は WSL のユーザー名に置き換えてください。

### ステップ 4: 確認

```bash
# 新しいターミナルを開く

# シンボリックリンクの確認
ls -la ~/.zshrc             # → ~/dotfiles/wsl/.zshrc
ls -la ~/.claude/CLAUDE.md  # → ~/dotfiles/claude/CLAUDE.md

# zsh が正常動作するか確認
zsh
```

## 環境に合わせて変更が必要な箇所

### .gitconfig のパス修正

`wsl/.gitconfig` 内のパスにユーザー名がハードコードされています。別のユーザー名の場合は修正してください。

```
[credential "https://github.com"]
    helper = !/home/<ユーザー名>/.local/bin/gh auth git-credential
```

### GitHub CLI の認証

```bash
gh auth login
```

ブラウザが開くので、GitHub アカウントで認証してください。

### Claude Code の認証

```bash
claude
```

初回起動時に API キーまたは認証の設定を求められます。

### rclone の認証

```bash
rclone config
```

Google Drive などの remote を作成してください。`backup-wsl-full` の既定値は `gdrive:WSL-FullBackups`。

## トラブルシューティング

| 症状 | 原因 | 対処法 |
|------|------|--------|
| `zsh: command not found: z` | zoxide 未インストール | zoxide をインストールする |
| `cfd()` が動かない | fzf 未インストール | `sudo apt install fzf` |
| `backup-wsl-full: command not found` | `install.sh` 未実行 or 新しいシェル未起動 | `./install.sh` 実行後にシェルを再起動 |
| `didn't find section in config file` | `rclone` remote 未設定 | `rclone config` で `gdrive:` を作成 |
| Windows でシンボリックリンクエラー | Developer Mode が無効 | 設定から Developer Mode を有効化 |
| `claude/` が空 | サブモジュール未取得 | `git submodule update --init --recursive` |
| WezTerm が WSL に接続しない | WSL 未インストール or 停止中 | `wsl --install` または `wsl --shutdown && wsl` |
