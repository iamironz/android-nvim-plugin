local M = {}

local buffer = require("tests.helpers.build_stream.buffer")
local panel = require("tests.helpers.build_stream.panel")
local stubs_helper = require("tests.helpers.stubs")
local vim_helpers = require("tests.helpers.build_stream.vim")

function M.reset_stream_module()
  package.loaded["android.build.stream"] = nil
  return require("android.build.stream")
end

M.with_temp_cursor = vim_helpers.with_temp_cursor
M.with_vim_stubs = vim_helpers.with_vim_stubs

local function build_job_stubs(config, job_state)
  local saved_state = { value = nil }
  local input_calls = nil
  local stubs = {
    ["android.command.jobs"] = {
      start = function(cmd, opts)
        job_state.spawn_calls = job_state.spawn_calls + 1
        job_state.spawn_cmd = cmd
        job_state.spawn_opts = opts
        if opts.on_stdout and config.stdout_lines then
          opts.on_stdout(config.stdout_lines)
        end
        if opts.on_stderr and config.stderr_lines then
          opts.on_stderr(config.stderr_lines)
        end
        if opts.on_exit and config.exit_code ~= nil then
          opts.on_exit(config.exit_code)
        end
        return { ok = true, stop = function() end }
      end,
    },
  }

  if config.state then
    stubs["android.actions.context"] = {
      load_state = function()
        return config.state
      end,
      save_state = function(_, next_state)
        saved_state.value = next_state
        config.state = next_state
      end,
    }
  end

  if config.input then
    input_calls = config.input.calls or {}
    stubs["android.ui.picker"] = {
      filter_input = function(opts)
        table.insert(input_calls, opts)
        if config.input.change_value and opts.on_change then
          opts.on_change(config.input.change_value)
        end
        if config.input.before_accept then
          config.input.before_accept(opts)
        end
        if config.input.cancel then
          if opts.on_cancel then
            opts.on_cancel()
          end
          return
        end
        if opts.on_accept then
          opts.on_accept(config.input.value or "")
        end
      end,
    }
  end

  return stubs, input_calls, saved_state
end

local function run_stream_with_vim(config, panel_state, stubs)
  local result = nil
  local keymaps = nil
  local vim_state = nil

  M.with_vim_stubs(function(state)
    if config.input_values then
      state.input_values = config.input_values
    end
    vim_state = state
    buffer.ensure_buffer(state, state.current_buf)
    stubs["android.ui.panel"] = panel.make_panel_stub(panel_state, state)
    stubs_helper.with_stubs(stubs, function()
      local stream = M.reset_stream_module()
      stream.start_build_job(
        config.root or "/root",
        config.args or { "gradle" },
        function(data)
          result = data
        end
      )
      keymaps = state.keymaps
      if config.after_start then
        config.after_start(state, stream)
      end
    end)
  end)

  return result, keymaps, vim_state
end

function M.run_build_job(config)
  local panel_state = panel.make_panel_state()
  local job_state = {
    spawn_cmd = nil,
    spawn_opts = nil,
    spawn_calls = 0,
  }
  local stubs, input_calls, saved_state = build_job_stubs(config, job_state)
  local result, keymaps, vim_state = run_stream_with_vim(config, panel_state, stubs)

  return {
    panel = panel_state,
    result = result,
    spawn_cmd = job_state.spawn_cmd,
    spawn_opts = job_state.spawn_opts,
    spawn_calls = job_state.spawn_calls,
    keymaps = keymaps,
    vim_state = vim_state,
    input_calls = input_calls,
    saved_state = saved_state.value,
  }
end

function M.default_build_config()
  return {
    stdout_lines = { "line 1" },
    stderr_lines = { "err 1", "err 2" },
    exit_code = 1,
  }
end

function M.build_config(overrides)
  local config = M.default_build_config()
  for key, value in pairs(overrides or {}) do
    config[key] = value
  end
  return config
end

function M.filter_config(overrides)
  local config = {
    stdout_lines = { "First line", "Error line" },
    stderr_lines = {},
    exit_code = 0,
  }
  for key, value in pairs(overrides or {}) do
    config[key] = value
  end
  return config
end

function M.run_default_build(overrides)
  return M.run_build_job(M.build_config(overrides))
end

function M.run_filter_build(overrides)
  return M.run_build_job(M.filter_config(overrides))
end

function M.run_filter_keymap()
  return M.run_filter_build({
    after_start = function(state)
      state.keymaps["n"]["f"]()
    end,
  })
end

function M.start_filter_input(state)
  state.keymaps["n"]["f"]()
end

function M.start_filter_input_from_enter(state)
  state.cursor_line = 1
  if state.control_buf then
    state.current_buf = state.control_buf
  end
  if state.control_win then
    state.current_win = state.control_win
  end
  state.keymaps["n"]["<CR>"]()
end

return M
