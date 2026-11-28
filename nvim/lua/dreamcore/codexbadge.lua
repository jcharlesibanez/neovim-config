-- The badge in the top right while the Codex panel is minimized: the OpenAI logo with little
-- stars twinkling over it. It sits below Claude Code's crab when both are minimized
-- (dreamcore/badges.lua stacks them).
local M = {}

local ns = vim.api.nvim_create_namespace('codex_badge')
local win, buf, timer
local tick = 0

-- The official OpenAI mark (Simple Icons' SVG), drawn at 20×20 pixels with octant block
-- characters: each cell is a 2×4 grid of solid pixels. Ghostty and kitty draw these themselves.
local LOGO = {
  '  \u{1CDD3}\u{1CD08}\u{1CD73}\u{1CDD8}\u{1CD2B}\u{1CD27}\u{1CDBB} ',
  '\u{1CDE1}\u{1CD02}▌▐\u{1CDAE}▄\u{1CD23}\u{1CDA0}\u{1CDD5}\u{1CD48}',
  '▜\u{1CEA3}\u{1CD1D}▟  ▛\u{1CD93}\u{1CEAB}▙',
  '\u{1CD21}\u{1CD4A}\u{1CD24}\u{1CD2B}▀\u{1CDAE}▌▐\u{1CDCB}\u{1CD17}',
  ' \u{1CD05}\u{1CD06}\u{1CD23}\u{1CDA3}\u{1CDAC}\u{1CD61}\u{1CD0F}  ',
}
local CANVAS, LOGO_COL = 14, 2 -- logo is 10 wide, with 2 columns of sky each side

-- Stars sit in empty cells around and over the logo (one in its center): { row, column,
-- phase, speed }. Each runs through the twinkle on its own clock so they never blink together.
local STARS = {
  { 0, 1, 0, 1 }, { 0, 3, 5, 2 }, { 0, 11, 2, 1 }, { 1, 13, 7, 2 },
  { 2, 6, 3, 2 }, { 3, 0, 9, 1 }, { 4, 2, 4, 1 }, { 4, 11, 10, 1 },
}
local TWINKLE = { ' ', '·', '✧', '✦', '✧', '·', ' ', ' ', ' ', ' ', ' ', ' ' }
local STAR_HL = { ['·'] = 'CodexStarDim', ['✧'] = 'CodexStar', ['✦'] = 'CodexStarBright' }

local function chars(s) return vim.fn.split(s, [[\zs]]) end

local function render()
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local grid = {}
  for r = 1, #LOGO do
    grid[r] = {}
    for c = 1, CANVAS do grid[r][c] = { ' ' } end
    for j, ch in ipairs(chars(LOGO[r])) do
      if ch ~= ' ' then grid[r][LOGO_COL + j] = { ch, 'CodexLogo' } end
    end
  end
  for _, s in ipairs(STARS) do
    local ch = TWINKLE[(math.floor(tick / s[4]) + s[3]) % #TWINKLE + 1]
    if ch ~= ' ' then grid[s[1] + 1][s[2] + 1] = { ch, STAR_HL[ch] } end
  end
  local lines, marks = {}, {}
  for r, row in ipairs(grid) do
    local line = ''
    for _, cell in ipairs(row) do
      if cell[2] then table.insert(marks, { r - 1, #line, #line + #cell[1], cell[2] }) end
      line = line .. cell[1]
    end
    lines[r] = line
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, mk in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, mk[1], mk[2], { end_col = mk[3], hl_group = mk[4] })
  end
end

function M.show()
  M.hide()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor', anchor = 'NE', row = 1, col = vim.o.columns - 1, width = CANVAS, height = #LOGO,
    style = 'minimal', border = 'single', focusable = false, zindex = 200,
  })
  vim.wo[win].winhl = 'NormalFloat:AgentIndicator,FloatBorder:AgentIndicatorBorder'
  require('dreamcore.badges').set('codex', 10, win)
  render()
  timer = assert(vim.uv.new_timer())
  timer:start(140, 140, vim.schedule_wrap(function() tick = tick + 1; render() end))
end

function M.hide()
  if timer then timer:stop(); timer:close(); timer = nil end
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  win, buf = nil, nil
  require('dreamcore.badges').set('codex', 10, nil)
end

return M
