if not vim.g.loaded_telescope then
  return
end

local setKeymap = vim.keymap.set
local opts = { noremap = true, silent = true }
local telescope = require('telescope')
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

function vim.getVisualSelectionForFilename()
  local selection = vim.getVisualSelection()
  -- replace all forward slashes with backslashes
  selection = selection:gsub("/", "\\")
  -- prepend a single quote for doing an exact match (fzf)
  return "'" .. selection
end

setKeymap('n', '<leader><Space>', ':Telescope find_files<cr>', opts)
setKeymap('n', '<leader>b', ':Telescope buffers<cr>', opts)
setKeymap('n', '<leader>p', ':Telescope registers<cr>', opts)
setKeymap('n', '<leader>g', ':Telescope live_grep<cr>', opts)
setKeymap('n', 'gr', ':Telescope coc references path_display={\'tail\'}<cr>', opts)
-- path_display='smart' ATM only checks for forward slashes in path instead of OS-specific path seperator.
-- setKeymap('n', 'gr', ':Telescope coc references path_display={\'smart\'}<cr>', opts)

-- Find files based on selection.
setKeymap('v', '<leader><Space>', function() tb.find_files({ default_text = vim.getVisualSelectionForFilename() }) end, opts)

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

telescope.load_extension('fzf')
telescope.load_extension('coc')
