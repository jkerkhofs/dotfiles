return {
  {
    -- A Git wrapper so awesome, it should be illegal
    'tpope/vim-fugitive',
    enabled = true,
    cmd = { 'G', 'Git', 'Gdiffsplit', 'Gvdiffsplit', 'Gread', 'Gwrite', 'Ggrep', 'GMove', 'GDelete', 'GBrowse' },
  },
  {
    -- Git integration for buffers (signs, hunks, blame)
    'lewis6991/gitsigns.nvim',
    enabled = true,
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require('gitsigns')
        local function map(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Navigate hunks for the current buffer
        map('[g', function() gitsigns.nav_hunk('prev') end, 'Previous hunk')
        map(']g', function() gitsigns.nav_hunk('next') end, 'Next hunk')
        -- Show hunk diff at current position
        map('<leader>hg', gitsigns.preview_hunk, 'Preview hunk')
      end,
    },
  },
}
