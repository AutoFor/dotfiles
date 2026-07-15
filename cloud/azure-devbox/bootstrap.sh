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

echo "########## 0) タイムゾーン (JST) ##########"
# 既定は UTC。cron のスケジュール (21:59 の tmux 駆け込み保存など) を
# 日本時間で書けるように Asia/Tokyo に合わせる。
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "Asia/Tokyo" ]; then
  sudo timedatectl set-timezone Asia/Tokyo
  sudo systemctl restart cron 2>/dev/null || true
fi

echo "########## 1) apt パッケージ ##########"
# neovim は apt 版が古すぎる(0.9.5)ため入れない。後段で stable tarball を入れる。
sudo apt-get update -qq
sudo apt-get install -y -qq \
  zsh git curl wget build-essential tmux \
  fzf zoxide golang-go unzip ca-certificates jq

echo "########## 1.5) Neovim (stable / tarball) ##########"
# 設定が nvim 0.11+ を要求するため、公式 stable を /opt に入れて ~/.local/bin にリンク。
if ! /opt/nvim/bin/nvim --version >/dev/null 2>&1; then
  tmp_nvim="$(mktemp -d)"
  url="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
  if ! curl -fsSL -o "$tmp_nvim/nvim.tar.gz" "$url"; then
    url="https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz"
    curl -fsSL -o "$tmp_nvim/nvim.tar.gz" "$url"
  fi
  extracted="$(tar -tzf "$tmp_nvim/nvim.tar.gz" | head -1 | cut -d/ -f1)"
  sudo rm -rf /opt/nvim "/opt/$extracted"
  sudo tar -C /opt -xzf "$tmp_nvim/nvim.tar.gz"
  sudo mv "/opt/$extracted" /opt/nvim
  rm -rf "$tmp_nvim"
fi
mkdir -p "$HOME/.local/bin"
ln -sf /opt/nvim/bin/nvim "$HOME/.local/bin/nvim"
echo "nvim: $(/opt/nvim/bin/nvim --version | head -1)"

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

echo "########## 4.5) Tailscale ##########"
# iPad / iPhone / 外出先クライアントから NSG の許可 IP に依存せず SSH するための VPN。
# 認証は対話が必要なため、ここではインストールと起動までを行い URL 表示のみ。
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
if tailscale status >/dev/null 2>&1; then
  echo "tailscale: ログイン済み ($(tailscale ip -4 2>/dev/null | head -1))"
else
  echo "tailscale: 未ログイン。後で以下を実行して表示される URL をブラウザで開いて認証する:"
  echo "  sudo tailscale up"
fi

echo "########## 5) dotfiles clone & install ##########"
if [ ! -d "$HOME/dotfiles" ]; then
  git clone https://github.com/AutoFor/dotfiles.git "$HOME/dotfiles"
else
  git -C "$HOME/dotfiles" pull --ff-only || true
fi
# 非 WSL なので wsl.conf 等のシステム設定はスキップ
INSTALL_SYSTEM_CONFIG=0 bash "$HOME/dotfiles/install.sh"

echo "########## 5.5) tmux プラグイン (TPM + resurrect/continuum) ##########"
# VM 再起動で tmux セッションが消えるため、構成を定期保存して起動時に自動復元する。
# 設定本体は dotfiles の linux/.tmux.conf 側 (セッション永続化セクション)。
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
if [ ! -d "$HOME/.tmux/plugins/tmux-resurrect" ]; then
  # install_plugins は tmux サーバーが設定を読んでいる必要がある。
  # 一時セッションを作って読み込ませる (既存セッションには触れない)。
  tmux new-session -d -s _bootstrap 2>/dev/null || true
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
  tmux kill-session -t _bootstrap 2>/dev/null || true
fi
# continuum の定期自動保存は status off 構成では発火しないため、cron で直接保存する。
# 21:59 は 22:00 の Azure 自動シャットダウン直前の駆け込み保存。
# idle-shutdown は 1 時間アイドル (端末 I/O なし & 低負荷) で自動 deallocate (dotfiles の
# linux/.local/bin/idle-shutdown。install.sh が ~/.local/bin にリンクする)。
( crontab -l 2>/dev/null | grep -v -e tmux-resurrect -e idle-shutdown; \
  echo '*/15 * * * * ~/.tmux/plugins/tmux-resurrect/scripts/save.sh quiet >/dev/null 2>&1'; \
  echo '59 21 * * * ~/.tmux/plugins/tmux-resurrect/scripts/save.sh quiet >/dev/null 2>&1'; \
  echo '*/10 * * * * $HOME/.local/bin/idle-shutdown >/dev/null 2>&1' ) | crontab -
echo "tmux plugins: $(ls "$HOME/.tmux/plugins" | tr '\n' ' ')"

echo "########## 6) デフォルトシェルを zsh に ##########"
ZSH_PATH="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]; then
  sudo chsh -s "$ZSH_PATH" "$USER"
  echo "default shell -> $ZSH_PATH"
else
  echo "default shell は既に zsh"
fi

echo "########## 完了 ##########"
echo "次にやること:  gh auth login   /   claude  (初回ログイン)   /   sudo tailscale up (VPN 認証)"
