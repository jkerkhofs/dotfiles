return {
  -- The undo history visualizer for VIM
  'mbbill/undotree',
  enabled = true,
  cmd = { 'UndotreeToggle', 'UndotreeShow' },
  keys = {
    { '<leader>u', '<Cmd>UndotreeToggle<CR>', desc = 'Toggle undotree' },
  },
}
