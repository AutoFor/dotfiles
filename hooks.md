# Claude Code Hooks Configuration

## User Prompt Submit Hook
```bash
# 編集確認プロンプトの検出と通知
if [[ "$OUTPUT" == *"Do you want to make"* ]] && [[ "$OUTPUT" == *"edits to"* ]]; then
  echo "📝 編集確認プロンプトを検出しました"
  
  # 編集数を抽出
  edit_count=$(echo "$OUTPUT" | grep -oE '[0-9]+ edits?' | grep -oE '[0-9]+')
  file_name=$(echo "$OUTPUT" | grep -oE 'to [^?]+' | sed 's/to //')
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[確認] ファイル編集' -Message '${edit_count}個の編集を${file_name}に適用しますか？'"
fi

# ユーザーが完了を伝えた時にgit操作を促す
if [[ "$1" == *"完了"* ]] || [[ "$1" == *"できた"* ]] || [[ "$1" == *"終わった"* ]] || [[ "$1" == *"終了"* ]]; then
  echo "🔄 完了メッセージを検出 - git操作を推奨します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status && git diff --cached"
fi
```

## Before Edit Hook
```bash
# Editツール使用前の通知
echo "🔔 Editツールを実行します"
# Windows通知送信
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[編集] ファイル変更' -Message 'Editツールでファイルを編集します' -Sound 'Default'"
```

## Before Write Hook  
```bash
# Writeツール使用前の通知
echo "📝 Writeツールを実行します"
# Windows通知送信
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[作成] ファイル作成' -Message 'Writeツールでファイルを作成します' -Sound 'Default'"
```

## Before MultiEdit Hook
```bash
# MultiEditツール使用前の通知
echo "📋 MultiEditツールを実行します"
# Windows通知送信
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[複数編集] ファイル変更' -Message 'MultiEditツールで複数編集を実行します' -Sound 'Default'"
```

## Before Bash Hook
```bash
# ブランチチェック（git操作前に自動実行）
if [[ "$1" == *"git"* ]] && [[ "$1" != *"branch"* ]]; then
  current_branch=$(git branch --show-current 2>/dev/null)
  if [ "$current_branch" = "main" ]; then
    echo "⚠️ WARNING: You are on main branch!"
    echo "Create a feature branch first:"
    echo "  git checkout -b feature/name"
    echo "  git checkout -b fix/name"
    exit 1
  fi
fi
```

## After Bash Hook
```bash
# ビルド成功時の自動処理
if [[ "$1" == *"dotnet build"* ]] && [[ "$OUTPUT" == *"成功"* ]]; then
  echo "✅ Build successful - Auto-generating documentation..."
  
  # 自動で仕様書テンプレートを作成/更新
  if [ ! -f "docs/specification.md" ]; then
    mkdir -p docs
    echo "# 仕様書" > docs/specification.md
    echo "" >> docs/specification.md
    echo "## 概要" >> docs/specification.md
    echo "TODO: プロジェクトの概要を記載" >> docs/specification.md
    echo "" >> docs/specification.md
    echo "## 主要機能" >> docs/specification.md
    echo "TODO: 主要機能を記載" >> docs/specification.md
    echo "" >> docs/specification.md
    echo "## クラス構成" >> docs/specification.md
    echo "TODO: クラス構成を記載" >> docs/specification.md
    echo "" >> docs/specification.md
    echo "⚠️ 仕様書テンプレートを作成しました。内容を更新してください。"
  fi
  
  # README.mdが存在しない場合はテンプレート作成
  if [ ! -f "README.md" ]; then
    echo "# プロジェクト名" > README.md
    echo "" >> README.md
    echo "## インストール" >> README.md
    echo "\`\`\`bash" >> README.md
    echo "dotnet restore" >> README.md
    echo "\`\`\`" >> README.md
    echo "" >> README.md
    echo "## 使用方法" >> README.md
    echo "\`\`\`bash" >> README.md
    echo "dotnet run" >> README.md
    echo "\`\`\`" >> README.md
    echo "" >> README.md
    echo "⚠️ README.mdテンプレートを作成しました。内容を更新してください。"
  fi
fi

# ビルド・テスト成功時の自動git操作トリガー
if [[ "$OUTPUT" == *"Build succeeded"* ]] || [[ "$OUTPUT" == *"ビルドが成功"* ]] || [[ "$OUTPUT" == *"ビルドに成功しました"* ]] || [[ "$OUTPUT" == *"0 Error(s)"* ]] || [[ "$OUTPUT" == *"0 エラー"* ]] || [[ "$OUTPUT" == *"0 個の警告"* && "$OUTPUT" == *"0 エラー"* ]]; then
  echo "✅ ビルド成功を検出 - git操作を自動実行します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status && git diff --cached"
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] ビルド成功' -Message 'ビルドが正常に完了しました'"
fi

if [[ "$OUTPUT" == *"All tests passed"* ]] || [[ "$OUTPUT" == *"テスト成功"* ]] || [[ "$OUTPUT" == *"tests passed"* ]] || [[ "$OUTPUT" == *"passed"* && "$OUTPUT" == *"test"* ]]; then
  echo "✅ テスト成功を検出 - git操作を自動実行します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status && git diff --cached"
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] テスト成功' -Message 'テストが正常に完了しました'"
fi

# npm/yarn系のビルド・テスト成功検出
if [[ "$1" == *"npm run build"* ]] || [[ "$1" == *"yarn build"* ]] || [[ "$1" == *"npm test"* ]] || [[ "$1" == *"yarn test"* ]]; then
  if [[ "$OUTPUT" != *"error"* ]] && [[ "$OUTPUT" != *"failed"* ]] && [[ "$OUTPUT" != *"Error"* ]]; then
    echo "✅ ビルド/テスト成功 - git操作を自動実行します"
    echo "以下のコマンドを実行してください:"
    echo "git add -A && git status"
    
    # Windows通知送信
    powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] NPM/Yarn成功' -Message 'ビルド/テストが正常に完了しました'"
  fi
fi

# タスク完了キーワード検出時の自動ドキュメントチェック
if [[ "$OUTPUT" == *"タスク完了"* ]] || [[ "$OUTPUT" == *"作業完了"* ]] || [[ "$OUTPUT" == *"実装完了"* ]]; then
  echo "📝 タスク完了を検出 - ドキュメントをチェックします"
  
  # ドキュメントの存在チェック
  docs_exist=0
  [ -f "docs/specification.md" ] && docs_exist=$((docs_exist+1))
  [ -f "README.md" ] && docs_exist=$((docs_exist+1))
  
  if [ $docs_exist -eq 2 ]; then
    echo "✅ ドキュメント確認済み - コミットを推奨します"
    echo "以下のコマンドを実行してください:"
    echo "git add -A && git commit -m 'タスク完了: ドキュメント更新を含む'"
    
    # Windows通知送信
    powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] タスク完了' -Message 'ドキュメント確認済み。コミットの準備ができました。'"
  else
    echo "⚠️ ドキュメントが不足しています。作成してください。"
  fi
fi
```

