# voice-input.ps1 -- マイク音声を Groq Whisper (whisper-large-v3-turbo) で文字起こしし、
# WezTerm のペイン（tmux 内の Claude Code プロンプト等）へ「疑似ストリーム」で流し込む。
# WezTerm の Ctrl+Space (toggle_voice_input) から起動される。
#
# 疑似ストリームの仕組み:
#   録音しっぱなしにして音量 (RMS) を監視し、「約 0.7 秒の無音 = フレーズの切れ目」で
#   チャンクを切り出してその場で Groq に POST → 結果を即ペインへ入力、を停止まで繰り返す。
#   Groq の Whisper API はストリーミング非対応 (ファイル一括のみ) のため、
#   本物のストリームではなくフレーズ単位の逐次変換で体感を近づけている。
#
# 流れ:
#   1) .wezterm.lua が Ctrl+Space の 1 回目でこのスクリプトを background 起動
#   2) winmm (waveIn) で 16kHz/16bit/mono 録音を開始し、100ms フレームごとに VAD 判定
#   3) フレーズの切れ目ごとに WAV を組み立てて Groq へ POST →
#      `wezterm cli send-text --pane-id <押下時のペイン>` で逐次入力
#   4) $StopFlag の出現 (2 回目の Ctrl+Space) で残りを変換して終了
#
# 幻聴・ゾンビ対策 (issue #229):
#   - PID ファイルで単一インスタンス化。停止フラグを取り逃したゾンビ録音が
#     タイピング音を拾って幻聴を貼り付け続けないよう、起動時に旧プロセスを kill
#   - verbose_json の no_speech_prob / compression_ratio、定型幻聴パターン
#     (「ご視聴ありがとうございました」等)、直前チャンクとの完全一致で
#     雑音チャンクの幻聴テキストをローカルで破棄する
#
# 小音量マイク対策 (issue #233):
#   VAD のしきい値が固定値だと、マイクの入力ボリュームが小さい環境で発話が
#   「声あり」と判定されず、チャンクごと捨てられて丸ごと取りこぼす。そこで
#   録音開始直後 600ms の環境音からノイズフロアを実測してしきい値を自動決定し
#   (計測中は下限値で判定するので頭は切れない)、さらに Groq へ送る前に
#   ピークを揃えて増幅する (小さいままだと Whisper 側の認識精度も落ちるため)。
#
# 辞書 (windows/voice-dictionary.txt):
#   Groq/Whisper にクラウド側の辞書機能は無いため、用語ヒント (prompt) で認識を
#   正しい表記へ寄せ、それでも外した分は「誤=正」ルールでローカル置換する。
#   辞書はリポジトリ管理なので devbox から編集して push → pull でも反映できる。
#   さらにセッション終了時、誤変換らしき用語を LLM が探してコメント状態で辞書へ
#   自動提案・コミットする (Invoke-DictionarySuggestion)。文字起こし全文は devbox の
#   ~/.cache/voice-transcripts.log にもミラーされ、devbox の Claude からも分析できる。
#
# 事前準備 (Windows 側):
#   - Groq の API キー (正本は Azure Key Vault autofor-kv/groq-api-key) を環境変数に設定:
#       pwsh> setx GROQ_API_KEY (az keyvault secret show --vault-name autofor-kv --name groq-api-key --query value -o tsv)
#     設定後は WezTerm を再起動する (環境変数は GUI 起動時に固定されるため)
#   - Windows 設定 > プライバシー > マイク で「デスクトップ アプリのマイク アクセス」を許可
#
# 録音は winmm.dll (waveIn) 直叩きなので ffmpeg 等の追加インストールは不要。
param(
  [Parameter(Mandatory)][int]$PaneId,        # 文字起こし結果の送り先 WezTerm ペイン ID
  [string]$WezTermExe = 'wezterm.exe',       # wezterm.executable_dir から渡される
  [string]$StopFlag = (Join-Path $env:TEMP 'wezterm-voice-stop.flag'),
  [string]$RecordingFlag = (Join-Path $env:TEMP 'wezterm-voice-recording.flag'),
  [int]$MaxSeconds = 300,                    # 停止し忘れの保険。超えたら自動停止する
  [string]$Model = 'whisper-large-v3-turbo',
  [string]$Language = 'ja',                  # 空文字で自動判定 (英語で話すときなど)
  [int]$SilenceThreshold = 0,                # これ未満の RMS (16bit 振幅) を無音とみなす。0 = 環境音から自動決定
  [int]$SilenceMs = 700,                     # この長さの無音でフレーズを区切って変換に回す
  [int]$MaxChunkSeconds = 15,                # 無音が来なくても強制的に区切る上限
  # 辞書: 「誤=正」の置換ルールと Whisper への用語ヒント (書式はファイル先頭のコメント参照)
  [string]$DictionaryFile = (Join-Path $PSScriptRoot '..\voice-dictionary.txt'),
  # セッション終了時に誤変換らしき用語を LLM に探させて辞書へ自動提案する。空文字で無効化
  [string]$SuggestModel = 'llama-3.3-70b-versatile',
  [switch]$Overlay                           # 画面中央の波形フローティング表示 (voice-overlay.ps1) を出す (既定オフ)
)

