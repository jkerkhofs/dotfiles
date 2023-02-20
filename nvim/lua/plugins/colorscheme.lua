return {
  -- Gruvbox with Material Palette
  'sainnhe/gruvbox-material',
  enabled = true,
  lazy = false,
  config = function()
    vim.g.gruvbox_material_better_performance = 1
    vim.g.gruvbox_material_background = 'medium'
    vim.g.gruvbox_material_transparent_background = 1
    vim.cmd 'colorscheme gruvbox-material'
  end
}
