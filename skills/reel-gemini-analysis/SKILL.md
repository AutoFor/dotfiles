---
name: reel-gemini-analysis
description: 「このリール分析して」「この動画の型を分析」「Geminiで動画分析」＋パソコンに保存したローカル動画のパスで使う。Gemini APIに動画そのものを渡し、フック・構成・テロップ・Bロール・音の型を時刻付きで取り出してMarkdownに保存する。各自が用意したGemini APIキーで動く。動画の生成、文章の校閲、字幕ファイル作成には使わない。
---

# リールをGeminiで分析する

参考にしたいリール・ショート動画をGeminiに渡し、「型」を取り出す。

## 1. 動画のパスを確認する

パソコンに保存されている動画ファイル（mp4・mov・webm・m4v）のパスをもらう。

- URLしか渡されなかった場合、このスキルは対応しない。保存した動画ファイルを渡してもらう。
- 動画のダウンロード手順（yt-dlp等の導入）は、このスキルの範囲外。

## 2. 初回は接続確認をする

そのパソコンで初めて使うときは、まず接続だけ確認する。

以下の `<SKILL_DIR>` はこの SKILL.md があるフォルダ（Claude Code なら `~/.claude/skills/reel-gemini-analysis`、Codex なら `~/.agents/skills/reel-gemini-analysis`。どちらも dotfiles の `skills/reel-gemini-analysis` へのリンク）。
Windows で `python3` が無いときは `py -3` か `python` に置き換える。

```
python3 <SKILL_DIR>/scripts/analyze_video.py --check
```

「接続OK」と出れば次へ進む。キーが見つからないと出た場合は、セットアップガイド（`setup-guide.md`）の「4. キーをパソコンに置く」を案内する。

## 3. 分析を実行する

```
python3 <SKILL_DIR>/scripts/analyze_video.py <動画パス>
```

- 出力：動画と同じ場所に `<動画名>_analysis.md`。`--out` で保存先を変えられる。
- 細かい文字を読ませたいときだけ `--resolution high`（料金は上がる）。
- 時刻付きの観察だけが欲しいときは `--prompt-file <SKILL_DIR>/prompts/raw-observation.md`。

## 4. 結果を読んで返す

出力されたMarkdownを読み、チャットで次の2つを返す。

- 型の要約：フック・構成・テロップ・Bロール・音のうち、この動画を成立させている要素。
- 自分の動画への転用案：すぐ試せる形で3〜5個。

## 5. 添える注意

- 秒数は概数。編集点としてそのまま使わない。気になる箇所は実際の映像で確認する。
- Geminiが読み取れなかった文字・音は不明として扱われている。断定しない。
- 他人の動画をそのまま真似ない。型だけを借りる。

## 6. キーがないとき

`--check` や実行でキーが見つからないと出たら、同梱の `setup-guide.md`（セットアップガイド）の「3. Gemini APIキーを取る」と「4. キーをパソコンに置く」を案内する。キーの値をチャットに貼らせない。
