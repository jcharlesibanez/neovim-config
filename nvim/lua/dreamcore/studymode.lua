-- Study mode: no inline errors, no completion — like coding on paper.
local M = {}
local badge_win

local function close_badge()
  if badge_win and vim.api.nvim_win_is_valid(badge_win) then
    vim.api.nvim_win_close(badge_win, true)
  end
  badge_win = nil
end

local function open_badge()
  close_badge()
  local text = ' ✎ STUDY MODE ACTIVE '
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.bo[buf].bufhidden = 'wipe'
  badge_win = vim.api.nvim_open_win(buf, false, {
    relative  = 'editor',
    anchor    = 'NE',
    -- Stack below the AGENT ON badge when it is showing.
    row       = vim.g.agent_badge_visible and 4 or 1,
    col       = vim.o.columns - 1,
    width     = vim.fn.strdisplaywidth(text),
    height    = 1,
    style     = 'minimal',
    border    = 'single',
    focusable = false,
    zindex    = 200,
  })
  vim.api.nvim_set_option_value('winhl', 'NormalFloat:AgentIndicator,FloatBorder:AgentIndicatorBorder', { win = badge_win })
end

function M.reposition()
  if vim.g.studymode then open_badge() end
end

function M.toggle()
  vim.g.studymode = not vim.g.studymode
  local on = vim.g.studymode
  vim.diagnostic.enable(not on)
  pcall(vim.lsp.inlay_hint.enable, false)
  local ok, cmp = pcall(require, 'cmp')
  if ok and on then cmp.close() end
  if on then open_badge() else close_badge() end
  vim.notify(on and 'Study mode on — no errors, no suggestions.' or 'Study mode off.')
end

function M.setup()
  vim.g.studymode = false
  vim.api.nvim_create_user_command('StudyMode', M.toggle, { desc = 'Toggle study mode (no diagnostics or completion)' })
  vim.cmd([[cnoreabbrev <expr> studymode getcmdtype() == ':' && getcmdline() ==# 'studymode' ? 'StudyMode' : 'studymode']])
  vim.api.nvim_create_autocmd('VimResized', { callback = M.reposition })
end

return M
