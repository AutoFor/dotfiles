return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")

      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" },
        },
        extensions = {
          fzf = {},
        },
      })

      telescope.load_extension("fzf")

      -- ファイル名検索
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope: find files" })
      -- テキスト全文検索
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope: live grep" })
      -- カーソル下の単語で検索
      vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Telescope: grep word under cursor" })
      -- 開いているバッファ一覧
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope: buffers" })
      -- 最近開いたファイル
      vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Telescope: recent files" })
    end,
  },
}
