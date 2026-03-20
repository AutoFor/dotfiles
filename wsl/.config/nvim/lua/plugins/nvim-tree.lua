
return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true

      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        on_attach = function(bufnr)
          local api = require("nvim-tree.api")

          local function opts(desc)
            return {
              desc = "nvim-tree: " .. desc,
              buffer = bufnr,
              noremap = true,
              silent = true,
              nowait = true,
            }
          end

          api.config.mappings.default_on_attach(bufnr)

          -- Tab: フォーカスを保ったままファイルをプレビュー
          vim.keymap.set("n", "<Tab>", function()
            api.node.open.preview()
          end, opts("Preview file, keep focus in tree"))

          -- 絶対パス → クリップボード
          vim.keymap.set("n", "gy", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end
            vim.fn.setreg("+", node.absolute_path, "c")
            vim.notify("Copied ABS: " .. node.absolute_path)
          end, opts("Copy absolute path to clipboard"))

          -- Windows パス → クリップボード (WSL2用)
          vim.keymap.set("n", "gW", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end
            local result = vim.fn.system("wslpath -w " .. vim.fn.shellescape(node.absolute_path))
            if vim.v.shell_error ~= 0 then
              vim.notify("wslpath failed: " .. result, vim.log.levels.ERROR)
              return
            end
            local win_path = result:gsub("\n$", "")
            -- OSC 52 でターミナル（WezTerm）経由でクリップボードに書き込む（SSH対応）
            local encoded = vim.fn.system({ "base64", "--wrap=0" }, win_path)
            io.write("\x1b]52;c;" .. encoded .. "\x07")
            io.flush()
            vim.notify("Copied WIN: " .. win_path)
          end, opts("Copy Windows path to clipboard"))

          -- フォルダ作成（カーソル位置の親ディレクトリに作成）
          vim.keymap.set("n", "A", function()
            local node = api.tree.get_node_under_cursor()
            local parent_path = (node.type == "directory") and node.absolute_path
              or vim.fn.fnamemodify(node.absolute_path, ":h")
            vim.ui.input({ prompt = "New directory: " }, function(name)
              if not name or name == "" then return end
              local path = parent_path .. "/" .. name
              vim.fn.mkdir(path, "p")
              api.tree.reload()
              vim.notify("Created: " .. path)
            end)
          end, opts("Create directory"))

          -- ファイル/フォルダを削除（確認あり・完全削除）
          vim.keymap.set("n", "dd", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end
            vim.ui.input({
              prompt = "Delete '" .. node.name .. "'? (y/N): ",
            }, function(input)
              if input == "y" or input == "Y" then
                api.fs.remove(node)
              end
            end)
          end, opts("Delete file/directory (permanent)"))

          -- 相対パス → クリップボード
          vim.keymap.set("n", "gr", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end
            local rel = vim.fn.fnamemodify(node.absolute_path, ":.")
            vim.fn.setreg("+", rel, "c")
            vim.notify("Copied REL: " .. rel)
          end, opts("Copy relative path to clipboard"))
        end,
      })

      vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>", { silent = true })

      local api = require("nvim-tree.api")

      -- Explorer フォーカス移動
      vim.keymap.set("n", "<leader>ef", function()
        api.tree.focus()
      end, { silent = true, desc = "Explorer: focus" })
      vim.keymap.set("n", "<leader>ee", "<C-w>l", { silent = true, desc = "Explorer: back to editor" })

      vim.keymap.set("n", "<leader>er", function()
        api.tree.change_root_to_node()
        api.tree.close()
        api.tree.open()
      end, { silent = true, noremap = true, desc = "NvimTree: re-root & reopen" })
    end,
  },
}
