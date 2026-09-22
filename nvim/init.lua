vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- A directory launch chooses the workspace; the home screen owns startup.
-- Consume it before explorer plugins can turn it into a directory browser.
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
vim.opt.showmode = false
vim.opt.cmdheight = 0
vim.opt.laststatus = 3
vim.opt.showtabline = 2
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
        require("nvim-treesitter").setup({
          ensure_installed = {
            "lua", "vim", "vimdoc", "python", "c", "cpp",
            "javascript", "typescript", "tsx", "html", "css", "json", "jsonc",
          },
        })
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(args)
            pcall(vim.treesitter.start, args.buf)
          end,
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

-- The UI layer is provided by Snacks; these keymaps stay lazy and fast.
vim.keymap.set('n', '<leader><space>', function() Snacks.picker.smart() end, { desc = "Dream Finder" })
vim.keymap.set('n', '<leader>ff', function() Snacks.picker.files() end, { desc = "Find Files" })
vim.keymap.set('n', '<leader>fg', function() Snacks.picker.grep() end, { desc = "Search Text" })
vim.keymap.set('n', '<leader>fb', function() Snacks.picker.buffers() end, { desc = "Open Buffers" })
vim.keymap.set('n', '<leader>fr', function() Snacks.picker.recent() end, { desc = "Recent Files" })
vim.keymap.set('n', '<leader>:', function() Snacks.picker.command_history() end, { desc = "Command History" })
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>ww', '<cmd>w!<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>o', function() Snacks.explorer.reveal() end, { desc = "Reveal Current File"})
vim.keymap.set('n', '<leader>qq', '<cmd>exit<CR>', { desc = "Exit Neovim"})
for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<CR>")
end
vim.keymap.set("n", "<leader>Q", function() Snacks.bufdelete() end, { desc = "Close Buffer" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
vim.keymap.set('n', '<leader>t', '<cmd>ToggleTerm<CR>')
vim.keymap.set('t', '<leader>t', '<cmd>ToggleTerm<CR>')
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

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank({ higroup = "IncSearch", timeout = 180 }) end,
})

require("dreamcore.webdev").setup()
require("dreamcore.motion").setup()

require("dreamcore.home").setup()
require("dreamcore.workbench").setup()

require("dreamcore.audio").setup()
