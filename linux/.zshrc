# Set up the prompt

autoload -Uz promptinit
promptinit
prompt adam1

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# zoxide（スマートcd）を有効化
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# fzf でカレントディレクトリ配下のフォルダを選択して cd
cfd() {
  local dir
  dir=$(find . -maxdepth 1 -type d | sort | fzf --no-sort) || return
  cd "$dir"
}

# 現在のディレクトリを確認付きで削除
lrm() {
  setopt localoptions glob_dots no_rm_star_silent

  local target=$PWD
  local parent
  parent=$(dirname -- "$target")

  if [[ "$target" == "/" || "$parent" == "$target" ]]; then
    echo "Refusing to delete: $target"
    return 1
  fi

  cd "$parent" || return 1
  print -n "Delete directory: $target ? [y/N] "

  local ans
  read ans
  [[ "$ans" == [yY] ]] || { cd "$target" 2>/dev/null; return 1; }

  rm -rf -- "$target" || { echo "rm failed"; return 1; }
}
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$PATH:$HOME/.dotnet/tools"

# エスケープシーケンスを最前面の端末 (WezTerm) まで届ける。
# tmux 内では passthrough (ESC P tmux; ... ESC \) でラップしないと tmux に飲まれる
# (.tmux.conf の allow-passthrough on とセット)
__term_emit() {
  local seq="$1"
  if [[ -n "${TMUX:-}" ]]; then
    printf '\033Ptmux;%s\033\\' "${seq//$'\033'/$'\033\033'}"
  else
    printf '%s' "$seq"
  fi
}

__wezterm_set_user_var() {
  local name="$1"
  local value="$2"
  local encoded
  encoded=$(printf '%s' "$value" | base64 | tr -d '\n') || return
  __term_emit "$(printf '\033]1337;SetUserVar=%s=%s\007' "$name" "$encoded")"
}

