#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# Azure に CLI 専用 Linux 開発サーバー (Ubuntu 24.04) を作成する
#   - Standard_B2s (2 vCPU / 4 GiB, バースト型・低コスト)
#   - Standard SSD 30GB / SSH 鍵認証
#   - SSH(22) は実行元のグローバル IP からのみ許可
#   - 毎日 22:00 に自動シャットダウン
#
# 前提: `az login` 済み。
# 使い方: bash create-vm.sh   (変数は環境変数で上書き可)
#   例) SIZE=Standard_B2ms LOCATION=japanwest bash create-vm.sh
#
# 作成後に開発環境を流し込む場合:
#   IP=$(az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv)
#   ssh azureuser@"$IP" 'bash -s' < bootstrap.sh
# =============================================================

# ---- 調整可能な変数 --------------------------------------------
RG="${RG:-rg-devbox}"
LOCATION="${LOCATION:-japaneast}"
VM="${VM:-devbox}"
SIZE="${SIZE:-Standard_B2s}"
ADMIN="${ADMIN:-azureuser}"
OS_DISK_GB="${OS_DISK_GB:-30}"
IMAGE="${IMAGE:-Ubuntu2404}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519.pub}"
# ----------------------------------------------------------------

# SSH 鍵が無ければ生成
if [ ! -f "$SSH_KEY" ]; then
  echo ">> SSH 鍵が無いので生成: ${SSH_KEY%.pub}"
  ssh-keygen -t ed25519 -f "${SSH_KEY%.pub}" -N ""
fi

# 実行元のグローバル IP を取得 (SSH をこの IP からだけ許可)
MY_IP="$(curl -s https://ifconfig.me)"
echo ">> SSH 許可元 IP: ${MY_IP}"

# 1) リソースグループ
az group create -n "$RG" -l "$LOCATION" -o none

# 2) VM 作成 (Standard SSD / SSH 鍵認証 / 受信ルールは後で手動)
az vm create \
  -g "$RG" -n "$VM" \
  --image "$IMAGE" \
  --size "$SIZE" \
  --admin-username "$ADMIN" \
  --ssh-key-values "$SSH_KEY" \
  --os-disk-size-gb "$OS_DISK_GB" \
  --storage-sku StandardSSD_LRS \
  --public-ip-sku Standard \
  --nsg-rule NONE \
  -o table

# 3) SSH(22) を実行元 IP からのみ許可
az network nsg rule create \
  -g "$RG" --nsg-name "${VM}NSG" \
  -n allow-ssh-home --priority 1000 \
  --access Allow --protocol Tcp --direction Inbound \
  --source-address-prefixes "${MY_IP}/32" \
  --destination-port-ranges 22 -o none

# 4) コスト対策: 毎日 22:00 (テナント既定 TZ) に自動シャットダウン
az vm auto-shutdown -g "$RG" -n "$VM" --time 2200 -o none

# 5) 接続情報
IP="$(az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv)"
echo "=============================================="
echo " 接続:  ssh ${ADMIN}@${IP}"
echo " 開発環境の流し込み:"
echo "   ssh ${ADMIN}@${IP} 'bash -s' < $(dirname "$0")/bootstrap.sh"
echo "=============================================="
