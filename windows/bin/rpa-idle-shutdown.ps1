# アイドル判定して deallocate するスケジュールタスク。10 分ごとに呼ばれる。
#
# 「アイドルが続いたら止める」を連続回数で判定する。1 回でも稼働中と判定したら
# カウンタを 0 に戻すので、瞬間的に SSH が切れただけでは停止しない。
# IdleTicksRequired 回連続 (10 分間隔なので 6 回 = 約 60 分) でようやく deallocate する。
#
# 稼働中とみなす条件 (どれか 1 つでも該当すれば停止しない):
#   1) RDP/コンソールセッションのアイドル時間が IdleMin 分未満 (quser)
#      ※ rpa は NSG で 3389 を Deny しているため通常は成立しない
#   2) SSH の ESTABLISHED 接続がある (22番ポート)
#      ※ devbox からの接続は除外する。devbox は tmux に rpa への SSH を
#        keepalive 付きで常駐させているため (2026-08-27 b23a630)、これを
#        稼働中と数えると永久に停止しなくなる (2026-08-26〜09-09 に 14 日間
#        連続稼働した原因)
#   3) devbox からの利用ハートビートが IdleMin 分以内 (#246)。devbox の cron
#      (rpa-activity-heartbeat) が、tmux の rpa セッションに直近の操作があるとき
#      だけ heartbeat ファイルを touch する。条件 2 で devbox の SSH を除外した
#      代わりの「実作業中」シグナル。CPU だけを防波堤にすると、rpa 上の Claude
#      待機中など低負荷の作業中に停止してしまう (2026-09-14 に発生)
#   4) CPU 使用率が LoadMax を超えている
#
# 認証はマネージド ID (az login --identity) を使うためログイン切れが起きない。
#
# 注意: このファイルは必ず UTF-8 BOM 付きで保存すること。BOM が無いと
# タスクが呼ぶ Windows PowerShell 5.1 が ANSI として読み、日本語コメントが
# 化けて構文エラーになり、スクリプトが起動すらしない (2026-08-26 の事故)。
$ErrorActionPreference = 'Continue'

$IdleMin = 60
$LoadMax = 30
$IdleTicksRequired = 6
$RG = "AUTOFOR-RG"
$VM = "rpa"
# devbox の Tailscale IP。ここからの SSH は tmux の常駐接続なので稼働中と数えない
$DevboxIP = "100.126.96.27"
# devbox の rpa-activity-heartbeat が touch する「使用中」シグナル
$HeartbeatPath = "$env:ProgramData\rpa-activity.heartbeat"
$LogPath = "$env:ProgramData\rpa-idle-shutdown.log"
$StatePath = "$env:ProgramData\rpa-idle-shutdown.state"

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Add-Content -Path $LogPath -Value $line
    $lines = Get-Content $LogPath -ErrorAction SilentlyContinue
    if ($lines -and $lines.Count -gt 500) { ($lines | Select-Object -Last 500) | Set-Content $LogPath }
}

function Get-IdleTicks {
    $v = Get-Content $StatePath -ErrorAction SilentlyContinue | Select-Object -First 1
    $n = 0
    if ($v -and [int]::TryParse($v.Trim(), [ref]$n)) { return $n }
    return 0
}

function Set-IdleTicks($n) {
    Set-Content -Path $StatePath -Value ([string]$n) -ErrorAction SilentlyContinue
}

$busyReasons = @()

