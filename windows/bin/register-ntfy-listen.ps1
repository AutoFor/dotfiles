# ===== ntfy-listen.ps1 をログオン時常駐に登録する =====
# 管理者権限は不要。dotfiles の場所を動かしたら再実行すること。
# 解除は: Unregister-ScheduledTask -TaskName "ntfy-listen" -Confirm:$false
$listener = Join-Path $PSScriptRoot "ntfy-listen.ps1"
# ストア版 pwsh の実体パスはバージョン入りで更新のたびに変わるため、
# 安定した実行エイリアス (WindowsApps\pwsh.exe) を優先する
$alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
$pwsh = if (Test-Path $alias) { $alias } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }

$taskName = "ntfy-listen"
$action = New-ScheduledTaskAction -Execute $pwsh -Argument (
    "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`"" -f $listener)
# トーストは対話セッションでしか出せないので、ログオン時にそのユーザーとして起動する
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
# 購読しっぱなしのプロセスなので実行時間制限を外し、落ちたら再起動させる
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "ntfy-listen: ログオン時常駐に登録して起動しました -> $listener"
