# Smart Commit Script for Claude Code
# Claude Codeを使用して自動的にコミットメッセージを生成するPowerShellスクリプト

param(
    [switch]$Push,              # コミット後に自動プッシュ
    [switch]$NoVerify,          # pre-commitフックをスキップ
    [switch]$Amend,             # 直前のコミットを修正
    [string]$Type = "auto"      # コミットタイプ (feat/fix/docs/style/refactor/test/chore/auto)
)

# ログファイルのパス設定
$logDir = "$env:USERPROFILE\.claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "smart-commit-$(Get-Date -Format 'yyyyMMdd').log"

# ログ出力関数
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

# smart-commit実行中フラグを環境変数に設定（通知抑制用）
$env:SMART_COMMIT_RUNNING = "true"

# ANSIカラーコード
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$MAGENTA = "$ESC[35m"
$CYAN = "$ESC[36m"
$RESET = "$ESC[0m"
$BOLD = "$ESC[1m"

# ヘッダー表示
Write-Host "`n${CYAN}${BOLD}🤖 Smart Commit with Claude Code${RESET}" -NoNewline
Write-Host ""
Write-Log "========== SMART COMMIT STARTED =========="
Write-Log "Working directory: $(Get-Location)"
Write-Log "Parameters: Push=$Push, NoVerify=$NoVerify, Amend=$Amend, Type=$Type"
Write-Host "${YELLOW}📝 Log file: $logFile${RESET}"

# Gitリポジトリの確認
if (-not (Test-Path .git)) {
    Write-Host "${RED}❌ Error: Not a git repository${RESET}"
    Write-Log "ERROR: Not a git repository"
    Write-Log "Smart Commit failed - not a git repository"
    exit 0  # Hook用に0で終了
}

# 変更の確認
Write-Log "Checking for changes with 'git status --porcelain'"
$status = git status --porcelain
Write-Log "Git status result: $(if ([string]::IsNullOrWhiteSpace($status)) { 'No changes' } else { "$($status -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines) file(s) changed" })"

if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "${YELLOW}⚠️  No changes to commit${RESET}"
    Write-Log "No changes detected - exiting gracefully"
    Write-Log "========== SMART COMMIT COMPLETED (NO CHANGES) =========="
    exit 0
}

# 変更内容の表示
Write-Host "`n${BLUE}📝 Current changes:${RESET}"
$shortStatus = git status --short
Write-Log "Files with changes:"
$shortStatus -split "`n" | ForEach-Object { if ($_) { Write-Log "  $_" } }
Write-Host $shortStatus

# ステージング確認
Write-Log "Checking staged files with 'git diff --cached --name-only'"
$staged = git diff --cached --name-only

if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Host "`n${YELLOW}⚠️  No staged changes. Staging all changes...${RESET}"
    Write-Log "No staged changes found - staging all files with 'git add -A'"
    git add -A
    $staged = git diff --cached --name-only
    Write-Log "Files staged: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines)) file(s)"
    $staged -split "`n" | ForEach-Object { if ($_) { Write-Log "  Staged: $_" } }
} else {
    Write-Log "Already staged: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines)) file(s)"
    $staged -split "`n" | ForEach-Object { if ($_) { Write-Log "  Staged: $_" } }
}

# 差分の取得
Write-Log "Getting diff with 'git diff --cached'"
$diff = git diff --cached
Write-Log "Diff size: $($diff.Length) characters"

# 変更の分析
Write-Host "`n${BLUE}🔍 Analyzing changes...${RESET}"

# ファイル数と変更行数の取得
$fileCount = ($staged -split "`n" | Where-Object { $_ }).Count
$stats = git diff --cached --stat
$insertions = 0
$deletions = 0
if ($stats) {
    $matches = $null
    if ($stats -match "(\d+) insertion") { 
        $insertions = $matches[1]
    }
    $matches = $null
    if ($stats -match "(\d+) deletion") { 
        $deletions = $matches[1]
    }
}

Write-Host "${GREEN}  ✓ ${fileCount} file(s) changed, +${insertions}/-${deletions} lines${RESET}"

# Claude Codeでコミットメッセージ生成
Write-Host "`n${BLUE}🤖 Generating commit message with Claude...${RESET}"
Write-Log "========== CLAUDE MESSAGE GENERATION =========="
Write-Log "Preparing prompt for Claude"

