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

# SSH リモート: OSC 1337 SetUserVar を書き込み、手元の WezTerm の
# user-var-changed ハンドラ（.wezterm.lua）がタブの 🔔 マーク付けとトースト表示を行う。
# payload: ディレクトリ名 \t タイトル \t メッセージ \t tmuxペイン番号（%なし。tmux 外は空）
# 4番目のフィールドは LEADER+j / トーストクリックでの通知元ペインへのジャンプに使う。
HOST=$(hostname -s 2>/dev/null || echo remote)
FULL_TITLE="[$HOST:$DIR] $TITLE"
PAYLOAD=$(printf '%s\t%s\t%s\t%s' "$DIR" "$FULL_TITLE" "$MESSAGE" "${TMUX_PANE#%}" | base64 | tr -d '\n')

# tmux 内: 自ペインの pty に passthrough（ESC 二重化 + ESC Ptmux; ラップ）で書く。
# allow-passthrough on（.tmux.conf）とセットで tmux を透過して WezTerm に届く。
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1; then
  TTY=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}' 2>/dev/null)
  if [ -n "$TTY" ] && [ -w "$TTY" ]; then
    printf '\033Ptmux;\033\033]1337;SetUserVar=claude_notify=%s\007\033\\' "$PAYLOAD" > "$TTY" 2>/dev/null
  fi
  exit 0
fi

# tmux 外（wezterm mux 等）: 書き込み先 tty を特定する。
# Claude Code の hook プロセスには制御端末が無く /dev/tty を開けないことがあるため、
# その場合は $WEZTERM_PANE から wezterm cli でペインの pty を引く。
TTY=""
# サブシェルで開けるか試す（特殊ビルトインのリダイレクト失敗はシェルごと終了するため）
if (exec >/dev/tty) 2>/dev/null; then
  TTY=/dev/tty
elif [ -n "$WEZTERM_PANE" ] && command -v wezterm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  TTY=$(wezterm cli list --format json 2>/dev/null |
    jq -r --arg p "$WEZTERM_PANE" '.[] | select((.pane_id | tostring) == $p) | .tty_name // empty')
fi
if [ -n "$TTY" ] && [ -w "$TTY" ]; then
  printf '\033]1337;SetUserVar=claude_notify=%s\033\\' "$PAYLOAD" > "$TTY" 2>/dev/null
fi
exit 0
