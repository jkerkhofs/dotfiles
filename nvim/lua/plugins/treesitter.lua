local parsers = {
  'angular',
  'bash',
  'c_sharp',
  'comment',
  'css',
  'dockerfile',
  'gitignore',
  'graphql',
  'html',
  'http',
  'javascript',
  'jsdoc',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'powershell',
  'regex',
  'scss',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'xml',
  'yaml',
}

return {
  {
    -- Nvim Treesitter configurations and abstraction layer (main branch: parser and query manager)
    'nvim-treesitter/nvim-treesitter',
    enabled = true,
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    init = function()
      -- tree-sitter-cli compiles parsers with MSVC (cl.exe) on Windows by default; fall back to gcc
      if vim.fn.has('win32') == 1 and not vim.env.CC and vim.fn.executable('cl') == 0 and vim.fn.executable('gcc') == 1 then
        vim.env.CC = 'gcc'
      end
    end,
    config = function()
      local treesitter = require('nvim-treesitter')
      treesitter.install(parsers)

      -- Enable treesitter highlighting and indentation for every filetype with an available parser
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterStart', { clear = true }),
        callback = function(ev)
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    -- Syntax aware text-objects, select, move, swap, and peek support
    'nvim-treesitter/nvim-treesitter-textobjects',
    enabled = true,
    branch = 'main',
    event = 'VeryLazy',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup({
        select = { lookahead = true },
      })

      local select = require('nvim-treesitter-textobjects.select')
      local textobjects = {
        af = { '@function.outer', 'Around function' },
        ['if'] = { '@function.inner', 'Inside function' },
        ac = { '@class.outer', 'Around class' },
        ic = { '@class.inner', 'Inside class' },
      }
      for lhs, textobject in pairs(textobjects) do
        vim.keymap.set({ 'x', 'o' }, lhs, function()
          select.select_textobject(textobject[1], 'textobjects')
        end, { desc = textobject[2] })
      end
    end,
  },
  {
    -- Use treesitter to auto close and auto rename html tag
    'windwp/nvim-ts-autotag',
    enabled = true,
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
}
