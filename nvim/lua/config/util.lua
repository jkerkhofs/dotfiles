local M = {}

-- Returns the current visual selection as a single line of text.
function M.get_visual_selection()
  vim.cmd('noau normal! "vy"')
  local text = vim.fn.getreg('v')
  vim.fn.setreg('v', {})

  text = string.gsub(text, '\n', '')
  return text
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
