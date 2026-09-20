local M = { enabled = false, paused = false, samples = {}, levels = {}, status = 'OFF', views = {} }
local uv = vim.uv or vim.loop
local root = vim.fn.stdpath('config') .. '/native/audio'
local ns = vim.api.nvim_create_namespace('SystemAudioWaveform')
-- One thin braille column, filled bottom-up in quarter-cell increments.
-- This keeps fractional tips attached to the baseline instead of stacking pipes.
local strokes = { ' ', '⡀', '⡄', '⡆', '⡇' }
local last_frame = 0
local stale_timer
local stderr = ''
local pending = ''
local exiting = false

-- Positive half-wave rectification, never absolute-value/full-wave rectification.
function M.rectify(value)
  if type(value) ~= 'number' or value ~= value then return 0 end
  return math.min(1, math.max(0, value * (vim.g.system_audio_gain or 2.5)))
end

-- Follow positive peaks promptly while allowing a short, smooth release.
-- Rectify before averaging: negative samples never become positive energy.
function M.smooth(samples, dt)
  local levels, bins = {}, 64
  dt = math.max(.005, math.min(.2, dt or .04))
  for bin = 1, bins do
    local first = math.floor((bin - 1) * #samples / bins) + 1
    local last = math.min(#samples, math.max(first, math.floor(bin * #samples / bins)))
    local peak = 0
    for i = first, last do
      local value = M.rectify(samples[i])
      peak = math.max(peak, value)
    end
    local target = peak
    local previous = M.levels[bin] or 0
    local tau = target > previous and .08 or .28
    local value = previous + (target - previous) * (1 - math.exp(-dt / tau))
    levels[bin] = value < .004 and target == 0 and 0 or value
  end
  M.levels = levels
end

function M.lines(levels, width, height)
  local rows = {}
  local bars = math.max(1, math.floor(width / 3))
  local offset = math.floor((width - (bars * 3 - 2)) / 2)
  for row = 1, height do
    local cells = {}
    for col = 1, width do cells[col] = ' ' end
    for bar = 1, bars do
      local index = math.min(#levels, math.floor((bar - 1) * #levels / bars) + 1)
      local value = math.max(0, math.min(1, levels[index] or 0))
      local level = value > .025 and math.floor(value * height * 4 + .5) or 0
      local fill = math.max(0, math.min(4, level - (height - row) * 4))
      cells[offset + (bar - 1) * 3 + 1] = fill > 0 and strokes[fill + 1] or row == height and '⡀' or ' '
    end
    rows[row] = table.concat(cells)
  end
  return rows
end

local function highlight()
  vim.api.nvim_set_hl(0, 'SystemAudioWave', { fg = '#5299a8', bg = '#050607' })
  vim.api.nvim_set_hl(0, 'SystemAudioLabel', { fg = '#627580', bg = '#050607' })
end

function M.render()
  if exiting then return end
  for tab, view in pairs(M.views) do
    if not vim.api.nvim_win_is_valid(view.win) or not vim.api.nvim_buf_is_valid(view.buf) then
      M.views[tab] = nil
    else
      local width, height = vim.api.nvim_win_get_width(view.win), vim.api.nvim_win_get_height(view.win)
      local keyboard = require('dreamcore.keyboard')
      local lines = keyboard.blank(width)
      local keyboard_height = #lines
      local wave = M.lines(M.levels, width, math.max(1, height - keyboard_height - 1))
      local label = ' SYSTEM AUDIO · ' .. M.status
      if width > 75 then label = label .. '    SPACE U V  TOGGLE' end
      lines[#lines + 1] = vim.fn.strcharpart(label, 0, width)
      vim.list_extend(lines, wave)
      vim.bo[view.buf].modifiable = true
      vim.api.nvim_buf_set_lines(view.buf, 0, -1, false, lines)
      vim.bo[view.buf].modifiable = false
      vim.api.nvim_buf_clear_namespace(view.buf, ns, 0, -1)
      vim.api.nvim_buf_add_highlight(view.buf, ns, 'SystemAudioLabel', keyboard_height, 0, -1)
      keyboard.draw(view.buf, width)
    end
  end
end

local function ensure_view()
  if not M.enabled or #vim.api.nvim_list_uis() == 0 or vim.o.lines < 16 then return end
  local tab = vim.api.nvim_get_current_tabpage()
  local view = M.views[tab]
  local _, keyboard_height = require('dreamcore.keyboard').layout(vim.o.columns)
  local desired_height = keyboard_height + 4
  if view and vim.api.nvim_win_is_valid(view.win) then
    vim.api.nvim_win_set_height(view.win, desired_height)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].filetype = 'nofile', 'wipe', 'system_waveform'
  vim.bo[buf].swapfile = false
  local win = vim.api.nvim_open_win(buf, false, {
    split = 'below', win = -1, height = desired_height, focusable = false, style = 'minimal', noautocmd = true,
  })
  M.views[tab] = { win = win, buf = buf }
  vim.wo[win].winfixheight = true
  vim.wo[win].winfixbuf = true
  vim.wo[win].winbar = ''
  vim.wo[win].statuscolumn = ''
  vim.wo[win].winhighlight = 'Normal:SystemAudioWave,NormalNC:SystemAudioWave,EndOfBuffer:SystemAudioWave'
  M.render()
end

function M.consume(frame)
  if not M.enabled or M.paused or type(frame.samples) ~= 'table' then return end
  M.samples = frame.samples
  local now = uv.now()
  M.smooth(frame.samples, last_frame > 0 and (now - last_frame) / 1000 or .04)
  M.status = frame.status == 'live' and 'LIVE' or 'WAITING FOR AUDIO'
  last_frame = uv.now()
  M.render()
end

local function stop_job()
  if M.job then
    local job = M.job
    M.job = nil
    vim.fn.jobstop(job)
  end
  if stale_timer then stale_timer:stop(); stale_timer:close(); stale_timer = nil end
end

local function capture()
  if not M.enabled or M.paused or M.job then return end
  local executable = root .. '/build/system-waveform'
  if vim.fn.executable(executable) ~= 1 then
    M.status = 'BUILD NEEDED · :AudioBuild'
    M.render()
    return
  end
  pending, stderr = '', ''
  M.status = 'CONNECTING'
  last_frame = uv.now()
  local job
  job = vim.fn.jobstart({ executable }, {
    on_stdout = function(_, data)
      if M.job ~= job then return end
      pending = pending .. table.concat(data, '\n')
      local frames = vim.split(pending, '\n', { plain = true })
      pending = table.remove(frames) or ''
      -- Display only the newest complete frame if Neovim was busy.
      for i = #frames, 1, -1 do
        local ok, frame = pcall(vim.json.decode, frames[i])
        if ok and type(frame) == 'table' then M.consume(frame); break end
      end
    end,
    on_stderr = function(_, data)
      if M.job == job then stderr = (stderr .. table.concat(data, '\n')):sub(-2000) end
    end,
    on_exit = function(_, code)
      if M.job ~= job then return end
      M.job = nil
      stop_job()
      M.samples, M.levels = {}, {}
      M.status = code == 0 and 'STOPPED · :AudioStart' or 'CHECK AUDIO ACCESS · :AudioStart'
      M.render()
      if code ~= 0 then
        vim.notify(stderr ~= '' and stderr or 'System audio unavailable. Allow audio capture in macOS Privacy & Security, then :AudioStart.', vim.log.levels.WARN, { title = 'System waveform' })
      end
    end,
  })
  if job <= 0 then
    M.status = 'COULD NOT START AUDIO'
  else
    M.job = job
    stale_timer = assert(uv.new_timer())
    stale_timer:start(500, 500, vim.schedule_wrap(function()
      if M.job and uv.now() - last_frame > 1000 then
        M.samples, M.levels = {}, {}
        M.status = 'WAITING FOR AUDIO ACCESS'
        M.render()
      end
    end))
  end
  M.render()
end

function M.start()
  if vim.fn.has('mac') ~= 1 then vim.notify('System waveform currently supports macOS.'); return end
  M.enabled = true
  M.paused = not require('dreamcore.motion').enabled
  ensure_view()
  if M.paused then M.status = 'PAUSED'; M.render() else capture() end
end

function M.stop()
  M.enabled = false
  stop_job()
  for _, view in pairs(M.views) do
    if vim.api.nvim_win_is_valid(view.win) then pcall(vim.api.nvim_win_close, view.win, true) end
  end
  M.views, M.samples, M.levels, M.status = {}, {}, {}, 'OFF'
end

function M.pause(paused)
  M.paused = paused
  if not M.enabled then return end
  if paused then stop_job(); M.status = 'PAUSED'; M.render() else capture() end
end

function M.toggle()
  if M.enabled then M.stop() else M.start() end
end

function M.setup()
  require('dreamcore.keyboard').setup()
  highlight()
  local group = vim.api.nvim_create_augroup('SystemWaveform', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlight })
  vim.api.nvim_create_autocmd({ 'TabEnter', 'VimResized' }, { group = group, callback = function()
    vim.schedule(function() if not exiting then ensure_view(); M.render() end end)
  end })
  vim.api.nvim_create_autocmd('QuitPre', { group = group, callback = function()
    local view = M.views[vim.api.nvim_get_current_tabpage()]
    if not view or not vim.api.nvim_win_is_valid(view.win) then return end
    local normal = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative == '' then normal = normal + 1 end
    end
    if normal == 2 and vim.api.nvim_get_current_win() ~= view.win then
      vim.api.nvim_win_close(view.win, true)
      M.views[vim.api.nvim_get_current_tabpage()] = nil
    end
  end })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() exiting = true; stop_job() end })
  vim.api.nvim_create_autocmd('UIEnter', { group = group, callback = function()
    if vim.g.system_audio_autostart ~= false then vim.schedule(M.start) end
  end })
  vim.api.nvim_create_user_command('AudioStart', function() stop_job(); M.start() end, {})
  vim.api.nvim_create_user_command('AudioStop', M.stop, {})
  vim.api.nvim_create_user_command('AudioToggle', M.toggle, {})
  vim.api.nvim_create_user_command('AudioBuild', function()
    vim.system({ 'sh', root .. '/build.sh' }, { text = true }, vim.schedule_wrap(function(result)
      if result.code == 0 then M.start() else vim.notify(result.stderr, vim.log.levels.ERROR) end
    end))
  end, {})
  vim.keymap.set('n', '<leader>uv', M.toggle, { desc = 'Toggle system audio waveform' })
  if #vim.api.nvim_list_uis() > 0 and vim.g.system_audio_autostart ~= false then vim.schedule(M.start) end
end
return M
