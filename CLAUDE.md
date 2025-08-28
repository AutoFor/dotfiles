# Global Rules for Claude Code

## 🛑 最優先ルール: 実行ブレークポイント

### 必ず停止して完了手順を実行するタイミング
**以下の状況を検出したら、即座に停止して完了手順チェックを実行：**

1. **コード変更完了の兆候**
   - `dotnet build` が成功した時
   - `dotnet run` が成功した時
   - ファイルを削除した時
   - ファイルを統合/マージした時
   - テストが成功した時

2. **完了メッセージを出力する前**
   - "完了しました"
   - "成功しました"
   - "統合しました"
   - "実装しました"
   - "修正しました"

3. **ユーザー要求を満たした時**
   - ユーザーの要求した機能が動作した
   - 問題が解決した
   - 質問に回答した後

### 停止時の自動実行プロトコル
```
1. 「✅ タスク完了を検出。完了手順を実行します」と宣言
2. TODOリストがある場合は、すべて完了済みか確認
3. 仕様書とREADME.mdの作成/更新
4. TODOアーカイブ作成（TODOリストがあった場合）
5. git status → git add -A → git commit 実行（すべての変更を1回のコミット）
6. Windows通知送信
```

## ⚡ タスク実行フロー（必須）

### Phase 1: タスク開始時（必須）
```
ユーザー要求受信
↓
TODO必要性判断（3ステップ以上なら必須）
↓
必要ならTodoWriteツール実行
↓
C#開発の場合: CSharp\DebugLogger.csを新規プロジェクトにコピー
↓
タスク実行開始
```

### C#開発時の初期設定
**新規C#プロジェクトを開始する場合は必ず以下を実行：**

1. **DebugLogger.csの自動コピー判定**
   - プロジェクト内に`DebugLogger.cs`が存在するか確認
   - 存在しない場合：`C:\Users\SeiyaKawashima\.claude\CSharp\DebugLogger.cs`を自動コピー
   - 存在する場合：スキップ（既存ファイルを保持）

2. **コピー後の処理（新規コピーの場合のみ）**
   - namespaceをプロジェクトに合わせて変更
   - プロジェクトのメインクラスにロガーを組み込む

```csharp
// 使用例
DebugLogger logger = DebugLogger.Instance;
logger.Info("処理開始");
logger.Debug("デバッグ情報");
logger.Error("エラー発生", exception);
```

```bash
# 自動判定コマンド例（C#プロジェクトルートで実行）
if (!(Test-Path "DebugLogger.cs")) { 
    Copy-Item "C:\Users\SeiyaKawashima\.claude\CSharp\DebugLogger.cs" -Destination "."
    Write-Host "DebugLogger.csをコピーしました"
} else {
    Write-Host "DebugLogger.csは既に存在します（スキップ）"
}
```

### Phase 2: タスク実行中
```
コード変更/ファイル操作
↓
ビルド/テスト実行
↓
成功 → 🛑 ブレークポイント発動 → Phase 3へ
失敗 → 修正して再実行
```

### Phase 3: タスク完了時（必須）
```
🛑 ブレークポイントで停止
↓
完了手順チェックリスト実行:
□ 仕様書作成/更新（docs/specification.md）
□ README.md作成/更新
□ TODOアーカイブ作成（必要な場合）
□ git status 実行
□ git add -A 実行（ドキュメント・TODOアーカイブも含む）
□ git commit 実行（すべての変更を1回でコミット）
□ Windows通知送信
↓
完了
```

## Windows環境での実行ルール

### 🔴 重要: 実行ファイルとコマンドの使い方

#### 絶対に守るべきルール
* **Windows環境では `.\bin\Debug\` のようなパスは使用禁止**
* **実行ファイルを直接実行しようとしない**
* **必ず `dotnet run` コマンドを使用すること**

#### 正しい実行方法
```bash
# ✅ 正しい: dotnet runを使用
dotnet run -- skip
dotnet run -- launch
dotnet run -- activate

# ❌ 間違い: 実行ファイルを直接実行
.\bin\Debug\net8.0\spotifyAutoPlayer.exe skip  # 絶対に使わない！
```

## コーディングルール

### コメントの必須ルール
* **すべてのコードに初心者向けの行末コメントを必ず追加すること**
* 専門用語は避け、わかりやすい日本語で説明
* 処理の意図や目的を明確に記載

### コメントの書き方
```csharp
// 概要: このクラス/関数の主な目的
// サブ概要: より詳細な説明（必要に応じて）
public class Example {
    private int count; // カウンター変数（現在の数を保持）
    
