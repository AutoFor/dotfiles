# ===== WezTerm 起動ランチャー（進捗表示・二重起動防止） =====
# タスクバー/スタートメニューから WezTerm を開くときの入口。
# wezterm-gui.exe を直接起動すると、devbox VM が停止していた場合に
# gui-startup の VM 起動担保 (devbox.ps1 ensure) が終わるまでウィンドウが
# 一切出ず、「反応していないように見える → もう一度クリック → 二重起動」が
# 起きる。このランチャーは:
#   1) 起動処理中の二度押しを無視する (Mutex)
#   2) 既に WezTerm が開いていれば前面化するだけ (二重起動しない)
#   3) このコンソールに進捗を出しながら devbox の起動を担保してから
#      wezterm-gui を起動する (ensure 済みなので gui-startup 側は即座に通る)
#   4) WezTerm のウィンドウが実際に表示されるまでコンソールを閉じない
# 事前に register-wezterm-launch.ps1 でショートカットを作成し、
# タスクバーには従来の WezTerm の代わりにそれをピン留めして使う。

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "WezTerm 起動中..."

$wezterm = Join-Path $env:ProgramFiles "WezTerm\wezterm-gui.exe"
if (-not (Test-Path $wezterm)) {
    Write-Warning "wezterm-gui.exe が見つかりません: $wezterm"
    Start-Sleep -Seconds 5
    exit 1
}

# 前面化まわりの Win32 API (wezterm-jump.ps1 と同じ手口)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WezLaunchWin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
}
"@

function Get-WezWindow {
    (Get-Process wezterm-gui -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1).MainWindowHandle
}

function Show-WezWindow([IntPtr]$hwnd) {
    if ([WezLaunchWin]::IsIconic($hwnd)) { [void][WezLaunchWin]::ShowWindow($hwnd, 9) }  # SW_RESTORE
    [void][WezLaunchWin]::SetForegroundWindow($hwnd)
    if ([WezLaunchWin]::GetForegroundWindow() -ne $hwnd) {
        # Windows は「入力を受け取っていないプロセス」からの前面化を黙って無視する。
        # 0px のマウス移動で入力イベントの発行元になると制限が外れる (wezterm-jump.ps1 と同じ)
        [WezLaunchWin]::mouse_event(0x0001, 0, 0, 0, [UIntPtr]::Zero)   # MOUSEEVENTF_MOVE
        [void][WezLaunchWin]::SetForegroundWindow($hwnd)
    }
}

# --- 1) 二度押しガード ---
# 起動処理中にもう一度クリックされても 2 プロセス目を作らない。
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\wezterm-devbox-launcher", [ref]$created)
if (-not $created) {
    Write-Host "WezTerm は起動処理中です。このままお待ちください (二重起動はしません)"
    Start-Sleep -Seconds 3
    exit 0
}

try {
    # --- 2) 既に開いていれば前面化だけ ---
    $hwnd = Get-WezWindow
    if ($hwnd) {
        Write-Host "起動済みの WezTerm を前面に出します"
        Show-WezWindow $hwnd
        exit 0
    }

    if (Get-Process wezterm-gui -ErrorAction SilentlyContinue) {
        # プロセスはあるがウィンドウ未表示 = ランチャーを経由せず起動された直後など。
        # 下のウィンドウ表示待ちループに合流する
        Write-Host "WezTerm は起動処理中です。ウィンドウの表示を待っています..."
    }
    else {
        # --- 3) devbox の起動を担保 (進捗は devbox.ps1 がこのコンソールに出す) ---
        Write-Host "devbox への到達性を確認しています..."
        & (Join-Path $PSScriptRoot "devbox.ps1") ensure
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "devbox の起動担保に失敗しました。WezTerm はこのまま起動します (接続エラーはウィンドウ内に表示されます)"
            Start-Sleep -Seconds 3
        }
        Write-Host "WezTerm を起動しています..."
        Start-Process $wezterm
    }

    # --- 4) ウィンドウが実際に出るまでこのコンソールを残す ---
    for ($i = 0; $i -lt 60; $i++) {
        $hwnd = Get-WezWindow
        if ($hwnd) {
            Show-WezWindow $hwnd
            exit 0
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Warning "30 秒待ちましたが WezTerm のウィンドウを確認できませんでした。もうしばらくかかるかもしれません。"
    Start-Sleep -Seconds 5
    exit 1
}
finally {
    if ($created) { [void]$mutex.ReleaseMutex() }
}
