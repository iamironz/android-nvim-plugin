local M = {}

local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")
local stubs_helper = require("tests.helpers.stubs")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function panel_stub(options)
  local opts = options or {}
  local header_calls = opts.header_calls
  local clear_body_calls = opts.clear_body_calls
  local header_lines = opts.header_lines

  return {
    open = function() end,
    clear = function() end,
    append = function() end,
    set_header_lines = function(lines)
      if header_calls then
        table.insert(header_calls, lines)
      end
      if header_lines then
        header_lines.value = lines
      end
    end,
    clear_body = function()
      if clear_body_calls then
        clear_body_calls.count = clear_body_calls.count + 1
      end
    end,
    replace_body = function() end,
    trim_body = function() end,
    close = function()
      return true
    end,
  }
end

local function package_change_restarts_logcat()
  local state = state_with("com.saved", "")
  local stubs = logcat_helpers.package_picker_stubs("com.new.app")

  logcat_helpers.with_logcat_and_enter({ state = state, stubs = stubs }, 1, function(ctx)
    assert.table_eq(
      { ctx.spawn_calls.count, ctx.clear_body_calls.count },
      { 2, 1 },
      "spawn after package change"
    )
  end)
end

local function package_change_persists_state()
  local state = state_with("com.saved", "")
  local stubs = logcat_helpers.package_picker_stubs("com.new.app")

  logcat_helpers.with_logcat_and_enter({ state = state, stubs = stubs }, 1, function(ctx)
    assert.eq(ctx.state.logcat.package, "com.new.app", "package persisted")
  end)
end

local function header_rerenders_after_package_change()
  local header_calls = {}
  local state = state_with("com.saved", "Old")
  local panel = panel_stub({ header_calls = header_calls })
  local stubs = stubs_helper.merge_stubs(
    logcat_helpers.package_picker_stubs("com.new.app"),
    { ["android.ui.panel"] = panel }
  )

  logcat_helpers.with_logcat_and_enter({ state = state, stubs = stubs }, 1, function()
    assert.table_eq(
      header_calls[2],
      { "Package: com.new.app", "Filter: Old", "Level: " },
      "header after package change"
    )
  end)
end

local function package_fallback_uses_input_and_persists_state()
  local state = state_with("com.saved", "")
  local stubs = stubs_helper.merge_stubs(logcat_helpers.empty_package_list_stubs(), {
    ["android.ui.picker"] = {
      select_from_list = function()
        error("picker should not be used when list empty")
      end,
    },
  })

  logcat_helpers.with_logcat_and_enter({
    state = state,
    vim_opts = { input_value = "com.fallback" },
    stubs = stubs,
  }, 1, function(ctx)
    local call = ctx.vim_state.input_calls[1] or {}
    local summary = string.format(
      "%d|%s|%s|%s",
      #ctx.vim_state.input_calls,
      call.prompt or "",
      call.default or "",
      ctx.state.logcat.package or ""
    )
    assert.eq(summary, "1|Logcat package: ||com.fallback", "package input used")
  end)
end

local function package_fallback_restarts_logcat()
  local state = state_with("com.saved", "")
  local stubs = logcat_helpers.empty_package_list_stubs()

  logcat_helpers.with_logcat_and_enter({
    state = state,
    vim_opts = { input_value = "com.fallback" },
    stubs = stubs,
  }, 1, function(ctx)
    assert.table_eq(
      { ctx.spawn_calls.count, ctx.clear_body_calls.count },
      { 2, 1 },
      "spawn after package fallback"
    )
  end)
end

local function package_fallback_uses_empty_default_when_no_saved_package()
  local state = state_with("", "")
  local stubs = stubs_helper.merge_stubs(logcat_helpers.empty_package_list_stubs(), {
    ["android.logcat.package"] = {
      resolve_default_package = function()
        return nil
      end,
    },
  })

  logcat_helpers.with_logcat_and_enter({
    state = state,
    vim_opts = { input_value = "com.manual" },
    stubs = stubs,
  }, 1, function(ctx)
    local call = ctx.vim_state.input_calls[1] or {}
    local summary = string.format(
      "%d|%s",
      #ctx.vim_state.input_calls,
      call.default or ""
    )
    assert.eq(summary, "1|", "package default empty")
  end)
end

local function empty_package_input_clears_and_restarts()
  local state = state_with("com.saved", "")
  local stubs = logcat_helpers.empty_package_list_stubs()

  logcat_helpers.with_logcat_and_enter({
    state = state,
    vim_opts = { input_value = "   " },
    stubs = stubs,
  }, 1, function(ctx)
    local summary = string.format(
      "%s|%d|%d",
      ctx.state.logcat.package or "",
      ctx.spawn_calls.count,
      ctx.clear_body_calls.count
    )
    assert.eq(summary, "|2|1", "empty package")
  end)
