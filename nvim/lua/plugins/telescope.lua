local os_util = require("os_util")

-- telescope-fzf-native のビルドコマンドは OS で異なる。
-- WSL/Linux: make / Windows: cmake（要 cmake + C コンパイラ）
local fzf_build = os_util.is_win
  and "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build"
  or "make"

return {
  {
    "nvim-telescope/telescope.nvim",
    enabled = require("features").telescope,
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = fzf_build },
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

      -- fzf-native がビルドできていない環境（cmake/compiler 無し）でも
      -- telescope 自体は使えるよう、拡張ロードは握りつぶす。
      pcall(telescope.load_extension, "fzf")

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
