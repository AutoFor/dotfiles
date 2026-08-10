# voice-overlay.ps1 -- 音声入力中、画面中央に波形付きの「録音中」フローティング表示を出す。
# voice-input.ps1 から起動され、録音フラグが消えると自動で閉じる。
#
# WezTerm/tmux の中には描かない:
#   - tmux display-popup はキー入力を奪うため、録音中に流れ込む send-text の
#     文字起こしがポップアップに食われて壊れる
#   - WezTerm Lua にはペイン上へ任意描画するオーバーレイ API が無い
# 録音の実体は Windows 側なので、Windows の最前面ウィンドウとして重ねるのが正解。
# 波形は voice-input.ps1 が 100ms ごとに $LevelFile へ書く実測 RMS で動く。
param(
  [string]$RecordingFlag = (Join-Path $env:TEMP 'wezterm-voice-recording.flag'),
  [string]$LevelFile = (Join-Path $env:TEMP 'wezterm-voice-level.txt'),
  [int]$TimeoutSeconds = 360   # 保険。voice-input.ps1 の MaxSeconds (300) より長め
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# フォーカスを奪わないフォーム。フォーカスが移ると 2 度目の LEADER+Space (停止) が
# WezTerm に届かなくなるため、WS_EX_NOACTIVATE が実質必須
$src = @'
using System.Windows.Forms;
public class NoActivateForm : Form {
  protected override bool ShowWithoutActivation { get { return true; } }
  protected override CreateParams CreateParams {
    get {
      CreateParams p = base.CreateParams;
      p.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
      p.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW (Alt+Tab に出さない)
      return p;
    }
  }
}
'@
$form = $null
try {
  # Roslyn コンパイル (毎回 1 秒前後) を避けるため、コンパイル済み DLL をキャッシュする
  # (voice-input.ps1 の recorder DLL と同じ方式)
  $overlayDll = Join-Path $env:TEMP 'wezterm-voice-overlay.dll'
  $overlayHashFile = "$overlayDll.hash"
  $srcHash = (Get-FileHash -Algorithm SHA256 -InputStream (
      [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($src)))).Hash
  if (-not (Test-Path -LiteralPath $overlayDll) -or
      (Get-Content -LiteralPath $overlayHashFile -ErrorAction SilentlyContinue) -ne $srcHash) {
    Add-Type -TypeDefinition $src -OutputAssembly $overlayDll -ReferencedAssemblies @(
      [System.Windows.Forms.Form].Assembly.Location,
      [System.ComponentModel.Component].Assembly.Location,
      [System.Drawing.Point].Assembly.Location
    )
    Set-Content -LiteralPath $overlayHashFile -Value $srcHash
  }
  if (-not ('NoActivateForm' -as [type])) { Add-Type -Path $overlayDll }
  $form = [NoActivateForm]::new()
} catch {
  # コンパイルに失敗しても機能自体は生かす (表示時に一瞬フォーカスを奪う欠点だけ残る)
  $form = [System.Windows.Forms.Form]::new()
}

$W = 320; $H = 96
$form.FormBorderStyle = 'None'
$form.StartPosition = 'Manual'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#16161e')
$form.Opacity = 0.92
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Bounds = [System.Drawing.Rectangle]::new(
  $wa.X + [int](($wa.Width - $W) / 2), $wa.Y + [int](($wa.Height - $H) / 2), $W, $H)

# 直近の音量履歴 (バー 1 本 = 50ms tick 1 回分)。左から右へ流れる
$history = [System.Collections.Generic.Queue[double]]::new()
foreach ($i in 1..41) { $history.Enqueue(0) }

$form.Add_Paint({
  param($s, $e)
  $g = $e.Graphics
  $g.SmoothingMode = 'AntiAlias'
  $g.FillEllipse([System.Drawing.Brushes]::Red, 16, 15, 10, 10)
  $font = [System.Drawing.Font]::new('Yu Gothic UI', 10)
  $g.DrawString('録音中 — Ctrl+q Space で停止', $font, [System.Drawing.Brushes]::White, 32, 12)
  $font.Dispose()
  # 波形バー: 中央線から上下対称。無音でも 2px 残して「生きている」ことを示す
  $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#7aa2f7'))
  $midY = 64; $maxH = 22; $x = 16
  foreach ($v in $history.ToArray()) {
    $h = [math]::Max(2.0, [math]::Min(1.0, $v / 3000.0) * $maxH)
    $g.FillRectangle($brush, $x, [single]($midY - $h), 4, [single]($h * 2))
    $x += 7
  }
  $brush.Dispose()
})

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 50
$timer.Add_Tick({
  if (-not (Test-Path -LiteralPath $RecordingFlag) -or (Get-Date) -gt $deadline) {
    $form.Close()
    return
  }
  $lvl = 0.0
  try { $lvl = [double]([System.IO.File]::ReadAllText($LevelFile).Trim()) } catch {}
  $null = $history.Dequeue()
  $history.Enqueue($lvl)
  $form.Invalidate()
})
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
$timer.Dispose()
