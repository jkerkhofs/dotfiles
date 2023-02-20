return {
  -- Open URI with your favorite browser from your most favorite editor
  'tyru/open-browser.vim',
  enabled = true,
  config = function()
    vim.g.openbrowser_format_message = { msg = "" }
    vim.api.nvim_set_keymap("n", "gx", "<Plug>(openbrowser-smart-search)", { noremap = true })
    vim.api.nvim_set_keymap("v", "gx", "<Plug>(openbrowser-smart-search)", { noremap = true })
    vim.api.nvim_set_keymap("n", "gH", "<Cmd>execute 'OpenBrowserSearch -devdocs' expand('<cword>')<CR>",
      { noremap = true })
  end
}
