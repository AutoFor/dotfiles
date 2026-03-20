
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
    {
      "<leader>cf",
      function() require("codex").open() end,
      desc = "Focus Codex",
      mode = "n",
    },
  },
  opts = {
    autoinstall = true,  -- codex CLI が無ければ自動インストール
    panel = true,        -- true にするとサイドパネル表示
    width = 0.3,         -- Claude Code と同様に右 30% のパネル幅
  },
}
