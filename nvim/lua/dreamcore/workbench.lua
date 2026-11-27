local M = {}
local terminal
local function shell(parts) return table.concat(vim.tbl_map(vim.fn.shellescape, parts), ' ') end

-- How to install something on this system: Homebrew/Xcode on macOS, apt on Ubuntu/Debian.
local function install_hint(mac_cmd, apt_pkg)
  if vim.fn.has('mac') == 1 then return mac_cmd end
  if vim.fn.executable('apt-get') == 1 then return 'sudo apt install ' .. apt_pkg end
  return 'install ' .. apt_pkg .. ' with your package manager'
end

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
    if python == '' then return nil, 'Install Python 3 to run this file: ' .. install_hint('brew install python', 'python3') end
    return shell({ python, '-u', file })
  elseif ft == 'cpp' or ft == 'c' then
    local compiler = vim.fn.exepath(ft == 'cpp' and 'clang++' or 'clang')
    if compiler == '' then compiler = vim.fn.exepath(ft == 'cpp' and 'g++' or 'gcc') end
    if compiler == '' then return nil, 'Install a C/C++ compiler first: ' .. install_hint('xcode-select --install', 'build-essential') end
    local output = vim.fn.tempname()
    return shell({ compiler, ft == 'cpp' and '-std=c++20' or '-std=c17', '-Wall', '-Wextra', '-g', file, '-o', output })
      .. ' && ' .. vim.fn.shellescape(output) .. '; result=$?; rm -f ' .. vim.fn.shellescape(output) .. '; exit $result'
  end
  return nil, 'Run supports Python, C++, C, CMake projects, or a web project with :Start.'
end

-- ── CMake projects ─────────────────────────────────────────────────────────

-- Outermost folder with a CMakeLists.txt, so subdirectory CMakeLists don't win.
local function cmake_root(file)
  local root
  for dir in vim.fs.parents(file) do
    if vim.fn.filereadable(dir .. '/CMakeLists.txt') == 1 then root = dir end
    if vim.fn.isdirectory(dir .. '/.git') == 1 then break end
  end
  return root
end

-- First add_executable() target in the root CMakeLists.txt, e.g. "rover".
local function cmake_target(root)
  local text = table.concat(vim.fn.readfile(root .. '/CMakeLists.txt'), '\n'):gsub('#[^\n]*', '')
  return text:match('add_executable%s*%(%s*([%w_%-%.]+)')
end

local build_log = vim.fn.tempname() .. '-build.log'

-- Configure only when there's no build dir yet (FetchContent downloads are slow),
-- then build. Output is teed to a log so errors can go to quickfix afterwards.
local function cmake_command(root, run)
  local log = vim.fn.shellescape(build_log)
  local steps = {}
  if vim.fn.filereadable(root .. '/build/CMakeCache.txt') == 0 then
    table.insert(steps, 'cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON')
  end
  table.insert(steps, 'cmake --build build -j')
  local cmd = 'set -o pipefail; { ' .. table.concat(steps, ' && ') .. '; } 2>&1 | tee ' .. log
  if run then
    local target = cmake_target(root)
    if not target then return nil, 'No add_executable() found in CMakeLists.txt.' end
    cmd = cmd .. ' && echo && ./build/' .. vim.fn.shellescape(target)
  end
  return cmd
end

-- Turn compiler errors/warnings from the build log into the quickfix list.
local function load_build_errors()
  if vim.fn.filereadable(build_log) == 0 then return end
  vim.fn.setqflist({}, ' ', {
    title = 'CMake build',
    lines = vim.fn.readfile(build_log),
    efm = '%f:%l:%c: %trror: %m,%f:%l:%c: %tarning: %m,%f:%l: %trror: %m,%-G%.%#',
  })
  vim.fn.delete(build_log)
  local errors, warnings = 0, 0
  for _, item in ipairs(vim.fn.getqflist()) do
    if item.valid == 1 and item.type == 'e' then errors = errors + 1
    elseif item.valid == 1 and item.type == 'w' then warnings = warnings + 1 end
  end
  if errors + warnings > 0 then
    vim.notify(('Build: %d error(s), %d warning(s). <leader>x lists them, ]q / [q jump.'):format(errors, warnings),
      errors > 0 and vim.log.levels.ERROR or vim.log.levels.WARN)
  end
end

