return {
  {
    -- Find, Filter, Preview, Pick. All lua, all the time
    'nvim-telescope/telescope.nvim',
    enabled = true,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim'
    },
    config = function()
      local status, telescope = pcall(require, "telescope")
      if (not status) then return end

      local actions = require('telescope.actions')
      local builtin = require('telescope.builtin')
      local utils = require('telescope.utils')

      local setKeymap = vim.keymap.set
      local opts = { noremap = true, silent = true }

      function vim.getVisualSelection()
        vim.cmd('noau normal! "vy"')
        local text = vim.fn.getreg('v')
        vim.fn.setreg('v', {})

        text = string.gsub(text, "\n", "")
        if #text > 0 then
          return text
        else
          return ''
        end
      end

      function vim.getVisualSelectionForFilename()
        local selection = vim.getVisualSelection()
        -- replace all forward slashes with backslashes
        selection = selection:gsub("/", "\\")
        -- prepend a single quote for doing an exact match (fzf)
        return "'" .. selection
      end

      telescope.setup {
        defaults = {
          mappings = {
            i = {
              ["<esc>"] = actions.close
            },
          },
          layout_strategy = 'vertical',
          layout_config = { height = 0.95 }
        },
        pickers = {
          buffers = {
            mappings = {
              i = {
                ["<del>"] = actions.delete_buffer
              }
            }
          }
        }
      }

      telescope.load_extension('fzf')

      setKeymap('n', '<leader><Space>', ':Telescope find_files<cr>', opts)
      setKeymap('n', '<c-p>', ':Telescope find_files<cr>', opts)
      setKeymap('n', '<leader>b', ':Telescope buffers<cr>', opts)
      setKeymap('n', '<leader>p', ':Telescope registers<cr>', opts)
      setKeymap('n', '<leader>g', ':Telescope live_grep<cr>', opts)
      setKeymap('n', '<leader>G', ':Telescope git_status<cr>', opts)
      setKeymap('n', '<leader>m', ':Telescope marks<cr>', opts)
      setKeymap('n', '<space><space>', ':Telescope resume<cr>', opts)

      -- Find files based on selection.
      setKeymap('v', '<leader><Space>',
        function() builtin.find_files({ default_text = vim.getVisualSelectionForFilename() }) end, opts)

      -- Live grep based on selection.
      setKeymap('v', '<leader>g', function() builtin.live_grep({ default_text = vim.getVisualSelection() }) end, opts)

      -- Find (other) files relative to current buffer
      setKeymap('n', '<leader>o', function()
        builtin.find_files({
          cwd = utils.buffer_dir(),
          find_command = { 'rg', '--files', '--max-depth=1' },
          prompt_title = 'Find Other Files | at the same level as the current buffer'
        })
      end, opts)
    end
  },
  {
    -- FZF sorter for telescope written in c
    'nvim-telescope/telescope-fzf-native.nvim',
    enabled = true,
    build = 'make',
    dependencies = { 'nvim-telescope/telescope.nvim' }
  },
  {
    -- Coc integration for telescope.nvim
    'fannheyward/telescope-coc.nvim',
    enabled = true,
    dependencies = { 'nvim-telescope/telescope.nvim', 'neoclide/coc.nvim' }
  }
}
