# Smart Tag Hook Script
# userPromptSubmitフックから呼び出されるラッパースクリプト

param(
    [string]$UserPrompt
)

# ログファイルのパス
$logFile = "$env:USERPROFILE\.claude\logs\smart-tag-hook-$(Get-Date -Format 'yyyyMMdd').log"

# デバッグログ
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"$timestamp - Hook called with prompt: $($UserPrompt.Substring(0, [Math]::Min(50, $UserPrompt.Length)))..." | Out-File -FilePath $logFile -Append

# 最後のプロンプトをファイルに保存
$promptFile = "$env:USERPROFILE\.claude\last-prompt.txt"
$UserPrompt | Set-Content $promptFile -Encoding UTF8

# smart-tagを呼び出し
if ($UserPrompt) {
    & "$env:USERPROFILE\.claude\smart-tag.ps1" -Action auto -UserPrompt $UserPrompt -Json
} else {
    # プロンプトがない場合は現在のタグを表示
    & "$env:USERPROFILE\.claude\smart-tag.ps1" -Action show -Json
}