# pptx 内の全フォントを Meiryo UI に一括変換する (AutoFor/pptx-font-meiryo-ui のラッパー)
# 使い方: pwsh -File windows\bin\pptx-meiryo.ps1 <input.pptx> [--output <out.pptx>] [--no-backup]
# 前提: PowerPoint がインストールされた Windows で実行すること (COM 経由で変換する)

$repo = Join-Path $env:USERPROFILE 'ghq\github.com\AutoFor\pptx-font-meiryo-ui'
$exe  = Join-Path $repo 'publish\pptx-meiryo.exe'

if (-not (Test-Path $exe)) {
    if (-not (Test-Path $repo)) {
        ghq get github.com/AutoFor/pptx-font-meiryo-ui
        if ($LASTEXITCODE -ne 0) { Write-Error 'ghq get に失敗しました'; exit 1 }
    }
    # ユーザーローカル SDK (dotnet-install.ps1 導入分) を優先
    $dotnet = Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet\dotnet.exe'
    if (-not (Test-Path $dotnet)) { $dotnet = 'dotnet' }
    & $dotnet publish (Join-Path $repo 'pptx-font-meiryo-ui.csproj') -c Release -o (Join-Path $repo 'publish') --nologo
    if ($LASTEXITCODE -ne 0) { Write-Error 'ビルドに失敗しました'; exit 1 }
}

& $exe @args
exit $LASTEXITCODE
