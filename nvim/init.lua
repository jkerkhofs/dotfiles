-- Load filetype detection before the vimrc: otherwise its `syntax enable` runs `filetype on` and
-- `doautoall`, which loads the startup files early without BufReadPre/BufReadPost (breaks lazy-loading)
vim.cmd('filetype plugin indent on')

-- Shared Vim/Neovim settings (leader, options, mappings, shell)
vim.cmd([[source ~/.vim/vimrc]])

-- Neovim specific options
require('config.options')

-- Init Lazy.nvim
-- Each plugin is defined in its own config file inside lua/plugins
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable', -- latest stable release
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
    }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = { { import = 'plugins' } },
  install = { colorscheme = { 'everforest' } },
  rocks = { enabled = false },
  change_detection = { notify = false },
})

require('config.diagnostics')
require('config.keymaps')
require('config.autocmds')
require('config.commands')
