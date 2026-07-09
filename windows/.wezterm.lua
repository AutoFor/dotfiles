local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Azure 開発サーバー (devbox) 関連の定数
local DEVBOX_DOMAIN = "azure"
local DEVBOX_HOST = "20.46.165.130"   -- Standard SKU の静的 IP（停止/再開で不変）
local DEVBOX_USER = "azureuser"
local DEVBOX_HOSTNAME = "devbox"      -- ステータス表示でネスト SSH と区別するために使う
-- VM 起動 + NSG の現在IP許可を担保するスクリプト（windows/bin/devbox.ps1）。
-- dotfiles を ~/dotfiles 以外に clone した場合は環境変数 DOTFILES_DIR で上書きする。
local DOTFILES_DIR = os.getenv("DOTFILES_DIR") or (wezterm.home_dir .. "\\dotfiles")
local DEVBOX_PS1 = DOTFILES_DIR .. "\\windows\\bin\\devbox.ps1"

local function sh_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- devbox の VM 起動と NSG を担保する。22番に届く場合は az を呼ばず即 return するため、
-- VM 起動中の普段は 1 秒程度で終わる（詳細は devbox.ps1 ensure）。
local function ensure_devbox()
  local ok = pcall(function()
    wezterm.run_child_process({
      "pwsh.exe", "-NoProfile", "-NonInteractive", "-File", DEVBOX_PS1, "ensure",
    })
  end)
  return ok
end

-- ペインの cwd（azure ドメインならリモート側のパス）を返す
local function pane_cwd(pane)
  local ok, uri = pcall(function()
    return pane:get_current_working_dir()
  end)
  if ok and uri and uri.file_path then
    return uri.file_path
  end
  return nil
end

-- WezTerm 起動時は Azure devbox の mux ドメインに接続する。
-- セッションはリモート側の wezterm-mux-server に残るため、休止/切断後に
-- WezTerm を開き直すだけでペイン/プロセス(Claude Code 含む)ごと復帰する。
-- 接続前に devbox.ps1 ensure で VM 起動と NSG(現在IPの許可)を担保する。
wezterm.on("gui-startup", function(cmd)
  ensure_devbox()
  local args = cmd or {}
  args.domain = { DomainName = DEVBOX_DOMAIN }
  local ok = pcall(function()
    wezterm.mux.spawn_window(args)
  end)
  if not ok then
    -- 接続できない場合はローカル PowerShell にフォールバック
    wezterm.mux.spawn_window({ args = { "pwsh.exe", "-NoLogo" } })
  end
end)


config.automatically_reload_config = true
-- フォーカス中のペインからの通知（OSC 777 等）はトーストにしない
-- ※ WezTerm 20240127 より古い場合は未対応の設定キー警告が出るので、この行を削除する
config.notification_handling = "SuppressFromFocusedPane"
config.font = wezterm.font("HackGen Console NF")
config.font_size = 12.0
-- WebGPU を試す（クラッシュするなら下の OpenGL に戻す）
-- config.front_end = "WebGpu"
-- config.webgpu_power_preference = "HighPerformance"
-- アダプタ固定が必要なら有効化
-- config.webgpu_preferred_adapter = {
--   backend = "Dx12",
--   device_type = "IntegratedGpu",
-- }
config.max_fps = 120
config.animation_fps = 60
config.front_end = "OpenGL"  -- WebGPU クラッシュのため無効化
config.use_ime = true
config.window_background_opacity = 1.0
config.macos_window_background_blur = 20

-- Azure devbox への永続 multiplexing ドメイン。
-- スリープ/切断で SSH が落ちても Azure 上の wezterm-mux-server が生き続け、
-- 再接続でペイン/プロセス(Claude Code 含む)がそのまま復帰する。
-- 事前: Azure に同一版 wezterm 導入済み(bootstrap.sh が導入)、
--       Windows の id_ed25519 公開鍵を authorized_keys 登録済み。
config.ssh_domains = {
  {
    name = DEVBOX_DOMAIN,
    remote_address = DEVBOX_HOST,
    username = DEVBOX_USER,
    ssh_option = {
      identityfile = wezterm.home_dir .. "\\.ssh\\id_ed25519",
    },
    remote_wezterm_path = "/usr/bin/wezterm",
    multiplexing = "WezTerm",
  },
}

