# 引き継ぎ: Claude Code 通知を Windows で常駐受信する (#224)

devbox 側のセッションから Windows 席へ引き継ぐための作業指示。
残っているのは **Windows ローカルの作業だけ**（BurntToast の導入とスケジュールタスクの修復）。
完了したらこのファイルは削除してよい。

- issue: https://github.com/AutoFor/dotfiles/issues/224
- 続きの機能要望: https://github.com/AutoFor/dotfiles/issues/226（着手は #224 完了後）

## 1. 通知の全体像

Claude Code の `Stop` / `Notification` hook（`claude/settings.json`）が `~/.claude/notify.sh` を呼ぶ。
`notify.sh` は状況を見て経路を選ぶ。

| 経路 | 条件 | 出力先 |
|------|------|--------|
| OSC 1337 SetUserVar | 手元の WezTerm にトーストを出せる | WezTerm がタブに 🔔 + BurntToast トースト（クリックでペインへジャンプ） |
| ntfy プッシュ | 上が出せない | ntfy.sh → Windows / iPhone |

「WezTerm にトーストを出せるか」の判定:

- **tmux 内** — 自セッション（グループセッションなら同一グループ）にクライアントが attach しているか
- **tmux 外** — OSC の書き込み先 tty があるか

この 2 つ目が無かったのが #224 のバグ。Claude Code アプリから devbox に SSH したセッションは
tmux も WezTerm も経由せず tty も無いため、`notify.sh` が何もせず `exit 0` して通知が消えていた。
**この修正自体は完了・マージ済み**（PR #225）。

## 2. 今どこまで動いているか

| 区間 | 状態 |
|------|------|
| devbox の `notify.sh` → ntfy.sh への配信 | ✅ 確認済み。トピックに実際にメッセージが届いている |
| Windows で `ntfy-listen.ps1` を**前面実行**したときのトースト | ✅ 出た |
| Windows の**スケジュールタスク**（常駐）経由のトースト | ❌ `LastTaskResult = 1` で即終了 ← **残作業はここだけ** |

## 3. 原因の見立て

`ntfy-listen.ps1` が `exit 1` するのは 2 箇所だけ。「トピック未設定」と「BurntToast の import 失敗」。
トピックファイルは存在するので、**BurntToast の import 失敗**が濃厚。

根拠は前面実行の verbose 出力:

```
Skipping the Version folder 1.1.0 under Module
  C:\Users\saint\OneDrive\ドキュメント\PowerShell\Modules\BurntToast
  as it does not have a valid module manifest file.
Loading module from path
  'C:\Users\saint\OneDrive\ドキュメント\WindowsPowerShell\Modules\BurntToast\1.1.0\BurntToast.psd1'
```

- PowerShell **7 用**の領域にある BurntToast 1.1.0 は**マニフェスト不正でスキップ**されている
- 実際に読めているのは Windows PowerShell **5.1 用**のユーザー領域にあるコピー
- pwsh 7 の既定の `PSModulePath` に、ユーザーの `Documents\WindowsPowerShell\Modules` は**含まれない**
  （含まれるのは AllUsers 側の `%ProgramFiles%\WindowsPowerShell\Modules` など）

つまり:

- **前面実行が成功した理由** — Windows PowerShell 5.1 から `pwsh` を起動したため、
  5.1 の `PSModulePath` を子プロセスが継承し、5.1 側の BurntToast が見えた
- **タスクが失敗する理由** — タスクは pwsh を素で起動するので `PSModulePath` は既定値のみ。
  7 用の領域のコピーは壊れていて、5.1 側は見えない → import 失敗 → `exit 1`

pwsh から `Get-Module -ListAvailable BurntToast` が**何も返さない**ことも確認済みで、
この見立てと整合している。

OneDrive のファイル オンデマンドでモジュールのファイルがプレースホルダーになっていることが
「マニフェスト不正」の原因の可能性がある。`Documents` が OneDrive にリダイレクトされている。

## 4. やること

### 4-1. BurntToast を PowerShell 7 用に入れ直す

必ず **pwsh 7 のセッションで**実行する（5.1 から入れると 5.1 側に入って同じ状態になる）。
入れ子の `pwsh -Command` は確認プロンプトで固まることがあるので、セッション内で直接叩く。

```powershell
Install-Module BurntToast -Scope CurrentUser -Force -AllowClobber -Verbose
```

`Install-Module` が無ければ PS 7.6 の新しい方:

```powershell
Install-PSResource BurntToast -Scope CurrentUser -TrustRepository
```

