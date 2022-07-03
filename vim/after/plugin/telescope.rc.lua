if not vim.g.loaded_telescope then
  return
end

local setKeymap = vim.keymap.set
local opts = { noremap = true, silent = true }
local actions = require('telescope.actions')
local tb = require('telescope.builtin')

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

setKeymap('n', '<leader><Space>', ':Telescope find_files<cr>', opts)
setKeymap('n', '<leader>b', ':Telescope buffers<cr>', opts)
setKeymap('n', '<leader>p', ':Telescope registers<cr>', opts)
setKeymap('n', '<leader>g', ':Telescope live_grep<cr>', opts)

-- Find files based on selection.
-- Uses single quote prefix for an exact match (fzf) and replaces all forward slashes with backslashes for path-matching.
setKeymap('v', '<leader><Space>', function() tb.find_files({ default_text = "'" .. vim.getVisualSelection():gsub("/", "\\") }) end, opts)

-- Live grep based on selection.
setKeymap('v', '<leader>g', function() tb.live_grep({ default_text = vim.getVisualSelection() }) end, opts)

require('telescope').setup{
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

require('telescope').load_extension('fzf')
