[CmdletBinding()]
param(
    [string]$Title = "Notification",
    [string]$Message = "",
    [string]$MessageFile,
    [ValidateSet("Default","IM","Mail","Reminder","Alarm","SMS","LoopingAlarm","LoopingAlarm2","LoopingCall","Silent")]
    [string]$Sound = "Reminder",
    [switch]$IncludeWorkingDirectory
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

New-BurntToastNotification -Text @($Title, $Message) -Sound $Sound