if not vim.g.loaded_telescope then
  return
end

local opts = { noremap = true, silent = false }
local actions = require('telescope.actions')

vim.api.nvim_set_keymap('n', '<leader><space>', '<cmd>Telescope find_files<cr>', opts)
vim.api.nvim_set_keymap('n', '<leader>b', '<cmd>Telescope buffers<cr>', opts)
vim.api.nvim_set_keymap('n', '<leader>p', '<cmd>Telescope registers<cr>', opts)

-- close telescope after first esc
require('telescope').setup{
  defaults = {
    file_ignore_patterns = {"node_modules"},
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<del>"] = actions.delete_buffer
      },
    },
  }
}
