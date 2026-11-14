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
  local h = 12
  terminal = require('toggleterm.terminal').Terminal:new({
    cmd = cmd, dir = vim.fs.dirname(file), direction = 'float', hidden = true,
    close_on_exit = false, display_name = 'Run · ' .. vim.fs.basename(file),
    float_opts = {
      border  = 'single',
      width   = function() return vim.o.columns - 4 end,
      height  = h,
      row     = function() return vim.o.lines - h - 3 end,
      col     = 2,
      winblend = 0,
    },
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

function M.setup()
  vim.api.nvim_create_user_command('Run', M.run, {})
  vim.keymap.set({ 'n', 'i', 't' }, '<F2>', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set('n', '<leader>e', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set({ 'n', 'i' }, '<F5>', M.run, { desc = 'Run current file' })
  vim.keymap.set('n', '<leader>r', M.run, { desc = 'Run current file' })
  vim.cmd([[cnoreabbrev <expr> run getcmdtype() == ':' && getcmdline() ==# 'run' ? 'Run' : 'run']])
end

return M