# nvim: プレーン（素の nvim / nvim-tree のみ）
# nvimc: 右に claude -y ペインを開いてから nvim を起動する
#   tmux 内なら tmux split-window で直接開く（WezTerm 非依存: iPad 等の SSH クライアントでも動く）
#   tmux 外 (wezterm mux 等) は従来どおり user var で WezTerm 側に依頼する
nvimc() {
  if [[ -n "${TMUX:-}" ]]; then
    if [[ "$(tmux display-message -p '#{window_panes}')" == "1" ]]; then
      tmux split-window -h -l '30%' -d -c "$PWD" 'claude -y; exec zsh -l'
    fi
    command nvim "$@"
    return
  fi
  if [[ -n "${SSH_CONNECTION:-}" || -n "${WEZTERM_PANE:-}" || -n "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    local marker="${PWD}:$$:${RANDOM}"
    mkdir -p "$HOME/.cache"
    printf '[%s] nvim trigger: pwd=%q marker=%q args=%q\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "$PWD" "$marker" "$*" >> "$HOME/.cache/wezterm-nvim-pane.log"
    __wezterm_set_user_var "open_agent_pane_for_nvim" "$marker"
  fi
  command nvim "$@"
}

tmp() {
  local dir="/tmp-nvim"
  local file="${dir}/$(date '+%Y-%m-%d-%H-%M-%S').txt"

  if [[ ! -d "$dir" ]]; then
    sudo mkdir -p "$dir" || return 1
    sudo chown "$USER:$(id -gn)" "$dir" || return 1
    chmod 700 "$dir" || return 1
  fi

  mkdir -p "$dir" || return 1
  touch "$file" || return 1

  NVIM_TMP_NOTE_FILE="$file" command nvim --cmd "cd $dir" "$file"
}

# メモディレクトリ (~/memo。MEMO_DIR で変更可) にタイムスタンプ付きメモ
# (yyyymmddhhmmss.md) を作成して nvim で開く。追加のメモは nvim 内で <leader>N
memo() {
  local dir="${MEMO_DIR:-$HOME/memo}"
  local file="${dir}/$(date '+%Y%m%d%H%M%S').md"
  mkdir -p "$dir" || return 1
  touch "$file" || return 1
  command nvim --cmd "cd $dir" "$file"
}

# WezTerm にカレントディレクトリを通知（OSC 7）
# tmux 内でも __term_emit がラップして届ける。WezTerm 側はこれで host=devbox を
# 認識し、ステータス表示や tmux ブリッジ判定 (is_tmux_client_pane) が機能する
__wezterm_osc7() {
  __term_emit "$(printf '\033]7;file://%s%s\007' "$(hostname)" "$PWD")"
}
precmd_functions+=(__wezterm_osc7)

# 最後に訪れたディレクトリを保存（WezTerm の新規タブ/ウィンドウで使用）
__save_last_dir() { echo "$PWD" > ~/.last_dir }
chpwd_functions+=(__save_last_dir)
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# Windows パスを WSL パスに変換して出力 + クリップボードにコピー
# 使い方: wpath 'G:\パス\ファイル.txt'  ← シングルクォート必須
wsl_require_quoted_windows_path() {
  local input="$*"

  if [[ -z "$input" ]]; then
    print -r -- "Usage: ${funcstack[2]} 'C:\path\to\target'"
    return 1
  fi

  if [[ "$input" =~ '^[A-Za-z]:[^/\\]' ]]; then
    print -r -- "Error: Windows path must be quoted."
    print -r -- "Example: ${funcstack[2]} 'C:\Users\SeiyaKawashima\Downloads'"
    return 1
  fi
}

wsl_copy_to_clipboard() {
  local value="$1"
  local clip_cmd="/mnt/c/Windows/System32/clip.exe"

  if [[ ! -x "$clip_cmd" ]]; then
    print -r -- "Warning: clip.exe is not available; skipped clipboard copy."
    return 1
  fi

  printf '%s' "$value" | "$clip_cmd" 2>/dev/null
}

# SSH 経由で WSL に入ると WSL_INTEROP が引き継がれず Windows の .exe（clip.exe 等）が
# 呼べなくなる。/run/WSL 配下の生きている interop ソケットを探して復元する。
# 有効なソケットが無い場合（純 SSH 運用など）は復元できないこともある。
_wsl_interop_works() {
  WSL_INTEROP="$1" /mnt/c/Windows/System32/cmd.exe /c "exit" >/dev/null 2>&1
}

wsl_restore_interop() {
  [[ -n "$WSL_INTEROP" ]] && _wsl_interop_works "$WSL_INTEROP" && return 0
  local sock
  for sock in /run/WSL/*_interop(NOm); do  # zsh: N=該当なしOK, Om=新しい順(mtime降順)
    if _wsl_interop_works "$sock"; then
      export WSL_INTEROP="$sock"
      return 0
    fi
  done
  return 1
}

# native セッションでは WSL_INTEROP が既にあるので何もしない。
# SSH セッション（WSL_INTEROP が空）のときだけ復元を試みる。
[[ -z "$WSL_INTEROP" && -d /run/WSL ]] && wsl_restore_interop

wpath() {
  wsl_require_quoted_windows_path "$@" || return 1
  local wsl_path
  wsl_path=$(wslpath -u "$*") || return 1
  wsl_copy_to_clipboard "'$wsl_path'" >/dev/null || true
  echo "'$wsl_path'"
}

# Windows パスを WSL パスに変換して claude を起動（ファイルパスは親ディレクトリに cd）
# 使い方: wcd 'G:\パス\スペース含む パス'  ← シングルクォート必須
wcd() {
  wsl_require_quoted_windows_path "$@" || return 1
  local wsl_path
  wsl_path=$(wslpath -u "$*") || return 1
  [[ -f "$wsl_path" ]] && wsl_path=$(dirname "$wsl_path")
  wsl_copy_to_clipboard "'$wsl_path'" >/dev/null || true
  cd "$wsl_path" && claude
}

export DOTNET_ROOT=$HOME/.dotnet
export PATH=$PATH:$HOME/.dotnet

# ghq + fzf でリポジトリを選択して cd（Ctrl+G）
function ghq-fzf() {
  local repo
  repo=$(ghq list | fzf) || return
  cd "$(ghq root)/$repo"
  zle reset-prompt
}
zle -N ghq-fzf
bindkey '^G' ghq-fzf

# ~/.git-worktrees 以下のイシューベースの worktree を fzf で選択して cd（issue-XXX-* パターンのみ）Alt+W
function worktree-fzf() {
  local base="$HOME/.git-worktrees"

  local target
  target=$(
    find "$base" -mindepth 3 -maxdepth 3 -type d -name 'issue-*' \
    | sort \
    | fzf --height=40% --reverse --prompt='worktree> ' \
      --preview 'ls -la {} | head -20' \
      --preview-window=right:30%
  ) || return

  cd "$target"
  zle reset-prompt
}
zle -N worktree-fzf
bindkey '\ew' worktree-fzf

# gh finish: Issue作成〜PRマージまで一括実行
alias gf='bash ~/.claude/skills/gh-finish/gh-finish.sh'

# claude の自動アップデートを無効化。
# 22:00 の自動シャットダウンと裏の更新処理が競合し、実行ファイルが
# 0 バイトに壊れて全ペインの claude --continue 復元が失敗した事例あり (2026-07-15)。
# 更新は claude 起動時に新バージョンの案内が出たとき手動で行う:
#   npm install -g @anthropic-ai/claude-code
export DISABLE_AUTOUPDATER=1

# claude: メモリ上限 12GB で起動
# claude -y / claude da: --dangerously-skip-permissions の短縮
unalias claude 2>/dev/null || true
claude() {
  if [[ "$1" == "-y" || "$1" == "da" ]]; then
    shift
    if command -v systemd-run >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
      command systemd-run --user --scope -p MemoryMax=12G claude --dangerously-skip-permissions "$@"
    else
      command claude --dangerously-skip-permissions "$@"
    fi
  else
    if command -v systemd-run >/dev/null 2>&1 && systemctl --user is-system-running >/dev/null 2>&1; then
      command systemd-run --user --scope -p MemoryMax=12G claude "$@"
    else
      command claude "$@"
    fi
  fi
}

# codex -y: --dangerously-bypass-approvals-and-sandbox の短縮
unalias codex 2>/dev/null || true
codex() {
  if [[ "$1" == "-y" ]]; then
    shift
    command codex --dangerously-bypass-approvals-and-sandbox "$@"
  else
    command codex "$@"
  fi
}

# ccusage: Claude Code / Codex のトークン使用量・コストを集計
# ccusage daily / weekly / monthly / session / blocks --live など
alias ccusage='npx ccusage@latest'

# tssh: trzsz でラップした SSH（ターミナル内ファイル転送）
# リモート側で trz → ローカルのファイル選択ダイアログが開いてアップロード（要 zenity + WSLg）
# リモート側で tsz <file> → ローカルにダウンロード
alias tssh='trzsz -d ssh'

# tm: tmux セッションに attach（無ければ作成）。tm <名前> で別セッション。
# 既存セッションにはグループセッション（ウィンドウ共有・ビュー独立）で入る:
#   - 端末ごとにアクティブウィンドウを独立して切り替えられる
#   - status line を表示（iPad/iPhone 等、WezTerm のタブバーが無いクライアント向け。
#     WezTerm は直接 attach (new -As main) するので status off のまま）
#   - detach で自動削除（destroy-unattached on）
tm() {
  local base="${1:-main}"
  if [[ -n "${TMUX:-}" ]]; then
    # tmux 内から呼ばれたらセッション切り替え
    tmux switch-client -t "=$base" 2>/dev/null || {
      tmux new-session -d -s "$base" && tmux switch-client -t "=$base"
    }
    return
  fi
  if ! tmux has-session -t "=$base" 2>/dev/null; then
    tmux new-session -s "$base"
    return
  fi
  local view="${base}-view-$$"
  tmux new-session -t "=$base" -s "$view" \; \
    set-option destroy-unattached on \; \
    set-option status on
}

# SSH ログイン時に自動で tmux(main)へ入る — `tmux new -As main` を毎回打たなくてよくする。
# 発動条件: 対話シェル / tmux 外 / 素の SSH(tty あり)。
# 除外: WezTerm が管理するペイン(mux ドメイン・wezterm ssh。WEZTERM_PANE で判定)、
#       NOTMUX=1 での明示回避(例: ssh -t devbox NOTMUX=1 zsh -l)。
# tm 経由なので main が無ければ作成、既にあればグループセッション(ビュー独立)で入る。
# detach (prefix+d) すると通常のシェルに戻る。
if [[ -o interactive && -z "${TMUX:-}" && -z "${WEZTERM_PANE:-}" \
      && -n "${SSH_TTY:-}" && -z "${NOTMUX:-}" ]] \
    && command -v tmux >/dev/null 2>&1; then
  tm
fi

# gh worktree branch: Issue作成 + worktree作成
# gwb     → worktree作成してcd "path"をクリップボードにコピー
# gwb r   → 右分割、gwb d → 下分割
# gwb t   → 新規タブで開く
gwb() {
  local url
  url=$(gh issue create --title "WIP" --body "") || return 1
  local num
  num=$(echo "$url" | grep -oE '[0-9]+$')
  if [[ $# -eq 0 ]]; then
    local output
    output=$(bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh "issue-${num}" "none") || return 1
    echo "$output"
    local path line
    while IFS= read -r line; do
      [[ "$line" == ディレクトリ:* ]] && path="${line#ディレクトリ: }" && break
    done <<< "$output"
    if [[ -n "$path" ]]; then
      local cd_cmd="cd \"$path\""
      printf '%s' "$cd_cmd" | /mnt/c/Windows/System32/clip.exe
      echo "クリップボードにコピーしました: $cd_cmd"
    else
      echo "警告: ディレクトリパスの取得に失敗しました"
      echo "スクリプト出力: $output"
    fi
  else
    local output
    output=$(bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh "issue-${num}" "$1") || return 1
    echo "$output"
    local path line
    while IFS= read -r line; do
      [[ "$line" == ディレクトリ:* ]] && path="${line#ディレクトリ: }" && break
    done <<< "$output"
    if [[ -n "$path" ]]; then
      local cd_cmd="cd \"$path\""
      printf '%s' "$cd_cmd" | /mnt/c/Windows/System32/clip.exe
      echo "クリップボードにコピーしました: $cd_cmd"
    fi
  fi
}

# WSL_INTEROP をサブプロセスに引き継ぐ（WSL 環境のときだけ）
# Azure 等の非WSLには /run/WSL が無く、zsh のグロブが "no matches found" を出すため -d でガードする
if [[ -z "$WSL_INTEROP" && -d /run/WSL ]]; then
  # (N)=該当なしでもエラーにしない（nomatch 抑止）
  export WSL_INTEROP=$(ls -t /run/WSL/*_interop(N) 2>/dev/null | head -1)
fi

# pptx-meiryo: PowerPoint フォントを Meiryo UI に変換
pptx-meiryo() {
    /mnt/c/tools/pptx-meiryo/pptx-meiryo.exe "$@"
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/seiya-kawashima/google-cloud-sdk/path.zsh.inc' ]; then . '/home/seiya-kawashima/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/seiya-kawashima/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/seiya-kawashima/google-cloud-sdk/completion.zsh.inc'; fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
