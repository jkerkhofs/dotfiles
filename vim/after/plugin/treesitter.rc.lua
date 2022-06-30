if not vim.g.loaded_nvim_treesitter then
  print("Treesitter is not loaded")
  return
end

local ts = require 'nvim-treesitter.configs'
ts.setup {
  ensure_installed = {
    'bash',
    'c_sharp',
    'comment',
    'css',
    'graphql',
    'help',
    'html',
    'http',
    'javascript',
    'jsdoc',
    'json',
    'lua',
    'markdown',
    'markdown_inline',
    'regex',
    'scss',
    'toml',
    'tsx',
    'typescript',
    'yaml'
  },
  highlight = {
    enable = true
  },
  context_commentstring = {
    enable = true
  },
  autotag = {
    enable = true,
  }
}
