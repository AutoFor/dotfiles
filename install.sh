#!/usr/bin/env bash
set -euo pipefail

# ===== dotfiles インストーラ（WSL 用） =====
# 既存ファイルをバックアップしてからシンボリックリンクを作成する。
# 冪等: 何度実行しても安全。

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d)"

# --- ヘルパー関数 ---

link_file() {
  local src="$1"
  local dest="$2"

  # 既にリンクが正しければスキップ
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "  [skip] $dest → 既にリンク済み"
    return
  fi

  # 既存ファイル/ディレクトリがあればバックアップ
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "  [backup] $dest → ${dest}${BACKUP_SUFFIX}"
    mv "$dest" "${dest}${BACKUP_SUFFIX}"
  fi

  # 親ディレクトリを作成
  mkdir -p "$(dirname "$dest")"

  ln -s "$src" "$dest"
  echo "  [link] $dest → $src"
}

echo "=== WSL 設定ファイルのリンク ==="

# --- WSL ホームディレクトリ直下 ---
link_file "$DOTFILES_DIR/wsl/.zshrc"     "$HOME/.zshrc"
link_file "$DOTFILES_DIR/wsl/.bashrc"    "$HOME/.bashrc"
link_file "$DOTFILES_DIR/wsl/.gitconfig" "$HOME/.gitconfig"

# --- WSL .config 配下 ---
link_file "$DOTFILES_DIR/wsl/.config/gh/config.yml" "$HOME/.config/gh/config.yml"
link_file "$DOTFILES_DIR/wsl/.config/git/ignore"    "$HOME/.config/git/ignore"
link_file "$DOTFILES_DIR/wsl/.config/nvim"          "$HOME/.config/nvim"

echo ""
echo "=== Claude Code 設定ファイルのリンク ==="

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# --- Claude 単体ファイル ---
link_file "$DOTFILES_DIR/claude/CLAUDE.md"                      "$CLAUDE_DIR/CLAUDE.md"
link_file "$DOTFILES_DIR/claude/settings.json"                  "$CLAUDE_DIR/settings.json"
link_file "$DOTFILES_DIR/claude/windows-notify.ps1"             "$CLAUDE_DIR/windows-notify.ps1"
link_file "$DOTFILES_DIR/claude/github-app-config.env.example"  "$CLAUDE_DIR/github-app-config.env.example"

# --- Claude mcp ---
link_file "$DOTFILES_DIR/claude/mcp" "$CLAUDE_DIR/mcp"

# --- Claude skills（ディレクトリ単位） ---
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$DOTFILES_DIR/claude/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link_file "$DOTFILES_DIR/claude/skills/$skill_name" "$CLAUDE_DIR/skills/$skill_name"
done

echo ""
echo "=== ~/.local/bin スクリプトのリンク ==="

mkdir -p "$HOME/.local/bin"
for bin_file in "$DOTFILES_DIR/wsl/.local/bin"/*; do
  bin_name="$(basename "$bin_file")"
  link_file "$bin_file" "$HOME/.local/bin/$bin_name"
done

echo ""
echo "=== Codex 設定ファイルのリンク ==="

CODEX_DIR="$HOME/.codex"
mkdir -p "$CODEX_DIR/skills"

link_file "$DOTFILES_DIR/codex/config.toml" "$CODEX_DIR/config.toml"

for skill_dir in "$DOTFILES_DIR/codex/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link_file "$DOTFILES_DIR/codex/skills/$skill_name" "$CODEX_DIR/skills/$skill_name"
done

echo ""
echo "=== 完了 ==="
echo "新しいターミナルを開いて設定が反映されていることを確認してください。"
