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

-- :TermRestart (or :termrestart) — end the <leader>t shell and open a fresh one, for when it
-- gets stuck. (If you just can't type into it, it's in normal mode: press i.)
vim.api.nvim_create_user_command('TermRestart', function()
  local term = require('toggleterm.terminal').get(1)
  if term then term:shutdown() end
  vim.cmd('1ToggleTerm')
  -- Ready to type, once toggleterm has finished opening it.
  vim.defer_fn(function()
    if vim.bo.buftype == 'terminal' then vim.cmd.startinsert() end
  end, 50)
end, { desc = 'Restart the <leader>t terminal' })
vim.cmd([[cnoreabbrev <expr> termrestart getcmdtype() == ':' && getcmdline() ==# 'termrestart' ? 'TermRestart' : 'termrestart']])

-- AI agent panels: Claude Code (<leader>cc) and Codex (<leader>co). Opening one minimizes the
-- other to a badge in the top right. See dreamcore/agents.lua.
require('dreamcore.agents').setup()

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
