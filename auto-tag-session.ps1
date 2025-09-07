# auto-tag-session.ps1
# セッション中のコミット履歴から作業内容を要約してGitタグを生成

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
$logFile = Join-Path $logDir "auto-tag-session-$(Get-Date -Format 'yyyyMMdd').log"

# ログ出力関数
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# セッション開始ログ
Write-Log "#################################################"
Write-Log "           セッションタグ生成開始"
Write-Log "#################################################"
Write-Log "作業ディレクトリ: $PSScriptRoot"

# セッションコミットログを読み込み
$sessionCommitLog = Join-Path $PSScriptRoot "session-commits.jsonl"
Write-Log "セッションコミットログ: $sessionCommitLog"

if (-not (Test-Path $sessionCommitLog)) {
    Write-Log "情報: セッションコミットログが存在しません"
    Write-Log "---------- セッションタグ生成スキップ ----------"
    exit 0
}

# コミット情報を読み込み
Write-Log "---------- コミット履歴読み込み ----------"
$commits = @()
Get-Content -Path $sessionCommitLog -Encoding UTF8 | ForEach-Object {
    try {
        $commit = $_ | ConvertFrom-Json
        $commits += $commit
        Write-Log "コミット読み込み: $($commit.hash) - $($commit.title)"
    } catch {
        Write-Log "警告: JSON解析エラー - $_"
    }
}

if ($commits.Count -eq 0) {
    Write-Log "情報: コミット履歴が空です"
    Write-Log "---------- セッションタグ生成スキップ ----------"
    exit 0
}

Write-Log "読み込まれたコミット数: $($commits.Count)"

# コミット内容を分析
Write-Log "---------- コミット内容分析 ----------"
$features = @()
$fixes = @()
$refactors = @()
$docs = @()
$others = @()
$allFiles = @()

foreach ($commit in $commits) {
    # タイプ別に分類
    if ($commit.title -match '^feat:') {
        $features += $commit.title -replace '^feat:\s*', ''
    } elseif ($commit.title -match '^fix:') {
        $fixes += $commit.title -replace '^fix:\s*', ''
    } elseif ($commit.title -match '^refactor:') {
        $refactors += $commit.title -replace '^refactor:\s*', ''
    } elseif ($commit.title -match '^docs:') {
        $docs += $commit.title -replace '^docs:\s*', ''
    } else {
        $others += $commit.title
    }
    
    # ファイルリストを集計
    $allFiles += $commit.files
}

# 重複を除去したファイル数
$uniqueFiles = $allFiles | Select-Object -Unique
Write-Log "変更されたユニークファイル数: $($uniqueFiles.Count)"

# セッション要約を生成
Write-Log "---------- セッション要約生成 ----------"
$summary = @()

if ($features.Count -gt 0) {
    $summary += "Features($($features.Count))"
    Write-Log "新機能: $($features.Count)件"
}
if ($fixes.Count -gt 0) {
    $summary += "Fixes($($fixes.Count))"
    Write-Log "修正: $($fixes.Count)件"
}
if ($refactors.Count -gt 0) {
    $summary += "Refactors($($refactors.Count))"
    Write-Log "リファクタリング: $($refactors.Count)件"
}
if ($docs.Count -gt 0) {
    $summary += "Docs($($docs.Count))"
    Write-Log "ドキュメント: $($docs.Count)件"
}
if ($others.Count -gt 0) {
    $summary += "Others($($others.Count))"
    Write-Log "その他: $($others.Count)件"
}

$summaryText = $summary -join ", "
if ($summaryText.Length -eq 0) {
    $summaryText = "$($commits.Count) commits"
}

Write-Log "要約: $summaryText"

# タグ名を生成
Write-Log "---------- タグ名生成 ----------"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tagName = "session-$timestamp"
Write-Log "生成されたタグ名: $tagName"

# タグメッセージを作成
$tagMessage = @"
Session Summary: $summaryText

Commits in this session ($($commits.Count)):
$($commits | ForEach-Object { "- $($_.title)" } | Out-String)

Files modified ($($uniqueFiles.Count)):
$($uniqueFiles | Select-Object -First 10 | ForEach-Object { "- $_" } | Out-String)
$(if ($uniqueFiles.Count -gt 10) { "... and $($uniqueFiles.Count - 10) more files" } else { "" })

Period: $($commits[0].timestamp) - $($commits[-1].timestamp)
"@

Write-Log "タグメッセージ生成完了"

# Gitタグを作成
Write-Log "---------- Gitタグ作成 ----------"
try {
    # 現在のコミットハッシュを取得
    $currentCommit = git rev-parse HEAD 2>&1
    Write-Log "現在のコミット: $currentCommit"
    
    # タグを作成
    Write-Log "実行コマンド: git tag -a $tagName -m [message]"
    $gitOutput = git tag -a $tagName -m "$tagMessage" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${GREEN}✅ Session tag created: $tagName${RESET}"
        Write-Log "タグ作成成功: $tagName"
        
        # タグ履歴を記録
        $tagLogDir = "$PSScriptRoot\tags\logs"
        if (-not (Test-Path $tagLogDir)) {
            New-Item -ItemType Directory -Path $tagLogDir -Force | Out-Null
        }
        
        $tagHistoryFile = Join-Path $tagLogDir "session-tags.log"
        $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tag: $tagName | Commits: $($commits.Count) | Summary: $summaryText"
        Add-Content -Path $tagHistoryFile -Value $logEntry -Encoding UTF8
        Write-Log "タグ履歴を記録しました: $tagHistoryFile"
        
        # セッションコミットログをアーカイブ
        $archiveDir = "$PSScriptRoot\session-archives"
        if (-not (Test-Path $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }
        $archivePath = Join-Path $archiveDir "session-$timestamp.jsonl"
        Move-Item -Path $sessionCommitLog -Destination $archivePath -Force
        Write-Log "セッションログをアーカイブしました: $archivePath"
        
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

Write-Log "---------- サマリー ----------"
Write-Log "タグ名: $tagName"
Write-Log "コミット数: $($commits.Count)"
Write-Log "要約: $summaryText"
Write-Log "---------- セッションタグ生成完了 ----------"
Write-Log ""

exit 0