local M = {}

local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function base_state()
  return {
    build = {
      module = ":app",
      variant = "debug",
    },
    logcat = {
      package = "com.saved",
      filter = "Auth",
      level = "W",
      serial = "device-1",
    },
  }
end

local function open_sets_panel_names_from_selected_values()
  local panel_names = { value = nil, history = {} }
  logcat_helpers.with_logcat_context({
    state = base_state(),
    panel_names = panel_names,
  }, function()
    local names = panel_names.value or {}
    assert.eq(
      names.body,
      "android://logcat module=:app variant=debug app=com.saved filter=Auth level=W",
      "body panel name"
    )
    assert.eq(
      names.control,
      "android://logcat-controls module=:app variant=debug app=com.saved filter=Auth level=W",
      "control panel name"
    )
  end)
end

local function package_change_updates_panel_names()
  local panel_names = { value = nil, history = {} }
  local stubs = logcat_helpers.package_picker_stubs("com.changed")

  logcat_helpers.with_logcat_context({
    state = base_state(),
    panel_names = panel_names,
    stubs = stubs,
  }, function(ctx)
    logcat_helpers.press_enter(ctx, 1)
    local names = panel_names.value or {}
    assert.eq(
      names.body,
      "android://logcat module=:app variant=debug app=com.changed filter=Auth level=W",
      "body name after package"
    )
  end)
end

local function filter_change_updates_panel_names()
  local panel_names = { value = nil, history = {} }
  local stubs = {
    ["android.ui.picker"] = {
      filter_input = function(opts)
        if opts.on_accept then
          opts.on_accept("Crash")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({
    state = base_state(),
    panel_names = panel_names,
    stubs = stubs,
  }, function(ctx)
    logcat_helpers.start_filter_edit(ctx)
    local names = panel_names.value or {}
    assert.eq(
      names.body,
      "android://logcat module=:app variant=debug app=com.saved filter=Crash level=W",
      "body name after filter"
    )
  end)
end

local function level_change_updates_panel_names()
  local panel_names = { value = nil, history = {} }
  local stubs = {
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_select then
          opts.on_select("E")
        end
      end,
    },
  }

  logcat_helpers.with_logcat_context({
    state = base_state(),
    panel_names = panel_names,
    stubs = stubs,
  }, function(ctx)
    ctx.vim_state.keymaps["n"]["gl"]()
    local names = panel_names.value or {}
    assert.eq(
      names.body,
      "android://logcat module=:app variant=debug app=com.saved filter=Auth level=E",
      "body name after level"
    )
  end)
end

function M.run()
  open_sets_panel_names_from_selected_values()
  package_change_updates_panel_names()
  filter_change_updates_panel_names()
  level_change_updates_panel_names()
end

return M
