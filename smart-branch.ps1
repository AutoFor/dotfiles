# Smart Branch Script for Claude Code
# 自動的にブランチ名を生成してブランチを作成するPowerShellスクリプト

param(
    [switch]$Force,              # 強制的にブランチを作成
    [string]$Type = "auto",      # ブランチタイプ (feat/fix/docs/refactor/test/chore/auto)
    [switch]$NoSwitch            # ブランチ作成後に切り替えない
)

# ログファイルのパス設定
$logDir = "$env:USERPROFILE\.claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "smart-branch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# ログ出力関数
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

# ANSIカラーコード
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$CYAN = "$ESC[36m"
$RESET = "$ESC[0m"
$BOLD = "$ESC[1m"

# ヘッダー表示
Write-Host "`n${CYAN}${BOLD}🌿 Smart Branch Creator${RESET}"
Write-Log "Smart Branch started"
Write-Log "Log file: $logFile"

# Gitリポジトリの確認
if (-not (Test-Path .git)) {
    Write-Host "${RED}❌ Error: Not a git repository${RESET}"
    Write-Log "ERROR: Not a git repository"
    exit 0
}

# 現在のブランチ確認
$currentBranch = git branch --show-current
Write-Log "Current branch: $currentBranch"
$isMainBranch = ($currentBranch -eq 'main' -or $currentBranch -eq 'master')
$isProtectedBranch = ($isMainBranch -or $currentBranch -eq 'develop' -or $currentBranch -eq 'staging' -or $currentBranch -eq 'production')

if ($isProtectedBranch) {
    Write-Host "${YELLOW}⚠️  You are on a protected branch: ${currentBranch}${RESET}"
    Write-Log "On protected branch: $currentBranch"
} else {
    Write-Host "${CYAN}ℹ️  Current branch: ${currentBranch}${RESET}"
}

# 変更の確認とステージング
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "${YELLOW}⚠️  No changes detected${RESET}"
    Write-Log "No changes detected"
    
    # 変更がない場合でも、タイムスタンプベースのブランチを作成可能
    if ($Force) {
        $branchName = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Host "${BLUE}Creating timestamp-based branch...${RESET}"
    } else {
        Write-Host "${YELLOW}Use -Force to create a branch without changes${RESET}"
        exit 0
    }
} else {
    # 変更内容の表示
    Write-Host "`n${BLUE}📝 Current changes:${RESET}"
    git status --short
    
    # ステージングされたファイルの確認
    $staged = git diff --cached --name-only
    if ([string]::IsNullOrWhiteSpace($staged)) {
        Write-Host "`n${YELLOW}Staging all changes for analysis...${RESET}"
        git add -A
        $staged = git diff --cached --name-only
    }
    
    Write-Host "`n${BLUE}Analyzing changes to generate branch name...${RESET}"
    
    # Claude Codeでブランチ名生成
    $branchPrompt = @"
変更ファイル: $($staged -split "`n" | Select-Object -First 3 | ForEach-Object { "- $_" } | Out-String)

ブランチ名を次の形式で出力:
<<<BRANCH>>>type/short-name<<<END>>>

重要なルール:
- type: feat, fix, docs, refactor, test, chore から選択
- 英語のみ使用（日本語禁止）
- 使用可能文字: a-z, 0-9, -, / のみ
- 例: <<<BRANCH>>>feat/add-user-auth<<<END>>>
- 例: <<<BRANCH>>>fix/queue-handling<<<END>>>

必ず<<<BRANCH>>>と<<<END>>>で囲み、英語のみで出力してください。
"@

    # タイプが指定されている場合
    if ($Type -ne "auto") {
        $branchPrompt = $branchPrompt -replace "type: feat, fix", "type: $Type を使用"
    }
    
    try {
        Write-Log "Generating branch name with Claude..."
        Write-Log "Branch prompt: $branchPrompt"
        $suggestedBranch = $branchPrompt | claude 2>&1 | Out-String
        Write-Log "Raw Claude response: $suggestedBranch"
        $suggestedBranch = $suggestedBranch.Trim()
        
        # <<<BRANCH>>>...<<<END>>>タグからブランチ名を抽出
        if ($suggestedBranch -match '<<<BRANCH>>>([^<]+)<<<END>>>') {
            $extractedBranch = $matches[1].Trim()
            Write-Log "Extracted branch name from tags: $extractedBranch"
            
            # ブランチ名の検証
            if ($extractedBranch -match '^(feat|fix|docs|refactor|test|chore)/[a-z0-9\-]+$') {
                $branchName = $extractedBranch
                Write-Log "Valid branch name: $branchName"
            } else {
                Write-Log "Invalid branch name format: $extractedBranch"
                $branchName = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-Log "Using fallback branch name: $branchName"
            }
        } else {
            Write-Log "No <<<BRANCH>>> tags found in response"
            Write-Log "Full response: $suggestedBranch"
            
            # タグが見つからない場合はパターンを直接探す
            if ($suggestedBranch -match '(feat|fix|docs|refactor|test|chore)/[a-z0-9\-]+') {
                $branchName = $matches[0]
                Write-Log "Found branch pattern without tags: $branchName"
            } else {
                Write-Log "No valid branch pattern found"
                $branchName = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-Log "Using fallback branch name: $branchName"
            }
        }
        
    } catch {
        Write-Host "${RED}Error generating branch name: $_${RESET}"
        Write-Log "ERROR generating branch name: $_"
        $branchName = "feature/update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Log "Using fallback branch name: $branchName"
    }
}

