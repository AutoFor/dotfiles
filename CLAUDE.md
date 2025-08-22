# Global Rules for Claude Code

## コーディング中のルール

### コメントの必須ルール
* **すべてのコードに初心者向けの行末コメントを必ず追加すること**
* 専門用語は避け、わかりやすい日本語で説明
* 処理の意図や目的を明確に記載

### コメントの書き方

#### 概要コメント（ファイル/クラス/関数の冒頭）
```
// 概要: このファイル/クラス/関数の主な目的
// サブ概要: より詳細な説明（必要に応じて）
// 使用例: 具体的な使用方法（必要に応じて）
```

#### 行末コメント
```
var result = calculateTotal(items); // 商品リストから合計金額を計算
if (result > 1000) { // 合計が1000円を超えた場合
    applyDiscount(); // 割引を適用する
}
```

#### 複雑な処理のコメント
```
// ステップ1: データの前処理
preprocessData(); // 不要な空白や特殊文字を削除

// ステップ2: バリデーション
validateInput(); // 入力値が正しい形式かチェック

// ステップ3: メイン処理
processMain(); // 実際の処理を実行
```

### コメント記載の優先順位
1. **変数宣言** - 何を格納するのか説明
2. **条件分岐** - なぜその条件なのか説明
3. **ループ処理** - 何を繰り返すのか説明
4. **関数呼び出し** - 何をするのか説明
5. **エラー処理** - どんなエラーに対処するのか説明

### 良いコメントの例
```csharp
// 概要: Spotifyの自動再生を管理するクラス
// サブ概要: キーボードショートカットの送信とウィンドウ制御を行う
public class SpotifyController {
    private IntPtr windowHandle; // Spotifyウィンドウのハンドル（識別子）
    
    // 概要: 次の曲にスキップする
    // サブ概要: Shift+→キーを送信して5秒早送りを実行
    public void SkipToNext() {
        SendKeys(VK_SHIFT, VK_RIGHT); // Shift+右矢印キーを送信
    }
}
```

## タスク完了後の必須手順（ステップバイステップ）

### 🔴 重要: 以下の順番を必ず守ること

#### Step 1: Git コミット
1. `git status` で変更ファイルを確認
2. 機能単位で `git add` を実行（選択的ステージング）
3. `git commit -m "機能説明"` でコミット
4. 複数の機能がある場合は Step 1 を繰り返す

#### Step 2: TODOアーカイブ作成
1. `docs/todo-archive/` ディレクトリを作成（なければ）
2. `YYYY-MM-DD_HH-MM_タスク概要.md` ファイルを作成
3. TODOリスト、変更ファイル、コミットハッシュを記録
4. 実施詳細を記載

#### Step 3: アーカイブのコミット
1. `git add docs/todo-archive/[作成したファイル]`
2. `git commit -m "[TODO完了] タスク名のアーカイブ"`

#### Step 4: Windows通知
1. 成功時: `[OK] Claude Code` タイトルで通知
2. 警告時: `[WARN] Claude Code` タイトルで通知
3. 失敗時: `[ERR] Claude Code` タイトルで通知

### チェックリスト
- [ ] すべての変更をコミットしたか
- [ ] TODOアーカイブを作成したか
- [ ] アーカイブをコミットしたか
- [ ] Windows通知を送信したか

### Git コミットルール詳細

#### 必須ルール
* **すべてのタスク完了後に必ず git commit すること**
* **機能ごとに新しいブランチを作成して作業すること**
* **細かい単位でこまめにコミットすること**

#### ブランチ戦略
* 新機能: `feature/機能名`
* バグ修正: `fix/修正内容`
* リファクタリング: `refactor/対象`
* ドキュメント: `docs/内容`

#### コミットのタイミング
* 1つの機能追加が完了したら即コミット
* バグ修正が1つ完了したら即コミット
* リファクタリングの1段階が完了したら即コミット
* テストの追加・修正が完了したら即コミット

#### 複数ファイル変更時のルール
* **複数ファイルが変更されていても、機能単位で分割してコミット**
* 関連する変更のみを `git add` で選択的にステージング
* 例：
  - UIの変更とロジックの変更は別コミット
  - 新機能とそのテストは同じコミット
  - リファクタリングと機能追加は別コミット
* コミット前に `git status` で確認し、無関係な変更は次のコミットへ

#### コミットメッセージ
* 日本語で簡潔に記述
* 何を変更したかを明確に記載
* 例: "ユーザー認証機能を追加", "ログイン処理のバグを修正"

### TODOアーカイブルール詳細

#### 必須ルール
* **すべてのTODO完了時に必ずアーカイブファイルを作成すること**
* アーカイブは `docs/todo-archive/` ディレクトリに保存
* ファイル名: `YYYY-MM-DD_HH-MM_タスク概要.md`

#### アーカイブ内容フォーマット
```markdown
# TODO完了レポート: [タスク名]

## TODOリスト
- [x] 完了項目1 → commit_hash: "コミットメッセージ1" (YYYY-MM-DD HH:MM)
- [x] 完了項目2 → commit_hash: "コミットメッセージ2" (YYYY-MM-DD HH:MM)
- [x] 完了項目3 → commit_hash: "コミットメッセージ3" (YYYY-MM-DD HH:MM)
- [ ] 未完了項目（あれば）

```

#### Git連携
* アーカイブファイルも必ずコミット対象に含める
* コミットメッセージに `[TODO完了]` タグを付ける

### Windows通知ルール詳細

#### 通知の原則
* すべてのタスク実行後に Windows 通知を出すこと
* 通知は **1〜2行で簡潔に**（結論＋要点）
* 詳細はログファイルに記録し、本文ではログパスを示す

#### 実行コマンド例
```powershell
# PowerShell経由で実行すること（必須）
# 成功
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[OK] Claude Code' -Message 'タスク名 完了 (xx件処理)'"

# 警告
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[WARN] Claude Code' -Message 'タスク名 警告: 詳細 log\xxx.warn.log'"

# 失敗
powershell -Command "& 'C:\Users\SeiyaKawashima\.claude\windows-notify.ps1' -Title '[ERR] Claude Code' -Message 'タスク名 失敗: 原因要確認 (log\xxx.err.log)'"
```

#### 通知フォーマット
* Title は `[OK] / [WARN] / [ERR] Claude Code` の3択
* Message は「タスク名＋結果＋要点」まで
* 長文は `-MessageFile` を使いログに出す
* 音は必要に応じて `-Sound` で調整