config.default_domain = DEVBOX_DOMAIN

-- ランチャーメニュー（LEADER + l で表示）
config.launch_menu = {
  {
    -- 永続 mux ドメイン。切断/スリープでも Azure 側セッションが生き残る。
    label = "Azure devbox (mux 永続)",
    domain = { DomainName = DEVBOX_DOMAIN },
  },
  {
    -- 素の SSH 接続（mux を経由しない切り分け用。切断でセッションは消える）
    label = "Azure devbox (SSH)",
    domain = { DomainName = "local" },
    args = { "pwsh.exe", "-NoLogo", "-NoProfile", "-File", DEVBOX_PS1, "connect" },
  },
  {
    label = "PowerShell",
    domain = { DomainName = "local" },
    args = { "pwsh.exe", "-NoLogo" },
  },
}

-- ウィンドウタイトルにカレントディレクトリ名を表示
local function basename(path)
  path = path:gsub("^file://", "")
  return path:gsub("(.*[/\\])(.*)", "%2")
end

wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
  if not pane then
    return "WezTerm"
  end
  local cwd = basename(tostring(pane.current_working_dir or ""))
  if cwd == "" then
    return "WezTerm"
  end
  return cwd .. " - WezTerm"
end)

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時も表示
config.hide_tab_bar_if_only_one_tab = false
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}

-- タブバーを背景色に合わせる
config.window_background_gradient = {
  colors = { "#000000" },
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false

-- タブ同士の境界線を非表示
config.colors = {
  tab_bar = {
    inactive_tab_edge = "none",
  },
}

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local background = "#5c6d74"
  local foreground = "#FFFFFF"
  local edge_background = "none"
  if tab.is_active then
    background = "#ae8b2d"
    foreground = "#FFFFFF"
  end
  local edge_foreground = background
  local raw = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title or tab.active_pane.title
  local title = "   " .. wezterm.truncate_right(raw, max_width - 1) .. "   "
  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)


----------------------------------------------------
-- keybinds
----------------------------------------------------

-- 右ステータス: workspace / 接続状態 / アクティブなキーテーブル
-- 接続状態は「mux 経由（永続）」「素の SSH（切断で消える）」「ローカル」の3値で表示する。
-- ドメイン名だけでは素の SSH（devbox ペイン内からさらに ssh した場合）を検出できないため、
-- シェルが OSC 7 で報告するホスト名（pane:get_current_working_dir().host）も併用する。
wezterm.on("update-right-status", function(window, pane)
  local ok, domain = pcall(function()
    return pane:get_domain_name()
  end)
  domain = (ok and domain) and domain or "?"

  local host
  local ok_cwd, cwd = pcall(function()
    return pane:get_current_working_dir()
  end)
  if ok_cwd and cwd and cwd.host and cwd.host ~= "" then
    host = cwd.host
  end

  local label, color
  if host and host:lower() ~= DEVBOX_HOSTNAME and domain ~= "local" then
    -- ペイン内から素の ssh で別ホストに入っている状態。切断するとセッションも消える
    label = "SSH:" .. host
    color = "#f7768e"
  elseif domain == DEVBOX_DOMAIN then
    -- 永続 mux ドメイン。切断/スリープしてもリモート側でセッションが生き残る
    label = "MUX:" .. (host or DEVBOX_DOMAIN)
    color = "#e0af68"
  else
    label = domain
    color = "#9ece6a"
  end

  local items = {
    { Foreground = { Color = "#7aa2f7" } },
    { Text = wezterm.mux.get_active_workspace() },
    { Foreground = { Color = color } },
    { Text = "  " .. wezterm.nerdfonts.md_server_network .. " " .. label },
  }
  local key_table = window:active_key_table()
  if key_table then
    table.insert(items, { Foreground = { Color = "#bb9af7" } })
    table.insert(items, { Text = "  TABLE: " .. key_table })
  end
  table.insert(items, { Text = "  " })
  window:set_right_status(wezterm.format(items))
end)

config.disable_default_key_bindings = true
-- Ctrl+q を leader に使う
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

