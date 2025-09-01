# Smart Git Commit Script with Intelligent Message Generation
param()

function Get-CommitType {
    param($diff, $files)
    
    # ファイル拡張子から判定
    $extensions = $files | ForEach-Object { [System.IO.Path]::GetExtension($_) }
    
    # 差分内容から判定
    if ($diff -match '(bug|fix|error|修正|エラー|バグ)') { return 'fix' }
    if ($diff -match '(feat|feature|add|新機能|追加|実装)') { return 'feat' }
    if ($diff -match '(test|spec|テスト)' -or $extensions -contains '.test.js' -or $extensions -contains '.spec.ts') { return 'test' }
    if ($diff -match '(doc|readme|仕様|ドキュメント)' -or $extensions -contains '.md') { return 'docs' }
    if ($diff -match '(refactor|clean|リファクタ|整理)') { return 'refactor' }
    if ($diff -match '(style|format|フォーマット)') { return 'style' }
    if ($diff -match '(perf|performance|パフォーマンス|高速化)') { return 'perf' }
    if ($diff -match '(chore|build|ci|設定)') { return 'chore' }
    
    return 'feat'  # デフォルト
}

function Get-CommitScope {
    param($files)
    
    # 共通のディレクトリを見つける
    $dirs = $files | ForEach-Object { Split-Path $_ -Parent } | Select-Object -Unique
    
    if ($dirs.Count -eq 1) {
        $scope = Split-Path $dirs[0] -Leaf
        if ($scope -and $scope -ne '.') {
            return "($scope)"
        }
    }
    
    # ファイル名から推測
    $components = $files | ForEach-Object { 
        $name = [System.IO.Path]::GetFileNameWithoutExtension($_)
        if ($name -match '^[A-Z]') { $name }  # Componentっぽいもの
    } | Select-Object -Unique -First 1
    
    if ($components) {
        return "($components)"
    }
    
    return ""
}

function Get-CommitDescription {
    param($type, $files, $diff)
    
    $fileCount = $files.Count
    $firstFile = [System.IO.Path]::GetFileNameWithoutExtension($files[0])
    
    # タイプ別のメッセージ生成
    switch ($type) {
        'feat' {
            if ($fileCount -eq 1) { return "${firstFile}の機能を追加" }
            return "${fileCount}個のファイルに新機能を追加"
        }
        'fix' {
            if ($diff -match 'null|undefined|error') { return "エラー処理を修正" }
            if ($fileCount -eq 1) { return "${firstFile}のバグを修正" }
            return "${fileCount}個のファイルのバグを修正"
        }
        'docs' {
            if ($files -contains 'README.md') { return "READMEを更新" }
            return "ドキュメントを更新"
        }
        'test' {
            return "テストを追加・更新"
        }
        'refactor' {
            if ($fileCount -eq 1) { return "${firstFile}をリファクタリング" }
            return "コードをリファクタリング"
        }
        'style' {
            return "コードスタイルを修正"
        }
        'perf' {
            return "パフォーマンスを改善"
        }
        'chore' {
            return "設定・ビルド関連の更新"
        }
        default {
            return "コードを更新"
        }
    }
}

# メイン処理
$status = git status --porcelain
if (-not $status) {
    Write-Host "変更なし"
    exit 0
}

# 現在のブランチ確認
$currentBranch = git branch --show-current
$isMainBranch = ($currentBranch -eq 'main' -or $currentBranch -eq 'master')

# git add実行
git add -A

# 変更内容を分析
$diff = git diff --cached
$changedFiles = @(git diff --cached --name-only)
$stats = git diff --cached --stat

# コミットタイプを判定
$commitType = Get-CommitType -diff $diff -files $changedFiles

# スコープを判定
$commitScope = Get-CommitScope -files $changedFiles

# 説明を生成
$commitDescription = Get-CommitDescription -type $commitType -files $changedFiles -diff $diff

# コミットメッセージは常に"temp"
$commitMessage = "temp"

# メインブランチの場合は一時ブランチ作成
if ($isMainBranch) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $branchName = "temp/${timestamp}"
    
    git checkout -b $branchName
    Write-Host "✅ 一時ブランチ作成: $branchName" -ForegroundColor Green
}

# コミット実行
git commit -m $commitMessage

# 結果表示
Write-Host "" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ コミット完了" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📝 メッセージ: $commitMessage" -ForegroundColor Yellow
Write-Host "🌿 ブランチ: $(git branch --show-current)" -ForegroundColor Blue
Write-Host "📊 変更: $($changedFiles.Count)ファイル" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan