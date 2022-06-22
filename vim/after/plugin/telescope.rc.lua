if not vim.g.loaded_telescope then
  return
end

local opts = { noremap = true, silent = true }
local actions = require('telescope.actions')

vim.api.nvim_set_keymap("n", "<Leader><Space>", "<cmd>lua require'telescope-config'.project_files()<cr>", opts)
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
