# skills/ — Claude Code と Codex 共通のスキル置き場 (正本)

スキルはここだけで管理する。`claude/skills` / `codex/skills` / `windows/claude-skills` は廃止した (二重管理で中身がずれていたため)。
SKILL.md は Agent Skills の共通形式なので、同じフォルダを Claude Code と Codex の両方が読める。

## 配備先

| エージェント | ユーザースコープの読み込み先 | 中身 |
| --- | --- | --- |
| Claude Code (CLI / デスクトップ) | `~/.claude/skills/<name>` | `skills/<name>` へのリンク |
| Codex (CLI / アプリ) | `~/.agents/skills/<name>` | 同上 (旧 `~/.codex/skills` のリンクは撤去する) |

フォルダ単位のリンクなので、`~/.claude/skills/synced/` (claude.ai から同期されたスキル) や
手で置いたスキルには触らない。

```bash
bash ~/dotfiles/skills/link-skills.sh          # Linux (devbox)。install.sh からも呼ばれる
```

```powershell
pwsh -File $HOME\ghq\github.com\AutoFor\dotfiles\skills\link-skills.ps1   # Windows。install-windows.ps1 からも呼ばれる
```

## 自動反映 (push すれば各マシンに勝手に届く)

コミットは post-commit フックで即 push される。各マシンは定期的に pull → リンク張り直しを行うので、
スキルの追加・改名・削除・編集はどのマシンでも最大 15 分ほどで反映される (手動の再実行は不要)。

| マシン | 仕組み | 間隔 | ログ |
| --- | --- | --- | --- |
| devbox (Linux) | crontab: `cron-with-pull bash ~/dotfiles/skills/link-skills.sh` (`cloud/azure-devbox/bootstrap.sh` が登録) | 10 分 | `~/.local/state/link-skills.log` / `cron-with-pull.log` |
| Windows (ノート PC / desktop) | タスク `dotfiles-skills-sync` → `skills/sync-skills.ps1` (`register-skills-sync.ps1` が登録。`install-windows.ps1` からも呼ばれる) | ログオン時 + 15 分 | `%LOCALAPPDATA%\dotfiles\skills-sync.log` |

ログには変化があったとき (リンクの追加・撤去・pull 失敗) だけ行が増える。
すぐ反映したいときは手で `link-skills.sh` / `sync-skills.ps1` を叩けばよい。

## 対象を絞る: `.skill-scope`

スキルフォルダに置く。無ければ全 OS・全エージェントに配る。

```
os: windows          # windows / linux
agents: claude       # claude / codex
```

## 書き方の約束 (Windows / Linux・Claude / Codex で差分を出さない)

- 付属ファイルは `~/.claude/skills/...` のような絶対パスで書かず、「この SKILL.md のフォルダ (`<SKILL_DIR>`)」からの相対で書く
- エージェント名を本文に固定で書かない (「Claude が触ったファイル」→「エージェントが触ったファイル」)
- OS 固有のコマンドしか無いスキルは `.skill-scope` で `os:` を絞る
- 片方のエージェントにしか無いツールに依存するスキルは `agents:` を絞るか、ツールが無いときの振る舞いを書く
- 改行は LF (`.gitattributes`)。`.ps1` だけ CRLF