    public void Process() {
        count++; // カウントを1増やす
        if (count > 10) { // 10を超えたら
            Reset(); // リセットする
        }
    }
}
```

### ドキュメント作成の必須ルール
**コーディング完了後、必ず以下のドキュメントを作成すること：**

1. **仕様書 (`docs/specification.md`)**
   - システムの概要と目的
   - 主要機能の詳細説明
   - クラス構成と責務
   - 処理フローの説明
   - 使用している技術・ライブラリの説明

2. **README.md**
   - プロジェクトの概要
   - インストール方法
   - 使用方法（コマンド例を含む）
   - 必要な環境・依存関係
   - トラブルシューティング

## Git コミットルール

### ブランチ戦略
**機能別に必ずブランチを作成すること：**

1. **ブランチ作成タイミング**
   - 新機能の開発開始時
   - バグ修正の開始時
   - リファクタリングの開始時
   - 実験的な変更を行う時

2. **ブランチ命名規則**
   ```bash
   feature/機能名    # 新機能追加
   fix/バグ名        # バグ修正
   refactor/対象名   # リファクタリング
   docs/ドキュメント名 # ドキュメント更新
   ```

3. **ブランチ運用フロー**
   ```bash
   # 1. 新しいブランチを作成して切り替え
   git checkout -b feature/新機能名
   
   # 2. 作業を実施してコミット
   git add -A
   git commit -m "機能追加: ○○を実装"
   
   # 3. mainブランチにマージ（作業完了後）
   git checkout main
   git merge feature/新機能名
   
   # 4. 不要になったブランチを削除
   git branch -d feature/新機能名
   ```

### 自動コミットトリガー
**以下のタイミングで必ずコミット：**
- 1つの機能追加が完了
- バグ修正が1つ完了
- ファイルの削除/統合が完了
- リファクタリングの1段階が完了
- テストの追加・修正が完了

### コミットメッセージ形式
```
機能追加: ○○機能を実装
バグ修正: ○○の問題を修正
リファクタ: ○○を改善
統合: ○○と××を統合
削除: 不要な○○を削除

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## TODOアーカイブルール

### アーカイブ作成トリガー
**TODOリストが存在し、すべて完了した場合は必ず作成**

### 保存先とフォーマット
- 保存先: `docs/todo-archive.md`
- 書き込み方法: **既存のTODOリストセクションがある場合は追記（Append）**
  - 新規作成時: `## TODOリスト` セクションを作成
  - 既存ファイルがある場合: 既存の `## TODOリスト` セクションの末尾に追記
  - タイムスタンプを付けて区別
- 内容:
```markdown
## TODOリスト

### [YYYY-MM-DD HH:mm] タスク名
- [x] 完了項目1 → commit: xxx
- [x] 完了項目2 → commit: yyy
- [x] 完了項目3 → commit: zzz
```

## Windows通知ルール

### 通知送信タイミング
**必ず送信するタイミング：**
- タスク完了時（OK）
- エラー発生時（ERR）
- 警告事項がある時（WARN）

### 実行コマンド
```powershell
# 成功時
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] Claude Code' -Message 'タスク名 完了 (xx件処理)'"

# 警告時
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[WARN] Claude Code' -Message 'タスク名 警告: 内容'"

# 失敗時
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[ERR] Claude Code' -Message 'タスク名 失敗: 原因'"
```

## 📊 実行証跡（ログ）

### タスク完了手順の実行/スキップを記録
**手順を実行しなかった場合、必ず理由を記録：**

```log
=== タスク完了手順チェック ===
[✓] TODO作成: 4項目作成
[✓] git commit: d9031ab
[✗] TODOアーカイブ: スキップ（理由: 技術タスクに集中していた）
[✗] Windows通知: スキップ（理由: 手順を忘れた）

→ 後から補完実行が必要
```

## 🚨 緊急停止ワード

**以下の単語を出力/実行する前に必ず停止：**
- 完了
- 成功
- 終了
- 統合
- 実装完了
- できました
- なりました

**停止後の動作：**
→ 完了手順チェックリストを実行
→ すべてチェックが入ったら続行

## 💡 ベストプラクティス

### やるべきこと
1. タスク開始時にTODOリスト作成を検討
2. こまめにgit commitを実行
3. 完了時は必ず完了手順を実行
4. Windows通知で進捗を報告

### やってはいけないこと
1. 技術的実装だけに集中して手順を忘れる
2. 「完了」と言った後で手順を実行する
3. TODOリストを作らずに複雑なタスクを開始
4. git commitせずに次のタスクに進む

## 📝 クイックリファレンス

### タスク完了時の最短手順
```bash
# 1. 仕様書作成/更新
# docs/specification.mdを作成または更新

# 2. README.md作成/更新
# プロジェクトルートのREADME.mdを作成または更新

# 3. TODOアーカイブ作成（必要な場合）
# docs/todo-archive.mdに追記

# 4. Gitコミット（すべての変更を含む）
git status
git add -A  # ドキュメント・TODOアーカイブも含めてすべて追加
git commit -m "タスク内容"

# 5. Windows通知
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] Claude Code' -Message 'タスク完了'"
```

---
**このルールは最優先で適用され、技術的なタスクよりも優先される**