# Agent-based Intelligent Commit using Claude Code
param()

# 変更内容チェック
$status = git status --porcelain
if (-not $status) {
    Write-Host "変更なし"
    exit 0
}

# git add実行
git add -A

# 変更内容を収集してファイルに保存
$diff = git diff --cached
$changedFiles = @(git diff --cached --name-only) 
$stats = git diff --cached --stat

# 変更サマリー作成
$changeSummary = @"
Changed Files: $($changedFiles -join ', ')
Statistics: $stats
"@

Write-Host "🤖 Claude Code Agentで変更を分析中..." -ForegroundColor Cyan

# プロンプトメッセージ作成
$message = @"
タスク: 以下のGit変更内容を分析して、適切なコミットを実行してください。

$changeSummary

差分内容（最初の200行）:
$($diff | Select-Object -First 200)

実行内容:
1. 変更の本質を理解する
2. Conventional Commits形式でコミットメッセージを決定
3. 現在のブランチを確認（git branch --show-current）
4. main/masterブランチの場合は新ブランチを作成
5. git commitを実行

コミットメッセージ要件:
- 形式: type(scope): description
- type: feat/fix/docs/style/refactor/test/chore
- 日本語で簡潔に（50文字以内）
- 変更の意図を正確に表現
"@

# メッセージをファイルに保存（Claude Codeから参照可能）
$promptFile = "$env:TEMP\agent-commit-prompt.txt"
$message | Out-File -FilePath $promptFile -Encoding utf8

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 以下のメッセージをClaude Codeに貼り付けてください:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host $message -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "または、保存されたファイルを参照:" -ForegroundColor Green
Write-Host $promptFile -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# クリップボードにコピー
$message | Set-Clipboard
Write-Host "✅ クリップボードにコピーしました（Ctrl+Vで貼り付け）" -ForegroundColor Green