$ErrorActionPreference = 'Stop'
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8   # ssh へのパイプ (文字起こしミラー) 用
} catch {}

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
  Show-Toast 'GROQ_API_KEY が未設定。setx GROQ_API_KEY (az keyvault secret show ...) を実行して WezTerm を再起動して'
  exit 1
}

# 多重起動ガード。トグルのレース (例: .wezterm.lua のフラグ不在 10 秒自動リセット後の
# Ctrl+Space が停止ではなく 2 個目の起動になる) で旧プロセスが停止フラグを取り逃すと、
# ゾンビ録音がタイピング音などの雑音を拾って幻聴テキストを貼り付け続ける (issue #229)。
# 新しい起動を正として、生き残りの旧インスタンスは kill してから始める
$PidFile = Join-Path $env:TEMP 'wezterm-voice.pid'
$oldPid = Get-Content -LiteralPath $PidFile -ErrorAction SilentlyContinue
if ($oldPid -match '^\d+$' -and $oldPid -ne "$PID") {
  $old = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
  if ($old -and $old.ProcessName -eq 'pwsh') {
    Write-Log "旧インスタンス (PID=$oldPid) が残っていたので kill する"
    Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
  }
}
Set-Content -LiteralPath $PidFile -Value $PID

# winmm の waveIn 直叩き録音 (依存ゼロ)。MCI と違い録音を止めずにフレーム単位で
# データを取り出せるため、無音検出でのチャンク分割 (疑似ストリーム) ができる。
# バッファは FIFO で完了するので Poll は次に完了すべき番号だけ見ればよい。
$recorderSrc = @'
using System;
using System.Runtime.InteropServices;

namespace Voice {
  public class Recorder : IDisposable {
    [StructLayout(LayoutKind.Sequential)]
    public struct WaveFormat {
      public ushort wFormatTag, nChannels;
      public uint nSamplesPerSec, nAvgBytesPerSec;
      public ushort nBlockAlign, wBitsPerSample, cbSize;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WaveHdr {
      public IntPtr lpData;
      public uint dwBufferLength, dwBytesRecorded;
      public IntPtr dwUser;
      public uint dwFlags, dwLoops;
      public IntPtr lpNext, reserved;
    }

