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
Write-Log "Smart Tag started - Action: $Action, Tag: $Tag, Global: $Global, Json: $Json"

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
    Write-Log "Loading tags from: $tagFile"
    
    if (Test-Path $tagFile) {
        try {
            $content = Get-Content $tagFile -Raw | ConvertFrom-Json
            Write-Log "Tags loaded successfully from $tagFile"
            return $content
        } catch {
            Write-Log "ERROR: Failed to parse tag file: $_"
            return @{
                tags = @{}
                current = $null
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        Write-Log "Tag file not found: $tagFile - Creating new tag structure"
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
    
    try {
        $TagData | ConvertTo-Json -Depth 10 | Set-Content $tagFile -Encoding UTF8
        Write-Log "Tags saved successfully to: $tagFile"
    } catch {
        Write-Log "ERROR: Failed to save tags to $tagFile - $_"
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

Write-Log "Processing action: $Action"

switch ($Action.ToLower()) {
    "list" {
        Write-Log "Listing tags (Global: $Global, Json: $Json)"
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
        Write-Log "Adding tag: $Tag with description: $Description"
        
        if (-not $Tag) {
            Write-Host "${RED}Error: -Tag parameter is required${RESET}"
            Write-Log "ERROR: Tag parameter missing"
            exit 1
        }
        
        if (-not $Description) {
            Write-Host "${RED}Error: -Description parameter is required${RESET}"
            Write-Log "ERROR: Description parameter missing"
            exit 1
        }
        
        # 新しいタグを追加
        $newTag = @{
            description = $Description
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            goals = @()
        }
        
        if ($tagData.tags -eq $null) {
            $tagData.tags = @{}
        }
        
        $tagData.tags[$Tag] = $newTag
        
        # 自動的にアクティブに設定
        $tagData.current = $Tag
        
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "Tag '$Tag' added and activated successfully"
        
        if ($Json) {
            @{ success = $true; message = "Tag added: $Tag" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Tag added and activated: ${CYAN}$Tag${RESET}"
            Write-Host "   ${YELLOW}Purpose:${RESET} $Description"
        }
    }
    
    "set" {
        Write-Log "Setting active tag to: $Tag"
        
        if (-not $Tag) {
            Write-Host "${RED}Error: -Tag parameter is required${RESET}"
            Write-Log "ERROR: Tag parameter missing for set action"
            exit 1
        }
        
        if (-not $tagData.tags.ContainsKey($Tag)) {
            Write-Host "${RED}Error: Tag '$Tag' not found${RESET}"
            Write-Host "Available tags: $($tagData.tags.Keys -join ', ')"
            Write-Log "ERROR: Tag '$Tag' not found. Available: $($tagData.tags.Keys -join ', ')"
            exit 1
        }
        
        $tagData.current = $Tag
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "Active tag set to: $Tag"
        
        if ($Json) {
            @{ success = $true; message = "Active tag set to: $Tag" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Active tag set to: ${CYAN}$Tag${RESET}"
            $activeTag = $tagData.tags.$Tag
            Write-Host "   ${YELLOW}Purpose:${RESET} $($activeTag.description)"
        }
    }
    
    "clear" {
        Write-Log "Clearing active tag"
        $tagData.current = $null
        Save-Tags -TagData $tagData -IsGlobal $Global
        Write-Log "Active tag cleared successfully"
        
        if ($Json) {
            @{ success = $true; message = "Active tag cleared" } | ConvertTo-Json
        } else {
            Write-Host "${GREEN}✅ Active tag cleared${RESET}"
        }
    }
    
    "show" {
        Write-Log "Showing current tag (Json: $Json)"
        
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
            
            Write-Log "Outputting tag context as JSON for Claude: active_tag=$($output.active_tag)"
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
        Write-Log "Adding goal to current tag: $Description"
        
        # ゴールの追加（拡張機能）
        if (-not $Description) {
            Write-Host "${RED}Error: -Description parameter is required for goal${RESET}"
            Write-Log "ERROR: Description parameter missing for goal"
            exit 1
        }
        
        if (-not $tagData.current) {
            Write-Host "${RED}Error: No active tag. Set a tag first with 'smart-tag -Action set -Tag <name>'${RESET}"
            Write-Log "ERROR: No active tag set for adding goal"
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
        Write-Log "Goal added successfully to tag '$($tagData.current)': $Description"
        
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
        Write-Log "ERROR: Unknown action '$Action'"
        exit 1
    }
}

Write-Log "Smart Tag completed successfully"

# PreToolUse用の出力（JSON形式の場合はすでに出力済み）
if (-not $Json -and $tagData.current) {
    Write-Host "`n${BLUE}💡 Current context will be provided to Claude${RESET}"
    Write-Log "Current context available for Claude: $($tagData.current)"
}