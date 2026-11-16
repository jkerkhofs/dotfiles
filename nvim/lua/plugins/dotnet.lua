-- project files are 'xml' buffers, only these have easy-dotnet support (package completion and mappings)
local project_files = '*.csproj,*.fsproj,Directory.Build.props,Directory.Packages.props'

return {
  -- .NET development: Roslyn LSP (with Roslynator and Razor), test runner, debugger, NuGet and project commands
  'GustavEikaas/easy-dotnet.nvim',
  enabled = true,
  ft = { 'cs', 'razor', 'fsharp' },
  event = { 'BufReadPre ' .. project_files, 'BufNewFile ' .. project_files },
  cmd = 'Dotnet',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'folke/snacks.nvim',
    'mfussenegger/nvim-dap',
  },
  ---@module 'easy-dotnet'
  ---@type easy-dotnet.Options
  opts = {
    picker = 'snacks',
    lsp = {
      -- the roslyn-language-server dotnet tool is installed by easy-dotnet and updated by :UpdateAll
      enabled = true,
      roslynator_enabled = true,
      -- needed for enhanced_rename and create_type_from_usage
      easy_dotnet_extension_enabled = true,
      -- also rename the file when renaming a class
      enhanced_rename = true,
      -- code action to create a class from an unresolved symbol in a separate file
      create_type_from_usage = true,
      config = {
        settings = {
          ['csharp|inlay_hints'] = {
            -- the type hints below are only shown when this one is enabled
            csharp_enable_inlay_hints_for_types = true,
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
          },
          ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
          },
        },
      },
    },
  },
  config = function(_, opts)
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('EasyDotnetAttach', { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'easy_dotnet' then return end

        -- codelens is enabled by easy-dotnet itself (lsp.auto_refresh_codelens)
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf, client_id = client.id })
      end,
    })
    require('easy-dotnet').setup(opts)
  end,
}
