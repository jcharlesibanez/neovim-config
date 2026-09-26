local M = {}

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

function M.toggle()
  local node = block_at_cursor()
  if not node then return false end

  local start_row, _, end_row = node:range()
  local first, last = start_row + 1, end_row + 1
  if last <= first then return false end

  vim.wo.foldmethod = 'manual'
  vim.wo.foldenable = true
  vim.api.nvim_win_set_cursor(0, { first, 0 })

  local previous_level = first > 1 and vim.fn.foldlevel(first - 1) or 0
  if vim.fn.foldclosed(first) == first then
    vim.cmd('normal! zo')
  elseif vim.fn.foldlevel(first) > previous_level then
    vim.cmd('normal! zc')
  else
    vim.cmd(('%d,%dfold'):format(first, last))
  end
  return true
end

function M.setup()
  vim.api.nvim_create_user_command('FoldBlock', M.toggle, { desc = 'Toggle the nearest code block' })
  -- Keep the old command working for muscle memory and external mappings.
  vim.api.nvim_create_user_command('FoldClass', M.toggle, { desc = 'Toggle the nearest code block' })
  vim.keymap.set('n', '\\', M.toggle, { desc = 'Fold/unfold nearest code block' })
end

return M