壊れたコピーが残って弾かれる場合は先に消す:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\OneDrive\ドキュメント\PowerShell\Modules\BurntToast"
```

**OneDrive 配下でまた壊れるようなら、AllUsers に入れる方が確実**（管理者権限が要る）。
`%ProgramFiles%\PowerShell\Modules` に入るので OneDrive の影響を受けず、
pwsh からもスケジュールタスクからも同じように見える。この構成には本来こちらが向いている。

```powershell
Install-Module BurntToast -Scope AllUsers -Force -AllowClobber
```

### 4-2. 確認

```powershell
Get-Module -ListAvailable BurntToast | Select-Object Version, ModuleBase
```

`ModuleBase` が `...\PowerShell\Modules\BurntToast\...`（`WindowsPowerShell` では**ない**方）か、
`%ProgramFiles%\PowerShell\Modules\...` になっていれば正しい。

### 4-3. タスクを再起動して状態を見る

前面実行の窓が残っていれば `Ctrl+C` で止めてから（どちらがトーストを出したか分からなくなるため）。

```powershell
Start-ScheduledTask ntfy-listen; Start-Sleep 3; Get-ScheduledTaskInfo ntfy-listen | Select-Object LastRunTime, LastTaskResult
```

`LastTaskResult` が `267009`（実行中）になれば成功。`1` のままなら 4-4 へ。

### 4-4. それでも直らない場合

タスクは失敗しても何も残らないので、まず**ログを取れるようにする**。
`windows/bin/ntfy-listen.ps1` の先頭に、起動と失敗理由をファイルへ追記する処理を入れる
（例: `$env:LOCALAPPDATA\ntfy-listen.log`）。`Import-Module` の失敗を握り潰さず理由ごと残すこと。

そのうえで、タスクと同じ条件を手元で再現して切り分ける。
`PSModulePath` を既定値に戻してから実行すると、タスク環境に近づけられる:

```powershell
$env:PSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath','Machine')
pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\saint\ghq\github.com\AutoFor\dotfiles\windows\bin\ntfy-listen.ps1 -Verbose
```

BurntToast の解決が根本的に不安定なら、`ntfy-listen.ps1` 側に
モジュールパスのフォールバック（既知のパスを明示 `Import-Module` する）を入れる案もある。

## 5. 受け入れ条件

**前面実行の窓を閉じた状態で**、devbox から通知を打って Windows にトーストが出ること。

Windows から自分で疎通テストできる:

```powershell
ssh -n devbox "sh ~/.claude/notify.sh 'テスト' 'Windows 常駐の疎通確認'"
```

**`-n` は必須**。`notify.sh` は hook JSON を読むために stdin が tty でないとき `cat` で読み切ろうとする。
`ssh host cmd` は stdin を開いたまま繋ぐので、`-n`（または `</dev/null`）が無いと数秒〜無限に待つ。

ntfy に実際に届いたかは devbox 側で確認できる:

```
curl -fsS "https://ntfy.sh/$(head -n1 ~/.config/ntfy-topic)/json?poll=1&since=10m" | jq -r 'select(.event=="message") | "\(.time) | \(.title) | \(.message)"'
```

通ったら #224 をクローズし、「All Issues」プロジェクト（https://github.com/orgs/AutoFor/projects/6）の
ステータスを Done にする（現在は手動で In Progress にしてある）。

## 6. ついでに確認したいこと

BurntToast が壊れていたのが本当の原因なら、**WezTerm 経由のトースト**
（`claude/windows-notify.ps1`）も同じ理由で出ていなかったはず。
WezTerm の tmux タブで Claude Code を動かして、トーストが出るか・クリックでペインへ飛ぶかを確認しておく。

## 7. 関連ファイル

| ファイル | 役割 |
|----------|------|
| `claude/notify.sh` | devbox 側。経路を選んで OSC か ntfy に流す（#224 で修正済み） |
| `claude/settings.json` | Stop / Notification hook の定義 |
| `claude/windows-notify.ps1` | WezTerm から呼ばれる BurntToast トースト（LaunchUri でジャンプ対応） |
| `windows/bin/ntfy-listen.ps1` | ntfy を購読して BurntToast でトースト化。**今回の主対象** |
| `windows/bin/register-ntfy-listen.ps1` | 上をログオン時常駐に登録（タスク名 `ntfy-listen`） |
| `windows/bin/wezterm-jump.ps1` | `wezterm-jump:` URI ハンドラ。#226 で拡張予定 |
| `windows/.wezterm.lua` | `user-var-changed` で OSC を受けて 🔔 + トースト |
| `docs/qiita/terminal-shortcuts.md` | 仕様の正本。挙動を変えたらここも更新する |

トピック名は Windows 側 `%USERPROFILE%\.config\ntfy-topic`、devbox 側 `~/.config/ntfy-topic`。
両方が同じ値である必要がある（どちらも git 管理外）。

## 8. リポジトリ運用の注意

- `windows/` は Windows のセッションで編集する。`claude/notify.sh` は devbox 側の担当だが、
  今回の残作業では触らない想定
- post-commit フックがコミット即 push する。作業前に `git pull`
- `claude/CLAUDE.md` に他セッションの未コミット変更が残っていることがある。**勝手にコミット・破棄しない**
- コミットメッセージは日本語 + `feat:` / `fix:` / `add:` / `docs:` プレフィックス
- 小さな設定調整は main 直、構造変更は issue → ブランチ → PR
