# Intelligent Git Commit Agent Script
param()

# 変更内容を取得
$status = git status --porcelain
if (-not $status) {
    Write-Host "変更なし"
    exit 0
}

# git add実行
git add -A

# 変更内容の詳細を取得
$diff = git diff --cached
$changedFiles = git diff --cached --name-only
$stats = git diff --cached --stat

# AIエージェント用プロンプト作成
$prompt = @"
以下のGit変更内容を分析して、適切なコミットメッセージを生成してください：

変更ファイル:
$changedFiles

変更統計:
$stats

差分（最初の500行）:
$($diff | Select-Object -First 500)

要件:
1. Conventional Commits形式で記述
2. 日本語で簡潔に（50文字以内）
3. 変更の本質を正確に表現
4. プレフィックス: feat/fix/docs/style/refactor/test/chore

出力形式:
prefix: 変更内容の簡潔な説明
"@

# Claude APIを呼び出す（または別の方法でAIに問い合わせ）
# ここは実装に応じて調整が必要
$commitMessage = "feat: インテリジェントコミット機能を追加"  # デモ用

# ブランチ戦略
$currentBranch = git branch --show-current
if ($currentBranch -eq 'main' -or $currentBranch -eq 'master') {
    # メインブランチの場合は新ブランチ作成
    $branchName = "feature/$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git checkout -b $branchName
    Write-Host "✅ 新ブランチ作成: $branchName"
}

# コミット実行
git commit -m $commitMessage
Write-Host "✅ コミット完了: $commitMessage"