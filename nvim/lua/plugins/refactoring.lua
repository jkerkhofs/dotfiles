return {
  -- The Refactoring library based off the Refactoring book by Martin Fowler
  'ThePrimeagen/refactoring.nvim',
  enabled = true,
  dependencies = {
    -- only required for Neovim 0.12
    'lewis6991/async.nvim',
  },
  -- Select a refactor via vim.ui.select for the selection (visual) or the current line (normal)
  keys = {
    { '<leader>A', function() require('refactoring').select_refactor() end, mode = 'x', desc = 'Select refactor' },
    {
      '<leader>A',
      "V<Cmd>lua require('refactoring').select_refactor()<CR>",
      mode = 'n',
      desc = 'Select refactor for current line',
    },
  },
  opts = {},
}
