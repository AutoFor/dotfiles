# ===== rpa (UiPath 用 Windows Server, Azure VM) の起動・接続 CLI（Windows 用） =====
# devbox.ps1 の rpa 版。tmux は使わない（RDP または ssh でそのまま入る）。
#
# 使い方: pwsh -File rpa.ps1 [connect|ensure|up|down|status]
#   connect : VM 起動を担保してから ssh で接続する（既定。Tailscale 経由）
#   ensure  : VM 起動の担保だけ行い、SSH はしない
#   up      : VM を起動するだけ
#   down    : VM を停止(deallocate)して課金をディスク代だけにする
#   status  : VM の電源状態を表示
#
# コスト対策: 毎日 22:00 自動シャットダウン + 1時間アイドルで自動 deallocate
#（rpa 上のタスク「rpa-idle-shutdown」。マネージド ID で自己 deallocate するため
#  devbox の idle-shutdown と異なり az ログイン切れが起きない）
#
# 環境変数で上書き可: RPA_RG / RPA_VM / RPA_USER / RPA_IP
param(
    [ValidateSet("connect", "ensure", "up", "down", "status")]
    [string]$Action = "connect"
)

$RG   = if ($env:RPA_RG)   { $env:RPA_RG }   else { "AUTOFOR-RG" }
$VM   = if ($env:RPA_VM)   { $env:RPA_VM }   else { "rpa" }
$User = if ($env:RPA_USER) { $env:RPA_USER } else { "azureuser" }
$IP   = if ($env:RPA_IP)   { $env:RPA_IP }   else { "100.118.192.14" }  # Tailscale IP（ノード固有で不変）

function Test-Ssh {
    param([string]$Target = $IP, [int]$TimeoutMs = 4000)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        return $client.ConnectAsync($Target, 22).Wait($TimeoutMs) -and $client.Connected
    }
    catch { return $false }
    finally { $client.Dispose() }
}

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

# VM 起動を担保する。22番（Tailscale 経由）に届く状態になれば true。
function Confirm-Rpa {
    if (Test-Ssh) { return $true }
    if (-not (Test-Az)) { return $false }

    $state = Get-VmState
    if ($state -ne "PowerState/running") {
        Write-Host "rpa を起動中... (現在: $(if ($state) { $state } else { 'unknown' }))"
        az vm start -g $RG -n $VM -o none
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "rpa の起動に失敗しました。"
            return $false
        }
    }

    for ($i = 0; $i -lt 20; $i++) {
        if (Test-Ssh) { return $true }
        Start-Sleep -Seconds 3
    }

    Write-Warning "$($IP):22 に依然到達できません（Tailscale 未接続 or 別要因）。"
    return $false
}

switch ($Action) {
    "status" {
        if (-not (Test-Az)) { exit 1 }
        $state = Get-VmState
        Write-Host "rpa: $(if ($state) { $state } else { 'unknown' })  (ssh到達: $(if (Test-Ssh) { 'OK' } else { 'NG' }))"
    }
    "up" {
        if (-not (Test-Az)) { exit 1 }
        if ((Get-VmState) -eq "PowerState/running") {
            Write-Host "rpa は既に起動中です"
        }
        else {
            Write-Host "rpa を起動中..."
            az vm start -g $RG -n $VM -o none && Write-Host "起動完了"
        }
        Write-Host "接続: ssh rpa  (= $User@$IP Tailscale 経由。または rpa.ps1 connect)"
    }
    "down" {
        if (-not (Test-Az)) { exit 1 }
        if ((Get-VmState) -eq "PowerState/deallocated") {
            Write-Host "rpa は既に停止しています"
        }
        else {
            Write-Host "rpa を停止(deallocate)中..."
            az vm deallocate -g $RG -n $VM -o none && Write-Host "停止完了（課金はディスク代のみ）"
        }
    }
    "ensure" {
        if (-not (Confirm-Rpa)) { exit 1 }
    }
    "connect" {
        if (-not (Confirm-Rpa)) {
            # ここで即 exit するとランチャーから開いたタブが理由を出さずに閉じてしまう
            Write-Host ""
            Write-Warning "rpa に接続できませんでした。上のメッセージを確認してください。"
            Write-Host "よくある原因: rpa 側の Tailscale がログアウト状態 (VM 上で 'tailscale up --unattended')"
            Read-Host "Enter キーで閉じます"
            exit 1
        }
        Write-Host "ssh $User@$IP"
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$User@$IP"
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ""
            Write-Warning "ssh が異常終了しました (exit $code)。"
            Read-Host "Enter キーで閉じます"
        }
        exit $code
    }
}
