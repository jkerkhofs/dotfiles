return {
  -- The Refactoring library based off the Refactoring book by Martin Fowler
  'ThePrimeagen/refactoring.nvim',
  enabled = true,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    local status_refactoring, refactoring = pcall(require, "refactoring")
    local status_telescope, telescope = pcall(require, "telescope")
    if not (status_refactoring or status_telescope) then return end

    refactoring.setup({})

    -- load refactoring Telescope extension
    telescope.load_extension("refactoring")

    -- remap to open the Telescope refactoring menu in visual mode
    vim.api.nvim_set_keymap(
      "v",
      "<leader>A",
      "<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>",
      { noremap = true }
    )

    vim.api.nvim_set_keymap(
      "n",
      "<leader>A",
      "V<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>",
      { noremap = true }
    )
  end
}
