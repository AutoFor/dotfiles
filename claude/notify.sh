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

# SSH リモート: 手元の WezTerm に OSC で届けるか、届かないなら ntfy に流す。
# payload: ディレクトリ名 \t タイトル \t メッセージ \t tmuxペイン番号（%なし。tmux 外は空）
# 4番目のフィールドは LEADER+j / トーストクリックでの通知元ペインへのジャンプに使う。
IN_TMUX=0
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1; then
  IN_TMUX=1
fi

# 複数ウィンドウで Claude Code を並行実行していてもどのウィンドウの通知か区別できるよう、
# タイトルを [ディレクトリ名/ウィンドウ番号 ウィンドウ名] にする（tmux 外は [ディレクトリ名] だけ）
WIN_LABEL=""
if [ "$IN_TMUX" = 1 ]; then
  WIN_LABEL=$(tmux display-message -t "$TMUX_PANE" -p '/#{window_index} #{window_name}' 2>/dev/null)
fi
FULL_TITLE="[${DIR}${WIN_LABEL}] $TITLE"

PAYLOAD=$(printf '%s\t%s\t%s\t%s' "$DIR" "$FULL_TITLE" "$MESSAGE" "${TMUX_PANE#%}" | base64 | tr -d '\n')

# ---- 1. OSC の書き込み先 tty を決める ----
TTY=""
if [ "$IN_TMUX" = 1 ]; then
  # tmux 内: 自ペインの pty。
  TTY=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}' 2>/dev/null)
else
  # tmux 外（wezterm mux 等）: Claude Code の hook プロセスには制御端末が無く
  # /dev/tty を開けないことがあるため、その場合は $WEZTERM_PANE から
  # wezterm cli でペインの pty を引く。
  # サブシェルで開けるか試す（特殊ビルトインのリダイレクト失敗はシェルごと終了するため）
  if (exec >/dev/tty) 2>/dev/null; then
    TTY=/dev/tty
  elif [ -n "$WEZTERM_PANE" ] && command -v wezterm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    TTY=$(wezterm cli list --format json 2>/dev/null |
      jq -r --arg p "$WEZTERM_PANE" '.[] | select((.pane_id | tostring) == $p) | .tty_name // empty')
  fi
fi
[ -n "$TTY" ] && [ -w "$TTY" ] || TTY=""

# ---- 2. 手元の WezTerm がトーストを出せるか判定する ----
# 出せるなら OSC だけ、出せないなら ntfy に流す（二重通知しない）。
# - tmux 内: 自セッション（グループセッションなら同一グループ）にクライアントが
#   attach していれば、OSC はそのクライアントの WezTerm まで届く
# - tmux 外: 書き込める tty があれば、それがそのまま WezTerm のペイン
LOCAL_TOAST=0
if [ "$IN_TMUX" = 1 ]; then
  # -F はクライアントが attach しているセッションの属性を展開する。
  # session_group は非グループセッションでは空になるので session_name にフォールバック。
  SELF_GROUP=$(tmux display-message -t "$TMUX_PANE" -p '#{session_group}' 2>/dev/null)
  if [ -n "$SELF_GROUP" ]; then
    tmux list-clients -F '#{session_group}' 2>/dev/null | grep -qxF "$SELF_GROUP" && LOCAL_TOAST=1
  else
    SELF_SESSION=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}' 2>/dev/null)
    [ -n "$SELF_SESSION" ] &&
      tmux list-clients -F '#{session_name}' 2>/dev/null | grep -qxF "$SELF_SESSION" && LOCAL_TOAST=1
  fi
elif [ -n "$TTY" ]; then
  LOCAL_TOAST=1
fi

# ---- 3. ntfy プッシュ通知（Windows / iPhone / Apple Watch。issue #221）----
# ~/.config/ntfy-topic にトピック名があり、かつ手元の WezTerm でトーストが
# 出せないときだけ送る。席を外しているとき（tmux 未 attach）と、
# tmux/WezTerm を経由しないセッション（Claude Code アプリからの SSH 等）が対象。
# サーバは NTFY_SERVER で上書き可（既定 https://ntfy.sh）。
NTFY_TOPIC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ntfy-topic"
if [ "$LOCAL_TOAST" = 0 ] && [ -r "$NTFY_TOPIC_FILE" ] &&
  command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  NTFY_TOPIC=$(head -n1 "$NTFY_TOPIC_FILE" | tr -d '[:space:]')
  if [ -n "$NTFY_TOPIC" ]; then
    # どのセッションからの通知か分かるよう、tmux のウィンドウ/ペイン情報を本文に足す
    PANE_INFO=""
    if [ "$IN_TMUX" = 1 ]; then
      PANE_INFO=$(tmux display-message -t "$TMUX_PANE" -p ' (#{session_name}:#{window_index} #{window_name} #{pane_id})' 2>/dev/null)
    fi
    jq -cn --arg topic "$NTFY_TOPIC" --arg title "$FULL_TITLE" --arg msg "${MESSAGE}${PANE_INFO}" \
      '{topic: $topic, title: $title, message: $msg}' |
      curl -fsS --max-time 3 -H "Content-Type: application/json" \
        -d @- "${NTFY_SERVER:-https://ntfy.sh}" >/dev/null 2>&1
  fi
fi

# ---- 4. OSC 1337 SetUserVar を書き込む ----
# 手元の WezTerm の user-var-changed ハンドラ（.wezterm.lua）が
# タブの 🔔 マーク付けとトースト表示を行う。
if [ -n "$TTY" ]; then
  if [ "$IN_TMUX" = 1 ]; then
    # tmux 内は passthrough（ESC 二重化 + ESC Ptmux; ラップ）で書く。
    # allow-passthrough on（.tmux.conf）とセットで tmux を透過して WezTerm に届く。
    printf '\033Ptmux;\033\033]1337;SetUserVar=claude_notify=%s\007\033\\' "$PAYLOAD" > "$TTY" 2>/dev/null
  else
    printf '\033]1337;SetUserVar=claude_notify=%s\033\\' "$PAYLOAD" > "$TTY" 2>/dev/null
  fi
fi
exit 0
