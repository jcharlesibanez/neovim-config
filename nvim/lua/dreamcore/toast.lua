-- Small italic messages in the bottom right that fade in, stay a moment, then fade out.
-- No box around them. They stack above whatever badge is already in the bottom right
-- (e.g. the :Music now-playing badge); otherwise they sit on the bottom line.
--
--   require('dreamcore.toast').show('Study mode active', { color = '#ff1a3a' })
--   show(text, { id = 'x', timeout = false })  -- stays until shown again with the same id
--
-- Showing a toast with an id that is already up changes that toast in place (no new popup).
local M = {}

local FADE_IN, FADE_OUT, TICK = 160, 700, 30 -- ms
local DEFAULT_TIMEOUT = 2500                    -- ms the toast stays fully visible
local DEFAULT_COLOR = '#ffffff'

local toasts = {} -- newest last; each {id, text, color, timeout, phase, t, win, buf, hl}
local timer
local seq = 0

-- Fade toward the terminal's background. The editor is see-through, so use the
-- background Neovim thinks it has: black when dark, near-white when light.
local function backdrop() return vim.o.background == 'light' and 0xfafafa or 0x000000 end

local function mix(color, amount) -- amount 0 = backdrop, 1 = full color
  local c, b = tonumber(color:sub(2), 16), backdrop()
  local out = 0
  for shift = 16, 0, -8 do
    local cc, bb = bit.band(bit.rshift(c, shift), 0xff), bit.band(bit.rshift(b, shift), 0xff)
    out = out + bit.lshift(math.floor(bb + (cc - bb) * amount + 0.5), shift)
  end
  return ('#%06x'):format(out)
end

local function bottom_row() return math.max(0, vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - 1) end

local function is_toast(win)
  for _, t in ipairs(toasts) do if t.win == win then return true end end
  return false
end

-- Lowest free row in the bottom-right corner: above any non-focusable badge float there.
local function base_row()
  local row = bottom_row()
  local moved = true
  while moved and row >= 0 do
    moved = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative == 'editor' and not cfg.focusable and not is_toast(win) and not cfg.hide then
        local border = (cfg.border and cfg.border ~= 'none' and #cfg.border > 0) and 2 or 0
        local top = type(cfg.row) == 'table' and cfg.row[false] or cfg.row
        local col = type(cfg.col) == 'table' and cfg.col[false] or cfg.col
        local bottom = top + cfg.height - 1 + border
        local right = col + cfg.width + border
        if right >= vim.o.columns - 3 and top <= row and bottom >= row then
          row, moved = top - 1, true
        end
      end
    end
  end
  return row >= 0 and row or bottom_row()
end

local function text_of(t)
  local text = ' ' .. t.text .. ' '
  local max = math.max(10, vim.o.columns - 4)
  if vim.fn.strdisplaywidth(text) > max then
    while vim.fn.strdisplaywidth(text) > max - 2 do text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1) end
    text = text .. '… '
  end
  return text
end

function M.reflow()
  local row = base_row()
  for i = #toasts, 1, -1 do -- newest at the bottom, older ones above it
    local t = toasts[i]
    local text = text_of(t)
    local width = vim.fn.strdisplaywidth(text)
    local cfg = {
      relative = 'editor', row = math.max(0, row), col = math.max(0, vim.o.columns - width - 1),
      width = width, height = 1, style = 'minimal', focusable = false, zindex = 160, border = 'none',
    }
    if t.win and vim.api.nvim_win_is_valid(t.win) then
      vim.api.nvim_buf_set_lines(t.buf, 0, -1, false, { text })
      vim.api.nvim_win_set_config(t.win, cfg)
    else
      t.buf = vim.api.nvim_create_buf(false, true)
      vim.bo[t.buf].bufhidden = 'wipe'
      vim.api.nvim_buf_set_lines(t.buf, 0, -1, false, { text })
      cfg.noautocmd = true
      t.win = vim.api.nvim_open_win(t.buf, false, cfg)
      vim.wo[t.win].winhl = 'Normal:' .. t.hl .. ',NormalFloat:' .. t.hl
    end
    row = row - 1
  end
end

local function close(t)
  if t.win and vim.api.nvim_win_is_valid(t.win) then vim.api.nvim_win_close(t.win, true) end
  pcall(vim.api.nvim_set_hl, 0, t.hl, {})
  for i, x in ipairs(toasts) do if x == t then table.remove(toasts, i) break end end
end

local function paint(t, amount)
  vim.api.nvim_set_hl(0, t.hl, { fg = mix(t.color, amount), bg = 'NONE', italic = true })
end

local function tick()
  local changed = false
  for _, t in ipairs(vim.list_extend({}, toasts)) do
    t.t = t.t + TICK
    if t.phase == 'in' then
      paint(t, math.min(1, t.t / FADE_IN))
      if t.t >= FADE_IN then t.phase, t.t = 'hold', 0 end
    elseif t.phase == 'hold' then
      if t.timeout and t.t >= t.timeout then t.phase, t.t = 'out', 0 end
    elseif t.phase == 'out' then
      local left = 1 - t.t / FADE_OUT
      if left <= 0 then close(t); changed = true else paint(t, left * left) end
    end
  end
  if changed then M.reflow() end
  if #toasts == 0 and timer then timer:stop(); timer:close(); timer = nil end
end

---@param text string
---@param opts? {id?:string, color?:string, timeout?:integer|false}
function M.show(text, opts)
  opts = opts or {}
  local timeout = opts.timeout
  if timeout == nil then timeout = DEFAULT_TIMEOUT end
  local t
  for _, x in ipairs(toasts) do if opts.id and x.id == opts.id then t = x end end
  if t then
    -- Same id: change it in place and keep it fully visible (no fade back in).
    t.text, t.color, t.timeout = text, opts.color or DEFAULT_COLOR, timeout or nil
    t.phase, t.t = 'hold', 0
    paint(t, 1)
  else
    seq = seq + 1
    t = { id = opts.id, text = text, color = opts.color or DEFAULT_COLOR, timeout = timeout or nil,
          phase = 'in', t = 0, hl = 'DreamToast' .. seq }
    table.insert(toasts, t)
    paint(t, 0)
  end
  M.reflow()
  if not timer then
    timer = assert(vim.uv.new_timer())
    timer:start(TICK, TICK, vim.schedule_wrap(tick))
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('VimResized', { callback = function() if #toasts > 0 then M.reflow() end end })
end

return M