## After Edit Hook
```bash
# 編集完了通知
echo "✅ ファイル編集が完了しました"

# mainブランチでの編集警告
current_branch=$(git branch --show-current 2>/dev/null)
if [ "$current_branch" = "main" ]; then
  echo "⚠️ WARNING: 現在mainブランチで作業しています！"
  echo "featureブランチの作成を推奨します:"
  echo "  git checkout -b feature/名前"
  
  # Windows通知送信（警告）
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[WARNING] mainブランチ' -Message 'mainブランチで編集しています。featureブランチの作成を推奨します。' -Sound 'Reminder'"
fi

# 編集回数をカウント（環境変数またはファイルで管理）
EDIT_COUNT_FILE="/tmp/claude_edit_count_$$"
if [ -f "$EDIT_COUNT_FILE" ]; then
  EDIT_COUNT=$(cat "$EDIT_COUNT_FILE")
  EDIT_COUNT=$((EDIT_COUNT + 1))
else
  EDIT_COUNT=1
fi
echo "$EDIT_COUNT" > "$EDIT_COUNT_FILE"

# 3ファイル以上編集したら自動でgit操作を促す
if [ "$EDIT_COUNT" -ge 3 ]; then
  echo "📝 複数ファイル編集を検出 ($EDIT_COUNT ファイル) - git操作を推奨します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status && git diff --cached"
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[INFO] 複数ファイル編集' -Message '$EDIT_COUNT ファイルを編集しました。git操作を推奨します。'"
  
  rm -f "$EDIT_COUNT_FILE"  # カウントリセット
else
  echo "📝 ファイル編集完了 ($EDIT_COUNT/3 ファイル編集済み)"
fi

# 特定のファイルパターンを編集したら自動git操作
if [[ "$OUTPUT" == *"package.json"* ]] || [[ "$OUTPUT" == *"requirements.txt"* ]] || [[ "$OUTPUT" == *".csproj"* ]]; then
  echo "⚠️ 依存関係ファイルが変更されました - git操作を推奨します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status"
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[WARNING] 依存関係更新' -Message '依存関係ファイルが変更されました'"
fi

# README.mdやドキュメント編集後は自動git操作
if [[ "$OUTPUT" == *"README.md"* ]] || [[ "$OUTPUT" == *"/docs/"* ]] || [[ "$OUTPUT" == *"specification.md"* ]]; then
  echo "📚 ドキュメント更新を検出 - git操作を推奨します"
  echo "以下のコマンドを実行してください:"
  echo "git add -A && git status && git commit -m 'docs: ドキュメント更新'"
  
  # Windows通知送信
  powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[INFO] ドキュメント更新' -Message 'ドキュメントが更新されました'"
fi
```