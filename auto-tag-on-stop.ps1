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

# 固定ファイル名でプロンプトファイルを特定
$promptDir = "$PSScriptRoot\prompts"
$PromptFile = "$promptDir\latest_prompt.txt"

Write-Log "プロンプトファイル: $PromptFile"

# プロンプトファイルを読み込み
Write-Log "---------- プロンプトファイル確認 ----------"
if (Test-Path $PromptFile) {
    Write-Log "プロンプトファイルが存在します"
    $prompt = Get-Content -Path $PromptFile -Raw -ErrorAction SilentlyContinue
    
    if ($prompt) {
        Write-Log "プロンプト内容を読み込みました (長さ: $($prompt.Length) 文字)"
        Write-Log "プロンプトの最初の50文字: $($prompt.Substring(0, [Math]::Min(50, $prompt.Length)))..."
        # プロンプトを要約（最初の50文字程度）
        Write-Log "---------- プロンプト要約処理 ----------"
        $summary = $prompt -replace '\r?\n', ' ' # 改行を空白に
        $summary = $summary -replace '\s+', ' '  # 連続する空白を単一に
        $summary = $summary.Trim()
        Write-Log "要約前の長さ: $($prompt.Length) 文字"
        Write-Log "要約後の長さ: $($summary.Length) 文字"
        
        # 50文字で切る
        if ($summary.Length -gt 50) {
            $summary = $summary.Substring(0, 47) + "..."
            Write-Log "要約を50文字に切り詰めました"
        }
        Write-Log "最終要約: $summary"
        
        # タグ名を生成（日時_要約の最初の20文字）
        Write-Log "---------- タグ名生成 ----------"
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $tagSummary = $summary -replace '[^\w\s-]', '' # 特殊文字を除去
        $tagSummary = $tagSummary -replace '\s+', '-'  # 空白をハイフンに
        Write-Log "特殊文字除去後: $tagSummary"
        
        if ($tagSummary.Length -gt 20) {
            $tagSummary = $tagSummary.Substring(0, 20)
            Write-Log "タグ要約を20文字に切り詰めました"
        }
        
        $tagName = "auto-$timestamp-$tagSummary"
        Write-Log "生成されたタグ名: $tagName"
        
        # Gitタグを作成
        Write-Log "---------- Gitタグ作成 ----------"
        try {
            # 現在のコミットハッシュを取得
            $currentCommit = git rev-parse HEAD 2>&1
            Write-Log "現在のコミット: $currentCommit"
            
            # 現在のコミットにタグを付ける
            Write-Log "実行コマンド: git tag -a $tagName -m 'Auto-tag: $summary'"
            $gitOutput = git tag -a $tagName -m "Auto-tag: $summary" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "${GREEN}✅ Git tag created: $tagName${RESET}"
                Write-Log "タグ作成成功: $tagName"
                
                # タグ履歴を別ファイルに記録
                $tagLogDir = "$PSScriptRoot\tags\logs"
                if (-not (Test-Path $tagLogDir)) {
                    New-Item -ItemType Directory -Path $tagLogDir -Force | Out-Null
                }
                
                $tagHistoryFile = Join-Path $tagLogDir "auto-tags.log"
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tag: $tagName | Commit: $currentCommit | Prompt: $summary"
                Add-Content -Path $tagHistoryFile -Value $logEntry -Encoding UTF8
                Write-Log "タグ履歴を記録しました: $tagHistoryFile"
            } else {
                Write-Host "${YELLOW}⚠ Failed to create tag: $gitOutput${RESET}"
                Write-Log "エラー: タグ作成失敗 (終了コード: $LASTEXITCODE)"
                Write-Log "Git出力: $gitOutput"
            }
        } catch {
            Write-Host "${RED}❌ Error creating tag: $_${RESET}"
            Write-Log "例外エラー: タグ作成中にエラーが発生しました"
            Write-Log "エラー詳細: $_"
        }
        
        # 処理後、プロンプトファイルを削除（次回の混乱を防ぐ）
        Write-Log "---------- クリーンアップ処理 ----------"
        Remove-Item -Path $PromptFile -Force -ErrorAction SilentlyContinue
        Write-Log "プロンプトファイルを削除しました: $PromptFile"
        
        # 古いプロンプトファイルをクリーンアップ
        Write-Log "古いプロンプトファイルのクリーンアップを実行中..."
        & "$PSScriptRoot\cleanup-prompts.ps1" -KeepDays 1 -KeepFiles 10
        Write-Log "クリーンアップ完了"
    } else {
        Write-Log "警告: プロンプトファイルが空です"
    }
} else {
    Write-Log "情報: プロンプトファイルが存在しません: $PromptFile"
}

Write-Log "---------- サマリー ----------"
if ($tagName) {
    Write-Log "タグ作成: 成功"
    Write-Log "タグ名: $tagName"
    Write-Log "タグメッセージ: Auto-tag: $summary"
} else {
    Write-Log "タグ作成: スキップ（プロンプトなし）"
}
Write-Log "---------- オートタグ正常完了 ----------"
Write-Log ""

exit 0