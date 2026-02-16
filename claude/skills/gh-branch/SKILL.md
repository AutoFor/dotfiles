---
name: gh-branch
description: 作業中の変更内容（diff）から自動で GitHub Issue を作成し、ブランチを作成する（Worktree なし）。main 上の未プッシュコミットがある場合は自動でブランチに移植する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - Skill
  - mcp__github__issue_write
  - mcp__github__create_pull_request
  - mcp__github__get_me
---

# Git ブランチ作成スキル（diff ベース自動命名、Worktree なし）

引数は一切使用しない（渡されても無視する）。
常に現在の変更内容から Issue タイトルを自動生成する。

## 実行フロー

### 1. リポジトリ情報を取得

```bash
git remote -v
```

出力から `owner` と `repo` を特定する。

### 2. 変更内容を分析

以下のコマンドで現在の作業内容を収集する：

```bash
# デフォルトブランチ名を判定
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'

# 変更ファイル一覧
git status --short

# unstaged の差分
git diff

# staged の差分
git diff --cached

# 未プッシュコミット
git log origin/<デフォルトブランチ>..HEAD --oneline
```

**変更が何もない場合**（status が空、diff が空、未プッシュコミットもなし）:
「変更がありません。先にコードを変更してから実行してください。」と表示して **停止する。それ以上何もしない。**

### 3. Issue タイトルを自動生成

ステップ 2 で収集した diff・status・コミットログを分析し、作業内容を要約して日本語で簡潔な Issue タイトルを生成する。

- 例: `hooks設定を新フォーマットに修正`
- 例: `ダークモード対応を追加`
- 例: `ログイン画面のバリデーションを改善`

### 4. GitHub Issue を作成

`mcp__github__issue_write` を使用：
- method: `create`
- owner: （リポジトリオーナー）
- repo: （リポジトリ名）
- title: ステップ 3 で自動生成したタイトル
- body: diff の内容に基づいた作業の概要を簡潔に記載

### 5. ブランチ名を生成

1. ステップ 3 のタイトルを英語スラッグに変換する
   - 小文字、ハイフン区切り、英数字のみ
   - 3〜5単語程度に簡潔にまとめる
   - 例: `hooks設定を新フォーマットに修正` → `fix-hooks-config-format`
2. ブランチ名: `issue-<Issue番号>-<英語スラッグ>`
   - 例: `issue-17-fix-hooks-config-format`

### 6. ブランチを作成

現在のブランチと未プッシュコミットの状態を判定し、適切な方法でブランチを作成する。

#### ケース A: main/master にいて、未プッシュコミットがある場合

```bash
# 現在のブランチを確認
git branch --show-current

# 未プッシュコミットがあるか確認
git log origin/<デフォルトブランチ>..HEAD --oneline
```

コミットがある場合:
```bash
git checkout -b <ブランチ名>        # 現在位置からブランチ作成（コミット含む）
git branch -f <デフォルトブランチ> origin/<デフォルトブランチ>  # main/master を origin にリセット
```

#### ケース B: それ以外（main/master にいてコミットなし、または別ブランチ）

```bash
git checkout -b <ブランチ名>
```

### 7. 変更をコミット

未コミットの変更がある場合、`/smart-commit` スキルを実行してコミットを作成する。

```bash
git status --short
```

変更がなければこのステップをスキップする。

> ⚠️ **重要: smart-commit が完了しても、このスキル（gh-branch）の処理は終わっていない。必ず 7a（push・Draft PR 作成）→ 8（完了メッセージ）へ続行すること。**

### 7a. push して Draft PR を作成

smart-commit で既にコミットがあるため空コミットは不要。

```bash
git push -u origin <ブランチ名>
```

`mcp__github__create_pull_request` で Draft PR を作成する（`draft: true` を指定）：
- title: `WIP: <Issueタイトル>`
- body: `Closes #<Issue番号>\n\n作業中...`
- head: `<ブランチ名>`
- base: main（または master）
- draft: true

**フォールバック:** `mcp__github__create_pull_request` が `draft` パラメータをサポートしない場合：

```bash
gh pr create --draft --title "WIP: <Issueタイトル>" --body "Closes #<Issue番号>

作業中..."
```

### 8. 完了メッセージ

以下の形式で出力する：

**ケース A（コミット移植あり）の場合:**

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>

<デフォルトブランチ> にあった未プッシュコミット（<コミット数>件）をブランチに移植しました。
<デフォルトブランチ> は origin/<デフォルトブランチ> にリセットされました。
```

**ケース B（通常）の場合:**

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
Draft PR: #<PR番号>
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
