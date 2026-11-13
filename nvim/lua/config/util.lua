local M = {}

-- Returns the current visual selection as a single line of text (without touching any register).
function M.get_visual_selection()
  local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() })
  -- leave visual mode, like a yank would
  vim.cmd('normal! ' .. vim.keycode('<Esc>'))
  return table.concat(lines, '')
end

-- Returns the current visual selection as an exact match (fzf syntax) for a filename.
function M.get_visual_selection_for_filename()
  local selection = M.get_visual_selection()
  if vim.fn.has('win32') == 1 then
    -- file paths use backslashes on Windows
    selection = selection:gsub('/', '\\')
  end
  -- prepend a single quote for doing an exact match (fzf)
  return "'" .. selection
end

return M
