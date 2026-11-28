-- Stacks the minimized-agent badges in the top-right corner, top to bottom by `order`:
-- Claude Code's crab (0), then Codex (10). When one goes away, the ones below move up.
local M = {}

local slots = {} -- id → { order, win }

function M.layout()
  local items = {}
  for id, s in pairs(slots) do
    if vim.api.nvim_win_is_valid(s.win) then table.insert(items, s) else slots[id] = nil end
  end
  table.sort(items, function(a, b) return a.order < b.order end)
  local row = 1
  for _, s in ipairs(items) do
    vim.api.nvim_win_set_config(s.win, { relative = 'editor', anchor = 'NE', row = row, col = vim.o.columns - 1 })
    row = row + vim.api.nvim_win_get_height(s.win) + 2 -- + its border
  end
end

-- Register a badge's window (or pass nil when it closes) and restack.
function M.set(id, order, win)
  slots[id] = win and { order = order, win = win } or nil
  M.layout()
end

vim.api.nvim_create_autocmd('VimResized', { callback = function() M.layout() end })

return M
