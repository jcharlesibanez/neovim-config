return {

    {"andreasvc/vim-256noir", lazy = false, priority = 1000,},
    {
      "rebelot/kanagawa.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("kanagawa").setup({ background = { dark = "wave", light = "lotus" } })
      end,
    },
  { "folke/which-key.nvim", opts = {} },
  {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      always_show_bufferline = true, -- Set to true to always show tabs
    },
  },
}

}

