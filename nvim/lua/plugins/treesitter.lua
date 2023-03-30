return {
  {
    -- Nvim Treesitter configurations and abstraction layer
    'nvim-treesitter/nvim-treesitter',
    enabled = true,
    version = false,
    build = ":TSUpdate",
    config = function()
      local status, treesitter_configs = pcall(require, "nvim-treesitter.configs")
      if (not status) then return end

      treesitter_configs.setup {
        ensure_installed = {
          'vim',
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
          enable = true,
          disable = {},
        },
        context_commentstring = {
          enable = true
        },
        autotag = {
          enable = true,
        }
      }
    end
  },
  {
    {
      -- Neovim treesitter plugin for setting the commentstring based on the cursor location in a file
      'JoosepAlviste/nvim-ts-context-commentstring',
      enabled = true,
      dependencies = { 'nvim-treesitter/nvim-treesitter' }
    },
  },
  {
    -- Use treesitter to auto close and auto rename html tag
    'windwp/nvim-ts-autotag',
    enabled = true,
    dependencies = { 'nvim-treesitter/nvim-treesitter' }
  },
}
