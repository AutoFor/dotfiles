# ===== dotfiles インストーラ（Windows 用） =====
# WSL の ~/dotfiles/windows/ から Windows ホームにシンボリックリンクを作成する。
# 管理者権限または Developer Mode が必要。
# 冪等: 何度実行しても安全。

$ErrorActionPreference = "Stop"

$DotfilesWindows = Join-Path $PSScriptRoot "windows"
$WinHome = $env:USERPROFILE
$BackupSuffix = ".backup." + (Get-Date -Format "yyyyMMdd")

function Link-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    # 既にリンクが正しければスキップ
    $item = Get-Item $Destination -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        $target = $item.Target
        if ($target -eq $Source) {
            Write-Host "  [skip] $Destination -> 既にリンク済み"
            return
        }
    }

    # 既存ファイルがあればバックアップ
    if (Test-Path $Destination) {
        $backupPath = "$Destination$BackupSuffix"
        Write-Host "  [backup] $Destination -> $backupPath"
        Move-Item -Path $Destination -Destination $backupPath -Force
    }

    # シンボリックリンク作成
    New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    Write-Host "  [link] $Destination -> $Source"
}

Write-Host "=== Windows 設定ファイルのリンク ==="

Link-File -Source "$DotfilesWindows\.wezterm.lua" -Destination "$WinHome\.wezterm.lua"
Link-File -Source "$DotfilesWindows\.gitconfig"   -Destination "$WinHome\.gitconfig"
Link-File -Source "$DotfilesWindows\.wslconfig"   -Destination "$WinHome\.wslconfig"
Link-File -Source "$DotfilesWindows\.bashrc"      -Destination "$WinHome\.bashrc"

Write-Host ""
Write-Host "=== 完了 ==="
Write-Host "WezTerm を再起動して設定が反映されていることを確認してください。"
