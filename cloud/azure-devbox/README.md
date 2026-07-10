# Azure CLI 開発サーバー (devbox)

Azure 上に CLI 専用の Linux 開発サーバー (Ubuntu 24.04) を立て、
この dotfiles をベースに Claude Code / wezterm-mux-server / Neovim などをセットアップするための一式。

Windows 側からの日常の起動・接続は `windows/bin/devbox.ps1` を使う
(WezTerm の起動時にも `devbox.ps1 ensure` が自動で呼ばれる)。

## 構成

| 項目 | 値 |
|---|---|
| VM サイズ | `Standard_B2s` (2 vCPU / 4 GiB, バースト型) |
| リージョン | Japan East |
| OS | Ubuntu 24.04 LTS |
| ディスク | Standard SSD 30GB |
| 認証 | SSH 鍵 |
| ネットワーク | SSH(22) を作成元のグローバル IP からのみ許可 |
| コスト対策 | 毎日 22:00 自動シャットダウン |

## 使い方

### 0. 事前準備
```bash
# Azure CLI 未導入なら
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --use-device-code
```

### 1. VM を作成
```bash
bash create-vm.sh
# サイズ等を変えたい場合は環境変数で上書き
#   SIZE=Standard_B2ms LOCATION=japanwest bash create-vm.sh
```

### 2. 開発環境を流し込む
```bash
IP=$(az vm show -d -g rg-devbox -n devbox --query publicIps -o tsv)
ssh azureuser@"$IP" 'bash -s' < bootstrap.sh
```

### 3. 各サービスにログイン (VM 内で)
```bash
ssh azureuser@"$IP"
gh auth login
claude            # 初回起動で認証
```

## 運用コマンド

Windows からは `devbox.ps1 up / down / status` が同じことをする。

```bash
# 使わない時は停止 → 課金はディスク代だけ (最大の節約)
az vm deallocate -g rg-devbox -n devbox
az vm start      -g rg-devbox -n devbox

# CPU/メモリ増強 (要停止): 8GB=B2ms, 16GB=Standard_D4s_v5 など
az vm deallocate -g rg-devbox -n devbox
az vm resize     -g rg-devbox -n devbox --size Standard_B2ms
az vm start      -g rg-devbox -n devbox

# ディスク拡張 (要停止): 例 30→64GB
az vm deallocate -g rg-devbox -n devbox
DISK=$(az vm show -g rg-devbox -n devbox --query "storageProfile.osDisk.name" -o tsv)
az disk update -g rg-devbox -n "$DISK" --size-gb 64
az vm start -g rg-devbox -n devbox
# VM 内で反映: sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1

# 公開IP直結フォールバック時のみ: NSG の許可元に現在 IP を追加
# （通常の接続は Tailscale 経由なので不要。Windows からは `devbox.ps1 nsg` で同等）
MY_IP=$(curl -s https://ifconfig.me)
az network nsg rule update -g rg-devbox --nsg-name devboxNSG \
  -n allow-ssh-home --source-address-prefixes "${MY_IP}/32"

# まるごと削除 (後片付け)
az group delete -n rg-devbox --yes
```

## Tailscale (VPN)

**全クライアント（Windows / iPad / iPhone）の SSH は Tailscale 経由が正** (#214 Phase 4)。
NSG の許可 IP リスト (`allow-ssh-home`) は Tailscale 障害時のフォールバック用に残しているだけで、
通常運用では触らない。
bootstrap.sh がインストールまで行うので、初回のみ VM 内で認証する:

```bash
sudo tailscale up   # 表示される URL をブラウザで開いて認証
```

| 項目 | 値 |
|---|---|
| Tailscale IP | `100.126.96.27` (`tailscale ip -4` で確認。ノード固有で不変) |
| MagicDNS 名 | `devbox.tail7bb5be.ts.net` (`tailscale status --json` の `Self.DNSName`) |

- クライアント側 (Windows は `winget install Tailscale.Tailscale`、iPad は App Store) にも Tailscale を入れて同じアカウントでログインすれば、`ssh devbox` (Windows) や `ssh azureuser@100.126.96.27` で NSG を経由せず接続できる（SSH 鍵は従来どおり必要）。
- Tailscale 障害時のフォールバック: `devbox.ps1 nsg` で現在 IP を NSG に許可してから `ssh devbox-public`（公開 IP 直結）。
- tailnet 内の通信は WireGuard トンネル (アウトバウンド UDP) なので **NSG の受信規則は不要**。将来的に 22 番のグローバル公開 (`allow-ssh-home`) を閉じることも可能。
- 直接接続が張れない場合は DERP リレー経由になる（動作はするがレイテンシ増）。改善したい場合は NSG で UDP 41641 の受信を許可する。
- ノードキーは既定 180 日で失効する。管理コンソールで devbox の「Disable key expiry」を設定すると再認証が不要になる。

## メモ

- 公開 IP は Standard SKU のため **静的**。停止→再開しても変わらない。
- **swap 4GB + earlyoom 導入済み**（bootstrap.sh 4.8）。RAM 4GB スワップ無しだと暴走プロセス 1 つで
  システムごと窒息する（2026-07-10 の障害: OOM killer が動く前に sshd/tailscaled が応答不能）。
  earlyoom は sshd / tmux / tailscaled を除外して最大プロセスだけを kill する。
- `.zshrc` 内の WSL 専用関数 (`wpath` / `wcd` / clip.exe 連携等) は存在チェックで
  ガードされており、純 Linux VM では no-op になる。