# プロンプトの構築
$prompt = @"
以下のgit diffからコミットメッセージを生成してください。

要件:
1. タイトルと詳細を別々に出力
2. タイトルは<<<TITLE>>>と<<<END>>>で囲む
3. 詳細は<<<DETAIL>>>と<<<END>>>で囲む
4. タイトルはConventional Commits形式（英語必須）
   - 必ず英語のprefix（feat/fix/docs/style/refactor/test/chore）で開始
   - 形式: "prefix: description"（例: feat: add user authentication）
   - 1行50文字以内
5. 詳細は日本語で、変更内容を箇条書きで説明
6. コードブロック(```)は使用禁止

出力形式:
<<<TITLE>>>feat: add new feature<<<END>>>
<<<DETAIL>>>
- 新機能の実装内容を日本語で説明
- 変更点を日本語で箇条書き
- 技術的な詳細も日本語で記載
<<<END>>>

重要:
- タイトルのprefix部分（feat:等）は必ず英語
- タイトルの説明部分も英語
- 詳細説明は必ず日本語

変更されたファイル:
$($staged -split "`n" | ForEach-Object { "- $_" } | Out-String)

差分（最初の300行）:
$($diff | Select-Object -First 300 | Out-String)

コミットメッセージ:
"@

# タイプが指定されている場合はプロンプトに追加
if ($Type -ne "auto") {
    $prompt = $prompt -replace "型は以下から適切に選択:", "型は「$Type」を使用:"
}

# Claude Codeを実行してメッセージ生成
try {
    Write-Log "Sending prompt to Claude (prompt length: $($prompt.Length) characters)"
    
    $message = $prompt | claude 2>&1 | Out-String
    Write-Log "Raw Claude response received (length: $($message.Length) characters)"
    Write-Log "Raw response: $message"
    
    $message = $message.Trim()
    Write-Log "Trimmed message: $message"
    
    # メッセージが空の場合のエラー処理
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw "Claude returned empty message"
    }
    
    # タイトルと詳細の抽出
    Write-Log "Extracting title and detail from Claude response"
    
    $title = ""
    $detail = ""
    
    # タイトルの抽出
    if ($message -match '<<<TITLE>>>([^<]+)<<<END>>>') {
        $title = $matches[1].Trim()
        Write-Log "Extracted title: $title"
        
        # タイトルの検証
        if ($title -notmatch '^(feat|fix|docs|style|refactor|test|chore|perf|ci|build):') {
            Write-Log "WARNING: Title doesn't follow Conventional Commits format"
            # フォールバック: feat:を追加
            $title = "feat: $title"
            Write-Log "Added 'feat:' prefix to title: $title"
        }
    } else {
        Write-Log "No <<<TITLE>>> tags found in response"
        # フォールバック: 従来の方法で抽出
        $lines = $message -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^\s*(feat|fix|docs|style|refactor|test|chore|perf|ci|build):') {
                $title = $line.Trim()
                Write-Log "Found title using fallback method: $title"
                break
            }
        }
        
        if (-not $title) {
            $title = "feat: コードの更新"
            Write-Log "Using default title: $title"
        }
    }
    
    # 詳細の抽出
    if ($message -match '<<<DETAIL>>>([\s\S]+?)<<<END>>>') {
        $detail = $matches[1].Trim()
        Write-Log "Extracted detail (length: $($detail.Length) chars)"
        Write-Log "Detail content: $detail"
    } else {
        Write-Log "No <<<DETAIL>>> tags found - no detail message"
    }
    
    # コミットメッセージの組み立て
    if ($detail) {
        # タイトルと詳細を結合
        $message = "$title`n`n$detail"
        Write-Log "Combined commit message with title and detail"
    } else {
        # タイトルのみ
        $message = $title
        Write-Log "Using title only (no detail provided)"
    }
    
    Write-Log "Final commit message:"
    Write-Log $message
    
} catch {
    Write-Host "${RED}❌ Failed to generate commit message with Claude${RESET}"
    Write-Host "${RED}   Error: $_${RESET}"
    Write-Log "ERROR: Failed to generate commit message with Claude"
    Write-Log "ERROR details: $_"
    Write-Log "ERROR stack trace: $($_.Exception.StackTrace)"
    Write-Log "========== SMART COMMIT FAILED (CLAUDE ERROR) =========="
    exit 0  # Hook用に0で終了
}

