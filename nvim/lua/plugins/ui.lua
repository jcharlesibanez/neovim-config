return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1100,
    opts = {
      flavour = "mocha",
      -- Use the terminal's own background everywhere (editor, floats, sidebars).
      transparent_background = true,
      float = { transparent = true },
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
      local BG  = 'NONE' -- transparent: show the terminal's background

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
        -- Names in a lighter red than the borders, all the same weight; only the item under
        -- the cursor is bold (no bar behind it, so the terminal shows through).
        local NAME = '#ff7a8c'
        vim.api.nvim_set_hl(0, 'SnacksPickerFile',        { fg = NAME })
        vim.api.nvim_set_hl(0, 'SnacksPickerDirectory',   { fg = NAME })
        vim.api.nvim_set_hl(0, 'SnacksPickerDirectoryOpen', { fg = RED, bold = true }) -- open folders
        vim.api.nvim_set_hl(0, 'SnacksPickerDir',         { fg = NAME })
        vim.api.nvim_set_hl(0, 'SnacksPickerPathHidden',  { fg = '#c25a6c' })
        vim.api.nvim_set_hl(0, 'SnacksPickerPathIgnored', { fg = '#94485a' })
        vim.api.nvim_set_hl(0, 'SnacksPickerListCursorLine', { bg = 'NONE', bold = true })
        -- Agent indicator badge
        vim.api.nvim_set_hl(0, 'AgentIndicator',       { fg = RED, bg = BG, bold = true })
        vim.api.nvim_set_hl(0, 'AgentIndicatorBorder', { fg = RED, bg = BG })
        vim.api.nvim_set_hl(0, 'AgentLogo',            { fg = '#d97757', bg = BG, bold = true }) -- Claude's coral

        -- Dim grey italic: :Music now-playing badge, LaTeX preview page bar.
        vim.api.nvim_set_hl(0, 'BadgeDim', { fg = '#8b949e', bg = BG, italic = true })

        -- Lines a pending `d{count}j/k` would delete.
        vim.api.nvim_set_hl(0, 'DeletePreview',   { fg = '#080608', bg = RED, bold = true })
        vim.api.nvim_set_hl(0, 'DeletePreviewUp', { fg = '#ffd8dc', bg = '#5a1020', bold = true })

        -- Line numbers: readable grey, current line bright white.
        vim.api.nvim_set_hl(0, 'LineNr',       { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'LineNrAbove',  { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'LineNrBelow',  { fg = '#6b7280' })
        vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#ffffff', bold = true })
        -- No bar behind the cursor's line: on a see-through terminal it showed as an opaque
        -- black strip. The bold white line number marks the current line instead.
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = 'NONE' })

        -- ── Code colors: red-centered ──────────────────────────────────────
        -- Built around the neon red of the borders. Reds and pinks are told apart by
        -- brightness, not just hue: keywords are the full neon red, names are near-white,
        -- and the quieter parts (operators, punctuation, comments) fade toward grey.
        -- No yellow or orange. Diagnostics and git signs keep their own colors.
        local C = {
          keyword  = RED,       -- if, return, class, const, #include
          func     = '#ffe4e8', -- function names: near-white with a red tint
          type     = '#ff7a8c', -- types / classes: light red (same as explorer names)
          builtin  = '#ff5c74', -- this, self, std types, true/false/nullptr
          string   = '#f0a3ae', -- strings: soft rose
          escape   = '#ffffff', -- \n, %d inside strings
          number   = '#ff4f8b', -- numbers / constants: raspberry
          param    = '#ffc2cb', -- parameters: pale pink, italic
          property = '#d9b3b9', -- fields / members: muted pink-grey
          variable = '#ead8dc', -- plain names: the normal text color
          module   = '#ff9aa8', -- namespaces / modules
          macro    = '#ff3d5c', -- macros, preprocessor
          operator = '#b8848c', -- = + && -> : rose-grey
          punct    = '#8a6168', -- ( ) { } , ; dim red-grey
          comment  = '#6b7280', -- grey italic so it stays readable
        }
        local groups = {
          keyword  = { 'Keyword', 'Statement', 'Conditional', 'Repeat', 'Include', 'Exception', 'StorageClass',
                       'Label', '@keyword', '@keyword.function', '@keyword.return', '@keyword.conditional',
                       '@keyword.conditional.ternary', '@keyword.repeat', '@keyword.import', '@keyword.operator',
                       '@keyword.exception', '@keyword.modifier', '@keyword.type', '@keyword.coroutine',
                       '@keyword.directive', '@keyword.directive.define', '@lsp.type.keyword', '@tag',
                       '@markup.heading', 'Title' },
          func     = { 'Function', '@function', '@function.call', '@function.method', '@function.method.call',
                       '@constructor', '@lsp.type.function', '@lsp.type.method' },
          type     = { 'Type', 'Structure', 'Typedef', '@type', '@type.definition', '@lsp.type.class',
                       '@lsp.type.struct', '@lsp.type.enum', '@lsp.type.type', '@lsp.type.interface',
                       '@lsp.type.typeParameter' },
          builtin  = { '@variable.builtin', '@constant.builtin', '@function.builtin', '@type.builtin',
                       '@module.builtin', 'Boolean', '@boolean' },
          string   = { 'String', 'Character', '@string', '@character', '@string.documentation', '@markup.raw' },
          escape   = { '@string.escape', '@string.special', 'SpecialChar', '@character.special' },
          number   = { 'Number', 'Float', 'Constant', '@number', '@number.float', '@constant',
                       '@lsp.type.enumMember' },
          param    = { '@variable.parameter', '@lsp.type.parameter' },
          property = { '@property', '@variable.member', '@lsp.type.property', '@tag.attribute' },
          variable = { 'Identifier', '@variable', '@lsp.type.variable' },
          module   = { '@module', '@lsp.type.namespace', '@markup.link' },
          macro    = { 'PreProc', 'Define', 'Macro', 'PreCondit', '@function.macro', '@constant.macro',
                       '@lsp.type.macro', '@attribute' },
          operator = { 'Operator', '@operator' },
          punct    = { 'Delimiter', '@punctuation', '@punctuation.bracket', '@punctuation.delimiter',
                       '@punctuation.special', '@tag.delimiter' },
        }
        local mine = {}
        for role, names in pairs(groups) do
          local spec = { fg = C[role] }
          if role == 'param' then spec.italic = true end
          for _, g in ipairs(names) do vim.api.nvim_set_hl(0, g, spec); mine[g] = true end
        end
        -- The theme also colors language-specific variants (e.g. @keyword.import.cpp in teal),
        -- which win over the base group. Point each of those back at the base color above.
        for name in pairs(vim.api.nvim_get_hl(0, {})) do
          if not mine[name] and name:sub(1, 1) == '@' then
            local base = name
            repeat base = base:match('^(.*)%.[^.]+$') until not base or mine[base]
            if base then vim.api.nvim_set_hl(0, name, { link = base }) end
          end
        end
        vim.api.nvim_set_hl(0, 'Comment',  { fg = C.comment, italic = true })
        vim.api.nvim_set_hl(0, '@comment', { link = 'Comment' })
        vim.api.nvim_set_hl(0, '@string.documentation.python', { fg = C.comment, italic = true })
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
