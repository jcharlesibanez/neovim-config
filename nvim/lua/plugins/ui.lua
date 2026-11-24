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
        maroon = "#c9d1d9",   -- parameters: light grey
        -- syntax: calm cool tones so code reads easily against the red UI
        peach = "#b5e3ff",    -- numbers / constants: ice blue
        yellow = "#5fd4c4",   -- types / classes: teal
        green = "#9ccc7a",    -- strings: soft green
        teal = "#5fd4c4",
        sky = "#8b949e",      -- operators / punctuation: grey
        sapphire = "#6cb6ff",
        blue = "#e6e6e6",     -- functions: near-white
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
        -- Explorer / picker file names in neon red; hidden & ignored stay dimmer so they're distinguishable.
        vim.api.nvim_set_hl(0, 'SnacksPickerFile',        { fg = RED })
        vim.api.nvim_set_hl(0, 'SnacksPickerDirectory',   { fg = RED, bold = true })
        vim.api.nvim_set_hl(0, 'SnacksPickerDir',         { fg = RED })
        vim.api.nvim_set_hl(0, 'SnacksPickerPathHidden',  { fg = '#9a2a3c' })
        vim.api.nvim_set_hl(0, 'SnacksPickerPathIgnored', { fg = '#6e1f2c' })
        -- Agent indicator badge
        vim.api.nvim_set_hl(0, 'AgentIndicator',       { fg = RED, bg = BG, bold = true })
        vim.api.nvim_set_hl(0, 'AgentIndicatorBorder', { fg = RED, bg = BG })

        -- Dim grey italic: :Music now-playing badge, LaTeX preview page bar.
        vim.api.nvim_set_hl(0, 'BadgeDim', { fg = '#8b949e', bg = '#080608', italic = true })

        -- Lines a pending `d{count}j/k` would delete.
        vim.api.nvim_set_hl(0, 'DeletePreview',   { fg = '#080608', bg = RED, bold = true })
        vim.api.nvim_set_hl(0, 'DeletePreviewUp', { fg = '#ffd8dc', bg = '#5a1020', bold = true })

        -- Line numbers: readable grey, current line bright white.
        vim.api.nvim_set_hl(0, 'LineNr',       { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'LineNrAbove',  { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'LineNrBelow',  { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#ffffff', bold = true })

        -- Keywords in calm blue instead of the neon-red accent.
        local KEYWORD = '#6cb6ff'
        for _, g in ipairs({
          'Keyword', 'Statement', 'Conditional', 'Repeat', 'Include', 'Exception', 'StorageClass',
          '@keyword', '@keyword.function', '@keyword.return', '@keyword.conditional',
          '@keyword.conditional.ternary', '@keyword.repeat', '@keyword.import', '@keyword.operator',
          '@keyword.exception', '@keyword.modifier', '@keyword.type', '@keyword.coroutine',
          '@keyword.directive', '@keyword.directive.define', '@lsp.type.keyword',
        }) do
          vim.api.nvim_set_hl(0, g, { fg = KEYWORD })
        end
        -- Builtins (self, this, nullptr, true…) in ice blue, not error red.
        for _, g in ipairs({ '@variable.builtin', '@constant.builtin', '@function.builtin',
                             '@type.builtin', '@module.builtin', 'Boolean' }) do
          vim.api.nvim_set_hl(0, g, { fg = '#b5e3ff' })
        end
        vim.api.nvim_set_hl(0, 'Comment',  { fg = '#6b7280', italic = true })
        vim.api.nvim_set_hl(0, '@comment', { link = 'Comment' })
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
