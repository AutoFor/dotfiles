local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Azure 開発サーバー (devbox) 関連の定数
local DEVBOX_DOMAIN = "azure"
local DEVBOX_TMUX_DOMAIN = "devbox-tmux"
local DEVBOX_HOST = "100.126.96.27"   -- Tailscale IP（ノード固有で不変。MagicDNS: devbox.tail7bb5be.ts.net）
local DEVBOX_USER = "azureuser"
local DEVBOX_HOSTNAME = "devbox"      -- ステータス表示でネスト SSH と区別するために使う
-- dotfiles のパスを探す。環境変数 DOTFILES_DIR > ghq 既定パス > ~/dotfiles の順。
local function find_dotfiles_dir()
  local candidates = {
    os.getenv("DOTFILES_DIR"),
    wezterm.home_dir .. "\\ghq\\github.com\\AutoFor\\dotfiles",
    wezterm.home_dir .. "\\dotfiles",
  }
  for _, dir in ipairs(candidates) do
    if dir then
      local f = io.open(dir .. "\\windows\\bin\\devbox.ps1", "r")
      if f then
        f:close()
        return dir
      end
    end
  end
  return wezterm.home_dir .. "\\dotfiles"
end
local DOTFILES_DIR = find_dotfiles_dir()
-- VM 起動を担保するスクリプト
local DEVBOX_PS1 = DOTFILES_DIR .. "\\windows\\bin\\devbox.ps1"
-- クリックで通知元ペインへジャンプできるトーストを出すスクリプト（BurntToast）。
-- クリック時の wezterm-jump: URI は windows/bin/register-wezterm-jump.ps1 で登録したハンドラが処理する。
local NOTIFY_PS1 = DOTFILES_DIR .. "\\claude\\windows-notify.ps1"

local function sh_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- devbox の VM 起動を担保する。22番に届く場合は az を呼ばず即 return するため、
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

-- 現在ペインが devbox 上の tmux クライアント（devbox-tmux ドメインのタブ）かどうか。
-- ドメイン名で確実に判定できる。手動 ssh + tmux（ローカルタブから）も host で拾う。
local function is_tmux_client_pane(pane)
  local ok_domain, domain = pcall(function()
    return pane:get_domain_name()
  end)
  if ok_domain and domain == DEVBOX_TMUX_DOMAIN then
    return true
  end
  if ok_domain and domain ~= "local" then
    return false
  end
  local ok_cwd, cwd = pcall(function()
    return pane:get_current_working_dir()
  end)
  local host = (ok_cwd and cwd and cwd.host) and cwd.host or nil
  return host ~= nil and host:lower() == DEVBOX_HOSTNAME
end

local TMUX_PREFIX = "\x02" -- C-b

