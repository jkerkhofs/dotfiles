local status, lualine = pcall(require, "lualine")
if (not status) then return end

lualine.setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    disabled_filetypes = {}
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch' },
    lualine_c = { 'filename' },
    lualine_x = {},
    lualine_y = { 'filetype', 'encoding', 'fileformat' },
    lualine_z = { 'progress', 'location' }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { 'filename' },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {
    lualine_a = {
      { 'tabs', mode = 2, max_length = vim.o.columns },
    },
  },
  extensions = { 'fugitive' }
}

-- hide the default vim mode
vim.o.showmode = false

-- reset showtabline to "1" as lualine sets it to "2" in the "set_tabline" setup function
vim.o.showtabline = 1
