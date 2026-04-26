return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- lazy.nvim がリセットした rtp にパーサーインストール先を追加
      local site = vim.fn.stdpath("data") .. "/site"
      if not vim.tbl_contains(vim.opt.rtp:get(), site) then
        vim.opt.rtp:prepend(site)
      end

      local ts = require("nvim-treesitter")

      -- 起動時に主要パーサーをインストール
      ts.install({ "lua", "vim", "vimdoc", "query", "c_sharp", "yaml" }, { summary = false })

      -- FileType ごとに treesitter ハイライトを有効化
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter-auto", { clear = true }),
        pattern = { "*" },
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
        end,
      })
    end,
  },
}
