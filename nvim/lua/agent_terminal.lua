local M = {}

M.debug_enabled = false

local function lower(value)
  if type(value) ~= "string" then
    return ""
  end
  return value:lower()
end

local function buf_term_title(buf)
  local ok, value = pcall(function()
    return vim.b[buf].term_title
  end)
  if ok and type(value) == "string" then
    return value
  end
  return ""
end

local function matches_agent_text(value)
  local text = lower(value)
  return text:match("claude") or text:match("codex")
end

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO, { title = "agent-terminal" })
  end)
end

local function set_wezterm_user_var(name, value)
  local encoded = vim.base64.encode(value)
  local osc = string.format("\027]1337;SetUserVar=%s=%s\007", name, encoded)
  local ok = pcall(vim.api.nvim_chan_send, vim.v.stderr, osc)
  return ok
end

-- tmux 内なら右隣のペインに直接送る (WezTerm 非依存)。右にペインが無ければ false
local function send_tmux_right_pane(text)
  if not (vim.env.TMUX and vim.env.TMUX ~= "") then
    return false
  end
  local at_right = vim.fn.trim(vim.fn.system({ "tmux", "display-message", "-p", "#{pane_at_right}" }))
  if at_right ~= "0" then
    return false
  end
  vim.fn.system({ "tmux", "send-keys", "-t", "{right-of}", "-l", text })
  if vim.v.shell_error ~= 0 then
    return false
  end
  vim.fn.system({ "tmux", "select-pane", "-R" })
  return true
end

function M.send_wezterm_right_pane(text)
  if send_tmux_right_pane(text) then
    M.debug("send: tmux right pane", { text = text })
    return true, "tmux-right-pane"
  end
  local ok = set_wezterm_user_var("send_to_right_agent_pane", text)
  if ok then
    M.debug("send: fallback to wezterm right pane", { text = text })
    return true, "wezterm-right-pane"
  end
  return false, "wezterm user var failed"
end

function M.debug(message, data)
  if not M.debug_enabled then
    return
  end

  local parts = { message }
  if data ~= nil then
    table.insert(parts, vim.inspect(data))
  end
  notify(table.concat(parts, "\n"), vim.log.levels.INFO)
end

function M.is_agent_terminal(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.bo[buf].buftype ~= "terminal" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local title = buf_term_title(buf)
  local filetype = vim.bo[buf].filetype

  return matches_agent_text(name) or matches_agent_text(title) or matches_agent_text(filetype)
end

function M.describe_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return {
      valid = false,
      buf = buf,
    }
  end

  local ok_chan, chan = pcall(function()
    return vim.bo[buf].channel
  end)

  return {
    valid = true,
    buf = buf,
    name = vim.api.nvim_buf_get_name(buf),
    buftype = vim.bo[buf].buftype,
    filetype = vim.bo[buf].filetype,
    term_title = buf_term_title(buf),
    channel = ok_chan and chan or nil,
    is_agent_terminal = M.is_agent_terminal(buf),
  }
end

local function list_visible_terminal_wins()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local terminals = {}

  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      local row, col = unpack(vim.api.nvim_win_get_position(win))
      table.insert(terminals, {
        win = win,
        buf = buf,
        row = row,
        col = col,
      })
    end
  end

  table.sort(terminals, function(a, b)
    if a.col == b.col then
      return a.row < b.row
    end
    return a.col > b.col
  end)

  return terminals
end

function M.find_agent_terminal()
  M.debug("find_agent_terminal: visible terminals", list_visible_terminal_wins())

  for _, item in ipairs(list_visible_terminal_wins()) do
    if M.is_agent_terminal(item.buf) then
      M.debug("find_agent_terminal: matched visible agent terminal", M.describe_buffer(item.buf))
      return item.buf
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if M.is_agent_terminal(buf) then
      M.debug("find_agent_terminal: matched hidden agent terminal", M.describe_buffer(buf))
      return buf
    end
  end

  local visible_terminals = list_visible_terminal_wins()
  if #visible_terminals > 0 then
    M.debug("find_agent_terminal: fallback visible terminal", M.describe_buffer(visible_terminals[1].buf))
    return visible_terminals[1].buf
  end

  M.debug("find_agent_terminal: no terminal found")
  return nil
end

function M.send(text)
  local buf = M.find_agent_terminal()
  if not buf then
    M.debug("send: no target terminal", { text = text })
    return M.send_wezterm_right_pane(text)
  end

  local chan = vim.bo[buf].channel
  if not chan or chan == 0 then
    M.debug("send: target has no channel", M.describe_buffer(buf))
    return M.send_wezterm_right_pane(text)
  end

  M.debug("send: target selected", {
    target = M.describe_buffer(buf),
    text = text,
  })
  vim.api.nvim_chan_send(chan, text)
  return true, buf
end

function M.toggle_debug()
  M.debug_enabled = not M.debug_enabled
  notify("debug " .. (M.debug_enabled and "enabled" or "disabled"))
  return M.debug_enabled
end

function M.collect_state()
  local current = vim.api.nvim_get_current_buf()
  local visible = {}
  for _, item in ipairs(list_visible_terminal_wins()) do
    table.insert(visible, {
      win = item.win,
      row = item.row,
      col = item.col,
      buffer = M.describe_buffer(item.buf),
    })
  end

  local matched = M.find_agent_terminal()

  return {
    cwd = vim.fn.getcwd(),
    current = M.describe_buffer(current),
    matched = matched and M.describe_buffer(matched) or nil,
    ssh = {
      SSH_TTY = vim.env.SSH_TTY,
      SSH_CLIENT = vim.env.SSH_CLIENT,
      SSH_CONNECTION = vim.env.SSH_CONNECTION,
      WEZTERM_UNIX_SOCKET = vim.env.WEZTERM_UNIX_SOCKET,
      TERM = vim.env.TERM,
    },
    visible_terminals = visible,
  }
end

return M
