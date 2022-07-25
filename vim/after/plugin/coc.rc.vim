if !exists(':CocCommand')
  finish
endif

let g:coc_global_extensions = [
        \ 'coc-tsserver',
        \ 'coc-eslint',
        \ 'coc-prettier',
        \ 'coc-html',
        \ 'coc-css',
        \ 'coc-json',
        \ 'coc-yaml',
        \ 'coc-git',
        \ 'coc-lua',
        \ 'coc-snippets',
        \ 'coc-explorer',
        \ 'coc-markdownlint',
        \ 'coc-powershell',
  \ ]

" Use tab and shift tab to jump through snippet
let g:coc_snippet_next = '<TAB>'
let g:coc_snippet_prev = '<S-TAB>'

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder.
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Add `:OR` command for organize imports of the current buffer.
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Select the first completion item on <CR> or <TAB>
inoremap <silent><expr> <CR> pumvisible() ? coc#_select_confirm() : "<CR>"

" Make <TAB> used for trigger completion, completion confirm, snippet expand and jump
inoremap <silent><expr> <TAB>
      \ pumvisible() ? coc#_select_confirm() :
      \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

nmap <silent> <leader>e :CocCommand explorer<CR>

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [e <Plug>(coc-diagnostic-prev)
nmap <silent> ]e <Plug>(coc-diagnostic-next)

" navigate chunks of current buffer
nmap <silent> ]g <Plug>(coc-git-nextchunk)
nmap <silent> [g <Plug>(coc-git-prevchunk)
" show chunk diff at current position
nmap <silent> <leader>hg <Plug>(coc-git-chunkinfo)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
" nmap <silent> gr <Plug>(coc-references) " mapped using telescope (./telescope.rc.lua)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>
nnoremap <silent> gh :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocActionAsync('doHover')
  endif
endfunction

" Symbol renaming.
nmap <leader>r <Plug>(coc-rename)

" Formatting code.
nmap <leader>f  <Plug>(coc-format)
xmap <leader>f  <Plug>(coc-format-selected)

function! s:organizeImportsAndFormatDoc()
  call CocAction('runCommand', 'editor.action.organizeImport')
  call CocAction('runCommand', 'editor.action.formatDocument')
endfunction

nmap <silent> <leader>F :call <SID>organizeImportsAndFormatDoc()<CR>

" Applying codeAction
" Example: `<leader>aap` for current paragraph
xmap <silent> <leader>a  <Plug>(coc-codeaction-selected)
nmap <silent> <leader>a  <Plug>(coc-codeaction-cursor)

" Map function and class text objects
" NOTE: Requires 'textDocument.documentSymbol' support from the language server.
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Use CTRL-S for selections ranges.
" Requires 'textDocument/selectionRange' support of language server.
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

" Mappings for CoCList
" Show all diagnostics.
nnoremap <silent> <leader>cd  :<C-u>CocList diagnostics<cr>
" Manage extensions.
nnoremap <silent> <leader>ce  :<C-u>CocList extensions<cr>
" Show commands.
nnoremap <silent> <leader><leader>  :<C-u>CocList commands<cr>
" Find symbol of current document.
nnoremap <silent> <leader>co  :<C-u>CocList outline<cr>
" Search workspace symbols.
nnoremap <silent> <leader>cs  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <leader>cj  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <leader>ck  :<C-u>CocPrev<CR>
" Resume latest coc list.
nnoremap <silent> <leader>c<space>  :<C-u>CocListResume<CR>
