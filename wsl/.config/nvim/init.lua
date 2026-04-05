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

-- 行番号
vim.opt.number = true
vim.opt.relativenumber = true

-- Fold (Treesitter ベース)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- 外部変更の自動リロード
vim.opt.autoread = true
vim.api.nvim_create_autocmd("FileChangedShell", {
  callback = function()
    vim.v.fcs_choice = "reload"
  end,
})

vim.opt.clipboard = "unnamedplus"

-- d/x は黒穴レジスタに捨てる（クリップボードを汚さない）
vim.keymap.set({"n", "v"}, "d", '"_d', { silent = true })
vim.keymap.set({"n", "v"}, "D", '"_D', { silent = true })
vim.keymap.set({"n", "v"}, "x", '"_x', { silent = true })
vim.keymap.set({"n", "v"}, "X", '"_X', { silent = true })

if os.getenv("SSH_TTY") or os.getenv("SSH_CLIENT") then
  -- SSH 接続時は OSC 52 でローカルクリップボードに転送
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
elseif vim.fn.has("wsl") == 1 then
  -- WSL では vim.ui.open を wslview に向ける
  vim.ui.open = function(uri)
    vim.fn.jobstart({ "wslview", uri }, { detach = true })
  end

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

-- ターミナルモードを Esc×2 で抜けて左ウィンドウへ移動
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Exit terminal mode and move left" })
vim.keymap.set("t", "<A-Left><A-Left>", [[<C-\><C-n>]], { silent = true, desc = "Exit terminal mode" })
-- Ctrl+Home で左、Ctrl+End で右ウィンドウへ移動（全モード対応）
vim.keymap.set("n", "<C-Home>", "<C-w>h", { silent = true, desc = "Move to left window" })
vim.keymap.set("n", "<C-End>", "<C-w>l", { silent = true, desc = "Move to right window" })
vim.keymap.set("i", "<C-Home>", "<Esc><C-w>h", { silent = true, desc = "Move to left window" })
vim.keymap.set("i", "<C-End>", "<Esc><C-w>l", { silent = true, desc = "Move to right window" })
vim.keymap.set("t", "<C-Home>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Exit terminal and move left" })
vim.keymap.set("t", "<C-End>", [[<C-\><C-n><C-w>l]], { silent = true, desc = "Exit terminal and move right" })

-- ウィンドウ移動を Alt+hjkl でショートカット（通常モード・ターミナルモード）
vim.keymap.set("n", "<A-h>", "<C-w>h", { silent = true, desc = "Left window" })
vim.keymap.set("n", "<A-l>", "<C-w>l", { silent = true, desc = "Right window" })
vim.keymap.set("n", "<A-j>", "<C-w>j", { silent = true, desc = "Down window" })
vim.keymap.set("n", "<A-k>", "<C-w>k", { silent = true, desc = "Up window" })
vim.keymap.set("t", "<A-h>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Left window (terminal)" })
vim.keymap.set("t", "<A-l>", [[<C-\><C-n><C-w>l]], { silent = true, desc = "Right window (terminal)" })
vim.keymap.set("t", "<A-j>", [[<C-\><C-n><C-w>j]], { silent = true, desc = "Down window (terminal)" })
vim.keymap.set("t", "<A-k>", [[<C-\><C-n><C-w>k]], { silent = true, desc = "Up window (terminal)" })
vim.keymap.set("n", "<leader>h", "<C-w>h", { silent = true, desc = "Left window" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { silent = true, desc = "Right window" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { silent = true, desc = "Down window" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { silent = true, desc = "Up window" })
vim.keymap.set("n", "<leader>w", "<C-w>w", { silent = true, desc = "Next window" })
vim.keymap.set("n", "<leader>c", "<C-w>c", { silent = true, desc = "Close window" })

-- :Codex で CodexToggle を呼ぶエイリアス
vim.api.nvim_create_user_command("Codex", function()
  vim.cmd("CodexToggle")
end, {})

-- :Claude で ClaudeCode を呼ぶエイリアス
vim.api.nvim_create_user_command("Claude", function()
  vim.cmd("ClaudeCode")
end, {})

-- Claude Code ウィンドウに入ったら自動でターミナルモードへ
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.bo.buftype == "terminal" and vim.fn.bufname():match("claude") then
      vim.cmd("startinsert")
    end
  end,
})

-- wezterm.exe のパス（WSL から Windows の wezterm CLI を叩く）
local wezterm = "/mnt/c/Program Files/WezTerm/wezterm.exe"

-- 起動時: 左に NvimTree を開き、WezTerm の右ペインを分割して Claude Code を開く
-- SSH 経由など wezterm cli が使えない場合は nvim 内で ClaudeCode を起動する
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.open()
    vim.schedule(function()
      if vim.env.WEZTERM_UNIX_SOCKET and vim.env.WEZTERM_UNIX_SOCKET ~= "" then
        -- WezTerm ネイティブ接続: 右ペインを分割して Claude Code を起動
        local cwd_win = vim.fn.trim(vim.fn.system("wslpath -w " .. vim.fn.shellescape(vim.fn.getcwd())))
        vim.fn.system({ wezterm, "cli", "split-pane", "--right", "--percent", "30", "--cwd", cwd_win })
      else
        -- SSH 経由など WezTerm ソケットがない場合: nvim 内で ClaudeCode を起動
        vim.cmd("ClaudeCode")
        vim.defer_fn(function()
          vim.cmd("wincmd p")
        end, 200)
      end
    end)
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

-- ビジュアル選択中の「相対パス:開始行-終了行」をクリップボードにコピー
local function visual_file_location()
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local start_line = vim.fn.line("v")
  local end_line   = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  if start_line == end_line then
    return string.format("%s:%d", file, start_line)
  else
    return string.format("%s:%d-%d", file, start_line, end_line)
  end
end

-- <leader>y : 右隣の WezTerm ペインに送信 + クリップボードにコピー
vim.keymap.set("v", "<leader>y", function()
  local s = visual_file_location()
  vim.fn.setreg("+", s)
  local pane_id = vim.fn.trim(vim.fn.system({ wezterm, "cli", "get-pane-direction", "right" }))
  if pane_id == "" then
    print("copied (no right pane): " .. s)
    return
  end
  -- ビジュアルモードを抜けてから送信・フォーカス移動
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  vim.fn.system({ wezterm, "cli", "send-text", "--no-paste", "--pane-id", pane_id, s .. "\n" })
  vim.fn.system({ wezterm, "cli", "activate-pane", "--pane-id", pane_id })
  print("sent & copied: " .. s)
end, { desc = "Send file:line to WezTerm right pane + copy to clipboard (visual)" })
