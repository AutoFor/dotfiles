# ===== PowerShell (pwsh) プロファイル =====
# install-windows.ps1 が $PROFILE (ドキュメント\PowerShell\) にシンボリックリンクする。

# zoxide（スマートcd）を有効化。z / zi が使えるようになる
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ghq + fzf でリポジトリを選択して cd（Ctrl+G）
function ghq-fzf {
    $repo = ghq list | fzf --height=40% --reverse --prompt='repo> '
    if ($repo) {
        Set-Location (Join-Path (ghq root) $repo)
    }
}

if (Get-Module PSReadLine) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+g' -BriefDescription 'ghq-fzf' -ScriptBlock {
        ghq-fzf
        # プロンプトを描き直して移動先を表示する
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}
