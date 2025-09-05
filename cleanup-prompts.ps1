# cleanup-prompts.ps1
# 古いプロンプトファイルを定期的に削除

param(
    [string]$PromptDir = "$PSScriptRoot\prompts",
    [int]$KeepDays = 1,  # 保持する日数（デフォルト1日）
    [int]$KeepFiles = 10  # 最低限保持するファイル数
)

if (Test-Path $PromptDir) {
    # 現在の時刻
    $now = Get-Date
    $cutoffDate = $now.AddDays(-$KeepDays)
    
    # プロンプトファイルを取得（作成日時でソート）
    $promptFiles = Get-ChildItem -Path $PromptDir -Filter "prompt_*.txt" | 
                   Sort-Object CreationTime -Descending
    
    # ファイル数を確認
    $totalFiles = $promptFiles.Count
    Write-Host "Total prompt files: $totalFiles" -ForegroundColor Cyan
    
    if ($totalFiles -gt $KeepFiles) {
        # 削除対象のファイルを特定
        $filesToDelete = @()
        
        # 最新の$KeepFilesファイルはスキップ
        for ($i = $KeepFiles; $i -lt $totalFiles; $i++) {
            $file = $promptFiles[$i]
            
            # 古いファイルのみ削除対象に
            if ($file.CreationTime -lt $cutoffDate) {
                $filesToDelete += $file
            }
        }
        
        # ファイル削除
        if ($filesToDelete.Count -gt 0) {
            Write-Host "Deleting $($filesToDelete.Count) old prompt files..." -ForegroundColor Yellow
            foreach ($file in $filesToDelete) {
                Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "  Deleted: $($file.Name)" -ForegroundColor Gray
            }
        } else {
            Write-Host "No old files to delete" -ForegroundColor Green
        }
    } else {
        Write-Host "File count is within limit ($totalFiles <= $KeepFiles)" -ForegroundColor Green
    }
    
    # 現在実行中のプロセスのプロンプトファイルは保護（削除しない）
    $currentPrompt = "$PromptDir\prompt_$PID.txt"
    if (Test-Path $currentPrompt) {
        Write-Host "Current session prompt preserved: prompt_$PID.txt" -ForegroundColor Cyan
    }
}

exit 0