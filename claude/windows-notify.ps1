[CmdletBinding()]
param(
    [string]$Title = "Notification",
    [string]$Message = "",
    [string]$MessageFile,
    [ValidateSet("Default","IM","Mail","Reminder","Alarm","SMS","LoopingAlarm","LoopingAlarm2","LoopingCall","Silent")]
    [string]$Sound = "Reminder",
    [switch]$IncludeWorkingDirectory,
    # クリック時にプロトコル起動する URI（例: wezterm-jump:12/5）。
    # 指定すると通知元ペインへのジャンプ付きトーストになる（.wezterm.lua から使用）
    [string]$LaunchUri
)

# smart-commit.ps1実行中はすべての通知をスキップ
if ($env:SMART_COMMIT_RUNNING -eq "true") {
    exit 0
}

try {
    Import-Module BurntToast -ErrorAction Stop
}
catch {
    Write-Error "BurntToast not found. Install with: Install-Module BurntToast -Scope CurrentUser"
    exit 1
}

if ($MessageFile) {
    if (-not (Test-Path -LiteralPath $MessageFile)) {
        Write-Error "MessageFile not found: $MessageFile"
        exit 1
    }
    $Message = Get-Content -LiteralPath $MessageFile -Raw
}
elseif (-not $PSBoundParameters.ContainsKey('Message')) {
    if ([Console]::IsInputRedirected) {
        $Message = [Console]::In.ReadToEnd()
    }
}

# 作業ディレクトリのフォルダ名をタイトルに追加
if ($IncludeWorkingDirectory) {
    $currentDir = Split-Path -Leaf (Get-Location)
    $Title = "[$currentDir] $Title"
}

if ($LaunchUri) {
    # トースト本体のクリックで LaunchUri をプロトコル起動する
    $children = @(New-BTText -Content $Title)
    if ($Message) { $children += New-BTText -Content $Message }
    $binding = New-BTBinding -Children $children
    $visual = New-BTVisual -BindingGeneric $binding
    $soundMap = @{ Default = "Notification.Default"; IM = "Notification.IM"; Mail = "Notification.Mail"; Reminder = "Notification.Reminder"; SMS = "Notification.SMS" }
    $audio = if ($Sound -eq "Silent") { New-BTAudio -Silent }
             elseif ($soundMap[$Sound]) { New-BTAudio -Source "ms-winsoundevent:$($soundMap[$Sound])" }
             else { New-BTAudio -Source "ms-winsoundevent:Notification.Default" }
    $content = New-BTContent -Visual $visual -Audio $audio -Launch $LaunchUri -ActivationType Protocol
    Submit-BTNotification -Content $content
    exit 0
}

New-BurntToastNotification -Text @($Title, $Message) -Sound $Sound