# dotfiles 運用ルール

## リポジトリ戦略 (2 クローン)
- Windows: `C:\Users\saint\ghq\github.com\AutoFor\dotfiles` (ghq 管理) / devbox: `~/dotfiles`
- 両クローンが main に直コミットする。小さな設定調整は main 直、構造変更は issue → ブランチ → PR
- コミットメッセージは日本語 + `feat:`/`fix:`/`add:`/`docs:` プレフィックス

## 編集席 (どちらのマシンで編集するか)
- `windows/` は Windows のセッションで編集する (WezTerm・PowerShell スクリプト等)
- `linux/` は devbox のセッションで編集する (tmux・zsh・~/.local/bin 等)
- 両側にまたがる機能は 1 つのセッションで完結させてコミットし、
  反対側へは push → pull で配備する (Windows 席から ssh で devbox に配備するのも可)

## rpa VM (pull 専用の消費者)
- rpa (UiPath 用 Windows Server) は**編集席ではない**。コミット主体を増やさないため、
  pull するだけの消費者として扱う。編集は上の 2 席で行う
- クローンは `C:\dotfiles`。配備は rpa の SSH セッション内で
  `pwsh -File C:\dotfiles\windows\bin\rpa-deploy.ps1` を実行する
  (clone/pull → 配備 → 構文チェック → タスク登録まで行う)
- スケジュールタスクが読むファイルは作業ツリー内に置かず `C:\ProgramData\` へ配備する。
  作業ツリーは改行変換やフィルタの影響を受けるため
- **rpa 上で動く .ps1 は UTF-8 BOM 付きで保存する。** BOM が無いとタスクが呼ぶ
  Windows PowerShell 5.1 が ANSI として読み、日本語コメントが化けて構文エラーになり、
  スクリプトが起動すらしない (2026-08-26 に `rpa-idle-shutdown.ps1` で発生)

## 同期 (push/pull 漏れを作らない)
- post-commit フック (.githooks/post-commit) がコミット即 push する。
  クローンを作り直したら `git config core.hooksPath .githooks` で有効化する
  (既存 2 クローンは設定済み 2026-07-16)
- 作業を始める前・配備の前に `git pull`。pull.rebase + rebase.autostash 設定済みなので
  未コミットの変更が残っていてもそのまま pull してよい
- 自分が触っていないファイルの未コミット変更は他セッションの作業中 WIP。
  勝手にコミット・破棄せず、そのまま残す