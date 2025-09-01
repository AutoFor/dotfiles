# Claude Code Agent-based Intelligent Commit Script
param()

# 変更内容チェック
$status = git status --porcelain
if (-not $status) {
    Write-Host "変更なし"
    exit 0
}

# git add実行
git add -A

# 変更内容を収集
$diff = git diff --cached | Select-Object -First 300
$changedFiles = @(git diff --cached --name-only)
$stats = git diff --cached --stat

# 一時ファイルに変更内容を保存
$tempFile = "$env:TEMP\git-changes-$(Get-Date -Format 'yyyyMMddHHmmss').txt"

@"
=== Git変更内容 ===
変更ファイル:
$($changedFiles -join "`n")

変更統計:
$stats

差分（抜粋）:
$diff
"@ | Out-File -FilePath $tempFile -Encoding utf8

# Claude Codeにプロンプトを送信するためのファイル作成
$promptFile = "$env:TEMP\commit-prompt.txt"

@"
以下のGit変更内容を分析して、適切なコミットを実行してください：

1. 変更内容は $tempFile に保存されています
2. 変更の本質を理解してください
3. Conventional Commits形式でコミットメッセージを生成
4. 現在のブランチがmain/masterの場合は適切な新ブランチを作成
5. git commitコマンドを実行

要件：
- type: feat/fix/docs/style/refactor/test/chore から選択
- 日本語で簡潔に（50文字以内）
- 変更の意図を正確に表現

実行するコマンド例：
git checkout -b feat/user-auth-20240101
git commit -m "feat(auth): ユーザー認証機能を実装"
"@ | Out-File -FilePath $promptFile -Encoding utf8

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📝 変更内容を分析中..." -ForegroundColor Yellow
Write-Host "変更ファイル: $($changedFiles.Count)個" -ForegroundColor Blue
Write-Host "" 
Write-Host "Claude Codeで以下のプロンプトを実行してください：" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "プロンプト保存先: $promptFile" -ForegroundColor Magenta
Write-Host "変更内容保存先: $tempFile" -ForegroundColor Magenta
Write-Host ""
Write-Host "コピー用コマンド:" -ForegroundColor Yellow
Write-Host "Get-Content '$promptFile' | Set-Clipboard" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# プロンプトをクリップボードにコピー
Get-Content $promptFile | Set-Clipboard
Write-Host "✅ プロンプトをクリップボードにコピーしました" -ForegroundColor Green