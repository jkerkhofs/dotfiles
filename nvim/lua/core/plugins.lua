local fn = vim.fn
local packer_bootstrap
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim',
    install_path })
  vim.cmd [[packadd packer.nvim]]
end

local au_id = vim.api.nvim_create_augroup("Plugins", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
  desc = 'Automatically run PackerCompile whenever this file updates',
  group = au_id,
  pattern = "plugins.lua",
  command = "source <afile> | PackerCompile"
})

return require('packer').startup(function(use)
  use {
    -- Packer can manage itself
    'wbthomason/packer.nvim'
  }
  use {
    -- A Git wrapper so awesome, it should be illegal
    'tpope/vim-fugitive'
  }
  use {
    -- Delete/change/add parentheses/quotes/XML-tags/much more with ease
    'tpope/vim-surround'
  }
  use {
    -- Enable repeating supported plugin maps with '.'
    'tpope/vim-repeat'
  }
  use {
    -- Switch between single-line and multiline forms of code
    'AndrewRadev/splitjoin.vim'
  }
  use {
    -- Vim-snipmate default snippets
    'honza/vim-snippets'
  }
  use {
    -- Continuously updated session files
    'tpope/vim-obsession'
  }
  use {
    -- Gruvbox with Material Palette
    'sainnhe/gruvbox-material',
    config = function() require('plugins.gruvbox-material') end
  }
  use {
    -- Comment stuff out
    'tpope/vim-commentary',
    config = function() require('plugins.commentary') end
  }
  use {
    -- Terminal manager for (neo)vim
    'voldikss/vim-floaterm',
    config = function() require('plugins.floaterm') end
  }
  use {
    -- Open URI with your favorite browser from your most favorite editor
    'tyru/open-browser.vim',
    config = function() require('plugins.open-browser') end
  }
  use {
    -- A Vim/NeoVim plugin for automated bullet lists
    'dkarter/bullets.vim',
    config = function() require('plugins.bullets') end
  }
  use {
    -- A plugin for easy resizing of Vim windows
    'talek/obvious-resize',
    config = function() require('plugins.obvious-resize') end
  }
  use {
    -- Handle vim sessions like a pro
    'dhruvasagar/vim-prosession',
    requires = { 'tpope/vim-obsession' },
    config = function() require('plugins.prosession') end
  }
  use {
    -- The undo history visualizer for VIM
    'mbbill/undotree',
    config = function() require('plugins.undotree') end
  }


  -------------------
  --  Status line  --
  -------------------
  use {
    -- A blazing fast and easy to configure neovim statusline plugin written in pure lua
    'nvim-lualine/lualine.nvim',
    config = function() require('plugins.lualine') end
    -- Icons seem to work without nvim-web-devicons, is this requirement necessary?
    -- requires = { 'kyazdani42/nvim-web-devicons' }
  }


  ----------------------------
  --  Abstract Syntax Tree  --
  ----------------------------
  use {
    -- Nvim Treesitter configurations and abstraction layer
    'nvim-treesitter/nvim-treesitter',
    run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
    config = function() require('plugins.treesitter') end
  }
  use {
    -- Neovim treesitter plugin for setting the commentstring
    -- based on the cursor location in a file
    'JoosepAlviste/nvim-ts-context-commentstring',
    requires = { 'nvim-treesitter/nvim-treesitter' }
  }
  use {
    -- Use treesitter to auto close and auto rename html tag
    'windwp/nvim-ts-autotag',
    requires = { 'nvim-treesitter/nvim-treesitter' }
  }


  --------------------
  --  Fuzzy finder  --
  --------------------
  use {
    -- Find, Filter, Preview, Pick. All lua, all the time
    'nvim-telescope/telescope.nvim',
    requires = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      'fannheyward/telescope-coc.nvim'
    },
    config = function() require('plugins.telescope') end
  }
  use
  {
    -- FZF sorter for telescope written in c
    'nvim-telescope/telescope-fzf-native.nvim',
    run = 'make'
  }
  use {
    -- Coc integration for telescope.nvim
    'fannheyward/telescope-coc.nvim',
    requires = { 'neoclide/coc.nvim' }
  }


  --------------------
  --  LSP (& more)  --
  --------------------
  use {
    -- Nodejs extension host for vim & neovim, load extensions
    -- like VSCode and host language servers
    'neoclide/coc.nvim',
    branch = 'release'
  }
  -- Execute a CocUpdate after each packer update
  vim.api.nvim_create_autocmd("User", {
    desc = 'Update coc extensions on install, update, clean, and sync',
    group = au_id,
    pattern = 'PackerComplete',
    command = 'CocUpdate',
  })
  use {
    -- The Refactoring library based off the Refactoring book by Martin Fowler
    'ThePrimeagen/refactoring.nvim',
    requires = { 'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter' },
    config = function() require('plugins.refactoring') end
  }


  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
