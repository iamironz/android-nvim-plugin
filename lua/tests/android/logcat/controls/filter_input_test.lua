local M = {}
local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function header_renders_saved_values()
  local state = state_with("com.saved", "Activity")

  logcat_helpers.with_logcat_context({ state = state }, function(ctx)
    assert.table_eq(
      ctx.header_lines.value,
      { "Package: com.saved", "Filter: Activity", "Level: " },
      "header lines"
    )
  end)
end

local function with_filter_change_context(state, callback)
  local input_calls = {}
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        table.insert(input_calls, opts)
        if opts.on_change then
          opts.on_change("New")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, callback)
end

local function filter_input_does_not_restart_logcat()
  local state = state_with("com.saved", "Old")

  with_filter_change_context(state, function(ctx)
    local initial_spawns = ctx.spawn_calls.count
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(ctx.spawn_calls.count, initial_spawns, "no restart on change")
  end)
end

local function filter_input_does_not_clear_body()
  local state = state_with("com.saved", "Old")

  with_filter_change_context(state, function(ctx)
    local initial_clears = ctx.clear_body_calls.count
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(ctx.clear_body_calls.count, initial_clears, "no clear on change")
  end)
end

local function filter_input_updates_state()
  local state = state_with("com.saved", "Old")
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_change then
          opts.on_change("New")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(ctx.state.logcat.filter, "New", "filter updated")
  end)
end

local function filter_input_persists_state()
  local state = state_with("com.saved", "Old")
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_accept then
          opts.on_accept("Newer")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(ctx.state.logcat.filter, "Newer", "filter persisted")
  end)
end

local function header_rerenders_after_filter_input()
  local state = state_with("com.saved", "Old")
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_accept then
          opts.on_accept("NewFilter")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.table_eq(
      ctx.header_lines.value,
      { "Package: com.saved", "Filter: NewFilter", "Level: " },
      "header after filter input"
    )
  end)
end

local function filter_input_cancel_keeps_latest()
  local state = state_with("com.saved", "Old")
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_change then
          opts.on_change("Temp")
        end
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(ctx.state.logcat.filter, "Temp", "filter kept")
  end)
end

local function filter_picker_receives_history()
  local state = logcat_helpers.build_state({
    logcat = { package = "com.saved", filter = "Old", filter_history = { "warn", "error" } },
  })
  local captured = {}
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        captured.items = opts.items
        if opts.on_change then
          opts.on_change("Temp")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.table_eq(captured.items or {}, { "warn", "error" }, "history items")
  end)
end

local function filter_picker_receives_prompt_text()
  local state = state_with("com.saved", "Old")
  local captured = {}
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        captured.prompt_title = opts.prompt_title
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.eq(captured.prompt_title, "Logcat filter", "prompt title")
  end)
end

local function filter_history_persists()
  local state = logcat_helpers.build_state({
    logcat = { package = "com.saved", filter = "Old", filter_history = { "old" } },
  })
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_accept then
          opts.on_accept("new")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.table_eq(ctx.state.logcat.filter_history, { "new", "old" }, "history saved")
  end)
end

local function filter_history_persists_on_cancel()
  local state = logcat_helpers.build_state({
    logcat = { package = "com.saved", filter = "Old", filter_history = { "old" } },
  })
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_change then
          opts.on_change("temp")
        end
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    assert.table_eq(ctx.state.logcat.filter_history, { "temp", "old" }, "history saved")
  end)
end

function M.run()
  header_renders_saved_values()
  filter_input_does_not_restart_logcat()
  filter_input_does_not_clear_body()
  filter_input_updates_state()
  filter_input_persists_state()
  header_rerenders_after_filter_input()
  filter_input_cancel_keeps_latest()
  filter_picker_receives_history()
  filter_picker_receives_prompt_text()
  filter_history_persists()
  filter_history_persists_on_cancel()
end

return M
