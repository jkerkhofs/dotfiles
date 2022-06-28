if not vim.g.loaded_telescope then
  return
end

local opts = { noremap = true, silent = true }
local actions = require('telescope.actions')

vim.api.nvim_set_keymap('n', '<leader><Space>', '<cmd>Telescope find_files<cr>', opts)
vim.api.nvim_set_keymap('n', '<leader>b', '<cmd>Telescope buffers<cr>', opts)
vim.api.nvim_set_keymap('n', '<leader>p', '<cmd>Telescope registers<cr>', opts)
vim.api.nvim_set_keymap('n', '<leader>gg', '<cmd>Telescope live_grep<cr>', opts)

require('telescope').setup{
  defaults = {
    mappings = {
      i = {
        ["<esc>"] = actions.close
      },
    },
    layout_strategy = 'vertical',
    layout_config = { height = 0.95 }
  },
  pickers = {
    buffers = {
      mappings = {
        i = {
          ["<del>"] = actions.delete_buffer
        }
      }
    }
  }
}

require('telescope').load_extension('fzf')
