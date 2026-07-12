# ===== Azure 開発サーバー (devbox) の起動・接続 CLI（Windows 用） =====
# 旧 WSL 版 ~/.local/bin/devbox の移植。az CLI は Windows 側に導入して使う。
#
# 使い方: pwsh -File devbox.ps1 [connect|ensure|up|down|status|nsg|nsg-close]
#   connect  : VM 起動を担保してから ssh で接続する（既定。Tailscale 経由）
#   ensure   : VM 起動の担保だけ行い、SSH はしない（WezTerm の gui-startup 用）
#   up       : VM を起動するだけ
#   down     : VM を停止(deallocate)して課金をディスク代だけにする
#   status   : VM の電源状態を表示
#   nsg      : 公開IP直結の緊急フォールバック路を開く（NSG ルールを現在の公開IPで
#              作成/更新 → `ssh devbox-public`）。22番は通常閉鎖 (2026-07-10)
#   nsg-close: 緊急フォールバック路を閉じる（NSG ルールを削除。使用後は必ず閉じる）
#
# 環境変数で上書き可:
#   DEVBOX_RG / DEVBOX_VM / DEVBOX_USER / DEVBOX_IP / DEVBOX_PUBLIC_IP
#   DEVBOX_NSG_RG / DEVBOX_NSG / DEVBOX_NSG_RULE
param(
    [ValidateSet("connect", "ensure", "up", "down", "status", "nsg", "nsg-close")]
    [string]$Action = "connect"
)

$RG      = if ($env:DEVBOX_RG)       { $env:DEVBOX_RG }       else { "rg-devbox" }
$VM      = if ($env:DEVBOX_VM)       { $env:DEVBOX_VM }       else { "devbox" }
$User    = if ($env:DEVBOX_USER)     { $env:DEVBOX_USER }     else { "azureuser" }
$IP      = if ($env:DEVBOX_IP)       { $env:DEVBOX_IP }       else { "100.126.96.27" }  # Tailscale IP（ノード固有で不変）
$PublicIP = if ($env:DEVBOX_PUBLIC_IP) { $env:DEVBOX_PUBLIC_IP } else { "20.46.165.130" }  # Standard SKU の静的公開 IP（フォールバック用）
$NsgRg   = if ($env:DEVBOX_NSG_RG)   { $env:DEVBOX_NSG_RG }   else { $RG }
$Nsg     = if ($env:DEVBOX_NSG)      { $env:DEVBOX_NSG }      else { "devboxNSG" }
$NsgRule = if ($env:DEVBOX_NSG_RULE) { $env:DEVBOX_NSG_RULE } else { "allow-ssh-home" }

# 22番への TCP 到達性を確認する
function Test-Ssh {
    param([string]$Target = $IP, [int]$TimeoutMs = 4000)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        return $client.ConnectAsync($Target, 22).Wait($TimeoutMs) -and $client.Connected
    }
    catch { return $false }
    finally { $client.Dispose() }
}

# ローカルの Tailscale サービスが動いているか（接続経路の前提）
function Test-Tailscale {
    $svc = Get-Service Tailscale -ErrorAction SilentlyContinue
    return ($svc -and $svc.Status -eq "Running")
}

# az CLI が使える状態か（未導入・未ログインなら警告して false）
function Test-Az {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Warning "az CLI が見つかりません。'winget install Microsoft.AzureCLI' で導入してください。"
        return $false
    }
    az account show --only-show-errors -o none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "az 未ログインです。'az login' を実行してください。"
        return $false
    }
    return $true
}

