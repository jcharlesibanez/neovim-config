-- The badge in the top right while the Claude Code panel is minimized: the Claude Code crab,
-- drawn cell for cell as Claude Code 2.1 draws it.
--   working   → the crab dances (shuffles side to side, switching which claw is up)
--   idle      → it stands still
--   attention → it stands still with a red "!" next to it, blinking: Claude needs your approval
--   unread    → same "!": Claude finished while the panel was minimized and you haven't looked yet
-- Claude Code reports these through hooks (see M.hook_settings), which call dream_agent_state().
local M = {}

local ns = vim.api.nvim_create_namespace('agent_badge')
local win, buf, timer
local tick = 0
local turn_start -- when Claude started on your last message (hrtime, ns); nil when it's done
M.state = 'idle'

-- Elapsed time the way Claude Code shows it: 12s, 1m 5s, 1h 2m 3s.
local function elapsed()
  local s = math.floor((vim.uv.hrtime() - turn_start) / 1e9)
  local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
  s = s % 60
  if h > 0 then return ('%dh %dm %ds'):format(h, m, s) end
  if m > 0 then return ('%dm %ds'):format(m, s) end
  return s .. 's'
end

-- Each row is { text, mask }: 'x' in the mask = that cell has the black background that
-- turns the dark corners of ▛ into eyes.
local CRAB = {
  { ' ▐▛███▛█ ', '  xxxxxx ' },
  { '▝▜██████▀', '  xxxxx  ' },
  { ' ▝▝   ▝▝ ', '         ' },
}
local CANVAS = 11 -- crab is 9 wide; one spare column each side to shuffle into
local BANG = { '██', '▀▀', '▀▀' } -- the "!": bar, then the dot under a half-row gap

local FLIP = { ['▐'] = '▌', ['▌'] = '▐', ['▛'] = '▜', ['▜'] = '▛', ['▝'] = '▘', ['▘'] = '▝',
               ['▙'] = '▟', ['▟'] = '▙', ['▖'] = '▗', ['▗'] = '▖' }
local function chars(s) return vim.fn.split(s, [[\zs]]) end
local function mirror(rows) -- the crab facing the other way (other claw up)
  return vim.tbl_map(function(r)
    local t, m = chars(r[1]), chars(r[2])
    local rt, rm = {}, {}
    for i = #t, 1, -1 do table.insert(rt, FLIP[t[i]] or t[i]); table.insert(rm, m[i]) end
    return { table.concat(rt), table.concat(rm) }
  end, rows)
end
local function legs(rows, from) -- same body, the other pair of legs forward
  return { rows[1], rows[2], from[3] }
end

local LEFT = CRAB
local RIGHT = mirror(CRAB)
-- The dance: { pose, column offset }.
local DANCE = {
  { LEFT, 1 }, { legs(LEFT, RIGHT), 2 }, { LEFT, 1 },
  { RIGHT, 1 }, { legs(RIGHT, LEFT), 0 }, { RIGHT, 1 },
}

local function render()
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  local pose, off = LEFT, 1
  if M.state == 'working' then pose, off = unpack(DANCE[math.floor(tick / 2) % #DANCE + 1]) end
  local bang = M.state == 'attention' or M.state == 'unread'
  local bang_on = bang and math.floor(tick / 5) % 2 == 0
  local lines, marks = {}, {}
  for i, row in ipairs(pose) do
    local t, m = chars(row[1]), chars(row[2])
    local line, byte = (' '):rep(off), off
    for j, ch in ipairs(t) do
      table.insert(marks, { i - 1, byte, byte + #ch, m[j] == 'x' and 'AgentLogoEye' or 'AgentLogo' })
      line, byte = line .. ch, byte + #ch
    end
    line = line .. (' '):rep(CANVAS - off - #t)
    if bang then
      local b = bang_on and BANG[i] or '  '
      table.insert(marks, { i - 1, #line + 1, #line + 1 + #b, 'AgentAttention' })
      line = line .. ' ' .. b .. ' '
    end
    lines[i] = line
  end
  -- While Claude is on your message (working, or waiting on an approval): how long so far.
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
    require('dreamcore.badges').layout() -- a taller crab badge pushes Codex's down
  end
end

local function animate()
  local moving = win and (M.state ~= 'idle')
  if moving and not timer then
    timer = assert(vim.uv.new_timer())
    timer:start(110, 110, vim.schedule_wrap(function() tick = tick + 1; render() end))
  elseif not moving and timer then
    timer:stop(); timer:close(); timer = nil
  end
end

function M.show()
  M.hide()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor', anchor = 'NE', row = 1, col = vim.o.columns - 1, width = CANVAS, height = #CRAB,
    style = 'minimal', border = 'single', focusable = false, zindex = 200,
  })
  vim.wo[win].winhl = 'NormalFloat:AgentIndicator,FloatBorder:AgentIndicatorBorder'
  require('dreamcore.badges').set('claude', 0, win)
  render()
  animate()
end

function M.hide()
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  win, buf = nil, nil
  require('dreamcore.badges').set('claude', 0, nil)
  animate()
end

function M.set_state(state)
  -- You sent a message: Claude starts working and the clock starts.
  if state == 'start' then state, turn_start = 'working', vim.uv.hrtime() end
  if state == 'done' or state == 'idle' then turn_start = nil end
  -- Claude finished: if the panel is minimized (badge showing), that's a reply you haven't read.
  if state == 'done' then state = (win and vim.api.nvim_win_is_valid(win)) and 'unread' or 'idle' end
  M.state = state
  render()
  animate()
end

-- You opened the panel: its reply is read. (An approval still waiting keeps its "!".)
function M.seen()
  if M.state == 'unread' then M.set_state('idle') end
end

-- Called by Claude Code's hooks through `nvim --server $NVIM --remote-expr`.
_G.dream_agent_state = function(state)
  M.set_state(state)
  return 0
end

-- Settings passed to `claude --settings` so the panel's Claude reports what it's doing.
-- Hooks inherit $NVIM (the address of this Neovim) from the terminal Claude runs in.
function M.hook_settings()
  local function report(state)
    return ('[ -n "$NVIM" ] && %s --server "$NVIM" --remote-expr "v:lua.dream_agent_state(\'%s\')" >/dev/null 2>&1; true')
      :format(vim.fn.shellescape(vim.v.progpath), state)
  end
  local function hook(state, matcher)
    return { { matcher = matcher, hooks = { { type = 'command', command = report(state) } } } }
  end
  return vim.json.encode({ hooks = {
    UserPromptSubmit = hook('start'),
    PostToolUse = hook('working', '*'),            -- you approved and the tool ran: back to work
    Notification = hook('attention', 'permission_prompt'),
    Stop = hook('done'),
  } })
end

return M
