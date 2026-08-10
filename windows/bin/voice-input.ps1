# voice-input.ps1 -- マイク録音 → Groq Whisper (whisper-large-v3-turbo) で文字起こしし、
# 結果を WezTerm のペイン（tmux 内の Claude Code プロンプト等）へ流し込む。
# WezTerm の LEADER+Space (toggle_voice_input) から起動される。
#
# 流れ:
#   1) .wezterm.lua が LEADER+Space の 1 回目でこのスクリプトを background 起動
#   2) winmm (MCI) でマイク録音を開始し、$StopFlag の出現を待つ
#      (2 回目の LEADER+Space で .wezterm.lua がフラグファイルを作成する)
#   3) 録音停止 → WAV 保存 → Groq の transcriptions API に POST
#   4) `wezterm cli send-text --pane-id <押下時のペイン>` で文字起こし結果を入力
#      (失敗時はクリップボードに退避してトースト通知)
#
# 事前準備 (Windows 側):
#   - Groq の API キーを取得 (https://console.groq.com/keys) してユーザー環境変数に設定:
#       pwsh> setx GROQ_API_KEY "gsk_..."
#     設定後は WezTerm を再起動する (環境変数は GUI 起動時に固定されるため)
#   - Windows 設定 > プライバシー > マイク で「デスクトップ アプリのマイク アクセス」を許可
#
# 録音は winmm.dll (MCI) 直叩きなので ffmpeg 等の追加インストールは不要。
param(
  [Parameter(Mandatory)][int]$PaneId,        # 文字起こし結果の送り先 WezTerm ペイン ID
  [string]$WezTermExe = 'wezterm.exe',       # wezterm.executable_dir から渡される
  [string]$StopFlag = (Join-Path $env:TEMP 'wezterm-voice-stop.flag'),
  [string]$RecordingFlag = (Join-Path $env:TEMP 'wezterm-voice-recording.flag'),
  [int]$MaxSeconds = 180,                    # 停止し忘れの保険。超えたら自動停止して文字起こしする
  [string]$Model = 'whisper-large-v3-turbo',
  [string]$Language = 'ja'                   # 空文字で自動判定 (英語で話すときなど)
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$logFile = Join-Path $env:TEMP 'wezterm-voice.log'
function Write-Log([string]$msg) {
  "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg | Add-Content -LiteralPath $logFile
}

# エラーは GUI から起動されて画面が無いので、Claude Code 通知と同じ BurntToast で知らせる
function Show-Toast([string]$msg) {
  try {
    & (Join-Path $PSScriptRoot '..\..\claude\windows-notify.ps1') -Title '音声入力' -Message $msg -Sound 'Default'
  } catch {
    Write-Log "toast failed: $_"
  }
}

if (-not $env:GROQ_API_KEY) {
  Write-Log 'GROQ_API_KEY 未設定'
  Show-Toast 'GROQ_API_KEY が未設定。pwsh で setx GROQ_API_KEY "gsk_..." を実行して WezTerm を再起動して'
  exit 1
}

# winmm の MCI で録音する (依存ゼロ)。record は非同期なのでフラグ待ちループと相性が良い
Add-Type -Namespace Win32 -Name Mci -MemberDefinition @'
[DllImport("winmm.dll", CharSet = CharSet.Unicode)]
public static extern int mciSendStringW(string command, System.Text.StringBuilder ret, int retLen, System.IntPtr hwnd);
'@

function Invoke-Mci([string]$command) {
  $sb = [System.Text.StringBuilder]::new(256)
  $rc = [Win32.Mci]::mciSendStringW($command, $sb, $sb.Capacity, [System.IntPtr]::Zero)
  if ($rc -ne 0) { throw "MCI error $rc : $command" }
  return $sb.ToString()
}

$wav = Join-Path $env:TEMP ("wezterm-voice-{0}.wav" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$opened = $false
try {
  Invoke-Mci 'open new type waveaudio alias cap'
  $opened = $true
  # Whisper 推奨の 16kHz/16bit/mono。失敗しても既定フォーマットで録音は続行できる
  try {
    Invoke-Mci 'set cap time format ms bitspersample 16 channels 1 samplespersec 16000 bytespersec 32000 alignment 2'
  } catch {
    Write-Log "set format failed (既定フォーマットで続行): $_"
  }
  Invoke-Mci 'record cap'

  # 右ステータスの「マイク起動中…」→「録音中」切り替え用 (.wezterm.lua が存在を見る)
  New-Item -ItemType File -Force -Path $RecordingFlag | Out-Null
  Write-Log "recording started (pane=$PaneId)"

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while (-not (Test-Path -LiteralPath $StopFlag)) {
    if ($sw.Elapsed.TotalSeconds -ge $MaxSeconds) {
      Write-Log "MaxSeconds ($MaxSeconds s) に達したため自動停止"
      break
    }
    Start-Sleep -Milliseconds 200
  }

  Invoke-Mci 'stop cap'
  Invoke-Mci "save cap ""$wav"""
}
finally {
  if ($opened) { try { Invoke-Mci 'close cap' } catch {} }
  Remove-Item -LiteralPath $StopFlag, $RecordingFlag -Force -ErrorAction SilentlyContinue
}

try {
  # 16kHz/16bit/mono = 32KB/s。0.5 秒未満は誤爆 (即 2 度押し等) とみなして捨てる
  if (-not (Test-Path -LiteralPath $wav) -or (Get-Item -LiteralPath $wav).Length -lt 16000) {
    Write-Log '録音が短すぎるため破棄'
    exit 0
  }

  $form = @{
    model           = $Model
    file            = Get-Item -LiteralPath $wav
    temperature     = '0'
    response_format = 'json'
  }
  if ($Language) { $form.language = $Language }

  try {
    $resp = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/audio/transcriptions' `
      -Method Post -Headers @{ Authorization = "Bearer $env:GROQ_API_KEY" } -Form $form
  } catch {
    $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Write-Log "Groq API 失敗: $detail"
    Show-Toast "文字起こしに失敗: $detail"
    exit 1
  }

  $text = ([string]$resp.text).Trim()
  Write-Log "transcribed: $text"
  if (-not $text) {
    Show-Toast '無音のため文字起こし結果が空だった'
    exit 0
  }

  # 続けて文章を打てるよう末尾へスペースを 1 つ足す (LEADER+v のパス貼り付けと同じ流儀)
  & $WezTermExe cli send-text --pane-id $PaneId -- ($text + ' ')
  if ($LASTEXITCODE -ne 0) {
    Set-Clipboard -Value $text
    Write-Log "send-text 失敗 (pane=$PaneId)。クリップボードに退避"
    Show-Toast 'ペインへの入力に失敗したため、クリップボードにコピーした (Ctrl+Shift+V で貼り付け)'
    exit 1
  }
}
finally {
  Remove-Item -LiteralPath $wav -Force -ErrorAction SilentlyContinue
}
