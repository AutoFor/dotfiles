# AI-Powered Intelligent Commit Script
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
$diff = git diff --cached
$changedFiles = @(git diff --cached --name-only)
$stats = git diff --cached --stat

# 変更内容を制限（大きすぎる場合）
$diffPreview = $diff | Select-Object -First 500

# AI分析用のプロンプト作成
$analysisPrompt = @"
以下のGit変更を分析し、適切なコミットメッセージとブランチ名を生成してください。

【変更ファイル】
$($changedFiles -join "`n")

【変更統計】
$stats

【差分内容（抜粋）】
$diffPreview

【要求事項】
1. 変更の本質的な目的を理解する
2. Conventional Commits形式で記述
3. 実装の意図と影響を考慮
4. 以下のJSON形式で返答：

{
  "type": "feat|fix|docs|style|refactor|test|chore",
  "scope": "影響範囲（オプション）",
  "description": "簡潔な説明（50文字以内）",
  "branch_name": "適切なブランチ名",
  "summary": "変更の詳細説明"
}
"@

# Claude APIを呼び出す（Anthropic API使用例）
$apiKey = $env:ANTHROPIC_API_KEY
if (-not $apiKey) {
    Write-Host "⚠️ ANTHROPIC_API_KEY環境変数が設定されていません" -ForegroundColor Yellow
    Write-Host "フォールバック: ルールベースコミットを使用" -ForegroundColor Yellow
    & "C:\Users\SeiyaKawashima\.claude\smart-commit.ps1"
    exit 0
}

# API リクエスト作成
$headers = @{
    "x-api-key" = $apiKey
    "anthropic-version" = "2023-06-01"
    "content-type" = "application/json"
}

$body = @{
    model = "claude-3-haiku-20240307"
    max_tokens = 500
    messages = @(
        @{
            role = "user"
            content = $analysisPrompt
        }
    )
} | ConvertTo-Json -Depth 10

try {
    # API呼び出し
    Write-Host "🤖 AIが変更内容を分析中..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
        -Method Post `
        -Headers $headers `
        -Body $body

    # レスポンスからJSON抽出
    $content = $response.content[0].text
    $jsonMatch = [regex]::Match($content, '\{[^}]+\}')
    
    if ($jsonMatch.Success) {
        $result = $jsonMatch.Value | ConvertFrom-Json
        
        # コミットメッセージ生成
        $commitMessage = "$($result.type)"
        if ($result.scope) {
            $commitMessage += "($($result.scope))"
        }
        $commitMessage += ": $($result.description)"
        
        # ブランチ処理
        $currentBranch = git branch --show-current
        if ($currentBranch -eq 'main' -or $currentBranch -eq 'master') {
            git checkout -b $result.branch_name
            Write-Host "✅ ブランチ作成: $($result.branch_name)" -ForegroundColor Green
        }
        
        # コミット実行
        git commit -m $commitMessage
        
        # 結果表示
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "✅ AIコミット完了" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "📝 メッセージ: $commitMessage" -ForegroundColor Yellow
        Write-Host "🌿 ブランチ: $(git branch --show-current)" -ForegroundColor Blue
        Write-Host "💡 要約: $($result.summary)" -ForegroundColor Magenta
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    }
    else {
        throw "JSON解析失敗"
    }
}
catch {
    Write-Host "⚠️ AI分析失敗: $_" -ForegroundColor Red
    Write-Host "フォールバック: ルールベースコミットを使用" -ForegroundColor Yellow
    & "C:\Users\SeiyaKawashima\.claude\smart-commit.ps1"
}