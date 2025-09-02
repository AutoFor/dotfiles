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

# ステージング確認
$staged = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Host "`n${YELLOW}⚠️  No staged changes. Staging all changes...${RESET}"
    git add -A
    $staged = git diff --cached --name-only
}

# 差分の取得
Write-Host "`n${BLUE}🔍 Analyzing changes...${RESET}"
$diff = git diff --cached

# ファイル数と変更行数の取得
$fileCount = ($staged -split "`n" | Where-Object { $_ }).Count
$stats = git diff --cached --stat
$insertions = 0
$deletions = 0
if ($stats) {
    if ($stats -match "(\d+) insertion") { $insertions = $matches[1] }
    if ($stats -match "(\d+) deletion") { $deletions = $matches[1] }
}

Write-Host "${GREEN}  ✓ ${fileCount} file(s) changed, +${insertions}/-${deletions} lines${RESET}"

# Claude Codeでコミットメッセージ生成
Write-Host "`n${BLUE}🤖 Generating commit message with Claude...${RESET}"

# プロンプトの構築
$prompt = @"
以下のgit diffからコミットメッセージを生成してください。

要件:
1. Conventional Commitsフォーマットに従う
2. 日本語で記述
3. 1行目は50文字以内
4. 型は以下から適切に選択:
   - feat: 新機能
   - fix: バグ修正
   - docs: ドキュメント
   - style: フォーマット修正
   - refactor: リファクタリング
   - test: テスト
   - chore: その他

差分:
``````
$diff
``````

コミットメッセージのみを出力してください（説明不要）。
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
$response = Read-Host

# レスポンスの処理
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