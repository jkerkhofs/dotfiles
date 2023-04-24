return {
  -- Comfortable & Pleasant Color Scheme for Vim
  'sainnhe/everforest',
  enabled = true,
  lazy = false,
  config = function()
    vim.g.everforest_better_performance = 1
    vim.g.everforest_background = 'medium'
    vim.g.everforest_transparent_background = 1
    vim.cmd.colorscheme 'everforest'
  end
}
