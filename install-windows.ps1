# ===== dotfiles インストーラ（Windows 用） =====
# リポジトリの windows/ から Windows ホームにシンボリックリンクを作成する。
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

function Link-Directory {
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

    # 既存ディレクトリがあればバックアップ
    if (Test-Path $Destination) {
        $backupPath = "$Destination$BackupSuffix"
        Write-Host "  [backup] $Destination -> $backupPath"
        Move-Item -Path $Destination -Destination $backupPath -Force
    }

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    Write-Host "  [link] $Destination -> $Source"
}

Write-Host "=== Windows 設定ファイルのリンク ==="

Link-File -Source "$DotfilesWindows\.wezterm.lua" -Destination "$WinHome\.wezterm.lua"
Link-File -Source "$DotfilesWindows\.gitconfig"   -Destination "$WinHome\.gitconfig"
Link-File -Source "$DotfilesWindows\.bashrc"      -Destination "$WinHome\.bashrc"

# SSH 設定 (#214 Phase 3: `ssh devbox` を全クライアント共通の入口にする)
$SshDir = Join-Path $WinHome ".ssh"
if (-not (Test-Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir | Out-Null
}
Link-File -Source "$DotfilesWindows\.ssh\config" -Destination "$SshDir\config"

Write-Host ""
Write-Host "=== devbox CLI のリンク ==="

# Azure devbox の起動/接続スクリプト。WezTerm は dotfiles 内の実体を直接参照するため
# このリンクは任意（シェルから直接叩きたい人向け）。
$LocalBin = Join-Path $WinHome ".local\bin"
if (-not (Test-Path $LocalBin)) {
    New-Item -ItemType Directory -Path $LocalBin -Force | Out-Null
}
Link-File -Source "$DotfilesWindows\bin\devbox.ps1" -Destination "$LocalBin\devbox.ps1"

Write-Host ""
Write-Host "=== Yamabuki R layout links ==="

$YamabukiRDir = ${env:YAMABUKIR_DIR}
if ([string]::IsNullOrWhiteSpace($YamabukiRDir)) {
    $YamabukiRDir = "C:\Prog\YamabukiR"
}

if (Test-Path $YamabukiRDir) {
    Link-Directory -Source "$DotfilesWindows\yamabuki-r\layout" -Destination "$YamabukiRDir\layout"
}
else {
    Write-Host "  [skip] $YamabukiRDir -> Yamabuki R not found"
}
Write-Host ""
Write-Host "=== Neovim 設定のリンク ==="

# nvim 設定（WSL/Windows 共有）→ %LOCALAPPDATA%\nvim
$NvimSrc  = Join-Path $PSScriptRoot "nvim"
$NvimDest = Join-Path $env:LOCALAPPDATA "nvim"
Link-Directory -Source $NvimSrc -Destination $NvimDest

Write-Host ""
Write-Host "=== 完了 ==="
Write-Host "WezTerm を再起動して設定が反映されていることを確認してください。"
