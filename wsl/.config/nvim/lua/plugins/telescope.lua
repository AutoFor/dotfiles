return {
  {
    "nvim-telescope/telescope.nvim",
dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")
      local actions = require("telescope.actions")

      -- ファイルを開いた後に nvim-tree でそのファイルを選択状態にする
      local function open_and_reveal(prompt_bufnr)
        actions.select_default(prompt_bufnr)
        require("nvim-tree.api").tree.find_file({ open = true, focus = false })
      end

      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" },
          mappings = {
            i = { ["<CR>"] = open_and_reveal },
            n = { ["<CR>"] = open_and_reveal },
          },
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
