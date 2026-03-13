local wezterm = require 'wezterm'
local act = wezterm.action

-- パスから末尾ディレクトリ名だけ取り出す
local function basename(path)
  path = path:gsub('^file://', '')
  return path:gsub('(.*[/\\])(.*)', '%2')
end

-- ウィンドウタイトルにカレントディレクトリ名を表示
wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  if not pane then
    return 'WezTerm'
  end
  local cwd = basename(tostring(pane.current_working_dir or ''))
  if cwd == '' then
    return 'WezTerm'
  end
  return cwd .. ' - WezTerm'
end)

local config = wezterm.config_builder()

-- WSL 関連（tmux 自動起動）
local wsl_domains = wezterm.default_wsl_domains()
for _, dom in ipairs(wsl_domains) do
  if dom.name == 'WSL:Ubuntu' then
    dom.default_prog = { 'tmux', 'new-session', '-A', '-s', 'main' }
  end
end
config.wsl_domains = wsl_domains
config.default_domain = 'WSL:Ubuntu'

-- Leader キー（Ctrl+q）
config.leader = {
  key = 'q',
  mods = 'CTRL',
  timeout_milliseconds = 1000,
}

config.keys = {
  -- Ctrl+q → Ctrl+q で左右分割
  {
    key = 'q',
    mods = 'LEADER|CTRL',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },

  -- Ctrl+q → a で上下分割
  {
    key = 'a',
    mods = 'LEADER',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },

  -- Ctrl+w で現在のペインを即閉じる
  {
    key = 'w',
    mods = 'CTRL',
    action = act.CloseCurrentPane { confirm = false },
  },

  -- Ctrl+Shift+A でスクロールバック全体をクリップボードにコピー
  {
    key = 'A',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local dims = pane:get_dimensions()
      local text = pane:get_lines_as_text(dims.scrollback_rows)
      window:copy_to_clipboard(text, 'Clipboard')
    end),
  },
}

return config
