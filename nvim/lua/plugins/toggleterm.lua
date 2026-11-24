return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function() return math.floor(vim.o.lines * 0.72) end,
      direction = "float",
      shade_terminals = false, -- same background as the rest of the terminal
      shading_factor = 2,
      start_in_insert = true,
      persist_size = true,
      float_opts = {
        border = "single",
        width = function() return math.floor(vim.o.columns * 0.82) end,
        height = function() return math.floor(vim.o.lines * 0.72) end,
        winblend = 0,
        title_pos = "center",
      },
    },
  },
}
