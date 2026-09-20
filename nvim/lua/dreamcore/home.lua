local M = { recent = {}, targets = {}, selected = 1 }
local ns = vim.api.nvim_create_namespace('dream_home')
local scan_ns = vim.api.nvim_create_namespace('obsidian_home_scan')
local history = vim.fn.stdpath('state') .. '/dream-folders.json'
local uv = vim.uv or vim.loop
local icons = {
  { name = 'NOVA', shape = { '      │      ', '   ╲  │  ╱   ', ' ─────◇───── ', '   ╱  │  ╲   ', '      │      ' } },
  { name = 'ORBIT', shape = { '   ╭─────╮   ', ' ╭─┼─────┼─╮ ', ' │ │  ●  │ │ ', ' ╰─┼─────┼─╯ ', '   ╰─────╯   ' } },
  { name = 'PRISM', shape = { '      △      ', '     ╱│╲     ', '    ╱ │ ╲    ', '   ╱  ◇  ╲   ', '  ╱_______╲  ' } },
  { name = 'NEXUS', shape = { '    ┌───┐    ', ' ┌──┘   └──┐ ', ' │    ◈    │ ', ' └──┐   ┌──┘ ', '    └───┘    ' } },
}


local function entry(file)
  if type(file) ~= 'string' or file == '' then return end
  local path = uv.fs_realpath(file)
  local stat = path and uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then return end
  return { file = path, folder = vim.fs.dirname(path) }
end

function M.collect(files)
  local result, seen = {}, {}
  for _, file in ipairs(files) do
    local item = entry(type(file) == 'table' and file.file or file)
    if item and not seen[item.folder] then
      seen[item.folder] = true
      result[#result + 1] = item
    end
    if #result == 100 then break end
  end
  return result
end

local function remember(buf)
  if vim.bo[buf].buftype ~= '' then return end
  local item = entry(vim.api.nvim_buf_get_name(buf))
  if not item then return end
  local items = { item }
  vim.list_extend(items, M.recent)
  M.recent = M.collect(items)
end

local function fit(s, width)
  s = s:gsub('[%c]', ' ')
  if vim.fn.strdisplaywidth(s) <= width then return s end
  while vim.fn.strdisplaywidth(s) > width - 1 do
    s = vim.fn.strcharpart(s, 0, vim.fn.strchars(s) - 1)
  end
  return s .. '…'
end

function M.open(index)
  local item = M.recent[index]
  if not item then Snacks.picker.files(); return end
  if not entry(item.file) then
    M.recent = M.collect(M.recent)
    M.render()
    vim.notify('That file moved. Recent folders refreshed.')
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(item.file))
  vim.cmd.lcd(vim.fn.fnameescape(item.folder))
end

