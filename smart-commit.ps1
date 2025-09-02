# Smart Commit Script for Claude Code
# Claude Codeを使用して自動的にコミットメッセージを生成するPowerShellスクリプト

param(
    [switch]$Push,              # コミット後に自動プッシュ
    [switch]$NoVerify,          # pre-commitフックをスキップ
    [switch]$Amend,             # 直前のコミットを修正
    [string]$Type = "auto",     # コミットタイプ (feat/fix/docs/style/refactor/test/chore/auto)
    [switch]$NoBranch           # ブランチ作成をスキップ
)

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
$isMainBranch = ($currentBranch -eq 'main' -or $currentBranch -eq 'master')
$isProtectedBranch = ($isMainBranch -or $currentBranch -eq 'develop' -or $currentBranch -eq 'staging' -or $currentBranch -eq 'production')

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
以下の変更内容から適切なGitブランチ名を生成してください。

要件:
1. 英語で記述（kebab-case）
2. prefixは以下から選択: feat/, fix/, docs/, refactor/, test/, chore/
3. 20-30文字程度
4. 変更の本質を表す名前
5. ブランチ名のみ出力（説明不要）

現在のブランチ: $currentBranch
変更ファイル:
$($staged -split "`n" | ForEach-Object { "- $_" } | Out-String)

差分の一部:
$($diff | Select-Object -First 100 | Out-String)
"@

    try {
        $suggestedBranch = $branchPrompt | claude 2>&1 | Out-String
        $suggestedBranch = $suggestedBranch.Trim()
        
        # 不要な文字を除去
        $suggestedBranch = $suggestedBranch -replace '^```[a-z]*\r?\n?', ''
        $suggestedBranch = $suggestedBranch -replace '\r?\n?```$', ''
        
        # 複数行の場合は最初の適切な行を抽出
        $lines = $suggestedBranch -split "`n"
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -match '^(feat|fix|docs|refactor|test|chore)/[\w\-]+$') {
                $suggestedBranch = $line
                break
            }
        }
        
        # 安全なブランチ名に変換（スペースをハイフンに、特殊文字を除去）
        $suggestedBranch = $suggestedBranch -replace '\s+', '-'
        $suggestedBranch = $suggestedBranch -replace '[^a-zA-Z0-9\-/]', ''
        $suggestedBranch = $suggestedBranch.Trim()
        
        if ([string]::IsNullOrWhiteSpace($suggestedBranch)) {
            $suggestedBranch = "feature/update-$(Get-Date -Format 'yyyyMMdd')"
        }
    } catch {
        $suggestedBranch = "feature/update-$(Get-Date -Format 'yyyyMMdd')"
    }
    
    Write-Host "${GREEN}✅ Suggested branch: ${CYAN}$suggestedBranch${RESET}"
    
    # ブランチ作成の確認
    Write-Host "${YELLOW}Create new branch? (Y/n/custom name): ${RESET}" -NoNewline
    $response = $null
    $response = Read-Host
    
    if ($null -eq $response) { $response = "" }
    
    # レスポンスの処理
    if ($response.ToLower() -eq "n") {
        Write-Host "${CYAN}ℹ️  Continuing on current branch: $currentBranch${RESET}"
    } else {
        # カスタム名が入力された場合はそれを使用、Yまたは空の場合は提案されたブランチ名を使用
        $branchName = if ($response -and $response.ToLower() -ne "y") { 
            $response 
        } else { 
            $suggestedBranch 
        }
        
        # ブランチ作成とチェックアウト
        $createResult = git checkout -b $branchName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${GREEN}✅ Created and switched to branch: $branchName${RESET}"
        } else {
            Write-Host "${RED}❌ Failed to create branch: $branchName${RESET}"
            Write-Host "${YELLOW}Continuing on current branch: $currentBranch${RESET}"
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
2. 日本語で記述
3. 1行目は50文字以内
4. コミットメッセージのみ出力（説明文は不要）
5. feat:やfix:で始まるメッセージを直接出力
6. バッククォートや```は使用しない

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

# 確認プロンプト
Write-Host "`n${YELLOW}Proceed with this commit message? (Y/n/e[dit]/r[egenerate]): ${RESET}" -NoNewline
$response = $null
$response = Read-Host

# レスポンスの処理
if ($null -eq $response) { $response = "" }
switch ($response.ToLower()) {
    "n" {
        Write-Host "${RED}❌ Commit cancelled${RESET}"
        exit 0
    }
    "e" {
        # メッセージを一時ファイルに保存して編集
        $tempFile = [System.IO.Path]::GetTempFileName()
        $message | Out-File -FilePath $tempFile -Encoding UTF8
        
        # デフォルトエディタで開く
        $editor = $env:EDITOR
        if (-not $editor) { $editor = "notepad" }
        Start-Process $editor -ArgumentList $tempFile -Wait
        
        # 編集されたメッセージを読み込み
        $message = Get-Content $tempFile -Raw -Encoding UTF8
        Remove-Item $tempFile
        
        Write-Host "${GREEN}✅ Using edited message${RESET}"
    }
    "r" {
        Write-Host "${BLUE}🔄 Regenerating...${RESET}"
        & $PSCommandPath @PSBoundParameters
        exit $LASTEXITCODE
    }
    default {
        # Y or Enter - proceed with commit
    }
}

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

Write-Host "`n${GREEN}${BOLD}🎉 Done!${RESET}"