    [DllImport("winmm.dll")] static extern int waveInOpen(out IntPtr h, uint dev, ref WaveFormat fmt, IntPtr cb, IntPtr inst, uint flags);
    [DllImport("winmm.dll")] static extern int waveInPrepareHeader(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveInUnprepareHeader(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveInAddBuffer(IntPtr h, IntPtr hdr, int size);
    [DllImport("winmm.dll")] static extern int waveInStart(IntPtr h);
    [DllImport("winmm.dll")] static extern int waveInReset(IntPtr h);
    [DllImport("winmm.dll")] static extern int waveInClose(IntPtr h);

    const uint WHDR_DONE = 1;
    const uint WAVE_MAPPER = 0xFFFFFFFF;

    IntPtr handle;
    IntPtr[] headers, buffers;
    int bufBytes, bufCount, next;
    public const int SampleRate = 16000;

    static void Check(int rc, string what) {
      if (rc != 0) throw new Exception("waveIn " + what + " failed: rc=" + rc);
    }

    public void Start(int frameMs, int frameCount) {
      bufBytes = SampleRate * 2 * frameMs / 1000;
      bufCount = frameCount;
      var fmt = new WaveFormat {
        wFormatTag = 1, nChannels = 1, nSamplesPerSec = SampleRate,
        wBitsPerSample = 16, nBlockAlign = 2, nAvgBytesPerSec = SampleRate * 2, cbSize = 0
      };
      Check(waveInOpen(out handle, WAVE_MAPPER, ref fmt, IntPtr.Zero, IntPtr.Zero, 0), "open");
      int hdrSize = Marshal.SizeOf(typeof(WaveHdr));
      headers = new IntPtr[bufCount];
      buffers = new IntPtr[bufCount];
      for (int i = 0; i < bufCount; i++) {
        buffers[i] = Marshal.AllocHGlobal(bufBytes);
        headers[i] = Marshal.AllocHGlobal(hdrSize);
        var h = new WaveHdr { lpData = buffers[i], dwBufferLength = (uint)bufBytes };
        Marshal.StructureToPtr(h, headers[i], false);
        Check(waveInPrepareHeader(handle, headers[i], hdrSize), "prepare");
        Check(waveInAddBuffer(handle, headers[i], hdrSize), "add");
      }
      Check(waveInStart(handle), "start");
    }

    // 完了済みフレームを 1 つ返す (無ければ null)。返したバッファは録音キューに戻す
    public byte[] Poll() {
      int hdrSize = Marshal.SizeOf(typeof(WaveHdr));
      var h = (WaveHdr)Marshal.PtrToStructure(headers[next], typeof(WaveHdr));
      if ((h.dwFlags & WHDR_DONE) == 0) return null;
      var data = new byte[(int)h.dwBytesRecorded];
      Marshal.Copy(h.lpData, data, 0, data.Length);
      Check(waveInUnprepareHeader(handle, headers[next], hdrSize), "unprepare");
      var fresh = new WaveHdr { lpData = buffers[next], dwBufferLength = (uint)bufBytes };
      Marshal.StructureToPtr(fresh, headers[next], false);
      Check(waveInPrepareHeader(handle, headers[next], hdrSize), "re-prepare");
      Check(waveInAddBuffer(handle, headers[next], hdrSize), "re-add");
      next = (next + 1) % bufCount;
      return data;
    }

    // 16bit PCM の RMS (0-32768 目安)。VAD のしきい値判定に使う
    public static double Rms(byte[] data) {
      if (data == null || data.Length < 2) return 0;
      long sum = 0;
      int n = data.Length / 2;
      for (int i = 0; i < n; i++) {
        short s = (short)(data[2 * i] | (data[2 * i + 1] << 8));
        sum += (long)s * s;
      }
      return Math.Sqrt((double)sum / n);
    }

    // 小音量のマイク対策 (issue #233)。ピークが targetPeak になるよう 16bit PCM を
    // その場で増幅する (倍率の上限は maxGain)。返り値は実際に掛けた倍率 (1.0 = 未加工)
    public static double Normalize(byte[] data, int targetPeak, double maxGain) {
      if (data == null || data.Length < 2) return 1.0;
      int n = data.Length / 2;
      int peak = 0;
      for (int i = 0; i < n; i++) {
        short s = (short)(data[2 * i] | (data[2 * i + 1] << 8));
        int a = s < 0 ? -s : s;
        if (a > peak) peak = a;
      }
      if (peak == 0) return 1.0;
      double g = (double)targetPeak / peak;
      if (g > maxGain) g = maxGain;
      if (g <= 1.0) return 1.0;   // 既に十分な音量なら触らない (歪ませない)
      for (int i = 0; i < n; i++) {
        short s = (short)(data[2 * i] | (data[2 * i + 1] << 8));
        int v = (int)Math.Round(s * g);
        if (v > 32767) v = 32767; else if (v < -32768) v = -32768;
        data[2 * i] = (byte)(v & 0xff);
        data[2 * i + 1] = (byte)((v >> 8) & 0xff);
      }
      return g;
    }

    public void Dispose() {
      if (handle == IntPtr.Zero) return;
      waveInReset(handle);
      int hdrSize = Marshal.SizeOf(typeof(WaveHdr));
      for (int i = 0; i < bufCount; i++) {
        waveInUnprepareHeader(handle, headers[i], hdrSize);
        Marshal.FreeHGlobal(headers[i]);
        Marshal.FreeHGlobal(buffers[i]);
      }
      waveInClose(handle);
      handle = IntPtr.Zero;
    }
  }
}
'@

# Add-Type の C# コンパイル (Roslyn) は毎回 1〜2 秒かかり、キーを押した直後の発話が
# 録音開始前に切れる主因になる。コンパイル済み DLL を %TEMP% にキャッシュし、
# 2 回目以降はロードだけ (数十 ms) で済ませる。ソースを変えたらハッシュ違いで再生成
$recorderDll = Join-Path $env:TEMP 'wezterm-voice-recorder.dll'
$recorderHashFile = "$recorderDll.hash"
$srcHash = (Get-FileHash -Algorithm SHA256 -InputStream (
    [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($recorderSrc)))).Hash
if (-not (Test-Path -LiteralPath $recorderDll) -or
    (Get-Content -LiteralPath $recorderHashFile -ErrorAction SilentlyContinue) -ne $srcHash) {
  Add-Type -TypeDefinition $recorderSrc -OutputAssembly $recorderDll
  Set-Content -LiteralPath $recorderHashFile -Value $srcHash
}
if (-not ('Voice.Recorder' -as [type])) {
  try {
    Add-Type -Path $recorderDll
  } catch {
    Write-Log "recorder DLL のロード失敗 ($_)。直接コンパイルにフォールバック"
    Add-Type -TypeDefinition $recorderSrc
  }
}

# 16kHz/16bit/mono の PCM に RIFF ヘッダを付けて WAV として書き出す
function Write-Wav([string]$path, [byte[]]$pcm) {
  $bw = [System.IO.BinaryWriter]::new([System.IO.File]::Create($path))
  try {
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int](36 + $pcm.Length))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $bw.Write([int]16)         # fmt チャンクサイズ
    $bw.Write([int16]1)        # PCM
    $bw.Write([int16]1)        # mono
    $bw.Write([int]16000)      # サンプルレート
    $bw.Write([int]32000)      # バイトレート
    $bw.Write([int16]2)        # ブロックアライン
    $bw.Write([int16]16)       # ビット深度
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int]$pcm.Length)
    $bw.Write($pcm)
  } finally {
    $bw.Dispose()
  }
}

