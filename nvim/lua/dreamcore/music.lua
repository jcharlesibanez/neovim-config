-- :Music [next|prev|off|<spotify link>] — control the Spotify app, with a grey italic
-- "now playing" badge in the bottom right. Uses Spotify's own AppleScript interface, so the
-- music is played by the real Spotify app on your account.
local M = {}

-- Default playlist for :Music ("ANYTHING ELSE"). Any Spotify link or URI works.
local PLAYLIST = 'spotify:playlist:4wVWND3UOHdYMEB2CMhAAL'
local ICON = '🔊' -- Monaco has no speaker glyph; macOS terminals draw this from the emoji font
local MAX_WIDTH = 48
local POLL_MS = 2000

local active = false -- :Music is on: poll Spotify and show the badge
local badge_win, poll_timer, last_text

-- ── Spotify ────────────────────────────────────────────────────────────────

local function osa(script, cb)
  vim.system({ 'osascript', '-e', script }, { text = true }, function(res)
    if cb then vim.schedule(function() cb(vim.trim(res.stdout or ''), res.code) end) end
  end)
end

local function tell(cmd, cb) osa('tell application "Spotify" to ' .. cmd, cb) end

-- https://open.spotify.com/playlist/ID?si=… → spotify:playlist:ID (URIs pass through).
local function to_uri(link)
  if link:match('^spotify:%a+:%w+$') then return link end
  local path = link:match('open%.spotify%.com/([^?#]+)')
  local kind, id = (path or ''):match('(%a+)/(%w+)/?$') -- last two parts (handles /intl-xx/ prefixes)
  return kind and ('spotify:%s:%s'):format(kind, id) or nil
end

-- ── Badge ──────────────────────────────────────────────────────────────────

local function close_badge()
  if badge_win and vim.api.nvim_win_is_valid(badge_win) then vim.api.nvim_win_close(badge_win, true) end
  badge_win, last_text = nil, nil
end

local function draw_badge(what)
  local text = ' ' .. ICON .. ' ' .. what .. ' '
  if vim.fn.strdisplaywidth(text) > MAX_WIDTH then
    while vim.fn.strdisplaywidth(text) > MAX_WIDTH - 2 do text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1) end
    text = text .. '… '
  end
  local width = vim.fn.strdisplaywidth(text)
  local cfg = {
    relative = 'editor',
    -- Bottom right, on the last editor line: above the statusline and command line.
    row = math.max(0, vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - 1),
    col = math.max(0, vim.o.columns - width - 1),
    width = width, height = 1, style = 'minimal', focusable = false, zindex = 150,
  }
  if badge_win and vim.api.nvim_win_is_valid(badge_win) then
    if text ~= last_text then vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(badge_win), 0, -1, false, { text }) end
    vim.api.nvim_win_set_config(badge_win, cfg)
  else
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    cfg.noautocmd = true
    badge_win = vim.api.nvim_open_win(buf, false, cfg)
    vim.wo[badge_win].winhl = 'Normal:BadgeDim,NormalFloat:BadgeDim'
  end
  last_text = text
end

-- Ask Spotify what's playing (without launching it) and update the badge.
local STATUS = [[
if application "Spotify" is running then
  tell application "Spotify"
    set s to player state as string
    if s is "stopped" then return "stopped"
    return s & linefeed & (name of current track) & linefeed & (artist of current track)
  end tell
else
  return "closed"
end if]]

local function poll()
  if not active then return end
  osa(STATUS, function(out)
    if not active then return end
    local state, name, artist = unpack(vim.split(out, '\n'))
    if state == 'playing' and name and name ~= '' then
      draw_badge((artist and artist ~= '' and (artist .. ' – ') or '') .. name)
    elseif state == 'paused' then
      draw_badge('paused')
    else
      close_badge()
    end
  end)
end

local function start_polling()
  active = true
  if not poll_timer then
    poll_timer = vim.uv.new_timer()
    poll_timer:start(0, POLL_MS, vim.schedule_wrap(poll))
  end
end

local function stop_polling()
  active = false
  if poll_timer then poll_timer:stop(); poll_timer:close(); poll_timer = nil end
  close_badge()
end

-- ── Commands ───────────────────────────────────────────────────────────────

local function play_uri(uri)
  draw_badge('starting Spotify…')
  start_polling()
  tell(('play track "%s"'):format(uri), function(_, code)
    if code ~= 0 then
      stop_polling()
      vim.notify('Music: could not start Spotify. Is it installed and logged in?', vim.log.levels.WARN)
    end
    vim.defer_fn(poll, 800)
  end)
end

function M.command(arg)
  arg = vim.trim(arg or '')
  if vim.fn.has('mac') == 0 then
    vim.notify('Music needs macOS (it controls the Spotify app).', vim.log.levels.WARN)
    return
  end
  if arg == 'off' or (arg == '' and active) then
    tell('pause'); stop_polling()
  elseif arg == 'next' then
    tell('next track', function() vim.defer_fn(poll, 400) end); start_polling()
  elseif arg == 'prev' then
    tell('previous track', function() vim.defer_fn(poll, 400) end); start_polling()
  elseif arg == '' then
    local uri = vim.g.music_playlist or PLAYLIST
    if uri then play_uri(uri) else
      vim.notify('Music: no playlist set yet. Use :Music <spotify playlist link>.', vim.log.levels.WARN)
    end
  else
    local uri = to_uri(arg)
    if uri then play_uri(uri) else vim.notify('Usage: :Music [next|prev|off|<spotify link>]', vim.log.levels.WARN) end
  end
end

function M.setup()
  vim.api.nvim_create_user_command('Music', function(o) M.command(o.args) end, {
    nargs = '?',
    complete = function() return { 'next', 'prev', 'off' } end,
    desc = 'Spotify: play playlist / toggle, next, prev, off',
  })
  vim.cmd([[cnoreabbrev <expr> music getcmdtype() == ':' && getcmdline() ==# 'music' ? 'Music' : 'music']])
  vim.api.nvim_create_autocmd('VimResized', { callback = poll })
  -- Quitting Neovim leaves Spotify playing; it's its own app. :Music off pauses it.
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = stop_polling })
end

return M
