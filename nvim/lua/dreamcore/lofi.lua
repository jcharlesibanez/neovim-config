-- :Lofi [next|off] — stream lofi radio, with a grey italic "now playing" badge bottom right.
local M = {}

-- Public lofi internet radio streams (found via radio-browser.info). If one fails,
-- the next is tried automatically. `titles` = the stream reports the current song.
local STATIONS = {
  { name = 'laut.fm lofi', url = 'https://stream.laut.fm/lofi', titles = true },
  { name = 'I Love Chillhop', url = 'https://ilm.stream18.radiohost.de/ilm_ilovechillhop_mp3-192', titles = true },
  { name = 'LITT Live Lofi', url = 'https://das-sa39.cdnstream1.com/5582_128', titles = true },
  { name = 'REYFM #lofi', url = 'https://listen.reyfm.de/lofi_128kbps.mp3' },
  { name = '0nlineradio Lo-Fi', url = 'https://stream.0nlineradio.com/lo-fi' },
}
local VOLUME = 0.5
local ICON = '🔊' -- Monaco has no speaker glyph; macOS terminals draw this from the emoji font
local MAX_WIDTH = 48

local script = vim.fn.stdpath('config') .. '/scripts/lofi_player.js'
local job, station, attempts, title, title_timer, badge_win
local status = 'off' -- 'off' | 'tuning' | 'playing'

-- ── Badge ──────────────────────────────────────────────────────────────────

local function close_badge()
  if badge_win and vim.api.nvim_win_is_valid(badge_win) then vim.api.nvim_win_close(badge_win, true) end
  badge_win = nil
end

local function badge_text()
  local s = STATIONS[station]
  local what = status == 'tuning' and 'tuning in…' or (title or s.name)
  local text = ' ' .. ICON .. ' lofi · ' .. what .. ' '
  if vim.fn.strdisplaywidth(text) > MAX_WIDTH then
    while vim.fn.strdisplaywidth(text) > MAX_WIDTH - 2 do text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1) end
    text = text .. '… '
  end
  return text
end

local function draw_badge()
  if status == 'off' then close_badge(); return end
  local text = badge_text()
  local width = vim.fn.strdisplaywidth(text)
  local buf = badge_win and vim.api.nvim_win_is_valid(badge_win) and vim.api.nvim_win_get_buf(badge_win)
  if not buf then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  local cfg = {
    relative = 'editor',
    -- Bottom right, on the last editor line: above the statusline and command line.
    row = math.max(0, vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0) - 1),
    col = math.max(0, vim.o.columns - width - 1),
    width = width, height = 1,
    style = 'minimal', focusable = false, zindex = 150,
  }
  if badge_win and vim.api.nvim_win_is_valid(badge_win) then
    vim.api.nvim_win_set_config(badge_win, cfg)
  else
    cfg.noautocmd = true
    badge_win = vim.api.nvim_open_win(buf, false, cfg)
    vim.wo[badge_win].winhl = 'Normal:LofiBadge,NormalFloat:LofiBadge'
  end
end

-- ── Song titles ────────────────────────────────────────────────────────────

-- Internet radio embeds the song title in the audio itself (ICY metadata): after
-- `icy-metaint` bytes of audio comes one length byte (×16) and "StreamTitle='…';".
local function parse_title(data)
  local body = data
  while true do -- skip redirect responses: keep only the final header block
    local e = body:find('\r\n\r\n', 1, true)
    if not e then return nil end
    local header, rest = body:sub(1, e), body:sub(e + 4)
    if rest:sub(1, 5) ~= 'HTTP/' then
      local metaint = tonumber(header:lower():match('icy%-metaint:%s*(%d+)'))
      if not metaint or #rest <= metaint then return nil end
      local len = rest:byte(metaint + 1) * 16
      local meta = rest:sub(metaint + 2, metaint + 1 + len)
      local t = meta:match("StreamTitle='(.-)';")
      t = t and vim.trim(t)
      return t ~= '' and t or nil
    end
    body = rest
  end
end

local function fetch_title()
  local s = STATIONS[station]
  if status ~= 'playing' or not s.titles then return end
  local want = station
  vim.system({ 'sh', '-c', 'curl -sL -m 8 -H "Icy-MetaData: 1" -D - "$0" | head -c 70000', s.url }, {}, function(res)
    local t = res.stdout and parse_title(res.stdout)
    vim.schedule(function()
      if station == want and status == 'playing' then title = t; draw_badge() end
    end)
  end)
end

local function stop_title_timer()
  if title_timer then title_timer:stop(); title_timer:close(); title_timer = nil end
end

-- ── Playback ───────────────────────────────────────────────────────────────

local function stop()
  stop_title_timer()
  if job then local j = job; job = nil; vim.fn.jobstop(j) end
  status, title = 'off', nil
  close_badge()
end

local start -- forward declaration

local function on_failed(id)
  if job ~= id then return end -- an old player we already replaced or stopped
  job = nil
  attempts = attempts + 1
  if attempts >= #STATIONS then
    stop()
    vim.notify('Lofi: no station is reachable right now (offline?).', vim.log.levels.WARN)
    return
  end
  start(station % #STATIONS + 1)
end

function start(i)
  stop_title_timer()
  if job then local j = job; job = nil; vim.fn.jobstop(j) end
  station, status, title = i, 'tuning', nil
  draw_badge()
  local id
  id = vim.fn.jobstart({ 'osascript', '-l', 'JavaScript', script, STATIONS[i].url, tostring(vim.g.lofi_volume or VOLUME) }, {
    on_stdout = function(_, lines)
      for _, line in ipairs(lines) do
        if line == 'playing' and job == id then
          status, attempts = 'playing', 0
          draw_badge()
          fetch_title()
          stop_title_timer()
          title_timer = vim.uv.new_timer()
          title_timer:start(30000, 30000, vim.schedule_wrap(fetch_title))
        elseif line == 'failed' then
          on_failed(id)
        end
      end
    end,
    on_exit = function() vim.schedule(function() on_failed(id) end) end,
  })
  if id <= 0 then
    vim.notify('Lofi: could not start the player.', vim.log.levels.ERROR)
    status = 'off'; close_badge()
    return
  end
  job = id
end

function M.command(arg)
  arg = vim.trim(arg or '')
  if vim.fn.has('mac') == 0 then
    vim.notify('Lofi needs macOS (it uses the built-in AVPlayer).', vim.log.levels.WARN)
    return
  end
  if arg == 'off' or (arg == '' and status ~= 'off') then
    stop()
  elseif arg == 'next' then
    attempts = 0
    start(status == 'off' and 1 or station % #STATIONS + 1)
  elseif arg == '' then
    attempts = 0
    start(station or 1)
  else
    vim.notify('Usage: :Lofi [next|off]', vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_user_command('Lofi', function(o) M.command(o.args) end, {
    nargs = '?',
    complete = function() return { 'next', 'off' } end,
    desc = 'Lofi radio: toggle, next station, or off',
  })
  vim.cmd([[cnoreabbrev <expr> lofi getcmdtype() == ':' && getcmdline() ==# 'lofi' ? 'Lofi' : 'lofi']])
  vim.api.nvim_create_autocmd('VimResized', { callback = draw_badge })
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = stop })
end

return M
