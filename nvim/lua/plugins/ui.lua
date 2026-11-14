return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1100,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      color_overrides = { mocha = {
        -- backgrounds: near-black with faint red warmth
        crust = "#030203", base = "#080608", mantle = "#0d080d",
        surface0 = "#160e14", surface1 = "#1f1319", surface2 = "#2a1a22",
        -- mid tones
        overlay0 = "#4c2a35", overlay1 = "#623540", overlay2 = "#7d464f",
        subtext0 = "#9a6065", subtext1 = "#bf8085",
        -- text
        text = "#ead8dc", lavender = "#d0b8b8",
        -- red accent family
        rosewater = "#ffd8dc", flamingo = "#ff90a0", pink = "#ff5878",
        mauve = "#ff1a3a",  -- PRIMARY ACCENT: neon red
        red = "#ff3d5c",    -- errors / emphasis
        maroon = "#cc2040",
        -- syntax: warm neutrals so non-red tokens don't compete
        peach = "#d87050", yellow = "#d4a830", green = "#78b868",
        teal = "#908060",
        sky = "#c8a8a8",      -- warm neutral
        sapphire = "#907878", -- warm rose
        blue = "#a09090",     -- warm neutral (parameters, fields)
      } },
      integrations = { treesitter = true, native_lsp = { enabled = true }, gitsigns = true, snacks = true },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")

      local RED = '#ff1a3a'
      local BG  = '#0d080d'

      local function apply_borders()
        -- Universal border colour — applies to every float and split
        vim.api.nvim_set_hl(0, 'FloatBorder',  { fg = RED })
        vim.api.nvim_set_hl(0, 'WinSeparator', { fg = RED })
        vim.api.nvim_set_hl(0, 'NormalFloat',  { bg = BG  })
        -- Snacks
        vim.api.nvim_set_hl(0, 'SnacksPickerBorder',       { fg = RED })
        vim.api.nvim_set_hl(0, 'SnacksPickerInputBorder',  { fg = RED })
        vim.api.nvim_set_hl(0, 'SnacksNotifierBorderInfo', { fg = RED })
        vim.api.nvim_set_hl(0, 'SnacksNotifierTitleInfo',  { fg = RED })
        -- Agent indicator badge
        vim.api.nvim_set_hl(0, 'AgentIndicator',       { fg = RED, bg = BG, bold = true })
        vim.api.nvim_set_hl(0, 'AgentIndicatorBorder', { fg = RED, bg = BG })
      end

      apply_borders()
      vim.api.nvim_create_autocmd('ColorScheme', { callback = apply_borders })

      local t = { "#030203", "#ff1a3a", "#78b868", "#d4a830", "#a09090", "#ff5878", "#ff1a3a", "#ead8dc",
                  "#623540", "#ff3d5c", "#96d080", "#f0c840", "#c0a8c0", "#ff7090", "#ff4060", "#ffd8dc" }
      for i, c in ipairs(t) do vim.g["terminal_color_" .. (i - 1)] = c end
    end,
  },
  { "lewis6991/gitsigns.nvim", event = "BufReadPre", opts = {
    signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "" }, topdelete = { text = "" }, changedelete = { text = "▎" } },
    current_line_blame = false,
  } },
}
