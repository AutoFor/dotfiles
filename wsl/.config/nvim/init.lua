-- lazy.nvim をブートストラップ
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- leader キー
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- プラグイン読み込み
require("lazy").setup({
  spec = {
    { import = "plugins" },  -- lua/plugins/*.lua を読む
  },
})

vim.opt.clipboard = "unnamedplus"

if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "win32yank-wsl",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 0,
  }
end

-- nvim-tree で <leader>y したら Windows クリップボードにパスを送る
vim.api.nvim_create_autocmd("FileType", {
  pattern = "NvimTree",
  callback = function()
    vim.keymap.set("n", "<leader>y", function()
      local api = require("nvim-tree.api")
      local node = api.tree.get_node_under_cursor()
      if node and node.absolute_path then
        vim.fn.setreg("+", node.absolute_path)  -- Windows クリップボード
        print("Copied: " .. node.absolute_path)
      end
    end, { buffer = true, silent = true })
  end,
})

-- ターミナルモードを Alt+q で抜ける
vim.keymap.set("t", "<A-q>", [[<C-\><C-n>]], { silent = true, desc = "Exit terminal mode" })

-- ウィンドウ移動を <leader> でショートカット
vim.keymap.set("n", "<leader>h", "<C-w>h", { silent = true, desc = "Left window" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { silent = true, desc = "Right window" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { silent = true, desc = "Down window" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { silent = true, desc = "Up window" })
vim.keymap.set("n", "<leader>w", "<C-w>w", { silent = true, desc = "Next window" })
vim.keymap.set("n", "<leader>c", "<C-w>c", { silent = true, desc = "Close window" })

-- 外部でファイルが変更されたら自動で再読込（Claude Code 連携用）
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "checktime",
})

-- :Codex で CodexToggle を呼ぶエイリアス
vim.api.nvim_create_user_command("Codex", function()
  vim.cmd("CodexToggle")
end, {})

-- :Claude で ClaudeCode を呼ぶエイリアス
vim.api.nvim_create_user_command("Claude", function()
  vim.cmd("ClaudeCode")
end, {})

-- 起動時に NvimTree と Claude を自動で開く
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.open()
    vim.cmd("ClaudeCode")
  end,
})

-- glow で markdown をプレビュー (<leader>md)
local function render_markdown_with_glow()
  local tempfile = vim.fn.tempname() .. ".md"
  local tempdir = vim.fn.fnamemodify(tempfile, ":h")
  vim.fn.system("mkdir -p " .. vim.fn.shellescape(tempdir))
  vim.cmd("write! " .. vim.fn.fnameescape(tempfile))
  vim.cmd("vsplit")
  vim.cmd("terminal glow -p " .. vim.fn.shellescape(tempfile))
  vim.cmd("startinsert!")
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set(
      "n",
      "<leader>md",
      render_markdown_with_glow,
      { silent = true, buffer = true, desc = "render markdown with glow" }
    )
  end,
})

