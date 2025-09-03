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
Write-Log "##################################################"
Write-Log "######### スマートコミット開始 #########"
Write-Log "##################################################"
Write-Log "作業ディレクトリ: $(Get-Location)"
Write-Log "パラメータ: Push=$Push, NoVerify=$NoVerify, Amend=$Amend, Type=$Type"
Write-Host "${YELLOW}📝 Log file: $logFile${RESET}"

# Gitリポジトリの確認
if (-not (Test-Path .git)) {
    Write-Host "${RED}❌ Error: Not a git repository${RESET}"
    Write-Log "エラー: Gitリポジトリではありません"
    Write-Log "スマートコミット失敗 - Gitリポジトリではありません"
    exit 0  # Hook用に0で終了
}

# 変更の確認
Write-Log "変更確認中 (git status --porcelain)"
$status = git status --porcelain
Write-Log "Git status結果: $(if ([string]::IsNullOrWhiteSpace($status)) { '変更なし' } else { "$($status -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines) ファイル変更あり" })"

if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "${YELLOW}⚠️  No changes to commit${RESET}"
    Write-Log "変更が検出されませんでした - 正常終了"
    Write-Log "##################################################"
Write-Log "######### スマートコミット完了（変更なし） #########"
Write-Log "##################################################"
    exit 0
}

# 変更内容の表示
Write-Host "`n${BLUE}📝 Current changes:${RESET}"
$shortStatus = git status --short
Write-Log "変更されたファイル:"
$shortStatus -split "`n" | ForEach-Object { if ($_) { Write-Log "  $_" } }
Write-Host $shortStatus

# ステージング確認
Write-Log "ステージング済みファイルの確認 (git diff --cached --name-only)"
$staged = git diff --cached --name-only

if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Host "`n${YELLOW}⚠️  No staged changes. Staging all changes...${RESET}"
    Write-Log "ステージング済みの変更なし - すべてのファイルをステージング (git add -A)"
    git add -A
    $staged = git diff --cached --name-only
    Write-Log "ステージング完了: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines)) ファイル"
    $staged -split "`n" | ForEach-Object { if ($_) { Write-Log "  ステージング済み: $_" } }
} else {
    Write-Log "既にステージング済み: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines)) ファイル"
    $staged -split "`n" | ForEach-Object { if ($_) { Write-Log "  ステージング済み: $_" } }
}

# 差分の取得とスマート抽出
Write-Log "差分取得中 (git diff --cached)"
$diff = git diff --cached
Write-Log "差分サイズ: $($diff.Length) 文字"

# スマート差分抽出処理
Write-Log "重要な変更を抽出中..."

# 1. 各ファイルの変更サマリーを取得
$diffStat = git diff --cached --stat
Write-Log "変更統計: $diffStat"

# 2. 各ファイルの重要な部分を抽出
$smartDiff = @()
$smartDiff += "=== 変更サマリー ==="
$smartDiff += $diffStat
$smartDiff += ""

# 3. 各ファイルの関数/クラス変更を抽出
$stagedFiles = $staged -split "`n" | Where-Object { $_ }
foreach ($file in $stagedFiles) {
    if (-not $file) { continue }
    
    Write-Log "ファイルの重要変更を抽出: $file"
    
    # ファイル拡張子を確認
    $ext = [System.IO.Path]::GetExtension($file)
    
    # プログラミング言語ファイルの場合、関数/クラス定義を抽出
    if ($ext -match '\.(cs|js|ts|jsx|tsx|py|java|cpp|c|h|go|rs|php|rb|swift)$') {
        # 追加/変更された関数/クラスを抽出
        $fileDiff = git diff --cached -U0 -- $file 2>&1
        
        # 関数/クラス定義の変更を検出
        $importantLines = $fileDiff -split "`n" | Where-Object {
            $_ -match '^[+\-].*(function|class|interface|struct|def|public|private|protected|async|export|import|using|namespace|package)' -or
            $_ -match '^@@.*@@'
        }
        
        if ($importantLines) {
            $smartDiff += "=== $file ==="
            $smartDiff += $importantLines | Select-Object -First 30
            $smartDiff += ""
        }
    }
    # 設定ファイルの場合は全体を含める
    elseif ($ext -match '\.(json|yml|yaml|toml|ini|config|xml)$') {
        $fileDiff = git diff --cached -- $file 2>&1
        $smartDiff += "=== $file (設定ファイル) ==="
        $smartDiff += $fileDiff -split "`n" | Select-Object -First 50
        $smartDiff += ""
    }
}

