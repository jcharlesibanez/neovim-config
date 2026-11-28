-- The badge in the top right while Codex is running out of sight (panel minimized, or running in
-- the <leader>t shell while it's closed): the OpenAI logo, the same size as Claude Code's crab.
-- It sits below the crab when both show (dreamcore/badges.lua stacks them).
--   idle      → the logo, still
--   working   → the logo flips around its vertical axis like a spinning coin, with the time
--   attention → a red "!" blinks next to it: Codex needs your approval
--   unread    → same "!": Codex finished while out of sight and you haven't looked
-- Codex reports these through hooks (dreamcore/agenthooks.lua).
local M = {}

local ns = vim.api.nvim_create_namespace('codex_badge')
local win, buf, timer
local tick = 0
local turn_start -- when Codex started on your last message (hrtime, ns); nil when it's done
M.state = 'idle'

-- The official OpenAI mark (Simple Icons' SVG) at 12×12 pixels: octant block characters (each
-- cell a 2×4 grid of pixels) with two shades per cell — one for its lit pixels (fg), one for the
-- rest (bg) — which keeps the interlocking links readable at this size. Shades are 0–f (black to
-- white); a bg of 0–2 is left see-through. Frames turn it around its vertical axis: 0° is the
-- still logo, 180° its mirror image.
local FRAMES = {
  { -- 0°
    chars = { '\u{1CDCB}\u{1CD4B}\u{1CD54}\u{1CD7D}\u{1CD41}▖', '\u{1CDA1}\u{1CD56}\u{1CD87}\u{1CDD4}\u{1CD94}\u{1CD9A}', '▝\u{1CD29}\u{1CD9D}\u{1CDB1}\u{1CD12}\u{1CD02}' },
    fg = { '8dcccb', 'babbbb', 'bcccd8' },
    bg = { '032411', '121221', '114230' },
  },
  { -- 40°
    chars = { '\u{1CEA0}\u{1CDE1}\u{1CD1B}\u{1CDB8}\u{1CD93}\u{1CEA3}', '\u{1CD21}\u{1CDC5}\u{1CD87}\u{1CDD4}\u{1CD4D}\u{1CD48}', '\u{1CEAB}\u{1CD1D}\u{1CD9F}\u{1CDAF}\u{1CD17}\u{1CEA8}' },
    fg = { '39cbb0', '7a99a7', '0bbc93' },
    bg = { '003220', '031130', '022300' },
  },
  { -- 70°
    chars = { '██\u{1CD63}\u{1CD39}██', '█▝\u{1CD3C}\u{1CDCD}▖█', '██\u{1CD1A}\u{1CD43}██' },
    fg = { '009b00', '009900', '00b900' },
    bg = { '003400', '006600', '004300' },
  },
  { -- 110°
    chars = { '██\u{1CD78}\u{1CD9D}██', '█▗\u{1CDBC}\u{1CD7B}▘█', '██\u{1CD7D}\u{1CD0A}██' },
    fg = { '00b900', '009900', '009b00' },
    bg = { '004300', '006600', '003400' },
  },
  { -- 140°
    chars = { '\u{1CEA0}\u{1CD4B}\u{1CDB9}\u{1CD0C}\u{1CDDE}\u{1CEA3}', '\u{1CD96}\u{1CD95}\u{1CDC1}\u{1CD5C}\u{1CDD0}\u{1CD0D}', '\u{1CEAB}\u{1CD26}\u{1CDB3}\u{1CD64}\u{1CD12}\u{1CEA8}' },
    fg = { '0bbc93', '7a99a7', '39cbb0' },
    bg = { '022300', '031130', '003220' },
  },
  { -- 180°
    chars = { '▗\u{1CD7C}\u{1CD43}\u{1CD83}\u{1CD93}\u{1CDBB}', '\u{1CD50}\u{1CD4C}\u{1CDC1}\u{1CD5C}\u{1CD8A}\u{1CD6B}', '\u{1CD05}\u{1CD1D}\u{1CDB4}\u{1CD63}\u{1CD28}▘' },
    fg = { 'bcccd8', 'bbbbab', '8dcccb' },
    bg = { '114230', '122121', '032411' },
  },
  { -- 220°
    chars = { '\u{1CEA0}\u{1CD4B}\u{1CDB9}\u{1CD0C}\u{1CDDE}\u{1CEA3}', '\u{1CD96}\u{1CD95}\u{1CDC1}\u{1CD5C}\u{1CDD0}\u{1CD0D}', '\u{1CEAB}\u{1CD26}\u{1CDB3}\u{1CD64}\u{1CD12}\u{1CEA8}' },
    fg = { '0bbc93', '7a99a7', '39cbb0' },
    bg = { '022300', '031130', '003220' },
  },
  { -- 250°
    chars = { '██\u{1CD78}\u{1CD9D}██', '█▗\u{1CDBC}\u{1CD7B}▘█', '██\u{1CD7D}\u{1CD0A}██' },
    fg = { '00b900', '009900', '009b00' },
    bg = { '004300', '006600', '003400' },
  },
  { -- 290°
    chars = { '██\u{1CD63}\u{1CD39}██', '█▝\u{1CD3C}\u{1CDCD}▖█', '██\u{1CD1A}\u{1CD43}██' },
    fg = { '009b00', '009900', '00b900' },
    bg = { '003400', '006600', '004300' },
  },
  { -- 320°
    chars = { '\u{1CEA0}\u{1CDE1}\u{1CD1B}\u{1CDB8}\u{1CD93}\u{1CEA3}', '\u{1CD21}\u{1CDC5}\u{1CD87}\u{1CDD4}\u{1CD4D}\u{1CD48}', '\u{1CEAB}\u{1CD1D}\u{1CD9F}\u{1CDAF}\u{1CD17}\u{1CEA8}' },
    fg = { '39cbb0', '7a99a7', '0bbc93' },
    bg = { '003220', '031130', '022300' },
  },
}
local CANVAS, LOGO_COL = 11, 2 -- same 11×3 box as the crab; the logo is 6 wide
local BANG = { '██', '▀▀', '▀▀' } -- the "!": bar, then the dot under a half-row gap

local function chars(s) return vim.fn.split(s, [[\zs]]) end

-- One highlight per shade pair, made as needed.
local function shade(fg, bg)
  local name = 'CodexPx' .. fg .. bg
  local f, b = tonumber(fg, 16) * 17, tonumber(bg, 16) * 17
  vim.api.nvim_set_hl(0, name, { fg = ('#%02x%02x%02x'):format(f, f, f),
                                 bg = tonumber(bg, 16) <= 2 and 'NONE' or ('#%02x%02x%02x'):format(b, b, b) })
  return name
end

local function elapsed()
  local s = math.floor((vim.uv.hrtime() - turn_start) / 1e9)
  local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
  s = s % 60
  if h > 0 then return ('%dh %dm %ds'):format(h, m, s) end
  if m > 0 then return ('%dm %ds'):format(m, s) end
  return s .. 's'
end

local function render()
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local frame = M.state == 'working' and FRAMES[tick % #FRAMES + 1] or FRAMES[1]
  local bang = M.state == 'attention' or M.state == 'unread'
  local bang_on = bang and math.floor(tick / 5) % 2 == 0
  local lines, marks = {}, {}
  for r = 1, 3 do
    local cs, fgs, bgs = chars(frame.chars[r]), frame.fg[r], frame.bg[r]
    local line = (' '):rep(LOGO_COL)
    for c, ch in ipairs(cs) do
      local fg, bg = fgs:sub(c, c), bgs:sub(c, c)
      if ch ~= ' ' or tonumber(bg, 16) > 2 then
        table.insert(marks, { r - 1, #line, #line + #ch, shade(fg, bg) })
      end
      line = line .. ch
    end
    line = line .. (' '):rep(CANVAS - LOGO_COL - #cs)
    if bang then
      local b = bang_on and BANG[r] or '  '
      table.insert(marks, { r - 1, #line + 1, #line + 1 + #b, 'AgentAttention' })
      line = line .. ' ' .. b .. ' '
    end
    lines[r] = line
  end
  -- While Codex is on your message (working, or waiting on an approval): how long so far.
  if turn_start and (M.state == 'working' or M.state == 'attention') then
    local text, width = elapsed(), vim.fn.strdisplaywidth(lines[1])
    local left = math.floor((width - #text) / 2)
    table.insert(lines, (' '):rep(left) .. text .. (' '):rep(width - left - #text))
    table.insert(marks, { #lines - 1, left, left + #text, 'AgentTime' })
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mk in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mk[1], mk[2], { end_col = mk[3], hl_group = mk[4] })
  end
  local width = vim.fn.strdisplaywidth(lines[1])
  if vim.api.nvim_win_get_width(win) ~= width or vim.api.nvim_win_get_height(win) ~= #lines then
    vim.api.nvim_win_set_config(win, { width = width, height = #lines })
    require('dreamcore.badges').layout()
  end
end

-- Animate only while there's something moving: the flip (working) or the blinking "!".
local function animate()
  local moving = win and M.state ~= 'idle'
  if moving and not timer then
    timer = assert(vim.uv.new_timer())
    timer:start(110, 110, vim.schedule_wrap(function() tick = tick + 1; render() end))
  elseif not moving and timer then
    timer:stop(); timer:close(); timer = nil
  end
end

function M.visible() return win ~= nil and vim.api.nvim_win_is_valid(win) end

function M.show()
  if M.visible() then return end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor', anchor = 'NE', row = 1, col = vim.o.columns - 1, width = CANVAS, height = 3,
    style = 'minimal', border = 'single', focusable = false, zindex = 200,
  })
  vim.wo[win].winhl = 'NormalFloat:AgentIndicator,FloatBorder:AgentIndicatorBorder'
  require('dreamcore.badges').set('codex', 10, win)
  render()
  animate()
end

function M.hide()
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  win, buf = nil, nil
  require('dreamcore.badges').set('codex', 10, nil)
  animate()
end

function M.set_state(state)
  -- You sent a message: Codex starts working and the clock starts.
  if state == 'start' then state, turn_start = 'working', vim.uv.hrtime() end
  if state == 'done' or state == 'idle' then turn_start = nil end
  -- Codex finished: if its badge is showing (out of sight), that's a reply you haven't read.
  if state == 'done' then state = M.visible() and 'unread' or 'idle' end
  M.state = state
  render()
  animate()
end

-- You looked at Codex: its reply is read. (An approval still waiting keeps its "!".)
function M.seen()
  if M.state == 'unread' then M.set_state('idle') end
end

return M
