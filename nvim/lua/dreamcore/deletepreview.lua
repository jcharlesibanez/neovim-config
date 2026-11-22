-- After `d`, show absolute line numbers and light up the lines a `d{count}j` / `d{count}k`
-- would remove, updating live as you type the count.
--
-- Why a mapping instead of watching operator-pending mode: Neovim doesn't run timers or
-- scheduled callbacks while you're typing a count, so the preview couldn't update live.
-- Here `d` reads the count itself, redrawing after each digit, then hands the full
-- command to the built-in `d` — so registers, dot-repeat and every motion still work.
local M = {}
local ns = vim.api.nvim_create_namespace('delete_preview')

local function draw(buf, cur, n)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local last = vim.api.nvim_buf_line_count(buf)
  local function mark(line, group)
    vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, { number_hl_group = group, priority = 300 })
  end
  -- Direction isn't known until j/k, so show both: down solid, up dimmer.
  for line = math.max(1, cur - n), cur - 1 do mark(line, 'DeletePreviewUp') end
  for line = cur, math.min(last, cur + n) do mark(line, 'DeletePreview') end
  vim.cmd('redraw')
end

local function delete()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local prefix = '"' .. vim.v.register .. (vim.v.count > 0 and tostring(vim.v.count) or '')
  local cur = vim.api.nvim_win_get_cursor(win)[1]
  local rnu = vim.wo[win].relativenumber
  if vim.wo[win].number then vim.wo[win].relativenumber = false end -- real line numbers, not distances

  local count, key = '', ''
  while true do
    draw(buf, cur, tonumber(count) or 0)
    local ok, c = pcall(vim.fn.getcharstr)
    if not ok then c = vim.keycode('<Esc>') end
    if c:match('^%d$') and not (c == '0' and count == '') then -- a leading 0 is a motion
      count = count .. c
    else
      key = c
      break
    end
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.wo[win].relativenumber = rnu
  vim.api.nvim_feedkeys(prefix .. 'd' .. count .. key, 'n', false)
end

function M.setup()
  vim.keymap.set('n', 'd', delete, { desc = 'Delete (previews d{count}j/k range)' })
end

return M
