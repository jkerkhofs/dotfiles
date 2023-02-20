return {
  -- Comment stuff out
  'tpope/vim-commentary',
  enabled = true,
  config = function()
    vim.api.nvim_set_keymap("n", "<leader>/", "gcc", {})
    vim.api.nvim_set_keymap("v", "<leader>/", "gc", {})
  end
}
