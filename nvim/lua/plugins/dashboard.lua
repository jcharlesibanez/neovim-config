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
    lazygit = { enabled = true }, -- <leader>gg / :lazygit — git in a floating window (q to close)
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
    -- Smooth scrolling for Ctrl-d/u, Ctrl-f/b, gg/G, search jumps, mouse wheel. :SmoothScroll toggles it.
    scroll = {
      enabled = true,
      animate = { duration = { step = 10, total = 180 }, easing = "outQuad" },
    },
    words = { enabled = true },
    dashboard = { enabled = false },
    styles = {
      notification = { border = "single", wo = { wrap = true, winblend = 0 } },
      input = { border = "single", relative = "cursor", row = -3, col = 0 },
    },
  },
  init = function()
    vim.api.nvim_create_user_command("SmoothScroll", function()
      vim.g.snacks_scroll = vim.g.snacks_scroll == false
      vim.notify("Smooth scroll " .. (vim.g.snacks_scroll and "on" or "off"))
    end, { desc = "Toggle smooth scrolling" })

    -- lazygit: stage, commit, push, browse history. Needs the lazygit program.
    local function lazygit()
      if vim.fn.executable("lazygit") == 0 then
        local how = vim.fn.has("mac") == 1 and "brew install lazygit"
          or "sudo apt install lazygit (Ubuntu 25.04+), or see github.com/jesseduffield/lazygit"
        vim.notify("lazygit isn't installed. Install it with: " .. how, vim.log.levels.WARN)
        return
      end
      Snacks.lazygit()
    end
    vim.keymap.set("n", "<leader>gg", lazygit, { desc = "Lazygit" })
    vim.api.nvim_create_user_command("Lazygit", lazygit, { desc = "Open lazygit" })
    vim.cmd([[cnoreabbrev <expr> lazygit getcmdtype() == ':' && getcmdline() ==# 'lazygit' ? 'Lazygit' : 'lazygit']])
  end,
}
