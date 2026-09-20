return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    cmdline = { enabled = true, view = "cmdline_popup" },
    messages = { enabled = true },
    popupmenu = { enabled = true, backend = "nui" },
    lsp = {
      progress = { enabled = false },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    presets = { bottom_search = false, command_palette = true, long_message_to_split = true, lsp_doc_border = true },
    views = {
      cmdline_popup = {
        position = { row = "35%", col = "50%" },
        size = { width = 64, height = "auto" },
        border = { style = "single", padding = { 0, 1 } },
        win_options = { winblend = 0, winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder" },
      },
      popupmenu = { relative = "editor", position = { row = "45%", col = "50%" }, size = { width = 64, height = 10 }, border = { style = "single" } },
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
}