-- ── Bottom output terminal ─────────────────────────────────────────────────

local function open_terminal(cmd, dir, name, on_exit)
  if terminal and terminal.job_id and vim.fn.jobwait({ terminal.job_id }, 0)[1] == -1 then
    terminal:open(); vim.notify('Your program is still running. Use Ctrl-C to stop it.'); return
  end
  if terminal then terminal:shutdown() end
  local h = 12
  terminal = require('toggleterm.terminal').Terminal:new({
    cmd = cmd, dir = dir, direction = 'float', hidden = true,
    close_on_exit = false, display_name = name,
    on_exit = on_exit and function() vim.schedule(on_exit) end or nil,
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

-- Build (and optionally run) the CMake project containing the current file.
local function cmake(run)
  local file = vim.api.nvim_buf_get_name(0)
  local root = cmake_root(file ~= '' and file or vim.fn.getcwd() .. '/x')
  if not root then vim.notify('No CMakeLists.txt found above this file.', vim.log.levels.WARN); return false end
  if vim.fn.executable('cmake') == 0 then vim.notify('Install CMake first: ' .. install_hint('brew install cmake', 'cmake'), vim.log.levels.WARN); return true end
  local cmd, err = cmake_command(root, run)
  if not cmd then vim.notify(err, vim.log.levels.WARN); return true end
  vim.cmd('silent! wall')
  open_terminal(cmd, root, (run and 'Run · ' or 'Build · ') .. vim.fs.basename(root), load_build_errors)
  return true
end

function M.build() cmake(false) end

function M.run()
  local file, ft = vim.api.nvim_buf_get_name(0), vim.bo.filetype
  if vim.tbl_contains({ 'c', 'cpp', 'cmake' }, ft) and file ~= '' and cmake_root(file) then cmake(true); return end
  if vim.bo.buftype ~= '' or file == '' then vim.notify('Open and save a code file first.'); return end
  if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'html', 'css' }, ft) then vim.cmd.Start(); return end
  local cmd, err = M.command(file, ft)
  if not cmd then vim.notify(err, vim.log.levels.WARN); return end
  vim.cmd.update()
  open_terminal(cmd, vim.fs.dirname(file), 'Run · ' .. vim.fs.basename(file))
end

function M.toggle_files()
  local explorers = Snacks.picker.get({ source = 'explorer' })
  if #explorers > 0 then
    for _, picker in ipairs(explorers) do picker:close() end
  else
    Snacks.explorer({ cwd = vim.fn.getcwd() })
  end
end

-- Ctrl-l: hop between the explorer and the file you're editing, keeping both open.
local function is_explorer(win) return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match('^snacks_') ~= nil end

-- Ctrl+L: open the explorer if it's closed, otherwise move to the next window to the right
-- (explorer → file → Claude Code → back to the explorer). See dreamcore/windows.lua.
function M.hop_files()
  if not Snacks.picker.get({ source = 'explorer' })[1] then Snacks.explorer({ cwd = vim.fn.getcwd() }); return end
  require('dreamcore.windows').next()
end

-- Each major version has a name: v2.2.2 is "v2.2.2 Delta". Add new majors here.
M.codenames = { [2] = 'Delta' }

-- Version of this config, from git tags (vX.Y.Z) plus the major's name. Between releases
-- git describe says e.g. "v2.0.0-3-gabc1234" (3 commits after v2.0.0); show that as
-- "v2.0.0+3 Delta (abc1234)".
function M.version()
  local dir = vim.fn.stdpath('config')
  local out = vim.trim(vim.system({ 'git', '-C', dir, 'describe', '--tags', '--always' }, { text = true }):wait().stdout or '')
  if out == '' then return 'unknown' end
  local tag, ahead, sha = out:match('^(.-)%-(%d+)%-g(%x+)$')
  local name = M.codenames[tonumber((tag or out):match('^v(%d+)%.'))]
  name = name and (' ' .. name) or ''
  if tag then return ('%s+%s%s (%s)'):format(tag, ahead, name, sha) end
  return out .. name
end

-- Files in the config repo you've edited but not committed (untracked files don't count).
local function local_changes(dir)
  local out = vim.system({ 'git', '-C', dir, 'status', '--porcelain', '--untracked-files=no' }, { text = true }):wait().stdout or ''
  local files = {}
  for line in out:gmatch('[^\n]+') do table.insert(files, vim.fn.fnamemodify(line:sub(4), ':t')) end
  return files
