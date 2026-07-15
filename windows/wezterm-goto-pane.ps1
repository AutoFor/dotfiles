# wezterm-pane://<pane_id> プロトコルハンドラ
# トースト通知のクリックで呼ばれ、WezTerm の該当ペインをアクティブにしてウィンドウを前面に出す。
# スキーム登録は install-windows.ps1 が行う。
param([string]$Url)

if ($Url -notmatch '^wezterm-pane://(\d+)') {
    exit 0
}
$PaneId = $Matches[1]

$Wezterm = Get-Command wezterm.exe -ErrorAction SilentlyContinue
if ($Wezterm) {
    $Wezterm = $Wezterm.Source
} else {
    $Wezterm = Join-Path $env:ProgramFiles "WezTerm\wezterm.exe"
}
if (-not (Test-Path $Wezterm)) {
    exit 1
}

# ペイン（とその含まれるタブ）をアクティブにする
& $Wezterm cli activate-pane --pane-id $PaneId

# WezTerm ウィンドウを前面へ（最小化されていれば復元）。
# トーストのクリック直後はフォアグラウンド権限が引き継がれるので SetForegroundWindow が通る。
$Sig = @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
'@
$Win32 = Add-Type -MemberDefinition $Sig -Name "Win32Focus" -Namespace "WeztermGotoPane" -PassThru

$Proc = Get-Process wezterm-gui -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1
if ($Proc) {
    $Hwnd = $Proc.MainWindowHandle
    if ($Win32::IsIconic($Hwnd)) {
        [void]$Win32::ShowWindowAsync($Hwnd, 9)  # SW_RESTORE
    }
    [void]$Win32::SetForegroundWindow($Hwnd)
}
