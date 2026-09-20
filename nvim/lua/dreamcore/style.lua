local M = {}
M.colors = {
  black = '#050607', base = '#090b0d', panel = '#0e1215', raised = '#141c21',
  border = '#24343e', muted = '#627580', text = '#d5e0e7', white = '#f0f7fa',
  cyan = '#57d9f5', ice = '#b8edfa', dim = '#286071', green = '#88d6b0',
  yellow = '#ddc38b', red = '#ef8292', blue = '#91b9e8',
}
function M.apply()
  local c = M.colors
  local groups = {
    Normal = { fg = c.text, bg = c.base }, NormalNC = { fg = c.text, bg = c.base },
    NormalFloat = { fg = c.text, bg = c.panel }, FloatBorder = { fg = c.border, bg = c.panel },
    FloatTitle = { fg = c.cyan, bg = c.panel, bold = true },
    WinSeparator = { fg = c.border }, CursorLine = { bg = '#0e1519' },
    CursorLineNr = { fg = c.cyan, bold = true }, LineNr = { fg = '#42535e' },
    SignColumn = { bg = c.base }, EndOfBuffer = { fg = c.base },
    Visual = { bg = '#1b3540' }, Search = { fg = c.white, bg = '#284755' },
    IncSearch = { fg = c.black, bg = c.cyan }, MatchParen = { fg = c.cyan, bold = true, underline = true },
    Pmenu = { fg = c.text, bg = c.panel }, PmenuSel = { fg = c.white, bg = '#203740', bold = true },
    PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.dim },
    StatusLine = { fg = c.muted, bg = c.black }, StatusLineNC = { fg = c.muted, bg = c.black },
    TabLineFill = { bg = c.black }, WinBar = { fg = c.muted, bg = c.base },
    WinBarNC = { fg = c.muted, bg = c.base }, Directory = { fg = c.ice },
    Comment = { fg = c.muted, italic = true }, NonText = { fg = c.border },
    SnacksIndent = { fg = '#17232a' }, SnacksIndentScope = { fg = c.dim },
    SnacksIndentChunk = { fg = c.cyan }, SnacksPickerBorder = { fg = c.border, bg = c.panel },
    SnacksPickerNormal = { bg = c.panel, fg = c.text },
    SnacksPickerInputBorder = { fg = c.dim, bg = c.panel },
    SnacksPickerTitle = { fg = c.cyan, bg = c.panel, bold = true },
    SnacksPickerInputTitle = { fg = c.cyan, bg = c.panel, bold = true },
    SnacksPickerMatch = { fg = c.cyan, bold = true }, SnacksPickerDir = { fg = c.muted },
    SnacksPickerListCursorLine = { bg = '#192a32' },
    SnacksNotifierBorderInfo = { fg = c.dim }, SnacksNotifierTitleInfo = { fg = c.cyan },
    NoiceCmdlinePopupBorder = { fg = c.dim, bg = c.panel },
    NoiceCmdlineIcon = { fg = c.cyan }, NoiceCmdlinePopup = { bg = c.panel },
    MiniMapNormal = { bg = c.black }, MiniMapSymbolView = { fg = c.dim },
    MiniMapSymbolLine = { fg = c.cyan }, MiniAnimateNormalFloat = { bg = c.panel },
    DropBarCurrentContext = { fg = c.ice, bold = true }, DropBarIconUISeparator = { fg = c.border },
    IlluminatedWordText = { bg = '#14262e' }, IlluminatedWordRead = { bg = '#14262e' },
    IlluminatedWordWrite = { bg = '#19343e', bold = true },
    DreamHomeIcon = { fg = c.dim, bg = c.base }, DreamHomeSelected = { fg = c.cyan, bg = c.base, bold = true },
    DreamHomeScan = { fg = c.ice, bg = c.base }, DreamHomeIdleScan = { fg = c.dim, bg = c.base },
    DreamHomeGhost = { fg = c.border, bg = c.base },
  }
  for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
end
function M.setup()
  local group = vim.api.nvim_create_augroup('ObsidianStyle', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = M.apply })
  vim.api.nvim_create_autocmd('User', { group = group, pattern = 'VeryLazy', callback = function() vim.schedule(M.apply) end })
  M.apply()
end
return M
