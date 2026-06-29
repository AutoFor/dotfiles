return {
  {
    "rebelot/kanagawa.nvim",
    enabled = require("features").colorscheme,
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        background = {
          dark = "dragon",
          light = "lotus",
        },
      })
      vim.cmd("colorscheme kanagawa-dragon")
    end,
  },
}
