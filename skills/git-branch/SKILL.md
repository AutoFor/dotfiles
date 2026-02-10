---
name: git-branch
description: 新しい作業を開始するときに GitHub Issue を作成し、ブランチを作成する（Worktree なし）。main 上の未プッシュコミットがある場合は自動でブランチに移植する。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Bash
  - mcp__github__issue_write
  - mcp__github__get_me
---

# Git ブランチ作成スキル（Issue-first、Worktree なし）

## 引数の処理

- **引数なし** (`/git-branch`): 「作業内容を伝えてください」と表示して **停止する。それ以上何もしない。**
- **引数あり** (`/git-branch ダークモード対応`): 引数を Issue タイトルとして使用し、以下のフローを実行する。

## 実行フロー（引数ありの場合）

### 1. リポジトリ情報を取得

```bash
git remote -v
```

出力から `owner` と `repo` を特定する。

### 2. GitHub Issue を作成

`mcp__github__issue_write` を使用：
- method: `create`
- owner: （リポジトリオーナー）
- repo: （リポジトリ名）
- title: ユーザーの引数をそのまま使用
- body: 作業の概要を簡潔に記載

### 3. ブランチ名を生成

1. ユーザーの引数を英語スラッグに変換する
   - 小文字、ハイフン区切り、英数字のみ
   - 3〜5単語程度に簡潔にまとめる
   - 例: `ダークモード追加` → `add-dark-mode`
2. ブランチ名: `issue-<Issue番号>-<英語スラッグ>`
   - 例: `issue-17-add-dark-mode`

### 4. ブランチを作成

現在のブランチと未プッシュコミットの状態を判定し、適切な方法でブランチを作成する。

#### ケース A: main/master にいて、未プッシュコミットがある場合

```bash
# デフォルトブランチ名を判定（main または master）
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'

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

### 5. 完了メッセージ

以下の形式で出力する：

**ケース A（コミット移植あり）の場合:**

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>

<デフォルトブランチ> にあった未プッシュコミット（<コミット数>件）をブランチに移植しました。
<デフォルトブランチ> は origin/<デフォルトブランチ> にリセットされました。
```

**ケース B（通常）の場合:**

```
処理が終了しました。

Issue: #<Issue番号> - <Issueタイトル>
ブランチ: <ブランチ名>
```

**これ以上何も出力しない。コード編集・次のステップの提案は一切しない。**
