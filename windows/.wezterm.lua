local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

-- WSL 関連
config.wsl_domains = wezterm.default_wsl_domains()
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

  -- ペイン移動: Ctrl + 矢印
  {
    key = 'LeftArrow',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Down',
  },

  -- Ctrl+w で現在のペインを即閉じる
  {
    key = 'w',
    mods = 'CTRL',
    action = act.CloseCurrentPane { confirm = false },
  },
}

return config
