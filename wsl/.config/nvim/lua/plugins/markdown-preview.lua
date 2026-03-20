return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_port = "8080"
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_open_ip = "100.120.150.49"  -- Tailscale IP
      vim.g.mkdp_open_browser_preview = 0  -- ブラウザ自動起動しない
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
  },
}
