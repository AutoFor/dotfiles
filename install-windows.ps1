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
Link-File -Source "$DotfilesWindows\.wslconfig"   -Destination "$WinHome\.wslconfig"
Link-File -Source "$DotfilesWindows\.bashrc"      -Destination "$WinHome\.bashrc"

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
Write-Host "=== wezterm-pane:// URL スキーム登録 ==="

# Claude Code 通知トーストのクリックで通知元ペインへジャンプするためのプロトコルハンドラ。
# HKCU 配下なので管理者権限は不要。冪等（再実行すると上書き更新）。
$GotoPaneScript = Join-Path $DotfilesWindows "wezterm-goto-pane.ps1"
$SchemeKey = "HKCU:\Software\Classes\wezterm-pane"
New-Item -Path "$SchemeKey\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path $SchemeKey -Name "(Default)" -Value "URL:WezTerm pane jump"
Set-ItemProperty -Path $SchemeKey -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "$SchemeKey\shell\open\command" -Name "(Default)" `
    -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$GotoPaneScript`" `"%1`""
Write-Host "  [reg] wezterm-pane:// -> $GotoPaneScript"

Write-Host ""
Write-Host "=== 完了 ==="
Write-Host "WezTerm を再起動して設定が反映されていることを確認してください。"
