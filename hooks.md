# Claude Code Hooks Configuration

## Stop Hook（処理完了通知）
```bash
powershell.exe -File "$(wslpath -w ~/.claude/windows-notify.ps1)" -Title " 応答完了" -Message "セッションタグ作成完了" -IncludeWorkingDirectory
```
