# ===== ntfy 購読 → Windows トースト通知 =====
# devbox の ~/.claude/notify.sh が ntfy に流した通知を受け取り、BurntToast で表示する。
# 手元の WezTerm に OSC で届かない経路（tmux 未 attach、Claude Code アプリからの
# SSH セッション等）の通知はこちらに来る。常駐させるには register-ntfy-listen.ps1。
[CmdletBinding()]
param(
    # 未指定なら %USERPROFILE%\.config\ntfy-topic から読む（devbox の ~/.config/ntfy-topic と同じ値）
    [string]$Topic,
    [string]$Server = "https://ntfy.sh",
    [ValidateSet("Default","IM","Mail","Reminder","Alarm","SMS","Silent")]
    [string]$Sound = "Reminder"
)

if (-not $Topic) {
    $topicFile = Join-Path $env:USERPROFILE ".config\ntfy-topic"
    if (Test-Path -LiteralPath $topicFile) {
        $Topic = (Get-Content -LiteralPath $topicFile -TotalCount 1).Trim()
    }
}
if (-not $Topic) {
    Write-Error "ntfy トピックが未設定。$env:USERPROFILE\.config\ntfy-topic に devbox の ~/.config/ntfy-topic と同じ値を置くか -Topic で渡す"
    exit 1
}

try {
    Import-Module BurntToast -ErrorAction Stop
}
catch {
    Write-Error "BurntToast not found. Install with: Install-Module BurntToast -Scope CurrentUser"
    exit 1
}

$client = [System.Net.Http.HttpClient]::new()
# 購読はサーバが keepalive を送り続ける長寿命ストリームなのでタイムアウトを外す
$client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan

$lastId = $null   # 再接続時に取りこぼさないための最後のメッセージ ID
$backoff = 1
$failures = 0

Write-Verbose "ntfy 購読開始: $Server/$Topic"

while ($true) {
    $resp = $null
    $reader = $null
    try {
        $url = "$Server/$Topic/json"
        if ($lastId) { $url += "?since=$lastId" }
        $resp = $client.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $resp.EnsureSuccessStatusCode() | Out-Null
        $reader = [System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
        # 接続できた時点でバックオフをリセット
        $backoff = 1
        $failures = 0

        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $ev = $line | ConvertFrom-Json } catch { continue }
            # open / keepalive は無視し、message だけトーストにする
            if ($ev.event -ne "message") { continue }
            $lastId = $ev.id

            $title = if ($ev.title) { $ev.title } else { "Claude Code" }
            $text = if ($ev.message) { @($title, $ev.message) } else { @($title) }
            New-BurntToastNotification -Text $text -Sound $Sound
        }
    }
    catch {
        $failures++
        Write-Verbose "ntfy 接続が切れた ($failures 回目): $_"
        # since=<id> をサーバが受け付けない等で即失敗し続ける場合は捨てて最初からやり直す
        if ($failures -ge 3) { $lastId = $null }
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($resp) { $resp.Dispose() }
    }

    # ネットワーク断・スリープ復帰に備えて指数バックオフで再接続（最大 60 秒）
    Start-Sleep -Seconds $backoff
    $backoff = [Math]::Min($backoff * 2, 60)
}
