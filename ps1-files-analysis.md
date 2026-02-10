# PowerShell ファイル分析結果

## 復元したファイル
- `windows-notify.ps1` - Windows通知機能（hooks.mdで使用）
- `hooks.md` - Hook設定ドキュメント

## 現在存在するPowerShellファイル一覧

### 1. 通知関連 ✅ **必要**
- `windows-notify.ps1` - Windows通知機能
  - hooks.mdから参照されている
  - **保持推奨**

### 2. タグ・セッション管理系
- `auto-tag-on-stop.ps1` - Stopフック時のタグ生成
  - `cleanup-prompts.ps1`を呼び出している
- `auto-tag-session.ps1` - セッション中のコミット履歴からタグ生成
- `smart-tag.ps1` - 作業マイルストーン管理
- `smart-tag-hook.ps1` - userPromptSubmitフックから呼び出し
  - `smart-tag.ps1`を呼び出している

### 3. プロンプト管理系
- `save-prompt.ps1` - プロンプト保存
- `cleanup-prompts.ps1` - 古いプロンプト削除
  - `auto-tag-on-stop.ps1`から呼び出される

### 4. Git操作系
- `smart-branch.ps1` - 自動ブランチ名生成・作成
- `smart-commit.ps1` - 自動コミットメッセージ生成
- `convert-temp-commits.ps1` - Tempコミットの変換

## 推奨される対応

現在のスキル設定（`/git-worktree-branch`, `/github-pr-create`, `/github-pr-approve`, `/github-finish`, `/japanese-comments`）と照らし合わせると：

### 削除候補
以下のファイルは現在のスキル設定では使用されていません：

1. **タグ管理系（5ファイル）**
   - `auto-tag-on-stop.ps1`
   - `auto-tag-session.ps1`
   - `smart-tag.ps1`
   - `smart-tag-hook.ps1`
   - `cleanup-prompts.ps1`（auto-tag-on-stopから呼ばれる）

2. **プロンプト保存**
   - `save-prompt.ps1`

3. **Git操作系（3ファイル）**
   - `smart-branch.ps1`（Git Worktreeスキルで代替）
   - `smart-commit.ps1`（GitHubスキルで代替）
   - `convert-temp-commits.ps1`

### 保持するファイル
- `windows-notify.ps1` - hooks.mdで使用
- `hooks.md` - Hook設定ドキュメント

**合計削除対象: 9ファイル**
