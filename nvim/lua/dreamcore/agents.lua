-- AI agent panels: Claude Code (<leader>cc) and Codex (<leader>co).
--
-- Each runs in a panel on the right (a red line on its left, its name on top) and goes
-- off → open → minimized → open … with its key. Only one panel shows at a time: opening one
-- minimizes the other, so the one you opened last is the one in front. Minimized agents keep
-- running and show a badge in the top right (Claude's crab on top, Codex's logo below). So does
-- an agent you started yourself in the <leader>t shell while that shell is closed. Status hooks
-- (dreamcore/agenthooks.lua) tell the badges what each agent is doing.
--
-- While you're in a panel, stray clicks elsewhere snap back to it; Ctrl+L / Ctrl+1–9 leave on
-- purpose. Click in it to type. Drag its red line to resize it.
local M = {}

local agents = {}   -- in the order they were defined
local cols = nil    -- panel width you dragged to (shared by both); nil = 42% of the screen
local locked = true -- in the panel: stray clicks elsewhere snap back to it

local function width()
  local c = cols or math.floor(vim.o.columns * 0.42)
  return math.max(30, math.min(c, vim.o.columns - 20))
end

local function window(a)
  local w = a.term and a.term.window
  return w and vim.api.nvim_win_is_valid(w) and w or nil
end

-- The agent whose panel is open (at most one), and its window.
function M.active()
  for _, a in ipairs(agents) do if a.state == 'active' then return a end end
end
function M.active_win()
  local a = M.active()
  return a and window(a)
end

-- Agents started yourself in the <leader>t shell (known from their hooks), by id.
local in_shell = {}

local function shell_open()
  local t = require('toggleterm.terminal').get(1)
  return t ~= nil and t:is_open()
end

-- Show each agent's badge while it's running out of sight: panel minimized, or running in the
-- shell while the shell is closed.
function M.refresh()
  for _, a in ipairs(agents) do
    local want = a.state == 'minimized' or (in_shell[a.id] and a.state ~= 'active' and not shell_open())
    if want then a.badge.show() else a.badge.hide() end
  end
end

-- Called by the agents' hooks: dream_agent_state(state, agent id, 'panel' | 'shell').
function M.report(state, id, source)
  local a
  for _, x in ipairs(agents) do if x.id == id then a = x end end
  if not a then return end
  if source == 'shell' then
    if state == 'ended' then in_shell[id] = nil else in_shell[id] = true end
  end
  if state == 'ended' then
    -- The session closed: nothing left to show for it (unless a panel session is still going).
    if not (source == 'shell' and a.state ~= 'off') then a.badge.set_state('idle') end
  elseif state ~= 'session' then
    a.badge.set_state(state)
  end
  M.refresh()
end
_G.dream_agent_state = function(state, id, source)
  M.report(state, id or 'claude', source or 'panel')
  return 0
end

local function minimize(a)
  a.state = 'minimized'
  a.closing = true
  a.term:toggle() -- closes the window, keeps the process
  a.closing = false
  M.refresh()
end

