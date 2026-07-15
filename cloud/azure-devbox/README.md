# Azure CLI 開発サーバー (devbox)

Azure 上に CLI 専用の Linux 開発サーバー (Ubuntu 24.04) を立て、
この dotfiles をベースに Claude Code / tmux / Neovim などをセットアップするための一式。

## 構成

| 項目 | 値 |
|---|---|
| VM サイズ | `Standard_B4ms` (4 vCPU / 16 GiB, バースト型) ※初期構築時は `Standard_B2s` (2 vCPU / 4 GiB) |
| リージョン | Japan East |
| OS | Ubuntu 24.04 LTS |
| ディスク | Standard SSD 30GB |
| 認証 | SSH 鍵 |
| ネットワーク | SSH(22) を作成元のグローバル IP からのみ許可 |
| コスト対策 | 毎日 22:00 自動シャットダウン (JST) + 1時間アイドルで自動 deallocate (idle-shutdown) |

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

```bash
# 使わない時は停止 → 課金はディスク代だけ (最大の節約)
az vm deallocate -g rg-devbox -n devbox
az vm start      -g rg-devbox -n devbox

# CPU/メモリ増強: 8GB=B2ms, 16GB=B4ms など
# 同一クラスタ内のサイズ (az vm list-vm-resize-options で確認) なら停止不要・再起動のみ
# ※ Bsv2 系 (B2s_v2 等) はこのサブスクリプションのクォータが 0 のため使用不可
az vm resize -g rg-devbox -n devbox --size Standard_B4ms
# ※ 実行すると VM が再起動し SSH/tmux が全て切断される (2026-07-14 に B2s → B4ms へ変更済み)

# ディスク拡張 (要停止): 例 30→64GB
az vm deallocate -g rg-devbox -n devbox
DISK=$(az vm show -g rg-devbox -n devbox --query "storageProfile.osDisk.name" -o tsv)
az disk update -g rg-devbox -n "$DISK" --size-gb 64
az vm start -g rg-devbox -n devbox
# VM 内で反映: sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1

# 自宅 IP が変わって SSH できなくなったら許可元を更新
MY_IP=$(curl -s https://ifconfig.me)
az network nsg rule update -g rg-devbox --nsg-name devboxNSG \
  -n allow-ssh-home --source-address-prefixes "${MY_IP}/32"

# まるごと削除 (後片付け)
az group delete -n rg-devbox --yes
```

## Tailscale (VPN)

iPad / iPhone / 外出先クライアントから NSG の許可 IP に依存せず SSH するための VPN。
bootstrap.sh がインストールまで行うので、初回のみ VM 内で認証する:

```bash
sudo tailscale up   # 表示される URL をブラウザで開いて認証
```

| 項目 | 値 |
|---|---|
| Tailscale IP | `tailscale ip -4` で確認 (100.x.x.x、ノード固有で不変) |
| MagicDNS 名 | `devbox.<tailnet>.ts.net` (`tailscale status --json` の `Self.DNSName`) |

- クライアント側 (iPad の Blink/Termius、Windows 等) にも Tailscale を入れて同じアカウントでログインすれば、`ssh azureuser@devbox.<tailnet>.ts.net` で NSG を経由せず接続できる（SSH 鍵は従来どおり必要）。
- tailnet 内の通信は WireGuard トンネル (アウトバウンド UDP) なので **NSG の受信規則は不要**。将来的に 22 番のグローバル公開 (`allow-ssh-home`) を閉じることも可能。
- 直接接続が張れない場合は DERP リレー経由になる（動作はするがレイテンシ増）。改善したい場合は NSG で UDP 41641 の受信を許可する。

## メモ

- 公開 IP は Standard SKU のため **静的**。停止→再開しても変わらない。
- `.zshrc` 内の WSL 専用関数 (`wpath` / `wcd` / clip.exe 連携等) は存在チェックで
  ガードされており、純 Linux VM では no-op になる。
