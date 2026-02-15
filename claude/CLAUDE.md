# Claude Code グローバルルール

## コア原則
- **簡潔性**: 必要最小限の指示のみ記載
- **自動化**: 繰り返し作業は自動化

---

## Claude Code Skills

繰り返し実行される作業は **Claude Code Skills** として定義されています。

### 利用可能なグローバルスキル

#### Git Worktree スキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/gh-worktree-branch` | 新規 Issue + ブランチ作成 | 「新しい機能を追加したい」「作業を開始したい」 |
| `/gh-worktree-from-issue` | **既存Issue**からブランチ作成 | 「Issue #123から作業したい」「既存のIssueで作業する」 |

#### GitHub PR スキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/gh-pr-create` | PR作成（ブランチ名からIssue検出） | 「作業が完了した」「PRを作成したい」 |
| `/gh-pr-approve` | PR の承認・マージと後処理 | 「PRを承認する」「マージして」 |
| `/gh-finish` | 一気にマージまで実行（ブランチ作成も自動判定） | 「全部やって」「一気に完了させて」「ブランチ作成から全部やって」 |

#### コーディングスキル

| スキル名 | 説明 | 呼び出し方法 |
|---------|------|------------|
| `/japanese-comments` | TypeScript/JavaScript コードに日本語コメント追加 | 「コードを書いて」「実装して」 |

スキルは `~/.claude/skills/` に保存されています。

---

## GitHub 運用ルール

### 作業の開始方法（2パターン）

#### パターン1: 既存Issueから作業を開始

**`/gh-worktree-from-issue` スキルを使用**

1. Issue番号を指定（例: `/gh-worktree-from-issue 123`）または対話的に選択
2. Issueタイトルから自動でブランチ名を生成（`feature/issue-123-xxx`形式）
3. Git Worktreeを作成し、Draft PR を自動作成して作業開始

**メリット:**
- Issue番号がブランチ名に含まれる → PR作成時に自動検出
- 既存の課題管理と連携しやすい
- Draft PR により作業の可視化・CI の早期実行が可能

#### パターン2: 新規作業から開始（Issue-first）

**`/gh-worktree-branch` スキルを使用**

1. 作業内容を引数で指定（例: `/gh-worktree-branch ダークモード追加`）
2. GitHub Issue を自動作成
3. ブランチ名 `issue-<番号>-<スラッグ>` で Git Worktree を作成し、Draft PR を自動作成して作業開始

**メリット:**
- 作業開始時に必ず Issue が存在する
- ブランチ名に Issue 番号が含まれる → PR作成時に自動検出
- Draft PR により作業の可視化・CI の早期実行が可能

### 作業完了時の手順

#### ステップ1: PR 作成から承認・マージまで (`/gh-pr-create`)

**詳細は `/gh-pr-create` スキルを参照してください。**

作業完了時に実行：

1. ブランチ名から Issue 番号を検出
2. Issue の存在を確認
3. 既存の Draft PR を検索し、Ready for Review に変更（Draft PR がない場合は新規 PR を作成）
4. 自動で `/gh-pr-approve` を呼び出して承認・マージまで進む

#### （参考）PR 承認・マージ (`/gh-pr-approve`)

**詳細は `/gh-pr-approve` スキルを参照してください。**

`/gh-pr-create` から自動で呼び出される：

1. PR 承認とマージ
2. Issue クローズ（自動）
3. master ブランチに戻る
4. リモートの最新状態を取得
5. Worktree 削除（使用時のみ）

---

## コーディング規約

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

## 推奨ファイル構造
```
project/
├── docs/
│   ├── specification.md    # 仕様書
│   └── todo-archive.md     # 完了TODOのアーカイブ
├── README.md               # プロジェクト説明
└── src/                    # ソースコード
```
