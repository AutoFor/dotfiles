# dotfiles の起点を devbox に一本化する

対象: AutoFor/dotfiles。作成 2026-11-07。

## 1. 今の構成 (2026-11-07 時点)

| マシン | クローン | 役割 | コミット | 自動 pull |
|---|---|---|---|---|
| devbox (Linux) | `~/dotfiles` → `~/ghq/github.com/AutoFor/dotfiles` | 編集席 | main 直 (post-commit で即 push) | cron `cron-with-pull` (5〜15 分、link-skills は 10 分) |
| ノート PC aura (Windows 11, ユーザー saint) | `C:\Users\saint\ghq\github.com\AutoFor\dotfiles` | 編集席 | main 直 (post-commit で即 push) | タスク `dotfiles-skills-sync` (ログオン時 + 15 分) |
| desktop (Windows 11, Claude は Entra ID の SeiyaKawashima) | `C:\Users\SeiyaKawashima\ghq\github.com\AutoFor\dotfiles` | 実質は消費者 (ルール上は明記なし) | 可能 (hooksPath 設定済み) | seiya の S4U タスク `dotfiles-skills-sync` |
| rpa (Windows Server) | `C:\dotfiles` | pull 専用 | しない (ルールのみ) | `rpa-deploy.ps1` を手で実行 |

- 正本は GitHub の main。devbox と aura が対等に直コミットしている。
- 「Windows のことは Windows のセッションで編集する」(CLAUDE.md の「編集席」) ので、Windows で会話を始めることになり、Windows が起点に見えてしまう。
- SSH の到達性 (確認済み): devbox → desktop は可。devbox → rpa は VM が止まっていると不可 (起動すれば可)。devbox → aura は不可 (aura に sshd が無い。`~/.ssh/config` に `Host aura` はあるが待ち受けていない)。

## 2. 目標の構成

- **編集・コミットは devbox だけで行う。** `windows/` も `skills/` も devbox のクローンで編集する。
- Windows のクローン (aura・desktop・rpa) は **すべて pull 専用の消費者**。
- 消費者でコミットしようとすると pre-commit フックが拒否する。どうしても必要なとき (devbox が落ちている等) は `DOTFILES_ALLOW_WINDOWS_COMMIT=1` で上書きできる。
- 消費者の pull は `--ff-only` にする (`pull.ff=only`、`pull.rebase=false`、`merge.autoStash=true`)。
  - 理由: 消費者にはローカルのコミットが無い前提なので、早送りできないこと自体が異常。rebase だとローカルのコミットを黙って積み直して押し出してしまうが、ff-only なら pull が失敗してログ (`skills-sync.log` の `pull NG`) に残り、気づける。
  - 未コミットの変更 (誤って直接いじったファイル) は autostash で退避・復元されるので、pull は止まらない (衝突したときだけ NG になる)。
- devbox は今のまま `pull.rebase=true` + `rebase.autostash=true` (自分が唯一の書き手なので rebase が要るのは GitHub 上で直接編集したときだけ)。

## 3. 仕組み

### 3.1 pre-commit フック (`.githooks/pre-commit`、新規)

- Git for Windows の sh で動く (`uname -s` が `MINGW*` / `MSYS*` / `CYGWIN*`、または `$OS = Windows_NT`) ときだけ拒否する。Linux では何もしない。
- メッセージ例: 「このクローンは pull 専用です。devbox (`ssh devbox` → `~/dotfiles`) で編集・コミットしてください。どうしても必要なら `DOTFILES_ALLOW_WINDOWS_COMMIT=1 git commit ...`」
- `--no-verify` で抜けられるのは git の仕様。誤操作を防ぐのが目的なので、それで十分とする。
- フックを効かせるには `core.hooksPath .githooks` が要る。aura・desktop は設定済み。rpa は `rpa-deploy.ps1`、新しい Windows マシンは `install-windows.ps1` が設定するようにする (下記 3.2)。

### 3.2 消費者の git 設定を配備スクリプトで入れる

`install-windows.ps1` / `rpa-deploy.ps1` / `skills/sync-skills.ps1` のどれかで、クローンのローカル設定として次を入れる (冪等):

```
git config core.hooksPath .githooks
git config pull.ff only
git config pull.rebase false
git config merge.autoStash true
```

- `sync-skills.ps1` は 15 分ごとに動くので、ここで毎回入れておくと既存のクローン (aura・desktop) にも自動で行き渡る。手作業は要らない。
- desktop は seiya の S4U タスクが SeiyaKawashima のクローンに対して実行するので、`-c safe.directory=...` を付けて `git config` する (pull と同じやり方)。

### 3.3 自動 pull (変えない)

- devbox: cron `cron-with-pull` (変更なし。コメントの「Windows 側でコミットした修正」だけ直す)
- aura・desktop: `dotfiles-skills-sync` (変更なし。pull が ff-only 設定に従うだけ)
- rpa: これまでどおり `rpa-deploy.ps1` を手で実行 (自動化はこの指示書の範囲外)
- スキルのリンク張り直し (`link-skills.sh` / `link-skills.ps1`) には手を入れない。

## 4. Windows 側でしか確かめられないものを devbox から扱う

基本の流れ: **devbox で編集 → コミット (即 push) → `ssh desktop` で pull して確かめる。** 直す必要があれば devbox に戻って直す。Windows 側のファイルは直接いじらない。

