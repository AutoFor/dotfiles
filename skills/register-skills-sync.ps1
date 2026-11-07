# ===== sync-skills.ps1 をタスクスケジューラに登録する (Windows) =====
# ログオン時 + 15 分ごとに「dotfiles を pull → スキルのリンクを張り直す」を実行する。
# 窓を出さないよう conhost --headless 経由で pwsh を起動する。
# 自分用なら管理者権限は不要:
#   pwsh -File skills\register-skills-sync.ps1
# 別ユーザー用 (desktop で SSH 用の seiya から、Claude を使う Entra ID ユーザーへ。要管理者):
#   pwsh -File skills\register-skills-sync.ps1 -UserId 'AzureAD\SeiyaKawashima' -HomeDir C:\Users\SeiyaKawashima -DotfilesDir C:\Users\SeiyaKawashima\ghq\github.com\AutoFor\dotfiles
# 解除: Unregister-ScheduledTask -TaskName dotfiles-skills-sync -Confirm:$false
param(
    [string]$UserId = "$env:USERDOMAIN\$env:USERNAME",
    [string]$HomeDir = $env:USERPROFILE,
    [string]$DotfilesDir = (Split-Path -Parent $PSScriptRoot),
    [string]$TaskName = "dotfiles-skills-sync",
    # Interactive: そのユーザーがログオン中だけ動く (管理者権限不要)
    # S4U: ログオフ中も動く (登録に管理者権限が要る。パスワードは保存しない)
    [ValidateSet("Interactive", "S4U")][string]$LogonType = "Interactive"
)

$ErrorActionPreference = "Stop"
$sync = Join-Path $DotfilesDir "skills\sync-skills.ps1"

# ストア版 pwsh の実体パスはバージョン入りで変わるため、対象ユーザーの実行エイリアスを優先する
$alias = Join-Path $HomeDir "AppData\Local\Microsoft\WindowsApps\pwsh.exe"
$pwsh = if (Test-Path $alias) { $alias } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }

$arg = "--headless `"{0}`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"{1}`" -DotfilesDir `"{2}`" -HomeDir `"{3}`"" -f $pwsh, $sync, $DotfilesDir, $HomeDir
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument $arg -WorkingDirectory $DotfilesDir

$logon = New-ScheduledTaskTrigger -AtLogOn -User $UserId
$every = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType $LogonType -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logon, $every) `
    -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "${TaskName}: $UserId 用に登録しました ($LogonType, ログオン時 + 15 分ごと) -> $sync"
