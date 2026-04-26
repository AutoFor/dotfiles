
return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local agent_terminal = require("agent_terminal")
      local blocked_media_extensions = {
        mp4 = true,
        mov = true,
        avi = true,
        mkv = true,
        webm = true,
        jpg = true,
        jpeg = true,
        zip = true,
        tar = true,
        gz = true,
        ["7z"] = true,
      }

      local function should_block_in_editor(node)
        if not node or node.type == "directory" or not node.name then
          return false
        end
        local ext = node.name:match("%.([^.]+)$")
        if not ext then
          return false
        end
        return blocked_media_extensions[ext:lower()] == true
      end

      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true

      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        filters = {
          git_ignored = false,
          custom = {
            "^\\.git$",
            "\\.mp3$", "\\.wav$", "\\.flac$", "\\.aac$",
            "\\.gif$", "\\.webp$", "\\.svg$",
            "\\.pdf$",
            "Zone\\.Identifier$",
          },
        },
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

          local function guarded_open(open_fn)
            return function()
              local node = api.tree.get_node_under_cursor()
              if should_block_in_editor(node) then
                vim.notify("Blocked in editor: " .. node.name)
                return
              end
              open_fn()
            end
          end

          vim.keymap.set("n", "<CR>", guarded_open(api.node.open.edit), opts("Open file"))
          vim.keymap.set("n", "o", guarded_open(api.node.open.edit), opts("Open file"))

          -- Tab: フォーカスを保ったままファイルをプレビュー
          vim.keymap.set("n", "<Tab>", guarded_open(api.node.open.preview), opts("Preview file, keep focus in tree"))

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

          -- Windows Explorer で開く (WSL2用)
          vim.keymap.set("n", "gE", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end

            local result = vim.fn.system("wslpath -w " .. vim.fn.shellescape(node.absolute_path))
            if vim.v.shell_error ~= 0 then
              vim.notify("wslpath failed: " .. result, vim.log.levels.ERROR)
              return
            end

            local win_path = result:gsub("\n$", "")
            local cmd
            if node.type == "directory" then
              cmd = { "/mnt/c/Windows/explorer.exe", win_path }
            else
              cmd = { "/mnt/c/Windows/explorer.exe", "/select,", win_path }
            end

            local job_id = vim.fn.jobstart(cmd, { detach = true })
            if job_id <= 0 then
              vim.notify("Failed to open Explorer: " .. win_path, vim.log.levels.ERROR)
              return
            end

            vim.notify("Opened Explorer: " .. win_path)
          end, opts("Open in Windows Explorer"))

          -- VSCode で開く (WSL Remote経由)
          vim.keymap.set("n", "gV", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end

            -- Remote WSL 拡張の wslCode.sh を動的に検索
            local wsl_ext = vim.fn.glob(
              "/mnt/c/Users/SeiyaKawashima/.vscode/extensions/ms-vscode-remote.remote-wsl-*/scripts/wslCode.sh",
              false, true)
            if #wsl_ext == 0 then
              vim.notify("Remote WSL extension not found", vim.log.levels.ERROR)
              return
            end
            table.sort(wsl_ext)
            local wsl_code_sh = wsl_ext[#wsl_ext]

            -- vscode-server のコミットハッシュを動的に取得
            local server_bins = vim.fn.glob(
              vim.fn.expand("~") .. "/.vscode-server/bin/*/bin/remote-cli/code",
              false, true)
            if #server_bins == 0 then
              vim.notify("VSCode server not found in ~/.vscode-server", vim.log.levels.ERROR)
              return
            end
            table.sort(server_bins)
            local commit = server_bins[#server_bins]:match("/.vscode%-server/bin/([^/]+)/")

            local electron = "/mnt/c/Users/SeiyaKawashima/AppData/Local/Programs/Microsoft VS Code/Code.exe"
            local job_id = vim.fn.jobstart(
              { wsl_code_sh, commit, "stable", electron, "code", ".vscode-server", node.absolute_path },
              { detach = true })
            if job_id <= 0 then
              vim.notify("Failed to open VSCode: " .. node.absolute_path, vim.log.levels.ERROR)
              return
            end
            vim.notify("Opened VSCode: " .. node.absolute_path)
          end, opts("Open in VSCode (WSL Remote)"))

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

          -- ファイル/フォルダを削除（確認あり・完全削除、マーク複数対応）
          vim.keymap.set("n", "dd", function()
            local marked = api.marks.list()
            if #marked > 0 then
              local names = vim.tbl_map(function(n) return n.name end, marked)
              vim.ui.input({
                prompt = #marked .. " files: " .. table.concat(names, ", ") .. " — Delete? (y/N): ",
              }, function(input)
                if input == "y" or input == "Y" then
                  for _, n in ipairs(marked) do
                    api.fs.remove(n)
                  end
                  api.marks.clear()
                end
              end)
            else
              local node = api.tree.get_node_under_cursor()
              if not node or not node.absolute_path then return end
              vim.ui.input({
                prompt = "Delete '" .. node.name .. "'? (y/N): ",
              }, function(input)
                if input == "y" or input == "Y" then
                  api.fs.remove(node)
                end
              end)
            end
          end, opts("Delete file/directory (permanent, supports marks)"))

          -- ファイルパスを claude ターミナルバッファに送信
          vim.keymap.set("n", "<leader>y", function()
            local node = api.tree.get_node_under_cursor()
            if not node or not node.absolute_path then return end
            local rel = vim.fn.fnamemodify(node.absolute_path, ":.")
            vim.fn.setreg("+", rel)
            local ok = agent_terminal.send(rel .. "\n")
            if not ok then
              vim.notify("copied (no agent terminal): " .. rel)
              return
            end
            vim.notify("sent & copied: " .. rel)
          end, opts("Send file path to agent terminal"))

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

      -- フォーカス移動
      vim.keymap.set("n", "<leader>tf", function()
        api.tree.focus()
      end, { silent = true, desc = "Tree: focus" })
      vim.keymap.set("n", "<leader>ef", "<C-w>l", { silent = true, desc = "Editor: focus" })

      vim.keymap.set("n", "<leader>tR", function()
        api.tree.reload()
      end, { silent = true, desc = "Tree: reload" })

      vim.keymap.set("n", "<leader>tr", function()
        api.tree.change_root_to_node()
        api.tree.close()
        api.tree.open()
      end, { silent = true, noremap = true, desc = "Tree: re-root & reopen" })
    end,
  },
}
