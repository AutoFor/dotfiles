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

-- Fold (ufo/LSP ベース)
vim.opt.foldcolumn = "1"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

-- 外部変更の自動リロード
vim.opt.autoread = true
vim.api.nvim_create_autocmd("FileChangedShell", {
  callback = function()
    vim.v.fcs_choice = "reload"
  end,
})

local function executable(cmd)
  return vim.fn.executable(cmd) == 1
end

local function is_ssh_session()
  return vim.env.SSH_TTY or vim.env.SSH_CLIENT or vim.env.SSH_CONNECTION
end

local agent_terminal = require("agent_terminal")

vim.opt.clipboard = "unnamedplus"

-- d/x は黒穴レジスタに捨てる（クリップボードを汚さない）
vim.keymap.set({"n", "v"}, "d", '"_d', { silent = true })
vim.keymap.set({"n", "v"}, "D", '"_D', { silent = true })
vim.keymap.set({"n", "v"}, "x", '"_x', { silent = true })
vim.keymap.set({"n", "v"}, "X", '"_X', { silent = true })

if vim.fn.has("wsl") == 1 and executable("win32yank.exe") then
  -- WSL ローカルでは Windows クリップボードへ直接つなぐ
  if executable("wslview") then
    vim.ui.open = function(uri)
      vim.fn.jobstart({ "wslview", uri }, { detach = true })
    end
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
elseif is_ssh_session() then
  -- SSH 先では OSC52 で手元の端末クリップボードへ返す
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "osc52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end

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

vim.api.nvim_create_user_command("AgentTerminalDebugToggle", function()
  agent_terminal.toggle_debug()
end, {})

vim.api.nvim_create_user_command("AgentTerminalDebugInfo", function()
  local state = agent_terminal.collect_state()
  vim.notify(vim.inspect(state), vim.log.levels.INFO, { title = "agent-terminal" })
end, {})

vim.api.nvim_create_user_command("AgentTerminalDebugSend", function(opts)
  local text = opts.args ~= "" and opts.args or "agent-terminal-debug"
  local ok, result = agent_terminal.send(text .. "\n")
  if ok then
    vim.notify("sent debug text to buffer " .. result, vim.log.levels.INFO, { title = "agent-terminal" })
  else
    vim.notify("debug send failed: " .. result, vim.log.levels.WARN, { title = "agent-terminal" })
  end
end, { nargs = "?" })

-- Claude Code ウィンドウに入ったら自動でターミナルモードへ
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
  callback = function(args)
    local buf = vim.api.nvim_get_current_buf()
    agent_terminal.debug("autocmd event", {
      event = args.event,
      current = agent_terminal.describe_buffer(buf),
    })
    if agent_terminal.is_agent_terminal(buf) then
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == buf then
          agent_terminal.debug("autocmd startinsert", agent_terminal.describe_buffer(buf))
          vim.cmd("startinsert")
        end
      end)
    end
  end,
})

-- wezterm.exe のパス（WSL から Windows の wezterm CLI を叩く）
local wezterm = "/mnt/c/Program Files/WezTerm/wezterm.exe"

-- 起動時: 左に NvimTree を開き、WezTerm の右ペインを分割して Claude Code を開く
-- SSH 経由など wezterm cli が使えない場合は、nvim 内 terminal にフォールバックしない。
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.open()
    vim.schedule(function()
      if vim.env.WEZTERM_UNIX_SOCKET and vim.env.WEZTERM_UNIX_SOCKET ~= "" then
        -- WezTerm ネイティブ接続: 右ペインを分割して Claude Code を起動
        local cwd_win = vim.fn.trim(vim.fn.system("wslpath -w " .. vim.fn.shellescape(vim.fn.getcwd())))
        vim.fn.system({ wezterm, "cli", "split-pane", "--right", "--percent", "30", "--cwd", cwd_win })
      else
        -- WSL-SSH では WezTerm socket が見えないため、ここでは何もしない。
        -- 本物の WezTerm 2ペイン構成は WezTerm 側の LEADER+v で起動する。
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

-- <leader>y : 右隣のペイン（WezTermまたはnvim内ターミナル）に送信 + クリップボードにコピー
vim.keymap.set("v", "<leader>y", function()
  local s = visual_file_location()
  vim.fn.setreg("+", s)
  local ok = agent_terminal.send(s .. "\n")
  if not ok then
    print("copied (no agent terminal): " .. s)
    return
  end
  print("sent & copied: " .. s)
end, { desc = "Send file:line to right pane/window + copy to clipboard (visual)" })
