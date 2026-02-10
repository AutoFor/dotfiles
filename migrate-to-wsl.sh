#!/bin/bash
# WSL側を正として .claude ディレクトリを統合する移行スクリプト
# 使用方法: bash migrate-to-wsl.sh
# 前提条件: WSL 環境内で実行すること
set -euo pipefail

WIN_CLAUDE="/mnt/c/Users/SeiyaKawashima/.claude"  # Windows側の .claude
WSL_CLAUDE="$HOME/.claude"                         # WSL側の .claude（移行先）

echo "=== .claude ディレクトリ WSL 移行スクリプト ==="
echo ""
echo "移行元 (Windows): $WIN_CLAUDE"
echo "移行先 (WSL):     $WSL_CLAUDE"
echo ""

# --- 事前チェック ---
if [ ! -d "$WIN_CLAUDE" ]; then
  echo "エラー: Windows側の .claude が見つかりません: $WIN_CLAUDE" >&2
  exit 1
fi

if [ -L "$WIN_CLAUDE" ]; then
  echo "エラー: Windows側の .claude は既にシンボリックリンクです（移行済み？）" >&2
  exit 1
fi

# --- Step 1: バックアップ ---
echo "[Step 1/5] バックアップを作成中..."

if [ -d "$WSL_CLAUDE" ] || [ -L "$WSL_CLAUDE" ]; then
  WSL_BACKUP="$HOME/.claude.bak.$(date +%Y%m%d-%H%M%S)"
  echo "  WSL側をバックアップ: $WSL_BACKUP"
  mv "$WSL_CLAUDE" "$WSL_BACKUP"
fi

WIN_BACKUP="${WIN_CLAUDE}.bak.$(date +%Y%m%d-%H%M%S)"
echo "  Windows側をバックアップ: $WIN_BACKUP"
cp -a "$WIN_CLAUDE" "$WIN_BACKUP"

echo "  完了"
echo ""

# --- Step 2: Windows → WSL コピー ---
echo "[Step 2/5] Windows側をWSL側にコピー中..."
cp -a "$WIN_CLAUDE" "$WSL_CLAUDE"
echo "  完了: $(du -sh "$WSL_CLAUDE" | cut -f1)"
echo ""

# --- Step 3: Windows固有パスを修正 ---
echo "[Step 3/5] Windows固有パスを修正中..."

# 3a. settings.json — フックをWSL用に、シェルをbashに変更
if [ -f "$WSL_CLAUDE/settings.json" ]; then
  cat > "$WSL_CLAUDE/settings.json" << 'SETTINGS_EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -File \"$(wslpath -w ~/.claude/windows-notify.ps1)\" -Title ' 応答完了' -Message 'セッションタグ作成完了' -IncludeWorkingDirectory"
          }
        ]
      }
    ]
  },
  "alwaysThinkingEnabled": true
}
SETTINGS_EOF
  echo "  settings.json: フックをWSL対応に変更、shell設定を削除"
fi

# 3b. settings.local.json — Windows固有パーミッションを削除してリセット
if [ -f "$WSL_CLAUDE/settings.local.json" ]; then
  cat > "$WSL_CLAUDE/settings.local.json" << 'LOCAL_EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Bash(git fetch:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(git worktree:*)",
      "Bash(git -C:*)",
      "Bash(gh:*)",
      "Bash(ls:*)",
      "Bash(rm:*)",
      "Bash(mkdir:*)",
      "Bash(echo:*)",
      "Bash(curl:*)",
      "Bash(npm install:*)",
      "Bash(python:*)",
      "Bash(bash:*)",
      "Bash(claude --version)",
      "Bash(claude mcp:*)",
      "WebSearch",
      "mcp__github__get_me",
      "mcp__github__list_issues",
      "mcp__github__issue_write",
      "mcp__github__issue_read",
      "mcp__github__create_pull_request",
      "mcp__github__update_pull_request",
      "mcp__github__merge_pull_request",
      "mcp__github__pull_request_review_write",
      "mcp__github__get_file_contents",
      "mcp__github__create_or_update_file",
      "mcp__github__list_branches",
      "mcp__github__sub_issue_write",
      "Skill(git-worktree-branch)"
    ],
    "deny": [],
    "ask": []
  }
}
LOCAL_EOF
  echo "  settings.local.json: Windows固有パスを削除し汎用パーミッションに整理"
fi

# 3c. plugins/known_marketplaces.json — パスをWSLに更新
MARKETPLACE_FILE="$WSL_CLAUDE/plugins/known_marketplaces.json"
if [ -f "$MARKETPLACE_FILE" ]; then
  sed -i "s|C:\\\\Users\\\\SeiyaKawashima\\\\.claude|$HOME/.claude|g" "$MARKETPLACE_FILE"
  echo "  plugins/known_marketplaces.json: installLocationをWSLパスに更新"
fi

echo "  完了"
echo ""

# --- Step 4: シンボリックリンク作成 ---
echo "[Step 4/5] シンボリックリンクを作成中..."
rm -rf "$WIN_CLAUDE"
ln -s "$WSL_CLAUDE" "$WIN_CLAUDE"
echo "  $WIN_CLAUDE → $WSL_CLAUDE"
echo "  完了"
echo ""

# --- Step 5: 動作確認 ---
echo "[Step 5/5] 動作確認..."

ERRORS=0

# シンボリックリンク確認
if [ -L "$WIN_CLAUDE" ]; then
  echo "  ✅ シンボリックリンクが正常に作成されています"
else
  echo "  ❌ シンボリックリンクが見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

# Skills 確認
if [ -d "$WSL_CLAUDE/skills" ]; then
  SKILL_COUNT=$(ls -1d "$WSL_CLAUDE/skills"/*/ 2>/dev/null | wc -l)
  echo "  ✅ Skills ディレクトリ: ${SKILL_COUNT} 個のスキル"
else
  echo "  ❌ Skills ディレクトリが見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

# Git リポジトリ確認
if git -C "$WSL_CLAUDE" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "  ✅ Git リポジトリが正常です"
else
  echo "  ❌ Git リポジトリが壊れています" >&2
  ERRORS=$((ERRORS + 1))
fi

# 設定ファイル確認
if [ -f "$WSL_CLAUDE/settings.json" ]; then
  echo "  ✅ settings.json が存在します"
else
  echo "  ❌ settings.json が見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

echo ""

if [ "$ERRORS" -eq 0 ]; then
  echo "=== 移行完了 ==="
  echo ""
  echo "バックアップは以下にあります（確認後に削除してください）:"
  [ -n "${WSL_BACKUP:-}" ] && echo "  - $WSL_BACKUP"
  echo "  - $WIN_BACKUP"
else
  echo "=== 移行完了（${ERRORS} 件のエラーあり） ===" >&2
  echo "バックアップから復元する場合:" >&2
  echo "  rm -f $WIN_CLAUDE" >&2
  echo "  mv $WIN_BACKUP $WIN_CLAUDE" >&2
  [ -n "${WSL_BACKUP:-}" ] && echo "  mv $WSL_BACKUP $WSL_CLAUDE" >&2
  exit 1
fi
