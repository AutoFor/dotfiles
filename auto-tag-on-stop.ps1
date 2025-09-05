# auto-tag-on-stop.ps1
# Stopフック時にプロンプトを読み込んでGitタグを生成

# カラー定義
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$CYAN = "`e[36m"
$MAGENTA = "`e[35m"
$RESET = "`e[0m"

# ログファイルの設定
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "auto-tag-$(Get-Date -Format 'yyyyMMdd').log"

# ログ出力関数
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# セッション開始ログ
Write-Log "#################################################"
Write-Log "                  オートタグ開始"
Write-Log "#################################################"
Write-Log "作業ディレクトリ: $PSScriptRoot"

# プロセスIDベースでプロンプトファイルを特定
$promptDir = "$PSScriptRoot\prompts"
$pid = $PID
$PromptFile = "$promptDir\prompt_$pid.txt"

Write-Log "プロセスID: $pid"
Write-Log "プロンプトファイル: $PromptFile"

# プロンプトファイルを読み込み
if (Test-Path $PromptFile) {
    $prompt = Get-Content -Path $PromptFile -Raw -ErrorAction SilentlyContinue
    
    if ($prompt) {
        # プロンプトを要約（最初の50文字程度）
        $summary = $prompt -replace '\r?\n', ' ' # 改行を空白に
        $summary = $summary -replace '\s+', ' '  # 連続する空白を単一に
        $summary = $summary.Trim()
        
        # 50文字で切る
        if ($summary.Length -gt 50) {
            $summary = $summary.Substring(0, 47) + "..."
        }
        
        # タグ名を生成（日時_要約の最初の20文字）
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $tagSummary = $summary -replace '[^\w\s-]', '' # 特殊文字を除去
        $tagSummary = $tagSummary -replace '\s+', '-'  # 空白をハイフンに
        
        if ($tagSummary.Length -gt 20) {
            $tagSummary = $tagSummary.Substring(0, 20)
        }
        
        $tagName = "auto-$timestamp-$tagSummary"
        
        # Gitタグを作成
        try {
            # 現在のコミットにタグを付ける
            $gitOutput = git tag -a $tagName -m "Auto-tag: $summary" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Git tag created: $tagName" -ForegroundColor Green
                
                # タグ情報をログファイルに記録
                $logDir = "$PSScriptRoot\tags\logs"
                if (-not (Test-Path $logDir)) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                }
                
                $logFile = Join-Path $logDir "auto-tags.log"
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tag: $tagName | Prompt: $summary"
                Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
            } else {
                Write-Host "Failed to create tag: $gitOutput" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Error creating tag: $_" -ForegroundColor Yellow
        }
        
        # 処理後、プロンプトファイルを削除（次回の混乱を防ぐ）
        Remove-Item -Path $PromptFile -Force -ErrorAction SilentlyContinue
        
        # 古いプロンプトファイルをクリーンアップ
        & "$PSScriptRoot\cleanup-prompts.ps1" -KeepDays 1 -KeepFiles 10
    }
}

exit 0