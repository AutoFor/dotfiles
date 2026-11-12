#!/usr/bin/env bash
set -euo pipefail

# ===== dotfiles インストーラ（Linux 用: Azure devbox 等） =====
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

echo "=== Linux 設定ファイルのリンク ==="

# --- ホームディレクトリ直下 ---
link_file "$DOTFILES_DIR/linux/.zshenv"   "$HOME/.zshenv"
link_file "$DOTFILES_DIR/linux/.zshrc"     "$HOME/.zshrc"
link_file "$DOTFILES_DIR/linux/.bashrc"    "$HOME/.bashrc"
link_file "$DOTFILES_DIR/linux/.gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/linux/.tmux.conf"  "$HOME/.tmux.conf"
# rpa への ssh 設定 (#238)。秘密鍵は追跡しないので、鍵が無い環境では
# ssh-keygen で作って rpa の administrators_authorized_keys に登録する
link_file "$DOTFILES_DIR/linux/.ssh/config" "$HOME/.ssh/config"

# --- .config 配下 ---
link_file "$DOTFILES_DIR/linux/.config/gh/config.yml" "$HOME/.config/gh/config.yml"
link_file "$DOTFILES_DIR/linux/.config/git/ignore"    "$HOME/.config/git/ignore"
link_file "$DOTFILES_DIR/nvim"          "$HOME/.config/nvim"

echo ""
echo "=== Claude Code 設定ファイルのリンク ==="

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# --- Claude 単体ファイル ---
link_file "$DOTFILES_DIR/claude/CLAUDE.md"                      "$CLAUDE_DIR/CLAUDE.md"
link_file "$DOTFILES_DIR/claude/settings.json"                  "$CLAUDE_DIR/settings.json"
link_file "$DOTFILES_DIR/claude/windows-notify.ps1"             "$CLAUDE_DIR/windows-notify.ps1"
link_file "$DOTFILES_DIR/claude/notify.sh"                      "$CLAUDE_DIR/notify.sh"
link_file "$DOTFILES_DIR/claude/gh-issue-start.sh"              "$CLAUDE_DIR/gh-issue-start.sh"
link_file "$DOTFILES_DIR/claude/github-app-config.env.example"  "$CLAUDE_DIR/github-app-config.env.example"

# --- Claude mcp ---
link_file "$DOTFILES_DIR/claude/mcp" "$CLAUDE_DIR/mcp"

# スキルは下の「スキルのリンク」で Claude Code / Codex にまとめて配る

echo ""
echo "=== ~/.local/bin スクリプトのリンク ==="

mkdir -p "$HOME/.local/bin"
for bin_file in "$DOTFILES_DIR/linux/.local/bin"/*; do
  bin_name="$(basename "$bin_file")"
  link_file "$bin_file" "$HOME/.local/bin/$bin_name"
done

echo ""
echo "=== Codex 設定ファイルのリンク ==="

CODEX_DIR="$HOME/.codex"
mkdir -p "$CODEX_DIR"

link_file "$DOTFILES_DIR/codex/config.toml" "$CODEX_DIR/config.toml"
# SessionStart hook: tmux ペイン → 会話 ID の記録 (tmux-claude-sessions track codex)
link_file "$DOTFILES_DIR/codex/hooks.json" "$CODEX_DIR/hooks.json"

echo ""
echo "=== スキルのリンク (Claude Code: ~/.claude/skills / Codex: ~/.agents/skills) ==="

# 正本は skills/ ひとつ。詳細は skills/README.md
bash "$DOTFILES_DIR/skills/link-skills.sh"

echo ""
echo "=== Kimi Code の SessionStart hook ==="

# ~/.kimi-code/config.toml は認証情報を含むためリポジトリ管理にしない。
# tmux ペイン → 会話 ID の記録用 hook だけを、無ければ追記する
KIMI_CONFIG="${KIMI_CODE_HOME:-$HOME/.kimi-code}/config.toml"
if [ -f "$KIMI_CONFIG" ]; then
  if grep -q "tmux-claude-sessions" "$KIMI_CONFIG"; then
    echo "  設定済み: $KIMI_CONFIG"
  else
    cat >> "$KIMI_CONFIG" <<'KIMI_HOOK'

# tmux ペイン → 会話 ID の記録 (dotfiles の install.sh が追記。tmux-claude-sessions 参照)
[[hooks]]
event = "SessionStart"
command = "sh \"$HOME/.local/bin/tmux-claude-sessions\" track kimi"
timeout = 5
KIMI_HOOK
    echo "  追記: $KIMI_CONFIG"
  fi
else
  echo "  スキップ: $KIMI_CONFIG が無い (kimi 未導入)"
fi

echo ""
echo "=== 常設の仮の画面 :99 (Xvfb + VNC + noVNC) ==="

# 実画面の Chrome が要るワーカーは DISPLAY=:99 で動かし、人は noVNC で覗く(RDP 不要)。
# 要るパッケージ: xvfb x11vnc novnc websockify openbox
for unit in devbox-display.service devbox-vnc.service devbox-novnc.service; do
  link_file "$DOTFILES_DIR/linux/.config/systemd/user/$unit" "$HOME/.config/systemd/user/$unit"
done
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now devbox-display.service devbox-vnc.service devbox-novnc.service
else
  echo "  スキップ: systemd --user が使えない"
fi

echo ""
echo "=== 起動時の tmux 自動起動 (#258) ==="

# VM が勝手に再起動しても、誰も attach しないうちに tmux サーバーを起こして
# tmux-autorestore の復元 (claude の会話の --resume を含む) を走らせる。
# ブート時に動かすには linger が要る (sudo loginctl enable-linger $USER)。
link_file "$DOTFILES_DIR/linux/.config/systemd/user/tmux-autostart.service" "$HOME/.config/systemd/user/tmux-autostart.service"
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  # --now は付けない。稼働中に start してもサーバーがあれば何もしないが、
  # 初回導入時に意図せず tmux サーバーを立ち上げないよう enable だけにする
  systemctl --user enable tmux-autostart.service
  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != yes ]; then
    echo "  注意: linger が無効。ブート時に動かすには sudo loginctl enable-linger $USER"
  fi
else
  echo "  スキップ: systemd --user が使えない"
fi

echo ""
echo "=== 完了 ==="
echo "新しいターミナルを開いて設定が反映されていることを確認してください。"