end

function M.upgrade()
  local dir = vim.fn.stdpath('config')
  local before = M.version()
  -- One white italic note in the bottom right the whole way: "Checking…" stays up until the
  -- pull finishes, then changes in place to the result and fades out.
  local function say(msg, timeout)
    require('dreamcore.toast').show(msg, { id = 'config_update', color = '#ffffff', timeout = timeout, order = 100 })
  end

  local function pull(overwrote)
    say('Checking for updates… (current version ' .. before .. ')', false)
    -- --tags so new version tags come down too, even ones not on the pulled commits.
    vim.system({ 'git', '-C', dir, 'pull', '--ff-only', '--tags' }, { text = true }, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          local err = vim.trim((res.stderr or '') .. '\n' .. (res.stdout or ''))
          say('Update failed: ' .. (err:match('[^\n]+') or 'git pull failed'), 6000)
          return
        end
        local note = overwrote and ' Local changes overwritten.' or ''
        local after = M.version()
        if after == before then
          say('Already on the latest version: ' .. after .. '.' .. note, 3000)
        else
          say('Updated ' .. before .. ' → ' .. after .. '. Restart Neovim to apply.' .. note, 5000)
        end
      end)
    end)
  end

  local changed = local_changes(dir)
  if #changed == 0 then return pull(false) end
  local names = table.concat(vim.list_slice(changed, 1, 3), ', ') .. (#changed > 3 and ', …' or '')
  vim.ui.input({
    prompt = ('You have local changes to the config (%s). Overwrite them and update? [Y/n] '):format(names),
  }, function(answer)
    if answer == nil or answer:lower():match('^%s*n') then
      say('Update cancelled.', 2500)
      return
    end
    -- Throw the edits away so the pull can't fail or clash. They go to `git stash` rather than
    -- straight to nothing, so an accidental Y can still be undone with `git stash pop`.
    local res = vim.system({ 'git', '-C', dir, 'stash', 'push', '-q', '-m', 'local changes overwritten by :Update' }):wait()
    if res.code ~= 0 then
      say('Update failed: could not clear local changes.', 6000)
      return
    end
    pull(true)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('Run', M.run, {})
  vim.api.nvim_create_user_command('Build', M.build, { desc = 'Build the CMake project (errors → quickfix)' })
  -- :Update / :update / :Upgrade / :upgrade all pull the latest config. Typing `:update`
  -- normally runs Vim's own "save if changed"; typed alone it now means :Update instead
  -- (scripts and autosave calling `update` still save; `:up` still saves too).
  vim.api.nvim_create_user_command('Update', M.upgrade, { desc = 'Pull latest config from GitHub, show version' })
  vim.api.nvim_create_user_command('Upgrade', M.upgrade, { desc = 'Pull latest config from GitHub, show version' })
  vim.cmd([[cnoreabbrev <expr> upgrade getcmdtype() == ':' && getcmdline() ==# 'upgrade' ? 'Upgrade' : 'upgrade']])
  vim.cmd([[cnoreabbrev <expr> update getcmdtype() == ':' && getcmdline() ==# 'update' ? 'Update' : 'update']])
  vim.cmd([[cnoreabbrev <expr> build getcmdtype() == ':' && getcmdline() ==# 'build' ? 'Build' : 'build']])
  vim.keymap.set({ 'n', 'i', 't' }, '<F2>', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set('n', '<leader>e', M.toggle_files, { desc = 'Toggle files' })
  vim.keymap.set('n', '<C-l>', M.hop_files, { desc = 'Next window (explorer → file → Claude Code)' })
  vim.keymap.set({ 'n', 'i' }, '<F5>', M.run, { desc = 'Run current file / CMake project' })
  vim.keymap.set('n', '<leader>r', M.run, { desc = 'Run current file / CMake project' })
  vim.keymap.set('n', '<leader>b', M.build, { desc = 'Build CMake project' })
  vim.keymap.set('n', '<leader>x', function()
    vim.cmd(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and 'cclose' or 'botright copen')
  end, { desc = 'Toggle build errors (quickfix)' })
  vim.cmd([[cnoreabbrev <expr> run getcmdtype() == ':' && getcmdline() ==# 'run' ? 'Run' : 'run']])
end

return M
