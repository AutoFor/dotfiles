#!/bin/bash
# WSL側を正として .claude ディレクトリを統合する移行スクリプト
# 使用方法: WSL 環境内で実行 → bash migrate-to-wsl.sh
# 実行後: Windows側はシンボリックリンクになり、WSL側が実体になる
set -euo pipefail

WIN_CLAUDE="/mnt/c/Users/SeiyaKawashima/.claude"
WSL_CLAUDE="$HOME/.claude"

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
echo "[Step 1/4] バックアップを作成中..."

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
echo "[Step 2/4] Windows側をWSL側にコピー中..."
cp -a "$WIN_CLAUDE" "$WSL_CLAUDE"
echo "  完了: $(du -sh "$WSL_CLAUDE" | cut -f1)"
echo ""

# --- Step 3: シンボリックリンク作成 ---
echo "[Step 3/4] シンボリックリンクを作成中..."
rm -rf "$WIN_CLAUDE"
ln -s "$WSL_CLAUDE" "$WIN_CLAUDE"
echo "  $WIN_CLAUDE → $WSL_CLAUDE"
echo "  完了"
echo ""

# --- Step 4: 動作確認 ---
echo "[Step 4/4] 動作確認..."

ERRORS=0

if [ -L "$WIN_CLAUDE" ]; then
  echo "  OK: シンボリックリンクが正常に作成されています"
else
  echo "  NG: シンボリックリンクが見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ -d "$WSL_CLAUDE/skills" ]; then
  SKILL_COUNT=$(ls -1d "$WSL_CLAUDE/skills"/*/ 2>/dev/null | wc -l)
  echo "  OK: Skills ディレクトリ: ${SKILL_COUNT} 個のスキル"
else
  echo "  NG: Skills ディレクトリが見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

if git -C "$WSL_CLAUDE" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "  OK: Git リポジトリが正常です"
else
  echo "  NG: Git リポジトリが壊れています" >&2
  ERRORS=$((ERRORS + 1))
fi

if [ -f "$WSL_CLAUDE/settings.json" ]; then
  echo "  OK: settings.json が存在します"
else
  echo "  NG: settings.json が見つかりません" >&2
  ERRORS=$((ERRORS + 1))
fi

echo ""

if [ "$ERRORS" -eq 0 ]; then
  echo "=== 移行完了 ==="
  echo ""
  echo "バックアップは以下にあります（確認後に削除してください）:"
  [ -n "${WSL_BACKUP:-}" ] && echo "  - $WSL_BACKUP"
  echo "  - $WIN_BACKUP"
  echo ""
  echo "注意: settings.json のフックコマンドをWSL用に更新してください。"
  echo "参考: hooks.md"
else
  echo "=== 移行完了（${ERRORS} 件のエラーあり） ===" >&2
  echo "バックアップから復元する場合:" >&2
  echo "  rm -f $WIN_CLAUDE" >&2
  echo "  mv $WIN_BACKUP $WIN_CLAUDE" >&2
  [ -n "${WSL_BACKUP:-}" ] && echo "  mv $WSL_BACKUP $WSL_CLAUDE" >&2
  exit 1
fi
