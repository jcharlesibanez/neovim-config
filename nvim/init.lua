vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
	{ import = "plugins" },
	    -- 1. Telescope
    {
      'nvim-telescope/telescope.nvim', tag = '0.1.8',
      dependencies = { 'nvim-lua/plenary.nvim' }
    },

    -- 2. Treesitter (Syntax Highlighting)
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter").setup({
          ensure_installed = { "lua", "vim", "vimdoc", "python", "javascript" },
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
        vim.keymap.set("n", "<C-s>", function() harpoon:list():select(4) end)
      end,
    },

    -- 4. Which-key
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {},
    },
  },
  rocks = { enabled = false },
})

-- Set colorscheme to kanagawa (dark)
vim.o.background = "dark"
vim.cmd("colorscheme kanagawa-dragon")

-- Keymaps
local builtin = require('telescope.builtin')
local utils = require('telescope.utils')

vim.keymap.set('n', '<leader>ff', function()
    builtin.find_files({ 
        cwd = utils.buffer_dir() 
    })
end, { desc = 'Find files in current buffer directory' })

vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = "Live Grep" })
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>ww', '<cmd>w!<CR>', { desc = "Save File" })
vim.keymap.set('n', '<leader>e', '<cmd>Ex<CR>', { desc = "Open Explorer"})
vim.keymap.set('n', '<leader>qq', '<cmd>exit<CR>', { desc = "Exit Neovim"})
for i = 1, 9 do
  vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<CR>")
end
vim.keymap.set("n", "<leader>Q", "<cmd>bdelete<CR>")
vim.keymap.set('n', '<leader>t', '<cmd>ToggleTerm<CR>')
vim.keymap.set('t', '<leader>t', '<cmd>ToggleTerm<CR>')
-- General Options
vim.opt.number = false
vim.opt.relativenumber = true
vim.opt.shiftwidth = 4   -- Number of spaces for each step of (auto)indent
vim.opt.tabstop = 4      -- Number of spaces that a <Tab> in the file counts for
vim.opt.softtabstop = 4  -- Number of spaces that a <Tab> counts for while editing
vim.opt.expandtab = true -- Convert tabs to spaces

