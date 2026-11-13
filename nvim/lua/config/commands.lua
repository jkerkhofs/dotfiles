-- Update the lazy.nvim plugins, the mason packages (language servers and tools) and the treesitter parsers.
-- Interactive: shows the lazy.nvim UI and updates mason and treesitter in the background after the sync.
-- Headless (e.g. `nvim --headless +UpdateAll +qa`): runs everything synchronously and prints the progress.
local function remaining_plugins()
  require('lazy.core.plugin').update_state()
  local remaining = {}
  for _, plugin in ipairs(require('lazy.core.config').to_clean) do
    remaining[#remaining + 1] = plugin.name
  end
  table.sort(remaining)
  return remaining
end

vim.api.nvim_create_user_command('UpdateAll', function()
  local headless = #vim.api.nvim_list_uis() == 0
  -- prevents the mason-tool-installer run on start, which would install in parallel with the update
  vim.g.update_all = true
  -- sets up mason, mason-lspconfig and mason-tool-installer
  require('lazy').load({ plugins = { 'nvim-lspconfig' } })

  if not headless then
    vim.api.nvim_create_autocmd('User', {
      pattern = 'LazySync',
      once = true,
      callback = function()
        local remaining = remaining_plugins()
        if #remaining > 0 then
          vim.notify('Plugin directories not removed:\n' .. table.concat(remaining, '\n'), vim.log.levels.ERROR)
        end
        vim.cmd('MasonToolsUpdate')
        require('nvim-treesitter').update(nil, { summary = true })
      end,
    })
    require('lazy').sync()
    return
  end

  local function log(msg)
    io.write(msg .. '\n')
  end
  local failed = false
  -- print notifications (e.g. from mason-tool-installer) as separate lines
  vim.notify = function(msg, level)
    if level == vim.log.levels.ERROR then
      failed = true
    end
    log('  ' .. (level == vim.log.levels.ERROR and 'error: ' or '') .. msg)
  end

  log('Updating lazy.nvim plugins...')
  -- don't show the output of every git task, the updated and failed plugins are listed below
  local headless_opts = require('lazy.core.config').options.headless
  headless_opts.process, headless_opts.log, headless_opts.task = false, false, false
  require('lazy').sync({ wait = true, show = false })
  for _, name in ipairs(remaining_plugins()) do
    failed = true
    log('  not removed: ' .. name)
  end
  local Plugin = require('lazy.core.plugin')
  local updated = 0
  for name, plugin in pairs(require('lazy.core.config').plugins) do
    if Plugin.has_errors(plugin) then
      failed = true
      log('  failed: ' .. name)
      for _, task in ipairs(plugin._.tasks or {}) do
        if task:has_errors() then
          log('    ' .. vim.trim(task:output(vim.log.levels.ERROR)):gsub('\n', '\n    '))
        end
      end
    elseif plugin._.updated and plugin._.updated.from ~= plugin._.updated.to then
      updated = updated + 1
      log('  updated: ' .. name)
    end
  end
  if updated == 0 then
    log('  all plugins are up to date')
  end

  log('Updating mason packages...')
  vim.cmd('MasonToolsUpdateSync')

  log('Updating treesitter parsers...')
  local ok, result = pcall(function()
    return require('nvim-treesitter').update():wait(10 * 60 * 1000)
  end)
  if not ok or result == false then
    failed = true
    log('  failed: ' .. tostring(ok and 'not all parsers were updated' or result))
  end
  -- process the pending (scheduled) notifications before the final message
  vim.wait(100)

  log(failed and 'Update finished with errors' or 'Update finished')
  if failed then
    vim.cmd('cquit 1')
  end
end, { desc = 'Update plugins, mason packages and treesitter parsers' })
