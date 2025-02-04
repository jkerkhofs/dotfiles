vim.cmd([[source ~/.vim/vimrc]])

-- Init Lazy.nvim
-- Each plugin is defined in its own config file inside lua/plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup('plugins')

-- Neovim options
vim.opt.fillchars = { eob = " " } -- hide the end of buffer chars
