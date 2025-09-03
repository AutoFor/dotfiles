# Smart Tag Script for Claude Code
# 作業の目的・マイルストーンをタグとして管理するPowerShellスクリプト

param(
    [string]$Action = "list",     # list/add/set/clear/show
    [string]$Tag,                  # タグ名
    [string]$Description,          # タグの説明
    [switch]$Global,               # グローバルタグ（全プロジェクト共通）
    [switch]$Json                  # JSON形式で出力
)

# ログファイルのパス設定
$logDir = "$env:USERPROFILE\.claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "smart-tag-$(Get-Date -Format 'yyyyMMdd').log"

# ログ出力関数
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

# ANSIカラーコード
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$MAGENTA = "$ESC[35m"
$CYAN = "$ESC[36m"
$RESET = "$ESC[0m"
$BOLD = "$ESC[1m"

# スクリプト開始ログ
Write-Log "##################################################"
Write-Log "          スマートタグ開始"
Write-Log "##################################################"
Write-Log "作業ディレクトリ: $(Get-Location)"
Write-Log "パラメータ: Action=$Action, Tag=$Tag, Global=$Global, Json=$Json"

# タグファイルのパス設定
$globalTagFile = "$env:USERPROFILE\.claude\tags\global-tags.json"
$localTagFile = ".claude\project-tags.json"

# ディレクトリの作成
$globalTagDir = Split-Path $globalTagFile -Parent
if (-not (Test-Path $globalTagDir)) {
    New-Item -ItemType Directory -Path $globalTagDir -Force | Out-Null
}

if (-not $Global) {
    $localTagDir = Split-Path $localTagFile -Parent
    if (-not (Test-Path $localTagDir)) {
        New-Item -ItemType Directory -Path $localTagDir -Force | Out-Null
    }
}

