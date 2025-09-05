# save-prompt.ps1
# ユーザーのプロンプトをファイルに保存するスクリプト

param(
    [string]$Prompt = "",
    [string]$OutputDir = "$PSScriptRoot\prompts"
)

# 出力ディレクトリ作成
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# タイムスタンプ付きファイル名
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$filename = Join-Path $OutputDir "prompt_$timestamp.txt"

# プロンプトをファイルに保存
if ($Prompt) {
    # プロンプトの内容を保存
    @"
=== User Prompt ===
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-------------------
$Prompt
"@ | Out-File -FilePath $filename -Encoding UTF8
    
    # 最新のプロンプトを別ファイルにも保存（常に上書き）
    $Prompt | Out-File -FilePath (Join-Path $OutputDir "latest_prompt.txt") -Encoding UTF8
    
    Write-Host "Prompt saved to: $filename" -ForegroundColor Green
}

exit 0