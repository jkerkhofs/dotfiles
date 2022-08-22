if not vim.g.loaded_commentary then return end

vim.api.nvim_set_keymap("n", "<leader>/", "gcc", {})
vim.api.nvim_set_keymap("v", "<leader>/", "gc", {})
