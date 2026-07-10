# ===== wezterm-jump: プロトコルの HKCU 登録 =====
# トースト通知クリック → wezterm-jump.ps1 起動を仲介する URI スキームを登録する。
# 管理者権限は不要。dotfiles の場所を動かしたら再実行すること。
$handler = Join-Path $PSScriptRoot "wezterm-jump.ps1"
# ストア版 pwsh の実体パスはバージョン入りで更新のたびに変わるため、
# 安定した実行エイリアス (WindowsApps\pwsh.exe) を優先する
$alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"
$pwsh = if (Test-Path $alias) { $alias } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
$key = "HKCU:\Software\Classes\wezterm-jump"
New-Item -Path "$key\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path $key -Name "(default)" -Value "URL:WezTerm Jump Protocol"
Set-ItemProperty -Path $key -Name "URL Protocol" -Value ""
Set-ItemProperty -Path "$key\shell\open\command" -Name "(default)" -Value ("`"{0}`" -NoProfile -NonInteractive -WindowStyle Hidden -File `"{1}`" `"%1`"" -f $pwsh, $handler)
Write-Host "wezterm-jump: プロトコルを登録しました -> $handler"
