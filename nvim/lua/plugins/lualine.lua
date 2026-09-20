return {
  'nvim-lualine/lualine.nvim',
  config = function()
    local c = require('dreamcore.style').colors
    local theme = {}
    for mode, accent in pairs({ normal = c.cyan, insert = c.green, visual = c.ice, replace = c.red, command = c.yellow, inactive = c.muted }) do
      theme[mode] = { a = { bg = c.black, fg = accent, gui = 'bold' }, b = { bg = c.black, fg = c.muted }, c = { bg = c.black, fg = c.text } }
    end
    require('lualine').setup({
      options = {
        theme = theme, globalstatus = true, icons_enabled = false,
        component_separators = '', section_separators = '',
        disabled_filetypes = { statusline = { 'snacks_dashboard', 'dream_home' } },
        refresh = { statusline = 160 },
      },
      sections = {
        lualine_a = { { 'mode', fmt = function(mode) return '▎ ' .. mode end } },
        lualine_b = { 'branch', { 'diff', symbols = { added = '+', modified = '~', removed = '−' } } },
        lualine_c = { { 'filename', path = 0, symbols = { modified = ' ●', readonly = ' [RO]', unnamed = 'Untitled' } } },
        lualine_x = {
          { 'diagnostics', symbols = { error = 'E ', warn = 'W ', info = 'I ', hint = '· ' } },
          { 'filetype', color = { fg = c.muted } },
          { function() return require('dreamcore.motion').status() end, color = { fg = c.cyan } },
        },
        lualine_y = { 'progress' }, lualine_z = { 'location' },
      },
    })
  end,
}
