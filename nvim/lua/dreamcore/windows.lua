-- Jump between windows by number, counted left to right (top to bottom within a column):
-- usually 1 = explorer, 2 = file, 3 = Claude Code. Ctrl+1 … Ctrl+9 jump straight to one;
-- Ctrl+L moves to the next one, wrapping around.
--
-- Ctrl+number needs a terminal that can send it (Ghostty and kitty can; plain Terminal.app can't).
local M = {}

-- Set by init.lua: the open Claude Code panel (a floating window, so it needs counting
-- explicitly) and a hook that runs before each jump.
M.agent_win = function() return nil end
M.on_jump = function(from, to) end

local function filetype(win) return vim.bo[vim.api.nvim_win_get_buf(win)].filetype end

-- The windows you can jump to, in order. The explorer counts once (its list, not its search box).
function M.list()
  local agent = M.agent_win()
  local found = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg, ft = vim.api.nvim_win_get_config(win), filetype(win)
    -- The explorer's list floats inside its sidebar, so it's counted by type, not by layout.
    local explorer_list = ft == 'snacks_picker_list'
    local explorer_part = ft:match('^snacks_') and not explorer_list
    if not explorer_part and (cfg.relative == '' or win == agent or explorer_list) then
      local pos = vim.api.nvim_win_get_position(win)
      table.insert(found, { win = win, row = pos[1], col = pos[2] })
    end
  end
  table.sort(found, function(a, b)
    if a.col ~= b.col then return a.col < b.col end
    return a.row < b.row
  end)
  return vim.tbl_map(function(x) return x.win end, found)
end

function M.go(win)
  local from = vim.api.nvim_get_current_win()
  if not win or win == from then return end
  M.on_jump(from, win)
  if vim.api.nvim_get_mode().mode:sub(1, 1) == 'i' then vim.cmd.stopinsert() end
  vim.api.nvim_set_current_win(win)
  -- Terminals (Claude Code, :ToggleTerm) start ready to type.
  if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal' then vim.cmd.startinsert() end
end

function M.jump(n) M.go(M.list()[n]) end

function M.next()
  local wins, cur = M.list(), vim.api.nvim_get_current_win()
  if #wins == 0 then return end
  for i, win in ipairs(wins) do
    if win == cur then return M.go(wins[i % #wins + 1]) end
  end
  M.go(wins[1]) -- somewhere not in the list (e.g. the explorer's search box): start at 1
end

function M.setup()
  for n = 1, 9 do
    vim.keymap.set({ 'n', 'i', 't', 'x' }, ('<C-%d>'):format(n), function() M.jump(n) end,
      { desc = ('Go to window %d (left to right)'):format(n) })
  end
end

return M
