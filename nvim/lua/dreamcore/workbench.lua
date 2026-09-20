local M = {}
local terminal
local function shell(parts) return table.concat(vim.tbl_map(vim.fn.shellescape, parts), ' ') end

function M.python(file)
  local root = vim.fs.root(file, { '.venv', 'venv', 'pyproject.toml', 'requirements.txt', '.git' })
  for _, dir in ipairs({ '.venv', 'venv' }) do
    local candidate = root and (root .. '/' .. dir .. '/bin/python')
    if candidate and vim.fn.executable(candidate) == 1 then return candidate end
  end
  local active = vim.env.VIRTUAL_ENV and (vim.env.VIRTUAL_ENV .. '/bin/python')
  if active and vim.fn.executable(active) == 1 then return active end
  return vim.fn.exepath('python3')
end

function M.command(file, ft)
  if ft == 'python' then
    local python = M.python(file)
    if python == '' then return nil, 'Install Python 3 to run this file.' end
    return shell({ python, '-u', file })
  elseif ft == 'cpp' or ft == 'c' then
    local compiler = vim.fn.exepath(ft == 'cpp' and 'clang++' or 'clang')
    if compiler == '' then compiler = vim.fn.exepath(ft == 'cpp' and 'g++' or 'gcc') end
    if compiler == '' then return nil, 'Install a C/C++ compiler first.' end
    local output = vim.fn.tempname()
    return shell({ compiler, ft == 'cpp' and '-std=c++20' or '-std=c17', '-Wall', '-Wextra', '-g', file, '-o', output })
      .. ' && ' .. vim.fn.shellescape(output) .. '; result=$?; rm -f ' .. vim.fn.shellescape(output) .. '; exit $result'
  end
  return nil, 'Run supports Python, C++, C, or a web project with :Start.'
end

function M.run()
  local file, ft = vim.api.nvim_buf_get_name(0), vim.bo.filetype
  if vim.bo.buftype ~= '' or file == '' then vim.notify('Open and save a code file first.'); return end
  if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'html', 'css' }, ft) then vim.cmd.Start(); return end
  local cmd, err = M.command(file, ft)
  if not cmd then vim.notify(err, vim.log.levels.WARN); return end
  vim.cmd.update()
  if terminal and terminal.job_id and vim.fn.jobwait({ terminal.job_id }, 0)[1] == -1 then
    terminal:open(); vim.notify('Your program is still running. Use Ctrl-C to stop it.'); return
  end
  if terminal then terminal:shutdown() end
  terminal = require('toggleterm.terminal').Terminal:new({
    cmd = cmd, dir = vim.fs.dirname(file), direction = 'float', hidden = true,
    close_on_exit = false, display_name = 'Run · ' .. vim.fs.basename(file),
    on_open = function(t)
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n><cmd>close<CR>]], { buffer = t.bufnr, desc = 'Back to editor' })
    end,
  })
  terminal:open()
end

function M.toggle_files()
  local explorers = Snacks.picker.get({ source = 'explorer' })
  if #explorers > 0 then
    for _, picker in ipairs(explorers) do picker:close() end
  else
    Snacks.explorer({ cwd = vim.fn.getcwd() })
  end
end

function M.home()
  for _, picker in ipairs(Snacks.picker.get()) do picker:close() end
  vim.cmd.stopinsert()
  require('dreamcore.home').show()
end

function M.toolbar()
  local clock = ' ' .. require('dreamcore.clock').text() .. ' '
  local clock_width = vim.fn.strdisplaywidth(clock)
  local start = math.max(0, math.floor((vim.o.columns - clock_width) / 2))
  local available = math.max(0, vim.o.columns - start - clock_width)
  local items = {
    { 'Home', 'Home F1' }, { 'Files', 'Files F2' }, { 'Run', 'Run F5' },
    { 'TabLeft', '← S-h' }, { 'TabRight', 'S-l →' }, { 'Save', 'Save ^S' },
    { 'Motion', require('dreamcore.motion').enabled and '◉' or '○' }, { 'Quit', 'Quit' },
  }
  local function size()
    local width = 0
    for _, item in ipairs(items) do width = width + vim.fn.strdisplaywidth(item[2]) + 2 end
    return width
  end
  if size() > available then
    local medium = { TabLeft = '←', TabRight = '→', Save = 'S', Quit = 'Q' }
    for _, item in ipairs(items) do item[2] = medium[item[1]] or item[2] end
  end
  if size() > available then
    local short = { Home = 'F1', Files = 'F2', Run = 'F5' }
    for _, item in ipairs(items) do item[2] = short[item[1]] or item[2] end
  end
  -- Keep the clock centered on small terminals; retain the primary shortcuts.
  for _, name in ipairs({ 'Motion', 'Save', 'Quit', 'TabLeft', 'TabRight', 'Run', 'Files', 'Home' }) do
    if size() <= available then break end
    for index, item in ipairs(items) do
      if item[1] == name then table.remove(items, index); break end
    end
  end
  local result = {
    { text = clock .. string.rep(' ', math.max(0, available - size())), fg = '#b8edfa', bg = '#050607' },
  }
  for _, item in ipairs(items) do
    result[#result + 1] = { text = '%@v:lua.Dream' .. item[1] .. '@ ' .. item[2] .. ' %X', fg = item[1] == 'Run' and '#57d9f5' or '#8b9faa', bg = '#050607' }
  end
  return result
end

function M.setup()
  require('dreamcore.clock').setup()
  local actions = {
    Motion = function() require('dreamcore.motion').toggle() end,
    Run = M.run, Home = M.home, Files = M.toggle_files,
    TabLeft = function() require('bufferline').cycle(-1) end,
    TabRight = function() require('bufferline').cycle(1) end,
    Save = function() vim.cmd.write() end, Quit = function() vim.cmd.confirm('qa') end,
  }
  for name, action in pairs(actions) do
    _G['Dream' .. name] = function() vim.schedule(action) end
    if name ~= 'Home' then vim.api.nvim_create_user_command(name, action, {}) end
  end
  for _, key in ipairs({ 'H', '<S-Left>' }) do vim.keymap.set('n', key, actions.TabLeft, { desc = 'Tab left' }) end
  for _, key in ipairs({ 'L', '<S-Right>' }) do vim.keymap.set('n', key, actions.TabRight, { desc = 'Tab right' }) end
  vim.keymap.set({ 'n', 'i', 't' }, '<F1>', M.home, { desc = 'Home' })
  vim.keymap.set({ 'n', 'i', 't' }, '<F2>', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set('n', '<leader>e', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set({ 'n', 'i' }, '<F5>', actions.Run, { desc = 'Run current file' })
  for lower, upper in pairs({ run = 'Run', tableft = 'TabLeft', tabright = 'TabRight', home = 'Home' }) do
    vim.cmd(string.format([[cnoreabbrev <expr> %s getcmdtype() == ':' && getcmdline() ==# '%s' ? '%s' : '%s']], lower, lower, upper, lower))
  end
end
return M
