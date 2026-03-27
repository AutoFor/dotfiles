return {
  {
    "reybits/scratch.nvim",
    config = function()
      require("scratch").setup()

      -- <leader>n でスクラッチを開く/閉じる
      vim.keymap.set("n", "<leader>n", "<Cmd>Scratch<CR>", { silent = true, desc = "Toggle scratch pad" })
    end,
  },
}
