return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function() return math.floor(vim.o.lines * 0.72) end,
      direction = "float",
      shade_terminals = true,
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
      highlights = { FloatBorder = { guifg = "#286071" }, NormalFloat = { guibg = "#0e1215" } },
    },
  },
}
