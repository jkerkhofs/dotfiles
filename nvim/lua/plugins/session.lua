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
    config = function()
      vim.g.prosession_dir = vim.fn.stdpath('config') .. '/session/'
    end
  }
}
