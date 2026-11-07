# ===== スキルを Claude Code と Codex の両方へリンクする (Windows) =====
# 正本: dotfiles\skills\<name>\  (1 スキル = 1 フォルダ。ここだけを編集する)
# リンク先:
#   Claude Code -> %USERPROFILE%\.claude\skills\<name>
#   Codex       -> %USERPROFILE%\.agents\skills\<name>   (Codex 公式のユーザースコープ)
# スキルフォルダに .skill-scope を置くと対象を絞れる (無ければ全 OS・全エージェント):
#   os: windows,linux
#   agents: claude,codex
# 冪等。dotfiles 管理外のスキル (synced\ や手で置いたもの) には触らない。
# 同名の実フォルダがあれば .claude\backups\skills-<日時>\ に退避してからリンクする。
# リンクはジャンクション (フォルダ専用・管理者権限も Developer Mode も不要) で作る。
#
# 別ユーザーのホームへ配備する例 (desktop で SSH 用ユーザーから Entra ID ユーザーへ):
#   pwsh -File link-skills.ps1 -HomeDir C:\Users\SeiyaKawashima -DotfilesDir C:\Users\SeiyaKawashima\ghq\github.com\AutoFor\dotfiles
param(
    [string]$HomeDir = $env:USERPROFILE,
    [string]$DotfilesDir = (Split-Path -Parent $PSScriptRoot),
    [switch]$Quiet   # 変化があった行だけ出す (定期実行用)
)

$ErrorActionPreference = "Stop"
$DotfilesDir = (Resolve-Path $DotfilesDir).Path.TrimEnd('\')
$SkillsSrc = Join-Path $DotfilesDir "skills"
$OsName = "windows"
$BackupDir = Join-Path $HomeDir (".claude\backups\skills-" + (Get-Date -Format "yyyyMMddHHmmss"))

function Get-LinkTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) { return [string]($item.Target | Select-Object -First 1) }
    return $null
}

function Test-InScope([string]$SkillDir, [string]$Agent) {
    $scope = Join-Path $SkillDir ".skill-scope"
    if (-not (Test-Path -LiteralPath $scope)) { return $true }
    foreach ($pair in @(@("os", $OsName), @("agents", $Agent))) {
        $line = Get-Content -LiteralPath $scope | Where-Object { $_ -match "^$($pair[0]):" } | Select-Object -First 1
        if ($line) {
            $values = ($line -split ":", 2)[1] -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            if ($values -notcontains $pair[1]) { return $false }
        }
    }
    return $true
}

function Sync-Agent([string]$Agent, [string]$DestRoot) {
    if (-not $Quiet) { Write-Host "--- ${Agent}: $DestRoot" }
    if (-not (Test-Path -LiteralPath $DestRoot)) { New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null }

    # dotfiles を指すリンクのうち 先が消えた/対象外 になったものを外す
    Get-ChildItem -LiteralPath $DestRoot -Force | Where-Object { $_.LinkType } | ForEach-Object {
        $target = Get-LinkTarget $_.FullName
        if (-not $target -or -not $target.StartsWith($DotfilesDir + "\", [StringComparison]::OrdinalIgnoreCase)) { return }
        $expected = Join-Path $SkillsSrc $_.Name
        if ($target -ne $expected -or -not (Test-Path -LiteralPath $target) -or -not (Test-InScope $target $Agent)) {
            $_.Delete()
            Write-Host "  [unlink] $($_.FullName)"
        }
    }

    Get-ChildItem -LiteralPath $SkillsSrc -Directory | ForEach-Object {
        $src = $_.FullName
        $dest = Join-Path $DestRoot $_.Name
        if (-not (Test-InScope $src $Agent)) { if (-not $Quiet) { Write-Host "  [scope] $($_.Name) は $OsName/$Agent 対象外" }; return }
        if ((Get-LinkTarget $dest) -eq $src) { if (-not $Quiet) { Write-Host "  [skip] $dest" }; return }
        if (Test-Path -LiteralPath $dest) {
            if (-not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
            Move-Item -LiteralPath $dest -Destination (Join-Path $BackupDir "$($_.Name).$Agent") -Force
            Write-Host "  [backup] $dest -> $BackupDir"
        }
        New-Item -ItemType Junction -Path $dest -Target $src | Out-Null
        Write-Host "  [link] $dest -> $src"
    }
}

Sync-Agent "claude" (Join-Path $HomeDir ".claude\skills")
Sync-Agent "codex"  (Join-Path $HomeDir ".agents\skills")

# 旧配置 .codex\skills の dotfiles リンクは撤去 (.agents\skills と二重に読まれるため)
$legacy = Join-Path $HomeDir ".codex\skills"
if (Test-Path -LiteralPath $legacy) {
    Get-ChildItem -LiteralPath $legacy -Force | Where-Object { $_.LinkType } | ForEach-Object {
        $target = Get-LinkTarget $_.FullName
        if ($target -and $target.StartsWith($DotfilesDir + "\", [StringComparison]::OrdinalIgnoreCase)) {
            $_.Delete(); Write-Host "  [unlink legacy] $($_.FullName)"
        }
    }
}
