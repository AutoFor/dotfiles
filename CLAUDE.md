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

## 同期 (push/pull 漏れを作らない)
- post-commit フック (.githooks/post-commit) がコミット即 push する。
  クローンを作り直したら `git config core.hooksPath .githooks` で有効化する
  (既存 2 クローンは設定済み 2026-07-16)
- 作業を始める前・配備の前に `git pull`。pull.rebase + rebase.autostash 設定済みなので
  未コミットの変更が残っていてもそのまま pull してよい
- 自分が触っていないファイルの未コミット変更は他セッションの作業中 WIP。
  勝手にコミット・破棄せず、そのまま残す