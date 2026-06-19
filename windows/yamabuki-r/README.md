# Yamabuki R

Yamabuki R の layout ファイルを管理する。

既定の反映先:

```text
C:\Prog\YamabukiR\layout
```

`install-windows.ps1` を実行すると、上記 layout ディレクトリを `windows\yamabuki-r\layout` へのシンボリックリンクに置き換える。既存の layout ディレクトリは `layout.backup.YYYYMMDD` に退避する。

Yamabuki R のインストール場所が違う場合は、PowerShell で `YAMABUKIR_DIR` を指定してから実行する。

```powershell
$env:YAMABUKIR_DIR = "C:\Prog\YamabukiR"
.\install-windows.ps1
```
