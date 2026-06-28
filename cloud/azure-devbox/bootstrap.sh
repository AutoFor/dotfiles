#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# =============================================================
# Azure 開発サーバー (Ubuntu 24.04) に開発環境を流し込む。
#   必要パッケージ → ghq / Node(nvm) / Claude Code → dotfiles 適用 → zsh
# 冪等: 何度実行しても安全。
#
# 使い方 (ローカルから VM へ):
#   ssh azureuser@<IP> 'bash -s' < bootstrap.sh
# =============================================================

echo "########## 1) apt パッケージ ##########"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  zsh neovim git curl wget build-essential tmux \
  fzf zoxide golang-go unzip ca-certificates jq

echo "########## 2) GitHub CLI (gh) ##########"
if ! command -v gh >/dev/null 2>&1; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi
echo "gh: $(gh --version | head -1)"

echo "########## 3) ghq (go install) ##########"
export PATH="$HOME/go/bin:$PATH"
if ! command -v ghq >/dev/null 2>&1; then
  go install github.com/x-motemen/ghq@latest
fi
echo "ghq: $("$HOME/go/bin/ghq" --version 2>/dev/null || echo installed)"

echo "########## 4) nvm + Node LTS + Claude Code ##########"
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts >/dev/null
nvm use --lts >/dev/null
echo "node: $(node -v) / npm: $(npm -v)"
npm install -g @anthropic-ai/claude-code
echo "claude: $(claude --version 2>/dev/null || echo 'installed (要ログイン)')"

echo "########## 5) dotfiles clone & install ##########"
if [ ! -d "$HOME/dotfiles" ]; then
  git clone https://github.com/AutoFor/dotfiles.git "$HOME/dotfiles"
else
  git -C "$HOME/dotfiles" pull --ff-only || true
fi
# 非 WSL なので wsl.conf 等のシステム設定はスキップ
INSTALL_SYSTEM_CONFIG=0 bash "$HOME/dotfiles/install.sh"

echo "########## 6) デフォルトシェルを zsh に ##########"
ZSH_PATH="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]; then
  sudo chsh -s "$ZSH_PATH" "$USER"
  echo "default shell -> $ZSH_PATH"
else
  echo "default shell は既に zsh"
fi

echo "########## 完了 ##########"
echo "次にやること:  gh auth login   /   claude  (初回ログイン)"
