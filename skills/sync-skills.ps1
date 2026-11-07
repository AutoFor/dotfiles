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

# Windows のクローンは pull 専用の消費者 (編集・コミットは devbox だけ。docs/devbox-as-source-of-truth.md)。
# そのための設定をクローンのローカル設定に毎回入れる (冪等。変えたときだけログに出す):
#   core.hooksPath  .githooks の pre-commit が Windows でのコミットを拒否する
#   pull.ff only    ローカルのコミットは無い前提なので、早送りできなければ失敗させて気づけるようにする
#   merge.autoStash 誤っていじったファイルがあっても pull を止めない
$safeOpt = "safe.directory=$($DotfilesDir.Replace('\', '/'))"
foreach ($kv in @(@('core.hooksPath', '.githooks'), @('pull.ff', 'only'), @('pull.rebase', 'false'), @('merge.autoStash', 'true'))) {
    $cur = git -c $safeOpt -C $DotfilesDir config --local --get $kv[0]
    if ($cur -ne $kv[1]) {
        git -c $safeOpt -C $DotfilesDir config --local $kv[0] $kv[1]
        if ($LASTEXITCODE -eq 0) { Write-Log "config $($kv[0])=$($kv[1])" } else { Write-Log "config NG: $($kv[0])" }
    }
}

# pull は 60 秒で打ち切る (ネットワークが無いときに溜まらないように)
$job = Start-Job -ScriptBlock { param($d)
    # 別ユーザー (管理者) が触ったクローンでも "dubious ownership" で止まらないよう、このリポジトリだけ信頼する
    git -c "safe.directory=$($d.Replace('\', '/'))" -C $d pull -q 2>&1; $LASTEXITCODE } -ArgumentList $DotfilesDir
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
