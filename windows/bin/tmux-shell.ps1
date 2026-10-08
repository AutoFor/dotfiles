# ===== devbox の tmux から ssh で入った pwsh セッションの初期化 (#253) =====
# devbox 側のラッパー ~/.local/bin/aura が
#   ssh -t aura pwsh -NoLogo -NoExit -File <このファイル>
# で起動する。プロファイル ($PROFILE) は通常どおり先に読み込まれ、その後にこれが走る。
#
#  - 文字コード: ssh セッションのコンソールは CP932 で始まるため UTF-8 に揃える
#    (日本語の文字化け防止)
#  - プロンプトのたびに端末タイトルへ cwd を書く。tmux がそれを pane_title として
#    受け取り、ステータス行に「pwsh @aura  <cwd>」と出す。devbox 側から Windows の
#    cwd を知る手段は無いので、タイトル経由で渡す。claude 等が自分のタイトルを出して
#    いる間はそちらが表示される (何が動いているか分かるので、それで良しとする)
$null = chcp.com 65001
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# 既存のプロンプト (プロファイルや zoxide が定義したもの) を残したまま、タイトル設定だけ足す
$global:__tmuxTitlePrevPrompt = $function:prompt
function global:prompt {
    $p = (Get-Location).Path
    $h = $env:USERPROFILE
    if ($h -and $p.StartsWith($h, [System.StringComparison]::OrdinalIgnoreCase)) {
        $p = '~' + $p.Substring($h.Length)
    }
    $Host.UI.RawUI.WindowTitle = $p
    # フォーカス通知 (ESC[I / ESC[O) を受け取らないようにする。claude 等の TUI が有効化した
    # まま終了すると、WezTerm の切り替えのたびに "[I[O" がプロンプトに文字として残るため、
    # プロンプトに戻るたびに切る (TUI は起動時に自分で有効化し直すので支障なし)
    [Console]::Write("`e[?1004l")
    & $global:__tmuxTitlePrevPrompt
}