function M.render()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then return end
  local win = vim.fn.bufwinid(M.buf)
  if win == -1 then return end
  local width, height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local cols = width >= 34 and 2 or 1
  local cell = math.max(3, math.min(28, math.floor((width - 2) / cols)))
  local rows = math.ceil(4 / cols)
  local top = math.max(1, math.floor((height - (rows * 10 - 2)) / 2))
  local lines, highlights = {}, {}
  M.targets = {}
  local function line(s) lines[#lines + 1] = s end
  for _ = 1, top do line('') end
  for row = 0, rows - 1 do
    local start = #lines + 1
    for part = 1, 10 do
      local text = string.rep(' ', math.max(0, math.floor((width - cols * cell) / 2)))
      for col = 0, cols - 1 do
        local index = row * cols + col + 1
        local icon = icons[index]
        local recent = M.recent[index]
        local content = icon.shape[part] or ''
        if part == 7 then content = recent and vim.fs.basename(recent.file) or 'Open a file' end
        content = fit(content, cell - 2)
        local pad = math.max(0, math.floor((cell - vim.fn.strdisplaywidth(content)) / 2))
        local first = #text
        text = text .. string.rep(' ', pad) .. content .. string.rep(' ', cell - pad - vim.fn.strdisplaywidth(content))
        highlights[#highlights + 1] = { #lines, first + pad, first + pad + #content, index == M.selected and 'DreamHomeSelected' or 'DreamHomeIcon' }
      end
      line(text)
    end
    for col = 0, cols - 1 do
      M.targets[#M.targets + 1] = { index = row * cols + col + 1, first = start, last = start + 7, left = math.max(0, math.floor((width - cols * cell) / 2)) + col * cell + 1, right = math.max(0, math.floor((width - cols * cell) / 2)) + (col + 1) * cell }
    end
  end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  for _, h in ipairs(highlights) do vim.api.nvim_buf_add_highlight(M.buf, ns, h[4], h[1], h[2], h[3]) end
  M.animate((package.loaded['dreamcore.motion'] or {}).tick or 0)
end

-- Overlay scan lights without rewriting the home buffer on every frame.
function M.animate(tick)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) or vim.fn.bufwinid(M.buf) == -1 then return end
  vim.api.nvim_buf_clear_namespace(M.buf, scan_ns, 0, -1)
  if tick == 0 then return end
  for _, target in ipairs(M.targets) do
    local width = target.right - target.left + 1
    local origin = target.left - 1 + math.floor((width - 13) / 2)
    if origin >= 0 and width >= 13 then
      local step = (math.floor(tick / 2) + target.index * 3) % 9
      vim.api.nvim_buf_set_extmark(M.buf, scan_ns, target.first + 4, 0, {
        virt_text = { { '━━', target.index == M.selected and 'DreamHomeScan' or 'DreamHomeIdleScan' } },
        virt_text_win_col = origin + 1 + step,
        hl_mode = 'replace', priority = 180,
      })
    end
  end
end

function M.show()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].bufhidden = 'hide'
    vim.bo[M.buf].filetype = 'dream_home'
    vim.bo[M.buf].swapfile = false
    local function map(key, fn) vim.keymap.set('n', key, fn, { buffer = M.buf, silent = true }) end
    for i = 1, 4 do map(tostring(i), function() M.open(i) end) end
    map('<CR>', function() M.open(M.selected) end)
    for _, key in ipairs({ '<Tab>', '<Right>', '<Down>', 'j', 'l' }) do
      map(key, function() M.selected = M.selected % 4 + 1; M.render() end)
    end
    for _, key in ipairs({ '<S-Tab>', '<Left>', '<Up>', 'k', 'h' }) do
      map(key, function() M.selected = (M.selected + 2) % 4 + 1; M.render() end)
    end
    map('<MouseMove>', function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid ~= vim.fn.bufwinid(M.buf) then return end
      for _, target in ipairs(M.targets) do
        if mouse.line >= target.first and mouse.line <= target.last and mouse.column >= target.left and mouse.column <= target.right then
          if M.selected ~= target.index then M.selected = target.index; M.render() end
          return
        end
      end
    end)
    map('<LeftMouse>', function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid ~= vim.fn.bufwinid(M.buf) then return end
      for _, target in ipairs(M.targets) do
        if mouse.line >= target.first and mouse.line <= target.last and mouse.column >= target.left and mouse.column <= target.right then
          M.open(target.index); return
        end
      end
    end)
    map('f', function() Snacks.picker.files() end)
    map('e', function() require('dreamcore.workbench').toggle_files() end)
    map('q', function() vim.cmd.confirm('qa') end)
  end
  vim.api.nvim_win_set_buf(0, M.buf)
  vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline = false, false, false
  vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.wrap = 'no', '0', false
  M.render()
end

function M.setup()
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(history), '\n')) end)
  local files = ok and type(data) == 'table' and data or {}
  vim.list_extend(files, vim.v.oldfiles)
  M.recent = M.collect(files)
  local group = vim.api.nvim_create_augroup('DreamHome', { clear = true })
  require('dreamcore.style').apply()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, { group = group, callback = function(a) remember(a.buf) end })
  vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    pcall(vim.fn.writefile, { vim.json.encode(M.recent) }, history)
  end })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, { group = group, callback = M.render })
  vim.api.nvim_create_autocmd('BufEnter', { group = group, callback = function(a)
    if vim.bo[a.buf].buftype == '' then
      vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline = true, true, true
      vim.wo.signcolumn = 'yes'
    end
  end })
  vim.api.nvim_create_autocmd('VimEnter', { group = group, callback = function()
    if vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(0) == '' and not vim.bo.modified then M.show() end
  end })
  vim.api.nvim_create_user_command('Home', M.show, { desc = 'Open recent folders' })
  vim.keymap.set('n', '<leader>H', M.show, { desc = 'Home' })
end
return M
