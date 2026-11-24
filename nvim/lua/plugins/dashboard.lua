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
          -- Keep names in the explorer's red; the ?/✖ column still shows git status.
          -- (Otherwise untracked files take git's dim "NonText" color.)
          formatters = { file = { git_status_hl = false } },
          -- Open folders get their own highlight (bold neon red) so they stand out.
          format = function(item, picker)
            local ret = Snacks.picker.format.file(item, picker)
            if item.dir and item.open then
              for _, seg in ipairs(ret) do
                if seg[2] == 'SnacksPickerDirectory' then seg[2] = 'SnacksPickerDirectoryOpen' end
              end
            end
            return ret
          end,
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
