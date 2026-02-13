# dotfiles

WSL Ubuntu + Windows の設定ファイルを一元管理するリポジトリ。

別PCへの移植を `git clone` + `./install.sh` だけで完了できるようにする。

## ディレクトリ構成

```
~/dotfiles/
├── README.md
├── install.sh                    # WSL 用セットアップスクリプト
├── install-windows.ps1           # Windows 用セットアップスクリプト
├── .gitignore
│
├── wsl/                          # WSL Ubuntu 設定
│   ├── .zshrc
│   ├── .bashrc
│   ├── .gitconfig
│   └── .config/
│       ├── gh/config.yml
│       └── git/ignore
│
├── windows/                      # Windows 設定
│   ├── .wezterm.lua
│   ├── .gitconfig
│   └── .bashrc
│
└── claude/                       # Claude Code 設定
    ├── CLAUDE.md
    ├── settings.json
    ├── windows-notify.ps1
    ├── github-app-config.env.example
    ├── mcp/mcp-config.json.example
    └── skills/（9ディレクトリ）
```

## 前提条件

### WSL 側

- **zsh**: `sudo apt install zsh && chsh -s $(which zsh)`
- **zoxide**: `curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh`
- **gh (GitHub CLI)**: `sudo apt install gh && gh auth login`
- **Claude Code**: `npm install -g @anthropic-ai/claude-code`

### Windows 側

- **WezTerm**: [公式サイト](https://wezfurlong.org/wezterm/)からインストール
- **Developer Mode** が有効（シンボリックリンク作成に必要）

## セットアップ手順

### 1. リポジトリをクローン

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
```

### 2. WSL 設定をインストール

```bash
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

既存ファイルは `*.backup.YYYYMMDD` にバックアップされる。

### 3. Windows 設定をインストール

PowerShell（管理者）で実行：

```powershell
\\wsl$\Ubuntu\home\<ユーザー名>\dotfiles\install-windows.ps1
```

### 4. 確認

```bash
# シンボリックリンクの確認
ls -la ~/.zshrc             # → ~/dotfiles/wsl/.zshrc
ls -la ~/.claude/CLAUDE.md  # → ~/dotfiles/claude/CLAUDE.md

# 新しいターミナルを開いて動作確認
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
| `~/dotfiles/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `~/dotfiles/claude/settings.json` | `~/.claude/settings.json` |

### 変更を GitHub に保存する

```bash
cd ~/dotfiles
git status                          # 変更を確認
git add -A                          # 変更をステージング
git commit -m "zshrc にエイリアスを追加"  # コミット
git push                            # GitHub にプッシュ
```

### 別のPCに移すとき

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

この3行だけで全設定が復元される。

## 注意事項

- WSL `.gitconfig` 内のパス（`/home/seiya-kawashima/...`）は別PCではユーザー名に合わせて変更が必要
- Windows のシンボリックリンク作成には管理者権限または Developer Mode が必要
- `.profile` にシークレットが含まれている場合はリポジトリに含めないこと
- `install.sh` は冪等: 何度実行しても安全
