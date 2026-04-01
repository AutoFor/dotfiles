---
title: GUIをぐいぐい使ってた人間がVimmerになるためのショートカット＆コマンド集
topics:
  - WezTerm
  - Zsh
  - Neovim
  - WSL
  - ClaudeCode
published: true
---

# GUIをぐいぐい使ってた人間がVimmerになるためのショートカット＆コマンド集

WSL2 + WezTerm + Zsh 環境で使っている、自分がよく忘れるショートカットとコマンドをまとめたメモです。

---

> このショートカット集やプラグイン構成は、以下の方々の記事・動画を大変参考にさせていただいております。
> 多大なる影響を受けました。ありがとうございます。
>
> - **ryoppippi** ([@ryoppippi](https://x.com/ryoppippi)) — [【外資ITエンジニアの開発環境】VimmerによるVimmer(になりたい人)のためのVim動画](https://www.youtube.com/watch?v=XsAlXYWzcv4)
> - **mozumasu** ([@mozumasu](https://x.com/mozumasu)) — [WezTerm をカスタマイズして開発体験を向上させる](https://zenn.dev/mozumasu/articles/mozumasu-wezterm-customization) / [【WezTerm】モテたい人のためのターミナル設定入門](https://www.youtube.com/watch?v=zShNd2J5oMI)
> - **TECH WORLD** ([YouTube チャンネル](https://www.youtube.com/@TECHWORLD111))

---

## 環境

- **ターミナル**: WezTerm（Windows）
- **シェル**: Zsh on WSL2 (Ubuntu)
- **プラグイン**: zoxide, fzf, ghq

各ツールの設定ファイルは https://github.com/AutoFor/dotfiles を参照してください。

---

## WezTerm

Leader キーは `Ctrl+q`（2秒タイムアウト）。

### Workspace

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `<leader> →w` | workspace 一覧を表示して切り替え | **w**orkspace |
| `Alt+E` | 現在の workspace 名を変更 | **E**dit name |
| `<leader> →Shift+W` | 新規 workspace を作成 | **W**orkspace（大文字＝新規） |

### Tab

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Ctrl+t` | 新規タブを開く | ブラウザ由来（**t**ab） |
| `Ctrl+w` | 現在のタブを閉じる | ブラウザ由来（**w**indow close） |
| `Ctrl+Tab` | 次のタブへ移動 | ブラウザ由来 |
| `Ctrl+Shift+Tab` | 前のタブへ移動 | 上記の逆 |
| `Ctrl+1`〜`Ctrl+9` | タブ番号で切り替え（9 は最後のタブ） | 番号＝タブ位置 |
| `Alt+,` | タブを左に移動 | `,` = `<`（左向き）と同キー |
| `Alt+.` | タブを右に移動 | `.` = `>`（右向き）と同キー |
| `Alt+e` | 現在のタブ名を変更 | **e**dit name |

| `<leader> →Shift+P` | PowerShell タブを新規で開く | **P**owerShell |
| `<leader> →l` | ランチャーメニューを表示（PowerShell / WSL 等） | **l**aunch |

### Pane

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `<leader> →r` | ペインを左右に分割 | **r**ight（左右に分かれる） |
| `<leader> →d` | ペインを上下に分割 | **d**own（上下に分かれる） |
| `<leader> →x` | 現在のペインを閉じる | × 印（消す） |
| `Alt+h/l/k/j` | 左/右/上/下のペインへ移動 | vim の hjkl |
| `Ctrl+Shift+[` | ペインを番号で選択 | vim の `[` ナビゲーション慣習 |
| `<leader> →z` | 現在のペインをズーム（トグル） | **z**oom |
| `<leader> →s` → `h/l/k/j` | ペインサイズを調整（Enter で終了） | **s**ize |
| `Alt+n` / `Alt+p` | ペインを次/前に回転して入れ替え | Emacs 由来（**n**ext / **p**revious） |
| `<leader> →p` | ペインをオーバーレイ表示して番号で選択（tmux display-panes 相当） | **p**ane |
| `<leader> →q` | ペイン一覧をオーバーレイ表示（`Esc` で閉じる） | **q**uery（一覧照会） |
| `<leader> →!` | 現在のペインを新規タブに切り出す | tmux の `!`（break-pane）由来 |

### コピーモード（vi ライク）

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `<leader> →[` | コピーモードを起動 | vim の `[` ブラケット慣習 |
| `h/j/k/l` | 左/下/上/右に移動 | vim 由来（ホームポジション） |
| `w` | 次の単語の先頭へ前進 | **w**ord |
| `b` | 前の単語の先頭へ後退 | **b**ackward |
| `e` | 次の単語の末尾へ前進 | **e**nd |
| `E` | 前の単語の末尾へ後退 | vim の `ge` 相当（**e**nd の逆方向） |
| `^ / $` | 行の最初の文字 / 行末に移動 | 正規表現の行頭・行末アンカー |
| `0` | 行の左端に移動 | 列 0（ゼロ番目） |
| `gg / G` | バッファ先頭 / 末尾に移動 | **g**o（gg = 先頭、G = 末尾） |
| `Ctrl+f / Ctrl+b` | 1ページ下/上にスクロール | **f**orward / **b**ackward |
| `Ctrl+d / Ctrl+u` | 半ページ下/上にスクロール | **d**own / **u**p |
| `v` | 文字単位の選択モード | **v**isual |
| `V` | 行単位の選択モード | **V**isual line（大文字＝行単位） |
| `Ctrl+v` | ブロック選択モード | **v**isual block |
| `y` | 選択範囲をクリップボードにコピー | **y**ank（vim 用語） |
| `Enter` | 選択範囲をコピーしてモード終了 | 確定・実行 |
| `q / Escape / Ctrl+c` | コピーモードを終了 | **q**uit / 脱出 |

### その他

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Ctrl+Shift+c` | クリップボードにコピー | OS 標準の **c**opy |
| `Ctrl+Shift+v` | クリップボードから貼り付け | OS 標準の **v** = paste |
| `Ctrl++` | フォントサイズを拡大 | `+` = 増加 |
| `Ctrl+-` | フォントサイズを縮小 | `-` = 減少 |
| `Ctrl+0` | フォントサイズをリセット | 0 = デフォルト（ゼロ点） |
| `Ctrl+p` / `Ctrl+Shift+p` | コマンドパレットを開く | **p**alette（VS Code 由来） |
| `Ctrl+Shift+r` | 設定を再読み込み | **r**eload |
| `Alt+Enter` | フルスクリーン切り替え | Enter = 確定・最大化 |

### WSL ドメイン設定（リサイズ安定化）

WezTerm は `wsl_domains` を明示設定することで、ConPTY 経由ではなく WezTerm ネイティブ WSL 統合を使用できる。
これにより、ウィンドウのリサイズ時に Claude Code などの TUI アプリが固まる問題が軽減される。

```lua
config.wsl_domains = {
  {
    name = "WSL:Ubuntu",
    distribution = "Ubuntu",
    default_cwd = "/home/yourname",
  },
}
config.default_domain = "WSL:Ubuntu"
```

なお、リサイズによる一時的な黒画面が起きた際は `<leader> →z`（ペインズーム）で回避しやすい。

### SSH（Tailscale 経由）

外出先から Tailscale 経由でリモートマシンに接続するとき、通常の `ssh` コマンドの代わりに `wezterm ssh` を使うと、WezTerm のペイン分割などのローカル機能がそのまま使える。

```bash
# 通常の SSH（WezTerm の機能は使えない）
ssh user@tailscale-hostname

# WezTerm SSH（リモート側に WEZTERM_PANE が自動でセットされる）
wezterm ssh user@tailscale-hostname
```

Tailscale の IP（`100.x.x.x`）や MagicDNS 名がそのまま使える。

**なぜ動くか：** `wezterm ssh` は SSH 接続時に WezTerm のマルチプレクサをセットアップし、リモート側に `WEZTERM_PANE` と `WEZTERM_UNIX_SOCKET` を自動でセットする。これにより `wezterm cli split-pane` などのコマンドがリモートからでも動作する。

---

## Zsh キーバインド

### ghq

| ショートカット / コマンド | 動作 | 由来 |
|------------------------|------|------|
| `Ctrl+G` | 管理リポジトリを fzf で絞り込んで即 `cd` | **G**it repo |
| `ghq create <name>` | 新規リポジトリを作成（`~/ghq/` 以下に配置） | create |
| `ghq get <URL>` | リポジトリをクローン（`~/ghq/` 以下に配置） | get = 取得 |
| `ghq list` | 管理リポジトリを一覧表示 | list |
| `ghq list -p` | フルパスで一覧表示 | **p**ath |
| `ghq root` | ghq のルートディレクトリを表示 | root directory |

---

## Zsh コマンド

### zoxide（スマートな `cd`）

| コマンド | 動作 | 由来 |
|---------|------|------|
| `z <キーワード>` | 履歴から部分一致して `cd` | **z**oxide の頭文字 |
| `zi` | fzf で履歴からディレクトリをインタラクティブ選択 | z + **i**nteractive |
| `zoxide query <キーワード>` | ジャンプせずに候補リストだけ確認 | query = 照会 |

よく行くディレクトリは `z` に任せると `cd` を打つより圧倒的に速い。

| コマンド | 動作 | 由来 |
|---------|------|------|
| `cfd` | カレントディレクトリ直下のフォルダを fzf で選んで `cd` | **c**d + **f**zf + **d**irectory |
| `wslpath -u 'C:\...'` | Windows パスを WSL パス（`/mnt/c/...`）に変換 | WSL path **u**nix |
| `wslpath -w '/mnt/c/...'` | WSL パスを Windows パス（`C:\...`）に変換 | WSL path **w**indows |
| `wpath 'C:\...'` | Windows パスを WSL パスに変換して出力 + クリップボードにコピー | **W**indows **path** |
| `wcd 'C:\...'` | Windows パスを WSL パスに変換して `cd` + Claude Code 起動（ファイルパスは親ディレクトリに cd）+ クリップボードにコピー | **W**indows **cd** |

> **注意**: Windows パスを引数に渡す場合は必ずシングルクォートで囲む（例: `wcd 'C:\Temp'`）。バックスラッシュをシェルに解釈させないためシングルクォートが必須。

### Git Worktree

| コマンド | 動作 | 由来 |
|---------|------|------|
| `Alt+W` | `~/.git-worktrees/` 以下の worktree を fzf で選択して `cd` | **W**orktree |
| `gwb` | GitHub Issue 作成 + worktree 作成 + WezTerm 下分割で Claude 起動 | **g**it **w**orktree **b**ranch |
| `gwb r` | 同上・右分割 | **r**ight |
| `gwb d` | 同上・下分割（`gwb` と同じ） | **d**own |
| `gwb t` | 同上・新規タブで worktree ディレクトリに cd | **t**ab |

### pptx-meiryo（PowerPoint フォント変換）

| コマンド | 動作 |
|---------|------|
| `pptx-meiryo <file.pptx>` | 指定した .pptx のすべてのフォントを Meiryo UI に変換（元ファイルを上書き・`.bak` 自動作成） |
| `pptx-meiryo <file.pptx> --output <out.pptx>` | 変換結果を別ファイルに出力 |
| `pptx-meiryo <file.pptx> --no-backup` | バックアップなしで上書き |

WSL パス（`/mnt/c/...`）・Windows パス（`C:\...` / `C:/...`）どちらも受け付ける。
実体は `C:\tools\pptx-meiryo\pptx-meiryo.exe`（PowerPoint COM Interop、要 PowerPoint インストール済み）。

---

## Neovim

Leader キーは `Space`。

### 基本操作

#### 起動・終了

| コマンド | 動作 | 由来 |
|---------|------|------|
| `nvim <ファイル>` | ファイルを指定して起動 | **N**eo**vim** |
| `nvim .` | カレントディレクトリを開いて起動 | `.` = カレントディレクトリ |
| `:qa` | 全ウィンドウを閉じて終了 | **q**uit **a**ll |
| `:qa!` | 未保存の変更を破棄して強制終了 | `!` = 強制 |
| `:wqa` | 全ファイルを保存して終了 | **w**rite + **q**uit **a**ll |

#### ファイル操作

| キー / コマンド | 動作 | 由来 |
|---------------|------|------|
| `:e` | ファイルをディスクから再読み込み（リロード） | **e**dit（再編集＝再読み込み） |
| `:w` | 保存 | **w**rite |
| `:q` | 閉じる | **q**uit |
| `:wq` | 保存して閉じる | **w**rite + **q**uit |
| `:!cp -r /path/to/src /path/to/dst` | 絶対パスでディレクトリを再帰コピー | `!` = シェルコマンド実行、`-r` = 再帰 |
| `:!cp -r /path/to/src .` | カレントディレクトリ直下に同名でコピー | `.` = カレントディレクトリ |

#### WezTerm ペインへの送信

ビジュアル選択中に右隣の WezTerm ペイン（Claude Code 等）へファイルパスと行番号を送信する。

| キー | モード | 動作 | 由来 |
|-----|--------|------|------|
| `<leader>y` | ビジュアル | 選択範囲の `ファイル:行` または `ファイル:開始行-終了行` を右ペインに送信 | **y**ank to pane |

#### 元に戻す／やり直す

| キー | 動作 | 由来 |
|-----|------|------|
| `u` | 元に戻す（Undo） | **u**ndo |
| `Ctrl+r` | やり直す（Redo） | **r**edo |

### 移動・検索・編集

#### 文字削除

| キー | 動作 | 由来 |
|-----|------|------|
| `x` | カーソル下の1文字を削除 | × 印（消す）、または e**x**cise |
| `X` | カーソルの左の1文字を削除 | `x` の逆方向（大文字＝逆） |
| `dw` | 単語を削除（次の単語の先頭まで） | **d**elete **w**ord |
| `db` | 単語を後方に削除 | **d**elete **b**ackward |
| `dd` | 行全体を削除 | **d**elete（dd = 行全体） |
| `D` | カーソルから行末まで削除 | **D**elete to end（大文字＝行末まで） |
| `d0` | カーソルから行頭まで削除 | **d**elete to 0（行頭） |
| `diw` | 単語全体を削除（空白は残す） | **d**elete **i**nner **w**ord |
| `daw` | 単語全体＋前後の空白を削除 | **d**elete **a**round **w**ord |
| `di"` | `"..."` の中身を削除 | **d**elete **i**nner `"` |
| `da"` | `"..."` ごと削除（引用符含む） | **d**elete **a**round `"` |
| `c` 系 | `d` と同じ範囲を削除してインサートモードへ | **c**hange |

`:normal` コマンドを使うと、全行に対してノーマルモードの操作を一括適用できる：

| コマンド | 動作 | 内訳 |
|---------|------|------|
| `:%normal 0x` | 全行の先頭1文字を削除 | `%` = 全行、`0` = 行頭へ移動、`x` = 1文字削除 |

#### 文字移動

| キー | 動作 | 由来 |
|-----|------|------|
| `h` | 左に1文字移動 | vim hjkl（h = 左） |
| `l` | 右に1文字移動 | vim hjkl（l = 右） |
| `0` | 行頭に移動 | 列 0（ゼロ番目） |
| `^` | 行頭の最初の文字に移動 | 正規表現の行頭アンカー |
| `$` | 行末に移動 | 正規表現の行末アンカー |

#### 単語移動

| キー | 動作 | 由来 |
|-----|------|------|
| `w` | 次の単語の先頭へ移動 | **w**ord |
| `b` | 前の単語の先頭へ移動 | **b**ackward |
| `e` | 次の単語の末尾へ移動 | **e**nd |
| `ge` | 前の単語の末尾へ移動 | `e` の逆方向 |
| `W` | 次の WORD 先頭へ移動（空白区切り、`-` 等を含む） | **W**ORD |
| `B` | 前の WORD 先頭へ移動（空白区切り） | **B**ackward WORD |
| `E` | 次の WORD 末尾へ移動（空白区切り） | **E**nd of WORD |

> `w`/`e` は `iskeyword` 定義の単位（`-` で区切られる）、`W`/`E`/`B` はスペースまでを 1 かたまりとして扱う。`apxi-yasdfa-ffff` 全体を一気に選ぶなら `vE`。

#### 行番号移動

| キー / コマンド | 動作 | 由来 |
|---------------|------|------|
| `:行番号` | 指定行へジャンプ（例: `:42`） | `:` = コマンドモード |
| `行番号G` | 指定行へジャンプ（例: `42G`） | **G**o to line |
| `gg` | ファイルの先頭へ | **g**o（gg = 先頭） |
| `G` | ファイルの末尾へ | **G**o（末尾） |
| `数字j` | 現在行から N 行下へ移動（例: `10j`） | j = 下（vim hjkl） |
| `数字k` | 現在行から N 行上へ移動（例: `10k`） | k = 上（vim hjkl） |

#### スクロール

| キー | 動作 | 由来 |
|-----|------|------|
| `Ctrl+f` | 1画面分下にスクロール | **f**orward（1ページ） |
| `Ctrl+b` | 1画面分上にスクロール | **b**ackward（1ページ） |
| `Ctrl+d` | 半画面分下にスクロール | **d**own（半ページ） |
| `Ctrl+u` | 半画面分上にスクロール | **u**p（半ページ） |
| `gg` | ファイルの先頭に移動 | **g**o（先頭） |
| `G` | ファイルの末尾に移動 | **G**o（末尾） |

#### ウィンドウ移動

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>h` | 左のウィンドウに移動 | vim hjkl（h = 左） |
| `<leader>l` | 右のウィンドウに移動 | vim hjkl（l = 右） |
| `<leader>j` | 下のウィンドウに移動 | vim hjkl（j = 下） |
| `<leader>k` | 上のウィンドウに移動 | vim hjkl（k = 上） |
| `<leader>w` | 次のウィンドウに移動（順番に切り替え） | **w**indow |
| `<leader>c` | 現在のウィンドウを閉じる | **c**lose |
| `:q` | 現在のウィンドウを閉じる | **q**uit |
| `Ctrl+Home` | 左のウィンドウに移動（ノーマル・インサート・ターミナルモード共通） | Home = 先頭・左端 |
| `Ctrl+End` | 右のウィンドウに移動（ノーマル・インサート・ターミナルモード共通） | End = 末尾・右端 |

#### ファイル内検索

| キー / コマンド | 動作 | 由来 |
|---------------|------|------|
| `/キーワード` | カーソル以降を前方検索 | `/` = 区切り・検索（vi 由来） |
| `?キーワード` | カーソル以前を後方検索 | `?` = 疑問（逆方向探索） |
| `n` | 次のマッチへ移動 | **n**ext |
| `N` | 前のマッチへ移動 | **N**ext（大文字＝逆方向） |
| `*` | カーソル下の単語を前方検索 | `*` = ワイルドカード（単語全体にマッチ） |
| `#` | カーソル下の単語を後方検索 | `*` の逆（`#` は `*` の隣キー） |
| `:noh` | 検索ハイライトを消す | **no** **h**ighlight |

#### 置換

| キー / コマンド | 動作 | 由来 |
|---------------|------|------|
| `:s/old/new/` | 現在行の最初のマッチを置換 | **s**ubstitute |
| `:s/old/new/g` | 現在行の全マッチを置換 | **g**lobal（行内全置換） |
| `:%s/old/new/g` | ファイル全体の全マッチを置換 | `%` = 全行 + **g**lobal |
| `:%s/old/new/gc` | ファイル全体を1件ずつ確認しながら置換 | **c**onfirm |
| `:'<,'>s/old/new/g` | ビジュアル選択範囲内の全マッチを置換（ビジュアルモードで `:`） | `'<,'>` = 選択範囲 |
| `:%s/\bold\b/new/g` | 単語境界付きで完全一致のみ置換（部分一致を除外） | `\b` = **b**oundary |
| `:%s/old/new/gi` | 大文字小文字を無視して全置換 | **i**gnore case |

確認モード（`c` オプション）の回答キー：

| キー | 動作 |
|-----|------|
| `y` | この箇所を置換 |
| `n` | この箇所をスキップ |
| `a` | 残りを全て置換 |
| `q` | 置換を中止 |
| `l` | この箇所だけ置換して終了 |

使用例：

| やりたいこと | コマンド |
|------------|---------|
| 現在行の `foo` を `bar` に全部置換 | `:%s/foo/bar/g` の代わりに `:s/foo/bar/g` |
| ファイル全体の変数名 `oldName` を `newName` にリネーム | `:%s/oldName/newName/g` |
| `http://` を `https://` に全置換（`/` を含むため区切り文字を変更） | `:%s|http://|https://|g` |
| `class` という単語のみ置換（`classname` などは除外） | `:%s/\bclass\b/Class/g` |
| 1〜10行目だけ置換 | `:1,10s/foo/bar/g` |
| 確認しながら安全に全置換 | `:%s/foo/bar/gc` |
| 選択範囲内の `TODO` を `DONE` に置換（ビジュアルで範囲選択後 `:`） | `:'<,'>s/TODO/DONE/g` |
| `; ` を改行に置換（置換文字列側では `\n` が改行） | `:%s/; /\n/g` |

#### 折りたたみ（fold）

カーソル下の fold 操作：

| キー | 動作 | 由来 |
|-----|------|------|
| `zo` | 1段階だけ開く | **o**pen |
| `zO` | カーソル位置の fold を再帰的にすべて開く | **O**pen all（大文字＝再帰） |
| `zc` | 1段階だけ閉じる | **c**lose |
| `zC` | カーソル位置の fold を再帰的にすべて閉じる | **C**lose all（大文字＝再帰） |
| `za` | fold をトグル（1段階） | **a**lternate |
| `zA` | fold を再帰的にトグル | **A**lternate all（大文字＝再帰） |
| `zv` | カーソル行が隠れていれば必要な分だけ開く | **v**iew cursor line |

ファイル全体の fold 操作：

| キー | 動作 | 由来 |
|-----|------|------|
| `zR` | 全ての fold を開く | **R**educe all folds |
| `zM` | 全ての fold を閉じる | **M**ore folds |

よく使うパターン：

| やりたいこと | 操作 |
|------------|------|
| 今いるメソッド配下を一気に展開 | `zO` |
| 今いるメソッド配下を一気に畳む | `zC` |
| 全部畳んでカーソル行だけ表示 | `zM` → 移動 → `zv` |

### プラグイン

#### Telescope

ファジーファインダー。ファイル名・テキスト・バッファ・履歴などをインクリメンタルに検索できる。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>ff` | ファイル名で検索して開く | **f**ind **f**iles |
| `<leader>fg` | プロジェクト全体をテキスト検索（live grep） | **f**ind **g**rep |
| `<leader>fw` | カーソル下の単語でテキスト検索 | **f**ind **w**ord |
| `<leader>fb` | 開いているバッファ一覧 | **f**ind **b**uffers |
| `<leader>fr` | 最近開いたファイル一覧 | **f**ind **r**ecent |

#### nvim-tree

左サイドバーにファイルツリーを表示するエクスプローラー。

##### ツリー操作

| キー | 動作 | 由来 |
|-----|------|------|
| `Ctrl+n` | ファイルツリーを開閉 | **n**vim-tree |
| `<leader>tf` | nvim-tree にフォーカス（閉じていれば開く） | **t**ree **f**ocus |
| `<leader>ef` | エディタにフォーカスを戻す | **e**ditor **f**ocus |
| `<leader>tR` | ツリーを最新状態に更新 | **t**ree **R**eload（大文字＝更新） |
| `<leader>tr` | カーソル下のディレクトリをルートに変更して再表示 | **t**ree **r**oot |
| `Ctrl+]` | フォルダを nvim-tree 内部のルートに変更（`:pwd` は変わらない） | `]` = 深く潜る（vim 慣習） |
| `W` | ツリー全体を折りたたむ（collapse all） | 大文字で全体操作 |
| `E` | ツリー全体を再帰的に展開（expand all） | 大文字で全体操作 |

##### 絞り込み

| キー | 動作 | 由来 |
|-----|------|------|
| `f` | ファイル名でライブフィルター（絞り込み） | **f**ilter |
| `F` | フィルターをクリア | **F**ilter clear（大文字＝リセット） |

##### ファイル・フォルダ操作

| キー | 動作 | 由来 |
|-----|------|------|
| `a` | 新規ファイル/ディレクトリを作成（末尾に `/` でディレクトリ） | **a**dd |
| `A` | フォルダのみ作成（プロンプトに名前入力） | **A**dd directory（大文字＝ディレクトリ専用） |
| `d` | 削除 | **d**elete |
| `r` | リネーム（パスごと書き換えで移動も可） | **r**ename |
| `m` | ファイル/フォルダをマーク（複数選択）／再度押すと解除 | **m**ark |
| `x` | カット（マーク済みがあれば一括、なければカーソル下を対象） | e**x**cise（切り取り） |
| `c` | コピー（マーク済みがあれば一括、なければカーソル下を対象） | **c**opy |
| `p` | カット/コピーしたファイルをカーソル位置のディレクトリに貼り付け | **p**aste |

> **注意**: `c` / `x` / `p` は同一 Neovim インスタンス内でのみ有効。別ウィンドウの Neovim との間ではクリップボードが共有されないため、ターミナルで `mv` / `cp` コマンドを使う。
>
> ```bash
> mv "ファイルパス" .      # 現在のディレクトリ直下に移動
> cp "ファイルパス" .      # 現在のディレクトリ直下にコピー
> ```

##### ファイルを開く

| キー | 動作 | 由来 |
|-----|------|------|
| `Enter` | ファイルを開く / フォルダを展開 | 確定・実行 |
| `Tab` | フォーカスを保ったままファイルをプレビュー | タブ＝仮表示 |
| `e` | 水平分割で開く | **e**dit horizontal split |

##### パスコピー

| キー | 動作 | 由来 |
|-----|------|------|
| `gy` | 絶対パス（Linux）をクリップボードにコピー | **g**et **y**ank |
| `gW` | Windows パスをクリップボードにコピー（WSL2用） | **g**et **W**indows path |
| `gr` | 相対パスをクリップボードにコピー | **g**et **r**elative path |
| `<leader>y` | ノードのパスを右 WezTerm ペイン（Claude Code 等）に送信 | **y**ank to pane |

#### glow

Markdown をターミナル内でレンダリングしてプレビューするプラグイン。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>md` | 右ペインで glow プレビューを開く（markdown ファイルのみ） | **m**ark**d**own |
| `Alt+q` → `<leader>c` | glow プレビューを閉じる（ターミナルモード抜け → ウィンドウ閉じる） | **q**uit terminal → **c**lose |

#### scratch.nvim

フローティングウィンドウでサッと書ける一時メモ用プラグイン（[reybits/scratch.nvim](https://github.com/reybits/scratch.nvim)）。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>n` | スクラッチパッドを開く / 閉じる | **n**ote |

#### outline.nvim

LSP シンボルや Markdown 見出しをサイドバーにアウトライン表示するプラグイン。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>o` | アウトラインを開閉（Markdown の見出し一覧／LSP シンボル） | **o**utline |

#### octo.nvim

Neovim から GitHub の Issue・PR・Discussion を操作するプラグイン。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>oi` | GitHub Issue 一覧を開く | **o**cto **i**ssue |
| `<leader>op` | GitHub Pull Request 一覧を開く | **o**cto **p**ull request |
| `<leader>od` | GitHub Discussion 一覧を開く | **o**cto **d**iscussion |
| `<leader>on` | GitHub Notification 一覧を開く | **o**cto **n**otification |
| `<leader>oI` | GitHub Issue を作成 | **o**cto **I**ssue create（大文字＝作成） |
| `<leader>os` | Issue/PR を検索 | **o**cto **s**earch |
| `<leader>oC` | Issue をクローズ（Issue バッファ内） | **o**cto **C**lose（大文字） |
| `<leader>oR` | Issue を再オープン（Issue バッファ内） | **o**cto **R**eopen（大文字） |
| `<leader>ola` | ラベルを追加（Issue/PR バッファ内） | **o**cto **l**abel **a**dd |
| `<leader>olr` | ラベルを削除（Issue/PR バッファ内） | **o**cto **l**abel **r**emove |
| `<leader>opa` | 親 Issue を追加（Issue バッファ内） | **o**cto **p**arent **a**dd |
| `<leader>opr` | 親 Issue を解除（Issue バッファ内） | **o**cto **p**arent **r**emove |
| `<leader>ope` | 親 Issue を編集（Issue バッファ内） | **o**cto **p**arent **e**dit |
| `<leader>oca` | 子 Issue を追加（Issue バッファ内） | **o**cto **c**hild **a**dd |
| `<leader>ocr` | 子 Issue を削除（Issue バッファ内） | **o**cto **c**hild **r**emove |

### AI 連携

#### claudecode.nvim

Neovim から Claude Code を操作するプラグイン。右パネルにターミナルを表示し、ファイル追加・選択範囲送信などが行える。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>ac` | Claude Code を開閉（`:Claude` でも可） | **a**i **c**laude |
| `<leader>af` | Claude Code にフォーカス | **a**i **f**ocus |
| `<leader>ab` | 現在のファイルを Claude Code に追加 | **a**i **b**uffer |
| `<leader>as` | 選択範囲を Claude Code に送信（ビジュアルモード） | **a**i **s**end |
| `<leader>av` | 縦分割（vertical）で Claude Code を開く（MCP連携あり） | **a**i **v**ertical |
| `<leader>ah` | 横分割（horizontal）で Claude Code を開く | **a**i **h**orizontal |

#### codex.nvim

Neovim から OpenAI Codex CLI を操作するプラグイン。サイドパネルに Codex ターミナルを表示する。

| キー | 動作 | 由来 |
|-----|------|------|
| `<leader>cx` | Codex を開閉（`:Codex` でも可） | **c**ode**x** |
| `<leader>cf` | Codex にフォーカス（閉じていれば開く） | **c**odex **f**ocus |

#### Claude Code 再起動

Neovim 内の Claude Code は「閉じて再度開く」ことで再起動できる（`claudecode.nvim` の既知仕様）。

| キー / コマンド | 動作 | 由来 |
|---------------|------|------|
| `<leader>ac`（Claude Code フォーカス中） | Claude Code パネルを閉じる（＝セッション終了） | **a**i **c**laude（トグル） |
| `<leader>ac`（閉じた後） | 新しい Claude Code プロセスを起動（＝再起動） | 同上（トグル） |
| `:ClaudeCodeClose` | パネルを明示的に閉じる | コマンド名そのまま |

ターミナル内の Claude Code プロセス自体を再起動したい場合：

| コマンド | 動作 | 由来 |
|---------|------|------|
| `exit` または `Ctrl+D` | Claude Code セッションを終了 | exit / EOF（**D** = end of file） |
| `claude` | 新規セッションで Claude Code を起動 | コマンド名そのまま |
| `claude -r <セッション名>` | 指定セッションで再開 | **r**esume |
| `claude da` | 権限確認をスキップして起動（danger mode） | **da**nger の略 |

#### Claude Code ゾンビプロセス防止

| コマンド / 操作 | 目的 |
|---------------|------|
| `Ctrl+D`（セッション終了時） | 明示的に閉じてゾンビプロセスを防ぐ |
| `ps aux \| grep claude` | 残存する不要な claude プロセスを確認 |

#### Claude Code プロンプト入力

| キー | 動作 | 由来 |
|-----|------|------|
| `Ctrl+J` | プロンプト内で改行（送信せずに次の行へ） | J = 下方向（vim hjkl） |
| `Ctrl+L` | プロンプトをクリアして入力欄を空にする | terminal の clear を連想しやすい |

#### ターミナルモード (Claude Code, Codex)

| キー | 動作 | 由来 |
|-----|------|------|
| `Alt+q` | ターミナルモード → ノーマルモードに戻る | **q**uit terminal mode |
| `Esc+Esc` | ターミナルモードを抜けて左ウィンドウへ移動 | 二度押しで確定（Claude Code → エディタ） |
| `Ctrl+Home` | ターミナルモードを抜けて左ウィンドウへ移動 | Home = 先頭・左端 |
| `Ctrl+End` | ターミナルモードを抜けて右ウィンドウへ移動 | End = 末尾・右端 |

---

## Slack（Windows）

### とりあえずの入口

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Ctrl+/` | ショートカット一覧を表示 | `/` = ヘルプ・コマンド入力の慣習 |
| `Ctrl+K` / `Ctrl+T` | どこでも会話にジャンプ（クイックスイッチャー） | Slack 独自（**K**ey navigation / **T**o channel） |
| `Ctrl+,` | 設定（Preferences）を開く | `,` = 設定・オプションの慣習 |

### ナビゲーション・未読処理

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Ctrl+Shift+A` | 全未読ビューを開く | **A**ll unreads |
| `Alt+↓` / `Alt+↑` | 次/前のチャンネル・DMへ移動 | 矢印キー = 方向 |
| `Alt+Shift+↓` / `Alt+Shift+↑` | 次/前の未読チャンネル・DMへ移動 | Shift = 未読に絞り込み |
| `Ctrl+Shift+L` | チャンネル一覧を開く | **L**ist channels |
| `Ctrl+Shift+K` | DM一覧を開く | Slack 独自（**K**ey = DM） |
| `Ctrl+Shift+M` | メンション/アクティビティを開く | **M**entions |
| `F6` / `Shift+F6` | セクション間フォーカス移動 | F6 = フォーカス移動の慣習 |
| `Esc` | 現在のチャンネル/DMを既読にする | Esc = 離脱・完了 |
| `Shift+Esc` | 全チャンネル・DMを既読にする | Shift = 全体に拡張 |

### スレッド・サイドバー

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Ctrl+Shift+T` | スレッドビューを開く | **T**hreads |
| `Ctrl+.` | 右サイドバーを開閉 | `.` = 右側（`>` の方向） |

### メッセージ入力・編集

| ショートカット | 動作 | 由来 |
|--------------|------|------|
| `Shift+Enter` | 改行のみ（送信せずに次の行へ） | Enter だけだと送信されるため Shift で抑制 |
| `Ctrl+B` | 太字 | **B**old |
| `Ctrl+I` | 斜体 | **I**talic |
| `Ctrl+Shift+X` | 打ち消し線 | × 印（消す） |
| `Ctrl+Shift+9` | 引用 | Slack 独自（`9` に特定の意味なし） |
| `Ctrl+Shift+C` | インラインコード | **C**ode |
| `Ctrl+Alt+Shift+C` | コードブロック | **C**ode block（修飾キーを増やして区別） |
| `Ctrl+Shift+7` | 番号付きリスト | Slack 独自（`7` に特定の意味なし） |
| `Ctrl+Shift+8` | 箇条書きリスト | `Shift+8` = `*`（アスタリスク＝箇条書き記号） |

## Azure CLI

### Azure Key Vault

| 操作 | コマンド |
|------|---------|
| Key Vault 一覧 | `az keyvault list --output table` |
| Key Vault の URL 確認 | `az keyvault show --name <vault-name> --query properties.vaultUri --output tsv` |
| シークレット一覧 | `az keyvault secret list --vault-name <vault-name> --output table` |
| シークレット追加・更新 | `az keyvault secret set --vault-name <vault-name> --name <key> --value <value>` |
| シークレット値を取得 | `az keyvault secret show --vault-name <vault-name> --name <key> --query value --output tsv` |
| シークレット削除 | `az keyvault secret delete --vault-name <vault-name> --name <key>` |

#### このプロジェクトの Key Vault

| 項目 | 値 |
|------|-----|
| Vault 名 | `autofor-kv` |
| URL | `https://autofor-kv.vault.azure.net/` |

```bash
# シークレット追加の例
az keyvault secret set --vault-name autofor-kv --name my-api-key --value "my-secret-value"

# シークレット値を取得する例
az keyvault secret show --vault-name autofor-kv --name my-api-key --query value --output tsv
```
