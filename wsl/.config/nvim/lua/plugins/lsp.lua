return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      if vim.fn.executable("yaml-language-server") == 1 then
        vim.lsp.config("yamlls", {
          capabilities = capabilities,
          settings = {
            yaml = {
              validate = true,
              completion = true,
              hover = true,
              keyOrdering = false,
            },
          },
        })

        vim.lsp.enable("yamlls")
      end
    end,
  },
}
