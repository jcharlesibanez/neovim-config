-- Study mode: no inline errors, no completion — like coding on paper.
-- Toggling shows a short red italic note in the bottom right that fades out.
local M = {}
local RED = '#ff1a3a'

function M.toggle()
  vim.g.studymode = not vim.g.studymode
  local on = vim.g.studymode
  vim.diagnostic.enable(not on)
  pcall(vim.lsp.inlay_hint.enable, false)
  local ok, cmp = pcall(require, 'cmp')
  if ok and on then cmp.close() end
  require('dreamcore.toast').show(on and '✎ Study mode active' or '✎ Study mode off', { id = 'studymode', color = RED })
end

function M.setup()
  vim.g.studymode = false
  vim.api.nvim_create_user_command('StudyMode', M.toggle, { desc = 'Toggle study mode (no diagnostics or completion)' })
  vim.cmd([[cnoreabbrev <expr> studymode getcmdtype() == ':' && getcmdline() ==# 'studymode' ? 'StudyMode' : 'studymode']])
end

return M
