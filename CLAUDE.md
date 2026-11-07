# dotfiles 運用ルール

## 起点は devbox だけ (2026-11-07〜)
- **編集・コミットは devbox のクローン `~/dotfiles` (= `~/ghq/github.com/AutoFor/dotfiles`) だけで行う。**
  `windows/` も `skills/` も devbox で編集する。設計と経緯は `docs/devbox-as-source-of-truth.md`
- 小さな設定調整は main 直、構造変更は issue → ブランチ → PR
- コミットメッセージは日本語 + `feat:`/`fix:`/`add:`/`docs:` プレフィックス

## Windows のクローンは pull 専用の消費者
- 対象: ノート PC (aura) `C:\Users\saint\ghq\github.com\AutoFor\dotfiles`、
  desktop `C:\Users\SeiyaKawashima\ghq\github.com\AutoFor\dotfiles`、rpa `C:\dotfiles`
- ここでは編集・コミットしない。`.githooks/pre-commit` が Windows でのコミットを拒否する
  (どうしても必要なときだけ `DOTFILES_ALLOW_WINDOWS_COMMIT=1 git commit ...`、その後 devbox で pull して確かめる)
- pull は `--ff-only` (`pull.ff=only` + `merge.autoStash=true`)。`skills/sync-skills.ps1` が 15 分ごとに設定・pull する。
  rpa は `rpa-deploy.ps1` が設定する
- Windows のセッションで dotfiles を直したくなったら、その場で編集せず devbox のセッションに渡す
- 自動でコミットする処理も devbox 側で行う (例: voice-input.ps1 の辞書提案は ssh devbox で追記・コミット)

## Windows でしか確かめられないもの
- devbox で編集 → コミット (即 push) → `ssh desktop` で pull して確かめる。直すなら devbox に戻って直す
  - desktop の ssh は ローカル管理者 seiya。pull は `git -c safe.directory=* -C /c/Users/SeiyaKawashima/ghq/github.com/AutoFor/dotfiles pull`
  - .ps1 の構文チェック: `[System.Management.Automation.Language.Parser]::ParseFile(...)`
- ノート PC (aura) には sshd が無く devbox から入れない。自動 pull で追従するので、画面での確認はユーザーに頼む
- rpa は起動してから `ssh rpa` → `pwsh -File C:\dotfiles\windows\bin\rpa-deploy.ps1`
  (clone/pull → 配備 → 構文チェック → タスク登録まで行う)
- スケジュールタスクが読むファイルは作業ツリー内に置かず `C:\ProgramData\` へ配備する。
  作業ツリーは改行変換やフィルタの影響を受けるため
- **rpa 上で動く .ps1 は UTF-8 BOM 付きで保存する。** BOM が無いとタスクが呼ぶ
  Windows PowerShell 5.1 が ANSI として読み、日本語コメントが化けて構文エラーになり、
  スクリプトが起動すらしない (2026-08-26 に `rpa-idle-shutdown.ps1` で発生)。
  devbox で編集したら `head -c3 <file> | xxd` で `efbbbf` を確かめる

## 同期 (push/pull 漏れを作らない)
- post-commit フック (.githooks/post-commit) がコミット即 push する。
  クローンを作り直したら `git config core.hooksPath .githooks` で有効化する
  (devbox は bootstrap.sh、Windows は sync-skills.ps1 / rpa-deploy.ps1 が入れる)
- devbox では作業を始める前に `git pull`。pull.rebase + rebase.autostash 設定済みなので
  未コミットの変更が残っていてもそのまま pull してよい
- 自分が触っていないファイルの未コミット変更は他セッションの作業中 WIP。
  勝手にコミット・破棄せず、そのまま残す

## スキル (Claude Code / Codex 共通)
- 正本はリポジトリ直下の `skills/<name>/` だけ。`~/.claude/skills` (Claude Code) と `~/.agents/skills` (Codex) にはフォルダ単位のリンクを置く
  (Linux はシンボリックリンク、Windows はジャンクション)。詳細は `skills/README.md`
- 各マシンは定期的に pull → リンク張り直しを自動で行う (devbox: cron 10 分 / Windows: タスク `dotfiles-skills-sync` ログオン時 + 15 分)。
  コミットすれば手動の配備は不要。新しいマシンでは install.sh / install-windows.ps1 を一度流せば登録される
- desktop は Claude を使うユーザーが SeiyaKawashima (SSH 用の seiya とは別)。そのユーザーのクローン
  `C:\Users\SeiyaKawashima\ghq\github.com\AutoFor\dotfiles` を、ローカル管理者 seiya の S4U タスクが pull → link する
  (Entra ID アカウントでは S4U が動かないため。登録コマンドは `skills/register-skills-sync.ps1` の先頭コメント)
- `~/.claude/skills/` で直接スキルを作らない。作ったら devbox の `skills/` に移して link し直す
