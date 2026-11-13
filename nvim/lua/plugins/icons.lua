return {
  -- Icon provider (used by snacks.nvim directly and by lualine via the nvim-web-devicons mock)
  'nvim-mini/mini.icons',
  enabled = true,
  lazy = true,
  opts = {},
  init = function()
    -- load mini.icons when a plugin requires nvim-web-devicons
    package.preload['nvim-web-devicons'] = function()
      require('mini.icons').mock_nvim_web_devicons()
      return package.loaded['nvim-web-devicons']
    end
  end,
}
