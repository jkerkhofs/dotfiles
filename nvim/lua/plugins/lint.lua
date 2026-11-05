return {
  -- An asynchronous linter plugin for Neovim complementary to the built-in LSP support
  'mfussenegger/nvim-lint',
  enabled = true,
  event = { 'BufWritePost', 'InsertLeave' },
  dependencies = {
    -- linters are installed with mason
    'mason-org/mason.nvim',
  },
  config = function()
    local lint = require('lint')
    lint.linters_by_ft = {
      markdown = { 'markdownlint-cli2' },
    }

    vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
      group = vim.api.nvim_create_augroup('Lint', { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
