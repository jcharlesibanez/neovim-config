local M = {}
local uv = vim.uv or vim.loop

-- No suffix means folder; a trailing slash explicitly requests a folder.
function M.create(directory, name)
  name = vim.trim(name or '')
  if name == '' then return nil, 'cancelled' end
  if name:sub(1, 1) == '/' or name:find('[%c]') then
    return nil, 'Enter a relative name inside the selected folder.'
  end
  for part in name:gmatch('[^/]+') do
    if part == '..' or part == '.' then return nil, 'Enter a name inside the selected folder.' end
  end
  local folder = name:sub(-1) == '/'
  local path = vim.fs.normalize(directory .. '/' .. name)
  local basename = vim.fs.basename(path)
  local is_file = not folder and basename:match('%.[^%.]+$') ~= nil
  if uv.fs_lstat(path) then return nil, 'That name already exists.' end
  local parent = is_file and vim.fs.dirname(path) or path
  local ok, err = pcall(vim.fn.mkdir, parent, 'p')
  if not ok then return nil, tostring(err) end
  if is_file then
    -- Exclusive creation also protects against a file appearing during the prompt.
    local fd, open_err = uv.fs_open(path, 'wx', 420)
    if not fd then return nil, open_err end
    uv.fs_close(fd)
  end
  return path, is_file
end

function M.prompt(picker)
  local directory = picker:dir()
  Snacks.input({ prompt = 'New: folder name or file.ext', default = '' }, function(name)
    if not name or vim.trim(name) == '' then return end
    local path, result = M.create(directory, name)
    if not path then
      vim.notify(result, vim.log.levels.WARN, { title = 'New item' })
      return
    end
    local tree = require('snacks.explorer.tree')
    tree:refresh(directory)
    tree:open(vim.fs.dirname(path))
    if not picker.closed then
      require('snacks.explorer.actions').update(picker, { target = path, refresh = true })
    end
  end)
end
return M
