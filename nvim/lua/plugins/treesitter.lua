local status, treesitter_configs = pcall(require, "nvim-treesitter.configs")
if (not status) then return end

treesitter_configs.setup {
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
