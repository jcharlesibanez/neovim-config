local M = {}
local timer

function M.text()
  local format = vim.o.columns < 75 and '%d %b %H:%M:%S' or '%a %d %b %Y %H:%M:%S'
  return os.date(format):upper()
end

function M.setup()
  local group = vim.api.nvim_create_augroup('WorkbenchClock', { clear = true })
  local function start()
    if timer or #vim.api.nvim_list_uis() == 0 then return end
    timer = assert((vim.uv or vim.loop).new_timer())
    timer:start(0, 1000, vim.schedule_wrap(function()
      if timer and #vim.api.nvim_list_uis() > 0 then vim.cmd.redrawtabline() end
    end))
  end
  vim.api.nvim_create_autocmd('UIEnter', { group = group, callback = start })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    if timer then timer:stop(); timer:close(); timer = nil end
  end })
  start()
end
return M
