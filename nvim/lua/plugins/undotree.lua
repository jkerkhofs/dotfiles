return {
  -- The undo history visualizer for VIM
  'mbbill/undotree',
  enabled = true,
  config = function()
    vim.api.nvim_set_keymap(
      "n",
      "<leader>u",
      ":UndotreeToggle<CR>",
      { noremap = true, silent = true, }
    )
  end
}
