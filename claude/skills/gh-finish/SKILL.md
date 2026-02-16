---
name: gh-finish
description: 作業完了時に一気にマージまで実行する。ブランチ上なら PR 作成→マージ、main 上なら Issue・ブランチ作成から PR マージまで自動判定。
disable-model-invocation: false
user-invocable: true
allowed-tools:
  - Skill
  - Bash
---

# GitHub 作業完了スキル（自動判定版）

現在のブランチ状態を判定し、適切なフローを自動選択して作業完了→マージまでを一気に行う。

## 絶対禁止事項

- `gh pr review --approve` は絶対に使用しないこと
- Bash で直接 PR 承認やマージを行わないこと。必ず `/gh-pr-approve` を Skill ツールで呼び出す
- サブスキルの処理を自分で再実装しないこと。必ず Skill ツールで委譲する
- 直接 `git add && git commit` を実行しないこと。未コミットの変更は `/smart-commit` を使う

## 実行手順

### 0. 現在のブランチを判定

```bash
git branch --show-current
```

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

- 現在のブランチがデフォルトブランチ（main/master）**である** → **フロー A** へ
- 現在のブランチがデフォルトブランチ**でない** → **フロー B** へ

---

## フロー A: main/master 上にいる場合（ブランチ作成から）

### A-1. Skill ツールで `/gh-branch` を呼び出す

```
Skill ツール: skill = "gh-branch"
```

gh-branch が以下を実行する：
1. 変更内容を分析して日本語 Issue タイトルを自動生成
2. GitHub Issue を作成
3. ブランチを作成（未プッシュコミットの移植含む）
4. `/smart-commit` で変更をコミット
5. プッシュして Draft PR を作成

> ⚠️ **重要: gh-branch が完了しても、このスキル（gh-finish）の処理は終わっていない。必ず A-2 → ステップ 1 へ続行すること。**

### A-2. ステップ 1 へ合流

→ **ステップ 1** へ進む。

---

## フロー B: feature ブランチ上にいる場合

### B-0. 未コミット・未プッシュの変更を確認

```bash
git status --short
git log @{u}..HEAD --oneline 2>/dev/null
```

- **未コミットの変更がある場合** → B-1 へ
- **未プッシュのコミットがある場合** → `git push` してステップ 1 へ
- **すべてコミット・プッシュ済み** → ステップ 1 へ

### B-1. Skill ツールで `/smart-commit` を呼び出す

```
Skill ツール: skill = "smart-commit"
```

> ⚠️ **重要: smart-commit が完了しても、このスキル（gh-finish）の処理は終わっていない。必ず以下の push → ステップ 1 へ続行すること。**

完了したらプッシュする：

```bash
git push -u origin $(git branch --show-current)
```

→ **ステップ 1** へ進む。

---

## ステップ 1（共通）: Skill ツールで `/gh-pr-create` を呼び出す

> ⚠️ **重要: ここに到達したら、必ず以下の `/gh-pr-create` を呼び出すこと。前のサブスキルが完了しただけでは gh-finish は完了していない。**

```
Skill ツール: skill = "gh-pr-create"
```

gh-pr-create が内部で以下を実行する：
1. ブランチ名から Issue 番号を抽出
2. Issue の存在を確認
3. 既存 Draft PR があれば Ready for Review に変更、なければ新規 PR 作成
4. PR と Issue を `Closes #<Issue番号>` で紐付け
5. 自動で `/gh-pr-approve` を呼び出して承認・マージまで進む

**注意:** gh-pr-create は内部で gh-pr-approve を自動呼び出しするため、このスキルから別途承認処理を実行する必要はない。

## 使い分け

- **段階的に進めたい場合**: `/gh-pr-create` → 確認 → `/gh-pr-approve`
- **一気に完了させたい場合**: `/gh-finish`（このスキル）

## 注意事項

- このスキルは確認なしで自動的に PR をマージする
- main 上の場合は Issue・ブランチも自動作成される
- 慎重に確認したい場合は各スキルを個別に実行すること
