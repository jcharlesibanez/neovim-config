local M = {}
local histories = {}

-- Tree-sitter uses slightly different names for the same ideas in each
-- language. These are complete structural blocks, rather than their bodies,
-- so folding an `if` also hides its attached `elif` and `else` clauses.
local foldable_nodes = {
  -- Classes and class-like containers
  class_definition = true,
  class_declaration = true,
  abstract_class_declaration = true,
  class_specifier = true,
  class = true,
  struct_specifier = true,
  interface_declaration = true,
  namespace_definition = true,

  -- Functions and methods
  function_definition = true,
  function_declaration = true,
  function_expression = true,
  method_definition = true,
  method_declaration = true,
  constructor_declaration = true,
  lambda_expression = true,
  arrow_function = true,

  -- Conditionals
  if_statement = true,
  unless = true,
  switch_statement = true,
  switch_expression = true,
  match_statement = true,
  case_statement = true,

  -- Loops
  for_statement = true,
  for_in_statement = true,
  foreach_statement = true,
  while_statement = true,
  do_statement = true,

  -- Other useful code blocks
  try_statement = true,
  try_expression = true,
  with_statement = true,
  synchronized_statement = true,
}

local function parser_tree(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then return nil end
  return parser:parse()[1]
end

local function enclosing_block(root, row, col)
  local node = root:named_descendant_for_range(row, col, row, col)
  while node do
    if foldable_nodes[node:type()] then return node end
    node = node:parent()
  end
end

-- C and C++ represent `else if` as an if_statement directly inside another
-- if_statement. Climb that direct chain so one press folds the entire chain,
-- while an if nested inside braces remains independently foldable.
local function whole_conditional_chain(node)
  if not node or node:type() ~= 'if_statement' then return node end
  while node:parent() and node:parent():type() == 'if_statement' do
    node = node:parent()
  end
  return node
end

local function nearest_block_above(root, row)
  local best, best_end, best_start

  local function visit(node)
    if foldable_nodes[node:type()] then
      local start_row, _, end_row = node:range()
      if end_row <= row then
        -- Prefer the block that finishes closest to the cursor. If nested
        -- blocks finish together, prefer the superior (outer) one.
        if not best or end_row > best_end or (end_row == best_end and start_row < best_start) then
          best, best_end, best_start = node, end_row, start_row
        end
      end
    end
    for child in node:iter_children() do visit(child) end
  end

  visit(root)
  return best
end

local function block_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local tree = parser_tree(buf)
  if not tree then return nil end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local line = vim.api.nvim_get_current_line()
  local first_code = line:find('%S')
  if first_code and col < first_code - 1 then col = first_code - 1 end
  local root = tree:root()
  local node = enclosing_block(root, row, col) or nearest_block_above(root, row)
  return whole_conditional_chain(node)
end

local function history_for_current_window()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  histories[win] = histories[win] or {}

  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local history = histories[win][buf]
  if not history or history.tick ~= tick then
    history = { tick = tick, entries = {} }
    histories[win][buf] = history
  end
  return history
end

function M.toggle()
  local node = block_at_cursor()
  if not node then return false end

  local start_row, _, end_row = node:range()
  local first, last = start_row + 1, end_row + 1
  if last <= first then return false end

  local original_cursor = vim.api.nvim_win_get_cursor(0)
  local history = history_for_current_window()
  vim.wo.foldmethod = 'manual'
  vim.wo.foldenable = true
  vim.api.nvim_win_set_cursor(0, { first, 0 })

  local previous_level = first > 1 and vim.fn.foldlevel(first - 1) or 0
  local action
  if vim.fn.foldclosed(first) == first then
    vim.cmd('normal! zo')
    action = 'opened'
  elseif vim.fn.foldlevel(first) > previous_level then
    vim.cmd('normal! zc')
    action = 'closed'
  else
    vim.cmd(('%d,%dfold'):format(first, last))
    action = 'created'
  end

  table.insert(history.entries, {
    action = action,
    first = first,
    cursor = original_cursor,
  })
  return true
end

local function undo_one_fold()
  local history = history_for_current_window()
  local entry = table.remove(history.entries)
  if not entry then return false end

  local line_count = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.min(entry.first, line_count), 0 })

  if entry.action == 'created' then
    vim.cmd('normal! zd')
  elseif entry.action == 'closed' then
    if vim.fn.foldclosed(entry.first) == entry.first then vim.cmd('normal! zo') end
  elseif entry.action == 'opened' then
    if vim.fn.foldclosed(entry.first) == -1 then vim.cmd('normal! zc') end
  end

  local cursor_line = math.min(entry.cursor[1], line_count)
  local max_col = #(vim.api.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1] or '')
  pcall(vim.api.nvim_win_set_cursor, 0, { cursor_line, math.min(entry.cursor[2], max_col) })
  return true
end

function M.undo()
  local remaining = vim.v.count1
  while remaining > 0 and undo_one_fold() do remaining = remaining - 1 end
  if remaining > 0 then vim.cmd(('normal! %du'):format(remaining)) end
end

function M.setup()
  vim.api.nvim_create_user_command('FoldBlock', M.toggle, { desc = 'Toggle the nearest code block' })
  -- Keep the old command working for muscle memory and external mappings.
  vim.api.nvim_create_user_command('FoldClass', M.toggle, { desc = 'Toggle the nearest code block' })
  vim.keymap.set('n', '\\', M.toggle, { desc = 'Fold/unfold nearest code block' })
  vim.keymap.set('n', 'u', M.undo, { desc = 'Undo fold or text change' })
end

return M