# 1) RDP/コンソールセッションのアイドル時間
try {
    $quserOutput = quser 2>$null
    foreach ($line in ($quserOutput | Select-Object -Skip 1)) {
        if (-not $line.Trim()) { continue }
        # IDLE TIME は STATE (Active/Disc) の直後の列として読む。切断中 (Disc) は
        # SESSIONNAME が空で列数が変わるため位置では決め打ちできない。
        # 「最初に数字に見える列」を拾うとセッション ID を分と誤読し、セッションが
        # 残っている限り永久に停止しなくなる (#248、2026-09-16〜19 に 3 日間連続稼働)
        $idleMinutes = $null
        if ($line -match '\s(?:Active|Disc)\s+(\S+)') {
            $idleRaw = $matches[1]
            # 形式: "." / "none" (操作直後), "N" (分), "H:MM", "D+HH:MM"
            if ($idleRaw -match '^(\d+)\+(\d{1,2}):(\d{2})$') {
                $idleMinutes = ([int]$matches[1] * 24 * 60) + ([int]$matches[2] * 60) + [int]$matches[3]
            } elseif ($idleRaw -match '^(\d{1,2}):(\d{2})$') {
                $idleMinutes = ([int]$matches[1] * 60) + [int]$matches[2]
            } elseif ($idleRaw -match '^\d+$') {
                $idleMinutes = [int]$idleRaw
            } elseif ($idleRaw -match '^(\.|none)$') {
                $idleMinutes = 0
            }
        }
        if ($null -eq $idleMinutes) {
            # 読めないときは安全側 (停止しない) に倒すが、黙って居座らないよう理由に出す
            $busyReasons += "quser の行を解析できない: $($line.Trim())"
        } elseif ($idleMinutes -lt $IdleMin) {
            $busyReasons += "RDPセッションのアイドルが${idleMinutes}分 (< ${IdleMin}分)"
        }
    }
} catch {
    Write-Log "quser 確認失敗: $_"
}

# 2) SSH の ESTABLISHED 接続 (devbox の tmux 常駐 SSH は除外)
try {
    $allConns = @(Get-NetTCPConnection -LocalPort 22 -State Established -ErrorAction SilentlyContinue)
    $sshConns = @($allConns | Where-Object { $_.RemoteAddress -ne $DevboxIP })
    $excluded = $allConns.Count - $sshConns.Count
    if ($sshConns.Count -gt 0) {
        $msg = "SSH接続が$($sshConns.Count)件確立中"
        if ($excluded -gt 0) { $msg += " (devbox 常駐 ${excluded}件は除外済み)" }
        $busyReasons += $msg
    } elseif ($excluded -gt 0) {
        Write-Log "devbox 常駐 SSH ${excluded}件のみ -> 稼働中とみなさない"
    }
} catch {
    Write-Log "SSH接続確認失敗: $_"
}

# 3) devbox からの利用ハートビート (#246)
try {
    $hb = Get-Item $HeartbeatPath -ErrorAction SilentlyContinue
    if ($hb) {
        $ageMin = ((Get-Date) - $hb.LastWriteTime).TotalMinutes
        if ($ageMin -lt $IdleMin) {
            $busyReasons += "devbox からの利用ハートビートが $([math]::Round($ageMin)) 分前 (< ${IdleMin}分)"
        }
    }
} catch {
    Write-Log "ハートビート確認失敗: $_"
}

# 4) CPU 負荷
try {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3 -ErrorAction Stop).CounterSamples |
        Measure-Object -Property CookedValue -Average | Select-Object -ExpandProperty Average
    if ($cpu -gt $LoadMax) {
        $busyReasons += "CPU使用率 $([math]::Round($cpu,1))% (> ${LoadMax}%)"
    }
} catch {
    Write-Log "CPU確認失敗: $_"
    $cpu = -1
}

if ($busyReasons.Count -gt 0) {
    Set-IdleTicks 0
    Write-Log "稼働中: $($busyReasons -join ' / ')"
    exit 0
}

$ticks = (Get-IdleTicks) + 1
Set-IdleTicks $ticks

if ($ticks -lt $IdleTicksRequired) {
    Write-Log "アイドル $ticks/$IdleTicksRequired 回目 (RDP/SSHなし, CPU $([math]::Round($cpu,1))%) -> まだ停止しない"
    exit 0
}

Write-Log "アイドルが $ticks 回連続 (約 $($ticks * 10) 分) -> deallocate 実行"
try {
    & az login --identity --allow-no-subscriptions -o none 2>>$LogPath
    & az vm deallocate -g $RG -n $VM --no-wait -o none 2>>$LogPath
    Set-IdleTicks 0
    Write-Log "deallocate 要求を送信"
} catch {
    Write-Log "deallocate 失敗: $_"
}
