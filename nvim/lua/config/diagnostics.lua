local severity = vim.diagnostic.severity

vim.diagnostic.config({
  severity_sort = true,
  -- virtual text is disabled by default since Neovim 0.11
  virtual_text = true,
  float = { border = 'rounded', source = 'if_many' },
  signs = {
    text = {
      [severity.ERROR] = 'E',
      [severity.WARN] = 'W',
      [severity.INFO] = 'I',
      [severity.HINT] = 'H',
    },
  },
})
