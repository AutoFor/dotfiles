# Convert Temp Commits to Proper Commits
# このスクリプトはClaude Code Agentsから実行されることを想定

param(
    [string]$Branch = "temp/*"
)

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🔄 Temp コミットの一括変換" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# tempブランチをすべて取得
$tempBranches = git branch --list $Branch | ForEach-Object { $_.Trim() }

if (-not $tempBranches) {
    Write-Host "❌ tempブランチが見つかりません" -ForegroundColor Red
    exit 0
}

Write-Host "📋 見つかったtempブランチ:" -ForegroundColor Green
$tempBranches | ForEach-Object { Write-Host "  - $_" }

# 各tempブランチの情報を収集
$branchInfoList = @()

foreach ($branch in $tempBranches) {
    # ブランチに切り替え
    git checkout $branch 2>$null
    
    # このブランチのコミット情報を取得
    $commits = git log --format="%H|%s|%b" --no-merges origin/main..$branch
    
    foreach ($commit in $commits) {
        $parts = $commit -split '\|'
        $hash = $parts[0]
        $subject = $parts[1]
        $body = $parts[2]
        
        # コミットの差分を取得
        $diff = git show --stat $hash
        $files = git diff-tree --no-commit-id --name-only -r $hash
        
        $branchInfoList += [PSCustomObject]@{
            Branch = $branch
            Hash = $hash
            Subject = $subject
            Body = $body
            Files = $files
            Diff = $diff
        }
    }
}

# JSON形式で出力（Claude Code Agentsが処理しやすい形式）
$outputFile = "$env:TEMP\temp-commits-$(Get-Date -Format 'yyyyMMddHHmmss').json"
$branchInfoList | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 分析結果:" -ForegroundColor Green
Write-Host "  - ブランチ数: $($tempBranches.Count)" -ForegroundColor Yellow
Write-Host "  - コミット数: $($branchInfoList.Count)" -ForegroundColor Yellow
Write-Host "  - 出力ファイル: $outputFile" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "🤖 Claude Code Agentsで以下を実行してください:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Read $outputFile" -ForegroundColor White
Write-Host "2. 各コミットを分析して適切なメッセージを生成" -ForegroundColor White
Write-Host "3. git rebase -i で書き換え、または新ブランチ作成" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# 情報をクリップボードにもコピー
@"
Claude Code Agentsへの指示:

$outputFile を読み込んで、以下のtempコミットを適切に変換してください：

ブランチ一覧:
$($tempBranches -join "`n")

各コミットの内容を分析し：
1. Conventional Commits形式の適切なメッセージに変換
2. 適切なブランチ名に変更
3. 必要に応じてコミットをまとめる

"@ | Set-Clipboard

Write-Host "✅ 指示をクリップボードにコピーしました" -ForegroundColor Green