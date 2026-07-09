# ===== Azure 開発サーバー (devbox) の起動・接続 CLI（Windows 用） =====
# 旧 WSL 版 ~/.local/bin/devbox の移植。az CLI は Windows 側に導入して使う。
#
# 使い方: pwsh -File devbox.ps1 [connect|ensure|up|down|status]
#   connect : VM 起動と NSG を担保してから ssh で接続する（既定）
#   ensure  : VM 起動と NSG の現在IP許可だけ行い、SSH はしない（WezTerm の gui-startup 用）
#   up      : VM を起動するだけ
#   down    : VM を停止(deallocate)して課金をディスク代だけにする
#   status  : VM の電源状態を表示
#
# 環境変数で上書き可:
#   DEVBOX_RG / DEVBOX_VM / DEVBOX_USER / DEVBOX_IP
#   DEVBOX_NSG_RG / DEVBOX_NSG / DEVBOX_NSG_RULE
param(
    [ValidateSet("connect", "ensure", "up", "down", "status")]
    [string]$Action = "connect"
)

$RG      = if ($env:DEVBOX_RG)       { $env:DEVBOX_RG }       else { "rg-devbox" }
$VM      = if ($env:DEVBOX_VM)       { $env:DEVBOX_VM }       else { "devbox" }
$User    = if ($env:DEVBOX_USER)     { $env:DEVBOX_USER }     else { "azureuser" }
$IP      = if ($env:DEVBOX_IP)       { $env:DEVBOX_IP }       else { "20.46.165.130" }  # Standard SKU の静的 IP
$NsgRg   = if ($env:DEVBOX_NSG_RG)   { $env:DEVBOX_NSG_RG }   else { $RG }
$Nsg     = if ($env:DEVBOX_NSG)      { $env:DEVBOX_NSG }      else { "devboxNSG" }
$NsgRule = if ($env:DEVBOX_NSG_RULE) { $env:DEVBOX_NSG_RULE } else { "allow-ssh-home" }

# 22番への TCP 到達性を確認する
function Test-Ssh {
    param([int]$TimeoutMs = 4000)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        return $client.ConnectAsync($IP, 22).Wait($TimeoutMs) -and $client.Connected
    }
    catch { return $false }
    finally { $client.Dispose() }
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

# 現在の公開IPを NSG ルールの許可送信元に追加する（既に許可済みなら何もしない）
function Add-CurrentIpToNsg {
    $cur = Get-PublicIp
    if (-not $cur) {
        Write-Warning "現在の公開IPを取得できませんでした。"
        return $false
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

# VM 起動 + NSG 許可を担保する。22番に届く状態になれば true。
# 高速パス: 既に届くなら az を一切呼ばない（WezTerm 起動を遅くしないため）。
function Confirm-Devbox {
    if (Test-Ssh) { return $true }

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

    if (Test-Ssh) { return $true }

    # 届かない場合は NSG に現在IPを反映してから、sshd の起動も含めて待つ
    Write-Host "$($IP):22 に到達できないため、現在の公開IPを NSG に反映します..."
    Add-CurrentIpToNsg | Out-Null
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 3
        if (Test-Ssh) { return $true }
    }

    Write-Warning "$($IP):22 に依然到達できません（NSG 反映待ち or 別要因）。現在の公開IP: $(Get-PublicIp)"
    return $false
}

switch ($Action) {
    "status" {
        if (-not (Test-Az)) { exit 1 }
        $state = Get-VmState
        Write-Host "devbox: $(if ($state) { $state } else { 'unknown' })  (ssh到達: $(if (Test-Ssh) { 'OK' } else { 'NG' }))"
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
        Write-Host "接続: ssh $User@$IP  (または devbox.ps1 connect)"
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
