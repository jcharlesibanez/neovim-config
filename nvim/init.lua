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
  -- `nvim .` / `nvim some/folder`: open the file explorer with the cursor in it.
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.schedule(function() Snacks.explorer({ cwd = vim.fn.getcwd() }) end)
    end,
  })
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

-- Leftover swap files: skip the "E325: ATTENTION" screen when the swap file holds nothing
-- worth recovering. They're left behind whenever Neovim is killed instead of quit (closing
-- the terminal window, a crash). Neovim already handles a file open in another running Neovim.
--   * swap has no unsaved changes          → delete it quietly
--   * the file was saved after the swap    → its changes are older than the file: delete it,
--                                            keeping a copy in ~/.local/state/nvim/swap-old
--   * the swap is newer than the file      → real unsaved work from a crash: still ask
local function newer(a, b) -- was file a modified strictly after file b?
  local sa, sb = vim.uv.fs_stat(a), vim.uv.fs_stat(b)
  if not (sa and sb) then return false end
  local ta, tb = sa.mtime, sb.mtime
  return ta.sec > tb.sec or (ta.sec == tb.sec and ta.nsec > tb.nsec)
end
vim.api.nvim_create_autocmd("SwapExists", {
  group = vim.api.nvim_create_augroup("dream_swap", { clear = true }),
  callback = function(ev)
    if vim.v.swapchoice ~= "" then return end -- already decided (open in another Neovim)
    local swap = vim.v.swapname
    local info = vim.fn.swapinfo(swap)
    if info.error then return end
    local pid = tonumber(info.pid) or 0
    if pid > 0 and vim.uv.kill(pid, 0) == 0 then return end -- its Neovim is still running: ask
    local name = vim.fn.fnamemodify(ev.file, ":t")
    local note
    if info.dirty == 0 then
      vim.v.swapchoice = "d"
    elseif newer(ev.file, swap) then
      local keep = vim.fn.stdpath("state") .. "/swap-old"
      vim.fn.mkdir(keep, "p")
      local copy = keep .. "/" .. vim.fn.fnamemodify(swap, ":t")
      if not vim.uv.fs_copyfile(swap, copy) then return end -- couldn't keep a copy: ask
      vim.v.swapchoice = "d"
      note = ("Old unsaved changes to %s were older than the file; copy kept in swap-old"):format(name)
    else
      return
    end
    if note then
      vim.schedule(function()
        require("dreamcore.toast").show(note, { id = "swap", color = "#8b949e", timeout = 5000 })
      end)
    end
  end,
})

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
vim.keymap.set('n', '<leader>qq', '<cmd>qa<CR>', { desc = "Quit all (stops if anything is unsaved)" })
vim.keymap.set("n", "<leader>Q", function() Snacks.bufdelete() end, { desc = "Close Buffer" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
-- <leader>t always toggles your shell (terminal 1). A plain :ToggleTerm toggles whichever terminal
-- you're in. Space shortcuts are normal-mode only: while you type in a terminal (Claude Code,
-- the shell) a space is just a space. Leave with Ctrl+1–9 / Ctrl+L, then use the shortcut.
vim.keymap.set('n', '<leader>t', '<cmd>1ToggleTerm<CR>', { desc = 'Toggle terminal' })

-- Claude Code agent panel  (off → active → minimized → active → …)
local agent_term  = nil
local agent_state = 'off'   -- 'off' | 'active' | 'minimized'

-- The crab badge while the panel is minimized (dances while Claude works, red "!" when it
-- needs your approval): dreamcore/agentbadge.lua.
local function agent_hide_indicator() require('dreamcore.agentbadge').hide() end
local function agent_show_indicator() require('dreamcore.agentbadge').show() end

-- Panel width in columns: 42% of the screen until you drag its red line (then what you set).
local agent_cols = nil
local function agent_width()
  local cols = agent_cols or math.floor(vim.o.columns * 0.42)
  return math.max(30, math.min(cols, vim.o.columns - 20))
end

-- While you're in the panel, stray clicks elsewhere snap focus back to it ("locked"). Leaving on
-- purpose with Ctrl+L or Ctrl+number unlocks it until you come back.
local agent_locked = true
local agent_closing = false -- true while <leader>cc minimizes the panel (see agent_term.close)

local function toggle_agent()
  if agent_state == 'off' then
    local w = agent_width
    agent_term = require('toggleterm.terminal').Terminal:new({
      -- --settings adds hooks that tell the badge when Claude is working, done, or waiting
      -- for your approval. Your own Claude Code settings are untouched.
      count        = 99, -- its own terminal number, so it never takes your shell's (1)
      cmd          = 'claude --settings ' .. vim.fn.shellescape(require('dreamcore.agentbadge').hook_settings()),
      dir          = vim.fn.getcwd(),
      direction    = 'float',
      float_opts   = {
        -- Only a red line on the left (like the explorer's edge) and the title on top: the top
        -- row is blank apart from " Claude Code ", with no right or bottom border.
        -- Order: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left.
        border    = { '│', ' ', '', '', '', '', '', '│' },
        title_pos = 'center',
        width    = w,
        height   = function() return vim.o.lines - 2 end,
        row      = 0,
        col      = function() return vim.o.columns - w() - 1 end,
        winblend = 0,
      },
      hidden       = true,
      display_name = ' Claude Code ', -- shown centered on the top row, like " Explorer "
      -- Red line like the explorer and every other float (toggleterm's own default is the
      -- plain text color, which showed as a white line).
      highlights   = { NormalFloat = { link = 'Normal' }, FloatBorder = { link = 'FloatBorder' } },
      on_exit = function()
        agent_hide_indicator()
        require('dreamcore.agentbadge').set_state('idle')
        agent_term  = nil
        agent_state = 'off'
      end,
      on_open = function(t)
        -- Ctrl+L hops on to the next window, as it does everywhere else.
        vim.keymap.set('t', '<C-l>', function() require('dreamcore.windows').next() end, { buffer = t.bufnr })
      end,
    })
    -- toggleterm closes a floating terminal as soon as you leave it. Keep this one open while
    -- you work in other windows; it closes only when minimized (<leader>cc) or Claude exits.
    local close = agent_term.close
    agent_term.close = function(self, ...)
      local exited = not self.job_id or vim.fn.jobwait({ self.job_id }, 0)[1] ~= -1
      if agent_closing or exited then return close(self, ...) end
    end
    agent_term:open()
    agent_state = 'active'
    agent_locked = true
  elseif agent_state == 'active' then
    agent_closing = true
    agent_term:toggle()        -- closes window, keeps process
    agent_closing = false
    agent_show_indicator()
    agent_state = 'minimized'
  else                         -- minimized
    agent_hide_indicator()
    require('dreamcore.agentbadge').seen()
    agent_term:toggle()        -- reopens window
    agent_state = 'active'
    agent_locked = true
    vim.schedule(function() -- back in the composer, ready to type
      if agent_term and agent_term.window == vim.api.nvim_get_current_win() then vim.cmd.startinsert() end
    end)
  end
end

vim.keymap.set('n', '<leader>cc', toggle_agent, { desc = 'Toggle Claude Code agent' })

-- Window numbers (Ctrl+1 … Ctrl+9, Ctrl+L) count the Claude Code panel too.
do
  local windows = require('dreamcore.windows')
  windows.agent_win = function()
    local win = agent_state == 'active' and agent_term and agent_term.window
    return win and vim.api.nvim_win_is_valid(win) and win or nil
  end
  windows.on_jump = function(from) if from == windows.agent_win() then agent_locked = false end end
  windows.setup()
end

-- While you're in the panel, clicking elsewhere snaps focus back to it (unless you left on purpose).
-- Only ordinary windows snap back: a terminal (<leader>t), picker or popup you open stays.
vim.api.nvim_create_autocmd('WinEnter', {
  callback = function()
    if agent_state ~= 'active' or not agent_term then return end
    local win = agent_term.window
    if not win then return end
    local cur = vim.api.nvim_get_current_win()
    if cur == win then agent_locked = true return end
    if not agent_locked or vim.api.nvim_win_get_config(cur).relative ~= '' then return end
    vim.schedule(function()
      if agent_state == 'active' and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd.startinsert()
      end
    end)
  end,
})
-- Drag the Claude Code panel's red line with the mouse to make it wider or narrower.
-- (It's a floating window, which Neovim can't resize by dragging on its own.)
do
  local dragging = false
  local function on_agent_line()
    if agent_state ~= 'active' or not agent_term then return false end
    local win = agent_term.window
    if not (win and vim.api.nvim_win_is_valid(win)) then return false end
    local m, cfg = vim.fn.getmousepos(), vim.api.nvim_win_get_config(win)
    local col = type(cfg.col) == 'table' and cfg.col[false] or cfg.col
    return m.screencol - 1 == col
  end
  local function mouse(key, fn)
    vim.keymap.set({ 'n', 'i', 't' }, key, function()
      if fn() then return '' end
      return key
    end, { expr = true, desc = 'Drag the Claude Code panel edge to resize it' })
  end
  -- A plain click that ends up in the panel (a click inside it, or a stray click elsewhere
  -- that snaps back to it) lands in Claude's composer, ready to type, instead of leaving you
  -- in Neovim's normal mode at the clicked spot. Dragging still selects text to copy.
  local moved = false
  mouse('<LeftMouse>', function()
    dragging, moved = on_agent_line(), false
    return dragging
  end)
  mouse('<LeftDrag>', function()
    moved = true
    if not dragging then return false end
    agent_cols = vim.o.columns - vim.fn.getmousepos().screencol
    vim.schedule(function() -- can't change windows from inside a key mapping's expression
      local win = agent_term and agent_term.window
      if not (win and vim.api.nvim_win_is_valid(win)) then return end
      vim.api.nvim_win_set_config(win, { relative = 'editor', row = 0, col = vim.o.columns - agent_width() - 1,
                                         width = agent_width(), height = vim.o.lines - 2 })
    end)
    return true
  end)
  mouse('<LeftRelease>', function()
    local was = dragging
    dragging = false
    -- A stray click elsewhere already snapped back to the composer: ignore its release, which
    -- would otherwise land outside the terminal and knock it out of typing mode.
    local win = agent_state == 'active' and agent_term and agent_term.window
    if not was and win and vim.api.nvim_get_current_win() == win and vim.api.nvim_get_mode().mode == 't'
      and vim.fn.getmousepos().winid ~= win then
      return true
    end
    if not was and not moved then
      vim.schedule(function()
        local win = agent_state == 'active' and agent_term and agent_term.window
        if win and vim.api.nvim_get_current_win() == win and vim.api.nvim_get_mode().mode:sub(1, 1) == 'n' then
          agent_locked = true
          vim.cmd.startinsert()
        end
      end)
    end
    return was
  end)
end

-- <leader>= : resize mode for the window you're in. Keep tapping, no leader needed:
--   h / ←  narrower    l / →  wider    k / ↑  taller    j / ↓  shorter    =  make all even
-- Any other key (Esc, Enter, …) finishes. The explorer's edge can also be dragged with the mouse.
vim.keymap.set('n', '<leader>=', function()
  local toast = require('dreamcore.toast')
  toast.show('Resize: h/l narrower/wider, j/k shorter/taller, = even, Esc done',
    { id = 'resize', color = '#ffffff', timeout = false, order = 100 })
  local left, right, up, down = vim.keycode('<Left>'), vim.keycode('<Right>'), vim.keycode('<Up>'), vim.keycode('<Down>')
  while true do
    vim.cmd.redraw()
    local ok, k = pcall(vim.fn.getcharstr)
    if not ok then break end
    if k == 'h' or k == left then vim.cmd('vertical resize -3')
    elseif k == 'l' or k == right then vim.cmd('vertical resize +3')
    elseif k == 'k' or k == up then vim.cmd('resize +1')
    elseif k == 'j' or k == down then vim.cmd('resize -1')
    elseif k == '=' then vim.cmd('wincmd =')
    else
      if k ~= vim.keycode('<Esc>') and k ~= '\r' then vim.api.nvim_feedkeys(k, 'm', false) end
      break
    end
  end
  toast.hide('resize')
end, { desc = 'Resize windows (h/l/j/k, = even, Esc done)' })

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
  nested = true, -- let the save fire BufWritePost (e.g. the LaTeX live-preview compile)
  callback = function(args)
    local bo = vim.bo[args.buf]
    if bo.buftype == "" and bo.modifiable and not bo.readonly and bo.modified
      and vim.api.nvim_buf_get_name(args.buf) ~= "" then
      vim.cmd("silent! update")
    end
  end,
})

-- Pasting with Cmd-V in normal mode never enters insert mode, so the InsertLeave autosave
-- above never fired and pasted text stayed unsaved. Save after pastes as well.
do
  local paste = vim.paste
  vim.paste = function(lines, phase)
    local ok = paste(lines, phase)
    if phase == -1 or phase == 3 then -- paste finished (single chunk, or last chunk)
      vim.schedule(function()
        local bo = vim.bo
        if vim.fn.mode() ~= "i" and bo.buftype == "" and bo.modifiable and not bo.readonly
          and vim.api.nvim_buf_get_name(0) ~= "" then
          vim.cmd("silent! update")
        end
      end)
    end
    return ok
  end
end

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 180 }) end,
})

require("dreamcore.webdev").setup()
require("dreamcore.workbench").setup()
require("dreamcore.folds").setup()
require("dreamcore.toast").setup()
require("dreamcore.studymode").setup()
require("dreamcore.deletepreview").setup()
require("dreamcore.asmr").setup()
require("dreamcore.music").setup()
