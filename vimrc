" General settings
set nocompatible
syntax enable
filetype plugin on

" change the mapleader from \ to ,
" NOTE: This has to be set before <leader> is used.
let mapleader=","

" source plugin config
runtime coc.vim

let g:coc_global_extensions = [
        \ 'coc-tsserver',
        \ 'coc-eslint',
        \ 'coc-prettier',
        \ 'coc-html',
        \ 'coc-css',
        \ 'coc-json'
  \ ]

packadd! matchit " enable the matchit plugin (e.g. to find the matching html tags)

" theme settings
set termguicolors
colorscheme gruvbox
set bg=dark
let g:airline_powerline_fonts = 1 " use the powerline symbols within Airline.

set belloff=all " disable audio bell

set showmatch " show matching braces when text indicator is over them

set history=1000 " Save 1,000 items in history

set ruler " Show the line and column number of the cursor position

set showcmd " Display the incomplete commands in the bottom right-hand side of your screen.  

set wildmenu " Display completion matches on your status line

set scrolloff=5 " Show a few lines of context around the cursor

set hlsearch " Highlight search matches

set incsearch " Enable incremental searching

" set ignorecase " Ignore case when searching

" set smartcase " Override the 'ignorecase' option if the search pattern contains upper case characters.

set number " Turn on line numbering
set rnu

set lbr " Don't line wrap mid-word.

set autoindent " Copy the indentation from the current line.

set smartindent " Enable smart autoindenting.

set expandtab " Use spaces instead of tabs

" FINDING FILES
" Search down into subfolders
" Provides tab-completion for all file-related tasks
" - Hit tab to :find by partial match
" - Use * to make it fuzzy
" - TIP: :b lets you autocomplete any open buffer
" set path+=**

" set smarttab " Enable smart tabs

" Make a tab equal to 4 spaces
" set shiftwidth=4
" set tabstop=4

" map Y y$ " Map Y to act like D and C, i.e. yank until EOL, rather than act like yy

" map 0 ^ " Remap VIM 0 to first non-blank character

" Easily create HTML unorded lists. 
" map <F3> i<ul><CR><Space><Space><li></li><CR><Esc>I</ul><Esc>kcit
" map <F4> <Esc>o<li></li><Esc>cit

" Quickly save your file.
" map <leader>w :w!<cr>

" For more options see ":help option-list" and ":options".
