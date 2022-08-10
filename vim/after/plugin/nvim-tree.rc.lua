local status_ok, nvim_tree = pcall(require, 'nvim-tree')
if not status_ok then
  return
end

local setKeymap = vim.keymap.set
local opts = { noremap = true, silent = true }

nvim_tree.setup({
  hijack_cursor = true,
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "l", action = "edit" },
        { key = "h", action = "close_node" },
        { key = "<esc>", action = "close" }
      }
    }
  },
  renderer = {
    highlight_opened_files = "name"
  },
  git = {
    enable = false -- enabling git causes lags on large git repos
  },
  diagnostics = {
    enable = true,
    show_on_dirs = true
  }
})

vim.cmd([[ highlight NvimTreeOpenedFile gui=bold ]])

setKeymap('n', '<leader>e', ':NvimTreeFindFile<cr>', opts)
