# Smart Commit Script for Claude Code
# Claude Codeを使用して自動的にコミットメッセージを生成するPowerShellスクリプト

param(
    [switch]$Push,              # コミット後に自動プッシュ
    [switch]$NoVerify,          # pre-commitフックをスキップ
    [switch]$Amend,             # 直前のコミットを修正
    [string]$Type = "auto",     # コミットタイプ (feat/fix/docs/style/refactor/test/chore/auto)
    [switch]$NoBranch           # ブランチ作成をスキップ
)

# ログファイルのパス設定
$logDir = "$env:USERPROFILE\.claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "smart-commit-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
Write-Log "Smart Commit started"
Write-Log "Log file: $logFile"
Write-Host "${YELLOW}📝 Log file: $logFile${RESET}"

# Gitリポジトリの確認
if (-not (Test-Path .git)) {
    Write-Host "${RED}❌ Error: Not a git repository${RESET}"
    exit 1
}

# 変更の確認
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "${YELLOW}⚠️  No changes to commit${RESET}"
    exit 0
}

# 変更内容の表示
Write-Host "`n${BLUE}📝 Current changes:${RESET}"
git status --short

# ステージング確認（ブランチ名生成のために先にステージング）
$staged = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Host "`n${YELLOW}⚠️  No staged changes. Staging all changes...${RESET}"
    git add -A
    $staged = git diff --cached --name-only
}

# 差分の取得（ブランチ名生成用）
$diff = git diff --cached

# 現在のブランチ確認
$currentBranch = git branch --show-current
Write-Log "Current branch: $currentBranch"
$isMainBranch = ($currentBranch -eq 'main' -or $currentBranch -eq 'master')
$isProtectedBranch = ($isMainBranch -or $currentBranch -eq 'develop' -or $currentBranch -eq 'staging' -or $currentBranch -eq 'production')
Write-Log "Is protected branch: $isProtectedBranch"

# ブランチ作成の処理（-NoBranchと-Amend以外の場合は常に提案）
if (-not $NoBranch -and -not $Amend) {
    if ($isProtectedBranch) {
        Write-Host "`n${YELLOW}⚠️  You are on a protected branch: ${currentBranch}${RESET}"
    } else {
        Write-Host "`n${CYAN}ℹ️  Current branch: ${currentBranch}${RESET}"
    }
    
    Write-Host "${BLUE}Analyzing changes to generate branch name...${RESET}"
    
    # Claude Codeでブランチ名生成
    $branchPrompt = @"
以下の変更からGitブランチ名を生成:

$($staged -split "`n" | Select-Object -First 3 | ForEach-Object { "File: $_" } | Out-String)

次の形式で1行のみ出力: feat/short-name
例: feat/add-auth, fix/user-bug, docs/update-readme

ブランチ名:
"@

    try {
        Write-Log "Generating branch name with Claude..."
        Write-Log "Branch prompt: $branchPrompt"
        $suggestedBranch = $branchPrompt | claude 2>&1 | Out-String
        Write-Log "Raw Claude response: $suggestedBranch"
        $suggestedBranch = $suggestedBranch.Trim()
        
        # 不要な文字やコードブロックを除去
        $suggestedBranch = $suggestedBranch -replace '```[a-z]*', ''
        $suggestedBranch = $suggestedBranch -replace '```', ''
        
        # 複数行から有効なブランチ名を探す
        $lines = $suggestedBranch -split "`r?\n"
        $validBranch = $null
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            # feat/, fix/等で始まる行を探す
            if ($line -match '^(feat|fix|docs|refactor|test|chore)/[a-z0-9\-]+$') {
                $validBranch = $line
                break
            }
        }
        
        if ($validBranch) {
            $suggestedBranch = $validBranch
        } else {
            # 最初の非空白行を取得して整形
            $firstLine = ($lines | Where-Object { $_.Trim() -ne "" })[0]
            if ($firstLine) {
                $firstLine = $firstLine.Trim()
                # feat/等で始まっていない場合は追加
                if ($firstLine -notmatch '^(feat|fix|docs|refactor|test|chore)/') {
                    if ($firstLine -match '^[a-z0-9\-]+$') {
                        $suggestedBranch = "feat/$firstLine"
                    } else {
                        $suggestedBranch = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    }
                } else {
                    $suggestedBranch = $firstLine
                }
            } else {
                $suggestedBranch = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }
        }
        
    } catch {
        Write-Host "${RED}Error generating branch name: $_${RESET}"
        Write-Log "ERROR generating branch name: $_"
        $suggestedBranch = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Log "Using fallback branch name: $suggestedBranch"
    }
    
    Write-Host "${GREEN}✅ Suggested branch: ${CYAN}$suggestedBranch${RESET}"
    Write-Log "Final suggested branch: $suggestedBranch"
    
    # バックグラウンド実行のため、自動的にブランチを作成
    Write-Host "${BLUE}Creating branch automatically...${RESET}"
    
    $branchName = $suggestedBranch
    Write-Log "Attempting to create branch: $branchName"
    
    # ブランチ作成とチェックアウト
    Write-Log "Executing: git checkout -b $branchName"
    $createResult = git checkout -b $branchName 2>&1
    $exitCode = $LASTEXITCODE
    Write-Log "Git checkout -b exit code: $exitCode"
    Write-Log "Git checkout -b result: $createResult"
    
    if ($exitCode -eq 0) {
        Write-Host "${GREEN}✅ Created and switched to branch: $branchName${RESET}"
        Write-Log "Successfully created and switched to branch: $branchName"
    } else {
        # ブランチが既に存在する場合はそのブランチにチェックアウト
        if ($createResult -match "already exists") {
            Write-Host "${YELLOW}⚠️  Branch already exists: $branchName${RESET}"
            Write-Log "Branch already exists: $branchName"
            Write-Host "${BLUE}Switching to existing branch...${RESET}"
            Write-Log "Executing: git checkout $branchName"
            $checkoutResult = git checkout $branchName 2>&1
            $checkoutExitCode = $LASTEXITCODE
            Write-Log "Git checkout exit code: $checkoutExitCode"
            Write-Log "Git checkout result: $checkoutResult"
            
            if ($checkoutExitCode -eq 0) {
                Write-Host "${GREEN}✅ Switched to existing branch: $branchName${RESET}"
                Write-Log "Successfully switched to existing branch: $branchName"
            } else {
                Write-Host "${RED}❌ Failed to switch to branch: $branchName${RESET}"
                Write-Host "${RED}   Error: $checkoutResult${RESET}"
                Write-Log "ERROR: Failed to switch to branch: $branchName"
                Write-Log "ERROR details: $checkoutResult"
                Write-Host "${YELLOW}Continuing on current branch: $currentBranch${RESET}"
                Write-Log "Continuing on current branch: $currentBranch"
            }
        } else {
            Write-Host "${RED}❌ Failed to create branch: $branchName${RESET}"
            Write-Host "${RED}   Error: $createResult${RESET}"
            Write-Log "ERROR: Failed to create branch: $branchName"
            Write-Log "ERROR details: $createResult"
            Write-Host "${YELLOW}Continuing on current branch: $currentBranch${RESET}"
            Write-Log "Continuing on current branch: $currentBranch"
        }
    }
}

