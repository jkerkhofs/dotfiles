return {
  -- The Refactoring library based off the Refactoring book by Martin Fowler
  'ThePrimeagen/refactoring.nvim',
  enabled = true,
  lazy = false,
  dependencies = {
    -- only required for Neovim 0.12
    'lewis6991/async.nvim',
  },
  config = function()
    local ok, refactoring = pcall(require, 'refactoring')
    if not ok then return end

    refactoring.setup({})

    -- Select a refactor via vim.ui.select for the selection (visual) or the current line (normal)
    vim.keymap.set('x', '<leader>A', function()
      refactoring.select_refactor()
    end, { desc = 'Select refactor' })
    vim.keymap.set('n', '<leader>A', "V<Cmd>lua require('refactoring').select_refactor()<CR>",
      { desc = 'Select refactor for current line' })
  end,
}
