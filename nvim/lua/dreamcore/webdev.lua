local M = {}

local state = {
  terminals = {},
  urls = {},
}

local package_files = { "package.json" }
local script_priority = { "dev", "serve", "start" }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Web development" })
end

local function current_path()
  local name = vim.api.nvim_buf_get_name(0)
  return name ~= "" and name or vim.fn.getcwd()
end

local function project_root()
  return vim.fs.root(current_path(), package_files)
end

local function exists(path)
  return (vim.uv or vim.loop).fs_stat(path) ~= nil
end

local function read_package(root)
  local path = root .. "/package.json"
  local file = io.open(path, "r")
  if not file then return nil end
  local contents = file:read("*a")
  file:close()
  local ok, package = pcall(vim.json.decode, contents)
  if not ok then return nil end
  return package
end

local function package_manager(root)
  if exists(root .. "/bun.lock") or exists(root .. "/bun.lockb") then return "bun" end
  if exists(root .. "/pnpm-lock.yaml") then return "pnpm" end
  if exists(root .. "/yarn.lock") then return "yarn" end
  return "npm"
end

local function dev_script(package)
  local scripts = package and package.scripts or {}
  for _, name in ipairs(script_priority) do
    if scripts[name] then return name end
  end
end

local function command_for(root, script)
  local manager = package_manager(root)
  if manager == "npm" then return { "npm", "run", script } end
  return { manager, "run", script }
end

local function shell_command(parts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, parts), " ")
end

local function clean_url(line)
  line = line:gsub("\27%[[0-9;?]*[ -/]*[@-~]", "")
  return line:match("https?://[%w%.:%-%[%]]+[^%s]*")
end

local function refresh_status()
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "WebDevStatusChanged" })
    pcall(vim.cmd, "redrawstatus")
  end)
end

local function is_running(terminal)
  if not terminal or not terminal.job_id then return false end
  return vim.fn.jobwait({ terminal.job_id }, 0)[1] == -1
end

local function start(options)
  options = options or {}
  local root = project_root()
  if not root then
    notify("No package.json found above this file.", vim.log.levels.WARN)
    return
  end

  local package = read_package(root)
  local script = dev_script(package)
  if not script then
    notify("package.json needs a dev, serve, or start script.", vim.log.levels.WARN)
    return
  end

  local existing = state.terminals[root]
  if is_running(existing) and not options.restart then
    existing:open()
    notify("Dev server is already live.")
    return
  end
  if existing then
    existing:shutdown()
    state.terminals[root] = nil
  end

  local ok, Terminal = pcall(function() return require("toggleterm.terminal").Terminal end)
  if not ok then
    notify("ToggleTerm is still loading. Run :start again in a moment.", vim.log.levels.WARN)
    return
  end

  local command = command_for(root, script)
  local terminal
  terminal = Terminal:new({
    cmd = shell_command(command),
    dir = root,
    direction = "float",
    close_on_exit = false,
    hidden = true,
    display_name = "web · " .. (package.name or vim.fs.basename(root)),
    on_stdout = function(_, _, data)
      for _, line in ipairs(data or {}) do
        local url = clean_url(line)
        if url then state.urls[root] = url end
      end
    end,
    on_exit = function()
      refresh_status()
    end,
  })
  state.terminals[root] = terminal
  terminal:toggle()
  refresh_status()
  notify(string.format("Running %s from %s", table.concat(command, " "), vim.fs.basename(root)))
end

local function stop()
  local root = project_root()
  local terminal = root and state.terminals[root] or nil
  if not is_running(terminal) then
    notify("No dev server is running for this project.")
    return
  end
  terminal:shutdown()
  state.terminals[root] = nil
  state.urls[root] = nil
  refresh_status()
  notify("Dev server stopped.")
end

local function open_site()
  local root = project_root()
  local terminal = root and state.terminals[root] or nil
  if not is_running(terminal) then
    notify("Run :start first.", vim.log.levels.WARN)
    return
  end
  local url = state.urls[root]
  if not url then
    notify("The server has not printed its website URL yet.", vim.log.levels.WARN)
    return
  end
  vim.ui.open(url)
end

function M.status()
  local root = project_root()
  if root and is_running(state.terminals[root]) then return "web ◉ live" end
  return "web ○ idle"
end

function M.setup()
  vim.opt.autowrite = true

  vim.api.nvim_create_user_command("Start", function(command)
    start({ restart = command.bang })
  end, { bang = true, desc = "Start or restart this website" })
  vim.api.nvim_create_user_command("Stop", stop, { desc = "Stop this website" })
  vim.api.nvim_create_user_command("Web", open_site, { desc = "Open this website" })

  -- Neovim requires user commands to begin with a capital, so translate the
  -- exact lowercase commands without interfering with longer Ex commands.
  vim.cmd([[cnoreabbrev <expr> start getcmdtype() == ':' && getcmdline() ==# 'start' ? 'Start' : 'start']])
  vim.cmd([[cnoreabbrev <expr> stop getcmdtype() == ':' && getcmdline() ==# 'stop' ? 'Stop' : 'stop']])
  vim.cmd([[cnoreabbrev <expr> web getcmdtype() == ':' && getcmdline() ==# 'web' ? 'Web' : 'web']])

  local save = "<cmd>w<CR>"
  vim.keymap.set("n", "<D-s>", save, { desc = "Save to Website" })
  vim.keymap.set("i", "<D-s>", save, { desc = "Save to Website" })
  vim.keymap.set("v", "<D-s>", "<Esc>" .. save .. "gv", { desc = "Save to Website" })
  vim.keymap.set("n", "<C-s>", save, { desc = "Save to Website" })
  vim.keymap.set("i", "<C-s>", save, { desc = "Save to Website" })
  vim.keymap.set("v", "<C-s>", "<Esc>" .. save .. "gv", { desc = "Save to Website" })

  vim.keymap.set("n", "<leader>ws", start, { desc = "Start Website" })
  vim.keymap.set("n", "<leader>wr", function() start({ restart = true }) end, { desc = "Restart Website" })
  vim.keymap.set("n", "<leader>wx", stop, { desc = "Stop Website" })
  vim.keymap.set("n", "<leader>wo", open_site, { desc = "Open Website" })
end

return M
