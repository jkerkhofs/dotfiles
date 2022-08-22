local opt = { noremap = true, silent = true }

vim.api.nvim_set_keymap("n", "<A-left>", ":<C-U>ObviousResizeLeft 5<CR>", opt)
vim.api.nvim_set_keymap("n", "<A-down>", ":<C-U>ObviousResizeDown 5<CR>", opt)
vim.api.nvim_set_keymap("n", "<A-up>", ":<C-U>ObviousResizeUp 5<CR>", opt)
vim.api.nvim_set_keymap("n", "<A-right>", ":<C-U>ObviousResizeRight 5<CR>", opt)
