# ファイル経由でClaude Codeと連携する改善版
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

# Claude Codeが監視するファイルに書き込み
$watchFile = "C:\Users\SeiyaKawashima\.claude\COMMIT_REQUEST.md"

@"
# 自動コミット要求

## 変更ファイル
$($changedFiles -join "`n")

## 変更統計
$stats

## 差分内容
``````diff
$diff
``````

## 実行してください
1. この変更を分析
2. 適切なコミットメッセージを生成
3. git commit -m "生成したメッセージ" を実行

---
*このファイルは自動生成されました*
"@ | Out-File -FilePath $watchFile -Encoding utf8

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ コミット要求ファイルを作成しました" -ForegroundColor Green
Write-Host "📁 $watchFile" -ForegroundColor Yellow
Write-Host "" 
Write-Host "Claude Codeで以下のコマンドを実行:" -ForegroundColor Cyan
Write-Host "  Read $watchFile" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# コマンドをクリップボードにコピー
"Read $watchFile してからコミットを実行してください" | Set-Clipboard