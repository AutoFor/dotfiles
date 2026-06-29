-- features.lua — どのプラグイン/機能を読み込むかを一元管理する。
--
-- 決定の優先順位:
--   1. nvim/lua/features_local.lua があれば、その戻り値テーブルで最終上書き（.gitignore 済み）
--   2. 環境変数 NVIM_PROFILE = "core" | "full" | "auto"（既定 "auto"）
--   3. "auto" のときは外部コマンドの有無で自動判定
--
-- 各 plugins/*.lua は `enabled = require("features").<name>` で参照する。

local function has_exec(cmd)
  return vim.fn.executable(cmd) == 1
end

-- treesitter は C コンパイラが必要。Windows では zig/clang/cc/gcc いずれか。
local function has_compiler()
  return has_exec("cc") or has_exec("gcc") or has_exec("clang") or has_exec("zig")
end

local profile = (vim.env.NVIM_PROFILE or "auto"):lower()

-- 外部依存のない「コア」機能。常に true。
local core = {
  colorscheme = true,
  bufremove = true,
  csvview = true,
  outline = true,
  scratch = true,
  ufo = true,
  auto_reload = true,
  nvim_tree = true,
}

-- 外部依存のある機能。プロファイルに応じて決める。
local function resolve_optional()
  if profile == "core" then
    return {
      telescope = false,
      treesitter = false,
      markdown_preview = false,
      lsp_yaml = false,
      octo = false,
      claudecode = false,
      codex = false,
      glow_preview = false,
    }
  elseif profile == "full" then
    return {
      telescope = true,
      treesitter = true,
      markdown_preview = true,
      lsp_yaml = true,
      octo = true,
      claudecode = true,
      codex = true,
      glow_preview = true,
    }
  else
    -- auto: コマンドの有無で判定
    return {
      telescope = has_exec("rg"),
      treesitter = has_compiler(),
      markdown_preview = has_exec("node"),
      lsp_yaml = has_exec("node"),
      octo = has_exec("gh"),
      claudecode = has_exec("claude"),
      codex = has_exec("codex"),
      glow_preview = has_exec("glow"),
    }
  end
end

local features = vim.tbl_extend("force", core, resolve_optional())

-- マシンローカル上書き（任意）
local ok, local_overrides = pcall(require, "features_local")
if ok and type(local_overrides) == "table" then
  features = vim.tbl_extend("force", features, local_overrides)
end

features._profile = profile
return features
