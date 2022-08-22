-- Open Lazygit in floating term
vim.api.nvim_set_keymap(
  "n",
  "<leader>lg",
  ":FloatermNew --height=0.9 --width=0.9 --autoclose=2 --title=Lazygit lazygit<CR>",
  { noremap = true, silent = true, }
)