# 4. 差分が大きすぎる場合は切り詰め
$smartDiffText = $smartDiff -join "`n"
if ($smartDiffText.Length -gt 3000) {
    $smartDiffText = $smartDiffText.Substring(0, 3000) + "`n... (以下省略)"
}

Write-Log "スマート差分サイズ: $($smartDiffText.Length) 文字"

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
Write-Log "---------- Claudeメッセージ生成 ----------"
Write-Log "Claudeへのプロンプト準備中"

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

スマート差分（重要な変更のみ）:
$smartDiffText

完全な差分（最初の200行）:
$($diff | Select-Object -First 200 | Out-String)

コミットメッセージ:
"@

# タイプが指定されている場合はプロンプトに追加
if ($Type -ne "auto") {
    $prompt = $prompt -replace "型は以下から適切に選択:", "型は「$Type」を使用:"
}

# Claude Codeを実行してメッセージ生成
try {
    Write-Log "Claudeにプロンプト送信中 (プロンプト長: $($prompt.Length) 文字)"
    
    $message = $prompt | claude 2>&1 | Out-String
    Write-Log "Claudeからの応答受信 (長さ: $($message.Length) 文字)"
    Write-Log "生の応答: $message"
    
    $message = $message.Trim()
    Write-Log "トリム後のメッセージ: $message"
    
    # メッセージが空の場合のエラー処理
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw "Claudeが空のメッセージを返しました"
    }
    
    # タイトルと詳細の抽出
    Write-Log "Claudeの応答からタイトルと詳細を抽出中"
    
    $title = ""
    $detail = ""
    
    # タイトルの抽出
    if ($message -match '<<<TITLE>>>([^<]+)<<<END>>>') {
        $title = $matches[1].Trim()
        Write-Log "抽出されたタイトル: $title"
        
        # タイトルの検証
        if ($title -notmatch '^(feat|fix|docs|style|refactor|test|chore|perf|ci|build):') {
            Write-Log "警告: タイトルがConventional Commits形式ではありません"
            # フォールバック: feat:を追加
            $title = "feat: $title"
            Write-Log "'feat:' プレフィックスを追加: $title"
        }
    } else {
        Write-Log "<<<TITLE>>>タグが応答に見つかりません"
        # フォールバック: 従来の方法で抽出
        $lines = $message -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^\s*(feat|fix|docs|style|refactor|test|chore|perf|ci|build):') {
                $title = $line.Trim()
                Write-Log "フォールバック方式でタイトル発見: $title"
                break
            }
        }
        
        if (-not $title) {
            $title = "feat: コードの更新"
            Write-Log "デフォルトタイトルを使用: $title"
        }
    }
    
    # 詳細の抽出
    if ($message -match '<<<DETAIL>>>([\s\S]+?)<<<END>>>') {
        $detail = $matches[1].Trim()
        Write-Log "抽出された詳細 (長さ: $($detail.Length) 文字)"
        Write-Log "詳細内容: $detail"
    } else {
        Write-Log "<<<DETAIL>>>タグが見つかりません - 詳細メッセージなし"
    }
    
    # コミットメッセージの組み立て
    if ($detail) {
        # タイトルと詳細を結合
        $message = "$title`n`n$detail"
        Write-Log "タイトルと詳細を結合したコミットメッセージ"
    } else {
        # タイトルのみ
        $message = $title
        Write-Log "タイトルのみ使用（詳細なし）"
    }
    
    Write-Log "最終コミットメッセージ:"
    Write-Log $message
    
} catch {
    Write-Host "${RED}❌ Failed to generate commit message with Claude${RESET}"
    Write-Host "${RED}   Error: $_${RESET}"
    Write-Log "エラー: Claudeでコミットメッセージ生成に失敗"
    Write-Log "エラー詳細: $_"
    Write-Log "スタックトレース: $($_.Exception.StackTrace)"
    Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
Write-Log "!!!!! スマートコミット失敗（Claudeエラー） !!!!!"
Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
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

Write-Log "---------- コミットメッセージ生成完了 ----------"
Write-Log "タイトル: $title"
if ($detail) {
    Write-Log "詳細: $detail"
}
Write-Log "完全なメッセージ: $message"

# バックグラウンド実行のため、確認プロンプトはスキップして自動コミット

# コミットの実行
Write-Host "`n${BLUE}📦 Committing changes...${RESET}"
Write-Log "---------- Gitコミット実行 ----------"

$commitArgs = @()
if ($Amend) { 
    $commitArgs += "--amend"
    Write-Log "修正フラグ: 有効"
}
if ($NoVerify) { 
    $commitArgs += "--no-verify"
    Write-Log "検証スキップフラグ: 有効"
}
Write-Log "コミット引数: $($commitArgs -join ' ')"

# コミット実行
Write-Log "実行中: git commit $($commitArgs -join ' ') -m '$message'"
$commitResult = git commit $commitArgs -m $message 2>&1
Write-Log "Git commit終了コード: $LASTEXITCODE"
Write-Log "Git commit出力: $commitResult"

if ($LASTEXITCODE -eq 0) {
    Write-Host "${GREEN}✅ Commit successful!${RESET}"
    Write-Log "コミット成功！"
    
    # コミットハッシュの取得と表示
    $commitHash = git rev-parse --short HEAD
    Write-Host "${CYAN}   Commit: $commitHash${RESET}"
    Write-Log "コミットハッシュ: $commitHash"
    Write-Log "使用されたコミットメッセージ: $message"
    
    # プッシュオプションが指定されている場合
    if ($Push) {
        Write-Host "`n${BLUE}🚀 Pushing to remote...${RESET}"
        Write-Log "---------- Gitプッシュ ----------"
        Write-Log "実行中: git push"
        $pushResult = git push 2>&1
        Write-Log "Git push終了コード: $LASTEXITCODE"
        Write-Log "Git push出力: $pushResult"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${GREEN}✅ Push successful!${RESET}"
            Write-Log "プッシュ成功！"
            Write-Log "変更をリモートリポジトリにプッシュしました"
        } else {
            Write-Host "${RED}❌ Push failed:${RESET}"
            Write-Host $pushResult
            Write-Log "エラー: プッシュ失敗"
            Write-Log "プッシュエラー詳細: $pushResult"
            Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
Write-Log "!!!!! スマートコミット完了（プッシュエラー） !!!!!"
Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            exit 0  # Hook用に0で終了
        }
    }
} else {
    Write-Host "${RED}❌ Commit failed:${RESET}"
    Write-Host $commitResult
    Write-Log "エラー: コミット失敗（終了コード: $LASTEXITCODE）"
    Write-Log "コミットエラー詳細: $commitResult"
    
    # よくあるエラーの診断
    if ($commitResult -match "nothing to commit") {
        Write-Log "診断: コミットする変更がありません"
    } elseif ($commitResult -match "pre-commit hook") {
        Write-Log "診断: Pre-commitフックの失敗"
    } elseif ($commitResult -match "Please tell me who you are") {
        Write-Log "診断: Gitユーザー設定が必要です"
    }
    
    Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
Write-Log "!!!!! スマートコミット失敗（コミットエラー） !!!!!"
Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 0  # Hook用に0で終了
}

# 成功メッセージは既に表示済みなので、追加の通知は不要

# スクリプト終了時に環境変数をクリア
$env:SMART_COMMIT_RUNNING = $null

# 最終サマリー
Write-Log "---------- サマリー ----------"
Write-Log "コミット成功: はい"
Write-Log "コミットされたファイル数: $(($staged -split "`n" | Measure-Object -Line | Select-Object -ExpandProperty Lines))"
Write-Log "コミットメッセージ: $message"
Write-Log "コミットハッシュ: $commitHash"
if ($Push) {
    Write-Log "プッシュステータス: $(if ($LASTEXITCODE -eq 0) { '成功' } else { '失敗' })"
}
Write-Log "##################################################"
Write-Log "######### スマートコミット正常完了 #########"
Write-Log "##################################################"
Write-Host "${YELLOW}📝 Log saved to: $logFile${RESET}"