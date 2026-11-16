local function dap(fn)
  return function()
    require('dap')[fn]()
  end
end

return {
  {
    -- Debug Adapter Protocol client; the .NET adapter (netcoredbg) and configurations are registered by easy-dotnet
    'mfussenegger/nvim-dap',
    enabled = true,
    dependencies = {
      'igorlfs/nvim-dap-view',
      'theHamsta/nvim-dap-virtual-text',
    },
    -- Rider/Visual Studio keys
    keys = {
      { '<F5>', dap('continue'), desc = 'Debug: start/continue' },
      { '<S-F5>', dap('terminate'), desc = 'Debug: stop' },
      { '<F9>', dap('toggle_breakpoint'), desc = 'Debug: toggle breakpoint' },
      { '<F10>', dap('step_over'), desc = 'Debug: step over' },
      { '<F11>', dap('step_into'), desc = 'Debug: step into' },
      { '<S-F11>', dap('step_out'), desc = 'Debug: step out' },
      {
        '<leader>dc',
        function()
          vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(condition)
            if condition and condition ~= '' then
              require('dap').set_breakpoint(condition)
            end
          end)
        end,
        desc = 'Conditional breakpoint',
      },
      { '<leader>dC', dap('run_to_cursor'), desc = 'Run to cursor' },
      { '<leader>dl', dap('run_last'), desc = 'Run last' },
      { '<leader>dB', dap('clear_breakpoints'), desc = 'Clear breakpoints' },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = 'Toggle REPL' },
      { '<leader>dv', function() require('dap-view').toggle() end, desc = 'Toggle debug view' },
      { '<leader>dt', dap('terminate'), desc = 'Terminate' },
    },
    config = function()
      local signs = {
        DapBreakpoint = { text = '●', texthl = 'DiagnosticError' },
        DapBreakpointCondition = { text = '◆', texthl = 'DiagnosticError' },
        DapLogPoint = { text = '◆', texthl = 'DiagnosticInfo' },
        DapBreakpointRejected = { text = '○', texthl = 'DiagnosticWarn' },
        DapStopped = { text = '▶', texthl = 'DiagnosticOk', linehl = 'DapStoppedLine' },
      }
      for name, sign in pairs(signs) do
        vim.fn.sign_define(name, sign)
      end
      vim.api.nvim_set_hl(0, 'DapStoppedLine', { default = true, link = 'Visual' })
    end,
  },
  {
    -- Debugging UI for nvim-dap: watches, scopes, breakpoints, threads and REPL in one window
    'igorlfs/nvim-dap-view',
    enabled = true,
    lazy = true,
    ---@module 'dap-view'
    ---@type dapview.Config
    opts = {
      -- open when a session starts and close when all sessions are finished
      auto_toggle = true,
    },
  },
  {
    -- Show the variable values as virtual text while debugging
    'theHamsta/nvim-dap-virtual-text',
    enabled = true,
    lazy = true,
    opts = {},
  },
}