function Get-VmState {
    az vm get-instance-view -g $RG -n $VM `
        --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv 2>$null
}

function Get-PublicIp {
    foreach ($url in "https://api.ipify.org", "https://ifconfig.me/ip") {
        try { return (Invoke-RestMethod -Uri $url -TimeoutSec 5).ToString().Trim() } catch {}
    }
    return $null
}

# 公開IP直結のフォールバック路を開く。NSG ルールが無ければ現在の公開IPで作成し、
# あれば許可送信元に現在の公開IPを追加する（既に許可済みなら何もしない）。
# 22番は通常閉鎖 (2026-07-10 以降) なので、初回はほぼ「作成」になる。
function Add-CurrentIpToNsg {
    $cur = Get-PublicIp
    if (-not $cur) {
        Write-Warning "現在の公開IPを取得できませんでした。"
        return $false
    }
    az network nsg rule show -g $NsgRg --nsg-name $Nsg -n $NsgRule -o none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "NSG($NsgRule) を公開IP $cur で作成します..."
        az network nsg rule create -g $NsgRg --nsg-name $Nsg -n $NsgRule `
            --priority 1000 --access Allow --direction Inbound --protocol Tcp `
            --destination-port-ranges 22 --source-address-prefixes "$cur/32" -o none
        return ($LASTEXITCODE -eq 0)
    }
    $existing = az network nsg rule show -g $NsgRg --nsg-name $Nsg -n $NsgRule `
        --query "sourceAddressPrefixes" -o tsv 2>$null
    if (-not $existing) {
        $existing = az network nsg rule show -g $NsgRg --nsg-name $Nsg -n $NsgRule `
            --query "sourceAddressPrefix" -o tsv 2>$null
    }
    $prefixes = @($existing -split "\s+" | Where-Object { $_ })
    if ($prefixes -contains "$cur/32") { return $true }
    Write-Host "公開IP $cur を NSG($NsgRule) に追加します..."
    az network nsg rule update -g $NsgRg --nsg-name $Nsg -n $NsgRule `
        --source-address-prefixes @($prefixes + "$cur/32") -o none
    return ($LASTEXITCODE -eq 0)
}

# VM 起動を担保する。22番（Tailscale 経由）に届く状態になれば true。
# 高速パス: 既に届くなら az を一切呼ばない（WezTerm 起動を遅くしないため）。
function Confirm-Devbox {
    if (Test-Ssh) { return $true }

    if (-not (Test-Tailscale)) {
        Write-Warning "ローカルの Tailscale サービスが動いていません。Tailscale を起動・ログインしてください。"
        Write-Warning "（緊急時は 'devbox.ps1 nsg' で現在IPを許可してから 'ssh devbox-public' で公開IP直結も可）"
    }

    if (-not (Test-Az)) { return $false }

    $state = Get-VmState
    if ($state -ne "PowerState/running") {
        Write-Host "devbox を起動中... (現在: $(if ($state) { $state } else { 'unknown' }))"
        az vm start -g $RG -n $VM -o none
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "devbox の起動に失敗しました。"
            return $false
        }
    }

    # sshd と tailscaled の起動を待つ
    for ($i = 0; $i -lt 15; $i++) {
        if (Test-Ssh) { return $true }
        Start-Sleep -Seconds 3
    }

    Write-Warning "$($IP):22 に依然到達できません（Tailscale 未接続 or 別要因）。"
    Write-Warning "フォールバック: 'devbox.ps1 nsg' で現在IPを許可してから 'ssh devbox-public'"
    return $false
}

switch ($Action) {
    "status" {
        if (-not (Test-Az)) { exit 1 }
        $state = Get-VmState
        Write-Host "devbox: $(if ($state) { $state } else { 'unknown' })  (ssh到達: tailscale=$(if (Test-Ssh) { 'OK' } else { 'NG' }) 公開IP=$(if (Test-Ssh -Target $PublicIP) { 'OK' } else { 'NG' }))"
    }
    "nsg" {
        if (-not (Test-Az)) { exit 1 }
        if (Add-CurrentIpToNsg) {
            Write-Host "NSG 許可済み。フォールバック接続: ssh devbox-public  (= $User@$PublicIP)"
            Write-Host "復旧後は 'devbox.ps1 nsg-close' で必ず閉じること。"
        }
        else { exit 1 }
    }
    "nsg-close" {
        if (-not (Test-Az)) { exit 1 }
        az network nsg rule delete -g $NsgRg --nsg-name $Nsg -n $NsgRule -o none
        if ($LASTEXITCODE -eq 0) { Write-Host "NSG($NsgRule) を削除しました。22番は閉鎖状態です。" }
        else { exit 1 }
    }
    "up" {
        if (-not (Test-Az)) { exit 1 }
        if ((Get-VmState) -eq "PowerState/running") {
            Write-Host "devbox は既に起動中です"
        }
        else {
            Write-Host "devbox を起動中..."
            az vm start -g $RG -n $VM -o none && Write-Host "起動完了"
        }
        Write-Host "接続: ssh devbox  (= $User@$IP Tailscale 経由。または devbox.ps1 connect)"
    }
    "down" {
        if (-not (Test-Az)) { exit 1 }
        if ((Get-VmState) -eq "PowerState/deallocated") {
            Write-Host "devbox は既に停止しています"
        }
        else {
            Write-Host "devbox を停止(deallocate)中..."
            az vm deallocate -g $RG -n $VM -o none && Write-Host "停止完了（課金はディスク代のみ）"
        }
    }
    "ensure" {
        if (-not (Confirm-Devbox)) { exit 1 }
    }
    "connect" {
        if (-not (Confirm-Devbox)) { exit 1 }
        Write-Host "ssh $User@$IP"
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$User@$IP"
        exit $LASTEXITCODE
    }
}
