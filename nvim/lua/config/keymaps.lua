local map = vim.keymap.set

-- Comment lines with the builtin commenting (see :h commenting)
map('n', '<leader>/', 'gcc', { remap = true, desc = 'Toggle comment line' })
map('x', '<leader>/', 'gc', { remap = true, desc = 'Toggle comment selection' })

-- Search the word under the cursor on devdocs.io
map('n', 'gH', function()
  vim.ui.open('https://devdocs.io/#q=' .. vim.uri_encode(vim.fn.expand('<cword>')))
end, { desc = 'Search word on devdocs' })
