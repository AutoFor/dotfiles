
-- ~/.config/nvim/lua/plugins/codex.lua
return {
  "johnseth97/codex.nvim",
  lazy = true,
  cmd = { "Codex", "CodexToggle" },
  keys = {
    {
      "<leader>cx",
      function() require("codex").toggle() end,
      desc = "Toggle Codex",
      mode = { "n", "t" },
    },
  },
  opts = {
    autoinstall = true,  -- codex CLI が無ければ自動インストール
    panel = false,       -- true にするとサイドパネル表示
  },
}
