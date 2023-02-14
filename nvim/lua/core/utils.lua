local M = {}

M.termcodes = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

M.check_back_space = function()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return (col == 0 or vim.api.nvim_get_current_line():sub(col, col):match "%s") and true
end

return M
