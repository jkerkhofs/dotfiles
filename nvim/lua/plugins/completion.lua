return {
  -- Performant, batteries-included completion plugin
  'saghen/blink.cmp',
  enabled = true,
  -- use a release tag to download the prebuilt fuzzy matcher binary
  version = '1.*',
  event = { 'InsertEnter', 'CmdlineEnter' },
  dependencies = {
    -- Set of preconfigured snippets for different languages
    'rafamadriz/friendly-snippets',
  },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      -- <CR> accepts the selected item
      preset = 'enter',
      -- Use tab and shift tab to go through the completion list and jump through snippets
      ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
    },
    completion = {
      -- don't select the first item, so <CR> only accepts after selecting an item
      list = { selection = { preselect = false, auto_insert = true } },
      documentation = { auto_show = true },
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
      per_filetype = {
        -- Neovim API completions are only useful in Lua files
        lua = { inherit_defaults = true, 'lazydev' },
      },
      providers = {
        lazydev = {
          name = 'LazyDev',
          module = 'lazydev.integrations.blink',
          -- make lazydev completions top priority (see `:h blink.cmp`)
          score_offset = 100,
        },
      },
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