end

local function header_enter_prompts_for_package_and_filter_modal()
  local state = state_with("com.saved", "Old")
  local input_calls = {}
  local stubs = stubs_helper.merge_stubs(logcat_helpers.empty_package_list_stubs(), {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        table.insert(input_calls, opts)
      end,
    },
  })

  logcat_helpers.with_logcat_context({
    state = state,
    vim_opts = { input_value = "Updated" },
    stubs = stubs,
  }, function(ctx)
    logcat_helpers.press_enter(ctx, 1)
    logcat_helpers.press_enter(ctx, 2)

    local call = ctx.vim_state.input_calls[1] or {}
    local prompt = input_calls[1] and input_calls[1].prompt_title or ""
    local summary = string.format(
      "%d|%s|%d|%s",
      #ctx.vim_state.input_calls,
      call.prompt or "",
      #input_calls,
      prompt
    )
    assert.eq(summary, "1|Logcat package: |1|Logcat filter", "header enter")
  end)
end

local function open_without_adb_opens_panel_and_renders_header()
  local header_lines = { value = nil }
  local panel_open_calls = { count = 0 }
  local state = state_with("com.saved", "Saved")

  local panel = panel_stub({
    header_lines = header_lines,
    clear_body_calls = { count = 0 },
  })

  local stubs = stubs_helper.merge_stubs(logcat_helpers.no_adb_stubs(), {
    ["android.ui.panel"] = {
      open = function()
        panel_open_calls.count = panel_open_calls.count + 1
      end,
      clear = panel.clear,
      append = panel.append,
      set_header_lines = panel.set_header_lines,
      clear_body = panel.clear_body,
      replace_body = panel.replace_body,
      close = panel.close,
    },
    ["android.logcat.processes"] = {
      list_packages = function()
        error("list_packages should not be called without adb")
      end,
    },
  })

  logcat_helpers.with_logcat_context({
    state = state,
    header_lines = header_lines,
    stubs = stubs,
  }, function()
    local header = table.concat(header_lines.value or {}, "|")
    local summary = string.format("%d|%s", panel_open_calls.count, header)
    assert.eq(summary, "1|Package: com.saved|Filter: Saved|Level: ", "panel opened")
  end)
end

local function open_without_adb_does_not_spawn()
  local state = state_with("com.saved", "Saved")
  local stubs = logcat_helpers.no_adb_stubs()

  logcat_helpers.with_logcat_context({ state = state, stubs = stubs }, function(ctx)
    assert.eq(ctx.spawn_calls.count, 0, "no spawn without adb")
  end)
end

local function manual_package_input_updates_state_without_adb()
  local state = state_with("com.saved", "Saved")
  local stubs = logcat_helpers.no_adb_stubs()

  logcat_helpers.with_logcat_and_enter({
    state = state,
    vim_opts = { input_value = "com.manual" },
    stubs = stubs,
  }, 1, function(ctx)
    local summary = string.format("%s|%d", ctx.state.logcat.package or "", ctx.spawn_calls.count)
    assert.eq(summary, "com.manual|0", "manual package")
  end)
end

local function retry_keymap_restarts_logcat_when_adb_available()
  local state = state_with("com.saved", "")

  logcat_helpers.with_logcat_and_retry({ state = state }, function(ctx)
    assert.table_eq(
      { ctx.spawn_calls.count, ctx.clear_body_calls.count },
      { 2, 1 },
      "spawn after retry"
    )
  end)
end

local function retry_keymap_warns_when_adb_missing()
  local state = state_with("com.saved", "")
  local stubs = logcat_helpers.no_adb_stubs()

  logcat_helpers.with_logcat_and_retry({ state = state, stubs = stubs }, function(ctx)
    local has_notify = #ctx.vim_state.notify_calls >= 1
    local last = ctx.vim_state.notify_calls[#ctx.vim_state.notify_calls] or {}
    local summary = string.format(
      "%s|%s|%d",
      tostring(has_notify),
      last.message or "",
      ctx.spawn_calls.count
    )
    assert.eq(summary, "true|adb not available for logcat|0", "warned on retry")
  end)
end

function M.run()
  package_change_restarts_logcat()
  package_change_persists_state()
  header_rerenders_after_package_change()
  package_fallback_uses_input_and_persists_state()
  package_fallback_restarts_logcat()
  package_fallback_uses_empty_default_when_no_saved_package()
  empty_package_input_clears_and_restarts()
  header_enter_prompts_for_package_and_filter_modal()
  open_without_adb_opens_panel_and_renders_header()
  open_without_adb_does_not_spawn()
  manual_package_input_updates_state_without_adb()
  retry_keymap_restarts_logcat_when_adb_available()
  retry_keymap_warns_when_adb_missing()
end

return M
