# dotfiles

WSL Ubuntu と Windows の設定ファイルを一か所にまとめて管理するリポジトリです。

## このリポジトリの目的

新しい PC をセットアップするとき、ターミナルやエディタの設定を一からやり直すのは大変です。このリポジトリは、**`git clone` と1つのスクリプト実行だけ**で、すべての設定を自動復元できるようにします。

## 何が管理されているか

| カテゴリ | 内容 | 例 |
|---------|------|-----|
| WSL シェル設定 | zsh / bash の設定、プロンプト、エイリアス | `.zshrc`, `.bashrc` |
| Git 設定 | コミット名、除外ファイル | `.gitconfig`, `git/ignore` |
| ターミナル設定 | WezTerm のキーバインド、分割設定 | `.wezterm.lua` |
| GitHub CLI 設定 | gh コマンドの設定 | `gh/config.yml` |
| Claude Code 設定 | AI アシスタントのルール、スキル | `CLAUDE.md`, `skills/` |

## セットアップ方法

### 1. リポジトリをクローン

```bash
git clone https://github.com/AutoFor/dotfiles.git ~/dotfiles
```

### 2. WSL 設定をインストール

```bash
cd ~/dotfiles && ./install.sh
```

### 3. Windows 設定をインストール（PowerShell 管理者）

```powershell
\\wsl$\Ubuntu\home\<ユーザー名>\dotfiles\install-windows.ps1
```

## 仕組み

`install.sh` は「シンボリックリンク」という仕組みを使います。設定ファイルの「ショートカット」を本来の場所に作り、本体は `~/dotfiles/` に残します。

```
~/.zshrc → ~/dotfiles/wsl/.zshrc（本体）
```

設定を変えたいときは `~/dotfiles/` 内のファイルを編集し、Git で保存・共有できます。

## 関連ページ

- [新規セットアップガイド](./Setup-Guide) - 別PCでのインストール手順
- [仕様書](./Specification) - 機能の詳細