# タグファイルの読み込み
function Get-Tags {
    param([bool]$IsGlobal)
    
    $tagFile = if ($IsGlobal) { $globalTagFile } else { $localTagFile }
    Write-Log "タグファイル読み込み中: $tagFile"
    
    if (Test-Path $tagFile) {
        $fileSize = (Get-Item $tagFile).Length
        Write-Log "ファイル存在確認: OK (サイズ: $fileSize bytes)"
        
        try {
            $rawContent = Get-Content $tagFile -Raw
            Write-Log "Raw JSON読み込み完了 (サイズ: $($rawContent.Length) 文字)"
            
            $content = $rawContent | ConvertFrom-Json
            Write-Log "JSONパース成功: current='$($content.current)', tags数=$($content.tags.PSObject.Properties.Count)"
            
            # タグの詳細をログ出力
            if ($content.tags) {
                $tagNames = @($content.tags.PSObject.Properties.Name) -join ', '
                Write-Log "読み込まれたタグ: [$tagNames]"
            } else {
                Write-Log "警告: tagsプロパティが存在しません"
            }
            
            Write-Log "タグファイル読み込み成功: $tagFile"
            return $content
        } catch {
            Write-Log "エラー: タグファイルの解析に失敗: $_"
            Write-Log "エラー詳細: $($_.Exception.Message)"
            return @{
                tags = @{}
                current = $null
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        Write-Log "タグファイルが見つかりません: $tagFile - 新規作成"
        return @{
            tags = @{}
            current = $null
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
}

# タグファイルの保存
function Save-Tags {
    param(
        [object]$TagData,
        [bool]$IsGlobal
    )
    
    $tagFile = if ($IsGlobal) { $globalTagFile } else { $localTagFile }
    $TagData.updated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    Write-Log "保存処理開始: ファイル='$tagFile', current='$($TagData.current)', tags数=$($TagData.tags.Count)"
    
    try {
        $jsonContent = $TagData | ConvertTo-Json -Depth 10
        Write-Log "JSON変換完了 (サイズ: $($jsonContent.Length) 文字)"
        
        $jsonContent | Set-Content $tagFile -Encoding UTF8
        Write-Log "ファイル書き込み完了: $tagFile"
        
        # 書き込み後の検証
        if (Test-Path $tagFile) {
            $fileSize = (Get-Item $tagFile).Length
            Write-Log "ファイル検証: 存在=OK, サイズ=$fileSize bytes"
        } else {
            Write-Log "警告: 保存後にファイルが存在しません"
        }
        
        Write-Log "タグファイル保存成功: $tagFile"
    } catch {
        Write-Log "エラー: タグファイルの保存に失敗: $tagFile - $_"
        Write-Log "エラー詳細: $($_.Exception.Message)"
        Write-Log "スタックトレース: $($_.ScriptStackTrace)"
    }
}

# ヘッダー表示
if (-not $Json) {
    Write-Host "`n${CYAN}${BOLD}🏷️  Smart Tag Manager${RESET}"
    if ($Global) {
        Write-Host "${YELLOW}[Global Mode]${RESET}"
    } else {
        Write-Host "${BLUE}[Project: $(Split-Path (Get-Location) -Leaf)]${RESET}"
    }
}

# メイン処理
$tagData = Get-Tags -IsGlobal $Global

Write-Log "メイン処理開始: current='$($tagData.current)', tags数=$($tagData.tags.Count)"
Write-Log "---------- アクション実行: $Action ----------"

switch ($Action.ToLower()) {
    "list" {
        Write-Log "タグ一覧表示 (グローバル: $Global, JSON出力: $Json)"
        if ($Json) {
            # JSON出力
            $output = @{
                mode = if ($Global) { "global" } else { "project" }
                current = $tagData.current
                tags = $tagData.tags
            }
            $output | ConvertTo-Json -Depth 10
        } else {
            # 通常出力
            Write-Host "`n${BOLD}Current Tags:${RESET}"
            
            if ($tagData.current) {
                Write-Host "${GREEN}✓ Active: ${CYAN}$($tagData.current)${RESET}"
                if ($tagData.tags.$($tagData.current)) {
                    $currentTag = $tagData.tags.$($tagData.current)
                    Write-Host "  ${YELLOW}Purpose:${RESET} $($currentTag.description)"
                    Write-Host "  ${BLUE}Created:${RESET} $($currentTag.created)"
                }
                Write-Host ""
            } else {
                Write-Host "${YELLOW}  No active tag${RESET}`n"
            }
            
            if ($tagData.tags.Count -gt 0) {
                Write-Host "${BOLD}Available Tags:${RESET}"
                foreach ($key in $tagData.tags.Keys | Sort-Object) {
                    $tag = $tagData.tags.$key
                    $isActive = ($key -eq $tagData.current)
                    $prefix = if ($isActive) { "${GREEN}→${RESET}" } else { " " }
                    
                    Write-Host "$prefix ${CYAN}$key${RESET}"
                    Write-Host "    $($tag.description)"
                    
                    if ($tag.goals -and $tag.goals.Count -gt 0) {
                        Write-Host "    ${MAGENTA}Goals:${RESET}"
                        foreach ($goal in $tag.goals) {
                            $status = if ($goal.completed) { "${GREEN}✓${RESET}" } else { "${YELLOW}○${RESET}" }
                            Write-Host "      $status $($goal.text)"
                        }
                    }
                }
            } else {
                Write-Host "${YELLOW}No tags defined${RESET}"
                Write-Host "Use 'smart-tag -Action add -Tag <name> -Description <desc>' to create one"
            }
        }
    }
    
    "add" {
        Write-Log "タグ追加: $Tag"
        Write-Log "説明: $Description"
        
        if (-not $Tag) {
            Write-Host "${RED}Error: -Tag parameter is required${RESET}"
            Write-Log "エラー: タグパラメータが指定されていません"
            exit 1
        }
        
        if (-not $Description) {
            Write-Host "${RED}Error: -Description parameter is required${RESET}"
            Write-Log "エラー: 説明パラメータが指定されていません"
            exit 1
        }
        
        # 新しいタグを追加
        $newTag = @{
            description = $Description
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            goals = @()
        }
        
        Write-Log "タグデータ構造確認 - tagsのnullチェック: $($tagData.tags -eq $null)"
        if ($tagData.tags -eq $null) {
            Write-Log "タグデータがnullのため、新規作成"
            $tagData.tags = @{}
        }
        
        Write-Log "タグ '$Tag' をデータ構造に追加中"
        $tagData.tags[$Tag] = $newTag
        Write-Log "タグ追加後のタグ数: $($tagData.tags.Count)"
        
        # 自動的にアクティブに設定
        Write-Log "アクティブタグを '$Tag' に設定中"
        $tagData.current = $Tag
        Write-Log "アクティブタグ設定後: current='$($tagData.current)'"
        
        Write-Log "保存前のデータ確認: current='$($tagData.current)', tags数=$($tagData.tags.Count)"
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "タグ '$Tag' を追加してアクティブ化しました"
        
        # 保存後の確認
        $verifyData = Get-Tags -IsGlobal $Global
        Write-Log "保存後の検証: current='$($verifyData.current)', tags数=$($verifyData.tags.Count)"
        if ($verifyData.current -ne $Tag) {
            Write-Log "警告: 保存後のアクティブタグが一致しません (期待値='$Tag', 実際='$($verifyData.current)')"
        }
        
        if ($Json) {
            @{ success = $true; message = "Tag added: $Tag" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Tag added and activated: ${CYAN}$Tag${RESET}"
            Write-Host "   ${YELLOW}Purpose:${RESET} $Description"
        }
    }
    
    "set" {
        Write-Log "アクティブタグを設定: $Tag"
        
        if (-not $Tag) {
            Write-Host "${RED}Error: -Tag parameter is required${RESET}"
            Write-Log "エラー: setアクションにタグパラメータが必要です"
            exit 1
        }
        
        if (-not $tagData.tags.ContainsKey($Tag)) {
            Write-Host "${RED}Error: Tag '$Tag' not found${RESET}"
            Write-Host "Available tags: $($tagData.tags.Keys -join ', ')"
            Write-Log "エラー: タグ '$Tag' が見つかりません。利用可能: $($tagData.tags.Keys -join ', ')"
            exit 1
        }
        
        $tagData.current = $Tag
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "アクティブタグを '$Tag' に設定しました"
        
        if ($Json) {
            @{ success = $true; message = "Active tag set to: $Tag" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Active tag set to: ${CYAN}$Tag${RESET}"
            $activeTag = $tagData.tags.$Tag
            Write-Host "   ${YELLOW}Purpose:${RESET} $($activeTag.description)"
        }
    }
    
    "clear" {
        Write-Log "アクティブタグをクリア"
        $tagData.current = $null
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "アクティブタグをクリアしました"
        
        if ($Json) {
            @{ success = $true; message = "Active tag cleared" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Active tag cleared${RESET}"
        }
    }
    
    "show" {
        Write-Log "現在のタグを表示 (JSON出力: $Json)"
        
        if ($Json) {
            # Claude用の構造化データを出力
            $output = @{
                mode = if ($Global) { "global" } else { "project" }
                active_tag = $null
                context = @{}
            }
            
            if ($tagData.current -and $tagData.tags.$($tagData.current)) {
                $currentTag = $tagData.tags.$($tagData.current)
                $output.active_tag = $tagData.current
                $output.context = @{
                    purpose = $currentTag.description
                    created = $currentTag.created
                    goals = $currentTag.goals
                }
            }
            
            Write-Log "ClaudeへのJSON出力: アクティブタグ=$($output.active_tag)"
            $output | ConvertTo-Json -Depth 10
        } else {
            if ($tagData.current) {
                Write-Host "`n${GREEN}Active Tag: ${CYAN}$($tagData.current)${RESET}"
                $currentTag = $tagData.tags.$($tagData.current)
                Write-Host "${YELLOW}Purpose:${RESET} $($currentTag.description)"
                Write-Host "${BLUE}Created:${RESET} $($currentTag.created)"
                
                if ($currentTag.goals -and $currentTag.goals.Count -gt 0) {
                    Write-Host "`n${MAGENTA}Goals:${RESET}"
                    foreach ($goal in $currentTag.goals) {
                        $status = if ($goal.completed) { "${GREEN}✓${RESET}" } else { "${YELLOW}○${RESET}" }
                        Write-Host "  $status $($goal.text)"
                    }
                }
            } else {
                Write-Host "${YELLOW}No active tag${RESET}"
            }
        }
    }
    
    "goal" {
        Write-Log "現在のタグにゴール追加: $Description"
        
        # ゴールの追加（拡張機能）
        if (-not $Description) {
            Write-Host "${RED}Error: -Description parameter is required for goal${RESET}"
            Write-Log "エラー: ゴールに説明パラメータが必要です"
            exit 1
        }
        
        if (-not $tagData.current) {
            Write-Host "${RED}Error: No active tag. Set a tag first with 'smart-tag -Action set -Tag <name>'${RESET}"
            Write-Log "エラー: ゴール追加のためのアクティブタグが設定されていません"
            exit 1
        }
        
        $currentTag = $tagData.tags.$($tagData.current)
        if (-not $currentTag.goals) {
            $currentTag.goals = @()
        }
        
        $newGoal = @{
            text = $Description
            completed = $false
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $currentTag.goals += $newGoal
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "タグ '$($tagData.current)' にゴールを追加しました: $Description"
        
        if ($Json) {
            @{ success = $true; message = "Goal added to tag: $($tagData.current)" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Goal added to tag '${CYAN}$($tagData.current)${GREEN}'${RESET}"
            Write-Host "   ${YELLOW}Goal:${RESET} $Description"
        }
    }
    
    default {
        Write-Host "${RED}Error: Unknown action '$Action'${RESET}"
        Write-Host "Available actions: list, add, set, clear, show, goal"
        Write-Log "エラー: 不明なアクション '$Action'"
        exit 1
    }
}

Write-Log "---------- サマリー ----------"
Write-Log "実行アクション: $Action"
if ($tagData.current) {
    Write-Log "現在のアクティブタグ: $($tagData.current)"
}
Write-Log "---------- スマートタグ正常完了 ----------"

# PreToolUse用の出力（JSON形式の場合はすでに出力済み）
if (-not $Json -and $tagData.current) {
    Write-Host "`n${BLUE}💡 Current context will be provided to Claude${RESET}"
    Write-Log "Claudeコンテキスト: アクティブタグ=$($tagData.current)"
}