# 差分の再取得（既に取得済みの場合はスキップ）
if (-not $diff) {
    Write-Host "`n${BLUE}🔍 Analyzing changes...${RESET}"
    $diff = git diff --cached
} else {
    Write-Host "`n${BLUE}🔍 Analyzing changes...${RESET}"
}

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

# プロンプトの構築
$prompt = @"
以下のgit diffからコミットメッセージを生成してください。

要件:
1. Conventional Commitsフォーマット（feat:, fix:, docs:等で開始）
2. 必ず日本語で記述（説明部分を日本語にする。例: feat: 新機能を追加）
3. 1行目は50文字以内
4. コミットメッセージのみ出力（説明文は不要）
5. feat:やfix:で始まるメッセージを直接出力
6. バッククォートや```は使用しない
7. 英語は使用禁止（feat:などのprefixは除く）

変更されたファイル:
$($staged -split "`n" | ForEach-Object { "- $_" } | Out-String)

差分（最初の300行）:
$($diff | Select-Object -First 300 | Out-String)

日本語のコミットメッセージ:
"@

# タイプが指定されている場合はプロンプトに追加
if ($Type -ne "auto") {
    $prompt = $prompt -replace "型は以下から適切に選択:", "型は「$Type」を使用:"
}

# Claude Codeを実行してメッセージ生成
try {
    $message = $prompt | claude 2>&1 | Out-String
    $message = $message.Trim()
    
    # メッセージが空の場合のエラー処理
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw "Claude returned empty message"
    }
    
    # バックティックやコードブロックマーカーを除去
    $message = $message -replace '^```[a-z]*\r?\n?', ''
    $message = $message -replace '\r?\n?```$', ''
    $message = $message -replace '^\s*適切な.*?[:：]\s*', ''
    $message = $message -replace '^\s*以下.*?[:：]\s*', ''
    $message = $message -replace '^\s*提案.*?[:：]\s*', ''
    
    # 複数行の場合は最初のコミットメッセージらしい行を抽出
    $lines = $message -split "`n"
    foreach ($line in $lines) {
        if ($line -match '^\s*(feat|fix|docs|style|refactor|test|chore|perf|ci|build):') {
            $message = $line.Trim()
            break
        }
    }
    
    $message = $message.Trim()
    
} catch {
    Write-Host "${RED}❌ Failed to generate commit message with Claude${RESET}"
    Write-Host "${RED}   Error: $_${RESET}"
    exit 1
}

# 生成されたメッセージの表示
Write-Host "`n${GREEN}✅ Generated commit message:${RESET}"
Write-Host "${CYAN}$message${RESET}"

# バックグラウンド実行のため、確認プロンプトはスキップして自動コミット

# コミットの実行
Write-Host "`n${BLUE}📦 Committing changes...${RESET}"

$commitArgs = @()
if ($Amend) { $commitArgs += "--amend" }
if ($NoVerify) { $commitArgs += "--no-verify" }

# コミット実行
$commitResult = git commit $commitArgs -m $message 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "${GREEN}✅ Commit successful!${RESET}"
    
    # コミットハッシュの取得と表示
    $commitHash = git rev-parse --short HEAD
    Write-Host "${CYAN}   Commit: $commitHash${RESET}"
    
    # プッシュオプションが指定されている場合
    if ($Push) {
        Write-Host "`n${BLUE}🚀 Pushing to remote...${RESET}"
        $pushResult = git push 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${GREEN}✅ Push successful!${RESET}"
        } else {
            Write-Host "${RED}❌ Push failed:${RESET}"
            Write-Host $pushResult
            exit 1
        }
    }
} else {
    Write-Host "${RED}❌ Commit failed:${RESET}"
    Write-Host $commitResult
    exit 1
}

# 成功メッセージは既に表示済みなので、追加の通知は不要

# スクリプト終了時に環境変数をクリア
$env:SMART_COMMIT_RUNNING = $null
Write-Log "Smart Commit completed"
Write-Host "${YELLOW}📝 Log saved to: $logFile${RESET}"