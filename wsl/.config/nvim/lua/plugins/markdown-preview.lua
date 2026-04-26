return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_port = ""
      vim.g.mkdp_open_to_the_world = 0
      vim.g.mkdp_echo_preview_url = 1  -- URLをコマンドラインに表示
      vim.g.mkdp_open_browser_preview = 0  -- ブラウザ自動起動しない
      -- WSL2はWindowsからlocalhost経由でアクセス可能
      vim.g.mkdp_open_ip = "127.0.0.1"
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
  },
}
