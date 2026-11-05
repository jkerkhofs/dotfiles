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

-- Windows Terminal resets the cursor shape to the profile's cursorShape on focus (microsoft/terminal#18174).
-- Re-apply guicursor and redraw so the cursor matches the current mode again.
-- Only needed in Windows Terminal, which sets WT_SESSION in every shell it starts.
if vim.env.WT_SESSION then
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("RestoreCursorShape", { clear = true }),
    callback = function()
      local guicursor = vim.o.guicursor
      vim.o.guicursor = ""
      vim.o.guicursor = guicursor
      vim.cmd("redraw!")
    end,
  })
end
