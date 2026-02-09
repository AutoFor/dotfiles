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
| `/github-finish` | 作業完了時の PR・Issue 作成フロー | 「作業が完了した」「PRを作成したい」 |
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
5. プルリクエスト & Issue 作成
6. PR マージ後に Worktree 削除

---

## 📋 GitHub 運用ルール

**詳細は `/github-finish` スキルを参照してください。**

### 作業完了後の必須手順

作業（テーマ）が完了したら、以下の順序で実行：

1. プルリクエスト作成
2. イシュー作成
3. PR と Issue を紐づけ
4. ユーザーに確認を依頼
5. PR 承認とマージ（ユーザー承認後）
6. Issue クローズ
7. master ブランチに戻る
8. リモートの最新状態を取得

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