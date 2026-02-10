# Claude Code グローバルルール

## 🎯 コア原則
- **簡潔性**: 必要最小限の指示のみ記載
- **自動化**: 繰り返し作業は自動化

---

## 📚 Claude Code Skills

繰り返し実行される作業は **Claude Code Skills** として定義されています。

### 利用可能なグローバルスキル

#### Git Worktree スキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/git-worktree-branch` | 新規作業用のブランチ作成 | 「新しい機能を追加したい」「作業を開始したい」 |
| `/git-worktree-from-issue` | **既存Issue**からブランチ作成 🆕 | 「Issue #123から作業したい」「既存のIssueで作業する」 |

#### GitHub PR スキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/github-pr-create` | PR作成（既存Issue自動検出） | 「作業が完了した」「PRを作成したい」 |
| `/github-pr-approve` | PR の承認・マージと後処理 | 「PRを承認する」「マージして」 |
| `/github-finish` | PR 作成から承認まで一気に実行 | 「全部やって」「一気に完了させて」 |

#### コーディングスキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/japanese-comments` | TypeScript/JavaScript コードに日本語コメント追加 | 「コードを書いて」「実装して」 |

スキルは `~/.claude/skills/` に保存されています。

---

## 📋 GitHub 運用ルール

### 作業の開始方法（2パターン）

#### パターン1: 既存Issueから作業を開始 🆕

**`/git-worktree-from-issue` スキルを使用**

1. Issue番号を指定（例: `/git-worktree-from-issue 123`）または対話的に選択
2. Issueタイトルから自動でブランチ名を生成（`feature/issue-123-xxx`形式）
3. Git Worktreeを作成して作業開始

**メリット:**
- Issue番号がブランチ名に含まれる → PR作成時に自動検出
- 既存の課題管理と連携しやすい

#### パターン2: 新規作業から開始（従来通り）

**`/git-worktree-branch` スキルを使用**

1. 作業内容を確認（機能追加 or バグ修正）
2. ブランチ名を提案（`feature/xxx` or `fix/xxx`）
3. Git Worktreeを作成して作業開始

### 作業完了時の手順

#### ステップ1: PR・Issue 作成 (`/github-pr-create`)

**詳細は `/github-pr-create` スキルを参照してください。**

**既存Issue自動検出機能:**
- ✅ 会話履歴やブランチ名から既存Issue番号を自動検出
- ✅ **既存Issueがある場合**: 新規Issue作成をスキップして既存Issueに紐付け
- ✅ **既存Issueがない場合**: 新規Issue作成（従来通り）

作業完了時に実行：

1. 既存Issue番号の検出（会話履歴・ブランチ名）
2. プルリクエスト作成
3. Issueの作成または既存Issue確認
   - 既存Issueがある → スキップ
   - 既存Issueがない → 新規作成
4. PR と Issue を紐づけ
5. ユーザーに確認を依頼

#### ステップ2: PR 承認・マージ (`/github-pr-approve`)

**詳細は `/github-pr-approve` スキルを参照してください。**

ユーザー承認後に実行：

1. PR 承認とマージ
2. Issue クローズ（自動）
3. master ブランチに戻る
4. リモートの最新状態を取得
5. Worktree 削除（使用時のみ）

---

## 💻 コーディング規約

**詳細は `/japanese-comments` スキルを参照してください。**

### コメント規約
- TypeScript/JavaScript コードには日本語の行末コメントを追加
- 初心者にも理解できる平易な説明を心がける
- すべての重要な行にコメントを付ける

### 例
```typescript
function parseData(input: string): Data {  // 入力文字列をデータ形式に変換
    const parser = new Parser();  // パーサーを初期化
    return parser.parse(input);  // パース結果を返す
}
```

---

## 📁 推奨ファイル構造
```
project/
├── docs/
│   ├── specification.md    # 仕様書
│   └── todo-archive.md     # 完了TODOのアーカイブ
├── README.md               # プロジェクト説明
└── src/                    # ソースコード
```