Write-Host "${GREEN}✅ Suggested branch: ${CYAN}$branchName${RESET}"

# ユーザーに確認（バックグラウンド実行でない場合）
if (-not $env:SMART_BRANCH_AUTO) {
    Write-Host "`n${YELLOW}Create and switch to this branch? (Y/n):${RESET} " -NoNewline
    $response = Read-Host
    if ($response -eq 'n' -or $response -eq 'N') {
        Write-Host "${YELLOW}Branch creation cancelled${RESET}"
        Write-Log "Branch creation cancelled by user"
        exit 0
    }
}

# ブランチ作成とチェックアウト
Write-Log "========== BRANCH CREATION ATTEMPT =========="
Write-Log "Target branch name: $branchName"
Write-Log "Current branch: $currentBranch"
Write-Log "Current directory: $(Get-Location)"

# 既存ブランチの一覧を取得してログに記録
$allBranches = git branch -a 2>&1
Write-Log "All branches before creation:"
Write-Log $allBranches

# ブランチ作成実行
if ($NoSwitch) {
    Write-Log "Executing: git branch '$branchName'"
    $createResult = git branch $branchName 2>&1
    $operation = "branch"
} else {
    Write-Log "Executing: git checkout -b '$branchName'"
    $createResult = git checkout -b $branchName 2>&1
    $operation = "checkout -b"
}

$exitCode = $LASTEXITCODE
Write-Log "Git $operation exit code: $exitCode"
Write-Log "Git $operation output: $createResult"

if ($exitCode -eq 0) {
    if ($NoSwitch) {
        Write-Host "${GREEN}✅ Created branch: $branchName${RESET}"
        Write-Host "${CYAN}   (staying on current branch: $currentBranch)${RESET}"
        Write-Log "SUCCESS: Created branch: $branchName (no switch)"
    } else {
        Write-Host "${GREEN}✅ Created and switched to branch: $branchName${RESET}"
        Write-Log "SUCCESS: Created and switched to branch: $branchName"
    }
} else {
    Write-Log "FAILED: Branch creation failed with exit code $exitCode"
    
    # エラーの詳細分析
    if ($createResult -match "already exists") {
        Write-Host "${YELLOW}⚠️  Branch already exists: $branchName${RESET}"
        Write-Log "REASON: Branch '$branchName' already exists"
        
        if (-not $NoSwitch) {
            Write-Host "${BLUE}Switching to existing branch...${RESET}"
            Write-Log "Attempting to switch to existing branch..."
            Write-Log "Executing: git checkout '$branchName'"
            $checkoutResult = git checkout $branchName 2>&1
            $checkoutExitCode = $LASTEXITCODE
            Write-Log "Git checkout exit code: $checkoutExitCode"
            Write-Log "Git checkout output: $checkoutResult"
            
            if ($checkoutExitCode -eq 0) {
                Write-Host "${GREEN}✅ Switched to existing branch: $branchName${RESET}"
                Write-Log "SUCCESS: Switched to existing branch: $branchName"
            } else {
                Write-Host "${RED}❌ Failed to switch to branch: $branchName${RESET}"
                Write-Host "${RED}   Error: $checkoutResult${RESET}"
                Write-Log "ERROR: Failed to switch to existing branch"
                Write-Log "CHECKOUT ERROR: $checkoutResult"
            }
        }
    } else {
        Write-Host "${RED}❌ Failed to create branch: $branchName${RESET}"
        Write-Host "${RED}   Error: $createResult${RESET}"
        Write-Log "ERROR: Failed to create branch"
        Write-Log "ERROR details: $createResult"
    }
}

Write-Log "========== END BRANCH CREATION ATTEMPT =========="
Write-Log "Smart Branch completed"

# 成功した場合はブランチ名を出力（他のスクリプトから利用可能）
if ($exitCode -eq 0) {
    Write-Output $branchName
}