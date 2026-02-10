# Claude Code グローバルルール

## 🎯 コア原則
- **簡潔性**: 必要最小限の指示のみ記載
- **自動化**: 繰り返し作業は自動化

---

## 📚 Claude Code Skills

繰り返し実行される作業は **Claude Code Skills** として定義されています。

### 利用可能なグローバルスキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/git-worktree-branch` | Git Worktree を使った新規ブランチ作成 | 「新しい機能を追加したい」「作業を開始したい」 |
| `/github-pr-create` | PR と Issue の作成・紐付け | 「作業が完了した」「PRを作成したい」 |
| `/github-pr-approve` | PR の承認・マージと後処理 | 「PRを承認する」「マージして」 |
| `/github-finish` | PR 作成から承認まで一気に実行 | 「全部やって」「一気に完了させて」 |
| `/japanese-comments` | TypeScript/JavaScript コードに日本語コメント追加 | 「コードを書いて」「実装して」 |

スキルは `~/.claude/skills/` に保存されています。

---

## 🔒 Git Worktree 運用ルール

**詳細は `/git-worktree-branch` スキルを参照してください。**

### ⚠️ 重要な原則
- **master（main）ブランチで直接コード修正を行わない**
- 改修作業を開始する前に、必ず新しいブランチを作成する
- ブランチ名の命名規則: `feature/機能名` または `fix/修正内容`

### 基本フロー

1. Git Worktree でブランチ作成
2. Worktree ディレクトリに移動
3. コード修正
4. コミット & プッシュ
5. `/github-pr-create` で PR・Issue 作成
6. `/github-pr-approve` で PR マージ・後処理

---

## 📋 GitHub 運用ルール

作業完了時は、2つのスキルを順番に実行します。

### ステップ1: PR・Issue 作成 (`/github-pr-create`)

**詳細は `/github-pr-create` スキルを参照してください。**

作業完了時に実行：

1. プルリクエスト作成
2. イシュー作成
3. PR と Issue を紐づけ
4. ユーザーに確認を依頼

### ステップ2: PR 承認・マージ (`/github-pr-approve`)

**詳細は `/github-pr-approve` スキルを参照してください。**

ユーザー承認後に実行：

1. PR 承認とマージ
2. Issue クローズ
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