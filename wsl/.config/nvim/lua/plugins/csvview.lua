return {
  "hat0uma/csvview.nvim",
  opts = {
    view = {
      display_mode = "border",
      header_lnum = true,
      sticky_header = { enabled = true },
    },
  },
  cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  ft = { "csv", "tsv" },
  config = function(_, opts)
    require("csvview").setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "csv", "tsv" },
      callback = function()
        require("csvview").enable()
        -- Tab/S-Tab でファイル全体のコンマを前後に移動（検索レジスタを汚さない）
        vim.keymap.set("n", "<Tab>", function() vim.fn.search(",") end,
          { buffer = true, silent = true, desc = "Next comma" })
        vim.keymap.set("n", "<S-Tab>", function() vim.fn.search(",", "b") end,
          { buffer = true, silent = true, desc = "Previous comma" })
      end,
    })
  end,
}
