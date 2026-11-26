-- :Music [pause|unpause|next|prev|off|<spotify link>] — control the Spotify app, with a grey italic
-- "now playing" badge in the bottom right. Uses Spotify's own AppleScript interface, so the
-- music is played by the real Spotify app on your account.
local M = {}

-- Default playlist for :Music ("ANYTHING ELSE"). Any Spotify link or URI works.
local PLAYLIST = 'spotify:playlist:4wVWND3UOHdYMEB2CMhAAL'
-- Monaco has neither glyph; macOS terminals draw these from the emoji font. The pause sign
-- needs its emoji variation selector (U+FE0F) so Neovim and the terminal agree it's 2 columns.
local ICON = '🔊'
local PAUSE_ICON = '⏸\u{FE0F}'
local MAX_WIDTH = 48
local POLL_MS = 2000

local active = false -- :Music is on: poll Spotify and show the badge
local starting = false -- Spotify is launching: keep the "starting" badge up meanwhile
local poll_timer

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

-- The badge is a toast (dreamcore.toast) like study mode and :Update, so it fades in and
-- out the same way. Order 0 keeps it lowest; the others stack above it.
local function close_badge()
  require('dreamcore.toast').hide('music')
end

local function draw_badge(what, icon)
  local text = (icon or ICON) .. ' ' .. what
  if vim.fn.strdisplaywidth(text) > MAX_WIDTH - 2 then
    while vim.fn.strdisplaywidth(text) > MAX_WIDTH - 4 do text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1) end
    text = text .. '…'
  end
  require('dreamcore.toast').show(text, { id = 'music', color = '#8b949e', order = 0, timeout = false })
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
    local track = name and name ~= '' and ((artist and artist ~= '' and (artist .. ' – ') or '') .. name)
    if state == 'playing' and track then
      draw_badge(track)
    elseif state == 'paused' then
      draw_badge(track or 'paused', PAUSE_ICON) -- same song, pause sign instead of the speaker
    elseif not starting then
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

-- Bundle id of the app in front (the terminal Neovim runs in when you type :Music).
local function frontmost(cb)
  vim.system({ 'osascript', '-l', 'JavaScript', '-e',
    'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier.js' },
    { text = true }, function(res) vim.schedule(function() cb(vim.trim(res.stdout or '')) end) end)
end

-- Play in the background. Telling a closed Spotify to play launches it normally, which brings
-- its window to the front; instead launch it hidden (`open -g -j`), wait until it answers,
-- then play. If it grabs focus anyway, give focus back to the terminal.
local function play_uri(uri)
  starting = true
  draw_badge('starting Spotify…')
  start_polling()
  frontmost(function(home)
    local function give_back_focus()
      frontmost(function(now)
        if now == 'com.spotify.client' and home ~= '' and home ~= now then vim.system({ 'open', '-b', home }) end
      end)
    end
    local function play(retry)
      tell(('play track "%s"'):format(uri), function(_, code)
        if code ~= 0 then
          starting = false
          stop_polling()
          vim.notify('Music: could not start Spotify. Is it installed and logged in?', vim.log.levels.WARN)
          return
        end
        give_back_focus()
        -- A freshly launched Spotify sometimes ignores the first request: check, retry once.
        vim.defer_fn(function()
          tell('return player state as string', function(state)
            if state ~= 'playing' and retry then play(false) return end
            starting = false
            give_back_focus()
            poll()
          end)
        end, 1500)
      end)
    end
    osa('return application "Spotify" is running', function(running)
      if running == 'true' then play(true) return end
      vim.system({ 'open', '-g', '-j', '-a', 'Spotify' }) -- -g: don't bring to front, -j: launch hidden
      local tries = 0
      local function wait_ready()
        tries = tries + 1
        osa('if application "Spotify" is running then tell application "Spotify" to return player state as string',
          function(state)
            if state ~= '' or tries >= 30 then vim.defer_fn(function() play(true) end, 1500)
            else vim.defer_fn(wait_ready, 500) end
          end)
      end
      vim.defer_fn(wait_ready, 500)
    end)
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
  elseif arg == 'pause' then
    tell('pause', function() poll() end); start_polling()
  elseif arg == 'unpause' then
    tell('play', function() vim.defer_fn(poll, 300) end); start_polling()
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
    if uri then play_uri(uri) else vim.notify('Usage: :Music [pause|unpause|next|prev|off|<spotify link>]', vim.log.levels.WARN) end
  end
end

function M.setup()
  vim.api.nvim_create_user_command('Music', function(o) M.command(o.args) end, {
    nargs = '?',
    complete = function() return { 'pause', 'unpause', 'next', 'prev', 'off' } end,
    desc = 'Spotify: play playlist / toggle, pause, unpause, next, prev, off',
  })
  vim.cmd([[cnoreabbrev <expr> music getcmdtype() == ':' && getcmdline() ==# 'music' ? 'Music' : 'music']])
  -- :Next / :Prev skip tracks. Vim's built-in :Next (previous file in the arg list) can't be
  -- overridden by a user command, so a typed `:Next` is rewritten to `:Music next` instead.
  vim.api.nvim_create_user_command('Prev', function() M.command('prev') end, { desc = 'Spotify: previous track' })
  vim.api.nvim_create_user_command('Pause', function() M.command('pause') end, { desc = 'Spotify: pause' })
  vim.api.nvim_create_user_command('Unpause', function() M.command('unpause') end, { desc = 'Spotify: resume' })
  vim.cmd([[cnoreabbrev <expr> Next getcmdtype() == ':' && getcmdline() ==# 'Next' ? 'Music next' : 'Next']])
  vim.api.nvim_create_autocmd('VimResized', { callback = poll })
  -- Quitting Neovim leaves Spotify playing; it's its own app. :Music off pauses it.
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = stop_polling })
end

return M
