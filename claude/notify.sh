#!/bin/sh
# Claude Code hook 通知スクリプト（WSL / SSH リモート両対応）
# 使い方: notify.sh <Title> <Message> [Sound]
# stdin の hook JSON から cwd を読み取り、タイトルに [ディレクトリ名] を付ける

TITLE="${1:-Notification}"
MESSAGE="${2:-}"
SOUND="${3:-Reminder}"

# 通知元の作業ディレクトリ（hook JSON の cwd → 環境変数 → カレントの順）
CWD=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null)
  if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
    CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  fi
fi
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
DIR=$(basename "$CWD")

PWSH="/mnt/c/Users/saint/AppData/Local/Microsoft/WindowsApps/pwsh.exe"
if command -v wslpath >/dev/null 2>&1 && [ -x "$PWSH" ]; then
  # WSL: BurntToast で Windows トースト通知
  exec "$PWSH" -ExecutionPolicy Bypass \
    -File "$(wslpath -w "$HOME/.claude/windows-notify.ps1")" \
    -Title "[$DIR] $TITLE" -Message "$MESSAGE" -Sound "$SOUND" </dev/null
fi

# SSH リモート: 端末エスケープシーケンスで手元の WezTerm に届ける
if [ -w /dev/tty ]; then
  HOST=$(hostname -s 2>/dev/null || echo remote)
  FULL_TITLE="[$HOST:$DIR] $TITLE"
  PAYLOAD=$(printf '%s\t%s\t%s' "$DIR" "$FULL_TITLE" "$MESSAGE" | base64 | tr -d '\n')
  {
    # OSC 777: WezTerm がトースト通知を表示（SSH 越しでも届く）
    printf '\033]777;notify;%s;%s\033\\' "$FULL_TITLE" "$MESSAGE"
    # OSC 1337 SetUserVar: 通知元ペインの記録とタブの 🔔 マーク付けを
    # .wezterm.lua の user-var-changed ハンドラで行う
    printf '\033]1337;SetUserVar=claude_notify=%s\033\\' "$PAYLOAD"
  } 2>/dev/null > /dev/tty
fi
exit 0
