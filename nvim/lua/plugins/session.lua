return {
  {
    -- Continuously updated session files
    'tpope/vim-obsession',
    enabled = true
  },
  {
    -- Handle vim sessions like a pro
    'dhruvasagar/vim-prosession',
    enabled = true,
    dependencies = { 'tpope/vim-obsession' },
    init = function()
      -- must be set before the plugin is loaded
      vim.g.prosession_dir = vim.fn.stdpath('state') .. '/sessions/'
    end
  }
}