$FrameMs = 100
$MinVoicedMs = 250   # 発話がこれ未満のチャンクはノイズとみなして捨てる (Whisper の無音幻聴対策も兼ねる)

# VAD しきい値の自動決定 (issue #233)。マイクの入力ボリュームは環境ごとにまちまちで、
# 固定値だと音量の小さいマイクで発話が「声あり」と判定されず、チャンクごと捨てられていた。
# 録音開始直後の環境音を実測し、そのノイズフロアの $NoiseMultiplier 倍をしきい値にする
$CalibrateFrames = 6    # ノイズフロアの計測に使うフレーム数 (x $FrameMs = 600ms)。計測中は $MinThreshold で判定する (取りこぼし防止)
$NoiseMultiplier = 2.0
$MinThreshold = 120     # 静かすぎる環境でしきい値が 0 付近に張り付くのを防ぐ下限
# 上限は旧来の固定値。自動決定は「小さい声も拾えるよう緩める」ためのものなので、
# 環境ノイズが大きくても旧来より厳しくはしない (厳しくすると声を一切拾わなくなる)
$MaxThreshold = 300
# 送信前の音量正規化。小さいまま投げると Whisper 側の認識精度も落ちる
$NormalizePeak = 22000     # 目標ピーク (16bit フルスケール 32767 の約 67%)
$NormalizeMaxGain = 8.0
$LevelFile = Join-Path $env:TEMP 'wezterm-voice-level.txt'   # 実測 RMS。オーバーレイの波形が読む

# 辞書の読み込み。置換ルール (順序保持) と用語ヒントに分ける。
# Groq/Whisper にはクラウド側の辞書機能が無いため、
# 「用語ヒント (prompt) で認識を寄せる + 取りこぼしはローカル置換で直す」の二段構え
$script:dictReplace = @()   # @(誤, 正) の配列
$script:glossary = ''       # prompt に渡す用語リスト (「、」区切り)
if (Test-Path -LiteralPath $DictionaryFile) {
  $terms = [System.Collections.Generic.List[string]]::new()
  foreach ($line in Get-Content -LiteralPath $DictionaryFile -Encoding utf8) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    if ($line -match '^(.+?)[=＝](.+)$') {
      $wrong = $Matches[1].Trim()
      $right = $Matches[2].Trim()
      $script:dictReplace += , @($wrong, $right)
      if (-not $terms.Contains($right)) { $terms.Add($right) }
    } elseif (-not $terms.Contains($line)) {
      $terms.Add($line)
    }
  }
  $script:glossary = $terms -join '、'
}