# 生成されたメッセージの表示
Write-Host "`n${GREEN}✅ Generated commit message:${RESET}"

# タイトルと詳細を分けて表示
if ($detail) {
    Write-Host "${CYAN}Title: $title${RESET}"
    Write-Host "${CYAN}Detail:${RESET}"
    Write-Host "${CYAN}$detail${RESET}"
} else {
    Write-Host "${CYAN}$message${RESET}"
}

Write-Log "========== COMMIT MESSAGE GENERATED =========="
Write-Log "Title: $title"
if ($detail) {
    Write-Log "Detail: $detail"
}
Write-Log "Full message: $message"

# バックグラウンド実行のため、確認プロンプトはスキップして自動コミット

# コミットの実行
Write-Host "`n${BLUE}📦 Committing changes...${RESET}"
Write-Log "========== GIT COMMIT EXECUTION =========="

$commitArgs = @()
if ($Amend) { 
    $commitArgs += "--amend"
    Write-Log "Amend flag: true"
}
if ($NoVerify) { 
    $commitArgs += "--no-verify"
    Write-Log "NoVerify flag: true"
}
Write-Log "Commit arguments: $($commitArgs -join ' ')"

# コミット実行
Write-Log "Executing: git commit $($commitArgs -join ' ') -m '$message'"
$commitResult = git commit $commitArgs -m $message 2>&1
Write-Log "Git commit exit code: $LASTEXITCODE"
Write-Log "Git commit output: $commitResult"

if ($LASTEXITCODE -eq 0) {
    Write-Host "${GREEN}✅ Commit successful!${RESET}"
    Write-Log "Commit successful!"
    
    # コミットハッシュの取得と表示
    $commitHash = git rev-parse --short HEAD
    Write-Host "${CYAN}   Commit: $commitHash${RESET}"
    Write-Log "Commit hash: $commitHash"
    Write-Log "Commit message used: $message"
    
    # プッシュオプションが指定されている場合
    if ($Push) {
        Write-Host "`n${BLUE}🚀 Pushing to remote...${RESET}"
        Write-Log "========== GIT PUSH =========="
        Write-Log "Executing: git push"
        $pushResult = git push 2>&1
        Write-Log "Git push exit code: $LASTEXITCODE"
        Write-Log "Git push output: $pushResult"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${GREEN}✅ Push successful!${RESET}"
            Write-Log "Push successful!"
            Write-Log "Changes pushed to remote repository"
        } else {
            Write-Host "${RED}❌ Push failed:${RESET}"
            Write-Host $pushResult
            Write-Log "ERROR: Push failed"
            Write-Log "Push error details: $pushResult"
            Write-Log "========== SMART COMMIT COMPLETED WITH PUSH ERROR =========="
            exit 0  # Hook用に0で終了
        }
    }
} else {
    Write-Host "${RED}❌ Commit failed:${RESET}"
    Write-Host $commitResult
    Write-Log "ERROR: Commit failed with exit code $LASTEXITCODE"
    Write-Log "Commit error details: $commitResult"
    
    # よくあるエラーの診断
    if ($commitResult -match "nothing to commit") {
        Write-Log "DIAGNOSIS: No changes to commit"
    } elseif ($commitResult -match "pre-commit hook") {
        Write-Log "DIAGNOSIS: Pre-commit hook failure"
    } elseif ($commitResult -match "Please tell me who you are") {
        Write-Log "DIAGNOSIS: Git user configuration required"
    }
    
    Write-Log "========== SMART COMMIT FAILED (COMMIT ERROR) =========="
    exit 0  # Hook用に0で終了
}

# 成功メッセージは既に表示済みなので、追加の通知は不要

# スクリプト終了時に環境変数をクリア
$env:SMART_COMMIT_RUNNING = $null

# 最終サマリー
Write-Log "========== SUMMARY =========="
Write-Log "Commit successful: Yes"
Write-Log "Files committed: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines))"
Write-Log "Commit message: $message"
Write-Log "Commit hash: $commitHash"
if ($Push) {
    Write-Log "Push status: $(if ($LASTEXITCODE -eq 0) { 'Success' } else { 'Failed' })"
}
Write-Log "========== SMART COMMIT COMPLETED SUCCESSFULLY =========="
Write-Host "${YELLOW}📝 Log saved to: $logFile${RESET}"