vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Consume a directory arg before explorer plugins turn it into a directory browser.
if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
  local directory = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
  vim.cmd.cd(vim.fn.fnameescape(directory))
  vim.cmd("argdelete *")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.fn.isdirectory(name) == 1 and not vim.bo[buf].modified then
      vim.api.nvim_buf_delete(buf, { force = false })
    end
  end
end

-- A comfortable, mouse-friendly editing baseline.
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.mousemoveevent = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number,screenline"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.showmode = true
vim.opt.cmdheight = 1
vim.opt.laststatus = 3
vim.opt.pumheight = 12
vim.opt.pumblend = 0
vim.opt.winblend = 0
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.clipboard = "unnamedplus"
vim.opt.fillchars = { eob = " ", vert = " ", horiz = " ", fold = "·", foldopen = "", foldclose = "" }
vim.opt.guicursor = "n-v-c:block-Cursor/lCursor,i-ci-ve:ver25-CursorInsert,r-cr:hor20,o:hor50"

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
	{ import = "plugins" },
    -- Treesitter syntax highlighting.
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "master", -- Neovim 0.11-compatible API; main currently requires 0.12.
      build = ":TSUpdate",
      config = function()
        -- The master branch reads ensure_installed from configs.setup, not the top-level setup.
        require("nvim-treesitter.configs").setup({
          ensure_installed = {
            "lua", "vim", "vimdoc", "python", "c", "cpp", "cmake", "markdown", "markdown_inline",
            "javascript", "typescript", "tsx", "html", "css", "json", "jsonc",
          },
          highlight = { enable = true },
        })
      end,
    },

    -- 3. Harpoon
    {
      "ThePrimeagen/harpoon",
      branch = "harpoon2",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        local harpoon = require("harpoon")
        harpoon:setup()

        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon Add File" })
        vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon Menu" })
        
        vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end)
        vim.keymap.set("n", "<C-t>", function() harpoon:list():select(2) end)
        vim.keymap.set("n", "<C-n>", function() harpoon:list():select(3) end)
        vim.keymap.set("n", "<leader>h4", function() harpoon:list():select(4) end, { desc = "Harpoon File 4" })
      end,
    },

    -- Keymap discovery.
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {},
    },
  },
  rocks = { enabled = false },
})

vim.o.background = "dark"

vim.keymap.set('n', '<leader><space>', function() Snacks.picker.smart() end, { desc = "Find" })
vim.keymap.set('n', '<leader>ff', function() Snacks.picker.files() end, { desc = "Find Files" })
vim.keymap.set('n', '<leader>fg', function() Snacks.picker.grep() end, { desc = "Search Text" })
vim.keymap.set('n', '<leader>fb', function() Snacks.picker.buffers() end, { desc = "Open Buffers" })
vim.keymap.set('n', '<leader>fr', function() Snacks.picker.recent() end, { desc = "Recent Files" })
vim.keymap.set('n', '<leader>:', function() Snacks.picker.command_history() end, { desc = "Command History" })
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>ww', '<cmd>w!<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>o', function() Snacks.explorer.reveal() end, { desc = "Reveal Current File"})
vim.keymap.set('n', '<leader>qq', '<cmd>exit<CR>', { desc = "Exit Neovim"})
vim.keymap.set("n", "<leader>Q", function() Snacks.bufdelete() end, { desc = "Close Buffer" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
vim.keymap.set('n', '<leader>t', '<cmd>ToggleTerm<CR>')
vim.keymap.set('t', '<leader>t', '<cmd>ToggleTerm<CR>')

-- Claude Code agent panel  (off → active → minimized → active → …)
local agent_term  = nil
local agent_state = 'off'   -- 'off' | 'active' | 'minimized'
local agent_win   = nil     -- indicator float window

local function agent_hide_indicator()
  if agent_win and vim.api.nvim_win_is_valid(agent_win) then
    vim.api.nvim_win_close(agent_win, true)
  end
  agent_win = nil
  if vim.g.agent_badge_visible then
    vim.g.agent_badge_visible = false
    require('dreamcore.studymode').reposition()
  end
end

local function agent_show_indicator()
  agent_hide_indicator()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { ' ◉ AGENT ON ' })
  vim.bo[buf].bufhidden = 'wipe'
  agent_win = vim.api.nvim_open_win(buf, false, {
    relative  = 'editor',
    anchor    = 'NE',
    row       = 1,
    col       = vim.o.columns - 1,
    width     = 13,
    height    = 1,
    style     = 'minimal',
    border    = 'single',
    focusable = false,
    zindex    = 200,
  })
  vim.api.nvim_set_option_value('winhl', 'NormalFloat:AgentIndicator,FloatBorder:AgentIndicatorBorder', { win = agent_win })
  vim.g.agent_badge_visible = true
  require('dreamcore.studymode').reposition()
end

local function toggle_agent()
  if agent_state == 'off' then
    local w = function() return math.floor(vim.o.columns * 0.42) end
    agent_term = require('toggleterm.terminal').Terminal:new({
      cmd          = 'claude',
      dir          = vim.fn.getcwd(),
      direction    = 'float',
      float_opts   = {
        border   = 'single',
        width    = w,
        height   = function() return vim.o.lines - 3 end,
        row      = 0,
        col      = function() return vim.o.columns - w() - 2 end,
        winblend = 0,
      },
      hidden       = true,
      display_name = 'Claude Code',
      on_exit = function()
        agent_hide_indicator()
        agent_term  = nil
        agent_state = 'off'
      end,
      on_open = function(t)
        vim.keymap.set('t', '<leader>-', toggle_agent, { buffer = t.bufnr })
      end,
    })
    agent_term:open()
    agent_state = 'active'
  elseif agent_state == 'active' then
    agent_term:toggle()        -- closes window, keeps process
    agent_show_indicator()
    agent_state = 'minimized'
  else                         -- minimized
    agent_hide_indicator()
    agent_term:toggle()        -- reopens window
    agent_state = 'active'
  end
end

vim.keymap.set({ 'n', 't' }, '<leader>-', toggle_agent, { desc = 'Toggle Claude Code agent' })

-- While the agent is open, clicking or jumping elsewhere snaps focus back to it.
vim.api.nvim_create_autocmd('WinEnter', {
  callback = function()
    if agent_state ~= 'active' or not agent_term then return end
    local win = agent_term.window
    if not win or vim.api.nvim_get_current_win() == win then return end
    vim.schedule(function()
      if agent_state == 'active' and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd.startinsert()
      end
    end)
  end,
})
vim.keymap.set('n', '<leader>H', function() Snacks.picker.recent() end, { desc = "Recent files" })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = "Clear Search" })
vim.opt.shiftwidth = 4   -- Number of spaces for each step of (auto)indent
vim.opt.tabstop = 4      -- Number of spaces that a <Tab> in the file counts for
vim.opt.softtabstop = 4  -- Number of spaces that a <Tab> counts for while editing
vim.opt.expandtab = true -- Convert tabs to spaces

-- Better diagnostics without visual noise.
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = "●" },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "single", source = "if_many" },
})

vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function(args)
    local bo = vim.bo[args.buf]
    if bo.buftype == "" and bo.modifiable and not bo.readonly and bo.modified
      and vim.api.nvim_buf_get_name(args.buf) ~= "" then
      vim.cmd("silent! update")
    end
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 180 }) end,
})

require("dreamcore.webdev").setup()
require("dreamcore.workbench").setup()
require("dreamcore.folds").setup()
require("dreamcore.studymode").setup()
require("dreamcore.deletepreview").setup()
require("dreamcore.asmr").setup()
require("dreamcore.lofi").setup()
