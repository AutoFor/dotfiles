# ===== wezterm-jump: URI ハンドラ =====
# トースト通知のクリックで起動され、通知元の WezTerm ペイン（と tmux ペイン）へジャンプする。
# URI 形式: wezterm-jump:<WezTermペインID>[/<tmuxペイン番号>]
# 事前に register-wezterm-jump.ps1 で HKCU にプロトコル登録しておくこと（管理者権限不要）。
param([Parameter(Mandatory = $true)][string]$Uri)

if ($Uri -notmatch '^wezterm-jump:(\d+)(?:/(\d+))?$') { exit 1 }
$wezPane  = $Matches[1]
$tmuxPane = $Matches[2]

$wezterm = Join-Path $env:ProgramFiles "WezTerm\wezterm.exe"
if (-not (Test-Path $wezterm)) { exit 1 }

# 起動中の GUI のソケットを特定して明示指定する
# （HOME が空の環境などで wezterm cli の自動発見が失敗することがあるため）
$sockDir = Join-Path $env:USERPROFILE ".local\share\wezterm"
$guiPids = @(Get-Process wezterm-gui -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
foreach ($f in Get-ChildItem $sockDir -Filter "gui-sock-*" -ErrorAction SilentlyContinue) {
    if ($guiPids -contains [int]($f.Name -replace '^gui-sock-', '')) {
        $env:WEZTERM_UNIX_SOCKET = $f.FullName
        break
    }
}

# WezTerm のウィンドウ/タブ/ペインをフォーカス
& $wezterm cli activate-pane --pane-id $wezPane

# tmux 側も通知元ペインへ移動する。
# キーストローク注入 (send-text) は経路によって tmux に届かないことがあるため、
# devbox 側の tmux-jump-pane を ssh で呼ぶ。クライアント選択（tm のグループ
# セッション対応）もそちらに集約している。
if ($tmuxPane) {
    $ssh = Join-Path $env:SystemRoot "System32\OpenSSH\ssh.exe"
    & $ssh -o BatchMode=yes -o ConnectTimeout=5 devbox "~/.local/bin/tmux-jump-pane '%$tmuxPane'"
}
