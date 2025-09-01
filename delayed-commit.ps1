# Delayed Smart Commit Script
param()

$lockFile = "$env:TEMP\commit-timer.lock"
$timerFile = "$env:TEMP\commit-timer.txt"

# 既存のタイマーをキャンセル
if (Test-Path $lockFile) {
    $pid = Get-Content $lockFile
    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
}

# 新しいタイマーを開始（バックグラウンド）
$job = Start-Job -ScriptBlock {
    Start-Sleep -Seconds 5
    & "C:\Users\SeiyaKawashima\.claude\smart-commit.ps1"
}

# プロセスIDを保存
$job.Id | Out-File $lockFile -Force
Write-Host "⏱️ 5秒後に自動コミット予定（新しい編集があればリセット）" -ForegroundColor Yellow