# フレームのリストを 1 本の PCM バイト列に結合する
function Join-Frames($frames) {
  $total = 0
  foreach ($f in $frames) { $total += $f.Length }
  $pcm = [byte[]]::new($total)
  $pos = 0
  foreach ($f in $frames) { [System.Array]::Copy($f, 0, $pcm, $pos, $f.Length); $pos += $f.Length }
  return $pcm
}
$script:allText = ''  # send-text 失敗時のクリップボード退避と、Groq への文脈ヒント (prompt) 用
$script:apiFails = 0  # Groq API の連続失敗回数。単発の失敗で録音セッションを殺さないため
$script:lastChunkText = ''  # 直前チャンクのテキスト。プロンプト反響 (同文の繰り返し幻聴) の検出用

# ほぼ無音・雑音だけのチャンクで Whisper が出す定型幻聴 (学習データの YouTube 字幕由来)。
# この文脈で本物の入力として現れることはまず無いので、含むセグメントは丸ごと捨てる
$HallucinationPatterns = @(
  'ご視聴ありがとうございました'
  'ご清聴ありがとうございました'
  'チャンネル登録'
)

# チャンクを Groq で文字起こしして送り先ペインへ入力する。失敗は throw (呼び元の catch で通知)
function Send-Chunk([byte[]]$pcm, [int]$chunkNo) {
  $wav = Join-Path $env:TEMP ("wezterm-voice-chunk{0}.wav" -f $chunkNo)
  try {
    $gain = [Voice.Recorder]::Normalize($pcm, $NormalizePeak, $NormalizeMaxGain)
    if ($gain -gt 1.0) { Write-Log ("chunk{0}: 音量を {1:n1} 倍に正規化" -f $chunkNo, $gain) }
    Write-Wav $wav $pcm
    $form = @{
      model           = $Model
      file            = Get-Item -LiteralPath $wav
      temperature     = '0'
      # verbose_json はセグメントごとの no_speech_prob / compression_ratio を返すので、
      # 雑音チャンクの幻聴 (issue #229) をローカルで足切りできる
      response_format = 'verbose_json'
    }
    if ($Language) { $form.language = $Language }
    # prompt = 辞書の用語ヒント + 直前までの文字起こし (文脈)。
    # 用語ヒントで固有名詞の表記が寄り、文脈でフレーズ間の文体が繋がる
    $hint = ''
    if ($script:glossary) { $hint = $script:glossary + '。' }
    if ($script:allText) {
      $tail = $script:allText
      if ($tail.Length -gt 200) { $tail = $tail.Substring($tail.Length - 200) }
      $hint += $tail
    }
    if ($hint) { $form.prompt = $hint }
    try {
      $resp = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/audio/transcriptions' `
        -Method Post -Headers @{ Authorization = "Bearer $env:GROQ_API_KEY" } -Form $form
    } catch {
      # 一時的な失敗 (レート制限・ネットワーク断) でセッション全体を殺すと、
      # 灰色アイコンだけ残って「反応しなくなった」ように見える。
      # このチャンクは諦めて録音は続行し、連続 3 回失敗したときだけ終了する
      $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
      $script:apiFails++
      Write-Log "Groq API 失敗 ($($script:apiFails) 回連続): $detail"
      if ($script:apiFails -ge 3) { throw "Groq API が連続で失敗: $detail" }
      if ($script:apiFails -eq 1) { Show-Toast "文字起こしに失敗した (録音は継続中): $detail" }
      return
    }
    $script:apiFails = 0
    # 幻聴の足切り (issue #229)。セグメント単位で
    #   - no_speech_prob 高 = 声ではない (打鍵音・環境音) → 捨てる
    #   - compression_ratio 高 = 同語反復ループ (「おわり おわり おわり…」) → 捨てる
    #   - 定型幻聴パターンを含む → 捨てる
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($seg in @($resp.segments)) {
      $segText = ([string]$seg.text).Trim()
      if (-not $segText) { continue }
      if ([double]$seg.no_speech_prob -gt 0.5) {
        Write-Log ("chunk{0}: no_speech_prob={1:n2} で破棄: {2}" -f $chunkNo, [double]$seg.no_speech_prob, $segText)
        continue
      }
      if ([double]$seg.compression_ratio -gt 2.4) {
        Write-Log ("chunk{0}: compression_ratio={1:n2} (反復ループ) で破棄: {2}" -f $chunkNo, [double]$seg.compression_ratio, $segText)
        continue
      }
      $isHallucination = $false
      foreach ($p in $HallucinationPatterns) {
        if ($segText.Contains($p)) { $isHallucination = $true; break }
      }
      if ($isHallucination) {
        Write-Log "chunk${chunkNo}: 幻聴パターンで破棄: $segText"
        continue
      }
      $parts.Add($segText)
    }
    $text = ($parts -join ' ').Trim()
    # 辞書の置換ルールを適用 (用語ヒントで寄せきれなかった誤変換を確実に直す)
    foreach ($pair in $script:dictReplace) {
      $text = $text.Replace($pair[0], $pair[1])
    }
    Write-Log ("chunk{0} ({1:n1}s): {2}" -f $chunkNo, ($pcm.Length / 32000.0), $text)
    if (-not $text) { return }
    # prompt (直前の文字起こし) の反響: 雑音チャンクが直前の発話をそのまま繰り返す幻聴。
    # 短文 (「はい」等) は本当に連呼することがあるので、10 文字以上の完全一致だけ捨てる
    if ($text.Length -ge 10 -and $text -eq $script:lastChunkText) {
      Write-Log "chunk${chunkNo}: 直前チャンクと同一のため破棄 (プロンプト反響)"
      return
    }
    $script:lastChunkText = $text
    $script:allText += $text + ' '
    # 続けて文章を打てるよう末尾へスペースを 1 つ足す (LEADER+v のパス貼り付けと同じ流儀)
    & $WezTermExe cli send-text --pane-id $PaneId -- ($text + ' ')
    if ($LASTEXITCODE -ne 0) {
      Set-Clipboard -Value $script:allText
      throw "ペインへの入力に失敗 (pane=$PaneId)。ここまでの全文をクリップボードに退避した (Ctrl+Shift+V で貼り付け)"
    }
  } finally {
    Remove-Item -LiteralPath $wav -Force -ErrorAction SilentlyContinue
  }
}

