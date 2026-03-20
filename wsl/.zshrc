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

# ~/.git-worktrees 以下の worktree を fzf で選択して cd（4〜5階層のみ、.bare 除外）
gw() {
  local base="$HOME/.git-worktrees"

  local target
  target=$(
    zoxide query -l \
    | rg "^$base(/[^/]+){4,5}$" \
    | rg -v '/\.bare$' \
    | fzf --height=40% --reverse --prompt='worktree> '
  ) || return

  cd "$target"
}

# WSL_INTEROP をサブプロセスに引き継ぐ
if [ -z "$WSL_INTEROP" ]; then
  export WSL_INTEROP=$(ls -t /run/WSL/*_interop 2>/dev/null | head -1)
fi
