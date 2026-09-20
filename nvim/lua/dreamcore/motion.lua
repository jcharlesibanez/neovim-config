local M = { enabled = true, paused = false, tick = 0, boost = 0 }
local uv = vim.uv or vim.loop
local c = require('dreamcore.style').colors
local frames = { '▁▂▃▅▃▂', '▂▃▅▃▂▁', '▃▅▃▂▁▂', '▅▃▂▁▂▃', '▃▂▁▂▃▅', '▂▁▂▃▅▃' }
local function mix(a, b, t)
  local result = '#'
  for i = 2, 6, 2 do
    local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
    result = result .. string.format('%02x', math.floor(x + (y - x) * t))
  end
  return result
end
local function external(enabled)
  local audio = package.loaded["dreamcore.audio"]
  if audio then audio.pause(not enabled) end
  vim.g.snacks_animate_indent = enabled
  local smear = package.loaded.smear_cursor
  if smear then smear.enabled = enabled end
  if _G.Snacks and Snacks.scroll then
    if enabled then Snacks.scroll.enable() else Snacks.scroll.disable() end
  end
  if _G.MiniAnimate then
    for _, kind in ipairs({ 'resize', 'open', 'close' }) do MiniAnimate.config[kind].enable = enabled end
  end
  if _G.Snacks and Snacks.config and Snacks.config.indent then
    Snacks.config.indent.animate.enabled = enabled
  end
end
local function frame()
  if not M.enabled or M.paused or #vim.api.nvim_list_uis() == 0 then return end
  M.tick = M.tick + 1
  M.boost = math.max(0, M.boost - 1)
  local pulse = (math.sin(M.tick / 9) + 1) / 2
  vim.api.nvim_set_hl(0, 'DreamHomeSelected', { fg = mix(c.cyan, c.white, pulse * .7), bg = c.base, bold = true })
  vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = M.boost > 0 and c.white or mix(c.dim, c.cyan, .5 + pulse * .5), bold = true })
  vim.api.nvim_set_hl(0, 'SnacksIndentScope', { fg = mix(c.dim, c.cyan, pulse * .55) })
  local home = package.loaded['dreamcore.home']
  if home then home.animate(M.tick) end
  if M.tick % 3 == 0 then vim.cmd.redrawstatus() end
end
function M.start()
  if not M.enabled or #vim.api.nvim_list_uis() == 0 then return end
  M.timer = M.timer or assert(uv.new_timer())
  M.timer:start(0, 80, vim.schedule_wrap(frame))
end
function M.stop(close)
  if M.timer then
    M.timer:stop()
    if close then M.timer:close(); M.timer = nil end
  end
end
function M.toggle()
  M.enabled = not M.enabled
  external(M.enabled)
  if M.enabled then M.start() else
    M.stop(false)
    require('dreamcore.style').apply()
    local home = package.loaded['dreamcore.home']
    if home then home.animate(0) end
  end
  vim.cmd.redrawtabline()
  vim.cmd.redrawstatus()
  vim.notify(M.enabled and 'Motion on' or 'Motion paused', vim.log.levels.INFO, { title = 'Appearance' })
end
function M.react(kind)
  M.boost = kind == 'save' and 16 or 7
end
function M.status()
  if not M.enabled then return '── PAUSED' end
  return frames[(math.floor(M.tick / 2) % #frames) + 1] .. (M.boost > 0 and ' SYNC' or ' LIVE')
end
function M.setup()
  local group = vim.api.nvim_create_augroup('dreamcore_motion', { clear = true })
  vim.api.nvim_create_autocmd('UIEnter', { group = group, callback = function() vim.schedule(M.start) end })
  vim.api.nvim_create_autocmd('FocusLost', { group = group, callback = function() M.paused = true end })
  vim.api.nvim_create_autocmd('FocusGained', { group = group, callback = function() M.paused = false end })
  vim.api.nvim_create_autocmd('ModeChanged', { group = group, callback = function() M.react('mode') end })
  vim.api.nvim_create_autocmd('TextYankPost', { group = group, callback = function() M.react('yank') end })
  vim.api.nvim_create_autocmd('BufWritePost', { group = group, callback = function() M.react('save') end })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function() M.stop(true) end })
  vim.keymap.set('n', '<leader>ua', M.toggle, { desc = 'Pause / resume all motion' })
  if #vim.api.nvim_list_uis() > 0 then vim.schedule(M.start) end
end
return M
