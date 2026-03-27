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
eval "$(zoxide init zsh)"

# fzf でカレントディレクトリ配下のフォルダを選択して cd
cfd() {
  local dir
  dir=$(find . -maxdepth 1 -type d | sort | fzf --no-sort) || return
  cd "$dir"
}
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# WezTerm にカレントディレクトリを通知（OSC 7）
__wezterm_osc7() {
  printf '\e]7;file://%s%s\e\\' "$(hostname)" "$PWD"
}
precmd_functions+=(__wezterm_osc7)

# 最後に訪れたディレクトリを保存（WezTerm の新規タブ/ウィンドウで使用）
__save_last_dir() { echo "$PWD" > ~/.last_dir }
chpwd_functions+=(__save_last_dir)
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000

# Windows パスを WSL パスに変換して claude を起動
wcd() {
  local wsl_path
  wsl_path=$(wslpath -u "$1") || return 1
  cd "$wsl_path" && claude
}
export DOTNET_ROOT=$HOME/.dotnet
export PATH=$PATH:$HOME/.dotnet

# ghq + fzf でリポジトリを選択して cd（Ctrl+G）
function ghq-fzf() {
  local repo
  repo=$(ghq list | fzf --preview "ls $(ghq root)/{}") || return
  cd "$(ghq root)/$repo"
  zle reset-prompt
}
zle -N ghq-fzf
bindkey '^G' ghq-fzf

# ~/.git-worktrees 以下の worktree を fzf で選択して cd（4〜5階層のみ、.bare 除外）Alt+W
function worktree-fzf() {
  local base="$HOME/.git-worktrees"

  local target
  target=$(
    zoxide query -l \
    | rg "^$base(/[^/]+){4,5}$" \
    | rg -v '/\.bare$' \
    | fzf --height=40% --reverse --prompt='worktree> '
  ) || return

  cd "$target"
  zle reset-prompt
}
zle -N worktree-fzf
bindkey '\ew' worktree-fzf

# gh finish: Issue作成〜PRマージまで一括実行
alias gf='bash ~/.claude/skills/gh-finish/gh-finish.sh'

# claude da: --dangerously-skip-permissions の短縮
claude() {
  if [[ "$1" == "da" ]]; then
    shift
    command claude --dangerously-skip-permissions "$@"
  else
    command claude "$@"
  fi
}

# gh worktree branch: Issue作成 + worktree作成
# gwb   → worktree作成してcd "path"をクリップボードにコピー
# gwb r → 右分割、gwb d → 下分割
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
    bash ~/.claude/skills/gh-worktree-branch/create-worktree.sh "issue-${num}" "$1"
  fi
}

# WSL_INTEROP をサブプロセスに引き継ぐ
if [ -z "$WSL_INTEROP" ]; then
  export WSL_INTEROP=$(ls -t /run/WSL/*_interop 2>/dev/null | head -1)
fi

# pptx-meiryo: PowerPoint フォントを Meiryo UI に変換
pptx-meiryo() {
    /mnt/c/tools/pptx-meiryo/pptx-meiryo.exe "$@"
}

# claude: メモリ上限 12GB で起動
alias claude='systemd-run --user --scope -p MemoryMax=12G claude'

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/seiya-kawashima/.git-worktrees/github.com/AutoFor/iizuka-coupon-map/issue-15/! exec -l /usr/bin/zsh/google-cloud-sdk/path.zsh.inc' ]; then . '/home/seiya-kawashima/.git-worktrees/github.com/AutoFor/iizuka-coupon-map/issue-15/! exec -l /usr/bin/zsh/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/seiya-kawashima/.git-worktrees/github.com/AutoFor/iizuka-coupon-map/issue-15/! exec -l /usr/bin/zsh/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/seiya-kawashima/.git-worktrees/github.com/AutoFor/iizuka-coupon-map/issue-15/! exec -l /usr/bin/zsh/google-cloud-sdk/completion.zsh.inc'; fi
