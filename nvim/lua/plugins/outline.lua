return {
  "hedyhli/outline.nvim",
  enabled = require("features").outline,
  cmd = { "Outline", "OutlineOpen" },
  keys = {
    { "<leader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
  },
  opts = {
    outline_window = {
      auto_jump = true,
    },
    providers = {
      priority = { "markdown", "lsp", "norg", "man" },
      markdown = {
        filetypes = { "markdown" },
      },
    },
  },
}
