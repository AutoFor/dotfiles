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

# WezTerm 内部のペイン/タブ選択
& $wezterm cli activate-pane --pane-id $wezPane

# activate-pane は WezTerm の中でペインを選ぶだけで、OS のウィンドウは前面に出ない。
# 他のアプリを見ているときにトーストをクリックすると、tmux 側は移動しているのに
# 画面上は何も起きないように見えるため、ここで明示的に前面化する
# （LEADER+j 側は .wezterm.lua の gui_window:focus() が同じ役割を担っている）。
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WezJumpWin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
}
"@

$hwnd = (Get-Process wezterm-gui -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1).MainWindowHandle
if ($hwnd) {
    if ([WezJumpWin]::IsIconic($hwnd)) { [void][WezJumpWin]::ShowWindow($hwnd, 9) }  # SW_RESTORE
    [void][WezJumpWin]::SetForegroundWindow($hwnd)
    if ([WezJumpWin]::GetForegroundWindow() -ne $hwnd) {
        # Windows は「入力を受け取っていないプロセス」からの前面化を黙って無視する。
        # トーストを押した経路によってはこの制限に当たり、tmux だけ移動して画面は
        # 変わらない状態になる（#224 の後に見つかった穴）。0px のマウス移動を
        # 出して入力イベントの発行元になると制限が外れる。ALT キー合成でも同じ
        # ことができるが、離した瞬間に元アプリのメニューを掴むので使わない。
        [WezJumpWin]::mouse_event(0x0001, 0, 0, 0, [UIntPtr]::Zero)   # MOUSEEVENTF_MOVE
        [void][WezJumpWin]::SetForegroundWindow($hwnd)
    }
}

# tmux 側も通知元ペインへ移動する。
# キーストローク注入 (send-text) は経路によって tmux に届かないことがあるため、
# devbox 側の tmux-jump-pane を ssh で呼ぶ。クライアント選択（tm のグループ
# セッション対応）もそちらに集約している。
if ($tmuxPane) {
    $ssh = Join-Path $env:SystemRoot "System32\OpenSSH\ssh.exe"
    # -n（stdin を /dev/null に）が無いと、経路によっては stdin を掴んだまま待つことがある
    & $ssh -n -o BatchMode=yes -o ConnectTimeout=5 devbox "~/.local/bin/tmux-jump-pane '%$tmuxPane'"
}