local function start(a)
  a.term = require('toggleterm.terminal').Terminal:new({
    count        = a.count, -- its own terminal number, so it never takes your shell's (1)
    cmd          = a.bin,
    env          = { DREAM_AGENT_SOURCE = 'panel' }, -- its hooks report from the panel, not the shell
    dir          = vim.fn.getcwd(),
    direction    = 'float',
    float_opts   = {
      -- Only a red line on the left (like the explorer's edge) and the title on top.
      -- Order: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left.
      border    = { '│', ' ', '', '', '', '', '', '│' },
      title_pos = 'center',
      width     = width,
      height    = function() return vim.o.lines - 2 end,
      row       = 0,
      col       = function() return vim.o.columns - width() - 1 end,
      winblend  = 0,
    },
    hidden       = true,
    display_name = ' ' .. a.title .. ' ',
    -- Red line like every other float (toggleterm's default is the plain text color).
    highlights   = { NormalFloat = { link = 'Normal' }, FloatBorder = { link = 'FloatBorder' } },
    on_exit = function()
      a.term, a.state = nil, 'off'
      a.badge.set_state('idle')
      M.refresh()
    end,
    on_open = function(t)
      -- Ctrl+L hops on to the next window, as it does everywhere else.
      vim.keymap.set('t', '<C-l>', function() require('dreamcore.windows').next() end, { buffer = t.bufnr })
    end,
  })
  -- toggleterm closes a floating terminal as soon as you leave it. Keep the panel open while
  -- you work in other windows; it closes only when minimized or when the agent exits.
  local close = a.term.close
  a.term.close = function(self, ...)
    local exited = not self.job_id or vim.fn.jobwait({ self.job_id }, 0)[1] ~= -1
    if a.closing or exited then return close(self, ...) end
  end
  a.term:open()
end

function M.toggle(a)
  if a.state == 'active' then return minimize(a) end
  if vim.fn.executable(a.bin) == 0 then
    vim.notify(('%s isn\'t installed. Install it with: %s'):format(a.title, a.install), vim.log.levels.WARN)
    return
  end
  local other = M.active()
  if other then minimize(other) end -- one panel at a time: the one you opened goes in front
  if a.state == 'off' then
    start(a)
  else
    a.badge.seen()
    a.term:toggle() -- reopens the window
  end
  a.state, locked = 'active', true
  M.refresh()
  vim.schedule(function() -- in the composer, ready to type
    if window(a) and window(a) == vim.api.nvim_get_current_win() then vim.cmd.startinsert() end
  end)
end

function M.define(a)
  a.state = 'off'
  table.insert(agents, a)
  vim.keymap.set('n', a.key, function() M.toggle(a) end, { desc = 'Toggle ' .. a.title })
  return a
end

-- Focus, clicks and dragging, shared by both panels.
local function setup_window_handling()
  -- Window numbers (Ctrl+1 … Ctrl+9, Ctrl+L) count the open panel too.
  local windows = require('dreamcore.windows')
  windows.agent_win = M.active_win
  windows.on_jump = function(from) if from == M.active_win() then locked = false end end
  windows.setup()

  -- While you're in the panel, clicking elsewhere snaps focus back to it (unless you left on
  -- purpose). Only ordinary windows snap back: a terminal, picker or popup you open stays.
  vim.api.nvim_create_autocmd('WinEnter', {
    callback = function()
      local win = M.active_win()
      if not win then return end
      local cur = vim.api.nvim_get_current_win()
      if cur == win then locked = true return end
      if not locked or vim.api.nvim_win_get_config(cur).relative ~= '' then return end
      vim.schedule(function()
        if M.active_win() == win then
          vim.api.nvim_set_current_win(win)
          vim.cmd.startinsert()
        end
      end)
    end,
  })

  -- Drag the panel's red line with the mouse to resize it (Neovim can't drag-resize floats).
  -- A plain click that ends up in the panel lands in the composer, ready to type; dragging
  -- inside still selects text to copy.
  local dragging, moved = false, false
  local function on_line()
    local win = M.active_win()
    if not win then return false end
    local cfg = vim.api.nvim_win_get_config(win)
    local col = type(cfg.col) == 'table' and cfg.col[false] or cfg.col
    return vim.fn.getmousepos().screencol - 1 == col
  end
  local function mouse(key, fn)
    vim.keymap.set({ 'n', 'i', 't' }, key, function()
      if fn() then return '' end
      return key
    end, { expr = true, desc = 'Drag the agent panel edge to resize it' })
  end
  mouse('<LeftMouse>', function()
    dragging, moved = on_line(), false
    return dragging
  end)
  mouse('<LeftDrag>', function()
    moved = true
    if not dragging then return false end
    cols = vim.o.columns - vim.fn.getmousepos().screencol
    vim.schedule(function() -- can't change windows from inside a mapping's expression
      local win = M.active_win()
      if not win then return end
      vim.api.nvim_win_set_config(win, { relative = 'editor', row = 0, col = vim.o.columns - width() - 1,
                                         width = width(), height = vim.o.lines - 2 })
    end)
    return true
  end)
  mouse('<LeftRelease>', function()
    local was = dragging
    dragging = false
    local win = M.active_win()
    -- A stray click elsewhere already snapped back to the composer: ignore its release, which
    -- would otherwise land outside the terminal and knock it out of typing mode.
    if not was and win and vim.api.nvim_get_current_win() == win and vim.api.nvim_get_mode().mode == 't'
      and vim.fn.getmousepos().winid ~= win then
      return true
    end
    if not was and not moved then
      vim.schedule(function()
        local w = M.active_win()
        if w and vim.api.nvim_get_current_win() == w and vim.api.nvim_get_mode().mode:sub(1, 1) == 'n' then
          locked = true
          vim.cmd.startinsert()
        end
      end)
    end
    return was
  end)
end

function M.setup()
  M.define({
    id = 'claude', title = 'Claude Code', key = '<leader>cc', count = 99, bin = 'claude',
    install = 'curl -fsSL https://claude.ai/install.sh | bash',
    badge = require('dreamcore.agentbadge'),
  })
  M.define({
    id = 'codex', title = 'Codex', key = '<leader>co', count = 98, bin = 'codex',
    install = vim.fn.has('mac') == 1 and 'brew install --cask codex' or 'npm install -g @openai/codex',
    badge = require('dreamcore.codexbadge'),
  })
  setup_window_handling()
  require('dreamcore.agenthooks').install()
  -- Opening or closing the <leader>t shell can show or hide a badge for an agent running in it;
  -- opening it counts as looking at that agent's reply.
  vim.api.nvim_create_autocmd({ 'WinNew', 'WinClosed', 'BufWinEnter' }, {
    callback = function()
      vim.schedule(function()
        if shell_open() then
          for _, a in ipairs(agents) do if in_shell[a.id] then a.badge.seen() end end
        end
        M.refresh()
      end)
    end,
  })
end

return M