# セッション終了後、今回の文字起こし全文と現在の辞書を Groq の LLM に見せて
# 「誤変換らしき表記 → 正しい表記」の辞書候補を自動提案させる。
# 提案はコメント状態 (# 誤=正) で voice-dictionary.txt に追記してコミットするので、
# 行頭の「# 」を外して採用するまでは置換に使われない (誤提案が入力を壊さない)。
function Invoke-DictionarySuggestion {
  if (-not $SuggestModel) { return }
  if ($script:allText.Length -lt 40) { return }   # 材料が少なすぎるセッションはスキップ
  $repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  # 最新の辞書に対して提案するため先に pull (rebase.autostash 設定済み。失敗しても続行)
  git -C $repo pull --quiet 2>&1 | Out-Null
  $dict = Get-Content -LiteralPath $DictionaryFile -Encoding utf8 -Raw
  $transcript = $script:allText
  if ($transcript.Length -gt 4000) { $transcript = $transcript.Substring($transcript.Length - 4000) }

  $sys = @'
あなたは音声入力システムの辞書メンテナ。文字起こしテキストから、技術用語・固有名詞・サービス名の誤変換と思われる箇所を見つけ、置換ルールを提案する。
出力は JSON のみ: {"suggestions":[{"wrong":"誤変換の表記","right":"正しい表記"}]}
- 確信が高いものだけ、最大 5 件
- 既に辞書に載っている組や、一般的な日本語の言い回しは提案しない
- wrong は文字起こしに実際に出てきた表記そのままにする
- 該当が無ければ {"suggestions":[]}
'@
  $body = @{
    model           = $SuggestModel
    temperature     = 0
    response_format = @{ type = 'json_object' }
    messages        = @(
      @{ role = 'system'; content = $sys }
      @{ role = 'user'; content = "## 現在の辞書`n$dict`n## 今回の文字起こし`n$transcript" }
    )
  } | ConvertTo-Json -Depth 5
  $resp = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/chat/completions' -Method Post `
    -Headers @{ Authorization = "Bearer $env:GROQ_API_KEY" } `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

  $parsed = $resp.choices[0].message.content | ConvertFrom-Json
  $news = @()
  foreach ($s in @($parsed.suggestions)) {
    $wrong = ([string]$s.wrong).Trim()
    $right = ([string]$s.right).Trim()
    if (-not $wrong -or -not $right -or $wrong -eq $right) { continue }
    # 採用済み・提案済み (コメント行含む) の組は再提案しない
    if ($dict.Contains("$wrong=") -or $dict.Contains("$wrong＝")) { continue }
    $news += "# $wrong=$right"
  }
  if (-not $news) {
    Write-Log 'dictionary suggestion: 候補なし'
    return
  }
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
  Add-Content -LiteralPath $DictionaryFile -Encoding utf8 -Value (
    @('', "# --- 自動提案 $stamp (採用するなら行頭の「# 」を外す。不要なら行ごと削除) ---") + $news
  )
  # 両クローンで辞書がズレないよう、この 1 ファイルだけコミット (post-commit フックが push)
  git -C $repo commit -m "add: 音声入力辞書の自動提案 $($news.Count) 件 (コメント状態)" -- windows/voice-dictionary.txt 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Log 'dictionary suggestion: git commit 失敗 (ローカルには追記済み)' }
  Write-Log ('dictionary suggestion: ' + ($news -join ' / '))
  Show-Toast ("辞書候補 {0} 件を voice-dictionary.txt に追記した (コメント状態。採用は # を外す)" -f $news.Count)
}

# devbox 側の Claude Code からも誤変換の傾向を分析・辞書化できるよう、
# 文字起こし全文を devbox の ~/.cache/voice-transcripts.log にミラーする
function Send-TranscriptMirror {
  $sshExe = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe'
  "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $script:allText |
    & $sshExe -o BatchMode=yes -o ConnectTimeout=5 devbox 'mkdir -p ~/.cache && cat >> ~/.cache/voice-transcripts.log'
}

$recorder = $null
try {
  $recorder = [Voice.Recorder]::new()
  # フレーム 100ms × 300 本 = 30 秒分の取りこぼし余裕 (Groq への POST 中も録音は途切れない)
  $recorder.Start($FrameMs, 300)

  # 右ステータスのマイクアイコン用フラグ。ファイルの存在 = 録音中、
  # 中身 (1/0) = 声を拾っているか。.wezterm.lua が読んで色を変える
  Set-Content -LiteralPath $RecordingFlag -Value '0' -NoNewline
  Write-Log ("recording started (pane={0}, threshold={1})" -f $PaneId,
    $(if ($SilenceThreshold -gt 0) { "$SilenceThreshold (固定)" } else { '環境音から自動決定' }))

  # 画面中央の波形フローティング表示 (既定オフ。表示が煩わしいとの評でアイコンのみ運用に)。
  # 録音フラグが消えると自動で閉じる
  if ($Overlay) {
    try {
      Start-Process -FilePath 'pwsh.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'voice-overlay.ps1')
      )
    } catch {
      Write-Log "overlay 起動失敗: $_"
    }
  }

  # VAD 状態機械: 無音の間は preRoll (直近 300ms) だけ保持し、声が出たら preRoll ごと
  # チャンクに積み始める。$SilenceMs の無音が続いたらチャンクを閉じて変換に回す
  $chunk = [System.Collections.Generic.List[byte[]]]::new()
  $preRoll = [System.Collections.Generic.List[byte[]]]::new()
  $voicedMs = 0; $trailingMs = 0; $chunkMs = 0
  $chunkNo = 0; $sawVoice = $false
  $speaking = $false   # マイクアイコンの色用。状態が変わったときだけフラグに書く
  # しきい値は計測が終わるまで暫定値 ($MinThreshold)。明示的に値を渡されたら計測しない
  $threshold = if ($SilenceThreshold -gt 0) { $SilenceThreshold } else { $MinThreshold }
  $calibrating = ($SilenceThreshold -le 0)
  $calibRms = [System.Collections.Generic.List[double]]::new()
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $stopping = $false

  while (-not $stopping) {
    if ((Test-Path -LiteralPath $StopFlag) -or ($sw.Elapsed.TotalSeconds -ge $MaxSeconds)) {
      $stopping = $true
    }
    while ($true) {
      $frame = $recorder.Poll()
      if ($null -eq $frame -or $frame.Length -eq 0) { break }
      $rms = [Voice.Recorder]::Rms($frame)
      if ($Overlay) {
        try { [System.IO.File]::WriteAllText($LevelFile, [string][int]$rms) } catch {}
      }
      if ($calibrating) {
        $calibRms.Add($rms)
        if ($calibRms.Count -ge $CalibrateFrames) {
          # いきなり話し始めると平均が跳ねるので、下位 25% 分位をノイズフロアとみなす
          $sorted = $calibRms.ToArray()
          [Array]::Sort($sorted)
          $floor = $sorted[[int][math]::Floor(($sorted.Count - 1) * 0.25)]
          $threshold = [int][math]::Min([double]$MaxThreshold, [math]::Max([double]$MinThreshold, $floor * $NoiseMultiplier))
          Write-Log ("ノイズフロア={0:n0} (計測 {1} フレームの最大={2:n0}) → 無音しきい値={3}" -f `
            $floor, $sorted.Count, $sorted[$sorted.Count - 1], $threshold)
          $calibrating = $false
          $calibRms.Clear()
        }
      }
      $voiced = $rms -ge $threshold
      if ($voiced -ne $speaking) {
        $speaking = $voiced
        try { [System.IO.File]::WriteAllText($RecordingFlag, $(if ($voiced) { '1' } else { '0' })) } catch {}
      }
      if ($chunk.Count -eq 0) {
        if ($voiced) {
          $sawVoice = $true
          $chunk.AddRange($preRoll)
          $preRoll.Clear()
          $chunk.Add($frame)
          $chunkMs = $chunk.Count * $FrameMs
          $voicedMs = $FrameMs; $trailingMs = 0
        } else {
          $preRoll.Add($frame)
          while ($preRoll.Count -gt 3) { $preRoll.RemoveAt(0) }
        }
        continue
      }
      $chunk.Add($frame)
      $chunkMs += $FrameMs
      if ($voiced) { $voicedMs += $FrameMs; $trailingMs = 0 } else { $trailingMs += $FrameMs }
      if ($trailingMs -ge $SilenceMs -or $chunkMs -ge $MaxChunkSeconds * 1000) {
        $pcm = Join-Frames $chunk
        $chunk.Clear()
        if ($voicedMs -ge $MinVoicedMs) {
          $chunkNo++
          Send-Chunk $pcm $chunkNo
        }
        $voicedMs = 0; $trailingMs = 0; $chunkMs = 0
      }
    }
    if (-not $stopping) { Start-Sleep -Milliseconds 30 }
  }

  # 停止時に言いかけのフレーズが残っていれば最後に変換する
  if ($chunk.Count -gt 0 -and $voicedMs -ge $MinVoicedMs) {
    $chunkNo++
    Send-Chunk (Join-Frames $chunk) $chunkNo
  }

  # 録音はここで終わり。オーバーレイ・右ステータスの「録音中」を先に消してから
  # 後処理 (ミラー・辞書提案) に進む。フラグ削除でオーバーレイは自動で閉じる
  $recorder.Dispose()
  $recorder = $null
  Remove-Item -LiteralPath $StopFlag, $RecordingFlag, $LevelFile -Force -ErrorAction SilentlyContinue

  if (-not $sawVoice) {
    Show-Toast "音声を検出しなかった。マイクが小さすぎるなら voice-input.ps1 の -SilenceThreshold ($SilenceThreshold) を下げる"
  }
  Write-Log "recording finished (chunks=$chunkNo)"

  if ($chunkNo -gt 0) {
    # 後処理はどちらも失敗しても本体機能 (入力) に影響させない
    try { Send-TranscriptMirror } catch { Write-Log "transcript mirror failed: $_" }
    try { Invoke-DictionarySuggestion } catch { Write-Log "dictionary suggestion failed: $_" }
  }
}
catch {
  Write-Log "error: $_"
  Show-Toast "音声入力エラー: $_"
  exit 1
}
finally {
  if ($recorder) { $recorder.Dispose() }
  # RecordingFlag を消すとオーバーレイも自動で閉じる
  Remove-Item -LiteralPath $StopFlag, $RecordingFlag, $LevelFile -Force -ErrorAction SilentlyContinue
  # PID ファイルは自分のものだったときだけ消す (新インスタンスが上書き済みなら触らない)
  if ((Get-Content -LiteralPath $PidFile -ErrorAction SilentlyContinue) -eq "$PID") {
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
  }
}
