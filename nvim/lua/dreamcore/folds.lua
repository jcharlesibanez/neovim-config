local M = {}

local class_nodes = {
  class_definition = true,          -- Python
  class_declaration = true,         -- JavaScript, TypeScript, Java, C#
  abstract_class_declaration = true,
  class = true,                     -- Ruby
}

local function class_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then return nil end
  local tree = parser:parse()[1]
  if not tree then return nil end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node do
    local kind = node:type()
    if class_nodes[kind] then return node end
    if kind == 'class_specifier' then
      local text = vim.treesitter.get_node_text(node, buf)
      if type(text) == 'string' and text:match('^%s*class%f[%W]') then return node end
    end
    node = node:parent()
  end
end

function M.toggle_class()
  local node = class_at_cursor()
  if not node then
    vim.notify('Put the cursor inside a class to fold it.', vim.log.levels.INFO, { title = 'Class fold' })
    return false
  end

  local start_row, _, end_row = node:range()
  local first, last = start_row + 1, end_row + 1
  vim.wo.foldmethod = 'manual'
  vim.wo.foldenable = true
  vim.api.nvim_win_set_cursor(0, { first, 0 })

  if vim.fn.foldlevel(first) == 0 then
    vim.cmd(('%d,%dfold'):format(first, last))
  elseif vim.fn.foldclosed(first) == -1 then
    vim.cmd('normal! zc')
  else
    vim.cmd('normal! zo')
  end
  return true
end

function M.setup()
  vim.api.nvim_create_user_command('FoldClass', M.toggle_class, { desc = 'Toggle the class under the cursor' })
  vim.keymap.set('n', '\\', M.toggle_class, { desc = 'Fold/unfold current class' })
end

return M
