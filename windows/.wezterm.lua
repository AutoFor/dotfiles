local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- WSL の ~/.last_dir から直近のディレクトリを取得
local function get_last_dir()
  local success, stdout = wezterm.run_child_process({
    "wsl.exe", "-e", "cat", "/home/seiya-kawashima/.last_dir",
  })
  if success and stdout and stdout ~= "" then
    return stdout:gsub("%s+$", "")
  end
  return nil
end

-- WezTerm 起動時に直近のディレクトリで開く
wezterm.on("gui-startup", function(cmd)
  local last_dir = get_last_dir()
  local args = cmd or {}
  if last_dir then
    args.cwd = last_dir
  end
  wezterm.mux.spawn_window(args)
end)


config.automatically_reload_config = true
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

-- WSL 関連
-- wsl_domains を明示することで ConPTY を経由せず WezTerm ネイティブ統合を使用する
-- → リサイズ時に Claude Code が固まる問題の軽減
config.wsl_domains = {
  {
    name = "WSL:Ubuntu",
    distribution = "Ubuntu",
    default_cwd = "/home/seiya-kawashima",
  },
}

-- SSH 経由で WSL に接続（wsl_domains より体感速度が速い場合がある）
-- 事前準備: WSL で sshd を 2222 番で起動し、Windows の公開鍵を authorized_keys に追加
config.ssh_domains = {
  {
    name = "WSL-SSH",
    remote_address = "127.0.0.1:2222",
    username = "seiya-kawashima",
    -- WSL に WezTerm をインストールした場合は "WezTermMux" に変更するとさらに速い
    multiplexing = "None",
  },
}

config.default_domain = "WSL-SSH"

-- ランチャーメニュー（LEADER + l で表示）
config.launch_menu = {
  {
    label = "PowerShell",
    args = { "pwsh.exe" },
  },
  {
    label = "WSL: Ubuntu (native)",
    domain = { DomainName = "WSL:Ubuntu" },
  },
  {
    label = "WSL: Ubuntu (SSH)",
    domain = { DomainName = "WSL-SSH" },
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

-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window, pane)
  local key_table = window:active_key_table()
  local workspace = wezterm.mux.get_active_workspace()
  local status = workspace
  if key_table then
    status = status .. "  TABLE: " .. key_table
  end
  window:set_right_status(status .. "  ")
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

config.keys = {
  {
    -- workspaceの切り替え
    key = "w",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Select workspace" }),
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
  -- Tab新規作成（常に WSL:Ubuntu で開く）
  {
    key = "t",
    mods = "CTRL",
    action = wezterm.action_callback(function(window, pane)
      local ok, cwd_uri = pcall(function()
        return pane:get_current_working_dir()
      end)
      local cwd = (ok and cwd_uri and cwd_uri.file_path) or get_last_dir()
      if cwd then
        window:perform_action(
          act.SpawnCommandInNewTab({ cwd = cwd, domain = { DomainName = "WSL-SSH" } }),
          pane
        )
      else
        window:perform_action(act.SpawnTab({ DomainName = "WSL-SSH" }), pane)
      end
    end),
  },
  -- Tabを閉じる
  { key = "w", mods = "CTRL", action = act({ CloseCurrentTab = { confirm = true } }) },
  { key = ".", mods = "ALT", action = act({ MoveTabRelative = 1 }) },

  -- 画面フルスクリーン切り替え
  { key = "Enter", mods = "ALT", action = act.ToggleFullScreen },

  -- コピーモード
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
  -- コピー
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  -- 貼り付け
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- Pane作成 leader + r or d
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
    -- ランチャーメニュー表示（PowerShell / WSL 切り替えなど）
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
