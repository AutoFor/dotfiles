return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  opts = {
    picker = "telescope",
    enable_builtin = true,
  },
  keys = {
    -- 一覧
    { "<leader>oi", "<CMD>Octo issue list<CR>",        desc = "List GitHub Issues" },
    { "<leader>op", "<CMD>Octo pr list<CR>",           desc = "List GitHub PullRequests" },
    { "<leader>od", "<CMD>Octo discussion list<CR>",   desc = "List GitHub Discussions" },
    { "<leader>on", "<CMD>Octo notification list<CR>", desc = "List GitHub Notifications" },
    -- Issue 操作
    { "<leader>oI",  "<CMD>Octo issue create<CR>",     desc = "Create GitHub Issue" },
    { "<leader>os",  "<CMD>Octo search<CR>",           desc = "Search GitHub Issues/PRs" },
    { "<leader>oC",  "<CMD>Octo issue close<CR>",      desc = "Close GitHub Issue" },
    { "<leader>oR",  "<CMD>Octo issue reopen<CR>",     desc = "Reopen GitHub Issue" },
    { "<leader>ola", "<CMD>Octo label add<CR>",        desc = "Add Label to Issue/PR" },
    { "<leader>olr", "<CMD>Octo label remove<CR>",     desc = "Remove Label from Issue/PR" },
    -- 親子 Issue
    { "<leader>opa", "<CMD>Octo parent add<CR>",       desc = "Add Parent Issue" },
    { "<leader>opr", "<CMD>Octo parent remove<CR>",    desc = "Remove Parent Issue" },
    { "<leader>ope", "<CMD>Octo parent edit<CR>",      desc = "Edit Parent Issue" },
    { "<leader>oca", "<CMD>Octo child add<CR>",        desc = "Add Child Issue" },
    { "<leader>ocr", "<CMD>Octo child remove<CR>",     desc = "Remove Child Issue" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
    "nvim-tree/nvim-web-devicons",
  },
}
