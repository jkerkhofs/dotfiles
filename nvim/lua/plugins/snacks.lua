return {
  -- A collection of QoL plugins for Neovim (picker, explorer, lazygit, notifier, ...)
  'folke/snacks.nvim',
  enabled = true,
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    input = { enabled = true },
    notifier = { enabled = true },
    lazygit = { enabled = true },
    explorer = { enabled = true, replace_netrw = true },
    picker = {
      enabled = true,
      ui_select = true,
      layout = { preset = 'vertical', layout = { height = 0.95 } },
      win = {
        input = {
          keys = {
            ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
            ['<C-x>'] = { 'edit_split', mode = { 'n', 'i' } },
          },
        },
        list = {
          keys = {
            ['<C-x>'] = 'edit_split',
          },
        },
      },
      sources = {
        buffers = {
          win = {
            input = {
              keys = {
                ['<Del>'] = { 'bufdelete', mode = { 'n', 'i' } },
              },
            },
          },
        },
        explorer = {
          win = {
            list = {
              keys = {
                ['<C-x>'] = 'edit_split',
                ['<C-v>'] = 'edit_vsplit',
                ['<C-t>'] = 'tab',
              },
            },
          },
        },
      },
    },
  },
  keys = {
    -- Pickers
    { '<leader><Space>', function() Snacks.picker.files() end, desc = 'Find files' },
    { '<C-p>', function() Snacks.picker.files() end, desc = 'Find files' },
    { '<leader>b', function() Snacks.picker.buffers() end, desc = 'Buffers' },
    { '<leader>p', function() Snacks.picker.registers() end, desc = 'Registers' },
    { '<leader>m', function() Snacks.picker.marks() end, desc = 'Marks' },
    { '<leader>g', function() Snacks.picker.grep() end, desc = 'Grep' },
    { '<leader>G', function() Snacks.picker.git_status() end, desc = 'Git status' },
    { '<leader>k', function() Snacks.picker.keymaps() end, desc = 'Keymaps' },
    { '<Space><Space>', function() Snacks.picker.resume() end, desc = 'Resume last picker' },
    { '<leader>C', function() Snacks.picker.commands() end, desc = 'Commands' },
    { '<leader>cd', function() Snacks.picker.diagnostics() end, desc = 'Diagnostics' },
    {
      '<leader>o',
      function()
        Snacks.picker.files({
          title = 'Find Other Files | at the same level as the current buffer',
          cwd = vim.fn.expand('%:p:h'),
          args = { '--max-depth', '1' },
        })
      end,
      desc = 'Find other files next to the current buffer',
    },
    {
      '<leader>vn',
      function() Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end,
      desc = 'Neovim config files',
    },
    -- Find files based on selection
    {
      '<leader><Space>',
      function() Snacks.picker.files({ pattern = require('config.util').get_visual_selection_for_filename() }) end,
      mode = 'x',
      desc = 'Find files with selection',
    },
    -- Grep based on selection
    {
      '<leader>g',
      function() Snacks.picker.grep({ search = require('config.util').get_visual_selection() }) end,
      mode = 'x',
      desc = 'Grep selection',
    },
    -- Explorer
    { '<leader>e', function() Snacks.explorer() end, desc = 'Explorer' },
    -- Lazygit
    { '<leader>lg', function() Snacks.lazygit() end, desc = 'Lazygit' },
  },
}
