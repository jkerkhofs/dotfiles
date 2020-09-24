syntax on " turn on syntax highlighting

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

" set backup " Turn on file backups

set lbr " Don't line wrap mid-word.

set autoindent " Copy the indentation from the current line.

set smartindent " Enable smart autoindenting.

set expandtab " Use spaces instead of tabs

" set smarttab " Enable smart tabs

" Make a tab equal to 4 spaces
" set shiftwidth=4
" set tabstop=4

colorscheme slate " Specifiy a color scheme.

" Tell vim what background you are using
" set bg=light
set bg=dark

" map Y y$ " Map Y to act like D and C, i.e. yank until EOL, rather than act like yy

" map 0 ^ " Remap VIM 0 to first non-blank character

" Easily create HTML unorded lists. 
" map <F3> i<ul><CR><Space><Space><li></li><CR><Esc>I</ul><Esc>kcit
" map <F4> <Esc>o<li></li><Esc>cit

" change the mapleader from \ to ,
" NOTE: This has to be set before <leader> is used.
" let mapleader=","

" Quickly save your file.
" map <leader>w :w!<cr>

" For more options see ":help option-list" and ":options".