local function activate_pane_or_send_alt(direction, key)
  return wezterm.action_callback(function(win, pane)
    local tab = win:active_tab()
    local adjacent = tab and tab.get_pane_direction and tab:get_pane_direction(direction) or nil
    if adjacent then
      win:perform_action(act.ActivatePaneDirection(direction), pane)
    else
      win:perform_action(act.SendKey({ key = key, mods = "ALT" }), pane)
    end
  end)
end

local window_mode_by_id = {}

local function maximize_with_taskbar_excluded()
  return wezterm.action_callback(function(window, pane)
    local success, output = wezterm.run_child_process({
      "powershell.exe",
      "-NoProfile",
      "-Command",
      [[
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MonitorInfo {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int left;
        public int top;
        public int right;
        public int bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFOEX {
        public uint cbSize;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public char[] szDevice;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    [DllImport("user32.dll")]
    public static extern bool GetMonitorInfoA(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromPoint([In] System.Drawing.Point pt, uint dwFlags);
}
"@

        $monitor = [MonitorInfo]::MonitorFromPoint(
            [System.Drawing.Point]::new([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.X,
                                       [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Y),
            0x00000001
        )
        $info = New-Object MonitorInfo+MONITORINFOEX
        $info.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($info)
        [MonitorInfo]::GetMonitorInfoA($monitor, [ref]$info)

        [int]$x = $info.rcWork.left
        [int]$y = $info.rcWork.top
        [int]$w = $info.rcWork.right - $info.rcWork.left
        [int]$h = $info.rcWork.bottom - $info.rcWork.top

        Write-Output "$x,$y,$w,$h"
      ]],
    })

    if success and output then
      local dims = output:match("^([0-9,-]+)")
      if dims then
        local x, y, w, h = dims:match("([^,]+),([^,]+),([^,]+),([^,]+)")
        if x and y and w and h then
          window:set_position(tonumber(x), tonumber(y))
          window:set_inner_size(tonumber(w), tonumber(h))
        end
      end
    end
  end)
end

local function cycle_window_mode()
  return wezterm.action_callback(function(window, pane)
    local window_id = window:window_id()
    local dimensions = window:get_dimensions()
    local mode = window_mode_by_id[window_id] or "normal"

    if dimensions.is_full_screen then
      mode = "fullscreen"
    end

    if mode == "normal" then
      window:perform_action(maximize_with_taskbar_excluded(), pane)
      window_mode_by_id[window_id] = "maximized"
    elseif mode == "maximized" then
      window:toggle_fullscreen()
      window_mode_by_id[window_id] = "fullscreen"
    else
      if dimensions.is_full_screen then
        window:toggle_fullscreen()
        wezterm.sleep_ms(50)
      end
      window:restore()
      window_mode_by_id[window_id] = "normal"
    end
  end)
end

-- Azure mux ドメインの新規タブを開く（切断してもセッションがリモート側に残る）。
-- devbox のペインから開いた場合は同じディレクトリを引き継ぐ。
-- VM 停止中はドメイン未接続で失敗するため、その場合は <leader> a（ensure してから開く）を使う。
local function spawn_mux_tab()
  return wezterm.action_callback(function(window, pane)
    local cwd
    local ok, pane_domain = pcall(function()
      return pane:get_domain_name()
    end)
    if ok and pane_domain == DEVBOX_DOMAIN then
      cwd = pane_cwd(pane)
    end
    window:perform_action(
      act.SpawnCommandInNewTab({
        domain = { DomainName = DEVBOX_DOMAIN },
        cwd = cwd,
      }),
      pane
    )
  end)
end

-- devbox の VM 起動と NSG を担保してから、Azure mux ドメインの新規タブを開く。
-- 休止明けや VM 停止中はこちらを使う（Ctrl+t は ensure しない分だけ速い）。
local function spawn_devbox_tab()
  return wezterm.action_callback(function(window, pane)
    ensure_devbox()
    window:perform_action(
      act.SpawnCommandInNewTab({
        domain = { DomainName = DEVBOX_DOMAIN },
      }),
      pane
    )
  end)
end

-- devbox の VM 起動と NSG を担保してから、Azure mux ドメインに attach する。
-- 既存の永続タブ/ペイン(claude 等)を丸ごと呼び戻す。休止/切断後の復帰はこれ。
local function attach_devbox_domain()
  return wezterm.action_callback(function(window, pane)
    ensure_devbox()
    window:perform_action(act.AttachDomain(DEVBOX_DOMAIN), pane)
  end)
end

local function cwd_from_nvim_user_var(value)
  if not value or value == "" then
    return nil
  end
  return value:match("^(.-):%d+:%d+$") or value
end

local function agent_command_with_debug(agent_command, cwd)
  local cd_prefix = ""
  if cwd and cwd ~= "" then
    cd_prefix = "cd " .. sh_quote(cwd) .. " 2>/dev/null || true; "
  end
  return "mkdir -p ~/.cache; "
    .. cd_prefix
    .. "printf '[%s] agent pane: pwd=%q command=%q\\n' \"$(date '+%Y-%m-%d %H:%M:%S')\" \"$PWD\" "
    .. sh_quote(agent_command)
    .. " >> ~/.cache/wezterm-nvim-pane.log; "
    .. agent_command
    .. "; exec zsh -l"
end

local function open_nvim_with_agent(agent_command)
  return wezterm.action_callback(function(window, pane)
    local cwd = pane_cwd(pane)
    local split = {
      direction = "Right",
      size = { Percent = 30 },
      command = { args = { "zsh", "-lic", agent_command_with_debug(agent_command, cwd) } },
    }
    if cwd then
      split.command.cwd = cwd
    end

    window:perform_action(act.SendString("nvim .\n"), pane)
    window:perform_action(act.SplitPane(split), pane)
  end)
end

-- Claude Code hook（~/.claude/notify.sh）からの通知。
-- リモート側が OSC 1337 SetUserVar "claude_notify" を発行すると、通知元ペインを記録して
-- タブタイトルに 🔔 を付ける。フォーカスすると解除。LEADER+j で最後に通知したペインへジャンプ。
local claude_notified = {} -- pane_id -> 通知前の明示タブタイトル（"" = 明示タイトルなし）
local claude_notify_order = {} -- 通知順の pane_id（新しいものが末尾）

local function claude_notify_forget(pane_id)
  claude_notified[pane_id] = nil
  for i = #claude_notify_order, 1, -1 do
    if claude_notify_order[i] == pane_id then
      table.remove(claude_notify_order, i)
    end
  end
end

local function claude_notify_clear_mark(pane_id)
  local original = claude_notified[pane_id]
  if original ~= nil then
    local mux_pane = wezterm.mux.get_pane(pane_id)
    local tab = mux_pane and mux_pane:tab() or nil
    if tab then
      tab:set_title(original)
    end
  end
  claude_notify_forget(pane_id)
end

local function jump_to_notified_pane()
  return wezterm.action_callback(function(window, pane)
    while #claude_notify_order > 0 do
      local target = claude_notify_order[#claude_notify_order]
      local mux_pane = wezterm.mux.get_pane(target)
      if mux_pane then
        local mux_win = mux_pane:window()
        local gui_win = mux_win and mux_win:gui_window() or nil
        if gui_win then
          gui_win:focus()
        end
        local tab = mux_pane:tab()
        if tab then
          tab:activate()
        end
        mux_pane:activate()
        return
      end
      -- ペインが既に閉じられていたら履歴から捨てて次を試す
      claude_notify_forget(target)
    end
  end)
end

wezterm.on("pane-focus-changed", function(window, pane)
  -- 通知マークの付いたペインに来たら解除してタイトルを復元
  claude_notify_clear_mark(pane:pane_id())
end)

wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "send_to_right_agent_pane" then
    local tab = window:active_tab()
    local adjacent = tab and tab.get_pane_direction and tab:get_pane_direction("Right") or nil
    if adjacent then
      window:perform_action(act.SendString(value), adjacent)
      window:perform_action(act.ActivatePaneDirection("Right"), pane)
    end
    return
  end

  if name == "claude_notify" then
    -- payload: "ディレクトリ名\tタイトル\tメッセージ"（notify.sh が base64 で送信、WezTerm が復号済み）
    local pane_id = pane:pane_id()
    -- 通知元ペインを見ているときはマーク不要
    if window:is_focused() and window:active_pane():pane_id() == pane_id then
      return
    end
    local dir = value:match("^([^\t]*)") or ""
    local mux_pane = wezterm.mux.get_pane(pane_id)
    local tab = mux_pane and mux_pane:tab() or nil
    if tab then
      if claude_notified[pane_id] == nil then
        claude_notified[pane_id] = tab:get_title() or ""
      end
      tab:set_title("🔔 " .. (dir ~= "" and dir or "claude"))
    end
    for i = #claude_notify_order, 1, -1 do
      if claude_notify_order[i] == pane_id then
        table.remove(claude_notify_order, i)
      end
    end
    table.insert(claude_notify_order, pane_id)
    return
  end

  if name ~= "open_agent_pane_for_nvim" then
    return
  end

  local tab = window:active_tab()
  local adjacent = tab and tab.get_pane_direction and tab:get_pane_direction("Right") or nil
  if adjacent then
    return
  end

  -- nvim と同じドメイン(通常 azure)・同じディレクトリで claude を開く
  local cwd = cwd_from_nvim_user_var(value) or pane_cwd(pane)
  local split = {
    direction = "Right",
    size = { Percent = 30 },
    command = { args = { "zsh", "-lic", agent_command_with_debug("claude -y", cwd) } },
  }
  if cwd then
    split.command.cwd = cwd
  end

  window:perform_action(act.SplitPane(split), pane)
end)

config.keys = {
  {
    -- workspaceの切り替え
    key = "w",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Select workspace" }),
  },
  {
    -- シェルから nvim + agent を WezTerm の2ペイン構成で開く
    key = "v",
    mods = "LEADER",
    action = open_nvim_with_agent("claude -y"),
  },
  {
    --workspaceの名前変更
    key = "E",
    mods = "ALT",
    action = act.PromptInputLine({
      description = "(wezterm) Set workspace title:",
      action = wezterm.action_callback(function(win, pane, line)
        if line then
          wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
        end
      end),
    }),
  },
  {
    -- タブ名変更
    key = "e",
    mods = "ALT",
    action = act.PromptInputLine({
      description = "タブ名を入力してください",
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
  {
    key = "W",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "(wezterm) Create new workspace:",
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(
            act.SwitchToWorkspace({
              name = line,
            }),
            pane
          )
        end
      end),
    }),
  },
  -- コマンドパレット表示
  { key = "p", mods = "CTRL", action = act.ActivateCommandPalette },
  -- Tab移動
  { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
  { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
  -- Tab入れ替え
  { key = ",", mods = "ALT", action = act({ MoveTabRelative = -1 }) },
  -- Tab新規作成: Azure mux ドメインで開く（永続。VM 停止中は <leader> a で起こしてから）
  {
    key = "t",
    mods = "CTRL",
    action = spawn_mux_tab(),
  },
  -- Tabを閉じる
  { key = "w", mods = "CTRL", action = act({ CloseCurrentTab = { confirm = true } }) },
  { key = ".", mods = "ALT", action = act({ MoveTabRelative = 1 }) },

  -- 画面モード切り替え: 通常 -> 最大化（タスクバーを残す） -> フルスクリーン -> 通常
  { key = "Enter", mods = "ALT", action = cycle_window_mode() },

  -- コピーモード
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
  -- コピー
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  -- 貼り付け
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- Pane作成 leader + r or d（現在ペインと同じドメイン・同じディレクトリで分割）
  { key = "d", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "r", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  -- Paneを閉じる leader + x
  { key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = true } }) },
  -- Pane移動 Alt + hjkl
  -- その方向に WezTerm pane があれば移動し、無ければアプリ側へ Alt+hjkl を渡す
  { key = "h", mods = "ALT", action = activate_pane_or_send_alt("Left", "h") },
  { key = "l", mods = "ALT", action = activate_pane_or_send_alt("Right", "l") },
  { key = "k", mods = "ALT", action = activate_pane_or_send_alt("Up", "k") },
  { key = "j", mods = "ALT", action = activate_pane_or_send_alt("Down", "j") },
  -- Pane選択
  { key = "[", mods = "CTRL|SHIFT", action = act.PaneSelect },
  -- 選択中のPaneのみ表示
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

  -- フォントサイズ切替
  { key = "+", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  -- フォントサイズのリセット
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- タブ切替 Ctrl + 数字
  { key = "1", mods = "CTRL", action = act.ActivateTab(0) },
  { key = "2", mods = "CTRL", action = act.ActivateTab(1) },
  { key = "3", mods = "CTRL", action = act.ActivateTab(2) },
  { key = "4", mods = "CTRL", action = act.ActivateTab(3) },
  { key = "5", mods = "CTRL", action = act.ActivateTab(4) },
  { key = "6", mods = "CTRL", action = act.ActivateTab(5) },
  { key = "7", mods = "CTRL", action = act.ActivateTab(6) },
  { key = "8", mods = "CTRL", action = act.ActivateTab(7) },
  { key = "9", mods = "CTRL", action = act.ActivateTab(-1) },

  -- コマンドパレット
  { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
  -- 設定再読み込み
  { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
  -- デバッグオーバーレイ（問題調査用）
  { key = "l", mods = "SHIFT|CTRL", action = act.ShowDebugOverlay },
  -- キーテーブル用
  { key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
  -- Pane入れ替え Alt + n/p
  { key = "n", mods = "ALT", action = act.RotatePanes("Clockwise") },
  { key = "p", mods = "ALT", action = act.RotatePanes("CounterClockwise") },
  {
    -- ペインをオーバーレイ表示して選択（tmux display-panes 相当）
    key = "p",
    mods = "LEADER",
    action = act.PaneSelect({ alphabet = "1234567890", show_pane_ids = true }),
  },
  {
    -- ランチャーメニュー表示（Azure devbox / PowerShell 切り替えなど）
    key = "l",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "LAUNCH_MENU_ITEMS", title = "Launch" }),
  },
  {
    -- PowerShell を新規タブで開く
    key = "P",
    mods = "LEADER|SHIFT",
    action = act.SpawnCommandInNewTab({
      domain = { DomainName = "local" },
      args = { "pwsh.exe", "-NoLogo" },
    }),
  },
  {
    -- Azure devbox を新規タブで開く（停止中なら自動起動してから mux 接続）
    key = "a",
    mods = "LEADER",
    action = spawn_devbox_tab(),
  },
  {
    -- 最後に通知が来た Claude Code のペインへジャンプ（通知トーストの代わり）
    key = "j",
    mods = "LEADER",
    action = jump_to_notified_pane(),
  },
  {
    -- Azure mux ドメインに attach：既存の永続タブ/ペイン(claude 等)を丸ごと呼び戻す。
    -- スリープ/切断後の再接続はこれ（VM 停止中でも ensure が自動起動する）。
    key = "A",
    mods = "LEADER|SHIFT",
    action = attach_devbox_domain(),
  },
  {
    -- Azure mux ドメインから detach（ローカル表示を切り離す。Azure 側セッションは生存継続）。
    key = "D",
    mods = "LEADER|SHIFT",
    action = act.DetachDomain({ DomainName = DEVBOX_DOMAIN }),
  },
}

config.key_tables = {
  resize_pane = {
    { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
    { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "Enter", action = "PopKeyTable" },
  },
  activate_pane = {
    { key = "h", action = act.ActivatePaneDirection("Left") },
    { key = "l", action = act.ActivatePaneDirection("Right") },
    { key = "k", action = act.ActivatePaneDirection("Up") },
    { key = "j", action = act.ActivatePaneDirection("Down") },
  },
  copy_mode = {
    { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
    { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
    { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
    { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
    { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
    { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
    { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
    { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
    { key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
    { key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
    { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
    { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
    { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
    { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
    { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
    { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
    { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
    { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
    { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
    { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
    { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
    { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
    { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
    { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
    { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
    { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
    { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
    { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
    { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
    { key = "y", mods = "NONE", action = act.CopyTo("Clipboard") },
    {
      key = "Enter",
      mods = "NONE",
      action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
    },
    { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
    { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
    { key = "q", mods = "NONE", action = act.CopyMode("Close") },
  },
}



return config
