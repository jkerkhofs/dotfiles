-- Language servers installed by mason-tool-installer and enabled by mason-lspconfig (via vim.lsp.enable)
local servers = {
  -- web
  'vtsls',
  'angularls',
  'eslint',
  'html',
  'cssls',
  'emmet_language_server',
  -- config files
  'jsonls',
  'yamlls',
  'taplo',
  'lemminx',
  'marksman',
  -- other
  'lua_ls',
  'powershell_es',
}

-- Formatters, linters and other tools installed by mason
local tools = {
  'prettierd',
  'stylua',
  'csharpier',
  'markdownlint-cli2',
  -- C# language server, used by roslyn.nvim
  'roslyn',
}

return {
  {
    -- Portable package manager for LSP servers, formatters and linters
    'mason-org/mason.nvim',
    enabled = true,
    cmd = 'Mason',
    opts = {
      registries = {
        'github:mason-org/mason-registry',
        -- roslyn language server (C#)
        'github:Crashdummyy/mason-registry',
      },
    },
  },
  {
    -- Quickstart configs for the builtin LSP client
    'neovim/nvim-lspconfig',
    enabled = true,
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'mason-org/mason.nvim',
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      -- JSON/YAML schemas from SchemaStore.org
      'b0o/SchemaStore.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })

      vim.lsp.config('vtsls', {
        settings = {
          vtsls = { autoUseWorkspaceTsdk = true },
          typescript = {
            preferences = { importModuleSpecifier = 'project-relative' },
          },
          javascript = {
            preferences = { importModuleSpecifier = 'project-relative' },
          },
        },
      })

      -- also provide HTML completion and hover in Angular templates
      vim.lsp.config('html', {
        filetypes = { 'html', 'htmlangular' },
      })

      -- only start in Angular workspaces (angular.json or nx.json)
      vim.lsp.config('angularls', {
        workspace_required = true,
      })

      vim.lsp.config('jsonls', {
        settings = {
          json = {
            schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config('yamlls', {
        settings = {
          yaml = {
            -- use the schemas from SchemaStore.nvim instead of the builtin schemaStore support
            schemaStore = { enable = false, url = '' },
            schemas = require('schemastore').yaml.schemas(),
          },
        },
      })

      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            telemetry = { enable = false },
            hint = { enable = false },
          },
        },
      })

      require('mason-lspconfig').setup({
        automatic_enable = {
          -- stylua is used as formatter via conform.nvim
          exclude = { 'stylua' },
        },
      })

      -- all mason packages in one list, so :MasonToolsUpdate also updates the language servers
      require('mason-tool-installer').setup({
        ensure_installed = vim.list_extend(vim.deepcopy(servers), tools),
        -- :UpdateAll installs and updates the packages itself
        run_on_start = not vim.g.update_all,
      })

      -- Remove the default LSP mappings starting with `gr` so `gr` (references) doesn't wait for 'timeoutlen'
      for _, map in ipairs({
        { 'n', 'grn' }, { 'n', 'grr' }, { 'n', 'gri' }, { 'n', 'grt' }, { 'n', 'grx' },
        { 'n', 'gra' }, { 'x', 'gra' },
      }) do
        pcall(vim.keymap.del, map[1], map[2])
      end

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('LspKeymaps', { clear = true }),
        callback = function(ev)
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
          end
          local function hover()
            vim.lsp.buf.hover({ border = 'rounded' })
          end

          -- GoTo code navigation
          map('n', 'gd', function() Snacks.picker.lsp_definitions() end, 'Go to definition')
          map('n', 'gy', function() Snacks.picker.lsp_type_definitions() end, 'Go to type definition')
          map('n', 'gi', function() Snacks.picker.lsp_implementations() end, 'Go to implementation')
          map('n', 'gr', function() Snacks.picker.lsp_references() end, 'References')

          -- Use K or gh to show documentation
          map('n', 'K', hover, 'Show documentation')
          map('n', 'gh', hover, 'Show documentation')

          map('n', '<leader>r', vim.lsp.buf.rename, 'Rename')
          map({ 'n', 'x' }, '<leader>a', vim.lsp.buf.code_action, 'Code action')

          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.name == 'eslint' then
            map('n', '<leader>ce', function() vim.cmd('LspEslintFixAll') end, 'Fix all ESLint problems')
          end
        end,
      })
    end,
  },
  {
    -- Configures LuaLS for editing the Neovim config
    'folke/lazydev.nvim',
    enabled = true,
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = 'snacks.nvim', words = { 'Snacks' } },
      },
    },
  },
}
