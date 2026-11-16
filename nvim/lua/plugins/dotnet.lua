-- project files are 'xml' buffers, only these have easy-dotnet support (package completion and mappings)
local project_files = '*.csproj,*.fsproj,Directory.Build.props,Directory.Packages.props'

-- <leader>n mapping for a :Dotnet command
local function dotnet(key, args, desc)
  return { '<leader>n' .. key, '<Cmd>Dotnet ' .. args .. '<CR>', desc = desc }
end

return {
  -- .NET development: Roslyn LSP (with Roslynator and Razor), test runner, debugger, NuGet and project commands
  'GustavEikaas/easy-dotnet.nvim',
  enabled = true,
  ft = { 'cs', 'razor', 'fsharp' },
  event = { 'BufReadPre ' .. project_files, 'BufNewFile ' .. project_files },
  cmd = 'Dotnet',
  keys = {
    -- test runner (the buffer mappings in test files are configured in test_runner.mappings)
    { '<leader>tt', '<Cmd>Dotnet testrunner<CR>', desc = 'Toggle test runner' },
    { '<leader>ta', '<Cmd>Dotnet test solution<CR>', desc = 'Run all tests in the solution' },
    -- .NET actions
    dotnet('b', 'build', 'Build project'),
    dotnet('B', 'build solution', 'Build solution'),
    dotnet('q', 'build quickfix', 'Build project, errors in quickfix'),
    dotnet('r', 'run', 'Run project'),
    dotnet('p', 'run profile', 'Run project with launch profile'),
    dotnet('w', 'watch', 'Watch project'),
    dotnet('t', 'test', 'Test project'),
    dotnet('R', 'restore', 'Restore'),
    dotnet('c', 'clean', 'Clean'),
    dotnet('N', 'new', 'New project from template'),
    dotnet('a', 'add package', 'Add NuGet package'),
    dotnet('x', 'remove package', 'Remove NuGet package'),
    dotnet('o', 'outdated', 'Outdated NuGet packages'),
    dotnet('s', 'secrets', 'Edit user secrets'),
    dotnet('d', 'diagnostic', 'Workspace diagnostics'),
    dotnet('S', 'solution select', 'Select solution'),
    dotnet('T', 'terminal toggle', 'Toggle terminal'),
    {
      '<leader>ni',
      function() require('easy-dotnet').create_item(vim.fn.expand('%:p:h')) end,
      desc = 'New item next to the current file',
    },
  },
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
    debugger = {
      -- registers the netcoredbg adapter and the C# configuration with nvim-dap
      auto_register_dap = true,
      -- the CPU and memory graphs are nvim-dap-ui elements, nvim-dap-view is used instead
      mem_cpu_usage = false,
    },
    test_runner = {
      -- buffer mappings in test files under <leader>t; the defaults override <leader>r (rename) and <leader>d (debug)
      mappings = {
        run_test_from_buffer = { lhs = '<leader>tr', desc = 'Run test' },
        debug_test_from_buffer = { lhs = '<leader>td', desc = 'Debug test' },
        run_all_tests_from_buffer = { lhs = '<leader>tf', desc = 'Run all tests in file' },
        peek_stack_trace_from_buffer = { lhs = '<leader>tp', desc = 'Peek test output' },
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
