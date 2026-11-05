return {
  -- Roslyn language server (C#) integration, the successor of OmniSharp
  'seblyng/roslyn.nvim',
  enabled = true,
  ft = 'cs',
  dependencies = {
    -- the roslyn server is installed with mason (Crashdummyy registry)
    'mason-org/mason.nvim',
  },
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {},
  config = function(_, opts)
    vim.lsp.config('roslyn', {
      settings = {
        ['csharp|inlay_hints'] = {
          csharp_enable_inlay_hints_for_implicit_object_creation = true,
          csharp_enable_inlay_hints_for_implicit_variable_types = true,
        },
        ['csharp|code_lens'] = {
          dotnet_enable_references_code_lens = true,
        },
      },
    })
    require('roslyn').setup(opts)
  end,
}
