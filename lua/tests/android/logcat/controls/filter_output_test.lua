local M = {}
local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function panel_stub(options)
  local opts = options or {}
  local appended = opts.appended

  return {
    open = function() end,
    clear = function() end,
    append = function(lines)
      if appended then
        appended.lines = lines
      end
    end,
    set_header_lines = function() end,
    clear_body = function() end,
    replace_body = function() end,
    trim_body = function() end,
    close = function()
      return true
    end,
  }
end

local function with_filter_output_context(callback)
  local filter_calls = { count = 0, lines = nil, filter = nil }
  local job_callbacks = {}
  local appended = { lines = nil }
  local panel = panel_stub({ appended = appended })
  local state = state_with("com.saved", "Allow")

  local stubs = {
    ["android.logcat.filters"] = {
      parse_terms = function()
        return {}
      end,
      normalize_level = function(value)
        return value
      end,
      build = function(options)
        return { level = options and options.level }
      end,
      filter_lines = function(lines, filter)
        filter_calls.count = filter_calls.count + 1
        filter_calls.lines = lines
        filter_calls.filter = filter
        return { "filtered line" }
      end,
    },
    ["android.command.job"] = {
      spawn = function(_, opts)
        job_callbacks.on_stdout = opts.on_stdout
        return { ok = true, stop = function() end }
      end,
    },
    ["android.ui.panel"] = panel,
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    callback(ctx, filter_calls, job_callbacks, appended)
  end)
end

local function handle_output_filters_lines_count()
  with_filter_output_context(function(_, filter_calls, job_callbacks)
    job_callbacks.on_stdout({ "match", "ignore" })
    assert.eq(filter_calls.count, 1, "filter called")
  end)
end

local function handle_output_filters_lines_input()
  with_filter_output_context(function(_, filter_calls, job_callbacks)
    job_callbacks.on_stdout({ "match", "ignore" })
    assert.table_eq(filter_calls.lines or {}, { "match", "ignore" }, "filter lines")
  end)
end

local function handle_output_filters_lines_filter_arg()
  with_filter_output_context(function(_, filter_calls, job_callbacks)
    job_callbacks.on_stdout({ "match", "ignore" })
    assert.eq(filter_calls.filter, "Allow", "filter arg")
  end)
end

local function handle_output_appends_filtered_lines()
  local job_callbacks = {}
  local appended = { lines = nil }
  local panel = panel_stub({ appended = appended })
  local state = state_with("com.saved", "Allow")

  local stubs = {
    ["android.logcat.filters"] = {
      parse_terms = function()
        return {}
      end,
      normalize_level = function(value)
        return value
      end,
      build = function(options)
        return { level = options and options.level }
      end,
      filter_lines = function()
        return { "filtered line" }
      end,
    },
    ["android.command.job"] = {
      spawn = function(_, opts)
        job_callbacks.on_stdout = opts.on_stdout
        return { ok = true, stop = function() end }
      end,
    },
    ["android.ui.panel"] = panel,
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    job_callbacks.on_stdout({ "match", "ignore" })
    assert.table_eq(appended.lines or {}, { "filtered line" }, "append filtered")
  end)
end

local function filter_change_rebuilds_body_from_raw_lines()
  local job_callbacks = {}
  local state = state_with("com.saved", "")
  local stubs = {
    ["android.command.job"] = {
      spawn = function(_, opts)
        job_callbacks.on_stdout = opts.on_stdout
        return { ok = true, stop = function() end }
      end,
    },
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_change then
          opts.on_change("match")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    job_callbacks.on_stdout({ "first", "match" })
    logcat_helpers.start_filter_edit(ctx)
    local body = logcat_helpers.body_lines(ctx.vim_state)
    assert.table_eq(body, { "match" }, "filter re-renders")
  end)
end

local function stopped_session_ignores_late_output()
  with_filter_output_context(function(ctx, filter_calls, job_callbacks, appended)
    ctx.vim_state.keymaps["n"]["q"]()

    job_callbacks.on_stdout({ "late line" })

    assert.eq(filter_calls.count, 0, "stopped session ignores filter")
    assert.eq(appended.lines, nil, "stopped session ignores append")
  end)
end

function M.run()
  handle_output_filters_lines_count()
  handle_output_filters_lines_input()
  handle_output_filters_lines_filter_arg()
  handle_output_appends_filtered_lines()
  filter_change_rebuilds_body_from_raw_lines()
  stopped_session_ignores_late_output()
end

return M
