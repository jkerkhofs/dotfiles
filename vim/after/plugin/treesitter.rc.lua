if not vim.g.loaded_nvim_treesitter then
  print("Treesitter is not loaded")
  return
end

local ts = require 'nvim-treesitter.configs'
ts.setup {
  ensure_installed = 'maintained', 
  highlight = {
    enable = true
  },
  context_commentstring = {
    enable = true
  }
}
