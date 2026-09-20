return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    quickfile = { enabled = true },
    input = { enabled = true },
    notifier = { enabled = true, timeout = 2600, top_down = true },
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
            workspace_home = function() require('dreamcore.workbench').home() end,
          },
          win = {
            input = { keys = {
              ['<F2>'] = { 'workspace_files', mode = { 'n', 'i' } },
              ['<F1>'] = { 'workspace_home', mode = { 'n', 'i' } },
              ['<leader>e'] = 'workspace_files',
            } },
            list = { keys = {
              ['n'] = { 'workspace_new', desc = 'New folder / file' },
              ['<F2>'] = { 'workspace_files', mode = { 'n', 'i' } },
              ['<F1>'] = { 'workspace_home', mode = { 'n', 'i' } },
              ['<leader>e'] = 'workspace_files',
            } },
          },
          layout = { preset = "sidebar", preview = false },
        },
      },
    },
    indent = {
      enabled = true,
      indent = { char = "│", only_scope = true },
      animate = { enabled = true, style = "up_down", easing = "inOutCubic", duration = { step = 16, total = 360 } },
      scope = { enabled = true, char = "┃", underline = true, only_current = false },
      chunk = {
        enabled = true,
        only_current = false,
        char = { corner_top = "╭", corner_bottom = "╰", horizontal = "─", vertical = "│", arrow = "▶" },
      },
    },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    zen = { enabled = true },
    dim = { enabled = true },
    dashboard = { enabled = false },
    styles = {
      notification = { border = "single", wo = { wrap = true, winblend = 0 } },
      input = { border = "single", relative = "cursor", row = -3, col = 0 },
    },
  },
  keys = {
    { "<leader>z", function() Snacks.zen() end, desc = "Enter Dream Focus" },
    { "<leader>Z", function() Snacks.zen.zoom() end, desc = "Zoom Window" },
  },
}
