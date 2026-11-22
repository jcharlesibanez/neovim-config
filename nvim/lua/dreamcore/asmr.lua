-- :ASMR [1-5|off] — mechanical keyboard sounds on every keypress.
local M = {}
local NAMES = { 'thock', 'clicky', 'tactile', 'typewriter', 'marble' }
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

local function player(file)
  if vim.fn.executable('afplay') == 1 then return { 'afplay', '-v', '0.7', file } end -- macOS
  if vim.fn.executable('paplay') == 1 then return { 'paplay', file } end            -- PulseAudio / PipeWire
  if vim.fn.executable('aplay') == 1 then return { 'aplay', '-q', file } end         -- ALSA
end

local function play(kind)
  -- Throttle so key-repeat or a burst of input doesn't spawn dozens of players.
  local now = vim.uv.now()
  if now - last < 18 or playing >= 6 then return end
  last = now
  local file = dir .. profile .. '/' .. (kind == 'key' and ('key' .. math.random(4)) or kind) .. '.wav'
  local cmd = player(file)
  if not cmd then return end
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
    vim.notify('ASMR off')
    return
  end
  local n = arg == '' and 1 or tonumber(arg)
  if not n or n % 1 ~= 0 or n < 1 or n > 5 then
    vim.notify('Usage: :ASMR [1-5|off]', vim.log.levels.WARN)
    return
  end
  if not player('') then
    vim.notify('No audio player found (need afplay, paplay or aplay).', vim.log.levels.WARN)
    return
  end
  profile = n
  vim.notify(('ASMR %d · %s  (:ASMR off to stop)'):format(n, NAMES[n]))
end

function M.setup()
  vim.on_key(on_key, ns)
  vim.api.nvim_create_user_command('ASMR', function(o) M.set(o.args) end, {
    nargs = '?',
    complete = function() return { '1', '2', '3', '4', '5', 'off' } end,
    desc = 'Mechanical keyboard sounds: 1 thock, 2 clicky, 3 tactile, 4 typewriter, 5 marble',
  })
  vim.cmd([[cnoreabbrev <expr> asmr getcmdtype() == ':' && getcmdline() ==# 'asmr' ? 'ASMR' : 'asmr']])
end

return M
