#!/usr/bin/env bash
# ===== スキルを Claude Code と Codex の両方へリンクする (Linux / macOS) =====
# 正本: dotfiles/skills/<name>/  (1 スキル = 1 フォルダ。ここだけを編集する)
# リンク先:
#   Claude Code → ~/.claude/skills/<name>
#   Codex       → ~/.agents/skills/<name>   (Codex 公式のユーザースコープ)
# スキルフォルダに .skill-scope を置くと対象を絞れる (無ければ全 OS・全エージェント):
#   os: windows,linux
#   agents: claude,codex
# LINK_SKILLS_QUIET=1 で変化があった行だけ出す (cron 用)。
# 冪等。dotfiles 管理外のスキル (synced/ や手で置いたもの) には触らない。
# 同名の実フォルダがあれば ~/.claude/backups/skills-<日時>/ に退避してからリンクする
# (skills/ 直下に退避すると重複スキルとして読まれてしまうため)。
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -P "$SCRIPT_DIR/.." && pwd)}"
SKILLS_SRC="$DOTFILES_DIR/skills"
OS_NAME="linux"
BACKUP_DIR="$HOME/.claude/backups/skills-$(date +%Y%m%d%H%M%S)"

# スキルが (os, agent) の対象か。.skill-scope の該当キーが無ければ対象
in_scope() {
  local skill_dir="$1" os="$2" agent="$3" scope="$1/.skill-scope" line
  [ -f "$scope" ] || return 0
  line="$(grep -E '^os:' "$scope" | head -1 | cut -d: -f2- | tr -d ' \r' || true)"
  if [ -n "$line" ] && [[ ",$line," != *",$os,"* ]]; then return 1; fi
  line="$(grep -E '^agents:' "$scope" | head -1 | cut -d: -f2- | tr -d ' \r' || true)"
  if [ -n "$line" ] && [[ ",$line," != *",$agent,"* ]]; then return 1; fi
  return 0
}

# dest_root 内の、dotfiles を指すリンクのうち 先が消えた/対象外 になったものを外す
prune_links() {
  local dest_root="$1" agent="$2" link target name
  for link in "$dest_root"/*; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    case "$target" in "$DOTFILES_DIR"/*) ;; *) continue ;; esac
    name="$(basename "$link")"
    if [ "$target" != "$SKILLS_SRC/$name" ] || [ ! -d "$target" ] || ! in_scope "$target" "$OS_NAME" "$agent"; then
      rm "$link"
      echo "  [unlink] $link"
    fi
  done
}

link_skill() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    [ -n "${LINK_SKILLS_QUIET:-}" ] || echo "  [skip] $dest"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest").$(basename "$(dirname "$dest")")"
    echo "  [backup] $dest → $BACKUP_DIR/"
  fi
  ln -s "$src" "$dest"
  echo "  [link] $dest → $src"
}

sync_agent() {
  local agent="$1" dest_root="$2" skill name
  [ -n "${LINK_SKILLS_QUIET:-}" ] || echo "--- $agent: $dest_root"
  mkdir -p "$dest_root"
  prune_links "$dest_root" "$agent"
  for skill in "$SKILLS_SRC"/*/; do
    skill="${skill%/}"
    name="$(basename "$skill")"
    in_scope "$skill" "$OS_NAME" "$agent" || { [ -n "${LINK_SKILLS_QUIET:-}" ] || echo "  [scope] $name は $OS_NAME/$agent 対象外"; continue; }
    link_skill "$skill" "$dest_root/$name"
  done
}

sync_agent claude "$HOME/.claude/skills"
sync_agent codex  "$HOME/.agents/skills"

# 旧配置 ~/.codex/skills の dotfiles リンクは撤去 (~/.agents/skills と二重に読まれるため)。
# .system など Codex 自身が置いたものには触らない
if [ -d "$HOME/.codex/skills" ]; then
  for link in "$HOME/.codex/skills"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in "$DOTFILES_DIR"/*) rm "$link"; echo "  [unlink legacy] $link" ;; esac
  done
fi
