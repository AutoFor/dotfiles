# ===== Windows に OpenSSH Server を立て、devbox から SSH で戻れるようにする (#253) =====
# 管理者 PowerShell で実行する:
#   pwsh -ExecutionPolicy Bypass -File C:\Users\saint\ghq\github.com\AutoFor\dotfiles\windows\bin\setup-sshd.ps1
# 何度実行しても同じ結果になる (冪等)。
#
# やること:
#   1) OpenSSH Server を入れる。Windows の機能追加 (Add-WindowsCapability / DISM) が
#      「クラスが登録されていません」や途中停止で使えなかったため、winget の
#      Win32-OpenSSH (Microsoft.OpenSSH.Preview) を使う
#   2) sshd を自動起動にして起動する
#   3) ファイアウォールで 22/tcp を開ける (Tailscale 経由でも Windows FW は効く)
#   4) devbox の公開鍵を登録する。管理者ユーザーは ~/.ssh/authorized_keys ではなく
#      C:\ProgramData\ssh\administrators_authorized_keys を見る決まりで、ACL も
#      Administrators と SYSTEM だけにしないと sshd が読んでくれない
#   5) ログインシェルを pwsh にする。ストア版 pwsh は sshd から起動できない
#      (実行エイリアス WindowsApps\pwsh.exe も、版数入りの実体パスも "exec request
#      failed" になる) ため、MSI 版 (C:\Program Files\PowerShell\7\pwsh.exe) を
#      winget で入れてそれを指す。ストア版とは共存する
$ErrorActionPreference = "Stop"

$devboxKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOUiZ6RmlUXUT3GTJ5HLfqpchV4P7/oDVEHFQjIvIr69 devbox->rpa"
$ak = "C:\ProgramData\ssh\administrators_authorized_keys"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "管理者 PowerShell で実行してください"
}

# --- 1) OpenSSH Server ---
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
    Write-Host "OpenSSH Server (Win32-OpenSSH) を winget で入れています..."
    winget install --id Microsoft.OpenSSH.Preview --accept-source-agreements --accept-package-agreements
    if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
        Write-Error "sshd サービスが見つかりません。winget のインストールに失敗しています。https://github.com/PowerShell/Win32-OpenSSH/releases/latest の OpenSSH-Win64-*.msi を手で入れてから再実行してください"
    }
} else {
    Write-Host "sshd は導入済み"
}

# --- 2) 自動起動 + 起動 ---
Set-Service sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne "Running") { Start-Service sshd }

# --- 3) ファイアウォール ---
if (-not (Get-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Host "ファイアウォールに 22/tcp の受信許可を追加"
}

# --- 4) devbox の公開鍵 ---
if (-not (Test-Path $ak) -or -not (Select-String -Path $ak -SimpleMatch $devboxKey -Quiet)) {
    Add-Content -Path $ak -Value $devboxKey
    Write-Host "devbox の公開鍵を登録"
}
icacls $ak /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null

# --- 5) ログインシェル (MSI 版 pwsh) ---
$shell = Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
if (-not (Test-Path $shell)) {
    Write-Host "MSI 版 PowerShell 7 を winget で入れています (sshd のログインシェル用。ストア版とは別物)..."
    winget install --id Microsoft.PowerShell --scope machine --accept-source-agreements --accept-package-agreements
    if (-not (Test-Path $shell)) {
        Write-Error "MSI 版 pwsh が見つかりません: $shell"
    }
}
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $shell -PropertyType String -Force | Out-Null
Restart-Service sshd

# --- 確認 ---
Write-Host ""
Write-Host "=== 確認 ==="
Get-Service sshd | Select-Object Status, StartType | Format-Table -AutoSize
Get-ItemProperty "HKLM:\SOFTWARE\OpenSSH" | Select-Object DefaultShell | Format-Table -AutoSize
Write-Host "--- $ak ---"
Get-Content $ak
Write-Host ""
Write-Host "次: devbox から  ssh saint@100.119.138.119 'echo ok'  で接続確認"
