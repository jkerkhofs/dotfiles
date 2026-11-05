-- Run the 'source.organizeImports' code action synchronously for all attached LSP clients that support it
local function organize_imports()
  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })) do
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { 'source.organizeImports' }, diagnostics = {} }
    local response = client:request_sync('textDocument/codeAction', params, 3000, bufnr)
    for _, action in ipairs(response and response.result or {}) do
      if not action.edit and client:supports_method('codeAction/resolve') then
        local resolved = client:request_sync('codeAction/resolve', action, 3000, bufnr)
        action = resolved and resolved.result or action
      end
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
      if action.command then
        local command = type(action.command) == 'table' and action.command or action
        client:request_sync('workspace/executeCommand', { command = command.command, arguments = command.arguments }, 3000,
          bufnr)
      end
    end
  end
end

local function format()
  require('conform').format({ async = true }, function(err)
    -- leave visual mode after a range format
    if not err and vim.startswith(vim.api.nvim_get_mode().mode:lower(), 'v') then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
    end
  end)
end

local prettier = { 'prettierd', 'prettier', stop_after_first = true }

return {
  -- Lightweight yet powerful formatter plugin for Neovim
  'stevearc/conform.nvim',
  enabled = true,
  cmd = 'ConformInfo',
  dependencies = {
    -- formatters are installed with mason
    'mason-org/mason.nvim',
  },
  keys = {
    { '<leader>f', format, mode = { 'n', 'x' }, desc = 'Format document or selection' },
    {
      '<leader>F',
      function()
        organize_imports()
        format()
      end,
      desc = 'Organize imports and format document',
    },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
  ---@module 'conform'
  ---@type conform.setupOpts
  opts = {
    formatters_by_ft = {
      javascript = prettier,
      javascriptreact = prettier,
      typescript = prettier,
      typescriptreact = prettier,
      html = prettier,
      htmlangular = prettier,
      css = prettier,
      scss = prettier,
      json = prettier,
      jsonc = prettier,
      yaml = prettier,
      markdown = prettier,
      lua = { 'stylua' },
      cs = { 'csharpier' },
    },
    -- no format on save: formatting is done manually with <leader>f
    default_format_opts = {
      lsp_format = 'fallback',
    },
    formatters = {
      prettierd = {
        env = {
          -- used when the project doesn't have a prettier config
          PRETTIERD_DEFAULT_CONFIG = vim.fs.joinpath(vim.fn.stdpath('config'), 'prettierrc.json'),
        },
      },
      prettier = {
        -- the print width is only used when the project doesn't have a prettier config
        prepend_args = { '--config-precedence', 'prefer-file', '--print-width', '100' },
      },
    },
  },
}
