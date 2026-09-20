local M = { enabled = false, paused = false, samples = {}, status = 'OFF', views = {} }
local uv = vim.uv or vim.loop
local root = vim.fn.stdpath('config') .. '/native/audio'
local ns = vim.api.nvim_create_namespace('SystemAudioWaveform')
local blocks = { ' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }
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

function M.lines(samples, width, height)
  local rows = {}
  for row = 1, height do
    local cells = {}
    for col = 1, width do
      -- Nearest-sample resampling retains the zero intervals of negative cycles.
      local index = math.min(#samples, math.floor((col - 1) * #samples / width) + 1)
      local level = math.floor(M.rectify(samples[index]) * height * 8 + .5)
      local fill = math.max(0, math.min(8, level - (height - row) * 8))
      cells[col] = fill == 0 and row == height and '─' or blocks[fill + 1]
    end
    rows[row] = table.concat(cells)
  end
  return rows
end

local function highlight()
  vim.api.nvim_set_hl(0, 'SystemAudioWave', { fg = '#57d9f5', bg = '#050607' })
  vim.api.nvim_set_hl(0, 'SystemAudioLabel', { fg = '#627580', bg = '#050607' })
end

function M.render()
  if exiting then return end
  for tab, view in pairs(M.views) do
    if not vim.api.nvim_win_is_valid(view.win) or not vim.api.nvim_buf_is_valid(view.buf) then
      M.views[tab] = nil
    else
      local width, height = vim.api.nvim_win_get_width(view.win), vim.api.nvim_win_get_height(view.win)
      local lines = M.lines(M.samples, width, math.max(1, height - 1))
      local label = ' SYSTEM AUDIO · ' .. M.status
      if width > 75 then label = label .. '    SPACE U V  TOGGLE' end
      table.insert(lines, 1, vim.fn.strcharpart(label, 0, width))
      vim.bo[view.buf].modifiable = true
      vim.api.nvim_buf_set_lines(view.buf, 0, -1, false, lines)
      vim.bo[view.buf].modifiable = false
      vim.api.nvim_buf_clear_namespace(view.buf, ns, 0, -1)
      vim.api.nvim_buf_add_highlight(view.buf, ns, 'SystemAudioLabel', 0, 0, -1)
    end
  end
end

local function ensure_view()
  if not M.enabled or #vim.api.nvim_list_uis() == 0 or vim.o.lines < 16 then return end
  local tab = vim.api.nvim_get_current_tabpage()
  local view = M.views[tab]
  if view and vim.api.nvim_win_is_valid(view.win) then return end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].filetype = 'nofile', 'wipe', 'system_waveform'
  vim.bo[buf].swapfile = false
  local win = vim.api.nvim_open_win(buf, false, {
    split = 'below', win = -1, height = 4, focusable = false, style = 'minimal', noautocmd = true,
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
      M.samples = {}
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
        M.samples = {}
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
  M.views, M.samples, M.status = {}, {}, 'OFF'
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
