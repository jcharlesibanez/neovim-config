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
        rosewater = "#d5e0e7", flamingo = "#c8d5dc", pink = "#b8cddd",
        mauve = "#57d9f5", red = "#ef8292", maroon = "#d999a3",
        peach = "#ddbc96", yellow = "#ddc38b", green = "#88d6b0",
        teal = "#76c9cf", sky = "#b8edfa", sapphire = "#69aec5",
        blue = "#91b9e8", lavender = "#c1d9ed", text = "#d5e0e7",
        subtext1 = "#afc0ca", subtext0 = "#8b9faa", overlay2 = "#748995",
        overlay1 = "#627580", overlay0 = "#4c5c66", surface2 = "#34454f",
        surface1 = "#24343e", surface0 = "#141c21", base = "#090b0d",
        mantle = "#0e1215", crust = "#050607",
      } },
      integrations = { treesitter = true, native_lsp = { enabled = true }, which_key = true, gitsigns = true, noice = true, bufferline = true, snacks = true, mini = { enabled = true } },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
      require("dreamcore.style").setup()
      local terminal = { "#050607", "#ef8292", "#88d6b0", "#ddc38b", "#91b9e8", "#b8cddd", "#57d9f5", "#d5e0e7", "#627580", "#f5a6b1", "#aff0d1", "#f0dcae", "#b3d6ff", "#d5e6f0", "#b8edfa", "#f0f7fa" }
      for index, color in ipairs(terminal) do vim.g["terminal_color_" .. (index - 1)] = color end
    end,
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        always_show_bufferline = true,
        show_tab_indicators = false,
        left_trunc_marker = "‹",
        right_trunc_marker = "›",
        custom_areas = { right = function() return require("dreamcore.workbench").toolbar() end },
        diagnostics = "nvim_lsp",
        show_buffer_icons = false,
        buffer_close_icon = "×",
        modified_icon = "●",
        close_icon = "×",
        max_name_length = 22,
        tab_size = 20,
        separator_style = "thin",
        indicator = { style = "underline" },
        show_buffer_close_icons = true,
        show_close_icon = false,
        hover = { enabled = true, delay = 120, reveal = { "close" } },
        offsets = { { filetype = "snacks_picker_list", text = "FILES", highlight = "Directory", separator = false } },
      },
    },
  },
  {
    "Bekaboo/dropbar.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      icons = {
        kinds = { dir_icon = '', file_icon = '' },
        ui = { bar = { separator = ' / ' }, menu = { indicator = '› ' } },
      },
      bar = {
        enable = function(buf, win)
          return vim.api.nvim_buf_is_valid(buf)
            and vim.api.nvim_win_is_valid(win)
            and vim.fn.win_gettype(win) == ""
            and vim.bo[buf].buftype == ""
            and not vim.tbl_contains({ "snacks_dashboard", "snacks_picker_list", "help" }, vim.bo[buf].filetype)
        end,
      },
    },
    keys = {
      { "<leader>;", function() require("dropbar.api").pick() end, desc = "Pick Breadcrumb" },
      { "[;", function() require("dropbar.api").goto_context_start() end, desc = "Previous Context" },
      { "];", function() require("dropbar.api").select_next_context() end, desc = "Next Context" },
    },
  },
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      cursor_color = "#57d9f5",
      stiffness = 0.8,
      trailing_stiffness = 0.55,
      damping = 0.9,
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      scroll_buffer_space = true,
      smear_insert_mode = false,
    },
  },
  {
    "nvim-mini/mini.animate",
    version = false,
    config = function()
      local animate = require("mini.animate")
      animate.setup({
        cursor = { enable = false }, -- smear-cursor owns this motion layer
        scroll = { enable = false }, -- Snacks provides smooth scrolling
        resize = { enable = true, timing = animate.gen_timing.cubic({ duration = 160, unit = "total" }) },
        open = { enable = true, timing = animate.gen_timing.cubic({ duration = 180, unit = "total" }) },
        close = { enable = true, timing = animate.gen_timing.cubic({ duration = 140, unit = "total" }) },
      })
    end,
  },
  {
    "echasnovski/mini.map",
    version = false,
    dependencies = { "lewis6991/gitsigns.nvim" },
    config = function()
      local map = require("mini.map")
      map.setup({
        integrations = { map.gen_integration.diagnostic(), map.gen_integration.gitsigns() },
        symbols = { encode = map.gen_encode_symbols.block("3x2"), scroll_line = "◆", scroll_view = "┃" },
        window = { focusable = false, side = "right", width = 5, winblend = 0 },
      })
      vim.keymap.set("n", "<leader>um", function() MiniMap.toggle() end, { desc = "Toggle Minimap" })

    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("rainbow-delimiters.setup").setup({
        highlight = {
          "RainbowDelimiterViolet", "RainbowDelimiterCyan", "RainbowDelimiterRed",
          "RainbowDelimiterBlue", "RainbowDelimiterYellow", "RainbowDelimiterGreen",
        },
        condition = function(buf)
          local lines = vim.api.nvim_buf_line_count(buf)
          return lines < 10000
        end,
      })
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 90,
        under_cursor = true,
        large_file_cutoff = 10000,
        filetypes_denylist = { "snacks_dashboard", "snacks_picker_list", "drop", "toggleterm" },
      })
      vim.keymap.set("n", "]]", function() require("illuminate").goto_next_reference(false) end, { desc = "Next Glowing Reference" })
      vim.keymap.set("n", "[[", function() require("illuminate").goto_prev_reference(false) end, { desc = "Previous Glowing Reference" })
    end,
  },
  { "lewis6991/gitsigns.nvim", event = "BufReadPre", opts = { signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "" }, topdelete = { text = "" }, changedelete = { text = "▎" } }, current_line_blame = false } },
}
