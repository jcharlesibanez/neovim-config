return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    input = { enabled = true },
    notifier = { enabled = true, timeout = 2600 },
    explorer = { enabled = true, replace_netrw = true, trash = true },
    picker = {
      enabled = true,
      ui_select = true,
      sources = {
        explorer = {
          auto_close = false,
          actions = {
            workspace_new = function(picker) require("dreamcore.files").prompt(picker) end,
            workspace_files = function() require('dreamcore.workbench').toggle_files() end,
          },
          win = {
            input = { keys = {
              ['<F2>'] = { 'workspace_files', mode = { 'n', 'i' } },
            } },
            list = { keys = {
              ['n'] = { 'workspace_new', desc = 'New folder / file' },
              ['<F2>'] = { 'workspace_files', mode = { 'n', 'i' } },
              ['<leader>e'] = 'workspace_files',
            } },
          },
          layout = { preset = "sidebar", preview = false },
        },
      },
    },
    scope = { enabled = true },
    words = { enabled = true },
    dashboard = { enabled = false },
    styles = {
      notification = { border = "single", wo = { wrap = true, winblend = 0 } },
      input = { border = "single", relative = "cursor", row = -3, col = 0 },
    },
  },
}
