# ===== rpa VM 上で dotfiles を pull し、スクリプトを配備する (rpa VM 上で実行) =====
#
# rpa は「編集席」ではなく pull するだけの消費者。編集は Windows / devbox の
# 2 クローンで行い、rpa はここで受け取って配備するだけ。
#
# 使い方 (rpa の SSH セッション内で):
#   pwsh -File C:\dotfiles\windows\bin\rpa-deploy.ps1
#
# 環境変数で上書き可: RPA_DOTFILES_DIR
param(
    [switch]$SkipPull
)

$ErrorActionPreference = 'Stop'

$RepoUrl  = 'https://github.com/AutoFor/dotfiles.git'
$RepoDir  = if ($env:RPA_DOTFILES_DIR) { $env:RPA_DOTFILES_DIR } else { 'C:\dotfiles' }
$TaskName = 'rpa-idle-shutdown'

# 配備するもの: リポジトリ内の正本 -> タスクが読む配備先。
# 配備先を作業ツリー内にしないのは、git の改行変換やフィルタの影響を避けるため。
$Deployments = @(
    @{ Src = 'windows\bin\rpa-idle-shutdown.ps1'; Dst = "$env:ProgramData\rpa-idle-shutdown.ps1" }
)

function Test-OnRpa {
    if ($env:COMPUTERNAME -ne 'rpa') {
        Write-Warning "ここは $env:COMPUTERNAME です。rpa 上で実行してください。中止します。"
        return $false
    }
    return $true
}

# UTF-8 BOM 付きで書き出す。BOM が無いとスケジュールタスクが呼ぶ
# Windows PowerShell 5.1 が ANSI として読み、日本語コメントが化けて
# 構文エラーになりスクリプトが起動すらしない (2026-08-26 の事故)。
# リポジトリ側が BOM 付きでも、経路の途中で失われる可能性があるため
# 配備時に必ず保証する。
function Write-Utf8Bom {
    param([string]$Path, [byte[]]$Content)
    $bom = [byte[]](0xEF, 0xBB, 0xBF)
    if ($Content.Length -ge 3 -and $Content[0] -eq 0xEF -and $Content[1] -eq 0xBB -and $Content[2] -eq 0xBF) {
        $Content = $Content[3..($Content.Length - 1)]
    }
    $out = New-Object byte[] ($bom.Length + $Content.Length)
    [Array]::Copy($bom, 0, $out, 0, $bom.Length)
    [Array]::Copy($Content, 0, $out, $bom.Length, $Content.Length)
    [System.IO.File]::WriteAllBytes($Path, $out)
}

# 壊れたものが黙って居座らないよう、配備後に必ず構文を確認する。
function Test-Parses {
    param([string]$Path)
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
    if ($errs) {
        Write-Warning "$Path に構文エラーが $($errs.Count) 件あります:"
        $errs | Select-Object -First 5 | ForEach-Object { Write-Warning ("  L{0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) }
        return $false
    }
    return $true
}

function Sync-Repo {
    if (Test-Path (Join-Path $RepoDir '.git')) {
        if ($SkipPull) { Write-Host "pull をスキップしました ($RepoDir)"; return }
        Write-Host "pull: $RepoDir"
        & git -C $RepoDir pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull に失敗しました" }
    }
    else {
        Write-Host "clone: $RepoUrl -> $RepoDir"
        & git clone $RepoUrl $RepoDir
        if ($LASTEXITCODE -ne 0) { throw "git clone に失敗しました" }
    }
}

# タスクが未登録なら作る。既にあれば触らない (手動調整を尊重する)。
function Register-IdleTask {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-Host "スケジュールタスク '$TaskName' は登録済みです"
        return
    }
    Write-Host "スケジュールタスク '$TaskName' を登録します"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$($Deployments[0].Dst)`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date
    $trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
        -RepetitionInterval (New-TimeSpan -Minutes 10) `
        -RepetitionDuration ([TimeSpan]::MaxValue)).Repetition
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
}

if (-not (Test-OnRpa)) { exit 1 }

Sync-Repo

$failed = $false
foreach ($d in $Deployments) {
    $src = Join-Path $RepoDir $d.Src
    if (-not (Test-Path $src)) { Write-Warning "見つかりません: $src"; $failed = $true; continue }

    Write-Utf8Bom -Path $d.Dst -Content ([System.IO.File]::ReadAllBytes($src))

    if (Test-Parses -Path $d.Dst) {
        Write-Host "配備 OK: $($d.Dst)  ($((Get-Item $d.Dst).Length) bytes)"
    }
    else {
        Write-Warning "配備したファイルが壊れています: $($d.Dst)"
        $failed = $true
    }
}

Register-IdleTask

if ($failed) { Write-Warning "一部の配備に失敗しました"; exit 1 }
Write-Host "完了しました"
