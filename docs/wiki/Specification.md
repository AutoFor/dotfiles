# 仕様書

## 全体構成

```
~/dotfiles/
├── install.sh              # WSL 用インストーラ
├── install-windows.ps1     # Windows 用インストーラ
├── wsl/                    # WSL Ubuntu 設定ファイル
├── windows/                # Windows 設定ファイル
├── claude/                 # Claude Code 設定（サブモジュール）
└── wsl/.local/bin/         # WSL 補助スクリプト
```

![アーキテクチャ図](./images/architecture.svg)

## コンポーネント一覧

### install.sh（WSL インストーラ）

| 項目 | 内容 |
|------|------|
| 動作 | 設定ファイルのシンボリックリンクを作成 |
| 冪等性 | あり（何度実行しても安全） |
| バックアップ | 既存ファイルを `*.backup.YYYYMMDD` に退避 |
| 対象 | `.zshrc`, `.bashrc`, `.gitconfig`, `gh/config.yml`, `git/ignore`, Claude 設定一式 |

### install-windows.ps1（Windows インストーラ）

| 項目 | 内容 |
|------|------|
| 動作 | Windows 側のシンボリックリンクを作成 |
| 要件 | 管理者権限または Developer Mode |
| 対象 | `.wezterm.lua`, `.gitconfig`, `.bashrc` |

### WSL 設定ファイル

#### .zshrc

| 機能 | 説明 |
|------|------|
| プロンプト | `adam1` テーマを使用 |
| 履歴 | 1000 行、重複除去、シェル間共有 |
| 補完 | zsh 標準の高度な補完システム |
| zoxide | `z` コマンドによるスマートディレクトリ移動 |
| cfd() | fzf でカレントディレクトリ配下のフォルダを選択して cd |
| OSC 7 | WezTerm にカレントディレクトリを通知 |

### WSL 補助スクリプト

#### backup-wsl-full

| 項目 | 内容 |
|------|------|
| 動作 | `wsl.exe --export` でディストリ全体を `.tar` 化し、`rclone` でクラウドへ転送 |
| 一時置き場 | `C:\Users\<WindowsUser>\AppData\Local\WSLBackups\tmp` |
| 保存先 | `gdrive:WSL-FullBackups/<distro>/` |
| 保持 | 30 日より古い `.tar` を削除 |
| 失敗時 | upload 失敗時はローカル `.tar` を保持 |
| 制約 | 実行中の現在ディストリ自身は WSL 内から terminate せず、そのまま export |

### Windows 設定ファイル

#### .wezterm.lua

| 機能 | キー / 説明 |
|------|------------|
| デフォルトドメイン | WSL:Ubuntu |
| Leader キー | `Ctrl+q`（2秒タイムアウト） |
| タブバー | 矢印型タブ・透過・境界線なし |
| 透過 | `window_background_opacity = 1.0` |
| 左右分割 | `Ctrl+q` → `r` |
| 上下分割 | `Ctrl+q` → `d` |
| ペイン移動 | `Alt+h/l/k/j` |
| ペイン閉じ | `Ctrl+q` → `x` |
| コピーモード | `Ctrl+q` → `[`（vi ライク） |
| Workspace 切替 | `leader → w` |
| Workspace 名変更 | `Alt+E` |
| ステータスバー | 現在の Workspace 名を右端に表示 |
| ウィンドウタイトル | カレントディレクトリ名を表示 |
| キーバインド定義 | `windows/.wezterm.lua`（インライン管理） |

### Claude Code 設定（サブモジュール）

Git サブモジュールとして管理される外部リポジトリ。

| 内容 | 説明 |
|------|------|
| CLAUDE.md | グローバルルール（コーディング規約、GitHub 運用ルール） |
| settings.json | Claude Code の設定 |
| skills/ | 自動化スキル（Git Worktree、PR 作成、Wiki 更新 等） |
| mcp/ | MCP サーバー設定 |

## 前提条件

### WSL 側

- zsh
- zoxide（スマート cd）
- fzf（ファジーファインダー）
- gh（GitHub CLI）
- rclone（クラウド転送）
- Claude Code

### Windows 側

- WezTerm（ターミナルエミュレータ）
- Developer Mode（シンボリックリンク作成に必要）

## シンボリックリンク一覧

| ソース（dotfiles 内） | リンク先（実際に使われる場所） |
|----------------------|--------------------------|
| `wsl/.zshrc` | `~/.zshrc` |
| `wsl/.bashrc` | `~/.bashrc` |
| `wsl/.gitconfig` | `~/.gitconfig` |
| `wsl/.config/gh/config.yml` | `~/.config/gh/config.yml` |
| `wsl/.config/git/ignore` | `~/.config/git/ignore` |
| `wsl/.local/bin/backup-wsl-full` | `~/.local/bin/backup-wsl-full` |
| `wsl/.local/bin/gf` | `~/.local/bin/gf` |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/skills/*` | `~/.claude/skills/*` |
| `windows/.wezterm.lua` | Windows `~/.wezterm.lua` |
| `windows/.gitconfig` | Windows `~/.gitconfig` |
| `windows/.bashrc` | Windows `~/.bashrc` |
