# ===== dotfiles を pull してスキルのリンクを張り直す (Windows の定期実行用) =====
# register-skills-sync.ps1 がタスクスケジューラに登録する。手で叩いてもよい。
# pull は best-effort (オフライン・競合で失敗してもリンクは張り直す)。
# ログ: %LOCALAPPDATA%\dotfiles\skills-sync.log (末尾 300 行だけ残す)
param(
    [string]$DotfilesDir = (Split-Path -Parent $PSScriptRoot),
    [string]$HomeDir = $env:USERPROFILE
)

$logDir = Join-Path $env:LOCALAPPDATA "dotfiles"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$log = Join-Path $logDir "skills-sync.log"
function Write-Log([string]$msg) { Add-Content -Path $log -Value ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg) -Encoding utf8 }

# pull は 60 秒で打ち切る (ネットワークが無いときに溜まらないように)
$job = Start-Job -ScriptBlock { param($d) git -C $d pull -q 2>&1; $LASTEXITCODE } -ArgumentList $DotfilesDir
if (Wait-Job $job -Timeout 60) {
    $out = @(Receive-Job $job)
    $code = $out[-1]
    $msg = ($out | Select-Object -SkipLast 1) -join " "
    if ($code -eq 0) { if ($msg) { Write-Log "pull ok: $msg" } } else { Write-Log "pull NG ($code): $msg" }
} else {
    Stop-Job $job; Write-Log "pull timeout"
}
Remove-Job $job -Force

try {
    $changes = & (Join-Path $DotfilesDir "skills\link-skills.ps1") -HomeDir $HomeDir -DotfilesDir $DotfilesDir -Quiet 6>&1 | Out-String
    if ($changes.Trim()) { Write-Log ("link:`n" + $changes.TrimEnd()) }
} catch {
    Write-Log "link NG: $_"
}

$lines = Get-Content $log -ErrorAction SilentlyContinue
if ($lines.Count -gt 300) { $lines | Select-Object -Last 300 | Set-Content $log -Encoding utf8 }
