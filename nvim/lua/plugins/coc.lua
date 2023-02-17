vim.g.coc_global_extensions = {
    'coc-tsserver',
    'coc-eslint',
    'coc-prettier',
    'coc-angular',
    'coc-html',
    'coc-emmet',
    'coc-css',
    'coc-json',
    'coc-yaml',
    'coc-git',
    'coc-sumneko-lua',
    'coc-snippets',
    'coc-explorer',
    'coc-markdownlint',
    'coc-powershell',
}

-- Use tab and shift tab to jump through snippet
vim.g.coc_snippet_next = '<TAB>'
vim.g.coc_snippet_prev = '<S-TAB>'

local ShowDocumentation = function()
  if vim.fn.index({ "vim", "help" }, vim.bo.filetype) >= 0 then
    vim.cmd("h " .. vim.fn.expand "<cword>")
  elseif vim.fn["coc#rpc#ready"]() then
    vim.fn.CocActionAsync "doHover"
  else
    vim.cmd("!" .. vim.o.keywordprg .. " " .. vim.fn.expand "<cword>")
  end
end

-- Highlight the symbol and its references on a CursorHold event(cursor is idle)
vim.api.nvim_create_augroup("CocGroup", {})
vim.api.nvim_create_autocmd("CursorHold", {
    group = "CocGroup",
    command = "silent call CocActionAsync('highlight')",
    desc = "Highlight symbol under cursor on CursorHold"
})

-- Setup formatexpr specified filetype(s)
vim.api.nvim_create_autocmd("FileType", {
    group = "CocGroup",
    pattern = "typescript,json",
    command = "setl formatexpr=CocAction('formatSelected')",
    desc = "Setup formatexpr specified filetype(s)."
})

-- " Map <tab> for trigger completion, completion confirm, snippet expand and jump like VSCode
vim.cmd [[
  inoremap <silent><expr> <TAB>
        \ coc#pum#visible() ? coc#_select_confirm() :
        \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
        \ CheckBackspace() ? "\<TAB>" :
        \ coc#refresh()

  function! CheckBackspace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction
]]

-- Enter to confirm completion
vim.keymap.set(
    "i",
    "<CR>",
    'coc#pum#visible() && coc#pum#info()["index"] != -1 ? coc#pum#confirm() : "\\<C-g>u\\<CR>\\<c-r>=coc#on_enter()\\<CR>"',
    { expr = true, noremap = true, silent = true }
)

vim.keymap.set("n", "<leader>e", ":CocCommand explorer<cr>", { silent = true, desc = "Open explorer" })

-- Use `[e` and `]e` to navigate diagnostics
-- Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
vim.keymap.set("n", "[d", "<Plug>(coc-diagnostic-prev)", { silent = true, desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", "<Plug>(coc-diagnostic-next)", { silent = true, desc = "Next diagnostic" })

-- Navigate chunks for current buffer
vim.keymap.set("n", "[g", "<Plug>(coc-git-prevchunk)", { silent = true, desc = "Previous chunk" })
vim.keymap.set("n", "]g", "<Plug>(coc-git-nextchunk)", { silent = true, desc = "Next chunk" })

-- Show chunk diff at current position
vim.keymap.set("n", "<leader>hg", "<Plug>(coc-git-chunkinfo)", { silent = true, desc = "Chunk info" })

-- GoTo code navigation
vim.keymap.set("n", "gd", "<Plug>(coc-definition)", { silent = true, desc = "Go to definition" })
vim.keymap.set("n", "gy", "<Plug>(coc-type-definition)", { silent = true, desc = "Go to type definition" })
vim.keymap.set("n", "gi", "<Plug>(coc-implementation)", { silent = true, desc = "Go to implementation" })
local telescopeAvailable, telescope = pcall(require, "telescope")
if telescopeAvailable then
  telescope.load_extension('coc')
  vim.keymap.set('n', 'gr', ':Telescope coc references path_display={\'tail\'}<cr>', { noremap = true, silent = true })
  -- path_display='smart' ATM only checks for forward slashes in path instead of OS-specific path seperator.
  -- setKeymap('n', 'gr', ':Telescope coc references path_display={\'smart\'}<cr>', opts)
else
  vim.keymap.set("n", "gr", "<Plug>(coc-references)", { silent = true })
end

-- Use K or gh to show documentation in preview window
vim.keymap.set("n", "K", ShowDocumentation, { noremap = true, silent = true, desc = "Show documentation" })
vim.keymap.set("n", "gh", ShowDocumentation, { noremap = true, silent = true, desc = "Show documentation" })

-- Symbol renaming
vim.keymap.set("n", "<leader>r", "<Plug>(coc-rename)", { silent = true, desc = "Rename" })

-- Formatting code
vim.keymap.set("n", "<leader>f", "<Plug>(coc-format)", { silent = true, desc = "Format document" })
vim.keymap.set("x", "<leader>f", "<Plug>(coc-format-selected)", { silent = true, desc = "Format selection" })
vim.keymap.set("n", "<leader>F", function()
  vim.fn.CocAction('runCommand', 'editor.action.organizeImport')
  vim.fn.CocAction('runCommand', 'editor.action.formatDocument')
end, { silent = true, desc = "Format document and organize imports" })

-- Apply codeAction to the selected region
-- Example: `<leader>aap` for current paragraph
local opts = { silent = true, nowait = true }
vim.keymap.set("n", "<leader>a", "<Plug>(coc-codeaction-cursor)", opts)
vim.keymap.set("x", "<leader>a", "<Plug>(coc-codeaction-selected)", opts)

-- Map function and class text objects
-- NOTE: Requires 'textDocument.documentSymbol' support from the language server
vim.keymap.set("x", "if", "<Plug>(coc-funcobj-i)", opts)
vim.keymap.set("o", "if", "<Plug>(coc-funcobj-i)", opts)
vim.keymap.set("x", "af", "<Plug>(coc-funcobj-a)", opts)
vim.keymap.set("o", "af", "<Plug>(coc-funcobj-a)", opts)
vim.keymap.set("x", "ic", "<Plug>(coc-classobj-i)", opts)
vim.keymap.set("o", "ic", "<Plug>(coc-classobj-i)", opts)
vim.keymap.set("x", "ac", "<Plug>(coc-classobj-a)", opts)
vim.keymap.set("o", "ac", "<Plug>(coc-classobj-a)", opts)

-- Mappings for CoCList
-- code actions and coc stuff
---@diagnostic disable-next-line: redefined-local
local opts = { silent = true, nowait = true }
-- Show all diagnostics
vim.keymap.set("n", "<leader>cd", ":<C-u>CocList diagnostics<cr>", opts)
-- Manage extensions
vim.keymap.set("n", "<leader>ce", ":<C-u>CocList extensions<cr>", opts)
-- Show commands
vim.keymap.set("n", "<leader><leader>", ":<C-u>CocList commands<cr>", opts)
-- Find symbol of current document
-- vim.keymap.set("n", "<leader>co", ":<C-u>CocList outline<cr>", opts)
-- Search workspace symbols
-- vim.keymap.set("n", "<leader>cs", ":<C-u>CocList -I symbols<cr>", opts)
-- Do default action for next item
-- vim.keymap.set("n", "<leader>cj", ":<C-u>CocNext<cr>", opts)
-- Do default action for previous item
-- vim.keymap.set("n", "<leader>ck", ":<C-u>CocPrev<cr>", opts)
-- Resume latest coc list
-- vim.keymap.set("n", "<leader>c<space>", ":<C-u>CocListResume<cr>", opts)
