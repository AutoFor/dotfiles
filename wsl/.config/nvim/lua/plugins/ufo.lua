return {
  {
    "kevinhwang91/nvim-ufo",
    lazy = false,
    dependencies = {
      "kevinhwang91/promise-async",
    },
    config = function()
      require("ufo").setup({
        provider_selector = function(_, filetype, _)
          if filetype == "yaml" then
            return { "lsp", "indent" }
          end

          return { "treesitter", "indent" }
        end,
      })

      vim.keymap.set("n", "zR", function()
        require("ufo").openAllFolds()
      end, { silent = true, desc = "Open all folds" })

      vim.keymap.set("n", "zM", function()
        require("ufo").closeAllFolds()
      end, { silent = true, desc = "Close all folds" })
    end,
  },
}
