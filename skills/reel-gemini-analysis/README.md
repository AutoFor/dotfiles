# リール分析スキル（reel-gemini-analysis）

参考にしたいリール・ショート動画をGeminiに読ませて、フック・構成・テロップ・Bロール・音の「型」を時刻付きで取り出すClaude Code用スキルです。

使うには、自分のGemini APIキーが必要です（Google AI Studioで無料で発行できます）。分析1本あたりの費用は数円です。

準備の手順は **[セットアップガイド（setup-guide.md）](setup-guide.md)** を上から順に読んでください。APIキーの取得から初回実行まで、そこに全部書いてあります。

- `SKILL.md`：Claude Codeが読む手順書
- `scripts/analyze_video.py`：分析を実行するスクリプト（追加インストール不要）
- `prompts/`：Geminiへの分析依頼文
