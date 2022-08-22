vim.g.openbrowser_format_message = { msg = "" }
vim.api.nvim_set_keymap( "n", "gx", "<Plug>(openbrowser-smart-search)", { noremap = true })
vim.api.nvim_set_keymap( "v", "gx", "<Plug>(openbrowser-smart-search)", { noremap = true })
