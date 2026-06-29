-- os_util.lua — OS 差分を吸収する共有ヘルパー
local M = {}

M.is_win = vim.fn.has("win32") == 1
M.is_wsl = vim.fn.has("wsl") == 1

-- 絶対パスをそのOSの「ネイティブ(Windows)パス」へ変換する。
-- WSL: wslpath -w で /mnt/c/... → C:\... に変換。
-- Windows: 既に Windows パスなのでそのまま返す。
function M.to_native_path(path)
  if M.is_wsl then
    local result = vim.fn.system("wslpath -w " .. vim.fn.shellescape(path))
    if vim.v.shell_error ~= 0 then
      return nil, "wslpath failed: " .. result
    end
    return (result:gsub("\n$", "")), nil
  end
  return path, nil
end

-- ファイル/ディレクトリを既定アプリ(Explorer)で開く。
function M.open_external(path)
  local native, err = M.to_native_path(path)
  if not native then
    vim.notify(err or "path conversion failed", vim.log.levels.ERROR)
    return false
  end
  local cmd
  if M.is_wsl then
    cmd = { "/mnt/c/Windows/explorer.exe", native }
  else
    cmd = { "explorer.exe", native }
  end
  local job_id = vim.fn.jobstart(cmd, { detach = true })
  -- explorer.exe は終了コードが不定なので job_id だけ確認
  if job_id <= 0 then
    vim.notify("Failed to open: " .. native, vim.log.levels.ERROR)
    return false
  end
  vim.notify("Opened: " .. native)
  return true
end

-- Explorer でファイルを選択状態にして開く（ディレクトリはそのまま開く）。
function M.reveal_in_explorer(path, is_dir)
  local native, err = M.to_native_path(path)
  if not native then
    vim.notify(err or "path conversion failed", vim.log.levels.ERROR)
    return false
  end
  local explorer = M.is_wsl and "/mnt/c/Windows/explorer.exe" or "explorer.exe"
  local cmd
  if is_dir then
    cmd = { explorer, native }
  else
    cmd = { explorer, "/select,", native }
  end
  local job_id = vim.fn.jobstart(cmd, { detach = true })
  if job_id <= 0 then
    vim.notify("Failed to open Explorer: " .. native, vim.log.levels.ERROR)
    return false
  end
  vim.notify("Opened Explorer: " .. native)
  return true
end

return M
