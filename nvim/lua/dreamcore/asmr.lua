-- :ASMR [1-5|off] — mechanical keyboard sounds on every keypress.
local M = {}
local NAMES = { 'NK Cream', 'Box Navy', 'Holy Panda', 'buckling spring', 'Topre' }
local dir = vim.fn.stdpath('config') .. '/sounds/asmr/'
local ns = vim.api.nvim_create_namespace('asmr')
local profile        -- nil = off
local last, playing = 0, 0

local SPECIAL = {
  [' '] = 'space',
  [vim.keycode('<CR>')] = 'enter',
  [vim.keycode('<NL>')] = 'enter',
  [vim.keycode('<BS>')] = 'backspace',
  [vim.keycode('<Del>')] = 'backspace',
}

-- macOS: one long-running player with every clip preloaded (scripts/asmr_player.js).
-- afplay-per-key lives ~1 s each, so fast typing piled up processes and dropped sounds.
local mac_script = vim.fn.stdpath('config') .. '/scripts/asmr_player.js'
local mac = vim.fn.has('mac') == 1 and vim.fn.executable('osascript') == 1
local job

local function start_job()
  if job then return end
  job = vim.fn.jobstart({ 'osascript', '-l', 'JavaScript', mac_script }, {
    on_exit = function() job = nil end,
  })
  if job <= 0 then job = nil end
end

local function stop_job()
  if job then vim.fn.jobstop(job); job = nil end
end

-- Linux fallback: one short-lived process per key.
local function spawn_cmd(file)
  if vim.fn.executable('paplay') == 1 then return { 'paplay', file } end   -- PulseAudio / PipeWire
  if vim.fn.executable('aplay') == 1 then return { 'aplay', '-q', file } end -- ALSA
end

local function available()
  return mac or spawn_cmd('') ~= nil
end

local function play(kind)
  -- Throttle so key-repeat doesn't machine-gun sounds.
  local now = vim.uv.now()
  if now - last < 12 then return end
  last = now
  local file = dir .. profile .. '/' .. (kind == 'key' and ('key' .. math.random(5)) or kind) .. '.wav'
  if mac then
    start_job()
    if job then pcall(vim.fn.chansend, job, file .. '\n') end
    return
  end
  local cmd = spawn_cmd(file)
  if not cmd or playing >= 12 then return end
  playing = playing + 1
  vim.system(cmd, { stdout = false, stderr = false }, function() playing = playing - 1 end)
end

local function on_key(_, typed)
  if not profile or not typed or typed == '' then return end -- typed = real keystrokes only, not mappings
  local kind = SPECIAL[typed]
  if not kind then
    local name = vim.fn.keytrans(typed)
    -- Skip mouse, scroll, focus and other non-keyboard events.
    if name:find('Mouse') or name:find('Scroll') or name:find('Drag') or name:find('Release')
      or name:find('Focus') or name:find('Ignore') or name:find('Paste') or name:find('Cursor') then
      return
    end
    kind = 'key'
  end
  play(kind)
end

function M.set(arg)
  arg = vim.trim(arg or '')
  if arg == 'off' or arg == '0' then
    profile = nil
    stop_job()
    vim.notify('ASMR off')
    return
  end
  local n = arg == '' and 1 or tonumber(arg)
  if not n or n % 1 ~= 0 or n < 1 or n > 5 then
    vim.notify('Usage: :ASMR [1-5|off]', vim.log.levels.WARN)
    return
  end
  if not available() then
    vim.notify('No audio player found (need macOS, paplay or aplay).', vim.log.levels.WARN)
    return
  end
  profile = n
  if mac then start_job() end -- warm up so the first key isn't delayed
  vim.notify(('ASMR %d · %s  (:ASMR off to stop)'):format(n, NAMES[n]))
end

function M.setup()
  vim.on_key(on_key, ns)
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = stop_job })
  vim.api.nvim_create_user_command('ASMR', function(o) M.set(o.args) end, {
    nargs = '?',
    complete = function() return { '1', '2', '3', '4', '5', 'off' } end,
    desc = 'Keyboard sounds: 1 Cream, 2 Box Navy, 3 Holy Panda, 4 buckling spring, 5 Topre',
  })
  vim.cmd([[cnoreabbrev <expr> asmr getcmdtype() == ':' && getcmdline() ==# 'asmr' ? 'ASMR' : 'asmr']])
end

return M
