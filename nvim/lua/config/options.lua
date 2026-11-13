-- Neovim specific options and overrides of the shared vimrc

-- hide the end of buffer chars
vim.opt.fillchars = { eob = ' ' }

-- use separate swap/backup dirs from Vim (the trailing '//' makes the file names unique)
local state = vim.fn.stdpath('state')
for _, dir in ipairs({ 'swap', 'backup' }) do
  vim.fn.mkdir(state .. '/' .. dir, 'p')
end
vim.o.directory = state .. '/swap//'
vim.o.backupdir = state .. '/backup//'
-- persistent undo (the default 'undodir' is in stdpath('state'))
vim.o.undofile = true

-- PowerShell settings as recommended in `:h shell-powershell` (the shell itself is set in the vimrc)
if vim.fn.has('win32') == 1 then
  vim.o.shelltemp = false
  vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command '
    .. '[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();'
    .. "$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
  if vim.o.shell == 'pwsh' then
    -- see `:h shell-pwsh`
    vim.o.shellcmdflag = vim.o.shellcmdflag .. "$PSStyle.OutputRendering = 'PlainText';"
    vim.env.__SuppressAnsiEscapeSequences = '1'
  end
  vim.o.shellredir = '> %s 2>&1'
  vim.o.shellpipe = '> %s 2>&1'
  vim.o.shellquote = ''
  vim.o.shellxquote = ''
end
