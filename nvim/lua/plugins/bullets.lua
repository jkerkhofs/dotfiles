return {
  -- A Vim/NeoVim plugin for automated bullet lists
  'dkarter/bullets.vim',
  enabled = true,
  config = function()
    vim.g.bullets_outline_levels = { 'num', 'abc', 'std-' }
    vim.g.bullets_checkbox_markers = ' x'
  end
}
