# ===== WezTerm ランチャーのショートカット登録 =====
# wezterm-launch.ps1 (進捗表示・二重起動防止つきの WezTerm 起動) を
# スタートメニューに「WezTerm (devbox)」として登録する。管理者権限不要。
# 登録後、タスクバーには従来の WezTerm の代わりにこのショートカットを
# ピン留めする (スタートメニューで検索 → 右クリック → タスクバーにピン留め)。
# dotfiles の場所を動かしたら再実行すること。
$launcher = Join-Path $PSScriptRoot "wezterm-launch.ps1"

# ストア版 pwsh の実体パスはバージョン入りで更新のたびに変わるため、
# 安定した実行エイリアス (WindowsApps\pwsh.exe) を優先する (register-wezterm-jump.ps1 と同じ)
$alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
$pwsh = if (Test-Path $alias) { $alias } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }

$lnk = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\WezTerm (devbox).lnk"
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath = $pwsh
$sc.Arguments = "-NoProfile -NoLogo -ExecutionPolicy Bypass -File `"$launcher`""
$sc.WorkingDirectory = $env:USERPROFILE
# 見た目は WezTerm 本体のアイコンを借りる
$sc.IconLocation = (Join-Path $env:ProgramFiles "WezTerm\wezterm-gui.exe") + ",0"
$sc.Description = "devbox の起動を担保しつつ WezTerm を開く (進捗表示・二重起動防止)"
$sc.Save()
Write-Host "登録しました -> $lnk"
Write-Host "タスクバーの WezTerm のピン留めをこれに差し替えてください。"
