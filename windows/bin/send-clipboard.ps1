# send-clipboard.ps1 -- Windows のクリップボードの内容 (画像 / ファイル / フォルダ /
# フルパス文字列) を devbox へ転送する。WezTerm の LEADER+v (paste_image_or_clipboard)
# から呼ばれ、tmux 内の Claude Code プロンプトへ「リモートパスの入力」という形で
# 貼り付ける経路を作る。クリップボードの中身そのものは SSH を越えられないため、
# 「ローカル実体 -> scp -> リモートパスを stdout に返す」で代替する。
#
# 判定順:
#   1) ビットマップ画像 (Win+Shift+S 等)     -> PNG 保存して転送
#   2) ファイル/フォルダのコピー (Explorer)   -> そのまま転送 (フォルダは scp -r)
#   3) 実在するローカルパスのテキスト         -> そのファイル/フォルダを転送
#      (Explorer「パスのコピー」の引用符付き・複数行にも対応)
#
# stdout プロトコル (1 行):
#   <リモートパス> [<リモートパス>...] : 転送成功 (複数はスペース区切り)
#   NOCONTENT                          : 転送対象なし (呼び出し側はテキストペーストへ)
# 失敗時: exit 1 + stderr にメッセージ。
param(
  [string]$RemoteHost = 'devbox',
  [string]$RemoteDir  = '.cache/clipboard',  # リモートホームからの相対パス
  [string]$RemoteHome = '/home/azureuser',
  [int]$MaxTotalMB    = 100                  # うっかり巨大フォルダを送って GUI が長時間固まるのを防ぐ
)

$ErrorActionPreference = 'Stop'

# WezTerm (run_child_process) は stdout/stderr を UTF-8 として読むが、pwsh の既定は
# OEM コードページ (日本語環境では CP932)。日本語ファイル名入りのパスが化けて
# SendString が空振りするため、明示的に UTF-8 で出力する
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$rand = [IO.Path]::GetRandomFileName().Substring(0, 4)

# プロンプトに貼ってもパスが壊れないよう、空白や記号を _ に潰す (日本語は \w なので残る)
function Get-SafeName([string]$name) {
  return ($name -replace '[^\w.\-]', '_')
}

function Get-SizeBytes([string]$path) {
  if (Test-Path -LiteralPath $path -PathType Container) {
    $sum = (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum).Sum
    return [long]($sum ?? 0)
  }
  return (Get-Item -LiteralPath $path).Length
}

# 転送対象を { Local, RemoteName } のリストに集める
$sources = @()
$paths = $null
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
  $img = [System.Windows.Forms.Clipboard]::GetImage()
  if ($img) {
    $tmpDir = Join-Path $env:TEMP 'clip-images'
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $name = "clip-$stamp-$rand.png"
    $png = Join-Path $tmpDir $name
    $img.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $img.Dispose()
    $sources += @{ Local = $png; RemoteName = $name }
  }
}
elseif ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
  $paths = @([System.Windows.Forms.Clipboard]::GetFileDropList())
}
elseif ([System.Windows.Forms.Clipboard]::ContainsText()) {
  # 「パスのコピー」形式を想定し、実在するフルパスの行だけ拾う
  $paths = @([System.Windows.Forms.Clipboard]::GetText() -split "`r?`n" | ForEach-Object {
    $_.Trim().Trim('"')
  } | Where-Object { $_ -match '^[A-Za-z]:[\\/]' -and (Test-Path -LiteralPath $_) })
}

if ($paths) {
  $i = 0
  foreach ($p in $paths) {
    # 複数転送時はインデックスで名前の衝突を避ける。元のファイル名は末尾に残す
    $suffix = if (@($paths).Count -gt 1) { "-$i" } else { '' }
    $leaf = Split-Path $p -Leaf
    $sources += @{ Local = $p; RemoteName = "clip-$stamp-$rand$suffix-" + (Get-SafeName $leaf) }
    $i++
  }
}

if (-not $sources) { Write-Output 'NOCONTENT'; exit 0 }

$totalMB = [math]::Round((($sources | ForEach-Object { Get-SizeBytes $_.Local }) | Measure-Object -Sum).Sum / 1MB, 1)
if ($totalMB -gt $MaxTotalMB) {
  [Console]::Error.WriteLine("合計 ${totalMB}MB は上限 ${MaxTotalMB}MB を超えるため中止 (必要なら -MaxTotalMB で緩和)")
  exit 1
}

# ssh/scp は WezTerm 側 (jump_to_notified_pane) と同じく System32 の OpenSSH を使う
$sshDir = Join-Path $env:SystemRoot 'System32\OpenSSH'
$sshOpts = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5')

# 転送先ディレクトリの用意 + 2 週間より古い転送済みエントリの掃除
& (Join-Path $sshDir 'ssh.exe') @sshOpts $RemoteHost "mkdir -p ~/$RemoteDir && find ~/$RemoteDir -mindepth 1 -mtime +14 -delete"
if ($LASTEXITCODE -ne 0) {
  [Console]::Error.WriteLine("ssh $RemoteHost に失敗 (VM 停止中? devbox.ps1 ensure を確認)")
  exit 1
}

foreach ($s in $sources) {
  $scpArgs = @($sshOpts)
  if (Test-Path -LiteralPath $s.Local -PathType Container) { $scpArgs += '-r' }
  & (Join-Path $sshDir 'scp.exe') @scpArgs -q $s.Local "${RemoteHost}:$RemoteDir/$($s.RemoteName)"
  if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("scp での転送に失敗: $($s.Local)")
    exit 1
  }
}

Write-Output (($sources | ForEach-Object { "$RemoteHome/$RemoteDir/$($_.RemoteName)" }) -join ' ')