| 対象 | devbox での確認 | desktop での確認 (`ssh desktop`、シェルは pwsh か bash) |
|---|---|---|
| `.ps1` 全般 | BOM の有無: `head -c3 f.ps1 \| xxd` (rpa で動くものは `ef bb bf` 必須)。pwsh を devbox に入れれば構文チェックもできる (任意: `sudo apt install powershell` または snap) | `git -C <clone> pull` のあと `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('<path>',[ref]$null,[ref]$e); $e"` で構文チェック。5.1 で動くものは `powershell.exe` でも同様に |
| タスク登録 (`register-*.ps1`) | 中身のレビューのみ | 登録・状態確認は desktop で: `schtasks /query /tn <name> /fo list`、`Get-ScheduledTaskInfo`。S4U 登録は管理者 (seiya) で実行 |
| WezTerm (`windows/.wezterm.lua`) | Lua の構文: `luac -p` (任意で lua を入れる) | `wezterm.exe show-keys` などで設定を読み込ませ、エラーが出ないか見る。見た目の確認は画面の前で (ユーザー) |
| `install-windows.ps1` | レビューのみ | desktop で実行して確かめられる。ただし SeiyaKawashima のホーム向けかは注意 (seiya で入ると seiya のホームに入る) |
| rpa 向け (`rpa-*.ps1`) | BOM チェック | rpa を起動 (`rpa` スキル) → devbox から `ssh rpa` → `pwsh -File C:\dotfiles\windows\bin\rpa-deploy.ps1` |
| ノート PC aura 固有のもの | — | devbox から入れない (sshd が無い)。pull は自動 (15 分) なので、確認はユーザーが aura の前で行うか、aura の Claude セッションに「確認だけ (編集・コミットしない)」で頼む |

- aura に sshd を入れれば (`windows/bin/setup-sshd.ps1`、`Host aura` は devbox 側に既にある) desktop と同じ扱いにできる。入れるかは別判断。
- Windows で Claude と話していて dotfiles を直したくなったら、その場で編集せず、devbox のセッションに渡す (指示を書いて `ssh devbox` のセッションへ)。

## 5. 移行手順

1. この指示書を `docs/devbox-as-source-of-truth.md` として devbox のクローンでコミットする。
2. aura に残っている未コミットの変更 (下記 6) を、決めた分だけ devbox のクローンに写してコミットする。写し終えたら aura 側の変更を戻す (中身は devbox 経由で pull されて同じになる)。
3. devbox で実装をコミット:
   - `CLAUDE.md` の「リポジトリ戦略」「編集席」「同期」を devbox 一本の書き方に書き換える
   - `.githooks/pre-commit` を追加、`.githooks/post-commit` のコメントを直す
   - `skills/sync-skills.ps1` (と `install-windows.ps1`・`rpa-deploy.ps1`) に消費者の git 設定を入れる処理を足す
   - `cron-with-pull` のコメントを直す
4. 確認:
   - devbox: コミットできる、post-commit で push される
   - desktop: 15 分以内 (または `ssh desktop` で手動 pull / タスク手動実行) に追従、`git config pull.ff` が `only`、試しのコミットが拒否される
   - aura: 15 分以内に追従、試しのコミットが拒否される (このセッションで確かめる)
   - rpa: 次に起動したとき `rpa-deploy.ps1` で設定が入る (今回は VM が止まっているので未確認になる)

## 6. aura に残っている未コミットの変更 (他セッションの WIP)

| ファイル | 内容 | 案 |
|---|---|---|
| `windows/powershell/Microsoft.PowerShell_profile.ps1` (未追跡) | pwsh プロファイル: zoxide 初期化、Ctrl+G で ghq + fzf のリポジトリ移動 | 取り込む |
| `install-windows.ps1` | 上のプロファイルを `ドキュメント\PowerShell\` にリンク | 取り込む |
| `README.md` | winget に fzf・zoxide を追加 | 取り込む |
| `windows/.ssh/config` | `Host desktop` (MagicDNS 名・User seiya) を追加 | 取り込む |
| `windows/.gitconfig` | user.name/email を実名 (noreply) に、credential を `seiya-kawashima` + gh の credential helper に | 取り込む (ユーザー判断)。gh のパス (`C:\Program Files\GitHub CLI`) は全 Windows 機で決め打ちになる |

→ 2026-11-07 にすべて devbox からコミット済み (87bff7a・e50e374)。aura 側は戻して pull し、同じ内容になっている。

devbox 側にも他セッションの WIP がある (`claude/settings.json`、`skills/linear-session-link/SKILL.md`)。これは devbox で作業中のものなので触らない。

## 7. Windows で自動コミットしていた処理

- `windows/bin/voice-input.ps1` の辞書の自動提案 (`Invoke-DictionarySuggestion`) が、Windows のクローンで `voice-dictionary.txt` をコミットしていた。
- 変更後: 提案は `ssh devbox` で devbox のクローンに追記・コミットする (devbox の post-commit が push)。成功したらすぐ Windows 側で pull して取り込む。
  - devbox が止まっているなどで失敗したら、ログに残してその回の提案は捨てる (文字起こしは devbox の `~/.cache/voice-transcripts.log` にもミラーしているので、あとで devbox から分析し直せる)。
  - コミットメッセージは ssh の引数に日本語を載せないよう base64 で渡す。
- ほかに Windows でコミットする処理は無い (`git commit` を呼ぶのはこれと `smart-commit` 系スキルの手順だけ)。
