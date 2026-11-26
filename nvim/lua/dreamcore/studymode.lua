-- Study mode: no inline errors, no completion — like coding on paper.
-- While it's on, a red italic note sits in the bottom right; turning it off fades it out.
local M = {}
local RED = '#ff1a3a'

function M.toggle()
  vim.g.studymode = not vim.g.studymode
  local on = vim.g.studymode
  vim.diagnostic.enable(not on)
  pcall(vim.lsp.inlay_hint.enable, false)
  local ok, cmp = pcall(require, 'cmp')
  if ok and on then cmp.close() end
  -- On: stays in the bottom right (just above the music badge) for as long as it's on.
  -- Off: changes to "Study mode off" and fades out.
  require('dreamcore.toast').show(on and '✎ Study mode active' or '✎ Study mode off',
    { id = 'studymode', color = RED, order = 10, timeout = not on and 2500 or false })
end

function M.setup()
  vim.g.studymode = false
  vim.api.nvim_create_user_command('StudyMode', M.toggle, { desc = 'Toggle study mode (no diagnostics or completion)' })
  vim.cmd([[cnoreabbrev <expr> studymode getcmdtype() == ':' && getcmdline() ==# 'studymode' ? 'StudyMode' : 'studymode']])
end

return M