-- devbox の tmux クライアント上なら prefix+keys を tmux に送り、
-- それ以外（ローカルペイン・mux フォールバック）は WezTerm ネイティブ動作。
-- ペイン管理を tmux 側に一本化するためのブリッジ (#214 Phase 2)。
local function tmux_bridge(keys, fallback_action)
  return wezterm.action_callback(function(window, pane)
    if is_tmux_client_pane(pane) then
      window:perform_action(act.SendString(TMUX_PREFIX .. keys), pane)
    else
      window:perform_action(fallback_action, pane)
    end
  end)
end

-- WezTerm 起動時は devbox に SSH して tmux の main セッションに attach する (#214)。
-- 実際のウィンドウ生成は default_domain (devbox-tmux) に任せる。
-- ここで spawn_window すると SSH 接続の非同期性でデフォルトウィンドウ (cmd) が
-- 二重に開くレースがあるため、gui-startup では VM の起動担保だけ行う。
-- 接続前に devbox.ps1 ensure で VM の起動を担保する（接続は Tailscale 経由なので NSG 操作は不要）。
wezterm.on("gui-startup", function(cmd)
  ensure_devbox()
  if cmd then
    -- CLI から明示的にコマンド指定された場合 (wezterm start -- ...) はそれを尊重
    wezterm.mux.spawn_window(cmd)
  end
end)


config.automatically_reload_config = true
-- ウィンドウを閉じるときの確認を出さない。
-- セッションの実体は devbox の tmux が保持しているので (#214)、
-- WezTerm を閉じてもプロセスは失われない (tm で即復帰できる)
config.window_close_confirmation = "NeverPrompt"
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
  -- 通常の入口 (#214): WezTerm ネイティブ SSH (libssh) で接続し tmux main に attach。
  -- ssh.exe (ConPTY 経由) だと DA 応答の二重化やマウスシーケンスの欠落で
  -- ペインにゴミ文字が流れるため、必ずネイティブ SSH ドメインを使う。
  {
    name = DEVBOX_TMUX_DOMAIN,
    remote_address = DEVBOX_HOST,
    username = DEVBOX_USER,
    ssh_option = {
      identityfile = wezterm.home_dir .. "\\.ssh\\id_ed25519",
    },
    multiplexing = "None",
    assume_shell = "Posix",
    default_prog = { "tmux", "new-session", "-A", "-s", "main" },
  },
  -- 旧 wezterm mux ドメイン（切り分け用フォールバック）
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

-- 既定ドメインはネイティブ SSH + tmux (#214)。起動時のウィンドウはここに生成される。
-- VM 停止中に接続失敗した場合はウィンドウにエラーが表示されるので、
-- LEADER+l のランチャーから PowerShell を開いて切り分けする。
config.default_domain = DEVBOX_TMUX_DOMAIN

-- ランチャーメニュー（LEADER + l で表示）
config.launch_menu = {
  {
    -- 通常の入口: ネイティブ SSH + tmux main セッション（セッションはリモート tmux が保持）
    label = "Azure devbox (tmux main)",
    domain = { DomainName = DEVBOX_TMUX_DOMAIN },
  },
  {
    -- 旧 mux ドメイン（切り分け用フォールバック。通常は使わない）
    label = "Azure devbox (mux フォールバック)",
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
-- タブが一つの時も表示 (#214: tmux のウィンドウ一覧をタブバーに描画するため常時表示)
config.hide_tab_bar_if_only_one_tab = false
-- tmux ウィンドウ一覧を1つのタブ枠に並べて描画するため、タブ幅の上限を実質撤廃
config.tab_max_width = 999
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

-- 1つの tmux ウィンドウを WezTerm タブ風のセグメントとして描画する
local function tmux_tab_segment(items, text, is_active)
  local edge_background = "none"
  local background = is_active and "#ae8b2d" or "#5c6d74"
  table.insert(items, { Background = { Color = edge_background } })
  table.insert(items, { Foreground = { Color = background } })
  table.insert(items, { Text = SOLID_LEFT_ARROW })
  table.insert(items, { Background = { Color = background } })
  table.insert(items, { Foreground = { Color = "#FFFFFF" } })
  table.insert(items, { Text = " " .. text .. " " })
  table.insert(items, { Background = { Color = edge_background } })
  table.insert(items, { Foreground = { Color = background } })
  table.insert(items, { Text = SOLID_RIGHT_ARROW })
  table.insert(items, { Text = " " })
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  -- devbox-tmux ペイン: tmux のウィンドウ一覧（wezterm-tabs-sync が SetUserVar で
  -- 通知）をタブ風セグメントで並べる。切り替えは Ctrl+Tab / Ctrl+数字（表示専用）
  local store = wezterm.GLOBAL.tmux_windows or {}
  local data = tab.active_pane and store[tostring(tab.active_pane.pane_id)] or nil
  if data and data ~= "" then
    local items = {}
    for entry in data:gmatch("[^\t]+") do
      local is_active = entry:sub(-1) == "*"
      local text = is_active and entry:sub(1, -2) or entry
      tmux_tab_segment(items, text, is_active)
    end
    return items
  end

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

-- 右ステータス: 接続状態 / アクティブなキーテーブル / 日時
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
  if domain == DEVBOX_DOMAIN then
    -- 旧 mux ドメイン（切り分け用フォールバック）
    label = "MUX:" .. (host or DEVBOX_DOMAIN)
    color = "#e0af68"
  elseif host and host ~= "" and host:lower() ~= DEVBOX_HOSTNAME and domain ~= "local" then
    -- devbox からさらに別ホストへ素の ssh で入っている状態。切断でセッションも消える
    label = "SSH:" .. host
    color = "#f7768e"
  elseif domain == DEVBOX_TMUX_DOMAIN or (host and host:lower() == DEVBOX_HOSTNAME) then
    -- ネイティブ SSH + tmux の通常運用（セッションはリモート tmux が保持）
    label = "devbox"
    color = "#9ece6a"
  else
    label = domain
    color = "#9ece6a"
  end

  local items = {
    { Foreground = { Color = color } },
    { Text = wezterm.nerdfonts.md_server_network .. " " .. label },
  }
  local key_table = window:active_key_table()
  if key_table then
    table.insert(items, { Foreground = { Color = "#bb9af7" } })
    table.insert(items, { Text = "  TABLE: " .. key_table })
  end
  table.insert(items, { Foreground = { Color = "#a9b1d6" } })
  table.insert(items, { Text = "  " .. wezterm.strftime("%m/%d %H:%M") })
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

-- 画面モード切り替え: 通常 -> 最大化 -> フルスクリーン -> 通常。
-- 「タスクバーを覆わない最大化」は OS 標準の最大化そのものなので
-- ネイティブの window:maximize() を使う（座標計算は不要）
local function cycle_window_mode()
  return wezterm.action_callback(function(window, pane)
    local window_id = window:window_id()
    local dimensions = window:get_dimensions()
    local mode = window_mode_by_id[window_id] or "normal"

    if dimensions.is_full_screen then
      mode = "fullscreen"
    end

    if mode == "normal" then
      window:maximize()
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

-- devbox の VM 起動を担保してから、ssh + tmux main セッションのタブを開く。
-- 休止/切断後の復帰はこれ（セッションはリモート tmux が保持しているので丸ごと戻る）。
local function spawn_devbox_tmux_tab()
  return wezterm.action_callback(function(window, pane)
    ensure_devbox()
    window:perform_action(
      act.SpawnCommandInNewTab({
        domain = { DomainName = DEVBOX_TMUX_DOMAIN },
      }),
      pane
    )
  end)
end

-- devbox の VM 起動を担保してから、Azure mux ドメインに attach する。
-- 旧 mux セッションの切り分け用フォールバック。
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
    if is_tmux_client_pane(pane) then
      -- tmux タブ: nvimc (zshrc) が tmux split-window で agent ペインごと開く
      window:perform_action(act.SendString("nvimc .\n"), pane)
      return
    end
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
local claude_notify_tmux = {} -- pane_id -> 通知元 tmux ペイン番号（%なし。最新の通知が勝つ）

local function claude_notify_forget(pane_id)
  claude_notified[pane_id] = nil
  claude_notify_tmux[pane_id] = nil
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
        -- フォーカス変更でマークが消える前に通知元 tmux ペインを取り出しておく
        local tmux_pane = claude_notify_tmux[target]
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
        -- tmux 側も通知元ペインへ移動する。キーストローク注入は経路によって tmux に
        -- 届かないことがあるため、devbox 側の tmux-jump-pane を ssh で呼ぶ
        -- （最適なクライアントの選択もそちらに集約。tm のグループセッション対応）。
        if tmux_pane then
          pcall(wezterm.background_child_process, {
            (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\OpenSSH\\ssh.exe",
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
            "devbox", "~/.local/bin/tmux-jump-pane '%" .. tmux_pane .. "'",
          })
        end
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
  if name == "tmux_windows" then
    -- tmux のウィンドウ一覧 (wezterm-tabs-sync が送信)。タブバー描画に使う
    local store = wezterm.GLOBAL.tmux_windows or {}
    store[tostring(pane:pane_id())] = value
    wezterm.GLOBAL.tmux_windows = store
    return
  end

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
    -- payload: "ディレクトリ名\tタイトル\tメッセージ\ttmuxペイン番号"
    -- （notify.sh が base64 で送信、WezTerm が復号済み。4番目は旧形式だと無い）
    local pane_id = pane:pane_id()
    -- 通知元ペインを見ているときはマーク・トースト不要
    if window:is_focused() and window:active_pane():pane_id() == pane_id then
      return
    end
    local dir, title, message, tmux_pane =
      value:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t?([^\t]*)")
    if not dir then
      dir = value:match("^([^\t]*)") or ""
      title, message, tmux_pane = "", "", ""
    end
    claude_notify_tmux[pane_id] = (tmux_pane ~= "" and tmux_pane) or nil
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
    -- クリックで通知元ペインへジャンプできる Windows トーストを出す
    local url = "wezterm-jump:" .. pane_id
    if tmux_pane ~= "" then
      url = url .. "/" .. tmux_pane
    end
    pcall(wezterm.background_child_process, {
      "pwsh.exe", "-NoProfile", "-NonInteractive",
      "-File", NOTIFY_PS1,
      "-Title", (title ~= "" and title) or "Claude Code",
      "-Message", message or "",
      "-LaunchUri", url,
    })
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
  ----------------------------------------------------
  -- Window/Tab/Pane 管理は tmux に一本化 (#214)。
  -- 以下のタブ/ペイン系キーは devbox の tmux 上でのみ動作し、tmux の prefix
  -- シーケンスに変換される。ローカルペイン (PowerShell 等) では何もしない。
  ----------------------------------------------------

  -- Tab (実体は tmux ウィンドウ。画面下部のステータスラインに表示)
  { key = "t", mods = "CTRL", action = tmux_bridge("c", act.Nop) }, -- 新規
  { key = "w", mods = "CTRL", action = tmux_bridge("&", act.Nop) }, -- 閉じる (確認なし)
  { key = "Tab", mods = "CTRL", action = tmux_bridge("n", act.Nop) }, -- 次へ
  { key = "Tab", mods = "SHIFT|CTRL", action = tmux_bridge("p", act.Nop) }, -- 前へ
  { key = ",", mods = "ALT", action = tmux_bridge("<", act.Nop) }, -- 左へ入れ替え
  { key = ".", mods = "ALT", action = tmux_bridge(">", act.Nop) }, -- 右へ入れ替え
  { key = "e", mods = "ALT", action = tmux_bridge(",", act.Nop) }, -- 名前変更
  { key = "w", mods = "LEADER", action = tmux_bridge("w", act.Nop) }, -- ウィンドウ一覧から選択
  -- タブ切替 Ctrl + 数字 (tmux ウィンドウ番号。base-index 1)
  { key = "1", mods = "CTRL", action = tmux_bridge("1", act.Nop) },
  { key = "2", mods = "CTRL", action = tmux_bridge("2", act.Nop) },
  { key = "3", mods = "CTRL", action = tmux_bridge("3", act.Nop) },
  { key = "4", mods = "CTRL", action = tmux_bridge("4", act.Nop) },
  { key = "5", mods = "CTRL", action = tmux_bridge("5", act.Nop) },
  { key = "6", mods = "CTRL", action = tmux_bridge("6", act.Nop) },
  { key = "7", mods = "CTRL", action = tmux_bridge("7", act.Nop) },
  { key = "8", mods = "CTRL", action = tmux_bridge("8", act.Nop) },
  { key = "9", mods = "CTRL", action = tmux_bridge("9", act.Nop) },

  -- Pane (tmux ペイン)
  { key = "d", mods = "LEADER", action = tmux_bridge("-", act.Nop) }, -- 上下分割
  { key = "r", mods = "LEADER", action = tmux_bridge("|", act.Nop) }, -- 左右分割
  { key = "x", mods = "LEADER", action = tmux_bridge("x", act.Nop) }, -- 閉じる (確認なし)
  { key = "z", mods = "LEADER", action = tmux_bridge("z", act.Nop) }, -- ズーム (トグル)
  { key = "p", mods = "LEADER", action = tmux_bridge("q", act.Nop) }, -- ペイン番号を表示して選択
  -- Pane移動 Alt + hjkl: WezTerm → tmux → nvim の順で、その方向に無ければ透過
  { key = "h", mods = "ALT", action = activate_pane_or_send_alt("Left", "h") },
  { key = "l", mods = "ALT", action = activate_pane_or_send_alt("Right", "l") },
  { key = "k", mods = "ALT", action = activate_pane_or_send_alt("Up", "k") },
  { key = "j", mods = "ALT", action = activate_pane_or_send_alt("Down", "j") },
  -- ペインサイズ調整は tmux 側 (prefix + H/J/K/L、またはマウスドラッグ)

  -- Session (tmux セッション。旧 workspace の代替。tm <名前> で作成)
  { key = "s", mods = "LEADER", action = tmux_bridge("s", act.Nop) }, -- セッション一覧から選択

  -- コピーモード (tmux 内は tmux copy-mode、ローカルペインは WezTerm copy mode)
  { key = "[", mods = "LEADER", action = tmux_bridge("[", act.ActivateCopyMode) },
  -- クリップボード
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  {
    -- シェルから nvim + agent の2ペイン構成で開く (tmux 内は nvimc に委譲)
    key = "v",
    mods = "LEADER",
    action = open_nvim_with_agent("claude -y"),
  },

  -- 画面モード切り替え: 通常 -> 最大化（タスクバーを残す） -> フルスクリーン -> 通常
  { key = "Enter", mods = "ALT", action = cycle_window_mode() },

  -- フォントサイズ切替
  { key = "+", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  -- フォントサイズのリセット
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- コマンドパレット
  { key = "p", mods = "CTRL", action = act.ActivateCommandPalette },
  { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
  -- 設定再読み込み
  { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
  -- デバッグオーバーレイ（問題調査用）
  { key = "l", mods = "SHIFT|CTRL", action = act.ShowDebugOverlay },
  {
    -- ランチャーメニュー表示（Azure devbox / PowerShell 切り替えなど）
    key = "l",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "LAUNCH_MENU_ITEMS", title = "Launch" }),
  },
  {
    -- QuickSelect: 画面上の URL / パス / ハッシュ等にラベルを振り、
    -- ラベルを打つとクリップボードへコピー。折り返した URL もマウス不要で拾える
    key = "u",
    mods = "LEADER",
    action = act.QuickSelect,
  },
  -- 画面に見えているペイン全体をまるごとコピー (tmux の prefix+Y にブリッジ)
  { key = "y", mods = "LEADER", action = tmux_bridge("Y", act.Nop) },
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
    -- Azure devbox を新規タブで開く（停止中なら自動起動してから ssh + tmux main に attach）
    key = "a",
    mods = "LEADER",
    action = spawn_devbox_tmux_tab(),
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
  -- WezTerm copy mode (ローカルペイン用。tmux 内は tmux copy-mode を使う)
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
