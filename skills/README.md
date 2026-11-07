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

スキルを追加・改名・削除したら、各マシンで `git pull` → 上のスクリプトを再実行する
(SKILL.md の中身を変えただけならリンク先が同じなので pull だけでよい)。

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
