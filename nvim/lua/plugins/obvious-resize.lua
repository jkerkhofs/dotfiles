return {
  -- A plugin for easy resizing of Vim windows
  'talek/obvious-resize',
  enabled = true,
  keys = {
    { '<A-left>', ':<C-U>ObviousResizeLeft 5<CR>', silent = true, desc = 'Resize window left' },
    { '<A-down>', ':<C-U>ObviousResizeDown 5<CR>', silent = true, desc = 'Resize window down' },
    { '<A-up>', ':<C-U>ObviousResizeUp 5<CR>', silent = true, desc = 'Resize window up' },
    { '<A-right>', ':<C-U>ObviousResizeRight 5<CR>', silent = true, desc = 'Resize window right' },
  },
}
