return {
  "hat0uma/csvview.nvim",
  opts = {},
  cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  ft = { "csv", "tsv" },
  config = function()
    require("csvview").setup()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "csv", "tsv" },
      callback = function()
        require("csvview").enable()
      end,
    })
  end,
}
