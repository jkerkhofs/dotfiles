-- Update the lazy.nvim plugins, the mason packages (language servers and tools), the global dotnet tools and the
-- treesitter parsers.
-- Interactive: shows the lazy.nvim UI and updates mason, dotnet tools and treesitter in the background after the sync.
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

-- global dotnet tools used by easy-dotnet.nvim, not managed by mason (`dotnet tool update` also installs missing tools)
local dotnet_update_cmds = {
  { name = 'EasyDotnet', cmd = { 'dotnet', 'tool', 'update', '--global', 'EasyDotnet' } },
  -- easy-dotnet knows the feed and version of the roslyn-language-server tool it supports
  { name = 'roslyn-language-server', cmd = { 'dotnet-easydotnet', 'roslyn', 'update' } },
}

-- Updates the dotnet tools one after another and reports every result with vim.notify.
-- Runs synchronously when `sync` is true, otherwise in the background.
local function update_dotnet_tools(sync)
  if vim.fn.executable('dotnet') == 0 then
    vim.notify('dotnet tools skipped: dotnet CLI not found in PATH', vim.log.levels.WARN)
    return
  end

  local function update(i)
    local tool = dotnet_update_cmds[i]
    if not tool then
      return
    end
    local function on_exit(result)
      local output = vim.trim((result.stdout or '') .. '\n' .. (result.stderr or '')):gsub('\r', '')
      if result.code == 0 then
        local lines = vim.split(output, '\n')
        vim.notify(('%s: %s'):format(tool.name, vim.trim(lines[#lines])), vim.log.levels.INFO)
      else
        vim.notify(('%s update failed:\n%s'):format(tool.name, output), vim.log.levels.ERROR)
      end
      update(i + 1)
    end
    -- vim.system throws when the executable doesn't exist (e.g. dotnet-easydotnet after a failed install)
    local ok, err = pcall(function()
      if sync then
        on_exit(vim.system(tool.cmd, { text = true }):wait())
      else
        vim.system(tool.cmd, { text = true }, vim.schedule_wrap(on_exit))
      end
    end)
    if not ok then
      vim.notify(('%s update failed: %s'):format(tool.name, err), vim.log.levels.ERROR)
      update(i + 1)
    end
  end
  update(1)
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
        update_dotnet_tools(false)
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

  log('Updating dotnet tools...')
  update_dotnet_tools(true)

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
end, { desc = 'Update plugins, mason packages, dotnet tools and treesitter parsers' })
