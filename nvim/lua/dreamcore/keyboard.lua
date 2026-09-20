-- Receives only keys delivered to Neovim. No OS hooks or key logging.
local M = { active = {}, keys = {} }
local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace('KeyboardLights')
local input_ns = vim.api.nvim_create_namespace('KeyboardLightsInput')
local timer
local indexes = {}
local function add(name, row, col)
  local key = { name = name, row = row, col = col }
  M.keys[#M.keys + 1] = key
  indexes[name] = key
end
add('Esc', 0, 0)
for i = 1, 12 do add('F' .. i, 0, i) end
for i, name in ipairs({ '`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 'BS' }) do add(name, 1, i - 1) end
for i, name in ipairs({ 'Tab', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\\' }) do add(name, 2, i - 1) end
for i, name in ipairs({ 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", 'CR' }) do add(name, 3, i + .2) end
for i, name in ipairs({ 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/' }) do add(name, 4, i + .6) end
add('Space', 5, 6)
add('Up', 5, 12)
add('Left', 6, 11)
add('Down', 6, 12)
add('Right', 6, 13)
assert(#M.keys == 68)

local shifted = {}
local plain, shift = '`1234567890-=[]\\;\',./', '~!@#$%^&*()_+{}|:"<>?'
for i = 1, #plain do shifted[shift:sub(i, i)] = plain:sub(i, i) end
local aliases = { Enter = 'CR', Return = 'CR', NL = 'CR', C_M = 'CR', Backspace = 'BS', Del = 'BS', Space = 'Space', lt = ',' }

function M.resolve(key)
  if key == ' ' then return 'Space' end
  if #key == 1 then
    local name = shifted[key] or key:lower()
    return indexes[name] and name or nil
  end
  local name = key:match('^<(.+)>$')
  if not name or name:find('Mouse') or name:find('Scroll') or name:find('Release') or name:find('Drag') then return end
  name = aliases[name] or name
  if indexes[name] then return name end
  -- Highlight the base physical key in a chord, never invent a modifier square.
  local base = name:gsub('^[CSAMD]%-', ''):gsub('^[CSAMD]%-', '')
  if base == name then return end
  return indexes[base] and base or M.resolve(base)
end

function M.layout(width)
  -- The keyboard is one quiet horizontal strip directly above the waveform.
  -- Every slot is one terminal cell wide so all 68 keys fit on one level.
  local positions = {}
  local gap = math.max(0, math.floor((width - #M.keys) / (#M.keys + 1)))
  local step = 1 + gap
  local left = math.max(0, math.floor((width - (#M.keys * step - gap)) / 2))
  for index, key in ipairs(M.keys) do
    positions[#positions + 1] = { name = key.name, row = 0, col = left + (index - 1) * step, size = 1 }
  end
  return positions, 1
end

function M.blank(width)
  local _, height = M.layout(width)
  local lines = {}
  for i = 1, height do lines[i] = string.rep(' ', width) end
  return lines
end

function M.draw(buf, width)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local now = uv.now()
  for _, key in ipairs(M.layout(width)) do
    local until_time = M.active[key.name]
    if until_time and until_time > now and key.col + key.size <= width then
      local strength = math.max(1, math.min(5, math.ceil((until_time - now) / 70)))
      vim.api.nvim_buf_set_extmark(buf, ns, key.row, key.col, {
        end_col = key.col + key.size, hl_group = 'KeyboardLight' .. strength,
        priority = 220,
      })
    end
  end
end

local function redraw()
  local audio = package.loaded['dreamcore.audio']
  if not audio then return end
  for _, view in pairs(audio.views) do
    if vim.api.nvim_win_is_valid(view.win) and vim.api.nvim_buf_is_valid(view.buf) then
      M.draw(view.buf, vim.api.nvim_win_get_width(view.win))
    end
  end
end

function M.hit(name)
  if not indexes[name] then return end
  local audio = package.loaded['dreamcore.audio']
  if not audio or not audio.enabled or not next(audio.views) then return end
  M.active[name] = uv.now() + 350
  if not timer then timer = assert(uv.new_timer()) end
  if not timer:is_active() then
    timer:start(0, 30, vim.schedule_wrap(function()
      local now = uv.now()
      for key, expires in pairs(M.active) do if expires <= now then M.active[key] = nil end end
      redraw()
      if not next(M.active) then timer:stop() end
    end))
  end
end

function M.setup()
  local function highlights()
    for i, color in ipairs({ '#092718', '#135332', '#21884a', '#37bf68', '#6bff9b' }) do
      vim.api.nvim_set_hl(0, 'KeyboardLight' .. i, { bg = color, fg = color })
    end
  end
  highlights()
  vim.on_key(function(_, typed)
    if typed == '' then return end -- Ignore mapping expansions, macros, and replayed keys.
    local text = vim.fn.keytrans(typed)
    local keys = {}
    while #text > 0 do
      local token = text:match('^<[^>]+>') or vim.fn.strcharpart(text, 0, 1)
      text = text:sub(#token + 1)
      local key = M.resolve(token)
      if key then keys[#keys + 1] = key end
    end
    if #keys > 0 then vim.schedule(function() for _, key in ipairs(keys) do M.hit(key) end end) end
  end, input_ns)
  local group = vim.api.nvim_create_augroup('KeyboardLights', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
  vim.api.nvim_create_autocmd('FocusLost', { group = group, callback = function() M.active = {}; redraw() end })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    vim.on_key(nil, input_ns)
    if timer then timer:stop(); timer:close(); timer = nil end
  end })
end
return M
