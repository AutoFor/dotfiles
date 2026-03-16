-- ~/.config/nvim/lua/plugins/claudecode.lua
return {
  "coder/claudecode.nvim",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
  },
  config = function()
    require("claudecode").setup({
      terminal = {
        provider = "snacks",
        split_side = "right",
        split_width_percentage = 0.3,
      },
      diff_opts = {
        auto_close_on_accept = true,  -- 承認時に diff ウィンドウを自動で閉じる
        vertical_split = true,
        open_in_current_tab = true,
        keep_terminal_focus = true,
      },
    })

    local map = vim.keymap.set
    local opts = { silent = true, noremap = true }

    map("n", "<leader>ac", "<cmd>ClaudeCode<CR>", opts)
    map("n", "<leader>af", "<cmd>ClaudeCodeFocus<CR>", opts)
    map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<CR>", opts)
    map("v", "<leader>as", function()
      vim.cmd("ClaudeCodeSend")
      vim.defer_fn(function()
        vim.cmd("ClaudeCodeFocus")
      end, 50)
    end, opts)
    map("n", "<leader>av", function()                        -- 縦分割で Claude を開く
      vim.cmd("vsplit")
      vim.cmd("terminal claude")
      vim.cmd("startinsert")
    end, opts)
    map("n", "<leader>ah", function()                        -- 横分割で Claude を開く
      vim.cmd("split")
      vim.cmd("terminal claude")
      vim.cmd("startinsert")
    end, opts)
  end,
}
