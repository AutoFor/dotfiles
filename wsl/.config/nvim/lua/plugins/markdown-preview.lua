return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_port = ""
      vim.g.mkdp_open_to_the_world = 1
      vim.g.mkdp_echo_preview_url = 1  -- URLをコマンドラインに表示
      vim.g.mkdp_open_browser_preview = 0  -- ブラウザ自動起動しない
      -- SSH経由（Tailscale端末）はTailscale IP、ローカルはlocalhost
      if os.getenv("SSH_CLIENT") or os.getenv("SSH_TTY") then
        local handle = io.popen("tailscale ip -4 2>/dev/null")
        local ip = handle and handle:read("*l") or "100.120.150.49"
        if handle then handle:close() end
        vim.g.mkdp_open_ip = ip
      else
        vim.g.mkdp_open_ip = "127.0.0.1"
      end
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
  },
}
